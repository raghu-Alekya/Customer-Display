// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import '../Constants/text.dart';
// import '../Utilities/constants.dart';
//
// class TopBar extends StatelessWidget { // Old Code
//   final Function() onModeChanged;
//
//   const TopBar({required this.onModeChanged, Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context); // Build #1.0.6 - Added theme for top bar
//     return Container(
//       height: 60,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//      // color: theme.appBarTheme.backgroundColor,
//       child: Row(
//         children: [
//           SvgPicture.asset(
//             'assets/svg/app_logo.svg',
//             height: 40,
//             width: 40,
//           ),
//           const SizedBox(width: 140),
//            Expanded(
//             child: Container( // Build #1.0.6
//               height: 50,
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: AppConstants.searchHint,
//                   prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(8)),
//                     borderSide: BorderSide.none,
//                   ),
//                   filled: true,
//                  // fillColor: theme.dividerColor,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 140),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 onPressed: () {},
//                 icon: const Icon(Icons.calculate),
//               ),
//               const Text(
//                 TextConstants.calculatorText,
//                 style: TextStyle(fontSize: 8),
//               ),
//             ],
//           ),
//           const SizedBox(width: 8),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 onPressed: () {},
//                 icon: const Icon(Icons.pause),
//               ),
//               const Text(
//                 TextConstants.holdText,
//                 style: TextStyle(fontSize: 8),
//               ),
//             ],
//           ),
//           const SizedBox(width: 8),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 onPressed: onModeChanged,
//                 icon: const Icon(Icons.switch_right),
//               ),
//               const Text(
//                 TextConstants.modeText,
//                 style: TextStyle(fontSize: 8),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:flutter_svg/svg.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:hive/hive.dart';
import 'package:pinaka_pos/Constants/misc_features.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_drawer.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus_platform_interface.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/enums.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/generator.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Orders/get_orders_model.dart' as model;
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_search_model.dart';
import '../Models/Search/product_variation_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/responsive_layout.dart';
import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;

import '../Utilities/svg_images_utility.dart';
enum Screen { FASTKEY, CATEGORY, ADD, ORDERS, APPS, SHIFT, SAFE, EDIT }
class TopBar extends StatefulWidget { // Build #1.0.13 : Updated top bar with search api integration
  final Function() onModeChanged;
  // final Function() onThemeChanged;
  final Function(ProductResponse)? onProductSelected;
  final Screen screen;

  const TopBar({
    required this.screen,
    required this.onModeChanged,
    // required this.onThemeChanged,
    this.onProductSelected,
    Key? key,
  }) : super(key: key);

  @override
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late BuildContext _context;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  final ProductBloc _productBloc = ProductBloc(ProductRepository());
  OverlayEntry? _overlayEntry;
  final GlobalKey _searchFieldKey = GlobalKey();
  final OrderHelper orderHelper = OrderHelper();
  late OrderBloc _orderBloc;
  StreamSubscription? _updateOrderSubscription;
  bool isAddingItemLoading = false; // Loader for adding items to order
  int? userId;
  String? userRole;
  String? userDisplayName;
  String? _lastSearchQuery; // Build #1.0.120: Track last searched query to avoid redundant fetches
  bool _isSearchEnabled = true;
  var _printerSettings =  PrinterSettings();

  @override
  void initState() {
    super.initState();
    _orderBloc = OrderBloc(OrderRepository());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _fetchUserId();
    _isSearchEnabled = !(widget.screen == Screen.ORDERS || widget.screen == Screen.APPS);// to restrict search box
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _updateOrderSubscription?.cancel(); // Add this if missing
    _searchFocusNode.dispose();
    _productBloc.dispose();
    _orderBloc.dispose();
    _removeOverlay();
    super.dispose();
  }

