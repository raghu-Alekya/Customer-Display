
import 'package:shared_preferences/shared_preferences.dart';

class AuthIdsStore {
  static const String _kMerchantId = 'auth_merchant_uuid';
  static const String _kStoreId = 'auth_store_uuid';

  static Future<void> save({
    required String merchantId,
    required String storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMerchantId, merchantId);
    await prefs.setString(_kStoreId, storeId);
  }

  static Future<String> getMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMerchantId) ?? '';
  }

  static Future<String> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStoreId) ?? '';
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMerchantId);
    await prefs.remove(_kStoreId);
  }
}