import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../Database/db_helper.dart';

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

    final token = await _getTokenFromDb();

    final uri = Uri.parse(
      '$baseUrl/wp-json/pinaka-pos/v1/orders/refund-valid-user',
    );

    if (kDebugMode) {
      print("API URL: $uri");
      print("Authorization Header: Bearer ${token.substring(0, 20)}...");
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['employee_pin'] = employeePin;

    if (kDebugMode) {
      print("Request Headers: ${request.headers}");
      print("Request Fields: ${request.fields}");
    }

    final streamedResponse = await request.send();

    if (kDebugMode) {
      print("Streamed Response Status: ${streamedResponse.statusCode}");
      print("Streamed Response Headers: ${streamedResponse.headers}");
    }

    final response = await http.Response.fromStream(streamedResponse);

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
    if (response.statusCode != 200) {
      if (kDebugMode) {
        print("❌ HTTP ERROR: ${response.statusCode}");
      }
      throw Exception("Unauthorized or session expired");
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