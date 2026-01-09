import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import 'inventory_categories_model.dart';

abstract class InventoryCategoriesRemoteDataSource {
  Future<List<InventoryCategoriesModel>> getCategories();
}

class InventoryCategoriesRemoteDataSourceImpl implements InventoryCategoriesRemoteDataSource {
  final http.Client client;

  InventoryCategoriesRemoteDataSourceImpl({required this.client});

  // Helper function to get token from DB
  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      if (kDebugMode) print("#### No active user found in database");
      throw Exception('No active user token found');
    }

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print("#### TOKEN FROM DBbbb: $token");
    return token;
  }

  @override
  Future<List<InventoryCategoriesModel>> getCategories() async {
    final token = await _getTokenFromDb();

    /// Full correct URL
    final String fullUrl =
        "${UrlHelper.wooBaseUrl}products/categories";

    final Uri url = Uri.parse(fullUrl);

    if (kDebugMode) {
      print("#### FULL REQUEST URL: $fullUrl");
    }

    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> decoded = json.decode(response.body);
      return decoded
          .map((e) => InventoryCategoriesModel.fromJson(e))
          .toList();
    } else {
      if (kDebugMode) {
        print('#### API ERROR: ${response.statusCode}');
        print('#### BODY: ${response.body}');
      }
      throw Exception('Failed to load categories');
    }
  }

}
