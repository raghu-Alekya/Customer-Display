
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:pinaka_pos/Helper/url_helper.dart';
import 'package:pinaka_pos/Repositories/Auth/AuthIdsStore.dart';

class CashbackHelper {
  // ---------------------------------------------------------
  // SAFE READ FROM STORAGE
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> getCashbackConfig() async {
    final box = StorageProvider.cashbackConfig;
    final raw = await box.get('config');

    if (raw == null) return null;

    try {
      return Map<String, dynamic>.from(raw is Map ? raw : {});
    } catch (_) {
      try {
        final converted = deepConvert(raw);
        return Map<String, dynamic>.from(converted as Map);
      } catch (e) {
        if (kDebugMode) {
          print('CashbackHelper: Failed to convert config: $e');
        }
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
  // RESOLVE TOKEN FROM HIVE USER STORAGE
  // Avoids calling the undefined getUserToken() method.
  // ---------------------------------------------------------
  /// Public alias used by DenominationHelper / other helpers.
  static Future<String?> resolveToken() => _resolveToken();

  static Future<String?> _resolveToken() async {
    try {
      final userBox = StorageProvider.user;
      final tokenRaw = await userBox.get('token');

      if (tokenRaw is String) {
        final token = tokenRaw.trim();

        if (token.isNotEmpty) {
          if (kDebugMode) {
            print('Cashback: Token loaded from user storage');
          }
          return token;
        }
      }

      if (tokenRaw is Map && tokenRaw['token'] != null) {
        final token = tokenRaw['token'].toString().trim();

        if (token.isNotEmpty) {
          if (kDebugMode) {
            print('Cashback: Token loaded from user map');
          }
          return token;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cashback: User storage token lookup failed: $e');
      }
    }

    if (kDebugMode) {
      print('Cashback: No valid token found');
    }

    return null;
  }

  // ---------------------------------------------------------
  // RESOLVE STORE ID
  // ---------------------------------------------------------
  /// Public alias used by DenominationHelper / other helpers.
  static Future<String?> resolveStoreId() => _resolveStoreId();

  static Future<String?> _resolveStoreId() async {
    try {
      final id = (await AuthIdsStore.getStoreId()).trim();

      if (id.isNotEmpty) {
        if (kDebugMode) {
          print('Cashback: Store ID resolved successfully');
        }
        return id;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cashback: Store ID lookup failed: $e');
      }
    }

    return null;
  }

  // ---------------------------------------------------------
  // FETCH CASHBACK CONFIGURATION
  //
  // GET:
  // {baseUrl}/store/store-pos-configuration/{storeId}/cashback_settings
  //
  // Expected response:
  // {
  //   "cash_back_service": {
  //     "enabled": true,
  //     "max_cashback": 100,
  //     "tiers": []
  //   }
  // }
  // ---------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchCashbackConfig() async {
    final token = await _resolveToken();

    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        print('Cashback: No token found; using cached configuration');
      }
      return getCashbackConfig();
    }

    final storeId = await _resolveStoreId();

    if (storeId == null || storeId.isEmpty) {
      if (kDebugMode) {
        print('Cashback: No store ID found; using cached configuration');
      }
      return getCashbackConfig();
    }

    final box = StorageProvider.cashbackConfig;

    final url =
        '${UrlHelper.baseUrl}/store/store-pos-configuration/'
        '$storeId/cashback_settings';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Cashback API status: ${response.statusCode}');
        print('Cashback API URL: $url');
      }

      if (response.statusCode == 200) {
        final decoded = deepConvert(jsonDecode(response.body));

        if (decoded is! Map) {
          if (kDebugMode) {
            print('Cashback: API response is not a JSON object');
          }
          return getCashbackConfig();
        }

        final safeJson = Map<String, dynamic>.from(decoded);

        await box.put('config', safeJson);

        final service = safeJson['cash_back_service'];

        if (kDebugMode && service is Map) {
          final tiers = service['tiers'];

          print(
            'Cashback config saved: '
                'enabled=${service['enabled']}, '
                'max=${service['max_cashback']}, '
                'tiers=${tiers is List ? tiers.length : 0}',
          );
        }

        return safeJson;
      }

      if (kDebugMode) {
        print('Cashback: API request failed; using cached configuration');
      }

      return getCashbackConfig();
    } catch (e) {
      if (kDebugMode) {
        print('Cashback API error: $e');
      }

      return getCashbackConfig();
    }
  }

  // ---------------------------------------------------------
  // STARTUP LOADER
  // ---------------------------------------------------------
  static Future<void> loadCashbackOnStartup() async {
    final token = await _resolveToken();

    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        print('Cashback: No valid token; skipping startup fetch');
      }
      return;
    }

    final storeId = await _resolveStoreId();

    if (storeId == null || storeId.isEmpty) {
      if (kDebugMode) {
        print('Cashback: No store ID; skipping startup fetch');
      }
      return;
    }

    final box = StorageProvider.cashbackConfig;

    final lastFetchRaw = await box.get('lastFetchTime');
    final cached = await box.get('config');
    final now = DateTime.now();

    DateTime? lastFetchTime;

    if (lastFetchRaw is String) {
      lastFetchTime = DateTime.tryParse(lastFetchRaw);
    } else if (lastFetchRaw is Map &&
        lastFetchRaw['time'] != null) {
      lastFetchTime =
          DateTime.tryParse(lastFetchRaw['time'].toString());
    }

    if (cached == null) {
      if (kDebugMode) {
        print('Cashback: No cached config; fetching configuration');
      }

      await fetchCashbackConfig();
      await box.put('lastFetchTime', now.toIso8601String());
      return;
    }

    // Refresh cached configuration every 2 seconds, matching
    // the original implementation.
    if (lastFetchTime == null ||
        now.difference(lastFetchTime).inSeconds >= 2) {
      if (kDebugMode) {
        print('Cashback: Refreshing configuration');
      }

      await fetchCashbackConfig();
      await box.put('lastFetchTime', now.toIso8601String());
      return;
    }

    if (kDebugMode) {
      print('Cashback: Using cached configuration');
    }
  }

  // ---------------------------------------------------------
  // CASHBACK FEE CALCULATOR
  // ---------------------------------------------------------
  static Future<double> getCashbackFee(double cashbackAmount) async {
    final config = await getCashbackConfig();

    if (config == null) return 0.0;

    final service = config['cash_back_service'];

    if (service is! Map) return 0.0;

    final enabled = service['enabled'];

    final bool isEnabled = enabled == 1 ||
        enabled == true ||
        enabled?.toString() == '1';

    if (!isEnabled) {
      if (kDebugMode) {
        print('Cashback fee skipped: service is disabled');
      }
      return 0.0;
    }

    final tiers = service['tiers'];

    if (tiers is! List) return 0.0;

    for (final tier in tiers) {
      if (tier is! Map) continue;

      final from = double.tryParse(
        tier['from']?.toString() ?? '',
      );

      final to = double.tryParse(
        tier['to']?.toString() ?? '',
      );

      final fee = double.tryParse(
        tier['fee']?.toString() ?? '',
      );

      if (from == null || to == null || fee == null) {
        continue;
      }

      if (cashbackAmount >= from && cashbackAmount <= to) {
        if (kDebugMode) {
          print('Cashback amount $cashbackAmount => fee $fee');
        }
        return fee;
      }
    }

    if (kDebugMode) {
      print('Cashback: No matching fee tier found');
    }

    return 0.0;
  }
}