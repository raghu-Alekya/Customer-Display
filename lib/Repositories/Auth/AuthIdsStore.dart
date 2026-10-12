
import 'package:shared_preferences/shared_preferences.dart';

class AuthIdsStore {
  static const String _kMerchantId = 'auth_merchant_uuid';
  static const String _kStoreId = 'auth_store_uuid';
  /// Explicit flag set only after a successful merchant/store login.
  /// Splash uses this so leftover/partial prefs cannot skip the merchant screen.
  static const String _kMerchantLoginDone = 'auth_merchant_store_login_done';

  static Future<void> save({
    required String merchantId,
    required String storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMerchantId, merchantId);
    await prefs.setString(_kStoreId, storeId);
    await prefs.setBool(_kMerchantLoginDone, true);
  }

  static Future<String> getMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMerchantId) ?? '';
  }

  static Future<String> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStoreId) ?? '';
  }

  /// True only after [save] from successful merchant/store login.
  static Future<bool> isMerchantLoginDone() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kMerchantLoginDone) ?? false;
    if (!done) return false;
    final merchantId = (prefs.getString(_kMerchantId) ?? '').trim();
    final storeId = (prefs.getString(_kStoreId) ?? '').trim();
    return merchantId.isNotEmpty && storeId.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMerchantId);
    await prefs.remove(_kStoreId);
    await prefs.remove(_kMerchantLoginDone);
  }
}
