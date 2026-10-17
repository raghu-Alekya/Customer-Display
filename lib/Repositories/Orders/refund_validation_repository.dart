import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../Auth/AuthIdsStore.dart';

class RefundValidationRepository {
  final String baseUrl;

  RefundValidationRepository({required this.baseUrl});

  Future<Map<String, dynamic>> validateEmployeePin({
    required String employeePin,
  }) async {
    if (kDebugMode) {
      print("========== REFUND VALIDATION START ==========");
      print("Employee PIN Entered: $employeePin");
    }

    final bool isOnline = await OfflineHelper.isNetworkAvailable();
    if (!isOnline) {
      if (kDebugMode) {
        print("⚡ Device is OFFLINE. Performing local PIN validation...");
      }

      String storedPin = "";
      try {
        const secureStorage = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );
        storedPin = await secureStorage.read(key: 'encrypted_login_pin') ?? "";
      } catch (_) {}

      if (storedPin.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          storedPin = prefs.getString('user_pin') ??
              prefs.getString('login_pin') ??
              prefs.getString('encrypted_login_pin') ??
              "";
        } catch (_) {}
      }

      final userData = await UserDbHelper().getUserData();
      final userPinInDb = userData?['pin']?.toString() ??
          userData?['user_pin']?.toString() ??
          userData?['login_pin']?.toString() ??
          "";

      bool isValid = false;
      if (employeePin.isNotEmpty) {
        if ((storedPin.isNotEmpty && storedPin == employeePin) ||
            (userPinInDb.isNotEmpty && userPinInDb == employeePin)) {
          isValid = true;
        } else {
          final matchedEmployee =
              await UserDbHelper().validateOfflinePin(employeePin);
          if (matchedEmployee != null) {
            isValid = true;
          }
        }
      }

      if (isValid) {
        if (kDebugMode) print("✅ Local OFFLINE PIN validated successfully");
        return {
          "success": true,
          "message": "User verified successfully (offline)",
        };
      } else {
        if (kDebugMode) print("❌ Local OFFLINE PIN validation failed");
        throw Exception("Invalid PIN or unauthorized user");
      }
    }

    final token = await _getTokenFromDb();
    final merchantId = (await AuthIdsStore.getMerchantId()).trim();
    final storeId = (await AuthIdsStore.getStoreId()).trim();

    // PCH API: POST {safeApiBaseUrl}/orders/refund-valid-user
    final uri = Uri.parse(
      '${UrlHelper.safeApiBaseUrl}/orders/refund-valid-user',
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (merchantId.isNotEmpty) 'x-merchant-id': merchantId,
      if (storeId.isNotEmpty) 'x-store-id': storeId,
    };
    final body = jsonEncode({'employee_pin': employeePin});

    if (kDebugMode) {
      print("API URL: $uri");
      print("x-merchant-id: $merchantId, x-store-id: $storeId");
    }

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print("========== REFUND VALIDATION RESPONSE ==========");
      print("Status Code: ${response.statusCode}");
      print("Raw Body: ${response.body}");
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print("❌ JSON Decode Failed: $e");
      }
      throw Exception("Invalid server response");
    }

    if (kDebugMode) {
      print("Decoded Response Type: ${decoded.runtimeType}");
      print("Decoded Response: $decoded");
    }

    // ❌ HTTP failure
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        print("❌ HTTP ERROR: ${response.statusCode}");
      }
      throw Exception(
        decoded is Map && decoded['message'] != null
            ? decoded['message']
            : "Unauthorized or session expired",
      );
    }

    // ✅ Success object
    if (decoded is Map && decoded['success'] == true) {
      if (kDebugMode) {
        print("✅ PIN VALIDATED SUCCESSFULLY");
      }
      return Map<String, dynamic>.from(decoded);
    }

    // ✅ Empty array = success (backend inconsistency)
    if (decoded is List && decoded.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Empty array returned, treating as SUCCESS");
      }
      return {
        "success": true,
        "message": "User verified successfully",
      };
    }

    // ❌ Real failure
    if (kDebugMode) {
      print("❌ PIN VALIDATION FAILED");
    }

    throw Exception(
      decoded is Map && decoded['message'] != null
          ? decoded['message']
          : "Invalid PIN or unauthorized user",
    );
  }

  // 🔥 TOKEN DEBUGGING
  Future<String> _getTokenFromDb() async {
    if (kDebugMode) {
      print("========== FETCHING TOKEN FROM DB ==========");
    }

    final db = await DBHelper.instance.database;

    final result = await db.query(
      AppDBConst.userTable,
      where:
      '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      if (kDebugMode) {
        print("❌ NO TOKEN FOUND IN DB");
      }
      throw Exception('No active user token found in database');
    }

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      print("JWT Token Retrieved: ${token.substring(0, 25)}...");
    }

    return token;
  }
}