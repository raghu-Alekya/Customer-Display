import 'dart:async';
<<<<<<< HEAD
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
=======
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar_community/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
>>>>>>> origin/Grocery_pch_api_integration
import 'package:provider/provider.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';

// Import your custom numpad
import '../Blocs/Assets/asset_bloc.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
<<<<<<< HEAD
import '../Constants/text.dart';
import '../Database/assets_db_helper.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
=======
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/assets_db_helper.dart';
import '../Database/db_helper.dart';
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Helper/cashbackhelper.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Helper/url_helper.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../Models/Assets/asset_model.dart';
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_custom_item_model.dart' as model;
import '../Repositories/Assets/asset_repository.dart';
import '../Repositories/Auth/AuthIdsStore.dart';
import '../Repositories/Category/category_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/svg_images_utility.dart';
import '../mqtt_server/cart_item.dart';
import '../mqtt_server/cart_state.dart';
import '../mqtt_server/cfd_store_payload.dart';
import '../mqtt_server/store_messaging_service.dart';
import 'OrderPopupHelper.dart';
import 'widget_custom_num_pad.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppScreenTabWidget extends StatefulWidget {
  AppScreenTabWidget(
      {this.selectedTabIndex = 0,
        this.barcode = "",
        this.refreshOrderList,
        required this.scaffoldMessengerContext,
        super.key});
>>>>>>> origin/Grocery_pch_api_integration
  int selectedTabIndex = 0;
  String barcode = "";
  final BuildContext scaffoldMessengerContext;
  final VoidCallback? refreshOrderList; // Callback to refresh order panel

  @override
  State<AppScreenTabWidget> createState() => _AppScreenTabWidgetState();
}

<<<<<<< HEAD
class _AppScreenTabWidgetState extends State<AppScreenTabWidget> with LayoutSelectionMixin {
  // Tab selection
  bool _isPayoutLoading = false;
  bool _isCouponLoading = false;
=======
class _AppScreenTabWidgetState extends State<AppScreenTabWidget>
    with LayoutSelectionMixin {
  // Tab selection
  bool _isPayoutLoading = false;
  // bool _isCouponLoading = false;
  bool _isCashbackLoading = false;
>>>>>>> origin/Grocery_pch_api_integration
  bool _isDiscountLoading = false;
  bool _isCustomItemLoading = false;
  final OrderHelper _orderHelper = OrderHelper(); // Add OrderHelper instance
  late OrderBloc orderBloc;
  late ProductBloc productBloc;
  int? orderId; // Store order ID
  double orderTotal = 0.0; // Store order total
  // Discount values
  String _discountValue = "0.00%";
  bool _isPercentageSelected = true;

  // Coupon value
  String _couponCode = "";
<<<<<<< HEAD
=======
  String _cashbackAmount = "";
>>>>>>> origin/Grocery_pch_api_integration

  // Custom item values
  String _customItemName = "";
  String _customItemPrice = "";
  String _sku = "";
<<<<<<< HEAD

=======
  List<TaxModel> _taxList = [];
  TaxModel? _selectedTax;
  bool _isTaxLoading = false;
  bool _isSkuGenerated = false;
>>>>>>> origin/Grocery_pch_api_integration
  // Tax slab options
  late List<String> _taxSlabOptions = [];
  String _selectedTaxSlab = '';
  final AssetDBHelper _assetDBHelper = AssetDBHelper.instance;
  bool _isTaxAvailable = false;

  // Payout value
  String _payoutAmount = "";
<<<<<<< HEAD
  // Adding a separate state variable for selected tab
  late int _selectedTabIndex;

  // Text editing controllers
  final TextEditingController _customItemNameController = TextEditingController();
  final TextEditingController _customItemPriceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  // Add this boolean variable to track when user is entering item price
  bool _isEnteringItemPrice = false;
=======
  double _maxCashbackLimit = 0.0;
  late final OrderRepository _orderRepository;
  DateTime? _lastCfdPushAt;
  bool _cfdPushInFlight = false;

  // Adding a separate state variable for selected tab
  late int _selectedTabIndex;
  // Map<String, dynamic>? _customItemTemplate;

  // Add after existing custom item variables
  List<Map<String, dynamic>> _categoriesList = [];
  String _selectedCategoryName = "Custom Product"; // default
  bool _isCategoriesLoading = false;

  // 🟢 NEW: Cache keys for custom items & categories
  static const String _customItemsCacheKey = "custom_items_template_cache";
  static const String _categoriesCacheKey = "categories_with_tax_cache";

  // Text editing controllers
  final TextEditingController _customItemNameController =
  TextEditingController();
  final TextEditingController _customItemPriceController =
  TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  // Focus nodes
  final FocusNode _nameFocusNode = FocusNode();

  bool _isTaxDropdownEnabled = true;

  // Add this boolean variable to track when user is entering item price
  bool _isEnteringItemPrice = false;
  bool _isAmountEntered = false;

  Map<String, dynamic>? _customItemTemplate;
  List<Map<String, dynamic>> _customItemsList = []; // ← NEW
  String _selectedCustomItemName = "Custom Item";

  static int _persistedTabIndex = 0;
>>>>>>> origin/Grocery_pch_api_integration

  // Function to check if the item name is empty
  bool _isItemNameEmpty() {
    return _customItemNameController.text.trim().isEmpty;
  }

<<<<<<< HEAD
  @override
  void initState() {
    orderBloc = OrderBloc(OrderRepository()); // Build #1.0.53
    productBloc = ProductBloc(ProductRepository());
    super.initState();
    _customItemNameController.addListener(() {
      _customItemName = _customItemNameController.text;
=======
  /// Generate SKU only when name is set and SKU is still empty (e.g. not scanner-prefilled).
  bool _isGenerateSkuEnabled() {
    return !_isItemNameEmpty() && _skuController.text.trim().isEmpty;
  }

  String normalizeSku(String s) {
    return OrderHelper.normalizeSku(s);
  }


  Future<String> _getTokenFromDb() async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        AppDBConst.userTable,
        where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        final token = result.first[AppDBConst.userToken] as String;
        if (kDebugMode) print('🔑 Token fetched from DB for Custom Items');
        return token;
      } else {
        throw Exception('No active user token found');
      }
    } catch (e) {
      print("❌ Error getting token: $e");
      // Fallback to hardcoded token (as safety net)
      return '';
    }
  }

  /// Instant CFD update (native + MQTT) after Apps tab changes.
  /// Does not change existing order logic — only publishes what is already in Hive.
  // Future<void> _pushCfdAfterAppsChange(int orderId) async {
  //   if (orderId <= 0) return;
  //
  //   // 1) Native secondary display
  //   try {
  //     CustomerDisplayHelper.skipNextPendingOrderRefresh = false;
  //     await CustomerDisplayHelper.updateCustomerDisplay(
  //       orderId,
  //       summaryEnabled: false,
  //     );
  //   } catch (e) {
  //     if (kDebugMode) print('⚠️ Native CFD update failed: $e');
  //   }
  //
  //   // 2) MQTT CFD (same payload shape as RightOrderPanel)
  //   try {
  //     final messaging =
  //     Provider.of<StoreMessagingService>(context, listen: false);
  //     final box = StorageProvider.offlineOrders;
  //     final raw = await box.get(orderId.toString());
  //     if (raw is! Map) return;
  //
  //     final order = Map<String, dynamic>.from(raw);
  //     final products = (order['products'] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e as Map))
  //         .toList();
  //     final payouts = (order['payouts'] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e as Map))
  //         .toList();
  //     final cashbacks = (order['cashbacks'] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e as Map))
  //         .toList();
  //
  //     // Build display lines: products + payout + cashback as cart items
  //     final List<CartItem> items = [];
  //
  //     for (final p in products) {
  //       items.add(CartItem.fromOrderItem({
  //         ...p,
  //         'item_name': p['name'] ?? p[AppDBConst.itemName] ?? '',
  //         'item_price': p['price'] ?? p[AppDBConst.itemPrice] ?? 0,
  //         'items_count': p['quantity'] ?? p[AppDBConst.itemCount] ?? 1,
  //         'item_type': p[AppDBConst.itemType] ?? p['type'] ?? 'product',
  //         'product_id': p['product_id'] ?? p['id'] ?? 0,
  //         'weight_qty': p['weight_qty'] ?? p['weightQty'] ?? 0,
  //         'unit_price': p['unit_price'] ?? p['regular_price'] ?? p['price'] ?? 0,
  //       }));
  //     }
  //     for (final p in payouts) {
  //       final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
  //       items.add(CartItem.fromOrderItem({
  //         'item_name': p['product_name'] ?? 'Payout',
  //         'item_price': amt,
  //         'items_count': 1,
  //         'item_type': 'payout',
  //         'product_id': p['payout_product_id'] ?? 0,
  //       }));
  //     }
  //     for (final c in cashbacks) {
  //       final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
  //       items.add(CartItem.fromOrderItem({
  //         'item_name': c['product_name'] ?? 'Cashback',
  //         'item_price': amt,
  //         'items_count': 1,
  //         'item_type': 'cashback',
  //         'product_id': c['cashback_product_id'] ?? 0,
  //       }));
  //     }
  //
  //     final double gross =
  //         (order['gross_total'] as num?)?.toDouble() ??
  //             items.fold(0.0, (s, i) => s + i.lineTotal);
  //     final double mDisc =
  //     ((order['merchantDiscount'] as num?)?.toDouble() ?? 0.0).abs();
  //     final double orderDisc =
  //     ((order['orderDiscount'] as num?)?.toDouble() ?? 0.0).abs();
  //     final double tax =
  //         (order['order_tax'] as num?)?.toDouble() ??
  //             (order['tax_discount'] as num?)?.toDouble() ??
  //             0.0;
  //     final double cbFee =
  //         (order['cashbackFee'] as num?)?.toDouble() ??
  //             (order[AppDBConst.orderCashbackFee] as num?)?.toDouble() ??
  //             0.0;
  //     final double netPay = (order['net_payable'] as num?)?.toDouble() ??
  //         (gross + tax + cbFee - mDisc - orderDisc);
  //
  //     final store = await CfdStorePayload.load();
  //     final loyaltyContact = (order['loyaltyContact'] ?? '').toString();
  //     final availablePoints =
  //         int.tryParse((order['available_points'] ?? '0').toString()) ?? 0;
  //
  //     final state = CartState(
  //       sessionId: 'ORDER-$orderId',
  //       sequence: CfdSequence.next(),
  //       screen: items.isEmpty ? 'IDLE' : 'CART',
  //       items: items,
  //       tax: tax,
  //       message: null,
  //       orderId: orderId,
  //       subtotalOverride: gross,
  //       orderDiscount: orderDisc,
  //       merchantDiscount: mDisc,
  //       cashbackFee: cbFee,
  //       netPayable: netPay,
  //       totalItems: items.fold(0, (s, i) => s + i.qty),
  //       orderDate: '',
  //       orderTime: '',
  //       summaryEnabled: false,
  //       storeId: store.storeId,
  //       storeName: store.storeName,
  //       storeLogoUrl: store.storeLogoUrl,
  //       storeBaseUrl: store.storeBaseUrl,
  //       slideshowUrls: store.slideshowUrls,
  //       loyaltyContact: loyaltyContact,
  //       availablePoints: availablePoints,
  //     );
  //
  //     await messaging.publishState(state);
  //
  //     if (kDebugMode) {
  //       print(
  //         '📤 [Apps→CFD] orderId=$orderId items=${items.length} '
  //             'gross=$gross mDisc=$mDisc cbFee=$cbFee net=$netPay',
  //       );
  //     }
  //   } catch (e, s) {
  //     if (kDebugMode) print('⚠️ MQTT CFD publish failed: $e\n$s');
  //   }
  // }

  Future<void> _pushCfdAfterAppsChange(int orderId) async {
    if (orderId <= 0) return;

    // ── Debounce guard ──────────────────────────────────────────────
    // Something downstream (native display update / order panel
    // refresh notifier) is re-triggering this function dozens of
    // times for a single item add, flooding the local MQTT broker
    // and desyncing the CFD's packet parser (RangeError in its log).
    // Collapse rapid repeat calls into a single publish.
    final now = DateTime.now();
    if (_cfdPushInFlight) {
      if (kDebugMode) print('🔇 CFD push already in flight — skipping');
      return;
    }
    if (_lastCfdPushAt != null &&
        now.difference(_lastCfdPushAt!) < const Duration(milliseconds: 120)) {
      if (kDebugMode) print('🔇 CFD push debounced (too soon after last push)');
      return;
    }

    _cfdPushInFlight = true;
    _lastCfdPushAt = now;

    try {
      try {
        CustomerDisplayHelper.skipNextPendingOrderRefresh = false;
      } catch (_) {}

      await _publishCfdFromHiveOnce(orderId);
    } finally {
      _cfdPushInFlight = false;
    }
  }

  Future<void> _publishCfdFromHiveOnce(int orderId) async {
    // 1) Native secondary display
    try {
      await CustomerDisplayHelper.updateCustomerDisplay(
        orderId,
        summaryEnabled: false,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Native CFD update failed: $e');
    }

    // 2) MQTT — same shape + rules as _publishMqttCart
    try {
      final messaging =
      Provider.of<StoreMessagingService>(context, listen: false);

      final box = StorageProvider.offlineOrders;
      final raw = await box.get(orderId.toString());

      if (raw is! Map) {
        final store = await CfdStorePayload.load();
        final idleState = CartState(
          sessionId: 'ORDER-0',
          sequence: CfdSequence.next(),
          screen: 'IDLE',
          items: const [],
          tax: 0,
          message: null,
          orderId: null,
          subtotalOverride: 0,
          orderDiscount: 0,
          merchantDiscount: 0,
          cashbackFee: 0,
          netPayable: 0,
          totalItems: 0,
          orderDate: '',
          orderTime: '',
          summaryEnabled: false,
          storeId: store.storeId,
          storeName: store.storeName,
          storeLogoUrl: store.storeLogoUrl,
          storeBaseUrl: store.storeBaseUrl,
          slideshowUrls: store.slideshowUrls,
          loyaltyContact: '',
          availablePoints: 0,
        );
        await messaging.publishState(idleState);
        if (kDebugMode) {
          print('📤 [Apps→CFD] no Hive data → soft IDLE orderId=$orderId');
        }
        return;
      }

      final order = Map<String, dynamic>.from(raw);

      final products = (order['products'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final payouts = (order['payouts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final cashbacks = (order['cashbacks'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final List<CartItem> items = [];

      for (final p in products) {
        final int productId = int.tryParse(
          (p['product_id'] ??
              p['id'] ??
              p['fast_key_product_id'] ??
              p['server_item_id'] ??
              0)
              .toString(),
        ) ??
            0;

        final double unitPrice = double.tryParse(
          (p['unit_price'] ??
              p['regular_price'] ??
              p['price'] ??
              p[AppDBConst.itemPrice] ??
              0)
              .toString(),
        ) ??
            0.0;

        final double linePrice = double.tryParse(
          (p[AppDBConst.itemPrice] ??
              p['sales_price'] ??
              p['price'] ??
              unitPrice)
              .toString(),
        ) ??
            unitPrice;

        final int qty = int.tryParse(
          (p['quantity'] ?? p[AppDBConst.itemCount] ?? 1).toString(),
        ) ??
            1;

        final double weightQty = double.tryParse(
          (p['weight_qty'] ?? p['weightQty'] ?? 0).toString(),
        ) ??
            0.0;

        items.add(CartItem.fromOrderItem({
          ...p,
          'item_name': p['name'] ?? p[AppDBConst.itemName] ?? '',
          'item_price': linePrice,
          'items_count': qty,
          'item_type': p[AppDBConst.itemType] ?? p['type'] ?? 'product',
          'product_id': productId,
          'productId': productId,
          'weight_qty': weightQty,
          'unit_price': unitPrice > 0 ? unitPrice : linePrice,
        }));
      }

      for (final p in payouts) {
        final rawAmt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final amt = rawAmt.abs();
        if (amt <= 0) continue;

        final int payoutProductId = int.tryParse(
          (p['payout_product_id'] ?? p['product_id'] ?? 0).toString(),
        ) ??
            0;

        items.add(CartItem.fromOrderItem({
          'item_name': p['product_name'] ?? p['name'] ?? 'Payout',
          'item_price': amt,
          'items_count': 1,
          'item_type': 'payout',
          'product_id': payoutProductId,
          'productId': payoutProductId,
          'item_image': p['product_image'] ?? '',
        }));
      }

      for (final c in cashbacks) {
        final amt = ((c['amount'] as num?)?.toDouble() ?? 0.0).abs();
        if (amt <= 0) continue;

        final int cashbackProductId = int.tryParse(
          (c['cashback_product_id'] ?? c['product_id'] ?? 0).toString(),
        ) ??
            0;

        items.add(CartItem.fromOrderItem({
          'item_name': c['product_name'] ?? c['name'] ?? 'Cashback',
          'item_price': amt,
          'items_count': 1,
          'item_type': 'cashback',
          'product_id': cashbackProductId,
          'productId': cashbackProductId,
          'item_image': c['product_image'] ?? '',
        }));
      }

      final String loyaltyContact =
      (order['loyaltyContact'] ?? '').toString();
      final int availablePoints =
          int.tryParse((order['available_points'] ?? '0').toString()) ?? 0;

      final double orderDisc =
      ((order['orderDiscount'] as num?)?.toDouble() ?? 0.0).abs();
      final double mDisc = ((order['merchantDiscount'] as num?)?.toDouble() ??
          (order['merchant_discount'] as num?)?.toDouble() ??
          0.0)
          .abs();
      final double tax = (order['order_tax'] as num?)?.toDouble() ??
          (order['tax_discount'] as num?)?.toDouble() ??
          0.0;
      final double cbFee = (order['cashbackFee'] as num?)?.toDouble() ??
          (order['cashback_fee'] as num?)?.toDouble() ??
          (order[AppDBConst.orderCashbackFee] as num?)?.toDouble() ??
          0.0;

      final double gross = (order['gross_total'] as num?)?.toDouble() ??
          items.fold(0.0, (s, i) => s + i.lineTotal);

      final double netPay = (order['net_payable'] as num?)?.toDouble() ??
          (gross + tax + cbFee - mDisc - orderDisc);

      final int itemCount = items.fold(0, (s, i) => s + i.qty);

      final store = await CfdStorePayload.load();

      final state = CartState(
        sessionId: 'ORDER-$orderId',
        sequence: CfdSequence.next(),
        screen: 'CART',
        items: items,
        tax: tax,
        message: null,
        orderId: orderId,
        subtotalOverride: gross,
        orderDiscount: orderDisc,
        merchantDiscount: mDisc,
        cashbackFee: cbFee,
        netPayable: netPay,
        totalItems: itemCount,
        orderDate: '',
        orderTime: '',
        summaryEnabled: false,
        storeId: store.storeId,
        storeName: store.storeName,
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
        loyaltyContact: loyaltyContact,
        availablePoints: availablePoints,
      );

      await messaging.publishState(state);

      if (kDebugMode) {
        print(
          '📤 [Apps→CFD] orderId=$orderId screen=${state.screen} '
              'items=${items.length} gross=$gross mDisc=$mDisc '
              'cbFee=$cbFee net=$netPay payouts=${payouts.length} '
              'cashbacks=${cashbacks.length}',
        );
      }
    } catch (e, s) {
      if (kDebugMode) print('⚠️ MQTT CFD publish failed: $e\n$s');
    }
  }


// ==================== FINAL FIXED: FETCH CUSTOM ITEM TEMPLATE ====================
//   Future<void> _fetchCustomItemTemplate() async {
//     await _loadCustomItemsFromCache();   // 🟢 NEW — instant UI from cache
//
//     try {
//       // Initialize dynamic base URL
//       await UrlHelper.initializeBaseUrl();
//
//       final String token = await _getTokenFromDb();
//       if (token.isEmpty) {
//         print("⚠️ No token available");
//         return;
//       }
//
//       final headers = {
//         'Authorization': 'Bearer $token',
//         'Content-Type': 'application/json',
//       };
//
//       // Use wooBaseUrl + your exact query parameter
//       final String fullUrl = '${UrlHelper.wooBaseUrl}products?custom_products=true';
//       final uri = Uri.parse(fullUrl);
//
//       final request = http.Request('GET', uri);
//       request.headers.addAll(headers);
//
//       if (kDebugMode) {
//         print(" Fetching Custom Items → $uri");
//       }
//
//       final response = await request.send();
//
//       if (response.statusCode == 200) {
//         final String body = await response.stream.bytesToString();
//         final List<dynamic> data = jsonDecode(body);
//
//         if (data.isNotEmpty && mounted) {
//           setState(() {
//             _customItemTemplate = data.first as Map<String, dynamic>;
//             _customItemsList = List<Map<String, dynamic>>.from(data);
//
//             if (_customItemsList.isNotEmpty) {
//               _selectedCustomItemName = _customItemsList.first['name']?.toString() ?? "Custom Item";
//               _customItemNameController.text = _selectedCustomItemName;
//             }
//           });
//
//           print(" Successfully Loaded ${_customItemsList.length} Custom Items");
//           for (var item in _customItemsList) {
//             print("   → ${item['name']} (ID: ${item['id']}) |Tags: ${item['tags']}%| Tax: ${item['tax_percent']}%");
//           }
//           await _saveCustomItemsToCache(data);
//         }
//       } else {
//         print(" Failed to load custom items: ${response.reasonPhrase} (Status: ${response.statusCode})");
//       }
//     } catch (e) {
//       print("Error fetching custom item template: $e");
//     }
//   }

  // ==================== FETCH CATEGORIES WITH TAX (Custom Item only) ====================
  // Uses catalog API: GET {safeApiBaseUrl}/pos/auth/catalog/categories
  // Only for Custom Item category dropdown — other screens keep CategoryRepository.

  Future<void> _fetchCategoriesWithTax() async {
    await _loadCategoriesFromCache();

    try {
      final token = await _getTokenFromDb();
      final merchantId = (await AuthIdsStore.getMerchantId()).trim();
      final storeId = (await AuthIdsStore.getStoreId()).trim();

      final uri = Uri.parse(
          '${UrlHelper.safeApiBaseUrl}/pos/auth/catalog/categories');

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (merchantId.isNotEmpty) 'x-merchant-id': merchantId,
        if (storeId.isNotEmpty) 'x-store-id': storeId,
      };

      if (kDebugMode) {
        print('Custom Item categories API: GET $uri');
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Catalog categories failed (${response.statusCode}): ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      final List rawList;
      if (decoded is Map && decoded['categories'] is List) {
        rawList = decoded['categories'] as List;
      } else if (decoded is List) {
        rawList = decoded;
      } else {
        rawList = const [];
      }

      if (!mounted) return;

      final filteredCategories = rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((cat) {
        final name = (cat['name'] ?? '').toString().trim().toLowerCase();
        final slug = (cat['slug'] ?? '').toString().trim().toLowerCase();
        return name != 'uncategorized' &&
            slug != 'uncategorized' &&
            name != 'default' &&
            slug != 'default' &&
            name.isNotEmpty;
      }).map((cat) {
        // Prefer payload (legacy shape) then top-level camelCase fields from catalog API
        final payload = cat['payload'] is Map
            ? Map<String, dynamic>.from(cat['payload'] as Map)
            : <String, dynamic>{};

        final id = payload['id'] ??
            cat['wordpressId'] ??
            cat['id'] ??
            0;
        final name = (payload['name'] ?? cat['name'] ?? '').toString();
        final slug = (payload['slug'] ?? cat['slug'] ?? '').toString();
        final parent = payload['parent'] ??
            cat['parentWordpressId'] ??
            cat['parent'] ??
            0;
        final description =
            (payload['description'] ?? cat['description'] ?? '').toString();
        final count = payload['count'] ??
            cat['productCount'] ??
            cat['count'] ??
            0;
        final image = payload['image'] ?? cat['image'];

        final posTaxClass = (payload['pos_tax_class'] ??
                cat['posTaxClass'] ??
                cat['pos_tax_class'] ??
                '')
            .toString();
        final posTaxPercent = (payload['pos_tax_percent'] ??
                cat['posTaxPercent'] ??
                cat['pos_tax_percent'] ??
                '0')
            .toString();
        final posTaxSlug = posTaxClass.isNotEmpty
            ? posTaxClass.toLowerCase().replaceAll(' ', '-')
            : 'standard';

        return <String, dynamic>{
          'id': id,
          'name': name,
          'slug': slug,
          'parent': parent,
          'description': description,
          'count': count,
          'image': image,
          'pos_tax_class': posTaxClass.isNotEmpty ? posTaxClass : 'standard',
          'pos_tax_percent': posTaxPercent,
          'pos_tax_slug': posTaxSlug,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _categoriesList = filteredCategories;
          _selectedCategoryName = "Select Category";
        });
      }

      if (kDebugMode) {
        print(
            "✅ Loaded ${_categoriesList.length} Categories via catalog API (Custom Item tab)");
        for (var cat in _categoriesList) {
          print(
              "Category: ${cat['name']} | id: ${cat['id']} | tax: ${cat['pos_tax_percent']}%");
        }
      }
      await _saveCategoriesToCache(filteredCategories);
    } catch (e) {
      if (kDebugMode) {
        print(" Error fetching categories for Custom Item tab: $e");
      }
      // Keep any categories already loaded from cache so the dropdown is not empty.
    }
  }

// ==================== 🟢 NEW: CACHE HELPERS (CUSTOM ITEMS) ====================
  Future<void> _loadCustomItemsFromCache() async {
    try {
      final cached = await StorageProvider.productCache.get(_customItemsCacheKey);
      if (cached == null || !mounted) return;

      List<dynamic>? cachedList;
      if (cached is List) {
        cachedList = cached;
      } else if (cached is Map && cached['items'] is List) {
        cachedList = cached['items'] as List;
      } else if (cached is String) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) cachedList = decoded;
          if (decoded is Map && decoded['items'] is List) cachedList = decoded['items'] as List;
        } catch (_) {}
      }

      if (cachedList == null || cachedList.isEmpty) return;

      setState(() {
        _customItemTemplate = Map<String, dynamic>.from(cachedList!.first as Map);
        _customItemsList = cachedList!.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (_customItemsList.isNotEmpty) {
          _selectedCustomItemName = _customItemsList.first['name']?.toString() ?? "Custom Item";
          _customItemNameController.text = _selectedCustomItemName;
        }
      });

      if (kDebugMode) print("⚡ Loaded ${_customItemsList.length} Custom Items from CACHE");
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to load custom items cache: $e");
    }
  }

  Future<void> _saveCustomItemsToCache(List<dynamic> data) async {
    try {
      await StorageProvider.productCache.put(_customItemsCacheKey, {"items": data});
      if (kDebugMode) print("💾 Custom Items cached (${data.length} items)");
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to save custom items cache: $e");
    }
  }
// ==================== END CACHE HELPERS (CUSTOM ITEMS) ====================

// ==================== 🟢 NEW: CACHE HELPERS (CATEGORIES) ====================
  Future<void> _loadCategoriesFromCache() async {
    try {
      final cached = await StorageProvider.productCache.get(_categoriesCacheKey);
      if (cached == null || !mounted) return;

      List<dynamic>? cachedList;
      if (cached is List) {
        cachedList = cached;
      } else if (cached is Map && cached['categories'] is List) {
        cachedList = cached['categories'] as List;
      } else if (cached is String) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) cachedList = decoded;
          if (decoded is Map && decoded['categories'] is List) cachedList = decoded['categories'] as List;
        } catch (_) {}
      }

      if (cachedList == null || cachedList.isEmpty) return;

      setState(() {
        _categoriesList = cachedList!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _selectedCategoryName = "Select Category";
      });

      if (kDebugMode) print("⚡ Loaded ${_categoriesList.length} Categories from CACHE");
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to load categories cache: $e");
    }
  }

