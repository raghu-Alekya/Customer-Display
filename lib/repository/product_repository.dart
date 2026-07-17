import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/product model.dart';
import '../utils/appconstant.dart';

class ProductRemoteDataSource {
  String get _customBaseUrl => AppConstants.productsByCategoryEndpoint;

  String get _wcProductsBaseUrl => AppConstants.wcProductsEndpoint;
  final http.Client _client;

  ProductRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<ProductModel>> fetchProductsByCategory(int categoryId) async {
    final cacheKey = 'products_cache_category_$categoryId';

    final cached = await _readCachedProducts(
      cacheKey,
      maxAge: const Duration(minutes: 20),
    );

    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final endpoint = Uri.parse('$_customBaseUrl/$categoryId');

    final products = await _requestProducts(endpoint);

    if (products.isNotEmpty) {
      await _writeCachedProducts(cacheKey, products);
    }

    return products;
  }
  Future<List<ProductModel>> searchProducts(String query) async {
    print("🔍 Searching Products: $query");
    final normalizedQuery = query.trim().toLowerCase();
    final cacheKey = 'products_cache_search_$normalizedQuery';
    final cached = await _readCachedProducts(
      cacheKey,
      maxAge: const Duration(minutes: 10),
    );
    if (cached != null && cached.isNotEmpty) {
      print("⚡ Returning cached search products for: $normalizedQuery");
      return cached;
    }

    final endpoints = <Uri>[
      Uri.parse(
        '$_wcProductsBaseUrl?search=${Uri.encodeQueryComponent(query)}&per_page=100',
      ),
      Uri.parse(
        '$_wcProductsBaseUrl?search=${Uri.encodeQueryComponent(query)}&per_page=100&status=publish',
      ),
    ];

    Exception? lastError;

    for (final endpoint in endpoints) {
      print("👉 Trying Search Endpoint: $endpoint");

      try {
        final products = await _requestProducts(endpoint);

        print("✅ Search Result Count: ${products.length}");

        if (products.isNotEmpty) {
          await _writeCachedProducts(cacheKey, products);
          return products;
        }
      } catch (e) {
        print("❌ Search Error: $e");
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) {
      print("🚨 Final Search Error: $lastError");
      throw lastError;
    }

    print("⚠️ No search results found");
    return const [];
  }

  Future<List<ProductModel>> _requestProducts(Uri endpoint) async {
    final headers = await _authHeaders();

    print("🔵 API Call: $endpoint");
    print("👉 Headers: $headers");

    final response = await _client.get(
      endpoint,
      headers: headers,
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load products (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    print("👉 Decoded Response Type: ${decoded.runtimeType}");
    print("👉 Decoded Response: $decoded");

    final list = _extractList(decoded);

    print("👉 Extracted List Length: ${list.length}");

    final products = list
        .whereType<Map<String, dynamic>>()
        .map((e) {
      print("👉 Mapping Product: $e");
      return ProductModel.fromJson(e);
    })
        .toList(growable: false);

    print("✅ Final Product Count: ${products.length}");

    return products;
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();

    print("🔐 Token: $token");

    if (token.isEmpty) {
      print("❌ Token Missing!");
      throw Exception('Authentication token missing. Please login again.');
    }

    return {
      'Authorization': 'Bearer $token',
    };
  }

  List<dynamic> _extractList(dynamic decoded) {
    print("🔍 Extracting List from Response...");

    if (decoded is List) return decoded;

    if (decoded is Map<String, dynamic>) {
      return _findListInMap(decoded);
    }

    print("⚠️ Unknown response format");
    return const [];
  }

  List<dynamic> _findListInMap(Map<String, dynamic> map) {
    print("🔍 Searching list inside map keys...");

    final priorityKeys = ['products', 'items', 'data', 'result'];

    for (final key in priorityKeys) {
      final value = map[key];

      if (value is List) {
        print("✅ Found list in key: $key");
        return value;
      }

      if (value is Map<String, dynamic>) {
        final nested = _findListInMap(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;

      if (value is List) {
        print("✅ Found list in dynamic key: ${entry.key}");
        return value;
      }

      if (value is Map<String, dynamic>) {
        final nested = _findListInMap(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    print("⚠️ No list found in response");
    return const [];
  }

  Future<void> _writeCachedProducts(
    String key,
    List<ProductModel> products,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'items': products
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'price': p.price,
                  'image': p.imageUrl ?? '',
                  'is_veg': p.isVeg,
                })
            .toList(growable: false),
      };
      await prefs.setString(key, jsonEncode(payload));
    } catch (e) {
      print("⚠️ Failed to write products cache for key=$key: $e");
    }
  }

  Future<List<ProductModel>?> _readCachedProducts(
    String key, {
    required Duration maxAge,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final ts = decoded['ts'];
      if (ts is! int) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > maxAge.inMilliseconds) {
        return null;
      }

      final items = decoded['items'];
      if (items is! List) return null;
      final products = items
          .whereType<Map>()
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return products;
    } catch (e) {
      print("⚠️ Failed to read products cache for key=$key: $e");
      return null;
    }
  }
}