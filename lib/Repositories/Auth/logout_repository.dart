import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Helper/api_helper.dart';
import 'package:pinaka_pos/Helper/url_helper.dart';

import '../../Models/Auth/logout_model.dart';

// Build #1.0.163: Added Logout Repository
class LogoutRepository {
  final APIHelper _helper = APIHelper();

  // Build #1.0.163: Added logout API call
  Future<String> logout() async {
    // Construct logout URL
    String url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}${EndUrlConstants.logout}";

    if (kDebugMode) {
      print("LogoutRepository - Initiating logout request to URL: $url");
    }

    try {
      // Make POST request to logout endpoint
      final response = await _helper.post(url, {}, true);
      if (kDebugMode) {
        print("LogoutRepository - Response received: $response");
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        print("LogoutRepository - Error during logout: $e");
      }
      rethrow;
    }
  }

  // Build #1.0.166: Added Logout By Employ Pin API call
  Future<String> performLogoutByEmpPin(LogoutRequest request) async {
    // Construct logout URL based on API endpoint
    String url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}${EndUrlConstants.logoutById}";

    if (kDebugMode) {
      print("LogoutRepository - URL: $url");
      print("LogoutRepository - Request: ${request.toJson()}");
    }

    // POST request with auth header (true) since JWT logout may require token
    final response = await _helper.post(url, request.toJson(), true);
    return response;
  }

}