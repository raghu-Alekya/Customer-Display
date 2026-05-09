import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/addon_model.dart';

class AddonRepository {
  Future<List<AddonModel>> getAddons({
    required int productId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "addons_$productId";

    /// 1. CHECK CACHE FIRST
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      print("✅ Loading addons from cache");

      final List decodedCache = json.decode(cachedData);

      return decodedCache
          .map((e) => AddonModel.fromJson(e))
          .toList();
    }

    /// 2. API CALL IF CACHE EMPTY
    final url = Uri.parse(
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/modifiers-addons/get-modifiers-by-product-id?product_id=$productId',
    );

    print("👉 API URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    final decoded = json.decode(response.body);

    if (response.statusCode == 200 &&
        decoded['status'] == "success") {
      final List data = decoded['data'];

      /// 3. SAVE TO CACHE
      await prefs.setString(
        cacheKey,
        json.encode(data),
      );

      print("✅ Addons cached for product $productId");

      return data
          .map((e) => AddonModel.fromJson(e))
          .toList();
    } else {
      throw Exception("Failed to load addons");
    }
  }

  /// OPTIONAL: CLEAR SPECIFIC PRODUCT CACHE
  Future<void> clearAddonCache(int productId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("addons_$productId");
  }

  /// OPTIONAL: CLEAR ALL ADDON CACHE
  Future<void> clearAllAddonCache() async {
    final prefs = await SharedPreferences.getInstance();

    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith("addons_"))
        .toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}