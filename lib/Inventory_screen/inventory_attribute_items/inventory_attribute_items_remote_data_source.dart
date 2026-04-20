import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import 'inventory_attribute_items_model.dart';

class InventoryAttributeItemsApi {

  /// Token from DB (unchanged)
  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where:
      '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('No active user token found');
    }

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print('Token from DB: $token');
    return token;
  }

  /// ✅ Fetch attribute terms using UrlHelper
  Future<List<InventoryAttributeItemsModel>> fetchItems(
      int attributeId) async {

    final token = await _getTokenFromDb();

    final String url =
        '${UrlHelper.wooBaseUrl}products/attributes/$attributeId/terms';

    if (kDebugMode) {
      print('Inventory Attribute Items URL: $url');
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => InventoryAttributeItemsModel.fromJson(e))
          .toList();
    } else {
      throw Exception(
        'Failed to load attribute items (${response.statusCode})',
      );
    }
  }

  /// ✅ Create a new attribute term
  Future<InventoryAttributeItemsModel> createTerm({
    required int attributeId,
    required String name,
    required String slug,
  }) async {
    final token = await _getTokenFromDb();

    final String url =
        '${UrlHelper.wooBaseUrl}products/attributes/$attributeId/terms';

    if (kDebugMode) {
      print('Create Term URL: $url');
      print('Create Term Body: name=$name, slug=$slug');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'slug': slug,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (kDebugMode) print('Created Term: $data');
      return InventoryAttributeItemsModel.fromJson(data);
    } else {
      throw Exception(
        'Failed to create term (${response.statusCode}): ${response.body}',
      );
    }
  }
}