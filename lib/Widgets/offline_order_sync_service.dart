import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../Repositories/Orders/order_repository.dart';
import '../Screens/Home/isar_payments/local_payments_db_helper.dart';

class OfflineOrderSyncService {
  static Timer? _timer;
  static bool _isSyncing = false;

  static void start() {
    _timer ??= Timer.periodic(
      const Duration(minutes: 1),
          (_) => syncPendingOrders(),
    );


    if (kDebugMode) {
      print("🔁 Offline order background sync started (1 min)");
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) {
      print("🛑 Offline order background sync stopped");
    }
  }

  static Future<void> syncPendingOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final box = Hive.box('offlineOrders');
      final keys = box.keys.toList();

      if (kDebugMode) {
        print("🔍 Checking offline orders → ${keys.length}");
      }

      for (final key in keys) {
        final raw = box.get(key);
        if (raw is! Map) continue;

        final order = Map<String, dynamic>.from(raw);

        // 🚫 Skip Woo → Local mapping records
        if (order.containsKey('map_to_local')) {
          if (kDebugMode) {
            print("🔁 Skipping mapping record → $key");
          }
          continue;
        }

        // ✅ Normalize products (migration-safe)
        List products = [];

        if (order['products'] is List && (order['products'] as List).isNotEmpty) {
          products = order['products'];
        } else if (order['items'] is List && (order['items'] as List).isNotEmpty) {
          products = order['items'];

          // 🔥 Auto-migrate legacy orders
          order['products'] = products;
          await box.put(key, order);
        }

        for (final key in keys) {
          final raw = box.get(key);
          if (raw is! Map) continue;

          final order = Map<String, dynamic>.from(raw);

          // ✅ Parse orderId safely

          final int? orderId = key is int ? key : int.tryParse(key.toString());

          if (orderId == null) {
            if (kDebugMode) print("⛔ Invalid order key: $key");
            continue;
          }

          final bool hasItems =
              order['items'] != null && (order['items'] as List).isNotEmpty;

          if (!hasItems) {
            if (kDebugMode) print("⛔ Skipping order $orderId → no items");
            continue;
          }

          // ✅ Fetch ONLY unsynced payments
          final payments =
          (await LocalPaymentDBHelper.instance.getPaymentsByOrderId(orderId))
              .where((p) => !p.isSynced)
              .toList();

          // Attach payments to order payload
          order['payments'] = payments.map((p) => {
            'local_id': p.id, // 👈 IMPORTANT for mapping back
            'orderId': p.orderId,
            'paymentMethod': p.paymentMethod,
            'amount': p.amount,
            'remainingBalance':
            p.remainingBalance < 0 ? 0 : p.remainingBalance,
            'status': p.status?.name ?? 'pending',
            'createdAt': p.createdAt.toIso8601String(),
          }).toList();

          if (kDebugMode) {
            print("\n📌 Payments for Order #$orderId (${payments.length}):");
            for (var p in payments) {
              print(
                  "   → ID: ${p.id} | Method: ${p.paymentMethod} | "
                      "Amount: \$${p.amount.toStringAsFixed(2)} | "
                      "Remaining: \$${p.remainingBalance.toStringAsFixed(2)} | "
                      "Status: ${p.status?.name ?? 'pending'} | Synced: ${p.isSynced}");
            }

            print("\n📤 Ready to sync order #$orderId:");
            print(order);
          }

          // 🚀 Send to server
          final result = await OrderRepository().syncSingleOfflineOrder(order);

          if (result == null || result['order_id'] == null) {
            if (kDebugMode) {
              print("❌ Order sync failed for #$orderId");
            }
            continue;
          }

          // ✅ Mark order as synced
          order['wooOrderId'] = result['order_id'];
          order['synced'] = true;
          order['sync_at'] = DateTime.now().toIso8601String();
          await box.put(key, order);

          // ✅ Mark PAYMENTS as synced
          if (result['payments'] != null && result['payments'] is List) {
            for (final sp in result['payments']) {
              final int? localId = sp['local_id'];
              final int? serverId = sp['server_id'];

              if (localId != null && serverId != null) {
                await LocalPaymentDBHelper.instance
                    .markAsSynced(localId, serverId);
              }
            }
          } else {
            // ⚠️ If backend does NOT return payment mapping
            for (final p in payments) {
              await LocalPaymentDBHelper.instance
                  .markAsSynced(p.id, result['order_id']);
            }
          }

          if (kDebugMode) {
            print("✅ Order + Payments synced → local:$orderId woo:${result['order_id']}");
          }
        }

        if (products.isEmpty) {
          if (kDebugMode) {
            print("⛔ Skipping order $key → no products");
          }
          continue;
        }

        final int? wooOrderId =
        int.tryParse(order['wooOrderId']?.toString() ?? '');


        final bool isSynced = order['synced'] == true;
        final String orderStatus =
            order['status']?.toString().toLowerCase() ?? '';

        if (wooOrderId != null &&
            wooOrderId > 0 &&
            isSynced &&orderStatus == 'completed'
        ) {

          await box.delete(key);

          if (kDebugMode) {
            print("🗑️ Completed order removed from Hive → local:$key woo:$wooOrderId");
          }

          continue;
        }

        if (kDebugMode) {
          print("📤 Syncing offline order → $key");
        }

        final result =
        await OrderRepository().syncSingleOfflineOrder(order);

        if (result != null && result['order_id'] != null) {
          order['wooOrderId'] = result['order_id'];
          order['synced'] = true;
          order['sync_at'] = DateTime.now().toIso8601String();

          await box.put(key, order);

          if (kDebugMode) {
            print(
              "✅ Order synced → local:$key woo:${result['order_id']}",
            );
          }
        }
      }
    } catch (e, s) {
      print("❌ Offline background sync failed: $e");
      print(s);
    } finally {
      _isSyncing = false;
    }
  }
}
