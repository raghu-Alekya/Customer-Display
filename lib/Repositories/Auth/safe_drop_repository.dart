import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/safe_drop_model.dart';
import '../../Models/Auth/shift_summary_model.dart';
import 'AuthIdsStore.dart';

class SafeDropRepository { // Build #1.0.70 - Added by Naveen
  final APIHelper _helper = APIHelper();

  /// POST {connector}/stores/{storeId}/pos/safe-drops/create-safe-drop
  Future<SafeDropResponse> createSafeDrop(SafeDropRequest request) async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw StateError('Store ID is missing; cannot create a safe drop.');
    }
    final url =
        "${UrlHelper.baseUrl}stores/${Uri.encodeComponent(storeId)}/pos/safe-drops/create-safe-drop";

    if (kDebugMode) {
      print("SafeDropRepository - POST URL: $url");
      print("SafeDropRepository - POST Request Body: ${request.toJson()}");
    }

    final response =
        await _helper.post(url, request.toJson(), true, validateMarchentUrl: true);

    if (kDebugMode) {
      print("SafeDropRepository - POST Raw Response: $response");
    }

    final dynamic decoded;
    try {
      decoded = response is String ? json.decode(response) : response;
    } catch (e) {
      if (kDebugMode) print("Error parsing safe drop response: $e");
      throw Exception("Failed to parse safe drop response");
    }
    if (decoded is! Map) {
      throw Exception("Unexpected response type in safe drop creation");
    }
    final responseData = Map<String, dynamic>.from(decoded);
    // 200 with success:false means the drop was rejected
    if (responseData['success'] == false) {
      throw Exception(
          responseData['message']?.toString() ?? 'Safe drop was rejected.');
    }
    return SafeDropResponse.fromJson(responseData);
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

  /// GET {connector}/stores/{storeId}/pos/safe-drops/get-all-safe-drops
  /// Returns the store's safe drops; with [serverShiftId] ("SHIFT-...") only
  /// that shift's drops. Throws if the request fails.
  Future<List<SafeDrop>> getAllSafeDrops({String? serverShiftId}) async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw StateError('Store ID is missing; cannot load safe drops.');
    }
    // Relative URL → APIHelper prefixes the connector base (/connector/api/v1/)
    final url =
        "stores/${Uri.encodeComponent(storeId)}/pos/safe-drops/get-all-safe-drops";

    final response = await _helper.get(url, true);
    if (kDebugMode) {
      print("SafeDropRepository - GET $url → $response");
    }
    final dynamic decoded =
    response is String && response.isNotEmpty ? json.decode(response) : response;

    final items = _findDropList(decoded);
    final wantedShift = serverShiftId?.trim();
    return items
        .where((item) {
      if (wantedShift == null || wantedShift.isEmpty) return true;
      final shiftId = item['shift_id'] ?? item['shiftId'];
      return shiftId?.toString() == wantedShift;
    })
        .map(SafeDrop.fromApi)
        .toList();
  }

  /// The list of safe drop objects in the response: top-level list, or the
  /// first list of objects under keys like data / safeDrops / safe_drops.
  static List<Map<String, dynamic>> _findDropList(dynamic node) {
    if (node is List) {
      return node.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (node is Map) {
      for (final key in const [
        'safeDrops',
        'safe_drops',
        'safes',
        'data',
        'items',
        'results',
      ]) {
        final value = node[key];
        if (value is List || value is Map) {
          final found = _findDropList(value);
          if (found.isNotEmpty) return found;
        }
      }
    }
    return const [];
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