  Future<void> _saveCategoriesToCache(List<Map<String, dynamic>> categories) async {
    try {
      await StorageProvider.productCache.put(_categoriesCacheKey, {"categories": categories});
      if (kDebugMode) print("💾 Categories cached (${categories.length} categories)");
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to save categories cache: $e");
    }
  }
// ==================== END CACHE HELPERS (CATEGORIES) ====================

  @override
  void initState() {
    _orderRepository = OrderRepository();
    orderBloc = OrderBloc(OrderRepository()); // Build #1.0.53
    productBloc = ProductBloc(ProductRepository());
    super.initState();
    _loadCashbackLimit();


    _customItemNameController.addListener(() {
      setState(() {
        _customItemName = _customItemNameController.text;

        // 🔥 FIX: re-enable tax + SKU when name entered
        _isTaxDropdownEnabled = _customItemName.trim().isNotEmpty;
        _isSkuGenerated = false; // reset SKU state for new item
      });
>>>>>>> origin/Grocery_pch_api_integration
    });
    _customItemPriceController.addListener(() {
      _customItemPrice = _customItemPriceController.text;
    });
    _skuController.addListener(() {
      _sku = _skuController.text;
    });
<<<<<<< HEAD
    _loadOrderData(); // Load order data on initialization
    _loadTaxSlabs();
    // Initialize the selected tab index from widget
    _selectedTabIndex = widget.selectedTabIndex;
    // Add a listener to _customItemNameController to track changes in the text field
    _customItemNameController.addListener(() {
      setState(() {});  // Trigger a rebuild when the text changes
    });
=======

    _loadOrderData(); // Load order data on initialization
    _loadTaxSlabs();
    _loadTaxes();
    // Initialize the selected tab index from widget
    _selectedTabIndex = _persistedTabIndex;

    //  NEW: Load Custom Item Template + List for Dropdown
    // Replace the old fetch block in initState with this:
    // _fetchCustomItemTemplate();   // No .then() needed anymore
    _fetchCategoriesWithTax();   // ← NEW
  }

  Future<void> _loadTaxes() async {
    if (!mounted) return;
    setState(() => _isTaxLoading = true);

    _taxList = await _orderRepository.getAllTaxes();

    // ✅ FIX: without this, if the sidebar navigates away (e.g. tapping Refund)
    // while getAllTaxes() is still in flight, this setState fires on a disposed
    // widget → "Null check operator used on a null value" (your crash log).
    if (!mounted) return;
    setState(() => _isTaxLoading = false);
>>>>>>> origin/Grocery_pch_api_integration
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
<<<<<<< HEAD
    ///It will load sku and text field both with barcode from scanner initially
    if (kDebugMode) {
      print("WidgetTabs.didChangeDependencies assign text field with barcode value ${_skuController.text} = ${widget.barcode}");
=======

    ///It will load sku and text field both with barcode from scanner initially
    if (kDebugMode) {
      print(
          "WidgetTabs.didChangeDependencies assign text field with barcode value ${_skuController.text} = ${widget.barcode}");
>>>>>>> origin/Grocery_pch_api_integration
    }
    //Build #1.0.234: Fixed Issue [SCRUM - 388] -> SKU Disappears After Device Keyboard is Hidden
    // Only set the barcode value if it's different from current value and not empty
    if (widget.barcode.isNotEmpty && _skuController.text != widget.barcode) {
      if (kDebugMode) {
<<<<<<< HEAD
        print("WidgetTabs.didChangeDependencies assign text field with barcode value ${widget.barcode}");
      }
      _skuController.text = widget.barcode;
      _sku = widget.barcode;
      if (kDebugMode) {
        print("WidgetTabs.didChangeDependencies are text field and sku same?  ${_skuController.text} = $_sku");
=======
        print(
            "WidgetTabs.didChangeDependencies assign text field with barcode value ${widget.barcode}");
      }
      _skuController.text = widget.barcode;
      _sku = widget.barcode;

      // Focus Name field after a scan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedTabIndex == 2 && _customItemName.isEmpty) {
          _nameFocusNode.requestFocus();
        }
      });

      _isTaxDropdownEnabled = true;

      if (kDebugMode) {
        print(
            "WidgetTabs.didChangeDependencies are text field and sku same?  ${_skuController.text} = $_sku");
>>>>>>> origin/Grocery_pch_api_integration
      }
    } else {
      if (kDebugMode) {
        print("#### DEBUG 200 ${_skuController.text}, $_sku");
      }
    }
  }

  Future<void> _loadTaxSlabs() async {
    try {
      List<Tax> taxes = await _assetDBHelper.getTaxList();
<<<<<<< HEAD
      if (kDebugMode) print("#### _loadTaxSlabs: Loaded ${taxes.length} taxes: ${taxes.map((t) => t.toMap()).toList()},  widget.barcode: -${widget.barcode},");
=======
      if (kDebugMode)
        print(
            "#### _loadTaxSlabs: Loaded ${taxes.length} taxes: ${taxes.map((t) => t.toMap()).toList()},  widget.barcode: -${widget.barcode},");
      // ✅ FIX: guard against setState after disposal (same class of crash as _loadTaxes)
      if (!mounted) return;
>>>>>>> origin/Grocery_pch_api_integration
      setState(() {
        _taxSlabOptions = taxes.map((tax) => tax.name).toSet().toList();
        if (_taxSlabOptions.isNotEmpty) {
          _selectedTaxSlab = _taxSlabOptions.first;
<<<<<<< HEAD
          if (kDebugMode) print("#### _loadTaxSlabs: Set selected tax slab to: $_selectedTaxSlab");
=======
          if (kDebugMode)
            print(
                "#### _loadTaxSlabs: Set selected tax slab to: $_selectedTaxSlab");
>>>>>>> origin/Grocery_pch_api_integration
        } else {
          if (kDebugMode) print("#### _loadTaxSlabs: Tax slabs are empty");
          _selectedTaxSlab = ''; // Ensure reset if no options
        }
      });
    } catch (e) {
      if (kDebugMode) print("#### _loadTaxSlabs: Error loading tax slabs: $e");
<<<<<<< HEAD
=======
      if (!mounted) return;
>>>>>>> origin/Grocery_pch_api_integration
      setState(() {
        _taxSlabOptions = [];
        _selectedTaxSlab = '';
      });
    }
  }

  @override
  void dispose() {
    _customItemNameController.dispose();
    _customItemPriceController.dispose();
    _skuController.dispose();
<<<<<<< HEAD
    super.dispose();
  }

  // Fetch order ID and total from OrderHelper
  Future<void> _loadOrderData() async {
    await _orderHelper.loadProcessingData();
=======
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _loadCashbackLimit() async {
    final config = await CashbackHelper.getCashbackConfig();

    // ✅ FIX: guard against setState after disposal
    if (!mounted) return;
    if (config != null &&
        config["cash_back_service"] != null &&
        config["cash_back_service"]["max_cashback"] != null) {
      setState(() {
        _maxCashbackLimit = double.tryParse(
            config["cash_back_service"]["max_cashback"].toString()) ??
            0.0;
      });

      print("🟢 Loaded Max Cashback Limit = $_maxCashbackLimit");
    } else {
      print("❌ max_cashback NOT FOUND");
    }
  }

  // Fetch order ID and total from OrderHelper (use loadData for offline orders)
  Future<void> _loadOrderData() async {
    await _orderHelper.loadData();
    // ✅ FIX: guard against setState after disposal
    if (!mounted) return;
>>>>>>> origin/Grocery_pch_api_integration
    setState(() {
      orderId = _orderHelper.activeOrderId;
      if (kDebugMode) {
        print("####_loadOrderData, orderId: $orderId");
      }
      if (orderId != null) {
<<<<<<< HEAD
        _orderHelper.getOrderById(orderId!).then((order) {
          if (order.isNotEmpty) {
            setState(() {
              orderTotal = order.first[AppDBConst.orderTotal] as double? ?? 0.0;
            });
          }
        });
=======
        final order =
        _orderHelper.orders.cast<Map<String, dynamic>>().where((o) {
          final oid = o['order_id'] ?? o['id'] ?? o[AppDBConst.orderServerId];
          return oid != null &&
              (oid == orderId || oid.toString() == orderId.toString());
        }).toList();
        if (order.isNotEmpty) {
          final o = order.first;
          orderTotal = (o['gross_total'] ??
              o['net_payable'] ??
              o['net_total'] ??
              o[AppDBConst.orderTotal] ??
              0.0) is num
              ? ((o['gross_total'] ??
              o['net_payable'] ??
              o['net_total'] ??
              o[AppDBConst.orderTotal]) as num)
              .toDouble()
              : 0.0;
        }
>>>>>>> origin/Grocery_pch_api_integration
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return
      //backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white,
      // const Color(0xFFF1F5F9),
      Padding(
<<<<<<< HEAD
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.grey.shade500),
=======
        padding: const EdgeInsets.fromLTRB(4, 10, 2, 10),
        child: Container(
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? Color(0xFF1A1A1A)
                    : Color(0xFFE1E1E1)),
>>>>>>> origin/Grocery_pch_api_integration
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
              )
            ],
          ),
<<<<<<< HEAD
          clipBehavior: Clip.antiAlias, // Ensures children conform to the rounded corners
=======
          clipBehavior: Clip.antiAlias,
          // Ensures children conform to the rounded corners
>>>>>>> origin/Grocery_pch_api_integration
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Top Tabs
              _buildTabs(),

              // Content based on selected tab
              Expanded(
                  child: ClipPath(
<<<<<<< HEAD
                    clipper: ContentSideClipper(selectedIndex: _selectedTabIndex),
                      child: _buildTabContent()
                  )
              ),
=======
                      clipper:
                      ContentSideClipper(selectedIndex: _selectedTabIndex),
                      child: _buildTabContent())),
>>>>>>> origin/Grocery_pch_api_integration
            ],
          ),
        ),
      );
  }

<<<<<<< HEAD
  //Build the top tabs
=======
>>>>>>> origin/Grocery_pch_api_integration
  Widget _buildTabs() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return ClipPath(
      clipper: TabSideClipper(selectedIndex: _selectedTabIndex),
      child: Container(
          width: MediaQuery.of(context).size.width * 0.12,
<<<<<<< HEAD
        decoration: BoxDecoration(
          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground : ThemeNotifier.tabsLightBackground,
          borderRadius: BorderRadius.circular(16.0),
        ),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTab(0,SvgUtils.addDiscountIcon, TextConstants.discounts), // Build #1.0.168: Updated - Changed the icons to figma svg icons
            const SizedBox(width: 10),
            // Hide divider if current tab (0) or next tab (1) is selected
            if (_selectedTabIndex != 0 && _selectedTabIndex != 1)
            Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
            _buildTab(1, SvgUtils.addCouponIcon, TextConstants.coupons),
            const SizedBox(width: 10),
            // Hide divider if current tab (1) or next tab (2) is selected
            if (_selectedTabIndex != 1 && _selectedTabIndex != 2)
           Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
            _buildTab(2, SvgUtils.addCustomItemIcon, TextConstants.customItem),
            const SizedBox(width: 10),
            // Hide divider if current tab (2) or next tab (3) is selected
            if (_selectedTabIndex != 2 && _selectedTabIndex != 3)
            Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
            _buildTab(3, SvgUtils.addPayoutIcon, TextConstants.payoutsText),
          ],
        )
      ),
    );
  }

  // Build individual tab
  Widget _buildTab(int index, String svgPath, String text) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    if (kDebugMode) {
      print("Widget_tabs _buildTab index : $index");
    }
    // Use the state variable instead of widget property
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (kDebugMode) {
            print("Widget_tabs _buildTab onTap index : $index");
          }
          setState(() {
            // Update the state variable instead of widget property
            _selectedTabIndex = index;
            // Reset highlighting when switching away from custom item tab
            if (index != 2) {
              _isEnteringItemPrice = false;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : Colors.white)
                : (themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.tabsBackground
                : ThemeNotifier.tabsLightBackground),  //Color(0xFF1E2745))
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset( // Build #1.0.168: Updated - Changed the icons to figma svg icons
                svgPath,
                height: 32,
                width: 32,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : Colors.black)
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Padding(padding: EdgeInsets.only(right: 5), child:
              Text(
                text,
                style: TextStyle(
                  color: isSelected
                      ? (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : Colors.black)
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),),

            ],
=======
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.tabsBackground
                : Color(0xFFEAEDFF),
            // borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTab(
                  0,

                  SvgUtils.addCustomItemIcon,
                  "Custom\nItem",
                  // Color(0xFF55709A),    // icon color
                  // Color(0xFF55709A),
                  const Color(0xFF4C5F7D), // default = white for logo
                  const Color(0xFF4C5F7D)
                // Color(0xFF007BFF),      // icon color
                // Color(0xFF007BFF),    // text color
                // color: isSelected
                //     ? const Color(0xFFFFFFFF) // default = white
                //     : Colors.blue,          // selected = blue

                //themeHelper: themeHelper,
              ),
              const SizedBox(width: 10),
              if (_selectedTabIndex != 0 && _selectedTabIndex != 1)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 10,
                    endIndent: 10,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ?  Color(0xFF313441)
                        : Color(0xFF8EAAD8)),
              _buildTab(
                  1,
                  SvgUtils.addDiscountIcon,
                  "Merchant \nDiscounts",

                  // Color(0xFF55CBCD),    // icon color
                  // Color(0xFF55CBCD),     // text color
                  const Color(0xFF4C5F7D), // default = white for logo
                  const Color(0xFF4C5F7D)),
              const SizedBox(width: 10),
              if (_selectedTabIndex != 1 && _selectedTabIndex != 2)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 10,
                    endIndent: 10,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ?  Color(0xFF313441)
                        : Color(0xFF8EAAD8)),
              _buildTab(
                  2,
                  SvgUtils.cashbackIcon,
                  "Cashback",

                  const Color(0xFF4C5F7D), // default = white for logo
                  const Color(0xFF4C5F7D)), // Foreground text color
              const SizedBox(width: 10),
              if (_selectedTabIndex != 2 && _selectedTabIndex != 3)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 10,
                    endIndent: 10,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ?  Color(0xFF313441)
                        : Color(0xFF8EAAD8)),
              _buildTab(
                  3,
                  SvgUtils.addPayoutIcon,
                  "Payouts",
                  // Color(0xFFD93535),    // icon color
                  // Color(0xFFD93535),   // text color
                  const Color(0xFF4C5F7D), // default = white for logo
                  const Color(0xFF4C5F7D)),
            ],
          )),
    );
  }

  Widget _buildTab(
      int index,
      String svgPath,
      String text,
      Color iconColor,
      Color textColor,
      ) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    bool isSelected = _selectedTabIndex == index;
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _persistedTabIndex = index;
            if (index != 2) _isEnteringItemPrice = false;
          });
          final activeId = _orderHelper.activeOrderId;
          if (activeId != null && activeId > 0) {
            unawaited(_pushCfdAfterAppsChange(activeId));
          }
        },
        child: SizedBox(

          //height: 80,
          //width: 20,
          // adjust if needed (same for all tabs)

          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              //   color: isSelected
              //       ? (themeHelper.themeMode == ThemeMode.dark
              //       ? ThemeNotifier.primaryBackground
              //       : Colors.white) // this will set the card background
              //       : (themeHelper.themeMode == ThemeMode.dark
              //       ? ThemeNotifier.tabsBackground
              //       : ThemeNotifier.tabsLightBackground),
              //   borderRadius: BorderRadius.circular(16.0),
              // ),//**8Raghu modified the code below, with blue cards when selected it shows white

              color: isSelected
                  ? (isDark
                  ? const Color(0xFF2A2D3E) // 🔹 dark selected (you can tweak)
                  : const Color(0xFFFFFFFF)) // 🔹 light selected
                  : (isDark
                  ? const Color(0xFF1F1D2B) // 🔹 dark unselected
                  : const Color(0xFFECF1FF)), // 🔹 light unselected
              //borderRadius: BorderRadius.circular(2.0),
              /// borderRadius: BorderRadius.circular(0), // REMOVE rounded corners for now
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  svgPath,
                  height: 32,
                  width: 32,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? (isSelected ? Colors.white : Colors.white70)
                        : (isSelected ? iconColor : iconColor.withOpacity(0.8)),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 5),
                //Padding(
                // padding: const EdgeInsets.only(right: 8, top: 3),
                //child:
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : textColor, // keep your existing color for light mode
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
>>>>>>> origin/Grocery_pch_api_integration
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildDiscountsTab();
      case 1:
        return _buildCouponsTab();
      case 2:
        return _buildCustomItemTab(context);
=======
  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCustomItemTab(context);
    // return _buildDiscountsTab();
      case 1:
        return _buildDiscountsTab();

      case 2:
        return _buildCashbackTab();
    // return _buildCustomItemTab(context);
>>>>>>> origin/Grocery_pch_api_integration
      case 3:
        return _buildPayoutsTab();
      default:
        return const SizedBox();
    }
  }

  // DISCOUNTS TAB
  Widget _buildDiscountsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
<<<<<<< HEAD
=======

>>>>>>> origin/Grocery_pch_api_integration
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
<<<<<<< HEAD
          // Title
           Text(
=======
          // 🏷 Title
          Text(
>>>>>>> origin/Grocery_pch_api_integration
            TextConstants.applyDiscountToSale,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
<<<<<<< HEAD
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
=======
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
>>>>>>> origin/Grocery_pch_api_integration
            ),
          ),

          const SizedBox(height: 20),

