import 'dart:convert';
import 'package:flutter/foundation.dart';
<<<<<<< HEAD
=======
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:http/http.dart' as http;
>>>>>>> origin/Grocery_pch_api_integration
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Search/product_custom_item_model.dart';
import '../../Models/Search/product_by_sku_model.dart';
import '../../Models/Search/product_search_model.dart';
import '../../Models/Search/product_variation_model.dart';
<<<<<<< HEAD
=======
import '../Auth/AuthIdsStore.dart';
import '../../core/api/token_storage.dart';
>>>>>>> origin/Grocery_pch_api_integration

class ProductRepository { // Build #1.0.13 : added product search repository
  final APIHelper _helper = APIHelper();

<<<<<<< HEAD
  Future<List<ProductResponse>> fetchProducts({String? searchQuery}) async {
=======
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

  /// Maps connector catalog product payload into the shape expected by
  /// [ProductBySkuResponse.fromJson] (legacy Woo-style fields).
  Map<String, dynamic> _normalizeCatalogProduct(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    // image: "https://..." → images: [{ src: "..." }]
    final imageVal = map['image'];
    final hasImagesList =
        map['images'] is List && (map['images'] as List).isNotEmpty;
    if (!hasImagesList) {
      if (imageVal is String && imageVal.trim().isNotEmpty) {
        map['images'] = [
          {
            'id': 0,
            'src': imageVal.trim(),
            'name': '',
            'alt': '',
          }
        ];
      } else if (imageVal is Map) {
        map['images'] = [Map<String, dynamic>.from(imageVal)];
      } else {
        map['images'] = map['images'] ?? [];
      }
    }

    // categoryId / categoryName → categories: [{ id, name }]
    final hasCategories =
        map['categories'] is List && (map['categories'] as List).isNotEmpty;
    if (!hasCategories && map['categoryId'] != null) {
      map['categories'] = [
        {
          'id': map['categoryId'],
          'name': map['categoryName']?.toString() ?? '',
          'slug': '',
        }
      ];
    }

    // Price defaults
    final price = map['price']?.toString() ?? '0';
    if ((map['regular_price'] == null ||
        map['regular_price'].toString().trim().isEmpty) &&
        price.isNotEmpty) {
      map['regular_price'] = price;
    }

    map['status'] = map['status'] ?? 'publish';
    map['stock_status'] = map['stock_status'] ?? 'instock';
    map['type'] = map['type'] ?? 'simple';
    map['sku'] = map['sku']?.toString() ?? '';
    map['name'] = map['name']?.toString() ?? '';
    map['id'] = map['id'] ?? 0;
    map['tags'] = map['tags'] ?? [];
    map['meta_data'] = map['meta_data'] ?? [];
    map['variations'] = map['variations'] ?? [];
    map['attributes'] = map['attributes'] ?? [];

    return map;
  }

  Future<List<ProductResponse>> fetchProducts(  {String? searchQuery}) async {
    final box = StorageProvider.productCache;
>>>>>>> origin/Grocery_pch_api_integration
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}";

    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += "${UrlParameterConstants.productSearchParameter}$searchQuery${EndUrlConstants.productSearchEndUrl}";
    } else {
      url += EndUrlConstants.productSearchEndUrl;
    }

<<<<<<< HEAD
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
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.variations}/$productId${EndUrlConstants.variationsEndUrl}";
=======
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


  // Connector variations API (same response shape as legacy Woo list):
  // GET /store/{storeId}/products/{productId}/variations
  // Header: Authorization: Bearer <accessToken>
  Future<List<ProductVariation>> fetchProductVariations(int productId) async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw Exception(
        'Missing saved store ID. Please complete merchant/store login again.',
      );
    }

    // Path uses singular "store" (connector API)
    final String url =
        "store/$storeId/products/$productId/variations";
