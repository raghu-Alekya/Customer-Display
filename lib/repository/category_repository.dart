import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/category_model.dart';

class CategoryRemoteDataSource {
  static const String _baseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/wc/v3/products/categories';

  final http.Client _client;

  CategoryRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<CategoryModel>> fetchCategories() async {
    final headers = await _authHeaders();

    print("👉 Headers: $headers");

    final uris = <Uri>[
      Uri.parse('$_baseUrl?page=1&per_page=100&hide_empty=true&parent=28'),
      Uri.parse('$_baseUrl?page=1&per_page=100&hide_empty=false&parent=28'),
      Uri.parse('$_baseUrl?page=1&per_page=100&hide_empty=false&parent=0'),
    ];

    Exception? lastError;

    for (final uri in uris) {
      print("🔵 Calling API: $uri");

      try {
        final response = await _client.get(
          uri,
          headers: headers,
        );

        print("👉 Status Code: ${response.statusCode}");
        print("👉 Raw Response: ${response.body}");

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Failed categories request (${response.statusCode})',
          );
        }

        final decoded = jsonDecode(response.body);

        print("👉 Decoded Response Type: ${decoded.runtimeType}");
        print("👉 Decoded Response: $decoded");

        if (decoded is! List) {
          throw Exception('Unexpected categories response format');
        }

        final categories = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) {
          print("👉 Mapping Category: $e");
          return CategoryModel.fromJson(e);
        })
            .where((e) => e.id != 0)
            .toList(growable: false);

        print("✅ Categories Count: ${categories.length}");

        if (categories.isNotEmpty) {
          return categories;
        } else {
          print("⚠️ Empty result for this API, trying next...");
        }
      } catch (e) {
        print("❌ Error while fetching from $uri: $e");
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) {
      print("🚨 Final Error: $lastError");
      throw lastError;
    }

    print("⚠️ No categories found from all APIs");
    return const [];
  }

  Future<List<CategoryModel>> fetchSubcategories(int parentId) async {
    final headers = await _authHeaders();

    final uri = Uri.parse(
      '$_baseUrl?page=1&per_page=100&hide_empty=false&parent=$parentId',
    );

    print("🔵 Fetch Subcategories API: $uri");

    final response = await _client.get(
      uri,
      headers: headers,
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed subcategories request (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    print("👉 Decoded Subcategories: $decoded");

    if (decoded is! List) {
      print("⚠️ Unexpected format for subcategories");
      return const [];
    }

    final result = decoded
        .whereType<Map<String, dynamic>>()
        .map((e) {
      print("👉 Mapping Subcategory: $e");
      return CategoryModel.fromJson(e);
    })
        .where((e) => e.parent > 0)
        .toList(growable: false);

    print("✅ Subcategories Count: ${result.length}");

    return result;
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();

    print("🔐 Token from SharedPreferences: $token");

    if (token.isEmpty) {
      print("❌ Token Missing!");
      throw Exception('Authentication token missing. Please login again.');
    }

    return {
      'Authorization': 'Bearer $token',
    };
  }
}