import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../Database/db_helper.dart';
import '../../Helper/url_helper.dart';

class PartialRefundRepository {
  final String baseUrl;

  PartialRefundRepository({required this.baseUrl});

  Future<bool> partialOrderRefund({
    required int orderId,
    required String reason,
    required String itemsReusable,
    required List<Map<String, dynamic>> items, // [{"order_item_id": 123, "qty": 1, "refundable_amount": 10}]
  }) async {
    final token = await _getTokenFromDb();

    final url = Uri.parse(
      '${UrlHelper.baseUrl}pinaka-pos/v1/orders/partial-order-refund',
    );

    if (kDebugMode) {
      print("=========== PARTIAL ORDER REFUND API ===========");
      print("URL: $url");
      print("Order ID: $orderId");
      print("Reason: $reason");
      print("Items Reusable: $itemsReusable");
      print("Items: $items");
      print("===============================================");
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
          "reason": reason,
          "items_reusable": itemsReusable,
          "items": items,
        }),
      );

      if (kDebugMode) {
        print("Status Code: ${response.statusCode}");
        print("Raw Response: ${response.body}");
      }

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '[]') {
          if (kDebugMode) print("Partial Refund API SUCCESS ✅ (empty array returned)");
          return true;
        }

        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data["success"] == true) {
            if (kDebugMode) {
              print("Partial Refund API SUCCESS ✅");
              print("Refunded Amount: ${data["refunded_amount"]}");
              print("Refund ID: ${data["refund_id"]}");
            }
            return true;
          } else {
            if (kDebugMode) print("Partial Refund API FAILED ❌ Message: ${data["message"]}");
            return false;
          }
        } else {
          if (kDebugMode) print("Partial Refund API returned unexpected structure ❌");
          return false;
        }
      } else {
        if (kDebugMode) print("HTTP Error ❌");
        return false;
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("Partial Refund API Exception ❌");
        print("Error: $e");
        print("StackTrace: $stacktrace");
      }
      rethrow;
    }
  }

  // Internal method to get token from DB
  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;

    final result = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
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