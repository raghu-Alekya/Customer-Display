// repositories/store_validation_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/store_validation_model.dart';
import 'AuthIdsStore.dart';

class StoreValidationRepository {  //Build #1.0.42: Added by Naveen
  final APIHelper _helper = APIHelper();

  Future<StoreValidationResponse> validateStore({
    required String username,
    required String password,
    required String storeId,
    required String deviceId, // kept so existing callers don't break; new API doesn't take it
  }) async {
    final url = UrlHelper.validateMerchant;
    final body = {
      'merchantIdentifier': username,
      'password': password,
      'storeId': storeId, // new API key (was store_id)
    };

    if (kDebugMode) {
      print("StoreValidationRepository - POST URL: $url");
      print("StoreValidationRepository - Body: $body");
    }

    final response = await _helper.post(url, body, false, validateMarchentUrl: true);

    if (kDebugMode) {
      print("StoreValidationRepository - POST Response: $response");
    }

    // Normalise the response to a Map
    Map<String, dynamic> responseData;
    if (response is String) {
      try {
        final decoded = json.decode(response);
        if (decoded is! Map<String, dynamic>) {
          throw Exception("Unexpected response format in store validation");
        }
        responseData = decoded;
      } catch (e) {
        throw Exception("Failed to parse store validation response: $e");
      }
    } else if (response is Map<String, dynamic>) {
      responseData = response;
    } else {
      throw Exception("Unexpected response type in store validation: ${response.runtimeType}");
    }

    // Save merchant + store UUIDs so the employee login can send them
    await _saveAuthIds(responseData);

    return StoreValidationResponse.fromJson(responseData);
  }

  Future<void> _saveAuthIds(Map<String, dynamic> responseData) async {
    try {
      if (responseData['success'] != true) return;

      final data = responseData['data'];
      if (data is! Map) return;

      final merchantId = (data['merchant'] is Map) ? data['merchant']['id']?.toString() ?? '' : '';
      final storeUuid = (data['store'] is Map) ? data['store']['id']?.toString() ?? '' : '';

      if (merchantId.isEmpty || storeUuid.isEmpty) return;

      await AuthIdsStore.save(merchantId: merchantId, storeId: storeUuid);

      if (kDebugMode) {
        print("StoreValidationRepository - Saved merchantId: $merchantId, storeId: $storeUuid");
      }
    } catch (e) {
      if (kDebugMode) print("StoreValidationRepository - Could not save auth ids: $e");
    }
  }
}