import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';

import '../../Database/isar_cache_entry.dart';
import '../../Database/isar_service.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../Auth/AuthIdsStore.dart';
import '../../core/api/token_storage.dart';

const String categoryBoxName = 'categoryCache';
const String productBoxName = 'productCache';
const cacheDuration = Duration(hours: 12);

/// Loads categories and products from the authenticated PCH catalog endpoint.
///
/// Endpoint:
/// POST /pos/auth/catalog/get-categories-products
///
/// Authentication and tenant headers are read from the values saved during
/// merchant/store login and employee login. The combined catalog response is
/// cached locally so the POS can still display previously loaded data offline.
class CategoryRepository {
  static const String _catalogEndpoint =
      'pos/auth/catalog/get-categories-products';
  static const String _catalogCacheKey = 'pch_catalog_categories_products';

  static final Map<int, Future<CategoryListResponse>> _inFlightByParent = {};
  static Future<Map<String, dynamic>>? _inFlightCatalog;

  Future<CategoryListResponse> getCategories({int parent = 0}) async {
    final cacheKey = 'categories_$parent';
    try {
      final categories = await _fetchStoreCategories();
      final filtered = categories.where((item) {
        return _toInt(item['parent'] ?? item['parent_id']) == parent;
      }).toList();

      await _cacheList(cacheKey, filtered);
      return CategoryListResponse.fromJson(filtered);
    } catch (e) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        if (kDebugMode) {
          print('Store categories API unavailable; using cached categories for $parent: $e');
        }
        return CategoryListResponse.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Fetch categories from the authenticated PCH store-categories endpoint.
  /// The access token is read from secure TokenStorage, and the store ID
  /// comes from the saved merchant/store login session.
  Future<List<Map<String, dynamic>>> _fetchStoreCategories() async {
    final token = (await TokenStorage().getAccessToken())?.trim() ?? '';
    final storeId = (await AuthIdsStore.getStoreId()).trim();

    if (token.isEmpty) {
      throw Exception(
        'Missing employee access token. Please log in to the employee account again.',
      );
    }
    if (storeId.isEmpty) {
      throw Exception(
        'Missing saved store ID. Please complete merchant/store login again.',
      );
    }

    final uri = Uri.parse(
      'https://pch.alektasolutions.com/connector/api/v1/store/'
          '$storeId/store-categories',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      // Never print the bearer token.
      print('Store categories API: GET $uri');
      print('Store categories API status: ${response.statusCode}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Store categories API failed (${response.statusCode}): '
            '${_safeBody(response.body)}',
      );
    }

    final decoded = json.decode(response.body);
    final List<dynamic>? rawList = decoded is List
        ? decoded
        : decoded is Map
        ? _findListByKeys(decoded, const {
      'data',
      'categories',
      'store_categories',
      'storeCategories',
    })
        : null;

    if (rawList == null) {
      throw Exception('Store categories API response is not a category list.');
    }

    return rawList.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final rawImage = item['image'];
      String? imageUrl;
      if (rawImage is Map) {
        imageUrl = (rawImage['src'] ?? rawImage['url'] ?? '').toString();
        if (imageUrl.isEmpty) imageUrl = null;
      } else if (rawImage is String && rawImage.isNotEmpty) {
        imageUrl = rawImage;
      }

      return <String, dynamic>{
        ...item,
        'id': _toInt(item['id'] ?? item['category_id']),
        'name': _readableName(item['name'] ?? item['category_name']),
        'slug': (item['slug'] ?? '').toString(),
        'parent': _toInt(item['parent'] ?? item['parent_id']),
        'description': (item['description'] ?? '').toString(),
        'count': _toInt(item['count'] ?? item['product_count']),
        'image': imageUrl,
      };
    }).toList();
  }

  Future<CategoryListResponse> _dedupedCategoriesApi(int parent) {
    final existing = _inFlightByParent[parent];
    if (existing != null) return existing;
    final future = getCategories(parent: parent).whenComplete(() {
      _inFlightByParent.remove(parent);
    });
    _inFlightByParent[parent] = future;
    return future;
  }

  /// Kept for compatibility with any existing callers that used this method.
  Future<CategoryListResponse> getCategoriesFromApi(int parent) =>
      _dedupedCategoriesApi(parent);

  Future<CategoryProductListResponse> getProductsByCategory(
      int categoryId) async {
    try {
      // Fetch products from the selected store category endpoint.
      final rawProducts = await _fetchStoreCategoryProducts(categoryId);
      final normalized = rawProducts.map(_normalizeProduct).toList();

      await _cacheList('products_$categoryId', normalized);
      return CategoryProductListResponse.fromJson(normalized);
    } catch (e) {
      final cached = await _readCachedList('products_$categoryId');
      if (cached != null) {
        if (kDebugMode) {
          print('Store category products API unavailable; using cached products '
              'for $categoryId: $e');
        }
        return CategoryProductListResponse.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Fetch products for one category from the authenticated PCH endpoint:
  /// GET /connector/api/v1/store/{storeId}/store-categories/{categoryId}/products
  ///
  /// The access token and store ID are read from the saved login session.
  Future<List<Map<String, dynamic>>> _fetchStoreCategoryProducts(
      int categoryId) async {
    final token = (await TokenStorage().getAccessToken())?.trim() ?? '';
    final storeId = (await AuthIdsStore.getStoreId()).trim();

    if (token.isEmpty) {
      throw Exception(
        'Missing employee access token. Please log in to the employee account again.',
      );
    }
    if (storeId.isEmpty) {
      throw Exception(
        'Missing saved store ID. Please complete merchant/store login again.',
      );
    }

    final uri = Uri.parse(
      'https://pch.alektasolutions.com/connector/api/v1/store/'
          '$storeId/store-categories/$categoryId/products',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      // Never print the bearer token.
      print('Store category products API: GET $uri');
      print('Store category products API status: ${response.statusCode}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Store category products API failed (${response.statusCode}): '
            '${_safeBody(response.body)}',
      );
    }

    final decoded = json.decode(response.body);
    final List<dynamic>? rawList = decoded is List
        ? decoded
        : decoded is Map
        ? _findListByKeys(decoded, const {
      'data',
      'products',
      'items',
      'category_products',
      'categoryProducts',
      'product_list',
      'productList',
    })
        : null;

    if (rawList == null) {
      throw Exception(
        'Store category products API response is not a product list.',
      );
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Make one authenticated request to the combined categories/products API.
  Future<Map<String, dynamic>> _getCatalog() {
    final current = _inFlightCatalog;
    if (current != null) return current;

    final request = _fetchCatalog().whenComplete(() {
      _inFlightCatalog = null;
    });
    _inFlightCatalog = request;
    return request;
  }

  Future<Map<String, dynamic>> _fetchCatalog() async {
    await UrlHelper.initializeBaseUrl();

    final token = (await TokenStorage().getAccessToken())?.trim() ?? '';
    final merchantId = (await AuthIdsStore.getMerchantId()).trim();
    final storeId = (await AuthIdsStore.getStoreId()).trim();

    if (token.isEmpty) {
      throw Exception(
        'Missing employee access token. Please log in to the employee account again.',
      );
    }
    if (merchantId.isEmpty || storeId.isEmpty) {
      throw Exception(
        'Missing saved merchant/store IDs. Please complete merchant/store login again.',
      );
    }

    final baseUrl = UrlHelper.baseUrl;
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse('$normalizedBase$_catalogEndpoint');

    final response = await http
        .post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-merchant-id': merchantId,
        'x-store-id': storeId,
      },
      body: '',
    )
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      // Do not log the token or any authorization header.
      print('Catalog API: POST $uri');
      print('Catalog API status: ${response.statusCode}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Catalog API failed (${response.statusCode}): ${_safeBody(response.body)}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      await _cacheCatalog(decoded);
      return decoded;
    }
    if (decoded is List) {
      final wrapped = <String, dynamic>{'data': decoded};
      await _cacheCatalog(wrapped);
      return wrapped;
    }
    throw Exception('Unexpected catalog response format.');
  }

  String _safeBody(String body) {
    // Avoid including any credentials in exception messages.
    final trimmed = body.trim();
    return trimmed.length > 500 ? '${trimmed.substring(0, 500)}…' : trimmed;
  }

  Future<void> _cacheCatalog(Map<String, dynamic> catalog) async {
    final isar = await IsarService.instance;
    await isar.writeTxn(() async {
      await isar.isarCacheEntrys.put(
        IsarCacheEntry()
          ..key = _catalogCacheKey
          ..json = json.encode(catalog)
          ..timestamp = DateTime.now(),
      );
    });
  }

  Future<Map<String, dynamic>?> _readCachedCatalog() async {
    final isar = await IsarService.instance;
    final entry = await isar.isarCacheEntrys
        .where()
        .keyEqualTo(_catalogCacheKey)
        .findFirst();
    if (entry == null) return null;
    final decoded = json.decode(entry.json);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<Map<String, dynamic>> _getCatalogFromCache() async {
    final cached = await _readCachedCatalog();
    if (cached == null) throw Exception('No cached catalog is available.');
    return cached;
  }

  List<dynamic> _extractCategories(Map<String, dynamic> catalog) {
    final found = _findListByKeys(catalog, const {
      'categories',
      'category_list',
      'categoryList',
      'product_categories',
      'productCategories',
    });
    if (found != null) return found;

    // Some connector responses return data as a list of category records
    // instead of wrapping that list in a "categories" property.
    final data = catalog['data'] ?? catalog['result'] ?? catalog['payload'];
    if (data is List &&
        data.any((item) =>
        item is Map &&
            (item.containsKey('category_id') ||
                item.containsKey('category_name') ||
                item.containsKey('parent_id')))) {
      return data;
    }
    if (_isCategoryObject(catalog)) return [catalog];
    throw Exception('The catalog response does not contain a categories list.');
  }

  List<dynamic> _extractProducts(
      Map<String, dynamic> catalog, int categoryId) {
    // First check category-grouped responses so products from another
    // category are never accidentally displayed.
    final categories = _flattenCategories(_extractCategories(catalog));
    for (final category in categories) {
      if (_toInt(category['id']) == categoryId) {
        final products = category['products'] ??
            category['items'] ??
            category['category_products'];
        if (products is List) return products;
      }
    }

    final topProducts = _findListByKeys(catalog, const {
      'products',
      'product_list',
      'productList',
      'category_products',
      'categoryProducts',
      'items',
    });

    if (topProducts != null) {
      final matched = topProducts.where((item) {
        if (item is! Map) return false;
        final categoryIds = _productCategoryIds(item);
        // If response products don't carry category IDs, keep them: the API
        // may already have filtered them to the requested category.
        return categoryIds.isEmpty || categoryIds.contains(categoryId);
      }).toList();
      return matched;
    }

    return const [];
  }

  List<dynamic>? _findListByKeys(
      dynamic node, Set<String> keys, {int depth = 0}) {
    if (depth > 8) return null;
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        if (keys.contains(key) && entry.value is List) {
          return List<dynamic>.from(entry.value as List);
        }
      }
      // Prefer drilling into common response envelopes first.
      for (final key in const ['data', 'result', 'response', 'payload']) {
        final value = node[key];
        if (value != null) {
          final result = _findListByKeys(value, keys, depth: depth + 1);
          if (result != null) return result;
        }
      }
      for (final value in node.values) {
        if (value is Map || value is List) {
          final result = _findListByKeys(value, keys, depth: depth + 1);
          if (result != null) return result;
        }
      }
    } else if (node is List) {
      for (final value in node) {
        final result = _findListByKeys(value, keys, depth: depth + 1);
        if (result != null) return result;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _flattenCategories(List<dynamic> categories) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    void visit(dynamic item, int inheritedParent) {
      if (item is! Map) return;
      final map = Map<String, dynamic>.from(item);
      final nestedCategory = map['category'];
      final categoryMap = nestedCategory is Map
          ? (Map<String, dynamic>.from(nestedCategory)..addAll({
        if (map['products'] is List) 'products': map['products'],
        if (map['items'] is List) 'items': map['items'],
      }))
          : map;
      final id = categoryMap['id'] ??
          categoryMap['category_id'] ??
          categoryMap['categoryId'];
      final parent = _toInt(
        categoryMap['parent'] ??
            categoryMap['parent_id'] ??
            categoryMap['parentId'] ??
            inheritedParent,
      );

      if (id != null && _isCategoryObject(categoryMap)) {
        final idString = id.toString();
        if (seen.add(idString)) {
          result.add({
            ...categoryMap,
            'id': _toInt(id),
            'parent': parent,
            'name': _readableName(categoryMap['name'] ??
                categoryMap['category_name'] ??
                categoryMap['title']),
            'slug': (map['slug'] ?? '').toString(),
            'description': (map['description'] ?? '').toString(),
            'count': _toInt(map['count'] ?? map['product_count']),
          });
        }
      }

      final children = map['children'] ??
          map['subcategories'] ??
          map['sub_categories'] ??
          map['child_categories'];
      if (children is List) {
        for (final child in children) {
          visit(child, _toInt(id ?? inheritedParent));
        }
      }
    }

    for (final item in categories) {
      visit(item, 0);
    }
    return result;
  }

  bool _isCategoryObject(Map value) {
    return value.containsKey('id') ||
        value.containsKey('category_id') ||
        value.containsKey('categoryId');
  }

  String _readableName(dynamic value) {
    if (value is Map) {
      return (value['rendered'] ?? value['name'] ?? '').toString();
    }
    return value?.toString() ?? '';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<int> _productCategoryIds(Map product) {
    final raw = product['categories'] ?? product['category_ids'] ?? [];
    if (raw is! List) return const [];
    return raw.map((item) {
      if (item is Map) {
        return _toInt(item['id'] ?? item['category_id']);
      }
      return _toInt(item);
    }).where((id) => id != 0).toList();
  }

  Map<String, dynamic> _normalizeProduct(dynamic item) {
    if (item is! Map) {
      throw Exception('Unexpected product item in catalog response.');
    }
    final product = Map<String, dynamic>.from(item);
    final rawName = product['name'] ?? product['product_name'] ?? product['title'];
    final name = _readableName(rawName);
    final rawImage = product['image'] ?? product['images'];
    String image = '';
    if (rawImage is Map) {
      image = (rawImage['src'] ?? rawImage['url'] ?? '').toString();
    } else if (rawImage is List && rawImage.isNotEmpty) {
      final first = rawImage.first;
      if (first is Map) image = (first['src'] ?? first['url'] ?? '').toString();
      if (first is String) image = first;
    } else if (rawImage is String) {
      image = rawImage;
    }

    final categories = product['categories'];
    final normalizedCategories = categories is List
        ? categories.map((value) {
      if (value is Map) {
        return {
          ...Map<String, dynamic>.from(value),
          'id': _toInt(value['id'] ?? value['category_id']),
          'name': _readableName(value['name'] ?? value['category_name']),
          'slug': (value['slug'] ?? '').toString(),
          'parent': _toInt(value['parent'] ?? value['parent_id']),
          'description': (value['description'] ?? '').toString(),
          'count': _toInt(value['count']),
        };
      }
      return {
        'id': _toInt(value),
        'name': '',
        'slug': '',
        'parent': 0,
        'description': '',
        'count': 0,
      };
    }).toList()
        : <Map<String, dynamic>>[];

    return {
      ...product,
      'id': _toInt(product['id'] ?? product['product_id']),
      'name': name,
      'sku': (product['sku'] ?? '').toString(),
      'price': product['price'] ?? product['regular_price'] ?? 0,
      'regular_price': (product['regular_price'] ?? '').toString(),
      'sale_price': (product['sale_price'] ?? '').toString(),
      'categories': normalizedCategories,
      'tags': product['tags'] is List ? product['tags'] : <dynamic>[],
      'images': rawImage is List
          ? rawImage
          : (image.isNotEmpty ? <dynamic>[{'src': image}] : <dynamic>[]),
      'attributes': product['attributes'] is List
          ? product['attributes']
          : <dynamic>[],
      'meta_data': product['meta_data'] is List
          ? product['meta_data']
          : <dynamic>[],
      'variations': product['variations'] is List
          ? product['variations']
          : <dynamic>[],
      'type': (product['type'] ?? 'simple').toString(),
    };
  }

  Future<void> _cacheList(String key, List<dynamic> list) async {
    final isar = await IsarService.instance;
    await isar.writeTxn(() async {
      await isar.isarCacheEntrys.put(
        IsarCacheEntry()
          ..key = key
          ..json = json.encode(list)
          ..timestamp = DateTime.now(),
      );
    });
  }

  Future<List<dynamic>?> _readCachedList(String key) async {
    final isar = await IsarService.instance;
    final entry =
    await isar.isarCacheEntrys.where().keyEqualTo(key).findFirst();
    if (entry == null) {
      // For category/product caches from older versions, attempt to derive
      // the requested list from the combined catalog cache.
      try {
        final catalog = await _getCatalogFromCache();
        if (key.startsWith('categories_')) {
          final parent = int.tryParse(key.substring('categories_'.length)) ?? 0;
          return _flattenCategories(_extractCategories(catalog))
              .where((item) => _toInt(item['parent']) == parent)
              .toList();
        }
        if (key.startsWith('products_')) {
          final id = int.tryParse(key.substring('products_'.length)) ?? 0;
          return _extractProducts(catalog, id).map(_normalizeProduct).toList();
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    final decoded = json.decode(entry.json);
    return decoded is List ? decoded : null;
  }
}
