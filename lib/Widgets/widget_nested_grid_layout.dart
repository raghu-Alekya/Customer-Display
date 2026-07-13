import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar/isar.dart';
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
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/url_helper.dart';
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
import 'widget_topbar.dart';

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

  static void clearProductMetaCache() {
    _productMetaCache.clear();
  }

  static int? _nestedProductMetaIdFromCacheMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final dynamic idRaw =
        m["fast_key_product_id"] ?? m["product_id"] ?? m["id"];
    if (idRaw is int) return idRaw;
    return int.tryParse(idRaw?.toString() ?? "");
  }


  /// One product-add flow at a time across the grid (fast taps otherwise queue heavy async work).
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

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
    if (!_productMetaCache.containsKey(productId)) {
      await _ingestNestedProductMetaFromMerged();
    }
    return _productMetaCache[productId];
  }

  static Future<void> _ingestNestedProductMetaFromMerged() async {
    try {
      _productMetaCache.clear(); // Force fresh
      final allCached = await TopBar.mergedCachedProductsForSearch();
      for (final raw in allCached) {
        final pid = _nestedProductMetaIdFromCacheMap(raw);
        if (pid != null) {
          _productMetaCache[pid] = Map<String, dynamic>.from(raw as Map);
        }
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ _ingestNestedProductMetaFromMerged failed: $e");
    }
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
    if (_truthyEbtNested(item["is_ebt_eligible"])) return true;
    if (_ebtMetaNested(item["meta_data"])) return true;

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

    // Must not use [Expanded] here: callers already wrap this widget in
    // `Expanded` + `ValueListenableBuilder`. Nesting [Expanded] causes
    // competing FlexParentData (ParentDataWidget assertion on hot restart).
    return SizedBox.expand(
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

                // Normalise EBT eligibility from multiple possible flags/encodings
                final dynamic rawEbtFlag = item['is_ebt_eligible'] ??
                    item['ebt_eligible'] ??
                    item['isEbtEligible'];
                final bool ebtFromFlag = rawEbtFlag == true ||
                    rawEbtFlag == 1 ||
                    rawEbtFlag == '1' ||
                    rawEbtFlag == 'true';

                final String itemTypeStr =
                    (item['type'] ?? '').toString().toLowerCase();
                final dynamic hvDb = item['fast_key_item_has_variant'];
                final bool hasVariantFromApiRow = hvDb == 1 ||
                    hvDb == true ||
                    hvDb == '1';
                final bool showVariantIcon = hasVariantFromApiRow ||
                    item['has_variants'] == true ||
                    item['has_variants'] == 1 ||
                    item['has_variants'] == '1' ||
                    item['has_variants'] == 'true' ||
                    (item['variations'] is List &&
                        (item['variations'] as List).isNotEmpty) ||
                    itemTypeStr == 'variable';

                final bool showEbtTag =
                    ebtFromFlag || _isProductEbtEligible(item);

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
                          if (_productTapInFlight) return;
                          _productTapInFlight = true;
                          // if (orderHelper?.activeOrderId == null) {
                          //   print("⛔ No active order → Show popup and block product adding");
                          //
                          //   await OrderPopupHelper.showNoOrderPopup(context);
                          //
                          //   return; // 🚫 STOP item adding
                          // }

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
                            // FORCE refresh from latest cache
                            if (productId > 0) {
                              await _enrichFastKeyItemSkuForNested(item);
                              final cached = await _getCachedProductFromIsar(productId);
                              if (cached != null) {
                                item.addAll(cached); // merge latest
                              }
                            }
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
                            // Use the same rules as FastKey screen + DB flag so
                            // tap behaviour matches category grid behaviour.
                            final dynamic hvDb = item['fast_key_item_has_variant'];
                            final bool hasVariantFromApiRow =
                                hvDb == 1 || hvDb == true || hvDb == '1';

                            final String typeStr =
                                (item["type"] ?? cachedProduct?["type"] ?? "")
                                    .toString()
                                    .toLowerCase();

                            final bool hasVariants =
                                hasVariantFromApiRow ||
                                (cachedProduct?["has_variants"] == true) ||
                                typeStr == "variable" ||
                                (item["variations"] != null &&
                                    item["variations"].isNotEmpty);

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
// Read from item meta_data
                            if (item['meta_data'] is List) {
                              for (var m in item['meta_data']) {
                                if (m is Map && m['key'] == '_product_loyalty_points') {
                                  loyaltyPoints = int.tryParse(m['value'].toString()) ?? 0;
                                  break;
                                }
                              }
                            }

                            print("🎯 LOYALTY POINTS forrrrrrrr ${productName}: $loyaltyPoints");

                            // ==================== END LOYALTY ====================
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
                            // final bool hasProduceTag = tags.any((t) {
                            //   final slug = (t["slug"] ?? "").toString().toLowerCase();
                            //   final name = (t["name"] ?? "").toString().toLowerCase();
                            //   return slug.contains("produce") || name.contains("produce");
                            // });
                            //
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
                            //     weightQty: weight,
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
                            //     onItemAdded: () async {
                            //       print(" Weighted product added successfully!");
                            //       onItemTapped(index, variantAdded: false);
                            //     },
                            //   );
                            //
                            //   return; //  IMPORTANT: Stop further processing
                            // }


// ─────────────────────────────────────────────────────────────────────────────
// PRODUCE / WEIGHTED ITEM — Use LIVE scale weight + Clear after add
// ─────────────────────────────────────────────────────────────────────────────
                            final bool hasProduceTag = tags.any((t) {
                              final slug = (t["slug"] ?? "").toString().toLowerCase();
                              final name = (t["name"] ?? "").toString().toLowerCase();
                              return slug.contains("produce") || name.contains("produce");
                            });

                            if (hasProduceTag) {
                              final weightProvider = Provider.of<WeightProvider>(context, listen: false);

                              // Parse current weight from display text
                              double liveWeight = 0.0;
                              try {
                                final parts = weightProvider.weightText.trim().split(' ');
                                if (parts.isNotEmpty) {
                                  liveWeight = double.tryParse(parts[0]) ?? 0.0;
                                }
                              } catch (_) {}

                              // Convert lb to kg (adjust if your scale uses different unit)
                              final double weightKg = liveWeight > 0 ? liveWeight * 0.453592 : 0.0;

                              // Fallback
                              final double weightToUse = weightKg > 0.00001 ? weightKg : 0.0001;

                              final double finalPrice = productPrice * weightToUse;

                              // if (weightKg <= 0.0001 && mounted) {
                              //   ScaffoldMessenger.of(context).showSnackBar(
                              //     const SnackBar(
                              //       content: Text('Scale not detected — using 100g default'),
                              //       duration: Duration(seconds: 2),
                              //     ),
                              //   );
                              // }

                              // Add the item
                              await orderHelper.addItemToOrder(
                                null,
                                productName,
                                productImage,
                                finalPrice,
                                1,
                                productSku,
                                activeOrderId,
                                type: 'weighted',
                                weightQty: weightToUse,
                                productId: productId,
                                variationId: -1,
                                salesPrice: finalPrice,
                                regularPrice: productPrice,
                                unitPrice: productPrice,
                                isEbtEligible: isEbtEligible,
                                metaData: item['meta_data'] is List
                                    ? List<Map<String, dynamic>>.from(item['meta_data'])
                                    : null,
                                loyaltyPoints: loyaltyPoints,
                                  onItemAdded: () async {
                                          print(" Weighted product added successfully!");
                                          print("$item['loyalty_points']");
                                          onItemTapped(index, variantAdded: true);
                                        },
                              );
                              return;
                            }




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
                                  metaData: item['meta_data'] is List
                                      ? List<Map<String, dynamic>>.from(item['meta_data'])
                                      : null,
                                  loyaltyPoints: loyaltyPoints,
                                  onItemAdded: () async {
                                    //await orderHelper.loadData();
                                  },
                                );

                                onItemTapped(index, variantAdded: true);
                                return; //  VERY IMPORTANT — stop popup here
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

                                    // ✅ Extract meta_data from variantData
                                    List<Map<String, dynamic>> metaData = [];
                                    if (variantData?["meta_data"] is List) {
                                      metaData = (variantData["meta_data"] as List)
                                          .whereType<Map>()
                                          .map((m) => Map<String, dynamic>.from(m))
                                          .toList();
                                    }

                                    // ✅ Extract loyalty points
                                    final loyaltyEntry = metaData.firstWhere(
                                          (m) => m['key'] == '_product_loyalty_points',
                                      orElse: () => <String, dynamic>{},
                                    );
                                    final int loyaltyPoints = loyaltyEntry.isNotEmpty
                                        ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
                                        : 0;

                                    rawVariations.add({
                                      "id": id,
                                      "name": name,
                                      "price": price,
                                      "sku": variantData?["sku"] ?? "",
                                      "image": image,
                                      "meta_data": metaData,  // ✅ Preserve meta_data
                                      "loyalty_points": loyaltyPoints,  // ✅ Store loyalty points
                                    });
                                  }

                                  if (kDebugMode) {
                                    print("📥 Built ${rawVariations.length} variant objects manually.");
                                  }
                                }

