// repositories/category_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';

import 'package:isar/isar.dart';

import '../../Database/isar_cache_entry.dart';
import '../../Database/isar_service.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../Search/product_search_repository.dart';

const String categoryBoxName = 'categoryCache';
const String productBoxName = 'productCache';
const cacheDuration = Duration(hours: 12);

/// ✅ Offline-first Category Repository
/// - Loads cached data instantly for fast UI.
/// - Refreshes from API in background.
/// - Caches products + variations + tax + age restriction info.
class CategoryRepository {
  final APIHelper _helper = APIHelper();

  /// Load categories from cache first, then update from API
  Future<CategoryListResponse> getCategories({int parent = 0}) async {
    final cacheKey = "categories_$parent";

    // 🧠 Load cached categories instantly
    final isar = await IsarService.instance;
    final cached = await isar.isarCacheEntrys.where().keyEqualTo(cacheKey).findFirst();
    if (cached != null) {
      final List<dynamic> cachedList = json.decode(cached.json);
      if (kDebugMode) print("📦 Loaded cached categories (parent: $parent)");
      // 🔄 Refresh in background
      _updateCategoriesFromApi(parent);
      return CategoryListResponse.fromJson(cachedList);
    }

    // 🚀 No cache → fetch directly from API
    return await _getCategoriesFromApi(parent);
  }

  Future<void> _updateCategoriesFromApi(int parent) async {
    try {
      await _getCategoriesFromApi(parent);
      if (kDebugMode) print("✅ Categories updated in background");
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to refresh categories: $e");
    }
  }

  Future<CategoryListResponse> _getCategoriesFromApi(int parent) async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.categories}${EndUrlConstants.allCategoriesEndUrl}$parent";
    if (kDebugMode) print("🌍 Fetching categories: $url");

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("🧩 Category API Response (parent: $parent):");
      print(response);
    }

    List<dynamic> categoryList;
    if (response is String) {
      categoryList = json.decode(response);
    } else if (response is List) {
      categoryList = response;
    } else {
      throw Exception("Unexpected category response type");
    }

    final isar = await IsarService.instance;
    await isar.writeTxn(() async {
      await isar.isarCacheEntrys.put(
        IsarCacheEntry()
          ..key = "categories_$parent"
          ..json = json.encode(categoryList)
          ..timestamp = DateTime.now(),
      );
    });

    if (kDebugMode) print("💾 Cached categories (parent: $parent)");
    return CategoryListResponse.fromJson(categoryList);
  }


  /// Load products by category (offline-first)
  Future<CategoryProductListResponse> getProductsByCategory(int categoryId) async {
    final cacheKey = "products_$categoryId";

    final isar = await IsarService.instance;
    final cached = await isar.isarCacheEntrys.where().keyEqualTo(cacheKey).findFirst();

    if (cached != null) {
      if (kDebugMode) {
        print("🔍 RAW DATA FROM ISAR [$cacheKey] → ${cached.json.length} chars");

        //  Print full JSON data
        print(" FULL DATA:\n${cached.json}");
      }

      final List<dynamic> cachedList = json.decode(cached.json);

      print(" Loaded cached products (category: $categoryId)");

      _updateProductsFromApi(categoryId); // background refresh

      return CategoryProductListResponse.fromJson(cachedList);
    }

    //  No cache → fetch directly
    return await _getProductsFromApi(categoryId);
  }

  Future<void> _updateProductsFromApi(int categoryId) async {
    try {
      await _getProductsFromApi(categoryId);
      if (kDebugMode) print(" Products updated in background");
    } catch (e) {
      if (kDebugMode) print(" Failed to refresh products: $e");
    }
  }

  ///  Fetch products + normalize + cache (tax + age + variants)
  Future<CategoryProductListResponse> _getProductsFromApi(int categoryId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants
        .productByCategories}/$categoryId";
    if (kDebugMode) print("🌍 Fetching products: $url");

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("🧩 Raw Product API Response (category: $categoryId):");
      print(const JsonEncoder.withIndent('  ').convert(response));
    }

    List<dynamic> productList;

    if (response is String) {
      productList = json.decode(response);
    } else if (response is List) {
      productList = response;
    } else {
      throw Exception("Unexpected product response type");
    }

