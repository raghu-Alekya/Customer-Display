import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../Constants/text.dart';
import '../Models/Auth/store_validation_model.dart';
<<<<<<< HEAD
import 'db_helper.dart';
=======
import '../Preferences/pinaka_preferences.dart';
import 'db_helper.dart';
import '../Repositories/Auth/AuthIdsStore.dart';
>>>>>>> origin/Grocery_pch_api_integration

class StoreDbHelper { //Build #1.0.126: Updated code - store validation data management
  static final StoreDbHelper instance = StoreDbHelper._internal();
  factory StoreDbHelper() => instance;

  StoreDbHelper._internal() {
    if (kDebugMode) {
      print("#### StoreDbHelper initialized!");
    }
  }

  /// Saves store validation data
  Future<void> saveStoreValidationData(StoreValidationResponse response) async {
    final db = await DBHelper.instance.database;

<<<<<<< HEAD
=======
    // New connector API may omit license fields; default so re-open checks pass.
    final licenseStatus = response.licenseStatus.trim().isNotEmpty
        ? response.licenseStatus.trim()
        : 'active';
    final expirationDate = response.expirationDate.trim().isNotEmpty
        ? response.expirationDate.trim()
        : DateTime.now().add(const Duration(days: 3650)).toIso8601String();

>>>>>>> origin/Grocery_pch_api_integration
    Map<String, dynamic> validationMap = {
      AppDBConst.storeId: response.storeId,
      AppDBConst.storeUserId: response.userId,
      AppDBConst.username: response.username,
      AppDBConst.email: response.email,
      AppDBConst.subscriptionType: response.subscriptionType,
      AppDBConst.storeName: response.storeName,
<<<<<<< HEAD
      AppDBConst.expirationDate: response.expirationDate,
=======
      AppDBConst.expirationDate: expirationDate,
>>>>>>> origin/Grocery_pch_api_integration
      AppDBConst.storeBaseUrl: response.storeBaseUrl,
      AppDBConst.storeAddress: response.storeAddress,
      AppDBConst.storePhone: response.storePhone,
      AppDBConst.storeInfo: response.storeInfo,
      AppDBConst.licenseKey: response.licenseKey,
<<<<<<< HEAD
      AppDBConst.licenseStatus: response.licenseStatus,
=======
      AppDBConst.licenseStatus: licenseStatus,
      // Build #offline: terminal identity fields
      AppDBConst.deviceDisplayName: response.deviceDisplayName,
      AppDBConst.deviceTableId: response.deviceTableId,
      AppDBConst.storeLogo: response.storeLogo,
      AppDBConst.storeGstin: response.storeGstin,
>>>>>>> origin/Grocery_pch_api_integration
    };

    await db.insert(
      AppDBConst.storeValidationTable,
      validationMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

<<<<<<< HEAD
=======
    try {
      await PinakaPreferences.saveLoggedInStore(
        storeId: response.storeId,
        storeName: response.storeName,
        storeLogoUrl: response.storeLogo,
        storeBaseUrl: response.storeBaseUrl,
      );
    } catch (_) {}

>>>>>>> origin/Grocery_pch_api_integration
    if (kDebugMode) {
      print("#### Store validation data saved: $validationMap");
    }
  }

  /// Retrieves store validation data
  Future<Map<String, dynamic>?> getStoreValidationData() async {
    final db = await DBHelper.instance.database;
    List<Map<String, dynamic>> result = await db.query(
      AppDBConst.storeValidationTable,
      orderBy: "${AppDBConst.storeValidationId} DESC",
      limit: 1,
    );

    if (result.isNotEmpty) {
      if (kDebugMode) print("#### Retrieved store validation data: ${result.first}");
      return result.first;
    }
    if (kDebugMode) print("#### No store validation data found");
    return null;
  }

<<<<<<< HEAD
  /// Checks if store validation is valid
=======
  /// Checks if store validation is valid.
  ///
  /// Once merchant/store login succeeds we persist the row in
  /// storeValidationTable. On subsequent app opens we should skip the
  /// merchant/store login screen and go straight to the employee PIN screen,
  /// as long as a storeId is present.
  ///
  /// The new connector merchant-store-login API often omits
  /// expiration_date / license_status. In that case we treat a saved
  /// storeId as sufficient proof of a prior successful store login. When
  /// those legacy fields are present we still enforce active license +
  /// non-expired date.
>>>>>>> origin/Grocery_pch_api_integration
  Future<bool> isStoreValidationValid() async {
    try {
      final validationData = await getStoreValidationData();
      if (validationData == null) {
<<<<<<< HEAD
        if (kDebugMode) print("#### No validation data found, store validation invalid");
        return false;
      }

      final expirationDateStr = validationData[AppDBConst.expirationDate];
      final licenseStatus = validationData[AppDBConst.licenseStatus];

      if (expirationDateStr == null || licenseStatus != 'Active') {
        if (kDebugMode) print("#### Invalid expiration date or license status");
        return false;
      }

      final expirationDate = DateTime.parse(expirationDateStr);
      final now = DateTime.now();
      final isValid = expirationDate.isAfter(now);

      if (kDebugMode) print("#### Store validation status: $isValid, expires: $expirationDateStr");
      return isValid;
=======
        if (kDebugMode) {
          print("#### No validation data found, store validation invalid");
        }
        return false;
      }

      final storeId =
          validationData[AppDBConst.storeId]?.toString().trim() ?? '';
      if (storeId.isEmpty) {
        if (kDebugMode) {
          print("#### Store validation row exists but storeId is empty");
        }
        return false;
      }

      final expirationDateStr =
      validationData[AppDBConst.expirationDate]?.toString().trim();
      final licenseStatus = validationData[AppDBConst.licenseStatus]
          ?.toString()
          .trim()
          .toLowerCase();

      // New API path: no license/expiration fields → treat saved store as valid.
      final hasLicenseInfo = (expirationDateStr != null &&
          expirationDateStr.isNotEmpty) ||
          (licenseStatus != null && licenseStatus.isNotEmpty);

      if (!hasLicenseInfo) {
        if (kDebugMode) {
          print(
              "#### Store validation valid (storeId=$storeId, no license fields from API)");
        }
        return true;
      }

      // Legacy path: enforce active license + future expiration when present.
      if (licenseStatus != null &&
          licenseStatus.isNotEmpty &&
          licenseStatus != 'active') {
        if (kDebugMode) {
          print("#### License status is not active: $licenseStatus");
        }
        return false;
      }

      if (expirationDateStr != null && expirationDateStr.isNotEmpty) {
        final expirationDate = DateTime.tryParse(expirationDateStr);
        if (expirationDate == null) {
          if (kDebugMode) {
            print("#### Invalid store expiration date: $expirationDateStr");
          }
          // Don't fail purely on unparseable date if storeId is present.
          return true;
        }
        final isValid = expirationDate.isAfter(DateTime.now());
        if (kDebugMode) {
          print(
              "#### Store validation status: $isValid, expires: $expirationDateStr");
        }
        return isValid;
      }

      if (kDebugMode) {
        print("#### Store validation valid (storeId=$storeId)");
      }
      return true;
>>>>>>> origin/Grocery_pch_api_integration
    } catch (e) {
      if (kDebugMode) print("#### Error checking store validation status: $e");
      return false;
    }
  }

