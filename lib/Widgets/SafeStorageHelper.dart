import 'package:shared_preferences/shared_preferences.dart';

class SafeStorageHelper {
  static const String _safeEnableKey = "safe_enable";

  static Future<void> saveSafeEnable(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_safeEnableKey, value);
  }

  static Future<bool> getSafeEnable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_safeEnableKey) ?? false;
  }
}
