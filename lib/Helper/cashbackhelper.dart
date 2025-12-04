import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Helper/url_helper.dart';

class CashbackHelper {

  // ---------------------------------------------------------
  // SAFE READ from Hive (ALWAYS returns Map<String, dynamic>)
  // ---------------------------------------------------------
  static Map<String, dynamic>? getCashbackConfig() {
    final box = Hive.box('cashbackConfig');
    final raw = box.get("config");

    if (raw == null) return null;

    try {
      // Normal case
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      // Fallback → deep convert
      try {
        final converted = deepConvert(raw);
        return Map<String, dynamic>.from(converted);
      } catch (_) {
        print("❌ CashbackHelper: Failed to convert Hive config");
        return null;
      }
    }
  }

  // ---------------------------------------------------------
  // RECURSIVE CONVERTER (solves _Map<dynamic,dynamic>)
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
  // FETCH API → SAVE CLEAN JSON INTO HIVE
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchCashbackConfig() async {
    final userBox = Hive.box('user');
    final token = userBox.get('token');

    if (token == null || token.isEmpty) {
      print("❌ No token found");
      return getCashbackConfig();
    }

    final box = Hive.box('cashbackConfig');
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
      return getCashbackConfig();
    }
  }


  // ---------------------------------------------------------
  // STARTUP LOADER
  // ---------------------------------------------------------
  static Future<void> loadCashbackOnStartup() async {
    // ⭐ Always read the fresh token from Hive
    final userBox = Hive.box('user');
    final token = userBox.get('token');

    if (token == null || token.isEmpty) {
      print("❌ No valid token found — skipping cashback API");
      return;
    }

    print("🔐 Using token for Cashback Startup → $token");

    final box = Hive.box('cashbackConfig');
    final lastFetch = box.get("lastFetchTime");
    final cached = box.get("config");
    final now = DateTime.now();

    print("🕒 Cashback lastFetch = $lastFetch");
    print("📦 Cached config = $cached");

    // --------------------------
    // 1️⃣ No cached config → Fetch new
    // --------------------------
    if (cached == null) {
      print("🟡 No Cashback config found → fetching new...");
      await fetchCashbackConfig(); // ⭐ token auto-loaded inside
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    // --------------------------
    // 2️⃣ Refresh if > 24 hours old
    // --------------------------
    if (lastFetch == null ||
        now.difference(DateTime.parse(lastFetch)).inSeconds  >= 2) {
      print("🔄 2 seconds passed → refreshing cashback config...");
      await fetchCashbackConfig(); // ⭐ token auto-loaded inside
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    // --------------------------
    // 3️⃣ Use existing cache
    // --------------------------
    print("🟩 Using cached cashback config");
  }

  // ---------------------------------------------------------
  // FINAL FEE CALCULATOR (NO CRASH POSSIBLE)
  // ---------------------------------------------------------
  static double getCashbackFee(double cashbackAmount) {
    final config = getCashbackConfig();

    if (config == null) {
      print("⚠ No cashback config");
      return 0.0;
    }

    if (!config.containsKey("cash_back_service")) return 0.0;

    final service = Map<String, dynamic>.from(config["cash_back_service"]);

    if (service["enabled"] != 1) return 0.0;

    final tiers = service["tiers"];
    if (tiers is! List) return 0.0;

    for (final t in tiers) {
      final tier = Map<String, dynamic>.from(t);

      final double from = (tier["from"] as num).toDouble();
      final double to = (tier["to"] as num).toDouble();
      final double fee = (tier["fee"] as num).toDouble();

      if (cashbackAmount >= from && cashbackAmount <= to) {
        print("💰 CashbackAmount $cashbackAmount → Fee = $fee");
        return fee;
      }
    }

    print("⚠ CashbackAmount $cashbackAmount out of tier range");
    return 0.0;
  }
}