>>>>>>> origin/Grocery_pch_api_integration

    if (kDebugMode) {
      print("ProductRepository - FetchProductVariations URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
<<<<<<< HEAD
      print("ProductRepository - FetchProductVariations Raw Response: $response");
    }

    if (response is String) {
      try {
        final List<dynamic> responseData = json.decode(response);
        return responseData.map((variationJson) => ProductVariation.fromJson(variationJson)).toList();
      } catch (e) {
        if (kDebugMode) {
          print("ProductRepository - Error parsing variations response: $e");
        }
        throw Exception("Failed to parse variations");
      }
    } else if (response is List) {
      return response.map((variationJson) => ProductVariation.fromJson(variationJson)).toList();
    } else {
      throw Exception("Unexpected response type");
    }
  }

  // Build #1.0.43: added by naveen
  Future<List<ProductBySkuResponse>> fetchProductBySku(String sku) async {
    String url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.products}${UrlParameterConstants.productBySku}$sku";

    if (kDebugMode) {
      print("ProductRepository - FetchProductBySku URL: $url");
=======
      print(
          "ProductRepository - FetchProductVariations Raw Response type: ${response.runtimeType}");
    }

    List<dynamic> responseData = [];

    if (response is String) {
      final decoded = json.decode(response);
      if (decoded is List) {
        responseData = decoded;
      } else if (decoded is Map) {
        final nested = decoded['data'] ?? decoded['variations'];
        responseData = nested is List ? nested : [decoded];
      }
    } else if (response is List) {
      responseData = response;
    } else if (response is Map) {
      final nested = response['data'] ?? response['variations'];
      responseData = nested is List ? nested : [response];
    } else {
      throw Exception("Unexpected response type: ${response.runtimeType}");
    }

    final variations = responseData
        .whereType<Map>()
        .map((variationJson) => ProductVariation.fromJson(
      Map<String, dynamic>.from(variationJson),
    ))
        .toList();

    // Cache normalized list for offline use (unchanged format)
    try {
      final productBox = StorageProvider.productCache;
      final cacheKey = "product_${productId}_variations";

      final normalized = responseData.whereType<Map>().map((v) {
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
        print(
            "💾 Cached ${normalized.length} variations for product $productId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠ Failed to cache variations for product $productId: $e");
      }
    }

    return variations;
  }

  /// Builds the connector variations URL for screens that call http.get directly.
  static Future<String> buildVariationsUrl(int productId) async {
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw Exception(
        'Missing saved store ID. Please complete merchant/store login again.',
      );
    }
    return "${UrlHelper.baseUrl}store/$storeId/products/$productId/variations";
  }


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
    // 🌐 2️⃣ FETCH FROM BACKEND (connector catalog by SKU / barcode)
    // GET /stores/{storeId}/catalog/products/{sku}
    // Header: Authorization: Bearer <accessToken>
    // ==========================================================
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (storeId.isEmpty) {
      throw Exception(
        'Missing saved store ID. Please complete merchant/store login again.',
      );
    }

    final encodedSku = Uri.encodeComponent(sku.trim());
    final String url =
        "stores/$storeId/catalog/products/$encodedSku";

    if (kDebugMode) {
      print("🌐 Fetching SKU from connector catalog → $url");
>>>>>>> origin/Grocery_pch_api_integration
    }

    final response = await _helper.get(url, true);

<<<<<<< HEAD
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
=======
    List<dynamic> responseList = [];

    if (response is String) {
      final decoded = json.decode(response);
      if (decoded is List) {
        responseList = decoded;
      } else if (decoded is Map) {
        responseList = [decoded];
      }
    } else if (response is List) {
      responseList = response;
    } else if (response is Map<String, dynamic>) {
      // Some gateways wrap as { data: [...] } or single object
      final data = response['data'] ?? response['products'];
      if (data is List) {
        responseList = data;
      } else {
        responseList = [response];
      }
    } else {
      throw Exception("Unexpected response type: ${response.runtimeType}");
    }

    // Normalize connector shape (image string, categoryId) → model shape
    final products = responseList
        .whereType<Map>()
        .map((e) => ProductBySkuResponse.fromJson(
      _normalizeCatalogProduct(Map<String, dynamic>.from(e)),
    ))
        .toList();

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
>>>>>>> origin/Grocery_pch_api_integration
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Grocery_pch_api_integration
  }
}