import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Search/product_custom_item_model.dart';
import '../../Models/Search/product_by_sku_model.dart';
import '../../Models/Search/product_search_model.dart';
import '../../Models/Search/product_variation_model.dart';

class ProductRepository { // Build #1.0.13 : added product search repository
  final APIHelper _helper = APIHelper();

  Future<List<ProductResponse>> fetchProducts({String? searchQuery}) async {
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}";

    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += "${UrlParameterConstants.productSearchParameter}$searchQuery${EndUrlConstants.productSearchEndUrl}";
    } else {
      url += EndUrlConstants.productSearchEndUrl;
    }

    if (kDebugMode) {
      print("ProductRepository - URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("ProductRepository - Raw Response: $response");
    }

    // Parse the response
    if (response is String) {
      try {
        final List<dynamic> responseData = json.decode(response);
        return responseData.map((productJson) => ProductResponse.fromJson(productJson)).toList();
      } catch (e) {
        if (kDebugMode) {
          print("Error parsing response: $e");
        }
        throw Exception("Failed to parse products");
      }
    } else if (response is List) {
      return response.map((productJson) => ProductResponse.fromJson(productJson)).toList();
    } else {
      throw Exception("Unexpected response type");
    }
  }

//Build 1.1.36: Fetches product variations from the wc/v3 endpoint
  Future<List<ProductVariation>> fetchProductVariations(int productId) async {
    String url =
        "${UrlHelper.wooCommerceV3}${UrlMethodConstants.variations}/$productId${EndUrlConstants.variationsEndUrl}";

    if (kDebugMode) {
      print("ProductRepository - FetchProductVariations URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("ProductRepository - FetchProductVariations Raw Response: $response");
    }

    List<dynamic> responseData = [];

    if (response is String) {
      responseData = json.decode(response);
    } else if (response is List) {
      responseData = response;
    } else {
      throw Exception("Unexpected response type");
    }

    // ✅ Convert responseData → ProductVariation objects
    final variations = responseData
        .map((variationJson) => ProductVariation.fromJson(variationJson))
        .toList();

    // ✅ Also store a normalized version in Hive for offline use
    try {
      final productBox = Hive.box('productCache');
      final cacheKey = "product_${productId}_variations";

      // Normalize variations for easier offline use
      final normalized = responseData.map((v) {
        final image = (v["image"] is Map && v["image"]["src"] != null)
            ? v["image"]["src"]
            : (v["image"] is String ? v["image"] : "");
        final name = (v["name"] is Map && v["name"]["rendered"] != null)
            ? v["name"]["rendered"]
            : (v["name"] is String ? v["name"] : "Unnamed Variant");
        final price = v["price"]?.toString() ?? "0";

        return {
          "id": v["id"],
          "name": name,
          "price": price,
          "sku": v["sku"] ?? "",
          "image": image,
        };
      }).toList();

      await productBox.put(cacheKey, {"variations": normalized});
      if (kDebugMode) {
        print("💾 Cached ${normalized.length} variations for product $productId");
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to cache variations for product $productId: $e");
    }

    return variations;
  }


  // Build #1.0.43: added by naveen
  Future<List<ProductBySkuResponse>> fetchProductBySku(String sku) async {
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}${UrlParameterConstants.productBySku}$sku";

    if (kDebugMode) {
      print("ProductRepository - FetchProductBySku URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("ProductRepository - FetchProductBySku Raw Response: $response");
    }

    if (response is String) {
      try {
        final List<dynamic> responseData = json.decode(response);
        return responseData.map((productJson) => ProductBySkuResponse.fromJson(productJson)).toList();
      } catch (e) {
        if (kDebugMode) {
          print("ProductRepository - Error parsing product by SKU response: $e");
        }
        throw Exception("Failed to parse product by SKU");
      }
    } else if (response is List) {
      return response.map((productJson) => ProductBySkuResponse.fromJson(productJson)).toList();
    } else {
      throw Exception("Unexpected response type");
    }
  }

  Future<AddCustomItemModel> addCustomItem(AddCustomItemRequest request) async {
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}";
    if (kDebugMode) {
      print("ProductRepository - CreateProduct URL: $url");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("ProductRepository - CreateProduct Raw Response: $response");
    }

    if (response is String) {
      try {
        final Map<String, dynamic> responseData = json.decode(response);
        return AddCustomItemModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) {
          print("ProductRepository - Error parsing create product response: $e");
        }
        throw Exception("Failed to parse create product response");
      }
    } else if (response is Map<String, dynamic>) {
      return AddCustomItemModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type");
    }
  }
}