  // This method creates a semi-transparent overlay with a centered CircularProgressIndicator to indicate loading during API calls.
  // It reuses _overlayEntry to manage the overlay, ensuring only one overlay is shown at a time.
  void _showLoaderOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => AbsorbPointer( // Build #1.0.200: Prevent dismissing by tapping outside
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onFocusChanged() { // Build #1.0.120: Fixed : result are reloading after dismissal of keypad
    if (kDebugMode) {
      print("TopBar - _onFocusChanged: hasFocus=${_searchFocusNode.hasFocus}, text='${_searchController.text}', overlayExists=${_overlayEntry != null}");
    }
    // Show overlay only if text field has focus, text is not empty, and no overlay exists
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty && _overlayEntry == null) {
      _showSearchResultsOverlay();
    } else if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      _removeOverlay();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () { // Build #1.0.120: Fixed : result are reloading after dismissal of keypad
      if (kDebugMode) {
        print("TopBar - _onSearchChanged: Debounce timer completed, processing search for '${_searchController.text}'");
      }

      //Build #1.0.134: fixed - shoes getting overlapped with age verification dialog
      // Only proceed if we have focus and text has actually changed
      if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty && _searchController.text != _lastSearchQuery) {
        if (kDebugMode) {
          print("TopBar - _onSearchChanged: Fetching products for new query '${_searchController.text}'");
        }
        _lastSearchQuery = _searchController.text;
        _productBloc.fetchProducts(searchQuery: _searchController.text);

        if (_overlayEntry == null) { // Show overlay only if text field has focus and no overlay exists
          _showSearchResultsOverlay();
        }
      } else if (_searchController.text.isEmpty) {
        _lastSearchQuery = null;
        _removeOverlay();
      }
      setState(() {}); // Rebuild to update clear button visibility
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _lastSearchQuery = null;
    _removeOverlay();
    _searchFocusNode.unfocus();
    setState(() {}); // Rebuild to hide clear button
  }

