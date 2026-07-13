import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar_community/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:pinaka_pos/Helper/auto_search.dart';
import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
import 'package:pinaka_pos/Widgets/widget_age_verification_popup_dialog.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Search/product_variation_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Providers/Auth/product_variation_provider.dart';
import '../Database/isar_service.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/shimmer_effect.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../Utilities/svg_images_utility.dart';
import 'ManualPriceDialog.dart';
import 'OrderPopupHelper.dart';
import 'widget_logs_toast.dart';

class NestedGridWidget extends StatelessWidget {
  final bool isHorizontal;
  final bool isLoading;
  final bool showAddButton;
  final bool showBackButton; // New property to show "Back to Categories" button
  final List<Map<String, dynamic>> items;
  final int? selectedItemIndex;
  final List<int?> reorderedIndices;
  final VoidCallback? onAddButtonPressed;
  final VoidCallback? onBackButtonPressed; // Callback for "Back to Categories"
  final Function(int, {bool variantAdded})
  onItemTapped; // Update the callback to accept a named parameter
  final Function(int, int) onReorder;
  final Function(int) onDeleteItem;
  final bool showDeleteButton;
  final Function() onCancelReorder;
  final bool? enableIcons; // Build #1.0.204: Added this
  final Function(int)? onLongPress; // Added this
  final ProductBloc? productBloc; //Build 1.1.36
  final OrderBloc? orderBloc;
  final OrderHelper orderHelper;
  final bool isPaginating;



  static final Map<int, Map<String, dynamic>> _productMetaCache = {};
  static bool _productMetaInitialized = false;
  // Avoid repeated variant API refresh calls for the same product
  // when users switch categories and tap the same item again.
  static final Set<int> _variantRefreshAttempted = <int>{};
  static bool _productTapInFlight = false;

  const NestedGridWidget({
    super.key,
    required this.isHorizontal,
    required this.isLoading,
    required this.showAddButton,
    required this.showBackButton,
    required this.items,
    this.selectedItemIndex,
    required this.reorderedIndices,
    this.onAddButtonPressed,
    this.onBackButtonPressed,
    required this.onItemTapped,
    required this.onReorder,
    required this.onDeleteItem,
    this.showDeleteButton = true,
    required this.onCancelReorder,
    this.enableIcons,
    this.onLongPress,
    this.productBloc,
    this.orderBloc,
    required this.orderHelper,
    required this.isPaginating,
  });

  // Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
  //   if (_productMetaCache.isNotEmpty) {
  //     return _productMetaCache[productId];
  //   }
  //
  //   try {
  //     final isar = await IsarService.instance;
  //     final entries = await isar.isarCacheEntrys.where().findAll();
  //
  //     for (final entry in entries) {
  //       if (!entry.key.startsWith("products_")) continue;
  //
  //       final List<dynamic> products = jsonDecode(entry.json);
  //
  //       for (final raw in products) {
  //         if (raw is! Map) continue;
  //         final map = Map<String, dynamic>.from(raw);
  //         final idStr =
  //         (map["fast_key_product_id"] ?? map["id"])?.toString();
  //         final pid = int.tryParse(idStr ?? "");
  //         if (pid != null) {
  //           _productMetaCache[pid] = map;
  //         }
  //       }
  //     }
  //
  //     return _productMetaCache[productId];
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print("⚠️ Isar cache lookup failed → $e");
  //     }
  //   }
  //   return null;
  // }

  static void clearProductMetaCache() {
    _productMetaCache.clear();
  }

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
    if (_productMetaCache.containsKey(productId)) {   // was: isNotEmpty
      return _productMetaCache[productId];
    }

