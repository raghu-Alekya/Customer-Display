import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Helper/offline_helper.dart';
import 'inventory_tax_model.dart';

abstract class Inventory_Tax_Remote_Data_Source {
  Future<List<Inventory_Tax_Model>> fetchInventoryTaxes();
}

class Inventory_Tax_Remote_Data_Source_Impl
    implements Inventory_Tax_Remote_Data_Source {
  final http.Client client;

  Inventory_Tax_Remote_Data_Source_Impl(this.client);

  @override
  // Future<List<Inventory_Tax_Model>> fetchInventoryTaxes() async {
  //   // 🔹 GET TOKEN FROM DATABASE
  //   final db = await DBHelper.instance.database;
  //
  //   List<Map<String, dynamic>> result = await db.query(
  //     AppDBConst.userTable,
  //     where:
  //     '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
  //     orderBy: '${AppDBConst.userId} DESC',
  //     limit: 1,
  //   );
  //
  //   if (result.isEmpty) {
  //     if (kDebugMode) print("#### No active user found in database");
  //     throw Exception('No active user token found');
  //   }
  //
  //   final token = result.first[AppDBConst.userToken];
  //
  //   if (kDebugMode) {
  //     print("#### TOKEN FROM DB: $token");
  //   }
  //
  //   // 🔹 MAKE API CALL WITH TOKEN
  //   final response = await client.get(
  //     Uri.parse('https://merchantretail.alektasolutions.com/wp-json/wc/v3/taxes'),
  //     headers: {
  //       'Authorization': 'Bearer $token',
  //     },
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final List decoded = json.decode(response.body);
  //     return decoded.map((e) => Inventory_Tax_Model.fromJson(e)).toList();
  //   } else {
  //     if (kDebugMode) {
  //       print('#### API ERROR: ${response.statusCode}');
  //       print('#### BODY: ${response.body}');
  //     }
  //     throw Exception('Failed to load inventory taxes');
  //   }
  // }

  Future<List<Inventory_Tax_Model>> fetchInventoryTaxes() async {
    if (!await OfflineHelper.isNetworkAvailable()) {
      if (kDebugMode) debugPrint('#### Offline: inventory taxes served as empty local list');
      return [];
    }

    try {
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

      final token = result.first[AppDBConst.userToken];

      if (kDebugMode) {
        print("#### TOKEN FROM DB: $token");
      }

      // 🔹 Construct URL using UrlHelper constants
      final url = "${UrlHelper.wooBaseUrl}${EndUrlConstants.gettaxes}";

      if (kDebugMode) {
        print("#### INVENTORY TAXES URL: $url");
      }

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List decoded = json.decode(response.body);
        return decoded.map((e) => Inventory_Tax_Model.fromJson(e)).toList();
      } else {
        if (kDebugMode) {
          print('#### API ERROR: ${response.statusCode}');
          print('#### BODY: ${response.body}');
        }
        throw Exception('Failed to load inventory taxes');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('#### Inventory taxes unavailable: serving empty local list');
      return [];
    }
  }

}
