import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';

class RefundOrderRepository {
  final String baseUrl;

  RefundOrderRepository({required this.baseUrl});
  Future<bool> fullOrderRefund({
    required int orderId,
    required double amount,
    required String reason,
    required String itemsReusable,
  }) async {
    final token = await _getTokenFromDb();

    final url = Uri.parse(
      "${UrlHelper.baseUrl}pinaka-pos/v1/orders/full-order-refund",
    );
    if (kDebugMode) {
      print("=========== FULL ORDER REFUND API ===========");
      print("URL: $url");
      print("Order ID: $orderId");
      print("Amount: $amount");
      print("Reason: $reason");
      print("Items Reusable: $itemsReusable");
      print("=============================================");
    }

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "order_id": orderId,
          "amount": amount,
          "reason": reason,
          "items_reusable": itemsReusable,
        }),
      );

      if (kDebugMode) {
        print("Status Code: ${response.statusCode}");
        print("Raw Response: ${response.body}");
      }

      if (response.statusCode == 200) {
        // ✅ Handle empty array
        if (response.body.isEmpty || response.body == '[]') {
          if (kDebugMode) print("Refund API SUCCESS ✅ (empty array returned)");
          return true;
        }

        // ✅ Parse JSON safely
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data["success"] == true) {
            if (kDebugMode) print("Refund API SUCCESS ✅");
            return true;
          } else {
            if (kDebugMode) print("Refund API FAILED ❌ Message: ${data["message"]}");
            return false;
          }
        } else {
          // Unexpected response structure
          if (kDebugMode) print("Refund API returned unexpected structure ❌");
          return false;
        }
      } else {
        if (kDebugMode) print("HTTP Error ❌");
        return false;
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("Refund API Exception ❌");
        print("Error: $e");
        print("StackTrace: $stacktrace");
      }
      rethrow;
    }
  }
  //  Internal method to get token
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

    if (kDebugMode) print('Using JWT token: ${token.substring(0, 20)}...');

    return token;
  }
}