  void _showSearchResultsOverlay() {
    if (_overlayEntry != null) return; // Prevent duplicate overlays

    final searchFieldBox = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (searchFieldBox == null) return;

    final searchFieldOffset = searchFieldBox.localToGlobal(Offset.zero);
    final searchFieldSize = searchFieldBox.size;

    _overlayEntry = OverlayEntry(
        builder: (context) {
          final themeHelper = Provider.of<ThemeNotifier>(context);
          return Stack(
              children: [
                // 🔥 FULL SCREEN CLICK DETECTOR
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _removeOverlay(); // 👈 auto close
                      _searchFocusNode.unfocus();
                    },
                  ),
                ),

                Positioned(
                  width: searchFieldSize.width,
                  left: searchFieldOffset.dx,
                  top: searchFieldOffset.dy + searchFieldSize.height,
                  child: Material(
                    elevation: 4,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color:themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: StreamBuilder<APIResponse<List<ProductResponse>>>(
                        stream: _productBloc.productStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            switch (snapshot.data!.status) {
                              case Status.LOADING:
                                if (kDebugMode) print("#### 2222 Status is LOADING");
                            // return const Center( //
                            //   child: Padding(
                            //     padding: EdgeInsets.all(16),
                            //     child: CircularProgressIndicator(),
                            //   ),
                            // );
                              case Status.COMPLETED:
                                final products = snapshot.data!.data;
                                if (products == null || products.isEmpty) {
                                  if (kDebugMode) {
                                    print("TopBar - result found no product with search text COMPLETED $_overlayEntry");
                                  }

                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No products found'),
                                  );
                                }
                                if (kDebugMode) {
                                  print("TopBar - result found product with search text COMPLETED ${products.length}");
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    return ListTile(
                                        leading: product.images != null && product.images!.isNotEmpty
                                            ? SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Image.network(
                                            product.images!.first,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(Icons.image, size: 40);
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: CircularProgressIndicator(),
                                              );
                                            },
                                          ),
                                        )
                                            : const Icon(Icons.image, size: 40,),
                                        title: Text(product.name ?? ''),
                                        subtitle: Text('${TextConstants.currencySymbol}${double.tryParse(product.price.toString())?.toStringAsFixed(2) ?? "0.00"}'),
                                        onTap: () async {
                                          try {
                                            // 🟩 Step 1: Initial cleanup and validation
                                            _searchFocusNode.unfocus();
                                            _removeOverlay();

                                            var screen = widget.screen;
                                            if (screen != Screen.FASTKEY && screen != Screen.CATEGORY && screen != Screen.ADD) {
                                              if (kDebugMode) print("TopBar - return from product selection (invalid screen)");
                                              return;
                                            }

                                            final serverOrderId = orderHelper.activeOrderId;
                                            final dbOrderId = orderHelper.activeOrderId;
                                            final offlineBox = Hive.box('offlineOrders');

                                            // 🟥 Step 2: Check order existence
                                            if (dbOrderId == null) {
                                              ScaffoldMessenger.of(_context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("No active order selected"),
                                                  backgroundColor: Colors.red,
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                              return;
                                            }

                                            final activeOrderId = dbOrderId.toString();
                                            final Map<String, dynamic> rawOrder =
                                            Map<String, dynamic>.from(offlineBox.get(activeOrderId) ?? {});

                                            print("CATEGORY FLOW ITEMS: ${rawOrder['products']}");
                                            print("LINE ITEMS: ${rawOrder['line_items']}");

                                            List<dynamic> lineItems = List.from(rawOrder['line_items'] ?? []);

                                            // 🟨 Step 3: Check for age restriction
                                            /// 🟨 Step 3: Check for age restriction

// Safely get tags list
                                            final tags = product.tags ?? [];

// Check if any tag is age_restricted
                                            final bool hasAgeRestriction =
                                            tags.any((t) => t.name == TextConstants.age_restricted);

// Only fetch the tag if it actually exists
                                            SKU.Tags? ageRestrictedTag;
                                            if (hasAgeRestriction) {
                                              ageRestrictedTag =
                                                  tags.firstWhere((t) => t.name == TextConstants.age_restricted);
                                            }

// Read existing age flag from order
                                            final dynamic hiveAge = rawOrder["age_verified"];

                                            final bool alreadyVerified =
                                                hiveAge == true ||
                                                    hiveAge == 1 ||
                                                    hiveAge?.toString().toLowerCase() == "true";

                                            if (hasAgeRestriction && !alreadyVerified) {
                                              final int minAge =
                                                  int.tryParse(ageRestrictedTag?.slug?.toString() ?? "0") ?? 0;

                                              print("🔞 Showing Age Verification Popup (SEARCH)");

                                              final prov = AgeVerificationProvider();
                                              final ok = await prov.verifyAge(context, minAge: minAge);

                                              if (!ok) {
                                                print("❌ Age verification failed → Block product");
                                                return;
                                              }

                                              // Save flag so this order never asks again
                                              rawOrder["age_verified"] = true;
                                              await offlineBox.put(activeOrderId, rawOrder);

                                              print("💾 Saved age_verified = true for search flow");
                                            }

                                            if (kDebugMode) {
                                              print(
                                                "TopBar - Age OK, proceeding → Product has variants: "
                                                    "${product.variations != null && product.variations!.isNotEmpty}",
                                              );
                                            }


                                            // 🟦 Step 4: Handle Variants (locally)
                                            if (product.variations != null && product.variations!.isNotEmpty) {
                                              _clearSearch();
                                              _productBloc.fetchProductVariations(product.id!);

                                              await showDialog(
                                                context: _context,
                                                barrierDismissible: false,
                                                builder: (context) => StreamBuilder<APIResponse<List<ProductVariation>>>(
                                                  stream: _productBloc.variationStream,
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData || snapshot.data!.status == Status.LOADING) {
                                                      return const Center(child: CircularProgressIndicator());
                                                    }

                                                    if (snapshot.data!.status == Status.COMPLETED) {
                                                      final variations = snapshot.data!.data!;
                                                      if (variations.isEmpty) return const SizedBox.shrink();

                                                      return VariantsDialog(
                                                          title: product.name ?? '',
                                                          variations: variations
                                                              .map((v) => {
                                                            "id": v.id,
                                                            "name": v.name,
                                                            "price": v.regularPrice,
                                                            "image": v.image.src,
                                                            "sku": v.sku ?? 'SKU${v.name}',
                                                          })
                                                              .toList(),
                                                          onAddVariant: (variant, quantity) async {
                                                            Navigator.pop(context);
                                                            _showLoaderOverlay();
                                                            setState(() => isAddingItemLoading = true);

                                                            try {
                                                              final int variantId = int.tryParse(variant["id"].toString()) ?? -1;
                                                              final int orderId = int.tryParse(activeOrderId.toString()) ?? -1;
                                                              final double variantPrice = double.tryParse(variant["price"].toString()) ?? 0.0;

                                                              if (orderId == -1) throw Exception("Invalid order ID");

                                                              // 🔥 Load products list (OrderPanel uses THIS)
                                                              List<Map<String, dynamic>> products = (rawOrder["products"] ?? [])
                                                                  .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
                                                                  .toList();

                                                              // 🔍 Check if variant already exists
                                                              int existingIndex = products.indexWhere((p) =>
                                                              (p["product_id"] == product.id) &&
                                                                  (p["variation_id"] == variantId)
                                                              );

                                                              if (existingIndex != -1) {
                                                                // ---------------------------------------------------------
                                                                // 🔄 VARIANT FOUND → INCREASE QUANTITY
                                                                // ---------------------------------------------------------
                                                                var existing = products[existingIndex];

                                                                int oldQty = int.tryParse(existing["quantity"].toString()) ?? 1;
                                                                int newQty = oldQty + quantity;

                                                                // Match OrderHelper.addItemToOrder() field structure
                                                                existing["quantity"] = newQty;
                                                                existing["price"] = variantPrice;
                                                                existing["unit_price"] = variantPrice;
                                                                existing["sales_price"] = variantPrice;
                                                                existing["regular_price"] = variantPrice;
                                                                existing["timestamp"] = DateTime.now().millisecondsSinceEpoch;

                                                                products[existingIndex] = existing;

                                                                // Save both lists
                                                                rawOrder["products"] = products;
                                                                rawOrder["line_items"] = products;

                                                                await offlineBox.put(activeOrderId, rawOrder);

                                                                // 🔥 Refresh OrderPanel data
                                                                await orderHelper.loadData();

                                                                _removeOverlay();
                                                                _clearSearch();
                                                                setState(() => isAddingItemLoading = false);

                                                                ScaffoldMessenger.of(_context).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text("Updated '${variant["name"]}' quantity to $newQty"),
                                                                    backgroundColor: Colors.green,
                                                                  ),
                                                                );

                                                                widget.onProductSelected?.call(
                                                                  ProductResponse(
                                                                    id: variantId,
                                                                    name: variant["name"],
                                                                    price: variantPrice.toString(),
                                                                    images: [variant["image"]],
                                                                    sku: variant["sku"],
                                                                  ),
                                                                );

                                                                return; // STOP HERE
                                                              }

                                                              // ---------------------------------------------------------
                                                              // 🆕 VARIANT NOT FOUND → ADD AS NEW ITEM
                                                              // ---------------------------------------------------------
                                                              await orderHelper.addItemToOrder(
                                                                variantId,
                                                                variant["name"] ?? 'Unknown',
                                                                variant["image"] ?? '',
                                                                variantPrice,
                                                                quantity,
                                                                variant["sku"] ?? 'SKU',
                                                                orderId,
                                                                type: 'variant',
                                                                productId: product.id,
                                                                variationId: variantId,
                                                                variationName: variant["name"],
                                                                unitPrice: variantPrice,
                                                                salesPrice: variantPrice,
                                                                onItemAdded: () async {
                                                                  _removeOverlay();
                                                                  _clearSearch();
                                                                  setState(() => isAddingItemLoading = false);

                                                                  widget.onProductSelected?.call(
                                                                    ProductResponse(
                                                                      id: variantId,
                                                                      name: variant["name"],
                                                                      price: variantPrice.toString(),
                                                                      images: [variant["image"]],
                                                                      sku: variant["sku"],
                                                                    ),
                                                                  );

                                                                  ScaffoldMessenger.of(_context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text("Variant '${variant["name"]}' added to order"),
                                                                      backgroundColor: Colors.green,
                                                                    ),
                                                                  );

                                                                  await orderHelper.loadData();
                                                                },
                                                              );
                                                            } catch (e, s) {
                                                              print("❌ Error adding variant: $e\n$s");
                                                              _removeOverlay();
                                                              setState(() => isAddingItemLoading = false);

                                                              ScaffoldMessenger.of(_context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text("Error adding variant locally"),
                                                                  backgroundColor: Colors.red,
                                                                ),
                                                              );
                                                            }
                                                          }


                                                      );

                                                    }

                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              );
                                            }
                                            else {
                                              // 🟩 Step 5: Handle simple product (NO variants)
                                              _showLoaderOverlay();
                                              setState(() => isAddingItemLoading = true);

                                              try {
                                                final pid = product.id!;
                                                final psku = product.sku ?? '';
                                                final pPrice = double.tryParse(product.price ?? '0.0') ?? 0.0;

                                                // Convert to editable list
                                                List<Map<String, dynamic>> products = (rawOrder["products"] ?? [])
                                                    .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
                                                    .toList();

                                                // ----------------------------------------------------------------------
                                                // 🟦 Step A: Check if SIMPLE PRODUCT already exists
                                                // RULE: simple product = variation_id == -1 (YOUR POS STANDARD)
                                                // ----------------------------------------------------------------------
                                                int index = products.indexWhere((item) =>
                                                item["product_id"].toString() == pid.toString() &&
                                                    (item["variation_id"]?.toString() ?? "-1") == "-1");

                                                if (index != -1) {
                                                  // 🟩 PRODUCT FOUND → Increase Quantity
                                                  var existing = products[index];

                                                  int oldQty = int.tryParse(existing["quantity"].toString()) ?? 1;
                                                  int newQty = oldQty + 1;

                                                  double unitPrice =
                                                      double.tryParse(existing["unit_price"]?.toString() ??
                                                          existing["price"]?.toString() ??
                                                          pPrice.toString()) ??
                                                          pPrice;

                                                  // Update fields
                                                  existing["quantity"] = newQty;
                                                  existing["price"] = unitPrice;
                                                  existing["unit_price"] = unitPrice;
                                                  existing["sales_price"] = unitPrice;
                                                  existing["regular_price"] = unitPrice;
                                                  existing["variation_id"] = -1; // POS simple-product rule
                                                  existing["timestamp"] = DateTime.now().millisecondsSinceEpoch;

                                                  products[index] = existing;

                                                  // Save back
                                                  rawOrder["products"] = products;
                                                  rawOrder["line_items"] = products;

                                                  await offlineBox.put(activeOrderId, rawOrder);

                                                  // Reload UI data
                                                  await orderHelper.loadData();

                                                  _removeOverlay();
                                                  _clearSearch();
                                                  setState(() => isAddingItemLoading = false);

                                                  widget.onProductSelected?.call(product);
                                                  return; // STOP HERE — DO NOT ADD DUPLICATE
                                                }

                                                // ----------------------------------------------------------------------
                                                // 🟥 SIMPLE PRODUCT NOT FOUND → ADD NEW ITEM
                                                // ----------------------------------------------------------------------
                                                final newItem = {
                                                  "product_id": pid,
                                                  "name": product.name ?? "Unknown",
                                                  "quantity": 1,
                                                  "price": pPrice,
                                                  "unit_price": pPrice,
                                                  "sales_price": pPrice,
                                                  "regular_price": pPrice,
                                                  "image": product.images?.isNotEmpty == true ? product.images!.first : '',
                                                  "sku": psku,
                                                  "total": pPrice,
                                                  "type": "simple",
                                                  "variation_id": -1, // POS rule
                                                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                                                };

                                                // products.add(newItem);
                                                // rawOrder["products"] = products;
                                                // rawOrder["line_items"] = products;
                                                //
                                                // await offlineBox.put(activeOrderId, rawOrder);

                                                // Also update orderHelper (UI sync)
                                                await orderHelper.addItemToOrder(
                                                  pid,
                                                  product.name ?? 'Unknown',
                                                  product.images?.isNotEmpty == true ? product.images!.first : '',
                                                  pPrice,
                                                  1,
                                                  psku,
                                                  int.tryParse(activeOrderId) ?? 0,
                                                  type: "simple",
                                                  productId: pid,
                                                  variationId: -1, // ✔ unified rule
                                                  variationName: null,
                                                  variationCount: 0,
                                                  combo: null,
                                                  salesPrice: pPrice,
                                                  regularPrice: pPrice,
                                                  unitPrice: pPrice,
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
                                            }







                                          } catch (e, s) {
                                            if (kDebugMode) print("TopBar onTap Exception: $e\n$s");
                                            _removeOverlay();
                                            setState(() => isAddingItemLoading = false);
                                          }
                                        }

                                    );
                                  },
                                );
                              case Status.ERROR:
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(snapshot.data!.message ?? 'Error loading products',
                                    style: TextStyle(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? ThemeNotifier.textDark
                                          : ThemeNotifier.textLight,
                                    ),
                                  ),
                                );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),
              ]);
        }

    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (kDebugMode) {
      print("TopBar - _removeOverlay");
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _fetchUserId() async { // Build #1.0.29: get the userId from db
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        if (kDebugMode) { // Build #1.0.148: tested using debug prints
          print("##### userId 00000 : $userId");
          print("##### userDisplayName 55555 : $userDisplayName");
        }
        userRole = userData[AppDBConst.userRole];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    final theme = Theme.of(context);
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
                //color: Colors.grey,
                borderRadius: BorderRadius.circular(20),
                // border: Border.all(color: const Color(0xFFEDEBEB)),//F1F1F3
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939) // Dark mode border,404454
                      : const Color(0xFFEDEBEB), // Light mode border
                ),

                boxShadow: [
                  BoxShadow(
                    color: themeHelper.themeMode == ThemeMode.dark
                    //? ThemeNotifier.shadow_F7
                        ? Color(0XFF605F5F)
                        : Colors.grey.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius:
                    themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              height: 46,
              key: _searchFieldKey,
              child:
              // BarcodeKeyboardListener( // Build #1.0.44 : Added - Wrap with BarcodeKeyboardListener for barcode scanning
              //   bufferDuration: Duration(milliseconds: 5000),
              //   //Build #1.0.78: Removed orderHelper.addItemToOrder from the API success block, as it’s now in OrderBloc.updateOrderProducts.
              //   // Kept local addItemToOrder for non-API orders.
              //   // Ensured loader is shown during API calls and hidden afterward.
              //   useKeyDownEvent: true,
              //   onBarcodeScanned: (barcode) async {
              //     _searchController.text = "";
              //     return;
              //   },
              //   child:
              TextField(
                enabled: _isSearchEnabled,
                controller: _searchController,
                onSubmitted: (value) {
                  if (kDebugMode) {
                    print("TopBar - TextField onSubmitted: Value='$value', overlayExists=${_overlayEntry != null}, lastQuery='$_lastSearchQuery'");
                  }
                  // Build #1.0.120: Fixed : result are reloading after dismissal of keypad
                  // Do not re-show overlay if it already exists or query hasn't changed
                  if (value.isNotEmpty && _overlayEntry == null && value != _lastSearchQuery) {
                    if (kDebugMode) {
                      print("TopBar - TextField onSubmitted: Showing search results overlay for new query");
                    }
                    _lastSearchQuery = value;
                    _productBloc.fetchProducts(searchQuery: value);
                    _showSearchResultsOverlay();
                  }
                },
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: TextConstants.searchHint,
                  prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
                  // Build #1.0.108: added loader for auto search items loading instead of (x)
                  suffixIcon: StreamBuilder<APIResponse<List<ProductResponse>>>(
                    stream: _productBloc.productStream,
                    builder: (context, snapshot) {
                      // Show loader when loading
                      if (snapshot.hasData && snapshot.data!.status == Status.LOADING && _searchController.text == _lastSearchQuery) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            // child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      // Show clear button when there's text
                      if (_searchController.text.isNotEmpty) {
                        return IconButton(
                          icon: Icon(Icons.clear, color: theme.iconTheme.color),
                          onPressed: _clearSearch,
                        );
                      }
                      // Return empty container when no icon needed
                      return const SizedBox.shrink();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),

                  filled: true,
                  fillColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.searchBarBackground : Colors.white,
                ),
              ),
            ),
          ),
          // ),
          const SizedBox(width: 200),
          // Column(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     IconButton(
          //       onPressed: () {},
          //       icon: const Icon(Icons.calculate),
          //     ),
          //     const Text(
          //       TextConstants.calculatorText,
          //       style: TextStyle(fontSize: 8),
          //     ),
          //   ],
          // ),
          // const SizedBox(width: 8),
          // Column(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     IconButton(
          //       onPressed: () {},
          //       icon: const Icon(Icons.pause),
          //     ),
          //     const Text(
          //       TextConstants.holdText,
          //       style: TextStyle(fontSize: 8),
          //     ),
          //   ],
          // ),
          // const SizedBox(width: 8),
          Row(
            children: [
              //cash drawer
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    // onTap: widget.onThemeChanged,
                    onTap: () async {
                      ///Deprecated code, moved to PrinterSettings now
                      //  // final profile = await CapabilityProfile.load(name: 'default');
                      //  // var bytes = Generator(PaperSize.mm80, profile).drawer(pin: PosDrawer.pin5); /// open drawer
                      //  // if (kDebugMode) {
                      //  //   print("TopBar onTap of cash drawer open tapped with profile: ${profile.name} and bytes return $bytes");
                      //  // }
                      // // var sunmi = SunmiPrinterPlus();
                      // // SunmiDrawer.openDrawer();
                      // var result = await SunmiPrinterPlusPlatform.instance.openDrawer();
                      // // sunmi.openDrawer();
                      //  // bool isOpen = await sunmi.isDrawerOpen();
                      //  if (kDebugMode) {
                      //    print("Drawer is open $result");
                      //  }
                      //  ScaffoldMessenger.of(context).showSnackBar(
                      //    const SnackBar(
                      //      content: Text(TextConstants.cashDrawerIsOpening),
                      //      backgroundColor: Colors.orange,
                      //      duration: Duration(seconds: 2),
                      //    ),
                      //  );

                      ///Use below code if only openDrawer is needed
                      // PrinterSettings.openDrawer(context: context);
                      ///As per Shravan's suggestion, we are now calling printTicket to open drawer from topbar which will automatically invoke open drawer
                      await PrinterSettings.openDrawer(context: context);
                      List<int> bytes = [];
                      final ticket =  await _printerSettings.getTicket();
                      bytes += ticket.feed(1);
                      final result = await _printerSettings.printTicket(bytes, ticket);
                      if (kDebugMode) {
                        print(">>>> TopBar printer result $result");
                      }
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.all(10), // spacing inside circle
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                            //? ThemeNotifier.shadow_F7
                                ? Color(0XFF605F5F)
                                : Colors.grey.withOpacity(0.2),
                            blurRadius: 2,
                            spreadRadius:
                            themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        border: Border.all(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(
                              0xFF3B3939) // Dark mode border, 2F3241
                              : const Color(0xFFF1F1F3), // Light mode border
                        ),

                        // border: Border.all(color: const Color(0xFF2F3241)),//#2F3241, 0xFFF1F1F3
                      ),
                      child: SvgPicture.asset(
                        SvgUtils.cashDrawerIcon,
                        width: 26,
                        height: 26,
                        colorFilter: ColorFilter.mode(
                          themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.lightBackground
                              : Colors.grey, //0xFFD5A52B
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  //  const SizedBox(height: 4), // space between icon and label
                  //const Text(
                  //  TextConstants.modeText,
                  //style: TextStyle(fontSize: 8),
                  // ),
                ],
              ),
              SizedBox(width: 16),
              // mode button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: widget.onModeChanged,
                    child: Container(
                      padding:
                      const EdgeInsets.all(13), // spacing inside circle
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                            //? ThemeNotifier.shadow_F7
                                ? Color(0XFF605F5F)
                                : Colors.grey.withOpacity(0.2),
                            blurRadius: 2,
                            spreadRadius:
                            themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        border: Border.all(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(
                              0xFF3B3939) // Dark mode border0xFF3B3939
                              : const Color(0xFFF1F1F3), // Light mode border
                        ),

                        // border: Border.all(color: const Color(0xFF2F3241)),//2F3241, F1F1F3
                      ),
                      child: SvgPicture.asset(
                        SvgUtils.changeModeIcon,
                        width: 26,
                        height: 26,
                        colorFilter: ColorFilter.mode(
                          themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.lightBackground
                              : Colors.grey, //0xFFD5A52B
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  //  const SizedBox(height: 4), // space between icon and label
                  //const Text(
                  //  TextConstants.modeText,
                  //style: TextStyle(fontSize: 8),
                  // ),
                ],
              ),
              SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // GestureDetector(
                  //   // FIX: Makes the entire area of the widget tappable, not just the visible parts.
                  //   behavior: HitTestBehavior.opaque,
                  //   onTap: () async {
                  //     if (kDebugMode) {
                  //       print("Theme icon tapped!");
                  //     }
                  //     final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
                  //     final newTheme = themeNotifier.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  //     themeNotifier.setThemeMode(newTheme);
                  //     // Save the new theme setting to the database
                  //     await UserDbHelper().saveUserSettings({
                  //       AppDBConst.themeMode: newTheme.toString(),
                  //     });
                  //   },
                  GestureDetector(
                    // on tap
                    onTap: () {
                      if (kDebugMode) {
                        print(
                            "TopBar onTap of thememode change ${themeHelper.getThemeMode()}");
                      }

                      themeHelper.setThemeMode(
                        themeHelper.getThemeMode() == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      );
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.all(10), // spacing inside circle
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white, //#2F3241
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                            //? ThemeNotifier.shadow_F7
                                ? Color(0XFF605F5F)
                                : Colors.grey.withOpacity(0.1),
                            blurRadius: 2,
                            spreadRadius:
                            themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        border: Border.all(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(0xFF605F5F) // Dark mode border
                              : const Color(0xFFF1F1F3), // Light mode border
                        ),

                        // border: Border.all(color: const Color(0xFF2F3241)),//2F3241, F1F1F3
                      ),
                      child: SvgPicture.asset(
                        SvgUtils.themeIcon,
                        width: 26,
                        height: 26,
                        colorFilter: ColorFilter.mode(
                          themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.lightBackground
                              : Colors.grey,
                          // ? const Color(0xFFD34BCA) // 💜 Use #D34BCA in dark mode
                          // : const Color(0xFFFFEAA6), // 🌼 Light mode color
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  // Text(
                  //   themeHelper.themeMode == ThemeMode.dark
                  //       ? TextConstants.darkText
                  //       : TextConstants.lightText,
                  //   style: const TextStyle(fontSize: 8),
                  // ),
                ],
              ),
              // // User profile section with container and notification bell
              // Container(
              //   height: 45,
              //   margin: EdgeInsets.all(10),
              //   padding: EdgeInsets.symmetric(
              //       horizontal: 16,
              //       vertical: 0
              //   ),
              //   decoration: BoxDecoration(
              //     color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
              //     borderRadius: BorderRadius.circular(15),
              //     boxShadow: [
              //       BoxShadow(
              //         color: themeHelper.themeMode == ThemeMode.dark
              //             ? ThemeNotifier.shadow_F7 : Colors.grey.withValues(alpha: 0.2),
              //         blurRadius: 2,
              //         spreadRadius: 4,
              //         offset: const Offset(0, 0),
              //       ),
              //     ],
              //   ),
              //   child: Row(
              //     children: [
              //       CircleAvatar(
              //         radius: 15,
              //         backgroundColor: Colors.deepPurple,
              //         child: Text(
              //           (userDisplayName ?? "Unknown").substring(0,1), // "A", /// use initial for the login user
              //           style: TextStyle(
              //               color: Colors.white,
              //               fontWeight: FontWeight.bold,
              //               fontSize: 14),
              //         ),
              //       ),
              //       SizedBox(width: 15),
              //       Column(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           Text(
              //             userDisplayName ?? "", // 'A Raghav Kumar', /// use login user display name
              //             style: TextStyle(
              //                 fontWeight: FontWeight.w500,
              //                 color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
              //                 fontSize: 14),
              //           ),
              //           Text(
              //             userRole ?? "Unknown", // 'I am Cashier', /// use user role
              //             style: TextStyle(
              //                 color: themeHelper.themeMode == ThemeMode.dark ? Colors.grey[400] : Colors.grey,
              //                 fontSize: 12),
              //           ),
              //         ],
              //       ),
              //     ],
              //   ),
              // ),
              SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeHelper.themeMode == ThemeMode.dark
                      // ? ThemeNotifier.shadow_F7
                          ?Color(0XFF605F5F)
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 2,
                      spreadRadius: themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                      offset: const Offset(0, 0),
                    ),
                  ],
                  border: Border.all(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF3B3939) // Dark mode border
                        : const Color(0xFFF1F1F3), // Light mode border
                  ),

                ),
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.notifications,
                  size: 24,
                  color: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black54,//#527EC3
                ),
              ),
              SizedBox(width: 16),
              // User profile section with container and notification bell
              Container(
                height: 45,
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0
                ),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: themeHelper.themeMode == ThemeMode.dark
                      //? ThemeNotifier.shadow_F7
                          ? Color(0XFF605F5F)
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 2,
                      spreadRadius: themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                      offset: const Offset(0, 0),
                    ),

                  ],
                  border: Border.all(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF3B3939) // Dark mode border
                        : const Color(0xFFF1F1F3), // Light mode border
                  ),

                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userDisplayName ?? "Unknown").substring(0,1), // "A", /// use initial for the login user
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userDisplayName ?? "", // 'A Raghav Kumar', /// use login user display name
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                              fontSize: 14),
                        ),
                        Text(
                          userRole ?? "Unknown", // 'I am Cashier', /// use user role
                          style: TextStyle(
                              color: themeHelper.themeMode == ThemeMode.dark ? Color(0xFFE09696): Color(0xFFE09696),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}