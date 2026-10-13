import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Helper/offline_helper.dart';
import 'inventory_get_product_types_model.dart';

abstract class InventoryGetProductTypesRemoteDataSource {
  Future<InventoryGetProductTypesModel> getProductTypes();
}

class InventoryGetProductTypesRemoteDataSourceImpl
    implements InventoryGetProductTypesRemoteDataSource {
  final http.Client client;

  InventoryGetProductTypesRemoteDataSourceImpl({required this.client});

  @override
  Future<InventoryGetProductTypesModel> getProductTypes() async {
    if (!await OfflineHelper.isNetworkAvailable()) {
      if (kDebugMode) debugPrint('#### Offline: product types served as empty local list');
      return InventoryGetProductTypesModel(types: const <String, String>{});
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
        throw Exception('No active user token found');
      }

      final token = result.first[AppDBConst.userToken];

      // Corrected URL
      final url =
          '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}inventories${EndUrlConstants.get_product_types}';

      if (kDebugMode) {
        print('#### PRODUCT TYPES URL: $url');
      }

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return InventoryGetProductTypesModel.fromJson(decoded);
      } else {
        if (kDebugMode) {
          print('#### API ERROR: ${response.statusCode}');
          print('#### BODY: ${response.body}');
        }
        throw Exception('Failed to load product types');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('#### Product types unavailable: serving empty local list');
      return InventoryGetProductTypesModel(types: const <String, String>{});
    }
  }
}
