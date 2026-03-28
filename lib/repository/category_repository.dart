import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:kioski2/features/category/data/models/category_model.dart';

import '../model/category_model.dart';

class CategoryRemoteDataSource {
  static const String _baseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/wc/v3/products/categories';

  final http.Client _client;

  CategoryRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<CategoryModel>> fetchCategories() async {
    final headers = await _authHeaders();
    final uris = <Uri>[
      Uri.parse(
          '$_baseUrl?page=1&per_page=100&hide_empty=true&parent=28'),
      Uri.parse(
          '$_baseUrl?page=1&per_page=100&hide_empty=false&parent=28'),
      Uri.parse('$_baseUrl?page=1&per_page=100&hide_empty=false&parent=0'),
    ];

    Exception? lastError;
    for (final uri in uris) {
      try {
        final response = await _client.get(
          uri,
          headers: headers,
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Failed categories request (${response.statusCode})',
          );
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw Exception('Unexpected categories response format');
        }

        final categories = decoded
            .whereType<Map<String, dynamic>>()
            .map(CategoryModel.fromJson)
            .where((e) => e.id != 0)
            .toList(growable: false);

        if (categories.isNotEmpty) {
          return categories;
        }
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    if (lastError != null) throw lastError;
    return const [];
  }

  Future<List<CategoryModel>> fetchSubcategories(int parentId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '$_baseUrl?page=1&per_page=100&hide_empty=false&parent=$parentId',
    );
    final response = await _client.get(
      uri,
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed subcategories request (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .where((e) => e.parent > 0)
        .toList(growable: false);
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) {
      throw Exception('Authentication token missing. Please login again.');
    }
    return {
      'Authorization': 'Bearer $token',
    };
  }
}