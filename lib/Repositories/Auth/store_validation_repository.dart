// repositories/store_validation_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/store_validation_model.dart';

class StoreValidationRepository {  //Build #1.0.42: Added by Naveen
  final APIHelper _helper = APIHelper();

  Future<StoreValidationResponse> validateStore({
    required String username,
    required String password,
    required String storeId,
    required String deviceId,
  }) async {
    final url = UrlHelper.validateMerchant;
    final body = {
      'username': username,
      'password': password,
      'store_id': storeId,
      'device_id': deviceId,
    };

    if (kDebugMode) {
      print("StoreValidationRepository - POST URL: $url");
      print("StoreValidationRepository - Body: $body");
    }

    final response = await _helper.post(url, body, false, validateMarchentUrl: true);

    if (kDebugMode) {
      print("StoreValidationRepository - POST Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        if (responseData is Map<String, dynamic>) {
          return StoreValidationResponse.fromJson(responseData);
        } else {
          throw Exception("Unexpected response format in store validation");
        }
      } catch (e) {
        throw Exception("Failed to parse store validation response: $e");
      }
    } else if (response is Map<String, dynamic>) {
      return StoreValidationResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in store validation: ${response.runtimeType}");
    }
  }

}