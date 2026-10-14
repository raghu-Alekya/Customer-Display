import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:pinaka_pos/Database/user_db_helper.dart';
import 'package:pinaka_pos/Helper/url_helper.dart';
import 'package:pinaka_pos/Repositories/Auth/AuthIdsStore.dart';

class CashbackHelper {
  // ---------------------------------------------------------
  // SAFE READ from storage
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> getCashbackConfig() async {
    final box = StorageProvider.cashbackConfig;
    final raw = await box.get("config");

    if (raw == null) return null;

    try {
      return Map<String, dynamic>.from(raw is Map ? raw : {});
    } catch (_) {
      try {
        final converted = deepConvert(raw);
        return Map<String, dynamic>.from(converted as Map);
      } catch (_) {
        print("❌ CashbackHelper: Failed to convert config");
        return null;
      }
    }
  }

  // ---------------------------------------------------------
  // RECURSIVE CONVERTER
  // ---------------------------------------------------------
  static dynamic deepConvert(dynamic value) {
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        map[key.toString()] = deepConvert(val);
      });
      return map;
    }

    if (value is List) {
      return value.map((e) => deepConvert(e)).toList();
    }

    return value;
  }

  /// Token from SQLite active user (same source as rest of POS).
  /// Falls back to Hive StorageProvider.user only if DB has none.
  static Future<String?> _resolveToken() async {
    try {
      final fromDb = await UserDbHelper().getUserToken();
      if (fromDb != null && fromDb.isNotEmpty) {
        if (kDebugMode) {
          print("🔑 Cashback token from UserDbHelper (len=${fromDb.length})");
        }
        return fromDb;
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ UserDbHelper token failed: $e");
    }

    try {
      final userBox = StorageProvider.user;
      final tokenRaw = await userBox.get('token');
      if (tokenRaw is String && tokenRaw.trim().isNotEmpty) {
        return tokenRaw.trim();
      }
      if (tokenRaw is Map && tokenRaw['token'] != null) {
        final t = tokenRaw['token'].toString().trim();
        if (t.isNotEmpty) return t;
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ StorageProvider.user token failed: $e");
    }

    return null;
  }

  /// Store UUID from AuthIdsStore (global prefs after merchant login).
  static Future<String?> _resolveStoreId() async {
    try {
      final id = (await AuthIdsStore.getStoreId()).trim();
      if (id.isNotEmpty) {
        if (kDebugMode) print("🏪 Cashback storeId from AuthIdsStore → $id");
        return id;
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ AuthIdsStore storeId failed: $e");
    }
    return null;
  }

  // ---------------------------------------------------------
  // FETCH API
  // GET {connector base}/store/store-pos-configuration/{storeId}/cashback_settings
  // Response: { "cash_back_service": { enabled, max_cashback, tiers } }
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchCashbackConfig() async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      print("❌ No token found (UserDb + Hive) — cannot fetch cashback");
      return getCashbackConfig();
    }

    final storeId = await _resolveStoreId();
    if (storeId == null || storeId.isEmpty) {
      print("❌ No storeId found (AuthIdsStore) — cannot fetch cashback");
      return getCashbackConfig();
    }

    final box = StorageProvider.cashbackConfig;

    // baseUrl is: https://pch.alektasolutions.com/connector/api/v1
    final url =
        "${UrlHelper.baseUrl}/store/store-pos-configuration/$storeId/cashback_settings";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("🌐 Cashback API Status → ${response.statusCode}");
      print("🌐 Cashback API URL    → $url");
      print("🌐 Cashback API Body   → ${response.body}");

      if (response.statusCode == 200) {
        final decoded = deepConvert(jsonDecode(response.body));
        if (decoded is! Map) {
          print("❌ Cashback API body is not a map");
          return getCashbackConfig();
        }
        final safeJson = Map<String, dynamic>.from(decoded);

        await box.put("config", safeJson);

        final service = safeJson["cash_back_service"];
        if (service is Map) {
          print(
            "✅ Cashback config saved → enabled=${service['enabled']} "
                "max=${service['max_cashback']} "
                "tiers=${(service['tiers'] is List) ? (service['tiers'] as List).length : 0}",
          );
        }

        return safeJson;
      }

      print("❌ Cashback API non-200 → falling back to cache");
      return getCashbackConfig();
    } catch (e) {
      print("❌ Cashback API error: $e");
      return getCashbackConfig();
    }
  }

  // ---------------------------------------------------------
  // STARTUP LOADER
  // ---------------------------------------------------------
  static Future<void> loadCashbackOnStartup() async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      print("❌ No valid token found — skipping cashback API");
      return;
    }

    final storeId = await _resolveStoreId();
    if (storeId == null || storeId.isEmpty) {
      print("❌ No storeId found — skipping cashback API");
      return;
    }

    print("🔐 Cashback startup → token ok, storeId=$storeId");

    final box = StorageProvider.cashbackConfig;

    final lastFetchRaw = await box.get("lastFetchTime");
    final cached = await box.get("config");
    final now = DateTime.now();

    print("🕒 Cashback lastFetch = $lastFetchRaw");
    print("📦 Cached config = $cached");

    DateTime? lastFetchTime;

    if (lastFetchRaw is String) {
      lastFetchTime = DateTime.tryParse(lastFetchRaw);
    } else if (lastFetchRaw is Map && lastFetchRaw["time"] != null) {
      lastFetchTime = DateTime.tryParse(lastFetchRaw["time"].toString());
    }

    if (cached == null) {
      print("🟡 No Cashback config found → fetching new...");
      await fetchCashbackConfig();
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    if (lastFetchTime == null ||
        now.difference(lastFetchTime).inSeconds >= 2) {
      print("🔄 Refreshing cashback config...");
      await fetchCashbackConfig();
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    print("🟩 Using cached cashback config");
  }

  // ---------------------------------------------------------
  // CASHBACK FEE CALCULATOR
  // ---------------------------------------------------------
  static Future<double> getCashbackFee(double cashbackAmount) async {
    final config = await getCashbackConfig();

    if (config == null) return 0.0;

    final service = config["cash_back_service"];
    if (service is! Map) return 0.0;

    final enabled = service["enabled"];
    // Accept 1 or true
    final bool isEnabled =
        enabled == 1 || enabled == true || enabled?.toString() == "1";
    if (!isEnabled) {
      if (kDebugMode) {
        print("💰 Cashback fee skipped — service disabled (enabled=$enabled)");
      }
      return 0.0;
    }

    final tiers = service["tiers"];
    if (tiers is! List) return 0.0;

    for (final t in tiers) {
      if (t is! Map) continue;

      final from = double.tryParse(t["from"]?.toString() ?? "");
      final to = double.tryParse(t["to"]?.toString() ?? "");
      final fee = double.tryParse(t["fee"]?.toString() ?? "");

      if (from == null || to == null || fee == null) continue;

      if (cashbackAmount >= from && cashbackAmount <= to) {
        print("💰 CashbackAmount $cashbackAmount → Fee = $fee");
        return fee;
      }
    }

    if (kDebugMode) {
      print("💰 No tier matched for cashback amount $cashbackAmount → fee 0");
    }
    return 0.0;
  }
}