<<<<<<< HEAD
          // Discount Input Toggle
          _buildDiscountToggle(),

          const SizedBox(height: 10),

          // Discount Value Display
          _buildDiscountDisplay(),

          const SizedBox(height: 10),

          // Custom Numpad
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 2.5,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() { // Build #1.0.53 : updated code
                  String currentValue = _discountValue.replaceAll('%', '').replaceAll(TextConstants.currencySymbol, '');
                  if (currentValue == "0.00" || currentValue == "0") {
                    currentValue = digit;
                  } else {
                    currentValue += digit;
                  }
                  _discountValue = _isPercentageSelected ? "$currentValue%" : currentValue;
=======
          // 🔘 Toggle Between % / ₹
          _buildDiscountToggle(),

          const SizedBox(height: 20),

          // 💬 Discount Entry Field (Styled like payout, centered)
          Container(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              textAlign: TextAlign.center,
              // ✅ Center alignment
              controller: TextEditingController(
                text: _isPercentageSelected
                    ? "${_discountValue.replaceAll('%', '')}%"
                    : "${TextConstants.currencySymbol}${_discountValue.replaceAll(TextConstants.currencySymbol, '')}",
              ),
              style: TextStyle(
                fontSize: 24,

                // ✔ Bold only when non-zero
                fontWeight: (() {
                  final clean = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '');
                  return (clean == "0.00" || clean.isEmpty)
                      ? FontWeight.normal
                      : FontWeight.bold;
                })(),

                // ✔ Light grey when zero or empty
                color: (() {
                  final clean = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '');
                  return (clean == "0.00" || clean.isEmpty)
                      ? Colors.grey.shade400
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : const Color(0xFF1E2745));
                })(),
              ),

              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔢 Custom Numpad
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 2.85,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
                  String cleanValue = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '')
                      .trim();

                  int rawValue =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  // ✅ Handle both "digit" and "00" properly like payout tab
                  if (digit == '00') {
                    rawValue = (rawValue * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawValue = (rawValue * 10 + d) % 100000000;
                  }

                  double displayValue = rawValue / 100.0;
                  _discountValue = displayValue.toStringAsFixed(2);

                  if (_isPercentageSelected) {
                    _discountValue = "$_discountValue%";
                  }
                });
              },
              onDeletePressed: () {
                setState(() {
                  String cleanValue = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '')
                      .trim();

                  int rawValue =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawValue = rawValue ~/ 10;

                  double displayValue = rawValue / 100.0;
                  _discountValue = displayValue.toStringAsFixed(2);

                  if (_isPercentageSelected) {
                    _discountValue = "$_discountValue%";
                  }
>>>>>>> origin/Grocery_pch_api_integration
                });
              },
              onClearPressed: () {
                setState(() {
<<<<<<< HEAD
                  _discountValue = _isPercentageSelected ? "0.00%" : "0.00";
                });
              },
              onDeletePressed: () { // Build #1.0.53 : updated code
                setState(() {
                  String currentValue = _discountValue.replaceAll('%', '').replaceAll(TextConstants.currencySymbol, ''); // Build #1.0.181: 1. Replaced Hard coded ‘\$’ with TextConstants.currencySymbol
                  if (currentValue.isNotEmpty && currentValue != "0.00") {
                    currentValue = currentValue.substring(0, currentValue.length - 1);
                    if (currentValue.isEmpty) {
                      currentValue = "0.00";
                    }
                  } else {
                    currentValue = "0.00";
                  } _discountValue = _isPercentageSelected ? "$currentValue%" : currentValue;
=======
                  _discountValue = "0.00";
                  if (_isPercentageSelected) {
                    _discountValue = "0.00%";
                  }
>>>>>>> origin/Grocery_pch_api_integration
                });
              },
              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleAddDiscount,
              isLoading: _isDiscountLoading,
<<<<<<< HEAD
              isDarkTheme: true,
=======
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
>>>>>>> origin/Grocery_pch_api_integration
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,

            ),
          ),
        ],
      ),
    );
  }

  // COUPONS TAB
<<<<<<< HEAD
  Widget _buildCouponsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
=======
  // Widget _buildCouponsTab() {
  //   final themeHelper = Provider.of<ThemeNotifier>(context);
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 20),
  //     child: Column(
  //       children: [
  //         // Title
  //         Text(
  //           TextConstants.enterCouponCode,
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                 .textDark : Color(0xFF1E2745),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Coupon Code Display
  //         Container(
  //           width: MediaQuery
  //               .of(context)
  //               .size
  //               .width / 2.75,
  //           height: MediaQuery
  //               .of(context)
  //               .size
  //               .height / 12,
  //           padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
  //           decoration: BoxDecoration(
  //             color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                 .paymentEntryContainerColor : Colors.white,
  //             borderRadius: BorderRadius.circular(10),
  //             border: Border.all(
  //                 color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                     .secondaryBackground : Colors.grey.shade300),
  //           ),
  //           alignment: Alignment.center,
  //           child: Text(
  //             _couponCode.isEmpty ? "Ex: 123456789" : _couponCode,
  //             // Build #1.0.53 : updated code
  //             style: TextStyle(
  //               fontSize: 24,
  //               fontWeight: FontWeight.bold,
  //               color: _couponCode.isEmpty ? Colors.grey : themeHelper
  //                   .themeMode == ThemeMode.dark
  //                   ? ThemeNotifier.textDark
  //                   : const Color(0xFF1E2745),
  //             ),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Custom Numpad
  //         SizedBox(
  //           width: MediaQuery
  //               .of(context)
  //               .size
  //               .width / 2.75,
  //           height: MediaQuery
  //               .of(context)
  //               .size
  //               .height / 2.25,
  //           child: CustomNumPad(
  //             onDigitPressed: (digit) {
  //               setState(() {
  //                 _couponCode += digit;
  //               });
  //             },
  //             onClearPressed: () {
  //               setState(() {
  //                 _couponCode = "";
  //               });
  //             },
  //             onDeletePressed: () { // Build #1.0.53 : updated code
  //               setState(() {
  //                 _couponCode = _couponCode.isNotEmpty ? _couponCode.substring(
  //                     0, _couponCode.length - 1) : "";
  //               });
  //             },
  //             actionButtonType: ActionButtonType.add,
  //             onAddPressed: _handleAddCoupon,
  //             isLoading: _isCouponLoading,
  //             isDarkTheme: true,
  //             numPadType: NumPadType.payment,
  //             showAddInsteadOfPay: true,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCashbackTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

>>>>>>> origin/Grocery_pch_api_integration
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
<<<<<<< HEAD
          // Title
          Text(
            TextConstants.enterCouponCode,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
            ),
          ),

          const SizedBox(height: 20),

          // Coupon Code Display
          Container(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 12,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: Text(
              _couponCode.isEmpty ? "Ex: 123456789" : _couponCode, // Build #1.0.53 : updated code
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _couponCode.isEmpty ?  Colors.grey : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : const Color(0xFF1E2745),
=======
          Text(
            TextConstants.addCashbackAmount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 10),
          // ⭐ MAX Cashback Info (from backend)
          if (_maxCashbackLimit > 0)
            Column(
              children: [
                Text(
                  "Max Allowed Cashback: ${TextConstants.currencySymbol}${_maxCashbackLimit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),

          // 💰 Payout Display
          Container(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                // ✅ Add the symbol only here
                text:
                "${TextConstants.currencySymbol}${_cashbackAmount.isEmpty ? "0.00" : _cashbackAmount}",
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                _isAmountEntered ? FontWeight.bold : FontWeight.normal,
                color: _cashbackAmount.isEmpty
                    ? Colors.grey.shade400
                    : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
>>>>>>> origin/Grocery_pch_api_integration
              ),
            ),
          ),

          const SizedBox(height: 20),

<<<<<<< HEAD
          // Custom Numpad
=======
          // 🔢 Custom Numpad
>>>>>>> origin/Grocery_pch_api_integration
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 2.25,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
<<<<<<< HEAD
                  _couponCode += digit;
=======
                  // Clean numeric part only
                  String cleanValue =
                  _cashbackAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  if (digit == '00') {
                    rawAmount = (rawAmount * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawAmount = (rawAmount * 10 + d) % 100000000;
                  }

                  double displayValue = rawAmount / 100.0;
                  _cashbackAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },
              onDeletePressed: () {
                setState(() {
                  String cleanValue =
                  _cashbackAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawAmount = rawAmount ~/ 10;

                  double displayValue = rawAmount / 100.0;
                  _cashbackAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
>>>>>>> origin/Grocery_pch_api_integration
                });
              },
              onClearPressed: () {
                setState(() {
<<<<<<< HEAD
                  _couponCode = "";
                });
              },
              onDeletePressed: () { // Build #1.0.53 : updated code
                setState(() {
                  _couponCode = _couponCode.isNotEmpty ? _couponCode.substring(0, _couponCode.length - 1) : "";
                });
              },
              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleAddCoupon,
              isLoading: _isCouponLoading,
              isDarkTheme: true,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
=======
                  _cashbackAmount = "0.00"; // ✅ no symbol
                  _isAmountEntered = false;
                });
              },
              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleCashbackpayout,
              isLoading: _isCashbackLoading,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
>>>>>>> origin/Grocery_pch_api_integration
            ),
          ),
        ],
      ),
    );
  }

  // CUSTOM ITEM TAB
  // Widget _buildCustomItemTab() {
  //   return
  //     Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         // First Row: Name & SKU
  //         Row(
  //           children: [
  //             // Name Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Name",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height / 15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       textAlign: TextAlign.left,
  //                       controller: _customItemNameController,
  //                       decoration: InputDecoration(
  //                         contentPadding: EdgeInsets.all(5),
  //                         border: InputBorder.none,
  //                         hintText: "Custom Item Name",
  //                         hintStyle: TextStyle(
  //                           color: Colors.grey,
  //                           fontSize: 14
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(width: 10),
  //             // SKU Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "SKU",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height /15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       controller: _skuController,
  //                       textAlign: TextAlign.center,
  //                       decoration: InputDecoration(
  //                         border: InputBorder.none,
  //                         hintText: "Generate the SKU",
  //                         hintStyle: TextStyle(
  //                             color: Colors.grey,
  //                             fontSize: 14
  //                         ),
  //                         contentPadding: const EdgeInsets.only(right: 5),
  //                         suffix: Container(
  //                           margin: const EdgeInsets.all(5.0),
  //                           child: ElevatedButton(
  //                             onPressed: _generateSku,
  //                             style: ElevatedButton.styleFrom(
  //                               backgroundColor: Colors.red.shade400,
  //                               foregroundColor: Colors.white,
  //                               elevation: 0,
  //                               shape: RoundedRectangleBorder(
  //                                 borderRadius: BorderRadius.circular(8),
  //                               ),
  //                               minimumSize: const Size(70, 40),
  //                             ),
  //                             child: const Text(
  //                               "Generate",
  //                               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 10),
  //
  //         // Second Row: Item Price & Tax
  //         Row(
  //           children: [
  //             // Item Price Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Item Price",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height / 15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       controller: _customItemPriceController,
  //                       //keyboardType: TextInputType.number,
  //                       decoration: const InputDecoration(
  //                         hintText: "Enter the Price",
  //                         hintStyle: TextStyle(
  //                             color: Colors.grey,
  //                             fontSize: 14
  //                         ),
  //                         border: InputBorder.none,
  //                         prefixText: "\$",
  //                         prefixStyle: TextStyle(fontSize: 14),
  //                         contentPadding: EdgeInsets.all(5),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(width: 10),
  //             // Tax Dropdown
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Tax",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height /15,
  //                     padding: const EdgeInsets.symmetric(horizontal: 15),
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: DropdownButton<String>(
  //                       value: _selectedTaxSlab.isEmpty ? null : _selectedTaxSlab,
  //                       hint: const Text(
  //                         'Choose a Tax Slab',
  //                         style: TextStyle(color: Colors.grey, fontSize: 14),
  //                       ),
  //                       icon: const Icon(Icons.arrow_drop_down),
  //                       isExpanded: true,
  //                       underline: Container(),
  //                       items: _taxSlabOptions.map((String value) {
  //                         return DropdownMenuItem<String>(
  //                           value: value,
  //                           child: Text(value),
  //                         );
  //                       }).toList(),
  //                       onChanged: (newValue) {
  //                         setState(() {
  //                           _selectedTaxSlab = newValue!;
  //                         });
  //                       },
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Custom Numpad
  //         Center(
  //           child: SizedBox(
  //             width: MediaQuery.of(context).size.width / 2.5,
  //             height: MediaQuery.of(context).size.height / 2.275,
  //             child: CustomNumPad(
  //               onDigitPressed: (digit) {
  //                 setState(() {
  //                   if (_customItemPrice == "0.00") {
  //                     _customItemPrice = digit;
  //                     _customItemPriceController.text = digit;
  //                   } else {
  //                     _customItemPrice += digit;
  //                     _customItemPriceController.text = _customItemPrice;
  //                   }
  //                 });
  //               },
  //               onClearPressed: () {
  //                 setState(() {
  //                   _customItemPrice = "";
  //                   _customItemPriceController.text = "";
  //                 });
  //               },
  //               actionButtonType: ActionButtonType.add,
  //               onAddPressed: () {
  //                 _handleAddCustomItem();
  //               },
  //             ),
  //           ),
  //         ),
  //       ],
  //     );
  //
  // }

<<<<<<< HEAD
  // CUSTOM ITEM TAB
  Widget _buildCustomItemTab(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    // return Container(
    //   width: screenWidth * 0.75,
    //   height: screenHeight * 0.75,
    //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 5),
    //   decoration: BoxDecoration(
    //       color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.red,
    //     borderRadius: BorderRadius.circular(16),
    //   ),
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child:  Column(
        children: [
=======
// CUSTOM ITEM TAB - WITH DROPDOWN (Enhanced UI)

  // Widget _buildCustomItemTab(BuildContext context) {
  //   final themeHelper = Provider.of<ThemeNotifier>(context);
  //
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 10),
  //     child: Column(
  //       children: [
  //         // ── Title ──────────────────────────────────────────────
  //         Text(
  //           TextConstants.customItem,
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: themeHelper.themeMode == ThemeMode.dark
  //                 ? ThemeNotifier.textDark
  //                 : const Color(0xFF1E2745),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // ── Row: Name Dropdown + Category Dropdown ─────────────
  //         SizedBox(
  //           width: MediaQuery.of(context).size.width / 2.75,
  //           child: Row(
  //             children: [
  //               // Name Dropdown
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       TextConstants.nameText,
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w600,
  //                         fontSize: 13,
  //                         color: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.textDark
  //                             : const Color(0xFF1E2745),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 5),
  //                     Container(
  //                       height: MediaQuery.of(context).size.height / 14,
  //                       padding: const EdgeInsets.symmetric(horizontal: 8),
  //                       decoration: BoxDecoration(
  //                         color: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.paymentEntryContainerColor
  //                             : Colors.white,
  //                         border: Border.all(
  //                           color: const Color(0xFF1E2745),
  //                           width: 1,
  //                         ),
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),
  //                       child: DropdownButton<String>(
  //                         value: _selectedCustomItemName,
  //                         isExpanded: true,
  //                         underline: const SizedBox(),
  //                         icon: const Icon(Icons.arrow_drop_down, size: 20),
  //                         style: TextStyle(
  //                           fontSize: 14,
  //                           color: themeHelper.themeMode == ThemeMode.dark
  //                               ? ThemeNotifier.textDark
  //                               : const Color(0xFF1E2745),
  //                         ),
  //                         dropdownColor: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.primaryBackground
  //                             : Colors.white,
  //                         items: _customItemsList.map((item) {
  //                           final name =
  //                               item['name']?.toString() ?? "Custom Item";
  //                           return DropdownMenuItem<String>(
  //                             value: name,
  //                             child: Text(
  //                               name,
  //                               overflow: TextOverflow.ellipsis,
  //                             ),
  //                           );
  //                         }).toList(),
  //                         onChanged: (newValue) {
  //                           if (newValue != null) {
  //                             setState(() {
  //                               _selectedCustomItemName = newValue;
  //                               _customItemNameController.text = newValue;
  //                               _selectedCategoryName = "Select Category";
  //
  //                             });
  //                           }
  //                         },
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //
  //               const SizedBox(width: 10),
  //
  //               // === FIXED & CLEAN CATEGORY DROPDOWN ===
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       "Category",
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w600,
  //                         fontSize: 13,
  //                         color: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.textDark
  //                             : const Color(0xFF1E2745),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 5),
  //                     Container(
  //                       height: MediaQuery.of(context).size.height / 14,
  //                       padding: const EdgeInsets.symmetric(horizontal: 8),
  //                       decoration: BoxDecoration(
  //                         color: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.paymentEntryContainerColor
  //                             : Colors.white,
  //                         border: Border.all(
  //                           color: const Color(0xFF1E2745),
  //                           width: 1,
  //                         ),
  //                         borderRadius: BorderRadius.circular(8),
  //                       ),
  //                       child: DropdownButton<String>(
  //
  //                         value: (_categoriesList.isEmpty ||
  //                             _selectedCategoryName == "Select Category" ||
  //                             !_categoriesList.any((cat) =>
  //                             cat['name']?.toString().trim() == _selectedCategoryName.trim()))
  //                             ? "Select Category"
  //                             : _selectedCategoryName,
  //
  //                         isExpanded: true,
  //                         underline: const SizedBox(),
  //                         icon: const Icon(Icons.arrow_drop_down, size: 20),
  //                         style: TextStyle(
  //                           fontSize: 14,
  //                           color: themeHelper.themeMode == ThemeMode.dark
  //                               ? ThemeNotifier.textDark
  //                               : const Color(0xFF1E2745),
  //                         ),
  //                         dropdownColor: themeHelper.themeMode == ThemeMode.dark
  //                             ? ThemeNotifier.primaryBackground
  //                             : Colors.white,
  //
  //                         items: [
  //                           // Placeholder
  //                           const DropdownMenuItem<String>(
  //                             value: "Select Category",
  //                             child: Text(
  //                               "Select Category",
  //                               style: TextStyle(color: Colors.grey),
  //                             ),
  //                           ),
  //                           ..._categoriesList.map((cat) {
  //                             final name = cat['name']?.toString() ?? "";
  //                             final tax = cat['pos_tax_percent']?.toString() ?? "0";
  //                             return DropdownMenuItem<String>(
  //                               value: name,
  //                               child: Text(
  //                                 "$name ($tax%)",
  //                                 overflow: TextOverflow.ellipsis,
  //                                 style: const TextStyle(fontSize: 15),
  //                               ),
  //                             );
  //                           }).toList(),
  //                         ],
  //
  //                         onChanged: (newValue) {
  //                           if (newValue != null && newValue != "Select Category") {
  //                             setState(() {
  //                               _selectedCategoryName = newValue;
  //                             });
  //                           }
  //                         },
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //
  //             ],
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // ── Item Price Display (centered, styled like discount field) ──
  //         Container(
  //           width: MediaQuery.of(context).size.width / 2.75,
  //           height: MediaQuery.of(context).size.height / 12,
  //           margin: const EdgeInsets.only(top: 10),
  //           child: TextField(
  //             readOnly: true,
  //             textAlign: TextAlign.center,
  //             controller: _customItemPriceController,
  //             style: TextStyle(
  //               fontSize: 24,
  //               fontWeight: _isEnteringItemPrice
  //                   ? FontWeight.bold
  //                   : FontWeight.normal,
  //               color: !_isEnteringItemPrice
  //                   ? Colors.grey.shade400
  //                   : (themeHelper.themeMode == ThemeMode.dark
  //                   ? ThemeNotifier.textDark
  //                   : const Color(0xFF1E2745)),
  //             ),
  //             decoration: InputDecoration(
  //               filled: true,
  //               fillColor: themeHelper.themeMode == ThemeMode.dark
  //                   ? ThemeNotifier.paymentEntryContainerColor
  //                   : Colors.white,
  //               hintText: "${TextConstants.currencySymbol} 0.00",
  //               hintStyle: TextStyle(
  //                 fontSize: 24,
  //                 fontWeight: FontWeight.normal,
  //                 color: Colors.grey.shade400,
  //               ),
  //               contentPadding:
  //               const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //                 borderSide: const BorderSide(
  //                   color: Color(0xFF1E2745),
  //                   width: 1,
  //                 ),
  //               ),
  //               enabledBorder: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //                 borderSide: const BorderSide(
  //                   color: Color(0xFF1E2745),
  //                   width: 1,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // ── Numpad ─────────────────────────────────────────────
  //         _buildCustomNumpad(context),
  //       ],
  //     ),
  //   );
  // }

  ////// dropdown modle

// CUSTOM ITEM TAB - 2 IN ROW - UNIFORM HEIGHT
// ============================================================================
// DROP-IN REPLACEMENT for _buildCustomItemTab(BuildContext context)
// Only this ONE method changes. Everything else in your class stays as-is.
//
// WHAT CHANGED:
// 1) Name field: TextField -> Autocomplete<String>
//    - Still uses your existing _customItemNameController and _nameFocusNode
//      (so your controller listener in initState keeps working untouched).
//    - optionsBuilder reads live from _customItemsList (the data you already
//      fetch via _fetchCustomItemTemplate()), so API names now actually show
//      up as suggestions while typing / on tap.
//    - onSelected fills the controller with the picked item's name and also
//      updates _selectedCustomItemName (already declared in your class).
//    - User can still type a fully custom name — nothing is locked to the
//      API list, it's just suggestions now.
//
// 2) Generate button: no longer has its own separate border/margin sitting
//    inside the field's Container (which caused the "double border" gap
//    look). It now stretches to fieldHeight and only rounds its RIGHT
//    corners, so it reads as part of the same field instead of a floating
//    button.
// ============================================================================

  Widget _buildCustomItemTab(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final fieldHeight = MediaQuery.of(context).size.height / 13.5; // Uniform height
    final fieldBorderColor = const Color(0xFF1E2745);
    final fieldRadius = 8.0;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          // Title
>>>>>>> origin/Grocery_pch_api_integration
          Text(
            TextConstants.customItem,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
<<<<<<< HEAD
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 20,),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLabeledTextField(
                title: TextConstants.nameText ,
                hintText: TextConstants.customItemName ,
                controller: _customItemNameController,
              ),
              const SizedBox(width: 20),
              _buildSkuField(),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            //mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLabeledTextField(
                title: TextConstants.itemPrice,
                hintText: "${TextConstants.currencySymbol} 0.00",//TextConstants.enterThePrice,
                controller: _customItemPriceController,
                readOnly: true,
                isHighlighted: _isEnteringItemPrice,  // Use dynamic highlighting instead of hardcoded true
              ),
              const SizedBox(width: 20),
              _buildTaxDropdown(),
            ],
          ),
          const SizedBox(height: 10),