  /// Retrieves store base URL
  Future<String?> getStoreBaseUrl() async {
    final validationData = await getStoreValidationData();
    final baseUrl = validationData?[AppDBConst.storeBaseUrl];
    if (kDebugMode) print("#### Retrieved store base URL: $baseUrl");
    return baseUrl;
  }

<<<<<<< HEAD
  /// Clears store validation data during logout
  Future<void> logout() async {
    final db = await DBHelper.instance.database;
    await db.delete(AppDBConst.storeValidationTable);
    if (kDebugMode) {
      print("#### Store validation data cleared during logout");
    }
  }
=======
  // Build #offline: get terminal display name
  Future<String?> getDeviceDisplayName() async {
    final data = await getStoreValidationData();
    return data?[AppDBConst.deviceDisplayName] as String?;
  }

  // Build #offline: get terminal / table id
  Future<String?> getDeviceTableId() async {
    final data = await getStoreValidationData();
    return data?[AppDBConst.deviceTableId] as String?;
  }

  /// Clears store validation data during logout / app reset.
  /// Also clears AuthIdsStore so splash shows merchant login again.
  Future<void> logout() async {
    final db = await DBHelper.instance.database;
    await db.delete(AppDBConst.storeValidationTable);
    try {
      await AuthIdsStore.clear();
    } catch (_) {}
    try {
      await PinakaPreferences.clearLoggedInStore();
    } catch (_) {}
    if (kDebugMode) {
      print("#### Store validation + AuthIdsStore cleared");
    }
  }

>>>>>>> origin/Grocery_pch_api_integration
}