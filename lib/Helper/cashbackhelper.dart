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
  static Future<Map<String, dynamic>?> fetchCashbackConfig(String token) async {
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
        final decoded = jsonDecode(response.body);

        // convert entire JSON to Map<String,dynamic>
        final safeJson = deepConvert(decoded);

        await box.put("config", safeJson);

        print("🟩 Saved cashback config into Hive");
        return Map<String, dynamic>.from(safeJson);
      }

      print("❌ API error: ${response.statusCode}");
      return getCashbackConfig();

    } catch (e) {
      print("⚠ Offline → using cached config");
      return getCashbackConfig();
    }
  }

  // ---------------------------------------------------------
  // STARTUP LOADER
  // ---------------------------------------------------------
  static Future<void> loadCashbackOnStartup(String token) async {
    final box = Hive.box('cashbackConfig');
    final lastFetch = box.get("lastFetchTime");
    final cached = box.get("config");
    final now = DateTime.now();

    print("🕒 Cashback lastFetch = $lastFetch");
    print("📦 Cached config = $cached");

    if (cached == null) {
      print("🟡 No config → fetching new");
      await fetchCashbackConfig(token);
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    if (lastFetch == null ||
        now.difference(DateTime.parse(lastFetch)).inHours >= 24) {
      print("🔄 Refreshing cashback config");
      await fetchCashbackConfig(token);
      await box.put("lastFetchTime", now.toIso8601String());
      return;
    }

    print("🟩 Using fresh cached cashback config");
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