// 🚀 Normalize for UI immediately
    final normalizedProducts = productList.map((product) {
      final image = (product["image"] is Map && product["image"]["src"] != null)
          ? product["image"]["src"]
          : (product["image"] is String ? product["image"] : "");

      final name = (product["name"] is Map &&
          product["name"]["rendered"] != null)
          ? product["name"]["rendered"]
          : (product["name"] is String ? product["name"] : "Unnamed Product");

      final price = double.tryParse(product["price"]?.toString() ?? "0") ?? 0.0;

      final taxStatus = product["tax_status"] ?? "taxable";
      final taxClass = product["tax_class"] ?? "";

      final metaDiscountAuto = product["meta_data"]?.firstWhere(
            (m) => m["key"] == "_pinaka_discount_amount_auto_apply",
        orElse: () => {"value": "no"},
      )["value"];

      final metaDiscountAmount = product["meta_data"]?.firstWhere(
            (m) => m["key"] == "_discount_amount",
        orElse: () => {"value": 0},
      )["value"];

      final double discountAmount =
          double.tryParse(metaDiscountAmount.toString()) ?? 0.0;

      final bool autoApplyDiscount =
          metaDiscountAuto.toString().toLowerCase() == "yes";


      bool hasAgeRestriction = false;
      int minAge = 0;

      final metaAge = product["fast_key_item_min_age"] ??
          product["min_age"] ??
          product["meta_data"]?.firstWhere(
                (m) => m["key"] == "min_age",
            orElse: () => {"value": 0},
          )["value"];

      if (metaAge != null) {
        minAge = int.tryParse(metaAge.toString()) ?? 0;
      }
      if (minAge > 0) hasAgeRestriction = true;

      // Copy tags
      final List productTags = product["tags"] ?? [];

      final isEbtEligible = productTags.any((t) =>
      t["name"].toString().toLowerCase().contains("ebt") ||
          t["slug"].toString().toLowerCase().contains("ebt"));

      return {
        ...product,
        "fast_key_item_name": name,
        "fast_key_item_image": image,
        "fast_key_item_price": price,
        "fast_key_product_id": product["id"],
        "tags": productTags,
        "has_variants": product["variations"] != null &&
            (product["variations"] as List).isNotEmpty,
        "has_age_restriction": hasAgeRestriction,
        "min_age": minAge,
        "tax_status": taxStatus,
        "tax_class": taxClass,

        /// 🔥 ADD THIS
        "is_ebt_eligible": isEbtEligible,

        "auto_discount_enabled": autoApplyDiscount,
        "discount_amount": discountAmount,
      };

    }).toList();

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print("🔍 NORMALIZED PRODUCT DATA + EBT FLAG");
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    for (final p in normalizedProducts) {
      print("🟦 PRODUCT ID: ${p["fast_key_product_id"]}");
      print("   NAME: ${p["fast_key_item_name"]}");
      print("   TAGS: ${p["tags"]}");
      print("   EBT Eligible: ${p["is_ebt_eligible"]}");
      print("--------------------------------------------------");
    }



// 🔍 DEBUG: Print tags and EBT eligibility
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print("🔍 NORMALIZED PRODUCT TAG DUMP (Category: $categoryId)");
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    for (final p in normalizedProducts) {
      final pid = p["fast_key_product_id"];
      final pname = p["fast_key_item_name"];
      final tags = p["tags"] ?? [];

      final isEbtEligible = tags.any((t) =>
      t["name"].toString().toLowerCase().contains("ebt") ||
          t["slug"].toString().toLowerCase().contains("ebt"));

      print("🟦 PRODUCT → ID: $pid | NAME: $pname");
      print("     ➤ tags: $tags");
      print("     ➤ EBT Eligible: $isEbtEligible");
    }

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");




