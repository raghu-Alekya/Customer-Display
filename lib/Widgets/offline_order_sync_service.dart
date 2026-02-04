import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../Repositories/Orders/order_repository.dart';
import '../Screens/Home/isar_payments/local_payments_db_helper.dart';

class OfflineOrderSyncService {
  //static Timer? _timer;
  static bool _isSyncing = false;

  // static void start() {
  //   _timer ??= Timer.periodic(
  //     const Duration(minutes: 1),
  //         (_) => syncPendingOrders(),
  //   );
  //
  //
  //   if (kDebugMode) {
  //     print("🔁 Offline order background sync started (1 min)");
  //   }
  // }
  //
  // static void stop() {
  //   _timer?.cancel();
  //   _timer = null;
  //   if (kDebugMode) {
  //     print("🛑 Offline order background sync stopped");
  //   }
  // }

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

        // 🚫 Skip Woo → Local mapping rows
        if (order.containsKey('map_to_local')) {
          if (kDebugMode) {
            print("🔁 Skipping mapping record → key:$key");
          }
          continue;
        }

        // ✅ Parse local orderId safely
        final int? orderId =
        key is int ? key : int.tryParse(key.toString());

        if (orderId == null) {
          if (kDebugMode) print("⛔ Invalid order key → $key");
          continue;
        }

        // ✅ Normalize products (migration-safe)
        List products = [];

        if (order['products'] is List &&
            (order['products'] as List).isNotEmpty) {
          products = order['products'];
        } else if (order['items'] is List &&
            (order['items'] as List).isNotEmpty) {
          products = order['items'];

          // 🔥 Auto-migrate legacy orders
          order['products'] = products;
          await box.put(key, order);
        }

        if (products.isEmpty) {
          if (kDebugMode) {
            print("⛔ Skipping order $orderId → no products");
          }
          continue;
        }

        // ✅ Fetch ONLY unsynced payments
        final payments =
        (await LocalPaymentDBHelper.instance
            .getPaymentsByOrderId(orderId))
            .where((p) => !p.isSynced)
            .toList();

        order['payments'] = payments.map((p) => {
          'local_id': p.id,
          'orderId': p.orderId,
          'paymentMethod': p.paymentMethod,
          'amount': p.amount,
          'remainingBalance':
          p.remainingBalance < 0 ? 0 : p.remainingBalance,
          'status': p.status?.name ?? 'pending',
          'createdAt': p.createdAt.toIso8601String(),
        }).toList();

        if (kDebugMode) {
          print("\n📦 Syncing order → local:$orderId");
          print("💰 Unsynced payments → ${payments.length}");
        }

        // 🚀 SYNC ONCE
        final result =
        await OrderRepository().syncSingleOfflineOrder(order);

        if (result == null || result is! Map) {
          if (kDebugMode) {
            print("❌ Invalid Woo response for order → $orderId");
          }
          continue;
        }

        final Map<String, dynamic> woo =
        Map<String, dynamic>.from(result);

        final int wooOrderId = woo['id'] ?? 0;

        final String wooStatus =
            woo['status']?.toString().toLowerCase() ?? '';

        if (kDebugMode) {
          print("🟣 Woo response → order:$wooOrderId status:$wooStatus");
        }


        // ✅ Mark payments as synced
        for (final p in payments) {
          await LocalPaymentDBHelper.instance
              .markAsSynced(p.id, wooOrderId);
        }

        // 🗑️ DELETE IMMEDIATELY if Woo says COMPLETED
        if (wooStatus == 'completed') {
          await box.delete(key);
          await box.delete(wooOrderId.toString());

          if (kDebugMode) {
            print(
              "🗑️ Offline order deleted → local:$orderId woo:$wooOrderId",
            );
          }

          continue;
        }

        // 🔁 Otherwise keep order for retry
        order['wooOrderId'] = wooOrderId;
        order['wooStatus'] = wooStatus;
        order['synced'] = true;
        order['sync_at'] = DateTime.now().toIso8601String();

        await box.put(key, order);

        if (kDebugMode) {
          print(
            "✅ Order saved for retry → local:$orderId woo:$wooOrderId status:$wooStatus",
          );
        }
      }
    } catch (e, s) {
      print("❌ Offline sync failed: $e");
      print(s);
    } finally {
      _isSyncing = false;
    }
  }

}
