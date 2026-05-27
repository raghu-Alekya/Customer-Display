// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import '../../../Database/db_helper.dart';
// import 'inventory_attribute_items_model.dart';
//
// abstract class InventoryAttributeItemsRemoteDataSource {
//   Future<List<InventoryAttributeItemsModel>> getInventoryAttributeItems({required int attributeId});
// }
//
// class InventoryAttributeItemsRemoteDataSourceImpl implements InventoryAttributeItemsRemoteDataSource {
//   final http.Client client;
//
//   InventoryAttributeItemsRemoteDataSourceImpl({required this.client});
//
//   Future<String> _getTokenFromDb() async {
//     final db = await DBHelper.instance.database;
//     final result = await db.query(
//       AppDBConst.userTable,
//       where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
//       orderBy: '${AppDBConst.userId} DESC',
//       limit: 1,
//     );
//
//     if (result.isEmpty) throw Exception('No active user token found');
//     final token = result.first[AppDBConst.userToken] as String;
//     if (kDebugMode) print("Token from DB: $token");
//     return token;
//   }
//
//   @override
//   Future<List<InventoryAttributeItemsModel>> getInventoryAttributeItems({required int attributeId}) async {
//     final token = await _getTokenFromDb();
//     final url = "https://merchantretail.alektasolutions.com/wp-json/wc/v3/products/attributes/$attributeId/terms";
//
//     if (kDebugMode) print('URL: $url');
//
//     final response = await client.get(
//       Uri.parse(url),
//       headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
//     );
//
//     if (response.statusCode == 200) {
//       final decoded = json.decode(response.body) as List;
//       return decoded.map((e) => InventoryAttributeItemsModel.fromJson(e)).toList();
//     } else {
//       if (kDebugMode) print('API Error ${response.statusCode}: ${response.body}');
//       throw Exception('Failed to fetch inventory attribute items');
//     }
//   }
// }


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import 'inventory_attribute_items_model.dart';

class InventoryAttributeItemsApi {

  /// ✅ Token from DB (unchanged)
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
}

