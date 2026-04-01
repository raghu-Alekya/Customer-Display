import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/product model.dart';

class ProductRemoteDataSource {
  static const String _customBaseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/products-by-category';
  static const String _wcProductsBaseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/wc/v3/products';

  final http.Client _client;

  ProductRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<ProductModel>> fetchProductsByCategory(int categoryId) async {
    print("🔵 Fetch Products By Category ID: $categoryId");

    final endpoints = <Uri>[
      Uri.parse('$_customBaseUrl/$categoryId'),
      Uri.parse(
        '$_wcProductsBaseUrl?category=$categoryId&per_page=100&status=publish',
      ),
    ];

    Exception? lastError;

    for (final endpoint in endpoints) {
      print("👉 Trying Endpoint: $endpoint");

      try {
        final products = await _requestProducts(endpoint);

        print("✅ Products Count from $endpoint: ${products.length}");

        if (products.isNotEmpty) {
          return products;
        } else {
          print("⚠️ Empty response, trying next endpoint...");
        }
      } catch (e) {
        print("❌ Error from $endpoint: $e");
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) {
      print("🚨 Final Error: $lastError");
      throw lastError;
    }

    print("⚠️ No products found for category $categoryId");
    return const [];
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    print("🔍 Searching Products: $query");

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

        if (products.isNotEmpty) return products;
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
}