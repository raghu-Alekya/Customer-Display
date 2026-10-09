import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/login_model.dart';
import 'AuthIdsStore.dart';

class LoginRepository {
  final APIHelper _helper = APIHelper();

  // The PIN may come from the old key (emp_login_pin) or the new one (pin),
  // so LoginRequest does not need to change.
  String _pinFrom(LoginRequest request) {
    final json = request.toJson();
    return (json['pin'] ?? json['emp_login_pin'])?.toString() ?? '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main login: online path + offline fallback
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> fetchLoginToken(LoginRequest request) async {
    // -> https://pch.alektasolutions.com/connector/api/v1/pos/auth/login
    final String url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}";

    final String pin = _pinFrom(request);

    // merchantId + storeId were saved after merchant-store-login
    final String merchantId = await AuthIdsStore.getMerchantId();
    final String storeId = await AuthIdsStore.getStoreId();

    if (merchantId.isEmpty || storeId.isEmpty) {
      throw Exception(
        "Store not set up. Please complete merchant login first.",
      );
    }

    // Body sent to the server: {"pin": "...", "merchantId": "...", "storeId": "..."}
    final Map<String, dynamic> body = {
      'pin': pin,
      'merchantId': merchantId,
      'storeId': storeId,
    };

    if (kDebugMode) {
      print("LoginRepository - URL: $url");
      print("LoginRepository - Request: $body");
    }

    // Always try the server first. Wi-Fi availability does not guarantee that
    // the configured API/tunnel is reachable (for example, an ngrok tunnel can
    // be offline while the device still reports internet=true).
    final isOnline = true;

    // Restore the configured store symbol before the login UI continues. This
    // also keeps offline order totals from reverting to the default currency.
    try {
      final currency = await AssetDBHelper.instance.getCurrency();
      final symbol = currency != null && currency.length > 1 ? currency[1] : null;
      if (symbol != null && symbol.trim().isNotEmpty) {
        TextConstants.currencySymbol = symbol;
      }
    } catch (_) {
      // Cached currency is optional and must never block sign-in.
    }

    if (isOnline) {
      // ── ONLINE PATH ────────────────────────────────────────────────────
      try {
        final response = await _helper.post(url, body, false);
        // On successful online login, save the PIN hash for future offline use
        await _cacheEmployeePinIfPresent(pin, response);
        return response;
      } catch (e) {
        if (kDebugMode) print("LoginRepository - Online login exception: $e");

        final errStr = e.toString().toLowerCase();
        final isAuthFailure = OfflineHelper.isSessionError(e) ||
            errStr.contains('invalid') ||
            errStr.contains('incorrect') ||
            errStr.contains('unauthorised') ||
            errStr.contains('wrong') ||
            errStr.contains('403') ||
            errStr.contains('401') ||
            errStr.contains('session_active_elsewhere');

        // If the server explicitly rejected the credentials, do not create a fake offline token
        if (isAuthFailure) {
          rethrow;
        }
        // Fall through only for actual network transport failure
      }
    }

    // ── OFFLINE PATH ────────────────────────────────────────────────────────
    if (kDebugMode) print("LoginRepository - Attempting offline PIN validation");

    final employee = await UserDbHelper().validateOfflinePin(pin);

    if (employee == null) {
      if (isOnline) {
        throw Exception(
          "Login failed. Server is unreachable. Please check your PIN and network connection.",
        );
      } else {
        throw Exception(
          "Offline login failed: PIN not recognized. Please log in online first to cache your credentials.",
        );
      }
    }

    // Found matching employee: create synthetic offline session
    final userId = int.tryParse(employee['employees_id']?.toString() ?? '0') ?? 0;
    final displayName = employee['employees_display_name']?.toString() ?? 'Cashier';
    final email = employee['employee_email']?.toString() ?? '';

    await UserDbHelper().saveOfflineUserSession(
      userId: userId,
      displayName: displayName,
      email: email,
    );

    if (kDebugMode) {
      print("LoginRepository - Offline session created for: $displayName (id: $userId)");
    }

    // Return a synthetic JSON response matching what the online API would return
    final offlineToken = 'OFFLINE_TOKEN_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    return '{"success":true,"data":{"id":$userId,"displayName":"$displayName","email":"$email","token":"$offlineToken","role":"cashier"}}';
  }

  // Takes the PIN directly (the request body is no longer the old LoginRequest map)
  Future<void> _cacheEmployeePinIfPresent(String pin, String rawResponse) async {
    try {
      if (pin.isEmpty) return;

      Map<String, dynamic>? dataMap;
      try {
        final decoded = jsonDecode(rawResponse);
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map<String, dynamic>) {
            dataMap = decoded['data'] as Map<String, dynamic>;
          } else {
            dataMap = decoded;
          }
        }
      } catch (_) {}

      // User details may be under data.user, data.employee, or directly in data
      final nestedUser = dataMap?['user'] is Map
          ? Map<String, dynamic>.from(dataMap!['user'] as Map)
          : dataMap?['employee'] is Map
          ? Map<String, dynamic>.from(dataMap!['employee'] as Map)
          : <String, dynamic>{};
      final source = <String, dynamic>{...?dataMap, ...nestedUser};

      final employeeId = source['id']?.toString() ??
          source['employeeId']?.toString() ??
          source['user_id']?.toString() ??
          '';

      final firstName = source['firstName']?.toString() ?? '';
      final lastName = source['lastName']?.toString() ?? '';
      final fullName = '$firstName $lastName'.trim();
      final displayName = source['displayName']?.toString() ??
          source['display_name']?.toString() ??
          (fullName.isNotEmpty ? fullName : (source['name']?.toString() ?? 'Cashier'));

      final email = source['email']?.toString() ?? '';

      if (employeeId.isNotEmpty && employeeId != '0') {
        await UserDbHelper().saveEmployeePin(
          employeeId: employeeId,
          displayName: displayName,
          email: email,
          pin: pin,
        );
        if (kDebugMode) {
          print("✅ LoginRepository - Cached employee PIN for offline login: $displayName (id: $employeeId)");
        }
      }
    } catch (e) {
      if (kDebugMode) print("LoginRepository - Could not cache PIN: $e");
    }
  }
}