    try {
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      for (final entry in entries) {
        if (!entry.key.startsWith("products_")) continue;
        final List<dynamic> products = jsonDecode(entry.json);
        for (final raw in products) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final idStr = (map["fast_key_product_id"] ?? map["id"])?.toString();
          final pid = int.tryParse(idStr ?? "");
          if (pid != null) {
            _productMetaCache[pid] = map;
          }
        }
      }
      return _productMetaCache[productId];
    } catch (e) {
      if (kDebugMode) print("⚠️ Isar cache lookup failed → $e");
    }
    return null;
  }

  Future<bool> _fastKeyHasVariants(Map<String, dynamic> item) async {
    final int? productId =
    int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    if (productId == null) return false;

    // 1️⃣ Fast item-level check
    if (item["type"] == "variable") return true;
    if (item["variations"] is List && item["variations"].isNotEmpty) return true;

    // 2️⃣ Check product meta cache
    final cached = await _getCachedProductFromIsar(productId);

    if (cached?["type"] == "variable") return true;
    if (cached?["has_variants"] == true) return true;

    // 3️⃣ 🔥 CHECK VARIATION CACHE (THIS WAS MISSING)
    try {
      final box = StorageProvider.productCache;
      final variationKey = "product_${productId}_variations";
      final variationData = await box.get(variationKey);

      if (variationData is Map &&
          variationData["variations"] is List &&
          (variationData["variations"] as List).isNotEmpty) {
        return true;
      }

      if (variationData is List && variationData.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  bool _isProductEbtEligible(Map<String, dynamic> item) {
    if (item["is_ebt_eligible"] == true) return true;

    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("ebt") || slug.contains("ebt")) return true;
        }
      }
    }

    return false;
  }

  bool _isVariableProduct(Map<String, dynamic> item) {
    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    if (tagsRaw is List) {
      return tagsRaw.any((t) {
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          return name.contains("variable") || slug.contains("variable");
        }
        return false;
      });
    }
    return false;
  }


  Widget _buildImage(String imagePath) {
    final imageWidget = imagePath.startsWith("http")
        ? SizedBox(
      width: 75,
      height: 75,
      child: Image.network(
        imagePath,
        width: 75,
        height: 75,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 75,
            height: 75,
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      ),
    )
        : Platform.isWindows
        ? Image.asset(
      'assets/default.png',
      height: 75,
      width: 75,
    )
        : Image.file(
      File(imagePath),
      width: 75,
      height: 75,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 75,
          height: 75,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount =
        (showAddButton ? 1 : 0) + (showBackButton ? 1 : 0) + items.length;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Colors.white,
        ),
        child: Stack(
          children: [
            /// 🔹 GRID
            isLoading
                ? ShimmerEffect.rectangular(height: 900)
                : ReorderableGridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: totalCount,
              dragEnabled: Misc
                  .enableReordering, // Build #1.0.204: Disable Re-Order for grid & Added this line to control drag functionality
              onReorder: Misc.enableReordering
                  ? onReorder
                  : (oldIndex,
                  newIndex) {}, // Disable reorder callback if not enabled
              itemBuilder: (context, index) {
                // Handle "Add" button if enabled
                if (showAddButton && index == 0) {
                  return Container(
                    key: const ValueKey('add_button'),
                    child: GestureDetector(
                      onTap: onAddButtonPressed ?? () {},
                      child: _getCardWidget(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add,
                                  size: 40, color: Color(0xFFFE6464)),
                              //SizedBox(height: 2),
                              Text(TextConstants.addProductText,
                                  style:
                                  TextStyle(color: Color(0xFFFE6464))),
                            ],
                          ),
                          themeHelper,
                          accentColor: Colors.redAccent),
                    ),
                  );
                }



                // Handle "Back to Categories" button if enabled
                if (showBackButton && index == (showAddButton ? 1 : 0)) {
                  return Container(
                    key: const ValueKey('back_button'),
                    child: GestureDetector(
                      onTap: onBackButtonPressed ?? () {},
                      child: _getCardWidget(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.arrow_back,
                                  size: 50, color: Colors.blue),
                              SizedBox(height: 5),
                              Text(TextConstants.backToCategories,
                                  style: TextStyle(color: Colors.blue)),
                            ],
                          ),
                          themeHelper),
                    ),
                  );
                }


                // Adjust the index based on the presence of "Add" and "Back" buttons
                final itemIndex = index -
                    (showAddButton ? 1 : 0) -
                    (showBackButton ? 1 : 0);
                if (itemIndex < 0 || itemIndex >= items.length) {
                  return const SizedBox.shrink();
                }

                final isReordered = reorderedIndices.isNotEmpty &&
                    reorderedIndices[itemIndex] != null;
                final item = items[itemIndex];
                final bool showEbtTag =
                    item['is_ebt_eligible'] == true || _isProductEbtEligible(item);


                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: isReordered
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  key: ValueKey(
                      'grid_item_${itemIndex}_${item["fast_key_item_name"]}'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          // if (orderHelper?.activeOrderId == null) {
                          //   print("⛔ No active order → Show popup and block product adding");
                          //
                          //   await OrderPopupHelper.showNoOrderPopup(context);
                          //
                          //   return; // 🚫 STOP item adding
                          // }
                          if (_productTapInFlight) return;
                          _productTapInFlight = true;

                          try {
                            final orderId = await orderHelper.ensureOrderExists();

                            if (orderId == null) {
                              final msg = OrderHelper.lastEnsureOrderError ??
                                  "Failed to create or restore order. Please try again.";
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                              return;
                            }

                            print("🆔 Active Order ID (ensured): $orderId");

                            print("🟩 TAP: Starting product add flow for item → ${item["fast_key_item_name"]}");

                            // 🧠 Hydrate from Isar cache (same flow as category load)
                            final productId =
                                int.tryParse(item["fast_key_product_id"].toString()) ?? -1;
                            final cachedProduct =
                            productId > 0 ? await _getCachedProductFromIsar(productId) : null;

                            // 🏷 Collect tags from item first, then from cache
                            final List<Map<String, dynamic>> tags = [];
                            void addTags(dynamic source) {
                              if (source is List) {
                                for (final t in source) {
                                  if (t is Map) {
                                    tags.add(Map<String, dynamic>.from(t));
                                  }
                                }
                              }
                            }

                            addTags(item["fast_key_item_tags"]);
                            if (tags.isEmpty) {
                              addTags(cachedProduct?["tags"]);
                            }

                            // ✅ DECLARE HERE (VERY IMPORTANT)
                            bool hasVariablePriceTag = tags.any((t) {
                              final slug = (t["slug"] ?? "").toString().toLowerCase();
                              final name = (t["name"] ?? "").toString().toLowerCase();
                              return slug.contains("variable") || name.contains("variable");
                            });

                            if (kDebugMode) {
                              print("🧪 hasVariablePriceTag = $hasVariablePriceTag");
                            }

                            // 🆔 Extract core product fields
                            final productName = (item["fast_key_item_name"] is String)
                                ? item["fast_key_item_name"]
                                : item["fast_key_item_name"]?["rendered"] ?? "Unnamed Product";

                            // ⭐ EBT eligibility from Isar cache or tags
                            bool isEbtEligible =
                                item["is_ebt_eligible"] == true || cachedProduct?["is_ebt_eligible"] == true;

                            if (!isEbtEligible && tags.isNotEmpty) {
                              isEbtEligible = tags.any((t) {
                                final name = (t["name"] ?? "").toString().toLowerCase();
                                final slug = (t["slug"] ?? "").toString().toLowerCase();
                                return name.contains("ebt") || slug.contains("ebt");
                              });
                            }

                            if (kDebugMode) {
                              print(
                                  "🥗 EBT CHECK → Product: $productName | Eligible: $isEbtEligible | Cached=${cachedProduct != null}");
                            }
                            final dynamic priceSource = item["fast_key_item_price"] ??
                                item["price"] ??
                                cachedProduct?["fast_key_item_price"] ??
                                cachedProduct?["price"];
                            var productPrice =
                                double.tryParse(priceSource?.toString() ?? "0") ?? 0.0;

                            if (kDebugMode) {
                              final itemPrice = item["fast_key_item_price"] ?? item["price"];
                              final cachedPrice = cachedProduct?["fast_key_item_price"] ?? cachedProduct?["price"];
                              print("💰 PRICE SOURCE → Item: $itemPrice | Cached: $cachedPrice | Final: $productPrice");
                            }

                            final productSku =
                                cachedProduct?["sku"] ?? item["fast_key_item_sku"] ?? "SKU-$productId";

                            final dynamic rawImage =
                                cachedProduct?["fast_key_item_image"] ??
                                    cachedProduct?["image"] ??
                                    item["fast_key_item_image"];
                            final productImage = rawImage is String
                                ? rawImage
                                : (rawImage is Map ? rawImage["src"] ?? "" : "");

                            // ✅ Detect variants & restrictions
                            final hasVariants = (cachedProduct?["has_variants"] == true) ||
                                (item["type"] == "variable" ||
                                    (item["variations"] != null && item["variations"].isNotEmpty));

                            // 🔞 Detect min age (field OR tags)
                            final dynamic minAgeSource =
                                cachedProduct?["min_age"] ?? item["fast_key_item_min_age"];
                            int minAge =
                                int.tryParse(minAgeSource?.toString() ?? "0") ?? 0;

// ✅ FALLBACK → derive from tags (VERY IMPORTANT)
                            if (minAge == 0) {
                              for (final t in tags) {
                                final name = (t["name"] ?? "").toString().toLowerCase();
                                final slug = (t["slug"] ?? "").toString();

                                if (name.contains("age") || name.contains("restricted")) {
                                  final parsedAge = int.tryParse(slug);
                                  if (parsedAge != null && parsedAge > 0) {
                                    minAge = parsedAge;
                                    break;
                                  }
                                  minAge = 18;
                                  break;
                                }
                              }
                            }

                            final bool hasAgeRestriction = minAge > 0;

                            if (kDebugMode) {
                              print("🔞 Age detection → hasAgeRestriction=$hasAgeRestriction, minAge=$minAge");
                            }

                            int loyaltyPoints = 0;
                            List<Map<String, dynamic>> resolvedMetaData = [];

// ✅ 1️⃣ PRIMARY SOURCE: Isar cache (products_<categoryId>) — matches your dump
                            if (cachedProduct?['meta_data'] is List) {
                              resolvedMetaData = (cachedProduct!['meta_data'] as List)
                                  .whereType<Map>()
                                  .map((m) => Map<String, dynamic>.from(m))
                                  .toList();

                              for (final m in resolvedMetaData) {
                                if (m['key'] == '_product_loyalty_points') {
                                  loyaltyPoints = int.tryParse(m['value']?.toString() ?? '0') ?? 0;
                                  break;
                                }
                              }

                              if (loyaltyPoints > 0) {
                                print("🎯 LOYALTY POINTS [ISAR CACHE] → $productName (id:$productId) = $loyaltyPoints pts");
                              }
                            }

// ✅ 2️⃣ FALLBACK: item's own meta_data (only if Isar had nothing)
                            if (loyaltyPoints == 0 && item['meta_data'] is List) {
                              final itemMeta = (item['meta_data'] as List)
                                  .whereType<Map>()
                                  .map((m) => Map<String, dynamic>.from(m))
                                  .toList();

                              for (final m in itemMeta) {
                                if (m['key'] == '_product_loyalty_points') {
                                  loyaltyPoints = int.tryParse(m['value']?.toString() ?? '0') ?? 0;
                                  break;
                                }
                              }

                              if (resolvedMetaData.isEmpty) resolvedMetaData = itemMeta;

                              if (loyaltyPoints > 0) {
                                print("🎯 LOYALTY POINTS [ITEM FALLBACK] → $productName (id:$productId) = $loyaltyPoints pts");
                              }
                            }

                            if (loyaltyPoints == 0) {
                              print("⚠️ LOYALTY POINTS NOT FOUND for $productName (id:$productId) — cachedProduct meta_data: ${cachedProduct?['meta_data']}, item meta_data: ${item['meta_data']}");
                            }

                            print("🎯 FINAL LOYALTY POINTS → $productName: $loyaltyPoints pts | metaEntries: ${resolvedMetaData.length}");
                            print(
                                "🔍 Product details: id=$productId, name=$productName, price=$productPrice, hasVariants=$hasVariants, hasAgeRestriction=$hasAgeRestriction, minAge=$minAge");

                            // 🧠 Init or restore offline order
                            final box = StorageProvider.offlineOrders;
                            int activeOrderId =
                                orderHelper.activeOrderId ?? (await box.get('lastOrderId')) ?? 1000;

                            if (orderHelper.activeOrderId == null) {
                              orderHelper.activeOrderId = activeOrderId;
                              await box.put('lastOrderId', activeOrderId);
                            }

                            print("🆔 Active Order ID: $activeOrderId");

                            // 🔞 Age Verification Flow
                            if (hasAgeRestriction && minAge > 0) {
                              print("🔞 Age restriction detected → Checking verification for order $activeOrderId...");
                              // Use SAME age key as barcode scan flow
                              // Use SAME age key as barcode scan flow
                              final orderKey = activeOrderId.toString();
                              final rawOrder = await box.get(orderKey);
                              final hiveOrder = Map<String, dynamic>.from(
                                rawOrder is Map ? rawOrder : {},
                              );

                              final alreadyVerified =
                                  hiveOrder["age_verified"] == true ||
                                      hiveOrder["age_verified"] == 1 ||
                                      hiveOrder["age_verified"]?.toString().toLowerCase() == "true";

                              if (alreadyVerified) {
                                print("✅ Age already verified → Skipping popup (Unified).");
                              } else {
                                print("🔞 Showing Age Verification Popup (Unified)");

                                // FIX → create provider
                                final prov = AgeVerificationProvider();

                                final isVerified =
                                await prov.verifyAge(context, minAge: minAge);

                                if (!isVerified) {
                                  print("❌ Age verification failed → Product blocked");
                                  return;
                                }

                                // SAVE SUCCESS FLAG
                                hiveOrder["age_verified"] = true;
                                await box.put(orderKey, hiveOrder);

                                print("💾 Saved age_verified = TRUE for order $orderKey");
                              }

                            } else {
                              print("✅ No age restriction for this product.");

                            }


                            //  PRODUCE (WEIGHED ITEMS) HANDLING
                            final bool hasProduceTag = tags.any((t) {
                              final slug = (t["slug"] ?? "").toString().toLowerCase();
                              final name = (t["name"] ?? "").toString().toLowerCase();
                              return slug.contains("produce") || name.contains("produce");
                            });

                            // if (hasProduceTag) {
                            //   print(" Produce product detected → Showing AutoWeightPriceDialog");
                            //
                            //   // Show AutoWeightPriceDialog
                            //   final result = await showDialog(
                            //     context: context,
                            //     barrierDismissible: false,
                            //     builder: (_) => AutoWeightPriceDialog(
                            //       productName: productName,
                            //       unitPrice: productPrice,
                            //     ),
                            //   );
                            //
                            //   if (result == null) {
                            //     print(" Auto weight cancelled");
                            //     return;
                            //   }
                            //
                            //   final double finalPrice = result["finalPrice"];
                            //   final double weight = result["weight"];
                            //
                            //   print(" Weight: ${weight}kg, Final Price: ₹$finalPrice");
                            //
                            //   await orderHelper.addItemToOrder(
                            //     null,
                            //     productName,
                            //     productImage,
                            //     finalPrice,
                            //     1, // quantity is 1 since weight determines the amount
                            //     productSku,
                            //     activeOrderId,
                            //     type: 'weighted', // Use a special type for weighed items
                            //     productId: productId,
                            //     variationId: -1,
                            //     salesPrice: finalPrice,
                            //     regularPrice: productPrice,
                            //     unitPrice: productPrice,
                            //     isEbtEligible: isEbtEligible,
                            //     // You might want to store weight info in metadata
                            //     // metaData: {
                            //     //   'weight': weight,
                            //     //   'unit': 'kg',
                            //     // },
                            //     // metaData: item['meta_data'] is List
                            //     //     ? List<Map<String, dynamic>>.from(item['meta_data'])
                            //     //     : null,
                            //     metaData: resolvedMetaData.isNotEmpty ? resolvedMetaData : null,
                            //     loyaltyPoints: loyaltyPoints,
                            //     onItemAdded: () async {
                            //       print(" Weighted product added successfully!");
                            //       print("$item['loyalty_points']");
                            //       onItemTapped(index, variantAdded: false);
                            //     },
                            //   );
                            //
                            //
                            //   return; //  IMPORTANT: Stop further processing
                            // }




// 💰 Variable Price (Manual Entry)
                            // 💰 Variable Price (Manual Entry)
                            double finalPrice = productPrice;

// RUN THIS BEFORE ANY POPUP
                            if (hasVariablePriceTag && !hasVariants) {
                              print("💰 Variable price product detected → Checking global first-add status…");

                              final orderKey = activeOrderId.toString();
                              final rawOrder = await box.get(orderKey);
                              final hiveOrder = Map<String, dynamic>.from(
                                rawOrder is Map ? rawOrder : {},
                              );

                              final variableKey = "variable_price_added_$productId";
                              final savedPriceKey = "selected_price_$productId";
                              final savedPrice = hiveOrder[savedPriceKey];

                              if (savedPrice != null) {
                                print("🔁 Auto-loading saved manual price for productId=$productId → ₹$savedPrice");
                                productPrice = savedPrice; // <-- FORCE OVERRIDE DEFAULT PRICE
                              }

                              // ⛔ GLOBAL CHECK: Has popup been shown before?
                              final alreadyAddedBefore =
                                  hiveOrder[variableKey] == true ||
                                      hiveOrder[variableKey] == 1 ||
                                      hiveOrder[variableKey]?.toString().toLowerCase() == "true";

                              // -------------------------------------------------------------
                              //1️⃣ PRODUCT ADDED BEFORE → SKIP POPUP ALWAYS
                              // -------------------------------------------------------------
                              if (alreadyAddedBefore) {
                                print("🔁 Variable product already added earlier → SKIPPING POPUP → increment quantity");

                                // Load saved manual price
                                final savedPrice = hiveOrder[savedPriceKey];
                                finalPrice = savedPrice ?? productPrice;

                                await orderHelper.addItemToOrder(
                                  null,
                                  productName,
                                  productImage,
                                  finalPrice,
                                  1,
                                  productSku,
                                  activeOrderId,
                                  type: 'product',
                                  productId: productId,
                                  variationId: -1,
                                  salesPrice: finalPrice,
                                  regularPrice: finalPrice,
                                  unitPrice: finalPrice,
                                  isEbtEligible: isEbtEligible,
                                  // metaData: item['meta_data'] is List
                                  //     ? List<Map<String, dynamic>>.from(item['meta_data'])
                                  //     : null,
                                  // loyaltyPoints: loyaltyPoints,
                                  metaData: resolvedMetaData.isNotEmpty ? resolvedMetaData : null,
                                  loyaltyPoints: loyaltyPoints,
                                  onItemAdded: () async {
                                    //await orderHelper.loadData();
                                  },
                                );


                                onItemTapped(index, variantAdded: false);
                                return; // ⛔ VERY IMPORTANT — stop popup here
                              }

                              // -------------------------------------------------------------
                              // 2️⃣ FIRST TIME EVER → SHOW POPUP
                              // -------------------------------------------------------------
                              print("💰 First-time variable product → showing manual price popup");

                              final enteredPrice = await ManualPriceDialog.show(
                                context,
                                productName: productName,
                                productImage: productImage,
                                minPrice: productPrice,
                              );

                              if (enteredPrice == null) {
                                print("❌ Manual price cancelled");
                                return;
                              }

                              finalPrice = enteredPrice;

                              // SAVE FLAGS
                              hiveOrder[variableKey] = true;       // mark popup shown
                              hiveOrder[savedPriceKey] = finalPrice; // store price

                              await box.put(orderKey, hiveOrder);

                              print("💾 Stored $variableKey = true");
                              print("💾 Stored $savedPriceKey = $finalPrice");
                            }

                            // 🧩 Variant Handling
                            if (hasVariants) {
                              if (kDebugMode) {
                                print("🧩 Product has variants → Loading offline variants...");
                              }
                              // Show loading immediately for instant feedback
                              bool loadingDialogShown = false;
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => PopScope(
                                    canPop: false,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                                loadingDialogShown = true;
                              }

                              List<Map<String, dynamic>> offlineVariations = [];

                              try {
                                final productBox = StorageProvider.productCache;
                                final cacheKey = "product_${productId}_variations";
                                final cachedData = await productBox.get(cacheKey);
                                if (kDebugMode) {
                                  print("📦 Checking cachedData for key=$cacheKey");
                                }

                                List rawVariations = [];

                                // 🔹 Try cached data
                                if (cachedData != null) {
                                  if (cachedData is Map && cachedData["variations"] is List) {
                                    rawVariations = cachedData["variations"];
                                  } else if (cachedData is List) {
                                    rawVariations = cachedData;
                                  } else if (cachedData is String) {
                                    try {
                                      final decoded = jsonDecode(cachedData);
                                      rawVariations =
                                      decoded is Map ? decoded["variations"] ?? [] : decoded;
                                    } catch (_) {
                                      if (kDebugMode) {
                                        print("⚠️ Error decoding cachedData string");
                                      }
                                    }
                                  }
                                }

                                // 🩵 Fallback: Try item["variations"] if cache is empty (parallel lookups)
                                if (rawVariations.isEmpty && item["variations"] != null) {
                                  final variationIds = item["variations"] as List;
                                  final results = await Future.wait(
                                    variationIds.map((id) => productBox.get("product_$id")),
                                  );
                                  for (var i = 0; i < variationIds.length; i++) {
                                    final id = variationIds[i];
                                    var variantData = results[i];

                                    if (variantData == null) {
                                      if (kDebugMode) {
                                        print("⚠️ No cache found for variant id=$id, using fallback");
                                      }
                                      continue;
                                    }

                                    if (variantData is String) {
                                      try {
                                        variantData = jsonDecode(variantData);
                                      } catch (_) {}
                                    }

                                    String name = "";
                                    if (variantData?["name"] != null &&
                                        variantData["name"].toString().isNotEmpty) {
                                      name = variantData["name"];
                                    } else if (variantData?["attributes"] != null &&
                                        variantData["attributes"] is List &&
                                        (variantData["attributes"] as List).isNotEmpty) {
                                      name = (variantData["attributes"] as List)
                                          .map((a) => a["option"] ?? "")
                                          .where((o) => o.toString().isNotEmpty)
                                          .join(", ");
                                    } else {
                                      name = "Variant $id";
                                    }

                                    final price = (variantData?["price"] ??
                                        variantData?["regular_price"] ??
                                        variantData?["sale_price"] ??
                                        productPrice)
                                        .toString();

                                    final image = (variantData?["image"] is Map)
                                        ? variantData["image"]["src"] ?? productImage
                                        : (variantData?["image"] ?? productImage);

                                    rawVariations.add({
                                      "id": id,
                                      "name": name,
                                      "price": price,
                                      "sku": variantData?["sku"] ?? "",
                                      "image": image,
                                    });
                                  }

                                  if (kDebugMode) {
                                    print("📥 Built ${rawVariations.length} variant objects manually.");
                                  }
                                }

                                // 🧠 Normalize all variants
                                offlineVariations = rawVariations.map<Map<String, dynamic>>((v) {
                                  if (v is String) {
                                    try {
                                      v = jsonDecode(v);
                                    } catch (_) {}
                                  }
                                  if (v is Map) {
                                    final map =
                                    v.map((key, value) => MapEntry(key.toString(), value));

                                    map["image"] = (map["image"] is Map && map["image"]["src"] != null)
                                        ? map["image"]["src"]
                                        : (map["image"] is String ? map["image"] : "");
                                    map["name"] = (map["name"] is Map &&
                                        map["name"]["rendered"] != null)
                                        ? map["name"]["rendered"]
                                        : (map["name"] is String
                                        ? map["name"]
                                        : "Unnamed Variant");
                                    map["price"] = map["price"]?.toString() ?? "0";
                                    return map;
                                  }
                                  return <String, dynamic>{};
                                }).where((v) => v.isNotEmpty).toList();

                                if (kDebugMode) {
                                  print("✅ Found ${offlineVariations.length} offline variants.");
                                }

                                // 🧩 Auto-refetch if variants are incomplete
                                final allSameAsParent = offlineVariations.isEmpty ||
                                    offlineVariations
                                        .every((v) => v["price"].toString() == productPrice.toString());

                                if (allSameAsParent &&
                                    !_variantRefreshAttempted.contains(productId)) {
                                  _variantRefreshAttempted.add(productId);
                                  print("🔁 Cached variants incomplete → Refetching from API...");
                                  await ProductRepository().fetchProductVariations(productId);

                                  final refreshed = await productBox.get(cacheKey);
                                  if (refreshed is Map && refreshed["variations"] is List) {
                                    offlineVariations = (refreshed["variations"] as List)
                                        .map((v) => Map<String, dynamic>.from(v as Map))
                                        .toList();
                                  }
                                } else if (allSameAsParent && kDebugMode) {
                                  print(
                                      "⏭️ Skipping repeated variant refetch for productId=$productId");
                                }
                              } catch (e, st) {
                                if (kDebugMode) {
                                  print("⚠️ Error decoding offline variations: $e");
                                  print(st);
                                }
                              }

                              // Dismiss loading dialog before showing VariantsDialog
                              if (context.mounted && loadingDialogShown) {
                                Navigator.of(context, rootNavigator: true).pop();
                              }

                              // 🪟 Show VariantsDialog
                              if (kDebugMode) {
                                print("🪟 Showing VariantsDialog for $productName...");
                              }
                              await showDialog(
                                context: context,
                                builder: (ctx) => VariantsDialog(
                                  title: productName,
                                  variations: offlineVariations,
                                  onAddVariant: (selectedVariant, qty) async {
                                    final variantId =
                                        int.tryParse(selectedVariant["id"].toString()) ?? -1;
                                    final variantName =
                                        selectedVariant["name"] ?? "Variant";
                                    final variantPrice =
                                        double.tryParse(selectedVariant["price"].toString()) ??
                                            productPrice;
                                    final variantSku =
                                        selectedVariant["sku"] ?? productSku;
                                    final variantImage =
                                        selectedVariant["image"] ?? productImage;

                                    print(
                                        "🧾 Adding variant → id:$variantId, name:$variantName, price:$variantPrice, qty:$qty");

                                    await orderHelper.addItemToOrder(
                                      0,
                                      "$variantName",
                                      variantImage,
                                      variantPrice,
                                      qty,
                                      variantSku,
                                      activeOrderId,
                                      type: 'variant',
                                      productId: productId,
                                      variationId: variantId,
                                      variationName: variantName,
                                      salesPrice: variantPrice,
                                      regularPrice: variantPrice,
                                      unitPrice: variantPrice,

                                      /// 🔥 ADD THIS
                                      isEbtEligible: isEbtEligible,
                                      // metaData: item['meta_data'] is List
                                      //     ? List<Map<String, dynamic>>.from(item['meta_data'])
                                      //     : null,
                                      // loyaltyPoints: loyaltyPoints,
                                      metaData: resolvedMetaData.isNotEmpty ? resolvedMetaData : null,
                                      loyaltyPoints: loyaltyPoints,

                                      onItemAdded: () async {
                                        print("✅ Variant item added successfully!");
                                        onItemTapped(index, variantAdded: true);
                                        //await orderHelper.loadData();
                                      },
                                    );

                                  },
                                ),
                              );
                              print("🪟 VariantsDialog closed for $productName");
                            } else {
                              // 🟩 Simple Product
                              print("🟩 Simple product, adding directly...");
                              await orderHelper.addItemToOrder(
                                null,               // ✅ serverItemId
                                productName,        // ✅ name
                                productImage,       // ✅ image
                                finalPrice,         // ✅ price (manual or default)
                                1,                  // ✅ quantity
                                productSku,         // ✅ sku
                                activeOrderId,      // ✅ orderId
                                type: 'product',
                                productId: productId,
                                variationId: -1,
                                salesPrice: finalPrice,
                                regularPrice: finalPrice,
                                unitPrice: finalPrice,
                                isEbtEligible: isEbtEligible,
                                // metaData: item['meta_data'] is List
                                //     ? List<Map<String, dynamic>>.from(item['meta_data'])
                                //     : null,
                                // loyaltyPoints: loyaltyPoints,
                                metaData: resolvedMetaData.isNotEmpty ? resolvedMetaData : null,
                                loyaltyPoints: loyaltyPoints,
                                onItemAdded: () async {
                                  print("✅ Simple product added successfully!");
                                  print("print : $loyaltyPoints");
                                  onItemTapped(index, variantAdded: false);
                                  //await orderHelper.loadData();
                                },
                              );
                            }

                            print("🎉 Product flow completed for → $productName");
                          } catch (e, s) {
                            print("❌ ERROR in offline onTap: $e");
                            print(s);
                          } finally {
                            _productTapInFlight = false;
                          }
                        },
                        onLongPress: () {
                          if (onLongPress != null) {
                            // Build #1.0.204
                            onLongPress!(
                                itemIndex); // Safe to use ! since we checked for null
                            if (kDebugMode) {
                              print("### TEST onLongPress");
                            }
                          } else {
                            if (kDebugMode) {
                              print("### onLongPress is null, skipping");
                            }
                          }
                        },
                        child: _getCardWidget(
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                children: [
                                  //_buildImage(item["fast_key_item_image"]),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                      children: [
                                        Text(
                                          item["fast_key_item_name"],
                                          style: TextStyle(
                                            fontSize: 12,

                                            fontWeight: FontWeight.bold,
                                            color: themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.textDark
                                                : ThemeNotifier.textLight,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: true,
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${TextConstants.currencySymbol}${double.tryParse(item["fast_key_item_price"].toString())?.toStringAsFixed(2) ?? "0.00"}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: themeHelper
                                                    .themeMode ==
                                                    ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : ThemeNotifier
                                                    .textLight,
                                              ),
                                            ),
                                            const SizedBox(
                                                width:
                                                16), // Space between price and variations
                                            //
                                            // FutureBuilder<bool>(
                                            //   future: _fastKeyHasVariants(item),
                                            //   builder: (context, snapshot) {
                                            //     if (snapshot.data == true) {
                                            //       return SvgPicture.asset(
                                            //         SvgUtils.variationIcon,
                                            //         height: 10,
                                            //         width: 10,
                                            //       );
                                            //     }
                                            //     return const SizedBox.shrink();
                                            //   },
                                            // ),
                                            const SizedBox(width: 16),

                                            if (
                                            item['has_variants'] == true ||
                                                (item['variations'] is List && item['variations'].isNotEmpty) ||
                                                item['type'] == 'variable'
                                            )


                                              Padding(
                                                padding: const EdgeInsets.only(left: 4),
                                                child: SvgPicture.asset(
                                                  SvgUtils.variationIcon,
                                                  height: 10,
                                                  width: 10,
                                                ),
                                              ),

                                            const SizedBox(width: 7),

                                            //
                                            // if (item['variations'] !=
                                            //     null &&
                                            //     item['variations']
                                            //         .isNotEmpty) // Build #1.0.157: show variationIcon with count
                                            //   Row(
                                            //     children: [
                                            //       SvgPicture.asset(
                                            //           SvgUtils
                                            //               .variationIcon,
                                            //           height: 10,
                                            //           width: 10),
                                            //       // SizedBox(width: 4),
                                            //       // Text(
                                            //       //   '${item["variations"].length}',
                                            //       //   style: TextStyle(
                                            //       //     fontSize: 12,
                                            //       //     color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                                            //       //   ),
                                            //       // ),
                                            //     ],
                                            //   ),

                                            const SizedBox(width: 7),
                                            if (showEbtTag)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical:1 ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade600,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  "EBT",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 6,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        // if (showEbtTag)
                                        //   Container(
                                        //     padding: const EdgeInsets.symmetric(horizontal: 4, vertical:1 ),
                                        //     decoration: BoxDecoration(
                                        //       color: Colors.green.shade600,
                                        //       borderRadius: BorderRadius.circular(4),
                                        //     ),
                                        //     child: const Text(
                                        //       "EBT",
                                        //       style: TextStyle(
                                        //         color: Colors.white,
                                        //         fontSize: 6,
                                        //         fontWeight: FontWeight.bold,
                                        //       ),
                                        //     ),
                                        //   ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            themeHelper),
                      ),
                      if (enableIcons == true &&
                          itemIndex ==
                              selectedItemIndex) // Build #1.0.204: Show icons only for long-pressed item
                        Positioned(
                          top: -5,
                          right: -2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDeleteButton)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () => onDeleteItem(itemIndex),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.grey, size: 20),
                                onPressed: onCancelReorder,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            /// 🔥 PAGINATION LOADER (FLOATING – NO GAP)
            if (isPaginating)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE74C3C),
                      ),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }

  /// Customize products card layout for the grid, here
  // pass widget - contents of the card
  // themeHelper - to support dark and light theme background
  // optional accentColor - to apply changes in shadow and border color
  Widget _getCardWidget(Widget widget, ThemeNotifier themeHelper,
      {MaterialAccentColor accentColor = Colors.blueAccent}) {
    return Card(
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Colors.white,

      /// card color
      elevation: 5,
      shadowColor: accentColor,

      /// card shadow color
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        /// Optional: remove if no border required
        side: BorderSide(
          color: accentColor,

          /// Color of the border
          width: 0.5,

          /// Thickness of the border
        ),
        borderRadius:
        BorderRadius.circular(15.0), // Optional: for rounded corners
      ),
      child: widget,
    );
  }

  Future<void> updateOrderPanel(int index) async {
    // Navigator.pop(context);
    onItemTapped(index, variantAdded: true);
  }

}