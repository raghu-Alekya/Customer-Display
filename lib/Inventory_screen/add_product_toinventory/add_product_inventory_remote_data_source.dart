import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';

class AddProductInventoryTaxRemoteDataSource {
  // final http.Client client;

  // AddProductInventoryTaxRemoteDataSource({required this.client});

  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    // Get the DB instance
    final db = await DBHelper.instance.database;

    // Query to get the latest active user token
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

    // Correct headers
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Replace with your correct URL
    final url =
        "${UrlHelper.wooBaseUrl}products";

    if (kDebugMode) {
      print('#### ADD PRODUCT URL: $url');
      print('#### PRODUCT DATA: $productData');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(productData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      if (kDebugMode) {
        print('#### API ERROR: ${response.statusCode}');
        print('#### BODY: ${response.body}');
      }
      throw Exception('Failed to add product: ${response.reasonPhrase}');
    }
  }
}