=======
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),

          const SizedBox(height: 20),

          // ── Row 1: Name + SKU ─────────────────────────────────────
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            child: Row(
              children: [
                // Name Field -> now Autocomplete, backed by _customItemsList
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextConstants.nameText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : const Color(0xFF1E2745),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: fieldHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.paymentEntryContainerColor
                              : Colors.white,
                          border: Border.all(color: fieldBorderColor, width: 1),
                          borderRadius: BorderRadius.circular(fieldRadius),
                        ),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _customItemNameController,
                          focusNode: _nameFocusNode,
                          style: TextStyle(
                            fontSize: 15,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : const Color(0xFF1E2745),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: "Enter Item Name",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // SKU Field with flush Generate button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextConstants.sku,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : const Color(0xFF1E2745),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: fieldHeight,
                        clipBehavior: Clip.antiAlias, // keeps button corners inside field radius
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.paymentEntryContainerColor
                              : Colors.white,
                          border: Border.all(color: fieldBorderColor, width: 1),
                          borderRadius: BorderRadius.circular(fieldRadius),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: TextField(
                                  controller: _skuController,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: themeHelper.themeMode == ThemeMode.dark
                                        ? ThemeNotifier.textDark
                                        : const Color(0xFF1E2745),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    hintText: "SKU",
                                    hintStyle:
                                    TextStyle(color: Colors.grey, fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                            // Flush Generate button — fills full field height,
                            // right corners match the field's own radius,
                            // no separate border/margin creating a gap.
                            SizedBox(
                              height: fieldHeight,
                              child: ElevatedButton(
                                onPressed: _isItemNameEmpty() ? null : _generateSku,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isGenerateSkuEnabled()
                                      ? Colors.redAccent
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(fieldRadius - 1),
                                      bottomRight:
                                      Radius.circular(fieldRadius - 1),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  "Generate",
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
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

          const SizedBox(height: 16),

          // ── Row 2: Category + Price (UNCHANGED) ───────────────────
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            child: Row(
              children: [
                // Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Category",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : const Color(0xFF1E2745),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: fieldHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.paymentEntryContainerColor
                              : Colors.white,
                          border: Border.all(color: fieldBorderColor, width: 1),
                          borderRadius: BorderRadius.circular(fieldRadius),
                        ),
                        child: DropdownButton<String>(
                          value: (_categoriesList.isEmpty ||
                              _selectedCategoryName == "Select Category" ||
                              !_categoriesList.any((cat) =>
                              cat['name']?.toString().trim() ==
                                  _selectedCategoryName.trim()))
                              ? "Select Category"
                              : _selectedCategoryName,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 14,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : const Color(0xFF1E2745),
                          ),
                          dropdownColor: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.primaryBackground
                              : Colors.white,
                          items: [
                            const DropdownMenuItem<String>(
                              value: "Select Category",
                              child: Text("Select Category",
                                  style: TextStyle(color: Colors.grey)),
                            ),
                            ..._categoriesList.map((cat) {
                              final name = cat['name']?.toString() ?? "";
                              final tax =
                                  cat['pos_tax_percent']?.toString() ?? "0";
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text("$name ($tax%)",
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                          ],
                          onChanged: (newValue) {
                            if (newValue != null && newValue != "Select Category") {
                              setState(() => _selectedCategoryName = newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Price Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Item Price",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : const Color(0xFF1E2745),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: fieldHeight,
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.paymentEntryContainerColor
                              : Colors.white,
                          border: Border.all(color: fieldBorderColor, width: 1),
                          borderRadius: BorderRadius.circular(fieldRadius),
                        ),
                        child: TextField(
                          readOnly: true,
                          controller: _customItemPriceController,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: _isEnteringItemPrice
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !_isEnteringItemPrice
                                ? Colors.grey.shade400
                                : (themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : const Color(0xFF1E2745)),
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "${TextConstants.currencySymbol} 0.00",
                            hintStyle:
                            const TextStyle(fontSize: 20, color: Colors.grey),
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Numpad (UNCHANGED)
>>>>>>> origin/Grocery_pch_api_integration
          _buildCustomNumpad(context),
        ],
      ),
    );
  }

  Widget _buildCustomNumpad(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 2.75,
        height: MediaQuery.of(context).size.height / 2.75,
        child: CustomNumPad(
          onDigitPressed: (digit) {
            setState(() {
<<<<<<< HEAD
              // Set highlighting to true when user starts entering price
              _isEnteringItemPrice = true;
              if (_customItemPrice == "0.00") {
                _customItemPrice = digit;
                _customItemPriceController.text = digit;
              } else {
                _customItemPrice += digit;
                _customItemPriceController.text = _customItemPrice;
              }
=======
              // Extract numeric part from current value (ignore ₹ or commas)
              String cleanValue =
              _customItemPrice.replaceAll(RegExp(r'[^\d.]'), '');

              // Convert current value (e.g. "12.34") to integer cents → 1234
              int rawAmount =
              ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

              // Append digit(s)
              if (digit == '00') {
                rawAmount =
                    (rawAmount * 100) % 100000000; // shift left two digits
              } else {
                int d = int.tryParse(digit) ?? 0;
                rawAmount =
                    (rawAmount * 10 + d) % 100000000; // shift left one digit
              }

              // Convert back to display value
              double displayValue = rawAmount / 100.0;

              // Update both internal value and controller text
              _customItemPrice = displayValue.toStringAsFixed(2);
              _customItemPriceController.text =
              "${TextConstants.currencySymbol}${_customItemPrice}";

              // Highlight only when price > 0
              _isEnteringItemPrice = rawAmount > 0;
>>>>>>> origin/Grocery_pch_api_integration
            });
          },
          onClearPressed: () {
            setState(() {
<<<<<<< HEAD
              // dismiss the highlight when clearing
              _isEnteringItemPrice = false;
              _customItemPrice = "";
              _customItemPriceController.text = "";
=======
              // _customItemPrice = "0.00";
              // _customItemPriceController.text =
              // "${TextConstants.currencySymbol}0.00";
              // _isEnteringItemPrice = false;
              _customItemPrice = "0.00";
              _customItemPriceController.text = "${TextConstants.currencySymbol}0.00";
              _isEnteringItemPrice = false;
              _customItemNameController.clear();   // Clear Name
              _skuController.clear();
              // 🔥 NEW: Clear Category + Reset to initial state
              _selectedCategoryName = "Select Category";
>>>>>>> origin/Grocery_pch_api_integration
            });
          },
          onDeletePressed: () {
            setState(() {
<<<<<<< HEAD
              // Keep highlighting when deleting
              _isEnteringItemPrice = true;
              if (_customItemPrice.isNotEmpty) {
                _customItemPrice =
                    _customItemPrice.substring(0, _customItemPrice.length - 1);
                _customItemPriceController.text = _customItemPrice;
              }
=======
              // Extract numeric value (ignore ₹ or commas)
              String cleanValue =
              _customItemPrice.replaceAll(RegExp(r'[^\d.]'), '');

              // Convert to integer cents
              int rawAmount =
              ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

              // Remove one digit from the end
              rawAmount = rawAmount ~/ 10;

              // Convert back to display value
              double displayValue = rawAmount / 100.0;

              // Update UI + controller
              _customItemPrice = displayValue.toStringAsFixed(2);
              _customItemPriceController.text =
              "${TextConstants.currencySymbol}${_customItemPrice}";

              _isEnteringItemPrice = rawAmount > 0;
>>>>>>> origin/Grocery_pch_api_integration
            });
          },
          actionButtonType: ActionButtonType.add,
          onAddPressed: () {
            if (kDebugMode) {
<<<<<<< HEAD
              print("#### DEBUG 11@33 onAddPressed");
            }
            // Remove highlighting when add is pressed (interaction complete)
            setState(() {
              _isEnteringItemPrice = false;
            });
=======
              print("✅ onAddPressed triggered — raw price: $_customItemPrice");
            }

            setState(() {
              _isEnteringItemPrice = false;
              // _selectedCategoryName = "Select Category";

            });

            // Remove symbols, spaces, etc.
            final cleanedPrice =
            _customItemPrice.replaceAll(RegExp(r'[^0-9.]'), '');
            double? price = double.tryParse(cleanedPrice);

            if (price == null || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter valid price'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Update the variable with cleaned numeric string
            _customItemPrice = price.toString();

>>>>>>> origin/Grocery_pch_api_integration
            _handleAddCustomItem();
          },
          isLoading: _isCustomItemLoading,
          isDarkTheme: true,
          numPadType: NumPadType.payment,
          showAddInsteadOfPay: true,
        ),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required String title,
    required String hintText,
    required TextEditingController controller,
    bool readOnly = false,
    bool isHighlighted = false,
<<<<<<< HEAD
=======
    FocusNode? focusNode,
>>>>>>> origin/Grocery_pch_api_integration
  }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Conditionally set the border color and width based on the highlight status
    final borderColor = isHighlighted
        ? Colors.deepPurpleAccent
<<<<<<< HEAD
        : (themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300);
    final borderWidth = isHighlighted ? 2.0 : 1.0;
    return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(height: 5,),
=======
        : (themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.borderColor
        : Colors.grey.shade300);
    final borderWidth = isHighlighted ? 2.0 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(
          height: 5,
        ),
>>>>>>> origin/Grocery_pch_api_integration
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
<<<<<<< HEAD
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
=======
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : Color(0xFF1E2745),
>>>>>>> origin/Grocery_pch_api_integration
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery.of(context).size.height / 14,
          width: MediaQuery.of(context).size.width * 0.2,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          decoration: BoxDecoration(
<<<<<<< HEAD
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : null,
=======
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.paymentEntryContainerColor
                : null,
>>>>>>> origin/Grocery_pch_api_integration
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
<<<<<<< HEAD
=======
            focusNode: focusNode,
>>>>>>> origin/Grocery_pch_api_integration
            readOnly: readOnly,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
<<<<<<< HEAD
              hintStyle: TextStyle(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey),
=======
              hintStyle: TextStyle(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.grey),
>>>>>>> origin/Grocery_pch_api_integration
            ),
          ),
        ),
      ],
    );
  }

<<<<<<< HEAD
  Widget _buildSkuField() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5,),
        Text(
          TextConstants.sku,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery.of(context).size.height / 14,
          width: MediaQuery.of(context).size.width * 0.2,
          decoration: BoxDecoration(
            border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300),
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Color(0xFFECE9E9), // Custom background color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skuController,
                  readOnly: true,
                  textAlign: TextAlign.start,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9) ,
                    hintText: TextConstants.generateTheSku,
                    hintStyle: TextStyle(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: ElevatedButton(
                  onPressed:  _isItemNameEmpty() ? null : _generateSku, // Disable functionality if item name is empty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isItemNameEmpty() ? Colors.grey : Colors.redAccent, // Change color based on button state
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    //minimumSize: const Size(60, 36),
                  ),
                  child: const Text(
                    TextConstants.generate,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaxDropdown() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5,),
=======
  // Widget _buildSkuField() {
  //   final themeHelper = Provider.of<ThemeNotifier>(context);
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       SizedBox(
  //         height: 5,
  //       ),
  //       Text(
  //         TextConstants.sku,
  //         style: TextStyle(
  //           fontWeight: FontWeight.w600,
  //           fontSize: 14,
  //           color: themeHelper.themeMode == ThemeMode.dark
  //               ? ThemeNotifier.textDark
  //               : Color(0xFF1E2745),
  //         ),
  //       ),
  //       const SizedBox(height: 5),
  //       Container(
  //         height: MediaQuery.of(context).size.height / 14,
  //         width: MediaQuery.of(context).size.width * 0.2,
  //         decoration: BoxDecoration(
  //           border: Border.all(
  //               color: themeHelper.themeMode == ThemeMode.dark
  //                   ? ThemeNotifier.borderColor
  //                   : Colors.grey.shade300),
  //           color: themeHelper.themeMode == ThemeMode.dark
  //               ? ThemeNotifier.paymentEntryContainerColor
  //               : Color(0xFFECE9E9),
  //           // Custom background color,
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         child: Row(
  //           children: [
  //             Expanded(
  //               child: TextField(
  //                 controller: _skuController,
  //                 readOnly: true,
  //                 textAlign: TextAlign.start,
  //                 decoration: InputDecoration(
  //                   border: InputBorder.none,
  //                   contentPadding:
  //                   EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  //                   hintText: 'generateTheSku',
  //                   hintStyle: TextStyle(
  //                       color: themeHelper.themeMode == ThemeMode.dark
  //                           ? ThemeNotifier.textDark
  //                           : Colors.grey),
  //                 ),
  //               ),
  //             ),
  //             Padding(
  //               padding: const EdgeInsets.all(6.0),
  //               child: ElevatedButton(
  //                 onPressed: (_isItemNameEmpty() || _isSkuGenerated) ? null : _generateSku,
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: _isGenerateSkuEnabled()
  //                       ? Colors.redAccent
  //                       : Colors.grey,
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(horizontal: 12),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   //minimumSize: const Size(60, 36),
  //                 ),
  //                 child: const Text(
  //                   TextConstants.generate,
  //                   style: TextStyle(
  //                     fontSize: 12,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             )
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildTaxDropdown() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
>>>>>>> origin/Grocery_pch_api_integration
        Text(
          TextConstants.taxText,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
<<<<<<< HEAD
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
=======
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : const Color(0xFF1E2745),
>>>>>>> origin/Grocery_pch_api_integration
          ),
        ),
        const SizedBox(height: 5),
        Container(
<<<<<<< HEAD
          alignment: Alignment.topLeft,
          height: MediaQuery.of(context).size.height / 14,
          width: MediaQuery.of(context).size.width * 0.2,
          padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 0),
          decoration: BoxDecoration(
            border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : null
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedTaxSlab.isEmpty ? null : _selectedTaxSlab,
            isExpanded: true,
            alignment: Alignment.centerLeft,
            dropdownColor: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : null,
            //underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down),
            items: _taxSlabOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
=======
          height: MediaQuery.of(context).size.height / 14,
          width: MediaQuery.of(context).size.width * 0.2,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.borderColor
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(10),
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.paymentEntryContainerColor
                : null,
          ),
          child: _isTaxLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : DropdownButtonFormField<TaxModel>(
            value: _selectedTax,
            isExpanded: true,
            dropdownColor: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : null,
            icon: const Icon(Icons.keyboard_arrow_down),
            items: _taxList.map((tax) {
              return DropdownMenuItem<TaxModel>(
                value: tax,
                child: Text(
                  tax.name, // ✅ DISPLAY NAME FROM API
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : const Color(0xFF1E2745),
>>>>>>> origin/Grocery_pch_api_integration
                  ),
                ),
              );
            }).toList(),
<<<<<<< HEAD
            onChanged: (newValue) {
              if (kDebugMode) {
                print("##### _buildTaxDropdown onChanged: $newValue");
              }
              setState(() {
                _selectedTaxSlab = newValue!;
              });
            },
            decoration: InputDecoration(
             contentPadding: const EdgeInsets.only(top: 0, bottom: 5), // left + vertical center
              border: InputBorder.none, // No border at all
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            hint: Container(
                //color: Colors.blue,
                padding: EdgeInsets.only(bottom: 0),
                child: Text(TextConstants.chooseTaxSlab,
                  style: TextStyle(
                      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey,fontSize: 14),)),
=======
            onChanged: _customItemNameController.text.trim().isNotEmpty
                ? (value) {
              if (kDebugMode) {
                print(
                    "✅ Selected Tax: ${value?.name} | Rate: ${value?.rate}");
              }
              setState(() {
                _selectedTax = value;
              });
            }
                : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            hint: Text(
              TextConstants.chooseTaxSlab,
              style: TextStyle(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : Colors.grey,
                fontSize: 14,
              ),
            ),
>>>>>>> origin/Grocery_pch_api_integration
          ),
        ),
      ],
    );
  }

<<<<<<< HEAD



  // PAYOUTS TAB
  Widget _buildPayoutsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
=======
  Widget _buildPayoutsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

>>>>>>> origin/Grocery_pch_api_integration
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            TextConstants.addPaymentAmount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
<<<<<<< HEAD
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Color(0xFF1E2745),
            ),
          ),
          // Floating label input field
          SizedBox(
            height: 20,
          ),
=======
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 20),

          // 💰 Payout Display
>>>>>>> origin/Grocery_pch_api_integration
          Container(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
<<<<<<< HEAD
                text: _payoutAmount.isEmpty ? "${TextConstants.currencySymbol}0.00" : "${TextConstants.currencySymbol}$_payoutAmount",
=======
                // ✅ Add the symbol only here
                text:
                "${TextConstants.currencySymbol}${_payoutAmount.isEmpty ? "0.00" : _payoutAmount}",
>>>>>>> origin/Grocery_pch_api_integration
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
<<<<<<< HEAD
                fontWeight: FontWeight.bold,
                color: _payoutAmount.isEmpty
                    ? Colors.grey.shade400 : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                floatingLabelAlignment: FloatingLabelAlignment.center,
                //labelText: TextConstants.addPaymentAmount,
                labelStyle: TextStyle(
                  fontSize: 20,
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor:themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
=======
                fontWeight:
                _isAmountEntered ? FontWeight.bold : FontWeight.normal,
                color: _payoutAmount.isEmpty
                    ? Colors.grey.shade400
                    : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
>>>>>>> origin/Grocery_pch_api_integration
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
<<<<<<< HEAD
          const SizedBox(height: 20),

          // Custom Numpad
=======

          const SizedBox(height: 20),

          // 🔢 Custom Numpad
>>>>>>> origin/Grocery_pch_api_integration
          SizedBox(
            width: MediaQuery.of(context).size.width / 2.75,
            height: MediaQuery.of(context).size.height / 2.25,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
<<<<<<< HEAD
                  if (_payoutAmount == "0.00" || _payoutAmount.isEmpty) {
                    _payoutAmount = digit;
                  } else {
                    _payoutAmount += digit;
                  }
                });
              },
              onClearPressed: () {
                setState(() {
                  _payoutAmount = "";
=======
                  // Clean numeric part only
                  String cleanValue = _payoutAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  if (digit == '00') {
                    rawAmount = (rawAmount * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawAmount = (rawAmount * 10 + d) % 100000000;
                  }

                  double displayValue = rawAmount / 100.0;
                  _payoutAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
>>>>>>> origin/Grocery_pch_api_integration
                });
              },
              onDeletePressed: () {
                setState(() {
<<<<<<< HEAD
                  _payoutAmount = _payoutAmount.isNotEmpty
                      ? _payoutAmount.substring(0, _payoutAmount.length - 1)
                      : "";
=======
                  String cleanValue = _payoutAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawAmount = rawAmount ~/ 10;

                  double displayValue = rawAmount / 100.0;
                  _payoutAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },
              onClearPressed: () {
                setState(() {
                  _payoutAmount = "0.00"; // ✅ no symbol
                  _isAmountEntered = false;
>>>>>>> origin/Grocery_pch_api_integration
                });
              },
              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleAddPayout,
              isLoading: _isPayoutLoading,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
            ),
          ),
        ],
      ),
    );
  }

  // Generate SKU function
  void _generateSku() {
<<<<<<< HEAD
    // Simple SKU generation logic - prefix + timestamp
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(0,12);
=======
    if (_skuController.text.trim().isNotEmpty) return;
    // Simple SKU generation logic - prefix + timestamp
    String timestamp =
    DateTime.now().millisecondsSinceEpoch.toString().substring(0, 12);
>>>>>>> origin/Grocery_pch_api_integration
    // String prefix = _customItemName.isNotEmpty
    //     ? _customItemName.substring(0, _customItemName.length > 3 ? 3 : _customItemName.length).toUpperCase()
    //     : "C";

    String prefix = 'C';
    setState(() {
      _sku = "$prefix-$timestamp";
      _skuController.text = _sku;
<<<<<<< HEAD
=======
      _isSkuGenerated = true;
>>>>>>> origin/Grocery_pch_api_integration
    });

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(TextConstants.skuGeneratedSuccessfully),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Build the percentage/amount toggle
  Widget _buildDiscountToggle() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      width: MediaQuery.of(context).size.width / 2.75,
<<<<<<< HEAD
      height: MediaQuery.of(context).size.height / 14 ,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.grey.shade300),
=======
      height: MediaQuery.of(context).size.height / 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.secondaryBackground
                : Colors.grey.shade300),
>>>>>>> origin/Grocery_pch_api_integration
      ),
      child: Row(
        children: [
          // Percentage option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (!_isPercentageSelected) {
                    _isPercentageSelected = true;
                    // Convert to percentage format
<<<<<<< HEAD
                    _discountValue = "${_discountValue.replaceAll(TextConstants.currencySymbol, '')}%"; // Build #1.0.181: 1. Replaced Hard coded ‘\$’ with TextConstants.currencySymbol
=======
                    _discountValue =
                    "${_discountValue.replaceAll(TextConstants.currencySymbol, '')}%"; // Build #1.0.181: 1. Replaced Hard coded ‘\$’ with TextConstants.currencySymbol
>>>>>>> origin/Grocery_pch_api_integration
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isPercentageSelected
                      ? Colors.red.shade400
<<<<<<< HEAD
                      : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground : Colors.white,
=======
                      : themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.tabsBackground
                      : Colors.white,
>>>>>>> origin/Grocery_pch_api_integration
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(9),
                      bottomLeft: Radius.circular(9),
                      topRight: Radius.circular(9),
                      bottomRight: Radius.circular(9)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "%",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
<<<<<<< HEAD
                    color: _isPercentageSelected ? Colors.white : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black,
=======
                    color: _isPercentageSelected
                        ? Colors.white
                        : themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Colors.black,
>>>>>>> origin/Grocery_pch_api_integration
                  ),
                ),
              ),
            ),
          ),

          // Dollar option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_isPercentageSelected) {
                    _isPercentageSelected = false;
                    // Convert to dollar format
                    _discountValue = _discountValue.replaceAll('%', '');
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
<<<<<<< HEAD
                  color:
                  !_isPercentageSelected ? Colors.redAccent :themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground :  Colors.white,
=======
                  color: !_isPercentageSelected
                      ? Colors.redAccent
                      : themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.tabsBackground
                      : Colors.white,
>>>>>>> origin/Grocery_pch_api_integration
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  TextConstants.currencySymbol,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
<<<<<<< HEAD
                    color: !_isPercentageSelected ? Colors.white : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black,
=======
                    color: !_isPercentageSelected
                        ? Colors.white
                        : themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Colors.black,
>>>>>>> origin/Grocery_pch_api_integration
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  // Build the discount value display
  Widget _buildDiscountDisplay() {
    // Build #1.0.53 : updated code
    final themeHelper = Provider.of<ThemeNotifier>(context);
    String displayValue = _isPercentageSelected ? _discountValue : "${TextConstants.currencySymbol}$_discountValue";
    bool isPlaceholder = _discountValue == "0.00%" || _discountValue == "0.00" || _discountValue == "0%" || _discountValue == "0";

    return Container(
      width: MediaQuery.of(context).size.width / 2.75,
      height: MediaQuery.of(context).size.height / 14,
      padding: const EdgeInsets.symmetric(vertical: 2), /// use this value for all inset paddings
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        displayValue,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isPlaceholder ?  Colors.grey : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : const Color(0xFF1E2745),
        ),
      ),
    );
  }

