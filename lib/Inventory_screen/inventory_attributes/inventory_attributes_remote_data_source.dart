import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Helper/offline_helper.dart';
import 'inventory_attributes_model.dart';

abstract class InventoryAttributesRemoteDataSource {
  Future<List<InventoryAttributesModel>> getInventoryAttributes();
}

class InventoryAttributesRemoteDataSourceImpl
    implements InventoryAttributesRemoteDataSource {
  final http.Client client;

  InventoryAttributesRemoteDataSourceImpl({required this.client});

  /// 🔐 Same token helper as Categories
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
      if (kDebugMode) print("#### No active user found in database");
      throw Exception('No active user token found');
    }

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print("#### TOKEN FROM DbbbB: $token");
    return token;
  }

  @override
  Future<List<InventoryAttributesModel>> getInventoryAttributes() async {
    if (!await OfflineHelper.isNetworkAvailable()) {
      if (kDebugMode) debugPrint('#### Offline: inventory attributes served as empty local list');
      return [];
    }

    try {
      final token = await _getTokenFromDb();

      final String fullUrl =
          "${UrlHelper.wooBaseUrl}products/attributes";

      if (kDebugMode) {
        print("#### FULL REQUEST  attributes URLlll: $fullUrl");
      }

      final response = await client.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        return decoded
            .map((e) => InventoryAttributesModel.fromJson(e))
            .toList();
      } else {
        if (kDebugMode) {
          print('#### API ERROR: ${response.statusCode}');
          print('#### BODY: ${response.body}');
        }
        throw Exception('Failed to load attributes');
      }
    } catch (e) {
      if (!await OfflineHelper.isNetworkAvailable()) {
        if (kDebugMode) debugPrint('#### Inventory attributes network failure: serving empty local list');
        return [];
      }
      rethrow;
    }
  }

// @override
// Future<List<InventoryAttributesModel>> getInventoryAttributes() async {
//   final token = await _getTokenFromDb();
//
//   final String fullUrl = "${UrlHelper.wooBaseUrl}products/attributes";
//
//   if (kDebugMode) {
//     print("#### FULL REQUEST attributes URL: $fullUrl");
//     print("#### TOKEN: $token");
//   }
//
//   final response = await client.get(
//     Uri.parse(fullUrl),
//     headers: {
//       'Authorization': 'Bearer $token',
//       'Accept': 'application/json',
//     },
//   );
//
//   // Print the full response
//   if (kDebugMode) {
//         print("#### RESPONSE STATUS CODE: ${response.statusCode}");
//     print("#### RESPONSE BODY: ${response.body}");
//   }
//
//   if (response.statusCode == 200) {
//     final List<dynamic> decoded = json.decode(response.body);
//     if (kDebugMode) {
//       print("#### DECODED RESPONSE LENGTH: ${decoded.length}");
//     }
//     return decoded
//         .map((e) => InventoryAttributesModel.fromJson(e))
//         .toList();
//   } else {
//     if (kDebugMode) {
//       print('#### API ERROR: ${response.statusCode}');
//       print('####API BODY: ${response.body}');
//     }
//     throw Exception('Failed to load attributes');
//   }
// }


}
