import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:http/http.dart' as http;
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Search/product_custom_item_model.dart';
import '../../Models/Search/product_by_sku_model.dart';
import '../../Models/Search/product_search_model.dart';
import '../../Models/Search/product_variation_model.dart';

class ProductRepository { // Build #1.0.13 : added product search repository
  final APIHelper _helper = APIHelper();

  /// ✅ Utility: Recursively convert Map<dynamic, dynamic> → Map<String, dynamic>
  Map<String, dynamic> deepConvertToStringKeys(Map<dynamic, dynamic> input) {
    final Map<String, dynamic> output = {};
    input.forEach((key, value) {
      if (value is Map) {
        output[key.toString()] = deepConvertToStringKeys(value);
      } else if (value is List) {
        output[key.toString()] = value.map((item) {
          if (item is Map) return deepConvertToStringKeys(item);
          return item;
        }).toList();
      } else {
        output[key.toString()] = value;
      }
    });
    return output;
  }

  Future<List<ProductResponse>> fetchProducts(  {String? searchQuery}) async {
    final box = StorageProvider.productCache;
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}";

    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += "${UrlParameterConstants.productSearchParameter}$searchQuery${EndUrlConstants.productSearchEndUrl}";
    } else {
      url += EndUrlConstants.productSearchEndUrl;
    }

    if (kDebugMode) print("🛰 ProductRepository - URL: $url");

    try {
      // 🌐 Fetch from API
      final response = await _helper.get(url, true);

      // ✅ Ensure we have proper JSON
      dynamic data;
      if (response is String) {
        data = json.decode(response);
      } else if (response is Map && response.containsKey('body')) {
        data = json.decode(response['body']);
      } else if (response is http.Response) {
        data = json.decode(response.body);
      } else if (response is List) {
        data = response;
      } else {
        throw Exception("Unexpected response type: ${response.runtimeType}");
      }

      if (data is! List) {
        throw Exception("API returned non-list data: $data");
      }

      // ✅ Convert to models
      final List<ProductResponse> products =
      data.map((e) => ProductResponse.fromJson(e)).toList();

      // ✅ Cache
      for (var product in products) {
        await box.put(product.id.toString(), deepConvertToStringKeys(product.toJson()));
      }

      if (kDebugMode) {
        print("✅ ${products.length} products fetched and cached successfully.");
      }

      return products;
    } catch (e, st) {
      // 📴 Offline fallback
      if (kDebugMode) {
        print("⚠ [API ERROR] $e");
        debugPrintStack(stackTrace: st);
      }

      final cacheMap = await box.toMap();
      if (cacheMap.isNotEmpty) {
        try {
          final cachedProducts = cacheMap.values.map((e) {
            try {
              dynamic jsonData;
              if (e is String) {
                jsonData = json.decode(e);
              } else if (e is Map) {
                jsonData = deepConvertToStringKeys(e);
              } else {
                throw Exception("Invalid cache type: ${e.runtimeType}");
              }
              return ProductResponse.fromJson(Map<String, dynamic>.from(jsonData));
            } catch (err) {
              if (kDebugMode) print("⚠ Skipping bad cache entry: $err");
              return null;
            }
          }).whereType<ProductResponse>().toList();

          if (searchQuery != null && searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            final filtered = cachedProducts
                .where((p) => (p.name ?? '').toLowerCase().contains(q))
                .toList();
            print("⚡ Offline search found ${filtered.length} products for '$searchQuery'");
            return filtered;
          }

          print("⚠ Using ${cachedProducts.length} cached products due to $e");
          return cachedProducts;
        } catch (err) {
          print("❌ Error reading cache: $err");
        }
      }

      throw Exception("Failed to fetch or load cached products: $e");
    }
  }


