import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../Repositories/Orders/order_repository.dart';

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

        final int? wooOrderId =
        int.tryParse(order['wooOrderId']?.toString() ?? '');

        final bool hasItems =
        (order['items'] != null && (order['items'] as List).isNotEmpty);

        final bool isSynced = order['synced'] == true;

        // ✅ REAL LOCK CONDITION
        if (wooOrderId != null && wooOrderId > 0 && hasItems && isSynced) {
          if (kDebugMode) {
            print("🔒 Order locked → local:$key woo:$wooOrderId");
          }
          continue;
        }

        // 🚫 Never sync empty orders
        if (!hasItems) {
          if (kDebugMode) {
            print("⛔ Skipping order $key → no items");
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
