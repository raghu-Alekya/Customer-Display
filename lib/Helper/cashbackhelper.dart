import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:pinaka_pos/Helper/url_helper.dart';

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

  // ---------------------------------------------------------
  // FETCH API
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchCashbackConfig() async {
    final userBox = StorageProvider.user;
    final tokenRaw = await userBox.get('token');

    final token = tokenRaw?.toString();

    if (token == null || token.isEmpty) {
      print("❌ No token found");
      return getCashbackConfig();
    }

    final box = StorageProvider.cashbackConfig;

    final url =
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.cashbackservices}";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      print("🌐 Cashback API Status → ${response.statusCode}");
      print("🌐 Cashback API Body   → ${response.body}");

      if (response.statusCode == 200) {
        final safeJson = deepConvert(jsonDecode(response.body));

        await box.put("config", safeJson);
        return Map<String, dynamic>.from(safeJson);
      }

      return getCashbackConfig();
    } catch (e) {
      print("❌ Cashback API error: $e");
      return getCashbackConfig();
    }
  }

  // ---------------------------------------------------------
  // STARTUP LOADER (FIXED TYPE SAFE)
  // ---------------------------------------------------------
  static Future<void> loadCashbackOnStartup() async {
    final userBox = StorageProvider.user;
    final tokenRaw = await userBox.get('token');

    String? token;

    if (tokenRaw is String) {
      token = tokenRaw;
    } else if (tokenRaw is Map && tokenRaw['token'] != null) {
      token = tokenRaw['token'].toString();
    }

    if (token == null || token.isEmpty) {
      print("❌ No valid token found — skipping cashback API");
      return;
    }

    print("🔐 Using token for Cashback Startup → $token");

    final box = StorageProvider.cashbackConfig;

    final lastFetchRaw = await box.get("lastFetchTime");
    final cached = await box.get("config");
    final now = DateTime.now();

    print("🕒 Cashback lastFetch = $lastFetchRaw");
    print("📦 Cached config = $cached");

    // ---------------------------------------------------------
    // SAFE PARSE lastFetchTime (FIX FOR YOUR CRASH)
    // ---------------------------------------------------------
    DateTime? lastFetchTime;

    if (lastFetchRaw is String) {
      lastFetchTime = DateTime.tryParse(lastFetchRaw);
    } else if (lastFetchRaw is Map && lastFetchRaw["time"] != null) {
      lastFetchTime =
          DateTime.tryParse(lastFetchRaw["time"].toString());
    }

    // ---------------------------------------------------------
    // 1️⃣ No cache → fetch
    // ---------------------------------------------------------
    if (cached == null) {
      print("🟡 No Cashback config found → fetching new...");
      await fetchCashbackConfig();
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    // ---------------------------------------------------------
    // 2️⃣ Refresh logic (safe)
    // ---------------------------------------------------------
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
  // CASHBACK FEE CALCULATOR (SAFE)
  // ---------------------------------------------------------
  static Future<double> getCashbackFee(double cashbackAmount) async {
    final config = await getCashbackConfig();

    if (config == null) return 0.0;

    final service = config["cash_back_service"];
    if (service is! Map) return 0.0;

    final enabled = service["enabled"];
    if (enabled != 1) return 0.0;

    final tiers = service["tiers"];
    if (tiers is! List) return 0.0;

    for (final t in tiers) {
      if (t is! Map) continue;

      final from = (t["from"] as num?)?.toDouble();
      final to = (t["to"] as num?)?.toDouble();
      final fee = (t["fee"] as num?)?.toDouble();

      if (from == null || to == null || fee == null) continue;

      if (cashbackAmount >= from && cashbackAmount <= to) {
        print("💰 CashbackAmount $cashbackAmount → Fee = $fee");
        return fee;
      }
    }

    return 0.0;
  }
}