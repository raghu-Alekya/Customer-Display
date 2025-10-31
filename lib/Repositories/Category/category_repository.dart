// repositories/category_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../Search/product_search_repository.dart';

const String categoryBoxName = 'categoryCache';
const String productBoxName = 'productCache';
const cacheDuration = Duration(hours: 12);

class CategoryRepository {
  final APIHelper _helper = APIHelper();

  /// ✅ Load Categories (and Subcategories) — with Hive Cache
  Future<CategoryListResponse> getCategories({int parent = 0}) async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.categories}${EndUrlConstants.allCategoriesEndUrl}$parent";

    final box = Hive.box(categoryBoxName);
    final cacheKey = "categories_$parent";
    final cachedData = box.get(cacheKey);
    if (cachedData != null) {
      final cacheTimestamp = DateTime.parse(cachedData['timestamp']);
      final isExpired = DateTime.now().difference(cacheTimestamp) > cacheDuration;

      if (!isExpired) {
        if (kDebugMode) print("✅ Loaded categories from Hive cache (parent: $parent)");
        final List<dynamic> cachedList = json.decode(cachedData['data']);
        return CategoryListResponse.fromJson(cachedList);
      } else {
        if (kDebugMode) print("⚠️ Cache expired for categories (parent: $parent)");
      }
    }
    if (kDebugMode) print("🌍 Fetching categories from API: $url");
    final response = await _helper.get(url, true);

    List<dynamic> categoryList;

    if (response is String) {
      categoryList = json.decode(response);
    } else if (response is List) {
      categoryList = response;
    } else {
      throw Exception("Unexpected response type in categories GET");
    }
    await box.put(cacheKey, {
      'timestamp': DateTime.now().toIso8601String(),
      'data': json.encode(categoryList),
    });

    if (kDebugMode) print("💾 Categories cached in Hive for parent: $parent");

    return CategoryListResponse.fromJson(categoryList);
  }

  Future<CategoryProductListResponse> getProductsByCategory(int categoryId) async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.productByCategories}/$categoryId";

    final box = Hive.box(productBoxName);
    final cacheKey = "products_$categoryId";
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      final cacheTimestamp = DateTime.parse(cachedData['timestamp']);
      final isExpired = DateTime.now().difference(cacheTimestamp) > cacheDuration;

      if (!isExpired) {
        if (kDebugMode) print("✅ Loaded products from Hive cache (category: $categoryId)");
        final List<dynamic> cachedList = json.decode(cachedData['data']);
        return CategoryProductListResponse.fromJson(cachedList);
      } else {
        if (kDebugMode) print("⚠️ Cache expired for products (category: $categoryId)");
      }
    }

    if (kDebugMode) print("🌍 Fetching products from API: $url");
    final response = await _helper.get(url, true);

    List<dynamic> productList;

    if (response is String) {
      productList = json.decode(response);
    } else if (response is List) {
      productList = response;
    } else {
      throw Exception("Unexpected response type in products GET");
    }

    // 💾 Save to Hive
    await box.put(cacheKey, {
      'timestamp': DateTime.now().toIso8601String(),
      'data': json.encode(productList),
    });

    if (kDebugMode) print("💾 Products cached in Hive for category: $categoryId");

    // 💾 Also pre-cache variations for offline use
    final productCacheBox = Hive.box('productCache');
    final productRepo = ProductRepository(); // ✅ use this

    for (final product in productList) {
      final productId = product['id'];
      final hasEmbeddedVariants =
          product['variations'] != null && product['variations'].isNotEmpty;

      if (hasEmbeddedVariants) {
        // Normalize embedded variations before saving
        final normalized = product['variations'].map<Map<String, dynamic>>((v) {
          final image = (v["image"] is Map && v["image"]["src"] != null)
              ? v["image"]["src"]
              : (v["image"] is String ? v["image"] : "");
          final name = (v["name"] is Map && v["name"]["rendered"] != null)
              ? v["name"]["rendered"]
              : (v["name"] is String ? v["name"] : "Unnamed Variant");
          final price = v["price"]?.toString() ?? "0";

          return {
            "id": v["id"],
            "name": name,
            "price": price,
            "sku": v["sku"] ?? "",
            "image": image,
          };
        }).toList();

        await productCacheBox.put("product_${productId}_variations", {
          'variations': normalized,
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print("💾 Cached embedded variations for product $productId");
        }
      } else {
        // Fetch and cache from WC API
        try {
          await productRepo.fetchProductVariations(productId); // ✅ fixed call
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ Failed to fetch variations for product $productId: $e");
          }
        }
      }
    }

    return CategoryProductListResponse.fromJson(productList);
  }


  /// 🧹 Optional: Clear cache (manual refresh)
  Future<void> clearCache() async {
    await Hive.box(categoryBoxName).clear();
    await Hive.box(productBoxName).clear();
    if (kDebugMode) print("🧹 Hive caches cleared.");
  }
}
