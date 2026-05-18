import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static Future<void> saveData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));

    print("💾 Cache saved for key: $key");
  }

  static Future<dynamic> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);

    print("🔍 Checking cache for key: $key");
    print("📦 Cached data exists: ${data != null}");

    if (data != null) {
      return jsonDecode(data);
    }

    return null;
  }
  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}