//Build 1.1.36: Fetches product variations from the wc/v3 endpoint
//   Future<List<ProductVariation>> fetchProductVariations(int productId) async {
//     String url =
//         "${UrlHelper.wooCommerceV3}${UrlMethodConstants.variations}/$productId${EndUrlConstants.variationsEndUrl}";
//
//     if (kDebugMode) {
//       print("ProductRepository - FetchProductVariations URL: $url");
//     }
//
//     final response = await _helper.get(url, true);
//
//     if (kDebugMode) {
//       print("ProductRepository - FetchProductVariations Raw Response: $response");
//     }
//
//     List<dynamic> responseData = [];
//
//     if (response is String) {
//       responseData = json.decode(response);
//     } else if (response is List) {
//       responseData = response;
//     } else {
//       throw Exception("Unexpected response type");
//     }
//
//     // ✅ Convert responseData → ProductVariation objects
//     final variations = responseData
//         .map((variationJson) => ProductVariation.fromJson(variationJson))
//         .toList();
//
//     // ✅ Also store a normalized version in Hive for offline use
//     try {
//       final productBox = StorageProvider.productCache;
//       final cacheKey = "product_${productId}_variations";
//
//       // Normalize variations for easier offline use
//       final normalized = responseData.map((v) {
//         final image = (v["image"] is Map && v["image"]["src"] != null)
//             ? v["image"]["src"]
//             : (v["image"] is String ? v["image"] : "");
//         final name = (v["name"] is Map && v["name"]["rendered"] != null)
//             ? v["name"]["rendered"]
//             : (v["name"] is String ? v["name"] : "Unnamed Variant");
//         final price = v["price"]?.toString() ?? "0";
//
//         return {
//           "id": v["id"],
//           "name": name,
//           "price": price,
//           "sku": v["sku"] ?? "",
//           "image": image,
//         };
//       }).toList();
//
//       await productBox.put(cacheKey, {"variations": normalized});
//       if (kDebugMode) {
//         print("💾 Cached ${normalized.length} variations for product $productId");
//       }
//     } catch (e) {
//       if (kDebugMode) print("⚠ Failed to cache variations for product $productId: $e");
//     }
//
//     return variations;
//   }


  Future<List<ProductBySkuResponse>> fetchProductBySku(
      String sku, {
        bool forceRefresh = false,
      }) async {

    final productBox = StorageProvider.productCache;
    final cacheKey = "sku_${sku.toLowerCase()}";

    // ==========================================================
    // 🧠 1️⃣ USE CACHE (IF NOT FORCE REFRESH)
    // ==========================================================
    if (!forceRefresh) {
      final cached = await productBox.get(cacheKey);

      if (cached != null && cached["products"] != null) {
        if (kDebugMode) {
          print("💾 SKU CACHE HIT → $sku");
        }

        final List<dynamic> list = cached["products"];

        return list
            .map((e) => ProductBySkuResponse.fromJson(e))
            .toList();
      }
    }

    // ==========================================================
    // 🌐 2️⃣ FETCH FROM BACKEND
    // ==========================================================
    final String url =
        "${UrlHelper.wooCommerceV3}"
        "${UrlMethodConstants.products}"
        "${UrlParameterConstants.productBySku}$sku"
        "&status=publish";

    if (kDebugMode) {
      print("🌐 Fetching SKU from backend → $url");
    }

    final response = await _helper.get(url, true);

    List<dynamic> responseList = [];

    if (response is String) {
      responseList = json.decode(response);
    } else if (response is List) {
      responseList = response;
    } else if (response is Map<String, dynamic>) {
      responseList = [response];
    } else {
      throw Exception("Unexpected response type: ${response.runtimeType}");
    }

    final products =
    responseList.map((e) => ProductBySkuResponse.fromJson(e)).toList();

    // ==========================================================
    // 🚫 3️⃣ IF NOT FOUND → DELETE CACHE
    // ==========================================================
    if (products.isEmpty) {
      await productBox.delete(cacheKey);

      if (kDebugMode) {
        print("🗑 SKU deleted from backend → cache cleared");
      }

      return [];
    }

    // ==========================================================
    // 💾 4️⃣ CACHE VALID PRODUCT
    // ==========================================================
    final normalizedProducts = products.map((p) {
      return {
        "id": p.id ?? 0,
        "name": p.name ?? "Unnamed Product",
        "price": p.price ?? "0.0",
        "sku": p.sku ?? sku,
        "type": p.type ?? "simple",
        "images": p.images?.map((img) => img.toJson()).toList() ?? [],
        "variations": p.variations ?? [],
        "tags": p.tags
            ?.map((t) => {
          "id": t.id,
          "name": t.name,
          "slug": t.slug,
        })
            .toList(),
        "meta_data": p.metaData
            ?.map((m) => {
          "key": m.key,
          "value": m.value,
        })
            .toList(),
      };
    }).toList();

    await productBox.put(cacheKey, {
      "products": normalizedProducts,
    });

    if (kDebugMode) {
      print("💾 SKU cached → $cacheKey");
    }

    return products;
  }
  Future<AddCustomItemModel> addCustomItem(AddCustomItemRequest request) async {
    final String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}";

    if (kDebugMode) {
      print("🧩 ProductRepository - CreateProduct URL: $url");
      print("📦 Request Body: ${json.encode(request.toJson())}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("🧩 ProductRepository - CreateProduct Raw Response: $response");
    }

    Map<String, dynamic> responseData = {};

    // ✅ Handle both String and Map responses safely
    if (response is String) {
      try {
        responseData = json.decode(response);
      } catch (e) {
        if (kDebugMode) print("❌ JSON decode failed: $e");
        throw Exception("Failed to parse product creation response");
      }
    } else if (response is Map<String, dynamic>) {
      responseData = response;
    } else {
      throw Exception("Unexpected response type: ${response.runtimeType}");
    }

    // ✅ Convert to model
    final addCustomItem = AddCustomItemModel.fromJson(responseData);

    // ✅ Store custom product in Hive for offline access
    try {
      final productBox = StorageProvider.productCache;
      final cacheKey = "sku_${(addCustomItem.sku ?? request.sku ?? '').toLowerCase()}";

      final normalized = [
        {
          "id": addCustomItem.id ?? 0,
          "name": addCustomItem.name ?? "Unnamed Custom Item",
          "price": addCustomItem.price?.toString() ?? request.regularPrice ?? "0.0",
          "sku": addCustomItem.sku ?? request.sku ?? "",
          "type": "custom_item",
          "images": [],
          "variations": [],
        }
      ];

      await productBox.put(cacheKey, {
        "products": normalized,
      });

      if (kDebugMode) {
        print("💾 Cached custom item in Hive (key: $cacheKey)");
        print("🔹 Name: ${addCustomItem.name}, Price: ${addCustomItem.price}, SKU: ${addCustomItem.sku}");
      }
    } catch (e) {
      if (kDebugMode) print("⚠ Failed to cache custom item: $e");
    }

    return addCustomItem;
  }
}