// 🧠 Normalize all variants with meta_data preservation
                                offlineVariations = rawVariations.map<Map<String, dynamic>>((v) {
                                  if (v is String) {
                                    try {
                                      v = jsonDecode(v);
                                    } catch (_) {}
                                  }
                                  if (v is Map) {
                                    final map = v.map((key, value) => MapEntry(key.toString(), value));

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

                                    // ✅ Preserve meta_data
                                    if (map["meta_data"] is! List) {
                                      map["meta_data"] = <Map<String, dynamic>>[];
                                    }

                                    // ✅ Ensure loyalty_points is set
                                    if (map["loyalty_points"] == null || map["loyalty_points"] == 0) {
                                      final metaData = map["meta_data"] as List<Map<String, dynamic>>;
                                      final loyaltyEntry = metaData.firstWhere(
                                            (m) => m['key'] == '_product_loyalty_points',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (loyaltyEntry.isNotEmpty) {
                                        map["loyalty_points"] = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                      } else {
                                        map["loyalty_points"] = 0;
                                      }
                                    }

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

                                if (allSameAsParent) {
                                  // print("🔁 Cached variants incomplete → Refetching from API...");
                                  // await ProductRepository().fetchProductVariations(productId);
                                  //
                                  // final refreshed = await productBox.get(cacheKey);
                                  // if (refreshed is Map && refreshed["variations"] is List) {
                                  //   offlineVariations = (refreshed["variations"] as List)
                                  //       .map((v) => Map<String, dynamic>.from(v as Map))
                                  //       .toList();
                                  // }
                                }
                              } catch (e, st) {
                                if (kDebugMode) {
                                  print("⚠️ Error decoding offline variations: $e");
                                  print(st);
                                }
                              }

                              // 🔥 Same as category screen: fetch WooCommerce variations when cache is empty
                              if (offlineVariations.isEmpty && productId > 0) {
                                final fetched =
                                    await _fetchVariationsFromApiNestedGrid(productId);
                                if (fetched.isNotEmpty) {
                                  offlineVariations = fetched;
                                  try {
                                    final box = StorageProvider.productCache;
                                    await box.put(
                                      "product_${productId}_variations",
                                      {
                                        "variations": fetched,
                                        "timestamp":
                                            DateTime.now().toIso8601String(),
                                      },
                                    );
                                  } catch (_) {}
                                }
                              }

                              if (offlineVariations.isEmpty) {
                                if (context.mounted && loadingDialogShown) {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "No variants available for this product right now.",
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                                return;
                              }

                              // Dismiss loading dialog before showing VariantsDialog
                              if (context.mounted && loadingDialogShown) {
                                Navigator.of(context, rootNavigator: true).pop();
                              }

                              // 🪟 Show VariantsDialog
                              if (kDebugMode) {
                                print("🪟 Showing VariantsDialog for $productName...");
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

                                    // ✅ CRITICAL: Extract meta_data from selected variant
                                    List<Map<String, dynamic>> variantMetaData = [];
                                    int variantLoyaltyPoints = 0;

                                    // Try to get meta_data from selectedVariant
                                    if (selectedVariant["meta_data"] is List) {
                                      variantMetaData = (selectedVariant["meta_data"] as List)
                                          .whereType<Map>()
                                          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
                                          .toList();

                                      // Extract loyalty from meta_data
                                      final loyaltyEntry = variantMetaData.firstWhere(
                                            (m) => m['key'] == '_product_loyalty_points',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (loyaltyEntry.isNotEmpty) {
                                        variantLoyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                      }
                                    }

                                    // If no loyalty from meta_data, try direct field
                                    if (variantLoyaltyPoints == 0 && selectedVariant["loyalty_points"] != null) {
                                      variantLoyaltyPoints = int.tryParse(selectedVariant["loyalty_points"].toString()) ?? 0;
                                    }

                                    // If still 0, try parent product's loyalty points (fallback)
                                    if (variantLoyaltyPoints == 0) {
                                      final parentMeta = item['meta_data'];
                                      if (parentMeta is List) {
                                        final parentLoyalty = parentMeta.firstWhere(
                                              (m) => m['key'] == '_product_loyalty_points',
                                          orElse: () => <String, dynamic>{},
                                        );
                                        if (parentLoyalty.isNotEmpty) {
                                          variantLoyaltyPoints = int.tryParse(parentLoyalty['value']?.toString() ?? '0') ?? 0;
                                          print('🔄 [NestedGrid] Using parent loyalty points: $variantLoyaltyPoints');
                                        }
                                      }
                                    }

                                    print('🛒 [NestedGrid] Added variant: $variantName');
                                    print('  → Variant ID: $variantId');
                                    print('  → Variant Price: $variantPrice');
                                    print('  → MetaData count: ${variantMetaData.length}');
                                    print('  → Loyalty Points: $variantLoyaltyPoints');

                                    // ✅ Pass variant loyalty points to order
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
                                      isEbtEligible: isEbtEligible,
                                      metaData: variantMetaData,  // ✅ Pass variant's meta_data
                                      loyaltyPoints: variantLoyaltyPoints,  // ✅ Pass variant's loyalty points
                                      onItemAdded: () async {
                                        print("✅ Variant item added successfully!");
                                        onItemTapped(index, variantAdded: true);
                                      },
                                    );
                                  },
                                ),
                              );
                              print("🪟 VariantsDialog closed for $productName");
                            } else {
                              // 🟩 Simple Product
                              print("🟩 Simple product, adding directly...");


// ✅ Extract loyalty points from item
                              int simpleLoyaltyPoints = 0;
                              if (item['meta_data'] is List) {
                                final loyaltyEntry = (item['meta_data'] as List).firstWhere(
                                      (m) => m['key'] == '_product_loyalty_points',
                                  orElse: () => <String, dynamic>{},
                                );
                                if (loyaltyEntry.isNotEmpty) {
                                  simpleLoyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
                                }
                              }
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
                                metaData: item['meta_data'] is List
                                    ? List<Map<String, dynamic>>.from(item['meta_data'])
                                    : null,
                                loyaltyPoints: simpleLoyaltyPoints,
                                onItemAdded: () async {
                                  print(" Simple product added successfully!");
                                  print("print : $loyaltyPoints");
                                  onItemTapped(index, variantAdded: true);
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
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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

                                      // ── Price + badges row ─────────────────────────────
                                      Row(
                                        children: [
                                          Text(
                                            '${TextConstants.currencySymbol}${double.tryParse(item["fast_key_item_price"].toString())?.toStringAsFixed(2) ?? "0.00"}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: themeHelper.themeMode == ThemeMode.dark
                                                  ? ThemeNotifier.textDark
                                                  : ThemeNotifier.textLight,
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // ✅ Variant icon (truthy flags + tag-based variable)
                                          if (showVariantIcon ||
                                              _isVariableProduct(item))
                                            SvgPicture.asset(
                                              SvgUtils.variationIcon,
                                              height: 10,
                                              width: 10,
                                            ),

                                          const SizedBox(width: 4),

                                          // ✅ EBT badge — same style as categories screen
                                          if (showEbtTag)
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade600,
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'EBT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          themeHelper,
                        ),
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

// ── Fast Keys: SKU Hive enrich + WooCommerce variations API (category parity) ──

Future<void> _enrichFastKeyItemSkuForNested(Map<String, dynamic> item) async {
  final sku = (item['fast_key_item_sku'] ?? '').toString().trim();
  if (sku.isEmpty || sku == 'N/A') return;

  try {
    final box = StorageProvider.productCache;
    final raw = await box.get('sku_${sku.toLowerCase()}');
    if (raw is! Map) return;

    final products = raw['products'];
    if (products is! List || products.isEmpty) return;

    final first = products.first;
    if (first is! Map) return;

    final p = Map<String, dynamic>.from(first);

    // Core fields
    if (p['type'] != null) item['type'] = p['type'];
    if (p['variations'] is List) item['variations'] = p['variations'];
    if (p['tags'] != null) item['fast_key_item_tags'] = p['tags'];
    if (p['meta_data'] != null) item['meta_data'] = p['meta_data'];

    // EBT
    if (_truthyEbtNested(p['is_ebt_eligible']) || _ebtMetaNested(p['meta_data'])) {
      item['is_ebt_eligible'] = true;
    }

    // Price / Name fallback
    if (p['price'] != null) item['fast_key_item_price'] = p['price'];
    if (p['name'] != null) item['fast_key_item_name'] = p['name'];
  } catch (e) {
    if (kDebugMode) print("⚠️ _enrichFastKeyItemSkuForNested error: $e");
  }
}

bool _truthyEbtNested(dynamic v) {
  if (v == true || v == 1) return true;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

bool _ebtMetaNested(dynamic meta) {
  if (meta is! List) return false;
  for (final m in meta) {
    if (m is! Map) continue;
    final key = (m['key'] ?? '').toString().toLowerCase();
    if (key != '_is_ebt_eligible' &&
        key != 'is_ebt_eligible' &&
        key != '_ebt_eligible') {
      continue;
    }
    if (_truthyEbtNested(m['value'])) return true;
  }
  return false;
}

Future<String> _getAuthTokenForNestedGrid() async {
  final db = await DBHelper.instance.database;
  final result = await db.query(
    AppDBConst.userTable,
    where:
        '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
    orderBy: '${AppDBConst.userId} DESC',
    limit: 1,
  );
  if (result.isEmpty) {
    throw Exception('No active user token found');
  }
  return result.first[AppDBConst.userToken] as String;
}

Future<List<Map<String, dynamic>>> _fetchVariationsFromApiNestedGrid(
    int productId) async {
  try {
    final token = await _getAuthTokenForNestedGrid();
    final url = Uri.parse(
      "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations",
    );
    final response =
    await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode != 200) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .whereType<Map>()
        .map<Map<String, dynamic>>((v) {
      final map = v.map((key, value) => MapEntry(key.toString(), value));
      final attrs = map["attributes"];
      final String fallbackName = attrs is List
          ? attrs
          .whereType<Map>()
          .map((a) => (a["option"] ?? "").toString())
          .where((x) => x.isNotEmpty)
          .join(" - ")
          : "";

      // ✅ Extract meta_data from variant
      final List<Map<String, dynamic>> metaData = (map["meta_data"] is List)
          ? (map["meta_data"] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList()
          : <Map<String, dynamic>>[];

      // ✅ Extract loyalty points from meta_data
      final loyaltyEntry = metaData.firstWhere(
            (m) => m['key'] == '_product_loyalty_points',
        orElse: () => <String, dynamic>{},
      );
      final int loyaltyPoints = loyaltyEntry.isNotEmpty
          ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
          : 0;

      if (kDebugMode) {
        print("🔹 [NestedGrid Variations API] id=${map['id']} loyalty=$loyaltyPoints metaCount=${metaData.length}");
      }

      return {
        "id": map["id"],
        "name": (map["name"] ?? "").toString().isNotEmpty
            ? map["name"]
            : (fallbackName.isNotEmpty
            ? fallbackName
            : "Unnamed Variant"),
        "price":
        (map["price"] ?? map["regular_price"] ?? "0").toString(),
        "sku": map["sku"] ?? "",
        "image": (map["image"] is Map && map["image"]["src"] != null)
            ? map["image"]["src"]
            : (map["image"] is String ? map["image"] : ""),
        "meta_data": metaData,  // ✅ Store meta_data
        "loyalty_points": loyaltyPoints,  // ✅ Store loyalty points
      };
    })
        .where((v) => v["id"] != null)
        .toList();
  } catch (e) {
    if (kDebugMode) {
      print("⚠️ _fetchVariationsFromApiNestedGrid: $e");
    }
    return <Map<String, dynamic>>[];
  }
}