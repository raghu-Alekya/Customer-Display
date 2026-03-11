import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/safe_drop_model.dart';

class SafeDropRepository { // Build #1.0.70 - Added by Naveen
  final APIHelper _helper = APIHelper();

  Future<SafeDropResponse> createSafeDrop(SafeDropRequest request) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.safes}${EndUrlConstants.safeDropEndUrl}";

    if (kDebugMode) {
      print("SafeDropRepository - POST URL: $url");
      print("SafeDropRepository - POST Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("SafeDropRepository - POST Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return SafeDropResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing safe drop response: $e");
        throw Exception("Failed to parse safe drop response");
      }
    } else if (response is Map<String, dynamic>) {
      return SafeDropResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in safe drop creation");
    }
  }
}