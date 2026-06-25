import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:pinaka_pos/Database/storage/box_storage.dart';
import 'package:pinaka_pos/Database/isar_service.dart';

/// Isar-backed implementation of BoxStorage using IsarCacheEntry.
/// Keys are prefixed with box name: "boxName::recordKey"
class IsarBoxStorage implements BoxStorage {
  IsarBoxStorage(this._boxName);

  final String _boxName;
  String _fullKey(String key) => '$_boxName::$key';

  Future<Isar> get _db async => await IsarService.instance;

  @override
  Future<dynamic> get(String key) async {
    final isar = await _db;
    final entry = await isar.isarCacheEntrys
        .where()
        .keyEqualTo(_fullKey(key))
        .findFirst();
    if (entry == null) return null;
    try {
      return jsonDecode(entry.json);
    } catch (_) {
      return entry.json;
    }
  }

  @override
  Future<void> put(String key, dynamic value) async {
    final isar = await _db;
    final fullKey = _fullKey(key);

    final String newJson = value is String ? value : jsonEncode(value);

    await isar.writeTxn(() async {

      final existing = await isar.isarCacheEntrys
          .where()
          .keyEqualTo(fullKey)
          .findFirst();

      // First save
      if (existing == null) {
        final entry = IsarCacheEntry()
          ..key = fullKey
          ..json = newJson
          ..timestamp = DateTime.now();

        await isar.isarCacheEntrys.put(entry);
        return;
      }

      Map<String, dynamic> oldMap = {};
      Map<String, dynamic> newMap = {};

      try { oldMap = jsonDecode(existing.json); } catch (_) {}
      try { newMap = jsonDecode(newJson); } catch (_) {}

      final bool isCheckoutUpdate = newMap['_update_source'] == 'checkout';
      if (!isCheckoutUpdate && oldMap.containsKey('discount_lines')) {
        newMap['discount_lines'] = oldMap['discount_lines'];
      }
      newMap.remove('_update_source');

      existing.json = jsonEncode(newMap);
      existing.timestamp = DateTime.now();

      await isar.isarCacheEntrys.put(existing);
    });
  }


  @override
  Future<bool> containsKey(String key) async {
    final isar = await _db;
    return await isar.isarCacheEntrys
        .where()
        .keyEqualTo(_fullKey(key))
        .count() > 0;
  }

  @override
  Future<void> delete(String key) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.isarCacheEntrys
          .where()
          .keyEqualTo(_fullKey(key))
          .deleteAll();
    });
  }

  @override
  Future<Map<String, dynamic>> toMap() async {
    final isar = await _db;
    final prefix = _fullKey('');
    final entries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith(prefix)
        .findAll();
    final result = <String, dynamic>{};
    for (final e in entries) {
      final shortKey = e.key.substring(prefix.length);
      try {
        result[shortKey] = jsonDecode(e.json);
      } catch (_) {
        result[shortKey] = e.json;
      }
    }
    return result;
  }

  @override
  Future<List<String>> getKeys() async {
    final m = await toMap();
    return m.keys.map((k) => k.toString()).toList();
  }
}
