import 'dart:convert';

import 'package:http/http.dart' as http;
// import 'package:kioski2/features/product/data/models/product_model.dart';

import '../model/product model.dart';

class ProductRemoteDataSource {
  static const String _customBaseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/products-by-category';
  static const String _wcProductsBaseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/wc/v3/products';

  static const String _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wva2lvc2tpLmFsZWt5YXRlY2hzb2x1dGlvbnMuY29tIiwiaWF0IjoxNzc0NTE5NDA4LCJuYmYiOjE3NzQ1MTk0MDgsImV4cCI6MTc3NzExMTQwOCwiZGF0YSI6eyJ1c2VyIjp7ImlkIjoyLCJkZXZpY2UiOiIiLCJwYXNzIjoiMmNjYzRkNDJlZGZlMzk3ODE1OTAyMzg3YmRhY2IxNGQifX19.Un2rM1rMr3HgWaO2XWpMn0UAHLAdQ_i8oV9WM3niZnw';

  final http.Client _client;

  ProductRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<ProductModel>> fetchProductsByCategory(int categoryId) async {
    final endpoints = <Uri>[
      Uri.parse('$_customBaseUrl/$categoryId'),
      Uri.parse(
        '$_wcProductsBaseUrl?category=$categoryId&per_page=100&status=publish',
      ),
    ];

    Exception? lastError;
    for (final endpoint in endpoints) {
      try {
        final products = await _requestProducts(endpoint);
        if (products.isNotEmpty) {
          return products;
        }
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) throw lastError;
    return const [];
  }

  Future<List<ProductModel>> searchProducts(String query) async {
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
      try {
        final products = await _requestProducts(endpoint);
        if (products.isNotEmpty) return products;
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) throw lastError;
    return const [];
  }

  Future<List<ProductModel>> _requestProducts(Uri endpoint) async {
    final response = await _client.get(
      endpoint,
      headers: const {
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load products (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final list = _extractList(decoded);

    return list
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList(growable: false);
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) return _findListInMap(decoded);
    return const [];
  }

  List<dynamic> _findListInMap(Map<String, dynamic> map) {
    final priorityKeys = ['products', 'items', 'data', 'result'];
    for (final key in priorityKeys) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final nested = _findListInMap(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    for (final value in map.values) {
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final nested = _findListInMap(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }
}