=======
  static final Map<int, Map<String, dynamic>> _productMetaCache = {};
  static bool _productMetaInitialized = false;

  String _resolveDynamicProductName(Map<String, dynamic> map) {
    final dynamic rawName = map["fast_key_item_name"] ?? map["name"];
    if (rawName is Map && rawName["rendered"] != null) {
      return rawName["rendered"].toString();
    }
    return (rawName ?? "").toString();
  }

  String _resolveDynamicProductSku(Map<String, dynamic> map) {
    final dynamic rawSku = map["fast_key_item_sku"] ?? map["sku"] ?? map["item_sku"];
    return (rawSku ?? "").toString();
  }

  String _resolveDynamicProductImage(Map<String, dynamic> map) {
    final dynamic rawImage =
        map["fast_key_item_image"] ?? map["image"] ?? map["images"];
    if (rawImage is String) return rawImage;
    if (rawImage is Map && rawImage["src"] != null) {
      return rawImage["src"].toString();
    }
    if (rawImage is List && rawImage.isNotEmpty) {
      final first = rawImage.first;
      if (first is String) return first;
      if (first is Map && first["src"] != null) return first["src"].toString();
    }
    return "";
  }

  int? _resolveDynamicProductId(Map<String, dynamic> map) {
    final dynamic rawId =
        map["fast_key_product_id"] ?? map["product_id"] ?? map["id"];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? "");
  }

  void _cacheDynamicProduct(Map<String, dynamic> map) {
    final normalized = _normalizeDynamicProductMap(map);
    final int? pid = _resolveDynamicProductId(normalized);
    if (pid == null) return;
    _productMetaCache[pid] = normalized;
    _productMetaInitialized = true;
  }

  Map<String, dynamic> _normalizeDynamicProductMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);
    final pid = _resolveDynamicProductId(normalized);
    final name = _resolveDynamicProductName(normalized);
    final sku = _resolveDynamicProductSku(normalized);
    final image = _resolveDynamicProductImage(normalized);

    if (pid != null) {
      normalized["fast_key_product_id"] = pid;
      normalized["product_id"] ??= pid;
      normalized["id"] ??= pid;
    }
    if (name.isNotEmpty) {
      normalized["fast_key_item_name"] = name;
      normalized["name"] ??= name;
    }
    if (sku.isNotEmpty) {
      normalized["fast_key_item_sku"] = sku;
      normalized["sku"] ??= sku;
    }
    if (image.isNotEmpty) {
      normalized["fast_key_item_image"] = image;
      normalized["image"] ??= image;
    }
    return normalized;
  }

  bool _dynamicProductMatches(
      Map<String, dynamic> map, List<String> tokens) {
    final name = _resolveDynamicProductName(map).toLowerCase();
    final sku = _resolveDynamicProductSku(map).toLowerCase();
    for (final token in tokens) {
      final t = token.toLowerCase();
      if (name.contains(t) || sku.contains(t)) return true;
    }
    return false;
  }

  Iterable<Map<String, dynamic>> _expandDynamicProductCandidates(
      dynamic raw) sync* {
    if (raw == null) return;
    if (raw is List) {
      for (final item in raw) {
        yield* _expandDynamicProductCandidates(item);
      }
      return;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map["products"] is List) {
        yield* _expandDynamicProductCandidates(map["products"]);
        return;
      }
      if (map["product"] is Map || map["product"] is List) {
        yield* _expandDynamicProductCandidates(map["product"]);
        return;
      }
      if (map["data"] is String) {
        try {
          final decoded = jsonDecode(map["data"]);
          yield* _expandDynamicProductCandidates(decoded);
          return;
        } catch (_) {}
      }
      if (map["data"] is List || map["data"] is Map) {
        yield* _expandDynamicProductCandidates(map["data"]);
        return;
      }
      yield map;
    }
  }

  Future<Map<String, dynamic>?> _findDynamicProductByTokens(
      List<String> tokens) async {
    final normalizedTokens =
    tokens.map((e) => e.toLowerCase().trim()).where((e) => e.isNotEmpty).toList();
    if (normalizedTokens.isEmpty) return null;

    if (_productMetaInitialized && _productMetaCache.isNotEmpty) {
      for (final p in _productMetaCache.values) {
        if (_dynamicProductMatches(p, normalizedTokens)) return p;
      }
    }

    try {
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      for (final entry in entries) {
        if (!entry.key.startsWith("products_") &&
            !entry.key.startsWith("indigo_products_")) {
          continue;
        }

        dynamic decoded;
        try {
          decoded = jsonDecode(entry.json);
        } catch (_) {
          continue;
        }

        for (final map in _expandDynamicProductCandidates(decoded)) {
          if (!_dynamicProductMatches(map, normalizedTokens)) continue;
          final normalized = _normalizeDynamicProductMap(map);
          _cacheDynamicProduct(normalized);
          return normalized;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Dynamic Isar lookup failed for '$normalizedTokens' → $e");
    }

    try {
      final allList = await StorageProvider.productCache.get("all_products_list");
      for (final map in _expandDynamicProductCandidates(allList)) {
        if (!_dynamicProductMatches(map, normalizedTokens)) continue;
        final normalized = _normalizeDynamicProductMap(map);
        _cacheDynamicProduct(normalized);
        return normalized;
      }
    } catch (e) {
      debugPrint("⚠️ Dynamic productCache lookup failed for '$normalizedTokens' → $e");
    }

    return null;
  }

  Map<String, dynamic> _buildFallbackDynamicProduct({
    required int id,
    required String name,
    required String sku,
  }) {
    return <String, dynamic>{
      "fast_key_product_id": id,
      "product_id": id,
      "id": id,
      "fast_key_item_name": name,
      "name": name,
      "fast_key_item_sku": sku,
      "sku": sku,
      "fast_key_item_image": "",
      "image": "",
    };
  }

  Future<Map<String, dynamic>?> _getCashbackProductFromIsar() async {
    final resolved = await _findDynamicProductByTokens([
      "cashback",
      "cash back",
      "cash-back",
      "cash_back",
      "cb",
    ]);
    if (resolved != null) return resolved;

    final fallback = _buildFallbackDynamicProduct(
      id: 3310111,
      name: "Cashback",
      sku: "CASHBACK-DYNAMIC",
    );
    _cacheDynamicProduct(fallback);
    if (kDebugMode) {
      print("⚠️ Cashback product missing in cache → using fallback map");
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _getDiscountProductFromIsar() async {
    final resolved = await _findDynamicProductByTokens([
      "discount",
      "merchant discount",
      "merchant-discount",
      "merchant_discount",
    ]);
    if (resolved != null) return resolved;

    final fallback = _buildFallbackDynamicProduct(
      id: 990002,
      name: "Merchant Discount",
      sku: "MERCHANT-DISCOUNT-DYNAMIC",
    );
    _cacheDynamicProduct(fallback);
    if (kDebugMode) {
      print("Discount product missing in cache → using fallback map");
    }
    return fallback;
  }

  // Build the discount value display

>>>>>>> origin/Grocery_pch_api_integration
  // Handle adding the discount
  //Build #1.0.78: Explanation!
  // Moved merchantDiscount update to OrderBloc.addPayout (already updated in OrderBloc to handle this).
  // Added dbOrderId parameter to addPayout call.
  // Kept local update for non-API orders (serverOrderId == null).
  // Added alert dialog with retry option for API failures.
  // Ensured _isDiscountLoading is shown during API calls and cleared afterward.
  // Preserved success toast and UI refresh logic.
<<<<<<< HEAD
  void _handleAddDiscount() async { // Build #1.0.53 : updated code with discount api call
    String discountValue = _discountValue.replaceAll('%', '').replaceAll(TextConstants.currencySymbol, ''); // Build #1.0.181: 1. Replaced Hard coded ‘\$’ with TextConstants.currencySymbol
    if (discountValue.isEmpty || discountValue == "0" || double.tryParse(discountValue) == null) {
      if (kDebugMode) print("Invalid discount value: $discountValue");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.invalidDiscountError), // Build #1.0.181: Added through TextConstants
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final orderId = OrderHelper().activeOrderId;  //Build #1.0.134: get activeOrderId
    if (orderId == null) {
      if (kDebugMode) print("No active order selected");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.noActiveOrderError), // Build #1.0.181: Added through TextConstants
=======
  // Future<void> _handleAddDiscount() async {
  //   print("🟦 [DISCOUNT] START ---- _handleAddDiscount() ----");
  //
  //   if (_discountValue.isEmpty ||
  //       _discountValue == "0" ||
  //       double.tryParse(_discountValue.replaceAll('%', '')) == null) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Invalid discount amount"),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() => _isDiscountLoading = true);
  //
  //   try {
  //     final offlineBox = StorageProvider.offlineOrders;
  //     final orderHelper = OrderHelper();
  //
  //     int? orderId = orderHelper.activeOrderId;
  //
  //     if (orderId == null) {
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("No active order found"),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //       setState(() => _isDiscountLoading = false);
  //       return;
  //     }
  //
  //     final key = orderId.toString();
  //     final existingOrder = Map<String, dynamic>.from(offlineBox.get(key));
  //
  //     // Load existing discount list
  //     final discounts = (existingOrder["discounts"] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     if (discounts.isNotEmpty) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("A discount already exists for this order."),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // ------------------------------
  //     // 🔎 UNIVERSAL SEARCH FOR DISCOUNT PRODUCT
  //     // Same logic as cashback
  //     // ------------------------------
  //
  //     // 🔎 DISCOUNT PRODUCT FROM ISAR (FAST)
  //     final discountProduct = await _getDiscountProductFromIsar();
  //
  //     if (discountProduct == null) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Discount product not found!"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     print("🟢 FOUND DISCOUNT PRODUCT → $discountProduct");
  //
  //     // Map<String, dynamic>? discountProduct;
  //     //
  //     // for (final k in productBox.keys) {
  //     //   final data = productBox.get(k);
  //     //   if (data == null) continue;
  //     //
  //     //   // Case A: Direct map
  //     //   if (data is Map) {
  //     //     final n = (data["fast_key_item_name"] ?? data["name"] ?? "")
  //     //         .toString()
  //     //         .toLowerCase();
  //     //
  //     //     if (n.contains("discount")) {
  //     //       discountProduct = Map<String, dynamic>.from(data);
  //     //       break;
  //     //     }
  //     //   }
  //     //
  //     //   // Case B: products list
  //     //   if (data is Map && data.containsKey("products")) {
  //     //     for (final item in data["products"]) {
  //     //       final n = (item["fast_key_item_name"] ?? item["name"] ?? "")
  //     //           .toString()
  //     //           .toLowerCase();
  //     //
  //     //       if (n.contains("discount")) {
  //     //         discountProduct = Map<String, dynamic>.from(item);
  //     //         break;
  //     //       }
  //     //     }
  //     //     if (discountProduct != null) break;
  //     //   }
  //     //
  //     //   // Case C: data: JSON array
  //     //   if (data is Map && data.containsKey("data")) {
  //     //     final list = json.decode(data["data"]);
  //     //     for (final item in list) {
  //     //       final n = (item["fast_key_item_name"] ?? item["name"] ?? "")
  //     //           .toString()
  //     //           .toLowerCase();
  //     //
  //     //       if (n.contains("discount")) {
  //     //         discountProduct = Map<String, dynamic>.from(item);
  //     //         break;
  //     //       }
  //     //     }
  //     //     if (discountProduct != null) break;
  //     //   }
  //     // }
  //     //
  //     // if (discountProduct == null) {
  //     //   print("🟥 Discount Product Not Found in Cache!");
  //     //   setState(() => _isDiscountLoading = false);
  //     //
  //     //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //     //     const SnackBar(
  //     //       content: Text("Discount product not found!"),
  //     //       backgroundColor: Colors.red,
  //     //     ),
  //     //   );
  //     //   return;
  //     // }
  //
  //     print("🟢 FOUND DISCOUNT PRODUCT → $discountProduct");
  //
  //     // ------------------------------
  //     // Load products
  //     // ------------------------------
  //     final products = (existingOrder["products"] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     // / ⛔ ADD CHECK HERE
  //     if (products.isEmpty) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Cannot apply discount on an empty order"),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }
  //
  //
  //     // Calculate gross total
  //     double grossTotal = 0.0;
  //     for (var p in products) {
  //       grossTotal +=
  //           (double.tryParse(p["price"].toString()) ?? 0.0) *
  //               (double.tryParse(p["quantity"].toString()) ?? 1.0);
  //     }
  //
  //     // Parse discount amount
  //     String parsedValue =
  //     _discountValue.replaceAll('%', '').replaceAll("₹", "").trim();
  //
  //     double discountAmount = double.parse(parsedValue);
  //     bool isPercentage = _isPercentageSelected;
  //
  //     if (isPercentage) {
  //       discountAmount = (discountAmount / 100) * grossTotal;
  //     }
  //
  //     if (discountAmount > grossTotal) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Discount cannot exceed total amount"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // ------------------------------
  //     // 🧾 CREATE DISCOUNT ENTRY
  //     // ------------------------------
  //     final discountEntry = {
  //       "order_id": orderId,
  //       "discount_product_id":
  //       discountProduct["product_id"] ??
  //           discountProduct["id"] ??
  //           discountProduct["fast_key_product_id"],
  //       // ⭐ SAME AS CASHBACK
  //       "name": discountProduct["fast_key_item_name"] ?? "Discount",
  //       "product_image": discountProduct["fast_key_item_image"] ?? "",
  //
  //       "discount_amount": -discountAmount,     // Negative for Woo
  //       "display_amount": discountAmount,       // Shown positive in UI
  //
  //       "discount_type": isPercentage ? "percentage" : "fixed",
  //       "original_input": _discountValue,
  //
  //       // Required for summary panel
  //       AppDBConst.itemName: "Discount",
  //       AppDBConst.itemType: "discount",
  //       AppDBConst.itemPrice: discountAmount.abs(),
  //       AppDBConst.itemSumPrice: discountAmount.abs(),
  //       AppDBConst.itemCount: 1,
  //
  //       "timestamp": DateTime.now().toIso8601String(),
  //     };
  //
  //     discounts.add(discountEntry);
  //
  //     // Recalculate totals
  //     double finalTotal = grossTotal - discountAmount;
  //
  //     final updatedOrder = {
  //       ...existingOrder,
  //       "products": products,
  //       "discounts": discounts,
  //       "gross_total": grossTotal,
  //       "net_total": grossTotal - discountAmount,
  //       "net_payable": finalTotal,
  //
  //       // ⭐ REQUIRED FIELDS FOR SUMMARY PANEL ⭐
  //       "merchantDiscount": discountAmount,              // <--- You MISSED THIS
  //       "merchantDiscountIsPercentage": isPercentage,    // <--- You MISSED THIS
  //       "merchantDiscountIds": [
  //         discountProduct["product_id"] ??
  //             discountProduct["id"] ??
  //             discountProduct["fast_key_product_id"]
  //       ],
  //     };
  //
  //
  //
  //     await offlineBox.put(key, updatedOrder);
  //
  //     // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //     //   SnackBar(
  //     //     content:
  //     //     Text("Discount of ₹${discountAmount.toStringAsFixed(2)} applied"),
  //     //     backgroundColor: Colors.green,
  //     //   ),
  //     // );
  //
  //     setState(() {
  //       _discountValue = isPercentage ? "0%" : "0";
  //       _isDiscountLoading = false;
  //     });
  //
  //     await _loadOrderData();
  //     widget.refreshOrderList?.call();
  //
  //     print("✅ [DISCOUNT] DONE ---- _handleAddDiscount() ----");
  //
  //   } catch (e, s) {
  //     print("🟥 [DISCOUNT] ERROR: $e\n$s");
  //     setState(() => _isDiscountLoading = false);
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       SnackBar(
  //         content: Text("Error applying discount: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }


  Future<void> _handleAddDiscount() async {
    print("🟦 [DISCOUNT] START ---- _handleAddDiscount() ----");

    // ────────────────────────────────────────
    // 1. Basic input validation
    // ────────────────────────────────────────
    if (_discountValue.isEmpty ||
        _discountValue == "0" ||
        _discountValue == "0%" ||
        double.tryParse(_discountValue
            .replaceAll('%', '')
            .replaceAll("₹", "")
            .trim()) ==
            null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid discount amount"),
>>>>>>> origin/Grocery_pch_api_integration
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

<<<<<<< HEAD
    setState(() {
      _isDiscountLoading = true;
    });

    try {
      // Fetch the current order total and serverOrderId from the database
      final db = await DBHelper.instance.database;
      final orderData = await db.query(
        AppDBConst.orderTable,
        where: '${AppDBConst.orderServerId} = ?',
        whereArgs: [orderId],
      );

      if (orderData.isEmpty) {
        if (kDebugMode) print("Order $orderId not found in database");
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar( // Build #1.0.128:  updated missed condition
          const SnackBar(
            content: Text(TextConstants.orderNotFoundError), // Build #1.0.181: Added through TextConstants
=======
    setState(() => _isDiscountLoading = true);

    try {
      final offlineBox = StorageProvider.offlineOrders;
      final orderHelper = OrderHelper();

      final orderId = orderHelper.activeOrderId;
      if (orderId == null) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("No active order found"),
>>>>>>> origin/Grocery_pch_api_integration
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
<<<<<<< HEAD
        return;
      }

      final serverOrderId = orderData.first[AppDBConst.orderServerId] as int?;
      /// Build #1.0.131: Issue Fixed: now correctly calculates order total after adding percentage discounts in add screen.
      /// For example, a 2% discount on ₹137 is now shown as ₹134.26 instead of ₹134.15.
      double currentOrderTotalWithTax = orderData.first[AppDBConst.orderTotal] as double? ?? 0.0;
      double currentOrderTax = orderData.first[AppDBConst.orderTax] as double? ?? 0.0;
      double mainOrderTotal = currentOrderTotalWithTax - currentOrderTax;
      if (kDebugMode) print("Fetched order total for order $orderId: OrderTotalWithTax - $currentOrderTotalWithTax,  OrderTax - $currentOrderTax, MainOrderTotal WithOut Tax - $mainOrderTotal");

      // Calculate discount based on current order total
      double discountAmount = double.parse(discountValue);
      if (_isPercentageSelected) {
        discountAmount = (discountAmount / 100) * mainOrderTotal; // Build #1.0.131
        if (kDebugMode) print("Calculated discount amount from percentage: $discountAmount");
      }

      //Build #1.0.78: For non-API orders, update locally
      // if (serverOrderId == null) {
      //   await db.update(
      //     AppDBConst.orderTable,
      //     {
      //       AppDBConst.merchantDiscount: discountAmount,
      //     },
      //     where: '${AppDBConst.orderServerId} = ?',
      //     whereArgs: [orderId],
      //   );
      //   setState(() {
      //     _discountValue = _isPercentageSelected ? "0%" : "0";
      //     _isDiscountLoading = false;
      //   });
      //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //     SnackBar(
      //       content: Text("Discount of \$${discountAmount.toStringAsFixed(2)} applied"),
      //       backgroundColor: Colors.green,
      //       duration: const Duration(seconds: 2),
      //     ),
      //   );
      //   await _orderHelper.loadData();
      //   await _loadOrderData();
      //   widget.refreshOrderList?.call();
      //   return;
      // }

      if (serverOrderId == null) {

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          SnackBar(
            content: Text("Discount of ${TextConstants.currencySymbol}${discountAmount.toStringAsFixed(2)} not applied, order id $serverOrderId not found in DB"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
=======
        setState(() => _isDiscountLoading = false);
        return;
      }

      final key = orderId.toString();
      final rawOrder = await offlineBox.get(key);
      if (rawOrder == null) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Order data not found"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final existingOrder = Map<String, dynamic>.from(rawOrder);

      // ────────────────────────────────────────
      // 2. Prevent multiple discounts (your current rule)
      // ────────────────────────────────────────
      final discounts = (existingOrder["discounts"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (discounts.isNotEmpty) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("A discount is already applied to this order."),
            backgroundColor: Colors.orange,
>>>>>>> origin/Grocery_pch_api_integration
          ),
        );
        return;
      }

<<<<<<< HEAD
      //Build #1.0.78: API-first approach for orders with serverOrderId
      StreamSubscription? subscription;

      subscription = orderBloc.addPayoutStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.COMPLETED) {
          if (kDebugMode) print("Discount confirmed via API for order $orderId");
          setState(() {
            _discountValue = _isPercentageSelected ? "0.00%" : "0.00";
          });
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text("Discount of ${TextConstants.currencySymbol}${discountAmount.toStringAsFixed(2)} applied"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _isDiscountLoading = false); //Build #1.0.92: fixed loader issue
          await _orderHelper.loadData();
          await _loadOrderData();
          widget.refreshOrderList?.call();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (kDebugMode) print("Failed to confirm discount: ${response.message}");
          setState(() => _isDiscountLoading = false); // Build #1.0.181: Fixed - continues loader on add discount button for empty order
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text(response.message ?? "Failed to apply discount"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4), // Build #1.0.181: increased reading time for the error toast message!
            ),
          );

          subscription?.cancel();
        }
      });

      await orderBloc.addPayout(orderId: serverOrderId, dbOrderId: orderId, amount: discountAmount, isPayOut: false);
    } catch (e) {
      if (kDebugMode) print("Error processing discount: $e");
      setState(() => _isDiscountLoading = false);
=======
      // ────────────────────────────────────────
      // 3. Find discount product
      // ────────────────────────────────────────
      final discountProduct = await _getDiscountProductFromIsar();

      if (discountProduct == null) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Discount product not found in catalog"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print(
          "🟢 Discount product found → ${discountProduct['name'] ?? 'Discount'}");

      // ────────────────────────────────────────
      // 4. Calculate current gross total (before discount)
      // Support both "products" (Categories/Fast Keys) and "order_items" (Order Summary)
      // ────────────────────────────────────────
      var products = (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Fallback: order may have order_items from Order Summary screen
      if (products.isEmpty) {
        final orderItems = (existingOrder["order_items"] as List? ?? []);
        for (final oi in orderItems) {
          final map = Map<String, dynamic>.from(oi is Map ? oi : {});
          final itemType =
          (map['item_type'] ?? map['type'] ?? '').toString().toLowerCase();
          if (itemType.contains('discount')) continue;
          products.add({
            ...map,
            'name': map['item_name'] ?? map['name'] ?? '',
            'price': (map['item_price'] ?? map['price'] ?? 0).toDouble(),
            'quantity': (map['items_count'] ?? map['quantity'] ?? 1).toInt(),
            'product_id': map['product_id'],
            'sku': map['sku'] ?? map['item_sku'],
            'type': map['item_type'] ?? map['type'] ?? 'product',
          });
        }
      }

      if (products.isEmpty) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cannot apply discount on an empty order"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      double grossTotal = 0.0;
      for (var p in products) {
        final price = double.tryParse(p["price"]?.toString() ?? '0') ?? 0.0;
        final qty = int.tryParse(p["quantity"]?.toString() ?? '1') ?? 1;
        grossTotal += price * qty;
      }

      print(
          "Current gross total before discount: ₹${grossTotal.toStringAsFixed(2)}");

      // ────────────────────────────────────────
      // 5. Parse discount value
      // ────────────────────────────────────────
      String parsedValue = _discountValue
          .replaceAll('%', '')
          .replaceAll(TextConstants.currencySymbol, '')
          .replaceAll("₹", "")
          .trim();

      double inputValue = double.parse(parsedValue);
      bool isPercentage = _isPercentageSelected;

      // Extract existing order tax and order discount
      double couponVal = (existingOrder['orderDiscount'] as num?)?.toDouble() ?? 0.0;

      double discountAmount =
      isPercentage ? (inputValue / 100) * (grossTotal - couponVal) : inputValue;

      if (discountAmount > (grossTotal - couponVal)) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Discount cannot exceed the current order total"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ────────────────────────────────────────
      // 6. Create discount line item (for order panel / receipt)
      // ────────────────────────────────────────
      final discountEntry = {
        "order_id": orderId,
        "discount_product_id": discountProduct["product_id"] ??
            discountProduct["id"] ??
            discountProduct["fast_key_product_id"],
        "name": discountProduct["fast_key_item_name"] ?? "Merchant Discount",
        "product_image": discountProduct["fast_key_item_image"] ?? "",
        "discount_amount": -discountAmount, // negative for accounting
        "display_amount": discountAmount, // positive for display
        "discount_type": isPercentage ? "percentage" : "fixed",
        "discount_percentage": isPercentage ? inputValue : 0.0,
        "original_input": _discountValue,
        AppDBConst.itemName: "Merchant Discount",
        AppDBConst.itemType: "discount",
        AppDBConst.itemPrice: discountAmount.abs(),
        AppDBConst.itemSumPrice: discountAmount.abs(),
        AppDBConst.itemCount: 1,
        "timestamp": DateTime.now().toIso8601String(),
      };

      discounts.add(discountEntry);

      // ────────────────────────────────────────
      // 7. Save updated order with better fields for future recalculation
      // ────────────────────────────────────────
      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "discounts": discounts,
        "gross_total": grossTotal,
        "net_total": grossTotal - discountAmount,
        "net_payable": grossTotal - discountAmount,

        // ──────── Fields for dynamic recalculation ────────
        "merchantDiscount": discountAmount, // current calculated value
        "merchantDiscountType": isPercentage ? "percentage" : "fixed",
        "merchantDiscountPercentage": isPercentage ? inputValue : 0.0,
        "merchantDiscountFixed": isPercentage ? 0.0 : discountAmount,
        "merchantDiscountBaseGross":
        grossTotal, // snapshot of total when applied
        "merchantDiscountIds": [
          discountProduct["product_id"] ??
              discountProduct["id"] ??
              discountProduct["fast_key_product_id"]
        ],
      };

      await offlineBox.put(key, updatedOrder);
      await _pushCfdAfterAppsChange(orderId);
      print("💾 Discount saved successfully");
      print("   • Type:        ${updatedOrder['merchantDiscountType']}");
      print("   • Percentage:  ${updatedOrder['merchantDiscountPercentage']}%");
      print("   • Fixed:       ₹${updatedOrder['merchantDiscountFixed']}");
      print(
          "   • Current amt: ₹${updatedOrder['merchantDiscount']?.toStringAsFixed(2)}");

      // ────────────────────────────────────────
      // 8. UI feedback & cleanup
      // ────────────────────────────────────────
      setState(() {
        _discountValue = isPercentage ? "0%" : "0.00";
        _isDiscountLoading = false;
      });

      await _orderHelper.loadData();
      await _loadOrderData();
      OrderHelper.notifyOrderPanelToRefresh();
      widget.refreshOrderList?.call();

      print(" [DISCOUNT] DONE ---- _handleAddDiscount() ----");
    } catch (e, stack) {
      print("🟥 [DISCOUNT] ERROR: $e");
      print("Stack trace: $stack");
      setState(() => _isDiscountLoading = false);

>>>>>>> origin/Grocery_pch_api_integration
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error applying discount: $e"),
          backgroundColor: Colors.red,
<<<<<<< HEAD
          duration: const Duration(seconds: 2),
=======
          duration: const Duration(seconds: 3),
>>>>>>> origin/Grocery_pch_api_integration
        ),
      );
    }
  }
<<<<<<< HEAD

// Handle adding the coupon
  void _handleAddCoupon() async {
    if (_couponCode.isEmpty || _couponCode == "0") {
      if (kDebugMode) print("### _couponCode is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.invalidCouponError), // Build #1.0.181: Added through TextConstants
=======
// Handle adding the coupon
//   void _handleAddCoupon() async {
//     if (_couponCode.isEmpty || _couponCode == "0") {
//       if (kDebugMode) print("### _couponCode is empty");
//       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//         const SnackBar(
//           content: Text(TextConstants.invalidCouponError),
//           // Build #1.0.181: Added through TextConstants
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     final orderId = OrderHelper()
//         .activeOrderId; //Build #1.0.134: get activeOrderId
//     if (orderId == null) {
//       if (kDebugMode) print("No active order selected");
//       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//         const SnackBar(
//           content: Text(TextConstants.noActiveOrderError),
//           // Build #1.0.181: Added through TextConstants
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isCouponLoading = true;
//     });
//
//     try {
//       final db = await DBHelper.instance.database;
//
//       final orderData = await db
//           .query( // Build #1.0.128: updated missed condition
//         AppDBConst.orderTable,
//         where: '${AppDBConst.orderServerId} = ?',
//         whereArgs: [orderId],
//       );
//
//       if (orderData.isEmpty) {
//         if (kDebugMode) print("Order $orderId not found in database");
//         setState(() => _isCouponLoading = false);
//         ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//           const SnackBar(
//             content: Text(TextConstants.orderNotFoundError),
//             // Build #1.0.181: Added through TextConstants
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         return;
//       }
//
//       // Check for existing coupon with the same couponCode
//       final existingCoupons = await db.query(
//         AppDBConst.purchasedItemsTable,
//         where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst
//             .itemName} = ? AND ${AppDBConst.itemType} = ?',
//         whereArgs: [orderId, _couponCode, ItemType.coupon.value],
//       );
//
//       if (existingCoupons.isNotEmpty) {
//         if (kDebugMode) print(
//             "Coupon with code $_couponCode already exists for order $orderId");
//         ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//           const SnackBar(
//             content: Text(TextConstants.couponAlreadyApplied),
//             // Build #1.0.181: Added through TextConstants
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         setState(() {
//           _isCouponLoading = false;
//         });
//         return;
//       }
//
//       StreamSubscription? subscription;
//       if (kDebugMode) print("### Subscribing to applyCouponStream");
//       subscription = orderBloc.applyCouponStream.listen((response) async {
//         if (!mounted) {
//           subscription?.cancel();
//           return;
//         }
//         if (response.status == Status.COMPLETED) {
//           // Insert coupons into DB, ensuring no duplicates
//           for (var coupon in response.data?.couponLines ?? []) {
//             if (coupon.code == null || coupon.id == null) {
//               if (kDebugMode) print("Invalid coupon data: code or id is null");
//               continue;
//             }
//
//             // Double-check for itemServerId to be extra safe
//             final duplicateCheck = await db.query(
//               AppDBConst.purchasedItemsTable,
//               where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst
//                   .itemServerId} = ?',
//               whereArgs: [orderId, coupon.id],
//             );
//
//             if (duplicateCheck.isEmpty) {
//               await db.insert(AppDBConst.purchasedItemsTable, {
//                 AppDBConst.orderIdForeignKey: orderId!,
//                 AppDBConst.itemServerId: coupon.id,
//                 AppDBConst.itemName: coupon.code!,
//                 AppDBConst.itemSKU: '',
//                 AppDBConst.itemPrice: coupon.nominalAmount?.toDouble() ?? 0.0,
//                 AppDBConst.itemCount: 1,
//                 AppDBConst.itemSumPrice: coupon.nominalAmount?.toDouble() ??
//                     0.0,
//                 AppDBConst.itemImage: 'assets/svg/coupon.svg',
//                 AppDBConst.itemType: ItemType.coupon.value,
//               });
//             }
//           }
//           if (Misc.showDebugSnackBar) {
//             ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//               SnackBar(
//                 content: Text("Coupon '${_couponCode}' applied successfully"),
//                 backgroundColor: Colors.green,
//                 duration: const Duration(seconds: 2),
//               ),
//             );
//           }
//
//           setState(() { // Build #1.0.248: Fixed [SCRUM-400] -> Inappropriate Toast Message Displaying After Custom Item & Coupon Addition
//             _couponCode = "";
//             _isCouponLoading = false;
//           });
//
//           // Refresh UI
//           await _orderHelper.loadData();
//           await _loadOrderData();
//           widget.refreshOrderList?.call();
//           subscription?.cancel();
//         } else if (response.status == Status.ERROR) {
//           if (kDebugMode) print("Failed to apply coupon: ${response.message}");
//           ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//             SnackBar(
//               content: Text(response.message ?? "Failed to apply coupon"),
//               backgroundColor: Colors.red,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//           setState(() {
//             _isCouponLoading = false;
//           });
//           subscription?.cancel();
//         }
//       }, onError: (error) {
//         if (kDebugMode) print("### applyCouponStream error: $error");
//         setState(() {
//           _isCouponLoading = false;
//         });
//         subscription?.cancel();
//       });
//
//       if (kDebugMode) print("### Calling orderBloc.applyCouponToOrder");
//       await orderBloc.applyCouponToOrder(
//           orderId: orderId!, couponCode: _couponCode);
//     } catch (e) {
//       if (kDebugMode) print("Error applying coupon: $e");
//       setState(() {
//         _isCouponLoading = false;
//       });
//     }
//   }

  void _handleCashbackpayout() async {
    print("🟩 [CASHBACK] START ---- _handleCashbackpayout() ----");

    if (_cashbackAmount.isEmpty ||
        _cashbackAmount == "0.00" ||
        double.tryParse(_cashbackAmount) == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Invalid cashback amount"),
>>>>>>> origin/Grocery_pch_api_integration
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

<<<<<<< HEAD
    final orderId = OrderHelper().activeOrderId;  //Build #1.0.134: get activeOrderId
    if (orderId == null) {
      if (kDebugMode) print("No active order selected");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.noActiveOrderError), // Build #1.0.181: Added through TextConstants
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCouponLoading = true;
    });

    try {

      final db = await DBHelper.instance.database;

      final orderData = await db.query( // Build #1.0.128: updated missed condition
        AppDBConst.orderTable,
        where: '${AppDBConst.orderServerId} = ?',
        whereArgs: [orderId],
      );

      if (orderData.isEmpty) {
        if (kDebugMode) print("Order $orderId not found in database");
        setState(() => _isCouponLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.orderNotFoundError), // Build #1.0.181: Added through TextConstants
=======
    setState(() => _isCashbackLoading = true);

    try {
      final offlineBox = StorageProvider.offlineOrders;
      final cashbackAmount = double.parse(_cashbackAmount);
      // 🔥 MAX CASHBACK VALIDATION
      if (_maxCashbackLimit > 0 && cashbackAmount > _maxCashbackLimit) {
        setState(() => _isCashbackLoading = false);

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          SnackBar(
            content: Text(
              "Cashback cannot exceed ${TextConstants.currencySymbol}${_maxCashbackLimit.toStringAsFixed(2)}",
            ),
>>>>>>> origin/Grocery_pch_api_integration
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
<<<<<<< HEAD
        return;
      }

      // Check for existing coupon with the same couponCode
      final existingCoupons = await db.query(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemName} = ? AND ${AppDBConst.itemType} = ?',
        whereArgs: [orderId, _couponCode, ItemType.coupon.value],
      );

      if (existingCoupons.isNotEmpty) {
        if (kDebugMode) print("Coupon with code $_couponCode already exists for order $orderId");
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.couponAlreadyApplied), // Build #1.0.181: Added through TextConstants
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isCouponLoading = false;
        });
        return;
      }

      StreamSubscription? subscription;
      if (kDebugMode) print("### Subscribing to applyCouponStream");
      subscription = orderBloc.applyCouponStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.COMPLETED) {
          // Insert coupons into DB, ensuring no duplicates
          for (var coupon in response.data?.couponLines ?? []) {
            if (coupon.code == null || coupon.id == null) {
              if (kDebugMode) print("Invalid coupon data: code or id is null");
              continue;
            }

            // Double-check for itemServerId to be extra safe
            final duplicateCheck = await db.query(
              AppDBConst.purchasedItemsTable,
              where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemServerId} = ?',
              whereArgs: [orderId, coupon.id],
            );

            if (duplicateCheck.isEmpty) {
              await db.insert(AppDBConst.purchasedItemsTable, {
                AppDBConst.orderIdForeignKey: orderId!,
                AppDBConst.itemServerId: coupon.id,
                AppDBConst.itemName: coupon.code!,
                AppDBConst.itemSKU: '',
                AppDBConst.itemPrice: coupon.nominalAmount?.toDouble() ?? 0.0,
                AppDBConst.itemCount: 1,
                AppDBConst.itemSumPrice: coupon.nominalAmount?.toDouble() ?? 0.0,
                AppDBConst.itemImage: 'assets/svg/coupon.svg',
                AppDBConst.itemType: ItemType.coupon.value,
              });
            }
          }

          setState(() {
            _couponCode = "";
            _isCouponLoading = false;
          });

          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text("Coupon '${_couponCode}' applied successfully"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Refresh UI
          await _orderHelper.loadData();
          await _loadOrderData();
          widget.refreshOrderList?.call();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (kDebugMode) print("Failed to apply coupon: ${response.message}");
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text(response.message ?? "Failed to apply coupon"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {
            _isCouponLoading = false;
          });
          subscription?.cancel();
        }
      }, onError: (error) {
        if (kDebugMode) print("### applyCouponStream error: $error");
        setState(() {
          _isCouponLoading = false;
        });
        subscription?.cancel();
      });

      if (kDebugMode) print("### Calling orderBloc.applyCouponToOrder");
      await orderBloc.applyCouponToOrder(orderId: orderId!, couponCode: _couponCode);
    } catch (e) {
      if (kDebugMode) print("Error applying coupon: $e");
      setState(() {
        _isCouponLoading = false;
      });
    }
  }

  // Handle adding the custom item
  //Build #1.0.78: Explanation!
  // Moved custom item insertion and order total update to OrderBloc.updateOrderProducts.
  // Added sku to OrderLineItem for API calls.
  // Added dbOrderId parameter to updateOrderProducts.
  // Kept local insertion for non-API orders.
  // Added alert dialog with retry option for API failures.
  // Ensured _isCustomItemLoading is shown during API calls.
  // Preserved success toast, UI refresh, and field clearing logic.
  // Removed commented-out navigation code, as it’s marked as not working.
  void _handleAddCustomItem() async {
    if (kDebugMode) print("#### DEBUG 55@99 _handleAddCustomItem");

    // Validation
    if (_customItemName.isEmpty) {
      if (kDebugMode) print("Custom item name is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.itemNameRequired), // Build #1.0.181: Added through TextConstants
=======
        return; // ❗ STOP here → Do NOT add cashback
      }

      final orderHelper = OrderHelper();
      int? orderId = await orderHelper.ensureOrderExists();
      if (orderId == null) {
        setState(() => _isCashbackLoading = false);
        final msg = OrderHelper.lastEnsureOrderError ??
            "Could not create or find an order. Please try again.";
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final key = orderId.toString();
      final rawKey = await offlineBox.get(key);
      final existingOrder =
      Map<String, dynamic>.from(rawKey is Map ? rawKey : {});

      // -------------------------------------------------------
// 🚫 STOP Cashback if order panel has EBT eligible product
// -------------------------------------------------------
      final List<Map<String, dynamic>> existingProducts =
      (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // 🚫 STOP Cashback if no products in cart
      if (existingProducts.isEmpty) {
        setState(() => _isCashbackLoading = false);

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Add products to cart before applying cashback."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );

        return;
      }

      bool hasEbtProduct = existingProducts.any((p) {
        return p["is_ebt_eligible"] == true;
      });

      if (hasEbtProduct) {
        // EBT products are allowed to receive cashback in this flow.
        // Previously we blocked this with an early return.
        print("✅ EBT product detected, but cashback is still allowed.");
      }

      final List<Map<String, dynamic>> cashbacks =
      (existingOrder["cashbacks"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ❌ Only 1 cashback allowed
      if (cashbacks.isNotEmpty) {
        setState(() => _isCashbackLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cashback already applied."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final cashbackProduct = await _getCashbackProductFromIsar();

      if (cashbackProduct == null) {
        throw "Dynamic cashback product not found in Isar cache!";
      }

      print("🟢 FOUND CASHBACK PRODUCT → $cashbackProduct");

      // -------------------------------------------------------
      // 🟢 UNIVERSAL PRODUCT SEARCH FOR "Cashback"
      // -------------------------------------------------------
      // Map<String, dynamic>? cashbackProduct;
      //
      // for (final k in productBox.keys) {
      //   final data = productBox.get(k);
      //
      //   if (data == null) continue;
      //
      //   // Case A: Direct product map (YOUR MAIN storage)
      //   if (data is Map) {
      //     final name = (data["fast_key_item_name"] ??
      //         data["name"] ??
      //         "").toString().toLowerCase();
      //
      //     if (name.contains("cashback")) {
      //       cashbackProduct = Map<String, dynamic>.from(data);
      //       break;
      //     }
      //   }
      //
      //   // Case B: { "products": [ ... ] } format
      //   if (data is Map && data.containsKey("products")) {
      //     final list = data["products"];
      //     if (list is List) {
      //       for (final item in list) {
      //         final name = (item["fast_key_item_name"] ??
      //             item["name"] ??
      //             "").toString().toLowerCase();
      //
      //         if (name.contains("cashback")) {
      //           cashbackProduct = Map<String, dynamic>.from(item);
      //           break;
      //         }
      //       }
      //     }
      //   }
      //
      //   // Case C: { "data": [...] } format
      //   if (data is Map && data.containsKey("data")) {
      //     final list = json.decode(data["data"]);
      //     if (list is List) {
      //       for (final item in list) {
      //         final name = (item["fast_key_item_name"] ??
      //             item["name"] ??
      //             "").toString().toLowerCase();
      //
      //         if (name.contains("cashback")) {
      //           cashbackProduct = Map<String, dynamic>.from(item);
      //           break;
      //         }
      //       }
      //     }
      //   }
      //
      //   if (cashbackProduct != null) break;
      // }
      //
      // if (cashbackProduct == null) {
      //   throw "Dynamic cashback product not found in productCache!";
      // }
      //
      // print("🟢 FOUND CASHBACK PRODUCT → $cashbackProduct");

      // -------------------------------------------------------
      // 🧾 PREPARE CASHBACK ENTRY
      // -------------------------------------------------------
      final cashbackEntry = {
        "order_id": orderId,
        "cashback_product_id": cashbackProduct["fast_key_product_id"],
        "product_name": cashbackProduct["fast_key_item_name"],
        "product_image":
        "https://merchantretail.alektasolutions.com/wp-content/uploads/2025/11/cashback-line-item.jpg",

        // ---- your amount ----
        "amount": cashbackAmount,

        // ---- REQUIRED FOR ORDER PANEL ----
        AppDBConst.itemPrice: cashbackAmount.abs(), // ⭐ MUST
        AppDBConst.itemSumPrice: cashbackAmount.abs(), // ⭐ MUST
        AppDBConst.itemCount: 1, // ⭐ MUST
        AppDBConst.itemName: "Cashback", // optional but clean
        AppDBConst.itemType: "cashback",

        "timestamp": DateTime.now().toIso8601String(),
      };

      cashbacks.add(cashbackEntry);

      print("🟦 Cashback Entry Added → $cashbackEntry");

      // -------------------------------------------------------
      // 🔄 Recalculate total
      // -------------------------------------------------------
      final List<Map<String, dynamic>> products =
      (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      double productsTotal = 0.0;
      for (var p in products) {
        productsTotal += (double.tryParse(p["price"].toString()) ?? 0.0) *
            (double.tryParse(p["quantity"].toString()) ?? 1.0);
      }

      // Cashback reduces total
      // 1️⃣ Calculate cashback fee from config
      final double fee = await CashbackHelper.getCashbackFee(cashbackAmount);

      print("💰 CashbackAmount = $cashbackAmount → Fee = $fee");

      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "cashbacks": cashbacks,

        // 2️⃣ Cashback reduces total, fee increases total
        "gross_total": productsTotal + cashbackAmount,

        // 3️⃣ Store cashback fee (NOT cashbackAmount)
        "cashbackFee": fee,
        AppDBConst.orderCashbackFee: fee,
      };

      await offlineBox.put(key, updatedOrder);
      print("🟩 SAVED ORDER → $updatedOrder");

      final extrasBox = StorageProvider.orderExtras;

// 🔒 NEVER overwrite an existing cashback
      final existingExtras = await extrasBox.get(orderId.toString());

      final double finalCashbackFee =
      existingExtras != null && existingExtras['cashback_fee'] != null
          ? (existingExtras['cashback_fee'] as num).toDouble()
          : fee;

      await extrasBox.put(orderId.toString(), {
        "local_order_id": orderId,
        "cashback_fee": finalCashbackFee,
        "cashback_amount": cashbackAmount, // optional, useful for audit
        "source": "cashback_payout",
        "saved_at": DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print("""
💾 [orderExtras] Cashback SAVED DIRECTLY
  Local Order ID : $orderId
  Cashback Amt  : $cashbackAmount
  Cashback Fee  : $finalCashbackFee
""");
      }


      try {
        CustomerDisplayHelper.skipNextPendingOrderRefresh = false; // ✅ NEW: guard against a stale skip flag eating this explicit update
        await CustomerDisplayHelper.updateCustomerDisplay(orderId, summaryEnabled: false);
        print("📺 Customer display updated after cashback addition");
      } catch (e) {
        print("❌ Customer display update failed after cashback: $e");
      }


      setState(() {
        _cashbackAmount = "";
        _isCashbackLoading = false;
      });
      await offlineBox.put(key, updatedOrder);
      await _pushCfdAfterAppsChange(orderId);
      await _orderHelper.loadData();
      await _loadOrderData();
      OrderHelper.notifyOrderPanelToRefresh();
      widget.refreshOrderList?.call();
    } catch (e, s) {
      print("🟥 [CASHBACK ERROR] $e\n$s");
      setState(() => _isCashbackLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
            content: Text("Error adding cashback: $e"),
            backgroundColor: Colors.red),
      );
    }
  }



  // Future<void> _handleAddCustomItem() async {
  //   if (kDebugMode) print("🟢 [CUSTOM ITEM] START");
  //
  //   // ── VALIDATION FIRST (BEFORE ANY OPERATIONS) ─────────────────
  //   if (_selectedCategoryName.trim() == "Select Category" ||
  //       _selectedCategoryName.trim().isEmpty ||
  //       !_categoriesList.any((cat) =>
  //       cat['name']?.toString().trim() == _selectedCategoryName.trim())) {
  //
  //     // Reset price field
  //     setState(() {
  //       _customItemPrice = "0.00";
  //       _customItemPriceController.text = "${TextConstants.currencySymbol}0.00";
  //       _isEnteringItemPrice = false;
  //     });
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please select a category before adding"),
  //         backgroundColor: Colors.orange,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return; // ← EXIT EARLY
  //   }
  //
  //   final orderHelper = OrderHelper();
  //   final int? ensuredOrderId = await orderHelper.ensureOrderExists();
  //
  //   if (ensuredOrderId == null) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Failed to create order"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   // ── Price Validation ────────────────────────────────────────
  //   final cleanedPrice = _customItemPrice.replaceAll(RegExp(r'[^0-9.]'), '');
  //   final double? price = double.tryParse(cleanedPrice);
  //   if (price == null || price <= 0) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please enter valid price"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() => _isCustomItemLoading = true);
  //
  //   try {
  //     final box = StorageProvider.offlineOrders;
  //     final key = ensuredOrderId.toString();
  //     final rawOrder = await box.get(key) ?? {};
  //     final orderData = Map<String, dynamic>.from(rawOrder);
  //
  //     List<dynamic> products = (orderData["products"] ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     // ── Find selected custom item from dropdown ──────────────
  //     final selectedItem = _customItemsList.firstWhere(
  //           (item) => (item['name']?.toString() ?? "") == _selectedCustomItemName,
  //       orElse: () => _customItemsList.isNotEmpty ? _customItemsList.first : {},
  //     );
  //
  //     final String baseItemName = selectedItem['name']?.toString() ?? "Custom Item";
  //     final int selectedProductId = selectedItem['id'] ?? 60303;
  //
  //     // ── EXTRACT TAGS FROM SELECTED ITEM ───────────────────────
  //     final List<dynamic> rawTags = selectedItem['tags'] is List ? selectedItem['tags'] : [];
  //     final List<Map<String, dynamic>> tags = rawTags
  //         .map((tag) {
  //       if (tag is Map) {
  //         return Map<String, dynamic>.from(tag);
  //       }
  //       return <String, dynamic>{};
  //     })
  //         .where((tag) => tag.isNotEmpty)
  //         .cast<Map<String, dynamic>>()
  //         .toList();
  //
  //     // ── CHECK FOR PRODUCE TAG ──────────────────────────────────
  //     final bool hasProduceTag = tags.any((t) {
  //       final slug = (t["slug"] ?? "").toString().toLowerCase();
  //       final name = (t["name"] ?? "").toString().toLowerCase();
  //       return slug.contains("produce") || name.contains("produce");
  //     });
  //
  //     // ── Find selected category and its tax slug ───────────────
  //     final selectedCategory = _categoriesList.firstWhere(
  //           (cat) => (cat['name']?.toString() ?? "").trim() == _selectedCategoryName.trim(),
  //       orElse: () => _categoriesList.isNotEmpty ? _categoriesList.first : {},
  //     );
  //
  //     final int selectedCategoryId = int.tryParse(selectedCategory['id']?.toString() ?? '0') ?? 0;
  //     final double categoryTaxPercent = double.tryParse(
  //         selectedCategory['pos_tax_percent']?.toString() ?? '0') ?? 0.0;
  //
  //     final String posTaxClass = selectedCategory['pos_tax_class']?.toString() ?? "standard";
  //     final String posTaxPercent = selectedCategory['pos_tax_percent']?.toString() ?? "0";
  //
  //     String taxSlug = selectedCategory['pos_tax_slug']?.toString() ?? '';
  //     if (taxSlug.isEmpty) {
  //       final rawClass = selectedCategory['pos_tax_class']?.toString() ?? '';
  //       taxSlug = rawClass.toLowerCase().replaceAll(' ', '-');
  //     }
  //
  //     final bool isTaxable = categoryTaxPercent > 0 && taxSlug.isNotEmpty;
  //     final String taxStatus = isTaxable ? "taxable" : "none";
  //     final String taxClass = isTaxable ? taxSlug : "";
  //
  //     // ── Duplicate check using stored `selected_category_id` ──
  //     bool alreadyExists = false;
  //     for (int i = 0; i < products.length; i++) {
  //       final existing = products[i];
  //       final int existingProductId = int.tryParse(existing['product_id']?.toString() ?? '0') ?? 0;
  //       final int existingSelectedCategoryId = int.tryParse(
  //           existing['selected_category_id']?.toString() ?? '0') ?? 0;
  //
  //       if (existingProductId == selectedProductId && existingSelectedCategoryId == selectedCategoryId) {
  //         alreadyExists = true;
  //         print("❌ DUPLICATE DETECTED → Same Product + Same Selected Category");
  //         break;
  //       }
  //     }
  //
  //     if (alreadyExists) {
  //       setState(() {
  //         _isCustomItemLoading = false;
  //         _customItemPrice = "0.00";
  //         _customItemPriceController.text = "${TextConstants.currencySymbol}0.00";
  //         _isEnteringItemPrice = false;
  //         _selectedCategoryName = "Select Category";
  //       });
  //
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("This item is already added. Create a new order to add it again."),
  //           backgroundColor: Colors.orange,
  //           duration: Duration(seconds: 1),
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // ── DETERMINE FINAL PRICE (WEIGHTED VS REGULAR) ──────────
  //     double finalPrice = price; // Default to entered price
  //     double weightQty = 0.0;
  //     String itemType = "custom";
  //
  //     if (hasProduceTag) {
  //       // For produce items, we need to use weight
  //       try {
  //         final weightProvider = Provider.of<WeightProvider>(context, listen: false);
  //
  //         // Parse current weight from display text (weight is in lbs from scale)
  //         double liveWeightLbs = 0.0;
  //         try {
  //           final parts = weightProvider.weightText.trim().split(' ');
  //           if (parts.isNotEmpty) {
  //             liveWeightLbs = double.tryParse(parts[0]) ?? 0.0;
  //           }
  //         } catch (_) {}
  //
  //         print('🟢 Live Weight (lbs): $liveWeightLbs for produce item');
  //
  //         if (liveWeightLbs > 0) {
  //           // finalPrice = unit price × weight
  //           finalPrice = price * liveWeightLbs;
  //           weightQty = liveWeightLbs;
  //           itemType = "weighted";
  //           print('🟢 Unit Price: $price | Weight: $liveWeightLbs lbs | Final Price: $finalPrice');
  //         } else {
  //           // If no weight available, use regular price
  //           print('⚠️ No weight available for produce item, using regular price');
  //           weightQty = 0.0;
  //           itemType = "custom";
  //         }
  //       } catch (e) {
  //         print('⚠️ Error getting weight for produce item: $e');
  //         weightQty = 0.0;
  //         itemType = "custom";
  //       }
  //     }
  //
  //     // ── Build item ─────────────────────────────────────────────
  //     final categories = selectedItem['categories'] is List ? selectedItem['categories'] : [];
  //
  //     final normalizedSku = _skuController.text.trim().isNotEmpty
  //         ? normalizeSku(_skuController.text)
  //         : "C-${DateTime.now().millisecondsSinceEpoch}";
  //
  //     final String displayName = "$_selectedCategoryName - $baseItemName";
  //
  //     final customItem = {
  //       "server_item_id": selectedProductId,
  //       "product_id": selectedProductId,
  //       "variation_id": 0,
  //       "type": selectedItem['type']?.toString() ?? "simple",
  //       "name": displayName,
  //       "price": finalPrice,  // Unit price
  //       "sku": normalizedSku,
  //       "categories": categories,
  //       "tags": tags,  // ← Store the FULL tags list
  //       "has_produce_tag": hasProduceTag,  // ← Store the flag
  //       "selected_category_id": selectedCategoryId,
  //       "selected_category_name": _selectedCategoryName,
  //       "selected_category_tax_slug": taxSlug,
  //       "pos_tax_class": posTaxClass,
  //       "pos_tax_percent": posTaxPercent,
  //       "tax_status": taxStatus,
  //       "tax_class": taxClass,
  //       "tax_rate": categoryTaxPercent,
  //       "tax_percent": categoryTaxPercent,
  //       "applied_tax": "$_selectedCategoryName Tax",
  //       "quantity": 1,
  //       "item_image": "assets/custom.png",
  //       "product_image": "assets/custom.png",
  //       AppDBConst.itemType: itemType,  // ← "custom" or "weighted"
  //       AppDBConst.itemName: displayName,
  //       AppDBConst.itemPrice: finalPrice,  // ← Final price (total)
  //       AppDBConst.itemSumPrice: finalPrice,
  //       AppDBConst.itemCount: 1,
  //     };
  //
  //     // Add weight-specific fields if it's a weighted item
  //     if (itemType == "weighted") {
  //       customItem["weight_qty"] = weightQty;
  //       customItem["unit_price"] = price;  // Store unit price separately
  //       customItem["sales_price"] = finalPrice;
  //       customItem["regular_price"] = price;
  //     }
  //
  //     products.add(customItem);
  //
  //     // ── Recalculate totals ───────────────────────────────────
  //     double grossTotal = 0.0;
  //     for (var p in products) {
  //       final itemPrice = (p[AppDBConst.itemPrice] ?? p["sales_price"] ?? p["price"] ?? 0.0) as num;
  //       final qty = (p["quantity"] ?? 1) as num;
  //       grossTotal += itemPrice * qty;
  //     }
  //
  //     orderData["products"] = products;
  //     orderData["gross_total"] = grossTotal;
  //     orderData["net_total"] = grossTotal;
  //     orderData["net_payable"] = grossTotal;
  //
  //     await box.put(key, orderData);
  //     await StorageProvider.productCache.put("sku_$normalizedSku", {"products": [customItem]});
  //
  //     // ── Reset UI ─────────────────────────────────────────────
  //     setState(() {
  //       _isCustomItemLoading = false;
  //       _customItemPrice = "0.00";
  //       _customItemPriceController.clear();
  //       _skuController.clear();
  //       _isEnteringItemPrice = false;
  //       _selectedCategoryName = "Select Category";
  //     });
  //
  //     // Clear weight if it was a produce item
  //     if (hasProduceTag) {
  //       try {
  //         final weightProvider = Provider.of<WeightProvider>(context, listen: false);
  //         weightProvider.updateWeight(0.0);
  //       } catch (_) {}
  //     }
  //
  //     await _orderHelper.loadData();
  //     await _loadOrderData();
  //     OrderHelper.notifyOrderPanelToRefresh();
  //     widget.refreshOrderList?.call();
  //
  //     print("✅ SUCCESS: Added → $displayName | Has Produce Tag: $hasProduceTag | Item Type: $itemType | Final Price: $finalPrice");
  //
  //     // Show success message with details
  //     if (itemType == "weighted") {
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         SnackBar(
  //           content: Text("$displayName added (${weightQty.toStringAsFixed(2)} lbs @ ${TextConstants.currencySymbol}${price.toStringAsFixed(2)}/lb)"),
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     } else {
  //       // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       //   SnackBar(
  //       //     content: Text("$displayName added successfully!"),
  //       //     backgroundColor: Colors.green,
  //       //     duration: const Duration(seconds: 1),
  //       //   ),
  //       // );
  //     }
  //
  //   } catch (e, stack) {
  //     print("❌ Custom Item Error: $e");
  //     print("Stack: $stack");
  //     setState(() => _isCustomItemLoading = false);
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       SnackBar(
  //         content: Text("Error adding custom item: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  /////// working weighing items


  // Future<void> _handleAddCustomItem() async {
  //   if (kDebugMode) print("🟢 [CUSTOM ITEM] START");
  //
  //   // ── VALIDATION FIRST ─────────────────
  //   final String enteredName = _customItemNameController.text.trim();
  //
  //   if (enteredName.isEmpty) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please enter item name"),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   if (_selectedCategoryName.trim() == "Select Category" ||
  //       _selectedCategoryName.trim().isEmpty ||
  //       !_categoriesList.any((cat) =>
  //       cat['name']?.toString().trim() == _selectedCategoryName.trim())) {
  //
  //     setState(() {
  //       _customItemPrice = "0.00";
  //       _customItemPriceController.text = "${TextConstants.currencySymbol}0.00";
  //       _isEnteringItemPrice = false;
  //     });
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please select a category before adding"),
  //         backgroundColor: Colors.orange,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   final orderHelper = OrderHelper();
  //   final int? ensuredOrderId = await orderHelper.ensureOrderExists();
  //
  //   if (ensuredOrderId == null) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(content: Text("Failed to create order"), backgroundColor: Colors.red),
  //     );
  //     return;
  //   }
  //
  //   // ── Price Validation ────────────────────────────────────────
  //   final cleanedPrice = _customItemPrice.replaceAll(RegExp(r'[^0-9.]'), '');
  //   final double? price = double.tryParse(cleanedPrice);
  //   if (price == null || price <= 0) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(content: Text("Please enter valid price"), backgroundColor: Colors.red),
  //     );
  //     return;
  //   }
  //
  //   setState(() => _isCustomItemLoading = true);
  //
  //   try {
  //     final box = StorageProvider.offlineOrders;
  //     final key = ensuredOrderId.toString();
  //     final rawOrder = await box.get(key) ?? {};
  //     final orderData = Map<String, dynamic>.from(rawOrder);
  //
  //     List<dynamic> products = (orderData["products"] ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     // ── Use the name user actually typed ─────────────────────
  //     final String baseItemName = enteredName;
  //     final int selectedProductId = _customItemsList.isNotEmpty
  //         ? (_customItemsList.first['id'] ?? 60303)
  //         : 60303;
  //
  //     // ── Find selected category ───────────────────────────────
  //     final selectedCategory = _categoriesList.firstWhere(
  //           (cat) => (cat['name']?.toString() ?? "").trim() == _selectedCategoryName.trim(),
  //       orElse: () => _categoriesList.isNotEmpty ? _categoriesList.first : {},
  //     );
  //
  //     final int selectedCategoryId = int.tryParse(selectedCategory['id']?.toString() ?? '0') ?? 0;
  //     final double categoryTaxPercent = double.tryParse(
  //         selectedCategory['pos_tax_percent']?.toString() ?? '0') ?? 0.0;
  //
  //     final String posTaxClass = selectedCategory['pos_tax_class']?.toString() ?? "standard";
  //     final String posTaxPercent = selectedCategory['pos_tax_percent']?.toString() ?? "0";
  //
  //     String taxSlug = selectedCategory['pos_tax_slug']?.toString() ?? '';
  //     if (taxSlug.isEmpty) {
  //       final rawClass = selectedCategory['pos_tax_class']?.toString() ?? '';
  //       taxSlug = rawClass.toLowerCase().replaceAll(' ', '-');
  //     }
  //
  //     final bool isTaxable = categoryTaxPercent > 0 && taxSlug.isNotEmpty;
  //     final String taxStatus = isTaxable ? "taxable" : "none";
  //     final String taxClass = isTaxable ? taxSlug : "";
  //
  //     // ── Build item using manual name ─────────────────────────
  //     final normalizedSku = _skuController.text.trim().isNotEmpty
  //         ? normalizeSku(_skuController.text)
  //         : "C-${DateTime.now().millisecondsSinceEpoch}";
  //
  //     final String displayName = "$_selectedCategoryName - $baseItemName";
  //
  //     final customItem = {
  //       "server_item_id": selectedProductId,
  //       "product_id": selectedProductId,
  //       "variation_id": 0,
  //       "type": "simple",
  //       "name": displayName,
  //       "price": price,
  //       "sku": normalizedSku,
  //       "categories": [],
  //       "tags": [],
  //       "selected_category_id": selectedCategoryId,
  //       "selected_category_name": _selectedCategoryName,
  //       "selected_category_tax_slug": taxSlug,
  //       "pos_tax_class": posTaxClass,
  //       "pos_tax_percent": posTaxPercent,
  //       "tax_status": taxStatus,
  //       "tax_class": taxClass,
  //       "tax_rate": categoryTaxPercent,
  //       "tax_percent": categoryTaxPercent,
  //       "applied_tax": "$_selectedCategoryName Tax",
  //       "quantity": 1,
  //       "item_image": "assets/custom.png",
  //       "product_image": "assets/custom.png",
  //       AppDBConst.itemType: "custom",
  //       AppDBConst.itemName: displayName,
  //       AppDBConst.itemPrice: price,
  //       AppDBConst.itemSumPrice: price,
  //       AppDBConst.itemCount: 1,
  //     };
  //
  //     products.add(customItem);
  //
  //     // Recalculate totals
  //     double grossTotal = 0.0;
  //     for (var p in products) {
  //       final itemPrice = (p[AppDBConst.itemPrice] ?? p["price"] ?? 0.0) as num;
  //       final qty = (p["quantity"] ?? 1) as num;
  //       grossTotal += itemPrice * qty;
  //     }
  //
  //     orderData["products"] = products;
  //     orderData["gross_total"] = grossTotal;
  //     orderData["net_total"] = grossTotal;
  //     orderData["net_payable"] = grossTotal;
  //
  //     await box.put(key, orderData);
  //     await StorageProvider.productCache.put("sku_$normalizedSku", {"products": [customItem]});
  //     await _pushCfdAfterAppsChange(ensuredOrderId);
  //     // safety re-push after panel has a moment to load Hive
  //     await Future.delayed(const Duration(milliseconds: 150));
  //     await _pushCfdAfterAppsChange(ensuredOrderId);
  //     // ── Reset UI after success ───────────────────────────────
  //     setState(() {
  //       _isCustomItemLoading = false;
  //       _customItemPrice = "0.00";
  //       _customItemPriceController.text = "${TextConstants.currencySymbol}0.00";
  //       _customItemNameController.clear();   // ← Clear Name
  //       _skuController.clear();              // ← Clear SKU
  //       _isEnteringItemPrice = false;
  //       _selectedCategoryName = "Select Category";
  //     });
  //
  //     await _orderHelper.loadData();
  //     await _loadOrderData();
  //     OrderHelper.notifyOrderPanelToRefresh();
  //     widget.refreshOrderList?.call();
  //
  //     print("✅ SUCCESS: Added → $displayName");
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       SnackBar(
  //         content: Text("$displayName added successfully!"),
  //         backgroundColor: Colors.green,
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //
  //   } catch (e, stack) {
  //     print("❌ Custom Item Error: $e");
  //     print("Stack: $stack");
  //     setState(() => _isCustomItemLoading = false);
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       SnackBar(
  //         content: Text("Error adding custom item: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }
  Future<void> _handleAddCustomItem() async {
    if (kDebugMode) print("🟢 [CUSTOM ITEM] START");

    // ── VALIDATION FIRST ─────────────────
    final String enteredName = _customItemNameController.text.trim();

    if (enteredName.isEmpty) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter item name"),
>>>>>>> origin/Grocery_pch_api_integration
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
<<<<<<< HEAD
    if (_customItemPrice.isEmpty || double.tryParse(_customItemPrice) == null || double.parse(_customItemPrice) == 0) {
      if (kDebugMode) print("Invalid custom item price: $_customItemPrice");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.invalidPriceError), // Build #1.0.181: Added through TextConstants
          backgroundColor: Colors.red,
=======

    if (_selectedCategoryName.trim() == "Select Category" ||
        _selectedCategoryName.trim().isEmpty ||
        !_categoriesList.any((cat) =>
        cat['name']?.toString().trim() == _selectedCategoryName.trim())) {
      setState(() {
        _customItemPrice = "0.00";
        _customItemPriceController.text =
        "${TextConstants.currencySymbol}0.00";
        _isEnteringItemPrice = false;
      });

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Please select a category before adding"),
          backgroundColor: Colors.orange,
>>>>>>> origin/Grocery_pch_api_integration
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
<<<<<<< HEAD
    /// COMMENT BELOW CODE -> If User want to create custom item without tax selection
    if (_selectedTaxSlab.isEmpty) {
      if (kDebugMode) print("No tax slab selected");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.taxSlabRequired), // Build #1.0.181: Added through TextConstants
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
=======

    final orderHelper = OrderHelper();
    final int? ensuredOrderId = await orderHelper.ensureOrderExists();

    if (ensuredOrderId == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Failed to create order"),
          backgroundColor: Colors.red,
>>>>>>> origin/Grocery_pch_api_integration
        ),
      );
      return;
    }
<<<<<<< HEAD
    if (_sku.isEmpty) {
      if (kDebugMode) print("SKU is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.skuRequired), // Build #1.0.181: Added through TextConstants
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
=======

    // ── Price Validation ────────────────────────────────────────
    final cleanedPrice = _customItemPrice.replaceAll(RegExp(r'[^0-9.]'), '');
    final double? price = double.tryParse(cleanedPrice);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid price"),
          backgroundColor: Colors.red,
>>>>>>> origin/Grocery_pch_api_integration
        ),
      );
      return;
    }
<<<<<<< HEAD
    /// Build #1.0.128: No need to check this condition here
    // if (orderId == null) {
    //   if (kDebugMode) print("No active order selected");
    //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
    //     const SnackBar(
    //       content: Text("No active order selected"),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 2),
    //     ),
    //   );
    //   return;
    // }
=======
>>>>>>> origin/Grocery_pch_api_integration

    setState(() => _isCustomItemLoading = true);

    try {
<<<<<<< HEAD
      // final db = await DBHelper.instance.database;
      // final orderData = await db.query(
      //   AppDBConst.orderTable,
      //   where: '${AppDBConst.orderServerId} = ?',
      //   whereArgs: [orderId],
      // );

      // if (orderData.isEmpty) {
      //   if (kDebugMode) print("Order $orderId not found in database");
      //   setState(() => _isCustomItemLoading = false);
      //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //     const SnackBar(
      //       content: Text(TextConstants.orderNotFoundError),
      //       backgroundColor: Colors.red,
      //       duration: Duration(seconds: 2),
      //     ),
      //   );
      //   return;
      // }

    //  final serverOrderId = orderData.first[AppDBConst.orderServerId] as int?;
      final serverOrderId = OrderHelper().activeOrderId;
      //Build #1.0.78: Check for existing item with same SKU
      // final existingItems = await db.query(
      //   AppDBConst.purchasedItemsTable,
      //   where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemSKU} = ?',
      //   whereArgs: [orderId, _sku],
      // );
      //
      // ///Todo: do we neeed this condition to check?
      /// Build #1.0.128: We don't need this, why because - after api call we are clearing sku value, user cant add custom item with same sku
      // if (existingItems.isNotEmpty) {
      //   if (kDebugMode) print("Item with SKU $_sku already exists in order $orderId");
      //   setState(() => _isCustomItemLoading = false);
      //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //     const SnackBar(
      //       content: Text("Item with this SKU already added to the order"),
      //       backgroundColor: Colors.orange,
      //       duration: Duration(seconds: 2),
      //     ),
      //   );
      //   return;
      // }

      // if (serverOrderId == null) {  /// Build #1.0.128: No need to check this condition here
      //   /// For non-API orders, insert locally
      //   // await db.insert(AppDBConst.purchasedItemsTable, {
      //   //   AppDBConst.orderIdForeignKey: orderId!,
      //   //   AppDBConst.itemName: _customItemName,
      //   //   AppDBConst.itemSKU: _sku,
      //   //   AppDBConst.itemPrice: double.parse(_customItemPrice),
      //   //   AppDBConst.itemCount: 1,
      //   //   AppDBConst.itemSumPrice: double.parse(_customItemPrice),
      //   //   AppDBConst.itemImage: 'assets/svg/custom_item.svg',
      //   //   AppDBConst.itemType: ItemType.customProduct.value,
      //   // });
      //   // final items = await _orderHelper.getOrderItems(orderId!);
      //   // final orderTotal = items.fold(0.0, (sum, item) => sum + (item[AppDBConst.itemSumPrice] as num).toDouble());
      //   // await db.update(
      //   //   AppDBConst.orderTable,
      //   //   {AppDBConst.orderTotal: orderTotal},
      //   //   where: '${AppDBConst.orderServerId} = ?',
      //   //   whereArgs: [orderId],
      //   // );
      //   // setState(() {
      //   //   _customItemName = "";
      //   //   _customItemPrice = "";
      //   //   _sku = "";
      //   //   _selectedTaxSlab = _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first : "";
      //   //   _customItemNameController.clear();
      //   //   _customItemPriceController.clear();
      //   //   _skuController.clear();
      //   //   _isCustomItemLoading = false;
      //   // });
      //   // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //   //   SnackBar(
      //   //     content: Text("Custom item '$_customItemName' added at \$$_customItemPrice"),
      //   //     backgroundColor: Colors.green,
      //   //     duration: const Duration(seconds: 2),
      //   //   ),
      //   // );
      //   // await _orderHelper.loadData();
      //   // await _loadOrderData();
      //   // widget.refreshOrderList?.call();
      //   ///Show error instead adding to local DB and return
      //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //     SnackBar(
      //       content: Text("Custom item '$_customItemName' did not add to Order, as of Order id is not found."),
      //       backgroundColor: Colors.orange,
      //       duration: const Duration(seconds: 2),
      //     ),
      //   );
      //   return;
      // }

      // API-first approach
      List<Tax> taxes = await _assetDBHelper.getTaxList();
      String taxStatus = "";
      String taxClass = "";
      if (_selectedTaxSlab.isNotEmpty) {
        Tax? selectedTax = taxes.firstWhere(
              (tax) => tax.name == _selectedTaxSlab,
          orElse: () => taxes.isNotEmpty ? taxes.first : Tax(slug: 'none', name: _selectedTaxSlab), //Build #1.0.92
        );
        if (kDebugMode) print("selectedTax name: ${selectedTax.name}, ## slug: ${selectedTax.slug}");
        if (selectedTax.slug.isNotEmpty) {
          taxStatus = TextConstants.taxable;
          taxClass = selectedTax.slug;
        }
      }

      model.AddCustomItemRequest request = model.AddCustomItemRequest(
        name: _customItemName,
        type: TextConstants.simple,
        regularPrice: _customItemPrice,
        sku: _sku,
        taxStatus: taxStatus,
        taxClass: taxClass,
        tags: [model.Tag(name: TextConstants.customItem)],
      );

      final completer = Completer<void>();
      StreamSubscription? createSubscription;
      StreamSubscription? updateSubscription;

      createSubscription = productBloc.addCustomItemStream.listen((response) async {
        if (!mounted) {
          createSubscription?.cancel();
          completer.complete();
          return;
        }
        if (response.status == Status.COMPLETED) {
          if (kDebugMode) print("Custom item created successfully: ${response.data?.id}");

          updateSubscription = orderBloc.updateOrderStream.listen((updateResponse) async {
            if (!mounted) {
              updateSubscription?.cancel();
              createSubscription?.cancel();
              completer.complete();
              return;
            }

            if (response.status == Status.LOADING) { // Build #1.0.80
              const Center(child: CircularProgressIndicator());
            }else if (updateResponse.status == Status.COMPLETED) {
              setState(() => _isCustomItemLoading = false);
              if (kDebugMode) print("Order updated successfully for order $orderId");
              setState(() {
                _customItemName = "";
                _customItemPrice = "";
                _sku = "";
                _selectedTaxSlab = _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first : "";
                _customItemNameController.clear();
                _customItemPriceController.clear();
                _skuController.clear();
              });
              ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
                SnackBar(
                  content: Text("Custom item '$_customItemName' added at ${TextConstants.currencySymbol}$_customItemPrice"),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              await _orderHelper.loadData();
              await _loadOrderData();
              widget.refreshOrderList?.call();
              updateSubscription?.cancel();
              createSubscription?.cancel();
              completer.complete();
            } else if (updateResponse.status == Status.ERROR) {
              if (kDebugMode) print("Failed to update order: ${updateResponse.message}");
              ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
                SnackBar(
                  content: Text(response.message ?? "Failed to update order"), //Build #1.0.92
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );

              updateSubscription?.cancel();
              createSubscription?.cancel();
              completer.complete();
            }
          });

          await orderBloc.updateOrderProducts(
            orderId: serverOrderId,
            dbOrderId: orderId,  // Build #1.0.128
            lineItems: [
              OrderLineItem(
                productId: response.data!.id,
                quantity: 1,
               // sku: _sku,
              ),
            ],
          );
        } else if (response.status == Status.ERROR) {
          if (kDebugMode) print("Failed to create custom item: ${response.message}");
          setState(() => _isCustomItemLoading = false);
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text("Failed to add custom item"), //Build #1.0.92
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );

          createSubscription?.cancel();
          completer.complete();
        }
      });

      await productBloc.addCustomItem(request);
      await completer.future;
    } catch (e) {
      if (kDebugMode) print("Exception in _handleAddCustomItem: $e");
      setState(() => _isCustomItemLoading = false);
=======
      final box = StorageProvider.offlineOrders;
      final key = ensuredOrderId.toString();
      final rawOrder = await box.get(key) ?? {};
      final orderData = Map<String, dynamic>.from(rawOrder);

      List<dynamic> products = (orderData["products"] ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ── Use the name user actually typed ─────────────────────
      final String baseItemName = enteredName;
      final int selectedProductId = _customItemsList.isNotEmpty
          ? (_customItemsList.first['id'] ?? 60303)
          : 60303;

      // ── Find selected category ───────────────────────────────
      final selectedCategory = _categoriesList.firstWhere(
            (cat) =>
        (cat['name']?.toString() ?? "").trim() ==
            _selectedCategoryName.trim(),
        orElse: () =>
        _categoriesList.isNotEmpty ? _categoriesList.first : {},
      );

      final int selectedCategoryId =
          int.tryParse(selectedCategory['id']?.toString() ?? '0') ?? 0;
      final double categoryTaxPercent = double.tryParse(
          selectedCategory['pos_tax_percent']?.toString() ?? '0') ??
          0.0;

      final String posTaxClass =
          selectedCategory['pos_tax_class']?.toString() ?? "standard";
      final String posTaxPercent =
          selectedCategory['pos_tax_percent']?.toString() ?? "0";

      String taxSlug = selectedCategory['pos_tax_slug']?.toString() ?? '';
      if (taxSlug.isEmpty) {
        final rawClass =
            selectedCategory['pos_tax_class']?.toString() ?? '';
        taxSlug = rawClass.toLowerCase().replaceAll(' ', '-');
      }

      final bool isTaxable = categoryTaxPercent > 0 && taxSlug.isNotEmpty;
      final String taxStatus = isTaxable ? "taxable" : "none";
      final String taxClass = isTaxable ? taxSlug : "";

      // ── Build item using manual name ─────────────────────────
      final normalizedSku = _skuController.text.trim().isNotEmpty
          ? normalizeSku(_skuController.text)
          : "C-${DateTime.now().millisecondsSinceEpoch}";

      final String displayName = "$_selectedCategoryName - $baseItemName";

      final customItem = {
        "server_item_id": selectedProductId,
        "product_id": selectedProductId,
        "variation_id": 0,
        "type": "simple",
        "name": displayName,
        "price": price,
        "sku": normalizedSku,
        "categories": [],
        "tags": [],
        "selected_category_id": selectedCategoryId,
        "selected_category_name": _selectedCategoryName,
        "selected_category_tax_slug": taxSlug,
        "pos_tax_class": posTaxClass,
        "pos_tax_percent": posTaxPercent,
        "tax_status": taxStatus,
        "tax_class": taxClass,
        "tax_rate": categoryTaxPercent,
        "tax_percent": categoryTaxPercent,
        "applied_tax": "$_selectedCategoryName Tax",
        "quantity": 1,
        "item_image": "assets/custom.png",
        "product_image": "assets/custom.png",
        AppDBConst.itemType: "custom",
        AppDBConst.itemName: displayName,
        AppDBConst.itemPrice: price,
        AppDBConst.itemSumPrice: price,
        AppDBConst.itemCount: 1,
      };

      products.add(customItem);

      // Recalculate totals
      double grossTotal = 0.0;
      for (var p in products) {
        final itemPrice =
        (p[AppDBConst.itemPrice] ?? p["price"] ?? 0.0) as num;
        final qty = (p["quantity"] ?? 1) as num;
        grossTotal += itemPrice * qty;
      }

      orderData["products"] = products;
      orderData["gross_total"] = grossTotal;
      orderData["net_total"] = grossTotal;
      orderData["net_payable"] = grossTotal;

      await box.put(key, orderData);
      await StorageProvider.productCache
          .put("sku_$normalizedSku", {"products": [customItem]});

      // Sync POS panel first so Hive + active order are ready for CFD
      await _orderHelper.loadData();
      await _loadOrderData();
      OrderHelper.notifyOrderPanelToRefresh();
      widget.refreshOrderList?.call();

      // Clear any stale skip so native CFD accepts this update
      try {
        CustomerDisplayHelper.skipNextPendingOrderRefresh = false;
      } catch (_) {}

      await _pushCfdAfterAppsChange(ensuredOrderId);


      // ── Reset UI after success ───────────────────────────────
      setState(() {
        _isCustomItemLoading = false;
        _customItemPrice = "0.00";
        _customItemPriceController.text =
        "${TextConstants.currencySymbol}0.00";
        _customItemNameController.clear(); // ← Clear Name
        _skuController.clear(); // ← Clear SKU
        _isEnteringItemPrice = false;
        _selectedCategoryName = "Select Category";
      });

      print("✅ SUCCESS: Added → $displayName");

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("$displayName added successfully!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      print("❌ Custom Item Error: $e");
      print("Stack: $stack");
      setState(() => _isCustomItemLoading = false);

>>>>>>> origin/Grocery_pch_api_integration
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error adding custom item: $e"),
          backgroundColor: Colors.red,
<<<<<<< HEAD
          duration: const Duration(seconds: 2),
=======
>>>>>>> origin/Grocery_pch_api_integration
        ),
      );
    }
  }
<<<<<<< HEAD

  // Handle adding the payout
  //Build #1.0.78: Explanation!
  // Moved payout insertion to OrderBloc.addPayout.
  // Added dbOrderId parameter to addPayout.
  // Kept local insertion for non-API orders.
  // Added alert dialog with retry option for API failures.
  // Ensured _isPayoutLoading is shown during API calls.
  // Preserved success toast and UI refresh logic.
  void _handleAddPayout() async {
    if (_payoutAmount.isEmpty || _payoutAmount == "0" || double.tryParse(_payoutAmount) == null) {
      if (kDebugMode) print("Invalid payout amount: $_payoutAmount");
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.invalidPayoutError), // Build #1.0.181: Added through TextConstants
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
=======
  ///  Converts any deeply nested Map/List from Hive into JSON-safe Map<String, dynamic>
  dynamic _convertToJsonSafe(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      // Convert
      return value.map((k, v) => MapEntry(k.toString(), _convertToJsonSafe(v)));
    } else if (value is List) {
      return value.map(_convertToJsonSafe).toList();
    } else {
      return value;
    }
  }

  Future<Map<String, dynamic>?> _getPayoutProductFromIsar() async {
    // FAST PATH
    if (_productMetaInitialized && _productMetaCache.isNotEmpty) {
      for (final p in _productMetaCache.values) {
        final name = (p["fast_key_item_name"] ?? p["name"] ?? "")
            .toString()
            .toLowerCase();

        if (name.contains("payout")) {
          return p;
        }
      }
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
          final name = (map["fast_key_item_name"] ?? map["name"] ?? "")
              .toString()
              .toLowerCase();

          if (name.contains("payout")) {
            final pid = int.tryParse(
                (map["fast_key_product_id"] ?? map["id"])?.toString() ?? "");

            if (pid != null) {
              _productMetaCache[pid] = map;
              _productMetaInitialized = true;
            }
            return map;
          }
        }
      }
    } catch (e) {
      debugPrint("Payout Isar lookup failed → $e");
    }

    return null;
  }


  //Build #1.0.78: Explanation

  void _handleAddPayout() async {
    print("🟦 [PAYOUT] START ---- _handleAddPayout() ----");

    if (_payoutAmount.isEmpty ||
        _payoutAmount == "0.00" ||
        double.tryParse(_payoutAmount) == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Invalid payout amount"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
>>>>>>> origin/Grocery_pch_api_integration
      return;
    }

    setState(() => _isPayoutLoading = true);
<<<<<<< HEAD
   ///  Build #1.0.219 -> FIXED ISSUE [SCRUM - 377] : Unable to Add Payouts When No Orders Exist
    ///  Adding payout -> if no order exit, creating new order then adding or else adding into existing order
    try {
      // Check if we have an active order, if not create one first
      int? orderId = OrderHelper().activeOrderId;
      int? serverOrderId;

      if (orderId == null) {
        // No active order exists, create a new order
        OrderBloc orderBloc = OrderBloc(OrderRepository());
        StreamSubscription? createSubscription;

        // Listen for order creation completion
        final completer = Completer<void>();
        createSubscription = orderBloc.createOrderStream.listen((response) async {
          if (!mounted) {
            createSubscription?.cancel();
            completer.complete();
            return;
          }

          if (response.status == Status.COMPLETED) {
            // Order created successfully, now proceed with adding payout
            orderId = OrderHelper().activeOrderId;
            serverOrderId = response.data!.id;

            // Fetch the order data to get serverOrderId
            final db = await DBHelper.instance.database;
            final orderData = await db.query(
              AppDBConst.orderTable,
              where: '${AppDBConst.orderServerId} = ?',
              whereArgs: [orderId],
            );

            if (orderData.isNotEmpty) {
              serverOrderId = orderData.first[AppDBConst.orderServerId] as int?;
            }

            completer.complete();
          } else if (response.status == Status.ERROR) {
            setState(() => _isPayoutLoading = false);
            ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
              SnackBar(
                content: Text("Failed to create order: ${response.message}"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
            completer.complete();
          }
        });

        // Create the order
        await orderBloc.createOrder();
        await completer.future;
        createSubscription?.cancel();
      } else {
        // Existing order found, get serverOrderId
        final db = await DBHelper.instance.database;
        final orderData = await db.query(
          AppDBConst.orderTable,
          where: '${AppDBConst.orderServerId} = ?',
          whereArgs: [orderId],
        );

        if (orderData.isNotEmpty) {
          serverOrderId = orderData.first[AppDBConst.orderServerId] as int?;
        }
      }

      // If we still don't have a valid orderId/serverOrderId, show error
      if (orderId == null || serverOrderId == null) {
        setState(() => _isPayoutLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.orderNotFoundError), // Build #1.0.181: Added through TextConstants
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
=======

    try {
      final offlineBox = StorageProvider.offlineOrders;
      final productBox = StorageProvider.productCache;
      final payoutAmount = double.parse(_payoutAmount);

      final orderHelper = OrderHelper();

      final int? ensuredOrderId = await orderHelper.ensureOrderExists();

      if (ensuredOrderId == null) {
        setState(() => _isPayoutLoading = false);

        final msg = OrderHelper.lastEnsureOrderError ??
            "Unable to create order. Please try again.";
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
>>>>>>> origin/Grocery_pch_api_integration
          ),
        );
        return;
      }

<<<<<<< HEAD
      double payoutAmount = double.parse(_payoutAmount);

      //Build #1.0.78: FIX - Check for existing payout for the order
      // DON'T ADD PAYOUT SAME ORDER IF ALREADY HAVE IT
      final db = await DBHelper.instance.database;
      final existingPayouts = await db.query(
        AppDBConst.purchasedItemsTable,
        where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst.itemType} = ?',
        whereArgs: [orderId, ItemType.payout.value],
      );

      if (existingPayouts.isNotEmpty) {
        if (kDebugMode) print("Payout already exists for order $orderId");
        setState(() => _isPayoutLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.payoutAlreadyAdded), // Build #1.0.181: Added through TextConstants
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
=======
      if (kDebugMode) {
        print("🆔 [PAYOUT] Active Order ID (ensured): $ensuredOrderId");
      }
      final int orderId = ensuredOrderId;
      orderHelper.activeOrderId = orderId;

      final key = orderId.toString();
      final rawExisting = await offlineBox.get(key);
      final existingOrder =
      Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});

      final payouts = (existingOrder["payouts"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (payouts.isNotEmpty) {
        setState(() => _isPayoutLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("A payout already exists for this order."),
            backgroundColor: Colors.orange,
>>>>>>> origin/Grocery_pch_api_integration
          ),
        );
        return;
      }
<<<<<<< HEAD

      // API-first approach
      StreamSubscription? subscription;

      subscription = orderBloc.addPayoutStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.COMPLETED) {
          if (kDebugMode) print("Payout added via API for order $orderId");
          setState(() {
            _payoutAmount = "";
            _isPayoutLoading = false; //Build #1.0.92: loader issue fixed
          });
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text("Payout of ${TextConstants.currencySymbol}$payoutAmount added successfully"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          await _orderHelper.loadData();
          await _loadOrderData();
          widget.refreshOrderList?.call();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (kDebugMode) print("Failed to add payout: ${response.message}");
          setState(() {_isPayoutLoading = false;}); // Build #1.0.181: Fixed loader not stopping issue
          ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text("Failed to add payout"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );

          subscription?.cancel();
        }
      });

      await orderBloc.addPayoutAsProduct(orderId: serverOrderId!, dbOrderId: orderId!, amount: payoutAmount, isPayOut: true);

    } catch (e) {
      if (kDebugMode) print("Error processing payout: $e");
=======
      Map<String, dynamic>? payoutProduct = await _getPayoutProductFromIsar();

// Fallback only if not found in catalog
      payoutProduct ??= {
        "fast_key_product_id": DateTime.now().millisecondsSinceEpoch,
        "fast_key_item_name": "Payout",
        "fast_key_item_price": 0,
        "fast_key_item_image":
        "https://merchantretail.alektasolutions.com/wp-content/uploads/2025/11/payout-2-1.png",
        "type": "simple",
      };

      print("🟢 FOUND PAYOUT PRODUCT → $payoutProduct");
      final payoutEntry = {
        "order_id": orderId,
        "payout_product_id": payoutProduct["fast_key_product_id"],
        "product_name": payoutProduct["fast_key_item_name"],
        "product_image": payoutProduct["fast_key_item_image"],
        "amount": -payoutAmount,
        "type": "payout",
        "timestamp": DateTime.now().toIso8601String(),
      };

      payouts.add(payoutEntry);

      final products = (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      double total = 0.0;
      for (var p in products) {
        total += (p["price"] ?? 0) * (p["quantity"] ?? 1);
      }

      final double newGross = total + (-payoutAmount);

      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "payouts": payouts,
        "gross_total": newGross,
        "net_total": newGross,
        "net_payable": newGross,
      };

      await offlineBox.put(key, updatedOrder);

      // Sync POS panel first so Hive + active order are ready for CFD
      await _orderHelper.loadData();
      await _loadOrderData();
      OrderHelper.notifyOrderPanelToRefresh();
      widget.refreshOrderList?.call();

      // Clear any stale skip so native CFD accepts this update
      try {
        CustomerDisplayHelper.skipNextPendingOrderRefresh = false;
      } catch (_) {}

      // Open cash drawer through connected thermal printer
      try {
        await PrinterSettings.openDrawer(
            context: widget.scaffoldMessengerContext);
      } catch (_) {}

      // Push CFD (native + MQTT) — works from IDLE
      await _pushCfdAfterAppsChange(orderId);

      // Second push after short delay so CFD catches post-panel refresh
      await Future.delayed(const Duration(milliseconds: 180));
      await _pushCfdAfterAppsChange(orderId);

      setState(() {
        _payoutAmount = "";
        _isPayoutLoading = false;
      });

      print("✅ [PAYOUT] DONE ---- _handleAddPayout() ----");
    } catch (e, s) {
      print("🟥 [PAYOUT] ERROR: $e\n$s");
>>>>>>> origin/Grocery_pch_api_integration
      setState(() => _isPayoutLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error adding payout: $e"),
          backgroundColor: Colors.red,
<<<<<<< HEAD
          duration: const Duration(seconds: 2),
=======
>>>>>>> origin/Grocery_pch_api_integration
        ),
      );
    }
  }
}

<<<<<<< HEAD
// Simple clipper for the tab side curves
=======

>>>>>>> origin/Grocery_pch_api_integration
class TabSideClipper extends CustomClipper<Path> {
  final int selectedIndex;

  TabSideClipper({required this.selectedIndex});

  @override
  Path getClip(Size size) {
    Path path = Path();
<<<<<<< HEAD
    double tabHeight = size.height / 4;
=======
    double tabHeight = size.height / 550;
>>>>>>> origin/Grocery_pch_api_integration
    double selectedTabTop = selectedIndex * tabHeight;
    double selectedTabBottom = selectedTabTop + tabHeight;
    double curveRadius = 16.0; // Your specified curve radius

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    // Top curve around selected tab
    if (selectedIndex > 0) {
      path.lineTo(size.width, selectedTabTop - curveRadius);
      // Smooth curve into the tab indent
      path.quadraticBezierTo(
<<<<<<< HEAD
          size.width, selectedTabTop,
          size.width - curveRadius, selectedTabTop
      );
=======
          size.width, selectedTabTop, size.width - curveRadius, selectedTabTop);
>>>>>>> origin/Grocery_pch_api_integration
      path.lineTo(size.width - curveRadius, selectedTabTop);
    } else {
      // If first tab is selected, start the indent from top
      path.lineTo(size.width - curveRadius, 0);
    }

    // Straight line along the tab indent
    path.lineTo(size.width - curveRadius, selectedTabBottom);

    // Bottom curve around selected tab
<<<<<<< HEAD
    if (selectedIndex < 3) {
      // Smooth curve out of the tab indent
      path.quadraticBezierTo(
          size.width, selectedTabBottom,
          size.width, selectedTabBottom + curveRadius
      );
=======
    if (selectedIndex < 4) {
      // Smooth curve out of the tab indent
      path.quadraticBezierTo(size.width, selectedTabBottom, size.width,
          selectedTabBottom + curveRadius);
>>>>>>> origin/Grocery_pch_api_integration
      path.lineTo(size.width, size.height);
    } else {
      // If last tab is selected, end the indent at bottom
      path.lineTo(size.width, size.height);
    }

    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class ContentSideClipper extends CustomClipper<Path> {
  final int selectedIndex;

  ContentSideClipper({required this.selectedIndex});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double tabHeight = size.height / 4;
    double selectedTabTop = selectedIndex * tabHeight;
    double selectedTabBottom = selectedTabTop + tabHeight;
    double cornerRadius = 16.0;
    double indentDepth = 16.0;

    // Start with rounded top-left corner
    path.moveTo(cornerRadius, 0);
    path.quadraticBezierTo(0, 0, 0, cornerRadius);

    // Top part before the selected tab indent
    if (selectedIndex > 0) {
      path.lineTo(0, selectedTabTop - cornerRadius);
      // Smooth curve into the indent (curves inward)
      path.quadraticBezierTo(0, selectedTabTop, cornerRadius, selectedTabTop);
<<<<<<< HEAD
      path.quadraticBezierTo(indentDepth, selectedTabTop + cornerRadius, indentDepth, selectedTabTop + cornerRadius * 2);
    } else {
      // If first tab is selected, start indent from top
      path.lineTo(0, cornerRadius);
      path.quadraticBezierTo(cornerRadius, cornerRadius, indentDepth, cornerRadius * 2);
=======
      path.quadraticBezierTo(indentDepth, selectedTabTop + cornerRadius,
          indentDepth, selectedTabTop + cornerRadius * 2);
    } else {
      // If first tab is selected, start indent from top
      path.lineTo(0, cornerRadius);
      path.quadraticBezierTo(
          cornerRadius, cornerRadius, indentDepth, cornerRadius * 2);
>>>>>>> origin/Grocery_pch_api_integration
    }

    // Middle of the indent (straight line)
    path.lineTo(indentDepth, selectedTabBottom - cornerRadius * 2);

    // Bottom part - curve out of the selected tab indent
<<<<<<< HEAD
    path.quadraticBezierTo(indentDepth, selectedTabBottom - cornerRadius, cornerRadius, selectedTabBottom);
    path.quadraticBezierTo(0, selectedTabBottom, 0, selectedTabBottom + cornerRadius);
=======
    path.quadraticBezierTo(indentDepth, selectedTabBottom - cornerRadius,
        cornerRadius, selectedTabBottom);
    path.quadraticBezierTo(
        0, selectedTabBottom, 0, selectedTabBottom + cornerRadius);
>>>>>>> origin/Grocery_pch_api_integration

    // Now add the outward bulge for the tab below the selected one
    if (selectedIndex < 3) {
      double nextTabTop = selectedTabBottom + cornerRadius;
      double nextTabBottom = nextTabTop + tabHeight - (cornerRadius * 2);

      // Go down a bit then curve outward (bulge)
      path.lineTo(0, nextTabTop);
<<<<<<< HEAD
      path.quadraticBezierTo(-cornerRadius, nextTabTop + cornerRadius, -cornerRadius, nextTabTop + cornerRadius * 2);
      path.lineTo(-cornerRadius, nextTabBottom - cornerRadius);
      path.quadraticBezierTo(-cornerRadius, nextTabBottom, 0, nextTabBottom + cornerRadius);
=======
      path.quadraticBezierTo(-cornerRadius, nextTabTop + cornerRadius,
          -cornerRadius, nextTabTop + cornerRadius * 2);
      path.lineTo(-cornerRadius, nextTabBottom - cornerRadius);
      path.quadraticBezierTo(
          -cornerRadius, nextTabBottom, 0, nextTabBottom + cornerRadius);
>>>>>>> origin/Grocery_pch_api_integration

      if (selectedIndex < 2) {
        // Continue to bottom if not the second-to-last tab
        path.lineTo(0, size.height - cornerRadius);
      } else {
        // Go to bottom
        path.lineTo(0, size.height - cornerRadius);
      }
    } else {
      // Last tab selected, just go to bottom
      path.lineTo(0, size.height - cornerRadius);
    }

    // Rounded bottom-left corner
    path.quadraticBezierTo(0, size.height, cornerRadius, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/Grocery_pch_api_integration
