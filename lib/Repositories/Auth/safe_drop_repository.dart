import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/safe_drop_model.dart';
import 'AuthIdsStore.dart';

class SafeDropRepository { // Build #1.0.70 - Added by Naveen
  final APIHelper _helper = APIHelper();

  Future<SafeDropResponse> createSafeDrop(SafeDropRequest request) async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw StateError('Store ID is missing; cannot create a safe.');
    }
    final url =
        "${UrlHelper.safeApiBaseUrl}/stores/${Uri.encodeComponent(storeId)}/pos/safes/create-safe";

    if (kDebugMode) {
      print("SafeDropRepository - POST URL: $url");
      print("SafeDropRepository - POST Request Body: ${request.toJson()}");
    }

    final response =
        await _helper.post(url, request.toJson(), true, validateMarchentUrl: true);

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

  /// GET /stores/{storeId}/pos/safe-drop/status
  /// Returns whether Safe Drop is enabled for the store, or null if the
  /// status can't be read (offline, error, unknown format) so callers keep
  /// the last saved value.
  Future<bool?> getSafeDropStatus() async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) return null;
    final url =
        "${UrlHelper.safeApiBaseUrl}/stores/${Uri.encodeComponent(storeId)}/pos/safe-drop/status";

    try {
      final response = await _helper.get(url, true);
      if (kDebugMode) {
        print("SafeDropRepository - GET $url → $response");
      }
      final dynamic decoded =
      response is String ? json.decode(response) : response;
      if (decoded is! Map) return null;
      final data = decoded['data'];
      return _readEnabled(data is Map ? data : null) ?? _readEnabled(decoded);
    } catch (e) {
      if (kDebugMode) print("SafeDropRepository - safe drop status failed: $e");
      return null;
    }
  }

  static const List<String> _enabledKeys = [
    'safe_drop_enabled',
    'safeDropEnabled',
    'safe_enable_drop',
    'safeEnableDrop',
    'is_enabled',
    'isEnabled',
    'enabled',
    'is_active',
    'isActive',
    'active',
    'status',
  ];

  static bool? _readEnabled(Map? map) {
    if (map == null) return null;
    for (final key in _enabledKeys) {
      if (!map.containsKey(key)) continue;
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      switch (value?.toString().trim().toLowerCase()) {
        case '1':
        case 'true':
        case 'yes':
        case 'on':
        case 'enabled':
        case 'active':
          return true;
        case '0':
        case 'false':
        case 'no':
        case 'off':
        case 'disabled':
        case 'inactive':
          return false;
      }
    }
    return null;
  }
}