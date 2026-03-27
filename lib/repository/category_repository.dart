import 'dart:convert';

import 'package:http/http.dart' as http;
// import 'package:kioski2/features/category/data/models/category_model.dart';

import '../model/category_model.dart';

class CategoryRemoteDataSource {
  static const String _baseUrl =
      'https://kioski.alekyatechsolutions.com/wp-json/wc/v3/products/categories';

  static const String _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wva2lvc2tpLmFsZWt5YXRlY2hzb2x1dGlvbnMuY29tIiwiaWF0IjoxNzc0NTE5NDA4LCJuYmYiOjE3NzQ1MTk0MDgsImV4cCI6MTc3NzExMTQwOCwiZGF0YSI6eyJ1c2VyIjp7ImlkIjoyLCJkZXZpY2UiOiIiLCJwYXNzIjoiMmNjYzRkNDJlZGZlMzk3ODE1OTAyMzg3YmRhY2IxNGQifX19.Un2rM1rMr3HgWaO2XWpMn0UAHLAdQ_i8oV9WM3niZnw';

  final http.Client _client;

  CategoryRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<CategoryModel>> fetchCategories() async {
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
          headers: const {
            'Authorization': 'Bearer $_token',
          },
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
    final uri = Uri.parse(
      '$_baseUrl?page=1&per_page=100&hide_empty=false&parent=$parentId',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Authorization': 'Bearer $_token',
      },
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
}
