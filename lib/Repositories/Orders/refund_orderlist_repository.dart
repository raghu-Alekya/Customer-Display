import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Orders/refund_orderlist_model.dart';

class CompletedOrdersRepository {
  final String baseUrl;

  CompletedOrdersRepository({
    required this.baseUrl,
  });

  Future<List<CompletedOrder>> fetchCompletedOrders({
    required int page,
    int? perPage,
    int? authorId,
    String? from,
    String? to,
  }) async {
    final token = await _getTokenFromDb();

    // ✅ Build query parameters dynamically
    final queryParams = {
      'page': page.toString(),
      if (perPage != null) 'per_page': perPage.toString(),
      if (authorId != null) 'author': authorId.toString(),
      if (from != null && from.isNotEmpty) 'after': from,
      if (to != null && to.isNotEmpty) 'before': to,
    };

    final uri = Uri.parse(
      '${UrlHelper.baseUrl}pinaka-pos/v1/orders/completed-orders',
    ).replace(queryParameters: queryParams);
    if (kDebugMode) {

      print('API URL: $uri');

      print('cURL:');
      print('curl -X GET "$uri" \\');
      print('  -H "Authorization: Bearer $token" \\');
      print('  -H "Accept: application/json"');
    }

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    if (kDebugMode) {
      print("completed Status Code: ${response.statusCode}");
      print("Body: ${response.body}");
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load completed orders (status: ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (kDebugMode) {
      print("DECODED JSON:");
      debugPrint(decoded.toString());
    }


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

  Future<Map<String, dynamic>> refundOrder({
    required int orderId,
    required String refundType,
    List<Map<String, dynamic>>? items,
  }) async {
    final token = await _getTokenFromDb();

    final uri = Uri.parse(
      '${UrlHelper.baseUrl}pinaka-pos/v1/orders/get-amt-by-paymethod',
    );

    final Map<String, dynamic> body = {
      "order_id": orderId,
      "refund_type": refundType,
    };

    if (refundType == "Partial" && items != null) {
      body["items"] = items;
    }

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final Map<String, dynamic> responseData = jsonDecode(response.body);

    /// ✅ SUCCESS
    if (response.statusCode == 200) {
      if (refundType == "Partial" && items != null) {
        final db = await DBHelper.instance.database;

        // for (var item in items) {
        //   final int serverId = item["order_item_id"];
        //
        //   await db.rawUpdate(
        //     'UPDATE order_items SET is_refund_item = 1 WHERE items_server_id = ?',
        //     [serverId],
        //   );
        // }
      }

      return {
        "success": true,
        "data": responseData
      };
    }

    /// ❌ BACKEND DISCOUNT VALIDATION
    if (responseData["code"] == "discounted_items_found") {
      return {
        "success": false,
        "type": "discount_error",
        "message": responseData["message"]
      };
    }

    /// ❌ OTHER ERROR
    return {
      "success": false,
      "message": responseData["message"] ?? "Refund failed"
    };
  }
}