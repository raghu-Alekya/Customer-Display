import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:pinaka_pos/Helper/auto_search.dart';
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
  final bool showBackButton;
  final List<Map<String, dynamic>> items;
  final int? selectedItemIndex;
  final List<int?> reorderedIndices;
  final VoidCallback? onAddButtonPressed;
  final VoidCallback? onBackButtonPressed;
  final Function(int, {bool variantAdded}) onItemTapped;
  final Function(int, int) onReorder;
  final Function(int) onDeleteItem;
  final bool showDeleteButton;
  final Function() onCancelReorder;
  final bool? enableIcons;
  final Function(int)? onLongPress;
  final ProductBloc? productBloc;
  final OrderBloc? orderBloc;
  final OrderHelper? orderHelper;
  final bool isPaginating;

  // OPTIMIZATION: CACHE FOR FASTER ACCESS
  static final Map<int, Map<String, dynamic>> _productMetaCache = {};
  static final Map<int, bool> _variantCheckCache = {};
  static final Map<int, bool> _ebtCheckCache = {};
  static final Map<int, int> _ageCheckCache = {};
  static final Map<int, bool> _variablePriceCache = {};
  static bool _productMetaInitialized = false;

  // UI Update performance tracking
  static final Map<String, int> _performanceStats = {};
  static final Map<String, int> _uiPerformanceStats = {};

  // INSTANT UI FEEDBACK: Optimistic updates
  static final Map<String, ValueNotifier<bool>> _uiUpdateNotifiers = {};
  static final Map<String, Completer<void>> _pendingUpdates = {};

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
    this.orderHelper,
    required this.isPaginating,
  });

  // Performance measurement helper
  void _logTime(String label, int milliseconds, {bool isCritical = false, bool isUi = false}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = '$label-$timestamp';
    if (isUi) {
      _uiPerformanceStats[key] = milliseconds;
    } else {
      _performanceStats[key] = milliseconds;
    }

    if (isCritical || milliseconds > 10) {
      print(" [$label] took ${milliseconds}ms ${isUi ? '(UI)' : ''}");
    }
  }

  void _printPerformanceSummary() {
    print("\n ========== PERFORMANCE SUMMARY ==========");
    print("Product Meta Cache Size: ${_productMetaCache.length}");
    print(" Variant Cache Size: ${_variantCheckCache.length}");
    print(" EBT Cache Size: ${_ebtCheckCache.length}");
    print(" Age Cache Size: ${_ageCheckCache.length}");

    // Group by label prefix for backend
    print("\n BACKEND PERFORMANCE:");
    final Map<String, List<int>> backendTimes = {};
    _performanceStats.forEach((key, value) {
      final parts = key.split('-');
      if (parts.isNotEmpty) {
        final label = parts[0];
        backendTimes.putIfAbsent(label, () => []).add(value);
      }
    });

    backendTimes.forEach((label, times) {
      if (times.isNotEmpty) {
        final avg = times.reduce((a, b) => a + b) ~/ times.length;
        final max = times.reduce((a, b) => a > b ? a : b);
        final min = times.reduce((a, b) => a < b ? a : b);
        print(" $label: Avg=${avg}ms, Min=${min}ms, Max=${max}ms, Count=${times.length}");
      }
    });

    // Group by label prefix for UI
    print("\n UI UPDATE PERFORMANCE:");
    final Map<String, List<int>> uiTimes = {};
    _uiPerformanceStats.forEach((key, value) {
      final parts = key.split('-');
      if (parts.isNotEmpty) {
        final label = parts[0];
        uiTimes.putIfAbsent(label, () => []).add(value);
      }
    });

    uiTimes.forEach((label, times) {
      if (times.isNotEmpty) {
        final avg = times.reduce((a, b) => a + b) ~/ times.length;
        final max = times.reduce((a, b) => a > b ? a : b);
        final min = times.reduce((a, b) => a < b ? a : b);
        print(" $label: Avg=${avg}ms, Min=${min}ms, Max=${max}ms, Count=${times.length}");
      }
    });
    print(" ========================================\n");
  }

  // OPTIMIZED: Load all cache data once
  Future<void> _initializeProductMetaCache() async {
    if (_productMetaInitialized) return;

    final stopwatch = Stopwatch()..start();

    try {
      print(" Initializing product meta cache...");
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      int processedCount = 0;
      for (final entry in entries) {
        if (!entry.key.startsWith("products_")) continue;

        try {
          final List<dynamic> products = jsonDecode(entry.json);

          // Process in smaller batches for Android
          final batchSize = 50;
          for (int i = 0; i < products.length; i += batchSize) {
            final end = i + batchSize < products.length ? i + batchSize : products.length;
            for (int j = i; j < end; j++) {
              final raw = products[j];
              if (raw is! Map) continue;
              final map = Map<String, dynamic>.from(raw);
              final idStr = (map["fast_key_product_id"] ?? map["id"])?.toString();
              final pid = int.tryParse(idStr ?? "");
              if (pid != null) {
                _productMetaCache[pid] = map;

                // Pre-calculate common checks
                _variantCheckCache[pid] = _calculateHasVariants(map);
                _ebtCheckCache[pid] = _calculateIsEbtEligible(map);
                _ageCheckCache[pid] = _calculateMinAge(map);
                _variablePriceCache[pid] = _calculateHasVariablePrice(map);
                processedCount++;
              }
            }
            // Small delay to prevent Android UI freeze
            if (Platform.isAndroid && processedCount % 100 == 0) {
              await Future.delayed(const Duration(milliseconds: 1));
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(" Error parsing cache entry: $e");
          }
        }
      }

      _productMetaInitialized = true;
      stopwatch.stop();
      print(" Product meta cache initialized with ${_productMetaCache.length} items in ${stopwatch.elapsedMilliseconds}ms");
      _logTime("CacheInit", stopwatch.elapsedMilliseconds);
    } catch (e) {
      if (kDebugMode) {
        print(" Isar cache initialization failed → $e");
      }
    }
  }

  bool _calculateHasVariants(Map<String, dynamic> item) {
    if (item["type"] == "variable") return true;
    if (item["variations"] is List && item["variations"].isNotEmpty) return true;
    if (item["has_variants"] == true) return true;
    return false;
  }

  bool _calculateIsEbtEligible(Map<String, dynamic> item) {
    if (item["is_ebt_eligible"] == true) return true;

    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    if (tagsRaw is List) {
      // Quick check for Android performance
      for (final t in tagsRaw.take(10)) { // Limit to 10 tags for speed
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("ebt") || slug.contains("ebt")) return true;
        }
      }
    }

    return false;
  }

  int _calculateMinAge(Map<String, dynamic> item) {
    final dynamic minAgeSource = item["min_age"] ?? item["fast_key_item_min_age"];
    int minAge = int.tryParse(minAgeSource?.toString() ?? "0") ?? 0;

    if (minAge == 0) {
      final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
      if (tagsRaw is List) {
        // Limit tag checking for Android performance
        for (final t in tagsRaw.take(10)) {
          if (t is Map) {
            final name = (t["name"] ?? "").toString().toLowerCase();
            final slug = (t["slug"] ?? "").toString();
            if (name.contains("age") || name.contains("restricted")) {
              final parsedAge = int.tryParse(slug);
              if (parsedAge != null && parsedAge > 0) {
                return parsedAge;
              }
            }
          }
        }
      }
    }

    return minAge;
  }

  bool _calculateHasVariablePrice(Map<String, dynamic> item) {
    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    if (tagsRaw is List) {
      // Quick check for Android performance
      for (final t in tagsRaw.take(10)) {
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("variable") || slug.contains("variable")) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
    final stopwatch = Stopwatch()..start();

    // Return from pre-initialized cache
    if (_productMetaCache.containsKey(productId)) {
      stopwatch.stop();
      _logTime("CacheHit", stopwatch.elapsedMilliseconds);
      return _productMetaCache[productId];
    }

    // Fallback to direct lookup
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
          if (pid == productId) {
            _productMetaCache[pid!] = map; // Cache for future use
            stopwatch.stop();
            _logTime("CacheMiss", stopwatch.elapsedMilliseconds);
            return map;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(" Direct Isar cache lookup failed → $e");
      }
    }

    stopwatch.stop();
    _logTime("CacheNotFound", stopwatch.elapsedMilliseconds);
    return null;
  }

  Future<bool> _fastKeyHasVariants(Map<String, dynamic> item) async {
    final stopwatch = Stopwatch()..start();
    final int? productId = int.tryParse(item["fast_key_product_id"]?.toString() ?? "");
    if (productId == null) {
      stopwatch.stop();
      _logTime("VariantCheck_NoID", stopwatch.elapsedMilliseconds);
      return false;
    }

    // Check cache first
    if (_variantCheckCache.containsKey(productId)) {
      stopwatch.stop();
      _logTime("VariantCheck_Cache", stopwatch.elapsedMilliseconds);
      return _variantCheckCache[productId]!;
    }

    // Fast item-level check
    if (item["type"] == "variable") {
      _variantCheckCache[productId] = true;
      stopwatch.stop();
      _logTime("VariantCheck_Type", stopwatch.elapsedMilliseconds);
      return true;
    }

    if (item["variations"] is List && item["variations"].isNotEmpty) {
      _variantCheckCache[productId] = true;
      stopwatch.stop();
      _logTime("VariantCheck_Variations", stopwatch.elapsedMilliseconds);
      return true;
    }

    // Check product meta cache
    final cached = await _getCachedProductFromIsar(productId);
    bool hasVariants = false;

    if (cached != null) {
      hasVariants = _calculateHasVariants(cached);
      _variantCheckCache[productId] = hasVariants; // Cache result
      stopwatch.stop();
      _logTime("VariantCheck_CachedProduct", stopwatch.elapsedMilliseconds);
      return hasVariants;
    }

    // Check variation cache - OPTIMIZED for Android
    try {
      final box = Hive.box('productCache');
      final variationKey = "product_${productId}_variations";

      // Use simpler check for Android
      if (box.containsKey(variationKey)) {
        final variationData = box.get(variationKey, defaultValue: null);

        if (variationData is Map && variationData["variations"] is List && (variationData["variations"] as List).isNotEmpty) {
          _variantCheckCache[productId] = true;
          stopwatch.stop();
          _logTime("VariantCheck_HiveMap", stopwatch.elapsedMilliseconds);
          return true;
        }

        if (variationData is List && variationData.isNotEmpty) {
          _variantCheckCache[productId] = true;
          stopwatch.stop();
          _logTime("VariantCheck_HiveList", stopwatch.elapsedMilliseconds);
          return true;
        }
      }
    } catch (_) {}

    _variantCheckCache[productId] = false;
    stopwatch.stop();
    _logTime("VariantCheck_Final", stopwatch.elapsedMilliseconds);
    return false;
  }

  bool _isProductEbtEligible(Map<String, dynamic> item) {
    final stopwatch = Stopwatch()..start();
    final int? productId = int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    // Check cache first
    if (productId != null && _ebtCheckCache.containsKey(productId)) {
      stopwatch.stop();
      _logTime("EBTCheck_Cache", stopwatch.elapsedMilliseconds);
      return _ebtCheckCache[productId]!;
    }

    if (item["is_ebt_eligible"] == true) {
      if (productId != null) _ebtCheckCache[productId] = true;
      stopwatch.stop();
      _logTime("EBTCheck_Field", stopwatch.elapsedMilliseconds);
      return true;
    }

    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    bool hasEbt = false;

    if (tagsRaw is List) {
      // Optimized loop for Android
      for (int i = 0; i < tagsRaw.length && i < 10; i++) {
        final t = tagsRaw[i];
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("ebt") || slug.contains("ebt")) {
            hasEbt = true;
            break;
          }
        }
      }
    }

    if (productId != null) {
      _ebtCheckCache[productId] = hasEbt;
    }

    stopwatch.stop();
    _logTime("EBTCheck_Tags", stopwatch.elapsedMilliseconds);
    return hasEbt;
  }

  bool _hasVariablePriceTag(Map<String, dynamic> item) {
    final stopwatch = Stopwatch()..start();
    final int? productId = int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    // Check cache first
    if (productId != null && _variablePriceCache.containsKey(productId)) {
      stopwatch.stop();
      _logTime("VarPriceCheck_Cache", stopwatch.elapsedMilliseconds);
      return _variablePriceCache[productId]!;
    }

    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    bool hasVariable = false;

    if (tagsRaw is List) {
      // Optimized for Android
      for (int i = 0; i < tagsRaw.length && i < 10; i++) {
        final t = tagsRaw[i];
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("variable") || slug.contains("variable")) {
            hasVariable = true;
            break;
          }
        }
      }
    }

    if (productId != null) {
      _variablePriceCache[productId] = hasVariable;
    }

    stopwatch.stop();
    _logTime("VarPriceCheck", stopwatch.elapsedMilliseconds);
    return hasVariable;
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = (showAddButton ? 1 : 0) + (showBackButton ? 1 : 0) + items.length;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    // Initialize cache when widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProductMetaCache();
    });

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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: totalCount,
              dragEnabled: Misc.enableReordering,
              onReorder: Misc.enableReordering
                  ? onReorder
                  : (oldIndex, newIndex) {},
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
                            const Icon(Icons.add, size: 40, color: Color(0xFFFE6464)),
                            Text(TextConstants.addProductText,
                                style: TextStyle(color: Color(0xFFFE6464))),
                          ],
                        ),
                        themeHelper,
                        accentColor: Colors.redAccent,
                      ),
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
                            Icon(Icons.arrow_back, size: 50, color: Colors.blue),
                            SizedBox(height: 5),
                            Text(TextConstants.backToCategories,
                                style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                        themeHelper,
                      ),
                    ),
                  );
                }

                // Adjust the index based on the presence of "Add" and "Back" buttons
                final itemIndex =
                    index - (showAddButton ? 1 : 0) - (showBackButton ? 1 : 0);
                if (itemIndex < 0 || itemIndex >= items.length) {
                  return const SizedBox.shrink();
                }

                final isReordered =
                    reorderedIndices.isNotEmpty && reorderedIndices[itemIndex] != null;
                final item = items[itemIndex];

                // Pre-calculate EBT tag visibility
                final bool showEbtTag = _isProductEbtEligible(item);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: isReordered ? Border.all(color: Colors.blue, width: 3) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  key: ValueKey('grid_item_${itemIndex}_${item["fast_key_item_name"]}'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          // Start timing for performance measurement
                          final totalStopwatch = Stopwatch()..start();
                          print("\n ========== START PRODUCT ADD ==========");

                          try {
                            // 1. Quick active order check
                            final stopwatch1 = Stopwatch()..start();
                            if (orderHelper?.activeOrderId == null) {
                              print(" No active order → Show popup and block product adding");
                              await OrderPopupHelper.showNoOrderPopup(context);
                              return;
                            }
                            stopwatch1.stop();
                            _logTime("OrderCheck", stopwatch1.elapsedMilliseconds, isCritical: true);

                            final int? productId =
                            int.tryParse(item["fast_key_product_id"].toString());

                            if (productId == null) {
                              print(" Invalid product ID");
                              return;
                            }

                            // 2. Parallel data fetching
                            final stopwatch2 = Stopwatch()..start();
                            final cachedFuture = _getCachedProductFromIsar(productId);
                            final orderIdFuture = Future.value(orderHelper?.activeOrderId);

                            // Get results
                            final cachedProduct = await cachedFuture;
                            final activeOrderId = await orderIdFuture;
                            stopwatch2.stop();
                            _logTime("DataFetch", stopwatch2.elapsedMilliseconds, isCritical: true);

                            if (activeOrderId == null) return;

                            // 3. Extract product data (optimized)
                            final stopwatch3 = Stopwatch()..start();
                            final productName = _extractProductName(item, cachedProduct);
                            final productPrice = _extractProductPrice(item, cachedProduct);
                            final productSku = _extractProductSku(item, cachedProduct, productId);
                            final productImage = _extractProductImage(item, cachedProduct);
                            final isEbtEligible = _isProductEligibleForEbt(item, cachedProduct);
                            final minAge = _extractMinAge(item, cachedProduct);
                            final hasVariablePrice = _hasVariablePriceTag(item);
                            stopwatch3.stop();
                            _logTime("DataExtract", stopwatch3.elapsedMilliseconds, isCritical: true);

                            print(" Product: $productName | Price: $productPrice | EBT: $isEbtEligible | Age: $minAge");

                            // 4. Check age restriction
                            if (minAge > 0) {
                              final stopwatch4 = Stopwatch()..start();
                              final ageVerified = await _checkAndVerifyAge(
                                  context,
                                  activeOrderId,
                                  minAge
                              );
                              stopwatch4.stop();
                              _logTime("AgeCheck", stopwatch4.elapsedMilliseconds, isCritical: true);
                              if (!ageVerified) return;
                            }

                            // 5. Variable price handling
                            double finalPrice = productPrice;
                            if (hasVariablePrice) {
                              final stopwatch5 = Stopwatch()..start();
                              finalPrice = await _handleVariablePrice(
                                context,
                                activeOrderId,
                                productId,
                                productName,
                                productImage,
                                productPrice,
                              );
                              stopwatch5.stop();
                              _logTime("VarPrice", stopwatch5.elapsedMilliseconds, isCritical: true);
                              if (finalPrice == -1) return; // Cancelled
                            }

                            // 6. Variant check
                            final stopwatch6 = Stopwatch()..start();
                            final hasVariants = await _fastKeyHasVariants(item);
                            stopwatch6.stop();
                            _logTime("VariantCheck", stopwatch6.elapsedMilliseconds, isCritical: true);

                            // 7. INSTANT UI FEEDBACK: Trigger UI update BEFORE backend
                            final uiUpdateStart = DateTime.now().millisecondsSinceEpoch;
                            onItemTapped(itemIndex, variantAdded: false);
                            final uiUpdateTime = DateTime.now().millisecondsSinceEpoch - uiUpdateStart;
                            _logTime("UI_InstantUpdate", uiUpdateTime, isUi: true, isCritical: true);

                            // 8. Add product ASYNC (in background)
                            Future.microtask(() async {
                              final backendStart = DateTime.now().millisecondsSinceEpoch;

                              if (hasVariants) {
                                await _handleVariants(
                                  context,
                                  productId,
                                  productName,
                                  productImage,
                                  productPrice,
                                  productSku,
                                  activeOrderId,
                                  isEbtEligible,
                                  itemIndex,
                                );
                              } else {
                                // Simple product - add directly in background
                                await orderHelper?.addItemToOrder(
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
                                  onItemAdded: () {
                                    // Optional: Trigger another UI update if needed
                                    print("✅ Backend add completed");
                                  },
                                );
                              }

                              final backendTime = DateTime.now().millisecondsSinceEpoch - backendStart;
                              _logTime("Backend_Async", backendTime, isCritical: true);
                            });

                            totalStopwatch.stop();
                            print("\n ========== PRODUCT ADD COMPLETE ==========");
                            print(" UI Instant Update: ${uiUpdateTime}ms");
                            print("Total perceived time: ${totalStopwatch.elapsedMilliseconds}ms");
                            print(" Product: $productName");
                            print(" Price: \$$finalPrice");
                            print(" EBT: $isEbtEligible");
                            _logTime("TOTAL_Perceived", totalStopwatch.elapsedMilliseconds, isCritical: true);

                            // Print summary every 5 operations
                            if (_performanceStats.length % 5 == 0) {
                              _printPerformanceSummary();
                            }
                          } catch (e, s) {
                            print(" ERROR in product tap: $e");
                            print(s);
                          }
                        },
                        onLongPress: () {
                          onLongPress?.call(itemIndex);
                        },
                        child: _getCardWidget(
                          Padding(
                            padding: const EdgeInsets.all(7.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // IMAGE
                                      SizedBox(
                                        height: 60,
                                        width: 60,
                                        child: _buildImage(item["fast_key_item_image"]),
                                      ),

                                      const SizedBox(width: 8),

                                      // NAME + PRICE COLUMN
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // ITEM NAME
                                            Text(
                                              item["fast_key_item_name"] ?? "",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: true,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: themeHelper.themeMode == ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : ThemeNotifier.textLight,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            // PRICE + ICONS
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${TextConstants.currencySymbol}'
                                                      '${double.tryParse(item["fast_key_item_price"]?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00"}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeHelper.themeMode == ThemeMode.dark
                                                        ? ThemeNotifier.textDark
                                                        : ThemeNotifier.textLight,
                                                  ),
                                                ),

                                                const SizedBox(width: 10),

                                                // VARIANT ICON
                                                if (item['has_variants'] == true ||
                                                    (item['variations'] is List &&
                                                        (item['variations'] as List).isNotEmpty) ||
                                                    item['type'] == 'variable')
                                                  SvgPicture.asset(
                                                    SvgUtils.variationIcon,
                                                    height: 10,
                                                    width: 10,
                                                  ),

                                                const SizedBox(width: 6),

                                                // EBT TAG
                                                if (showEbtTag)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 4, vertical: 1),
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
                                          ],
                                        ),
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
                      if (enableIcons == true && itemIndex == selectedItemIndex)
                        Positioned(
                          top: -5,
                          right: -2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDeleteButton)
                                IconButton(
                                  icon:
                                  const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => onDeleteItem(itemIndex),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
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

            /// 🔥 PAGINATION LOADER
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

  // OPTIMIZED HELPER METHODS WITH TIMING

  String _extractProductName(Map<String, dynamic> item, Map<String, dynamic>? cached) {
    final stopwatch = Stopwatch()..start();
    String result;

    if (item["fast_key_item_name"] is String) {
      result = item["fast_key_item_name"];
    } else if (item["fast_key_item_name"]?["rendered"] != null) {
      result = item["fast_key_item_name"]["rendered"];
    } else if (cached?["fast_key_item_name"] is String) {
      result = cached!["fast_key_item_name"];
    } else if (cached?["name"] is String) {
      result = cached!["name"];
    } else {
      result = "Unnamed Product";
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractName", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  double _extractProductPrice(Map<String, dynamic> item, Map<String, dynamic>? cached) {
    final stopwatch = Stopwatch()..start();
    double result = 0.0;

    // Try item price first
    final dynamic itemPrice = item["fast_key_item_price"] ?? item["price"];
    if (itemPrice != null) {
      final parsed = double.tryParse(itemPrice.toString());
      if (parsed != null) result = parsed;
    }

    // Try cached price if still 0
    if (result == 0.0) {
      final dynamic cachedPrice = cached?["fast_key_item_price"] ?? cached?["price"];
      if (cachedPrice != null) {
        final parsed = double.tryParse(cachedPrice.toString());
        if (parsed != null) result = parsed;
      }
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractPrice", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  String _extractProductSku(
      Map<String, dynamic> item, Map<String, dynamic>? cached, int productId) {
    final stopwatch = Stopwatch()..start();
    final result = cached?["sku"] ?? item["fast_key_item_sku"] ?? "SKU-$productId";
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractSku", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  String _extractProductImage(Map<String, dynamic> item, Map<String, dynamic>? cached) {
    final stopwatch = Stopwatch()..start();
    String result = "";

    final dynamic rawImage = cached?["fast_key_item_image"] ?? cached?["image"] ?? item["fast_key_item_image"];

    if (rawImage is String) {
      result = rawImage;
    } else if (rawImage is Map) {
      result = rawImage["src"] ?? "";
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractImage", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  bool _isProductEligibleForEbt(Map<String, dynamic> item, Map<String, dynamic>? cached) {
    final stopwatch = Stopwatch()..start();
    bool result = false;

    // Check item first
    if (item["is_ebt_eligible"] == true) {
      result = true;
    } else if (cached?["is_ebt_eligible"] == true) {
      result = true;
    } else if (_tagsContainEbt(item["fast_key_item_tags"] ?? item["tags"])) {
      result = true;
    } else if (_tagsContainEbt(cached?["fast_key_item_tags"] ?? cached?["tags"])) {
      result = true;
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("CheckEbt", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  bool _tagsContainEbt(dynamic tags) {
    if (tags is List) {
      // Optimized for Android - limit iterations
      for (int i = 0; i < tags.length && i < 10; i++) {
        final t = tags[i];
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("ebt") || slug.contains("ebt")) return true;
        }
      }
    }
    return false;
  }

  int _extractMinAge(Map<String, dynamic> item, Map<String, dynamic>? cached) {
    final stopwatch = Stopwatch()..start();
    int result = 0;
    final int? productId = int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    // Check cache first
    if (productId != null && _ageCheckCache.containsKey(productId)) {
      result = _ageCheckCache[productId]!;
    } else {
      // Try item min_age
      final dynamic itemMinAge = item["fast_key_item_min_age"] ?? item["min_age"];
      result = int.tryParse(itemMinAge?.toString() ?? "0") ?? 0;

      if (result == 0) {
        // Try cached min_age
        final dynamic cachedMinAge = cached?["min_age"] ?? cached?["fast_key_item_min_age"];
        result = int.tryParse(cachedMinAge?.toString() ?? "0") ?? 0;
      }

      if (result == 0) {
        // Extract from tags
        final dynamic tags = item["fast_key_item_tags"] ?? item["tags"] ?? cached?["tags"];
        if (tags is List) {
          // Limit for Android performance
          for (int i = 0; i < tags.length && i < 10; i++) {
            final t = tags[i];
            if (t is Map) {
              final name = (t["name"] ?? "").toString().toLowerCase();
              final slug = (t["slug"] ?? "").toString();
              if (name.contains("age") || name.contains("restricted")) {
                final parsedAge = int.tryParse(slug);
                if (parsedAge != null && parsedAge > 0) {
                  result = parsedAge;
                  break;
                }
              }
            }
          }
        }
      }

      if (productId != null) {
        _ageCheckCache[productId] = result;
      }
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractAge", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  Future<bool> _checkAndVerifyAge(BuildContext context, int orderId, int minAge) async {
    final stopwatch = Stopwatch()..start();

    if (minAge <= 0) {
      stopwatch.stop();
      _logTime("AgeSkip", stopwatch.elapsedMilliseconds);
      return true;
    }

    final box = Hive.box('offlineOrders');
    final orderKey = orderId.toString();
    final hiveOrder = Map<String, dynamic>.from(box.get(orderKey, defaultValue: {}));

    final alreadyVerified = hiveOrder["age_verified"] == true ||
        hiveOrder["age_verified"] == 1 ||
        hiveOrder["age_verified"]?.toString().toLowerCase() == "true";

    if (alreadyVerified) {
      print(" Age already verified → Skipping popup");
      stopwatch.stop();
      _logTime("AgeVerified", stopwatch.elapsedMilliseconds);
      return true;
    }

    print(" Showing Age Verification Popup");
    final prov = AgeVerificationProvider();
    final isVerified = await prov.verifyAge(context, minAge: minAge);

    if (isVerified) {
      hiveOrder["age_verified"] = true;
      await box.put(orderKey, hiveOrder);
      print(" Saved age_verified = TRUE for order $orderKey");
    }

    stopwatch.stop();
    _logTime("AgePopup", stopwatch.elapsedMilliseconds);
    return isVerified;
  }

  Future<double> _handleVariablePrice(
      BuildContext context,
      int orderId,
      int productId,
      String productName,
      String productImage,
      double defaultPrice,
      ) async {
    final stopwatch = Stopwatch()..start();

    final box = Hive.box('offlineOrders');
    final orderKey = orderId.toString();
    final hiveOrder = Map<String, dynamic>.from(box.get(orderKey, defaultValue: {}));

    final variableKey = "variable_price_added_$productId";
    final savedPriceKey = "selected_price_$productId";
    final savedPrice = hiveOrder[savedPriceKey];

    // Check if already added before
    final alreadyAddedBefore = hiveOrder[variableKey] == true ||
        hiveOrder[variableKey] == 1 ||
        hiveOrder[variableKey]?.toString().toLowerCase() == "true";

    if (alreadyAddedBefore && savedPrice != null) {
      print(" Variable product already added → Using saved price: ₹$savedPrice");
      stopwatch.stop();
      _logTime("VarPriceSaved", stopwatch.elapsedMilliseconds);
      return savedPrice;
    }

    // First time - show manual price dialog
    print(" First-time variable product → showing manual price popup");
    final enteredPrice = await ManualPriceDialog.show(
      context,
      productName: productName,
      productImage: productImage,
      minPrice: defaultPrice,
    );

    if (enteredPrice == null) {
      stopwatch.stop();
      _logTime("VarPriceCancelled", stopwatch.elapsedMilliseconds);
      return -1; // Cancelled
    }

    // Save flags
    hiveOrder[variableKey] = true;
    hiveOrder[savedPriceKey] = enteredPrice;
    await box.put(orderKey, hiveOrder);

    print(" Stored $variableKey = true");
    print(" Stored $savedPriceKey = $enteredPrice");

    stopwatch.stop();
    _logTime("VarPriceNew", stopwatch.elapsedMilliseconds);
    return enteredPrice;
  }

  Future<void> _handleVariants(
      BuildContext context,
      int productId,
      String productName,
      String productImage,
      double productPrice,
      String productSku,
      int activeOrderId,
      bool isEbtEligible,
      int itemIndex,
      ) async {
    final stopwatch = Stopwatch()..start();
    print(" Product has variants → Loading offline variants...");
    List<Map<String, dynamic>> offlineVariations = [];

    try {
      final productBox = Hive.box('productCache');
      final cacheKey = "product_${productId}_variations";

      // Measure Hive access time
      final hiveStopwatch = Stopwatch()..start();
      final cachedData = productBox.get(cacheKey);
      hiveStopwatch.stop();
      _logTime("HiveAccess", hiveStopwatch.elapsedMilliseconds);

      List rawVariations = [];

      // Process cached data
      if (cachedData != null) {
        final processStopwatch = Stopwatch()..start();
        rawVariations = _extractVariationsFromCache(cachedData);
        processStopwatch.stop();
        _logTime("CacheProcess", processStopwatch.elapsedMilliseconds);
      }

      // Fallback to item variations
      if (rawVariations.isEmpty) {
        final buildStopwatch = Stopwatch()..start();
        rawVariations = await _buildVariationsFromItem(productId, productBox, productPrice, productImage);
        buildStopwatch.stop();
        _logTime("BuildVariants", buildStopwatch.elapsedMilliseconds);
      }

      // Normalize variations
      final normalizeStopwatch = Stopwatch()..start();
      offlineVariations = _normalizeVariations(rawVariations, productImage, productPrice);
      normalizeStopwatch.stop();
      _logTime("Normalize", normalizeStopwatch.elapsedMilliseconds);

      // Show variants dialog
      final dialogStopwatch = Stopwatch()..start();
      await showDialog(
        context: context,
        builder: (ctx) => VariantsDialog(
          title: productName,
          variations: offlineVariations,
          onAddVariant: (selectedVariant, qty) async {
            final addStopwatch = Stopwatch()..start();

            // INSTANT UI FEEDBACK for variants too
            final uiUpdateStart = DateTime.now().millisecondsSinceEpoch;
            onItemTapped(itemIndex, variantAdded: true);
            final uiUpdateTime = DateTime.now().millisecondsSinceEpoch - uiUpdateStart;
            _logTime("UI_VariantInstant", uiUpdateTime, isUi: true, isCritical: true);

            // Run backend async
            Future.microtask(() async {
              final variantId = int.tryParse(selectedVariant["id"].toString()) ?? -1;
              final variantName = selectedVariant["name"] ?? "Variant";
              final variantPrice = double.tryParse(selectedVariant["price"].toString()) ?? productPrice;
              final variantSku = selectedVariant["sku"] ?? productSku;
              final variantImage = selectedVariant["image"] ?? productImage;

              await orderHelper?.addItemToOrder(
                0,
                variantName,
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
                onItemAdded: () {
                  print(" Variant backend add completed");
                },
              );
            });

            addStopwatch.stop();
            _logTime("Variant_BackendAsync", addStopwatch.elapsedMilliseconds);
          },
        ),
      );
      dialogStopwatch.stop();
      _logTime("VariantDialog", dialogStopwatch.elapsedMilliseconds);
    } catch (e, st) {
      print(" Error handling variants: $e");
      print(st);
    }

    stopwatch.stop();
    _logTime("HandleVariantsTotal", stopwatch.elapsedMilliseconds);
  }

  List _extractVariationsFromCache(dynamic cachedData) {
    final stopwatch = Stopwatch()..start();
    List result = [];

    if (cachedData is Map && cachedData["variations"] is List) {
      result = cachedData["variations"];
    } else if (cachedData is List) {
      result = cachedData;
    } else if (cachedData is String) {
      try {
        final decoded = jsonDecode(cachedData);
        result = decoded is Map ? decoded["variations"] ?? [] : decoded;
      } catch (_) {
        print(" Error decoding cachedData string");
      }
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("ExtractVariations", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  Future<List> _buildVariationsFromItem(
      int productId,
      Box productBox,
      double productPrice,
      String productImage,
      ) async {
    final stopwatch = Stopwatch()..start();
    final List variations = [];
    final item = _productMetaCache[productId];

    if (item?["variations"] is List) {
      final List variationIds = item!["variations"];

      // Process in batches for Android
      final batchSize = 5;
      for (int i = 0; i < variationIds.length; i += batchSize) {
        final end = i + batchSize < variationIds.length ? i + batchSize : variationIds.length;
        for (int j = i; j < end; j++) {
          final id = variationIds[j];
          var variantData = productBox.get("product_$id");

          if (variantData == null) continue;

          if (variantData is String) {
            try {
              variantData = jsonDecode(variantData);
            } catch (_) {}
          }

          String name = "";
          if (variantData?["name"] != null && variantData["name"].toString().isNotEmpty) {
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

          variations.add({
            "id": id,
            "name": name,
            "price": price,
            "sku": variantData?["sku"] ?? "",
            "image": image,
          });
        }

        // Small delay to prevent Android UI freeze
        if (Platform.isAndroid) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
    }

    stopwatch.stop();
    _logTime("BuildVariantsBatch", stopwatch.elapsedMilliseconds);
    return variations;
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

  List<Map<String, dynamic>> _normalizeVariations(
      List rawVariations,
      String fallbackImage,
      double fallbackPrice,
      ) {
    final stopwatch = Stopwatch()..start();
    final result = rawVariations.map<Map<String, dynamic>>((v) {
      if (v is String) {
        try {
          v = jsonDecode(v);
        } catch (_) {}
      }

      if (v is Map) {
        final map = v.map((key, value) => MapEntry(key.toString(), value));

        map["image"] = (map["image"] is Map && map["image"]["src"] != null)
            ? map["image"]["src"]
            : (map["image"] is String ? map["image"] : fallbackImage);

        map["name"] = (map["name"] is Map && map["name"]["rendered"] != null)
            ? map["name"]["rendered"]
            : (map["name"] is String ? map["name"] : "Unnamed Variant");

        map["price"] = map["price"]?.toString() ?? fallbackPrice.toString();

        return map;
      }

      return <String, dynamic>{};
    }).where((v) => v.isNotEmpty).toList();

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      _logTime("NormalizeBatch", stopwatch.elapsedMilliseconds);
    }
    return result;
  }

  /// Customize products card layout for the grid
  Widget _getCardWidget(
      Widget widget,
      ThemeNotifier themeHelper, {
        MaterialAccentColor accentColor = Colors.blueAccent,
      }) {
    return Card(
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Colors.white,
      elevation: 5,
      shadowColor: accentColor,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: accentColor,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: widget,
    );
  }

  Future<void> updateOrderPanel(int index) async {
    onItemTapped(index, variantAdded: true);
  }
}