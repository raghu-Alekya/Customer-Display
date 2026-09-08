import 'package:shared_preferences/shared_preferences.dart';

import 'models/pos_context.dart';

abstract class PosContextProvider {
  Future<PosContext?> getContext();
  Future<void> saveContext(PosContext context);
  Future<void> updateUserId(String? userId);
  Future<void> clearUserSession();
  Future<void> clearAll();
}

class PosContextProviderImpl implements PosContextProvider {
  static const _kMerchantId = 'pch_merchant_id';
  static const _kStoreId = 'pch_store_id';
  static const _kDeviceId = 'pch_device_id';
  static const _kUserId = 'pch_user_id';

  @override
  Future<PosContext?> getContext() async {
    final prefs = await SharedPreferences.getInstance();
    final merchantId = prefs.getString(_kMerchantId);
    final storeId = prefs.getString(_kStoreId);
    final deviceId = prefs.getString(_kDeviceId);

    if (merchantId == null || storeId == null || deviceId == null) {
      return null;
    }

    return PosContext(
      merchantId: merchantId,
      storeId: storeId,
      deviceId: deviceId,
      userId: prefs.getString(_kUserId),
    );
  }

  @override
  Future<void> saveContext(PosContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMerchantId, context.merchantId);
    await prefs.setString(_kStoreId, context.storeId);
    await prefs.setString(_kDeviceId, context.deviceId);
    if (context.userId != null) {
      await prefs.setString(_kUserId, context.userId!);
    }
  }

  @override
  Future<void> updateUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_kUserId);
    } else {
      await prefs.setString(_kUserId, userId);
    }
  }

  @override
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMerchantId);
    await prefs.remove(_kStoreId);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kUserId);
  }
}
