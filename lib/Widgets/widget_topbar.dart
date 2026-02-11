import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';

import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/isar_cache_entry.dart';
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_search_model.dart';
import '../Models/Search/product_variation_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Category/category_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/responsive_layout.dart';
import '../Utilities/svg_images_utility.dart';
import 'ManualPriceDialog.dart';
import 'OrderPopupHelper.dart';

import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;

enum Screen { FASTKEY, CATEGORY, ADD, ORDERS, APPS, SHIFT, SAFE, EDIT }

class _PinBoxField extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;

  const _PinBoxField({required this.controller, required this.hasError});

  @override
  State<_PinBoxField> createState() => _PinBoxFieldState();
}

class _PinBoxFieldState extends State<_PinBoxField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: widget.controller,
        maxLength: 6,
        autofocus: true,
        keyboardType: TextInputType.text,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          letterSpacing: 14,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: isDark ? const Color(0xFF40424F) : const Color(0xFFF2F4F8),
          suffixIcon: IconButton(
            splashRadius: 13,
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: isDark ? Colors.white54 : Colors.grey),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.hasError ? Colors.red : Colors.transparent, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.hasError ? Colors.red : Colors.redAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatefulWidget {
  final Function() onModeChanged;
  final Function(ProductResponse)? onProductSelected;
  final Screen screen;

  const TopBar({
    required this.screen,
    required this.onModeChanged,
    this.onProductSelected,
    super.key,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late BuildContext _context;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  final _searchFieldKey = GlobalKey();

  final orderHelper = OrderHelper();
  late OrderBloc _orderBloc;

  bool isAddingItemLoading = false;
  int? userId;
  String? userRole;
  String? userDisplayName;

  bool _isSearchEnabled = true;
  var _printerSettings = PrinterSettings();

  List<dynamic> _cachedProducts = [];
  bool _cacheLoaded = false;
  final ProductBloc productBloc = ProductBloc(ProductRepository());

  bool _dialogOpen = false;


  @override
  void initState() {
    super.initState();
    _orderBloc = OrderBloc(OrderRepository());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _fetchUserId();
    _isSearchEnabled = widget.screen != Screen.ORDERS && widget.screen != Screen.APPS;

    _loadCachedProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _orderBloc.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadCachedProducts() async {
    try {
      final repo = CategoryRepository();
      final products = await repo.getAllCachedProducts();
      setState(() {
        _cachedProducts = products;
        _cacheLoaded = true;
      });
    } catch (e) {
      debugPrint("Failed to load cached products: $e");
    }
  }

  String _getProductImage(dynamic product) {
    try {
      if (product.images != null && product.images!.isNotEmpty) {
        final img = product.images!.first;
        if (img is String && img.isNotEmpty) return img;
        if (img is Map && img["src"] != null) return img["src"].toString();
      }
    } catch (_) {}
    return "";
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty && _overlayEntry == null) {
      _showSearchResultsOverlay();
    } else if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      _removeOverlay();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _searchController.text.toLowerCase();

      print('Search query: "$query"');

      if (query.isEmpty) {
        _removeOverlay();
        setState(() {});
        return;
      }

      if (_overlayEntry == null) {
        _showSearchResultsOverlay();
      } else {
        _overlayEntry?.markNeedsBuild();
      }

      setState(() {});
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _removeOverlay();
    _searchFocusNode.unfocus();
    setState(() {});
  }

  void _showSearchResultsOverlay() {
    if (_overlayEntry != null || _dialogOpen) return; // 🔥 ADD THIS

    final box = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Provider.of<ThemeNotifier>(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _removeOverlay();
                  _searchFocusNode.unfocus();
                },
              ),
            ),
            Positioned(
              width: size.width,
              left: offset.dx,
              top: offset.dy + size.height,
              child: Material(
                elevation: 6,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(
                    color: theme.themeMode == ThemeMode.dark
                        ? ThemeNotifier.secondaryBackground
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildLocalResultsList(),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildLocalResultsList() {
    final query = _searchController.text.toLowerCase();

    if (!_cacheLoaded) return const Center(child: CircularProgressIndicator());
    if (_cachedProducts.isEmpty) return const Center(child: Text("No products in cache"));

    final Map<String, dynamic> unique = {};
    for (final p in _cachedProducts) {
      final name = (p["fast_key_item_name"] ?? "").toString().trim().toLowerCase();
      if (name.isEmpty || !name.contains(query)) continue;
      unique[name] = p;
    }

    final list = unique.values.toList()
      ..sort((a, b) {
        final na = (a["fast_key_item_name"] ?? "").toString().toLowerCase();
        final nb = (b["fast_key_item_name"] ?? "").toString().toLowerCase();
        final sa = na.startsWith(query);
        final sb = nb.startsWith(query);
        if (sa && !sb) return -1;
        if (!sa && sb) return 1;
        return na.compareTo(nb);
      });

    if (list.isEmpty) return const Center(child: Text("No products found"));

    return ListView.builder(
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p = list[i];
        final name = p["fast_key_item_name"]?.toString() ?? "Unknown";
        final price = p["fast_key_item_price"]?.toString() ?? "0.00";

        String? imageUrl;
        final imagesRaw = p["images"];
        if (imagesRaw != null) {
          if (imagesRaw is String && imagesRaw.isNotEmpty) {
            imageUrl = imagesRaw;
          } else if (imagesRaw is List && imagesRaw.isNotEmpty) {
            final first = imagesRaw.first;
            if (first is String) imageUrl = first;
            else if (first is Map && first["src"] != null) imageUrl = first["src"].toString();
          }
        }
        imageUrl ??= p["fast_key_item_image"]?.toString();

        return ListTile(
          leading: SizedBox(
            width: 50,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
              )
                  : const Icon(Icons.image, size: 40),
            ),
          ),
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text("\$${price}"),
          onTap: () async {
            ProductResponse fullProduct = ProductResponse(
              id: int.tryParse(p["fast_key_product_id"]?.toString() ?? "0") ?? 0,
              name: name,
              price: price,
              sku: p["sku"]?.toString(),
              images: imageUrl != null ? [imageUrl] : [],
            );

            try {
              final isar = await IsarService.instance;
              final entries = await isar.isarCacheEntrys
                  .where()
                  .filter()
                  .keyStartsWith("products_")
                  .findAll();

              for (final entry in entries) {
                final List<dynamic> cached = jsonDecode(entry.json);
                final match = cached.firstWhere(
                      (item) => item["fast_key_product_id"]?.toString() == p["fast_key_product_id"]?.toString(),
                  orElse: () => null,
                );

                if (match != null) {
                  final rawTags = match["tags"];
                  if (rawTags is List) {
                    fullProduct.tags = rawTags.map((t) {
                      return SKU.Tags(
                        id: t["id"],
                        name: t["name"],
                        slug: t["slug"],
                      );
                    }).toList();
                  }
                  break;
                }
              }
            } catch (e) {
              debugPrint("Enrich product failed: $e");
            }

            _handleProductTap(fullProduct);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getVariantsFromCache(int productId) async {
    final isar = await IsarService.instance;
    final entries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith("products_")
        .findAll();

    for (final entry in entries) {
      final List<dynamic> products = jsonDecode(entry.json);

      final match = products.firstWhere(
            (p) => p["fast_key_product_id"]?.toString() == productId.toString(),
        orElse: () => null,
      );

      if (match == null) continue;

      final rawVariations = match["variations"];
      if (rawVariations is! List || rawVariations.isEmpty) continue;

      final List<Map<String, dynamic>> variants = [];

      for (final v in rawVariations) {
        if (v is Map<String, dynamic>) {
          variants.add({
            "id": v["id"],
            "name": v["name"] ?? (v["attributes"] as List?)?.map((a) => a["option"]).join(" - "),
            "price": v["regular_price"] ?? v["price"] ?? "0",
            "image": v["image"]?["src"],
            "sku": v["sku"],
          });
        } else if (v is int) {
          variants.add({
            "id": v,
            "name": "Variant",
            "price": match["price"] ?? "0",
            "image": match["image"],
            "sku": match["sku"],
          });
        }
      }

      if (variants.isNotEmpty) return variants;
    }

    return [];
  }

  // ──────────────────────────────────────────────────────────────
  // FIXED VERSION – removes overlay before EVERY popup
  // ──────────────────────────────────────────────────────────────
  Future<void> _handleProductTap(ProductResponse product) async {
    try {
      _searchFocusNode.unfocus();
      _removeOverlay();

      var screen = widget.screen;
      if (screen != Screen.FASTKEY && screen != Screen.CATEGORY && screen != Screen.ADD) {
        if (kDebugMode) print("TopBar - return from product selection (invalid screen)");
        return;
      }

      // ✅ Ensure order exists (create or restore)
      final ensuredOrderId = await orderHelper?.ensureOrderExists();

      if (ensuredOrderId == null) {
        if (kDebugMode) {
          print("❌ Failed to create or restore order");
        }
        return; // 🚫 Stop product add
      }

      final offlineBox = Hive.box('offlineOrders');
      final activeOrderId = ensuredOrderId.toString();

      final Map<String, dynamic> rawOrder =
      Map<String, dynamic>.from(
        offlineBox.get(activeOrderId) ?? {},
      );

      print("CATEGORY FLOW ITEMS: ${rawOrder['products']}");
      print("LINE ITEMS: ${rawOrder['line_items']}");

      final List<dynamic> lineItems =
      List<dynamic>.from(rawOrder['line_items'] ?? []);

      // ─── Age verification ────────────────────────────────────────
      final tags = product.tags ?? [];
      final bool hasAgeRestriction =
      tags.any((t) => t.name == TextConstants.age_restricted);

      SKU.Tags? ageRestrictedTag;
      if (hasAgeRestriction) {
        ageRestrictedTag =
            tags.firstWhere((t) => t.name == TextConstants.age_restricted);
      }

      final dynamic hiveAge = rawOrder["age_verified"];
      final bool alreadyVerified =
          hiveAge == true ||
              hiveAge == 1 ||
              hiveAge?.toString().toLowerCase() == "true";

      if (hasAgeRestriction && !alreadyVerified) {
        final int minAge =
            int.tryParse(ageRestrictedTag?.slug?.toString() ?? "0") ?? 0;

        print("🔞 Showing Age Verification Popup (SEARCH)");

        _dialogOpen = true; // 🔥 LOCK SEARCH OVERLAY

        _searchFocusNode.unfocus();
        _removeOverlay();
        await WidgetsBinding.instance.endOfFrame;

        final prov = AgeVerificationProvider();
        final ok = await prov.verifyAge(
          context,
          minAge: minAge,
        );

        _dialogOpen = false; // 🔓 UNLOCK SEARCH OVERLAY

        if (!ok) {
          print("❌ Age verification failed → Block product");
          return;
        }

        rawOrder["age_verified"] = true;
        await offlineBox.put(activeOrderId, rawOrder);

        print("💾 Saved age_verified = true for search flow");
      }


      // ─── EBT eligibility ─────────────────────────────────────────
      bool isEbtEligible = false;

      try {
        final isar = await IsarService.instance;

        final cachedEntries = await isar.isarCacheEntrys
            .where()
            .filter()
            .keyStartsWith("products_")
            .findAll();

        for (final entry in cachedEntries) {
          final List<dynamic> products = jsonDecode(entry.json);

          final match = products.firstWhere(
                (p) => p["fast_key_product_id"]?.toString() == product.id.toString(),
            orElse: () => null,
          );

          if (match != null) {
            isEbtEligible = match["is_ebt_eligible"] == true;

            if (kDebugMode) {
              print("🥗 EBT FOUND (ISAR) → ${match["fast_key_item_name"]} | Eligible: $isEbtEligible");
            }
            break;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("⚠️ Error resolving EBT eligibility (ISAR): $e");
        }
      }

      // ─── Variable / variants logic ───────────────────────────────

      final double productPrice = (product.price is num)
          ? (product.price as num).toDouble()
          : double.tryParse(product.price?.toString() ?? "") ?? 0.0;

      double finalPrice = productPrice;

      final bool hasVariablePriceTag = tags.any((t) =>
      t.slug?.toLowerCase() == "variable-product" ||
          t.slug?.toLowerCase() == "variable" ||
          t.name?.toLowerCase() == "variable product" ||
          t.name?.toLowerCase() == "variable");

      List<Map<String, dynamic>> products = (rawOrder["products"] ?? [])
          .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
          .toList();

      final String variableKey = "variable_price_added_${product.id}";
      final String savedPriceKey = "selected_price_${product.id}";

      final bool popupAlreadyShown = rawOrder[variableKey] == true;

      if (popupAlreadyShown) {
        final savedPrice = rawOrder[savedPriceKey] ?? productPrice;
        finalPrice = double.tryParse(savedPrice.toString()) ?? productPrice;
      }

      bool hasVariants = false;

      final cachedVariants = await _getVariantsFromCache(product.id!);
      hasVariants = cachedVariants.isNotEmpty;

      if (!hasVariants) {
        productBloc.fetchProductVariations(product.id!);
        final response = await productBloc.variationStream
            .firstWhere((r) => r.status == Status.COMPLETED);

        hasVariants = response.data != null && response.data!.isNotEmpty;
      }

      if (hasVariants) {
        productBloc.fetchProductVariations(product.id!);

        final response = await productBloc.variationStream
            .firstWhere((r) => r.status == Status.COMPLETED);

        List<Map<String, dynamic>> variants = [];

        if (response.data != null && response.data!.isNotEmpty) {
          variants = response.data!.map((v) => {
            "id": v.id,
            "name": v.name ?? "Variant",
            "price": v.price ?? "0",
            "image": v.image?.src ?? "",
            "sku": v.sku ?? "",
          }).toList();
        } else {
          variants = cachedVariants;
        }

        if (variants.isEmpty) return;

        // ─── FIX: Aggressive overlay removal before variants popup ───
        _removeOverlay();
        await Future.delayed(const Duration(milliseconds: 40));
        _removeOverlay();

        await showDialog(
          context: _context,
          barrierDismissible: false,
          builder: (_) => VariantsDialog(
            title: product.name ?? "Select Variant",
            variations: variants,
            onAddVariant: (selected, qty) async {
              final price = double.tryParse(selected["price"].toString()) ?? 0;

              await orderHelper.addItemToOrder(
                selected["id"],
                selected["name"],
                selected["image"],
                price,
                qty,
                selected["sku"],
                int.parse(activeOrderId),
                type: 'variant',
                productId: product.id,
                variationId: selected["id"],
                isEbtEligible: isEbtEligible,
                onItemAdded: () {
                  _removeOverlay();
                  _clearSearch();

                  if (mounted) {
                    setState(() => isAddingItemLoading = false);
                  }

                  widget.onProductSelected?.call(product);
                },
              );
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        );

        _removeOverlay();
        _clearSearch();
        setState(() => isAddingItemLoading = false);
        return;
      }

      if (hasVariablePriceTag && !popupAlreadyShown) {
        // ─── FIX: Aggressive overlay removal before manual price popup ───
        _removeOverlay();
        await Future.delayed(const Duration(milliseconds: 40));
        _removeOverlay();

        final enteredPrice = await ManualPriceDialog.show(
          _context,
          productName: product.name ?? "Product",
          productImage: _getProductImage(product),
          minPrice: productPrice,
        );

        if (enteredPrice == null) return;

        finalPrice = enteredPrice;
        rawOrder[variableKey] = true;
        rawOrder[savedPriceKey] = finalPrice;
        await offlineBox.put(activeOrderId, rawOrder);
      }

      setState(() => isAddingItemLoading = true);

      try {
        final pid = product.id!;
        final psku = product.sku ?? '';
        final image = product.images?.isNotEmpty == true ? product.images!.first : '';

        await orderHelper.addItemToOrder(
          pid,
          product.name ?? 'Unknown',
          image,
          finalPrice,
          1,
          psku,
          int.tryParse(activeOrderId) ?? 0,
          type: "simple",
          productId: pid,
          variationId: -1,
          variationName: null,
          variationCount: 0,
          combo: null,
          salesPrice: finalPrice,
          regularPrice: finalPrice,
          unitPrice: finalPrice,
          isEbtEligible: isEbtEligible,
          onItemAdded: () {
            _removeOverlay();
            _clearSearch();
            setState(() => isAddingItemLoading = false);
            widget.onProductSelected?.call(product);
          },
        );
      } catch (e, s) {
        print("❌ Simple product add error: $e\n$s");
        _removeOverlay();
        setState(() => isAddingItemLoading = false);
      }
    } catch (e, s) {
      if (kDebugMode) print("TopBar onTap Exception: $e\n$s");
      _removeOverlay();
      setState(() => isAddingItemLoading = false);
    }
  }

  void _removeOverlay() {
    if (kDebugMode) print("TopBar - _removeOverlay | exists: ${_overlayEntry != null}");
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _fetchUserId() async {
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        userRole = userData[AppDBConst.userRole];
      });
    }
  }

  Future<bool> _showCashDrawerPinPopup(BuildContext context) async {
    final TextEditingController pinController = TextEditingController();
    bool isError = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: isDark
                    ? const Color(0xFF2F3241)
                    : Colors.white,
                child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔐 Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "Authentication Required ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Enter PIN to open cash drawer",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Inter',
                            color: isDark
                                ? Colors.white60
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 18),

                        // 🔢 PIN BOXES
                        _PinBoxField(
                          controller: pinController,
                          hasError: isError,
                        ),

                        if (isError) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "You are not authorized to access this feature.",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 🔘 ACTION BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFF50535F)
                                      : const Color(0xFFE0E0E0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final pin = pinController.text.trim();

                                  if (pin.length != 6) {
                                    setState(() => isError = true);
                                    return;
                                  }

                                  setState(() => isError = false);

                                  try {
                                    final response =
                                    await OrderRepository().validateLoginPin(pin); // ✅ positional

                                    final decoded = json.decode(response);

                                    if (decoded["success"] == true) {
                                      Navigator.pop(ctx, true);
                                    } else {
                                      setState(() => isError = true);
                                      pinController.clear();
                                    }
                                  } catch (e) {
                                    setState(() => isError = true);
                                    pinController.clear();
                                  }
                                },


                                child: const Text(
                                  "Confirm",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ));
          },
        );
      },
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SvgPicture.asset(
            themeHelper.themeMode == ThemeMode.dark ? 'assets/svg/app_logo.svg' : 'assets/svg/app_icon.svg',
            height: 40,
            width: 40,
          ),
          const SizedBox(width: 80),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF3B3939) : const Color(0xFFEDEBEB)),
                boxShadow: [
                  BoxShadow(
                    color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF605F5F) : Colors.grey.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              height: 46,
              key: _searchFieldKey,
              child: TextField(
                enabled: _isSearchEnabled,
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: TextConstants.searchHint,
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color), onPressed: _clearSearch)
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.searchBarBackground : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 200),
          GestureDetector(
            onTap: () async {
              final isAuthorized = await _showCashDrawerPinPopup(context);
              if (!isAuthorized) return;

              /// ✅ ACTUAL CASH DRAWER OPEN
              await PrinterSettings.openDrawer(context: context);

              List<int> bytes = [];
              final ticket = await _printerSettings.getTicket();
              bytes += ticket.feed(1);
              await _printerSettings.printTicket(bytes, ticket);
            },

            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF3B3939) : const Color(0xFFF1F1F3)),
              ),
              child: SvgPicture.asset(SvgUtils.cashDrawerIcon, width: 26, height: 26, colorFilter: ColorFilter.mode(themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey, BlendMode.srcIn)),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: widget.onModeChanged,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF3B3939) : const Color(0xFFF1F1F3)),
              ),
              child: SvgPicture.asset(SvgUtils.changeModeIcon, width: 26, height: 26, colorFilter: ColorFilter.mode(themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey, BlendMode.srcIn)),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              themeHelper.setThemeMode(themeHelper.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF605F5F) : const Color(0xFFF1F1F3)),
              ),
              child: SvgPicture.asset(SvgUtils.themeIcon, width: 26, height: 26, colorFilter: ColorFilter.mode(themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.grey, BlendMode.srcIn)),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF3B3939) : const Color(0xFFF1F1F3)),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.notifications, size: 24, color: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black54),
          ),
          const SizedBox(width: 16),
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF3B3939) : const Color(0xFFF1F1F3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    (userDisplayName ?? "Unknown").substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userDisplayName ?? "",
                      style: TextStyle(fontWeight: FontWeight.w500, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight, fontSize: 14),
                    ),
                    Text(
                      userRole ?? "Unknown",
                      style: TextStyle(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFFE09696) : const Color(0xFFE09696), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}