// Continue existing flow

    final categoryResponse = CategoryProductListResponse.fromJson(productList);
    unawaited(_cacheProductsAndVariations(
        categoryId, productList, normalizedProducts));
    return categoryResponse;
  }

  Future<void> _cacheProductsAndVariations(
      int categoryId,
      List<dynamic> productList,
      List<dynamic> normalizedProducts,
      ) async {

    final isar = await IsarService.instance;
    final cacheKey = "products_$categoryId";

    // 🔥 STEP 1: Read existing cached products
    final existingEntry = await isar.isarCacheEntrys
        .where()
        .keyEqualTo(cacheKey)
        .findFirst();

    Set<int> oldIds = {};
    if (existingEntry != null) {
      final List<dynamic> oldProducts = json.decode(existingEntry.json);
      oldIds = oldProducts
          .map((e) => e["fast_key_product_id"] as int)
          .toSet();
    }

    // 🔥 STEP 2: Collect new API product IDs
    final newIds = normalizedProducts
        .map((e) => e["fast_key_product_id"] as int)
        .toSet();

    // 🔥 STEP 3: Detect deleted products
    final deletedIds = oldIds.difference(newIds);

    if (deletedIds.isNotEmpty) {
      print("🗑️ Products deleted in backend → cleaning local cache: $deletedIds");

      final productCacheBox = StorageProvider.productCache;

      if (existingEntry != null) {
        final List<dynamic> oldProducts =
        json.decode(existingEntry.json);

        for (final deletedId in deletedIds) {
          try {
            final deletedProduct = oldProducts.firstWhere(
                  (p) => p["fast_key_product_id"] == deletedId,
              orElse: () => null,
            );

            if (deletedProduct != null) {
              final sku = deletedProduct["sku"];

              if (sku != null && sku.toString().isNotEmpty) {
                final normalizedSku =
                OrderHelper.normalizeSku(sku.toString());

                // 🔥 Remove SKU cache
                await productCacheBox.delete("sku_$normalizedSku");
                print("🗑️ Hive SKU removed → sku_$normalizedSku");

                // 🔥 Remove variation cache
                await productCacheBox.delete(
                    "product_${deletedId}_variations");

                print("🗑️ Variation cache removed → product_${deletedId}_variations");

                // 🔥 Remove from memory cache
                OrderHelper.removeFromCache(normalizedSku);
              }
            }
          } catch (e) {
            print("⚠️ Error cleaning deleted product $deletedId → $e");
          }
        }
      }
    }

    // 🔥 STEP 4: Overwrite cache with fresh API data
    await isar.writeTxn(() async {
      await isar.isarCacheEntrys.put(
        IsarCacheEntry()
          ..key = cacheKey
          ..json = json.encode(normalizedProducts)
          ..timestamp = DateTime.now(),
      );
    });

    if (kDebugMode) {
      print("💾 Cache synced for category $categoryId "
          "(Total: ${normalizedProducts.length})");
    }

    // ============================================================
    // 🔽 KEEP YOUR EXISTING VARIATION CACHING LOGIC BELOW
    // ============================================================

    final productRepo = ProductRepository();
    final productCacheBox = StorageProvider.productCache;

    for (final product in productList) {
      final productId = product['id'];
      final hasEmbeddedVariants =
          product['variations'] != null &&
              product['variations'].isNotEmpty;

      final parentMinAge = product["fast_key_item_min_age"] ??
          product["min_age"] ??
          product["meta_data"]?.firstWhere(
                (m) => m["key"] == "min_age",
            orElse: () => {"value": 0},
          )["value"] ??
          0;

      if (hasEmbeddedVariants) {
        final variations = product['variations'] as List;

        final normalized = variations
            .whereType<Map>()
            .map<Map<String, dynamic>>((v) {
          final image = (v["image"] is Map &&
              v["image"]["src"] != null)
              ? v["image"]["src"]
              : (v["image"] is String ? v["image"] : "");

          final name = (v["name"] is Map &&
              v["name"]["rendered"] != null)
              ? v["name"]["rendered"]
              : (v["name"] is String ? v["name"] : "Unnamed Variant");

          final price = v["price"]?.toString() ?? "0";

          final varMinAge = v["min_age"] ??
              v["fast_key_item_min_age"] ??
              parentMinAge ??
              0;

          final varHasAgeRestriction =
              varMinAge != null &&
                  (int.tryParse(varMinAge.toString()) ?? 0) > 0;

          return {
            "id": v["id"],
            "name": name,
            "price": price,
            "sku": v["sku"] ?? "",
            "image": image,
            "has_age_restriction": varHasAgeRestriction,
            "min_age": int.tryParse(varMinAge.toString()) ?? 0,
          };
        }).toList();

        if (normalized.isNotEmpty) {
          await productCacheBox.put(
            "product_${productId}_variations",
            {
              'variations': normalized,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      } else {
        try {
          await productRepo.fetchProductVariations(productId);
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ Failed to fetch variations for product $productId: $e");
          }
        }
      }
    }
  }
  /////

  // Future<List<dynamic>> getAllCachedProducts() async {
  //   final isar = await IsarService.instance;
  //
  //   final cachedEntries = await isar.isarCacheEntrys
  //       .where()
  //       .filter()
  //       .keyStartsWith("products_")
  //       .findAll();
  //
  //   final Map<int, dynamic> uniqueProducts = {};
  //
  //   for (final entry in cachedEntries) {
  //     final List<dynamic> products = json.decode(entry.json);
  //
  //     for (final product in products) {
  //       final int productId = product["fast_key_product_id"];
  //       uniqueProducts[productId] = product; // de-duplicate
  //     }
  //   }
  //
  //   if (kDebugMode) {
  //     print("🔍 Loaded ${uniqueProducts.length} unique products from cache");
  //   }
  //
  //   return uniqueProducts.values.toList();
  // }


  Future<List<dynamic>> getAllCachedProducts() async {
    final isar = await IsarService.instance;

    final cachedEntries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith("products_")
        .findAll();

    final Map<int, dynamic> uniqueProducts = {};

    for (final entry in cachedEntries) {
      final List<dynamic> products = json.decode(entry.json);

      for (final product in products) {
        final int? productId = product["fast_key_product_id"];

        if (productId == null) continue;

        // 🔒 Deduplicate here
        uniqueProducts.putIfAbsent(productId, () => product);
      }
    }

    if (kDebugMode) {
      print("✅ Global cache loaded: ${uniqueProducts.length} unique products");
    }

    return uniqueProducts.values.toList();
  }


}