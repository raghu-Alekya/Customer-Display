import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/login_model.dart';
import '../../Screens/Auth/store_id_screen.dart';
import 'AuthIdsStore.dart';

class LoginRepository {
  final APIHelper _helper = APIHelper();

  /// Supports both old key (emp_login_pin) and new key (pin).
  String _pinFrom(LoginRequest request) {
    final json = request.toJson();
    return (json['pin'] ?? json['emp_login_pin'])?.toString() ?? '';
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceId = (await DeviceHelper.getDeviceId()).trim();
      if (deviceId.isNotEmpty) return deviceId;
    } catch (e) {
      if (kDebugMode) {
        print('LoginRepository - Could not get device ID: $e');
      }
    }
    return 'unknown';
  }

  /// Employee PIN login against PCH connector:
  /// POST {base}/pos/auth/login
  /// Body: pin, device-id, merchantId, storeId
  ///
  /// Returns a JSON **string** (LoginBloc does `json.decode(token)`).
  Future<String> fetchLoginToken(LoginRequest request) async {
    final String url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}";

    final String pin = _pinFrom(request);
    final String merchantId = await AuthIdsStore.getMerchantId();
    final String storeId = await AuthIdsStore.getStoreId();
    final String deviceId = await _getDeviceId();

    final Map<String, dynamic> body = {
      ...request.toJson(),
      'pin': pin,
      'device-id': deviceId,
      'deviceId': deviceId,
      if (merchantId.isNotEmpty) 'merchantId': merchantId,
      if (storeId.isNotEmpty) 'storeId': storeId,
    };

    if (kDebugMode) {
      print("LoginRepository - URL: $url");
      print("LoginRepository - device-id: $deviceId");
      print("LoginRepository - merchantId=$merchantId storeId=$storeId");
      print("LoginRepository - Request: $body");
    }

    final response = await _helper.post(url, body, false);

    if (response is String) {
      return response;
    }
    if (response is Map) {
      return json.encode(Map<String, dynamic>.from(response));
    }
    return response.toString();
  }
}
