
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
}
