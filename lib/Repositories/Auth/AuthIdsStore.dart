
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists merchant/store IDs and a **build session marker**.
///
/// - SharedPreferences holds merchantId/storeId for API headers.
/// - A marker file next to the app executable is written after successful
///   merchant login. `flutter clean` deletes `build/`, so that marker is gone
///   and the next run shows merchant login again (as requested).
/// - Normal app reopen (without clean) keeps the marker → employee PIN.
class AuthIdsStore {
  static const String _kMerchantId = 'auth_merchant_uuid';
  static const String _kStoreId = 'auth_store_uuid';
  static const String _kEmployeeId = 'auth_employee_uuid';
  static const String _markerFileName = '.pch_merchant_login_ok';

  static Future<void> save({
    required String merchantId,
    required String storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMerchantId, merchantId);
    await prefs.setString(_kStoreId, storeId);
    await _writeBuildMarker();
    if (kDebugMode) {
      print('[AuthIdsStore] saved merchant=$merchantId store=$storeId + build marker');
    }
  }

  static Future<String> getMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMerchantId) ?? '';
  }

  static Future<String> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStoreId) ?? '';
  }

  /// Employee UUID from the PIN login response. The SQLite user table only
  /// keeps a numeric id, so the raw UUID is kept here for employee APIs.
  static Future<void> saveEmployeeId(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmployeeId, employeeId);
  }

  static Future<String> getEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmployeeId) ?? '';
  }

  /// True only when prefs have both IDs **and** this build still has the marker.
  /// After `flutter clean`, marker is missing → returns false → merchant login.
  static Future<bool> isMerchantLoginDone() async {
    final prefs = await SharedPreferences.getInstance();
    final merchantId = (prefs.getString(_kMerchantId) ?? '').trim();
    final storeId = (prefs.getString(_kStoreId) ?? '').trim();
    if (merchantId.isEmpty || storeId.isEmpty) {
      return false;
    }
    final hasMarker = await _hasBuildMarker();
    if (!hasMarker) {
      // flutter clean (or new build folder) — force merchant login again
      if (kDebugMode) {
        print('[AuthIdsStore] prefs exist but build marker missing → merchant login');
      }
      return false;
    }
    return true;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMerchantId);
    await prefs.remove(_kStoreId);
    await _deleteBuildMarker();
  }

  // ── Build marker (lives under build/…/runner/Debug on Windows) ───────────

  static String _markerPath() {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(exeDir, _markerFileName);
    } catch (_) {
      return p.join(Directory.current.path, _markerFileName);
    }
  }

  static Future<void> _writeBuildMarker() async {
    try {
      final file = File(_markerPath());
      await file.writeAsString(
        'merchant_login_ok\n${DateTime.now().toIso8601String()}\n',
        flush: true,
      );
      if (kDebugMode) {
        print('[AuthIdsStore] build marker written: ${file.path}');
      }
    } catch (e) {
      if (kDebugMode) print('[AuthIdsStore] write marker failed: $e');
    }
  }

  static Future<bool> _hasBuildMarker() async {
    try {
      return await File(_markerPath()).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteBuildMarker() async {
    try {
      final file = File(_markerPath());
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Device Activation ──────────────────────────────────────────
  static const String _kDeviceActivated = 'device_is_activated';
  static const String _kDeviceActivationCode = 'device_activation_code';
  static const String _kDeviceSerialNumber = 'device_serial_number';
  static const String _kDeviceId = 'device_id';
  static const String _kDeviceCode = 'device_code';
  static const String _kDeviceName = 'device_name';
  static const String _kDeviceAccessToken = 'device_access_token';
  static const String _kDeviceRegisterId = 'device_register_id';
  static const String _kDeviceMerchantCode = 'device_merchant_code';
  static const String _kDeviceStoreCode = 'device_store_code';
  static const String _kDeviceStoreName = 'device_store_name';

  static Future<bool> isDeviceActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDeviceActivated) ?? false;
  }

  static Future<void> saveDeviceActivation({
    required String activationCode,
    required String serialNumber,
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeviceActivated, true);
    await prefs.setString(_kDeviceActivationCode, activationCode.trim());
    await prefs.setString(_kDeviceSerialNumber, serialNumber.trim());

    if (data != null) {
      final deviceId = (data['deviceId'] ?? data['device_id'] ?? '').toString();
      final deviceCode = (data['deviceCode'] ?? data['device_code'] ?? '').toString();
      final deviceName = (data['deviceName'] ?? data['device_name'] ?? '').toString();
      final registerId = (data['registerId'] ?? '').toString();
      final token = (data['deviceAccessToken'] ?? data['accessToken'] ?? data['token'] ?? '').toString();

      if (deviceId.isNotEmpty) await prefs.setString(_kDeviceId, deviceId);
      if (deviceCode.isNotEmpty) await prefs.setString(_kDeviceCode, deviceCode);
      if (deviceName.isNotEmpty) await prefs.setString(_kDeviceName, deviceName);
      if (registerId.isNotEmpty) await prefs.setString(_kDeviceRegisterId, registerId);
      if (token.isNotEmpty) await prefs.setString(_kDeviceAccessToken, token);

      if (data['merchant'] is Map) {
        final m = data['merchant'] as Map;
        final mId = (m['id'] ?? '').toString();
        final mCode = (m['merchantCode'] ?? '').toString();
        if (mId.isNotEmpty) await prefs.setString(_kMerchantId, mId);
        if (mCode.isNotEmpty) await prefs.setString(_kDeviceMerchantCode, mCode);
      }

      if (data['store'] is Map) {
        final s = data['store'] as Map;
        final sId = (s['id'] ?? '').toString();
        final sCode = (s['storeCode'] ?? '').toString();
        final sName = (s['storeName'] ?? '').toString();
        if (sId.isNotEmpty) await prefs.setString(_kStoreId, sId);
        if (sCode.isNotEmpty) {
          await prefs.setString(_kDeviceStoreCode, sCode);
          await prefs.setString('storeId', sCode);
        }
        if (sName.isNotEmpty) {
          await prefs.setString(_kDeviceStoreName, sName);
          await prefs.setString('storeName', sName);
        }
      }
    }
  }

  static Future<String> getDeviceSerialNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceSerialNumber) ?? '';
  }

  static Future<String> getDeviceActivationCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceActivationCode) ?? '';
  }

  static Future<String> getDeviceAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceAccessToken) ?? '';
  }
}
