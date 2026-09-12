import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../Database/db_helper.dart';
import '../../Helper/offline_helper.dart';  // Build #offline
import '../../Helper/url_helper.dart';
import '../../Models/Orders/refund_orderlist_model.dart';

class CompletedOrdersRepository {
  final String baseUrl;

  CompletedOrdersRepository({
    required this.baseUrl,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch completed orders — with offline fallback to SQLite
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<CompletedOrder>> fetchCompletedOrders({
    required int page,
    int? perPage,
    int? authorId,
    String? from,
    String? to,
  }) async {
    // Check connectivity first
    final isOnline = await OfflineHelper.isNetworkAvailable();

    if (!isOnline) {
      if (kDebugMode) print('[RefundRepo] Offline: serving completed orders from SQLite');
      return OfflineHelper.buildOfflineCompletedOrdersFromDb(
        page: page,
        perPage: perPage ?? 20,
        authorId: authorId,
        from: from,
        to: to,
      );
    }

    try {
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

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("completed orders Status Code: ${response.statusCode}");
        print("Body: ${response.body}");
      }

      // Build #offline: session expired → propagate for re-login
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('SESSION_EXPIRED: Your session has expired. Please log in again.');
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
      return ordersList.map((e) => CompletedOrder.fromJson(e)).toList();
    } catch (e, s) {
      if (kDebugMode) {
        print('[RefundRepo] fetchCompletedOrders error: $e\n$s');
      }

      // Session error → rethrow so UI can redirect to login
      if (OfflineHelper.isSessionError(e)) rethrow;

      // Any other error (network, timeout) → offline fallback
      if (kDebugMode) print('[RefundRepo] Falling back to offline SQLite completed orders');
      return OfflineHelper.buildOfflineCompletedOrdersFromDb(
        page: page,
        perPage: perPage ?? 20,
        authorId: authorId,
        from: from,
        to: to,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token helper
  // ─────────────────────────────────────────────────────────────────────────
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
      throw Exception('SESSION_EXPIRED: No active user token found. Please log in again.');
    }

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      print('Using JWT token: ${token.length > 20 ? token.substring(0, 20) : token}...');
    }

    return token;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Refund order — with offline fallback: mark items locally
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> refundOrder({
    required int orderId,
    required String refundType,
    List<Map<String, dynamic>>? items,
  }) async {
    final isOnline = await OfflineHelper.isNetworkAvailable();

    if (!isOnline) {
      // Build #offline: mark items as refunded in SQLite so they cannot be double-refunded
      return _processOfflineRefund(orderId: orderId, refundType: refundType, items: items);
    }

    try {
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

      // Build #offline: session expired
      if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          "success": false,
          "type": "session_error",
          "message": "Your session has expired. Please log in again."
        };
      }

      /// ✅ SUCCESS
      if (response.statusCode == 200) {
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
    } catch (e) {
      if (kDebugMode) print('[RefundRepo] refundOrder error: $e');
      if (OfflineHelper.isSessionError(e)) {
        return {
          "success": false,
          "type": "session_error",
          "message": "Your session has expired. Please log in again."
        };
      }
      // Network error → process offline
      return _processOfflineRefund(orderId: orderId, refundType: refundType, items: items);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal: mark items as refunded in SQLite, queue sync
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _processOfflineRefund({
    required int orderId,
    required String refundType,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final db = await DBHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        if (refundType == "Partial" && items != null && items.isNotEmpty) {
          for (final item in items) {
            final rawServerItemId =
                item["order_item_id"] ?? item["items_server_id"];
            final rawLocalItemId =
                item["item_id"] ?? item["items_id"];
            final rawProductId =
                item["product_id"] ?? item["item_product_id"];

            final qty =
                int.tryParse(item["qty"]?.toString() ?? '') ??
                int.tryParse(item["items_count"]?.toString() ?? '') ??
                1;

            final serverItemId =
                int.tryParse(rawServerItemId?.toString() ?? '');
            final localItemId =
                int.tryParse(rawLocalItemId?.toString() ?? '');
            final productId =
                rawProductId?.toString().trim();

            int updated = 0;
            if (serverItemId != null) {
              updated = await txn.rawUpdate(
                'UPDATE ${AppDBConst.purchasedItemsTable} '
                'SET ${AppDBConst.isRefundItem} = 1 '
                'WHERE ${AppDBConst.itemServerId} = ? '
                'AND ${AppDBConst.isRefundItem} = 0',
                [serverItemId],
              );
            } else if (localItemId != null) {
              updated = await txn.rawUpdate(
                'UPDATE ${AppDBConst.purchasedItemsTable} '
                'SET ${AppDBConst.isRefundItem} = 1 '
                'WHERE ${AppDBConst.itemId} = ? '
                'AND ${AppDBConst.isRefundItem} = 0',
                [localItemId],
              );
            }

            if (updated == 0) {
              throw Exception(
                'Refund item is missing, already refunded, or not found.',
              );
            }

            final restock =
                item["restock"] == true ||
                item["restockToInventory"] == true ||
                item["restock_to_inventory"] == true;

            if (productId != null && productId.isNotEmpty && qty > 0) {
              await txn.rawUpdate(
                'UPDATE ${AppDBConst.fastKeyItemsTable} '
                'SET ${AppDBConst.fastKeyStockQuantity} = '
                '${AppDBConst.fastKeyStockQuantity} + ? '
                'WHERE ${AppDBConst.fastKeyProductId} = ?',
                restock ? [qty, productId] : [0, productId],
              );

              await txn.insert(
                AppDBConst.inventoryLogTable,
                {
                  AppDBConst.inventoryLogOrderId: orderId,
                  AppDBConst.inventoryLogOrderItemId:
                      serverItemId ?? localItemId,
                  AppDBConst.inventoryLogProductId: productId,
                  AppDBConst.inventoryLogQuantity: qty,
                  AppDBConst.inventoryLogAction:
                      restock ? 'RESTOCK' : 'DISCARD',
                  AppDBConst.inventoryLogReason:
                      restock
                          ? 'OFFLINE_REFUND'
                          : 'OFFLINE_REFUND_NON_RESTOCK',
                  AppDBConst.inventoryLogCreatedAt: now,
                  AppDBConst.inventoryLogSynced: 0,
                },
              );
            }
          }
        } else {
          final rows = await txn.query(
            AppDBConst.purchasedItemsTable,
            where:
                '${AppDBConst.orderIdForeignKey} = ? '
                'AND ${AppDBConst.isRefundItem} = 0',
            whereArgs: [orderId],
          );

          if (rows.isEmpty) {
            throw Exception('No refundable items found for order $orderId.');
          }

          for (final row in rows) {
            final qty =
                int.tryParse(row[AppDBConst.itemCount]?.toString() ?? '') ?? 1;
            final productId =
                row[AppDBConst.itemProductId]?.toString().trim();

            final changed = await txn.update(
              AppDBConst.purchasedItemsTable,
              {AppDBConst.isRefundItem: 1},
              where:
                  '${AppDBConst.itemId} = ? AND ${AppDBConst.isRefundItem} = 0',
              whereArgs: [row[AppDBConst.itemId]],
            );

            if (changed != 1) {
              throw Exception('Could not mark full-refund item as refunded.');
            }

            if (productId != null && productId.isNotEmpty && qty > 0) {
              await txn.rawUpdate(
                'UPDATE ${AppDBConst.fastKeyItemsTable} '
                'SET ${AppDBConst.fastKeyStockQuantity} = '
                '${AppDBConst.fastKeyStockQuantity} + ? '
                'WHERE ${AppDBConst.fastKeyProductId} = ?',
                [qty, productId],
              );

              await txn.insert(
                AppDBConst.inventoryLogTable,
                {
                  AppDBConst.inventoryLogOrderId: orderId,
                  AppDBConst.inventoryLogOrderItemId:
                      row[AppDBConst.itemServerId] ?? row[AppDBConst.itemId],
                  AppDBConst.inventoryLogProductId: productId,
                  AppDBConst.inventoryLogQuantity: qty,
                  AppDBConst.inventoryLogAction: 'RESTOCK',
                  AppDBConst.inventoryLogReason: 'OFFLINE_FULL_REFUND',
                  AppDBConst.inventoryLogCreatedAt: now,
                  AppDBConst.inventoryLogSynced: 0,
                },
              );
            }
          }

          await txn.update(
            AppDBConst.orderTable,
            {
              AppDBConst.orderStatus: 'refunded',
              AppDBConst.synced: 0,
            },
            where: '${AppDBConst.orderId} = ?',
            whereArgs: [orderId],
          );
        }
      });

      if (kDebugMode) {
        print(
          '[Offline Refund] Atomic refund completed for order $orderId '
          '($refundType)',
        );
      }

      return {
        "success": true,
        "offline": true,
        "message":
            "Refund recorded locally. Inventory and sync audit records were saved.",
        "data": {
          "order_id": orderId,
          "refund_type": refundType,
          "status": "pending_sync",
        }
      };
    } catch (e) {
      if (kDebugMode) {
        print('[Offline Refund] Transaction rolled back: $e');
      }
      return {
        "success": false,
        "offline": true,
        "message":
            "Could not process refund offline. No partial refund changes were saved.",
      };
    }
  }
}
