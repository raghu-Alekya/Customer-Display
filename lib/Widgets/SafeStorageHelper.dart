import 'package:shared_preferences/shared_preferences.dart';

class SafeStorageHelper {
  static const String _safeEnableKey = "safe_enable";
  static const String _safeEnableDropKey = "safe_enable_drop";

  // 🔐 SAFE ENABLE
  static Future<void> saveSafeEnable(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_safeEnableKey, value);
  }

  static Future<bool> getSafeEnable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_safeEnableKey) ?? false;
  }

  // 🔽 SAFE ENABLE DROP
  static Future<void> saveSafeEnableDrop(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_safeEnableDropKey, value);
  }

  static Future<bool> getSafeEnableDrop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_safeEnableDropKey) ?? false;
  }

  // 🔄 RELOAD (Force sync with disk)
  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }
}
