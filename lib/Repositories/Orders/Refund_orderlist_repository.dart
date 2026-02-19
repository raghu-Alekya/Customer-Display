import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../Database/db_helper.dart';
import '../../Models/Orders/refund_orderlist_model.dart';

class CompletedOrdersRepository {
  final String baseUrl;

  CompletedOrdersRepository({
    required this.baseUrl,
  });

  Future<List<CompletedOrder>> fetchCompletedOrders({
    required int page,
    required int perPage,
    int? authorId,
    String? from,
    String? to,
  }) async {
    final token = await _getTokenFromDb();

    // ✅ Build query parameters dynamically
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (authorId != null) 'author': authorId.toString(),
      if (from != null && from.isNotEmpty) 'after': from,
      if (to != null && to.isNotEmpty) 'before': to,
    };

    final uri = Uri.parse(
      '$baseUrl/wp-json/pinaka-pos/v1/orders/completed-orders',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print("========== COMPLETED ORDERS API ==========");
      print("URL: $uri");
      print("Using Token: ${token.substring(0, 20)}...");
    }

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (kDebugMode) {
      print("Status Code: ${response.statusCode}");
      print("Body: ${response.body}");
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load completed orders (status: ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    // ✅ Safe parsing
    if (decoded == null ||
        decoded['orders_data'] == null ||
        decoded['orders_data'] is! List) {
      return [];
    }

    final List ordersList = decoded['orders_data'];

    return ordersList
        .map((e) => CompletedOrder.fromJson(e))
        .toList();
  }

  // 🔥 SAME TOKEN METHOD
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
      throw Exception('No active user token found in database');
    }

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      print('Using JWT token: ${token.substring(0, 20)}...');
    }

    return token;
  }
}
