import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Assets/asset_model.dart';
import '../Auth/AuthIdsStore.dart';

class AssetRepository { //Build #1.0.40
  final APIHelper _helper = APIHelper();

  /// GET store bootstrap (currency, taxes, roles, denominations, employees, etc.)
  /// PCH: /store/store-pos-configuration/{storeId}/bootstrap
  Future<AssetResponse> getAssets() async {
    String storeId = '';
    try {
      storeId = (await AuthIdsStore.getStoreId()).trim();
    } catch (e) {
      if (kDebugMode) print("AssetRepository - getStoreId failed: $e");
    }

    // Prefer bootstrap when storeId is available; fallback to legacy assets path
    final String url;
    if (storeId.isNotEmpty) {
      url =
      "${UrlHelper.baseUrl}${UrlMethodConstants.cashbackservices}/$storeId/bootstrap";
    } else {
      url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.assets}";
    }

    if (kDebugMode) {
      print("AssetRepository - GET URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("AssetRepository - GET Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return AssetResponse.fromJson(
            Map<String, dynamic>.from(responseData as Map));
      } catch (e) {
        if (kDebugMode) print("Error parsing assets/bootstrap response: $e");
        throw Exception("Failed to parse assets response");
      }
    } else if (response is Map<String, dynamic>) {
      return AssetResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in assets GET");
    }
  }

  // Build #1.0.163: Added Image Assets API call
  Future<ImageAssetsResponse> getImageAssets() async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.assets}${EndUrlConstants.assetsImages}";
    if (kDebugMode) {
      print("AssetRepository - GET Image Assets URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("AssetRepository - GET Image Assets Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return ImageAssetsResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing image assets response: $e");
        throw Exception("Failed to parse image assets response");
      }
    } else if (response is Map<String, dynamic>) {
      return ImageAssetsResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in image assets GET");
    }
  }
}
