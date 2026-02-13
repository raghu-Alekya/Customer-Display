import 'package:flutter/foundation.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinaka_pos/Database/storage/isar_box_storage.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';

/// One-time migration from Hive to Isar for existing user data.
/// Call once at app startup before any storage is read.
Future<void> migrateHiveToIsarIfNeeded() async {
  const key = 'hive_to_isar_migration_v1_done';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) == true) return;

  try {
    final boxes = [
      'offlineOrders', 'deletedOrders', 'productCache', 'orderExtras',
      'cashbackConfig', 'user', 'categoryCache', 'fastKeysBox',
    ];
    for (final name in boxes) {
      if (!Hive.isBoxOpen(name)) {
        try {
          await Hive.openBox(name);
        } catch (_) {
          // Box doesn't exist yet (fresh install), skip
        }
      }
    }

    await _migrateBox('offlineOrders', StorageProvider.offlineOrders);
    await _migrateBox('deletedOrders', StorageProvider.deletedOrders);
    await _migrateBox('productCache', StorageProvider.productCache);
    await _migrateBox('orderExtras', StorageProvider.orderExtras);
    await _migrateBox('cashbackConfig', StorageProvider.cashbackConfig);
    await _migrateBox('user', StorageProvider.user);
    await _migrateBox('categoryCache', StorageProvider.categoryCache);
    await _migrateBox('fastKeysBox', StorageProvider.fastKeysBox);

    await prefs.setBool(key, true);
    if (kDebugMode) {
      print('✅ Hive to Isar migration completed');
    }
  } catch (e, s) {
    if (kDebugMode) {
      print('⚠️ Hive to Isar migration error: $e');
      print(s);
    }
    // Don't set flag on error - allow retry on next launch
  }
}

Future<void> _migrateBox(String boxName, IsarBoxStorage target) async {
  if (!Hive.isBoxOpen(boxName)) return;

  final box = Hive.box(boxName);
  final keys = box.keys.toList();
  if (keys.isEmpty) return;

  for (final k in keys) {
    final key = k.toString();
    final value = box.get(key);
    if (value != null) {
      await target.put(key, value);
    }
  }

  if (kDebugMode && keys.isNotEmpty) {
    print('   Migrated $boxName: ${keys.length} entries');
  }
}
