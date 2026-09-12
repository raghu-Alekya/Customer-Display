import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:pinaka_pos/Helper/Extentions/extensions.dart';
import 'package:pinaka_pos/Helper/Extentions/money_rounding_helper.dart';
import 'package:pinaka_pos/Screens/Home/pos_home_screen.dart';
import 'package:pinaka_pos/Screens/Home/redeem_points_popup_screen.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:provider/provider.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Payment/payment_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/printer_db_helper.dart';
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Helper/customerdisplayhelper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Payment/payment_model.dart';
import '../../Models/Payment/void_payment_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Payment/payment_repository.dart';
import '../../Utilities/global_utility.dart';
import '../../Utilities/responsive_layout.dart';
import '../../Utilities/result_utility.dart';
import '../../Utilities/svg_images_utility.dart';
import '../../Widgets/PaymentNumPad.dart';
import '../../Widgets/offline_order_sync_service.dart';
import '../../Widgets/pay_later_widget.dart';
import '../../Widgets/scanner_guard.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_payment_dialog.dart';
import '../../Widgets/widget_topbar.dart';
import '../../mqtt_server/cart_item.dart';
import '../../mqtt_server/cart_state.dart';
import '../../mqtt_server/cfd_store_payload.dart';
import '../../mqtt_server/store_messaging_service.dart';
import '../../services/CustomerDisplayService.dart';
import '../../services/customer_services.dart';


import 'package:android_intent_plus/android_intent.dart';

import 'package:thermal_printer/thermal_printer.dart';

import 'Settings/image_utils.dart';
import 'Settings/printer_setup_screen.dart';
import 'isar_payments/local_payments_db_helper.dart';
import 'isar_payments/local_payments_model.dart';


class LastPaymentInfo {
  final String method;
  final double amount;
  late final String? paymentId;
  final String? sunmiTxnId;
  final String? sunmiOrderId;
  final String? sunmiDeviceId;
  final String? transactionId; // ⭐ ADD THIS

  LastPaymentInfo({
    required this.method,
    required this.amount,
    this.paymentId,
    this.sunmiTxnId,
    this.sunmiOrderId,
    this.sunmiDeviceId,
    this.transactionId, // ⭐ ADD THIS
  });

  Map<String, dynamic> toJson() => {
    "method": method,
    "amount": amount,
    "paymentId": paymentId,
    "sunmiTxnId": sunmiTxnId,
    "sunmiOrderId": sunmiOrderId,
    "sunmiDeviceId": sunmiDeviceId,
    "transactionId": transactionId, // ⭐ ADD THIS
  };

  factory LastPaymentInfo.fromJson(Map<String, dynamic> json) {
    return LastPaymentInfo(
      method: json["method"],
      amount: (json["amount"] as num).toDouble(),
      paymentId: json["paymentId"],
      sunmiTxnId: json["sunmiTxnId"],
      sunmiOrderId: json["sunmiOrderId"],
      sunmiDeviceId: json["sunmiDeviceId"],
      transactionId: json["transactionId"], // ⭐ ADD THIS
    );
  }
}

/// SQLite / Hive often store flags as 0/1; summary UI used strict `== true`.
bool _orderSummaryLineEbtEligible(Map<String, dynamic> item) {
  bool truthy(dynamic v) {
    if (v == true || v == 1) return true;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  return truthy(item['is_ebt_eligible']) || truthy(item['ebt_eligible']);
}

/// Issued (generate for customer) → `generate_type` false. Redeemed on order → true.
bool _couponHiveEntryIsRedeem(Map<String, dynamic> c) {
  final gt = c['generate_type'];
  if (gt == true) return true;
  if (gt == false) return false;
  final keys = c.keys.toSet();
  return keys.length == 1 && keys.contains('code');
}

Map<String, dynamic> _mergeRedeemIntoCouponResponse(
    dynamic prevCouponResponse,
    String redeemCode,
    ) {
  Map<String, dynamic> base = {};
  if (prevCouponResponse is Map) {
    base = Map<String, dynamic>.from(prevCouponResponse);
  }
  final prevCoupons = <Map<String, dynamic>>[];
  final rawList = base['coupons'];
  if (rawList is List) {
    for (final x in rawList) {
      if (x is Map) {
        prevCoupons.add(Map<String, dynamic>.from(x));
      }
    }
  }
  final trimmed = redeemCode.trim();
  final keptIssued =
  prevCoupons.where((c) => !_couponHiveEntryIsRedeem(c)).toList();
  final otherRedeems = prevCoupons
      .where((c) =>
  _couponHiveEntryIsRedeem(c) &&
      c['code']?.toString().trim() != trimmed)
      .toList();
  base['coupons'] = [
    ...keptIssued,
    ...otherRedeems,
    <String, dynamic>{'code': redeemCode, 'generate_type': true},
  ];
  return base;
}

void _enrichRedeemCouponIdsFromWoo(
    Map<String, dynamic> offlineOrder,
    Map<String, dynamic> wooResult,
    String appliedCode,
    ) {
  final cr = offlineOrder['coupon_response'];
  if (cr is! Map) return;
  final map = Map<String, dynamic>.from(cr);
  final coupons = map['coupons'];
  if (coupons is! List) return;
  final lines = wooResult['coupon_lines'] as List? ?? [];
  final trimmed = appliedCode.trim();
  final updated = <dynamic>[];
  for (final c in coupons) {
    if (c is! Map) {
      updated.add(c);
      continue;
    }
    final m = Map<String, dynamic>.from(c);
    if (m['generate_type'] == true && m['code']?.toString().trim() == trimmed) {
      for (final line in lines) {
        if (line is! Map) continue;
        if (line['code']?.toString().trim() == trimmed) {
          final wid = line['id'];
          if (wid != null) m['id'] = wid;
          break;
        }
      }
    }
    updated.add(m);
  }
  map['coupons'] = updated;
  offlineOrder['coupon_response'] = map;
}

int _orderSummaryLineVariationId(Map<String, dynamic> item) {
  final raw = item['variation_id'] ??
      item['variationId'] ??
      item['item_variation_id'] ??
      item['item_variation'] ??
      0;
  final v = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
  return v < 0 ? 0 : v;
}

String _orderSummaryLineVariationName(Map<String, dynamic> item) {
  final n = item['variation_name'] ??
      item['item_variation_custom_name'] ??
      item['attribute_variant'];
  return n?.toString().trim() ?? '';
}

String _orderSummaryNormalizeSku(dynamic raw) {
  return (raw ?? '').toString().trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]'),
    '',
  );
}

bool _cachedProductMapIndicatesEbt(Map<String, dynamic> p) {
  if (_orderSummaryLineEbtEligible(p)) return true;
  final meta = p['meta_data'];
  if (meta is List) {
    for (final x in meta) {
      if (x is! Map) continue;
      final key = (x['key'] ?? '').toString().toLowerCase();
      if (key != 'is_ebt_eligible' &&
          key != '_is_ebt_eligible' &&
          key != '_ebt_eligible') {
        continue;
      }
      final v = x['value'];
      if (v == true || v == 1) return true;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == '1' || s == 'true' || s == 'yes') return true;
      }
    }
  }
  final tags = p['tags'];
  if (tags is List) {
    for (final t in tags) {
      if (t is! Map) continue;
      final name = (t['name'] ?? '').toString().toLowerCase();
      final slug = (t['slug'] ?? '').toString().toLowerCase();
      if (name.contains('ebt') || slug.contains('ebt')) return true;
    }
  }
  return false;
}

/// When SQLite/Hive mismatch left lines without badges, use TopBar merged product list (same as POS search).
Future<void> _mergeOrderSummaryLineItemsFromProductCache(
    List<Map<String, dynamic>> lineItems,
    ) async {
  try {
    final all = await TopBar.mergedCachedProductsForSearch();
    final byId = <int, Map<String, dynamic>>{};
    for (final raw in all) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final idRaw = m['fast_key_product_id'] ?? m['product_id'] ?? m['id'];
      final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
      if (id != null && id > 0) {
        byId[id] = m;
      }
    }

    for (final line in lineItems) {
      final lt = (line['item_type'] ?? '').toString().toLowerCase();
      final nm = (line[AppDBConst.itemName] ?? line['item_name'] ?? '')
          .toString()
          .toLowerCase();
      if (lt.contains('discount') ||
          lt.contains('coupon') ||
          lt.contains('payout') ||
          lt.contains('cashback') ||
          lt.contains('loyalty') ||
          nm.contains('merchant discount')) {
        continue;
      }

      final pidRaw = line['product_id'] ??
          line[AppDBConst.itemProductId] ??
          line['item_product_id'];
      final int? pid =
      pidRaw is int ? pidRaw : int.tryParse(pidRaw?.toString() ?? '');
      if (pid == null || pid <= 0) continue;

      final p = byId[pid];
      if (p == null) continue;

      if (!_orderSummaryLineEbtEligible(line) &&
          _cachedProductMapIndicatesEbt(p)) {
        line['is_ebt_eligible'] = 1;
        line['ebt_eligible'] = 1;
      }

      // Only back-fill variant badges from cache for real child variations.
      // Do not use parent_id != null — API/maps often send parent_id: 0, which
      // incorrectly marked every simple product as a variant.
      if (_orderSummaryLineVariationId(line) <= 0 &&
          _orderSummaryLineVariationName(line).isEmpty) {
        final typeStr = (p['type'] ?? '').toString().toLowerCase();
        final parentRaw = p['parent_id'];
        final parentId = parentRaw is int
            ? parentRaw
            : int.tryParse(parentRaw?.toString() ?? '') ?? 0;
        final isChildVariation =
            (typeStr == 'variation' || typeStr == 'variant') && parentId > 0;
        if (!isChildVariation) continue;

        final vId = int.tryParse(
          (p['id'] ?? p['variation_id'] ?? 0).toString(),
        ) ??
            0;
        if (vId <= 0) continue;

        line['variation_id'] = vId;
        line['variationId'] = vId;
        line['item_variation_id'] = vId;
        line['item_variation'] = vId;
        final vName = (p['name'] ?? '').toString().trim();
        if (vName.isNotEmpty) {
          line['variation_name'] = vName;
          line['item_variation_custom_name'] = vName;
          line['attribute_variant'] = vName;
        }
        line['is_variant'] = 1;
        final lType = (line['item_type'] ?? '').toString().toLowerCase();
        if (lType.isEmpty || lType == 'product') {
          line['item_type'] = 'variant';
        }
        // NEW: Merge meta_data (loyalty points etc.) from cached Indigo product
        // === IMPROVED: Merge meta_data (loyalty points + other merchant data) ===
        if (p != null) {
          print('🔍 [Merge Meta] Found cached product for ID: ${p['fast_key_product_id'] ?? p['id']} | Name: ${p['name'] ?? p['fast_key_item_name']}');

          dynamic meta = p['meta_data'] ?? p['metaData'];

          if (meta is List) {
            line['meta_data'] = List<Map<String, dynamic>>.from(meta);
            print('✅ [Merge Meta] Copied meta_data List with ${meta.length} entries');
          } else if (meta is Map) {
            line['meta_data'] = [Map<String, dynamic>.from(meta)];
            print('✅ [Merge Meta] Converted single meta Map to List');
          } else {
            // Try alternative keys
            meta = p['metaData'] ?? p['metadata'] ?? p['meta'] ?? null;
            if (meta is List) {
              line['meta_data'] = List<Map<String, dynamic>>.from(meta);
              print('✅ [Merge Meta] Found meta_data using fallback key');
            } else {
              print('⚠️ [Merge Meta] No meta_data found in cached product');
            }
          }

          // Always provide fallback key
          if (line['meta_data'] != null) {
            line['metaData'] = line['meta_data'];
          }

          // Extract loyalty points + debug print
          if (line['meta_data'] is List) {
            bool foundLoyalty = false;
            for (var m in line['meta_data']) {
              if (m is Map && m['key'] == '_product_loyalty_points') {
                final points = int.tryParse(m['value']?.toString() ?? '0') ?? 0;
                line['loyalty_points'] = points;
                print('🎯 [Merge Meta] Loyalty Points Found: $points for ${p['name']}');
                foundLoyalty = true;
                break;
              }
            }
            if (!foundLoyalty) {
              print('ℹ️ [Merge Meta] No _product_loyalty_points found in meta_data');
            }
          }
        } else {
          print('⚠️ [Merge Meta] No cached product (p == null)');
        }

      }
    }
  } catch (_) {}

}

/// Pending orders often load line items from SQLite without EBT/variation flags
/// while the same cart still exists in Hive `products`. Merge so badges match the order panel.
void _mergeOrderSummaryLineItemsFromHive(
    List<Map<String, dynamic>> lineItems,
    Map<String, dynamic>? hiveOrder,
    ) {
  if (hiveOrder == null) return;
  final rawProducts = hiveOrder['products'];
  if (rawProducts is! List || rawProducts.isEmpty) return;

  for (final line in lineItems) {
    final name = (line[AppDBConst.itemName] ?? line['item_name'] ?? '')
        .toString()
        .trim();
    final pidRaw = line['product_id'] ??
        line[AppDBConst.itemProductId] ??
        line['item_product_id'];
    final int? pid =
    pidRaw is int ? pidRaw : int.tryParse(pidRaw?.toString() ?? '');

    Map<String, dynamic>? matched;
    for (final p in rawProducts) {
      if (p is! Map) continue;
      final m = Map<String, dynamic>.from(p);
      final pPidRaw = m['product_id'] ?? m['id'];
      final pPid =
      pPidRaw is int ? pPidRaw : int.tryParse(pPidRaw?.toString() ?? '');
      if (pid != null && pPid != null && pPid == pid) {
        matched = m;
        break;
      }
    }
    if (matched == null && name.isNotEmpty) {
      for (final p in rawProducts) {
        if (p is! Map) continue;
        final m = Map<String, dynamic>.from(p);
        if ((m['name'] ?? '').toString().trim() == name) {
          matched = m;
          break;
        }
      }
    }
    if (matched == null) {
      final lineSku = _orderSummaryNormalizeSku(
        line[AppDBConst.itemSKU] ?? line['sku'],
      );
      if (lineSku.isNotEmpty) {
        for (final p in rawProducts) {
          if (p is! Map) continue;
          final m = Map<String, dynamic>.from(p);
          if (_orderSummaryNormalizeSku(m['sku']) == lineSku) {
            matched = m;
            break;
          }
        }
      }
    }
    if (matched == null) continue;

    if (!_orderSummaryLineEbtEligible(line)) {
      final dynamic ebt = matched['is_ebt_eligible'];
      if (ebt == true ||
          ebt == 1 ||
          (ebt is String && (ebt == '1' || ebt.toLowerCase() == 'true'))) {
        line['is_ebt_eligible'] = 1;
        line['ebt_eligible'] = 1;
      } else if (_cachedProductMapIndicatesEbt(matched)) {
        line['is_ebt_eligible'] = 1;
        line['ebt_eligible'] = 1;
      }
    }

    final dynamic vidRaw = matched['variation_id'] ??
        matched['variationId'] ??
        matched['item_variation'];
    int vNum = 0;
    if (vidRaw is num) {
      vNum = vidRaw.toInt();
    } else {
      vNum = int.tryParse(vidRaw?.toString() ?? '') ?? 0;
    }
    if (vNum < 0) vNum = 0;

    final vName = (matched['variation_name'] ?? '').toString().trim();
    final pType = (matched['type'] ?? '').toString().toLowerCase();

    final bool showVariantBadge = pType == 'variant' || vNum > 0;

    if (showVariantBadge) {
      if (vNum > 0) {
        line['variation_id'] = vNum;
        line['variationId'] = vNum;
        line['item_variation_id'] = vNum;
        line['item_variation'] = vNum;
      }
      if (vName.isNotEmpty) {
        line['variation_name'] = vName;
        line['item_variation_custom_name'] = vName;
        line['attribute_variant'] = vName;
      }
      line['is_variant'] = 1;
      final lt = (line['item_type'] ?? '').toString().toLowerCase();
      if (lt.isEmpty || lt == 'product') {
        if (pType == 'variant') {
          line['item_type'] = 'variant';
        }
      }
    }
  }
}

class OrderSummaryScreen extends StatefulWidget {
  final String formattedDate;
  final String formattedTime;
  final List<Map<String, dynamic>> orderItems;
  final double grossTotal;
  final double orderDiscount;
  final double merchantDiscount;
  final double orderTax;
  final double netPayable;
  final int? orderId;
  final bool isOfflineSynced;
  final int? offlineOrderId;
  final double cashbackFee;
  final double? balanceamount;
  final double ebtAmount; //  NEW
  final double discountAmount;
  final bool itemPricesAlreadyAdjusted;
  // bool isCustomerFieldDisabled = false;

  const OrderSummaryScreen({
    required this.formattedDate,
    required this.formattedTime,
    required this.orderItems,
    required this.grossTotal,
    required this.orderDiscount,
    required this.merchantDiscount,
    required this.orderTax,
    required this.netPayable,
    required this.orderId,
    required this.cashbackFee,
    required this.ebtAmount,
    this.isOfflineSynced = false,
    this.offlineOrderId,
    super.key,
    this.balanceamount,
    required this.discountAmount,
    this.itemPricesAlreadyAdjusted = false,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  List<Map<String, dynamic>> orderItems = [];
  String selectedPaymentMethod = "";
  TextEditingController amountController = TextEditingController();
  bool _paymentDialogShown = false;
  bool get isOrderPending => orderStatus == 'pending';
  LastPaymentInfo? _lastPayment;
  bool isCustomerFieldDisabled = false;

  final PaymentBloc paymentBloc =
  PaymentBloc(PaymentRepository()); // Added PaymentBloc
  final ScrollController _scrollController = ScrollController();
  int? userId; // Build #1.0.29: To store user ID
  String? userDisplayName; // Build #1.0.29: To store user ID
  String? userRole;
  int? orderId; // server id from order table
  String? orderDateTime = "";
  double oldTax = 0.0;
  int shiftId = 1; // Hardcoded as per requirement
  int vendorId = 1; // Hardcoded as per requirement
  String serviceType = "default"; // Hardcoded as per requirement
  double total = 0.0;
  double orderTotal = 0.0; // Build #1.0.137
  String orderStatus = TextConstants.processing; // Build  #1.0.177
  double grossTotal = 0.0;
  double netTotal = 0.0;
  double payableAmount = 0.0;
  double balanceAmount = 0.0;
  double tenderAmount = 0.0; // Build #1.0.33 : added new variables
  double paidAmount = 0.0;
  double changeAmount = 0.0;
  double discount = 0.0; // Add this to track discount
  double merchantDiscount = 0.0; // Add this to track merchant discount
  double tax = 0.0;
  double cashback = 0.0;
  double servicecharges = 0.0;
  bool isRedeemActive = false;
  bool isCouponActive = false;
  bool isGiftReceiptActive = false;
  double cashbackFee = 0.0;
  bool isPhoneValid = false;
  bool isEmailValid = false;
  Map<String, dynamic>? loyaltyData;
  bool isAddLoading = false;
// ⭐ store full API data globally
  bool isPaymentDone = false;
  Map<String, dynamic> _order = {};
  bool couponPopupActive = false;
  bool _successPopupShown = false;
  bool isAddButtonEnabled = true;
  bool isButtonDisabled = false;

  final bool enableCardPayment = false;
  final bool enableWalletPayment = false;

  bool _isShowingPartialDialog = false;

  bool _isShowingPaymentDialog = false;
  bool _isVoiding = false;
  bool _isOrderSyncInProgress = false;
  String? _activeSyncOrderKey;
  DateTime? _lastOrderSyncAt;
  String? _lastSyncedOrderKey;

  double? _pendingTaxRefTax;
  double? _pendingTaxRefBase;
  double? _pendingTaxRefRate;

  double ebtTotal = 0.0;
  double payByEbt = 0.0; // ADD THIS
  TextEditingController ebtAmountController = TextEditingController();

  Map<String, dynamic>? _selectedPayLaterUser;  // ← ADD THIS LINE
  bool _isPayLaterSelected = false;
  // static int _cfdSequence = 0;
  bool _suppressCfdSync = false;

  // int _computeTotalItems() {
  //   //   return orderItems.fold(0, (sum, item) {
  //   //     final name = item['item_name']?.toString().toLowerCase() ?? '';
  //   //     if (name == 'payout' || name == 'cashback') {
  //   //       return sum;
  //   //     }
  //   //     final qty = int.tryParse(item['items_count']?.toString() ?? '1') ?? 1;
  //   //     return sum + qty;
  //   //   });
  //   // }
     // Push current Order Summary totals + items to CFD (MQTT + native).
  /// Call after: coupon apply, coupon remove, customer number add, merchant discount change.
  /// Push current Order Summary state to CFD (MQTT + native).
  /// Call after coupon apply/remove, customer number, merchant discount, etc.
  // Future<void> _syncCfdFromOrderSummary() async {
  //   final int? id = widget.offlineOrderId ?? widget.orderId ?? orderId;
  //   if (id == null || id <= 0) {
  //     if (kDebugMode) print('⚠️ CFD sync skipped – no order id');
  //     return;
  //   }
  //
  //   try {
  //     // ── Native secondary display ────────────────────────────────────
  //     await CustomerDisplayHelper.updateCustomerDisplay(
  //       id,
  //       summaryEnabled: true,
  //     );
  //
  //     // ── MQTT CFD ────────────────────────────────────────────────────
  //     try {
  //       final messaging =
  //       Provider.of<StoreMessagingService>(context, listen: false);
  //
  //       final store = await CfdStorePayload.load();
  //
  //       final List<CartItem> items = orderItems
  //           .map((e) => CartItem.fromOrderItem(Map<String, dynamic>.from(e)))
  //           .toList();
  //
  //       // POS stores coupon as negative (e.g. -7.00). CFD expects positive discount.
  //       final double couponAbs = discount.abs();
  //       final double mDiscAbs = merchantDiscount.abs();
  //       final double net = (grossTotal - couponAbs - mDiscAbs);
  //       final double netPay = computedNetPayable;
  //       final int itemCount = _computeTotalItems();
  //
  //       final state = CartState(
  //         sessionId: 'ORDER-$id',
  //         sequence: 0,
  //         screen: 'CART',
  //         items: items,
  //         tax: tax,
  //         message: null,
  //         orderId: id,
  //         subtotalOverride: grossTotal,
  //         orderDiscount: couponAbs,          // ← coupon amount (positive)
  //         merchantDiscount: mDiscAbs,
  //         cashbackFee: cashbackFee,
  //         netPayable: netPay,                // ← Net Payable (bottom total)
  //         totalItems: itemCount,
  //         orderDate: _displayDate.isNotEmpty
  //             ? _displayDate
  //             : widget.formattedDate,
  //         orderTime: _displayTime.isNotEmpty
  //             ? _displayTime
  //             : widget.formattedTime,
  //         summaryEnabled: true,              // ← MUST be true for bottom panel
  //         storeId: store.storeId,
  //         storeName: store.storeName,
  //         storeLogoUrl: store.storeLogoUrl,
  //         storeBaseUrl: store.storeBaseUrl,
  //         slideshowUrls: store.slideshowUrls,
  //       );
  //
  //       await messaging.publishState(state);
  //
  //       if (kDebugMode) {
  //         print(
  //           '📤 [CFD] coupon apply → gross=$grossTotal coupon=$couponAbs '
  //               'tax=$tax netPayable=$netPay items=$itemCount summary=true',
  //         );
  //       }
  //     } catch (e) {
  //       if (kDebugMode) print('⚠️ MQTT CFD publish failed: $e');
  //     }
  //   } catch (e, st) {
  //     if (kDebugMode) {
  //       print('❌ _syncCfdFromOrderSummary: $e');
  //       print(st);
  //     }
  //   }
  // }

  Future<void> _publishMqttThankYouThenWelcome() async {
    try {
      final messaging =
      Provider.of<StoreMessagingService>(context, listen: false);
      final store = await CfdStorePayload.load();

      // ── 1) THANK YOU (empty cart – no old items) ──
      final thankYou = CartState(
        sessionId: 'ORDER-${orderId ?? 0}',
        sequence: CfdSequence.next(),
        screen: 'THANK_YOU',
        items: const [],
        tax: 0,
        message: null,
        orderId: orderId,
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
      await messaging.publishState(thankYou);

      if (kDebugMode) {
        print('📤 [MQTT] THANK_YOU published for order ${orderId ?? 0}');
      }

      // Hold so CFD can show Thank You
      await Future.delayed(const Duration(seconds: 3));

      // ── 2) WELCOME with store name (no items) ──
      final welcome = CartState(
        sessionId: 'ORDER-0',
        sequence: CfdSequence.next(),
        screen: 'WELCOME', // or 'IDLE' – both map to Welcome layout on CFD
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
        storeName: store.storeName, // "Welcome to {storeName}"
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
        loyaltyContact: '',
        availablePoints: 0,
      );
      await messaging.publishState(welcome);

      if (kDebugMode) {
        print(
          '📤 [MQTT] WELCOME published → store="${store.storeName}"',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('⚠️ _publishMqttThankYouThenWelcome failed: $e');
        print(st);
      }
    }
  }

  Future<void> _syncCfdFromOrderSummary() async {
    final int? id = widget.offlineOrderId ?? widget.orderId ?? orderId;
    if (id == null || id <= 0) return;

    try {
      // Optional native first – MQTT must win after this
      try {
        await CustomerDisplayHelper.updateCustomerDisplay(
          id,
          summaryEnabled: true,
        );
      } catch (_) {}

      final messaging =
      Provider.of<StoreMessagingService>(context, listen: false);
      final store = await CfdStorePayload.load();

      final List<CartItem> items = orderItems
          .map((e) => CartItem.fromOrderItem(Map<String, dynamic>.from(e)))
          .toList();

      // EXACT values shown on Order Summary screen (not Hive)
      final double couponAbs = discount.abs();           // e.g. 7.00
      final double mDiscAbs = merchantDiscount.abs();    // e.g. 12.39
      final double netPay = computedNetPayable;          // e.g. 115.07
      final int itemCount = _computeTotalItems();

      String loyaltyContact = mobileController.text.trim();
      int availablePts = availablePoints;
      try {
        final box = StorageProvider.offlineOrders;
        final raw = await box.get(id.toString());
        if (raw is Map) {
          final order = Map<String, dynamic>.from(raw);
          if (loyaltyContact.isEmpty) {
            loyaltyContact = (order['loyaltyContact'] ?? '').toString();
          }
          availablePts = int.tryParse(
              (order['available_points'] ?? availablePoints).toString()) ??
              availablePoints;
        }
      } catch (_) {}

      final state = CartState(
        sessionId: 'ORDER-$id',
        sequence: CfdSequence.next(),
        screen: 'CART',
        items: items,
        tax: tax,
        message: null,
        orderId: id,
        subtotalOverride: grossTotal,      // 123.95
        orderDiscount: couponAbs,          // 7.00  → CFD Coupon row
        merchantDiscount: mDiscAbs,        // 12.39 → CFD Merchant Discount row
        cashbackFee: cashbackFee,          // 1.00
        netPayable: netPay,                // 115.07
        totalItems: itemCount,
        orderDate:
        _displayDate.isNotEmpty ? _displayDate : widget.formattedDate,
        orderTime:
        _displayTime.isNotEmpty ? _displayTime : widget.formattedTime,
        summaryEnabled: true,
        storeId: store.storeId,
        storeName: store.storeName,
        storeLogoUrl: store.storeLogoUrl,
        storeBaseUrl: store.storeBaseUrl,
        slideshowUrls: store.slideshowUrls,
        loyaltyContact: loyaltyContact,
        availablePoints: availablePts,
      );

      await messaging.publishState(state); // LAST – must win

      if (kDebugMode) {
        print(
          '📤 [CFD] OrderSummary → gross=$grossTotal '
              'coupon=$couponAbs mDisc=$mDiscAbs tax=$tax '
              'cbFee=$cashbackFee net=$netPay',
        );
      }
    } catch (e, st) {
      if (kDebugMode) print('❌ _syncCfdFromOrderSummary: $e\n$st');
    }
  }

  int _computeTotalItems() {
    return orderItems.fold(0, (sum, item) {
      final String itemType = (item['item_type'] ?? '').toString().toLowerCase();
      final String itemNameLower = (item['item_name'] ?? '').toString().toLowerCase();

      if (itemType.contains('discount') || itemNameLower.contains('merchant discount')) {
        return sum;
      }
      final qty = int.tryParse(item['items_count']?.toString() ?? '1') ?? 1;
      return sum + qty;
    });
  }

  PaymentMode _paymentModeFromMethod(dynamic method) {
    final String m = (method ?? '').toString().trim().toLowerCase();
    if (m == TextConstants.ebtText.toLowerCase()) return PaymentMode.ebt;
    if (m == TextConstants.card.toLowerCase()) return PaymentMode.card;
    if (m == TextConstants.wallet.toLowerCase()) return PaymentMode.payLater;
    if (m == 'pay later') return PaymentMode.payLater;   // ⭐ ADDED: route Pay Later to Wallet mode
    return PaymentMode.cash;
  }

  PaymentMode _currentDialogPaymentMode() {
    // Prefer the latest persisted payment method from the payment result path.
    final String? lastPaymentMethod = _lastPayment?.method;
    if (lastPaymentMethod != null && lastPaymentMethod.trim().isNotEmpty) {
      return _paymentModeFromMethod(lastPaymentMethod);
    }

    // Fallback to last in-memory progression details, then current selection.
    final dynamic lastMethod = _lastPaymentDetails?['method'];
    return _paymentModeFromMethod(lastMethod ?? selectedPaymentMethod);
  }

  static const bool offline_PAYMENT_SUCCESS = true; // ← toggle this

  bool _dialogGuard = false;
  bool _successDialogAlreadyShown = false;
  bool _partialDialogAlreadyShown = false;

  double NetTotal = 0.0;
  // AddED tax variable
  double payByCash = 0.0;
  double payByOther = 0.0;
  // String? orderStatus = ""; // Build #1.0.175: save orderStatus value
  StreamSubscription? _paymentListSubscription;
  bool isLoading = false; // Add this to track loading state
  bool isSummaryLoading = false;
  String?
  _processingPaymentMethod; // Track which payment method is currently processing
  // final TextEditingController _paymentController = TextEditingController();
  var _printerSettings = PrinterSettings();
  List<int> bytes = [];
  String? paymentId; // To store the transaction ID after wallet payment
  late OrderBloc orderBloc;
  bool _showFullSummary = false;
  String? _amountErrorText;
  bool _isAmountEntered = false;
  bool _userManuallyEnteredAmount = false;
  double payByCard = 0.0;
  Map<String, dynamic>? offlineOrder;

  bool _isCardPaymentCancelled = false;

  double?
  _currentPaymentRemainingBalance; // Track remaining balance from current payment
  Map<String, dynamic>? _lastPaymentDetails; // Store details of last payment

  double discountValue = 0.0;

  // Determine the date and time to display
  String _displayDate = "";
  String _displayTime = "";
  int _rawAmount = 0;
  double computedNetPayable = 0.0;
// holds value in paise/cents, e.g. 2345
  bool showCustomerInput = false;
  final TextEditingController mobileController = TextEditingController();
  int availablePoints = 0; // from backend API
  double orderTotalAmount = 0.0; // from order helper / cart total
  bool isMobileValid = false;
  double redeemedValue = 0.0;
  bool isPaymentStarted = false;
  bool isRedeemAppliedFromApi = false;
  bool isCouponAppliedFromApi = false;
  double couponValue = 0;
  double couponDiscount = 0.0;
  double merchantDiscountPercentage = 0.0;

  bool _isProcessing = false; // Add this flag

  String _formatNetPayable(double value) {
    return value < 0
        ? '-${TextConstants.currencySymbol}${value.abs().toStringAsFixed(2)}'
        : '${TextConstants.currencySymbol}${value.toStringAsFixed(2)}';
  }

  Future<void> _calculateBalanceFromPaymentHistory() async {
    try {
      if (orderId == null || orderId == 0) {
        setState(() {
          balanceAmount = computedNetPayable;
          _currentPaymentRemainingBalance = null;
          _lastPaymentDetails = null;
        });
        return;
      }

      final payments =
      await LocalPaymentDBHelper.instance.getPaymentsByOrderId(orderId!);
      final box = StorageProvider.offlineOrders;
      final key = orderId.toString();
      final rawStored = await box.get(key);
      final stored =
      Map<String, dynamic>.from(rawStored is Map ? rawStored : {});
      final double originalEbt =
          (stored["originalEbt"] as num?)?.toDouble() ?? ebtTotal;
      // redeemedValue = (stored["redeemed_value"] as num?)?.toDouble() ?? 0.0;
      //       // final double effectivePayable =
      //       // (computedNetPayable - redeemedValue).clamp(0.0, double.infinity);

      redeemedValue = (stored["redeemed_value"] as num?)?.toDouble() ?? 0.0;
      final double effectivePayable = computedNetPayable < 0
          ? (computedNetPayable - redeemedValue)
          : (computedNetPayable - redeemedValue).clamp(0.0, double.infinity);

      if (payments.isEmpty) {
        final double remainingEbt =
            (stored["remainingEbt"] as num?)?.toDouble() ?? originalEbt;
        stored["redeemed_value"] = redeemedValue; // ensure saved

        setState(() {
          balanceAmount = effectivePayable;
          _currentPaymentRemainingBalance = null;
          _lastPaymentDetails = null;
          payByEbt = 0.0;
          ebtTotal = remainingEbt;
        });
        return;
      }

      payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      double totalPaid = 0.0;
      // double runningBalance = computedNetPayable;
      LocalPayment? lastPayment;

      // double effectivePayable =
      // (computedNetPayable - redeemedValue).clamp(0.0, double.infinity);

      double runningBalance = effectivePayable;
      double previousBalance = effectivePayable;

      print("\n📊 PAYMENT HISTORY PROGRESSION FOR ORDER #$orderId:");
      print("=" * 60);
      print("Starting Balance: \$${effectivePayable.toStringAsFixed(2)}");
      print("-" * 60);

      // Track balance progression
      for (var i = 0; i < payments.length; i++) {
        final payment = payments[i];
        final paymentAmount = payment.amount;

        double balanceBeforePayment = runningBalance;
        totalPaid += paymentAmount;
        runningBalance -= paymentAmount;
        if (runningBalance < 0) runningBalance = 0.0;

        lastPayment = payment;

        print(
            "Payment ${i + 1}: ${payment.paymentMethod} - \$${paymentAmount.toStringAsFixed(2)}");
        print("  Balance Before: \$${balanceBeforePayment.toStringAsFixed(2)}");
        print("  Balance After: \$${runningBalance.toStringAsFixed(2)}");
        print("  " + "-" * 40);

        previousBalance = balanceBeforePayment; // Store for next iteration
      }


      double actualRemaining = effectivePayable - totalPaid;

      if (actualRemaining < 0) {
        actualRemaining = 0.0;
      }

      print("\n📈 FINAL SUMMARY:");
      print("Total Paid: \$${totalPaid.toStringAsFixed(2)}");
      print("Remaining Balance: \$${actualRemaining.toStringAsFixed(2)}");
      print(
          "Previous Balance Before Last Payment: \$${previousBalance.toStringAsFixed(2)}");
      print("=" * 60);

      // Set last payment details with progression info
      if (lastPayment != null) {
        _lastPaymentDetails = {
          'amount': lastPayment.amount,
          'method': lastPayment.paymentMethod,
          'remainingBalance': actualRemaining,
          'previousBalance': previousBalance, //  ADD THIS
          'datetime': lastPayment.datetime,
          'paymentId': lastPayment.id,
          'totalPaid': totalPaid, //  ADD THIS
          'paymentNumber': payments.length, //  ADD THIS
        };
      }

      setState(() {
        tenderAmount = totalPaid;
        balanceAmount = actualRemaining;

        if (actualRemaining > 0) {
          _currentPaymentRemainingBalance = actualRemaining;
        } else {
          _currentPaymentRemainingBalance = null;
        }

        // Payment method totals
        payByCash = payments
            .where((p) =>
        p.paymentMethod.toLowerCase() ==
            TextConstants.cash.toLowerCase())
            .fold(0.0, (sum, p) => sum + p.amount);

        payByCard = payments
            .where((p) =>
        p.paymentMethod.toLowerCase() ==
            TextConstants.card.toLowerCase())
            .fold(0.0, (sum, p) => sum + p.amount);

        payByEbt = payments
            .where((p) =>
        p.paymentMethod.toLowerCase() ==
            TextConstants.ebtText.toLowerCase())
            .fold(0.0, (sum, p) => sum + p.amount);

        payByOther = payments
            .where((p) =>
        p.paymentMethod.toLowerCase() !=
            TextConstants.cash.toLowerCase() &&
            p.paymentMethod.toLowerCase() !=
                TextConstants.card.toLowerCase() &&
            p.paymentMethod.toLowerCase() !=
                TextConstants.ebtText.toLowerCase())
            .fold(0.0, (sum, p) => sum + p.amount);

        // Match API-path logic: non-EBT overflow should reduce remaining EBT.
        final double nonEbtOrderValue =
        (computedNetPayable - originalEbt).clamp(0.0, double.infinity);
        // final double nonEbtPaid = payByCash + payByOther;

        final double nonEbtPaid = payByCash + payByOther+payByCard ;

        final double overflowToEbt =
        nonEbtPaid > nonEbtOrderValue ? nonEbtPaid - nonEbtOrderValue : 0.0;
        final double remainingEbt =
        (originalEbt - payByEbt).clamp(0.0, double.infinity);
        ebtTotal = (remainingEbt - overflowToEbt).clamp(0.0, double.infinity);

        isPaymentStarted = totalPaid > 0;
      });

      stored["originalEbt"] = originalEbt;
      stored["remainingEbt"] = ebtTotal;
      await box.put(key, stored);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(" Error calculating balance from payment history: $e");
        print(stackTrace);
      }
      setState(() {
        balanceAmount = computedNetPayable;
        _currentPaymentRemainingBalance = null;
        _lastPaymentDetails = null;
      });
    }
  }

  Future<void> _printPaymentHistorySummary() async {
    if (orderId == null || orderId == 0) return;

    final payments =
    await LocalPaymentDBHelper.instance.getPaymentsByOrderId(orderId!);

    if (payments.isEmpty) {
      print("📊 No payment history found for Order #$orderId");
      return;
    }

    // Sort by creation date ascending
    payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    print("\n" + "=" * 70);
    print("📊 PAYMENT SESSION HISTORY - ORDER #$orderId");
    print("=" * 70);

    double totalPaid = 0.0;
    double currentBalance = computedNetPayable;

    for (var i = 0; i < payments.length; i++) {
      final p = payments[i];
      totalPaid += p.amount;

      double balanceBefore = currentBalance;
      currentBalance -= p.amount;
      if (currentBalance < 0) currentBalance = 0.0;

      final isPartial = p.status == PaymentDbStatus.pending;
      final isSuccessful = p.status == PaymentDbStatus.completed;

      print("Session ${i + 1}. ${p.createdAt.toString().split(' ')[1]} | "
          "ID:${p.id} | ${p.paymentMethod} | "
          "Paid:\$${p.amount.toStringAsFixed(2)} | "
          "Balance: \$${balanceBefore.toStringAsFixed(2)} → \$${currentBalance.toStringAsFixed(2)} | "
          "Status:${p.status?.name ?? 'unknown'} | "
          "local_order_id: \$${p.orderId} |"
          "${isPartial ? '← PARTIAL' : ''}"
          "${isSuccessful ? '← COMPLETE' : ''}");
    }

    // Compute current balance
    final actualBalance = computedNetPayable - totalPaid;
    final displayBalance = actualBalance > 0 ? actualBalance : 0.0;

    print("--" * 70);
    print("SESSION SUMMARY:");
    print("Net Payable: \$${computedNetPayable.toStringAsFixed(2)}");
    print("Total Paid: \$${totalPaid.toStringAsFixed(2)}");
    print("Current Balance: \$${displayBalance.toStringAsFixed(2)}");
    print(
        "Active Session: ${_currentPaymentRemainingBalance != null ? 'Yes' : 'No'}");
    if (_currentPaymentRemainingBalance != null) {
      print(
          "Session Balance: \$${_currentPaymentRemainingBalance!.toStringAsFixed(2)}");
    }
    print("=" * 70 + "\n");
  }

  Future<void> _savePaymentToHive({
    required double amount,
    required String paymentMethod,
    required String transactionId,
    LocalPayment? localPayment,
  }) async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      print(" [SAVE] Starting for order: $key");
      print(" [SAVE] Amount: $amount, Method: $paymentMethod");

      // 1. Make sure the order exists in Hive
      if (!(await box.containsKey(key))) {
        print(" Order not found → creating new entry: $key");
        await _createOfflineOrderEntry(key);
      }

      // 2. Read current data (FRESH COPY)
      final existingOrder = await box.get(key);
      if (existingOrder == null) {
        print(" Failed to read order after creation");
        return;
      }

      var order = Map<String, dynamic>.from(existingOrder);

      print(
          " [SAVE] Current payments count: ${(order['payments'] as List?)?.length ?? 0}");

      // 3. Current totals
      double totalPaid = (order['total_paid'] as num?)?.toDouble() ?? 0.0;
      double remaining = (order['remaining_balance'] as num?)?.toDouble() ??
          computedNetPayable;

      // 4. Calculate new values
      final newPaid = totalPaid + amount;
      double newRemaining = remaining - amount;
      double newChange = 0.0;

      if (newRemaining <= 0) {
        newChange = amount - remaining;
        newRemaining = 0.0;
      }

      final isComplete = newRemaining <= 0;

      // 5. Update payment method counters
      double payCash = (order['pay_by_cash'] as num?)?.toDouble() ?? 0.0;
      double payCard = (order['pay_by_card'] as num?)?.toDouble() ?? 0.0;
      double payEbt = (order['pay_by_ebt'] as num?)?.toDouble() ?? 0.0;
      double payOther = (order['pay_by_other'] as num?)?.toDouble() ?? 0.0;

      switch (paymentMethod.toLowerCase()) {
        case 'cash':
          payCash += amount;
          break;
        case 'card':
          payCard += amount;
          break;
        case 'ebt':
          payEbt += amount;
          break;
        default:
          payOther += amount;
      }

      // 6. Create payment entry
      final now = DateTime.now();
      final ts = now.toIso8601String();

      final Map<String, dynamic> historyEntry = {
        'local_id': localPayment?.id ?? 0,
        'amount': amount,
        'method': paymentMethod,
        'datetime': ts,
        'transaction_id': transactionId,
        'remaining_after': newRemaining,
        'status': isComplete ? 'completed' : 'partial',
        'synced': localPayment?.isSynced ?? false,

        // Additional fields from LocalPayment
        'title': localPayment?.title ?? paymentMethod,
        'orderId': localPayment?.orderId ?? orderId ?? 0,
        'shiftId': localPayment?.shiftId ?? shiftId,
        'vendorId': localPayment?.vendorId ?? vendorId,
        'userId': localPayment?.userId ?? userId ?? 0,
        'serviceType': localPayment?.serviceType ?? serviceType,
        'notes': localPayment?.notes ?? '',
        'remainingBalance': newRemaining,
        'isSynced': localPayment?.isSynced ?? false,
        'serverPaymentId': localPayment?.serverPaymentId,
        'syncError': localPayment?.syncError,
        'syncAttempts': localPayment?.syncAttempts,
        'sunmiTxnId': localPayment?.sunmiTxnId,
        'sunmiOrderId': localPayment?.sunmiOrderId,
        'sunmiDeviceId': localPayment?.sunmiDeviceId,
        'createdAt': localPayment?.createdAt.toIso8601String() ?? ts,
        'syncedAt': localPayment?.syncedAt?.toIso8601String(),
      };

      // 7.  CRITICAL FIX: Get existing payments and append new one
      List<dynamic> payments = [];

      if (order['payments'] != null) {
        // Convert existing payments to List
        if (order['payments'] is List) {
          payments = List<Map<String, dynamic>>.from((order['payments'] as List)
              .map((e) => Map<String, dynamic>.from(e)));
        }
      }

      // Add new payment
      payments.add(historyEntry);

      print(" [SAVE] Payments after adding: ${payments.length}");

      // 8. Update order with ALL fields
      order['payments'] = payments; // ← CRITICAL
      order['total_paid'] = newPaid;
      order['remaining_balance'] = newRemaining;
      order['balance_amount'] = newRemaining;
      order['tender_amount'] = newPaid;
      order['change_amount'] = newChange;
      order['pay_by_cash'] = payCash;
      order['pay_by_card'] = payCard;
      order['pay_by_ebt'] = payEbt;
      order['pay_by_other'] = payOther;
      order['last_payment_time'] = ts;
      order['order_status'] = isComplete ? 'processing' : 'pending_offline';
      order['updated_at'] = ts;

      // Save lastPayment
      if (_lastPayment != null) {
        order['lastPayment'] = _lastPayment!.toJson();
      }

      // 9. WRITE BACK TO HIVE & SQLITE
      await box.put(key, order);
      if (orderId != null && orderId! > 0) {
        unawaited(OfflineHelper.updateOfflineOrderStatus(
          orderId!,
          order['order_status']?.toString() ?? (isComplete ? 'processing' : 'pending_offline'),
          paymentMethod: paymentMethod,
        ));
      }

      print(" [SAVE] Written to Hive successfully");

      // Debug output
      if (kDebugMode) {
        print('''
═══════════════════════════════════════════════════════
 PAYMENT SAVED TO HIVE ── payments[] UPDATED
═══════════════════════════════════════════════════════
Order:          $key
This payment:   $paymentMethod \$${amount.toStringAsFixed(2)}
Local ID:       ${localPayment?.id ?? '-'}
Payments now:   ${payments.length}
Total paid:     \$${newPaid.toStringAsFixed(2)}
Remaining:      \$${newRemaining.toStringAsFixed(2)}
Change:         \$${newChange.toStringAsFixed(2)}
Status:         ${order['order_status']}
Computed Net Payable: \$${computedNetPayable.toStringAsFixed(2)}
Previous Remaining: \$${remaining.toStringAsFixed(2)}
═══════════════════════════════════════════════════════
''');
      }

      //  CRITICAL FIX: Update UI state - CLEAR current payment remaining when complete
      setState(() {
        // Update main values
        tenderAmount = newPaid;
        balanceAmount = newRemaining;
        changeAmount = newChange;
        payByCash = payCash;
        payByCard = payCard;
        payByEbt = payEbt;
        payByOther = payOther;
        orderStatus = order['order_status'];
        isPaymentStarted = true;

        //  FIX: Only set current payment remaining if payment is NOT complete
        if (newRemaining > 0) {
          // Still have balance - show current payment remaining
          _currentPaymentRemainingBalance = newRemaining;
          _lastPaymentDetails = {
            'amount': amount,
            'method': selectedPaymentMethod,
            'remainingBalance': newRemaining,
            'datetime': DateTime.now().toIso8601String(),
          };
        } else {
          //  Payment COMPLETE - CLEAR current payment remaining
          _currentPaymentRemainingBalance = null;
          _lastPaymentDetails = null;
          print(" PAYMENT COMPLETE - Current Payment Remaining cleared!");
        }
      });

      //  If payment is complete, show success popup
      if (newRemaining <= 0) {
        print(" Order fully paid! Showing success popup...");

        // Small delay to ensure state is updated
        Future.delayed(Duration(milliseconds: 100), () async {
          if (mounted && !_successPopupShown) {
            _successPopupShown = true;
            final boxData = await box.get(key);
            final cr =
            boxData is Map ? (boxData as Map)["coupon_response"] : null;
            final couponResponse = cr is Map
                ? Map<String, dynamic>.from(cr as Map)
                : <String, dynamic>{};

            // _showPaymentDialog(
            //   context,
            //   tenderAmount,
            //   changeAmount: changeAmount,
            //   showChange: changeAmount != null && changeAmount! > 0,
            //   couponResponse: couponResponse,
            // );
          }
        });
      }
    } catch (e, st) {
      print(" _savePaymentToHive crashed: $e");
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Offline save failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(OrderSummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the order items list has changed
    if (_orderItemsHaveChanged(oldWidget.orderItems, widget.orderItems)) {
      // Recalculate tax and gross/net values (these will update customer display)
      _recalculateTaxOnDiscountedItems();
      _recalculateGrossAndNetFromLineItemDiscounts();
      _recalculateEbtTotalAfterDiscount();  // if you use EBT
    }
  }


  bool _orderItemsHaveChanged(List<Map<String, dynamic>> oldItems, List<Map<String, dynamic>> newItems) {
    if (oldItems.length != newItems.length) return true;
    // Compare serialized JSON strings for deep equality
    final oldJson = jsonEncode(oldItems);
    final newJson = jsonEncode(newItems);
    return oldJson != newJson;
  }

  Future<void> _refreshPaymentData() async {
    // Recalculate balance from payment history
    await _calculateBalanceFromPaymentHistory();

    // Print updated summary
    await _printPaymentHistorySummary();

    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  //  IMPROVED: Save LocalPayment data to Hive offline box

  Future<void> _saveLocalPaymentToHive(LocalPayment payment) async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (kDebugMode) {
        print("🔵 [SAVE LOCAL PAYMENT] Starting for order: $key");
        print("🔵 Payment ID: ${payment.id}");
        print("🔵 Amount: ${payment.amount}");
        print("🔵 Method: ${payment.paymentMethod}");
      }

      // 1. Make sure the order exists in Hive
      if (!(await box.containsKey(key))) {
        print("Order not found → creating new entry: $key");
        await _createOfflineOrderEntry(key);
      }

      // 2. Read current data (FRESH COPY)
      final existingOrder = await box.get(key);
      if (existingOrder == null) {
        print("Failed to read order after creation");
        return;
      }

      var order = Map<String, dynamic>.from(existingOrder);

      print(
          " [SAVE] Current payments count: ${(order['payments'] as List?)?.length ?? 0}");

      // 3. Get existing payments array or create new one
      List<dynamic> payments = [];
      if (order['payments'] != null) {
        if (order['payments'] is List) {
          payments = List<Map<String, dynamic>>.from((order['payments'] as List)
              .map((e) => Map<String, dynamic>.from(e)));
        }
      }

      // 4. Create payment entry from LocalPayment model
      final Map<String, dynamic> paymentEntry = {
        'local_id': payment.id,
        'orderId': payment.orderId,
        'title': payment.title,
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'shiftId': payment.shiftId,
        'vendorId': payment.vendorId,
        'userId': payment.userId,
        'serviceType': payment.serviceType,
        'datetime': payment.datetime,
        'notes': payment.notes,
        'remainingBalance': payment.remainingBalance,
        'isSynced': payment.isSynced,
        'status': payment.status?.name ?? 'pending',
        'serverPaymentId': payment.serverPaymentId,
        'syncError': payment.syncError,
        'syncAttempts': payment.syncAttempts,
        'sunmiTxnId': payment.sunmiTxnId,
        'sunmiOrderId': payment.sunmiOrderId,
        'sunmiDeviceId': payment.sunmiDeviceId,
        'createdAt': payment.createdAt.toIso8601String(),
        'syncedAt': payment.syncedAt?.toIso8601String(),
        'addedToOrderAt': DateTime.now().toIso8601String(),
      };

      // 5. Add new payment to the array
      payments.add(paymentEntry);

      print(" [SAVE] Payments after adding: ${payments.length}");

      // 6. Calculate totals
      double totalPaid = (order['total_paid'] as num?)?.toDouble() ?? 0.0;
      totalPaid += payment.amount;

      double remaining = payment.remainingBalance;
      double change = 0.0;

      if (remaining <= 0) {
        change = remaining.abs();
        remaining = 0.0;
      }

      // 7. Update payment method counters
      double payCash = (order['pay_by_cash'] as num?)?.toDouble() ?? 0.0;
      double payCard = (order['pay_by_card'] as num?)?.toDouble() ?? 0.0;
      double payEbt = (order['pay_by_ebt'] as num?)?.toDouble() ?? 0.0;
      double payOther = (order['pay_by_other'] as num?)?.toDouble() ?? 0.0;

      switch (payment.paymentMethod.toLowerCase()) {
        case 'cash':
          payCash += payment.amount;
          break;
        case 'card':
          payCard += payment.amount;
          break;
        case 'ebt':
          payEbt += payment.amount;
          break;
        default:
          payOther += payment.amount;
      }

      // 8. Update order with ALL fields
      order['payments'] = payments;
      order['total_paid'] = totalPaid;
      order['remaining_balance'] = remaining;
      order['balance_amount'] = remaining;
      order['tender_amount'] = totalPaid;
      order['change_amount'] = change;
      order['pay_by_cash'] = payCash;
      order['pay_by_card'] = payCard;
      order['pay_by_ebt'] = payEbt;
      order['pay_by_other'] = payOther;
      order['last_payment_time'] = DateTime.now().toIso8601String();
      order['order_status'] = remaining <= 0 ? 'processing' : 'pending_offline';
      order['updated_at'] = DateTime.now().toIso8601String();

      // Save lastPayment info
      if (_lastPayment != null) {
        order['lastPayment'] = _lastPayment!.toJson();
      }

      // 9.  WRITE BACK TO HIVE & SQLITE
      await box.put(key, order);
      if (orderId != null && orderId! > 0) {
        unawaited(OfflineHelper.updateOfflineOrderStatus(
          orderId!,
          order['order_status']?.toString() ?? (remaining <= 0 ? 'processing' : 'pending_offline'),
          paymentMethod: payment.paymentMethod,
        ));
      }

      print(" [SAVE] Written to Hive successfully");

      // 10. Verify it was saved
      final verification = await box.get(key);
      if (verification != null) {
        final verifyPayments = verification['payments'] as List?;
        print(" [VERIFY] Payments in Hive now: ${verifyPayments?.length ?? 0}");
      }

      // Debug output
      if (kDebugMode) {
        print('''
═══════════════════════════════════════════════════════
 LOCAL PAYMENT SAVED TO HIVE
═══════════════════════════════════════════════════════
Order:          $key
Payment ID:     ${payment.id}
Method:         ${payment.paymentMethod}
Amount:         \$${payment.amount.toStringAsFixed(2)}
Payments now:   ${payments.length}
Total paid:     \$${totalPaid.toStringAsFixed(2)}
Remaining:      \$${remaining.toStringAsFixed(2)}
Change:         \$${change.toStringAsFixed(2)}
Status:         ${order['order_status']}

 PAYMENT ENTRY:
${JsonEncoder.withIndent('  ').convert(paymentEntry)}
═══════════════════════════════════════════════════════
''');
      }

      // 11. Update UI
      if (mounted) {
        setState(() {
          tenderAmount = totalPaid;
          balanceAmount = remaining;
          changeAmount = change;
          payByCash = payCash;
          payByCard = payCard;
          payByEbt = payEbt;
          payByOther = payOther;
          orderStatus = order['order_status'];
          isPaymentStarted = true;
        });
      }
    } catch (e, st) {
      print(" _saveLocalPaymentToHive crashed: $e");
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save payment to offline storage: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePaymentLocally(double amount) async {
    if (kDebugMode) {
      print("\n" + "🟦" * 30);
      print("💾 STARTING LOCAL PAYMENT SAVE");
      print("🟦" * 30);
      print("Amount: \$${amount.toStringAsFixed(2)}");
      print("Method: $selectedPaymentMethod");
      print("Order ID: $orderId");
      print("Balance Before: \$${balanceAmount.toStringAsFixed(2)}");
    }

    final String datetime =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final localPayment = LocalPayment(
      orderId: orderId ?? 0,
      title: selectedPaymentMethod!,
      amount: widget.netPayable,
      paymentMethod: selectedPaymentMethod!,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetime,
      notes: 'offline payment - ${DateTime.now().toIso8601String()}',
      isSynced: false,
      createdAt: DateTime.now(),
      remainingBalance: balanceAmount - widget.netPayable,
      // status: balanceAmount - widget.netPayable <= 0 ? PaymentDbStatus.completed : PaymentDbStatus.pending,
      status: PaymentDbStatus.pending, // line in _callCreatePaymentAPI
    );

    try {
      // Save to Isar
      final savedPayment =
      await LocalPaymentDBHelper.instance.savePayment(localPayment);

      if (kDebugMode) {
        print("\n PAYMENT SAVED TO ISAR SUCCESSFULLY!");
        print("Local Payment ID: ${savedPayment.id}");
        print("============================================================");
        print("LocalPayment {");
        print("  id: ${savedPayment.id},");
        print("  orderId: ${savedPayment.orderId},");
        print("  title: \"${savedPayment.title}\",");
        print("  amount: \$${savedPayment.amount.toStringAsFixed(2)},");
        print("  paymentMethod: \"${savedPayment.paymentMethod}\",");
        print("  shiftId: ${savedPayment.shiftId},");
        print("  vendorId: ${savedPayment.vendorId},");
        print("  userId: ${savedPayment.userId},");
        print("  serviceType: \"${savedPayment.serviceType}\",");
        print("  datetime: \"${savedPayment.datetime}\",");
        print("  notes: \"${savedPayment.notes}\",");
        print(
            "  remainingBalance: \$${savedPayment.remainingBalance.toStringAsFixed(2)},");
        print("  isSynced: ${savedPayment.isSynced},");
        print("  status: ${savedPayment.status?.name},");
        print("  serverPaymentId: ${savedPayment.serverPaymentId},");
        print("  syncError: ${savedPayment.syncError},");
        print("  syncAttempts: ${savedPayment.syncAttempts},");
        print("  sunmiTxnId: ${savedPayment.sunmiTxnId},");
        print("  sunmiOrderId: ${savedPayment.sunmiOrderId},");
        print("  sunmiDeviceId: ${savedPayment.sunmiDeviceId},");
        print("  createdAt: ${savedPayment.createdAt},");
        print("  syncedAt: ${savedPayment.syncedAt}");
        print("}");
        print("============================================================");
      }

      //  NEW: Save to Hive offline box
      await _saveLocalPaymentToHive(savedPayment);

      // Update local state
      _updateLocalPaymentState(amount, savedPayment);

      // Show success popup
      await _showPaymentSuccessPopup(amount, savedPayment);

      // Schedule sync
      _schedulePaymentSync(savedPayment);

      if (kDebugMode) {
        print("🟦" * 30 + "\n");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("\n❌ ERROR SAVING PAYMENT");
        print("Error: $e");
        print("Stack: $stackTrace");
        print("🟦" * 30 + "\n");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save payment: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

//  NEW: Create complete offline order entry structure
  Future<void> _createOfflineOrderEntry(String key) async {
    try {
      final box = StorageProvider.offlineOrders;
      final now = DateTime.now();
      final timestamp = now.toIso8601String();

      final orderEntry = {
        'order_id': orderId,
        'offline_order_id': widget.offlineOrderId,
        'created_at': timestamp,
        'updated_at': timestamp,

        // Order items
        'order_items':
        orderItems.map((item) => Map<String, dynamic>.from(item)).toList(),

        // Financial details
        'gross_total': grossTotal,
        'orderDiscount': discount,
        'merchantDiscount': merchantDiscount,
        'order_tax': tax,
        'cashback_fee': cashbackFee,
        'ebtTotal': ebtTotal,
        'originalEbt': ebtTotal, // Store original EBT
        'redeemed_value': redeemedValue,
        'net_payable': computedNetPayable,

        // Payment tracking
        'payments': [],
        'total_paid': 0.0,
        'remaining_balance': computedNetPayable,
        'balance_amount': computedNetPayable,
        'tender_amount': 0.0,
        'change_amount': 0.0,
        'pay_by_cash': 0.0,
        'pay_by_card': 0.0,
        'pay_by_ebt': 0.0,
        'pay_by_other': 0.0,

        // Order metadata
        'order_status': TextConstants.processing,
        'order_date': _displayDate,
        'order_time': _displayTime,
        'user_id': userId,
        'user_name': userDisplayName,
        'user_role': userRole,

        // Loyalty & coupons
        'loyaltyContact': '',
        'available_points': 0,
        'coupon_response': {},

        // Sync status
        'is_synced': false,
        'last_payment_time': null,
      };

      await box.put(key, orderEntry);

      if (kDebugMode) {
        print("✅ Created new offline order entry for ID: $key");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error creating offline order entry: $e");
      }
    }
  }

//  IMPROVED: Update _updateHivePaymentData to use new structure
  Future<void> _updateHivePaymentData(LocalPayment payment) async {
    try {
      if (kDebugMode) {
        print("Updating Hive payment + price data...");
      }

      await _savePaymentToHive(
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        transactionId: "local_${payment.id}",
        localPayment: payment,
      );

      // 🔁 Re-read updated order from Hive (source of truth)
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (!(await box.containsKey(key))) return;

      final rawUpdated = await box.get(key);
      final updatedOrder =
      Map<String, dynamic>.from(rawUpdated is Map ? rawUpdated : {});

      //  Extract updated values
      final double updatedPaid =
          (updatedOrder['total_paid'] as num?)?.toDouble() ?? 0.0;
      final double updatedBalance =
          (updatedOrder['remaining_balance'] as num?)?.toDouble() ?? 0.0;
      final double updatedChange =
          (updatedOrder['change_amount'] as num?)?.toDouble() ?? 0.0;

      final double updatedGrossTotal =
          (updatedOrder['gross_total'] as num?)?.toDouble() ?? grossTotal;
      final double updatedNetTotal =
          (updatedOrder['net_total'] as num?)?.toDouble() ?? 0.0;
      final double updatedPayable =
          (updatedOrder['payable_amount'] as num?)?.toDouble() ?? 0.0;

      final String updatedStatus =
          updatedOrder['order_status'] ?? TextConstants.pending;

      //  Update UI state AFTER Hive is correct
      if (mounted) {
        setState(() {
          tenderAmount = updatedPaid;
          balanceAmount = updatedBalance;
          changeAmount = updatedChange;

          grossTotal = updatedGrossTotal;
          netTotal = updatedNetTotal;
          payableAmount = updatedPayable;

          orderStatus = updatedStatus;
          isPaymentStarted = true;
        });
      }

      if (kDebugMode) {
        print(" Hive payment + price updated successfully");
        print("💰 Paid: $updatedPaid");
        print("📉 Balance: $updatedBalance");
        print("🔁 Change: $updatedChange");
        print("🧾 Payable: $updatedPayable");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("❌ Failed to update Hive payment data: $e");
        print(stackTrace);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update payment"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _loadOfflineOrderData() async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (!(await box.containsKey(key))) {
        if (kDebugMode) {
          print(" No offline order found for ID: $key");
        }
        return null;
      }

      final rawData = await box.get(key);
      final data = Map<String, dynamic>.from(rawData is Map ? rawData : {});

      if (kDebugMode) {
        print("\n" + "📂" * 30);
        print("LOADED OFFLINE ORDER DATA");
        print("📂" * 30);
        print("Order ID: $key");
        print(
            "Total Paid: \$${(data['total_paid'] ?? 0.0).toStringAsFixed(2)}");
        print(
            "Balance: \$${(data['remaining_balance'] ?? 0.0).toStringAsFixed(2)}");
        print("Payments Count: ${(data['payments'] as List?)?.length ?? 0}");
        print("Status: ${data['order_status']}");
        print("📂" * 30 + "\n");
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error loading offline order: $e");
      }
      return null;
    }
  }

//  NEW: Get payment history from Hive
  Future<List<Map<String, dynamic>>> _getPaymentHistoryFromHive() async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (!(await box.containsKey(key))) {
        return [];
      }

      final rawExisting = await box.get(key);
      final existing =
      Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});
      final payments = existing['payments'] as List<dynamic>? ?? [];

      return payments.map((p) => Map<String, dynamic>.from(p)).toList();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error getting payment history: $e");
      }
      return [];
    }
  }

//  NEW: Clear offline order after completion
  Future<void> _clearOfflineOrder() async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (await box.containsKey(key)) {
        await box.delete(key);

        if (kDebugMode) {
          print("️ Cleared offline order: $key");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error clearing offline order: $e");
      }
    }
  }

// Update _updateLocalPaymentState to use correct calculation:
  void _updateLocalPaymentState(double amount, LocalPayment payment) {
    if (kDebugMode) {
      print(
          "\n PROCESSING PAYMENT #${(_lastPaymentDetails?['paymentNumber'] ?? 0) + 1}");
      print("=" * 50);
    }

    double balanceBefore = balanceAmount;
    double newBalance = balanceAmount - amount;
    double change = 0.0;

    if (newBalance < 0) {
      change = newBalance.abs();
      newBalance = 0.0;
    }

    // Calculate payment number
    int paymentNumber = (_lastPaymentDetails?['paymentNumber'] ?? 0) + 1;
    double totalPaid = tenderAmount + amount;

    print("💰 PAYMENT DETAILS:");
    print("  Payment #: $paymentNumber");
    print("  Method: ${selectedPaymentMethod}");
    print("  Amount: \$${amount.toStringAsFixed(2)}");
    print("  Balance Before Payment: \$${balanceBefore.toStringAsFixed(2)}");
    print("  Balance After Payment: \$${newBalance.toStringAsFixed(2)}");
    print("  Total Paid So Far: \$${totalPaid.toStringAsFixed(2)}");
    print("  Change: \$${change.toStringAsFixed(2)}");
    print("  Complete: ${newBalance <= 0}");

    // Update payment method totals
    double newPayByCash = payByCash;
    double newPayByCard = payByCard;
    double newPayByEbt = payByEbt;
    double newPayByOther = payByOther;

    switch (selectedPaymentMethod!.toLowerCase()) {
      case 'cash':
        newPayByCash += amount;
        break;
      case 'card':
        newPayByCard += amount;
        break;
      case 'ebt':
        newPayByEbt += amount;
        break;
      default:
        newPayByOther += amount;
    }

    setState(() {
      isPaymentStarted = true;
      paidAmount = amount;
      paymentId = "local_${payment.id}";
      _lastPayment = LastPaymentInfo(
        method: selectedPaymentMethod!,
        amount: amount,
        paymentId: paymentId,
        sunmiTxnId: null,
      );

      // Update amounts
      tenderAmount = totalPaid;
      balanceAmount = newBalance;

      // CRITICAL: Store progression info
      _lastPaymentDetails = {
        'amount': amount,
        'method': selectedPaymentMethod!,
        'remainingBalance': newBalance,
        'previousBalance': balanceBefore, // Store previous balance
        'datetime': DateTime.now().toIso8601String(),
        'paymentId': "local_${payment.id}",
        'timestamp': DateTime.now(),
        'totalPaid': totalPaid, // Store total paid
        'paymentNumber': paymentNumber, // Store payment number
      };

      // Set current payment remaining
      if (newBalance > 0) {
        _currentPaymentRemainingBalance = newBalance;
      } else {
        _currentPaymentRemainingBalance = null;
      }

      // Update payment method totals
      payByCash = newPayByCash;
      payByCard = newPayByCard;
      payByEbt = newPayByEbt;
      payByOther = newPayByOther;

      changeAmount = change;
    });

    _updateHivePaymentData(payment);

    if (kDebugMode) {
      print("\n UPDATED STATE:");
      print("  Tender Amount: \$${tenderAmount.toStringAsFixed(2)}");
      print("  Balance Amount: \$${balanceAmount.toStringAsFixed(2)}");
      print(
          "  Current Payment Remaining: ${_currentPaymentRemainingBalance != null ? '\$${_currentPaymentRemainingBalance!.toStringAsFixed(2)}' : 'None'}");
      print("  Previous Balance: \$${balanceBefore.toStringAsFixed(2)}");
      print("  Payment Method Totals: Cash=\$${payByCash.toStringAsFixed(2)}");
      print("  " + "=" * 50 + "\n");
    }
  }

  void _autoSelectPaymentMethodAndFillAmount() {
    print("Starting auto-select payment. Current balanceAmount: $balanceAmount, " +
        "ebtTotal: $ebtTotal, Current Payment Remaining: $_currentPaymentRemainingBalance");

    //  FIX: Only auto-fill if there's a current payment remaining
    if (_currentPaymentRemainingBalance != null &&
        _currentPaymentRemainingBalance! > 0) {
      double amountToUse = _currentPaymentRemainingBalance!;

      //  Rule: If there's EBT balance, preselect EBT
      if (ebtTotal > 0 && amountToUse <= ebtTotal) {
        print(
            "EBT balance available. Preselecting EBT. Amount to use: $amountToUse");
        _selectPaymentMethod(
          TextConstants.ebtText,
          maxAllowedAmount: amountToUse,
        );
      }
      // Otherwise preselect Cash
      else {
        print(
            "No EBT or balance > EBT. Preselecting Cash. Amount to use: $amountToUse");
        _selectPaymentMethod(
          TextConstants.cash,
          maxAllowedAmount: amountToUse,
        );
      }

      // Auto-fill the amount
      print("Auto-filling current payment remaining balance: $amountToUse");
      _rawAmount = (amountToUse * 100).round();
      amountController.text =
      '${TextConstants.currencySymbol}${amountToUse.toStringAsFixed(2)}';

      setState(() {
        _isAmountEntered = true;
        _amountErrorText = null;
      });
    } else if (balanceAmount > 0) {
      // This is for fresh payments (no current payment remaining)
      print("No current payment remaining. Using main balance: $balanceAmount");

      // Rule: If there's EBT balance, preselect EBT
      if (ebtTotal > 0 && balanceAmount <= ebtTotal) {
        double amountToUse = min(balanceAmount, ebtTotal);
        print(
            "EBT balance available. Preselecting EBT. Amount to use: $amountToUse");
        _selectPaymentMethod(
          TextConstants.ebtText,
          maxAllowedAmount: amountToUse,
        );
      }
      // Otherwise preselect Cash
      else {
        print(
            "No EBT or balance > EBT. Preselecting Cash. Amount to use: $balanceAmount");
        _selectPaymentMethod(
          TextConstants.cash,
          maxAllowedAmount: balanceAmount,
        );
      }

      // Auto-fill the amount
      print("Auto-filling main balance: $balanceAmount");
      // _autoFillRemainingBalance();
    } else {
      print(
          "Balance amount is zero or negative. No payment method auto-selected.");
    }
  }

  // ADD THIS NEW METHOD - does not change any existing code
  void _recalculateEbtTotalAfterDiscount() {
    final double originalEbt = widget.ebtAmount;
    if (originalEbt <= 0) return;

    final double originalNetPayable = widget.netPayable > 0
        ? widget.netPayable
        : (widget.grossTotal + widget.orderTax);

    if (originalNetPayable <= 0) return;

    // Calculate proportion of EBT in original order
    final double ebtRatio = originalEbt / originalNetPayable;

    // Apply same ratio to new net payable
    final double newEbtTotal = (computedNetPayable * ebtRatio)
        .clamp(0.0, originalEbt);

    // Only update remaining EBT (not already paid portion)
    final double alreadyPaidEbt = payByEbt;
    ebtTotal = (newEbtTotal - alreadyPaidEbt).clamp(0.0, double.infinity);
  }

// Show success popup
  Future<void> _showPaymentSuccessPopup(
      double amount, LocalPayment payment) async {
    final bool isPaymentComplete = balanceAmount <= 0;

    //  Clear the payment-specific balance display when order is fully paid
    if (isPaymentComplete) {
      setState(() {
        _currentPaymentRemainingBalance = null;
        _lastPaymentDetails = null;
      });
    }

    if (kDebugMode) {
      print("\n PAYMENT STATUS");
      print("   Balance: \$${balanceAmount.toStringAsFixed(2)}");
      print("   Complete: $isPaymentComplete");
      print("   Current Payment Remaining: $_currentPaymentRemainingBalance");
      print("   Popup Shown: $_successPopupShown\n");
    }

    if (isPaymentComplete && !_successPopupShown) {
      _successPopupShown = true;
      // ✅ ADD THIS LINE (CRITICAL FIX)
      // await CustomerDisplayService.showThankYou();
      // ✅ STEP 2: CLEAR ACTIVE ORDER (CRITICAL)
      await orderHelper.setActiveOrder(null);

      // ✅ STEP 3: RESET DISPLAY (FINAL STATE)
      await CustomerDisplayService.resetDisplay();
      unawaited(_publishMqttThankYouThenWelcome());
      print("✅ Payment complete → display reset");
      // ✅ SHOW SUCCESS SNACKBAR
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order successfully completed"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();
      final boxDataKey = await box.get(key);
      final cr =
      boxDataKey is Map ? (boxDataKey as Map)["coupon_response"] : null;
      final couponResponse = cr is Map
          ? Map<String, dynamic>.from(cr as Map)
          : <String, dynamic>{};

      _showPaymentDialog(
        context,
        tenderAmount,
        changeAmount: changeAmount,
        showChange: changeAmount != null && changeAmount! > 0,
        couponResponse: couponResponse,
      );
    } else if (balanceAmount > 0) {
      //  AUTO-FILL BEFORE SHOWING PARTIAL DIALOG
      // _autoFillRemainingBalance();
      _showPartialPaymentDialog(context, amount);
    }
  }

//  Schedule sync
  Future<void> _schedulePaymentSync(LocalPayment payment) async {
    if (kDebugMode) {
      print("\n⏰ SCHEDULING SYNC");
      print("   Payment ID: ${payment.id}");
      print("   Delay: 500ms\n");
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _syncPaymentToServer(payment);
    });
  }

//  Sync to server
  Future<void> _syncPaymentToServer(LocalPayment payment) async {
    if (kDebugMode) {
      print("\n" + "🔄" * 30);
      print("SYNCING PAYMENT TO SERVER");
      print("🔄" * 30);
      print("Local ID: ${payment.id}");
      print("Order ID: ${payment.orderId}");
      print("Amount: \$${payment.amount.toStringAsFixed(2)}");
      print("Method: ${payment.paymentMethod}");
    }

    final paymentRequest = PaymentRequestModel(
      title: payment.title,
      orderId: payment.orderId,
      amount: payment.amount,
      paymentMethod: payment.paymentMethod,
      shiftId: payment.shiftId,
      vendorId: payment.vendorId,
      userId: payment.userId,
      serviceType: payment.serviceType,
      datetime: payment.datetime,
      notes: payment.notes,
    );

    // paymentBloc.createPayment(paymentRequest);

    StreamSubscription? subscription;
    subscription = paymentBloc.createPaymentStream.listen(
          (paymentResponse) async {
        if (paymentResponse.status == Status.COMPLETED &&
            paymentResponse.data != null) {
          final serverPaymentId = paymentResponse.data!.paymentId;

          if (kDebugMode) {
            print("\n SYNC SUCCESS!");
            print("   Local ID: ${payment.id}");
            print("   Server ID: $serverPaymentId");
          }

          await LocalPaymentDBHelper.instance.markAsSynced(
            payment.id,
            serverPaymentId ?? 0,
          );

          if (mounted) {
            setState(() {
              paymentId = serverPaymentId.toString();
            });
          }

          _lastPayment = LastPaymentInfo(
            method: payment.paymentMethod,
            amount: payment.amount,
            paymentId: serverPaymentId.toString(),
            sunmiTxnId: null,
          );

          final box = StorageProvider.offlineOrders;
          final key = (orderId ?? 0).toString();
          final hasKey = await box.containsKey(key);
          final raw = hasKey ? await box.get(key) : null;
          final existing = Map<String, dynamic>.from(raw is Map ? raw : {});

          existing["lastPayment"] = _lastPayment!.toJson();
          existing["serverPaymentId"] = serverPaymentId;
          existing["localPaymentSynced"] = true;
          await box.put(key, existing);

          // Print updated payment
          await LocalPaymentDBHelper.instance
              .getLastPaymentForOrder(payment.orderId);

          if (kDebugMode) {
            print("🔄" * 30 + "\n");
          }
        } else if (paymentResponse.status == Status.ERROR) {
          if (kDebugMode) {
            print("\n❌ SYNC FAILED");
            print("   Error: ${paymentResponse.message}");
          }

          await LocalPaymentDBHelper.instance.updateSyncError(
            payment.id,
            paymentResponse.message ?? 'Unknown error',
          );

          await LocalPaymentDBHelper.instance.getUnsyncedPayments();

          if (kDebugMode) {
            print("🔄" * 30 + "\n");
          }

          if (mounted && Misc.showDebugSnackBar) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Payment saved locally. Will sync when online."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        subscription?.cancel();
      },
    );
  }

  Future<void> retrySyncUnsyncedPayments() async {
    final unsyncedPayments =
    await LocalPaymentDBHelper.instance.getUnsyncedPayments();

    if (unsyncedPayments.isEmpty) {
      if (kDebugMode) {
        print(" No unsynced payments\n");
      }
      return;
    }

    if (kDebugMode) {
      print("\n🔁 RETRYING ${unsyncedPayments.length} PAYMENTS");
    }

    for (final payment in unsyncedPayments) {
      if ((payment.syncAttempts ?? 0) > 5) {
        if (kDebugMode) {
          print("⏭ Skipping ID ${payment.id} (too many attempts)");
        }
        continue;
      }

      await _syncPaymentToServer(payment);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _fetchShiftId() async {
    final data = await UserDbHelper().getUserData();
    if (data != null && data["shift_id"] != null) {
      setState(() {
        shiftId = data["shift_id"];
      });
    }
  }

  void _selectPaymentMethod(
      String method, {
        bool autoFillAmount = false,
        double? maxAllowedAmount,
      }) {
    setState(() {
      selectedPaymentMethod = method;

      if (autoFillAmount && maxAllowedAmount != null) {
        _rawAmount = (maxAllowedAmount * 100).toInt();
        amountController.text =
        '${TextConstants.currencySymbol}${maxAllowedAmount.toStringAsFixed(2)}';
        _isAmountEntered = true;
        _amountErrorText = null;
      }
    });
  }

  void _onQuickAmountSelected(double amount) {
    setState(() {
      double allowedAmount = amount;

      // ---------- EBT LIMIT ----------
      if (selectedPaymentMethod == TextConstants.ebtText) {
        allowedAmount = min(amount, ebtTotal);
      }

      // ---------- CARD LIMIT ----------
      else if (selectedPaymentMethod == TextConstants.card) {
        allowedAmount = min(amount, balanceAmount);
      }

      // Convert to paise/cents
      _rawAmount = (allowedAmount * 100).round();

      amountController.text =
      '${TextConstants.currencySymbol}${allowedAmount.toStringAsFixed(2)}';

      _amountErrorText = null;
      _isAmountEntered = _rawAmount > 0;
    });
  }

  void _handlePay() {
    if (balanceAmount <= 0 &&
        (double.tryParse(amountController.text
            .replaceAll(TextConstants.currencySymbol, '')
            .trim()) ??
            0) >
            0) {
      print(
          "⚠️ DEFENSIVE RESET: balance=0 but amount entered > 0 → forcing reset after possible void");
      setState(() {
        _successPopupShown = false;
        _currentPaymentRemainingBalance = null;
        isPaymentStarted = false;
      });
      _calculateBalanceFromPaymentHistory();
    }

    final cleanAmount = amountController.text
        .replaceAll(TextConstants.currencySymbol, '')
        .trim();

    final double amount = double.tryParse(cleanAmount) ?? 0.0;
    final int enteredCents = (amount * 100).round();
    final int ebtCents = (ebtTotal * 100).round();

    // Basic validation
    if (enteredCents <= 0 && computedNetPayable > 0) {
      setState(() {
        _amountErrorText = TextConstants.amountValidation;
      });
      return;
    }
    _amountErrorText = null;

    // EBT validation
    if (selectedPaymentMethod == TextConstants.ebtText) {
      if (ebtCents <= 0) {
        setState(() {
          _amountErrorText = "No EBT balance available";
        });
        return;
      }
      if (enteredCents > ebtCents) {
        setState(() {
          _amountErrorText =
          "Amount cannot exceed available EBT balance (\$${ebtTotal.toStringAsFixed(2)})";
        });
        return;
      }
    }


    // ✅ All payment methods (Cash, Card, Wallet, EBT) now call the local storage API
    _callCreatePaymentAPI(); // uses validated amount
    _resetAmountAfterPay();
  }

//  ADD THIS METHOD (you might already have it, but here it is for reference)
  void _resetAmountAfterPay() {
    _rawAmount = 0;
    amountController.text = '${TextConstants.currencySymbol}0.00';
    setState(() {
      _isAmountEntered = false;
      _amountErrorText = null;
    });
  }

  //  UPDATED - Add Payment to Offline Order with Success Message
  Future<void> _addPaymentToOfflineOrder(LocalPayment payment) async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (!(await box.containsKey(key))) {
        if (kDebugMode) {
          print(" Offline order not found for key: $key");
        }

        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error: Order not found"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Get existing order
      final rawExisting = await box.get(key);
      final existing =
      Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});

      // Get existing payments array or create new one
      List<dynamic> payments = existing['payments'] ?? [];

      // Get current timestamp
      final now = DateTime.now();
      final timestamp = now.toIso8601String();

      // Add new payment with timestamp
      payments.add({
        'id': payment.id,
        'orderId': payment.orderId,
        'title': payment.title,
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'shiftId': payment.shiftId,
        'vendorId': payment.vendorId,
        'userId': payment.userId,
        'serviceType': payment.serviceType,
        'datetime': payment.datetime,
        'notes': payment.notes,
        'remainingBalance': payment.remainingBalance,
        'isSynced': payment.isSynced,
        'status': payment.status?.name,
        'serverPaymentId': payment.serverPaymentId,
        'syncError': payment.syncError,
        'syncAttempts': payment.syncAttempts,
        'sunmiTxnId': payment.sunmiTxnId,
        'sunmiOrderId': payment.sunmiOrderId,
        'sunmiDeviceId': payment.sunmiDeviceId,
        'createdAt': payment.createdAt.toIso8601String(),
        'syncedAt': payment.syncedAt?.toIso8601String(),
        'addedToOrderAt': timestamp, // Track when added to order
      });

      // Update order with new payments array
      existing['payments'] = payments;

      // Also update totals
      final currentTotalPaid =
          (existing['total_paid'] as num?)?.toDouble() ?? 0.0;
      existing['remaining_balance'] = payment.remainingBalance;
      existing['total_paid'] = currentTotalPaid + payment.amount;
      existing['last_payment_time'] = timestamp; //  Track last payment time

      // Save back to Hive
      await box.put(key, existing);

      if (kDebugMode) {
        print(" Payment added to offline order successfully!");
        print("   Order ID: $key");
        print("   Payment ID: ${payment.id}");
        print("   wooo ID: ${payment.serverPaymentId}");

        print("   Payment Method: ${payment.paymentMethod}");
        print("   Amount: \$${payment.amount.toStringAsFixed(2)}");
        print("   Time: $timestamp");
        print("   Total Payments: ${payments.length}");
        print("   Total Paid: \$${existing['total_paid'].toStringAsFixed(2)}");
        print(
            "   Remaining Balance: \$${payment.remainingBalance.toStringAsFixed(2)}");
        print("   Status: ${payment.status?.name}");
      }

      //  Show success message to user
      if (mounted) {
        final bool isPartial = payment.remainingBalance > 0;
        final String statusText = isPartial ? "Partial" : "Full";
        final String timeText = DateFormat('HH:mm:ss').format(now);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  " $statusText Payment Recorded",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Amount: \$${payment.amount.toStringAsFixed(2)} (${payment.paymentMethod})",
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  "Time: $timeText",
                  style: const TextStyle(fontSize: 12),
                ),
                if (isPartial)
                  Text(
                    "Remaining: \$${payment.remainingBalance.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.yellow,
                    ),
                  ),
              ],
            ),
            backgroundColor: isPartial ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(" Error adding payment to offline order: $e");
        print("Stack trace: $stackTrace");
      }

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving payment: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

//  OPTIONAL - View Payment History with Timestamps
  Future<void> _showPaymentHistory() async {
    final payments = await _getPaymentsFromOfflineOrder();

    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No payments recorded yet"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment History"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              final amount = payment['amount'] ?? 0.0;
              final method = payment['paymentMethod'] ?? 'Unknown';
              final timeStr =
                  payment['addedToOrderAt'] ?? payment['createdAt'] ?? '';

              DateTime? time;
              try {
                time = DateTime.parse(timeStr);
              } catch (e) {
                time = null;
              }

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Method: $method'),
                      if (time != null)
                        Text(
                          'Time: ${DateFormat('HH:mm:ss').format(time)}',
                          style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: Icon(
                    payment['isSynced'] == true
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: payment['isSynced'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // OPTIONAL HELPER - Get Payments from Offline Order
  Future<List<Map<String, dynamic>>> _getPaymentsFromOfflineOrder() async {
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();

      if (!(await box.containsKey(key))) {
        return [];
      }

      final rawExisting = await box.get(key);
      final existing =
      Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});
      final payments = existing['payments'] as List<dynamic>? ?? [];

      return payments.map((p) => Map<String, dynamic>.from(p)).toList();
    } catch (e) {
      if (kDebugMode) {
        print(" Error getting payments from offline order: $e");
      }
      return [];
    }
  }

  /// Fills EBT / variant fields on summary lines from offline `products` when SQLite rows omit them (pending orders).
  Future<void> _enrichOrderItemsFromHiveProducts() async {
    final box = StorageProvider.offlineOrders;
    final wantIds = <int>{
      if (widget.offlineOrderId != null) widget.offlineOrderId!,
      if (orderId != null && orderId != 0) orderId!,
    };

    Map<String, dynamic>? hiveOrder;

    for (final id in wantIds) {
      final raw = await box.get(id.toString());
      if (raw is Map) {
        hiveOrder = Map<String, dynamic>.from(raw);
        break;
      }
    }

    if (hiveOrder == null && wantIds.isNotEmpty) {
      try {
        final all = await box.toMap();
        for (final entry in all.values) {
          if (entry is! Map) continue;
          final m = Map<String, dynamic>.from(entry);
          final oid = m['order_id'] ?? m['id'] ?? m[AppDBConst.orderServerId];
          final int? o = oid is int ? oid : int.tryParse(oid?.toString() ?? '');
          if (o != null && wantIds.contains(o)) {
            hiveOrder = m;
            break;
          }
        }
      } catch (_) {}
    }

    _mergeOrderSummaryLineItemsFromHive(orderItems, hiveOrder);
    await _mergeOrderSummaryLineItemsFromProductCache(orderItems);
  }


  // === LOYALTY POINTS CALCULATION (FIXED + DEBUG) ===
// FIX: Added Hive fallback so meta_data missing from orderItems is recovered
//      from the offline order's products array. All other code unchanged.
  void _calculateAndPrintLoyaltyPoints() async {
    if (orderItems.isEmpty) {
      print("⚠️ [Loyalty] No order items found");
      return;
    }

    // --- FIX: Pre-load Hive products so we can recover meta_data ---
    Map<String, List<Map<String, dynamic>>> _hiveMetaByName = {};
    Map<String, List<Map<String, dynamic>>> _hiveMetaBySku  = {};

    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.offlineOrderId?.toString() ??
          widget.orderId?.toString() ??
          orderId?.toString() ??
          "";

      if (orderKey.isNotEmpty) {
        final rawOrder = await box.get(orderKey);
        if (rawOrder is Map) {
          final hiveOrder = Map<String, dynamic>.from(rawOrder);
          final hiveProducts = (hiveOrder['products'] as List?) ?? [];

          for (final p in hiveProducts) {
            if (p is! Map) continue;
            final product = Map<String, dynamic>.from(p);
            final metaRaw = product['meta_data'] ?? product['metaData'];
            if (metaRaw == null) continue;

            List<Map<String, dynamic>> metaList = [];
            if (metaRaw is List) {
              for (final m in metaRaw) {
                if (m is Map) metaList.add(Map<String, dynamic>.from(m));
              }
            }
            if (metaList.isEmpty) continue;

            // Index by name (lowercase)
            final name = (product['name'] ?? product['product_name'] ?? '')
                .toString().toLowerCase().trim();
            if (name.isNotEmpty) {
              _hiveMetaByName[name] = metaList;
            }

            // Index by sku (lowercase)
            final sku = (product['sku'] ?? product['item_sku'] ?? '')
                .toString().toLowerCase().trim();
            if (sku.isNotEmpty) {
              _hiveMetaBySku[sku] = metaList;
            }
          }
          print('🔍 [Loyalty] Hive fallback loaded: '
              '${_hiveMetaByName.length} by name, '
              '${_hiveMetaBySku.length} by sku');
        }
      }
    } catch (e) {
      print('⚠️ [Loyalty] Hive pre-load error (non-fatal): $e');
    }
    // --- END FIX ---

    int totalLoyaltyPoints = 0;

    for (var item in orderItems) {
      final int qty =
      (item['items_count'] ?? item['quantity'] ?? 1).toInt();

      int itemPoints = 0;

      // Step 1: try meta_data already on the item (original logic, unchanged)
      final meta = item['meta_data'];
      if (meta is List) {
        for (var m in meta) {
          if (m is Map && m['key'] == '_product_loyalty_points') {
            itemPoints = int.tryParse(m['value']?.toString() ?? '0') ?? 0;
            break;
          }
        }
      } else if (meta is Map && meta['key'] == '_product_loyalty_points') {
        itemPoints = int.tryParse(meta['value']?.toString() ?? '0') ?? 0;
      }

      // --- FIX: Step 2 – fall back to Hive when item has no meta_data ---
      if (itemPoints == 0 && (_hiveMetaByName.isNotEmpty || _hiveMetaBySku.isNotEmpty)) {
        final itemName = (item['item_name'] ?? item['fast_key_item_name'] ?? '')
            .toString().toLowerCase().trim();
        final itemSku  = (item['sku'] ?? item['item_sku'] ?? '')
            .toString().toLowerCase().trim();

        List<Map<String, dynamic>>? fallbackMeta;
        if (itemName.isNotEmpty) fallbackMeta = _hiveMetaByName[itemName];
        if (fallbackMeta == null && itemSku.isNotEmpty) {
          fallbackMeta = _hiveMetaBySku[itemSku];
        }

        if (fallbackMeta != null) {
          for (final m in fallbackMeta) {
            if (m['key'] == '_product_loyalty_points') {
              itemPoints =
                  int.tryParse(m['value']?.toString() ?? '0') ?? 0;
              print('🔄 [Loyalty] Recovered meta from Hive for "$itemName" '
                  '→ $itemPoints pts');
              break;
            }
          }
        }
      }
      // --- END FIX ---

      final linePoints = qty * itemPoints;
      item['loyalty_points'] = linePoints; // save per item (unchanged)

      if (linePoints > 0) {
        final itemName = (item['item_name'] ??
            item['fast_key_item_name'] ??
            'Unknown')
            .toString();
        print(
            '🔹 [Loyalty] $itemName × $qty = $linePoints pts (per item: $itemPoints)');
      }

      totalLoyaltyPoints += linePoints;
    }

    // Store total on order level (unchanged)
    _order['total_loyalty_points'] = totalLoyaltyPoints;

    if (totalLoyaltyPoints > 0) {
      print(
          '🛒 [Loyalty] ORDER TOTAL LOYALTY POINTS = $totalLoyaltyPoints pts');
    } else {
      print('ℹ️ [Loyalty] No loyalty points found in this order');
    }

    // Refresh UI so the points row shows the new total
    if (mounted) setState(() {});
  }


  // DEBUG ONLY - call this to find where loyalty data actually lives
  Future<void> _debugPrintHiveOrderStructure() async {
    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.offlineOrderId?.toString() ??
          widget.orderId?.toString() ??
          orderId?.toString() ??
          "";

      print('🔎 [DEBUG] Looking for orderKey: $orderKey');

      if (orderKey.isEmpty) {
        print('🔎 [DEBUG] orderKey is EMPTY');
        return;
      }

      final rawOrder = await box.get(orderKey);
      if (rawOrder == null) {
        print('🔎 [DEBUG] Hive entry is NULL for key: $orderKey');
        // Print ALL keys in box to find correct one
        final allKeys = await box.getKeys();
        print('🔎 [DEBUG] All Hive keys: $allKeys');
        return;
      }

      final hiveOrder = Map<String, dynamic>.from(rawOrder as Map);
      print('🔎 [DEBUG] Hive order top-level keys: ${hiveOrder.keys.toList()}');

      // Check products array
      final products = (hiveOrder['products'] as List?) ?? [];
      print('🔎 [DEBUG] products[] count: ${products.length}');

      for (int i = 0; i < products.length; i++) {
        if (products[i] is! Map) continue;
        final p = Map<String, dynamic>.from(products[i] as Map);
        print('🔎 [DEBUG] products[$i] keys: ${p.keys.toList()}');
        print('🔎 [DEBUG] products[$i] name: ${p['name'] ?? p['product_name']}');
        print('🔎 [DEBUG] products[$i] meta_data: ${p['meta_data']}');
        print('🔎 [DEBUG] products[$i] loyalty_points: ${p['loyalty_points']}');
      }

      // Also check orderItems (what fetchOrderItems returns)
      print('🔎 [DEBUG] orderItems count: ${orderItems.length}');
      for (int i = 0; i < orderItems.length; i++) {
        final item = orderItems[i];
        print('🔎 [DEBUG] orderItems[$i] keys: ${item.keys.toList()}');
        print('🔎 [DEBUG] orderItems[$i] name: ${item['item_name']}');
        print('🔎 [DEBUG] orderItems[$i] meta_data: ${item['meta_data']}');
        print('🔎 [DEBUG] orderItems[$i] loyalty_points: ${item['loyalty_points']}');
        print('🔎 [DEBUG] orderItems[$i] product_id: ${item['product_id']}');
      }

    } catch (e, st) {
      print('🔎 [DEBUG] Error: $e\n$st');
    }
  }

  static const MethodChannel customerDisplayChannel = MethodChannel(
    'com.alekta.pinakapos/sunmi_display',
  );

  Future<void> _handleCustomerAddFromDisplay(String contact) async {
    try {
      final offlineBox = StorageProvider.offlineOrders;
      final localKey = widget.offlineOrderId?.toString();

      if (localKey == null) {
        throw Exception("Offline order not found");
      }

      final existing = await offlineBox.get(localKey);

      if (existing == null) {
        throw Exception("Order data missing");
      }

      final offlineOrder = Map<String, dynamic>.from(existing);

      final syncResponse = await orderBloc.syncSingleOfflineOrder(offlineOrder);

      if (syncResponse == null) {
        throw Exception("Sync failed");
      }

      final int syncedOrderId = syncResponse["id"] ?? 0;

      final rawResponse = await orderBloc.addLoyaltyPoints(
        orderId: syncedOrderId,
        contact: contact,
      );

      final result = jsonDecode(rawResponse);

      if (result["success"] != true) {
        throw Exception(result["message"]);
      }

      final data = result["data"] ?? {};

      final pts = int.tryParse(
        data["available_points"]?.toString() ?? "0",
      ) ??
          0;

      // final redeemedAmount =
      //     (data["value_redeemed"] as num?)?.toDouble() ?? 0.0;

      print("SENDING TO CUSTOMER DISPLAY");
      print("points=$pts");
      // print("redeemedAmount=$redeemedAmount");

      // UPDATE CUSTOMER DISPLAY
      await customerDisplayChannel.invokeMethod(
        "customerDisplayResult",
        {
          "success": true,
          "points": pts,
          // "redeemedAmount": redeemedAmount,
        },
      );

      setState(() {
        availablePoints = pts;

        // keep redeemed value
        // redeemedValue = redeemedAmount;

        mobileController.text = contact;
      });

      // FIX: persist points + contact to Hive so later calls to
      // CustomerDisplayHelper.updateCustomerDisplay() (e.g. after applying
      // or removing a coupon) don't reset available points back to 0.
      try {
        final rawLatest = await offlineBox.get(localKey);
        if (rawLatest is Map) {
          final latestOrder = Map<String, dynamic>.from(rawLatest);
          latestOrder["loyaltyContact"] = contact;
          latestOrder["available_points"] = pts;
          await offlineBox.put(localKey, latestOrder);
          print("💾 [Loyalty] Persisted available_points=$pts to Hive for order $localKey");
        }
      } catch (e) {
        print("⚠️ [Loyalty] Failed to persist available_points to Hive: $e");
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }

  Future<void> _applyRedeemFromCustomerDisplay() async {
    setState(() {
      isRedeemAppliedFromApi = true;

      // keep net payable unchanged
      // balanceAmount =
      //     (computedNetPayable - redeemedValue) - tenderAmount;
    });


  }

  // /// bala tax code

  double _proportionalCouponDiscountForItem(Map<String, dynamic> item) {
    // Only distribute coupon discount across real product lines
    final String itemType = (item['item_type'] ?? '').toString().toLowerCase();
    final String itemName = (item['item_name'] ?? '').toString().toLowerCase();
    if (itemType.contains('discount') ||
        itemType.contains('coupon') ||
        itemType.contains('payout') ||
        itemType.contains('cashback') ||
        itemName.contains('merchant discount')) return 0.0;

    final double couponDisc = discount.abs(); // discount is already negative
    if (couponDisc <= 0 || grossTotal <= 0) return 0.0;

    // Distribute proportionally by line item's gross contribution
    double unitPrice = (item['item_price'] ?? item['price'] ?? 0).toDouble();
    int qty = (item['items_count'] ?? item['quantity'] ?? 1) is num
        ? (item['items_count'] ?? item['quantity'] ?? 1).toInt()
        : 1;
    double lineGross = unitPrice * qty;

    return (lineGross / grossTotal) * couponDisc;
  }

  double _extractTotalDiscountForItem(Map<String, dynamic> item) {
    double n(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    // 🔥 FIX: Take MAX value for AUTO discounts
    List<double> autoDiscountValues = [
      n(item['_pos_auto_discount']),
      n(item['auto_discount']),
      n(item['autoDiscount']),
      n(item['auto_discount_total']),
      n(item['display_auto_discount']),
    ];
    double posAuto = autoDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    // 🔥 FIX: Take MAX value for COMBO discounts
    List<double> comboDiscountValues = [
      n(item['combo_discount_total']),
      n(item['comboDiscountTotal']),
      n(item['combo_discount']),
    ];
    double combo = comboDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    // 🔥 FIX: Take MAX value for MULTIPACK discounts
    List<double> multipackDiscountValues = [
      n(item['multipack_discount_total']),
      n(item['multipackDiscountTotal']),
      n(item['multipack_discount']),
    ];
    double multipack = multipackDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    // 🔥 FIX: Take MAX value for MIXMATCH discounts
    List<double> mixmatchDiscountValues = [
      n(item['mixmatch_discount_total']),
      n(item['mixMatchDiscountTotal']),
      n(item['mixmatch_discount']),
    ];
    double mixmatch = mixmatchDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    // ADD: proportional share of order-level coupon discount
    double couponShare = _proportionalCouponDiscountForItem(item);

    final String dtype = (item['discount_type'] ?? '').toString().toLowerCase();

    double lineDiscount;
    if (dtype == 'auto' || dtype.isEmpty) {
      lineDiscount = posAuto;
    } else if (dtype == 'combo' || dtype == 'mixmatch') {
      lineDiscount = combo > 0 ? combo : posAuto;
    } else if (dtype == 'multipack') {
      lineDiscount = multipack > 0 ? multipack : posAuto;
    } else {
      lineDiscount = posAuto + combo + multipack + mixmatch;
    }

    return lineDiscount + couponShare;
  }

  // Future<void> _recalculateTaxOnDiscountedItems() async {
  //   if (orderItems.isEmpty) return;
  //
  //   double toDouble(dynamic v) =>
  //       v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  //
  //   double resolveTaxRate(Map<String, dynamic> item) {
  //     for (final key in ['tax_rate', 'tax', 'tax_percent']) {
  //       final raw = item[key];
  //       if (raw != null) {
  //         final r = toDouble(raw);
  //         if (r > 0) return r / 100.0;
  //       }
  //     }
  //     return 0.0;
  //   }
  //
  //   double lineItemOnlyDiscount(Map<String, dynamic> item) {
  //     double n(dynamic v) =>
  //         v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  //
  //     List<double> autoDiscountValues = [
  //       n(item['_pos_auto_discount']),
  //       n(item['auto_discount']),
  //       n(item['autoDiscount']),
  //       n(item['auto_discount_total']),
  //       n(item['display_auto_discount']),
  //     ];
  //     double posAuto = autoDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);
  //
  //     List<double> comboDiscountValues = [
  //       n(item['combo_discount_total']),
  //       n(item['comboDiscountTotal']),
  //       n(item['combo_discount']),
  //     ];
  //     double combo = comboDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);
  //
  //     List<double> multipackDiscountValues = [
  //       n(item['multipack_discount_total']),
  //       n(item['multipackDiscountTotal']),
  //       n(item['multipack_discount']),
  //     ];
  //     double multipack = multipackDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);
  //
  //     List<double> mixmatchDiscountValues = [
  //       n(item['mixmatch_discount_total']),
  //       n(item['mixMatchDiscountTotal']),
  //       n(item['mixmatch_discount']),
  //     ];
  //     double mixmatch = mixmatchDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);
  //
  //     final String dtype = (item['discount_type'] ?? '').toString().toLowerCase();
  //
  //     if (dtype.isEmpty) {
  //       double total = posAuto + combo + multipack + mixmatch;
  //       return total > 0 ? total : 0.0;
  //     }
  //
  //     if (dtype == 'auto') return posAuto;
  //     if (dtype == 'combo' || dtype == 'mixmatch')
  //       return combo > 0 ? combo : posAuto;
  //     if (dtype == 'multipack') return multipack > 0 ? multipack : posAuto;
  //     return posAuto + combo + multipack + mixmatch;
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // 🔥 STEP 1: Calculate product totals and tax rates (exclude payout/cashback)
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   double productGrossTotal = 0.0;
  //   double productDiscountTotal = 0.0;
  //   double payoutCashbackTotal = 0.0;
  //   double totalLineGross = 0.0;
  //   double totalLineDiscount = 0.0;
  //   double totalTaxFromItems = 0.0;
  //   bool anyItemHasDiscountOrTaxRate = false;
  //   double weightedTaxRate = 0.0;
  //
  //   // 🔥 NEW: Track product tax rates directly from Hive like the order panel
  //   final Map<int, double> _hiveTaxRateByProductId = {};
  //   final Map<int, String> _hiveTaxStatusByProductId = {};
  //
  //   // Load tax rates from offline order products
  //   if (offlineOrder != null) {
  //     final hiveProducts = (offlineOrder?['products'] as List?) ?? [];
  //     for (final p in hiveProducts) {
  //       final int pid = int.tryParse(
  //           (p['product_id'] ?? p['id'] ?? '0').toString()) ?? 0;
  //       if (pid <= 0) continue;
  //       final double rate = double.tryParse(p['tax_rate']?.toString() ?? '0') ?? 0.0;
  //       final String status = (p['tax_status'] ?? 'taxable').toString().toLowerCase();
  //       if (rate > 0) _hiveTaxRateByProductId[pid] = rate;
  //       _hiveTaxStatusByProductId[pid] = status;
  //     }
  //   }
  //
  //   for (final item in orderItems) {
  //     final String itemType = (item['item_type'] ?? '').toString().toLowerCase();
  //     final String itemName = (item['item_name'] ?? '').toString().toLowerCase();
  //
  //     if (itemType.contains('discount') ||
  //         itemType.contains('coupon') ||
  //         itemType.contains('loyalty') ||
  //         itemName.contains('merchant discount')) {
  //       continue;
  //     }
  //
  //     final bool isPayout = itemType.contains('payout') || itemName.contains('payout');
  //     final bool isCashback = itemType.contains('cashback') || itemName.contains('cashback');
  //     final bool isPayoutOrCashback = isPayout || isCashback;
  //
  //     final double unitPrice = toDouble(item['item_price'] ?? item['price']);
  //     final int qty = (item['items_count'] ?? item['quantity'] ?? 1).toInt();
  //     final double lineTotal = unitPrice * qty;
  //
  //     final double itemDiscount = lineItemOnlyDiscount(item);
  //     final double taxableBase = (lineTotal - itemDiscount).clamp(0.0, double.infinity);
  //
  //     totalLineGross += lineTotal;
  //     totalLineDiscount += itemDiscount;
  //
  //     if (!isPayoutOrCashback) {
  //       productGrossTotal += lineTotal;
  //       productDiscountTotal += itemDiscount;
  //     } else {
  //       payoutCashbackTotal += lineTotal;
  //     }
  //
  //     if (itemDiscount > 0) anyItemHasDiscountOrTaxRate = true;
  //
  //     double itemTax = 0.0;
  //     final double taxRate = resolveTaxRate(item);
  //
  //     if (taxRate > 0) {
  //       anyItemHasDiscountOrTaxRate = true;
  //       itemTax = taxableBase * taxRate;
  //       if (taxableBase > 0) {
  //         weightedTaxRate += (taxableBase * taxRate);
  //       }
  //     } else {
  //       final double rawTax = toDouble(item['item_tax'] ?? item['tax_amount']);
  //       if (rawTax > 0 && lineTotal > 0) {
  //         anyItemHasDiscountOrTaxRate = true;
  //         itemTax = rawTax * (taxableBase / lineTotal);
  //         if (taxableBase > 0) {
  //           weightedTaxRate += (taxableBase * (rawTax / lineTotal));
  //         }
  //       }
  //       // 🔥 FIX: If no tax found, try to get from Hive product map
  //       else if (itemTax <= 0) {
  //         final int productId = int.tryParse((item['product_id'] ?? 0).toString()) ?? 0;
  //         if (productId > 0) {
  //           final double hiveTaxRate = _hiveTaxRateByProductId[productId] ?? 0.0;
  //           if (hiveTaxRate > 0 && taxableBase > 0) {
  //             itemTax = (taxableBase * hiveTaxRate) / 100.0;
  //             weightedTaxRate += (taxableBase * (hiveTaxRate / 100.0));
  //             anyItemHasDiscountOrTaxRate = true;
  //           }
  //         }
  //       }
  //     }
  //
  //     totalTaxFromItems += itemTax;
  //   }
  //
  //   // Calculate the weighted average tax rate
  //   final double totalTaxableBase = productGrossTotal - productDiscountTotal;
  //   if (totalTaxableBase > 0) {
  //     weightedTaxRate = weightedTaxRate / totalTaxableBase;
  //   } else {
  //     weightedTaxRate = 0.0;
  //   }
  //
  //   totalTaxFromItems = double.parse(totalTaxFromItems.toStringAsFixed(4));
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // 🔥 STEP 2: Calculate Merchant Discount on PRODUCTS ONLY
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   final String mdType = offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
  //   final double productNetAfterDiscounts = productGrossTotal - productDiscountTotal;
  //
  //   if (mdType == 'percentage' && merchantDiscountPercentage > 0 && productNetAfterDiscounts > 0) {
  //     merchantDiscount = -((productNetAfterDiscounts * merchantDiscountPercentage) / 100.0);
  //     merchantDiscount = double.parse(merchantDiscount.toStringAsFixed(2));
  //   } else {
  //     merchantDiscount = 0.0;
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // 🔥 STEP 3: Calculate TAX - CORRECTED VERSION
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   double finalTax = 0.0;
  //
  //   final double couponDiscount = discount < 0 ? discount.abs() : 0.0;
  //   final double taxableNetAmount = (productNetAfterDiscounts + merchantDiscount - couponDiscount).clamp(0.0, double.infinity);
  //
  //   print("🔧 TAX CALCULATION - CORRECTED:");
  //   print("   📍 productGrossTotal: $productGrossTotal");
  //   print("   📍 productDiscountTotal: $productDiscountTotal");
  //   print("   📍 productNetAfterDiscounts: $productNetAfterDiscounts");
  //   print("   📍 merchantDiscount: $merchantDiscount");
  //   print("   📍 couponDiscount: $couponDiscount");
  //   print("   📍 taxableNetAmount: $taxableNetAmount");
  //   print("   📍 weightedTaxRate: ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
  //   print("   📍 totalTaxFromItems: $totalTaxFromItems");
  //   print("   ───────────────────────────────────────────────");
  //
  //   // 🔥 PRIMARY METHOD: Calculate tax directly from the weighted tax rate
  //   // This is what the order panel does - it uses the tax rate from Hive
  //   if (weightedTaxRate > 0 && taxableNetAmount > 0) {
  //     print("   ✅ Calculating tax directly from weighted tax rate");
  //     print("   🧮 Calculation: $taxableNetAmount × ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
  //     finalTax = roundTaxHalfUp(taxableNetAmount * weightedTaxRate);
  //     print("   🧾 Final tax: $finalTax");
  //   }
  //   // SECONDARY METHOD: If we have item tax data, use proportional scaling
  //   else if (anyItemHasDiscountOrTaxRate && totalTaxFromItems > 0 && productGrossTotal > 0) {
  //     final double originalBase = productNetAfterDiscounts;
  //     if (originalBase > 0) {
  //       print("   ✅ Using item tax data with proportional scaling");
  //       print("   🧮 Calculation: $totalTaxFromItems × ($taxableNetAmount / $originalBase)");
  //       print("   🧮 Ratio: ${(taxableNetAmount / originalBase).toStringAsFixed(4)}");
  //       double scaledTax = totalTaxFromItems * (taxableNetAmount / originalBase);
  //       finalTax = roundTaxHalfUp(scaledTax);
  //       print("   🧾 Final tax: $finalTax");
  //     } else {
  //       finalTax = 0.0;
  //     }
  //   }
  //   // TERTIARY METHOD: Calculate from product gross using weighted tax rate
  //   else if (weightedTaxRate > 0 && productGrossTotal > 0) {
  //     print("   ✅ Calculating tax from product gross with weighted tax rate");
  //     print("   🧮 Calculation: $taxableNetAmount × ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
  //     finalTax = roundTaxHalfUp(taxableNetAmount * weightedTaxRate);
  //     print("   🧾 Final tax: $finalTax");
  //   }
  //   // FALLBACK: Use server tax
  //   else {
  //     print("   ⚠️ Fallback: Using server tax directly");
  //     print("   📍 widget.orderTax: ${widget.orderTax}");
  //     finalTax = widget.orderTax;
  //     print("   🧾 Final tax: $finalTax");
  //   }
  //
  //   // Ensure we have a reasonable tax value
  //   finalTax = double.parse(finalTax.toStringAsFixed(2));
  //
  //   print("   ───────────────────────────────────────────────");
  //   print("   🎯 FINAL TAX: $finalTax");
  //   print("   ✅ Expected tax rate applied to taxable amount");
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // 🔥 STEP 4: Calculate final totals
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   final double newNetTotal = grossTotal + discount + merchantDiscount;
  //   final double newNetPayable = newNetTotal + finalTax + cashbackFee;
  //
  //   final bool totalsChanged = (finalTax - tax).abs() > 0.000005 ||
  //       (newNetPayable - computedNetPayable).abs() > 0.000005;
  //   if (!totalsChanged) return;
  //
  //   setState(() {
  //     tax = finalTax;
  //     NetTotal = newNetTotal;
  //     computedNetPayable = newNetPayable;
  //     orderTotal = newNetPayable;
  //
  //     if (tenderAmount <= 0) {
  //       balanceAmount = newNetPayable;
  //     }
  //   });
  //
  //   final String orderKey = widget.offlineOrderId?.toString() ??
  //       widget.orderId?.toString() ??
  //       orderId?.toString() ??
  //       "";
  //
  //   if (orderKey.isNotEmpty) {
  //     try {
  //       final box = StorageProvider.offlineOrders;
  //       final rawOrder = await box.get(orderKey);final offlineOrder = Map<String, dynamic>.from(rawOrder);
  //       if (rawOrder != null) {
  //
  //         offlineOrder["tax_discount"] = finalTax;
  //         offlineOrder["order_tax"] = finalTax;
  //         offlineOrder["grand_total"] = newNetPayable;
  //         offlineOrder["net_payable"] = newNetPayable;
  //         if (tenderAmount <= 0) {
  //           offlineOrder["balanceAmount"] = newNetPayable;
  //           offlineOrder["balance_amount"] = newNetPayable;
  //           offlineOrder["remaining_balance"] = newNetPayable;
  //         }
  //         offlineOrder["merchantDiscount"] = merchantDiscount.abs();
  //         offlineOrder["merchant_discount"] = merchantDiscount.abs();
  //         offlineOrder["merchantDiscountPercentage"] = merchantDiscountPercentage;
  //         offlineOrder["NetTotal"] = newNetTotal;
  //         offlineOrder["net_total"] = newNetTotal;
  //
  //         await box.put(orderKey, offlineOrder);
  //         if (kDebugMode) {
  //           print(
  //               "💾 [CD/Summary] Updated Hive with recalculated tax: $finalTax, netPayable: $newNetPayable");
  //         }
  //       }
  //     } catch (e) {
  //       if (kDebugMode) {
  //         print("❌ [CD/Summary] Failed to update Hive order tax: $e");
  //       }
  //     }
  //   }
  //
  //   await Future.delayed(const Duration(milliseconds: 100));
  //
  //   if (widget.offlineOrderId != null) {
  //     await CustomerDisplayHelper.updateCustomerDisplay(
  //       widget.offlineOrderId!,
  //       summaryEnabled: true,
  //     );
  //   }
  // }


    Future<void> _recalculateTaxOnDiscountedItems() async {
    if (orderItems.isEmpty) return;

    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    double resolveTaxRate(Map<String, dynamic> item) {
      for (final key in ['tax_rate', 'tax', 'tax_percent']) {
        final raw = item[key];
        if (raw != null) {
          final r = toDouble(raw);
          if (r > 0) return r / 100.0;
        }
      }
      return 0.0;
    }

    double lineItemOnlyDiscount(Map<String, dynamic> item) {
      double n(dynamic v) =>
          v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

      List<double> autoDiscountValues = [
        n(item['_pos_auto_discount']),
        n(item['auto_discount']),
        n(item['autoDiscount']),
        n(item['auto_discount_total']),
        n(item['display_auto_discount']),
      ];
      double posAuto = autoDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      List<double> comboDiscountValues = [
        n(item['combo_discount_total']),
        n(item['comboDiscountTotal']),
        n(item['combo_discount']),
      ];
      double combo = comboDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      List<double> multipackDiscountValues = [
        n(item['multipack_discount_total']),
        n(item['multipackDiscountTotal']),
        n(item['multipack_discount']),
      ];
      double multipack = multipackDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      List<double> mixmatchDiscountValues = [
        n(item['mixmatch_discount_total']),
        n(item['mixMatchDiscountTotal']),
        n(item['mixmatch_discount']),
      ];
      double mixmatch = mixmatchDiscountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      final String dtype = (item['discount_type'] ?? '').toString().toLowerCase();

      if (dtype.isEmpty) {
        double total = posAuto + combo + multipack + mixmatch;
        return total > 0 ? total : 0.0;
      }

      if (dtype == 'auto') return posAuto;
      if (dtype == 'combo' || dtype == 'mixmatch')
        return combo > 0 ? combo : posAuto;
      if (dtype == 'multipack') return multipack > 0 ? multipack : posAuto;
      return posAuto + combo + multipack + mixmatch;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🔥 STEP 1: Calculate product totals and tax rates (exclude payout/cashback)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    double productGrossTotal = 0.0;
    double productDiscountTotal = 0.0;
    double payoutCashbackTotal = 0.0;
    double totalLineGross = 0.0;
    double totalLineDiscount = 0.0;
    double totalTaxFromItems = 0.0;
    bool anyItemHasDiscountOrTaxRate = false;
    double weightedTaxRate = 0.0;

    // 🔥 NEW: Track product tax rates directly from Hive like the order panel
    final Map<int, double> _hiveTaxRateByProductId = {};
    final Map<int, String> _hiveTaxStatusByProductId = {};

    // Load tax rates from offline order products
    if (offlineOrder != null) {
      final hiveProducts = (offlineOrder?['products'] as List?) ?? [];
      for (final p in hiveProducts) {
        final int pid = int.tryParse(
            (p['product_id'] ?? p['id'] ?? '0').toString()) ?? 0;
        if (pid <= 0) continue;
        final double rate = double.tryParse(p['tax_rate']?.toString() ?? '0') ?? 0.0;
        final String status = (p['tax_status'] ?? 'taxable').toString().toLowerCase();
        if (rate > 0) _hiveTaxRateByProductId[pid] = rate;
        _hiveTaxStatusByProductId[pid] = status;
      }
    }

    for (final item in orderItems) {
      final String itemType = (item['item_type'] ?? '').toString().toLowerCase();
      final String itemName = (item['item_name'] ?? '').toString().toLowerCase();

      if (itemType.contains('discount') ||
          itemType.contains('coupon') ||
          itemType.contains('loyalty') ||
          itemName.contains('merchant discount')) {
        continue;
      }

      final bool isPayout = itemType.contains('payout') || itemName.contains('payout');
      final bool isCashback = itemType.contains('cashback') || itemName.contains('cashback');
      final bool isPayoutOrCashback = isPayout || isCashback;

      final double unitPrice = toDouble(item['item_price'] ?? item['price']);
      final int qty = (item['items_count'] ?? item['quantity'] ?? 1).toInt();
      final double lineTotal = unitPrice * qty;

      final double itemDiscount = lineItemOnlyDiscount(item);
      final double taxableBase = (lineTotal - itemDiscount).clamp(0.0, double.infinity);

      totalLineGross += lineTotal;
      totalLineDiscount += itemDiscount;

      if (!isPayoutOrCashback) {
        productGrossTotal += lineTotal;
        productDiscountTotal += itemDiscount;
      } else {
        payoutCashbackTotal += lineTotal;
      }

      if (itemDiscount > 0) anyItemHasDiscountOrTaxRate = true;

      double itemTax = 0.0;
      final double taxRate = resolveTaxRate(item);

      if (taxRate > 0) {
        anyItemHasDiscountOrTaxRate = true;
        itemTax = taxableBase * taxRate;
        if (taxableBase > 0) {
          weightedTaxRate += (taxableBase * taxRate);
        }
      } else {
        final double rawTax = toDouble(item['item_tax'] ?? item['tax_amount']);
        if (rawTax > 0 && lineTotal > 0) {
          anyItemHasDiscountOrTaxRate = true;
          itemTax = rawTax * (taxableBase / lineTotal);
          if (taxableBase > 0) {
            weightedTaxRate += (taxableBase * (rawTax / lineTotal));
          }
        }
        // 🔥 FIX: If no tax found, try to get from Hive product map
        else if (itemTax <= 0) {
          final int productId = int.tryParse((item['product_id'] ?? 0).toString()) ?? 0;
          if (productId > 0) {
            final double hiveTaxRate = _hiveTaxRateByProductId[productId] ?? 0.0;
            if (hiveTaxRate > 0 && taxableBase > 0) {
              itemTax = (taxableBase * hiveTaxRate) / 100.0;
              weightedTaxRate += (taxableBase * (hiveTaxRate / 100.0));
              anyItemHasDiscountOrTaxRate = true;
            }
          }
        }
      }

      totalTaxFromItems += itemTax;
    }

    // Calculate the weighted average tax rate
    final double totalTaxableBase = productGrossTotal - productDiscountTotal;
    if (totalTaxableBase > 0) {
      weightedTaxRate = weightedTaxRate / totalTaxableBase;
    } else {
      weightedTaxRate = 0.0;
    }

    totalTaxFromItems = double.parse(totalTaxFromItems.toStringAsFixed(4));

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🔥 STEP 2: Calculate Merchant Discount on PRODUCTS ONLY
    //
    // FIX: For a percentage discount, recompute it based on the current
    // (post-item-discount) product net so it stays proportionally correct.
    // For a FIXED dollar discount, do NOT recompute a formula — just read the
    // dollar amount the user actually entered/saved. The order panel writes
    // this under 'merchantDiscountFixed' (see getCurrentMerchantDiscount() in
    // widget_order_panel.dart), so we must read that same key here. Older data
    // may have used 'merchantDiscount' as a plain dollar value, so that's kept
    // as a fallback. Previously this branch unconditionally set
    // merchantDiscount = 0.0, which is why fixed/$ merchant discounts never
    // appeared on the Order Summary screen.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final String mdType = offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
    final double productNetAfterDiscounts = productGrossTotal - productDiscountTotal;

    if (mdType == 'percentage' && merchantDiscountPercentage > 0 && productNetAfterDiscounts > 0) {
      merchantDiscount = -((productNetAfterDiscounts * merchantDiscountPercentage) / 100.0);
      merchantDiscount = double.parse(merchantDiscount.toStringAsFixed(2));
    } else {
      final double storedFixed =
          (offlineOrder?['merchantDiscountFixed'] as num?)?.toDouble() ??
              (offlineOrder?['merchantDiscount'] as num?)?.toDouble() ??
              0.0;
      merchantDiscount = storedFixed != 0 ? -(storedFixed.abs()) : 0.0;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🔥 STEP 3: Calculate TAX - CORRECTED VERSION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    double finalTax = 0.0;

    final double couponDiscount = discount < 0 ? discount.abs() : 0.0;
    final double taxableNetAmount = (productNetAfterDiscounts + merchantDiscount - couponDiscount).clamp(0.0, double.infinity);

    print("🔧 TAX CALCULATION - CORRECTED:");
    print("   📍 productGrossTotal: $productGrossTotal");
    print("   📍 productDiscountTotal: $productDiscountTotal");
    print("   📍 productNetAfterDiscounts: $productNetAfterDiscounts");
    print("   📍 merchantDiscount: $merchantDiscount");
    print("   📍 couponDiscount: $couponDiscount");
    print("   📍 taxableNetAmount: $taxableNetAmount");
    print("   📍 weightedTaxRate: ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
    print("   📍 totalTaxFromItems: $totalTaxFromItems");
    print("   ───────────────────────────────────────────────");

    // 🔥 PRIMARY METHOD: Calculate tax directly from the weighted tax rate
    if (weightedTaxRate > 0 && taxableNetAmount > 0) {
      print("   ✅ Calculating tax directly from weighted tax rate");
      print("   🧮 Calculation: $taxableNetAmount × ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
      finalTax = roundTaxHalfUp(taxableNetAmount * weightedTaxRate);
      print("   🧾 Final tax: $finalTax");
    }
    // SECONDARY METHOD: If we have item tax data, use proportional scaling
    else if (anyItemHasDiscountOrTaxRate && totalTaxFromItems > 0 && productGrossTotal > 0) {
      final double originalBase = productNetAfterDiscounts;
      if (originalBase > 0) {
        print("   ✅ Using item tax data with proportional scaling");
        print("   🧮 Calculation: $totalTaxFromItems × ($taxableNetAmount / $originalBase)");
        print("   🧮 Ratio: ${(taxableNetAmount / originalBase).toStringAsFixed(4)}");
        double scaledTax = totalTaxFromItems * (taxableNetAmount / originalBase);
        finalTax = roundTaxHalfUp(scaledTax);
        print("   🧾 Final tax: $finalTax");
      } else {
        finalTax = 0.0;
      }
    }
    // TERTIARY METHOD: Calculate from product gross using weighted tax rate
    else if (weightedTaxRate > 0 && productGrossTotal > 0) {
      print("   ✅ Calculating tax from product gross with weighted tax rate");
      print("   🧮 Calculation: $taxableNetAmount × ${(weightedTaxRate * 100).toStringAsFixed(2)}%");
      finalTax = roundTaxHalfUp(taxableNetAmount * weightedTaxRate);
      print("   🧾 Final tax: $finalTax");
    }
    // FALLBACK: Use server tax
    else {
      print("   ⚠️ Fallback: Using server tax directly");
      print("   📍 widget.orderTax: ${widget.orderTax}");
      finalTax = widget.orderTax;
      print("   🧾 Final tax: $finalTax");
    }

    // Ensure we have a reasonable tax value
    finalTax = double.parse(finalTax.toStringAsFixed(2));

    print("   ───────────────────────────────────────────────");
    print("   🎯 FINAL TAX: $finalTax");
    print("   ✅ Expected tax rate applied to taxable amount");

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🔥 STEP 4: Calculate final totals
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final double newNetTotal = grossTotal + discount + merchantDiscount;
    final double newNetPayable = newNetTotal + finalTax + cashbackFee;

    final bool totalsChanged = (finalTax - tax).abs() > 0.000005 ||
        (newNetPayable - computedNetPayable).abs() > 0.000005;
    if (!totalsChanged) return;

    setState(() {
      tax = finalTax;
      NetTotal = newNetTotal;
      computedNetPayable = newNetPayable;
      orderTotal = newNetPayable;

      if (tenderAmount <= 0) {
        balanceAmount = newNetPayable;
      }
    });

    final String orderKey = widget.offlineOrderId?.toString() ??
        widget.orderId?.toString() ??
        orderId?.toString() ??
        "";

    if (orderKey.isNotEmpty) {
      try {
        final box = StorageProvider.offlineOrders;
        final rawOrder = await box.get(orderKey);final offlineOrder = Map<String, dynamic>.from(rawOrder);
        if (rawOrder != null) {

          offlineOrder["tax_discount"] = finalTax;
          offlineOrder["order_tax"] = finalTax;
          offlineOrder["grand_total"] = newNetPayable;
          offlineOrder["net_payable"] = newNetPayable;
          if (tenderAmount <= 0) {
            offlineOrder["balanceAmount"] = newNetPayable;
            offlineOrder["balance_amount"] = newNetPayable;
            offlineOrder["remaining_balance"] = newNetPayable;
          }
          offlineOrder["merchantDiscount"] = merchantDiscount.abs();
          offlineOrder["merchant_discount"] = merchantDiscount.abs();
          offlineOrder["merchantDiscountPercentage"] = merchantDiscountPercentage;
          offlineOrder["NetTotal"] = newNetTotal;
          offlineOrder["net_total"] = newNetTotal;

          await box.put(orderKey, offlineOrder);
          if (kDebugMode) {
            print(
                "💾 [CD/Summary] Updated Hive with recalculated tax: $finalTax, netPayable: $newNetPayable");
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("❌ [CD/Summary] Failed to update Hive order tax: $e");
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));

    if (widget.offlineOrderId != null) {
      await CustomerDisplayHelper.updateCustomerDisplay(
        widget.offlineOrderId!,
        summaryEnabled: true,
      );
      // Skip intermediate CFD publishes during coupon apply/remove (prevents flicker)
      if (_suppressCfdSync) return;

      await Future.delayed(const Duration(milliseconds: 100));

      if (widget.offlineOrderId != null) {
        // Single path only — _syncCfdFromOrderSummary updates native + MQTT
        unawaited(_syncCfdFromOrderSummary());
      }
    }
  }

// ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadLatestMerchantDiscount() async {
    final key = (widget.offlineOrderId ?? orderId ?? 0).toString();
    final raw = await StorageProvider.offlineOrders.get(key);

    if (raw != null && raw is Map) {
      final mdRaw = raw['merchantDiscount'] ??
          raw['merchant_discount'] ??
          raw['_merchant_discount'] ?? 0;

      final double mdVal = (mdRaw is num)
          ? mdRaw.toDouble()
          : double.tryParse(mdRaw.toString()) ?? 0.0;

      setState(() {
        merchantDiscount = mdVal.abs();           // Positive for UI display
        merchantDiscountPercentage = (raw['merchantDiscountPercentage'] as num?)?.toDouble() ?? 0.0;

        // Also update internal map
        _order[AppDBConst.merchantDiscount] = -mdVal;
        _order["merchantDiscount"] = -mdVal;
        _order["merchant_discount"] = -mdVal;
      });

      print("🔄 Loaded fresh merchant discount from Hive: $merchantDiscount (was stale before)");
    }
  }

  Future<void> _recalculateGrossAndNetFromLineItemDiscounts() async {
    if (orderItems.isEmpty) return;

    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    double recalculatedGrossTotal = 0.0;
    double totalLineItemDiscount = 0.0;
    double payoutCashbackTotal = 0.0;

    // Store previous values to detect changes
    final double previousGrossTotal = grossTotal;
    final double previousMerchantDiscount = merchantDiscount;
    final double previousComputedNetPayable = computedNetPayable;

    for (final item in orderItems) {
      final String itemType = (item['item_type'] ?? '').toString().toLowerCase();
      final String itemName = (item['item_name'] ?? '').toString().toLowerCase();

      final bool isPayout = itemType.contains('payout') ||
          itemType.contains('cashback') ||
          itemName == 'payout' ||
          itemName == 'cashback' ||
          itemName.contains('payout') ||
          itemName.contains('cashback');

      if (isPayout) {
        final double unitPrice = toDouble(item['item_price'] ?? item['price']);
        final int qty = (item['items_count'] ?? item['quantity'] ?? 1).toInt();
        payoutCashbackTotal += unitPrice * qty;
        continue;
      }

      if (itemType.contains('discount') ||
          itemType.contains('coupon') ||
          itemType.contains('loyalty') ||
          itemName.contains('merchant discount')) {
        continue;
      }

      final double itemSumPrice = toDouble(item['item_sum_price']);
      final double unitPrice = toDouble(item['item_price'] ?? item['price']);
      final int qty = (item['items_count'] ?? item['quantity'] ?? 1).toInt();
      final double lineOriginalTotal = unitPrice * qty;

      final double lineGross = itemSumPrice > 0 ? itemSumPrice : lineOriginalTotal;
      recalculatedGrossTotal += lineGross;

      final String dtype = (item['discount_type'] ?? '').toString().toLowerCase();

      // 🔥 FIX: Take MAX value instead of SUM to prevent double counting
      List<double> discountValues = [
        toDouble(item['auto_discount']),
        toDouble(item['auto_discount_total']),
        toDouble(item['autoDiscount']),
        toDouble(item['autoDiscountTotal']),
        toDouble(item['display_auto_discount']),
        toDouble(item['_pos_auto_discount']),
      ];

      double autoDiscount = discountValues.where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

      double comboDiscount = [
        item['combo_discount_total'],
        item['comboDiscountTotal'],
        item['combo_discount'],
      ].map((e) => toDouble(e)).firstWhere((v) => v != 0, orElse: () => 0);

      double mixMatchDiscount = [
        item['mixmatch_discount_total'],
        item['mixMatchDiscountTotal'],
        item['mixmatch_discount'],
      ].map((e) => toDouble(e)).firstWhere((v) => v != 0, orElse: () => 0);

      double multipackDiscount = [
        item['multipack_discount_total'],
        item['multipackDiscountTotal'],
        item['multipack_discount'],
      ].map((e) => toDouble(e)).firstWhere((v) => v != 0, orElse: () => 0);

      if (dtype == 'mixmatch' && autoDiscount > 0 && mixMatchDiscount == 0) {
        mixMatchDiscount = autoDiscount;
        autoDiscount = 0;
      }
      if (dtype == 'combo' && autoDiscount > 0 && comboDiscount == 0) {
        comboDiscount = autoDiscount;
        autoDiscount = 0;
      }
      if (dtype == 'multipack' && autoDiscount > 0 && multipackDiscount == 0) {
        multipackDiscount = autoDiscount;
        autoDiscount = 0;
      }

      final double itemDiscount =
          autoDiscount + comboDiscount + mixMatchDiscount + multipackDiscount;
      totalLineItemDiscount += itemDiscount;
    }

    if (totalLineItemDiscount <= 0 &&
        payoutCashbackTotal == 0 &&
        (recalculatedGrossTotal - grossTotal).abs() <= 0.01) {
      return;
    }

    final double productGross = recalculatedGrossTotal != 0
        ? recalculatedGrossTotal
        : (widget.grossTotal > 0 ? widget.grossTotal : 0.0);

    final double productGrossAfterDiscounts = productGross - totalLineItemDiscount;

    final double newGrossForDisplay = productGrossAfterDiscounts + payoutCashbackTotal;

    final double newNetTotal = newGrossForDisplay + discount + merchantDiscount;
    final double newNetPayable = newNetTotal + tax + cashbackFee;

    if (kDebugMode) {
      print('── LINE-ITEM DISCOUNT RECALCULATION ──');
      print('   New Gross For Display : $newGrossForDisplay');
      print('   Total Line Discounts  : $totalLineItemDiscount');
      print('   NetTotal (pre-merchant) : $newNetTotal');
      print('   Merchant Discount     : $merchantDiscount');
      print('   New Net Payable       : $newNetPayable');

    }

    setState(() {
      grossTotal = newGrossForDisplay;
      NetTotal = newNetTotal;
      computedNetPayable = newNetPayable;
      orderTotal = newNetPayable;

      if (tenderAmount <= 0) {
        balanceAmount = newNetPayable;
      }
    });

    final String orderKey = widget.offlineOrderId?.toString() ??
        widget.orderId?.toString() ??
        orderId?.toString() ??
        "";

    if (orderKey.isNotEmpty) {
      try {
        final box = StorageProvider.offlineOrders;
        final rawOrder = await box.get(orderKey);
        if (rawOrder != null) {
          final offlineOrder = Map<String, dynamic>.from(rawOrder);
          offlineOrder["gross_total"] = newGrossForDisplay;
          offlineOrder["NetTotal"] = newNetTotal;
          offlineOrder["net_total"] = newNetTotal;
          offlineOrder["net_payable"] = newNetPayable;
          offlineOrder["grand_total"] = newNetPayable;
          if (tenderAmount <= 0) {
            offlineOrder["balanceAmount"] = newNetPayable;
            offlineOrder["balance_amount"] = newNetPayable;
            offlineOrder["remaining_balance"] = newNetPayable;
          }
          offlineOrder["merchantDiscount"] = merchantDiscount.abs();
          offlineOrder["merchant_discount"] = merchantDiscount.abs();
          offlineOrder["merchantDiscountPercentage"] = merchantDiscountPercentage;

          await box.put(orderKey, offlineOrder);
          if (kDebugMode) {
            print(
                "💾 [CD/Summary] Updated Hive with recalculated gross: $newGrossForDisplay, netTotal: $newNetTotal, netPayable: $newNetPayable");
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("❌ [CD/Summary] Failed to update Hive order gross/net: $e");
        }
      }
    }

    // Update customer display when merchant discount changes
    final bool merchantDiscountChanged = (merchantDiscount - previousMerchantDiscount).abs() > 0.01;
    final bool netPayableChanged = (computedNetPayable - previousComputedNetPayable).abs() > 0.01;

    if (merchantDiscountChanged || netPayableChanged) {
      await _updateCustomerDisplayWithMerchantDiscount();
      if (widget.offlineOrderId != null) {
        await CustomerDisplayHelper.updateCustomerDisplay(
          widget.offlineOrderId!,
          summaryEnabled: true,
        );
        if (merchantDiscountChanged || netPayableChanged) {
          // Skip intermediate CFD publishes during coupon apply/remove (prevents flicker)
          if (_suppressCfdSync) return;
          // Single path only — avoid double native + MQTT publish
          if (widget.offlineOrderId != null || orderId != null) {
            unawaited(_syncCfdFromOrderSummary());
          }
        }
      }
    }
  }

  Future<void> _updateCustomerDisplayWithMerchantDiscount() async {
    final int? orderIdToUse = widget.offlineOrderId ?? orderId;
    if (orderIdToUse == null || orderIdToUse == 0) return;

    if (kDebugMode) {
      print('🔄 Updating customer display via helper...');
    }

    try {
      await CustomerDisplayHelper.updateCustomerDisplay(
        orderIdToUse,
        summaryEnabled: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update customer display via helper: $e');
      }
    }
  }



  @override
  void initState() {
    super.initState();

    const MethodChannel _customerDisplayChannel = MethodChannel(
      'com.alekta.pinakapos/sunmi_display',
    );

    _customerDisplayChannel.setMethodCallHandler((call) async {
      print("=================================");
      print("📥 FLUTTER RECEIVED: ${call.method}");
      print("ARGS = ${call.arguments}");

      if (call.method == "customerDisplayPopupClosed") {
        print("📥 POPUP CLOSED FROM CUSTOMER DISPLAY");

        if (mounted) {
          setState(() {
            isRedeemActive = false;
            isAddLoading = false;

            // keep phone number
            // do NOT clear mobileController

            // keep validation based on existing number
            isPhoneValid = mobileController.text.isNotEmpty;

            // enable Add button
            isButtonDisabled = false;
          });
        }

        return;
      }

      if (call.method == "customerDisplayRedeemClicked") {
        final String contact = call.arguments["contact"] ?? "";

        print("📱 CONTACT = $contact");
        // CLOSE POS KEYBOARD
        FocusManager.instance.primaryFocus?.unfocus();

        if (contact.isEmpty) {
          if (mounted) {
            setState(() {
              isButtonDisabled = false;
            });
          }
          return;
        }

        try {
          if (mounted) {
            setState(() {
              isButtonDisabled = true;
              isAddLoading = true;
            });
          }

          await _handleCustomerAddFromDisplay(contact);
          // CLOSE AGAIN after controller update
          FocusManager.instance.primaryFocus?.unfocus();

          await _customerDisplayChannel.invokeMethod(
            "customerDisplayResult",
            {
              "success": true,
              "points": availablePoints,
              "redeemedAmount": redeemedValue,
            },
          );
        } catch (e) {
          print("❌ ERROR = $e");

          if (mounted) {
            setState(() {
              isButtonDisabled = false;
              isAddLoading = false;
            });
          }

          await _customerDisplayChannel.invokeMethod(
            "customerDisplayResult",
            {
              "success": false,
              "message": e.toString(),
            },
          );
        }
      }

      print("=================================");
    });

    // remaining initState code...

    ScannerGuard.isCouponPopupOpen = true;


    orderItems = List.from(widget.orderItems); // ensure copy

    // IMPORTANT: Call after merges
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _mergeOrderSummaryLineItemsFromProductCache(orderItems);
      _mergeOrderSummaryLineItemsFromHive(orderItems, offlineOrder);

      _calculateAndPrintLoyaltyPoints();
      _syncEbtTotalWithOrderItems();   // ← ADD THIS
      if (mounted) setState(() {});
    });

    orderItems =
        widget.orderItems.map((e) => Map<String, dynamic>.from(e)).toList();
    grossTotal = widget.grossTotal;
    discount =
    (widget.orderDiscount != 0) ? -(widget.orderDiscount.abs()) : 0.0;
    merchantDiscount =
    (widget.merchantDiscount != 0) ? -(widget.merchantDiscount.abs()) : 0.0;
    // tax = getAdjustedSummaryTax();
    orderId = widget.orderId;
    ebtTotal = widget.ebtAmount;

    // merchantDiscountPercentage is loaded asynchronously below

    _displayDate = widget.formattedDate;
    _displayTime = widget.formattedTime;
    cashbackFee = widget.cashbackFee;
    discountValue = widget.discountAmount;

    Future.delayed(Duration.zero, () async {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? 0).toString();
      if (await box.containsKey(key)) {
        final rawExisting = await box.get(key);
        final existing =
        Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});
        if (widget.ebtAmount > 0 &&
            existing["originalEbt"] != widget.ebtAmount) {
          existing["originalEbt"] = widget.ebtAmount;
          existing["remainingEbt"] = widget.ebtAmount;
          await box.put(key, existing);
          if (kDebugMode) print("🛠 MIGRATED EBT → ${widget.ebtAmount}");
        }
      }

      final offlineBox = StorageProvider.offlineOrders;
      final orderIdKey = (orderId ?? 0).toString();
      if (await offlineBox.containsKey(orderIdKey)) {
        final raw = await offlineBox.get(orderIdKey);
        offlineOrder = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (offlineOrder != null &&
            offlineOrder!['merchantDiscountPercentage'] != null) {
          merchantDiscountPercentage = double.tryParse(
              offlineOrder!['merchantDiscountPercentage']?.toString() ??
                  '0') ??
              0.0;
        }

        if (offlineOrder != null &&
            offlineOrder!['tenderAmount'] != null &&
            offlineOrder!['balanceAmount'] != null) {
          tenderAmount = (offlineOrder!['tenderAmount'] as num).toDouble();
          balanceAmount = (offlineOrder!['balanceAmount'] as num).toDouble();
          payByCash = (offlineOrder!['payByCash'] as num?)?.toDouble() ?? 0.0;
          payByOther = (offlineOrder!['payByOther'] as num?)?.toDouble() ?? 0.0;

          if (offlineOrder!.containsKey("lastPayment")) {
            _lastPayment = LastPaymentInfo.fromJson(
              Map<String, dynamic>.from(offlineOrder!["lastPayment"]),
            );
          }
          if (balanceAmount > 0) {
            _currentPaymentRemainingBalance = balanceAmount;
            _lastPaymentDetails = {
              'amount': tenderAmount,
              'method': 'Cash',
              'remainingBalance': balanceAmount,
              'datetime': DateTime.now().toIso8601String(),
            };
          } else {
            _currentPaymentRemainingBalance = null;
            _lastPaymentDetails = null;
          }
        } else {
          balanceAmount = orderTotal;
          _currentPaymentRemainingBalance = null;
          _lastPaymentDetails = null;
        }
      } else {
        balanceAmount = orderTotal;
        _currentPaymentRemainingBalance = null;
        _lastPaymentDetails = null;
      }

      await _enrichOrderItemsFromHiveProducts();
      await _debugPrintHiveOrderStructure();

      _calculateAndPrintLoyaltyPoints();
      await _recalculateTaxOnDiscountedItems();
      if (!widget.itemPricesAlreadyAdjusted) {
        await _recalculateGrossAndNetFromLineItemDiscounts();
      }

// ✅ FIX: Recalculate EBT proportionally after merchant discount is applied
      _recalculateEbtTotalAfterDiscount();
      _syncEbtTotalWithOrderItems();   // ← ADD THIS


      if (mounted) setState(() {});

      await _calculateBalanceFromPaymentHistory();

      await _printPaymentHistorySummary();
      if (_currentPaymentRemainingBalance != null) {
        print("\n ACTIVE PAYMENT SESSION DETECTED");
        print(
            "Remaining Balance: \$${_currentPaymentRemainingBalance!.toStringAsFixed(2)}");
      } else {
        print("\n NO ACTIVE PAYMENT SESSION");
        print(
            "Starting fresh from balance: \$${balanceAmount.toStringAsFixed(2)}");
      }
      await retrySyncUnsyncedPayments();
      await _recalculateTaxOnDiscountedItems();
      if (!widget.itemPricesAlreadyAdjusted) {
        await _recalculateGrossAndNetFromLineItemDiscounts();
      }
    });

    Future.delayed(Duration.zero, () async {
      if (kDebugMode) {
        print("\n ORDER SUMMARY INITIALIZED");
        print("Order ID: $orderId");
      }

      // Calculate balance from payment history first
      await _calculateBalanceFromPaymentHistory();

      // Print payment history summary
      await _printPaymentHistorySummary();

      await retrySyncUnsyncedPayments();
      await _recalculateTaxOnDiscountedItems();
    });

    Future.delayed(Duration.zero, () async {
      if (kDebugMode) {
        print("\n ORDER SUMMARY INITIALIZED");
        print("Order ID: $orderId");
      }

      await LocalPaymentDBHelper.instance.printAllPayments();
      await retrySyncUnsyncedPayments();
    });

    amountController.addListener(() {
      if (balanceAmount < 0 &&
          amountController.text != '${TextConstants.currencySymbol}0.00') {
        final value = '${TextConstants.currencySymbol}0.00';
        amountController.text = value;
        amountController.selection =
            TextSelection.collapsed(offset: value.length);
      }
    });

    Future.delayed(Duration.zero, () async {
      final key = (orderId ?? 0).toString();
      final box = StorageProvider.offlineOrders;

      if (!(await box.containsKey(key))) {
        await _createOfflineOrderEntry(key);
      } else {
        // Load existing data
        final data = await _loadOfflineOrderData();
        if (data != null) {
          // Restore state from Hive
          setState(() {
            tenderAmount = (data['tender_amount'] as num?)?.toDouble() ?? 0.0;
            balanceAmount = (data['remaining_balance'] as num?)?.toDouble() ??
                computedNetPayable;
            changeAmount = (data['change_amount'] as num?)?.toDouble() ?? 0.0;
            payByCash = (data['pay_by_cash'] as num?)?.toDouble() ?? 0.0;
            payByCard = (data['pay_by_card'] as num?)?.toDouble() ?? 0.0;
            payByOther = (data['pay_by_other'] as num?)?.toDouble() ?? 0.0;
            isPaymentStarted = tenderAmount > 0;
          });
        }
      }
    });

    _fetchShiftId();
    orderBloc = OrderBloc(OrderRepository());
    selectedPaymentMethod = TextConstants.cash;
    final bool isNegativeOrder = widget.grossTotal < 0;

    print("🏷 q = $discountValue");

    print(" EBT Total in Summary Screen = $ebtTotal");

    // Compute totals
    NetTotal = grossTotal + discount + merchantDiscount;
    computedNetPayable = NetTotal + tax + cashbackFee;

    orderTotal = computedNetPayable;

    print(" Computed Net Payable (Order Total) = $orderTotal");
    // Payment restoration is done in Future.delayed above (async storage)

    // Show restored payment state
    print("💵 Current Payment Breakdown:");
    print("   → payByCash = $payByCash");
    print("   → payByOther = $payByOther");
    print("   → tenderAmount = $tenderAmount");
    print("   → balanceAmount = $balanceAmount");

    // Redeem listener
    mobileController.addListener(() {
      setState(() {
        isMobileValid = RegExp(r'^[0-9]{10}$').hasMatch(mobileController.text);

        if (!isMobileValid) {
          isRedeemActive = false;
        }
      });
    });

    _fetchUserId();

    // Debug dump
    print("🧾 Order Summary Init:"
        "\nItems: ${widget.orderItems.length}"
        "\nGross: ${widget.grossTotal}"
        "\nDiscount: ${widget.orderDiscount}"
        "\nTax: ${widget.orderTax}"
        "\nCashback Fee: $cashbackFee"
        "\nNet Payable: ${widget.netPayable}");

    for (var item in orderItems) {
      print(jsonEncode(item));
    }

    print("💵 INITIAL PAYMENT STATE:");
    print("   payByCash = $payByCash");
    print("   payByOther = $payByOther");
    print("   tenderAmount = $tenderAmount");
    print("   balanceAmount = $balanceAmount");
    print("   orderTotal = $orderTotal");

    if (!isNegativeOrder) {
      _fetchPaymentsByOrderId(); // sale only
    } else {
      //  payout → no API, no loading
      setState(() {
        isLoading = false;
        isSummaryLoading = false;
        balanceAmount = widget.netPayable; // negative
      });
    }
  }

  @override
  void dispose() {
    //Build #1.0.99: Added Dispose
    ScannerGuard.isCouponPopupOpen = false;
    _paymentListSubscription?.cancel();
    paymentBloc.dispose();
    _scrollController.dispose();
    amountController.dispose();

    super.dispose();
  }

  Future<void> _fetchUserId() async {
    // Build #1.0.29: get the userId from db
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        userRole = userData[AppDBConst.userRole];
      });
    }
  }

  static const MethodChannel _paymentChannel =
  MethodChannel("sunmi_payment_channel");

  Future<void> _openSunmiVoidScreen({
    required double amount,
    required String orderId,
    required String originTransactionId,
  }) async {
    if (kDebugMode) {
      print(" Starting CARD VOID → amount=$amount, orderId=$orderId");
    }

    final result = await _paymentChannel.invokeMethod("startVoid", {
      "amount": amount.toString(),
      "originOrderId": orderId,
      "originTransactionId": originTransactionId,
    });

    final data = jsonDecode(result);
    final fullSunmi = jsonDecode(data["fullResponse"]);

    final bool success = data["status"] == "SUCCESS";
    final double voidedAmount =
        double.tryParse(fullSunmi["processedAmount"] ?? "0") ?? 0.0;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Card void failed")),
      );
      return;
    }

    // -------------------------------
    // UPDATE FLUTTER TOTALS
    // -------------------------------
    payByCard = (payByCard - voidedAmount).clamp(0, double.infinity);
    tenderAmount = (tenderAmount - voidedAmount).clamp(0, double.infinity);

    balanceAmount = (orderTotal - tenderAmount).clamp(0, double.infinity);

    changeAmount = 0;

    if (kDebugMode) {
      print(" VOID SUCCESS");
      print("payByCard = $payByCard");
      print("tenderAmount = $tenderAmount");
      print("balanceAmount = $balanceAmount");
    }

    setState(() {});
    // --------------------------------------------------
    // OFFLINE DELETE (same as cash flow)
    // --------------------------------------------------
    if (widget.isOfflineSynced && widget.offlineOrderId != null) {
      try {
        final offlineId = widget.offlineOrderId!;
        final box = StorageProvider.offlineOrders;

        if (await box.containsKey(offlineId.toString())) {
          await box.delete(offlineId.toString());
        }

        await orderHelper.deleteOrder(offlineId);
      } catch (e) {
        print(" Failed deleting offline order: $e");
      }
    }

    // -------------------------------
    //  CALL EXISTING VOID API
    // -------------------------------
    _handleVoidPayment(context, isPartial: true);
  }

  Future<void> _openSunmiSaleScreen({
    required double amount,
    required String orderId,
  }) async {
    setState(() {
      _processingPaymentMethod = TextConstants.card;
      isLoading = true;
    });

    try {
      final result = await _paymentChannel.invokeMethod("startSale", {
        "amount": amount.toString(),
        "orderId": orderId,
      });

      final data = jsonDecode(result);
      final fullSunmi = jsonDecode(data["fullResponse"]);

      double paidAmount =
          double.tryParse(fullSunmi["processedAmount"] ?? "0") ?? 0.0;

      if (paidAmount <= 0) {
        throw Exception("Invalid paid amount from Sunmi");
      }

      // ==================== UNIFIED PAYMENT FLOW (Same as Cash) ====================
      selectedPaymentMethod = TextConstants.card;

      final String datetime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final localPayment = LocalPayment(
        orderId: widget.orderId ?? 0,
        title: TextConstants.card,
        amount: paidAmount,
        paymentMethod: TextConstants.card,
        shiftId: shiftId,
        vendorId: vendorId,
        userId: userId ?? 0,
        serviceType: serviceType,
        datetime: datetime,
        notes: jsonEncode({
          "sunmiTransactionId": fullSunmi["transactionId"],
          "sunmiOrderId": fullSunmi["orderId"],
          "authCode": fullSunmi["authCode"],
          "cardType": fullSunmi["cardType"],
          "maskedCard": fullSunmi["maskedCardNumber"],
          "hostRef": fullSunmi["hostReferenceNumber"],
        }),
        isSynced: false,
        createdAt: DateTime.now(),
        remainingBalance:
        (balanceAmount - paidAmount).clamp(0.0, double.infinity),
        status:
        PaymentDbStatus.pending, // Will be marked completed later if needed
      );

      // 1. Save to Isar
      final savedPayment =
      await LocalPaymentDBHelper.instance.savePayment(localPayment);

      // 2. Save to Hive (this is what powers your session history)
      await _savePaymentToHive(
        amount: paidAmount,
        paymentMethod: TextConstants.card,
        transactionId: "sunmi_${savedPayment.id}",
        localPayment: savedPayment,
      );

      await _saveLocalPaymentToHive(savedPayment);

      // 3. Store last payment info (for void)
      _lastPayment = LastPaymentInfo(
        method: TextConstants.card,
        amount: paidAmount,
        paymentId: savedPayment.id.toString(),
        sunmiTxnId: fullSunmi["transactionId"]?.toString(),
        sunmiOrderId: fullSunmi["orderId"]?.toString(),
        sunmiDeviceId: fullSunmi["deviceID"]?.toString(),
      );

      // 4. Update local state
      _updateLocalPaymentState(paidAmount, savedPayment);

      // 5. Optional: Also try server sync
      _createPaymentFromSunmi(paidAmount, fullSunmi);

      // 6. Show appropriate dialog
      if (balanceAmount > 0) {
        _showPartialPaymentDialog(context, paidAmount);
      } else {
        _showPaymentSuccessPopup(paidAmount, savedPayment);
      }
    } catch (e, stack) {
      print("Sunmi Card Payment Error: $e");
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Card payment faileddddddd: $e"),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _processingPaymentMethod = null;
        isLoading = false;
      });
    }
  }

  Future<void> _createPaymentFromSunmi(
      double amount,
      Map<String, dynamic> sunmi,
      ) async {
    final String datetime =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final paymentRequest = PaymentRequestModel(
      title: "Card",
      orderId: orderId ?? 0,
      amount: amount,
      paymentMethod: TextConstants.card,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetime,
      notes: jsonEncode({
        "sunmiTransactionId": sunmi["transactionId"],
        "sunmiOrderId": sunmi["orderId"],
        "authCode": sunmi["authCode"],
        "cardType": sunmi["cardType"],
        "maskedCard": sunmi["maskedCardNumber"],
        "hostRef": sunmi["hostReferenceNumber"],
      }),
    );

    //  REQUEST LOG
    print(" ================= SUNMI PAYMENT REQUEST =================");
    print(paymentRequest);
    print("=========================================================");

    // paymentBloc.createPayment(paymentRequest);

    StreamSubscription? subscription;
    subscription =
        paymentBloc.createPaymentStream.listen((paymentResponse) async {
          print("");
          print(" ================= SUNMI PAYMENT FULL RESPONSE =================");

          print("STATUS → ${paymentResponse.status}");
          print("RAW RESPONSE OBJECT → $paymentResponse");

          //  ERROR
          if (paymentResponse.status == Status.ERROR) {
            print(" ERROR MESSAGE → ${paymentResponse.message}");
            print(" ERROR DATA → ${paymentResponse.data}");
            print(
                "===============================================================");
            subscription?.cancel();
            return;
          }

          //  SUCCESS
          if (paymentResponse.status == Status.COMPLETED &&
              paymentResponse.data != null) {
            final data = paymentResponse.data!;

            print(" MESSAGE → ${data.message}");
            print(" PAYMENT ID → ${data.paymentId}");
            print(" ORDER ID → ${data.orderId}");
            print("ORDER STATUS → ${data.orderStatus}");

            // =====================================================
            //  STORE LAST PAYMENT INFO (FOR VOID)
            //=====================
            _lastPayment = LastPaymentInfo(
              method: TextConstants.card,
              amount: amount,
              paymentId: data.paymentId?.toString(),

              sunmiTxnId: sunmi["transactionId"]?.toString(),
              sunmiOrderId: sunmi["orderId"]?.toString(),
              sunmiDeviceId: sunmi["deviceID"]?.toString(), //  FIX
            );

// Keep for API void usage
            paymentId = data.paymentId?.toString();

            // =====================================================
            //  SAVE TO HIVE (SURVIVES APP RESTART)
            // =====================================================
            try {
              final box = StorageProvider.offlineOrders;
              final key = (orderId ?? 0).toString();

              final hasKey = await box.containsKey(key);
              final raw = hasKey ? await box.get(key) : null;
              final existing = Map<String, dynamic>.from(raw is Map ? raw : {});

              existing["lastPayment"] = _lastPayment!.toJson();
              await box.put(key, existing);

              print("💾 LAST PAYMENT SAVED TO HIVE");
              print("   → method = ${_lastPayment!.method}");
              print("   → amount = ${_lastPayment!.amount}");
              print("   → sunmiTxn = ${_lastPayment!.sunmiTxnId}");
              print("   → paymentId = ${_lastPayment!.paymentId}");
            } catch (e) {
              print(" Failed saving last payment to Hive: $e");
            }

            // 🔹 FULL DATA DUMP
            try {
              print("📦 FULL DATA JSON ↓↓↓");
              print(jsonEncode(data.toJson()));
            } catch (e) {
              print("⚠ toJson() not available");
              print(data);
            }
          }

          print("===============================================================");
          subscription?.cancel();
        });
  }

  Future<void> updateOfflineOrderRedeem(
      String orderId,
      double redeemedValue,
      int redeemedPoints,
      int updatedAvailablePoints,
      ) async {
    final box = StorageProvider.offlineOrders;
    final existing = await box.get(orderId);

    if (existing == null) {
      print("[Hive] Cannot update redeem → Order not found: $orderId");
      return;
    }

    final updated = Map<String, dynamic>.from(existing);

    updated["redeemed_value"] = redeemedValue;
    updated["redeemed_points"] = redeemedPoints;
    updated["available_points_after_redeem"] = updatedAvailablePoints;

    await box.put(orderId, updated);

    print(
        " [Hive] Saved redeem → ID: $orderId | value: $redeemedValue | points: $redeemedPoints | left: $updatedAvailablePoints");
  }

  void _recalculateAfterPayment(double amount) {
    double remaining = balanceAmount;

    // 1 If paying by EBT
    if (selectedPaymentMethod == TextConstants.ebtText) {
      if (amount >= ebtTotal) {
        // Full EBT paid
        amount -= ebtTotal;
        remaining -= ebtTotal;
        ebtTotal = 0;
      } else {
        // Partial EBT payment
        ebtTotal -= amount;
        remaining -= amount;
        amount = 0;
      }
    }

    // 2 If paying by CASH or CARD etc.
    else {
      double nonEbtBalance =
          remaining - ebtTotal; // balance that cash CAN pay safely

      if (amount <= nonEbtBalance) {
        // Case 1 → cash does NOT affect EBT
        remaining -= amount;
      } else {
        // Case 2 → extra cash reduces EBT
        double extraCash = amount - nonEbtBalance;

        // Reduce EBT by that extra amount
        ebtTotal = (ebtTotal - extraCash).clamp(0, double.infinity);

        // New remaining balance becomes exactly new EBT
        remaining = ebtTotal;
      }
    }

    balanceAmount = remaining.clamp(0, double.infinity);

    setState(() {});
  }

  Future<void> removeOfflineOrderRedeem(String orderId) async {
    final box = StorageProvider.offlineOrders;
    final existing = await box.get(orderId);

    if (existing == null) return;

    final updated = Map<String, dynamic>.from(existing);

    updated.remove("redeemed_value");
    updated.remove("redeemed_points");
    updated.remove("available_points_after_redeem");

    await box.put(orderId, updated);

    if (kDebugMode) {
      print("🗑 [Hive] Redeem REMOVED → OrderId: $orderId");
    }
  }

  Future<void> _fetchPaymentsByOrderId() async {
    if (kDebugMode) print("###### _fetchPaymentsByOrderId");

    if (orderId == null) return;

    final box = StorageProvider.offlineOrders;
    final key = orderId.toString();

    // ================================
    //  RESTORE REDEEM
    // ================================
    try {
      if (await box.containsKey(key)) {
        final rawStored = await box.get(key);
        final stored =
        Map<String, dynamic>.from(rawStored is Map ? rawStored : {});
        redeemedValue = (stored["redeemed_value"] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {
      redeemedValue = 0.0;
    }

    // ================================
    //  RESTORE REMAINING EBT (fallback: original)
    // ================================
    try {
      if (await box.containsKey(key)) {
        final rawStored = await box.get(key);
        final stored =
        Map<String, dynamic>.from(rawStored is Map ? rawStored : {});
        if (stored["remainingEbt"] != null) {
          ebtTotal = (stored["remainingEbt"] as num).toDouble();
        } else if (stored["originalEbt"] != null) {
          ebtTotal = (stored["originalEbt"] as num).toDouble();
        }
      }
    } catch (_) {}

    setState(() => isSummaryLoading = true);

    paymentBloc.getPaymentsByOrderId(orderId!);

    _paymentListSubscription?.cancel();
    _paymentListSubscription =
        paymentBloc.paymentsListStream.listen((response) async {
          if (response.status == Status.COMPLETED) {
            final data = response.data ?? [];
            if (data.isNotEmpty) {
              await _processPaymentList(data);
            } else {
              // API returned empty - use LocalPayment as source of truth
              // (fixes balance showing net payable when payments exist locally but not yet synced)
              await _calculateBalanceFromPaymentHistory();
            }
          }
          if (mounted) setState(() => isSummaryLoading = false);
        });
  }

  Future<void> _processPaymentList(List<PaymentListModel> payments) async {
    // When API returns empty but we may have local payments, prefer LocalPayment
    if (payments.isEmpty) {
      await _calculateBalanceFromPaymentHistory();
      return;
    }

    double cashTotal = 0.0;
    double otherTotal = 0.0;
    double ebtPaid = 0.0;

    // ===================================================
    // 1 ACCUMULATE NON-VOID PAYMENTS
    // ===================================================
    for (final payment in payments) {
      if (payment.voidStatus) continue;

      final amount = double.tryParse(payment.amount) ?? 0.0;

      if (payment.paymentMethod == TextConstants.ebtText) {
        ebtPaid += amount;
      } else if (payment.paymentMethod == TextConstants.cash) {
        cashTotal += amount;
      } else {
        otherTotal += amount;
      }
    }

    final box = StorageProvider.offlineOrders;
    final key = orderId.toString();

    final hasKey = await box.containsKey(key);
    final raw = hasKey ? await box.get(key) : null;
    final existing = Map<String, dynamic>.from(raw is Map ? raw : {});

    // ===================================================
    //  SINGLE SOURCE OF TRUTH
    // ===================================================
    final double basePayable = computedNetPayable;

    // ===================================================
    // LOCK ORIGINAL EBT
    // ===================================================
    final double originalEbt =
        (existing["originalEbt"] as num?)?.toDouble() ?? ebtTotal;

    existing["originalEbt"] ??= originalEbt;

    // ===================================================
    //  REMAINING EBT AFTER EBT PAYMENTS
    // ===================================================
    final double remainingEbt =
    originalEbt - ebtPaid < 0 ? 0.0 : originalEbt - ebtPaid;

    // ===================================================
    //  NON-EBT PORTION
    // ===================================================
    final double nonEbtOrderValue =
    basePayable - originalEbt < 0 ? 0.0 : basePayable - originalEbt;

    final double nonEbtPaid = cashTotal + otherTotal;

    // ===================================================
    //  CASH / CARD OVERFLOW REDUCES EBT
    // ===================================================
    final double overflowToEbt =
    nonEbtPaid > nonEbtOrderValue ? nonEbtPaid - nonEbtOrderValue : 0.0;

    final double finalRemainingEbt =
    remainingEbt - overflowToEbt < 0 ? 0.0 : remainingEbt - overflowToEbt;

    // ===================================================
    //  APPLY REDEEM (DISCOUNT ONLY)
    // ===================================================
    final double effectiveOrderTotal = basePayable - redeemedValue;

    // ===================================================
    //  TOTAL PAID
    // ===================================================
    final double totalPaid = cashTotal + otherTotal + ebtPaid;

    final double rawBalance = effectiveOrderTotal - totalPaid;

// Balance should NEVER be negative
    final double finalBalance = rawBalance > 0 ? rawBalance : 0.0;

// Change only if overpaid
    final double changeAmount = rawBalance < 0 ? rawBalance.abs() : 0.0;

    final Map<String, dynamic> couponResponse =
        (existing["coupon_response"] as Map?)?.cast<String, dynamic>() ?? {};

    // ===================================================
    //  UPDATE UI
    // ===================================================
    setState(() {
      payByCash = cashTotal;
      payByOther = otherTotal;
      payByEbt = ebtPaid;

      ebtTotal = finalRemainingEbt;
      tenderAmount = totalPaid;

      balanceAmount = finalBalance; //  never negative
      isPaymentStarted = totalPaid > 0;

      if (isPaymentStarted) {
        isRedeemActive = false;
      }

      _paymentDialogShown = false;
    });

    // ===================================================
    //  SAVE TO HIVE
    // ===================================================
    existing["remainingEbt"] = finalRemainingEbt;
    existing["redeemed_value"] = redeemedValue;
    existing["remainingBalance"] = finalBalance;

    await box.put(key, existing);

    if (kDebugMode) {
      print(" PAYMENT SUMMARY");
      print("Base Payable      = $basePayable");
      print("Redeem            = $redeemedValue");
      print("Cash              = $cashTotal");
      print("Other             = $otherTotal");
      print("EBT Paid          = $ebtPaid");
      print("Remaining EBT     = $finalRemainingEbt");
      print("Total Paid        = $totalPaid");
      print("Balance           = $finalBalance");
    }

    // ===================================================
// RESET SUCCESS POPUP AFTER VOID / PARTIAL PAYMENT
// ===================================================
    if (finalBalance > 0) {
      _successPopupShown = false;
    }

    // ===================================================
    //  PAYMENT COMPLETE (ZERO OR NEGATIVE)
    // ===================================================
    // if (payments.isNotEmpty && finalBalance <= 0) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _showPaymentDialog(
    //       context,
    //       tenderAmount,
    //       changeAmount: changeAmount, //  negative allowed
    //       showChange: true,
    //       couponResponse: couponResponse,
    //     );
    //   });
    // }
  }

  void _toggleSummary() {
    setState(() {
      _showFullSummary = !_showFullSummary;
    });
  }

  void deleteItemFromOrder(dynamic itemId) async {
    setState(() {
      orderItems.removeWhere((item) => item[AppDBConst.itemId] == itemId);
      _syncEbtTotalWithOrderItems();   // ← ADD THIS
    });
  }


  Future<void> _voidCardPaymentViaKickbackAPI({
    required String transactionId,
    required String paymentId,
    required int wooOrderId,
  }) async {
    if (transactionId.isEmpty) {
      if (kDebugMode) print("⚠️ Kickback void skipped – no transaction_id");
      return;
    }

    try {
      final String token = await _getTokenFromDb();

      final uri = Uri.parse(
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.payments}/void-kickback-transaction",
      );

      if (kDebugMode) {
        print("🔄 Voiding card via kickback API");
        print("   order_id: $wooOrderId");
        print("   payment_id: $paymentId");
        print("   transaction_id: $transactionId");
      }

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "order_id": wooOrderId.toString(),
          "payment_id": paymentId,
          "transaction_id": transactionId,
        }),
      );

      if (kDebugMode) {
        print("Kickback void response: ${response.statusCode}");
        print("Body: ${response.body}");
      }

      final Map<String, dynamic> body =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (body["success"] == true) {
        if (kDebugMode) print("✅ Kickback card void successful");
      } else {
        if (kDebugMode) {
          print("Kickback card void failed: ${body["message"]}");
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print(" _voidCardPaymentViaKickbackAPI error: $e");
        print(st);
      }
    }
  }

  Future<void> _voidServerPaymentIfCard({required String? serverPaymentId}) async {
    if (kDebugMode) {
      print(" ===== _voidServerPaymentIfCard CALLED =====");
      print("   serverPaymentId  : $serverPaymentId");
      print("   _lastPayment     : ${_lastPayment?.toJson()}");
    }

    if (serverPaymentId == null || serverPaymentId.isEmpty) {
      if (kDebugMode) print(" Card void skipped – no server payment_id");
      return;
    }

    final int wooOrderId = await _resolveWooOrderIdForPayment(forceSync: false);
    if (kDebugMode) print("   wooOrderId resolved: $wooOrderId");

    if (wooOrderId <= 0) {
      if (kDebugMode) print(" Card void skipped – wooOrderId missing");
      return;
    }

    // ── STEP 1: Try transactionId from in-memory _lastPayment ──────────────
    String? txnId = _lastPayment?.transactionId;
    if (kDebugMode) print("   transactionId from _lastPayment: $txnId");

    // ── STEP 2: If null, recover from Hive (handles screen-reload case) ─────
    if (txnId == null || txnId.isEmpty) {
      if (kDebugMode) print("🔍 transactionId not in memory → checking Hive...");
      try {
        final String orderKey = widget.offlineOrderId?.toString() ??
            widget.orderId?.toString() ??
            orderId?.toString() ??
            "";
        if (orderKey.isNotEmpty) {
          final box = StorageProvider.offlineOrders;
          final rawHive = await box.get(orderKey);
          if (rawHive is Map) {
            final hiveMap = Map<String, dynamic>.from(rawHive);
            final dynamic lastPaymentRaw = hiveMap["lastPayment"];
            if (lastPaymentRaw is Map) {
              final Map<String, dynamic> lastPaymentMap =
              Map<String, dynamic>.from(lastPaymentRaw);
              txnId = lastPaymentMap["transactionId"]?.toString();
              if (kDebugMode) {
                print("   Hive lastPayment: $lastPaymentMap");
                print("   transactionId recovered from Hive: $txnId");
              }
            } else {
              if (kDebugMode) print("   Hive lastPayment key missing or not a Map");
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("⚠️ Failed to read transactionId from Hive: $e");
      }
    }

    // ── STEP 3: Route to kickback API if we have a transactionId ────────────
    if (txnId != null && txnId.isNotEmpty) {
      if (kDebugMode) {
        print("✅ transactionId found → routing to kickback void API");
        print("   txnId      : $txnId");
        print("   paymentId  : $serverPaymentId");
        print("   wooOrderId : $wooOrderId");
      }
      await _voidCardPaymentViaKickbackAPI(
        transactionId: txnId,
        paymentId: serverPaymentId,
        wooOrderId: wooOrderId,
      );
      return;
    }

    // ── STEP 4: Fallback to old void API (no transactionId available) ────────
    if (kDebugMode) {
      print("⚠️ No transactionId found anywhere → falling back to old void API");
      print("   paymentId  : $serverPaymentId");
      print("   wooOrderId : $wooOrderId");
    }

    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = paymentBloc.voidPaymentStream.listen((response) {
      if (response.status == Status.COMPLETED ||
          response.status == Status.ERROR) {
        if (kDebugMode) {
          print(
              "Old void API → ${response.status} ${response.message ?? response.data?.message}");
        }
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });


    paymentBloc.voidPayment(VoidPaymentRequestModel(
      orderId: wooOrderId,
      paymentId: serverPaymentId,
    ));

    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        if (kDebugMode) print("⚠️ Old void API timed out");
        sub.cancel();
      },
    );

    if (kDebugMode) print("🔴 ===== _voidServerPaymentIfCard DONE =====");
  }

  // Add this helper method to the class
  Future<http.Response> _postWithRedirect(Uri uri, {required Map<String, String> headers, required String body}) async {
    final client = http.Client();
    try {
      var response = await client.post(uri, headers: headers, body: body);

      // Handle 307 redirect
      if (response.statusCode == 307 || response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'];
        if (location != null) {
          final redirectUri = Uri.parse(location);
          response = await client.post(redirectUri, headers: headers, body: body);
        }
      }
      return response;
    } finally {
      client.close();
    }
  }

  Future<String> _getTokenFromDb() async {
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

    final token = result.first[AppDBConst.userToken] as String;
    if (kDebugMode) print('Token from DB: $token');
    return token;
  }

  /// Pay Later only supports paying the FULL balance — disable the button
  /// whenever the user has typed a partial amount into the keypad.
  bool _isPartialAmountEntered() {
    final double enteredAmount = double.tryParse(
      amountController.text
          .replaceAll(TextConstants.currencySymbol, '')
          .trim(),
    ) ??
        0.0;

    final double effectiveBalance =
        _currentPaymentRemainingBalance ?? balanceAmount;

    return enteredAmount > 0 && enteredAmount < (effectiveBalance - 0.01);
  }

  // Future<void> _handlePayLaterPayment() async {
  //   // Safety guard — button is already disabled for this case, but re-check.
  //   setState(() => _amountErrorText = null);
  //
  //   // ⭐ NEW: Require an amount to be entered/selected first — same validation
  //   // Cash and Card use. Without this, tapping Pay Later at $0.00 skipped
  //   // straight to the popup + sync, which is wrong.
  //   final double enteredAmount = double.tryParse(
  //     amountController.text
  //         .replaceAll(TextConstants.currencySymbol, '')
  //         .trim(),
  //   ) ??
  //       0.0;
  //
  //   if (enteredAmount <= 0 && computedNetPayable > 0) {
  //     setState(() => _amountErrorText = TextConstants.amountValidation);
  //     return;
  //   }
  //
  //   if (_isPartialAmountEntered()) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Pay Later cannot be used with a partial amount"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   final double effectiveBalance =
  //       _currentPaymentRemainingBalance ?? balanceAmount;
  //
  //   if (effectiveBalance <= 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Nothing to pay"),
  //         backgroundColor: Colors.orange,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   // ── Show the Pay Later customer-picker popup ───────────────────────────
  //   final dynamic selectedUser = await showDialog<dynamic>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => Dialog(
  //       backgroundColor: Colors.transparent,
  //       elevation: 0,
  //       insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
  //       child: PayLaterWidget(),
  //     ),
  //   );
  //
  //   // Cancel tapped (or dialog dismissed) → just stay on Order Summary.
  //   if (selectedUser == null) {
  //     if (kDebugMode) print(" Pay Later cancelled by user");
  //     return;
  //   }
  //
  //   setState(() {
  //     _selectedPayLaterUser = Map<String, dynamic>.from(selectedUser as Map);
  //     _isPayLaterSelected = true;
  //     _processingPaymentMethod = "Pay Later";
  //     isLoading = true;
  //   });
  //
  //   _showPaymentProgressDialog(context);
  //
  //   try {
  //     final box = StorageProvider.offlineOrders;
  //     final String orderKey = widget.offlineOrderId?.toString() ??
  //         widget.orderId?.toString() ??
  //         orderId?.toString() ??
  //         "";
  //
  //     if (orderKey.isEmpty) {
  //       _hidePaymentProgressDialog();
  //       setState(() {
  //         isLoading = false;
  //         _processingPaymentMethod = null;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Could not resolve order"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     final raw = await box.get(orderKey);
  //     final Map<String, dynamic> order =
  //     raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  //
  //     // ── Attach Pay Later customer to the offline order BEFORE syncing ────
  //     order['selectedPayLaterUser'] =
  //     Map<String, dynamic>.from(_selectedPayLaterUser!);
  //     order['is_pay_later_order'] = true;
  //     order['payment_method'] = "Pay Later";
  //
  //     await box.put(orderKey, order);
  //
  //     if (kDebugMode) {
  //       print("✅ Pay Later user saved to Hive before sync: "
  //           "${_selectedPayLaterUser!['name']} (ID: ${_selectedPayLaterUser!['user_id']})");
  //     }
  //
  //     // ── Sync the order (with the Pay Later user attached) to the server ──
  //     final result = await OrderRepository().syncSingleOfflineOrder(order);
  //
  //     if (result == null || result is! Map) {
  //       _hidePaymentProgressDialog();
  //       setState(() {
  //         isLoading = false;
  //         _processingPaymentMethod = null;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Failed to sync Pay Later order"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     _hidePaymentProgressDialog();
  //
  //     // ── Treat this as a full payment (Pay Later covers the whole balance)─
  //     final double amount = effectiveBalance;
  //     final double newTender = tenderAmount + amount;
  //
  //     _lastPayment = LastPaymentInfo(
  //       method: "Pay Later",
  //       amount: amount,
  //       paymentId: "paylater_${DateTime.now().millisecondsSinceEpoch}",
  //       sunmiTxnId: null,
  //     );
  //
  //     final String datetimeStr =
  //     DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  //
  //     final localPayment = LocalPayment(
  //       orderId: orderId ?? 0,
  //       title: "Pay Later",
  //       amount: amount,
  //       paymentMethod: "Pay Later",
  //       shiftId: shiftId,
  //       vendorId: vendorId,
  //       userId: userId ?? 0,
  //       serviceType: serviceType,
  //       datetime: datetimeStr,
  //       notes:
  //       "Pay Later – assigned to ${_selectedPayLaterUser?['name'] ?? 'customer'} "
  //           "(ID: ${_selectedPayLaterUser?['user_id']})",
  //       isSynced: true,
  //       createdAt: DateTime.now(),
  //       remainingBalance: 0.0,
  //       status: PaymentDbStatus.completed,
  //     );
  //
  //     final savedPayment =
  //     await LocalPaymentDBHelper.instance.savePayment(localPayment);
  //
  //     await _savePaymentToHive(
  //       amount: amount,
  //       paymentMethod: "Pay Later",
  //       transactionId: "paylater_${savedPayment.id}",
  //       localPayment: savedPayment,
  //     );
  //     await _saveLocalPaymentToHive(savedPayment);
  //
  //     setState(() {
  //       isPaymentStarted = true;
  //       isLoading = false;
  //       _processingPaymentMethod = null;
  //       paidAmount = amount;
  //       tenderAmount = newTender;
  //       balanceAmount = 0.0;
  //       changeAmount = 0.0;
  //       payByOther += amount; // Pay Later rolls up under "Other" totals
  //       _currentPaymentRemainingBalance = null;
  //       _lastPaymentDetails = null;
  //       _successPopupShown = true;
  //     });
  //
  //     _resetAmountAfterPay();
  //
  //     final cr = order["coupon_response"];
  //     final couponResponse =
  //     cr is Map ? Map<String, dynamic>.from(cr) : <String, dynamic>{};
  //
  //     // ── Show the same full-payment success popup as cash/card/EBT ────────
  //     _showPaymentDialog(
  //       context,
  //       newTender,
  //       changeAmount: 0.0,
  //       showChange: false,
  //       couponResponse: couponResponse,
  //     );
  //   } catch (e, st) {
  //     if (kDebugMode) {
  //       print("❌ _handlePayLaterPayment error: $e");
  //       print(st);
  //     }
  //     _hidePaymentProgressDialog();
  //     setState(() {
  //       isLoading = false;
  //       _processingPaymentMethod = null;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text("Pay Later error: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  ///// above code was old and working

  Future<void> _handlePayLaterPayment() async {
    // Safety guard — button is already disabled for this case, but re-check.
    setState(() => _amountErrorText = null);

    // ⭐ NEW: Require an amount to be entered/selected first — same validation
    // Cash and Card use. Without this, tapping Pay Later at $0.00 skipped
    // straight to the popup + sync, which is wrong.
    final double enteredAmount = double.tryParse(
      amountController.text
          .replaceAll(TextConstants.currencySymbol, '')
          .trim(),
    ) ??
        0.0;

    if (enteredAmount <= 0 && computedNetPayable > 0) {
      setState(() => _amountErrorText = TextConstants.amountValidation);
      return;
    }

    if (_isPartialAmountEntered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pay Later cannot be used with a partial amount"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double effectiveBalance =
        _currentPaymentRemainingBalance ?? balanceAmount;

    if (effectiveBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nothing to pay"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ⭐ FIX: Cap the entered amount to the effective balance (like Cash/Card)
    // This prevents Pay Later from taking more than the remaining balance
    double amountToUse = enteredAmount;

    // If entered amount exceeds balance, cap it to the balance
    if (enteredAmount > effectiveBalance) {
      amountToUse = effectiveBalance;

      // Update the UI to show the capped amount
      _rawAmount = (amountToUse * 100).round();
      amountController.text =
      '${TextConstants.currencySymbol}${amountToUse.toStringAsFixed(2)}';
      setState(() {
        _isAmountEntered = true;
        _amountErrorText = null;
      });

      // Show a snackbar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Amount adjusted to remaining balance (${TextConstants.currencySymbol}${amountToUse.toStringAsFixed(2)})'
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (amountToUse <= 0) {
      setState(() => _amountErrorText = TextConstants.amountValidation);
      return;
    }

    // ── Show the Pay Later customer-picker popup ───────────────────────────
    final dynamic selectedUser = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: PayLaterWidget(),
      ),
    );

    // Cancel tapped (or dialog dismissed) → just stay on Order Summary.
    if (selectedUser == null) {
      if (kDebugMode) print(" Pay Later cancelled by user");
      return;
    }

    setState(() {
      _selectedPayLaterUser = Map<String, dynamic>.from(selectedUser as Map);
      _isPayLaterSelected = true;
      _processingPaymentMethod = "Pay Later";
      isLoading = true;
    });

    _showPaymentProgressDialog(context);

    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.offlineOrderId?.toString() ??
          widget.orderId?.toString() ??
          orderId?.toString() ??
          "";

      if (orderKey.isEmpty) {
        _hidePaymentProgressDialog();
        setState(() {
          isLoading = false;
          _processingPaymentMethod = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not resolve order"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final raw = await box.get(orderKey);
      final Map<String, dynamic> order =
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      // ── Attach Pay Later customer to the offline order BEFORE syncing ────
      order['selectedPayLaterUser'] =
      Map<String, dynamic>.from(_selectedPayLaterUser!);
      order['is_pay_later_order'] = true;
      order['payment_method'] = "Pay Later";

      await box.put(orderKey, order);

      if (kDebugMode) {
        print("✅ Pay Later user saved to Hive before sync: "
            "${_selectedPayLaterUser!['name']} (ID: ${_selectedPayLaterUser!['user_id']})");
      }

      // ── Sync the order (with the Pay Later user attached) to the server ──
      final result = await OrderRepository().syncSingleOfflineOrder(order);

      if (result == null || result is! Map) {
        _hidePaymentProgressDialog();
        setState(() {
          isLoading = false;
          _processingPaymentMethod = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to sync Pay Later order"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _hidePaymentProgressDialog();

      // ⭐ FIX: Use the capped amount (amountToUse) instead of effectiveBalance
      // This ensures Pay Later only takes the exact amount entered (capped at balance)
      final double amount = amountToUse;
      final double newTender = tenderAmount + amount;

      _lastPayment = LastPaymentInfo(
        method: "Pay Later",
        amount: amount,
        paymentId: "paylater_${DateTime.now().millisecondsSinceEpoch}",
        sunmiTxnId: null,
      );

      final String datetimeStr =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final localPayment = LocalPayment(
        orderId: orderId ?? 0,
        title: "Pay Later",
        amount: amount,
        paymentMethod: "Pay Later",
        shiftId: shiftId,
        vendorId: vendorId,
        userId: userId ?? 0,
        serviceType: serviceType,
        datetime: datetimeStr,
        notes:
        "Pay Later – assigned to ${_selectedPayLaterUser?['name'] ?? 'customer'} "
            "(ID: ${_selectedPayLaterUser?['user_id']})",
        isSynced: true,
        createdAt: DateTime.now(),
        remainingBalance: (effectiveBalance - amount).clamp(0.0, double.infinity),
        status: PaymentDbStatus.completed,
      );

      final savedPayment =
      await LocalPaymentDBHelper.instance.savePayment(localPayment);

      await _savePaymentToHive(
        amount: amount,
        paymentMethod: "Pay Later",
        transactionId: "paylater_${savedPayment.id}",
        localPayment: savedPayment,
      );
      await _saveLocalPaymentToHive(savedPayment);

      // Calculate new balance after this payment
      final double newBalance = (effectiveBalance - amount).clamp(0.0, double.infinity);
      final bool isFullPayment = newBalance <= 0.01;

      setState(() {
        isPaymentStarted = true;
        isLoading = false;
        _processingPaymentMethod = null;
        paidAmount = amount;
        tenderAmount = newTender;
        balanceAmount = newBalance;
        changeAmount = 0.0;
        payByOther += amount; // Pay Later rolls up under "Other" totals

        if (isFullPayment) {
          _currentPaymentRemainingBalance = null;
          _lastPaymentDetails = null;
          _successPopupShown = true;
        } else {
          _currentPaymentRemainingBalance = newBalance;
          _lastPaymentDetails = {
            'amount': amount,
            'method': "Pay Later",
            'remainingBalance': newBalance,
            'previousBalance': effectiveBalance,
            'datetime': DateTime.now().toIso8601String(),
            'paymentNumber': (_lastPaymentDetails?['paymentNumber'] ?? 0) + 1,
          };
        }
      });

      _resetAmountAfterPay();

      final cr = order["coupon_response"];
      final couponResponse =
      cr is Map ? Map<String, dynamic>.from(cr) : <String, dynamic>{};

      // ── Show appropriate dialog based on payment status ──
      if (isFullPayment) {
        _successPopupShown = true;
        await CustomerDisplayService.showThankYou();
        await orderHelper.setActiveOrder(null);
        await CustomerDisplayService.resetDisplay();
        unawaited(_publishMqttThankYouThenWelcome());

        _showPaymentDialog(
          context,
          newTender,
          changeAmount: 0.0,
          showChange: false,
          couponResponse: couponResponse,
        );
      } else {
        _showPartialPaymentDialog(context, amount);
      }
    } catch (e, st) {
      if (kDebugMode) {
        print("❌ _handlePayLaterPayment error: $e");
        print(st);
      }
      _hidePaymentProgressDialog();
      setState(() {
        isLoading = false;
        _processingPaymentMethod = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pay Later error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleEbtCardPaymentViaAPI() async {
    final double amount = double.tryParse(
      amountController.text
          .replaceAll(TextConstants.currencySymbol, '')
          .trim(),
    ) ??
        0.0;

    if (amount <= 0) {
      setState(() => _amountErrorText = TextConstants.amountValidation);
      return;
    }

    // EBT-specific validation
    final int enteredCents = (amount * 100).round();
    final int ebtCents = (ebtTotal * 100).round();

    if (ebtCents <= 0) {
      setState(() => _amountErrorText = "No EBT balance available");
      return;
    }
    if (enteredCents > ebtCents) {
      setState(() => _amountErrorText =
      "Amount cannot exceed available EBT balance (\$${ebtTotal.toStringAsFixed(2)})");
      return;
    }

    _amountErrorText = null;

    // ── 1. Show loading ──────────────────────────────────────
    setState(() {
      isLoading = true;
      _processingPaymentMethod = TextConstants.ebtText;
    });
    _showPaymentProgressDialog(context);

    try {
      // ── 2. Sync offline order → get WooCommerce order id ──
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.offlineOrderId?.toString() ??
          widget.orderId?.toString() ??
          orderId?.toString() ??
          "";

      int wooOrderId = 0;

      if (orderKey.isNotEmpty) {
        final raw = await box.get(orderKey);
        if (raw is Map) {
          final offlineMap = Map<String, dynamic>.from(raw);

          final cached = offlineMap["wooOrderId"];
          wooOrderId = (cached is int)
              ? cached
              : int.tryParse(cached?.toString() ?? "") ?? 0;

          if (wooOrderId == 0) {
            final syncResult =
            await OrderRepository().syncSingleOfflineOrder(offlineMap);
            if (syncResult is Map) {
              wooOrderId = (syncResult?["id"] as num?)?.toInt() ?? 0;
              offlineMap["wooOrderId"] = wooOrderId;
              await box.put(orderKey, offlineMap);
            }
          }
        }
      }

      if (wooOrderId == 0) {
        wooOrderId = widget.orderId ?? orderId ?? 0;
      }

      if (wooOrderId == 0) {
        _hidePaymentProgressDialog();
        setState(() {
          isLoading = false;
          _processingPaymentMethod = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not resolve order – please try again"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ── 3. Build auth header ──────────────────────────────
      final String token = await _getTokenFromDb();

      // ── 4. Call create-payment API ────────────────────────
      if (_isCardPaymentCancelled) return;

// === API Call ===
      final uri = Uri.parse(
        "${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.payments}/create-payment",
      );

      final requestBody = {
        "order_id": wooOrderId,
        "amount": amount,
        "payment_method": "card",
        "shift_id": shiftId,
      };

// Print request details
      print("API URLllllll: $uri");
      print("Request Body: ${jsonEncode(requestBody)}");

      final http.Response response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

// Print response details
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      _hidePaymentProgressDialog();
      setState(() {
        isLoading = false;
        _processingPaymentMethod = null;
      });

      if (kDebugMode) {
        print("EBT payment API → ${response.statusCode}");
        print("Body: ${response.body}");
      }

      final Map<String, dynamic> body =
      jsonDecode(response.body) as Map<String, dynamic>;

      // ── 5. Handle response ────────────────────────────────
      if (body["success"] != true) {
        final String msg =
            body["message"]?.toString() ?? "EBT payment failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        return;
      }

      // ── 6. success: true → update local state & save ──────
// Refresh payment history FIRST so balanceAmount is accurate
// (card/cash payments already made are reflected correctly)
      await _calculateBalanceFromPaymentHistory();

      final double currentBalance = balanceAmount; // now fresh
      final double newTender = payByEbt + amount;
      double newBalance = (currentBalance - amount).clamp(0.0, double.infinity);
      double newChange = 0.0;
      if (amount > currentBalance) {
        newChange = amount - currentBalance;
        newBalance = 0.0;
      }

// Use a small tolerance for floating point (e.g. 0.01)
      final bool isFullPayment = newBalance <= 0.01;


      final String datetimeStr =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final localPayment = LocalPayment(
        orderId: orderId ?? 0,
        title: TextConstants.ebtText,
        amount: amount,
        paymentMethod: TextConstants.ebtText,
        shiftId: shiftId,
        vendorId: vendorId,
        userId: userId ?? 0,
        serviceType: serviceType,
        datetime: datetimeStr,
        notes: "ebt via API – wooOrderId: $wooOrderId",
        isSynced: true,
        createdAt: DateTime.now(),
        remainingBalance: newBalance,
        status: isFullPayment
            ? PaymentDbStatus.completed
            : PaymentDbStatus.pending,
      );

      final saved =
      await LocalPaymentDBHelper.instance.savePayment(localPayment);

      _lastPayment = LastPaymentInfo(
        method: TextConstants.ebtText,
        amount: amount,
        paymentId: saved.id.toString(),
        sunmiTxnId: null,
        sunmiOrderId: null,
      );

      await _savePaymentToHive(
        amount: amount,
        paymentMethod: TextConstants.ebtText,
        transactionId: "ebt_api_${saved.id}",
        localPayment: saved,
      );
      await _saveLocalPaymentToHive(saved);

      setState(() {
        isPaymentStarted = true;
        paidAmount = amount;
        paymentId = saved.id.toString();
        tenderAmount = newTender;
        balanceAmount = newBalance;
        changeAmount = newChange;
        payByEbt += amount;
        // Reduce remaining EBT balance
        ebtTotal = (ebtTotal - amount).clamp(0.0, double.infinity);
        _currentPaymentRemainingBalance =
        isFullPayment ? null : newBalance;
        _lastPaymentDetails = {
          "amount": amount,
          "method": TextConstants.ebtText,
          "remainingBalance": newBalance,
          "previousBalance": currentBalance,
          "datetime": DateTime.now().toIso8601String(),
          "paymentNumber":
          (_lastPaymentDetails?["paymentNumber"] ?? 0) + 1,
        };
      });

      _resetAmountAfterPay();

      // ── 7. Show popup ─────────────────────────────────────

      if (isFullPayment) {
        _successPopupShown = false; // reset so full dialog always shows
        // _successPopupShown = true;
        await CustomerDisplayService.showThankYou();
        await orderHelper.setActiveOrder(null);
        await CustomerDisplayService.resetDisplay();
        unawaited(_publishMqttThankYouThenWelcome());
        final boxData = await box.get(orderKey);
        final cr = boxData is Map ? boxData["coupon_response"] : null;
        final couponResponse = cr is Map
            ? Map<String, dynamic>.from(cr)
            : <String, dynamic>{};

        _showPaymentDialog(
          context,
          newTender,
          changeAmount: newChange,
          showChange: newChange > 0,
          couponResponse: couponResponse,
        );
      } else if (!isFullPayment && amount > 0) {
        _showPartialPaymentDialog(context, amount);
      }
    } catch (e, st) {
      _hidePaymentProgressDialog();
      setState(() {
        isLoading = false;
        _processingPaymentMethod = null;
      });
      // Only show error if NOT cancelled by user
      if (!_isCardPaymentCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Payment failed. Please try again."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Reset cancel flag
      _isCardPaymentCancelled = false;
    }
  }

  Future<void> _handleCardPaymentViaAPI() async {
    _isCardPaymentCancelled = false;

    final double enteredAmount = double.tryParse(
      amountController.text
          .replaceAll(TextConstants.currencySymbol, '')
          .trim(),
    ) ??
        0.0;

    if (enteredAmount <= 0) {
      setState(() => _amountErrorText = TextConstants.amountValidation);
      return;
    }

    _recalculateGrossAndNetFromLineItemDiscounts();
    await _recalculateTaxOnDiscountedItems();
    await _calculateBalanceFromPaymentHistory();

    final double effectiveBalance =
        _currentPaymentRemainingBalance ?? balanceAmount;
    final double amount = enteredAmount.clamp(0.0, effectiveBalance + 0.01);

    if ((enteredAmount - amount).abs() > 0.01) {
      setState(() {
        _rawAmount = (amount * 100).round();
        amountController.text =
        '${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}';
        _isAmountEntered = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Amount adjusted to available balance (\$${amount.toStringAsFixed(2)})'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _amountErrorText = null;

    final double balanceBeforePayment = effectiveBalance;
    final bool willBeFullPayment = amount >= (balanceBeforePayment - 0.01);

    if (kDebugMode) {
      print(
          '💰 CARD PAYMENT → Amount: \$$amount | Balance before: \$$balanceBeforePayment');
    }

    setState(() {
      isLoading = true;
      _processingPaymentMethod = TextConstants.card;
    });
    _showPaymentProgressDialog(context);

    try {
      // ── Detect void and clear cached wooOrderId if needed ──────────────
      try {
        final String orderKey = widget.offlineOrderId?.toString() ??
            widget.orderId?.toString() ??
            orderId?.toString() ??
            '';
        if (orderKey.isNotEmpty) {
          final box = StorageProvider.offlineOrders;
          final rawHive = await box.get(orderKey);
          if (rawHive is Map) {
            final hiveMap = Map<String, dynamic>.from(rawHive);
            final int localOrderId = int.tryParse(orderKey) ?? 0;
            if (localOrderId > 0) {
              final payments = await LocalPaymentDBHelper.instance
                  .getPaymentsByOrderId(localOrderId);
              final bool hasVoidedPayment = payments
                  .any((p) => p.status == PaymentDbStatus.voided || p.amount < 0);
              if (hasVoidedPayment) {
                hiveMap['synced'] = false;
                await box.put(orderKey, hiveMap);
                if (kDebugMode) {
                  print(
                      '🔄 Void detected → cleared cached wooOrderId for fresh sync');
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Void-detection pre-check failed (non-fatal): $e');
        }
      }

      int wooOrderId =
      await _resolveWooOrderIdForPayment(forceSync: false);
      if (wooOrderId == 0) {
        _hidePaymentProgressDialog();
        setState(() {
          isLoading = false;
          _processingPaymentMethod = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not resolve order'),
              backgroundColor: Colors.red),
        );
        return;
      }

      if (_isCardPaymentCancelled) return;

      final String token = await _getTokenFromDb();
      if (_isCardPaymentCancelled) return;

      final requestBody = {
        'order_id': wooOrderId,
        'amount': amount ,
        'payment_method': 'card',
        'shift_id': shiftId,
      };

      if (kDebugMode) {
        print('========== CARD PAYMENT REQUEST ==========');
        print('Body: ${jsonEncode(requestBody)}');
        print('==========================================');
      }

      final uri = Uri.parse(
          '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.payments}/create-payment');
      //
      // final http.Response response = await http.post(
      //   uri,
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode(requestBody),
      // );

      final http.Response response = await _postWithRedirect(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      _hidePaymentProgressDialog();
      setState(() {
        isLoading = false;
        _processingPaymentMethod = null;
      });

      if (kDebugMode) {
        print('URL: $uri');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      // final Map<String, dynamic> body =
      // jsonDecode(response.body) as Map<String, dynamic>;

      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        _hidePaymentProgressDialog();
        setState(() {
          isLoading = false;
          _processingPaymentMethod = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Payment failed. Please try again."),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _handleCardPaymentViaAPI();
                },
              ),
            ),
          );
        }
        return;
      }

      if (body['success'] != true) {
        final String msg =
            body['message']?.toString() ?? 'Card payment failed';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
        _resetAmountAfterPay();
        return;
      }

      final String? serverPaymentId = _extractServerPaymentId(body);

      // ── KEY FIX: use helper that reads both top-level and nested fields ──
      final String? cardTransactionId = _extractCardTransactionId(body);

      if (kDebugMode) {
        print(
            'cardTransactionId extracted → $cardTransactionId (serverPaymentId: $serverPaymentId)');
      }

      // ── Cache wooOrderId from response ──────────────────────────────────
      final int responseWooOrderId =
          (body['order_id'] as num?)?.toInt() ?? wooOrderId;
      if (responseWooOrderId > 0) {
        try {
          final box = StorageProvider.offlineOrders;
          final String orderKey = widget.offlineOrderId?.toString() ??
              widget.orderId?.toString() ??
              orderId?.toString() ??
              '';
          if (orderKey.isNotEmpty) {
            final rawHive = await box.get(orderKey);
            if (rawHive is Map) {
              final hiveMap = Map<String, dynamic>.from(rawHive);
              hiveMap['wooOrderId'] = responseWooOrderId;
              hiveMap['synced'] = true;
              hiveMap['sync_at'] = DateTime.now().toIso8601String();
              await box.put(orderKey, hiveMap);
              if (kDebugMode) {
                print(
                    '✅ wooOrderId cached from payment response → $responseWooOrderId');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to cache wooOrderId from response: $e');
          }
        }
      }

      // ── Build _lastPayment with transactionId populated ─────────────────
      _lastPayment = LastPaymentInfo(
        method: TextConstants.card,
        amount: amount,
        paymentId: serverPaymentId,
        transactionId: cardTransactionId, // ← now correctly set
      );

      if (kDebugMode) {
        print('💾 _lastPayment built:');
        print('   method        : ${_lastPayment!.method}');
        print('   amount        : ${_lastPayment!.amount}');
        print('   paymentId     : ${_lastPayment!.paymentId}');
        print('   transactionId : ${_lastPayment!.transactionId}');
      }

      // ── Persist lastPayment (including transactionId) to Hive ───────────
      try {
        final box = StorageProvider.offlineOrders;
        final String orderKey = widget.offlineOrderId?.toString() ??
            widget.orderId?.toString() ??
            orderId?.toString() ??
            '';
        if (orderKey.isNotEmpty) {
          final rawHive = await box.get(orderKey);
          if (rawHive is Map) {
            final hiveMap = Map<String, dynamic>.from(rawHive);
            hiveMap['lastPayment'] = _lastPayment!.toJson();
            await box.put(orderKey, hiveMap);
            if (kDebugMode) {
              print(
                  '✅ lastPayment persisted to Hive → transactionId: $cardTransactionId');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to persist lastPayment to Hive: $e');
        }
      }

      // ── Save locally ─────────────────────────────────────────────────────
      final String datetimeStr =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final localPayment = LocalPayment(
        orderId: orderId ?? 0,
        title: TextConstants.card,
        amount: amount,
        paymentMethod: TextConstants.card,
        shiftId: shiftId,
        vendorId: vendorId,
        userId: userId ?? 0,
        serviceType: serviceType,
        datetime: datetimeStr,
        notes: 'Card payment via API',
        isSynced: true,
        createdAt: DateTime.now(),
        remainingBalance:
        (balanceBeforePayment - amount).clamp(0.0, double.infinity),
        status: PaymentDbStatus.pending,
      );

      final savedPayment =
      await LocalPaymentDBHelper.instance.savePayment(localPayment);

      if (serverPaymentId != null) {
        await LocalPaymentDBHelper.instance
            .markAsSynced(savedPayment.id, int.tryParse(serverPaymentId) ?? 0);
      }

      await _savePaymentToHive(
        amount: amount,
        paymentMethod: TextConstants.card,
        transactionId: 'card_api_${savedPayment.id}',
        localPayment: savedPayment,
      );
      await _saveLocalPaymentToHive(savedPayment);

      // ── Refresh balance ──────────────────────────────────────────────────
      await _calculateBalanceFromPaymentHistory();

      final double finalRemaining =
          _currentPaymentRemainingBalance ?? balanceAmount;
      final bool isActuallyFull = finalRemaining <= 0.01;

      final double newTenderAmount = payByCard;
      final double newChangeAmount = amount > balanceBeforePayment
          ? (amount - balanceBeforePayment)
          : 0.0;

      // ── EBT recalculation ────────────────────────────────────────────────
      final double originalEbt = ebtTotal;
      final double nonEbtOrderValue =
      (computedNetPayable - originalEbt).clamp(0.0, double.infinity);
      final double totalNonEbtPaid = payByCash + payByOther + newTenderAmount;
      final double overflowToEbt =
      totalNonEbtPaid > nonEbtOrderValue
          ? (totalNonEbtPaid - nonEbtOrderValue)
          : 0.0;
      final double newEbtTotal =
      (originalEbt - overflowToEbt).clamp(0.0, double.infinity);

      Future.microtask(() => _recalculateEbtAfterNonEbtPayment?.call());

      setState(() {
        balanceAmount = finalRemaining;
        payByCard = newTenderAmount;
        ebtTotal = newEbtTotal;
        _currentPaymentRemainingBalance =
        isActuallyFull ? null : finalRemaining;
        _lastPaymentDetails = {
          'amount': amount,
          'method': TextConstants.card,
          'remainingBalance': finalRemaining,
          'previousBalance': balanceBeforePayment,
          'datetime': DateTime.now().toIso8601String(),
          'paymentNumber':
          (_lastPaymentDetails?['paymentNumber'] ?? 0) + 1,
        };
      });

      _resetAmountAfterPay();

      // ── Show success or partial dialog ───────────────────────────────────
      if (isActuallyFull) {
        _successPopupShown = true;
        final box = StorageProvider.offlineOrders;
        final key =
        (orderId ?? widget.offlineOrderId ?? 0).toString();
        final raw = await box.get(key);
        final couponResponse =
        (raw is Map && raw['coupon_response'] is Map)
            ? Map<String, dynamic>.from(raw['coupon_response'])
            : <String, dynamic>{};

        if (mounted) {
          await CustomerDisplayService.showThankYou();
          _showPaymentDialog(
            context,
            newTenderAmount,
            changeAmount: newChangeAmount,
            showChange: newChangeAmount > 0,
            couponResponse: couponResponse,
          );
        }
      } else {
        if (mounted) {
          _showPartialPaymentDialog(context, amount);
        }
      }
    } catch (e, st) {
      _hidePaymentProgressDialog();
      setState(() {
        isLoading = false;
        _processingPaymentMethod = null;
        selectedPaymentMethod = TextConstants.cash;
      });
      _resetAmountAfterPay();

      if (kDebugMode) {
        print('❌ _handleCardPaymentViaAPI error: $e');
        print(st);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Card payment error: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  String? _extractCardTransactionId(Map<String, dynamic> body) {
    // 1. Top-level "transaction_id" (present in the response you showed)
    final topLevel = body['transaction_id']?.toString().trim();
    if (topLevel != null && topLevel.isNotEmpty) return topLevel;

    // 2. Nested inside transaction_details (camelCase and snake_case variants)
    final details = body['transaction_details'];
    if (details is Map) {
      final nested = details['transactionid']?.toString().trim() ??
          details['transaction_id']?.toString().trim() ??
          details['transactionId']?.toString().trim();
      if (nested != null && nested.isNotEmpty) return nested;
    }

    return null;
  }

  Future<int> _resolveWooOrderIdForPayment({bool forceSync = true}) async {
    final box = StorageProvider.offlineOrders;
    final String orderKey = widget.offlineOrderId?.toString() ??
        widget.orderId?.toString() ??
        orderId?.toString() ??
        "";

    if (orderKey.isEmpty) {
      return widget.orderId ?? orderId ?? 0;
    }

    final raw = await box.get(orderKey);
    if (raw is! Map) {
      return widget.orderId ?? orderId ?? 0;
    }

    var offlineMap = Map<String, dynamic>.from(raw);
    final int localId = orderId ?? int.tryParse(orderKey) ?? 0;
    if (localId > 0) {
      offlineMap['id'] ??= localId;
      offlineMap['order_id'] ??= localId;
    }

    // ── STEP 1: Read cached wooOrderId (never cleared – the critical fix) ──────
    int wooOrderId =
        int.tryParse(offlineMap['wooOrderId']?.toString() ?? '') ?? 0;

    if (wooOrderId > 0) {
      if (kDebugMode) {
        print('✅ [resolveWooOrderId] Using cached wooOrderId: $wooOrderId');
      }
      return wooOrderId;
    }

    // ── STEP 2: Cache is empty → this is the very first card tap for this order.
    //           Attempt a sync.  If the server says "duplicate", extract and cache
    //           the existing Woo order ID rather than throwing. ─────────────────
    if (kDebugMode) {
      print('🔄 [resolveWooOrderId] No cached wooOrderId — attempting first sync');
    }

    try {
      final syncResult =
      await OrderRepository().syncSingleOfflineOrder(offlineMap);

      if (syncResult is Map) {
        wooOrderId = (syncResult?['id'] as num?)?.toInt() ?? 0;

        if (wooOrderId > 0) {
          offlineMap['wooOrderId'] = wooOrderId;
          offlineMap['synced'] = true;
          offlineMap['sync_at'] = DateTime.now().toIso8601String();
          await box.put(orderKey, offlineMap);

          if (kDebugMode) {
            print(
                '✅ [resolveWooOrderId] Sync succeeded — wooOrderId cached: $wooOrderId');
          }
        }
      }
    } catch (e) {
      // ── Handle duplicate_client_order_id gracefully ──────────────────────────
      // The error arrives as a JSON string like:
      //   {"code":"duplicate_client_order_id","message":"...already exists (Order ID: 42410).","data":{"status":400}}-Invalid Request:
      // We parse the embedded Woo order ID and cache it so no further syncs are
      // attempted, and the payment API receives the correct server-side ID.
      final errorStr = e.toString();

      if (errorStr.contains('duplicate_client_order_id')) {
        if (kDebugMode) {
          print(
              '⚠️ [resolveWooOrderId] duplicate_client_order_id detected — extracting existing Woo order ID');
          print('   Raw error: $errorStr');
        }

        // Try to extract the numeric ID from the message.
        // Patterns we handle:
        //   "already exists (Order ID: 42410)"
        //   "already exists. Order ID: 42410"
        final RegExp idPattern =
        RegExp(r'Order ID[:\s]+(\d+)', caseSensitive: false);
        final match = idPattern.firstMatch(errorStr);

        if (match != null) {
          final int extractedId = int.tryParse(match.group(1) ?? '') ?? 0;

          if (extractedId > 0) {
            wooOrderId = extractedId;
            offlineMap['wooOrderId'] = wooOrderId;
            offlineMap['synced'] = true;
            offlineMap['sync_at'] = DateTime.now().toIso8601String();
            await box.put(orderKey, offlineMap);

            if (kDebugMode) {
              print(
                  '✅ [resolveWooOrderId] Extracted & cached wooOrderId from duplicate error: $wooOrderId');
            }
          }
        }

        // Also try parsing the error body as JSON in case the string includes it.
        if (wooOrderId == 0) {
          try {
            // The error string may start with the raw JSON body.
            final jsonStart = errorStr.indexOf('{');
            if (jsonStart >= 0) {
              final jsonPart = errorStr.substring(jsonStart);
              // Find end of first JSON object (simple heuristic).
              final jsonEnd = jsonPart.indexOf('}-') + 1;
              final jsonStr =
              jsonEnd > 0 ? jsonPart.substring(0, jsonEnd) : jsonPart;
              final Map<String, dynamic> body =
              jsonDecode(jsonStr) as Map<String, dynamic>;
              final msg = body['message']?.toString() ?? '';
              final m2 = idPattern.firstMatch(msg);
              if (m2 != null) {
                final int id2 = int.tryParse(m2.group(1) ?? '') ?? 0;
                if (id2 > 0) {
                  wooOrderId = id2;
                  offlineMap['wooOrderId'] = wooOrderId;
                  offlineMap['synced'] = true;
                  offlineMap['sync_at'] = DateTime.now().toIso8601String();
                  await box.put(orderKey, offlineMap);
                  if (kDebugMode) {
                    print(
                        '✅ [resolveWooOrderId] Extracted wooOrderId from JSON error body: $wooOrderId');
                  }
                }
              }
            }
          } catch (_) {
            // JSON parse failed — not critical, we'll fall through to the
            // widget.orderId fallback below.
          }
        }

        if (wooOrderId == 0 && kDebugMode) {
          print(
              '❌ [resolveWooOrderId] Could not extract wooOrderId from duplicate error — payment will likely fail');
        }
      } else {
        // Some other sync error — rethrow so the caller can show the user.
        if (kDebugMode) {
          print('❌ [resolveWooOrderId] Sync failed with unexpected error: $e');
        }
        rethrow;
      }
    }

    // ── STEP 3: Last-resort fallback ─────────────────────────────────────────
    if (wooOrderId == 0) {
      wooOrderId = widget.orderId ?? orderId ?? 0;
      if (kDebugMode) {
        print(
            '⚠️ [resolveWooOrderId] Using widget.orderId as last-resort fallback: $wooOrderId');
      }
    }

    return wooOrderId;
  }


  String? _extractServerPaymentId(Map<String, dynamic> body) {
    final dynamic raw = body['payment_id'] ??
        (body['data'] is Map ? body['data']['payment_id'] : null) ??
        (body['data'] is Map ? body['data']['id'] : null);
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  void _recalculateEbtAfterNonEbtPayment() {
    final double originalEbt = widget.ebtAmount; // Original EBT amount from order
    final double nonEbtOrderValue = (computedNetPayable - originalEbt).clamp(0.0, double.infinity);

    // Calculate total non-EBT payments made (cash, card, other - excluding EBT payments)
    final double totalNonEbtPaid = payByCash + payByCard + payByOther;

    // If non-EBT payments exceed the non-EBT portion, overflow reduces EBT
    final double overflowToEbt = totalNonEbtPaid > nonEbtOrderValue
        ? (totalNonEbtPaid - nonEbtOrderValue)
        : 0.0;

    // Calculate remaining EBT (original EBT minus EBT payments minus overflow from non-EBT)
    final double remainingEbt = (originalEbt - payByEbt).clamp(0.0, double.infinity);
    final double newEbtTotal = (remainingEbt - overflowToEbt).clamp(0.0, double.infinity);

    setState(() {
      ebtTotal = newEbtTotal;
    });
  }



  Future<void> _callCreatePaymentAPI({bool skipPopup = false}) async {
    if (kDebugMode) {
      print(
          "###### _callCreatePaymentAPI called, balanceAmount: $balanceAmount, skipPopup: $skipPopup");
    }

    final now = DateTime.now();
    final String datetimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    // ────────────────────────────────────────────────
    //  Fake payment mode
    // ────────────────────────────────────────────────
    if (offline_PAYMENT_SUCCESS) {
      if (kDebugMode) print("⚡ FAKE PAYMENT SUCCESS MODE ACTIVE ⚡");

      double amount = double.tryParse(
        amountController.text
            .replaceAll(TextConstants.currencySymbol, '')
            .trim(),
      ) ??
          0.0;

      final double currentBalance = balanceAmount;
      final double newTender = tenderAmount + amount;

      double newBalance = currentBalance - amount;
      double newChange = 0.0;

      if (amount >= currentBalance) {
        newChange = amount - currentBalance;
        newBalance = 0.0;
      }

      newBalance = double.parse(newBalance.toStringAsFixed(2));
      newChange = double.parse(newChange.toStringAsFixed(2));

      final bool isFullPayment = newBalance <= 0;
      final bool isPartialPayment = !isFullPayment && amount > 0;

      // ─── Update UI state ───
      setState(() {
        isPaymentStarted = true;
        _processingPaymentMethod = null;
        isLoading = false;
        paidAmount = amount;
        paymentId = "fake_${now.millisecondsSinceEpoch}";
        orderStatus = TextConstants.completed;
        tenderAmount = newTender;
        balanceAmount = newBalance;
        changeAmount = newChange;

        _currentPaymentRemainingBalance = isPartialPayment ? newBalance : null;

        if (isPartialPayment) {
          // Update payment method totals
          if (selectedPaymentMethod == TextConstants.cash) payByCash += amount;
          if (selectedPaymentMethod == TextConstants.ebtText) {
            payByEbt += amount;
            ebtTotal = (ebtTotal - amount).clamp(0, double.infinity);
          }

          _lastPaymentDetails = {
            'amount': amount,
            'method': selectedPaymentMethod,
            'remainingBalance': newBalance,
            'previousBalance': currentBalance,
            'datetime': now.toIso8601String(),
            'paymentNumber': (_lastPaymentDetails?['paymentNumber'] ?? 0) + 1,
          };
        }
      });

      // ─── Show success popup only for full payment ───
      if (isFullPayment && !_successPopupShown) {
        // ✅ FULL PAYMENT
        _successPopupShown = true;

        final box = StorageProvider.offlineOrders;
        final key = (orderId ?? 0).toString();
        final d = await box.get(key);
        final cr = d is Map ? d["coupon_response"] : null;
        final couponResponse =
        cr is Map ? Map<String, dynamic>.from(cr) : <String, dynamic>{};

        // Update Hive order status
        // final box = StorageProvider.offlineOrders;
        // final key = (orderId ?? 0).toString();
        final raw = await box.get(key);
        if (raw != null) {
          final order = Map<String, dynamic>.from(raw);
          order['order_status'] = TextConstants.completed;
          await box.put(key, order);
        }

        if (orderId != null && orderId! > 0) {
          unawaited(OfflineHelper.updateOfflineOrderStatus(
            orderId!,
            TextConstants.completed,
            paymentMethod: selectedPaymentMethod,
          ));
        }

        _showPaymentDialog(
          context,
          amount,
          changeAmount: newChange,
          showChange: newChange > 0,
          couponResponse: couponResponse,
        );

// 🟡 PARTIAL PAYMENT — only if amount > 0 and balance remains
      } else if (!isFullPayment && amount > 0) {
        print("🟡 SHOWING PARTIAL PAYMENT DIALOG");
        _showPartialPaymentDialog(context, amount);
      }

      // ─── Save fake payment locally ───
      _lastPayment = LastPaymentInfo(
        method: selectedPaymentMethod ?? "Cash",
        amount: amount,
        paymentId: paymentId,
        sunmiTxnId: null,
      );

      final localPayment = LocalPayment(
        orderId: orderId ?? 0,
        title: selectedPaymentMethod ?? "Cash",
        amount: amount,
        paymentMethod: selectedPaymentMethod ?? "Cash",
        shiftId: shiftId,
        vendorId: vendorId,
        userId: userId ?? 0,
        serviceType: serviceType,
        datetime: datetimeStr,
        notes: "offline payment - ${now.toIso8601String()}",
        isSynced: false,
        createdAt: now,
        // status: isFullPayment ? PaymentDbStatus.completed : PaymentDbStatus.pending,
        status: PaymentDbStatus.pending,
        remainingBalance: newBalance,
      );

      try {
        final saved =
        await LocalPaymentDBHelper.instance.savePayment(localPayment);
        _lastPayment?.paymentId = "local_${saved.id}";
        _updateHivePaymentData(localPayment);

        if (kDebugMode) {
          print(
              " offline  payment saved → ID: ${saved.id}, Amount: $amount, New balance: $newBalance");
        }
      } catch (e) {
        print("✗ Failed to save fake payment: $e");
      }

      amountController.clear();
      return; // Skip real API
    }

    // ────────────────────────────────────────────────
    //  Real payment mode
    // ────────────────────────────────────────────────
    if (selectedPaymentMethod == null || selectedPaymentMethod!.isEmpty) {
      print("❌ ERROR: No payment method selected");
      return;
    }

    final bool isCard = selectedPaymentMethod == TextConstants.card;

    if (!isCard && balanceAmount > 0 && amountController.text.trim().isEmpty) {
      print("❌ ERROR: Amount required for Cash / Wallet / EBT");
      return;
    }

    double amount = double.tryParse(
      amountController.text
          .replaceAll(TextConstants.currencySymbol, '')
          .trim(),
    ) ??
        0.0;

    if (!isCard) {
      if (amount < 0) {
        print("❌ ERROR: Negative amount");
        return;
      }
      if (amount == 0 && computedNetPayable > 0) {
        setState(() => _amountErrorText = TextConstants.amountValidation);
        return;
      }
    } else {
      if (amount <= 0) amount = 0.0;
    }

    _amountErrorText = null;
    final double remainingBalance = balanceAmount;

    setState(() {
      _processingPaymentMethod = selectedPaymentMethod;
      isLoading = true;
    });

    if (!skipPopup) _showPaymentProgressDialog(context);

    final paymentRequest = PaymentRequestModel(
      title: selectedPaymentMethod!,
      orderId: orderId ?? 0,
      amount: amount,
      paymentMethod: selectedPaymentMethod!,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetimeStr,
      notes: '',
    );

    // paymentBloc.createPayment(paymentRequest);

    StreamSubscription? subscription;
    subscription =
        paymentBloc.createPaymentStream.listen((paymentResponse) async {
          if (kDebugMode) print("Payment stream response: $paymentResponse");

          if (paymentResponse.status == Status.ERROR) {
            if (!skipPopup)
              _hidePaymentProgressDialog();
            else if (Navigator.canPop(context)) Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Payment failed: ${paymentResponse.message}"),
                backgroundColor: Colors.red,
              ),
            );

            setState(() {
              _processingPaymentMethod = null;
              isLoading = false;
              _successPopupShown = false;
            });

            subscription?.cancel();
            return;
          }

          if (paymentResponse.status == Status.COMPLETED &&
              paymentResponse.data != null &&
              paymentResponse.data!.message == "Payment Created Successfully") {
            if (!skipPopup) _hidePaymentProgressDialog();

            final paymentData = paymentResponse.data!;
            paidAmount = amount;
            paymentId = paymentData.paymentId.toString();

            final bool isFullPayment = amount >= remainingBalance;
            final bool isPartialPayment = !isFullPayment && amount > 0;

            // Update balances
            tenderAmount += amount;
            final String paidMethod = selectedPaymentMethod!.toLowerCase().trim();
            if (paidMethod == TextConstants.cash.toLowerCase()) {
              payByCash += amount;
            } else if (paidMethod == TextConstants.card.toLowerCase()) {
              payByCard += amount;
            } else if (paidMethod == TextConstants.ebtText.toLowerCase()) {
              payByEbt += amount;
              ebtTotal = (ebtTotal - amount).clamp(0.0, double.infinity);
            } else {
              payByOther += amount;
            }
            if (isFullPayment) {
              balanceAmount = 0.0;
              changeAmount = amount - remainingBalance;
            } else {
              balanceAmount = remainingBalance - amount;
              changeAmount = 0.0;
            }
            balanceAmount = double.parse(balanceAmount.toStringAsFixed(2));

            // ─── Save last payment info ───
            _lastPayment = LastPaymentInfo(
              method: selectedPaymentMethod!,
              amount: amount,
              paymentId: paymentId,
              sunmiTxnId: null,
            );

            try {
              final box = StorageProvider.offlineOrders;
              final key = (orderId ?? 0).toString();
              final hasKey = await box.containsKey(key);
              final raw = hasKey ? await box.get(key) : null;
              final existing = Map<String, dynamic>.from(raw is Map ? raw : {});
              existing["lastPayment"] = _lastPayment!.toJson();
              existing["balanceAmount"] = balanceAmount;
              existing["paidAmount"] = tenderAmount;
              existing["tenderAmount"] = tenderAmount;
              existing["ebtTotal"] = ebtTotal;
              await box.put(key, existing);
            } catch (e) {
              print("⚠ Hive update error: $e");
            }

            if (mounted)
              setState(() {
                _processingPaymentMethod = null;
                isLoading = false;
                _currentPaymentRemainingBalance =
                isPartialPayment ? balanceAmount : null;
                _lastPaymentDetails = {
                  'amount': amount,
                  'method': selectedPaymentMethod!,
                  'remainingBalance': balanceAmount,
                  'previousBalance': remainingBalance,
                  'datetime': DateTime.now().toIso8601String(),
                };
              });

            // ─── Full: success receipt dialog | Partial: "next payment" dialog ───
            // Progress overlay was already closed above for both paths (!skipPopup).
            if (isFullPayment && !_successPopupShown) {
              _successPopupShown = true;

              final box = StorageProvider.offlineOrders;
              final key = (orderId ?? 0).toString();
              final rawBox = await box.get(key);
              final cr = rawBox is Map ? rawBox["coupon_response"] : null;
              final couponResponse =
              cr is Map ? Map<String, dynamic>.from(cr) : <String, dynamic>{};

              _showPaymentDialog(
                context,
                amount,
                changeAmount: changeAmount,
                showChange: changeAmount > 0,
                couponResponse: couponResponse,
              );
            } else if (isPartialPayment && amount > 0) {
              await _showPartialPaymentDialog(context, amount);
            }

            amountController.clear();
            _fetchPaymentsByOrderId();
            subscription?.cancel();
          }
        });
  }

  void _hidePaymentProgressDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  bool get _hasEbtItemsInOrder =>
      orderItems.any((item) => _orderSummaryLineEbtEligible(item));

  void _syncEbtTotalWithOrderItems() {
    if (!_hasEbtItemsInOrder && ebtTotal != 0.0) {
      ebtTotal = 0.0;
      if (kDebugMode) {
        print("🧹 No EBT-eligible items remain → ebtTotal reset to 0");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeHelper = Provider.of<ThemeNotifier>(context);
    ResponsiveLayout.init(context);

    return Scaffold(
      backgroundColor: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Color(0xFFF1F1F3),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with logo and user info
            // _buildHeader(),
            _buildNavigationBar(),

            // Main content area: split horizontally
            Expanded(
              child: Row(
                children: [
                  // Left Side: Navigation bar + Order Summary stacked vertically
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildOrderSummary(),
                        ),
                      ],
                    ),
                  ),

                  // Right Side: Payment Section
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        // Payment content takes remaining space
                        Expanded(
                          child: _buildPaymentSection(),
                        ),

                        Container(
                          margin: const EdgeInsets.only(
                            left: 0,
                            right: 8,
                            top: 0,
                            bottom: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 8),
                          decoration: themeHelper.themeMode == ThemeMode.dark
                              ? ShapeDecoration(
                            color: const Color(
                                0xFF1F1D2B), // dark background
                            shape: RoundedRectangleBorder(
                              // side: BorderSide(
                              //   width: 0,
                              //   color: Colors.black.withOpacity(0.20),
                              // ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(
                                    ResponsiveLayout.getRadius(10)),
                                bottomRight: Radius.circular(
                                    ResponsiveLayout.getRadius(10)),
                              ),
                            ),
                          )
                              : BoxDecoration(
                            color: Colors.white, // light background
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(
                                  ResponsiveLayout.getRadius(10)),
                              bottomRight: Radius.circular(
                                  ResponsiveLayout.getRadius(10)),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? const Color(
                                  0xFF303136) // dark mode background
                                  : Colors.white, // light mode background
                              border: Border.all(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? Color(
                                    0xFF303136) // optional darker border for dark mode
                                    : const Color(0xFFEDF2F9),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? Colors.black.withOpacity(
                                      0.3) // subtle shadow in dark mode
                                      : Colors.white,
                                  blurRadius: 8,
                                  offset: const Offset(2, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildPaymentModeButton(
                                    TextConstants.cash,
                                    Image.asset(
                                      'assets/cash.png',
                                      width: ResponsiveLayout.getIconSize(24),
                                      height: ResponsiveLayout.getIconSize(24),
                                      fit: BoxFit.contain,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9CCD7B),
                                        Color(0xFF9CCD7B),
                                      ],
                                    ),
                                    borderColor: const Color(0xFF9CCD7B),
                                    iconColor: const Color(0xFF9CCD7B),
                                    isLoading: _processingPaymentMethod == TextConstants.cash && isLoading,
                                    isDisabled: _processingPaymentMethod != null &&
                                        _processingPaymentMethod != TextConstants.cash,
                                    onTap: () async {
                                      _selectPaymentMethod(TextConstants.cash);
                                      _handlePay();
                                    },
                                  ),
                                ),

                                Expanded(
                                  child: _buildPaymentModeButton(
                                    TextConstants.card,
                                    Image.asset(
                                      'assets/card.png',
                                      width: ResponsiveLayout.getIconSize(24),
                                      height: ResponsiveLayout.getIconSize(24),
                                      fit: BoxFit.contain,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFA484C8),
                                        Color(0xFFA484C8),
                                      ],
                                    ),
                                    borderColor: const Color(0xFFA484C8),
                                    iconColor: const Color(0xFFA484C8),
                                    isLoading: false,
                                    isDisabled: false,
                                    onTap: () async {
                                      _selectPaymentMethod(
                                        TextConstants.card,
                                        maxAllowedAmount: balanceAmount,
                                      );
                                      await _handleCardPaymentViaAPI();
                                    },
                                  ),
                                ),

                                Expanded(
                                  child: _buildPaymentModeButton(
                                    "Pay Later",
                                    Image.asset(
                                      'assets/wallet.png',
                                      width: ResponsiveLayout.getIconSize(24),
                                      height: ResponsiveLayout.getIconSize(24),
                                      fit: BoxFit.contain,
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFCCB985),
                                        Color(0xFFCCB985),
                                      ],
                                    ),
                                    borderColor: const Color(0xFFCCB985),
                                    iconColor: const Color(0xFFCCB985),
                                    isLoading:
                                    _processingPaymentMethod == "Pay Later" && isLoading,
                                    isDisabled: _isPartialAmountEntered() ||
                                        balanceAmount <= 0 ||
                                        (_processingPaymentMethod != null &&
                                            _processingPaymentMethod != "Pay Later"),
                                    onTap: () async {
                                      await _handlePayLaterPayment();
                                    },
                                  ),
                                ),

                                if (ebtTotal > 0 && _hasEbtItemsInOrder)
                                  Expanded(
                                    child: _buildPaymentModeButton(
                                      TextConstants.ebtText,
                                      Image.asset(
                                        'assets/ebt.png',
                                        width: ResponsiveLayout.getIconSize(24),
                                        height: ResponsiveLayout.getIconSize(24),
                                        fit: BoxFit.contain,
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF84A2CB),
                                          Color(0xFF84A2CB),
                                        ],
                                      ),
                                      borderColor: const Color(0xFF84A2CB),
                                      iconColor: Colors.white,
                                      isLoading: _processingPaymentMethod ==
                                          TextConstants.ebtText &&
                                          isLoading,
                                      isDisabled: _processingPaymentMethod != null &&
                                          _processingPaymentMethod != TextConstants.ebtText,
                                      onTap: () async {
                                        if (ebtTotal <= 0) {
                                          setState(() {
                                            _amountErrorText = "No EBT balance available";
                                          });
                                          return;
                                        }

                                        final allowedAmount =
                                        balanceAmount.clamp(0.0, ebtTotal);

                                        if (allowedAmount <= 0) {
                                          setState(() {
                                            _amountErrorText =
                                            "Cannot pay with EBT, balance is zero";
                                          });
                                          return;
                                        }

                                        final enteredAmount = double.tryParse(
                                          amountController.text
                                              .replaceAll(
                                              TextConstants.currencySymbol, '')
                                              .trim(),
                                        ) ??
                                            0.0;

                                        final amountToUse = enteredAmount > 0
                                            ? enteredAmount.clamp(0.0, allowedAmount)
                                            : allowedAmount;

                                        if (amountToUse <= 0) {
                                          setState(() {
                                            _amountErrorText =
                                                TextConstants.amountValidation;
                                          });
                                          return;
                                        }

                                        _selectPaymentMethod(TextConstants.ebtText);

                                        setState(() {
                                          _rawAmount = (amountToUse * 100).round();
                                          amountController.text =
                                          '${TextConstants.currencySymbol}${amountToUse.toStringAsFixed(2)}';
                                          _isAmountEntered = true;
                                          _amountErrorText = null;
                                        });

                                        await _handleEbtCardPaymentViaAPI();
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // void _showPaymentProgressDialog(BuildContext context) {
  //   final bool isDark = Theme.of(context).brightness == Brightness.dark;
  //
  //   // THEME COLORS (same pattern as coupon popup)
  //   final Color dialogBg = isDark ? const Color(0xFF252837) : Colors.white;
  //   final Color textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
  //   final Color textSecondary =
  //   isDark ? Colors.white70 : const Color(0xFF6B7280);
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) {
  //       return WillPopScope(
  //         onWillPop: () async => false,
  //         child: Dialog(
  //           elevation: 0,
  //           backgroundColor: Colors.transparent,
  //           child: Center(
  //             child: Container(
  //               width: 300,
  //               padding: const EdgeInsets.symmetric(
  //                 vertical: 28,
  //                 horizontal: 24,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: dialogBg,
  //                 borderRadius: BorderRadius.circular(18),
  //                 boxShadow: [
  //                   if (!isDark)
  //                     BoxShadow(
  //                       color: Colors.black.withOpacity(0.08),
  //                       blurRadius: 16,
  //                       offset: const Offset(0, 8),
  //                     ),
  //                 ],
  //               ),
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   SizedBox(
  //                     width: 44,
  //                     height: 44,
  //                     child: CircularProgressIndicator(
  //                       strokeWidth: 3,
  //                       valueColor: AlwaysStoppedAnimation<Color>(
  //                         isDark ? Colors.white70 : const Color(0xFF1BA672),
  //                       ),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 20),
  //                   Text(
  //                     "Payment in progress",
  //                     textAlign: TextAlign.center,
  //                     style: TextStyle(
  //                       fontSize: 17,
  //                       fontWeight: FontWeight.w600,
  //                       color: textPrimary,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 6),
  //                   if (_processingPaymentMethod != null)
  //                     Text(
  //                       "Processing ${_processingPaymentMethod!}",
  //                       textAlign: TextAlign.center,
  //                       style: TextStyle(
  //                         fontSize: 13,
  //                         height: 1.3,
  //                         color: textSecondary,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  void _showPaymentProgressDialog(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark ? const Color(0xFF252837) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color textSecondary = isDark ? Colors.white70 : const Color(0xFF6B7280);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  color: dialogBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white70 : const Color(0xFF1BA672),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Payment in progress",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_processingPaymentMethod != null)
                      Text(
                        "Processing ${_processingPaymentMethod!}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: textSecondary,
                        ),
                      ),
                    // const SizedBox(height: 24),
                    // // ✅ CANCEL BUTTON
                    // SizedBox(
                    //   width: double.infinity,
                    //   height: 40,
                    //   child: OutlinedButton(
                    //     style: OutlinedButton.styleFrom(
                    //       foregroundColor: Colors.red,
                    //       side: const BorderSide(color: Colors.red, width: 1.5),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //     ),
                    //     onPressed: () {
                    //       // Set cancel flag
                    //       _isCardPaymentCancelled = true;
                    //       // Close the progress dialog
                    //       if (Navigator.canPop(context)) {
                    //         Navigator.pop(context);
                    //       }
                    //       // Reset loading state
                    //       if (mounted) {
                    //         setState(() {
                    //           isLoading = false;
                    //           _processingPaymentMethod = null;
                    //         });
                    //       }
                    //     },
                    //     child: const Text(
                    //       "Cancel Payment",
                    //       style: TextStyle(
                    //         fontSize: 14,
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      height: ResponsiveLayout.getHeight(60),
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.primaryBackground
          : Color(0xFFE4E4E4),
      padding: ResponsiveLayout.getResponsivePadding(
        horizontal: 16,
        vertical: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pinaka logo with triangle above it
          SvgPicture.asset(
            themeHelper.themeMode == ThemeMode.dark
                ? 'assets/svg/app_logo.svg'
                : 'assets/svg/app_icon.svg',
            height: ResponsiveLayout.getHeight(40),
            width: ResponsiveLayout.getWidth(40),
          ),

          // User profile section with container and notification bell
          Row(
            children: [
              Container(
                height: ResponsiveLayout.getHeight(45), //45
                margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(16), vertical: 0),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: ResponsiveLayout.getRadius(18),
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userDisplayName ?? TextConstants.unknown).substring(
                            0, 1), //"A", /// use initial for the login user
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveLayout.getFontSize(14)),
                      ),
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userDisplayName ??
                              "", //'A Raghav Kumar', /// use login user display name
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark
                                  : ThemeNotifier.textLight,
                              fontSize: ResponsiveLayout.getFontSize(14)),
                        ),
                        Text(
                          userRole ??
                              TextConstants
                                  .unknown, //'I am Cashier', /// use user role
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveLayout.getWidth(16)),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                child: Icon(
                  Icons.notifications_outlined,
                  size: ResponsiveLayout.getIconSize(24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCouponAppliedSnackBar(
      BuildContext context,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Coupon already applied. Remove coupon to go back.",
          ),

          //  RED COLOR
          backgroundColor: Colors.red,

          duration: Duration(seconds: 3),

          behavior: SnackBarBehavior.floating,
        ),
      );
  }
//******************************************************************************** */
  void _showRedeemPointsSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Loyalty applied, please remove and try again",
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildNavigationBar() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    // Determine the date and time to display
    _displayDate = widget.formattedDate;
    _displayTime = widget.formattedTime;

    final order = orderHelper.activeOrderId != null
        ? orderHelper.orders.firstWhere(
          (o) => o[AppDBConst.orderServerId] == orderHelper.activeOrderId,
      orElse: () => {},
    )
        : {};

    if (order.isNotEmpty && order[AppDBConst.orderDate] != null) {
      try {
        final DateTime createdDateTime =
        DateTime.parse(order[AppDBConst.orderDate].toString());
        _displayDate =
            DateFormat(TextConstants.dateFormat).format(createdDateTime);
        _displayTime =
            DateFormat(TextConstants.timeFormat).format(createdDateTime);
      } catch (e) {
        if (kDebugMode) {
          print("Error parsing order creation date: $e");
        }
        // Fallback to raw data or default if parsing fails
        _displayDate = order[AppDBConst.orderDate].toString().split(' ').first;
      }
    }

    bool isCustomerFieldDisabled = redeemedValue > 0;
    final bool isButtonDisabled = isPaymentDone ||
        redeemedValue > 0 ||
        isOrderPending ||
        (!(isPhoneValid || isEmailValid) && !showCustomerInput);

    return Container(
      height: ResponsiveLayout.getHeight(60),
      width: double.infinity,
      margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
      padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.getPadding(6)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.appBarBackground
            : const Color(0xFFFFFFFF),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ////**88 */ Back button

          InkWell(
            borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(8)),
            onTap: () async {
              final box = StorageProvider.offlineOrders;

              final String orderKey = orderId?.toString() ??
                  widget.offlineOrderId?.toString() ??
                  "";

              final rawOrder = await box.get(orderKey);

              final latestOrder = Map<String, dynamic>.from(
                rawOrder is Map ? rawOrder : {},
              );

              print("LATEST ORDER -> $latestOrder");

              final bool couponExists = latestOrder["coupon_applied"] == true;

              print("coupon_applied: ${latestOrder["coupon_applied"]}");
              print("couponExists: $couponExists");

              // Get payments (defensive fallback across possible local/server IDs)
              // so back-flow still detects a void even when one ID path is empty.
              final Set<int> candidateIds = {
                if (orderId != null && orderId! > 0) orderId!,
                if (widget.orderId != null && widget.orderId! > 0)
                  widget.orderId!,
                if (widget.offlineOrderId != null && widget.offlineOrderId! > 0)
                  widget.offlineOrderId!,
              };

              final List<LocalPayment> payments = [];
              final Set<int> seenPaymentIds = {};
              for (final id in candidateIds) {
                final rows = await LocalPaymentDBHelper.instance
                    .getPaymentsByOrderId(id);
                for (final p in rows) {
                  if (seenPaymentIds.add(p.id)) {
                    payments.add(p);
                  }
                }
              }

              final bool hasAnyPaymentBeenMade = payments.isNotEmpty;

              double netAmount = payments.fold(0.0, (sum, p) => sum + p.amount);

              final bool hasNetPayment = netAmount.abs() > 0.01;

              // After a full void, net can be ~0 but unsynced void lines must still sync;
              // user should still get the exit confirmation.
              final bool hasUnsyncedPayments = payments.any((p) => !p.isSynced);

              final bool hasDiscount = discount > 0;

              final bool hasRedeemPoints = redeemedValue > 0;

              if (kDebugMode) {
                print("===== BACK BUTTON DEBUG =====");
                print("redeemedValue(UI): $redeemedValue");
                print("isRedeemAppliedFromApi: $isRedeemAppliedFromApi");
                print("hasRedeemPoints: $hasRedeemPoints");
                print("============================");
              }

              // Remaining balance
              final double effectiveRemaining =
              (_currentPaymentRemainingBalance != null &&
                  _currentPaymentRemainingBalance! > 0)
                  ? _currentPaymentRemainingBalance!
                  : balanceAmount;

// Always update customer display
              if (orderId != null) {
                await CustomerDisplayHelper.updateCustomerDisplay(
                  orderId!,
                  summaryEnabled: false,
                );
              }

// CASE 1: partial/full payment started
              if (hasAnyPaymentBeenMade || hasUnsyncedPayments) {
                _showExitPaymentConfirmation(context);
                return;
              }

// CASE 2: redeem applied but no payment
              if (hasRedeemPoints) {
                _showRedeemPointsSnackBar(context);
                return;
              }

              // ✅ CASE 2: Coupon applied but no payment yet
              // CASE 2: Coupon applied
              if (couponExists) {
                // ⭐ ISSUE COUPON → show exit confirmation popup
                if (isCouponActive) {
                  print("🎟 Issue coupon → showing exit confirmation");
                  _showExitPaymentConfirmation(context);
                  return;
                }

                // ⭐ GENERATED COUPON → show snackbar
                print("🚨 Generated coupon exists → showing snackbar");
                _showCouponAppliedSnackBar(context);
                return;
              }
              if (couponExists || isCouponAppliedFromApi) {
                print("🚨 Coupon already applied → showing snackbar");
                _showCouponAppliedSnackBar(context);
                return;
              }
              // ✅ CASE 3: Discount applied
              if (hasDiscount) {
                _showExitPaymentConfirmation(context);
                return;
              }

              // ✅ CASE 4: No payment and no coupon
              if (kDebugMode) {
                print("Back button → direct exit");
              }

              Navigator.of(context).pop();
            },
            child: Container(
              // height: 40,
              margin: EdgeInsets.only(left: 15.0, top: 10.0),
              width: MediaQuery.of(context).size.width * 0.075,
              height: MediaQuery.of(context).size.height * 0.05,
              decoration: BoxDecoration(
                color: Color(0xFF3B4259),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: Color(0xFF3B4259)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 10),
                  Container(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      weight: 10,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    TextConstants.back,
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getFontSize(15),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 20),

          const SizedBox(width: 180),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ---------------- CUSTOMER INPUT CONTAINER ----------------
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.only(
                      top: 4,
                      left: 16,
                      right: 10,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF40424F)
                          : const Color(0xFFE5EFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Customer :',
                          style: TextStyle(
                            color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF115ACD),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                width: 1,
                                color: Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.black.withOpacity(0.20),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: StatefulBuilder(
                              builder: (context, innerSetState) {
                                print(
                                    "BUILD -> isCustomerFieldDisabled=$isCustomerFieldDisabled, "
                                        "showCustomerInput=$showCustomerInput");
                                return TextField(
                                  controller: mobileController,
                                  enabled: true,
                                  readOnly: showCustomerInput,
                                  enableInteractiveSelection:
                                  !showCustomerInput,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    TextInputFormatter.withFunction(
                                            (oldValue, newValue) {
                                          final text = newValue.text;

                                          // If input is only digits → Mobile number
                                          if (RegExp(r'^\d*$').hasMatch(text)) {
                                            if (text.length > 10) {
                                              return oldValue; // block extra digits
                                            }
                                          }
                                          // Otherwise → Email
                                          else {
                                            if (text.length > 50) {
                                              return oldValue; // block extra characters
                                            }
                                          }

                                          return newValue;
                                        }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      isPhoneValid = RegExp(r'^[0-9]{10}$')
                                          .hasMatch(value);
                                      isEmailValid = RegExp(
                                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                      ).hasMatch(value);
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Add Mobile No ',
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    counterText: '',
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF313131),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 18),

                // ---------------- ADD / CANCEL BUTTON (SAME LOGIC) ----------------
//                 InkWell(
//                   onTap: isButtonDisabled
//                       ? null
//                       : () async {
//                     // ---------- CANCEL ----------
//                     if (showCustomerInput) {
//                       // Only allow cancel if not disabled
//                       if (isPaymentDone || redeemedValue > 0) return;
//
//                       setState(() {
//                         mobileController.clear();
//                         showCustomerInput = false;
//                         isPhoneValid = false;
//                         isEmailValid = false;
//                         isRedeemActive = false;
//                         // Enable field again
//                         isCustomerFieldDisabled = false;
//                       });
//
//                       final offlineBox = StorageProvider.offlineOrders;
//                       final localKey = widget.offlineOrderId?.toString();
//
//                       if (localKey != null) {
//                         final existing = await offlineBox.get(localKey);
//                         if (existing != null) {
//                           final d = Map<String, dynamic>.from(
//                               existing is Map ? existing : {});
//                           d["loyaltyContact"] = "";
//                           await offlineBox.put(localKey, d);
//                         }
//                       }
//
//                       final localOrderId = widget.offlineOrderId;
//                       if (localOrderId != null) {
//                         await CustomerDisplayHelper.updateCustomerDisplay(
//                           localOrderId,
//                           summaryEnabled: true,
//                         );
//                       }
//                       return;
//                     }
//
//                     // ---------- ADD ----------
//                     // ---------- ADD ----------
//                     if (!(isPhoneValid || isEmailValid)) return;
//
//                     // ✅ Close keyboard immediately
//                     FocusManager.instance.primaryFocus?.unfocus();
//
//                     setState(() => isAddLoading = true);
//
//                     final contact = mobileController.text.trim();
//
//                     try {
//                       // ======================================
//                       // 1️⃣ LOAD OFFLINE ORDER FROM HIVE
//                       // ======================================
//                       final offlineBox = StorageProvider.offlineOrders;
//
//                       final localKey = widget.offlineOrderId?.toString();
//
//                       if (localKey == null) {
//                         throw Exception("Offline order not found");
//                       }
//
//                       final existing = await offlineBox.get(localKey);
//
//                       if (existing == null) {
//                         throw Exception("Order data missing");
//                       }
//
//                       final offlineOrder =
//                       Map<String, dynamic>.from(existing);
//
//                       print("🟡 OFFLINE ORDER LOADED");
//
//                       // ======================================
//                       // 2️⃣ SYNC ORDER WITH BACKEND
//                       // ======================================
//                       final syncResponse =
//                       await orderBloc.syncSingleOfflineOrder(
//                         offlineOrder,
//                       );
//
//                       print("✅ SYNC RESPONSE points: $syncResponse");
//
//                       if (syncResponse == null) {
//                         throw Exception("Sync failed");
//                       }
//
//                       // ======================================
//                       // 3️⃣ GET WOO ORDER ID
//                       // ======================================
//                       final int syncedOrderId = syncResponse["id"] ?? 0;
//
//                       if (syncedOrderId == 0) {
//                         throw Exception("Backend order id missing");
//                       }
//
//                       print("🟢 WOO ORDER ID lo: $syncedOrderId");
//
//                       // ======================================
//                       // 4️⃣ CALL CREATE CUSTOMER API
//                       // ======================================
//                       final rawResponse =
//                       await orderBloc.addLoyaltyPoints(
//                         orderId: syncedOrderId,
//                         contact: contact,
//                       );
//
//                       print("🌐 CUSTOMER RESPONSE: $rawResponse");
//
//                       final result = jsonDecode(rawResponse);
//
//                       print("✅ FULL CUSTOMER RESULT: $result");
//
//                       if (result == null) {
//                         throw Exception("Empty customer response");
//                       }
//
//                       if (result["success"] == false) {
//                         throw Exception(
//                           result["message"] ?? "Customer API failed",
//                         );
//                       }
//
//                       final data = result["data"] ?? {};
//
//                       final pts = int.tryParse(
//                         data["available_points"]?.toString() ?? "0",
//                       ) ??
//                           0;
//                       // ======================================
//                       // 5️⃣ UPDATE UI
//                       // ======================================
//                       setState(() {
//                         loyaltyData = data;
//                         availablePoints = pts;
//                         isRedeemActive = true;
//                         showCustomerInput = true;
//
//                         // Disable field after successful add
//                         isCustomerFieldDisabled = true;
//                       });
//
//                       print(
//                           "AFTER ADD -> isCustomerFieldDisabled = $isCustomerFieldDisabled");
//                       // ======================================
//                       // 6️⃣ SAVE CONTACT LOCALLY
//                       // ======================================
//                       offlineOrder["loyaltyContact"] = contact;
//                       offlineOrder["available_points"] = pts; // FIX: persist so it survives later refreshes
//
//                       await offlineBox.put(localKey, offlineOrder);
//
//                       // ======================================
//                       // 7️⃣ UPDATE CUSTOMER DISPLAY
//                       // ======================================
//                       // ======================================
// // 7️⃣ DO NOT REFRESH CUSTOMER DISPLAY
// // ======================================
// //                       try {
// //                         await const MethodChannel(
// //                           'com.alekta.pinakapos/sunmi_display',
// //                         ).invokeMethod(
// //                           'showCustomerData',
// //                           {
// //                             'orderId': int.tryParse(localKey) ?? 0,
// //                             'items': List<Map<String, dynamic>>.from(
// //                               offlineOrder['products'] ?? [],
// //                             ),
// //
// //                             'grossTotal': grossTotal,
// //                             'discount': discount,
// //                             'merchantDiscount': merchantDiscount,
// //                             'netTotal': NetTotal,
// //                             'tax': tax,
// //                             'netPayable': computedNetPayable,
// //                             'orderDate': offlineOrder['order_date'] ?? '',
// //                             'orderTime': offlineOrder['order_time'] ?? '',
// //                             'cashbackFee':
// //                             (offlineOrder['cashback_fee'] as num?)
// //                                 ?.toDouble() ??
// //                                 0.0,
// //                             'loyaltyContact': contact,
// //                             'availablePoints': pts,
// //                             'summaryEnabled': true,
// //                           },
// //                         );
// //                       } on PlatformException catch (e) {
// //                         if (e.code != 'NO_DISPLAY') {
// //                           rethrow;
// //                         }
// //                       }
//
//                       try {
//                         // Use the SAME item list/count logic as Order Summary's
//                         // _computeTotalItems(), so the customer display's count
//                         // matches exactly (excludes merchant-discount rows only).
//                         final List<Map<String, dynamic>> rawDisplayProducts =
//                         List<Map<String, dynamic>>.from(
//                           offlineOrder['products'] ?? [],
//                         );
//
//                         final List<Map<String, dynamic>> filteredDisplayProducts =
//                         rawDisplayProducts.where((p) {
//                           final t = (p['item_type'] ?? p['type'] ?? '')
//                               .toString()
//                               .toLowerCase();
//                           final n = (p['item_name'] ??
//                               p['name'] ??
//                               '')
//                               .toString()
//                               .toLowerCase();
//                           return !(t.contains('discount') ||
//                               n.contains('merchant discount'));
//                         }).toList();
//
//                         // final int totalItemsForDisplay =
//                         // filteredDisplayProducts.fold<int>(0, (sum, p) {
//                         //   final qty = int.tryParse(
//                         //     (p['items_count'] ??
//                         //         p['quantity'] ??
//                         //         p['qty'] ??
//                         //         1)
//                         //         .toString(),
//                         //   ) ??
//                         //       1;
//                         //   return sum + qty;
//                         // });
//                         final int totalItemsForDisplay = _computeTotalItems();
//
//                         await const MethodChannel(
//                           'com.alekta.pinakapos/sunmi_display',
//                         ).invokeMethod(
//                           'showCustomerData',
//                           {
//                             'orderId': int.tryParse(localKey) ?? 0,
//                             'items': filteredDisplayProducts,
//                             'totalItems': totalItemsForDisplay,
//
//                             'grossTotal': grossTotal,
//                             'discount': discount,
//                             'merchantDiscount': merchantDiscount,
//                             'netTotal': NetTotal,
//                             'tax': tax,
//                             'netPayable': computedNetPayable,
//                             'orderDate': offlineOrder['order_date'] ?? '',
//                             'orderTime': offlineOrder['order_time'] ?? '',
//                             'cashbackFee':
//                             (offlineOrder['cashback_fee'] as num?)
//                                 ?.toDouble() ??
//                                 0.0,
//                             'loyaltyContact': contact,
//                             'availablePoints': pts,
//                             'summaryEnabled': true,
//                           },
//                         );
//                       } on PlatformException catch (e) {
//                         if (e.code != 'NO_DISPLAY') {
//                           rethrow;
//                         }
//                       }
//                       if (mounted) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text("Customer Added Successfully!"),
//                             backgroundColor: Colors.green,
//                             duration: Duration(seconds: 1),
//                           ),
//                         );
//                       }
//                     } catch (e) {
//                       print("Print the error : $e");
//
//
//                     } finally {
//                       if (mounted) {
//                         setState(() => isAddLoading = false);
//                       }
//                     }
//                   },
//                   child: Container(
//                     height: 44,
//                     width: 126,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: isButtonDisabled
//                           ? Colors.grey.shade400 // 🔒 Disabled / Pending
//                           : showCustomerInput
//                           ? Colors.red // ❌ Cancel
//                           : const Color(0xFF3B4259), // ➕ Add
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: isAddLoading
//                         ? const SizedBox(
//                       height: 16,
//                       width: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                         : Text(
//                       showCustomerInput ? '× Cancel' : '+ Add',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 )

                // ---------------- ADD / CANCEL BUTTON (SAME LOGIC) ----------------
                InkWell(
                  onTap: isButtonDisabled
                      ? null
                      : () async {
                    // ---------- CANCEL ----------
                    if (showCustomerInput) {
                      // Only allow cancel if not disabled
                      if (isPaymentDone || redeemedValue > 0) return;

                      setState(() {
                        mobileController.clear();
                        showCustomerInput = false;
                        isPhoneValid = false;
                        isEmailValid = false;
                        isRedeemActive = false;
                        // Enable field again
                        isCustomerFieldDisabled = false;
                        // FIX: reset points in UI state when cancelling
                        availablePoints = 0;
                        loyaltyData = null;
                      });

                      final offlineBox = StorageProvider.offlineOrders;
                      final localKey = widget.offlineOrderId?.toString();

                      if (localKey != null) {
                        final existing = await offlineBox.get(localKey);
                        if (existing != null) {
                          final d = Map<String, dynamic>.from(
                              existing is Map ? existing : {});
                          d["loyaltyContact"] = "";
                          d["available_points"] = 0; // FIX: clear persisted points too
                          await offlineBox.put(localKey, d);
                        }
                      }

                      final localOrderId = widget.offlineOrderId;
                      if (localOrderId != null) {
                        // FIX: push the cleared contact/points straight to the
                        // customer display, same channel/shape as the ADD flow,
                        // so it doesn't keep showing the old number/points.
                        try {
                          final List<Map<String, dynamic>> rawDisplayProducts =
                          List<Map<String, dynamic>>.from(
                            offlineOrder?['products'] ?? [],
                          );

                          final List<Map<String, dynamic>> filteredDisplayProducts =
                          rawDisplayProducts.where((p) {
                            final t = (p['item_type'] ?? p['type'] ?? '')
                                .toString()
                                .toLowerCase();
                            final n = (p['item_name'] ??
                                p['name'] ??
                                '')
                                .toString()
                                .toLowerCase();
                            return !(t.contains('discount') ||
                                n.contains('merchant discount'));
                          }).toList();

                          final int totalItemsForDisplay = _computeTotalItems();

                          await const MethodChannel(
                            'com.alekta.pinakapos/sunmi_display',
                          ).invokeMethod(
                            'showCustomerData',
                            {
                              'orderId': localOrderId,
                              'items': filteredDisplayProducts,
                              'totalItems': totalItemsForDisplay,

                              'grossTotal': grossTotal,
                              'discount': discount,
                              'merchantDiscount': merchantDiscount,
                              'netTotal': NetTotal,
                              'tax': tax,
                              'netPayable': computedNetPayable,
                              'orderDate': offlineOrder?['order_date'] ?? '',
                              'orderTime': offlineOrder?['order_time'] ?? '',
                              'cashbackFee':
                              (offlineOrder?['cashback_fee'] as num?)
                                  ?.toDouble() ??
                                  0.0,
                              'loyaltyContact': '',
                              'availablePoints': 0,
                              'summaryEnabled': true,
                            },
                          );
                        } on PlatformException catch (e) {
                          if (e.code != 'NO_DISPLAY') {
                            rethrow;
                          }
                        }
                        unawaited(_syncCfdFromOrderSummary());
                        await CustomerDisplayHelper.updateCustomerDisplay(
                          localOrderId,
                          summaryEnabled: true,
                        );
                      }
                      return;
                    }

                    // ---------- ADD ----------
                    // ---------- ADD ----------
                    if (!(isPhoneValid || isEmailValid)) return;

                    // ✅ Close keyboard immediately
                    FocusManager.instance.primaryFocus?.unfocus();

                    setState(() => isAddLoading = true);

                    final contact = mobileController.text.trim();

                    try {
                      // ======================================
                      // 1️⃣ LOAD OFFLINE ORDER FROM HIVE
                      // ======================================
                      final offlineBox = StorageProvider.offlineOrders;

                      final localKey = widget.offlineOrderId?.toString();

                      if (localKey == null) {
                        throw Exception("Offline order not found");
                      }

                      final existing = await offlineBox.get(localKey);

                      if (existing == null) {
                        throw Exception("Order data missing");
                      }

                      final offlineOrder =
                      Map<String, dynamic>.from(existing);

                      print("🟡 OFFLINE ORDER LOADED");

                      // ======================================
                      // 2️⃣ SYNC ORDER WITH BACKEND
                      // ======================================
                      final syncResponse =
                      await orderBloc.syncSingleOfflineOrder(
                        offlineOrder,
                      );

                      print("✅ SYNC RESPONSE points: $syncResponse");

                      if (syncResponse == null) {
                        throw Exception("Sync failed");
                      }

                      // ======================================
                      // 3️⃣ GET WOO ORDER ID
                      // ======================================
                      final int syncedOrderId = syncResponse["id"] ?? 0;

                      if (syncedOrderId == 0) {
                        throw Exception("Backend order id missing");
                      }

                      print("🟢 WOO ORDER ID lo: $syncedOrderId");

                      // ======================================
                      // 4️⃣ CALL CREATE CUSTOMER API
                      // ======================================
                      final rawResponse =
                      await orderBloc.addLoyaltyPoints(
                        orderId: syncedOrderId,
                        contact: contact,
                      );

                      print("🌐 CUSTOMER RESPONSE: $rawResponse");

                      final result = jsonDecode(rawResponse);

                      print("✅ FULL CUSTOMER RESULT: $result");

                      if (result == null) {
                        throw Exception("Empty customer response");
                      }

                      if (result["success"] == false) {
                        throw Exception(
                          result["message"] ?? "Customer API failed",
                        );
                      }

                      final data = result["data"] ?? {};

                      final pts = int.tryParse(
                        data["available_points"]?.toString() ?? "0",
                      ) ??
                          0;
                      // ======================================
                      // 5️⃣ UPDATE UI
                      // ======================================
                      setState(() {
                        loyaltyData = data;
                        availablePoints = pts;
                        isRedeemActive = true;
                        showCustomerInput = true;

                        // Disable field after successful add
                        isCustomerFieldDisabled = true;
                      });

                      print(
                          "AFTER ADD -> isCustomerFieldDisabled = $isCustomerFieldDisabled");
                      // ======================================
                      // 6️⃣ SAVE CONTACT LOCALLY
                      // ======================================
                      offlineOrder["loyaltyContact"] = contact;
                      offlineOrder["available_points"] = pts; // FIX: persist so it survives later refreshes

                      await offlineBox.put(localKey, offlineOrder);

                      // ======================================
                      // 7️⃣ UPDATE CUSTOMER DISPLAY
                      // ======================================
                      // ======================================
// 7️⃣ DO NOT REFRESH CUSTOMER DISPLAY
// ======================================
//                       try {
//                         await const MethodChannel(
//                           'com.alekta.pinakapos/sunmi_display',
//                         ).invokeMethod(
//                           'showCustomerData',
//                           {
//                             'orderId': int.tryParse(localKey) ?? 0,
//                             'items': List<Map<String, dynamic>>.from(
//                               offlineOrder['products'] ?? [],
//                             ),
//
//                             'grossTotal': grossTotal,
//                             'discount': discount,
//                             'merchantDiscount': merchantDiscount,
//                             'netTotal': NetTotal,
//                             'tax': tax,
//                             'netPayable': computedNetPayable,
//                             'orderDate': offlineOrder['order_date'] ?? '',
//                             'orderTime': offlineOrder['order_time'] ?? '',
//                             'cashbackFee':
//                             (offlineOrder['cashback_fee'] as num?)
//                                 ?.toDouble() ??
//                                 0.0,
//                             'loyaltyContact': contact,
//                             'availablePoints': pts,
//                             'summaryEnabled': true,
//                           },
//                         );
//                       } on PlatformException catch (e) {
//                         if (e.code != 'NO_DISPLAY') {
//                           rethrow;
//                         }
//                       }

                      try {
                        // Use the SAME item list/count logic as Order Summary's
                        // _computeTotalItems(), so the customer display's count
                        // matches exactly (excludes merchant-discount rows only).
                        final List<Map<String, dynamic>> rawDisplayProducts =
                        List<Map<String, dynamic>>.from(
                          offlineOrder['products'] ?? [],
                        );

                        final List<Map<String, dynamic>> filteredDisplayProducts =
                        rawDisplayProducts.where((p) {
                          final t = (p['item_type'] ?? p['type'] ?? '')
                              .toString()
                              .toLowerCase();
                          final n = (p['item_name'] ??
                              p['name'] ??
                              '')
                              .toString()
                              .toLowerCase();
                          return !(t.contains('discount') ||
                              n.contains('merchant discount'));
                        }).toList();

                        // final int totalItemsForDisplay =
                        // filteredDisplayProducts.fold<int>(0, (sum, p) {
                        //   final qty = int.tryParse(
                        //     (p['items_count'] ??
                        //         p['quantity'] ??
                        //         p['qty'] ??
                        //         1)
                        //         .toString(),
                        //   ) ??
                        //       1;
                        //   return sum + qty;
                        // });
                        final int totalItemsForDisplay = _computeTotalItems();

                        await const MethodChannel(
                          'com.alekta.pinakapos/sunmi_display',
                        ).invokeMethod(
                          'showCustomerData',
                          {
                            'orderId': int.tryParse(localKey) ?? 0,
                            'items': filteredDisplayProducts,
                            'totalItems': totalItemsForDisplay,

                            'grossTotal': grossTotal,
                            'discount': discount,
                            'merchantDiscount': merchantDiscount,
                            'netTotal': NetTotal,
                            'tax': tax,
                            'netPayable': computedNetPayable,
                            'orderDate': offlineOrder['order_date'] ?? '',
                            'orderTime': offlineOrder['order_time'] ?? '',
                            'cashbackFee':
                            (offlineOrder['cashback_fee'] as num?)
                                ?.toDouble() ??
                                0.0,
                            'loyaltyContact': contact,
                            'availablePoints': pts,
                            'summaryEnabled': true,
                          },
                        );
                      } on PlatformException catch (e) {
                        if (e.code != 'NO_DISPLAY') {
                          rethrow;
                        }
                      }
                      unawaited(_syncCfdFromOrderSummary());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Customer Added Successfully!"),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    } catch (e) {
                      print("Print the error : $e");


                    } finally {
                      if (mounted) {
                        setState(() => isAddLoading = false);
                      }
                    }
                  },
                  child: Container(
                    height: 44,
                    width: 126,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isButtonDisabled
                          ? Colors.grey.shade400 // 🔒 Disabled / Pending
                          : showCustomerInput
                          ? Colors.red // ❌ Cancel
                          : const Color(0xFF3B4259), // ➕ Add
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isAddLoading
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      showCustomerInput ? '× Cancel' : '+ Add',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 90),
          // User profile section with container and notification bell
          Row(
            children: [
              Container(
                height: ResponsiveLayout.getHeight(45),
                margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.getPadding(16),
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        themeHelper.themeMode == ThemeMode.dark ? 0.3 : 0.12,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: ResponsiveLayout.getRadius(18),
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userDisplayName ?? TextConstants.unknown)
                            .substring(0, 1),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userDisplayName ?? "",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                            fontSize: ResponsiveLayout.getFontSize(14),
                          ),
                        ),
                        Text(
                          userRole ?? TextConstants.unknown,
                          style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveLayout.getWidth(16)),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        themeHelper.themeMode == ThemeMode.dark ? 0.3 : 0.15,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                child: Icon(
                  Icons.notifications_outlined,
                  size: ResponsiveLayout.getIconSize(24),
                ),
              ),
            ],
          ),

          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    int totalItems = _computeTotalItems();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            left: ResponsiveLayout.getPadding(10),
            right: ResponsiveLayout.getPadding(10),
            bottom: ResponsiveLayout.getPadding(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Color(0xFFFFFFFF),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
              left: ResponsiveLayout.getPadding(12),
              right: ResponsiveLayout.getPadding(10),
              bottom: ResponsiveLayout.getPadding(15),
              top: ResponsiveLayout.getPadding(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// LEFT — Order ID
                  Row(
                    children: [
                      Text(
                        '${TextConstants.orderId}: ',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(16),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '# $orderId ',
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveLayout.getFontSize(16),
                            ),
                          ),



                        ],
                      ),
                    ],
                  ),

                  /// PUSH RIGHT CONTENT TO END
                  const Spacer(),

                  /// RIGHT — Date + Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: ResponsiveLayout.getIconSize(20),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white // Dark mode color
                            : const Color(0xFF4C5F7D), // Light mode color
                      ),

                      const SizedBox(width: 6),
                      Text(
                        _displayDate,
                        style: TextStyle(
                          fontSize: ResponsiveLayout.getFontSize(13),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// Divider
                      Container(
                        height: ResponsiveLayout.getHeight(16),
                        width: 1,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54 // slightly lighter for dark mode
                            : Colors.grey.shade400,
                      ),

                      const SizedBox(width: 8),

                      /// Time
                      Text(
                        _displayTime,
                        style: TextStyle(
                          fontSize: ResponsiveLayout.getFontSize(13),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                height: 30,
                margin: EdgeInsets.fromLTRB(
                  ResponsiveLayout.getPadding(2),
                  ResponsiveLayout.getPadding(5),
                  ResponsiveLayout.getPadding(2),
                  0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE6464),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Item Name
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Item Name",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14), // SAME
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),

                    // Unit
                    Expanded(
                      flex: 1,
                      child: Text(
                        "Unit",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                    // Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Price",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14), // SAME
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveLayout.getHeight(8)),
              Expanded(
                flex: 6,
                child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(ResponsiveLayout.getRadius(10)),
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.secondaryBackground
                          : Colors.white,
                      border: Border.all(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.borderColor
                              : Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: orderItems.length,
                      itemBuilder: (context, index) {
                        return _buildOrderItem(index);
                      },
                    )),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(6)),
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                ),
                margin: EdgeInsets.only(top: ResponsiveLayout.getPadding(10)),
                child: AnimatedSize(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showFullSummary
                      ? Container(
                    height: ResponsiveLayout.getHeight(205),
                    margin: EdgeInsets.only(
                      top: ResponsiveLayout.getPadding(0),
                      right: ResponsiveLayout.getPadding(1),
                      left: ResponsiveLayout.getPadding(1),
                      bottom: ResponsiveLayout.getPadding(3),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          topLeft: Radius.circular(8)),
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.orderPanelSummary
                          : Colors.white,
                      boxShadow: [
                        // Shadow at the top
                        BoxShadow(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? Color(0xFFF0F0F0).withOpacity(
                              0.15) // dark mode top shadow
                              : Colors.black.withOpacity(
                              0.15), // light mode top shadow
                          // color: Colors.black.withOpacity(0.15),
                          offset: Offset(
                              0, -4), // 0 horizontal, -4 vertical (up)
                          blurRadius: 6,
                          spreadRadius: -0.5,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.getPadding(8),
                    ),
                    child: isSummaryLoading
                        ? Center(child: CircularProgressIndicator())
                        : ScrollConfiguration(
                      behavior: NoScrollbarBehavior()
                          .copyWith(overscroll: false),
                      // thumbVisibility: true,
                      // radius: Radius.circular(10),
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildOrderCalculation(
                              TextConstants.grossTotal,
                              grossTotal < 0
                                  ? '-${TextConstants.currencySymbol}${grossTotal.abs().toStringAsFixed(2)}'
                                  : '${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}',
                              isTotal: true,
                            ),
                            //Raghu--**
                            if (merchantDiscount < 0)
                              _buildOrderCalculation(
                                merchantDiscountPercentage > 0
                                    ? '${TextConstants.merchantDiscount} (${merchantDiscountPercentage % 1 == 0 ? merchantDiscountPercentage.toStringAsFixed(0) : merchantDiscountPercentage.toStringAsFixed(1)}%)'
                                    : TextConstants
                                    .merchantDiscount,
                                '-${TextConstants.currencySymbol}${merchantDiscount.abs().toStringAsFixed(2)}',
                              ),
                            _buildOrderCalculation(
                                TextConstants.discountText,
                                '-${TextConstants.currencySymbol}${discount.abs().toStringAsFixed(2)}',
                                isDiscount: true),

                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: themeHelper.themeMode ==
                                      ThemeMode.dark
                                      ? [
                                    Colors.white
                                        .withOpacity(0.1),
                                    Colors.white
                                        .withOpacity(0.7),
                                    Colors.white
                                        .withOpacity(0.1),
                                  ]
                                      : [
                                    Colors.black
                                        .withOpacity(0.1),
                                    Colors.black
                                        .withOpacity(0.7),
                                    Colors.black
                                        .withOpacity(0.1),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: DottedLine(
                                dashLength: 6,
                                dashGapLength: 4,
                                lineThickness: 1,
                                direction: Axis.horizontal,
                                dashColor: themeHelper.themeMode ==
                                    ThemeMode.dark
                                    ? Colors.white
                                    : Colors
                                    .black, // ✅ ensures gradient works correctly
                              ),
                            ),
                            //Raghu--***

                            _buildOrderCalculation(
                              TextConstants.NetTotal,
                              NetTotal < 0
                                  ? '-${TextConstants.currencySymbol}${NetTotal.abs().toStringAsFixed(2)}'
                                  : '${TextConstants.currencySymbol}${NetTotal.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                              TextConstants.taxText,
                              '${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}',
                            ),
                            //Raghu--*

                            if (cashbackFee > 0)
                              _buildOrderCalculation(
                                TextConstants.cashbackFee,
                                '${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}',
                              ),

                            /// Service Charges
                            _buildOrderCalculation(
                                TextConstants.servicecharges,
                                '${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}'),

                            if (redeemedValue > 0)
                              _buildOrderCalculation(
                                "Redeemed Amount",
                                '-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}',
                              ),

                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: themeHelper.themeMode ==
                                      ThemeMode.dark
                                      ? [
                                    Colors.white
                                        .withOpacity(0.1),
                                    Colors.white
                                        .withOpacity(0.7),
                                    Colors.white
                                        .withOpacity(0.1),
                                  ]
                                      : [
                                    Colors.black
                                        .withOpacity(0.1),
                                    Colors.black
                                        .withOpacity(0.7),
                                    Colors.black
                                        .withOpacity(0.1),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: DottedLine(
                                dashLength: 6,
                                dashGapLength: 4,
                                lineThickness: 1,
                                direction: Axis.horizontal,
                                dashColor: themeHelper.themeMode ==
                                    ThemeMode.dark
                                    ? Colors.white
                                    : Colors
                                    .black, // ✅ ensures gradient works correctly
                              ),
                            ),

                            // _buildOrderCalculation(
                            //   TextConstants.netPayable,
                            //   computedNetPayable < 0
                            //       ? '-${TextConstants.currencySymbol}${computedNetPayable.abs().toStringAsFixed(2)}'
                            //       : '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                            //   isTotal: true,
                            // ),

                            _buildOrderCalculation(
                              TextConstants.netPayable,
                              computedNetPayable < 0
                                  ? '-${TextConstants.currencySymbol}${computedNetPayable.abs().toStringAsFixed(2)}'
                                  : '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                              isTotal: true,
                            ),

                            // if (redeemedValue > 0)
                            //   _buildOrderCalculation(
                            //     "Redeemed Amount",
                            //     '-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}',
                            //   ),
                            _buildOrderCalculation(
                              "Pay by Card",
                              '${TextConstants.currencySymbol}${payByCard.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                                TextConstants.payByCash,
                                '${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}'),
                            _buildOrderCalculation(
                              "Pay by EBT",
                              '${TextConstants.currencySymbol}${payByEbt.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                                TextConstants.payByOther,
                                '${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.tenderAmount,
                                '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.change,
                                '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}'),
                            // After Change Amount Row
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Order Earned Points",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[800],
                                  ),
                                ),
                                Text(
                                  "${_order['total_loyalty_points'] ?? 0} pts",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      : SizedBox.shrink(),
                ),
              ),
              GestureDetector(
                onTap: _toggleSummary,
                child: Container(
                  height: 32,
                  margin: EdgeInsets.only(
                    top: _showFullSummary
                        ? ResponsiveLayout.getPadding(0)
                        : ResponsiveLayout.getPadding(0),
                    right: ResponsiveLayout.getPadding(1),
                    left: ResponsiveLayout.getPadding(1),
                    bottom: ResponsiveLayout.getPadding(3),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomRight:
                      Radius.circular(ResponsiveLayout.getRadius(6)),
                      bottomLeft:
                      Radius.circular(ResponsiveLayout.getRadius(6)),
                      topLeft: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(6)),
                      topRight: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(6)),
                    ),
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Color(0xFF32343E)
                        : const Color(0xFFEAEDFE),

                    /// ⭐ ADD THIS SHADOW
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            themeHelper.themeMode == ThemeMode.dark
                                ? 0.3
                                : 0.15),
                        offset: const Offset(0, 3),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(18),
                    vertical: ResponsiveLayout.getPadding(0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${TextConstants.totalItemsText}: $totalItems",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _showFullSummary
                                ? '${TextConstants.netPayable} : '
                                '${_formatNetPayable(computedNetPayable - redeemedValue)}'
                                : '${TextConstants.netPayable} '
                                '${_formatNetPayable(computedNetPayable - redeemedValue)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark
                                  : ThemeNotifier.textLight,
                            ),
                          ),
                          SizedBox(width: ResponsiveLayout.getPadding(8)),
                          Icon(
                            _showFullSummary
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 0, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  final OrderHelper orderHelper =
  OrderHelper(); // Helper instance to manage orders

  // Build #1.0.10: Fetches order items for the active order
  Future<void> fetchOrderItems() async {
    if (orderHelper.activeOrderId != null) {
      var orderData =
      await orderHelper.getOrderById(orderHelper.activeOrderId!);
      List<Map<String, dynamic>> items = await orderHelper
          .getOrderItems(orderData.first[AppDBConst.orderServerId]);

      //Build #1.0.29:  Fetch the orderServerId from the database

      if (orderData.isNotEmpty) {
        double dbMerchantDiscountPerc = 0.0;
        try {
          final box = StorageProvider.offlineOrders;
          final key = (orderHelper.activeOrderId).toString();
          if (await box.containsKey(key)) {
            final raw = await box.get(key);
            if (raw is Map) {
              dbMerchantDiscountPerc = double.tryParse(
                  raw['merchantDiscountPercentage']?.toString() ?? '0') ??
                  0.0;
            }
          }
        } catch (_) {}

        setState(() {
          orderId = orderData.first[AppDBConst.orderServerId] as int? ?? 0;
          orderDateTime =
          "${orderData.first[AppDBConst.orderDate]} ${orderData.first[AppDBConst.orderTime]}";
          discount =
              (orderData.first[AppDBConst.orderDiscount] as num?)?.toDouble() ??
                  0.0; // Fetch discount
          final dbMerchantDiscount =
              (orderData.first[AppDBConst.merchantDiscount] as num?)
                  ?.toDouble() ??
                  0.0;
          // Keep merchant discount algebraic (negative) for summary display/total logic.
          merchantDiscount = dbMerchantDiscount != 0
              ? -(dbMerchantDiscount.abs())
              : 0.0; // Build #1.0.80
          merchantDiscountPercentage = dbMerchantDiscountPerc;
          tax =
              (orderData.first[AppDBConst.orderTax] as num?)?.toDouble() ?? 0.0;
          orderTotal =
              (orderData.first[AppDBConst.orderTotal] as num?)?.toDouble() ??
                  0.0; // Build #1.0.80
          cashbackFee = (orderData.first[AppDBConst.orderCashbackFee] as num?)
              ?.toDouble() ??
              0.0;
          orderStatus = (orderData.first[AppDBConst.orderStatus] as String?) ??
              TextConstants.processing; // Build  #1.0.177
          if (kDebugMode) {
            print(
                "Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${orderHelper.activeOrderId}, Time: $orderDateTime");
          }
        });
      } else {
        if (kDebugMode) {
          print(
              "No orderServerId found for activeOrderId: ${orderHelper.activeOrderId}");
        }
      }

      /// Call fetch payment details by order id API call after order id assigned here above, otherwise we get null order id
      _fetchPaymentsByOrderId();

      // Build #1.0.29: Calculate balance amount from order items
      for (var item in items) {
        double price = (item[AppDBConst.itemPrice] as num).toDouble();
        int count = item[AppDBConst.itemCount] as int;
        total += price * count;
      }

      if (kDebugMode) {
        print("##### fetchOrderItems :$items");
        print("Calculated balance amount: $total");
        print(
            "##### DEBUG 1001 orderTotal: $orderTotal, payByCash: $payByCash");
      }

      setState(() {
        orderItems = items;
        grossTotal = GlobalUtility.getGrossTotal(
            orderItems); // Build #1.0.138: GrossTotal calculation form global class for code re usability
        balanceAmount =
            orderTotal; // Build #1.0.138: using orderTotal from API value #No need our calculation here
        tenderAmount = 0.0; // Reset for new order
        changeAmount = 0.0; // Reset for new order
        paidAmount = 0.0; // Reset for new order
      });
    } else {
      setState(() {
        orderItems.clear();
        balanceAmount = 0.0;
        tenderAmount = 0.0; // Reset
        changeAmount = 0.0; // Reset
        paidAmount = 0.0; // Reset
        discount = 0.0; // Reset discount
      });
    }
  }

//   Widget _buildOrderItem(int index) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     final orderItem = orderItems[index];
//
//     final String itemType =
//         orderItem['item_type']?.toString().toLowerCase() ?? '';
//     final String itemNameLower =
//     (orderItem['item_name']?.toString() ?? '').toLowerCase();
//
//     // Hide merchant discount line-items from the list (keep it in totals section).
//     if (itemType.contains('discount') ||
//         itemNameLower.contains('merchant discount')) {
//       return const SizedBox.shrink();
//     }
//
//     final bool isPayout = itemType.contains(TextConstants.payoutText);
//     final bool isCoupon = itemType.contains(TextConstants.couponText);
//     final bool isCashback = itemType.contains("cashback");
//     final bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
//
//     // Parse variation_id: Woo/Hive use variation_id; SQLite uses item_variation_id.
//     final int varId = _orderSummaryLineVariationId(orderItem);
//     final bool hasVariationId = varId > 0;
//
//     // Only show variant icon for actual product line items (not payout/coupon/custom/cashback)
//     final bool isProductItem = !isPayoutOrCoupon;
//     final bool isVariantFlag =
//         orderItem['is_variant'] == true || orderItem['is_variant'] == 1;
//     // item_variation_custom_name is populated from API even for simple lines
//     // (fallback is the full line-item name), so never treat name alone as variant.
//     final bool isVariant = isProductItem &&
//         (isVariantFlag ||
//             (itemType == 'variant' || itemType == 'variation') ||
//             hasVariationId);
//
//     final bool isEbtEligible = _orderSummaryLineEbtEligible(orderItem);
//
//     final String itemName = orderItem['item_name']?.toString() ?? '';
//     final double itemPrice = (orderItem['item_price'] ?? 0).toDouble();
//     final int itemCount = (orderItem['items_count'] ?? 0).toInt();
//
//     final double originalTotal = (orderItem['item_sum_price'] ?? 0).toDouble();
//
//     // --------------------------------------------------
//     // ✅ DISCOUNT EXTRACTION
//     // --------------------------------------------------
//     // -----------------------------
// // DISCOUNT EXTRACTION
// // -----------------------------
//     final String discountType =
//         orderItem['discount_type']?.toString().toLowerCase() ?? '';
//
//     double _num(dynamic value) {
//       if (value is num) return value.toDouble();
//       return double.tryParse(value?.toString() ?? '') ?? 0.0;
//     }
//
//     // Pending/offline orders may use *_total or camelCase keys.
//     double autoDiscount = _num(orderItem['auto_discount']) != 0
//         ? _num(orderItem['auto_discount'])
//         : _num(orderItem['auto_discount_total']) != 0
//         ? _num(orderItem['auto_discount_total'])
//         : _num(orderItem['autoDiscount']) != 0
//         ? _num(orderItem['autoDiscount'])
//         : _num(orderItem['autoDiscountTotal']) != 0
//         ? _num(orderItem['autoDiscountTotal'])
//         : _num(orderItem['display_auto_discount']);
//
//     double comboDiscount = [
//       orderItem['combo_discount_total'],
//       orderItem['comboDiscountTotal'],
//       orderItem['combo_discount'],
//     ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);
//
//     double mixMatchDiscount = [
//       orderItem['mixmatch_discount_total'],
//       orderItem['mixMatchDiscountTotal'],
//       orderItem['mixmatch_discount'],
//     ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);
//
//     double multipackDiscount = [
//       orderItem['multipack_discount_total'],
//       orderItem['multipackDiscountTotal'],
//       orderItem['multipack_discount'],
//     ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);
//
//     /// 🔥 FIX: backend sometimes moves discount into auto_discount
//     if (discountType == 'mixmatch' &&
//         autoDiscount > 0 &&
//         mixMatchDiscount == 0) {
//       mixMatchDiscount = autoDiscount;
//       autoDiscount = 0;
//     }
//
//     if (discountType == 'combo' && autoDiscount > 0 && comboDiscount == 0) {
//       comboDiscount = autoDiscount;
//       autoDiscount = 0;
//     }
//
//     if (discountType == 'multipack' &&
//         autoDiscount > 0 &&
//         multipackDiscount == 0) {
//       multipackDiscount = autoDiscount;
//       autoDiscount = 0;
//     }
//
//     /// Flags
//     final bool hasAutoDiscount = autoDiscount > 0;
//     final bool isComboDiscount = comboDiscount > 0 || mixMatchDiscount > 0;
//     final bool isMultipackDiscount = multipackDiscount > 0;
//
//     /// Final price
//     final double finalItemTotal = originalTotal -
//         autoDiscount -
//         comboDiscount -
//         mixMatchDiscount -
//         multipackDiscount;
//
//     print(
//       "SUMMARY ITEM -> ${orderItem['item_name']} "
//           "TYPE:$discountType "
//           "AUTO:$autoDiscount "
//           "COMBO:$comboDiscount "
//           "MIX:$mixMatchDiscount "
//           "MULTIPACK:$multipackDiscount",
//     );
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//           child: SizedBox(
//             height: 40,
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 /// LEFT + CENTER COLUMN
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       /// ROW 1 — NAME + QTY
//                       SizedBox(
//                         height: 16,
//                         child: Row(
//                           children: [
//                             SizedBox(
//                               width: 150,
//                               child: Text(
//                                 itemName.length > 30
//                                     ? '${itemName.substring(0, 30)}...'
//                                     : itemName,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   fontSize: 12.5,
//                                   height: 1.0,
//                                   fontWeight: FontWeight.bold,
//                                   color: themeHelper.themeMode == ThemeMode.dark
//                                       ? ThemeNotifier.textDark
//                                       : ThemeNotifier.textLight,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             if (!isPayoutOrCoupon)
//                               Text(
//                                 "${TextConstants.currencySymbol}${itemPrice.toStringAsFixed(2)} x $itemCount",
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   height: 1.0,
//                                   fontWeight: FontWeight.bold,
//                                   color: themeHelper.themeMode == ThemeMode.dark
//                                       ? ThemeNotifier.textDark
//                                       : Colors.black87,
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//
//                       /// ROW 2 — BADGES
//                       /// ROW 2 — BADGES
//                       if (isEbtEligible ||
//                           isVariant ||
//                           hasAutoDiscount ||
//                           isComboDiscount ||
//                           isMultipackDiscount)
//                         SizedBox(
//                           height: 12,
//                           child: Row(
//                             children: [
//                               if (isEbtEligible)
//                                 Container(
//                                   height: 14,
//                                   padding:
//                                   const EdgeInsets.symmetric(horizontal: 6),
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color: Colors.green,
//                                     borderRadius: BorderRadius.circular(3),
//                                   ),
//                                   child: const Text(
//                                     "EBT",
//                                     style: TextStyle(
//                                       fontSize: 8,
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                               if (isVariant) ...[
//                                 const SizedBox(width: 5),
//                                 SvgPicture.asset(
//                                   SvgUtils.variationIcon,
//                                   height: 8,
//                                   width: 8,
//                                 ),
//                               ],
//                               if (hasAutoDiscount) ...[
//                                 const SizedBox(width: 5),
//                                 _discountBadge(
//                                   "Autodiscount",
//                                   Colors.red,
//                                   amount: autoDiscount,
//                                 ),
//                               ],
//                               if (isComboDiscount) ...[
//                                 const SizedBox(width: 5),
//                                 _discountBadge(
//                                   "combo discount",
//                                   Colors.orange,
//                                   amount: comboDiscount + mixMatchDiscount,
//                                 ),
//                               ],
//                               if (isMultipackDiscount) ...[
//                                 const SizedBox(width: 5),
//                                 _discountBadge(
//                                   "Multipack",
//                                   Colors.blue,
//                                   amount: multipackDiscount,
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//
//                 /// RIGHT PRICE COLUMN
//                 SizedBox(
//                   //width: 55,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       /// FINAL PRICE
//                       SizedBox(
//                         height: 16,
//                         child: Text(
//                           isCoupon || isPayout
//                               ? "-${TextConstants.currencySymbol}${originalTotal.abs().toStringAsFixed(2)}"
//                               : "${TextConstants.currencySymbol}${finalItemTotal.toStringAsFixed(2)}",
//                           style: TextStyle(
//                             fontSize: 14,
//                             height: 1.0,
//                             fontWeight: FontWeight.bold,
//                             color: isCoupon || isPayout
//                                 ? Colors.red
//                                 : themeHelper.themeMode == ThemeMode.dark
//                                 ? ThemeNotifier.textDark
//                                 : ThemeNotifier.textLight,
//                           ),
//                         ),
//                       ),
//
//                       /// STRIKED ORIGINAL
//                       SizedBox(
//                         height: 12,
//                         child: ((hasAutoDiscount ||
//                             isComboDiscount ||
//                             isMultipackDiscount) &&
//                             !isPayoutOrCoupon)
//                             ? Text(
//                           "${TextConstants.currencySymbol}${originalTotal.toStringAsFixed(2)}",
//                           style: const TextStyle(
//                             fontSize: 12,
//                             height: 1.0,
//                             color: Colors.grey,
//                             decoration: TextDecoration.lineThrough,
//                           ),
//                         )
//                             : const SizedBox.shrink(),
//                       ),
//
//                       const SizedBox(height: 12),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//
//         /// ✅ DIVIDER — NOW IT WILL SHOW
//         Divider(
//           height: 1,
//           thickness: 0.8,
//           color: themeHelper.themeMode == ThemeMode.dark
//               ? Colors.black26
//               : Colors.grey.shade300,
//         ),
//       ],
//     );
//   }

  Widget _buildOrderItem(int index) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final orderItem = orderItems[index];

    final String itemType =
        orderItem['item_type']?.toString().toLowerCase() ?? '';
    final String itemNameLower =
    (orderItem['item_name']?.toString() ?? '').toLowerCase();

    // Hide merchant discount line-items from the list (keep it in totals section).
    if (itemType.contains('discount') ||
        itemNameLower.contains('merchant discount')) {
      return const SizedBox.shrink();
    }

    final bool isPayout = itemType.contains(TextConstants.payoutText);
    final bool isCoupon = itemType.contains(TextConstants.couponText);
    final bool isCashback = itemType.contains("cashback");
    final bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;

    // 🔥 CHECK IF WEIGHTED ITEM
    final bool isWeightedItem = itemType.contains('weighted');

    // Parse variation_id: Woo/Hive use variation_id; SQLite uses item_variation_id.
    final int varId = _orderSummaryLineVariationId(orderItem);
    final bool hasVariationId = varId > 0;

    // Only show variant icon for actual product line items (not payout/coupon/custom/cashback)
    final bool isProductItem = !isPayoutOrCoupon;
    final bool isVariantFlag =
        orderItem['is_variant'] == true || orderItem['is_variant'] == 1;
    final bool isVariant = isProductItem &&
        (isVariantFlag ||
            (itemType == 'variant' || itemType == 'variation') ||
            hasVariationId);

    final bool isEbtEligible = _orderSummaryLineEbtEligible(orderItem);

    final String itemName = orderItem['item_name']?.toString() ?? '';
    final double itemPrice = (orderItem['item_price'] ?? 0).toDouble();
    final int itemCount = (orderItem['items_count'] ?? 0).toInt();

    final double originalTotal = (orderItem['item_sum_price'] ?? 0).toDouble();

    // 🔥 EXTRACT WEIGHT DATA FOR WEIGHTED ITEMS
    double weightQty = 0.0;
    double unitPrice = 0.0;
    if (isWeightedItem) {
      weightQty = (orderItem['weight_qty'] ??
          orderItem['weightQty'] ??
          orderItem['weight'] ??
          0.0).toDouble();
      unitPrice = (orderItem['unit_price'] ??
          orderItem['regular_price'] ??
          orderItem['item_price'] ??
          0.0).toDouble();

      print('🟢 DISPLAY ITEM: ${orderItem['item_name']} | '
          'unitPricePerLb=$unitPrice | '
          'weightLbs=$weightQty | '
          'lineTotal=${unitPrice * weightQty}');
    }

    // --------------------------------------------------
    // ✅ DISCOUNT EXTRACTION
    // --------------------------------------------------
    final String discountType =
        orderItem['discount_type']?.toString().toLowerCase() ?? '';

    double _num(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    double autoDiscount = _num(orderItem['auto_discount']) != 0
        ? _num(orderItem['auto_discount'])
        : _num(orderItem['auto_discount_total']) != 0
        ? _num(orderItem['auto_discount_total'])
        : _num(orderItem['autoDiscount']) != 0
        ? _num(orderItem['autoDiscount'])
        : _num(orderItem['autoDiscountTotal']) != 0
        ? _num(orderItem['autoDiscountTotal'])
        : _num(orderItem['display_auto_discount']);

    double comboDiscount = [
      orderItem['combo_discount_total'],
      orderItem['comboDiscountTotal'],
      orderItem['combo_discount'],
    ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);

    double mixMatchDiscount = [
      orderItem['mixmatch_discount_total'],
      orderItem['mixMatchDiscountTotal'],
      orderItem['mixmatch_discount'],
    ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);

    double multipackDiscount = [
      orderItem['multipack_discount_total'],
      orderItem['multipackDiscountTotal'],
      orderItem['multipack_discount'],
    ].map((e) => _num(e)).firstWhere((v) => v != 0, orElse: () => 0);

    if (discountType == 'mixmatch' && autoDiscount > 0 && mixMatchDiscount == 0) {
      mixMatchDiscount = autoDiscount;
      autoDiscount = 0;
    }

    if (discountType == 'combo' && autoDiscount > 0 && comboDiscount == 0) {
      comboDiscount = autoDiscount;
      autoDiscount = 0;
    }

    if (discountType == 'multipack' && autoDiscount > 0 && multipackDiscount == 0) {
      multipackDiscount = autoDiscount;
      autoDiscount = 0;
    }

    final bool hasAutoDiscount = autoDiscount > 0;
    final bool isComboDiscount = comboDiscount > 0 || mixMatchDiscount > 0;
    final bool isMultipackDiscount = multipackDiscount > 0;

    final double finalItemTotal = originalTotal -
        autoDiscount -
        comboDiscount -
        mixMatchDiscount -
        multipackDiscount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// LEFT + CENTER COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ROW 1 — NAME + QTY
                      SizedBox(
                        height: 16,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(
                                itemName.length > 30
                                    ? '${itemName.substring(0, 30)}...'
                                    : itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.bold,
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? ThemeNotifier.textDark
                                      : ThemeNotifier.textLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isPayoutOrCoupon)
                              Builder(
                                builder: (_) {
                                  // 🔥 FOR WEIGHTED ITEMS - SHOW WEIGHT INFO
                                  if (isWeightedItem && weightQty > 0 && unitPrice > 0) {
                                    final double lineTotal = unitPrice * weightQty;
                                    return Text(
                                      "\$${unitPrice.toStringAsFixed(2)} × ${weightQty.toStringAsFixed(3)} lb",
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.0,
                                        fontWeight: FontWeight.bold,
                                        color: themeHelper.themeMode == ThemeMode.dark
                                            ? ThemeNotifier.textDark
                                            : Colors.black87,
                                      ),
                                    );
                                  }
                                  // 🔥 NORMAL ITEMS
                                  return Text(
                                    "${TextConstants.currencySymbol}${itemPrice.toStringAsFixed(2)} × $itemCount",
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.0,
                                      fontWeight: FontWeight.bold,
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? ThemeNotifier.textDark
                                          : Colors.black87,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      /// ROW 2 — WEIGHT BADGE (for weighted items)
                      // if (isWeightedItem && weightQty > 0)
                      //   SizedBox(
                      //     height: 12,
                      //     child: Row(
                      //       children: [
                      //         Container(
                      //           height: 14,
                      //           padding: const EdgeInsets.symmetric(horizontal: 6),
                      //           alignment: Alignment.center,
                      //           decoration: BoxDecoration(
                      //             color: Colors.orange,
                      //             borderRadius: BorderRadius.circular(3),
                      //           ),
                      //           child: Text(
                      //             "${weightQty.toStringAsFixed(3)} lb",
                      //             style: const TextStyle(
                      //               fontSize: 8,
                      //               color: Colors.white,
                      //               fontWeight: FontWeight.bold,
                      //             ),
                      //           ),
                      //         ),
                      //         const SizedBox(width: 5),
                      //         Container(
                      //           height: 14,
                      //           padding: const EdgeInsets.symmetric(horizontal: 6),
                      //           alignment: Alignment.center,
                      //           decoration: BoxDecoration(
                      //             color: Colors.blue.shade300,
                      //             borderRadius: BorderRadius.circular(3),
                      //           ),
                      //           child: Text(
                      //             "\$${unitPrice.toStringAsFixed(2)}/lb",
                      //             style: const TextStyle(
                      //               fontSize: 8,
                      //               color: Colors.white,
                      //               fontWeight: FontWeight.bold,
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),

                      /// ROW 2 — BADGES (existing)
                      if (isEbtEligible ||
                          isVariant ||
                          hasAutoDiscount ||
                          isComboDiscount ||
                          isMultipackDiscount)
                        SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              if (isEbtEligible)
                                Container(
                                  height: 14,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    "EBT",
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isVariant) ...[
                                const SizedBox(width: 5),
                                SvgPicture.asset(
                                  SvgUtils.variationIcon,
                                  height: 8,
                                  width: 8,
                                ),
                              ],
                              if (hasAutoDiscount) ...[
                                const SizedBox(width: 5),
                                _discountBadge(
                                  "Autodiscount",
                                  Colors.red,
                                  amount: autoDiscount,
                                ),
                              ],
                              if (isComboDiscount) ...[
                                const SizedBox(width: 5),
                                _discountBadge(
                                  "combo discount",
                                  Colors.orange,
                                  amount: comboDiscount + mixMatchDiscount,
                                ),
                              ],
                              if (isMultipackDiscount) ...[
                                const SizedBox(width: 5),
                                _discountBadge(
                                  "Multipack",
                                  Colors.blue,
                                  amount: multipackDiscount,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                /// RIGHT PRICE COLUMN
                SizedBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// FINAL PRICE
                      SizedBox(
                        height: 16,
                        child: Text(
                          isCoupon || isPayout
                              ? "-${TextConstants.currencySymbol}${originalTotal.abs().toStringAsFixed(2)}"
                              : isWeightedItem
                              ? "${TextConstants.currencySymbol}${(unitPrice * weightQty).toStringAsFixed(2)}"
                              : "${TextConstants.currencySymbol}${finalItemTotal.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: isCoupon || isPayout
                                ? Colors.red
                                : themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ),
                      ),

                      /// STRIKED ORIGINAL
                      SizedBox(
                        height: 12,
                        child: ((hasAutoDiscount ||
                            isComboDiscount ||
                            isMultipackDiscount) &&
                            !isPayoutOrCoupon)
                            ? Text(
                          "${TextConstants.currencySymbol}${originalTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.0,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        /// DIVIDER
        Divider(
          height: 1,
          thickness: 0.8,
          color: themeHelper.themeMode == ThemeMode.dark
              ? Colors.black26
              : Colors.grey.shade300,
        ),
      ],
    );
  }

  /// 🔹 Reusable badge widget
  /// 🔹 Reusable badge widget
  Widget _discountBadge(String text, Color color, {double? amount}) {
    final double? displayAmount =
    (amount != null && amount > 0) ? amount : null;
    return Text(
      displayAmount == null
          ? text
          : '$text  -${TextConstants.currencySymbol}${displayAmount.toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: color, // ✅ text color only
      ),
    );
  }

  FontWeight labelFontWeight = FontWeight.w500;
  FontWeight amountFontWeight = FontWeight.w600;

  Widget _buildOrderCalculation(String label, String amount,
      {bool isTotal = false, bool isDiscount = false}) {
    // //Build #1.0.34: Update the amount based on the label
    final themeHelper = Provider.of<ThemeNotifier>(context);
    if (label == TextConstants.tenderAmount) {
      amount =
      '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}';
    } else if (label == TextConstants.change) {
      amount =
      '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}';
    } else if (label == TextConstants.total) {
      amount =
      '${TextConstants.currencySymbol}${(grossTotal - discount).toStringAsFixed(2)}'; // Adjust total with discount
    } else if (label == TextConstants.payByCash) {
      amount = '${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}';
    } else if (label == TextConstants.payByOther) {
      amount =
      '${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}';
    } else if (label == TextConstants.discountText) {
      amount =
      '-${TextConstants.currencySymbol}${discount.abs().toStringAsFixed(2)}'; // Display discount from DB
    // } else if (label == TextConstants.netPayable) {
    //   amount =
    //   '${TextConstants.currencySymbol}${(computedNetPayable - redeemedValue).clamp(0.0, double.infinity).toStringAsFixed(2)}';
    // }

      } else if (label == TextConstants.netPayable) {
      amount = _formatNetPayable(computedNetPayable - redeemedValue);
    }

    // Determine colors and icons based on label
    Color labelColor = themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.textDark
        : (isTotal ? Colors.black87 : Colors.grey[700]!);
    Color amountColor = themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.textDark
        : (isTotal ? Colors.black87 : Colors.grey[800]!);
    Widget? leadingIcon;

    //Raghu--**
    // ---------------- Merchant Discount----------------
    if (isTotal) {
      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.textDark
          : Colors.black87;
    } else if (label == TextConstants.discountText || isDiscount) {
      labelColor = const Color.fromARGB(255, 53, 195, 60)!;
      amountColor = Colors.green[600]!;
    } else if (label.startsWith(TextConstants.merchantDiscount)) {
      labelColor = Colors.blue[600]!;
      amountColor = Colors.blue[600]!;
    }
    //Raghu--*

    // ---------------- CASHBACK ( #55CBCD ) ----------------
    else if (label == TextConstants.cashbackFee ||
        label.toLowerCase().contains("cashback")) {
      labelColor = const Color(0xFF55CBCD);
      amountColor = const Color(0xFF55CBCD);
      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update your asset name if needed
        colorFilter: const ColorFilter.mode(Color(0xFF55CBCD), BlendMode.srcIn),
      );
    }

// ---------------- SERVICE CHARGE ( #0A122D ) ----------------
    else if (label == TextConstants.servicecharges ||
        label.toLowerCase().contains("service")) {
      labelColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF) // White for dark mode
          : const Color(0xFF0A122D); // Dark blue for light mode

      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF) // White in dark mode
          : const Color(0xFF0A122D); // Dark blue in light mode

      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update asset name
        colorFilter: const ColorFilter.mode(Color(0xFF0A122D), BlendMode.srcIn),
      );
    }
    // ---------------- NET TOTAL ( #373535 ) ----------------
    else if (label == TextConstants.NetTotal ||
        label.toLowerCase().contains("net total")) {
      labelColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF) // White in dark mode
          : const Color(0xFF373535); // Dark grey in light mode

      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF) // White in dark mode
          : const Color(0xFF373535); // Dark blue in light mode

      // Make NET TOTAL bold
      labelFontWeight = FontWeight.w900;
      amountFontWeight = FontWeight.w900;

      leadingIcon = SvgPicture.asset(
        'assets/svg/net_total.svg',
        colorFilter: const ColorFilter.mode(Color(0xFF373535), BlendMode.srcIn),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
          vertical: ResponsiveLayout.getPadding(
              2)), //ResponsiveLayout.getResponsiveMargin(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
              ],

              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  fontSize: ResponsiveLayout.getFontSize(isTotal ? 14 : 12),
                  color: labelColor,
                ),
              ),
              // ---------------- DELETE ICON FOR DISCOUNT ----------------
              if ((label == TextConstants.discountText || isDiscount) &&
                  discount.abs() > 0 &&
                  redeemedValue == 0)
                GestureDetector(
                  onTap: isPaymentStarted
                      ? null
                      : () async => await _removeAppliedCoupon(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.delete_forever,
                      color: isPaymentStarted ? Colors.grey : Colors.red,
                      size: 20,
                    ),
                  ),
                ),

              if (label == "Redeemed Amount" && redeemedValue > 0)
                GestureDetector(
                  onTap: isPaymentStarted
                      ? null
                      : () async {
                    await _removeRedeemedAmount();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.delete_forever,
                      color: isPaymentStarted ? Colors.grey : Colors.red,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  fontSize: ResponsiveLayout.getFontSize(isTotal ? 14 : 12),
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> showRedeemSummary(double redeemedAmount) async {
    if (redeemedAmount <= 0) {
      print("❌ Redeem: Invalid amount $redeemedAmount");
      return;
    }

    print(
        "🔄 Redeem Requested: $redeemedAmount | Current computedNetPayable: $computedNetPayable | Tendered: $tenderAmount");

    final double availableBalance =
    (computedNetPayable - tenderAmount).clamp(0.0, double.infinity);
    final double actualRedeem = redeemedAmount.clamp(0.0, availableBalance);

    setState(() {
      redeemedValue = actualRedeem;
      isRedeemAppliedFromApi = true;

      // 🔥 CORE CALCULATION - Apply redeem
      NetTotal = grossTotal + discount + merchantDiscount - actualRedeem;
      computedNetPayable = NetTotal + tax + cashbackFee;
      orderTotal = computedNetPayable;

      balanceAmount =
          (computedNetPayable - tenderAmount).clamp(0.0, double.infinity);

      // Reduce EBT if needed
      if (ebtTotal > 0) {
        ebtTotal = (ebtTotal - (redeemedAmount - actualRedeem))
            .clamp(0.0, double.infinity);
      }
    });

    // Persist to Hive
    try {
      final box = StorageProvider.offlineOrders;
      final key = (orderId ?? widget.offlineOrderId ?? 0).toString();

      if (await box.containsKey(key)) {
        final order = Map<String, dynamic>.from(await box.get(key));
        order['redeemed_value'] = actualRedeem;
        order['net_payable'] = computedNetPayable;
        order['balance_amount'] = balanceAmount;
        order['NetTotal'] = NetTotal; // extra safety
        order['computedNetPayable'] = computedNetPayable;
        await box.put(key, order);
        print("💾 Redeem successfully saved to Hive → $actualRedeem");
      }
    } catch (e) {
      print("⚠️ Failed to save redeem to Hive: $e");
    }
    unawaited(_syncCfdFromOrderSummary());

    print("✅ REDEEM APPLIED SUCCESSFULLY!");
    print("   Redeemed     : -${actualRedeem.toStringAsFixed(2)}");
    print("   New NetTotal : ${NetTotal.toStringAsFixed(2)}");
    print("   New Payable  : ${computedNetPayable.toStringAsFixed(2)}");
    print("   New Balance  : ${balanceAmount.toStringAsFixed(2)}");

    // Force refresh UI
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _removeRedeemedAmount() async {
    // 🔴 Contact is mandatory
    if (mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Customer contact not found."),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final String contact = mobileController.text.trim();

    // =====================================
// GET WOO ORDER ID FROM HIVE
// =====================================
    final offlineBox = StorageProvider.offlineOrders;

    final localKey = widget.offlineOrderId?.toString();

    if (localKey == null) {
      throw Exception("Offline order not found");
    }

    final existing = await offlineBox.get(localKey);

    if (existing == null) {
      throw Exception("Order data missing");
    }

    final offlineOrder = Map<String, dynamic>.from(
      existing is Map ? existing : {},
    );

// 🔥 GET WOO ORDER ID
    final int order = int.tryParse(
      offlineOrder["wooOrderId"]?.toString() ?? "0",
    ) ??
        0;

    if (order == 0) {
      throw Exception("Woo Order ID missing");
    }

    print("🟢 USING WOO ORDER ID: $order");

    setState(() => isSummaryLoading = true);

    try {
      // =====================================
      // API CALL
      // =====================================
      final rawRes = await OrderRepository().removeLoyaltyPoints(
        orderId: order,
        contact: contact,
      );

      // =====================================
      // SAFE RESPONSE
      // =====================================
      final result = rawRes is String ? jsonDecode(rawRes) : rawRes;

      print("🟢 REMOVE RESPONSE: $result");

      if (result["success"] != true) {
        throw Exception(
          result["message"] ?? "Unable to remove points",
        );
      }

      final data = result["data"] ?? {};

      // =====================================
      // API VALUES
      // =====================================
      final double updatedOrderTotal = double.tryParse(
        data["order_total"]?.toString() ?? "0",
      ) ??
          widget.netPayable;
      final int updatedPoints = int.tryParse(
        data["available_points"]?.toString() ?? "0",
      ) ??
          availablePoints;

// UPDATE UI
      setState(() {
        redeemedValue = 0;
        isRedeemAppliedFromApi = false;
        isRedeemActive = false;
        loyaltyData = null;
        availablePoints = updatedPoints;
        computedNetPayable = updatedOrderTotal;
        balanceAmount = updatedOrderTotal - tenderAmount;
      });

// clear hive first
      // clear hive
      await removeOfflineOrderRedeem(localKey);

      // FIX: removeOfflineOrderRedeem() only strips redeemed_value/points keys;
      // it doesn't touch available_points. Re-persist the latest available
      // points + contact right after, so subsequent
      // CustomerDisplayHelper.updateCustomerDisplay() calls (e.g. triggered by
      // applying/removing a coupon) don't show 0 available points.
      try {
        final rawLatest = await offlineBox.get(localKey);
        if (rawLatest is Map) {
          final latestOrder = Map<String, dynamic>.from(rawLatest);
          latestOrder["loyaltyContact"] = contact;
          latestOrder["available_points"] = updatedPoints;
          await offlineBox.put(localKey, latestOrder);
          print("💾 [Loyalty] Persisted available_points=$updatedPoints to Hive for order $localKey");
        }
      } catch (e) {
        print("⚠️ [Loyalty] Failed to persist available_points to Hive: $e");
      }

// tell android immediately
      await customerDisplayChannel.invokeMethod(
        "customerDisplayResult",
        {
          "success": true,
          "points": updatedPoints,
          "redeemedAmount": 0.0,
          "removeRedeem": true,
        },
      );
      unawaited(_syncCfdFromOrderSummary());

// then refresh full display
//       await CustomerDisplayHelper.updateCustomerDisplay(
//         widget.offlineOrderId!,
//         summaryEnabled: true,
//       );
      // =====================================
      // SUCCESS MESSAGE
      // =====================================
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result["message"] ?? "Redeemed points removed successfully.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      print("🧹 Redeem removed successfully");
    } catch (e) {
      print("❌ Remove Loyalty Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll("Exception:", ""),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
              () => isSummaryLoading = false,
        );
      }
    }
  }

  String _getPaymentHeader() {
    switch (selectedPaymentMethod) {
      case TextConstants.cash:
        return TextConstants.cashPayment;

      case TextConstants.card:
        return TextConstants.cardPayment;

      case TextConstants.wallet:
        return TextConstants.walletPayment;

      case TextConstants.ebtText:
        return TextConstants.ebtPayment;

      default:
        return TextConstants.cashPayment;
    }
  }

  void _resetAmount() {
    _rawAmount = 0;
    amountController.text = '${TextConstants.currencySymbol}0.00';
    _amountErrorText = null;
    _isAmountEntered = false;
  }

  Widget _buildPaymentSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateBalanceFromPaymentHistory();
    });

    // ============================================
    // ⭐ PAYMENT PROGRESSION DISPLAY
    // ============================================
    // print("\n" + "📊" * 60);
    // print("📊 PAYMENT PROGRESSION - ORDER #$orderId");
    // print("📊" * 60);
    // print("💰 INITIAL NET PAYABLE: \$${computedNetPayable.toStringAsFixed(2)}");
    // print("💵 TOTAL TENDERED: \$${tenderAmount.toStringAsFixed(2)}");
    // print("📉 BALANCE REDUCED BY: \$${(computedNetPayable - balanceAmount).toStringAsFixed(2)}");
    // print("🔢 PAYMENTS MADE: ${_lastPaymentDetails?['paymentNumber'] ?? 0}");
    //
    // if (_lastPaymentDetails != null) {
    //   print("📈 LAST PAYMENT (#${_lastPaymentDetails!['paymentNumber']}):");
    //   print("   → Method: ${_lastPaymentDetails!['method']}");
    //   print("   → Amount: \$${_lastPaymentDetails!['amount']?.toStringAsFixed(2)}");
    //   print("   → Previous Balance: \$${_lastPaymentDetails!['previousBalance']?.toStringAsFixed(2)}");
    // }
    //
    // print("🎯 CURRENT STATUS:");
    // print("   → Balance Amount: \$${balanceAmount.toStringAsFixed(2)}");
    // print("   → Current Payment Remaining: ${_currentPaymentRemainingBalance != null ? '\$${_currentPaymentRemainingBalance!.toStringAsFixed(2)}' : 'None (Payment Complete)'}");
    // print("   → Payment Methods Used:");
    // print("      • Cash: \$${payByCash.toStringAsFixed(2)}");
    // print("      • Card: \$${payByCard.toStringAsFixed(2)}");
    // print("      • EBT: \$${payByEbt.toStringAsFixed(2)}");
    // print("      • Other: \$${payByOther.toStringAsFixed(2)}");
    // print("📊" * 60 + "\n");

    // Log payment history from database
    _printPaymentHistorySummary();

    final themeHelper = Provider.of<ThemeNotifier>(context);
    bool hasEbtItem =
    orderItems.any((item) => _orderSummaryLineEbtEligible(item));
    final bool hasOnlyCashbackOrPayoutItems = orderItems.isNotEmpty &&
        orderItems.every((item) {
          final type = (item['item_type'] ?? item['type'] ?? '')
              .toString()
              .toLowerCase();

          return type == 'cashback' || type == 'payout';
        });
    return Container(
      // Remove the fixed height constraint to let it match the left container
      margin: EdgeInsets.only(
        bottom: ResponsiveLayout.getPadding(0),
        right: ResponsiveLayout.getPadding(10),
        top: ResponsiveLayout.getPadding(2),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ResponsiveLayout.getRadius(10)),
          topRight: Radius.circular(ResponsiveLayout.getRadius(10)),
          bottomLeft: Radius.circular(ResponsiveLayout.getRadius(0)),
          bottomRight: Radius.circular(ResponsiveLayout.getRadius(0)),
        ),
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground
            : Color(0xFFFFFFFF),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: ResponsiveLayout.getPadding(18),
          right: ResponsiveLayout.getPadding(18),
          top: ResponsiveLayout.getPadding(15),
          bottom: ResponsiveLayout.getPadding(18), // Add bottom padding
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment:
          CrossAxisAlignment.start, // Changed to start for better alignment
          children: [
            Expanded(
              flex: 3,
              child: Column(
                // Remove SingleChildScrollView to avoid height issues
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                MainAxisAlignment.start, // Changed from spaceEvenly
                children: [
                  SizedBox(height: ResponsiveLayout.getHeight(6)),

                  // Payment methods section
                  Expanded(
                    // Make this expand to fill available space
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cash payment section - make it flexible
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                // Make the payment container expand to fill space
                                child: Container(
                                  width: double.infinity, // Take full width
                                  padding: EdgeInsets.only(
                                    left: ResponsiveLayout.getPadding(16),
                                    right: ResponsiveLayout.getPadding(16),
                                    top: ResponsiveLayout.getPadding(0),
                                    bottom: ResponsiveLayout.getPadding(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    themeHelper.themeMode == ThemeMode.dark
                                        ? Color(0xFF1F1D2B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveLayout.getRadius(8)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height:
                                            ResponsiveLayout.getHeight(60),
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                              ResponsiveLayout.getPadding(
                                                  16),
                                            ),
                                            decoration: BoxDecoration(
                                              color: themeHelper.themeMode ==
                                                  ThemeMode.dark
                                                  ? const Color(0xFF40424F)
                                                  : const Color(0xFFF9FBFF),
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x22000000),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                /// 🔵 LABEL
                                                Text(
                                                  "Tender Amount :",
                                                  style: TextStyle(
                                                    fontSize: ResponsiveLayout
                                                        .getFontSize(18),
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                    themeHelper.themeMode ==
                                                        ThemeMode.dark
                                                        ? Colors.white
                                                        : const Color(
                                                        0xFF0D47A1),
                                                  ),
                                                ),

                                                const SizedBox(width: 16),

                                                /// 🔹 AMOUNT FIELD
                                                Expanded(
                                                  child: Container(
                                                    height: ResponsiveLayout
                                                        .getHeight(44),
                                                    padding:
                                                    EdgeInsets.symmetric(
                                                      horizontal:
                                                      ResponsiveLayout
                                                          .getPadding(12),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: themeHelper
                                                          .themeMode ==
                                                          ThemeMode.dark
                                                          ? const Color(
                                                          0xFF1F1D2B)
                                                          : Colors.white,
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                      border: Border.all(
                                                        color: _amountErrorText !=
                                                            null
                                                            ? Colors.red
                                                            : themeHelper
                                                            .themeMode ==
                                                            ThemeMode
                                                                .dark
                                                            ? Colors.white24
                                                            : const Color(
                                                            0xFFB6C6E3),
                                                        width:
                                                        _amountErrorText !=
                                                            null
                                                            ? 1.5
                                                            : 1.0,
                                                      ),
                                                      boxShadow: [
                                                        if (themeHelper
                                                            .themeMode !=
                                                            ThemeMode.dark)
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                0.05),
                                                            blurRadius: 4,
                                                            offset:
                                                            const Offset(
                                                                0, 2),
                                                          ),
                                                      ],
                                                    ),
                                                    alignment:
                                                    Alignment.centerRight,
                                                    child: TextField(
                                                      controller:
                                                      amountController,
                                                      keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                      textInputAction:
                                                      TextInputAction.done,
                                                      enabled: true,
                                                      readOnly: true,
                                                      textAlign:
                                                      TextAlign.right,
                                                      autofocus: false,
                                                      cursorColor: themeHelper
                                                          .themeMode ==
                                                          ThemeMode.dark
                                                          ? Colors.white
                                                          : const Color(
                                                          0xFF1F1D2B),
                                                      decoration:
                                                      InputDecoration(
                                                        border:
                                                        InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                        EdgeInsets.zero,
                                                        hintText:
                                                        '${TextConstants.currencySymbol}0.00',
                                                        hintStyle: TextStyle(
                                                          color: themeHelper
                                                              .themeMode ==
                                                              ThemeMode.dark
                                                              ? Colors.white38
                                                              : Colors
                                                              .grey[400],
                                                          fontSize:
                                                          ResponsiveLayout
                                                              .getFontSize(
                                                              22),
                                                        ),

                                                        // errorText: _amountErrorText,
                                                        // errorStyle: TextStyle(
                                                        //   color: Colors.red,
                                                        //   fontSize: ResponsiveLayout.getFontSize(12),
                                                        // ),
                                                      ),
                                                      style: TextStyle(
                                                        fontSize:
                                                        ResponsiveLayout
                                                            .getFontSize(
                                                            22),
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color: themeHelper
                                                            .themeMode ==
                                                            ThemeMode.dark
                                                            ? const Color(
                                                            0xFFFFFFFF)
                                                            : const Color(
                                                            0xFF1F1D2B),
                                                      ),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .allow(RegExp(
                                                            r'^\d*\.?\d{0,2}')),
                                                      ],
                                                      onTap: () {
                                                        // Select all text when tapped (makes overwriting easy)
                                                        amountController
                                                            .selection =
                                                            TextSelection(
                                                              baseOffset: 0,
                                                              extentOffset:
                                                              amountController
                                                                  .text.length,
                                                            );
                                                      },
                                                      // ────────────────────────────────────────────────
                                                      // IMPORTANT: Detect real user typing
                                                      // ────────────────────────────────────────────────
                                                      onChanged: (value) {
                                                        // Mark that user is actively typing → prevent auto-fill later
                                                        _userManuallyEnteredAmount =
                                                        true;

                                                        // Optional: clean up pasted currency symbol
                                                        String clean = value
                                                            .replaceAll(
                                                            TextConstants
                                                                .currencySymbol,
                                                            '')
                                                            .trim();
                                                        if (clean != value) {
                                                          amountController
                                                              .value =
                                                              TextEditingValue(
                                                                text: clean,
                                                                selection: TextSelection
                                                                    .collapsed(
                                                                    offset: clean
                                                                        .length),
                                                              );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // /// 🔴 ERROR TEXT BELOW FIELD
                                          // if (computedNetPayable > 0 && _amountErrorText != null)
                                          //   Padding(
                                          //     padding: EdgeInsets.only(
                                          //       top: ResponsiveLayout.getPadding(4),
                                          //       left: ResponsiveLayout.getPadding(12),
                                          //     ),
                                          //     child: Text(
                                          //       _amountErrorText!,
                                          //       style: TextStyle(
                                          //         color: Colors.red,
                                          //         fontSize: ResponsiveLayout.getFontSize(12),
                                          //       ),
                                          //     ),
                                          //   ),
                                        ],
                                      ),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(8)),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(12)),

// NUM PAD - FIXED LOGIC
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // ✅ Display current payment remaining balance if available
                                            // if (_currentPaymentRemainingBalance != null && balanceAmount > 0)
                                            //   Container(
                                            //     margin: EdgeInsets.only(bottom: ResponsiveLayout.getHeight(8)),
                                            //     padding: EdgeInsets.symmetric(
                                            //       horizontal: ResponsiveLayout.getPadding(12),
                                            //       vertical: ResponsiveLayout.getPadding(6),
                                            //     ),
                                            //     decoration: BoxDecoration(
                                            //       color: themeHelper.themeMode == ThemeMode.dark
                                            //           ? Colors.orange.withOpacity(0.2)
                                            //           : Colors.orange.withOpacity(0.1),
                                            //       borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(6)),
                                            //       border: Border.all(
                                            //         color: Colors.orange.withOpacity(0.3),
                                            //         width: 1,
                                            //       ),
                                            //     ),
                                            //     child: Row(
                                            //       mainAxisAlignment: MainAxisAlignment.center,
                                            //       children: [
                                            //         Icon(
                                            //           Icons.info_outline,
                                            //           size: ResponsiveLayout.getIconSize(14),
                                            //           color: Colors.orange,
                                            //         ),
                                            //         // SizedBox(width: ResponsiveLayout.getWidth(6)),
                                            //         // Text(
                                            //         //   "Balance after last ${_lastPaymentDetails?['method'] ?? 'payment'}: ",
                                            //         //   style: TextStyle(
                                            //         //     fontSize: ResponsiveLayout.getFontSize(12),
                                            //         //     color: Colors.orange,
                                            //         //   ),
                                            //         // ),
                                            //         Text(
                                            //           '${TextConstants.currencySymbol}${_currentPaymentRemainingBalance!.toStringAsFixed(2)}',
                                            //           style: TextStyle(
                                            //             fontSize: ResponsiveLayout.getFontSize(12),
                                            //             fontWeight: FontWeight.bold,
                                            //             color: Colors.orange,
                                            //           ),
                                            //         ),
                                            //       ],
                                            //     ),
                                            //   ),

                                            // PaymentNumPad with modified logic
                                            Expanded(
                                              child: PaymentNumPad(
                                                numPadType:
                                                CustomTypeNumPad.payment,
                                                isDarkTheme:
                                                themeHelper.themeMode ==
                                                    ThemeMode.dark,
                                                getPaidAmount: () =>
                                                amountController.text,
                                                balanceAmount:
                                                selectedPaymentMethod ==
                                                    TextConstants
                                                        .ebtText
                                                    ? min(
                                                  ebtTotal,
                                                  _currentPaymentRemainingBalance ??
                                                      balanceAmount,
                                                )
                                                    : (_currentPaymentRemainingBalance ??
                                                    balanceAmount),
                                                onDigitPressed: (value) {
                                                  _userManuallyEnteredAmount =
                                                  true; // User touched → block future auto-fill

                                                  int digit = value == '00'
                                                      ? 0
                                                      : int.tryParse(value) ??
                                                      0;

                                                  int newAmount = value == '00'
                                                      ? _rawAmount * 100
                                                      : _rawAmount * 10 + digit;

                                                  int maxAmount;
                                                  double effectiveBalance =
                                                      _currentPaymentRemainingBalance ??
                                                          balanceAmount;

                                                  if (selectedPaymentMethod ==
                                                      TextConstants.ebtText) {
                                                    maxAmount = (min(ebtTotal,
                                                        effectiveBalance) *
                                                        100)
                                                        .toInt();
                                                  } else if (selectedPaymentMethod ==
                                                      TextConstants.card) {
                                                    maxAmount =
                                                        (effectiveBalance * 100)
                                                            .toInt();
                                                  } else {
                                                    maxAmount = 999999999;
                                                  }

                                                  if (newAmount > maxAmount)
                                                    return;

                                                  _rawAmount = newAmount;
                                                  double displayValue =
                                                      _rawAmount / 100.0;
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}${displayValue.toStringAsFixed(2)}';

                                                  setState(() {
                                                    _isAmountEntered =
                                                        _rawAmount != 0;
                                                  });
                                                },
                                                onClearPressed: () {
                                                  _userManuallyEnteredAmount =
                                                  true;

                                                  _rawAmount = 0;
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}0.00';
                                                  _amountErrorText = null;

                                                  setState(() {
                                                    _isAmountEntered = false;
                                                  });
                                                },
                                                onDeletePressed: () {
                                                  _userManuallyEnteredAmount =
                                                  true;

                                                  _rawAmount = _rawAmount ~/ 10;
                                                  double displayValue =
                                                      _rawAmount / 100.0;
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}${displayValue.toStringAsFixed(2)}';

                                                  setState(() {
                                                    _isAmountEntered =
                                                        _rawAmount != 0;
                                                  });
                                                },
                                                onQuickAmountSelected:
                                                    (double selectedAmount) {
                                                  _userManuallyEnteredAmount =
                                                  true;

                                                  double amountToUse =
                                                      selectedAmount;

                                                  if (selectedPaymentMethod ==
                                                      TextConstants.ebtText) {
                                                    amountToUse = min(
                                                        selectedAmount,
                                                        ebtTotal);
                                                  }
                                                  // For cash/card/wallet → allow full selectedAmount (even > balance)

                                                  _rawAmount =
                                                      (amountToUse * 100)
                                                          .round();
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}${amountToUse.toStringAsFixed(2)}';

                                                  setState(() {
                                                    _amountErrorText = null;
                                                    _isAmountEntered =
                                                        _rawAmount > 0;
                                                  });

                                                  print(
                                                      "Quick selected → $amountToUse (user picked $selectedAmount)");
                                                },
                                                onPayPressed: () async {
                                                  String cleanAmount =
                                                  amountController.text
                                                      .replaceAll(
                                                      TextConstants
                                                          .currencySymbol,
                                                      '')
                                                      .trim();

                                                  double amount =
                                                      double.tryParse(
                                                          cleanAmount) ??
                                                          0.0;

                                                  double effectiveBalance =
                                                      _currentPaymentRemainingBalance ??
                                                          balanceAmount;

                                                  _amountErrorText = null;

                                                  // Calculations (your existing logic)
                                                  double previousBalance =
                                                      effectiveBalance;
                                                  double newBalance =
                                                  (effectiveBalance -
                                                      amount)
                                                      .clamp(0,
                                                      double.infinity);
                                                  double newTenderAmount =
                                                      tenderAmount + amount;
                                                  double newChange = 0.0;

                                                  if (amount >
                                                      effectiveBalance) {
                                                    newChange = amount -
                                                        effectiveBalance;
                                                    newBalance = 0.0;
                                                  }

                                                  // Update UI
                                                  setState(() {
                                                    balanceAmount = newBalance;
                                                    tenderAmount =
                                                        newTenderAmount;
                                                    changeAmount = newChange;

                                                    if (selectedPaymentMethod ==
                                                        TextConstants.cash) {
                                                      payByCash += amount;
                                                    } else if (selectedPaymentMethod ==
                                                        TextConstants.ebtText) {
                                                      payByEbt += amount;
                                                      ebtTotal = (ebtTotal -
                                                          amount)
                                                          .clamp(0,
                                                          double.infinity);
                                                    }

                                                    isPaymentStarted = true;

                                                    int newPaymentNumber =
                                                        (_lastPaymentDetails?[
                                                        'paymentNumber'] ??
                                                            0) +
                                                            1;

                                                    if (newBalance > 0) {
                                                      _currentPaymentRemainingBalance =
                                                          newBalance;
                                                      _lastPaymentDetails = {
                                                        'amount': amount,
                                                        'method':
                                                        selectedPaymentMethod,
                                                        'remainingBalance':
                                                        newBalance,
                                                        'previousBalance':
                                                        previousBalance,
                                                        'datetime': DateTime
                                                            .now()
                                                            .toIso8601String(),
                                                        'paymentNumber':
                                                        newPaymentNumber,
                                                        'totalPaid':
                                                        newTenderAmount,
                                                      };
                                                    } else {
                                                      _currentPaymentRemainingBalance =
                                                      null;
                                                      _lastPaymentDetails =
                                                      null;
                                                    }
                                                  });

                                                  // ────────────────────────────────────────────────
                                                  // CRITICAL CHANGE: RESET TO 0.00 — BUT DO NOT AUTO-FILL
                                                  // ────────────────────────────────────────────────
                                                  _rawAmount = 0;
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}0.00';
                                                  _isAmountEntered = false;

                                                  // DO NOT call _autoFillRemainingBalance() here anymore!
                                                  // Only reset — let user decide next amount

                                                  // Show dialogs (your existing logic)
                                                  if (newBalance > 0) {
                                                    _showPartialPaymentDialog(
                                                        context, amount);
                                                  } else {
                                                    _successPopupShown = true;
                                                    final box = StorageProvider
                                                        .offlineOrders;
                                                    final key = (orderId ?? 0)
                                                        .toString();
                                                    final boxData =
                                                    await box.get(key);
                                                    final cr = boxData is Map
                                                        ? (boxData as Map)[
                                                    "coupon_response"]
                                                        : null;
                                                    final couponResponse = cr
                                                    is Map
                                                        ? Map<String,
                                                        dynamic>.from(
                                                        cr as Map)
                                                        : <String, dynamic>{};

                                                    _showPaymentDialog(
                                                      context,
                                                      newTenderAmount,
                                                      changeAmount: newChange,
                                                      showChange: newChange > 0,
                                                      couponResponse:
                                                      couponResponse,
                                                    );
                                                  }

                                                  // Background API
                                                  _callCreatePaymentAPI(
                                                      skipPopup: true);
                                                },
                                                isLoading: isLoading,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveLayout.getWidth(16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right side - Payment mode selection
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // SizedBox(height: ResponsiveLayout.getHeight(3)),

                  SizedBox(height: ResponsiveLayout.getHeight(3)),

                  // Payment mode buttons - make flexible
                  Expanded(
                    // fit: FlexFit.loose,
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveLayout.getPadding(8)),
                      child: Column(
                        children: [
                          /// Net Payable
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 6, right: 6, bottom: 6),
                              decoration: BoxDecoration(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? const Color(0xFF091B34)
                                    : const Color(0xFFF4FCF7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                  top: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3EAE4C)),
                                  right: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3EAE4C)),
                                  bottom: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3EAE4C)),
                                  left: BorderSide.none,
                                ),
                              ),
                              child: _buildAmountDisplay(
                                TextConstants.netPayable,
                                _formatNetPayable(computedNetPayable - redeemedValue),
                                leftBarColor: const Color(0xFF3EAE4C),
                                amountColor: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black,
                                // Dynamic font size
                                labelFontSize: _hasEbtItemsInOrder ? 11 : 18,     // ← was ebtTotal > 0
                                amountFontSize: _hasEbtItemsInOrder ? 12 : 25,
                              ),
                            ),
                          ),

                          SizedBox(height: ResponsiveLayout.getHeight(10)),


                          /// Balance Amount - Extra Large & Bold when no EBT
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 6, right: 6, bottom: 6),
                              decoration: BoxDecoration(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? const Color(0xFF091B34)
                                    : (_currentPaymentRemainingBalance != null && _currentPaymentRemainingBalance! > 0)
                                    ? const Color(0xFFE6F3FF)
                                    : const Color(0xFFFCF4F4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                  top: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : (_currentPaymentRemainingBalance != null && _currentPaymentRemainingBalance! > 0) ? const Color(0xFF3B7DDD) : const Color(0xFFE85C43)),
                                  right: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : (_currentPaymentRemainingBalance != null && _currentPaymentRemainingBalance! > 0) ? const Color(0xFF3B7DDD) : const Color(0xFFE85C43)),
                                  bottom: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : (_currentPaymentRemainingBalance != null && _currentPaymentRemainingBalance! > 0) ? const Color(0xFF3B7DDD) : const Color(0xFFE85C43)),
                                  left: BorderSide.none,
                                ),
                              ),
                              child: _currentPaymentRemainingBalance != null && _currentPaymentRemainingBalance! > 0
                                  ? _buildPaymentAmountDisplay(
                                "Balance Amount",
                                '${TextConstants.currencySymbol}${_currentPaymentRemainingBalance!.toStringAsFixed(2)}',
                                leftBarColor: const Color(0xFF3B7DDD),
                                amountColor: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black,
                                isPaymentBalance: true,
                                labelFontSize: _hasEbtItemsInOrder ? 11 : 14,     // ← was ebtTotal > 0
                                amountFontSize: _hasEbtItemsInOrder ? 13 : 27,    // ← was ebtTotal > 0
                                amountFontWeight: FontWeight.w900,             // Extra Bold
                              )
                                  : _buildPaymentAmountDisplay(
                                TextConstants.balanceAmount,
                                balanceAmount < 0
                                    ? '-${TextConstants.currencySymbol}${balanceAmount.abs().toStringAsFixed(2)}'
                                    : '${TextConstants.currencySymbol}${balanceAmount.toStringAsFixed(2)}',
                                leftBarColor: const Color(0xFFE85C43),
                                amountColor: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black,
                                labelFontSize: _hasEbtItemsInOrder ? 11 : 14,     // ← was ebtTotal > 0
                                amountFontSize: _hasEbtItemsInOrder ? 13 : 27,          // Bigger
                                amountFontWeight: FontWeight.w900,                // Extra Bold
                              ),
                            ),
                          ),

                          if (ebtTotal > 0 && hasEbtItem) ...[
                            SizedBox(height: ResponsiveLayout.getHeight(10)),
                            /// EBT (smaller fonts when 3 items are shown)
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(top: 6, right: 6, bottom: 6),
                                decoration: BoxDecoration(
                                  color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFFF4F7FC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border(
                                    top: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3B7DDD)),
                                    right: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3B7DDD)),
                                    bottom: BorderSide(color: themeHelper.themeMode == ThemeMode.dark ? const Color(0xFF091B34) : const Color(0xFF3B7DDD)),
                                    left: BorderSide.none,
                                  ),
                                ),
                                child: _buildAmountDisplay(
                                  TextConstants.EBTAmount,
                                  (() {
                                    final double originalEbt = widget.ebtAmount;

                                    if (originalEbt <= 0) {
                                      return '${TextConstants.currencySymbol}${ebtTotal.toStringAsFixed(2)}';
                                    }

                                    final double originalNetPayable = widget.netPayable > 0
                                        ? widget.netPayable
                                        : (widget.grossTotal + widget.orderTax);

                                    if (originalNetPayable <= 0) {
                                      return '${TextConstants.currencySymbol}${ebtTotal.toStringAsFixed(2)}';
                                    }

                                    if ((computedNetPayable - originalNetPayable).abs() > 0.01) {
                                      final ratio = originalEbt / originalNetPayable;
                                      final proportionalEbt =
                                      (computedNetPayable * ratio).clamp(0.0, originalEbt);

                                      final displayEbt =
                                      (proportionalEbt - payByEbt).clamp(0.0, double.infinity);

                                      return '${TextConstants.currencySymbol}${displayEbt.toStringAsFixed(2)}';
                                    }

                                    return '${TextConstants.currencySymbol}${ebtTotal.toStringAsFixed(2)}';
                                  })(),
                                  leftBarColor: const Color(0xFF3B7DDD),
                                  amountColor: themeHelper.themeMode == ThemeMode.dark ? Colors.white : Colors.black,
                                  labelFontSize: 11,
                                  amountFontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveLayout.getHeight(10)),

                  // Payment options - make flexible
                  Expanded(
                    // flex: 2, // Give less space to payment options
                    child: Container(
                      width: double.infinity,
                      padding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? const Color(0xFF303136)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveLayout.getRadius(8),
                        ),
                        border: Border.all(
                          color: const Color(0x2E4C5F7D), // #4C5F7D2E
                          width: 1.5, // adjust as needed
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black12,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              /// ⭐ Redeem Points
                              _buildPaymentOptionButton(
                                TextConstants.redeemPoints,
                                "assets/redeem.png",
                                isActive: redeemedValue == 0 &&
                                    availablePoints > 0 &&
                                    isRedeemActive &&
                                    !isPaymentStarted &&
                                    !hasEbtItem &&
                                    !isOrderPending,
                                onTap: () async {
                                  final bool isInPartialSession =
                                      _currentPaymentRemainingBalance != null &&
                                          _currentPaymentRemainingBalance! > 0;

                                  if (isInPartialSession || discount > 0) {
                                    _showExitPaymentConfirmation(context);
                                    return;
                                  }

                                  // Direct back in all other cases
                                  // Navigator.of(context).pop();
                                  if (hasEbtItem) return; // block redeem

                                  if (!isRedeemActive) return;
                                  if (isOrderPending) {
                                    print("⛔ Redeem blocked: Order is pending");
                                    return;
                                  }

                                  // ⭐ Block redeem when partial payment has started
                                  if (isPaymentStarted) {
                                    print(
                                        "⛔ Redeem blocked: Payment already started");
                                    return;
                                  }

                                  print("🔍 Current State Before Action:");
                                  print("➡ redeemedValue: $redeemedValue");
                                  print("➡ availablePoints: $availablePoints");
                                  print("➡ isMobileValid: $isMobileValid");
                                  print("➡ isEmailValid: $isEmailValid");

                                  if (redeemedValue > 0) {
                                    print(
                                        "⛔ Redeem blocked: Already redeemedValue > 0");
                                    return;
                                  }

                                  if (availablePoints == 0) {
                                    print(
                                        "⛔ Redeem blocked: No availablePoints");
                                    return;
                                  }

                                  if (!isMobileValid && !isEmailValid) {
                                    print(
                                        "⛔ Invalid Contact: Neither mobile nor email valid");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Enter valid mobile number or email"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  print("📨 Opening RedeemPointsDialog...");
                                  final result = await showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => RedeemPointsDialog(
                                        apiData: loyaltyData!),
                                  );

                                  print("📨 Dialog Result: $result");

                                  if (result == null) {
                                    print(
                                        "⛔ Dialog closed manually (null result)");
                                    return;
                                  }

                                  // User removed redeem
                                  if (result["remove"] == true) {
                                    print("🗑 REMOVE REDEEM SELECTED");
                                    setState(() {
                                      redeemedValue = 0;
                                      computedNetPayable = NetTotal;
                                    });

                                    final String orderKey =
                                        widget.orderId?.toString() ??
                                            widget.offlineOrderId?.toString() ??
                                            "";

                                    print(
                                        "🗑 Removing redeem from Hive → OrderKey: $orderKey");

                                    if (orderKey.isNotEmpty) {
                                      await removeOfflineOrderRedeem(orderKey);
                                    }

                                    print("🧹 Redeem removed successfully.");
                                    return;
                                  }

                                  print("🟦 Processing API response...");

                                  final redeemApi =
                                  jsonDecode(result["apiResponse"]);
                                  print("📦 API Raw Response: $redeemApi");

                                  if (redeemApi == null) {
                                    print("❌ ERROR: Redeem API is null");
                                    return;
                                  }

                                  if (redeemApi["success"] != true) {
                                    print(
                                        "❌ API reported failure: ${redeemApi["message"]}");
                                    return;
                                  }

                                  final data = redeemApi["data"];
                                  print("📦 Parsed Data: $data");

                                  // Extract values
                                  final double newRedeemValue = double.tryParse(
                                      data["redeem_amount"].toString()) ??
                                      0.0;

                                  final int usedPoints = int.tryParse(
                                      data["redeem_points"].toString()) ??
                                      0;

                                  final int newAvailablePoints = int.tryParse(
                                      data["available_points"]
                                          .toString()) ??
                                      availablePoints;

                                  final double newBalanceAmount =
                                      double.tryParse(
                                          data["order_total"].toString()) ??
                                          computedNetPayable;

                                  print("🔢 Extracted API Values:");
                                  print("➡ newRedeemValue: $newRedeemValue");
                                  print("➡ usedPoints: $usedPoints");
                                  print(
                                      "➡ newAvailablePoints: $newAvailablePoints");
                                  print(
                                      "➡ newBalanceAmount: $newBalanceAmount");

                                  // Update UI
                                  setState(() {
                                    redeemedValue = newRedeemValue;
                                    availablePoints = newAvailablePoints;
                                    balanceAmount = newBalanceAmount;
                                    isRedeemAppliedFromApi = true;
                                  });

                                  print("🟩 UI Updated:");
                                  print("➡ redeemedValue: $redeemedValue");
                                  print("➡ availablePoints: $availablePoints");
                                  print("➡ balanceAmount: $balanceAmount");

                                  // Save to Hive
                                  final String orderKey =
                                      widget.orderId?.toString() ??
                                          widget.offlineOrderId?.toString() ??
                                          "";

                                  print(
                                      "💾 Saving redeem to Hive → OrderKey: $orderKey");

                                  if (orderKey.isNotEmpty) {
                                    await updateOfflineOrderRedeem(
                                      orderKey,
                                      newRedeemValue,
                                      usedPoints,
                                      newAvailablePoints,
                                    );
                                  }

                                  print("💾 Redeem successfully saved to Hive");
                                  print(
                                      "======== 🟩 REDEEM PROCESS COMPLETED 🟩 ========");
                                },
                              ),

                              const SizedBox(height: 10),
                              _buildCouponButton(
                                TextConstants.generatecoupon,
                                "assets/coupon.png",
                                isActive: redeemedValue == 0 &&
                                    !isPaymentStarted &&
                                    !isOrderPending &&
                                    !hasOnlyCashbackOrPayoutItems &&
                                    computedNetPayable > 0, // ✅ keep this
                                onTap: () {
                                  if (redeemedValue > 0 ||
                                      isPaymentStarted ||
                                      isOrderPending ||
                                      hasOnlyCashbackOrPayoutItems ||
                                      computedNetPayable <= 0) {
                                    return;
                                  }

                                  _openCouponPopup();
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildRedeemCouponButton(
                                TextConstants.Issuecoupon,
                                "assets/coupon.png",
                                isActive:
                                !(offlineOrder?["coupon_applied"] == true ||
                                    isCouponActive ||
                                    computedNetPayable < 0),
                                onTap: () async {
                                  if (offlineOrder == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text("No offline order found")),
                                    );
                                    return;
                                  }
                                  await _syncAndShowCouponPopup();
                                  // Issue Coupon should not mark coupon as applied
                                  // to the current order.
                                  setState(() {
                                    isCouponActive = false;
                                  });
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isGenerateCouponActive = false;

  // Future<bool> _syncAndShowCouponPopup() async {
  //   if (_isProcessing) return false;
  //
  //   setState(() => _isProcessing = true);
  //   bool loaderOpen = true;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => const Center(child: CircularProgressIndicator()),
  //   );
  //
  //   try {
  //     final response = await OrderRepository().CouponApply(offlineOrder!);
  //
  //     if (loaderOpen) {
  //       Navigator.of(context).pop();
  //       loaderOpen = false;
  //     }
  //
  //     if (response == null || response is! Map<String, dynamic>) {
  //       _showErrorPopup("Coupon applied but no response data received.");
  //       return false;
  //     }
  //
  //     final coupons = response["coupons"] as List? ?? [];
  //     if (coupons.isEmpty) {
  //       _showErrorPopup("Coupon applied, but no coupon details returned.");
  //       return false;
  //     }
  //
  //     final coupon = coupons.first;
  //     final double discountAmount =
  //         (coupon["amount"] as num?)?.toDouble() ?? 0.0;
  //     final String couponCode = coupon["code"]?.toString() ?? "";
  //
  //     // Optional: Early minimum amount check (if backend provides it)
  //     final double minAmount =
  //         (coupon["min_amount"] as num?)?.toDouble() ?? 0.0;
  //     final double currentSubtotal = grossTotal; // or computed subtotal
  //
  //     if (minAmount > 0 && currentSubtotal < minAmount) {
  //       _showErrorPopup(
  //           "Coupon '$couponCode' requires minimum order of \$$minAmount");
  //       return false;
  //     }
  //
  //     // Update UI temporarily
  //     setState(() {
  //       couponValue = discountAmount;
  //       ebtTotal = 0.0;
  //       cashbackFee = 0.0;
  //       isGenerateCouponActive = true;
  //     });
  //
  //     // Show confirmation popup
  //     final bool confirmed = await _showCouponResponsePopup(response);
  //
  //     if (!confirmed) {
  //       debugPrint("🔵 Coupon popup closed with X – not saving to Hive");
  //       setState(() => isGenerateCouponActive = false);
  //       return false;
  //     }
  //
  //     // === Save to Hive only after user confirmation ===
  //     final box = StorageProvider.offlineOrders;
  //     final String key = offlineOrder?['id']?.toString() ??
  //         offlineOrder?['order_id']?.toString() ??
  //         offlineOrder?['local_order_id']?.toString() ??
  //         "";
  //
  //     if (key.isEmpty) return true;
  //
  //     final hasKey = await box.containsKey(key);
  //     final raw = hasKey ? await box.get(key) : null;
  //     final Map<String, dynamic> existing = raw is Map
  //         ? Map<String, dynamic>.from(raw)
  //         : Map<String, dynamic>.from(offlineOrder!);
  //
  //     // Prepare issued coupons
  //     final List<Map<String, dynamic>> issueCoupons = [];
  //     for (final c in response["coupons"] as List? ?? []) {
  //       if (c is! Map) continue;
  //       final m = Map<String, dynamic>.from(c);
  //       if (m["generate_type"] != true) {
  //         m["generate_type"] = false;
  //       }
  //       issueCoupons.add(m);
  //     }
  //
  //     // Keep previous redeemed coupons
  //     final prevCoupons = <Map<String, dynamic>>[];
  //     final prevCr = existing["coupon_response"];
  //     if (prevCr is Map && prevCr["coupons"] is List) {
  //       for (final x in prevCr["coupons"] as List) {
  //         if (x is Map) prevCoupons.add(Map<String, dynamic>.from(x));
  //       }
  //     }
  //
  //     final keptRedeems =
  //     prevCoupons.where((c) => _couponHiveEntryIsRedeem(c)).toList();
  //
  //     final mergedResponse = Map<String, dynamic>.from(response);
  //     mergedResponse["coupons"] = [...issueCoupons, ...keptRedeems];
  //
  //     existing["coupon_response"] = mergedResponse;
  //     existing["coupon_applied"] = true;
  //     existing["coupon_applied_at"] = DateTime.now().toIso8601String();
  //     existing["coupon_amount"] = discountAmount;
  //
  //     await box.put(key, existing);
  //     offlineOrder = existing;
  //
  //     debugPrint("✅ Generated Coupon saved in Hive for order $key");
  //     return true;
  //   } catch (e) {
  //     if (loaderOpen) {
  //       Navigator.of(context).pop();
  //       loaderOpen = false;
  //     }
  //     _showErrorPopup("Something went wrong while applying coupon.");
  //     debugPrint("❌ Coupon popup error: $e");
  //     return false;
  //   } finally {
  //     setState(() => _isProcessing = false);
  //   }
  // }

  ///above code was working code
  ///

  Future<bool> _syncAndShowCouponPopup() async {
    if (_isProcessing) return false;

    setState(() => _isProcessing = true);
    bool loaderOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ✅ CRITICAL FIX: Save Pay Later user to offlineOrder and Hive BEFORE sync
      if (offlineOrder != null && _selectedPayLaterUser != null) {
        // Add to offlineOrder map
        offlineOrder!['selectedPayLaterUser'] = Map<String, dynamic>.from(_selectedPayLaterUser!);
        offlineOrder!['is_pay_later_order'] = true;

        debugPrint("✅ Pay Later user added to offlineOrder: ${_selectedPayLaterUser!['name']} (ID: ${_selectedPayLaterUser!['user_id']})");

        // ✅ CRITICAL: Save to Hive immediately so the sync function can read it
        final box = StorageProvider.offlineOrders;
        final String key = offlineOrder?['id']?.toString() ??
            offlineOrder?['order_id']?.toString() ??
            offlineOrder?['local_order_id']?.toString() ??
            widget.offlineOrderId?.toString() ??
            "";

        if (key.isNotEmpty) {
          await box.put(key, offlineOrder);
          debugPrint("✅ Pay Later user saved to Hive before sync: ${_selectedPayLaterUser!['name']}");

          // ✅ Verify it was saved
          final verify = await box.get(key);
          if (verify is Map) {
            final savedUser = verify['selectedPayLaterUser'];
            if (savedUser is Map) {
              debugPrint("✅ Verification: Pay Later user found in Hive: ${savedUser['name']} (ID: ${savedUser['user_id']})");
            } else {
              debugPrint("⚠️ Verification: Pay Later user NOT found in Hive after save!");
            }
          }
        } else {
          debugPrint("⚠️ Could not save to Hive - key is empty");
        }
      } else {
        debugPrint("⚠️ No Pay Later user selected or offlineOrder is null");
      }

      // Now call the repository with the updated offlineOrder
      final response = await OrderRepository().CouponApply(offlineOrder!);

      if (loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }

      if (response == null || response is! Map<String, dynamic>) {
        _showErrorPopup("Coupon applied but no response data received.");
        return false;
      }

      final coupons = response["coupons"] as List? ?? [];
      if (coupons.isEmpty) {
        _showErrorPopup("Coupon applied, but no coupon details returned.");
        return false;
      }

      final coupon = coupons.first;
      final double discountAmount =
          (coupon["amount"] as num?)?.toDouble() ?? 0.0;
      final String couponCode = coupon["code"]?.toString() ?? "";

      final double minAmount =
          (coupon["min_amount"] as num?)?.toDouble() ?? 0.0;
      final double currentSubtotal = grossTotal;

      if (minAmount > 0 && currentSubtotal < minAmount) {
        _showErrorPopup(
            "Coupon '$couponCode' requires minimum order of \$$minAmount");
        return false;
      }

      setState(() {
        couponValue = discountAmount;
        ebtTotal = 0.0;
        cashbackFee = 0.0;
        isGenerateCouponActive = true;
      });

      final bool confirmed = await _showCouponResponsePopup(response);

      if (!confirmed) {
        debugPrint("🔵 Coupon popup closed with X – not saving to Hive");
        setState(() => isGenerateCouponActive = false);
        return false;
      }

      final box = StorageProvider.offlineOrders;
      final String key = offlineOrder?['id']?.toString() ??
          offlineOrder?['order_id']?.toString() ??
          offlineOrder?['local_order_id']?.toString() ??
          widget.offlineOrderId?.toString() ??
          "";

      if (key.isEmpty) return true;

      final hasKey = await box.containsKey(key);
      final raw = hasKey ? await box.get(key) : null;
      final Map<String, dynamic> existing = raw is Map
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(offlineOrder!);

      // ✅ PRESERVE PAY LATER USER DATA IN HIVE
      if (_selectedPayLaterUser != null) {
        existing['selectedPayLaterUser'] = Map<String, dynamic>.from(_selectedPayLaterUser!);
        existing['is_pay_later_order'] = true;
        debugPrint("✅ Pay Later user preserved in Hive: ${_selectedPayLaterUser!['name']}");
      }

      final List<Map<String, dynamic>> issueCoupons = [];
      for (final c in response["coupons"] as List? ?? []) {
        if (c is! Map) continue;
        final m = Map<String, dynamic>.from(c);
        if (m["generate_type"] != true) {
          m["generate_type"] = false;
        }
        issueCoupons.add(m);
      }

      final prevCoupons = <Map<String, dynamic>>[];
      final prevCr = existing["coupon_response"];
      if (prevCr is Map && prevCr["coupons"] is List) {
        for (final x in prevCr["coupons"] as List) {
          if (x is Map) prevCoupons.add(Map<String, dynamic>.from(x));
        }
      }

      final keptRedeems =
      prevCoupons.where((c) => _couponHiveEntryIsRedeem(c)).toList();

      final mergedResponse = Map<String, dynamic>.from(response);
      mergedResponse["coupons"] = [...issueCoupons, ...keptRedeems];

      existing["coupon_response"] = mergedResponse;
      existing["coupon_applied"] = true;
      existing["coupon_applied_at"] = DateTime.now().toIso8601String();
      existing["coupon_amount"] = discountAmount;

      await box.put(key, existing);
      offlineOrder = existing;

      debugPrint("✅ Coupon saved in Hive for order $key");
      if (_selectedPayLaterUser != null) {
        debugPrint("✅ Pay Later user data verified in Hive: ${_selectedPayLaterUser!['name']} (ID: ${_selectedPayLaterUser!['user_id']})");
      }
      return true;
    } catch (e) {
      if (loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }
      _showErrorPopup("Something went wrong while applying coupon.");
      debugPrint("❌ Coupon popup error: $e");
      return false;
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Center(
          child: Text(
            "Error",
            style: TextStyle(
              color: Color(0xFFFE6464), // 🔴 red color
              fontSize: 24, // adjust if needed
              fontWeight: FontWeight.bold, // stronger emphasis
              fontFamily: "Inter", // ✅ your custom font (change if needed)
            ),
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center, // ✅ center message
        ),
        actionsAlignment: MainAxisAlignment.center, // ✅ center button
        actions: [
          SizedBox(
            width: 100,
            height: 40,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFE6464), // 🔴 button color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCouponResponsePopup(Map<String, dynamic> response) async {
    final coupons = response["coupons"] as List? ?? [];
    final coupon = coupons.isNotEmpty ? coupons.first : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogBg = isDark ? const Color(0xFF1A1C2A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF2B2D3C) : const Color(0xFFF2F4F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white70 : Colors.grey;
    const success = Color(0xFF1ABC9C);

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: dialogBg,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// HEADER
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard,
                              color: success, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Coupon Generated",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Can be redeemed after payment",
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// COUPON CARD
                      if (coupon != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              /// CODE BOX
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_offer,
                                        color: success),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        coupon["code"].toString(),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                            color: textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // _couponRow("Discount Amount",
                              //     "${coupon["amount"]}", textPrimary),
                              _couponRow(
                                "Discount Amount",
                                "\$${coupon["amount"]}",
                                textPrimary,
                              ),

                              _couponRow(
                                "Min Order Amount",
                                coupon["min_amount"] == null
                                    ? "No minimum"
                                    : "₹${coupon["min_amount"]}",
                                textPrimary,
                              ),

                              _couponRow(
                                "Max order Amount",
                                coupon["max_amount"] == null
                                    ? "No maximum"
                                    : "₹${coupon["max_amount"]}",
                                textPrimary,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 18),

                      /// OK BUTTON → confirm (true)
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.red.shade400, // soft light red
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text(
                            "OK",
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// CLOSE (X) BUTTON → cancel (false)
                Positioned(
                  right: 12,
                  top: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext, false),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Widget _couponRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildCouponButton(
      String title,
      String iconPath, {
        required VoidCallback onTap,
        bool isActive = true,
      }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Container(
        height: 50,
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 24), // ✅ SAME PADDING
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFFEB910E) : Colors.grey,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 LEFT: TEXT
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isActive ? const Color(0xFFEB910E) : Colors.grey,
                ),
              ),
            ),

            // 🔹 RIGHT: ICON (ALIGNED)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFFEB910E) : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemCouponButton(
      String title,
      String iconPath, {
        required VoidCallback onTap,
        bool isActive = true,
      }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Container(
        height: 50,
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        // ✅ SAME PADDING
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF1ABC9C) : Colors.grey,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 LEFT: TEXT
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isActive ? const Color(0xFF1ABC9C) : Colors.grey,
                ),
              ),
            ),

            // 🔹 RIGHT: ICON (ALIGNED)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF1ABC9C) : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //
  // Future<void> _removeAppliedCoupon() async {
  //   if (widget.orderId == null || widget.orderId == 0) return;
  //
  //   final offlineBox = StorageProvider.offlineOrders;
  //   final localKey = widget.offlineOrderId?.toString(); // 🔥 LOCAL KEY ONLY
  //
  //   if (localKey == null) {
  //     print("❌ No offlineOrderId found");
  //     return;
  //   }
  //
  //   setState(() => isSummaryLoading = true);
  //
  //   try {
  //     // 🔥 Remove coupon from Woo
  //     await orderBloc.removeCooupon(
  //       orderId: widget.orderId!,
  //       couponCode: "",
  //     );
  //
  //     // 🔥 RESTORE ORIGINAL PAYABLE
  //     final double restoredPayable =
  //         grossTotal + oldTax - merchantDiscount + cashbackFee;
  //
  //     setState(() {
  //       discount = 0.0;
  //       discountValue = 0.0;
  //       couponDiscount = 0.0;
  //       NetTotal = grossTotal;
  //       computedNetPayable = restoredPayable;
  //       balanceAmount = restoredPayable - tenderAmount;
  //
  //       isCouponAppliedFromApi = false;
  //     });
  //
  //     // ----------------- UPDATE HIVE -----------------
  //     final existing = offlineBox.get(localKey);
  //     if (existing != null) {
  //       final data = Map<String, dynamic>.from(existing);
  //
  //       // 🧹 CLEAR COUPON DATA
  //       data.remove("appliedCoupon");
  //       data.remove("couponCode");
  //       data.remove("couponDiscount");
  //       data.remove("orderDiscount");
  //
  //       // 🔥 SINGLE SOURCE OF TRUTH
  //       data["basePayableAmount"] = restoredPayable;
  //       data["wooTax"] = oldTax;
  //       data["couponRemoved"] = true;
  //
  //       offlineBox.put(localKey, data);
  //
  //       print("🗑 Coupon removed | Base payable restored = $restoredPayable");
  //     }
  //
  //     await CustomerDisplayHelper.updateCustomerDisplay(
  //       widget.offlineOrderId!,
  //     );
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Coupon removed successfully"),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //   } catch (e) {
  //     print("❌ Error removing coupon: $e");
  //   } finally {
  //     setState(() => isSummaryLoading = false);
  //   }
  // }

  Future<void> _removeAppliedCoupon() async {
    try {
      final box = StorageProvider.offlineOrders;

      final String orderKey = widget.orderId?.toString() ??
          widget.offlineOrderId?.toString() ??
          orderId?.toString() ??
          "";

      if (orderKey.isEmpty) return;

      final rawOrder = await box.get(orderKey);

      if (rawOrder == null) return;

      final offlineOrder = Map<String, dynamic>.from(rawOrder);

      if (mounted) {
        setState(() => isSummaryLoading = true);
      }

      final int safeOrderId = int.tryParse(orderKey) ?? widget.orderId ?? 0;

      final double restoredTax = widget.orderTax;
      _suppressCfdSync = true;

      // ================= RESET VALUES =================
      setState(() {
        discount = 0.0;
        discountValue = 0.0;
        couponDiscount = 0.0;

        tax = restoredTax;

        grossTotal = widget.grossTotal;

        merchantDiscount = widget.merchantDiscount < 0
            ? widget.merchantDiscount
            : -widget.merchantDiscount.abs();

        NetTotal = grossTotal + discount + merchantDiscount;

        computedNetPayable = NetTotal + tax + cashbackFee;

        orderTotal = computedNetPayable;

        balanceAmount = computedNetPayable - tenderAmount;

        isCouponAppliedFromApi = false;
      });

      // ================= RECALCULATE =================
      await _recalculateTaxOnDiscountedItems();

      if (!widget.itemPricesAlreadyAdjusted) {
        await _recalculateGrossAndNetFromLineItemDiscounts();
      }
      //Raghu--**
      // ================= FINAL TOTAL RECALC =================
      setState(() {
        NetTotal = grossTotal + discount + merchantDiscount; //Raghu

        computedNetPayable = NetTotal + tax + cashbackFee;

        orderTotal = computedNetPayable;

        balanceAmount = computedNetPayable - tenderAmount;
      });

      // ================= UPDATE HIVE =================
      offlineOrder["coupon_response"] = {
        "coupons": [],
        "available_coupons": [],
      };

      offlineOrder["applied_coupons"] = [];

      offlineOrder["coupon_applied"] = false;

      offlineOrder["orderDiscount"] = discount;

      offlineOrder["tax_discount"] = tax;

      offlineOrder["grand_total"] = computedNetPayable;

      await box.put(
        orderKey,
        offlineOrder,
      );

      // ================= SERVER SYNC FIRST =================
      try {
        // await OrderRepository().syncSingleOfflineOrder(
        //   offlineOrder,
        // );
        // ── Inject latest merchant discount into offlineOrder BEFORE sync ──
        if (merchantDiscount != 0) {
          offlineOrder['merchantDiscount'] = merchantDiscount.abs();
          offlineOrder['merchantDiscountPercentage'] = merchantDiscountPercentage;
        }

        final result = await OrderRepository().syncSingleOfflineOrder(offlineOrder);
      } catch (e) {
        print(
          "Sync after coupon removal failed: $e",
        );
      }

      // ================= IMPORTANT DELAY =================
      await Future.delayed(
        const Duration(
          milliseconds: 300,
        ),
      );

      // ================= FINAL CUSTOMER DISPLAY REFRESH =================
      if (safeOrderId > 0) {
        await CustomerDisplayHelper.updateCustomerDisplay(
          safeOrderId,
          summaryEnabled: true,
        );
        _suppressCfdSync = false;
        if (safeOrderId > 0) {
          // One publish with final totals only
          await _syncCfdFromOrderSummary();
        }
      }

      // ================= SUCCESS =================
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Coupon removed successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print(
        "Error removing coupon: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to remove coupon: $e",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSummaryLoading = false);
      }
    }
  }

  void _openCouponPopup() {
    ScannerGuard.isCouponPopupOpen = true;

    final TextEditingController _couponCtrl = TextEditingController();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // THEME COLORS
    final Color dialogBg = isDark ? const Color(0xFF252837) : Colors.white;
    final Color borderColor =
    isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade300;
    final Color textPrimary = isDark ? Colors.white : Colors.black87;
    final Color textSecondary = isDark ? Colors.white70 : Colors.black54;
    final Color hintColor = isDark ? Colors.white38 : Colors.grey;
    final Color redPrimary = const Color(0xFFFD6464);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.10),
      builder: (context) {
        return Stack(children: [
          /// 🔹 WHITE BACKGROUND when keyboard opens
          if (MediaQuery.of(context).viewInsets.bottom > 0)
            Positioned.fill(
              child: Container(
                color: isDark
                    ? const Color(0xFF1F1D2B) // match your dark dialog bg
                    : Colors.white,
              ),
            ),

          /// 🔹 YOUR EXISTING DIALOG
          Center(
              child: WillPopScope(
                onWillPop: () async {
                  ScannerGuard.isCouponPopupOpen = false;
                  return true;
                },
                child: BarcodeKeyboardListener(
                  bufferDuration: const Duration(milliseconds: 600),
                  onBarcodeScanned: (barcode) {
                    final code = barcode.trim();
                    print("🎯 Coupon QR/Barcode scanned → $code");

                    _couponCtrl.text = code; // ✅ Correct prefill
                  },
                  child: Dialog(
                    backgroundColor: dialogBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(26),
                      width: MediaQuery.of(context).size.width * 0.30,
                      decoration: BoxDecoration(
                        color: dialogBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              color: Colors.black.withOpacity(0.15),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              "Apply Coupon",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: redPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _couponCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              labelText: "Enter Coupon Code",
                              labelStyle: TextStyle(color: textSecondary),
                              hintStyle: TextStyle(color: hintColor),
                              filled: true,
                              fillColor:
                              isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: redPrimary, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                BorderSide(color: borderColor, width: 1.0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: redPrimary,
                                  side: BorderSide(color: redPrimary, width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  ScannerGuard.isCouponPopupOpen =
                                  false; // CLOSE FLAG
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: redPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  final code = _couponCtrl.text.trim();

                                  if (code.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                        const Text("Please enter coupon code"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  ScannerGuard.isCouponPopupOpen =
                                  false; // CLOSE FLAG
                                  Navigator.pop(context);
                                  await _applyCoupon(code);
                                },
                                child: const Text("Apply"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ))
        ]);
      },
    ).then((_) {
      ScannerGuard.isCouponPopupOpen = false; // 🔓 Ensure scanner re-enables
    });
  }

  Future<void> _applyCoupon(String code) async {
    code = code.trim().toLowerCase();
    if (code.isEmpty) return;

    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.orderId?.toString() ??
          widget.offlineOrderId?.toString() ??
          orderId?.toString() ??
          "";

      if (orderKey.isEmpty) return;

      final rawOrder = await box.get(orderKey);
      if (rawOrder == null) return;

      Map<String, dynamic> offlineOrder = Map<String, dynamic>.from(rawOrder);

      setState(() => isSummaryLoading = true);

      // Save original merchant discount values before sync
      final double originalMerchantDiscount = merchantDiscount;
      final double originalMerchantDiscountPercentage = merchantDiscountPercentage;
      final String originalMerchantDiscountType = offlineOrder['merchantDiscountType']?.toString() ?? 'fixed';

      // ==================== SMART DUPLICATE CHECK ====================
      final dynamic cr = offlineOrder["coupon_response"];
      bool isAlreadyRedeemed = false;

      if (cr is Map) {
        final List<dynamic> coupons = cr["coupons"] as List? ?? [];

        for (final dynamic item in coupons) {
          if (item is! Map) continue;

          final Map<String, dynamic> couponMap = Map<String, dynamic>.from(item);
          final String existingCode =
          (couponMap["code"]?.toString() ?? "").trim().toLowerCase();

          if (existingCode == code) {
            if (_couponHiveEntryIsRedeem(couponMap)) {
              isAlreadyRedeemed = true;
              break;
            }
          }
        }
      }

      if (isAlreadyRedeemed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Coupon already applied"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Backup original
      final dynamic originalCouponResponse = offlineOrder["coupon_response"];

      // Merge redeem coupon
      offlineOrder["coupon_response"] =
          _mergeRedeemIntoCouponResponse(offlineOrder["coupon_response"], code);

      _cleanInvalidRedeemCoupons(offlineOrder, code);

      final int? localOrderId = int.tryParse(orderKey);
      if (localOrderId != null) {
        offlineOrder["id"] = localOrderId;
      }

      await box.put(orderKey, offlineOrder);

      // ── Inject latest merchant discount into offlineOrder BEFORE sync ──
      if (merchantDiscount != 0) {
        offlineOrder['merchantDiscount'] = merchantDiscount.abs();
        offlineOrder['merchantDiscountPercentage'] = merchantDiscountPercentage;
      }

      final result = await OrderRepository().syncSingleOfflineOrder(offlineOrder);

      if (result == null || result is! Map<String, dynamic>) {
        offlineOrder["coupon_response"] = originalCouponResponse;
        await box.put(orderKey, offlineOrder);

        String errorMsg = "Invalid coupon or unable to apply";
        if (result is Map<String, dynamic> && result['code'] == 'invalid_coupon') {
          errorMsg = result['message']?.toString() ?? errorMsg;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange),
        );
        return;
      }

      // Extract values from response
      final double newDiscount =
          double.tryParse(result["discount_total"]?.toString() ?? "0") ?? 0.0;
      final double newTax =
          double.tryParse(result["tax"]?.toString() ?? "0") ?? widget.orderTax;
      final double newTotal =
          double.tryParse(result["total"]?.toString() ?? "0") ?? 0.0;

      // Update offline order
      offlineOrder["orderDiscount"] = newDiscount;
      offlineOrder["tax_discount"] = newTax;
      offlineOrder["grand_total"] = newTotal;
      offlineOrder["coupon_applied"] = true;
      offlineOrder["applied_coupons"] = [
        {"code": code.toUpperCase(), "amount": newDiscount}
      ];

      if (result.containsKey("id")) {
        offlineOrder["wooOrderId"] = result["id"];
        offlineOrder["wooStatus"] = result["status"]?.toString().toLowerCase() ?? '';
        offlineOrder["synced"] = true;
        offlineOrder["sync_at"] = DateTime.now().toIso8601String();
      }

      _enrichRedeemCouponIdsFromWoo(offlineOrder, result, code);
      await box.put(orderKey, offlineOrder);

      // ============================================================
      // ✅ FIX: RECALCULATE TAX AFTER DISCOUNT IS APPLIED
      // ============================================================

      // Step 1: Update discount value first
      setState(() {
        discount = (newDiscount != 0) ? -newDiscount.abs() : 0.0;
        isCouponAppliedFromApi = true;
      });

      // Step 2: Recalculate tax based on discounted items
      await _recalculateTaxOnDiscountedItems();

      // Step 3: Recalculate gross/net from line item discounts
      if (!widget.itemPricesAlreadyAdjusted) {
        await _recalculateGrossAndNetFromLineItemDiscounts();
      }
      // Suppress CFD until ALL totals (discount, tax, merchant, net) are final
      _suppressCfdSync = true;
      // Step 4: Final totals update
      setState(() {
        NetTotal = grossTotal + discount + merchantDiscount;
        computedNetPayable = NetTotal + tax + cashbackFee;
        orderTotal = computedNetPayable;
        balanceAmount = computedNetPayable - tenderAmount;
        if (balanceAmount < 0) balanceAmount = 0.0;

        // ✅ Restore merchant discount values
        merchantDiscount = originalMerchantDiscount;
        merchantDiscountPercentage = originalMerchantDiscountPercentage;
      });

      // //  Update offlineOrder with restored merchant discount values
      // offlineOrder["merchantDiscount"] = originalMerchantDiscount;
      // offlineOrder["merchantDiscountPercentage"] = originalMerchantDiscountPercentage;
      // offlineOrder["merchantDiscountType"] = originalMerchantDiscountType;
      // await box.put(orderKey, offlineOrder);
      //
      // //  Update customer display
      // if (localOrderId != null) {
      //   await CustomerDisplayHelper.updateCustomerDisplay(
      //     localOrderId,
      //     summaryEnabled: true,
      //   );
      // }

      final rawLatestForDisplay = await box.get(orderKey);
      if (rawLatestForDisplay != null) {
        final latestOrder = Map<String, dynamic>.from(rawLatestForDisplay);
        final double positiveMerchantDiscount = originalMerchantDiscount.abs();
        latestOrder["merchantDiscount"] = positiveMerchantDiscount;
        latestOrder["merchant_discount"] = positiveMerchantDiscount;
        latestOrder["merchantDiscountFixed"] = positiveMerchantDiscount;
        latestOrder["merchantDiscountPercentage"] = originalMerchantDiscountPercentage;
        latestOrder["merchantDiscountType"] = originalMerchantDiscountType;
        await box.put(orderKey, latestOrder);
        offlineOrder = latestOrder;
      }

// Single source of truth for CFD – do NOT call Helper again after this
      await _syncCfdFromOrderSummary();

      // // ✅ Update customer display
      // if (localOrderId != null) {
      //   await CustomerDisplayHelper.updateCustomerDisplay(
      //     localOrderId,
      //     summaryEnabled: true,
      //   );
      // }

      if (localOrderId != null) {
        // await CustomerDisplayHelper.updateCustomerDisplay(
        //   localOrderId,
        //   summaryEnabled: true,
        // );

        await CustomerDisplayHelper.updateCustomerDisplay(localOrderId, summaryEnabled: true);

      }
      _suppressCfdSync = false;
      await _syncCfdFromOrderSummary();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Coupon applied successfully"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print("❌ Apply coupon error: $e");
      // Restore logic...
      try {
        final box = StorageProvider.offlineOrders;
        final String orderKey = widget.orderId?.toString() ??
            widget.offlineOrderId?.toString() ??
            "";
        if (orderKey.isNotEmpty) {
          final raw = await box.get(orderKey);
          if (raw is Map) {
            final order = Map<String, dynamic>.from(raw);
            final cr = order["coupon_response"];
            if (cr is Map) {
              final map = Map<String, dynamic>.from(cr);
              final coupons = (map['coupons'] as List?) ?? [];
              map['coupons'] = coupons.where((c) {
                if (c is! Map) return false;
                return !_couponHiveEntryIsRedeem(Map<String, dynamic>.from(c));
              }).toList();
              order["coupon_response"] = map;
              await box.put(orderKey, order);
            }
          }
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to apply coupon: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSummaryLoading = false);
    }
  }


  Future<void> _recalculateMerchantDiscount() async {
    // Get merchant discount type and percentage from offline order
    final String mdType = offlineOrder?['merchantDiscountType']?.toString() ?? 'fixed';
    final num mdPercentage = offlineOrder?['merchantDiscountPercentage'] as num? ?? merchantDiscountPercentage;
    //Raghu--**
    // Calculate current base (Gross)
    final double baseAmount = grossTotal  ;

    if (mdType == 'percentage' && mdPercentage > 0) {
      // Recalculate merchant discount based on new base amount
      final double newMerchantDiscount = -((baseAmount * mdPercentage) / 100.0);

      if (kDebugMode) {
        print('🔄 Recalculating merchant discount:');
        print('   Base Amount (Gross): $baseAmount');
        print('   Percentage: $mdPercentage%');
        print('   New Merchant Discount: $newMerchantDiscount');
        print('   Old Merchant Discount: $merchantDiscount');
      }

      setState(() {
        merchantDiscount = newMerchantDiscount;
      });

      // Update offline order
      if (offlineOrder != null) {
        offlineOrder!['merchantDiscount'] = merchantDiscount;
        await StorageProvider.offlineOrders.put(
            (orderId ?? 0).toString(),
            offlineOrder!
        );
      }
    } else {
      // Fixed dollar-amount merchant discount: pull the stored value from Hive
      // instead of resetting to 0. Previously this branch always zeroed it out,
      // which is why fixed/$ merchant discounts never showed on this screen.
      final double storedFixed =
          (offlineOrder?['merchantDiscount'] as num?)?.toDouble() ?? 0.0;
      merchantDiscount = storedFixed != 0 ? -(storedFixed.abs()) : 0.0;
    }
  }

  /// Remove previously failed/invalid redeem coupons before syncing
  void _cleanInvalidRedeemCoupons(
      Map<String, dynamic> offlineOrder, String currentCode) {
    final cr = offlineOrder['coupon_response'];
    if (cr is! Map) return;

    final map = Map<String, dynamic>.from(cr);
    final List<dynamic> coupons = map['coupons'] as List? ?? [];

    final cleaned = <Map<String, dynamic>>[];

    for (final dynamic c in coupons) {
      if (c is! Map) continue;
      final couponMap = Map<String, dynamic>.from(c);
      final isRedeem = _couponHiveEntryIsRedeem(couponMap);

      if (!isRedeem) {
        cleaned.add(couponMap);
      } else if (couponMap['code']?.toString().trim() == currentCode) {
        cleaned.add(couponMap); // keep only current one
      }
    }

    map['coupons'] = cleaned;
    offlineOrder['coupon_response'] = map;
  }
  // Future<void> _applyCoupon(String code) async {
  //   try {
  //     final box = StorageProvider.offlineOrders;
  //
  //     final String orderKey =
  //         widget.orderId?.toString() ?? widget.offlineOrderId?.toString() ?? "";
  //
  //     if (orderKey.isEmpty) return;
  //
  //     final rawOrder = await box.get(orderKey);
  //
  //     final offlineOrder = Map<String, dynamic>.from(
  //       rawOrder is Map ? rawOrder : {},
  //     );
  //
  //     if (offlineOrder.isEmpty) return;
  //
  //     // Store coupon locally (redeem: generate_type true; keep issued coupons if any)
  //
  //     offlineOrder["coupon_response"] =
  //         _mergeRedeemIntoCouponResponse(offlineOrder["coupon_response"], code);
  //
  //     // ✅ Use LOCAL order ID instead of Woo ID for syncing
  //
  //     final int? localOrderId = int.tryParse(orderKey);
  //
  //     if (localOrderId != null) {
  //       offlineOrder["id"] = localOrderId; // critical for local sync
  //     }
  //
  //     await box.put(orderKey, offlineOrder);
  //
  //     setState(() => isSummaryLoading = true);
  //
  //     // Send to repository with local ID
  //
  //     final result =
  //     await OrderRepository().syncSingleOfflineOrder(offlineOrder);
  //
  //     if (result == null || result is! Map) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Invalid coupon or unable to apply"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //
  //       return;
  //     }
  //
  //     // ⭐ Extract values from repository response
  //
  //     final double newDiscount =
  //         double.tryParse(result["discount_total"]?.toString() ?? "0") ?? 0.0;
  //
  //     final double newTax =
  //         double.tryParse(result["tax"]?.toString() ?? "0") ?? tax;
  //
  //     final double newTotal =
  //         double.tryParse(result["total"]?.toString() ?? "0") ?? 0.0;
  //
  //     // Update offline order fields
  //
  //     offlineOrder["orderDiscount"] = newDiscount;
  //
  //     offlineOrder["tax_discount"] = newTax;
  //
  //     offlineOrder["grand_total"] = newTotal;
  //
  //     offlineOrder["coupon_applied"] = true;
  //
  //     offlineOrder["applied_coupons"] = [
  //       {"code": code, "amount": newDiscount}
  //     ];
  //
  //     // ✅ Store Woo info if returned, but do NOT send Woo ID next time
  //
  //     if (result.containsKey("id")) {
  //       offlineOrder["wooOrderId"] = result["id"];
  //
  //       offlineOrder["wooStatus"] =
  //           result["status"]?.toString().toLowerCase() ?? '';
  //
  //       offlineOrder["synced"] = true;
  //
  //       offlineOrder["sync_at"] = DateTime.now().toIso8601String();
  //     }
  //
  //     _enrichRedeemCouponIdsFromWoo(offlineOrder, result, code);
  //
  //     await box.put(orderKey, offlineOrder);
  //
  //     // 🔥 Update display
  //
  //     await CustomerDisplayHelper.updateCustomerDisplay(
  //       localOrderId!,
  //       summaryEnabled: true,
  //     );
  //
  //     setState(() {
  //       // Enforce negative sign for display consistency (-$5.00)
  //       discount = (newDiscount != 0) ? -(newDiscount.abs()) : 0.0;
  //       tax = newTax;
  //
  //       // Use algebraic sum
  //       NetTotal = grossTotal + discount + merchantDiscount;
  //       computedNetPayable = NetTotal + tax + cashbackFee;
  //       orderTotal = newTotal;
  //
  //       balanceAmount = newTotal;
  //
  //       isCouponAppliedFromApi = true;
  //     });
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Coupon applied successfully"),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //
  //     print(
  //         "✅ Coupon Applied (local ID $localOrderId): Discount $newDiscount, Tax $newTax, Total $newTotal");
  //   } catch (e) {
  //     print("❌ Apply coupon error: $e");
  //   } finally {
  //     setState(() => isSummaryLoading = false);
  //   }
  // }

  Widget _buildAmountDisplay(
      String label,
      String amount, {
        required Color leftBarColor,
        Color? amountColor = Colors.black,
        double labelFontSize = 11,
        double amountFontSize = 12,
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      width: MediaQuery.of(context).size.width * 0.240,
      height: ResponsiveLayout.getHeight(40),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: ResponsiveLayout.getHeight(45),
            decoration: BoxDecoration(
              color: leftBarColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(labelFontSize),
                  fontWeight: FontWeight.w500,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : const Color(0xFF333333),
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(amountFontSize),
                  fontWeight: FontWeight.w700,
                  color: amountColor ??
                      (themeHelper.themeMode == ThemeMode.dark
                          ? Colors.white
                          : const Color(0xFF222222)),
                ),
                child: Text(amount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    // Build #1.0.29: updated
    return GestureDetector(
      onTap: () {
        // Remove '$' and ensure the value is numeric
        String cleanAmount =
        amount.replaceAll(TextConstants.currencySymbol, '');
        double numericValue = double.parse(cleanAmount);
        amountController.text =
        '${TextConstants.currencySymbol} ${numericValue.toStringAsFixed(2)}';
        setState(() {});
      },
      child: Container(
        height: ResponsiveLayout.getHeight(43),
        width: ResponsiveLayout.getWidth(100),
        alignment: Alignment.center,
        padding: EdgeInsets.all(ResponsiveLayout.getPadding(5.0)),
        decoration: BoxDecoration(
          color: Color(0xFFE1F8DC),
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(5)),
        ),
        child: Text(
          amount,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveLayout.getFontSize(16),
              color: Color(0xFF518C3A)),
        ),
      ),
    );
  }

  // Helper method to generate exactly 5 unique quick amounts
  List<double> _generateQuickAmounts(double balanceAmount) {
    Set<double> amounts = {};

    // 1. Exact balance amount
    amounts.add(balanceAmount);

    // 2. Round up to next whole number
    amounts.add(balanceAmount.ceilToDouble());

    // 3. Round up to next 5
    double nextFive = ((balanceAmount / 5).ceil() * 5).toDouble();
    amounts.add(nextFive);

    // 4. Round up to next 10
    double nextTen = ((balanceAmount / 10).ceil() * 10).toDouble();
    amounts.add(nextTen);

    // Keep adding logical amounts until we have at least 5
    List<double> additionalAmounts = [];

    if (balanceAmount < 20) {
      additionalAmounts = [20.0, 25.0, 50.0, 100.0];
    } else if (balanceAmount < 50) {
      additionalAmounts = [50.0, 75.0, 100.0, 150.0];
    } else if (balanceAmount < 100) {
      additionalAmounts = [100.0, 150.0, 200.0, 250.0];
    } else if (balanceAmount < 500) {
      additionalAmounts = [
        ((balanceAmount / 50).ceil() * 50).toDouble(),
        ((balanceAmount / 100).ceil() * 100).toDouble(),
        ((balanceAmount / 100).ceil() * 100 + 100).toDouble(),
        ((balanceAmount / 100).ceil() * 100 + 200).toDouble(),
      ];
    } else {
      additionalAmounts = [
        ((balanceAmount / 100).ceil() * 100).toDouble(),
        ((balanceAmount / 500).ceil() * 500).toDouble(),
        ((balanceAmount / 1000).ceil() * 1000).toDouble(),
        ((balanceAmount / 1000).ceil() * 1000 + 500).toDouble(),
      ];
    }

    // Add additional amounts to ensure we have enough
    for (double amount in additionalAmounts) {
      amounts.add(amount);
      if (amounts.length >= 7) break; // Get more than 5 to have options
    }

    // Convert to sorted list and take exactly 5 unique values
    List<double> sortedAmounts = amounts.toList()..sort();

    // Ensure we always return exactly 5 amounts
    if (sortedAmounts.length >= 5) {
      return sortedAmounts.take(5).toList();
    } else {
      // If somehow we don't have 5, pad with increments
      while (sortedAmounts.length < 5) {
        double lastAmount = sortedAmounts.last;
        double increment = lastAmount < 100 ? 25 : 100;
        sortedAmounts.add(lastAmount + increment);
      }
      return sortedAmounts.take(5).toList();
    }
  }

  Widget _buildPaymentModeButton(
      String label,
      Widget iconWidget, {
        required LinearGradient gradient,
        required Color borderColor,
        Color? iconColor, // optional
        VoidCallback? onTap,
        bool isLoading = false,
        bool isDisabled = false,
      }) {
    double _scale = 1.0;
    final bool isEnabled = !isDisabled && !isLoading && onTap != null;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTapDown: isEnabled
              ? (_) {
            setState(() {
              _scale = 0.95; // press effect
            });
          }
              : null,
          onTapUp: isEnabled
              ? (_) {
            setState(() {
              _scale = 1.0;
            });
            if (onTap != null) onTap();
          }
              : null,
          onTapCancel: isEnabled
              ? () {
            setState(() {
              _scale = 1.0;
            });
          }
              : null,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Container(
                width: double.infinity,
                height: ResponsiveLayout.getHeight(54),
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 4,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                    BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                    onTap: isEnabled ? onTap : null,
                    splashColor: Colors.white24,
                    highlightColor: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon inside circle or loading indicator
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: isLoading
                              ? SizedBox(
                            width: ResponsiveLayout.getIconSize(24),
                            height: ResponsiveLayout.getIconSize(24),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  borderColor),
                            ),
                          )
                              : iconWidget,
                        ),
                        SizedBox(width: ResponsiveLayout.getWidth(12)),
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveLayout.getFontSize(18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionButton(
      String title,
      String iconPath, {
        required bool isActive,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Container(
        height: 50,
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 24), // ✅ SAME PADDING
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF817ACC) : Colors.grey,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 LEFT: TEXT
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isActive ? const Color(0xFF817ACC) : Colors.grey,
                ),
              ),
            ),

            // 🔹 RIGHT: ICON (ALIGNED)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF817ACC) : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build #1.0.175: Modified _handleVoidPayment for partial void with API call

  Future<void> _handleVoidPayment(BuildContext context,
      {required bool isPartial}) async {
    // ────────────────────────────────────────────────
    //  0. Early validation
    // ────────────────────────────────────────────────
    if (_lastPayment == null || _lastPayment!.amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No valid payment to void")),
      );
      Navigator.of(context).pop(); // close confirmation dialog
      return;
    }

    final voidedAmount = _lastPayment!.amount;
    final method = _lastPayment!.method;

    print(
        "VOID INITIATED → reversing \$${voidedAmount.toStringAsFixed(2)} ($method) | isPartial: $isPartial");

    final now = DateTime.now();
    final String voidDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    // ────────────────────────────────────────────────
    //  1. Create NEGATIVE payment record
    // ────────────────────────────────────────────────
    final negativePayment = LocalPayment(
      orderId: orderId ?? 0,
      title: "Void ($method)",
      amount: -voidedAmount,
      // IMPORTANT: use the original payment method so per-method totals (Pay by Cash)
      // correctly subtract the negative void amount.
      paymentMethod: method,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: voidDateTime,
      notes:
      "Local void of ${method} payment – original ID: ${_lastPayment?.paymentId ?? 'local'}",
      isSynced: false,
      createdAt: now,
      remainingBalance:
      (balanceAmount + voidedAmount).clamp(0.0, double.infinity),
      status: PaymentDbStatus.voided,
      serverPaymentId: int.tryParse(_lastPayment?.paymentId ?? "0"),
    );

    try {
      // ────────────────────────────────────────────────
      //  2. Save void payment (Isar + Hive mirroring)
      // ────────────────────────────────────────────────
      final savedVoid =
      await LocalPaymentDBHelper.instance.savePayment(negativePayment);
      print(
          "Void saved in Isar → ID: ${savedVoid.id} | amount: -${voidedAmount.toStringAsFixed(2)}");

      await _savePaymentToHive(
        amount: -voidedAmount,
        paymentMethod: method,
        transactionId: "void_${savedVoid.id}",
        localPayment: savedVoid,
      );

      await _saveLocalPaymentToHive(savedVoid);

      // ────────────────────────────────────────────────
      //  3. Refresh balances from full payment history
      //     (this should now include the -amount entry)
      // ────────────────────────────────────────────────
      await _calculateBalanceFromPaymentHistory();
      await _printPaymentHistorySummary();

      // ── Call server void for card payments ──────────────────────────
      final String? serverPaymentId = _lastPayment?.paymentId;
      if (_lastPayment?.method.toLowerCase() == TextConstants.card.toLowerCase()) {
        await _voidServerPaymentIfCard(serverPaymentId: serverPaymentId);
      }

      // ────────────────────────────────────────────────
      //  4. CRITICAL: Force-reset "payment completed" flags
      //     Especially important when isPartial == false (full void)
      // ────────────────────────────────────────────────
      setState(() {
        // Always clear last payment reference
        _lastPayment = null;
        _lastPaymentDetails = null;

        // If this was a FULL payment void → make sure we allow new full payment
        if (!isPartial) {
          // Most important resets for full void
          _currentPaymentRemainingBalance =
          null; // no longer "in partial session"
          _successPopupShown = false; // allow success dialog again
          isPaymentStarted = false; // visually reset "payment in progress"
        }

        // Clear the input + payment-method highlight so we don't remain in "EBT zone"
        // when the user voids and continues paying.
        selectedPaymentMethod = TextConstants.cash;

        // Always update main UI flags based on new calculated balance
        isPaymentStarted = tenderAmount > 0;
      });

      // Reset keypad input (amount field) after void.
      // (Do it outside setState so it also updates controller text.)
      _resetAmountAfterPay();

      // ────────────────────────────────────────────────
      //  5. Optional: Show feedback (non-intrusive)
      // ────────────────────────────────────────────────
      String message = isPartial
          ? "Partial payment of \$${voidedAmount.toStringAsFixed(2)} voided"
          : "Full payment of \$${voidedAmount.toStringAsFixed(2)} voided. Ready for new payment.";

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(message),
      //     backgroundColor: Colors.orange[800],
      //     duration: const Duration(seconds: 4),
      //   ),
      // );
    } catch (e, stack) {
      print("VOID FAILED: $e");
      print(stack);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text("Failed to void payment: $e"),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }

    // Push void + updated balances to Woo while Hive still holds wooOrderId
    if (mounted) {
      Future.microtask(() async {
        try {
          await _syncCurrentOfflineOrder();
        } catch (e) {
          print("❌ Post-void sync failed: $e");
        }
      });
    }

    // Always close the confirmation dialog at the end
    // if (Navigator.canPop(context)) {
    //   Navigator.of(context).pop();
    // }
  }

  // Build #1.0.175: New method for void order API call
  void _handleVoidOrder(BuildContext context) {
    if (orderId == null || orderId == 0) {
      if (kDebugMode) {
        print(
            "_handleVoidOrder -> Invalid order ID: $orderId. Cannot void order.");
      }
      Navigator.of(context).pop(); // Close the dialog
      return;
    }

    // DEBUG: Log the void order attempt
    if (kDebugMode) {
      print("_handleVoidOrder -> Attempting to void order ID: $orderId");
    }

    paymentBloc.voidOrder(orderId!);
    StreamSubscription? subscription;
    subscription = paymentBloc.voidOrderStream.listen((response) {
      if (!mounted) {
        if (kDebugMode) {
          print("_handleVoidOrder -> Widget not mounted, skipping UI updates");
        }
        subscription?.cancel();
        return;
      }

      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print(
              "_handleVoidOrder -> Void order successful: ${response.data!.message}");
        }

        // Reset UI values after voiding order
        setState(() {
          payByCash = 0.0;
          payByOther = 0.0;
          tenderAmount = 0.0;
          changeAmount = 0.0;
          balanceAmount = orderTotal; // Reset to original order total
          if (kDebugMode) {
            print(
                "_handleVoidOrder -> Balance reset to original order total: $balanceAmount");
          }
        });

        if (Misc.showDebugSnackBar) {
          // Build #1.0.254
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data!.message ?? TextConstants.voidSuccess,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Build #1.0.175
        Navigator.of(context).pop(); // Close void confirmation dialog
        Navigator.of(context).pop(); // Close payment dialog
        // Navigator.of(context).pop(TextConstants.refresh); // Navigate back to previous screen
        if (kDebugMode) {
          print("_handleVoidOrder -> 2: ${response.data!.message}");
        }

        ///This is for voiding completed payment
        OrderHelper.isOrderPanelLoaded = false;

        ///Update! on 9-Sep-25: asked by Shravan, void button click will result in cancelling of payment only, no need to change order status to cancelled now. If balance amount is changed then order will be pending else it will be processing
        // Navigator.pushReplacement(result: TextConstants.refresh,
        //   context,
        //   MaterialPageRoute(builder: (_) => POSHomeScreen()),
        // );
      } else if (response.status == Status.ERROR) {
        if (kDebugMode) {
          print(
              "_handleVoidOrder -> Void order failed: ${response.data!.message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data!.message ?? '',
              style: const TextStyle(color: Colors.red),
            ),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Close the dialog
      }
      subscription?.cancel();
    });
  }

  // --------------------

  Future<void> _showPartialPaymentDialog(BuildContext context, double amount,
      {bool isVoidDisabled = false}) async {
    if (_isShowingPartialDialog) {
      print("Partial dialog already showing → skipping duplicate call");
      return;
    }
    _isShowingPartialDialog = true;

    final double remainingToShow =
        _currentPaymentRemainingBalance ?? balanceAmount;
    print(
        "Showing Partial Payment Dialog → amount: $amount | remaining: $remainingToShow");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PaymentDialog(
        status: PaymentStatus.partial,
        mode: _currentDialogPaymentMode(),
        amount: amount,
        remainingBalance: remainingToShow,
        isVoidDisabled: isVoidDisabled,
        onVoid: () async {
          print("Void tapped from partial dialog");
          // 1. Close the partial dialog cleanly first
          Navigator.of(dialogCtx).pop();

          // 2. Show void confirmation
          if (!_isShowingPartialDialog) {
            showVoidExitConfirmation(context, false); // false = not partial
          }
          await _showVoidConfirmation(context, isPartial: true);
        },
        onNextPayment: () async {
          // try {
          //   await CustomerDisplayService.showThankYou();
          // } catch (e) {
          //   print(">>> Error showing Thank You screen: $e");
          // }

          print("Next Payment tapped → closing partial dialog cleanly");

          Navigator.of(dialogCtx).pop();

          if (mounted) {
            setState(() {
              selectedPaymentMethod = TextConstants.cash;
            });
            _resetAmountAfterPay();
          }
        },
      ),
    );

    // Reset guard after dialog is fully closed
    _isShowingPartialDialog = false;
    print("Partial dialog closed → guard reset");
  }

  Future<void> _showVoidConfirmation(BuildContext context,
      {required bool isPartial}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PaymentDialog.voidConfirmation(
        onVoidCancel: () async {
          print("❌ VOID CANCELED ByyyY USER");

          // ⚠️ This will mark all pending payments as completed – use with extreme caution
          if (orderId != null && orderId! > 0) {
            int retries = 3;
            while (retries > 0) {
              final payments = await LocalPaymentDBHelper.instance
                  .getPaymentsByOrderId(orderId!);
              final pendingPayments = payments
                  .where((p) =>
              p.amount > 0 && p.status == PaymentDbStatus.pending)
                  .toList();
              if (pendingPayments.isNotEmpty) {
                for (final p in pendingPayments) {
                  await LocalPaymentDBHelper.instance.updateStatus(
                    p.id,
                    PaymentDbStatus.pending,
                  );
                }
                print(
                    "✅ Marked ${pendingPayments.length} payments as completed");
                break;
              } else {
                retries--;
                if (retries > 0) {
                  print(
                      " No pending payments found, retrying... ($retries left)");
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
          }

          Navigator.of(dialogCtx, rootNavigator: false).pop();
          _isVoiding = false;
        },
        onVoidConfirm: () async {
          // try {
          //   await CustomerDisplayService.showThankYou();
          // } catch (e) {
          //   print(">>> Error showing Thank You screen: $e");
          // }
          Navigator.of(dialogCtx).pop();

          if (_lastPayment == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No payment to void")),
            );
            return;
          }

          final method = _lastPayment!.method.toLowerCase();

          if (method == TextConstants.card.toLowerCase() &&
              _lastPayment!.sunmiTxnId != null &&
              _lastPayment!.sunmiOrderId != null) {
            await _openSunmiVoidScreen(
              amount: _lastPayment!.amount,
              orderId: _lastPayment!.sunmiOrderId!,
              originTransactionId: _lastPayment!.sunmiTxnId!,
            );
          } else {
            // For card payments via API (no Sunmi hardware), call kickback void
            // then do the local void bookkeeping
            if (method == TextConstants.card.toLowerCase()) {
              final String? serverPaymentId = _lastPayment!.paymentId;
              await _voidServerPaymentIfCard(serverPaymentId: serverPaymentId);
            }
            await _handleVoidPayment(context, isPartial: isPartial);
          }

          // 🔁 STAY ON SCREEN (no Navigator.pop)
          print("Void completed – staying on OrderSummaryScreen");

          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  ////////

  // void _showPaymentDialog(
  //     BuildContext context,
  //     double amount, {
  //       double? changeAmount,
  //       required bool showChange,
  //       Map<String, dynamic>? couponResponse,
  //     }) async {
  //   if (kDebugMode) {
  //     print(
  //         "Showing Payment Dialog: amount=$amount, showChange=$showChange, changeAmount=$changeAmount");
  //   }
  //
  //   final storeInfo = PinakaPreferences.getLoggedInStore();
  //
  //   Future<void> _updateCustomerDisplayWelcome(
  //       Map<String, String?> storeInfo) async {
  //     if (storeInfo.isNotEmpty) {
  //       if (kDebugMode) {
  //         print(">>> Updating Customer Display with store info:");
  //         print("Store ID: ${storeInfo['storeId']}");
  //         print("Store Name: ${storeInfo['storeName']}");
  //         print("Store Logo URL: ${storeInfo['storeLogoUrl']}");
  //         print("Store Base URL: ${storeInfo['storeBaseUrl']}");
  //       }
  //
  //       await CustomerDisplayHelper.updateWelcomeWithStore(
  //         storeInfo['storeId'] ?? '0',
  //         storeInfo['storeName'] ?? 'Store',
  //         storeLogoUrl: storeInfo['storeLogoUrl'] ?? '',
  //         storeBaseUrl: storeInfo['storeBaseUrl'] ?? '',
  //       );
  //     } else {
  //       if (kDebugMode) {
  //         print(">>> No store info found, showing default welcome screen");
  //       }
  //       await CustomerDisplayService.showWelcome();
  //     }
  //   }
  //
  //   try {
  //     if (kDebugMode) print(">>> Showing THANK YOU screen before receipt options");
  //     await CustomerDisplayService.showThankYou();
  //   } catch (e) {
  //     if (kDebugMode) print(">>> Error showing Thank You screen: $e");
  //   }
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (dialogCtx) => PaymentDialog(
  //       status: PaymentStatus.successful,
  //       mode: PaymentMode.cash,
  //       amount: amount,
  //       changeAmount: showChange ? changeAmount : null,
  //       couponResponse: couponResponse,
  //
  //       // ────────────────────────────────────────────────
  //       // UPDATED: Void button now navigates back instantly after confirmation
  //       // ────────────────────────────────────────────────
  //       onVoid: () {
  //         print("Void tapped from FULL payment success dialog");
  //
  //         // Close the success dialog first (clean stack)
  //         Navigator.of(dialogCtx).pop();
  //
  //         // Show confirmation → and let it handle instant navigation on success/fail
  //         showVoidExitConfirmation(context, false); // false = not partial
  //       },
  //
  //       onNoReceipt: () async {
  //         if (kDebugMode) print(">>> NoReceipt pressed");
  //         await _updateCustomerDisplayWelcome(storeInfo);
  //         changeStatusToCompletedAndExit(false);
  //       },
  //
  //       onDone: (selectedOption, {String? email}) async {
  //         if (kDebugMode) {
  //           print("DEBUG 0011 : $selectedOption, $email, ${email?.isNotEmpty}");
  //         }
  //
  //         if (selectedOption == TextConstants.email &&
  //             email != null &&
  //             email.isNotEmpty) {
  //           if (orderId == null || orderId == 0) {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text(TextConstants.canNotSendEmail),
  //                 backgroundColor: Colors.red,
  //                 duration: const Duration(seconds: 3),
  //               ),
  //             );
  //             return;
  //           }
  //
  //           paymentBloc.sendOrderDetails(orderId!, email);
  //           StreamSubscription? subscription;
  //           subscription = paymentBloc.sendOrderDetailsStream.listen((response) async {
  //             subscription?.cancel();
  //             if (kDebugMode) print(">>> Email sent, updating customer display");
  //             await _updateCustomerDisplayWelcome(storeInfo);
  //             changeStatusToCompletedAndExit(true, selectedOption: selectedOption);
  //           });
  //           return;
  //         }
  //
  //         if (selectedOption == TextConstants.print && !Misc.disablePrinter) {
  //           if (kDebugMode) print(">>> Printing receipt");
  //           await _preparePrintTicket();
  //           await _printTicket(manual: true);
  //         }
  //
  //         if (kDebugMode) print(">>> Returning to Welcome after Thank You");
  //         await _updateCustomerDisplayWelcome(storeInfo);
  //         changeStatusToCompletedAndExit(true, selectedOption: selectedOption);
  //       },
  //     ),
  //   );
  // }

  Future<void> _updatePaymentStatusInHive(
      int localOrderId, int paymentLocalId, String newStatus) async {
    try {
      final box = StorageProvider.offlineOrders;
      final String hiveKey =
      localOrderId.toString(); // key is the local order ID

      if (!(await box.containsKey(hiveKey))) return;

      final raw = await box.get(hiveKey);
      final order = Map<String, dynamic>.from(raw is Map ? raw : {});

      final List<dynamic> payments = order['payments'] ?? [];
      bool updated = false;

      for (int i = 0; i < payments.length; i++) {
        final p = payments[i] as Map<String, dynamic>;
        if (p['local_id'] == paymentLocalId) {
          p['status'] = newStatus;
          updated = true;
          break;
        }
      }

      if (updated) {
        order['payments'] = payments;
        await box.put(hiveKey, order);
        print("✅ Hive payment #$paymentLocalId status updated to '$newStatus'");
      }
    } catch (e) {
      print("❌ Error updating Hive payment status: $e");
    }
  }

  Future<void> _markHiveOrderCompleted(int localOrderId) async {
    try {
      final box = StorageProvider.offlineOrders;
      final String key = localOrderId.toString();

      if (!(await box.containsKey(key))) return;

      final raw = await box.get(key);
      final order = Map<String, dynamic>.from(raw is Map ? raw : {});

      order['order_status'] = 'processing';
      order['updated_at'] = DateTime.now().toIso8601String();

      await box.put(key, order);
      await OfflineHelper.updateOfflineOrderStatus(localOrderId, 'processing');
      print("✅ Hive & SQLite order #$localOrderId marked as processing");
    } catch (e) {
      print("❌ _markHiveOrderCompleted error: $e");
    }
  }

  Future<void> _updateHiveWithLatestMerchantDiscount() async {
    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = orderId?.toString() ??
          widget.orderId?.toString() ??
          widget.offlineOrderId?.toString() ??
          "";

      if (orderKey.isEmpty) return;

      final raw = await box.get(orderKey);
      if (raw is! Map<String, dynamic>) return;

      final order = Map<String, dynamic>.from(raw);

      // Update merchant discount values
      order['merchantDiscount'] = merchantDiscount.abs();
      order['merchantDiscountPercentage'] = merchantDiscountPercentage;

      // Also update financial totals to ensure consistency
      order['NetTotal'] = NetTotal;
      order['computedNetPayable'] = computedNetPayable;
      order['order_total'] = orderTotal;
      order['balance_amount'] = balanceAmount;
      order['remaining_balance'] = balanceAmount;

      await box.put(orderKey, order);

      if (kDebugMode) {
        print('✅ Updated Hive with merchant discount: $merchantDiscount');
        print('   Percentage: $merchantDiscountPercentage%');
      }
    } catch (e) {
      print('❌ Failed to update Hive with merchant discount: $e');
    }
  }

  Future<void> _syncCurrentOfflineOrder() async {
    final String orderKey = widget.orderId?.toString() ??
        widget.offlineOrderId?.toString() ??
        orderId?.toString() ??
        "";

    if (orderKey.isEmpty) return;

    if (_isOrderSyncInProgress && _activeSyncOrderKey == orderKey) return;

    _isOrderSyncInProgress = true;
    _activeSyncOrderKey = orderKey;

    try {
      final box = StorageProvider.offlineOrders;
      final raw = await box.get(orderKey);
      if (raw is! Map<String, dynamic>) return;

      var order = Map<String, dynamic>.from(raw);

      // ✅ CRITICAL: Update merchant discount values before sync
      order['merchantDiscount'] = merchantDiscount.abs();
      order['merchantDiscountPercentage'] = merchantDiscountPercentage;

      // Also update the merchant discount type if available
      if (offlineOrder?['merchantDiscountType'] != null) {
        order['merchantDiscountType'] = offlineOrder!['merchantDiscountType'];
      }

      // === CRITICAL: Handle coupon validation failures ===
      bool syncSuccess = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!syncSuccess && retryCount < maxRetries) {
        retryCount++;

        final result = await OrderRepository().syncSingleOfflineOrder(order);

        if (result != null && result is Map) {
          // Success
          syncSuccess = true;
          final woo = Map<String, dynamic>.from(result);
          final wooOrderId = woo['id'] ?? 0;
          final wooStatus = woo['status']?.toString().toLowerCase() ?? '';

          // Mark payments synced
          final localOrderId = int.tryParse(orderKey);
          if (localOrderId != null) {
            final payments = await LocalPaymentDBHelper.instance
                .getPaymentsByOrderId(localOrderId);
            for (final p in payments.where((p) => !p.isSynced)) {
              await LocalPaymentDBHelper.instance
                  .markAsSynced(p.id, wooOrderId);
            }
          }

          // Clean up Hive
          if (wooStatus == 'completed') {
            await box.delete(orderKey);
            print("✅ Order $orderKey synced & deleted (completed)");
          } else {
            order['wooOrderId'] = wooOrderId;
            order['wooStatus'] = wooStatus;
            order['synced'] = true;
            order['sync_at'] = DateTime.now().toIso8601String();
            await box.put(orderKey, order);
          }
        } else if (retryCount < maxRetries) {
          // === HANDLE COUPON FAILURE GRACEFULLY ===
          print(
              "⚠️ Sync attempt $retryCount failed. Checking for coupon issues...");

          // Remove problematic coupons from this attempt and retry
          if (order['coupon_response'] is Map) {
            final cr = Map<String, dynamic>.from(order['coupon_response']);
            final coupons = (cr['coupons'] as List?) ?? [];

            // Keep only "issued" coupons (generate_type: false), remove redeem ones that failed
            final keptCoupons = coupons.where((c) {
              if (c is Map) {
                final isRedeem = c['generate_type'] == true ||
                    (c['code']?.toString().contains("2026") ?? false);
                return !isRedeem;
              }
              return true;
            }).toList();

            cr['coupons'] = keptCoupons;
            order['coupon_response'] = cr;
            order['coupon_lines'] = []; // clear for next attempt
            order['coupon_applied'] = keptCoupons.isNotEmpty;

            print("🔄 Removed failing coupons. Retrying sync...");
            await box.put(orderKey, order); // save cleaned version
          }
        } else {
          print("❌ All retry attempts failed for order $orderKey");
          // Optional: mark as partially synced or show user notification
        }
      }
    } catch (e, stack) {
      print("❌ _syncCurrentOfflineOrder error: $e");
      print(stack);
    } finally {
      _isOrderSyncInProgress = false;
      _activeSyncOrderKey = null;
      _lastSyncedOrderKey = orderKey;
      _lastOrderSyncAt = DateTime.now();
    }
  }

  void _showPaymentDialog(
      BuildContext context,
      double amount, {
        double? changeAmount,
        required bool showChange,
        Map<String, dynamic>? couponResponse,
        bool isVoidDisabled = false,
      }) async {
    if (_isShowingPaymentDialog) {
      print("Payment dialog already showing → skipping duplicate call");
      return;
    }

    _isShowingPaymentDialog = true;

    final storeInfo = PinakaPreferences.getLoggedInStore();

    // ── Helper: update customer display ──────────────────────
    Future<void> updateCustomerDisplayWelcome() async {
      try {
        if (storeInfo.isNotEmpty) {
          await CustomerDisplayHelper.updateWelcomeWithStore(
            storeInfo['storeId'] ?? '0',
            storeInfo['storeName'] ?? 'Store',
            storeLogoUrl: storeInfo['storeLogoUrl'] ?? '',
            storeBaseUrl: storeInfo['storeBaseUrl'] ?? '',
          );
        } else {
          await CustomerDisplayService.showWelcome();
        }
      } catch (e) {
        print(">>> Error updating customer display: $e");
      }
    }

    // ── Check if this is a negative/payout order ─────────────
    final bool isNegativeOrder = computedNetPayable <= 0;

    // ── Helper: mark order completed in Hive ─────────────────
    Future<void> forceMarkHiveOrderCompleted() async {
      try {
        final box = StorageProvider.offlineOrders;
        final String key = (orderId ?? 0).toString();
        if (!(await box.containsKey(key))) return;

        final raw = await box.get(key);
        final order = Map<String, dynamic>.from(raw is Map ? raw : {});

        order['order_status'] = 'completed'; // force completed
        order['updated_at'] = DateTime.now().toIso8601String();

        await box.put(key, order);
        if (orderId != null && orderId! > 0) {
          await OfflineHelper.updateOfflineOrderStatus(orderId!, 'completed', paymentMethod: selectedPaymentMethod);
        }
        print("✅ Hive & SQLite order #$orderId force-marked as completed");
      } catch (e) {
        print("❌ forceMarkHiveOrderCompleted error: $e");
      }
    }

    /// MQTT only: Thank You → Welcome (store name). Clears old cart on CFD.

    // ── Helper: background work (non-blocking) ───────────────
    void doBackgroundWork() {
      unawaited(orderHelper.setActiveOrder(null));
      unawaited(orderHelper.clearPersistedCartSelection());

      Future(() async {
        if (orderId != null && orderId! > 0) {
          final allPayments = await LocalPaymentDBHelper.instance
              .getPaymentsByOrderId(orderId!);

          final bool isNegativeOrder = computedNetPayable <= 0;

          for (final p in allPayments) {
            if (p.status == PaymentDbStatus.pending) {
              if (p.amount > 0 || isNegativeOrder) {
                await LocalPaymentDBHelper.instance
                    .updateStatus(p.id, PaymentDbStatus.completed);
                print(" Completed payment ID ${p.id} "
                    "amount:\$${p.amount} isNegativeOrder:$isNegativeOrder");
              }
            }
          }
        }

        // ✅ CRITICAL FIX: Update Hive with latest merchant discount values BEFORE sync
        await _updateHiveWithLatestMerchantDiscount();

        // Sync to backend (your original unchanged _syncCurrentOfflineOrder)
        try {
          await _syncCurrentOfflineOrder();
          print("✅ doBackgroundWork: sync done");
        } catch (e) {
          print("❌ doBackgroundWork: sync failed: $e");
        }

        // MQTT: Thank You → Welcome after full payment path
        try {
          // Capture messaging before async gap if needed – or call helper
          // Helper uses context; if called from Future after navigate, prefer inline publish.
          final store = await CfdStorePayload.load();
          final messaging =
          Provider.of<StoreMessagingService>(context, listen: false);

          final thankYou = CartState(
            sessionId: 'ORDER-${orderId ?? 0}',
            sequence: CfdSequence.next(),
            screen: 'THANK_YOU',
            items: const [],
            tax: 0,
            message: null,
            orderId: orderId,
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
          await messaging.publishState(thankYou);

          await Future.delayed(const Duration(seconds: 3));

          final welcome = CartState(
            sessionId: 'ORDER-0',
            sequence: CfdSequence.next(),
            screen: 'WELCOME',
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
          await messaging.publishState(welcome);
        } catch (e) {
          if (kDebugMode) print('⚠️ MQTT thank-you/welcome failed: $e');
        }
      });
    }

    // try {
    //   await CustomerDisplayService.showThankYou();
    // } catch (e) {
    //   print(">>> Error showing Thank You screen: $e");
    // }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogCtx) => PaymentDialog(
        status: PaymentStatus.successful,
        mode: _currentDialogPaymentMode(),
        amount: amount,
        changeAmount: showChange ? changeAmount : null,
        couponResponse: couponResponse,
        isVoidDisabled: isVoidDisabled,

        // ── VOID ─────────────────────────────────────────────
        onVoid: () async {
          Navigator.of(dialogCtx, rootNavigator: false).pop();

          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!_isShowingPartialDialog) {
              showVoidExitConfirmation(context, false);
            }
          });
        },
        // ── NO RECEIPT ───────────────────────────────────────
        onNoReceipt: () async {
          try {
            await CustomerDisplayService.showThankYou();
          } catch (e) {
            print(">>> Error showing Thank You screen: $e");
          }

          Navigator.of(dialogCtx, rootNavigator: false).pop();

          doBackgroundWork();

          OrderHelper.isOrderPanelLoaded = false;
          OrderHelper.notifyOrderPanelToRefresh();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => POSHomeScreen()),
            result: TextConstants.refresh,
          );
        },

        // ── DONE (Print / Email / SMS) ────────────────────────
        onDone: (selectedOption, {String? email}) async {
          try {
            await CustomerDisplayService.showThankYou();
          } catch (e) {
            print(">>> Error showing Thank You screen: $e");
          }

          print("onDone → $selectedOption, email=$email");

          // ── EMAIL ────────────────────────────────────────────
          if (selectedOption == TextConstants.email &&
              email != null &&
              email.isNotEmpty) {
            Navigator.of(dialogCtx, rootNavigator: false).pop();

            if (orderId == null || orderId == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TextConstants.canNotSendEmail),
                  backgroundColor: Colors.red,
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            } else {
              paymentBloc.sendOrderDetails(orderId!, email);

              StreamSubscription? subscription;
              subscription =
                  paymentBloc.sendOrderDetailsStream.listen((response) {
                    subscription?.cancel();
                    print(">>> Email sent");
                  });
            }

            doBackgroundWork();

            OrderHelper.isOrderPanelLoaded = false;
            OrderHelper.notifyOrderPanelToRefresh();

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => POSHomeScreen()),
              result: TextConstants.refresh,
            );
            return;
          }

          // ── PRINT ─────────────────────────────────────────────
          Navigator.of(dialogCtx, rootNavigator: false).pop();

          if (selectedOption == TextConstants.print && !Misc.disablePrinter) {
            Future(() async {
              await _preparePrintTicket();
              await _printTicket(manual: true);
            });
          }

          doBackgroundWork();

          OrderHelper.isOrderPanelLoaded = false;
          OrderHelper.notifyOrderPanelToRefresh();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => POSHomeScreen()),
            result: TextConstants.refresh,
          );
        },
      ),
    ).then((_) {
      _isShowingPaymentDialog = false;
      print("Payment dialog closed → guard reset");
    });
  }

// ============================================================
// ALSO REPLACE _showPartialPaymentDialog with immediate close on Next Payment
// ============================================================

  // Future<void> _showPartialPaymentDialog(BuildContext context, double amount) async {
  //   if (_isShowingPartialDialog) {
  //     print("Partial dialog already showing → skipping duplicate call");
  //     return;
  //   }
  //   _isShowingPartialDialog = true;
  //
  //   final double remainingToShow = _currentPaymentRemainingBalance ?? balanceAmount;
  //   print("Showing Partial Payment Dialog → amount: $amount | remaining: $remainingToShow");
  //
  //   await showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (dialogCtx) => PaymentDialog(
  //       status: PaymentStatus.partial,
  //       mode: PaymentMode.cash,
  //       amount: amount,
  //       remainingBalance: remainingToShow,
  //
  //       onVoid: () async {
  //         // ✅ Close immediately
  //         Navigator.of(dialogCtx, rootNavigator: false).pop();
  //         _isShowingPartialDialog = false;
  //
  //         await _showVoidConfirmation(context, isPartial: true);
  //       },
  //
  //       onNextPayment: () {
  //         // ✅ Close immediately — no async work needed
  //         Navigator.of(dialogCtx, rootNavigator: false).pop();
  //         print("Next Payment tapped → partial dialog closed");
  //       },
  //     ),
  //   );
  //
  //   _isShowingPartialDialog = false;
  //   print("Partial dialog closed → guard reset");
  // }

/////impo

  // void showVoidExitConfirmation(BuildContext context, bool isPartial) {
  //   print("showVoidExitConfirmation → isPartial: $isPartial");
  //
  //   if (_isVoiding) {
  //     print("Void already in progress → skipping");
  //     return;
  //   }
  //   _isVoiding = true;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     useRootNavigator: false,
  //     builder: (dialogCtx) => PaymentDialog.voidConfirmation(
  //
  //       onVoidCancel: () {
  //         // ✅ Close dialog IMMEDIATELY
  //         Navigator.of(dialogCtx, rootNavigator: false).pop();
  //         _isVoiding = false;
  //
  //         // Do background work (mark payments completed + sync) without blocking
  //         Future(() async {
  //           if (orderId != null && orderId! > 0) {
  //             int retries = 3;
  //             while (retries > 0) {
  //               final payments = await LocalPaymentDBHelper.instance
  //                   .getPaymentsByOrderId(orderId!);
  //               final pendingPayments = payments
  //                   .where((p) => p.amount > 0 && p.status == PaymentDbStatus.pending)
  //                   .toList();
  //               if (pendingPayments.isNotEmpty) {
  //                 for (final p in pendingPayments) {
  //                   await LocalPaymentDBHelper.instance.updateStatus(
  //                     p.id,
  //                     PaymentDbStatus.completed,
  //                   );
  //                 }
  //                 print("✅ Background: Marked ${pendingPayments.length} payments as completed");
  //
  //                 // Sync after marking complete
  //                 try {
  //                   await _syncCurrentOfflineOrder();
  //                 } catch (e) {
  //                   print("❌ Background sync failed: $e");
  //                 }
  //
  //                 if (mounted) {
  //                   OrderHelper.isOrderPanelLoaded = false;
  //                   OrderHelper.notifyOrderPanelToRefresh();
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(builder: (_) => POSHomeScreen()),
  //                     result: TextConstants.refresh,
  //                   );
  //                 }
  //                 return;
  //               }
  //               retries--;
  //               if (retries > 0) await Future.delayed(const Duration(milliseconds: 200));
  //             }
  //           }
  //         });
  //       },
  //
  //       onVoidConfirm: () async {
  //         // ✅ Close dialog IMMEDIATELY
  //         Navigator.of(dialogCtx, rootNavigator: false).pop();
  //         _isVoiding = false;
  //
  //         if (_lastPayment == null) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text("No payment to void")),
  //           );
  //           return;
  //         }
  //
  //         final method = _lastPayment!.method.toLowerCase();
  //
  //         if (method == TextConstants.card.toLowerCase() &&
  //             _lastPayment!.sunmiTxnId != null &&
  //             _lastPayment!.sunmiOrderId != null) {
  //           await _openSunmiVoidScreen(
  //             amount: _lastPayment!.amount,
  //             orderId: _lastPayment!.sunmiOrderId!,
  //             originTransactionId: _lastPayment!.sunmiTxnId!,
  //           );
  //         } else {
  //           await _handleVoidPayment(context, isPartial: isPartial);
  //         }
  //
  //         print("Void completed – staying on OrderSummaryScreen");
  //         if (mounted) setState(() {});
  //       },
  //     ),
  //   );
  // }

////

  void showVoidExitConfirmation(BuildContext context, bool isPartial) {
    print("showVoidExitConfirmation → isPartial: $isPartial");

    if (_isVoiding) {
      print("Void already in progress → skipping");
      return;
    }
    _isVoiding = true;

    // ✅ CAPTURE these BEFORE showing dialog (dialog context won't have them)
    final double capturedAmount = tenderAmount;
    final double capturedChange = changeAmount;
    final bool capturedShowChange = changeAmount > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogCtx) => PaymentDialog.voidConfirmation(
        onVoidCancel: () {
          // ✅ STEP 1: Close void confirmation dialog IMMEDIATELY
          Navigator.of(dialogCtx, rootNavigator: false).pop();
          _isVoiding = false;

          // ✅ STEP 2: Re-show the payment success dialog
          // Small delay to let void dialog fully close first
          Future.delayed(const Duration(milliseconds: 100), () async {
            if (!mounted) return;

            // Get coupon response from Hive
            final box = StorageProvider.offlineOrders;
            final key = (orderId ?? 0).toString();
            final raw = await box.get(key);
            final cr = raw is Map ? raw["coupon_response"] : null;
            final couponResponse =
            cr is Map ? Map<String, dynamic>.from(cr) : <String, dynamic>{};

            // ✅ Re-show payment success popup
            _showPaymentDialog(
              context,
              capturedAmount,
              changeAmount: capturedChange,
              showChange: capturedShowChange,
              couponResponse: couponResponse,
              isVoidDisabled: true, // Disable void button when returning
            );
          });

          // ✅ STEP 3: Background sync only (NO navigation)
          Future(() async {
            if (orderId != null && orderId! > 0) {
              int retries = 3;
              while (retries > 0) {
                final payments = await LocalPaymentDBHelper.instance
                    .getPaymentsByOrderId(orderId!);

                final bool isNegativeOrder = computedNetPayable <= 0;

                final pendingPayments = payments
                    .where((p) =>
                p.status == PaymentDbStatus.pending &&
                    (p.amount > 0 || isNegativeOrder))
                    .toList();

                if (pendingPayments.isNotEmpty) {
                  for (final p in pendingPayments) {
                    await LocalPaymentDBHelper.instance
                        .updateStatus(p.id, PaymentDbStatus.completed);
                  }
                  print(
                      "✅ Background: Marked ${pendingPayments.length} payments completed");
                  break;
                }
                retries--;
                if (retries > 0) {
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
            try {
              await _syncCurrentOfflineOrder();
              print("✅ Background: Sync done after void cancel");
            } catch (e) {
              print("❌ Background sync failed: $e");
            }
          });
        },
        onVoidConfirm: () async {
          //  Close dialog IMMEDIATELY
          Navigator.of(dialogCtx, rootNavigator: false).pop();
          _isVoiding = false;

          if (_lastPayment == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No payment to void")),
            );
            return;
          }

          final method = _lastPayment!.method.toLowerCase();

          if (method == TextConstants.card.toLowerCase() &&
              _lastPayment!.sunmiTxnId != null &&
              _lastPayment!.sunmiOrderId != null) {
            await _openSunmiVoidScreen(
              amount: _lastPayment!.amount,
              orderId: _lastPayment!.sunmiOrderId!,
              originTransactionId: _lastPayment!.sunmiTxnId!,
            );
          } else {
            await _handleVoidPayment(context, isPartial: isPartial);
          }

          print("Void completed – staying on OrderSummaryScreen");
          if (mounted) setState(() {});
        },
      ),
    ).then((_) {
      if (mounted) _isVoiding = false;
    });
  }

  // void showVoidExitConfirmation(BuildContext context, bool isPartial) {
  //   print("showVoidExitConfirmation → isPartial: $isPartial, orderId: $orderId");
  //
  //   if (_isVoiding) {
  //     print("Void already in progress → skipping");
  //     return;
  //   }
  //   _isVoiding = true;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     useRootNavigator: false,
  //     builder: (dialogCtx) => PaymentDialog.voidConfirmation(
  //
  //       onVoidCancel: () async {
  //         print("❌ VOID CANCELED BY USEeeeR");
  //
  //         bool updatedAny = false;
  //
  //         // --- 1. Mark all pending payments as completed locally ---
  //         if (orderId != null && orderId! > 0) {
  //           int retries = 3;
  //           while (retries > 0) {
  //             final payments = await LocalPaymentDBHelper.instance
  //                 .getPaymentsByOrderId(orderId!);
  //             final pendingPayments = payments
  //                 .where((p) => p.amount > 0 && p.status == PaymentDbStatus.pending)
  //                 .toList();
  //
  //             if (pendingPayments.isNotEmpty) {
  //               for (final p in pendingPayments) {
  //                 await LocalPaymentDBHelper.instance.updateStatus(
  //                   p.id,
  //                   PaymentDbStatus.completed,
  //                 );
  //               }
  //               print("✅ Marked ${pendingPayments.length} payments as completed");
  //               updatedAny = true;
  //               break;
  //             } else {
  //               retries--;
  //               if (retries > 0) {
  //                 print("⏳ No pending payments found, retrying... ($retries left)");
  //                 await Future.delayed(const Duration(milliseconds: 200));
  //               }
  //             }
  //           }
  //
  //         }
  //
  //         // --- 2. Sync the updated order to the backend ---
  //         if (updatedAny && mounted) {
  //           try {
  //             await _syncCurrentOfflineOrder(); // This sends the order and completed payments to Woo
  //             print("✅ Order synced to backend after completing pending payments");
  //           } catch (e) {
  //             print("❌ Failed to sync order: $e");
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text("Order completed locally but sync failed: $e"),
  //                 backgroundColor: Colors.orange,
  //               ),
  //             );
  //           }
  //         }
  //
  //
  //         // --- 3. Close the confirmation dialog (after all async work) ---
  //         // Navigator.of(dialogCtx, rootNavigator: false).pop();
  //         _isVoiding = false;
  //
  //         // --- 4. Navigate to home screen only if payments were updated ---
  //         if (updatedAny && mounted) {
  //           OrderHelper.isOrderPanelLoaded = false;
  //           OrderHelper.notifyOrderPanelToRefresh();
  //           Navigator.pop(context);
  //
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (_) => POSHomeScreen()),
  //             result: TextConstants.refresh,
  //           );
  //
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(
  //               content: Text("Payments completed and order finalized"),
  //               backgroundColor: Colors.green,
  //               duration: Duration(seconds: 2),
  //             ),
  //           );
  //         }
  //       },
  //
  //       onVoidConfirm: () async {
  //         // (unchanged – handles actual void)
  //         print("✅ VOID CONFIRMED");
  //         Navigator.of(dialogCtx, rootNavigator: false).pop();
  //
  //         if (_lastPayment == null) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text("No payment to void")),
  //           );
  //           _isVoiding = false;
  //           return;
  //         }
  //
  //         final method = _lastPayment!.method.toLowerCase();
  //
  //         if (method == TextConstants.card.toLowerCase() &&
  //             _lastPayment!.sunmiTxnId != null &&
  //             _lastPayment!.sunmiOrderId != null) {
  //           await _openSunmiVoidScreen(
  //             amount: _lastPayment!.amount,
  //             orderId: _lastPayment!.sunmiOrderId!,
  //             originTransactionId: _lastPayment!.sunmiTxnId!,
  //           );
  //         } else {
  //           await _handleVoidPayment(context, isPartial: isPartial);
  //         }
  //
  //         print("${isPartial ? 'Partial' : 'Full'} payment voided → staying on OrderSummaryScreen");
  //
  //         if (mounted) {
  //           setState(() {});
  //         }
  //
  //         _isVoiding = false;
  //       },
  //     ),
  //   );
  // }

  // ============================================================
// REPLACE your _showExitPaymentConfirmation method with this
// KEY FIX: Navigate IMMEDIATELY, sync in background
// ============================================================

  void _showExitPaymentConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogCtx) => PaymentDialog(
        status: PaymentStatus.exitConfirmation,
        onExitCancel: () {
          if (Navigator.of(dialogCtx).canPop()) {
            Navigator.of(dialogCtx).pop();
          }
        },
        onExitConfirm: () async {
          // Close popup
          if (Navigator.of(dialogCtx).canPop()) {
            Navigator.of(dialogCtx).pop();
          }

          // Customer display
          try {
            await CustomerDisplayService.showThankYou();
          } catch (e) {
            print(">>> Error updating customer display: $e");
          }

          // ✅ Update Hive with latest merchant discount before sync
          await _updateHiveWithLatestMerchantDiscount();

          // Refresh order panel
          OrderHelper.isOrderPanelLoaded = false;
          OrderHelper.notifyOrderPanelToRefresh();

          // Navigate safely
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => POSHomeScreen(),
              ),
            );
          }

          // Background sync
          Future(() async {
            try {
              await _syncCurrentOfflineOrder();
              print("✅ Background: Exit sync completed");
            } catch (e) {
              print("❌ Background: Exit sync failed: $e");
            }
          });
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> loadPrinterData() async {
    var printerDB = await PrinterDBHelper().getPrinterFromDB();
    if (printerDB.isEmpty) {
      if (kDebugMode) {
        print(">>>>> OrderSummaryScreen : printerDB is empty");
      }
      return null;
    }
    return printerDB.first;
  }

//   Future _preparePrintTicket() async {
//     if (kDebugMode) {
//       print("OrderSummaryScreen _preparePrintTicket call print receipt");
//     }
//
//     var printerData = await loadPrinterData();
//     var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
//     var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
//     var logo = printerData?[AppDBConst.receiptIconPath] ?? "";
//
//     bytes = [];
//     final ticket = await _printerSettings.getTicket();
//
//     // -------------------------------
//     // LOGO (unchanged)
//     // -------------------------------
//     final ByteData data;
//     if (logo != "") {
//       data = await GlobalUtility.fileToByteData(File(logo)) ??
//           await rootBundle.load('assets/Bubbas_logo.png');
//     } else {
//       data = await rootBundle.load('assets/Bubbas_logo.png');
//     }
//
//     if (data.lengthInBytes > 0) {
//       final Uint8List imageBytes = data.buffer.asUint8List();
//       final decodedImage = img.decodeImage(imageBytes)!;
//       img.Image thumbnail = img.copyResize(decodedImage, height: 280);
//       img.Image originalImg =
//       img.copyResize(decodedImage, width: 470, height: 280);
//       img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
//       var padding = (originalImg.width - thumbnail.width) / 2;
//       drawImage(originalImg, thumbnail, dstX: padding.toInt());
//       var grayscaleImage = img.grayscale(originalImg);
//       // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
//     }
//
//     // -------------------------------
//     // HEADER & STORE INFO (unchanged)
//     // -------------------------------
//     var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
//     var storeId = "${merchantDetails?[AppDBConst.storeId]}";
//     var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
//
//     var storeDetails = await AssetDBHelper.instance.getStoreDetails();
//     var storeName = "${storeDetails?.name}";
//     var address = "${storeDetails?.address},";
//     var cityStateZip =
//         "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
//     var orderIdToPrint = '$orderId';
//
//     final userData = await UserDbHelper().getUserData();
//     var cashierName =
//         "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
//     var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
//
//     if (header != "") {
//       bytes += ticket.row([
//         PosColumn(
//             text: header, width: 12, styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//
//     bytes += ticket.row([
//       PosColumn(
//         text: "***** CUST-INVOICE *****",
//         width: 12,
//         styles: PosStyles(align: PosAlign.center, bold: true),
//       ),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(
//         text: storeName,
//         width: 12,
//         styles: PosStyles(
//           align: PosAlign.center,
//           bold: true,
//           height: PosTextSize.size2,
//           width: PosTextSize.size2,
//         ),
//       ),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(
//           text: address, width: 12, styles: PosStyles(align: PosAlign.center))
//     ]);
//     bytes += ticket.row([
//       PosColumn(
//           text: cityStateZip,
//           width: 12,
//           styles: PosStyles(align: PosAlign.center))
//     ]);
//     bytes += ticket.row([
//       PosColumn(
//           text: "Phone: $storePhone",
//           width: 12,
//           styles: PosStyles(align: PosAlign.center)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "Date: $_displayDate", width: 7),
//       PosColumn(text: "Time: $_displayTime", width: 5),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Cashier: $cashierName", width: 7),
//       PosColumn(text: "StoreID: $storeId", width: 5),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Role: $cashierRole", width: 7),
//       PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     // -------------------------------
//     // ITEM HEADER
//     // -------------------------------
//     bytes += ticket.row([
//       PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
//       PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
//       PosColumn(
//           text: "Qty",
//           width: 1,
//           styles: PosStyles(align: PosAlign.center, bold: true)),
//       PosColumn(
//           text: "Rate",
//           width: 2,
//           styles: PosStyles(align: PosAlign.right, bold: true)),
//       PosColumn(
//           text: "Amt",
//           width: 3,
//           styles: PosStyles(align: PosAlign.right, bold: true)),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     String formatCurrency(double amount) {
//       if (amount < 0) {
//         return "-${TextConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}";
//       } else {
//         return "${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}";
//       }
//     }
//
//     // -------------------------------
//     // ITEMS LOOP (with Combo Discount added)
//     // -------------------------------
//     // for (int i = 0; i < orderItems.length; i++) {
//     //   var item = orderItems[i];
//     //
//     //   String itemName = item['item_name'] ?? '';
//     //   double unitPrice = (item['item_price'] ?? 0).toDouble();
//     //   int qty = (item['items_count'] ?? 0).toInt();
//     //   double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
//     //   String type = item['item_type']?.toString().toLowerCase() ?? '';
//     //
//     //   // Hide merchant discount/discount line-items from print item list
//     //   final nameLower = itemName.toLowerCase();
//     //   if (type.contains('discount') ||
//     //       nameLower.contains('merchant discount')) {
//     //     continue;
//     //   }
//     //
//     //   bool isPayout = type.contains(TextConstants.payoutText);
//     //   bool isCoupon = type.contains(TextConstants.couponText);
//     //   bool isCashback = type.contains("cashback");
//     //   bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
//     //
//     //   String formattedRate = formatCurrency(unitPrice);
//     //   String formattedTotal = formatCurrency(lineTotal);
//     //
//     //   bytes += ticket.row([
//     //     PosColumn(text: "${i + 1}", width: 1),
//     //     PosColumn(text: itemName, width: 5),
//     //     PosColumn(
//     //         text: "$qty", width: 1, styles: PosStyles(align: PosAlign.center)),
//     //     PosColumn(
//     //         text: formattedRate,
//     //         width: 2,
//     //         styles: PosStyles(align: PosAlign.right)),
//     //     PosColumn(
//     //         text: formattedTotal,
//     //         width: 3,
//     //         styles: PosStyles(align: PosAlign.right)),
//     //   ]);
//     //
//     //   // ────────────────────────────────────────────────
//     //   // DISCOUNT EXTRACTION & PRINTING
//     //   // ────────────────────────────────────────────────
//     //   String discountType = item['discount_type']?.toString() ?? '';
//     //
//     //   double autoDiscount = (discountType.isEmpty || discountType == 'auto')
//     //       ? (item['auto_discount'] ?? 0).toDouble()
//     //       : 0.0;
//     //
//     //   double multipackDiscount = (discountType == 'multipack')
//     //       ? (item['auto_discount'] ?? 0).toDouble()
//     //       : 0.0;
//     //
//     //   double comboDiscount =
//     //   (discountType == 'combo' || discountType == 'mixmatch')
//     //       ? (item['auto_discount'] ?? 0).toDouble()
//     //       : 0.0;
//     //
//     //   // Auto Discount
//     //   if (autoDiscount > 0 && !isPayoutOrCoupon) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "Auto Discount", width: 9),
//     //       PosColumn(
//     //         text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}",
//     //         width: 3,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   // Combo / Mix & Match Discount
//     //   if (comboDiscount > 0 && !isPayoutOrCoupon) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "Combo Discount", width: 9),
//     //       PosColumn(
//     //         text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}",
//     //         width: 3,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   // Multipack Discount
//     //   if (multipackDiscount > 0 && !isPayoutOrCoupon) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "Multipack Discount", width: 9),
//     //       PosColumn(
//     //         text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}",
//     //         width: 3,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   bytes += ticket.emptyLines(1);
//     // }
//
//     // Prefer discount coming from GetOrderModel/API (json['discount']) for printing.
//     // Falls back to passed-in discountValue (offline) and finally the screen's discount.
//
//
//     // -------------------------------
//     // ITEMS LOOP (with Combo Discount added)
//     // -------------------------------
//     for (int i = 0; i < orderItems.length; i++) {
//       var item = orderItems[i];
//
//       String itemName = item['item_name'] ?? '';
//       double unitPrice = (item['item_price'] ?? 0).toDouble();
//       int qty = (item['items_count'] ?? 0).toInt();
//       double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
//       String type = item['item_type']?.toString().toLowerCase() ?? '';
//
//       // Hide merchant discount/discount line-items from print item list
//       final nameLower = itemName.toLowerCase();
//       if (type.contains('discount') ||
//           nameLower.contains('merchant discount')) {
//         continue;
//       }
//
//       bool isPayout = type.contains(TextConstants.payoutText);
//       bool isCoupon = type.contains(TextConstants.couponText);
//       bool isCashback = type.contains("cashback");
//       bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
//
//       // ── WEIGHTED ITEM DETECTION (same logic as UI) ──
//       final bool isWeightedItem = type.contains('weighted');
//
//       double weightQty = 0.0;
//       double weightUnitPrice = 0.0;
//       if (isWeightedItem) {
//         weightQty = (item['weight_qty'] ??
//             item['weightQty'] ??
//             item['weight'] ??
//             0.0).toDouble();
//         weightUnitPrice = (item['unit_price'] ??
//             item['regular_price'] ??
//             item['item_price'] ??
//             0.0).toDouble();
//       }
//
//       // ── FORMAT RATE & QTY/WEIGHT columns ──
//       String formattedQtyOrWeight;
//       String formattedRate;
//       String formattedTotal;
//
//       if (isWeightedItem && weightQty > 0 && weightUnitPrice > 0) {
//         // e.g.  "2.000lb"   "$2.99/lb"   "$5.98"
//         formattedQtyOrWeight = "${weightQty.toStringAsFixed(2)}lb";
//         formattedRate = "${formatCurrency(weightUnitPrice)}";
//         formattedTotal = formatCurrency(weightUnitPrice * weightQty);
//       } else {
//         formattedQtyOrWeight = "$qty";
//         formattedRate = formatCurrency(unitPrice);
//         formattedTotal = formatCurrency(lineTotal);
//       }
//
//       bytes += ticket.row([
//         PosColumn(text: "${i + 1}", width: 1),
//         PosColumn(text: itemName, width: 5),
//         PosColumn(
//             text: formattedQtyOrWeight,
//             width: 1,
//             styles: PosStyles(align: PosAlign.center)),
//         PosColumn(
//             text: formattedRate,
//             width: 2,
//             styles: PosStyles(align: PosAlign.right)),
//         PosColumn(
//             text: formattedTotal,
//             width: 3,
//             styles: PosStyles(align: PosAlign.right)),
//       ]);
//
//       // ────────────────────────────────────────────────
//       // DISCOUNT EXTRACTION & PRINTING (unchanged)
//       // ────────────────────────────────────────────────
//       String discountType = item['discount_type']?.toString() ?? '';
//
//       double autoDiscount = (discountType.isEmpty || discountType == 'auto')
//           ? (item['auto_discount'] ?? 0).toDouble()
//           : 0.0;
//
//       double multipackDiscount = (discountType == 'multipack')
//           ? (item['auto_discount'] ?? 0).toDouble()
//           : 0.0;
//
//       double comboDiscount =
//       (discountType == 'combo' || discountType == 'mixmatch')
//           ? (item['auto_discount'] ?? 0).toDouble()
//           : 0.0;
//
//       // Auto Discount
//       if (autoDiscount > 0 && !isPayoutOrCoupon) {
//         bytes += ticket.row([
//           PosColumn(text: "Auto Discount", width: 9),
//           PosColumn(
//             text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}",
//             width: 3,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       // Combo / Mix & Match Discount
//       if (comboDiscount > 0 && !isPayoutOrCoupon) {
//         bytes += ticket.row([
//           PosColumn(text: "Combo Discount", width: 9),
//           PosColumn(
//             text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}",
//             width: 3,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       // Multipack Discount
//       if (multipackDiscount > 0 && !isPayoutOrCoupon) {
//         bytes += ticket.row([
//           PosColumn(text: "Multipack Discount", width: 9),
//           PosColumn(
//             text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}",
//             width: 3,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       bytes += ticket.emptyLines(1);
//     }
//
//     final double discount = () {
//       final raw = _order["discount"] ??
//           _order["order_discount"] ??
//           _order["discount_amount"];
//       final parsed = raw == null ? null : double.tryParse(raw.toString());
//       final fromGetOrder =
//           parsed ?? (discountValue != 0 ? discountValue : null);
//       if (fromGetOrder == null) return this.discount;
//       return fromGetOrder != 0 ? -(fromGetOrder.abs()) : 0.0;
//     }();
//
//     // -------------------------------
//     // TOTALS (unchanged from your version)
//     // -------------------------------
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.grossTotal, width: 8),
//       PosColumn(
//         text: formatCurrency(grossTotal),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     // Show Coupon (standardized negative display)
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.discountText, width: 8),
//       PosColumn(
//         text: discount != 0 ? formatCurrency(discount) : formatCurrency(0.0),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.taxText, width: 8),
//       PosColumn(
//         text: formatCurrency(tax),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
// //Raghu--**
//     bytes += ticket.row([
//       PosColumn(
//         text: merchantDiscountPercentage > 0
//             ? '${TextConstants.merchantDiscount} (${merchantDiscountPercentage % 1 == 0 ? merchantDiscountPercentage.toStringAsFixed(0) : merchantDiscountPercentage.toStringAsFixed(1)}%)'
//             : TextConstants.merchantDiscount,
//         width: 8,
//       ),
//       PosColumn(
//         text: merchantDiscount != 0
//             ? formatCurrency(merchantDiscount)
//             : formatCurrency(0.0),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
// //Raghu--*
//
//     if (cashbackFee > 0) {
//       bytes += ticket.row([
//         PosColumn(text: TextConstants.cashbackFee, width: 8),
//         PosColumn(
//           text: formatCurrency(cashbackFee),
//           width: 4,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//       ]);
//     }
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.servicecharges, width: 8),
//       PosColumn(
//         text: formatCurrency(servicecharges),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     // Final Net Payable logic matching the summary screen precisely
//     double printNetPayable = grossTotal +
//         discount +
//         merchantDiscount +
//         tax +
//         servicecharges +
//         cashbackFee;
//     if (printNetPayable < 0) printNetPayable = 0.0;
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.netPayable, width: 8),
//       PosColumn(
//         text: formatCurrency(printNetPayable),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     if (redeemedValue > 0) {
//       bytes += ticket.row([
//         PosColumn(text: "Redeemed Amount", width: 8),
//         PosColumn(
//           text: "-${formatCurrency(redeemedValue).replaceAll('-', '')}",
//           width: 4,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//       ]);
//     }
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByCash, width: 8),
//       PosColumn(
//         text: formatCurrency(payByCash),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Pay by EBT", width: 8),
//       PosColumn(
//         text: formatCurrency(payByEbt),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByOther, width: 8),
//       PosColumn(
//         text: formatCurrency(payByOther),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.tenderAmount, width: 8),
//       PosColumn(
//         text: formatCurrency(tenderAmount),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.change, width: 8),
//       PosColumn(
//         text: formatCurrency(changeAmount),
//         width: 4,
//         styles: PosStyles(align: PosAlign.right),
//       ),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     if (footer != "") {
//       bytes += ticket.feed(1);
//       bytes += ticket.row([
//         PosColumn(
//             text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//   }


  // Future _preparePrintTicket() async {
  //   if (kDebugMode) {
  //     print("OrderSummaryScreen _preparePrintTicket call print receipt");
  //   }
  //
  //   var printerData = await loadPrinterData();
  //   var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
  //   var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
  //   var logo = printerData?[AppDBConst.receiptIconPath] ?? "";
  //
  //   bytes = [];
  //   final ticket = await _printerSettings.getTicket();
  //
  //   // -------------------------------
  //   // LOGO (unchanged)
  //   // -------------------------------
  //   final ByteData data;
  //   if (logo != "") {
  //     data = await GlobalUtility.fileToByteData(File(logo)) ??
  //         await rootBundle.load('assets/Bubbas_logo.png');
  //   } else {
  //     data = await rootBundle.load('assets/Bubbas_logo.png');
  //   }
  //
  //   if (data.lengthInBytes > 0) {
  //     final Uint8List imageBytes = data.buffer.asUint8List();
  //     final decodedImage = img.decodeImage(imageBytes)!;
  //     img.Image thumbnail = img.copyResize(decodedImage, height: 280);
  //     img.Image originalImg =
  //     img.copyResize(decodedImage, width: 470, height: 280);
  //     img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
  //     var padding = (originalImg.width - thumbnail.width) / 2;
  //     drawImage(originalImg, thumbnail, dstX: padding.toInt());
  //     var grayscaleImage = img.grayscale(originalImg);
  //     // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
  //   }
  //
  //   // -------------------------------
  //   // HEADER & STORE INFO (unchanged)
  //   // -------------------------------
  //   var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
  //   var storeId = "${merchantDetails?[AppDBConst.storeId]}";
  //   var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
  //
  //   var storeDetails = await AssetDBHelper.instance.getStoreDetails();
  //   var storeName = "${storeDetails?.name}";
  //   var address = "${storeDetails?.address},";
  //   var cityStateZip =
  //       "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
  //   var orderIdToPrint = '$orderId';
  //
  //   final userData = await UserDbHelper().getUserData();
  //   var cashierName =
  //       "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
  //   var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
  //
  //   if (header != "") {
  //     bytes += ticket.row([
  //       PosColumn(
  //           text: header, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: "***** CUST-INVOICE *****",
  //       width: 12,
  //       styles: PosStyles(align: PosAlign.center, bold: true),
  //     ),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: storeName,
  //       width: 12,
  //       styles: PosStyles(
  //         align: PosAlign.center,
  //         bold: true,
  //         height: PosTextSize.size2,
  //         width: PosTextSize.size2,
  //       ),
  //     ),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: address, width: 12, styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: cityStateZip,
  //         width: 12,
  //         styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "Phone: $storePhone",
  //         width: 12,
  //         styles: PosStyles(align: PosAlign.center)),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Date: $_displayDate", width: 7),
  //     PosColumn(text: "Time: $_displayTime", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Cashier: $cashierName", width: 7),
  //     PosColumn(text: "StoreID: $storeId", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Role: $cashierRole", width: 7),
  //     PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // -------------------------------
  //   // ITEM HEADER
  //   // -------------------------------
  //   bytes += ticket.row([
  //     PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
  //     PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
  //     PosColumn(
  //         text: "Qty",
  //         width: 1,
  //         styles: PosStyles(align: PosAlign.center, bold: true)),
  //     PosColumn(
  //         text: "Rate",
  //         width: 2,
  //         styles: PosStyles(align: PosAlign.right, bold: true)),
  //     PosColumn(
  //         text: "Amt",
  //         width: 3,
  //         styles: PosStyles(align: PosAlign.right, bold: true)),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   String formatCurrency(double amount) {
  //     if (amount < 0) {
  //       return "-${TextConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}";
  //     } else {
  //       return "${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}";
  //     }
  //   }
  //
  //   // Helper function to wrap long item names
  //   List<String> wrapItemName(String name, int maxLength) {
  //     List<String> lines = [];
  //     String remaining = name;
  //
  //     while (remaining.isNotEmpty) {
  //       if (remaining.length <= maxLength) {
  //         lines.add(remaining);
  //         break;
  //       } else {
  //         // Find a good break point (space) within the maxLength
  //         int breakIndex = remaining.lastIndexOf(' ', maxLength);
  //         if (breakIndex == -1) {
  //           // No space found, force break at maxLength
  //           breakIndex = maxLength;
  //         }
  //         lines.add(remaining.substring(0, breakIndex));
  //         remaining = remaining.substring(breakIndex).trim();
  //       }
  //     }
  //     return lines;
  //   }
  //
  //   // -------------------------------
  //   // ITEMS LOOP (with Weighted Item support + Name Wrapping)
  //   // -------------------------------
  //   for (int i = 0; i < orderItems.length; i++) {
  //     var item = orderItems[i];
  //
  //     String itemName = item['item_name'] ?? '';
  //     double unitPrice = (item['item_price'] ?? 0).toDouble();
  //     int qty = (item['items_count'] ?? 0).toInt();
  //     double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
  //     String type = item['item_type']?.toString().toLowerCase() ?? '';
  //
  //     // Hide merchant discount/discount line-items from print item list
  //     final nameLower = itemName.toLowerCase();
  //     if (type.contains('discount') ||
  //         nameLower.contains('merchant discount')) {
  //       continue;
  //     }
  //
  //     bool isPayout = type.contains(TextConstants.payoutText);
  //     bool isCoupon = type.contains(TextConstants.couponText);
  //     bool isCashback = type.contains("cashback");
  //     bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
  //
  //     // ── WEIGHTED ITEM DETECTION ──
  //     final bool isWeightedItem = type.contains('weighted');
  //
  //     double weightQty = 0.0;
  //     double weightUnitPrice = 0.0;
  //     if (isWeightedItem) {
  //       weightQty = (item['weight_qty'] ??
  //           item['weightQty'] ??
  //           item['weight'] ??
  //           0.0).toDouble();
  //       weightUnitPrice = (item['unit_price'] ??
  //           item['regular_price'] ??
  //           item['item_price'] ??
  //           0.0).toDouble();
  //     }
  //
  //     // ── FORMAT QTY/WEIGHT ──
  //     String formattedQtyOrWeight;
  //     if (isWeightedItem && weightQty > 0) {
  //       formattedQtyOrWeight = "${weightQty.toStringAsFixed(2)}lb";
  //     } else {
  //       formattedQtyOrWeight = "$qty";
  //     }
  //
  //     // ── FORMAT RATE ──
  //     String formattedRate;
  //     if (isWeightedItem && weightUnitPrice > 0) {
  //       formattedRate = formatCurrency(weightUnitPrice);
  //     } else {
  //       formattedRate = formatCurrency(unitPrice);
  //     }
  //
  //     // ── FORMAT TOTAL ──
  //     String formattedTotal;
  //     if (isWeightedItem && weightQty > 0 && weightUnitPrice > 0) {
  //       formattedTotal = formatCurrency(weightUnitPrice * weightQty);
  //     } else {
  //       formattedTotal = formatCurrency(lineTotal);
  //     }
  //
  //     // ── WRAP LONG ITEM NAMES ──
  //     List<String> nameLines = wrapItemName(itemName, 18); // Max 18 chars per line
  //
  //     // Print first line with all details
  //     bytes += ticket.row([
  //       PosColumn(text: "${i + 1}", width: 1),
  //       PosColumn(text: nameLines[0], width: 5),
  //       PosColumn(
  //           text: formattedQtyOrWeight,
  //           width: 1,
  //           styles: PosStyles(align: PosAlign.center)),
  //       PosColumn(
  //           text: formattedRate,
  //           width: 2,
  //           styles: PosStyles(align: PosAlign.right)),
  //       PosColumn(
  //           text: formattedTotal,
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //
  //     // Print additional name lines (if any) with indentation
  //     for (int j = 1; j < nameLines.length; j++) {
  //       bytes += ticket.row([
  //         PosColumn(text: "", width: 1),           // Empty # column
  //         PosColumn(text: "  ${nameLines[j]}", width: 5), // Indented description
  //         PosColumn(text: "", width: 1),           // Empty qty
  //         PosColumn(text: "", width: 2),           // Empty rate
  //         PosColumn(text: "", width: 3),           // Empty amount
  //       ]);
  //     }
  //
  //     // ────────────────────────────────────────────────
  //     // DISCOUNT EXTRACTION & PRINTING (unchanged)
  //     // ────────────────────────────────────────────────
  //     String discountType = item['discount_type']?.toString() ?? '';
  //
  //     double autoDiscount = (discountType.isEmpty || discountType == 'auto')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //
  //     double multipackDiscount = (discountType == 'multipack')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //
  //     double comboDiscount =
  //     (discountType == 'combo' || discountType == 'mixmatch')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //
  //     // Auto Discount
  //     if (autoDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Auto Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //     }
  //
  //     // Combo / Mix & Match Discount
  //     if (comboDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Combo Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //     }
  //
  //     // Multipack Discount
  //     if (multipackDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Multipack Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //     }
  //
  //     bytes += ticket.emptyLines(1);
  //   }
  //
  //   final double discount = () {
  //     final raw = _order["discount"] ??
  //         _order["order_discount"] ??
  //         _order["discount_amount"];
  //     final parsed = raw == null ? null : double.tryParse(raw.toString());
  //     final fromGetOrder =
  //         parsed ?? (discountValue != 0 ? discountValue : null);
  //     if (fromGetOrder == null) return this.discount;
  //     return fromGetOrder != 0 ? -(fromGetOrder.abs()) : 0.0;
  //   }();
  //
  //   // -------------------------------
  //   // TOTALS (unchanged from your version)
  //   // -------------------------------
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.grossTotal, width: 8),
  //     PosColumn(
  //       text: formatCurrency(grossTotal),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   // Show Coupon (standardized negative display)
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.discountText, width: 8),
  //     PosColumn(
  //       text: discount != 0 ? formatCurrency(discount) : formatCurrency(0.0),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.taxText, width: 8),
  //     PosColumn(
  //       text: formatCurrency(tax),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: merchantDiscountPercentage > 0
  //           ? '${TextConstants.merchantDiscount} (${merchantDiscountPercentage % 1 == 0 ? merchantDiscountPercentage.toStringAsFixed(0) : merchantDiscountPercentage.toStringAsFixed(1)}%)'
  //           : TextConstants.merchantDiscount,
  //       width: 8,
  //     ),
  //     PosColumn(
  //       text: merchantDiscount != 0
  //           ? formatCurrency(merchantDiscount)
  //           : formatCurrency(0.0),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   if (cashbackFee > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: TextConstants.cashbackFee, width: 8),
  //       PosColumn(
  //         text: formatCurrency(cashbackFee),
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.servicecharges, width: 8),
  //     PosColumn(
  //       text: formatCurrency(servicecharges),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // Final Net Payable logic matching the summary screen precisely
  //   double printNetPayable = grossTotal +
  //       discount +
  //       merchantDiscount +
  //       tax +
  //       servicecharges +
  //       cashbackFee;
  //   if (printNetPayable < 0) printNetPayable = 0.0;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.netPayable, width: 8),
  //     PosColumn(
  //       text: formatCurrency(printNetPayable),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   if (redeemedValue > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Redeemed Amount", width: 8),
  //       PosColumn(
  //         text: "-${formatCurrency(redeemedValue).replaceAll('-', '')}",
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByCash, width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByCash),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Pay by EBT", width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByEbt),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByOther, width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByOther),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.tenderAmount, width: 8),
  //     PosColumn(
  //       text: formatCurrency(tenderAmount),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.change, width: 8),
  //     PosColumn(
  //       text: formatCurrency(changeAmount),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //
  //
  //   // ── NEW: Only print "Order Earned Points" when redeem/loyalty was active for this order ──
  //   final bool _shouldPrintEarnedPoints =
  //       isRedeemActive || redeemedValue > 0 || availablePoints > 0;
  //
  //   if (_shouldPrintEarnedPoints) {
  //     final int earnedPoints =
  //         (_order['total_loyalty_points'] as num?)?.toInt() ?? 0;
  //
  //     bytes += ticket.row([
  //       PosColumn(text: "Order Earned Points", width: 8),
  //       PosColumn(
  //         text: "$earnedPoints pts",
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //   }
  //
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   if (footer != "") {
  //     bytes += ticket.feed(1);
  //     bytes += ticket.row([
  //       PosColumn(
  //           text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  // }


  // Future _preparePrintTicket() async {
  //   if (kDebugMode) {
  //     print("═══════════════════════════════════════════════════════════");
  //     print("🖨️ ORDER SUMMARY SCREEN - PREPARE PRINT TICKET");
  //     print("═══════════════════════════════════════════════════════════");
  //     print("📋 Order ID: $orderId");
  //     print("📋 Offline Order ID: ${widget.offlineOrderId}");
  //     print("📋 Items Count: ${orderItems.length}");
  //     print("📋 Total Payable: ${computedNetPayable.toStringAsFixed(2)}");
  //     print("═══════════════════════════════════════════════════════════");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 1: LOAD PRINTER DATA
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   var printerData = await loadPrinterData();
  //   if (kDebugMode) {
  //     print("📦 Printer Data Loaded:");
  //     print("   Header: ${printerData?[AppDBConst.receiptHeaderText] ?? 'Not Set'}");
  //     print("   Footer: ${printerData?[AppDBConst.receiptFooterText] ?? 'Not Set'}");
  //     print("   Logo Path: ${printerData?[AppDBConst.receiptIconPath] ?? 'Not Set'}");
  //   }
  //
  //   var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
  //   var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
  //   var logo = printerData?[AppDBConst.receiptIconPath] ?? "";
  //
  //   bytes = [];
  //   final ticket = await _printerSettings.getTicket();
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 2: LOGO PROCESSING
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   if (kDebugMode) {
  //     print("🖼️ Processing Logo...");
  //   }
  //
  //   final ByteData data;
  //   if (logo != "") {
  //     if (kDebugMode) {
  //       print("   Logo path provided: $logo");
  //     }
  //     data = await GlobalUtility.fileToByteData(File(logo)) ??
  //         await rootBundle.load('assets/Bubbas_logo.png');
  //   } else {
  //     if (kDebugMode) {
  //       print("   Using default logo: assets/Bubbas_logo.png");
  //     }
  //     data = await rootBundle.load('assets/Bubbas_logo.png');
  //   }
  //
  //   if (data.lengthInBytes > 0) {
  //     final Uint8List imageBytes = data.buffer.asUint8List();
  //     final decodedImage = img.decodeImage(imageBytes)!;
  //     img.Image thumbnail = img.copyResize(decodedImage, height: 280);
  //     img.Image originalImg =
  //     img.copyResize(decodedImage, width: 470, height: 280);
  //     img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
  //     var padding = (originalImg.width - thumbnail.width) / 2;
  //     drawImage(originalImg, thumbnail, dstX: padding.toInt());
  //     var grayscaleImage = img.grayscale(originalImg);
  //     // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
  //     if (kDebugMode) {
  //       print("✅ Logo processed successfully");
  //     }
  //   } else {
  //     if (kDebugMode) {
  //       print("⚠️ Logo image has 0 bytes, skipping");
  //     }
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 3: STORE DETAILS - FIXED
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   if (kDebugMode) {
  //     print("🏪 Loading Store Details...");
  //   }
  //
  //   var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
  //   var storeId = "${merchantDetails?[AppDBConst.storeId] ?? 'N/A'}";
  //
  //   var storeDetails = await AssetDBHelper.instance.getStoreDetails();
  //
  //   String storePhone = "";
  //   if (storeDetails?.phoneNumber != null && storeDetails!.phoneNumber!.isNotEmpty) {
  //     storePhone = storeDetails.phoneNumber!;
  //   } else if (merchantDetails?[AppDBConst.storePhone] != null &&
  //       merchantDetails![AppDBConst.storePhone].toString().isNotEmpty) {
  //     storePhone = merchantDetails![AppDBConst.storePhone].toString();
  //   }
  //
  //   String storeName = storeDetails?.name?.isNotEmpty == true
  //       ? storeDetails!.name!
  //       : "Store Name";
  //
  //   String address = storeDetails?.address != null && storeDetails!.address!.isNotEmpty
  //       ? "${storeDetails.address},"
  //       : "";
  //
  //   String city = storeDetails?.city?.isNotEmpty == true ? storeDetails!.city! : "";
  //   String state = storeDetails?.state?.isNotEmpty == true ? storeDetails!.state! : "";
  //   String zip = storeDetails?.zipCode?.isNotEmpty == true ? storeDetails!.zipCode! : "";
  //
  //   List<String> locationParts = [];
  //   if (city.isNotEmpty) locationParts.add(city);
  //   if (state.isNotEmpty) locationParts.add(state);
  //   if (zip.isNotEmpty) locationParts.add(zip);
  //
  //   String cityStateZip = locationParts.isNotEmpty ? locationParts.join(", ") : "";
  //
  //   var orderIdToPrint = '$orderId';
  //
  //   if (kDebugMode) {
  //     print("   Store Name: $storeName");
  //     print("   Store ID: $storeId");
  //     print("   Store Phone: ${storePhone.isNotEmpty ? storePhone : 'Not Set'}");
  //     print("   Address: ${address.isNotEmpty ? address : 'Not Set'}");
  //     print("   City/State/Zip: ${cityStateZip.isNotEmpty ? cityStateZip : 'Not Set'}");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 4: USER/CASHIER DETAILS
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   final userData = await UserDbHelper().getUserData();
  //   var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
  //   var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
  //
  //   if (kDebugMode) {
  //     print("👤 Cashier Details:");
  //     print("   Name: $cashierName");
  //     print("   Role: $cashierRole");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 5: CUSTOMER CONTACT
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   String customerContact = "";
  //   try {
  //     final box = StorageProvider.offlineOrders;
  //     final String orderKey = widget.offlineOrderId?.toString() ??
  //         widget.orderId?.toString() ??
  //         orderId?.toString() ??
  //         "";
  //     if (orderKey.isNotEmpty) {
  //       if (kDebugMode) {
  //         print("🔍 Looking for customer contact in Hive key: $orderKey");
  //       }
  //       final rawOrder = await box.get(orderKey);
  //       if (rawOrder != null) {
  //         final order = Map<String, dynamic>.from(rawOrder);
  //         customerContact = order["loyaltyContact"]?.toString() ?? "";
  //         if (kDebugMode) {
  //           print("   Hive loyaltyContact: '$customerContact'");
  //         }
  //       } else {
  //         if (kDebugMode) {
  //           print("   No order found in Hive for key: $orderKey");
  //         }
  //       }
  //     }
  //
  //     if (customerContact.isEmpty) {
  //       customerContact = mobileController.text.trim();
  //       if (kDebugMode) {
  //         print("   Fallback to mobileController: '$customerContact'");
  //       }
  //     }
  //
  //     if (customerContact.isEmpty && loyaltyData != null) {
  //       customerContact = loyaltyData?["contact"]?.toString() ?? "";
  //       if (kDebugMode) {
  //         print("   Fallback to loyaltyData: '$customerContact'");
  //       }
  //     }
  //
  //     if (kDebugMode) {
  //       print("📞 FINAL Customer Contact: '${customerContact.isNotEmpty ? customerContact : 'Not Provided'}'");
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print("⚠️ Failed to get customer contact: $e");
  //     }
  //     customerContact = mobileController.text.trim();
  //     if (kDebugMode) {
  //       print("   Final fallback to mobileController: '$customerContact'");
  //     }
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 6: DATE AND TIME
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   if (kDebugMode) {
  //     print("📅 Date: $_displayDate");
  //     print("🕐 Time: $_displayTime");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 7: BUILD RECEIPT HEADER
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   if (kDebugMode) {
  //     print("📄 Building Receipt...");
  //     print("─────────────────────────────────────────────────────────────");
  //   }
  //
  //   if (header.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //     if (kDebugMode) {
  //       print("🏷️ Header: $header");
  //     }
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: "***** CUST-INVOICE *****",
  //       width: 12,
  //       styles: PosStyles(align: PosAlign.center, bold: true),
  //     ),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: storeName,
  //       width: 12,
  //       styles: PosStyles(
  //         align: PosAlign.center,
  //         bold: true,
  //         height: PosTextSize.size2,
  //         width: PosTextSize.size2,
  //       ),
  //     ),
  //   ]);
  //   if (kDebugMode) {
  //     print("🏪 Store: $storeName");
  //   }
  //
  //   bytes += ticket.feed(1);
  //
  //   if (address.isNotEmpty && address != "N/A") {
  //     bytes += ticket.row([
  //       PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //     if (kDebugMode) {
  //       print("📭 Address: $address");
  //     }
  //   }
  //
  //   if (cityStateZip.isNotEmpty && cityStateZip != "N/A") {
  //     bytes += ticket.row([
  //       PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //     if (kDebugMode) {
  //       print("📮 City/State/Zip: $cityStateZip");
  //     }
  //   }
  //
  //   if (storePhone.isNotEmpty && storePhone != "N/A") {
  //     bytes += ticket.row([
  //       PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //     if (kDebugMode) {
  //       print("📞 Store Phone: $storePhone");
  //     }
  //   }
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Date: $_displayDate", width: 7),
  //     PosColumn(text: "Time: $_displayTime", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Cashier: $cashierName", width: 7),
  //     PosColumn(text: "StoreID: $storeId", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Role: $cashierRole", width: 7),
  //     PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
  //   ]);
  //
  //   if (kDebugMode) {
  //     print("👤 Cashier: $cashierName");
  //     print("🏷️ Order ID: $orderIdToPrint");
  //   }
  //
  //   if (customerContact.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Customer: $customerContact", width: 12),
  //     ]);
  //     if (kDebugMode) {
  //       print("📞 Customer: $customerContact");
  //     }
  //   } else {
  //     if (kDebugMode) {
  //       print("📞 Customer: Not Provided");
  //     }
  //   }
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 8: ITEM HEADER
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   bytes += ticket.row([
  //     PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
  //     PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
  //     PosColumn(
  //         text: "Qty",
  //         width: 2,  // ← Increased for weight
  //         styles: PosStyles(align: PosAlign.center, bold: true)),
  //     PosColumn(
  //         text: "Rate",
  //         width: 2,
  //         styles: PosStyles(align: PosAlign.right, bold: true)),
  //     PosColumn(
  //         text: "Amt",
  //         width: 2,  // ← Adjusted to keep total 12
  //         styles: PosStyles(align: PosAlign.right, bold: true)),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   if (kDebugMode) {
  //     print("─────────────────────────────────────────────────────────────");
  //     print("🛒 ITEMS:");
  //     print("   # | Description | Qty | Rate | Amt");
  //     print("─────────────────────────────────────────────────────────────");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 9: FORMATTING HELPERS
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   String formatCurrency(double amount) {
  //     if (amount < 0) {
  //       return "-${TextConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}";
  //     } else {
  //       return "${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}";
  //     }
  //   }
  //
  //   List<String> wrapItemName(String name, int maxLength) {
  //     List<String> lines = [];
  //     String remaining = name;
  //
  //     while (remaining.isNotEmpty) {
  //       if (remaining.length <= maxLength) {
  //         lines.add(remaining);
  //         break;
  //       } else {
  //         int breakIndex = remaining.lastIndexOf(' ', maxLength);
  //         if (breakIndex == -1) {
  //           breakIndex = maxLength;
  //         }
  //         lines.add(remaining.substring(0, breakIndex));
  //         remaining = remaining.substring(breakIndex).trim();
  //       }
  //     }
  //     return lines;
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 10: ITEMS LOOP - FIXED FOR WEIGHTED ITEMS
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   int itemIndex = 0;
  //   double printedGrossTotal = 0.0;
  //   double printedTotalDiscount = 0.0;
  //
  //   for (int i = 0; i < orderItems.length; i++) {
  //     var item = orderItems[i];
  //
  //     String itemName = item['item_name'] ?? '';
  //     double unitPrice = (item['item_price'] ?? 0).toDouble();
  //     int qty = (item['items_count'] ?? 0).toInt();
  //     double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
  //     String type = item['item_type']?.toString().toLowerCase() ?? '';
  //
  //     final nameLower = itemName.toLowerCase();
  //     if (type.contains('discount') || nameLower.contains('merchant discount')) {
  //       if (kDebugMode) {
  //         print("   ⏭️ Skipping discount line: $itemName");
  //       }
  //       continue;
  //     }
  //
  //     bool isPayout = type.contains(TextConstants.payoutText);
  //     bool isCoupon = type.contains(TextConstants.couponText);
  //     bool isCashback = type.contains("cashback");
  //     bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
  //
  //     final bool isWeightedItem = type.contains('weighted');
  //
  //     double weightQty = 0.0;
  //     double weightUnitPrice = 0.0;
  //     if (isWeightedItem) {
  //       weightQty = (item['weight_qty'] ?? item['weightQty'] ?? item['weight'] ?? 0.0).toDouble();
  //       weightUnitPrice = (item['unit_price'] ?? item['regular_price'] ?? item['item_price'] ?? 0.0).toDouble();
  //     }
  //
  //     // FIXED: Weight on same line with proper spacing and wider column
  //     String formattedQtyOrWeight;
  //     if (isWeightedItem && weightQty > 0) {
  //       formattedQtyOrWeight = "${weightQty.toStringAsFixed(2)}lb";
  //     } else {
  //       formattedQtyOrWeight = "$qty";
  //     }
  //
  //     String formattedRate;
  //     if (isWeightedItem && weightUnitPrice > 0) {
  //       formattedRate = formatCurrency(weightUnitPrice);
  //     } else {
  //       formattedRate = formatCurrency(unitPrice);
  //     }
  //
  //     String formattedTotal;
  //     double displayTotal;
  //     if (isWeightedItem && weightQty > 0 && weightUnitPrice > 0) {
  //       displayTotal = weightUnitPrice * weightQty;
  //       formattedTotal = formatCurrency(displayTotal);
  //     } else {
  //       displayTotal = lineTotal;
  //       formattedTotal = formatCurrency(lineTotal);
  //     }
  //
  //     printedGrossTotal += displayTotal;
  //
  //     List<String> nameLines = wrapItemName(itemName, 18);
  //
  //     itemIndex++;
  //
  //     bytes += ticket.row([
  //       PosColumn(text: "$itemIndex", width: 1),
  //       PosColumn(text: nameLines[0], width: 5),
  //       PosColumn(
  //           text: formattedQtyOrWeight,
  //           width: 2,  // ← Changed from 1 to 2
  //           styles: PosStyles(align: PosAlign.center)),
  //       PosColumn(
  //           text: formattedRate,
  //           width: 2,
  //           styles: PosStyles(align: PosAlign.right)),
  //       PosColumn(
  //           text: formattedTotal,
  //           width: 2,  // ← Changed from 3 to 2
  //           styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //
  //     if (kDebugMode) {
  //       print("   $itemIndex | ${nameLines[0]} | $formattedQtyOrWeight | $formattedRate | $formattedTotal");
  //     }
  //
  //     for (int j = 1; j < nameLines.length; j++) {
  //       bytes += ticket.row([
  //         PosColumn(text: "", width: 1),
  //         PosColumn(text: "  ${nameLines[j]}", width: 5),
  //         PosColumn(text: "", width: 2),
  //         PosColumn(text: "", width: 2),
  //         PosColumn(text: "", width: 2),
  //       ]);
  //       if (kDebugMode) {
  //         print("     ${nameLines[j]}");
  //       }
  //     }
  //
  //     // Discount printing (unchanged)
  //     String discountType = item['discount_type']?.toString() ?? '';
  //     double autoDiscount = (discountType.isEmpty || discountType == 'auto')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //     double multipackDiscount = (discountType == 'multipack')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //     double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
  //         ? (item['auto_discount'] ?? 0).toDouble()
  //         : 0.0;
  //
  //     if (autoDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Auto Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //       printedTotalDiscount += autoDiscount;
  //     }
  //
  //     if (comboDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Combo Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //       printedTotalDiscount += comboDiscount;
  //     }
  //
  //     if (multipackDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Multipack Discount", width: 9),
  //         PosColumn(
  //           text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}",
  //           width: 3,
  //           styles: PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //       printedTotalDiscount += multipackDiscount;
  //     }
  //
  //     bytes += ticket.emptyLines(1);
  //   }
  //
  //   if (kDebugMode) {
  //     print("─────────────────────────────────────────────────────────────");
  //     print("📊 Item Totals:");
  //     print("   Gross Total (from items): ${formatCurrency(printedGrossTotal)}");
  //     print("   Total Discounts: ${formatCurrency(printedTotalDiscount)}");
  //     print("─────────────────────────────────────────────────────────────");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 11: DISCOUNT VALUE (Coupon / Order Level)
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   final double couponDiscountValue = () {
  //     final raw = _order["discount"] ??
  //         _order["order_discount"] ??
  //         _order["discount_amount"];
  //     final parsed = raw == null ? null : double.tryParse(raw.toString());
  //     final fromGetOrder =
  //         parsed ?? (discountValue != 0 ? discountValue : null);
  //     if (fromGetOrder == null) return this.discount;
  //     return fromGetOrder != 0 ? -(fromGetOrder.abs()) : 0.0;
  //   }();
  //
  //   if (kDebugMode) {
  //     print("🏷️ Coupon/Order Discount: ${formatCurrency(couponDiscountValue)}");
  //     print("📊 Merchant Discount: ${formatCurrency(merchantDiscount)}");
  //     print("📊 Tax: ${formatCurrency(tax)}");
  //     print("📊 Cashback Fee: ${formatCurrency(cashbackFee)}");
  //     print("📊 Redeemed Value: ${formatCurrency(redeemedValue)}");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 12: TOTALS SECTION
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   // Gross Total
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.grossTotal, width: 8),
  //     PosColumn(
  //       text: formatCurrency(grossTotal),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   // Coupon/Order Discount
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.discountText, width: 8),
  //     PosColumn(
  //       text: couponDiscountValue != 0 ? formatCurrency(couponDiscountValue) : formatCurrency(0.0),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   // Tax
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.taxText, width: 8),
  //     PosColumn(
  //       text: formatCurrency(tax),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   // Merchant Discount
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: merchantDiscountPercentage > 0
  //           ? '${TextConstants.merchantDiscount} (${merchantDiscountPercentage % 1 == 0 ? merchantDiscountPercentage.toStringAsFixed(0) : merchantDiscountPercentage.toStringAsFixed(1)}%)'
  //           : TextConstants.merchantDiscount,
  //       width: 8,
  //     ),
  //     PosColumn(
  //       text: merchantDiscount != 0
  //           ? formatCurrency(merchantDiscount)
  //           : formatCurrency(0.0),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   // Cashback Fee
  //   if (cashbackFee > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: TextConstants.cashbackFee, width: 8),
  //       PosColumn(
  //         text: formatCurrency(cashbackFee),
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //   }
  //
  //   // Service Charges
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.servicecharges, width: 8),
  //     PosColumn(
  //       text: formatCurrency(servicecharges),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 13: NET PAYABLE
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   double printNetPayable = grossTotal +
  //       couponDiscountValue +
  //       merchantDiscount +
  //       tax +
  //       servicecharges +
  //       cashbackFee;
  //   if (printNetPayable < 0) printNetPayable = 0.0;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.netPayable, width: 8),
  //     PosColumn(
  //       text: formatCurrency(printNetPayable),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right, bold: true),
  //     ),
  //   ]);
  //
  //   if (kDebugMode) {
  //     print("💰 Net Payable: ${formatCurrency(printNetPayable)}");
  //   }
  //
  //   // Redeemed Amount
  //   if (redeemedValue > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Redeemed Amount", width: 8),
  //       PosColumn(
  //         text: "-${formatCurrency(redeemedValue).replaceAll('-', '')}",
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //     if (kDebugMode) {
  //       print("🎯 Redeemed: -${formatCurrency(redeemedValue)}");
  //     }
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 14: PAYMENT BREAKDOWN
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByCash, width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByCash),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Pay by EBT", width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByEbt),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByOther, width: 8),
  //     PosColumn(
  //       text: formatCurrency(payByOther),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.tenderAmount, width: 8),
  //     PosColumn(
  //       text: formatCurrency(tenderAmount),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.change, width: 8),
  //     PosColumn(
  //       text: formatCurrency(changeAmount),
  //       width: 4,
  //       styles: PosStyles(align: PosAlign.right),
  //     ),
  //   ]);
  //
  //   if (kDebugMode) {
  //     print("💵 Payment Breakdown:");
  //     print("   Cash: ${formatCurrency(payByCash)}");
  //     print("   EBT: ${formatCurrency(payByEbt)}");
  //     print("   Other: ${formatCurrency(payByOther)}");
  //     print("   Tendered: ${formatCurrency(tenderAmount)}");
  //     print("   Change: ${formatCurrency(changeAmount)}");
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 15: LOYALTY/EARNED POINTS (only if redeem was used)
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   final bool shouldPrintEarnedPoints =
  //       isRedeemActive || redeemedValue > 0 || availablePoints > 0;
  //
  //   if (shouldPrintEarnedPoints) {
  //     final int earnedPoints =
  //         (_order['total_loyalty_points'] as num?)?.toInt() ?? 0;
  //
  //     bytes += ticket.row([
  //       PosColumn(text: "Order Earned Points", width: 8),
  //       PosColumn(
  //         text: "$earnedPoints pts",
  //         width: 4,
  //         styles: PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //
  //     if (kDebugMode) {
  //       print("⭐ Order Earned Points: $earnedPoints pts");
  //     }
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 16: FOOTER
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   if (footer.isNotEmpty) {
  //     bytes += ticket.feed(1);
  //     bytes += ticket.row([
  //       PosColumn(
  //           text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //     if (kDebugMode) {
  //       print("📝 Footer: $footer");
  //     }
  //   }
  //
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   // STEP 17: FINAL SUMMARY
  //   // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   if (kDebugMode) {
  //     print("═══════════════════════════════════════════════════════════");
  //     print("✅ RECEIPT PREPARED SUCCESSFULLY");
  //     print("═══════════════════════════════════════════════════════════");
  //     print("📊 Final Summary:");
  //     print("   Gross Total: ${formatCurrency(grossTotal)}");
  //     print("   Coupon Discount: ${formatCurrency(couponDiscountValue)}");
  //     print("   Merchant Discount: ${formatCurrency(merchantDiscount)}");
  //     print("   Tax: ${formatCurrency(tax)}");
  //     print("   Cashback Fee: ${formatCurrency(cashbackFee)}");
  //     print("   Net Payable: ${formatCurrency(printNetPayable)}");
  //     print("   Total Tendered: ${formatCurrency(tenderAmount)}");
  //     print("   Change: ${formatCurrency(changeAmount)}");
  //     if (customerContact.isNotEmpty) {
  //       print("   Customer: $customerContact");
  //     }
  //     print("═══════════════════════════════════════════════════════════");
  //     print("📋 Total bytes for print: ${bytes.length}");
  //     print("═══════════════════════════════════════════════════════════");
  //   }
  // }



  Future _preparePrintTicket() async {
    if (kDebugMode) {
      print("═══════════════════════════════════════════════════════════");
      print("🖨️ ORDER SUMMARY SCREEN - PREPARE PRINT TICKET");
      print("═══════════════════════════════════════════════════════════");
      print("📋 Order ID: $orderId");
      print("📋 Offline Order ID: ${widget.offlineOrderId}");
      print("📋 Items Count: ${orderItems.length}");
      print("📋 Total Payable: ${computedNetPayable.toStringAsFixed(2)}");
      print("═══════════════════════════════════════════════════════════");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 1: LOAD PRINTER DATA
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    var printerData = await loadPrinterData();
    if (kDebugMode) {
      print("📦 Printer Data Loaded:");
      print("   Header: ${printerData?[AppDBConst.receiptHeaderText] ?? 'Not Set'}");
      print("   Footer: ${printerData?[AppDBConst.receiptFooterText] ?? 'Not Set'}");
      print("   Logo Path: ${printerData?[AppDBConst.receiptIconPath] ?? 'Not Set'}");
    }

    var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
    var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
    var logo = printerData?[AppDBConst.receiptIconPath] ?? "";

    bytes = [];
    final ticket = await _printerSettings.getTicket();

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 2: LOGO PROCESSING
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (kDebugMode) {
      print("🖼️ Processing Logo...");
    }

    final ByteData data;
    if (logo != "") {
      if (kDebugMode) {
        print("   Logo path provided: $logo");
      }
      data = await GlobalUtility.fileToByteData(File(logo)) ??
          await rootBundle.load('assets/Bubbas_logo.png');
    } else {
      if (kDebugMode) {
        print("   Using default logo: assets/Bubbas_logo.png");
      }
      data = await rootBundle.load('assets/Bubbas_logo.png');
    }

    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes)!;
      img.Image thumbnail = img.copyResize(decodedImage, height: 280);
      img.Image originalImg =
      img.copyResize(decodedImage, width: 470, height: 280);
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;
      drawImage(originalImg, thumbnail, dstX: padding.toInt());
      var grayscaleImage = img.grayscale(originalImg);
      // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
      if (kDebugMode) {
        print("✅ Logo processed successfully");
      }
    } else {
      if (kDebugMode) {
        print("⚠️ Logo image has 0 bytes, skipping");
      }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 3: STORE DETAILS - FIXED
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (kDebugMode) {
      print("🏪 Loading Store Details...");
    }

    var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
    var storeId = "${merchantDetails?[AppDBConst.storeId] ?? 'N/A'}";

    var storeDetails = await AssetDBHelper.instance.getStoreDetails();

    String storePhone = "";
    if (storeDetails?.phoneNumber != null && storeDetails!.phoneNumber!.isNotEmpty) {
      storePhone = storeDetails.phoneNumber!;
    } else if (merchantDetails?[AppDBConst.storePhone] != null &&
        merchantDetails![AppDBConst.storePhone].toString().isNotEmpty) {
      storePhone = merchantDetails![AppDBConst.storePhone].toString();
    }

    String storeName = storeDetails?.name?.isNotEmpty == true
        ? storeDetails!.name!
        : "Store Name";

    String address = storeDetails?.address != null && storeDetails!.address!.isNotEmpty
        ? "${storeDetails.address},"
        : "";

    String city = storeDetails?.city?.isNotEmpty == true ? storeDetails!.city! : "";
    String state = storeDetails?.state?.isNotEmpty == true ? storeDetails!.state! : "";
    String zip = storeDetails?.zipCode?.isNotEmpty == true ? storeDetails!.zipCode! : "";

    List<String> locationParts = [];
    if (city.isNotEmpty) locationParts.add(city);
    if (state.isNotEmpty) locationParts.add(state);
    if (zip.isNotEmpty) locationParts.add(zip);

    String cityStateZip = locationParts.isNotEmpty ? locationParts.join(", ") : "";

    var orderIdToPrint = '$orderId';

    if (kDebugMode) {
      print("   Store Name: $storeName");
      print("   Store ID: $storeId");
      print("   Store Phone: ${storePhone.isNotEmpty ? storePhone : 'Not Set'}");
      print("   Address: ${address.isNotEmpty ? address : 'Not Set'}");
      print("   City/State/Zip: ${cityStateZip.isNotEmpty ? cityStateZip : 'Not Set'}");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 4: USER/CASHIER DETAILS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final userData = await UserDbHelper().getUserData();
    var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
    var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";

    if (kDebugMode) {
      print("👤 Cashier Details:");
      print("   Name: $cashierName");
      print("   Role: $cashierRole");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 5: CUSTOMER CONTACT
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    String customerContact = "";
    try {
      final box = StorageProvider.offlineOrders;
      final String orderKey = widget.offlineOrderId?.toString() ??
          widget.orderId?.toString() ??
          orderId?.toString() ??
          "";
      if (orderKey.isNotEmpty) {
        if (kDebugMode) {
          print("🔍 Looking for customer contact in Hive key: $orderKey");
        }
        final rawOrder = await box.get(orderKey);
        if (rawOrder != null) {
          final order = Map<String, dynamic>.from(rawOrder);
          customerContact = order["loyaltyContact"]?.toString() ?? "";
          if (kDebugMode) {
            print("   Hive loyaltyContact: '$customerContact'");
          }
        } else {
          if (kDebugMode) {
            print("   No order found in Hive for key: $orderKey");
          }
        }
      }

      if (customerContact.isEmpty) {
        customerContact = mobileController.text.trim();
        if (kDebugMode) {
          print("   Fallback to mobileController: '$customerContact'");
        }
      }

      if (customerContact.isEmpty && loyaltyData != null) {
        customerContact = loyaltyData?["contact"]?.toString() ?? "";
        if (kDebugMode) {
          print("   Fallback to loyaltyData: '$customerContact'");
        }
      }

      if (kDebugMode) {
        print("📞 FINAL Customer Contact: '${customerContact.isNotEmpty ? customerContact : 'Not Provided'}'");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Failed to get customer contact: $e");
      }
      customerContact = mobileController.text.trim();
      if (kDebugMode) {
        print("   Final fallback to mobileController: '$customerContact'");
      }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 6: DATE AND TIME
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (kDebugMode) {
      print("📅 Date: $_displayDate");
      print("🕐 Time: $_displayTime");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 7: BUILD RECEIPT HEADER
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (kDebugMode) {
      print("📄 Building Receipt...");
      print("─────────────────────────────────────────────────────────────");
    }

    if (header.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
      if (kDebugMode) {
        print("🏷️ Header: $header");
      }
    }

    bytes += ticket.row([
      PosColumn(
        text: "***** CUST-INVOICE *****",
        width: 12,
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(
        text: storeName,
        width: 12,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);
    if (kDebugMode) {
      print("🏪 Store: $storeName");
    }

    bytes += ticket.feed(1);

    if (address.isNotEmpty && address != "N/A") {
      bytes += ticket.row([
        PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
      ]);
      if (kDebugMode) {
        print("📭 Address: $address");
      }
    }

    if (cityStateZip.isNotEmpty && cityStateZip != "N/A") {
      bytes += ticket.row([
        PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
      ]);
      if (kDebugMode) {
        print("📮 City/State/Zip: $cityStateZip");
      }
    }

    if (storePhone.isNotEmpty && storePhone != "N/A") {
      bytes += ticket.row([
        PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
      if (kDebugMode) {
        print("📞 Store Phone: $storePhone");
      }
    }

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: "Date: $_displayDate", width: 7),
      PosColumn(text: "Time: $_displayTime", width: 5),
    ]);

    bytes += ticket.row([
      PosColumn(text: "Cashier: $cashierName", width: 7),
      PosColumn(text: "StoreID: $storeId", width: 5),
    ]);

    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7),
      PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
    ]);

    if (kDebugMode) {
      print("👤 Cashier: $cashierName");
      print("🏷️ Order ID: $orderIdToPrint");
    }

    if (customerContact.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: "Customer: $customerContact", width: 12),
      ]);
      if (kDebugMode) {
        print("📞 Customer: $customerContact");
      }
    } else {
      if (kDebugMode) {
        print("📞 Customer: Not Provided");
      }
    }

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 8: ITEM HEADER
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    bytes += ticket.row([
      PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
      PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
      PosColumn(
          text: "Qty",
          width: 2,  // ← Increased for weight
          styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(
          text: "Rate",
          width: 2,
          styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: "Amt",
          width: 2,  // ← Adjusted to keep total 12
          styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += ticket.feed(1);

    if (kDebugMode) {
      print("─────────────────────────────────────────────────────────────");
      print("🛒 ITEMS:");
      print("   # | Description | Qty | Rate | Amt");
      print("─────────────────────────────────────────────────────────────");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 9: FORMATTING HELPERS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    String formatCurrency(double amount) {
      if (amount < 0) {
        return "-${TextConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}";
      } else {
        return "${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}";
      }
    }

    List<String> wrapItemName(String name, int maxLength) {
      List<String> lines = [];
      String remaining = name;

      while (remaining.isNotEmpty) {
        if (remaining.length <= maxLength) {
          lines.add(remaining);
          break;
        } else {
          int breakIndex = remaining.lastIndexOf(' ', maxLength);
          if (breakIndex == -1) {
            breakIndex = maxLength;
          }
          lines.add(remaining.substring(0, breakIndex));
          remaining = remaining.substring(breakIndex).trim();
        }
      }
      return lines;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 10: ITEMS LOOP - FIXED FOR WEIGHTED ITEMS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    int itemIndex = 0;
    double printedGrossTotal = 0.0;
    double printedTotalDiscount = 0.0;

    for (int i = 0; i < orderItems.length; i++) {
      var item = orderItems[i];

      String itemName = item['item_name'] ?? '';
      double unitPrice = (item['item_price'] ?? 0).toDouble();
      int qty = (item['items_count'] ?? 0).toInt();
      double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
      String type = item['item_type']?.toString().toLowerCase() ?? '';

      final nameLower = itemName.toLowerCase();
      if (type.contains('discount') || nameLower.contains('merchant discount')) {
        if (kDebugMode) {
          print("   ⏭️ Skipping discount line: $itemName");
        }
        continue;
      }

      bool isPayout = type.contains(TextConstants.payoutText);
      bool isCoupon = type.contains(TextConstants.couponText);
      bool isCashback = type.contains("cashback");
      bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;

      final bool isWeightedItem = type.contains('weighted');

      double weightQty = 0.0;
      double weightUnitPrice = 0.0;
      if (isWeightedItem) {
        weightQty = (item['weight_qty'] ?? item['weightQty'] ?? item['weight'] ?? 0.0).toDouble();
        weightUnitPrice = (item['unit_price'] ?? item['regular_price'] ?? item['item_price'] ?? 0.0).toDouble();
      }

      // FIXED: Weight on same line with proper spacing and wider column
      String formattedQtyOrWeight;
      if (isWeightedItem && weightQty > 0) {
        formattedQtyOrWeight = "${weightQty.toStringAsFixed(2)}lb";
      } else {
        formattedQtyOrWeight = "$qty";
      }

      String formattedRate;
      if (isWeightedItem && weightUnitPrice > 0) {
        formattedRate = formatCurrency(weightUnitPrice);
      } else {
        formattedRate = formatCurrency(unitPrice);
      }

      String formattedTotal;
      double displayTotal;
      if (isWeightedItem && weightQty > 0 && weightUnitPrice > 0) {
        displayTotal = weightUnitPrice * weightQty;
        formattedTotal = formatCurrency(displayTotal);
      } else {
        displayTotal = lineTotal;
        formattedTotal = formatCurrency(lineTotal);
      }

      printedGrossTotal += displayTotal;

      List<String> nameLines = wrapItemName(itemName, 18);

      itemIndex++;

      bytes += ticket.row([
        PosColumn(text: "$itemIndex", width: 1),
        PosColumn(text: nameLines[0], width: 5),
        PosColumn(
            text: formattedQtyOrWeight,
            width: 2,  // ← Changed from 1 to 2
            styles: PosStyles(align: PosAlign.center)),
        PosColumn(
            text: formattedRate,
            width: 2,
            styles: PosStyles(align: PosAlign.right)),
        PosColumn(
            text: formattedTotal,
            width: 2,  // ← Changed from 3 to 2
            styles: PosStyles(align: PosAlign.right)),
      ]);

      if (kDebugMode) {
        print("   $itemIndex | ${nameLines[0]} | $formattedQtyOrWeight | $formattedRate | $formattedTotal");
      }

      for (int j = 1; j < nameLines.length; j++) {
        bytes += ticket.row([
          PosColumn(text: "", width: 1),
          PosColumn(text: "  ${nameLines[j]}", width: 5),
          PosColumn(text: "", width: 2),
          PosColumn(text: "", width: 2),
          PosColumn(text: "", width: 2),
        ]);
        if (kDebugMode) {
          print("     ${nameLines[j]}");
        }
      }

      // Discount printing (unchanged)
      String discountType = item['discount_type']?.toString() ?? '';
      double autoDiscount = (discountType.isEmpty || discountType == 'auto')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;
      double multipackDiscount = (discountType == 'multipack')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;
      double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;

      if (autoDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Auto Discount", width: 9),
          PosColumn(
            text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
        printedTotalDiscount += autoDiscount;
      }

      if (comboDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Combo Discount", width: 9),
          PosColumn(
            text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
        printedTotalDiscount += comboDiscount;
      }

      if (multipackDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Multipack Discount", width: 9),
          PosColumn(
            text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
        printedTotalDiscount += multipackDiscount;
      }

      bytes += ticket.emptyLines(1);
    }

    if (kDebugMode) {
      print("─────────────────────────────────────────────────────────────");
      print("📊 Item Totals:");
      print("   Gross Total (from items): ${formatCurrency(printedGrossTotal)}");
      print("   Total Discounts: ${formatCurrency(printedTotalDiscount)}");
      print("─────────────────────────────────────────────────────────────");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 11: DISCOUNT VALUE (Coupon / Order Level)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final double couponDiscountValue = () {
      final raw = _order["discount"] ??
          _order["order_discount"] ??
          _order["discount_amount"];
      final parsed = raw == null ? null : double.tryParse(raw.toString());
      final fromGetOrder =
          parsed ?? (discountValue != 0 ? discountValue : null);
      if (fromGetOrder == null) return this.discount;
      return fromGetOrder != 0 ? -(fromGetOrder.abs()) : 0.0;
    }();

    if (kDebugMode) {
      print("🏷️ Coupon/Order Discount: ${formatCurrency(couponDiscountValue)}");
      print("📊 Merchant Discount: ${formatCurrency(merchantDiscount)}");
      print("📊 Tax: ${formatCurrency(tax)}");
      print("📊 Cashback Fee: ${formatCurrency(cashbackFee)}");
      print("📊 Redeemed Value: ${formatCurrency(redeemedValue)}");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 12: TOTALS SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    // Gross Total (always printed)
    bytes += ticket.row([
      PosColumn(text: TextConstants.grossTotal, width: 8),
      PosColumn(
        text: formatCurrency(grossTotal),
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    // Coupon/Order Discount — only if non-zero
    if (couponDiscountValue != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.discountText, width: 8),
        PosColumn(
          text: formatCurrency(couponDiscountValue),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Tax — only if non-zero
    if (tax != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.taxText, width: 8),
        PosColumn(
          text: formatCurrency(tax),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Merchant Discount — only if non-zero
    if (merchantDiscount != 0) {
      bytes += ticket.row([
        PosColumn(
          text: merchantDiscountPercentage > 0
              ? '${TextConstants.merchantDiscount} (${merchantDiscountPercentage % 1 == 0 ? merchantDiscountPercentage.toStringAsFixed(0) : merchantDiscountPercentage.toStringAsFixed(1)}%)'
              : TextConstants.merchantDiscount,
          width: 8,
        ),
        PosColumn(
          text: formatCurrency(merchantDiscount),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Cashback Fee (unchanged — already conditional)
    if (cashbackFee > 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.cashbackFee, width: 8),
        PosColumn(
          text: formatCurrency(cashbackFee),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Service Charges — only if non-zero
    if (servicecharges != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.servicecharges, width: 8),
        PosColumn(
          text: formatCurrency(servicecharges),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 13: NET PAYABLE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 13: NET PAYABLE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    double printNetPayable = grossTotal +
        couponDiscountValue +
        merchantDiscount +
        tax +
        servicecharges +
        cashbackFee;
    // Do NOT clamp to 0 — payout/negative orders must print the actual
    // negative Net Payable value.

    bytes += ticket.row([
      PosColumn(text: TextConstants.netPayable, width: 8),
      PosColumn(
        text: formatCurrency(printNetPayable),
        width: 4,
        styles: PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (kDebugMode) {
      print("💰 Net Payable: ${formatCurrency(printNetPayable)}");
    }

    // Redeemed Amount
    if (redeemedValue > 0) {
      bytes += ticket.row([
        PosColumn(text: "Redeemed Amount", width: 8),
        PosColumn(
          text: "-${formatCurrency(redeemedValue).replaceAll('-', '')}",
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      if (kDebugMode) {
        print("🎯 Redeemed: -${formatCurrency(redeemedValue)}");
      }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 14: PAYMENT BREAKDOWN
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (payByCash != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.payByCash, width: 8),
        PosColumn(
          text: formatCurrency(payByCash),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (payByEbt != 0) {
      bytes += ticket.row([
        PosColumn(text: "Pay by EBT", width: 8),
        PosColumn(
          text: formatCurrency(payByEbt),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (payByOther != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.payByOther, width: 8),
        PosColumn(
          text: formatCurrency(payByOther),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (tenderAmount != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.tenderAmount, width: 8),
        PosColumn(
          text: formatCurrency(tenderAmount),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (changeAmount != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.change, width: 8),
        PosColumn(
          text: formatCurrency(changeAmount),
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (kDebugMode) {
      print("💵 Payment Breakdown:");
      print("   Cash: ${formatCurrency(payByCash)}");
      print("   EBT: ${formatCurrency(payByEbt)}");
      print("   Other: ${formatCurrency(payByOther)}");
      print("   Tendered: ${formatCurrency(tenderAmount)}");
      print("   Change: ${formatCurrency(changeAmount)}");
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 15: LOYALTY/EARNED POINTS (only if redeem was used)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final bool shouldPrintEarnedPoints =
        isRedeemActive || redeemedValue > 0 || availablePoints > 0;

    if (shouldPrintEarnedPoints) {
      final int earnedPoints =
          (_order['total_loyalty_points'] as num?)?.toInt() ?? 0;

      bytes += ticket.row([
        PosColumn(text: "Order Earned Points", width: 8),
        PosColumn(
          text: "$earnedPoints pts",
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      if (kDebugMode) {
        print("⭐ Order Earned Points: $earnedPoints pts");
      }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 16: FOOTER
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    if (footer.isNotEmpty) {
      bytes += ticket.feed(1);
      bytes += ticket.row([
        PosColumn(
            text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
      if (kDebugMode) {
        print("📝 Footer: $footer");
      }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 17: FINAL SUMMARY
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (kDebugMode) {
      print("═══════════════════════════════════════════════════════════");
      print("✅ RECEIPT PREPARED SUCCESSFULLY");
      print("═══════════════════════════════════════════════════════════");
      print("📊 Final Summary:");
      print("   Gross Total: ${formatCurrency(grossTotal)}");
      print("   Coupon Discount: ${formatCurrency(couponDiscountValue)}");
      print("   Merchant Discount: ${formatCurrency(merchantDiscount)}");
      print("   Tax: ${formatCurrency(tax)}");
      print("   Cashback Fee: ${formatCurrency(cashbackFee)}");
      print("   Net Payable: ${formatCurrency(printNetPayable)}");
      print("   Total Tendered: ${formatCurrency(tenderAmount)}");
      print("   Change: ${formatCurrency(changeAmount)}");
      if (customerContact.isNotEmpty) {
        print("   Customer: $customerContact");
      }
      print("═══════════════════════════════════════════════════════════");
      print("📋 Total bytes for print: ${bytes.length}");
      print("═══════════════════════════════════════════════════════════");
    }
  }


//////

  Future _printTicket({bool manual = false}) async {
    final ticket = await _printerSettings.getTicket();
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }

    switch (result) {
      case Ok<BluetoothPrinter>():
        break;
      case Error<BluetoothPrinter>():
        if (manual) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error.getMessage,
                style: const TextStyle(color: Colors.red),
              ),
              backgroundColor: Colors.black,
              duration: const Duration(seconds: 3),
            ),
          );

          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrinterSetup(),
              )).then((result) {
            if (result == TextConstants.refresh) {
              _printerSettings.loadPrinter();
              setState(() {
                if (!Misc.disablePrinter) {
                  _printTicket(); // retry only when NOT manual
                }
              });
            } else {
              if (mounted) {
                _showReceiptDialog(context, paidAmount);
              }
            }
          });
        });
        break;
    }
  }

  Future _printCustomTest() async {
    if (kDebugMode) {
      print("OrderSummaryScreen _printCustomTest call print reciept");
    }
    List<int> bytes = [];

    final ticket = await _printerSettings.getTicket();
    bytes += ticket.row([
      PosColumn(text: "#", width: 1),
      PosColumn(text: "Description", width: 5),
      PosColumn(text: "Qty", width: 1),
      PosColumn(text: "Rate", width: 2),
      PosColumn(text: "Dis", width: 1),
      PosColumn(text: "Amt", width: 2),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "1", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width: 5),
      PosColumn(text: "1.0", width: 1),
      PosColumn(text: "420.0", width: 2),
      PosColumn(text: "0.0", width: 1),
      PosColumn(text: "420.0", width: 2),
    ]);
    bytes += ticket.row([
      PosColumn(
          text: "sfgasa sdfasdfasdf asdfasdfasdfsdfasdfasdf adfasdfasdfasdf",
          width: 12),
    ]);
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }
    switch (result) {
      case Ok<BluetoothPrinter>():
      // BluetoothPrinter printer = result.value;
        break;
      case Error<BluetoothPrinter>():
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Build #1.0.16
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error.getMessage,
                style: const TextStyle(color: Colors.red),
              ),
              backgroundColor: Colors.black, // ✅ Black background
              duration: const Duration(seconds: 3),
            ),
          );

          /// call printer setup screen
          if (kDebugMode) {
            print("call printer setup screen");
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrinterSetup(),
              )).then((result) {
            if (result == TextConstants.refresh) {
              // Build #1.0.175: added TextConstants
              _printerSettings.loadPrinter();
              setState(() {
                // Update state to refresh the UI
                if (kDebugMode) {
                  print(
                      "SettingScreen - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
                }
                if (!Misc.disablePrinter) {
                  _printTicket();
                }
              });
            }
          });
        });
        break;
    }
  }

  void _showReceiptDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        status: PaymentStatus.receipt,
        mode: _currentDialogPaymentMode(),
        amount: amount,
        onPrint: () {
          if (kDebugMode) {
            print("Printing receipt for amount: $amount");
          }
        },
        onEmail: (email) {
          if (kDebugMode) {
            print("Email option selected with email: $email");
          }
        },
        onSMS: (phone) {},
        onNoReceipt: () async {
          // await CustomerService.publishPaymentSuccess(
          //   orderId ?? 0,
          //   orderItems,
          //   subtotal: grossTotal,
          //   tax: tax,
          //   total: computedNetPayable,
          // );
          print("Email option selected with data");

          await Future.delayed(const Duration(milliseconds: 300));
          if (orderId != null && orderId! > 0) {
            int retries = 3;
            while (retries > 0) {
              final payments = await LocalPaymentDBHelper.instance
                  .getPaymentsByOrderId(orderId!);
              final pendingPayments = payments
                  .where((p) =>
              p.amount > 0 && p.status == PaymentDbStatus.pending)
                  .toList();
              if (pendingPayments.isNotEmpty) {
                for (final p in pendingPayments) {
                  await LocalPaymentDBHelper.instance.updateStatus(
                    p.id,
                    PaymentDbStatus.completed,
                  );
                }
                print(
                    "✅ Marked ${pendingPayments.length} payments as completed");
                break;
              } else {
                retries--;
                if (retries > 0) {
                  print(
                      "⏳ No pending payments found, retrying... ($retries left)");
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
          }
          changeStatusToCompletedAndExit(false);
        },
        onDone: (selectedOption, {String? email}) async {
          // Build #1.0.159: Integrated Send Email Order Details API
          print("onDone → $selectedOption, email=$email");

          // ✅ KEY FIX: mark completed FIRST — same inline pattern as onNoReceipt
          await Future.delayed(const Duration(milliseconds: 300));
          if (orderId != null && orderId! > 0) {
            int retries = 3;
            while (retries > 0) {
              final payments = await LocalPaymentDBHelper.instance
                  .getPaymentsByOrderId(orderId!);
              final pendingPayments = payments
                  .where((p) =>
              p.amount > 0 && p.status == PaymentDbStatus.pending)
                  .toList();
              if (pendingPayments.isNotEmpty) {
                for (final p in pendingPayments) {
                  await LocalPaymentDBHelper.instance.updateStatus(
                    p.id,
                    PaymentDbStatus.completed,
                  );
                }
                print(
                    "✅ Marked ${pendingPayments.length} payments as completed");
                break;
              } else {
                retries--;
                if (retries > 0) {
                  print(
                      "⏳ No pending payments found, retrying... ($retries left)");
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
          }

          // ✅ NOW close dialog (triggers .then() → _syncCurrentOfflineOrder)
          // Isar already updated above so sync will see "completed"
          // Navigator.of(dialogCtx, rootNavigator: false).pop();
          if (kDebugMode) {
            print("DEBUG 0011 : $selectedOption, $email, ${email?.isNotEmpty}");
          }
          // Call API only if email option is selected and an email is provided
          if (selectedOption == TextConstants.email &&
              email != null &&
              email.isNotEmpty) {
            if (orderId == null || orderId == 0) {
              if (kDebugMode) {
                print("Invalid order ID: $orderId. Cannot send email.");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TextConstants.canNotSendEmail),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }

            if (kDebugMode) {
              print(
                  "Sending receipt to email: $email for order ID: $orderId on Done button click");
            }

            paymentBloc.sendOrderDetails(orderId!, email);
            StreamSubscription? subscription;
            subscription =
                paymentBloc.sendOrderDetailsStream.listen((response) {
                  if (response.status == Status.COMPLETED) {
                    if (kDebugMode) {
                      print("Email sent successfully: ${response.data!.message}");
                    }
                    if (Misc.showDebugSnackBar) {
                      // Build #1.0.254
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response.data!.message),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else if (response.status == Status.ERROR) {
                    if (kDebugMode) {
                      print("Failed to send email: ${response.message}");
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(TextConstants.failedSendEmail),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  subscription?.cancel();
                  // Proceed to complete the order after email API response
                  changeStatusToCompletedAndExit(true,
                      selectedOption: selectedOption);
                });
          } else {
            // For non-email options, proceed directly to complete the order
            changeStatusToCompletedAndExit(true,
                selectedOption: selectedOption);
          }
        },
      ),
    );
  }

  ///Use this function to change status to complete the order after payment
  ///it is used called by no receipt and print receipt on order payment completed - print button tap
  // void changeStatusToCompletedAndExit(bool isReceipt,
  //     {String selectedOption = TextConstants.print}) {
  //   if (kDebugMode) {
  //     print(
  //         "OrderSummaryScreen _showReceiptDialog Done call print receipt = $isReceipt");
  //   }
  //
  //   if (kDebugMode) {
  //     print(
  //         "changeStatusToCompletedAndExit called with isReceipt=$isReceipt, selectedOption=$selectedOption");
  //   } else if (selectedOption == TextConstants.sms) {
  //     // SMS receipt
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(TextConstants.smsConfiguration),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 1),
  //       ),
  //     );
  //   }
  //
  //   // If user navigates back to this screen later, make sure we don't keep
  //   // the keypad/EBT highlight from the previous payment flow.
  //   selectedPaymentMethod = TextConstants.cash;
  //   _rawAmount = 0;
  //   amountController.text = '${TextConstants.currencySymbol}0.00';
  //   _isAmountEntered = false;
  //   _amountErrorText = null;
  //
  //   // ✅ Update Hive with latest merchant discount before final sync
  //   _updateHiveWithLatestMerchantDiscount().then((_) {
  //     // Background sync after updating Hive
  //     Future(() async {
  //       try {
  //         await _syncCurrentOfflineOrder();
  //         print("✅ Background: Final sync completed");
  //       } catch (e) {
  //         print("❌ Background: Final sync failed: $e");
  //       }
  //     });
  //   });
  //
  //   Navigator.of(context).pop(); // Dismiss the receipt dialog
  //
  //   if (kDebugMode) {
  //     print("changeStatusToCompletedAndExit -> 3:");
  //   }
  //
  //   ///Completed order
  //   OrderHelper.isOrderPanelLoaded = false;
  //   OrderHelper.notifyOrderPanelToRefresh();
  //   Navigator.pushReplacement(
  //     result: TextConstants.refresh,
  //     context,
  //     MaterialPageRoute(builder: (_) => POSHomeScreen()),
  //   );
  //
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         TextConstants.orderCompleted,
  //         style: const TextStyle(color: Colors.white),
  //       ),
  //       backgroundColor: Colors.green,
  //       duration: const Duration(seconds: 1),
  //     ),
  //   );
  // }

  void doBackgroundWork() {
    // Capture before the async gap / navigation so context is still valid.
    final messaging = Provider.of<StoreMessagingService>(context, listen: false);

    Future(() async {
      if (orderId != null && orderId! > 0) {
        final allPayments = await LocalPaymentDBHelper.instance
            .getPaymentsByOrderId(orderId!);
        final bool isNegativeOrder = computedNetPayable <= 0;
        for (final p in allPayments) {
          if (p.status == PaymentDbStatus.pending) {
            if (p.amount > 0 || isNegativeOrder) {
              await LocalPaymentDBHelper.instance
                  .updateStatus(p.id, PaymentDbStatus.completed);
            }
          }
        }
      }

      await _updateHiveWithLatestMerchantDiscount();

      try {
        await _syncCurrentOfflineOrder();
      } catch (e) {
        if (kDebugMode) print("❌ doBackgroundWork: sync failed: $e");
      }

      // FIX: tell the MQTT-driven CFD to go idle. Previously only the
      // native secondary display was refreshed here — the Customer
      // Display flutter app (StoreMessagingService/MQTT) was never
      // notified, so it kept showing the last paid order forever
      // whenever this full-payment path was used instead of
      // changeStatusToCompletedAndExit().
      try {
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
      } catch (e) {
        if (kDebugMode) print('⚠️ CFD idle publish failed: $e');
      }

      try {
        final storeInfo = PinakaPreferences.getLoggedInStore();
        if (storeInfo.isNotEmpty) {
          await CustomerDisplayHelper.updateWelcomeWithStore(
            storeInfo['storeId'] ?? '0',
            storeInfo['storeName'] ?? 'Store',
            storeLogoUrl: storeInfo['storeLogoUrl'] ?? '',
            storeBaseUrl: storeInfo['storeBaseUrl'] ?? '',
          );
        } else {
          await CustomerDisplayService.showWelcome();
        }
      } catch (e) {
        if (kDebugMode) print(">>> customer display error: $e");
      }
    });
  }

  void changeStatusToCompletedAndExit(bool isReceipt,
      {String selectedOption = TextConstants.print}) {
    if (kDebugMode) {
      print(
          "OrderSummaryScreen _showReceiptDialog Done call print receipt = $isReceipt");
    }

    if (kDebugMode) {
      print(
          "changeStatusToCompletedAndExit called with isReceipt=$isReceipt, selectedOption=$selectedOption");
    } else if (selectedOption == TextConstants.sms) {
      // SMS receipt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextConstants.smsConfiguration),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    // ── Clear CFD immediately (last order must not stick) ──
    unawaited(() async {
      try {
        final messaging =
        Provider.of<StoreMessagingService>(context, listen: false);
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
        await CustomerDisplayService.showWelcome();
      } catch (_) {}
    }());

    // Clear active order so RightOrderPanel does not reload finished cart
    unawaited(OrderHelper().setActiveOrder(null));
    unawaited(OrderHelper().clearPersistedCartSelection());

    _updateHiveWithLatestMerchantDiscount().then((_) {
      Future(() async {
        try {
          await _syncCurrentOfflineOrder();
        } catch (e) {
          print("❌ Background: Final sync failed: $e");
        }
      });
    });

    Navigator.of(context).pop(); // receipt dialog if open

    OrderHelper.isOrderPanelLoaded = false;
    OrderHelper.notifyOrderPanelToRefresh();

    Navigator.pushReplacement(
      result: TextConstants.refresh,
      context,
      MaterialPageRoute(builder: (_) => POSHomeScreen()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          TextConstants.orderCompleted,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }


  // void showVoidExitConfirmation(BuildContext context, bool isPartial) {
  //   if (kDebugMode) {
  //     print(
  //       "showVoidExitConfirmation → isPartial: $isPartial, orderId: $orderId",
  //     );
  //   }
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (dialogContext) => PaymentDialog.voidConfirmation(
  //       onVoidCancel: () {
  //         if (kDebugMode) {
  //           print("❌ VOID CANCELED BY USER");
  //         }
  //         Navigator.of(dialogContext).pop(); // Just close dialog
  //       },
  //
  //       onVoidConfirm: () async {
  //         // 1. Close confirmation dialog first
  //         Navigator.of(dialogContext).pop();
  //
  //         if (_lastPayment == null) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text("No payment to void")),
  //           );
  //           return;
  //         }
  //
  //         final method = _lastPayment!.method.toLowerCase();
  //
  //         // CARD → SUNMI VOID
  //         if (method == TextConstants.card.toLowerCase() &&
  //             _lastPayment!.sunmiTxnId != null &&
  //             _lastPayment!.sunmiOrderId != null) {
  //
  //           if (kDebugMode) {
  //             print("🔁 VOID CONFIRM → CARD → SUNMI HARDWARE VOID");
  //           }
  //
  //           await _openSunmiVoidScreen(
  //             amount: _lastPayment!.amount,
  //             orderId: _lastPayment!.sunmiOrderId!,
  //             originTransactionId: _lastPayment!.sunmiTxnId!,
  //           );
  //         }
  //         // Other methods → local void
  //         else {
  //           if (kDebugMode) {
  //             print("🔁 VOID CONFIRM → $method → LOCAL VOID");
  //           }
  //
  //           await _handleVoidPayment(context, isPartial: isPartial);
  //         }
  //
  //         // ────────────────────────────────────────────────
  //         // SAME NAVIGATION FOR BOTH PARTIAL AND FULL VOID
  //         // ────────────────────────────────────────────────
  //         if (kDebugMode) {
  //           print("${isPartial ? 'Partial' : 'Full'} payment voided → simple pop (back one screen)");
  //         }
  //
  //         // Just go back one screen (same behavior for both cases)
  //         Navigator.of(context).pop();
  //
  //         // Optional feedback (shows for both partial & full)
  //         // ScaffoldMessenger.of(context).showSnackBar(
  //         //   SnackBar(
  //         //     content: Text(
  //         //       "Void successful – ${isPartial ? 'partial' : 'full'} payment reversed",
  //         //     ),
  //         //     backgroundColor: Colors.orange[800],
  //         //   ),
  //         // );
  //       },
  //     ),
  //   );
  // }

  // void _showExitPaymentConfirmation(BuildContext context) {
  //   // No need for orderStatus check here anymore
  //
  //   if (kDebugMode) {
  //     print("_showExitPaymentConfirmation called → will show dialog because caller already checked balance");
  //     print("   payByCash: $payByCash | payByOther: $payByOther");
  //     print("   balanceAmount: $balanceAmount | orderTotal: $orderTotal");
  //     print("   orderStatus: $orderStatus | tenderAmount: $tenderAmount");
  //   }
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (dialogContext) => PaymentDialog(
  //       status: PaymentStatus.exitConfirmation,
  //       onExitCancel: () {
  //         if (kDebugMode) {
  //           print("_showExitPaymentConfirmation → User canceled exit");
  //         }
  //         Navigator.of(dialogContext).pop();
  //       },
  //       onExitConfirm: () {
  //         if (kDebugMode) {
  //           print("_showExitPaymentConfirmation → User confirmed exit → navigating back");
  //         }
  //         Navigator.of(dialogContext).pop();
  //
  //         OrderHelper.isOrderPanelLoaded = false;
  //
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(builder: (_) => POSHomeScreen()),
  //           result: TextConstants.refresh,
  //         );
  //
  //       },
  //     ),
  //   );
  // }

  Widget _buildPaymentAmountDisplay(
      String label,
      String amount, {
        required Color leftBarColor,
        Color? amountColor = Colors.black,
        bool isPaymentBalance = false,
        double labelFontSize = 11,
        double amountFontSize = 12,
        FontWeight amountFontWeight = FontWeight.w700,   // ← This was missing
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      width: MediaQuery.of(context).size.width * 0.240,
      height: ResponsiveLayout.getHeight(40),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT INDICATOR BAR
          Container(
            width: 4,
            height: ResponsiveLayout.getHeight(45),
            decoration: BoxDecoration(
              color: leftBarColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: leftBarColor.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // TEXT CONTENT
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(labelFontSize),
                  fontWeight: FontWeight.w500,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(amountFontSize),
                  fontWeight: amountFontWeight,           // ← Now working
                  color: amountColor ?? (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : const Color(0xFF222222)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
