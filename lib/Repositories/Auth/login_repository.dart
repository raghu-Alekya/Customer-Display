import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/login_model.dart';
import '../../Screens/Auth/store_id_screen.dart';
import 'AuthIdsStore.dart';

class LoginRepository {
  final APIHelper _helper = APIHelper();

  // Supports both the old key (emp_login_pin) and the new key (pin).
  String _pinFrom(LoginRequest request) {
    final json = request.toJson();
    return (json['pin'] ?? json['emp_login_pin'])?.toString() ?? '';
  }

  // Get the current device ID.
  //
  // Do not instantiate PosContextProvider here because it is abstract.
  // DeviceHelper is used directly as the fallback device ID source.
  Future<String> _getDeviceId() async {
    try {
      final deviceId = (await DeviceHelper.getDeviceId()).trim();

      if (deviceId.isNotEmpty) {
        return deviceId;
      }
    } catch (e) {
      if (kDebugMode) {
        print('LoginRepository - Could not get device ID: $e');
      }
    }

    return 'unknown';
  }

  // Main login: online login with offline fallback.
  Future<String> fetchLoginToken(LoginRequest request) async {
    final String url =
        '${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}';

    final String pin = _pinFrom(request);

    // Merchant and store IDs saved after merchant-store login.
    final String merchantId = await AuthIdsStore.getMerchantId();
    final String storeId = await AuthIdsStore.getStoreId();

    // Resolve the current device ID without instantiating an abstract class.
    final String deviceId = await _getDeviceId();

    // Connector login expects "device-id" with a hyphen.
    final Map<String, dynamic> body = {
      'pin': pin,
      'device-id': deviceId,
      'merchantId': merchantId,
      'storeId': storeId,
    };

    if (kDebugMode) {
      print('LoginRepository - URL: $url');
      print('LoginRepository - device-id: $deviceId');
      print('LoginRepository - Request: $body');
    }

    // Always try the server first.
    const bool isOnline = true;

    // Restore the saved currency symbol.
    try {
      final currency = await AssetDBHelper.instance.getCurrency();

      final symbol =
      currency != null && currency.length > 1 ? currency[1] : null;

      if (symbol != null && symbol.trim().isNotEmpty) {
        TextConstants.currencySymbol = symbol;
      }
    } catch (e) {
      if (kDebugMode) {
        print('LoginRepository - Could not restore currency: $e');
      }
    }

    if (isOnline) {
      // ONLINE LOGIN
      try {
        final response = await _helper.post(url, body, false);

        // Cache the employee PIN after a successful online login.
        await _cacheEmployeePinIfPresent(pin, response);

        return response;
      } catch (e) {
        if (kDebugMode) {
          print('LoginRepository - Online login exception: $e');
        }

        final errStr = e.toString().toLowerCase();

        final bool isAuthFailure =
            OfflineHelper.isSessionError(e) ||
                errStr.contains('invalid') ||
                errStr.contains('incorrect') ||
                errStr.contains('unauthorised') ||
                errStr.contains('unauthorized') ||
                errStr.contains('wrong') ||
                errStr.contains('403') ||
                errStr.contains('401') ||
                errStr.contains('session_active_elsewhere');

        // Never create an offline session when credentials are rejected.
        if (isAuthFailure) {
          rethrow;
        }

        // For other failures, attempt offline PIN validation.
      }
    }

    // OFFLINE LOGIN
    if (kDebugMode) {
      print('LoginRepository - Attempting offline PIN validation');
    }

    final employee = await UserDbHelper().validateOfflinePin(pin);

    if (employee == null) {
      throw Exception(
        'Login failed. Server is unreachable. '
            'Please check your PIN and network connection.',
      );
    }

    final int userId =
        int.tryParse(employee['employees_id']?.toString() ?? '0') ?? 0;

    final String displayName =
        employee['employees_display_name']?.toString() ?? 'Cashier';

    final String email = employee['employee_email']?.toString() ?? '';

    // Save the local offline user session.
    await UserDbHelper().saveOfflineUserSession(
      userId: userId,
      displayName: displayName,
      email: email,
    );

    if (kDebugMode) {
      print(
        'LoginRepository - Offline session created for: '
            '$displayName (id: $userId)',
      );
    }

    // Return a synthetic JSON response for offline login.
    final String offlineToken =
        'OFFLINE_TOKEN_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    return jsonEncode({
      'success': true,
      'data': {
        'id': userId,
        'displayName': displayName,
        'email': email,
        'token': offlineToken,
        'role': 'cashier',
      },
    });
  }

  // Cache the employee PIN after successful ONLINE login.
  Future<void> _cacheEmployeePinIfPresent(
      String pin,
      String rawResponse,
      ) async {
    try {
      if (pin.isEmpty) return;

      Map<String, dynamic>? dataMap;

      try {
        final decoded = jsonDecode(rawResponse);

        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map) {
            dataMap = Map<String, dynamic>.from(decoded['data'] as Map);
          } else {
            dataMap = decoded;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('LoginRepository - Could not parse login response: $e');
        }
        return;
      }

      if (dataMap == null) return;

      final Map<String, dynamic> nestedUser;

      if (dataMap['user'] is Map) {
        nestedUser = Map<String, dynamic>.from(dataMap['user'] as Map);
      } else if (dataMap['employee'] is Map) {
        nestedUser =
        Map<String, dynamic>.from(dataMap['employee'] as Map);
      } else {
        nestedUser = <String, dynamic>{};
      }

      final source = <String, dynamic>{
        ...dataMap,
        ...nestedUser,
      };

      final String employeeId =
          source['id']?.toString() ??
              source['user_id']?.toString() ??
              '';

      final String firstName = source['firstName']?.toString() ?? '';
      final String lastName = source['lastName']?.toString() ?? '';

      final String fullName = '$firstName $lastName'.trim();

      final String displayName =
          source['displayName']?.toString() ??
              source['display_name']?.toString() ??
              (fullName.isNotEmpty ? fullName : 'Cashier');

      final String email = source['email']?.toString() ?? '';

      if (employeeId.isNotEmpty && employeeId != '0') {
        await UserDbHelper().saveEmployeePin(
          employeeId: employeeId,
          displayName: displayName,
          email: email,
          pin: pin,
        );

        if (kDebugMode) {
          print(
            'LoginRepository - Cached employee PIN for offline login: '
                '$displayName (id: $employeeId)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('LoginRepository - Could not cache PIN: $e');
      }
    }
  }
}