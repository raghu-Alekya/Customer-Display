import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../Constants/text.dart';
import '../Models/Auth/store_validation_model.dart';
import 'db_helper.dart';

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

    Map<String, dynamic> validationMap = {
      AppDBConst.storeId: response.storeId,
      AppDBConst.storeUserId: response.userId,
      AppDBConst.username: response.username,
      AppDBConst.email: response.email,
      AppDBConst.subscriptionType: response.subscriptionType,
      AppDBConst.storeName: response.storeName,
      AppDBConst.expirationDate: response.expirationDate,
      AppDBConst.storeBaseUrl: response.storeBaseUrl,
      AppDBConst.storeAddress: response.storeAddress,
      AppDBConst.storePhone: response.storePhone,
      AppDBConst.storeInfo: response.storeInfo,
      AppDBConst.licenseKey: response.licenseKey,
      AppDBConst.licenseStatus: response.licenseStatus,
    };

    await db.insert(
      AppDBConst.storeValidationTable,
      validationMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

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

  /// Checks if store validation is valid
  Future<bool> isStoreValidationValid() async {
    try {
      final validationData = await getStoreValidationData();
      if (validationData == null) {
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

  /// Clears store validation data during logout
  Future<void> logout() async {
    final db = await DBHelper.instance.database;
    await db.delete(AppDBConst.storeValidationTable);
    if (kDebugMode) {
      print("#### Store validation data cleared during logout");
    }
  }
}