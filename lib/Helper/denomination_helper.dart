import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:pinaka_pos/Helper/cashbackhelper.dart';
import 'package:pinaka_pos/Helper/url_helper.dart';
import 'package:pinaka_pos/Models/Assets/asset_model.dart';

/// Loads cash denominations (notes, coins, safe drop, tubes) from the store
/// bootstrap API and caches them in the asset denomination tables, which the
/// shift balance, safe open and safe drop screens read from.
class DenominationHelper {
  // Accepted key names for each list; first match anywhere in the response wins.
  static const List<String> _notesKeys = [
    'notes_denom', 'notesDenom', 'notes_denominations', 'note_denominations', 'notes',
  ];
  static const List<String> _coinKeys = [
    'coin_denom', 'coins_denom', 'coinDenom', 'coin_denominations', 'coins_denominations', 'coins',
  ];
  static const List<String> _safeKeys = [
    'safe_denom', 'safeDenom', 'safe_denominations', 'safe_drop_denominations', 'safe_drop_denom',
  ];
  static const List<String> _tubesKeys = [
    'tubes_denom', 'tube_denom', 'tubesDenom', 'tube_denominations', 'tubes_denominations',
  ];

  static Future<void>? _inFlight;

  /// Fetch bootstrap and refresh the denomination tables. Concurrent callers
  /// share one request. Failures leave the existing cache untouched.
  static Future<void> syncFromBootstrap() {
    return _inFlight ??= _sync().whenComplete(() => _inFlight = null);
  }

  static Future<void> _sync() async {
    final token = await CashbackHelper.resolveToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) print("❌ Denominations: no token, using cached denominations");
      return;
    }
    final storeId = await CashbackHelper.resolveStoreId();
    if (storeId == null || storeId.isEmpty) {
      if (kDebugMode) print("❌ Denominations: no storeId, using cached denominations");
      return;
    }

    final url = "${UrlHelper.safeApiBaseUrl}/${UrlMethodConstants.cashbackservices}"
        "/$storeId/${UrlMethodConstants.posConfigurationBootstrap}";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print("🌐 Bootstrap API Status → ${response.statusCode}");
        print("🌐 Bootstrap API URL    → $url");
        print("🌐 Bootstrap API Body   → ${response.body}");
      }

      if (response.statusCode != 200) {
        if (kDebugMode) print("❌ Denominations: bootstrap non-200, using cached denominations");
        return;
      }

      final decoded = CashbackHelper.deepConvert(jsonDecode(response.body));
      final notes = _parseList(_findList(decoded, _notesKeys));
      final coins = _parseList(_findList(decoded, _coinKeys));
      final safe = _parseList(_findList(decoded, _safeKeys));
      final tubes = _parseList(_findList(decoded, _tubesKeys));

      if (notes == null && coins == null && safe == null && tubes == null) {
        if (kDebugMode) print("⚠️ Denominations: no denomination lists found in bootstrap response");
        return;
      }

      await AssetDBHelper.instance.saveDenominations(
        notes: notes,
        coins: coins,
        safe: safe,
        tubes: tubes,
      );
    } catch (e) {
      if (kDebugMode) print("❌ Denominations: bootstrap error: $e");
    }
  }

  // Depth-first search for the first key in [keys] whose value is a List.
  static List? _findList(dynamic node, List<String> keys) {
    if (node is Map) {
      for (final key in keys) {
        final value = node[key];
        if (value is List) return value;
      }
      for (final value in node.values) {
        final found = _findList(value, keys);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findList(value, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  // Items may be bare values (100, "0.25") or objects ({denom, image, tube_limit, symbol}).
  static List<Denom>? _parseList(List? raw) {
    if (raw == null) return null;
    final result = <Denom>[];
    for (final item in raw) {
      if (item is Map) {
        final value = item['denom'] ?? item['value'] ?? item['denomination'] ?? item['amount'];
        final denom = _normalize(value);
        if (denom == null) continue;
        result.add(Denom(
          denom: denom,
          image: (item['image'] ?? item['image_url'] ?? item['icon'])?.toString(),
          tubeLimit: int.tryParse((item['tube_limit'] ?? item['tubeLimit'])?.toString() ?? ''),
          symbol: (item['symbol'] ?? item['currency_symbol'])?.toString(),
        ));
      } else {
        final denom = _normalize(item);
        if (denom != null) result.add(Denom(denom: denom));
      }
    }
    return result;
  }

  // "100.00" / 100 -> "100" (screens int.parse whole-number notes);
  // fractional values keep the API text, e.g. "0.10".
  static String? _normalize(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) return null;
    if (parsed == parsed.truncateToDouble()) return parsed.toInt().toString();
    return text;
  }
}
