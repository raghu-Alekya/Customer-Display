import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/cacheheiper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/FastKey/fastkey_product_model.dart';

class FastKeyProductRepository {  // Build #1.0.15
  final APIHelper _helper = APIHelper();

  // POST: Add products to FastKey
  Future<FastKeyProductResponse> addProductsToFastKey(FastKeyProductRequest request) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.fastKeys}${EndUrlConstants.addFastKeyProductEndUrl}";

    if (kDebugMode) {
      print("FastKeyProductRepository - POST URL: $url");
      print("Request body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("FastKeyProductRepository - POST Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return FastKeyProductResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing POST response: $e");
        throw Exception("Failed to parse FastKey products response");
      }
    } else if (response is Map<String, dynamic>) {
      return FastKeyProductResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type");
    }
  }

  // GET: Fetch products by FastKey ID
  Future<FastKeyProductsResponse> getProductsByFastKeyId(int fastKeyId) async {
    final cacheKey = "fastkey_products_$fastKeyId";

    final cachedData = await CacheHelper.getData(cacheKey);

    if (cachedData != null) {
      if (kDebugMode) {
        print("✅ Loaded FastKey $fastKeyId from CACHE");
      }
      return FastKeyProductsResponse.fromJson(cachedData);
    }

    if (kDebugMode) {
      print("🌐 Cache miss → Calling API for FastKey $fastKeyId");
    }

    final url =
        "${UrlHelper.componentVersionUrl}"
        "${UrlMethodConstants.fastKeys}"
        "${EndUrlConstants.getFastKeyProductsEndUrl}"
        "$fastKeyId";

    final response = await _helper.get(url, true);

    dynamic responseData;

    if (response is String) {
      responseData = json.decode(response);
    } else if (response is Map<String, dynamic>) {
      responseData = response;
    } else {
      throw Exception("Unexpected API response type");
    }

    await CacheHelper.saveData(cacheKey, responseData);

    if (kDebugMode) {
      print("💾 Saved FastKey $fastKeyId to CACHE");
    }

    return FastKeyProductsResponse.fromJson(responseData);
  }
  // Build #1.0.89: Added this method for deleteProductFromFastKey API
  Future<FastKeyProductResponse> deleteProductFromFastKey(int fastkeyId, int productId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.fastKeys}${EndUrlConstants.deleteProductFromFastKeyEndUrl}";

    if (kDebugMode) {
      print("FastKeyProductRepository - DELETE PRODUCT URL: $url");
      print("Request body: {'fastkey_id': $fastkeyId, 'product_id': $productId}");
    }

    final response = await _helper.post(url, {
      TextConstants.fastKeyId: fastkeyId,
      TextConstants.productId: productId,
    }, true);

    if (kDebugMode) {
      print("FastKeyProductRepository - DELETE PRODUCT Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return FastKeyProductResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing DELETE PRODUCT response: $e");
        throw Exception("Failed to parse FastKey product delete response");
      }
    } else if (response is Map<String, dynamic>) {
      return FastKeyProductResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in DELETE PRODUCT");
    }
  }
}