import 'dart:async';
import 'dart:core';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide MetaData;
import 'package:flutter/services.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:pinaka_pos/Helper/Extentions/extensions.dart';
import 'package:pinaka_pos/Helper/Extentions/money_rounding_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:pinaka_pos/Screens/Home/Settings/image_utils.dart';
import 'package:pinaka_pos/Screens/Home/order_summary_screen.dart';
import 'package:pinaka_pos/Widgets/widget_order_status.dart';
import 'package:pinaka_pos/Widgets/widget_alert_popup_dialogs.dart';
import 'package:provider/provider.dart';
import '../Blocs/Payment/payment_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/assets_db_helper.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/printer_db_helper.dart';
import '../Database/store_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Models/Orders/get_orders_model.dart';
import '../Models/Payment/payment_model.dart';
import '../Repositories/Payment/payment_repository.dart';
import '../Utilities/global_utility.dart';
import '../Repositories/Auth/store_validation_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Screens/Home/Settings/printer_setup_screen.dart';
import '../Screens/Home/isar_payments/local_payments_db_helper.dart';
import '../Screens/Home/isar_payments/local_payments_model.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/result_utility.dart';
import '../services/CustomerDisplayService.dart';

/// Same EBT rules as [OrderPanelDBHelper] / Fast Keys: product tag `ebt-eligible` OR line/variation
/// meta keys `is_ebt_eligible`, `_is_ebt_eligible`, `_ebt_eligible` (list API often omits tags).
bool lineItemEbtEligibleForPanelPreview(LineItem li) {
  if (li.isEbtEligible) return true;

  bool metaListSaysEbt(List<MetaData> list) {
    for (final meta in list) {
      final key = meta.key.toLowerCase();
      if (key != 'is_ebt_eligible' &&
          key != '_is_ebt_eligible' &&
          key != '_ebt_eligible') {
        continue;
      }
      final v = meta.value;
      if (v == true || v == 1) return true;
      if (v is num && v == 1) return true;
      final s = v?.toString().toLowerCase().trim() ?? '';
      if (s == '1' || s == 'true' || s == 'yes') return true;
    }
    return false;
  }

  if (metaListSaysEbt(li.metaData)) return true;
  final vMeta = li.productVariationData?.metaData;
  if (vMeta != null && vMeta.isNotEmpty && metaListSaysEbt(vMeta)) {
    return true;
  }
  return false;
}

/// Build order-panel rows from Total Orders list API [LineItem]s (instant display before DB sync).
// List<Map<String, dynamic>> panelMapsFromApiLineItems(List<LineItem> lines) {
//   final out = <Map<String, dynamic>>[];
//   for (final li in lines) {
//     try {
//       final qty = li.quantity;
//       final total = double.tryParse(li.total) ?? (li.price * qty);
//       final unit = qty > 0 ? total / qty : li.price;
//       final nameLower = li.name.toLowerCase();
//       final isDiscountItem = nameLower.contains('discount');
//       final variationId = li.variationId;
//       final variationName = li.productVariationData?.sku ?? '';
//       final int ebtFlag = lineItemEbtEligibleForPanelPreview(li) ? 1 : 0;
//       String discountType = '';
//       if (li.multipackApplied) {
//         discountType = 'multipack';
//       } else if (li.comboDiscountApplied) {
//         discountType = 'mixmatch';
//       } else if (li.autoDiscountApplied) {
//         discountType = 'auto';
//       }
//       out.add({
//         AppDBConst.itemName: li.name,
//         AppDBConst.itemCount: qty,
//         AppDBConst.itemPrice: unit,
//         AppDBConst.itemSumPrice: total,
//         // Same shape as SQLite rows: panel ListView uses item_unit_price / item_sales_price /
//         // item_regular_price with ?.toDouble() — if those are missing or String, you get NoSuchMethodError.
//         AppDBConst.itemUnitPrice: unit,
//         AppDBConst.itemSalesPrice: 0.0,
//         AppDBConst.itemRegularPrice: 0.0,
//         'product_id': li.productId,
//         'item_type': 'product',
//         AppDBConst.itemImage: li.image.src,
//         AppDBConst.itemVariationId: variationId,
//         AppDBConst.itemVariationCustomName: variationName,
//         'attribute_variant': variationId > 0 ? variationName : '',
//         'variant_name': variationId,
//         'variation_id': variationId,
//         'ebt_eligible': ebtFlag,
//         AppDBConst.isEbtEligible: ebtFlag,
//         'is_discount_item': isDiscountItem,
//         AppDBConst.isRefundItem: li.isRefundItem,
//         'discount_type': discountType,
//         AppDBConst.multipackDiscount: li.multipackDiscountAmount,
//         AppDBConst.autoDiscountTotal: li.autoDiscountAmount,
//         AppDBConst.comboDiscountTotal: li.comboDiscountAmount,
//         AppDBConst.displayAutoDiscount: li.displayAutoDiscountAmount,
//         'mixmatch_discount_total': li.comboDiscountAmount,
//       });
//     } catch (e, st) {
//       if (kDebugMode) {
//         print('panelMapsFromApiLineItems skip line: $e\n$st');
//       }
//     }
//   }
//   return out;
// }

/// Build order-panel rows from Total Orders list API [LineItem]s with FULL discount & tax support
// List<Map<String, dynamic>> panelMapsFromApiLineItems(List<LineItem> lines) {
//   final out = <Map<String, dynamic>>[];
//
//   for (final li in lines) {
//     try {
//       final qty = li.quantity;
//       final total = double.tryParse(li.total) ?? (li.price * qty);
//       final unit = qty > 0 ? total / qty : li.price;
//
//       final nameLower = li.name.toLowerCase();
//       final isDiscountItem = nameLower.contains('discount');
//
//       final variationId = li.variationId;
//       final variationName = li.productVariationData?.sku ?? '';
//
//       final int ebtFlag = lineItemEbtEligibleForPanelPreview(li) ? 1 : 0;
//
//       // 🔥 CHECK IF THIS IS A WEIGHTED ITEM
//       final bool isWeightedItem = li.name.contains('@') ||
//           li.name.contains('/lb') ||
//           (li.metaData?.any((m) => m.key == '_weighted_item' && m.value == '1') ?? false);
//
//       // 🔥 EXTRACT WEIGHT AND UNIT PRICE FROM NAME OR METADATA
//       double weightQty = 0.0;
//       double unitPrice = 0.0;
//
//       if (isWeightedItem) {
//         // Extract from meta data
//         if (li.metaData != null) {
//           for (final meta in li.metaData!) {
//             if (meta.key == '_weight_qty') {
//               weightQty = double.tryParse(meta.value?.toString() ?? '0') ?? 0.0;
//             }
//             if (meta.key == '_unit_price') {
//               unitPrice = double.tryParse(meta.value?.toString() ?? '0') ?? 0.0;
//             }
//           }
//         }
//
//         // If weight not found in meta, try to parse from name
//         if (weightQty == 0) {
//           // Look for pattern like "0.400 lbs" in the name
//           final RegExp weightPattern = RegExp(r'([\d.]+)\s*(?:lbs|lb)');
//           final match = weightPattern.firstMatch(li.name);
//           if (match != null) {
//             weightQty = double.tryParse(match.group(1) ?? '0') ?? 0.0;
//           }
//         }
//
//         // If unit price not found in meta, try to parse from name
//         if (unitPrice == 0) {
//           final RegExp pricePattern = RegExp(r'\$([\d.]+)/lb');
//           final match = pricePattern.firstMatch(li.name);
//           if (match != null) {
//             unitPrice = double.tryParse(match.group(1) ?? '0') ?? 0.0;
//           }
//         }
//
//         print(' WEIGHTED ITEM DETECTED: ${li.name} | weightQty=$weightQty | unitPrice=$unitPrice | qty=$qty');
//       }
//
//       // ✅ FIXED: Better discount type detection
//       String discountType = '';
//       double autoDiscount = 0.0;
//       double comboDiscount = 0.0;
//       double multipackDiscount = 0.0;
//
//       if (li.multipackApplied) {
//         discountType = 'multipack';
//         multipackDiscount = li.multipackDiscountAmount ?? 0.0;
//       } else if (li.comboDiscountApplied) {
//         discountType = 'mixmatch';
//         comboDiscount = li.comboDiscountAmount ?? 0.0;
//       } else if (li.autoDiscountApplied) {
//         discountType = 'auto';
//         autoDiscount = li.autoDiscountAmount ?? 0.0;
//       }
//
//       // ✅ FIXED: Better tax & total calculation
//       final double itemTax = double.tryParse(li.totalTax ?? '0') ?? 0.0;
//       final double itemTotalWithTax = total + itemTax;
//
//       // 🔥 CREATE THE MAP FIRST
//       final Map<String, dynamic> itemMap = {
//         AppDBConst.itemName: li.name,
//         AppDBConst.itemCount: isWeightedItem ? 1 : qty.toInt(),
//         AppDBConst.itemPrice: unit,
//         AppDBConst.itemSumPrice: total,
//         AppDBConst.itemUnitPrice: unit,
//         AppDBConst.itemSalesPrice: total,
//         AppDBConst.itemRegularPrice: li.price,
//         'product_id': li.productId,
//         'item_type': 'product',
//         AppDBConst.itemImage: li.image.src,
//         AppDBConst.itemVariationId: variationId,
//         AppDBConst.itemVariationCustomName: variationName,
//         'attribute_variant': variationId > 0 ? variationName : '',
//         'variant_name': variationId,
//         'variation_id': variationId,
//         'ebt_eligible': ebtFlag,
//         AppDBConst.isEbtEligible: ebtFlag,
//         'is_discount_item': isDiscountItem,
//         AppDBConst.isRefundItem: li.isRefundItem ?? 0,
//         'discount_type': discountType,
//         AppDBConst.multipackDiscount: multipackDiscount,
//         AppDBConst.autoDiscountTotal: autoDiscount,
//         AppDBConst.comboDiscountTotal: comboDiscount,
//         AppDBConst.displayAutoDiscount: autoDiscount,
//         'mixmatch_discount_total': comboDiscount,
//         'item_tax': itemTax,
//         'total_with_tax': itemTotalWithTax,
//       };
//
//       // 🔥 ADD WEIGHT FIELDS FOR WEIGHTED ITEMS
//       if (isWeightedItem) {
//         itemMap['is_weighted'] = true;
//         itemMap['weight_qty'] = weightQty > 0 ? weightQty : qty; // Use qty as fallback
//         itemMap['weightQty'] = weightQty > 0 ? weightQty : qty;
//         itemMap['weight'] = weightQty > 0 ? weightQty : qty;
//         itemMap['unit_price'] = unitPrice > 0 ? unitPrice : unit;
//         itemMap['display_qty'] = weightQty > 0 ? weightQty : qty;
//
//         // 🔥 Update item_type to 'weighted' so the UI knows how to display it
//         itemMap['item_type'] = 'weighted';
//
//         // 🔥 Update the display name to show weight info
//         if (weightQty > 0 && unitPrice > 0) {
//           itemMap[AppDBConst.itemName] = "${li.name.split('(')[0].trim()}";
//         }
//
//         print('⚖️ WEIGHT MAP ADDED: weight_qty=${itemMap['weight_qty']} | unit_price=${itemMap['unit_price']} | display_qty=${itemMap['display_qty']}');
//       }
//
//       // 🔥 ADD THE MAP TO OUTPUT
//       out.add(itemMap);
//
//     } catch (e, st) {
//       if (kDebugMode) {
//         print('panelMapsFromApiLineItems skip line: $e');
//         print('Stack: $st');
//       }
//     }
//   }
//   return out;
// }


/// Build order-panel rows from Total Orders list API [LineItem]s with FULL weighted item support
List<Map<String, dynamic>> panelMapsFromApiLineItems(List<LineItem> lines) {
  final out = <Map<String, dynamic>>[];

  for (final li in lines) {
    try {
      final bool isWeightedItem = li.isWeighted ||
          (li.weightQty != null && li.weightQty! > 0.0);

      final double weightQty = li.weightQty ?? 0.0;
      final String weightUnit = li.weightUnit ?? 'lb';
      final double unitPrice = li.unitPrice ??
          (double.tryParse(li.subtotal) ?? 0.0) / (li.quantity > 0 ? li.quantity : 1);

      final double qty = li.quantity.toDouble();
      final double total = double.tryParse(li.total) ?? (li.price * qty);
      final double displayQty = isWeightedItem && weightQty > 0 ? weightQty : qty;

      final nameLower = li.name.toLowerCase();
      final isDiscountItem = nameLower.contains('discount');

      final variationId = li.variationId;
      final variationName = li.productVariationData?.sku ?? '';

      final int ebtFlag = lineItemEbtEligibleForPanelPreview(li) ? 1 : 0;

      String discountType = '';
      double autoDiscount = li.autoDiscountAmount;
      double comboDiscount = li.comboDiscountAmount;
      double multipackDiscount = li.multipackDiscountAmount;

      if (li.multipackApplied) {
        discountType = 'multipack';
      } else if (li.comboDiscountApplied) {
        discountType = 'mixmatch';
      } else if (li.autoDiscountApplied) {
        discountType = 'auto';
      }

      final double itemTax = double.tryParse(li.totalTax) ?? 0.0;
      final double itemTotalWithTax = total + itemTax;

      final Map<String, dynamic> itemMap = {
        AppDBConst.itemName: li.name,
        AppDBConst.itemCount: isWeightedItem ? 1 : qty.toInt(),
        AppDBConst.itemPrice: unitPrice,
        AppDBConst.itemSumPrice: total,
        AppDBConst.itemUnitPrice: unitPrice,
        AppDBConst.itemSalesPrice: total,
        AppDBConst.itemRegularPrice: li.price,
        'product_id': li.productId,
        'item_type': isWeightedItem ? 'weighted' : 'product',
        AppDBConst.itemImage: li.image.src,
        AppDBConst.itemVariationId: variationId,
        AppDBConst.itemVariationCustomName: variationName,
        'attribute_variant': variationId > 0 ? variationName : '',
        'variant_name': variationId,
        'variation_id': variationId,
        'ebt_eligible': ebtFlag,
        AppDBConst.isEbtEligible: ebtFlag,
        'is_discount_item': isDiscountItem,
        AppDBConst.isRefundItem: li.isRefundItem ? 1 : 0,
        'discount_type': discountType,
        AppDBConst.multipackDiscount: multipackDiscount,
        AppDBConst.autoDiscountTotal: autoDiscount,
        AppDBConst.comboDiscountTotal: comboDiscount,
        AppDBConst.displayAutoDiscount: li.displayAutoDiscountAmount,
        'mixmatch_discount_total': comboDiscount,
        'item_tax': itemTax,
        'total_with_tax': itemTotalWithTax,

        // 🔥 WEIGHTED ITEM FIELDS
        'is_weighted': isWeightedItem,
        'weight_qty': weightQty,
        'weightUnit': weightUnit,
        'unit_price': unitPrice,
        'display_qty': displayQty,
        'weight_display': isWeightedItem
            ? "${weightQty.toStringAsFixed(3)} $weightUnit @ \$${unitPrice.toStringAsFixed(2)}/lb"
            : null,
      };

      out.add(itemMap);

    } catch (e, st) {
      if (kDebugMode) {
        print('panelMapsFromApiLineItems skip line: $e');
        print('Stack: $st');
      }
    }
  }
  return out;
}

/// Reads Woo `merchant_discount` fee line total + total_tax (e.g. -0.97 + -0.09 = -1.06).
double merchantDiscountFromFeeLines(dynamic feeLinesRaw) {
  if (feeLinesRaw is! List || feeLinesRaw.isEmpty) {
    return 0.0;
  }

  double total = 0.0;
  for (final fee in feeLinesRaw) {
    String? name;
    String? lineTotalStr;
    String? lineTaxStr;

    if (fee is Map) {
      name = fee['name']?.toString();
      lineTotalStr = fee['total']?.toString();
      lineTaxStr = fee['total_tax']?.toString();
    } else {
      try {
        name = fee.name?.toString();
        lineTotalStr = fee.total?.toString();
        lineTaxStr = fee.totalTax?.toString();
      } catch (_) {
        continue;
      }
    }

    final nameLower = (name ?? '').toLowerCase();
    final isMerchantDiscount = nameLower == 'merchant_discount' ||
        (nameLower.contains('merchant') && nameLower.contains('discount'));
    if (!isMerchantDiscount) continue;

    final lineTotal = double.tryParse(lineTotalStr ?? '0') ?? 0.0;
    final lineTax = double.tryParse(lineTaxStr ?? '0') ?? 0.0;
    total += lineTotal + lineTax;
  }

  return total;
}

/// Maps Total Orders API [OrderModel] into the same shape as SQLite `_order` so status,
/// coupon lines, tax/totals, and coupon visibility match the list immediately (before DB sync).
Map<String, dynamic> orderPanelOrderMapFromOrderModel(OrderModel o) {
  final couponLines = o.couponLines
      .map((c) => <String, dynamic>{
    'discount': c.discount,
    'code': c.code,
  })
      .toList();
  final metaList = o.metaData
      .map((m) => <String, dynamic>{'key': m.key, 'value': m.value})
      .toList();

  double? metaDouble(String key) {
    for (final m in o.metaData) {
      if (m.key == key) {
        return double.tryParse(m.value?.toString() ?? '') ??
            (m.value is num ? (m.value as num).toDouble() : null);
      }
    }
    return null;
  }

  final double discTotal = double.tryParse(o.discountTotal) ?? 0.0;
  final double taxTotal = double.tryParse(o.totalTax) ?? 0.0;
  final double orderTotal = double.tryParse(o.total) ?? 0.0;
  final double feeLineMerchantDiscount =
  merchantDiscountFromFeeLines(o.feeLines).abs();
  final double merchantMeta = feeLineMerchantDiscount > 0
      ? feeLineMerchantDiscount
      : (metaDouble('merchant_discount') ??
      metaDouble('_merchant_discount') ??
      0.0)
      .abs();

  final bool couponsApplied = couponLines.isNotEmpty || discTotal > 0;

  return <String, dynamic>{
    AppDBConst.orderServerId: o.id,
    AppDBConst.orderStatus:
    o.status.isNotEmpty ? o.status : TextConstants.processing,
    AppDBConst.orderDate: o.dateCreated,
    AppDBConst.orderDiscount: discTotal,
    AppDBConst.merchantDiscount: merchantMeta,
    'merchantDiscount': merchantMeta,
    AppDBConst.orderTax: taxTotal,
    AppDBConst.orderTotal: orderTotal,
    'coupon_lines': couponLines,
    'meta_data': metaList,
    'coupon_applied': couponsApplied,
    'wooTax': taxTotal,
    'wooTotal': orderTotal,
    'net_payment': o.netPayment,
    AppDBConst.orderCashbackFee: o.cashbackFee,
    'cashbackFee': o.cashbackFee,
    'cashback_fee': o.cashbackFee,
    'fee_lines': o.feeLines
        ?.map((f) => {
      'id': f.id,
      'name': f.name,
      'total': f.total,
      'total_tax': f.totalTax,
      'tax_status': f.taxStatus,
    })
        .toList() ??
        [],
  };
}

class OrderScreenPanel extends StatefulWidget {
  final String formattedDate;
  final String formattedTime;
  final List<int> quantities;
  final VoidCallback? refreshOrderList;
  int? activeOrderId; // Build #1.0.251 : updated
  final bool fetchOrders; //Build #1.0.234:  Mark as final
  /// When set (e.g. from Total Orders list response), panel shows these rows immediately.
  final List<LineItem>? previewLineItemsFromApi;

  /// Same order as [previewLineItemsFromApi]: hydrates status, discounts, and meta before SQLite loads.
  final OrderModel? previewOrderFromApi;

  OrderScreenPanel({
    required this.formattedDate,
    required this.formattedTime,
    required this.quantities,
    this.refreshOrderList,
    this.activeOrderId,
    this.fetchOrders = false,
    this.previewLineItemsFromApi,
    this.previewOrderFromApi,
    Key? key,
  }) : super(key: key);

  @override
  _OrderScreenPanelState createState() => _OrderScreenPanelState();
}

class _OrderScreenPanelState extends State<OrderScreenPanel>
    with TickerProviderStateMixin {
  List<Map<String, Object>> tabs = []; // List of order tabs
  TabController? _tabController; // Controller for tab switching
  List<Map<String, dynamic>> orderItems =
  []; // List of items in the selected order
  final OrderHelper orderHelper =
  OrderHelper(); // Helper instance to manage orders

  bool _isLoading = false;
  bool _isPayBtnLoading = false;
  bool _initialFetchDone =
  false; // Build #1.0.143: Track initial fetch of fetchOrdersData
  // late OrderBloc orderBloc;
  StreamSubscription? _updateOrderSubscription;
  StreamSubscription? _fetchOrdersSubscription;
  final ProductBloc productBloc = ProductBloc(
      ProductRepository()); // Build #1.0.44 : Added for barcode scanning
  StreamSubscription?
  _productBySkuSubscription; // Build #1.0.44 : Added for product stream
  final OrderRepository _orderRepository = OrderRepository();
  OrderModel? _wooOrder;

  bool _showFullSummary = false;
  late ScaffoldMessengerState _scaffoldMessenger;
  var _printerReceipt;

  // Build #1.0.221 : Added these variables
  late PaymentBloc paymentBloc;
  StreamSubscription? _paymentListSubscription;
  double payByCash = 0.0;
  double payByOther = 0.0;
  double tenderAmount = 0.0;
  double changeAmount = 0.0;
  double cashbackFee = 0.0;
  double ebtAmount = 0.0;

  double hiveRedeemedValue = 0.0;
  int hiveRedeemedPoints = 0;
  int hiveAvailablePoints = 0;
  double uiGrossTotal = 0.0;
  double uiOrderDiscount = 0.0;
  double uiMerchantDiscount = 0.0;
  double uiOrderTax = 0.0;
  double uiNetPayable = 0.0;
  double uiCashbackFee = 0.0;
  int uiTotalItems = 0;
  double uiRedeemedValue = 0.0;

  String orderStatus = TextConstants.processing;
  int? orderServerId; // Server order ID for API calls
  double total = 0.0;
  double balanceAmount = 0.0;
  double paidAmount = 0.0;
  double discount = 0.0; // Add this to track discount
  double merchantDiscount = 0.0; // Add this to track merchant discount
  double servicecharges = 0.0;
  double tax = 0.0; // AddED tax variable
  final _printerSettings = PrinterSettings();
  List<int> bytes = [];

  /// Cancels stale [fetchOrderItems] completions when the user switches orders quickly.
  int _fetchOrderItemsSeq = 0;

  /// Cancels stale [fetchOrdersData]/[fetchOrder] completions during rapid order switches.
  int _fetchOrdersDataSeq = 0;

  /// true → still money left to pay → show Pay button
  /// false → fully paid → show Print Invoice
  bool get _shouldShowPayButton {
    // Prefer live balance
    if (balanceAmount > 0.01) return true;

    // Fallback: status is still open and tender is less than net payable
    final status = orderStatus.toLowerCase().trim();
    final isOpenStatus = status == 'pending' ||
        status == 'pending_offline' ||
        status == 'processing' ||
        status == 'on-hold' ||
        status.contains('pending');

    final netPay = (_order["payable"] as num?)?.toDouble() ??
        (_order["net_payable"] as num?)?.toDouble() ??
        uiNetPayable;

    if (isOpenStatus && tenderAmount < (netPay - 0.01)) {
      return true;
    }

    return false; // fully paid → Print Invoice
  }

  void _toggleSummary() {
    setState(() {
      _showFullSummary = !_showFullSummary;
    });
  }

  VoidCallback? _orderPanelRefreshListener;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print("##### OrderPanel initState");
    }
    _orderPanelRefreshListener = () {
      if (mounted) fetchOrdersData();
    };
    OrderHelper.orderPanelRefreshNotifier
        .addListener(_orderPanelRefreshListener!);
    //  orderBloc = OrderBloc(OrderRepository()); // Build #1.0.143: no need
    fetchOrdersData(); // Build #1.0.104
    _initialFetchDone =
    true; // Build #1.0.143: Track initial fetch of fetchOrdersData, after return from order summary screen we are updating order screen panel in didUpdateWidget, added this flag for multiple re-calls of fetchOrdersData()
    // _getOrderTabs(); //Build #1.0.40: Load existing orders into tabs
    //_fetchOrders(); //Build #1.0.40: Fetch orders on initialization
    loadPrinterData();
    // Initialize payment bloc
    paymentBloc = PaymentBloc(PaymentRepository());
  }

  // Build #1.0.221 : getPaymentsByOrderId API call for payment details
  // we need to call payment by order id api in order screen panel and load the details payByCash, payByOther, tender amount, change amount
  void _fetchPaymentsByOrderId() {
    if (kDebugMode) {
      print("###### _fetchPaymentsByOrderId - OrderScreenPanel");
    }

    if (orderServerId != null) {
      // paymentBloc.getPaymentsByOrderId(orderServerId!);

      _paymentListSubscription?.cancel();
      _paymentListSubscription =
          paymentBloc.paymentsListStream.listen((response) async {
            if (response.status == Status.COMPLETED) {
              if (kDebugMode) {
                print(
                    "###### _fetchPaymentsByOrderId Api call COMPLETED - OrderScreenPanel");
                print("###### Response data: ${response.data}");
              }

              final data = response.data ?? [];

              if (data.isNotEmpty) {
                orderStatus = data.first.orderStatus ?? TextConstants.processing;
                if (kDebugMode) {
                  print("###### Order status updated to: $orderStatus");
                }
                _processPaymentList(data);
              } else {
                // API returned empty - use LocalPayment as source of truth
                // (fixes balance showing net payable when payments exist locally but not yet synced)
                await _loadBalanceFromLocalPayment();
              }
            } else if (response.status == Status.ERROR) {
              if (kDebugMode) {
                print("Error fetching payments: ${response.message}");
              }
            }
          });
    } else {
      if (kDebugMode) {
        print("###### orderServerId is null - Cannot fetch payments");
      }
    }
  }

  Future<void> _fetchWooOrder(int serverId) async {
    try {
      final woo =
      await _orderRepository.getOrderdata(orderId: serverId.toString());

      if (!mounted) return;

      setState(() {
        _wooOrder = woo;

        // store cashback into local order map
        final cashback = woo.cashbackFee;
        _order["cashbackFee"] = cashback;
        _order["cashback_fee"] = cashback;
        _order[AppDBConst.orderCashbackFee] = cashback;
      });

      print("🌐 Woo Order Loaded: ${woo.id}");
      print("💰 Cashback From API: ${woo.cashbackFee}");
    } catch (e) {
      print("❌ Woo order fetch failed: $e");
    }
  }

// Build #1.0.221 Process payment list and update UI
  void _processPaymentList(List<PaymentListModel> payments) {
    double cashPaid = 0.0;
    double otherPaid = 0.0;
    double ebtPaid = 0.0;

    for (var payment in payments) {
      double amount = double.tryParse(payment.amount) ?? 0.0;

      if (amount > 0 && payment.voidStatus == false) {
        final method = payment.paymentMethod.toLowerCase().trim();

        // Match cash
        if (method == "cash" ||
            method == TextConstants.cash.toLowerCase() ||
            method == TextConstants.payByCash.toLowerCase()) {
          cashPaid += amount;
        }
        // Match EBT
        else if (method == "ebt" ||
            method.contains("ebt") ||
            method == TextConstants.ebtText.toLowerCase() ||
            method ==
                TextConstants.EBTAmount.toLowerCase().replaceAll('.', '')) {
          ebtPaid += amount;
        }
        // Everything else is other
        else {
          otherPaid += amount;
        }
      }
    }

    setState(() {
      payByCash = cashPaid;
      payByOther = otherPaid;
      ebtAmount = ebtPaid;

      // Tender amount includes all payments
      tenderAmount =
          (payByCash + payByOther + ebtAmount).clamp(0.0, double.infinity);

      double effectiveTotal = (_order["payable"] as num?)?.toDouble() ??
          (_order["net_payable"] as num?)?.toDouble() ??
          uiNetPayable ??
          0.0;

      balanceAmount =
          (effectiveTotal - tenderAmount).clamp(0.0, double.infinity);
      changeAmount = (tenderAmount > effectiveTotal)
          ? (tenderAmount - effectiveTotal)
          : 0.0;
    });
  }

  /// Load balance from LocalPayment when API returns empty (payments not yet synced).
  // Future<void> _loadBalanceFromLocalPayment() async {
  //   if (widget.activeOrderId == null || !mounted) return;
  //
  //   try {
  //     final orderId = widget.activeOrderId!;
  //
  //     // 1️⃣ Get summary
  //     final summary =
  //     await LocalPaymentDBHelper.instance.getPaymentSummaryForOrder(orderId);
  //
  //     print("========== Local Payment Summary ==========");
  //     print("Full summary map: $summary");
  //
  //     if (summary != null) {
  //       summary.forEach((key, value) {
  //         print("Key: $key  =>  Value: $value");
  //
  //         if (key == 'paymentCount') {
  //           final count = (value as num).toInt();
  //           print("💳 Payment count: $count");
  //         }
  //       });
  //     }
  //     print("===========================================");
  //
  //     final paymentCount = (summary['paymentCount'] ?? 0.0).toDouble();
  //
  //     // 2️⃣ Get all individual payments for this order
  //     final payments =
  //     await LocalPaymentDBHelper.instance.getPaymentsByOrderId(orderId);
  //
  //     if (payments.isNotEmpty) {
  //       print("========== Local Payment Records ==========");
  //       for (var p in payments) {
  //         final amountStr = p.amount >= 0
  //             ? "Cash: \$${p.amount.toStringAsFixed(2)}"
  //             : "void: \$${p.amount.toStringAsFixed(2)}";
  //
  //         print(
  //             "→ ID: ${p.id} | Order ID: ${p.orderId} | $amountStr | Synced: ${p.isSynced} | Status: ${p.status.name}");
  //       }
  //       print("===========================================");
  //     }
  //
  //     // 3️⃣ Compute tender, balance, and change
  //     if (paymentCount > 0) {
  //       final totalPaid = (summary['totalPaid'] ?? 0.0).toDouble();
  //
  //       setState(() {
  //         tenderAmount = totalPaid.clamp(0.0, double.infinity);
  //         payByOther = tenderAmount;
  //         payByCash = 0.0;
  //
  //         final remaining = summary['remainingBalance'];
  //         if (remaining != null) {
  //           balanceAmount =
  //               (remaining as num).toDouble().clamp(0.0, double.infinity);
  //         } else {
  //           final netPay = (_order["payable"] as num?)?.toDouble() ??
  //               (_order["net_payable"] as num?)?.toDouble() ??
  //               uiNetPayable ??
  //               0.0;
  //
  //           balanceAmount = (netPay - tenderAmount).clamp(0.0, double.infinity);
  //         }
  //
  //         if (balanceAmount <= 0) {
  //           changeAmount = (tenderAmount - (_order["payable"] ?? 0.0))
  //               .clamp(0.0, double.infinity);
  //           balanceAmount = 0.0;
  //         } else {
  //           changeAmount = 0.0;
  //         }
  //
  //         // ✅ Add this override to compute change using netPay
  //         final netPay = (_order["payable"] as num?)?.toDouble() ??
  //             (_order["net_payable"] as num?)?.toDouble() ??
  //             uiNetPayable ??
  //             0.0;
  //         changeAmount = ( netPay).clamp(0.0, double.infinity);
  //
  //         print(
  //             "Local payments → tender clamped = $tenderAmount | balance = $balanceAmount | change = $changeAmount");
  //       });
  //     }
  //   } catch (e) {
  //     if (kDebugMode) print("LocalPayment error: $e");
  //   }
  // }
  Future<void> _loadBalanceFromLocalPayment() async {
    if (widget.activeOrderId == null || !mounted) return;

    try {
      final orderId = widget.activeOrderId!;

      // 1️⃣ Get summary
      final summary = await LocalPaymentDBHelper.instance
          .getPaymentSummaryForOrder(orderId);

      print("========== Local Payment Summary ==========");
      print("Full summary map: $summary");

      final paymentCount = (summary?['paymentCount'] ?? 0).toDouble();

      // 2️⃣ Get all individual payments
      final payments =
      await LocalPaymentDBHelper.instance.getPaymentsByOrderId(orderId);

      double cashPaid = 0.0;
      double otherPaid = 0.0;
      double ebtPaid = 0.0;

      if (payments.isNotEmpty) {
        print("========== Local Payment Records ==========");
        for (var p in payments) {
          final method = p.paymentMethod.toLowerCase().trim();
          if (method == "cash" ||
              method == TextConstants.cash.toLowerCase() ||
              method == TextConstants.payByCash.toLowerCase()) {
            cashPaid += p.amount;
          } else if (method == "ebt" ||
              method.contains("ebt") ||
              method == TextConstants.ebtText.toLowerCase() ||
              method ==
                  TextConstants.EBTAmount.toLowerCase().replaceAll('.', '')) {
            ebtPaid += p.amount;
          } else {
            otherPaid += p.amount;
          }

          final amountStr = p.amount >= 0
              ? "Cash: \$${p.amount.toStringAsFixed(2)}"
              : "void: \$${p.amount.toStringAsFixed(2)}";
          print(
              "→ ID: ${p.id} | Order ID: ${p.orderId} | $amountStr | Synced: ${p.isSynced} | Status: ${p.status.name}");
        }
        print("===========================================");
      }

      // 3️⃣ Compute tender, balance, and change
      if (paymentCount > 0) {
        final totalPaid = (summary?['totalPaid'] ?? 0.0).toDouble();
        final remaining = summary?['remainingBalance']?.toDouble();

        // Compute netPay
        final netPay = (_order["payable"] as num?)?.toDouble() ??
            (_order["net_payable"] as num?)?.toDouble() ??
            uiNetPayable ??
            0.0;

        // Compute balanceAmount
        double computedBalance;
        if (remaining != null) {
          computedBalance = remaining.clamp(0.0, double.infinity);
        } else {
          computedBalance = (netPay - totalPaid).clamp(0.0, double.infinity);
        }

        // Compute changeAmount
        // Compute changeAmount strictly from overpayment
        double computedChange =
        (totalPaid - netPay).clamp(0.0, double.infinity);

// If there is change, balance must be zero
        if (computedChange > 0) {
          computedBalance = 0.0;
        }

        //  Override to ensure changeAmount reflects netPay if needed
        // computedChange = netPay < balanceAmount ? netPay : balanceAmount;

        //  Set final values once
        setState(() {
          tenderAmount = totalPaid.clamp(0.0, double.infinity);
          payByCash = cashPaid;
          payByOther = otherPaid;
          ebtAmount = ebtPaid;
          balanceAmount = computedBalance;
          changeAmount = computedChange;
        });

        print(
            "Local payments → tender clamped = $tenderAmount | balance = $balanceAmount | change = $changeAmount");
      }
    } catch (e) {
      if (kDebugMode) print("LocalPayment error: $e");
    }
  }

  Future<void> loadPrinterData() async {
    var printerDB = await PrinterDBHelper().getPrinterFromDB();
    if (printerDB.isEmpty) {
      if (kDebugMode) {
        print(">>>>> OrderScreenPanel : printerDB is empty");
      }
      return;
    }
    _printerReceipt = printerDB.first;
  }

  // Build #1.0.118: Updated fetchOrdersData to use widget.activeOrderId
  Future<void> fetchOrdersData() async {
    // Build #1.0.104: created this function for initial load and back button refresh
    if (!mounted) return; // Build #1.0.240 : Added
    final int requestSeq = ++_fetchOrdersDataSeq;
    final int? requestOrderId = widget.activeOrderId;
    // Reset payment-related fields to avoid leaking values from the previously opened order.
    // This fixes cases where discount-only orders were showing discount as "Change".
    final preview = widget.previewLineItemsFromApi;
    final bool hasApiPreview = preview != null && preview.isNotEmpty;
    setState(() {
      tenderAmount = 0.0;
      changeAmount = 0.0;
      balanceAmount = 0.0;
      payByCash = 0.0;
      payByOther = 0.0;
      ebtAmount = 0.0;
      if (hasApiPreview) {
        orderItems = panelMapsFromApiLineItems(preview);
        _isLoading = false;
        final po = widget.previewOrderFromApi;
        if (po != null && po.id == widget.activeOrderId) {
          _order = orderPanelOrderMapFromOrderModel(po);
          _wooOrder = po;
          orderServerId = po.id;
        }
      } else {
        _isLoading = true;
      }
    });
    if (kDebugMode) {
      print(
          "##### fetchOrdersData called for activeOrderId: ${widget.activeOrderId}");
    }
    try {
      await fetchOrder();
      if (!mounted ||
          requestSeq != _fetchOrdersDataSeq ||
          widget.activeOrderId != requestOrderId) {
        return;
      }
      final latestPreviewOrder = widget.previewOrderFromApi;
      if (latestPreviewOrder != null &&
          latestPreviewOrder.id == widget.activeOrderId) {
        // Keep panel status/coupon/totals aligned with latest Total Orders API
        // snapshot while local SQLite/Hive catches up.
        _order.addAll(orderPanelOrderMapFromOrderModel(latestPreviewOrder));
        _wooOrder = latestPreviewOrder;
      }
      // Enrich _order from offline storage (SQLite may not have cashback, discounts)
      if (widget.activeOrderId != null && _order != null && _order is Map) {
        final cfKey = _order["cashbackFee"] ??
            _order["cashback_fee"] ??
            _order[AppDBConst.orderCashbackFee];
        final existingFee = double.tryParse(cfKey?.toString() ?? '') ?? 0.0;
        // if (existingFee <= 0) {
        //   final fee = await loadCashbackFee(offlineOrderId: widget.activeOrderId.toString());
        //   if (fee > 0) {
        //     _order["cashbackFee"] = fee;
        //     _order["cashback_fee"] = fee;
        //     _order[AppDBConst.orderCashbackFee] = fee;
        //   }
        // }

        // Enrich from offline order (discount, balance for pending orders)
        final sqliteOrderDiscount =
            (_order[AppDBConst.orderDiscount] as num?)?.toDouble() ?? 0.0;
        final sqliteMerchantDiscount =
            (_order[AppDBConst.merchantDiscount] as num?)?.toDouble() ??
                (_order["merchantDiscount"] as num?)?.toDouble() ??
                0.0;
        final raw = await StorageProvider.offlineOrders
            .get(widget.activeOrderId.toString());
        if (raw != null && raw is Map) {
          final offline = Map<String, dynamic>.from(raw);
          // Restore cashback from offline order when SQLite/API snapshot misses it.
          if (existingFee <= 0) {
            final dynamic offlineCashbackRaw =
                offline['cashbackFee'] ?? offline['cashback_fee'] ?? 0;
            final double offlineCashback =
                double.tryParse(offlineCashbackRaw.toString()) ?? 0.0;
            if (offlineCashback > 0) {
              _order["cashbackFee"] = offlineCashback;
              _order["cashback_fee"] = offlineCashback;
              _order[AppDBConst.orderCashbackFee] = offlineCashback;
            }
          }
          if (sqliteOrderDiscount == 0) {
            final od =
            (offline['orderDiscount'] ?? offline['order_discount'] ?? 0)
                .toString();
            final odVal = double.tryParse(od) ?? 0.0;
            if (odVal > 0) {
              _order[AppDBConst.orderDiscount] = -odVal;
            } else {
              _order[AppDBConst.orderDiscount] = odVal;
            }
          }
          if (sqliteMerchantDiscount == 0) {
            final md = (offline['merchantDiscount'] ??
                offline['merchant_discount'] ??
                0)
                .toString();
            final mdVal = double.tryParse(md) ?? 0.0;
            if (mdVal > 0) {
              _order[AppDBConst.merchantDiscount] = -mdVal;
              _order["merchantDiscount"] = -mdVal;
            } else {
              _order[AppDBConst.merchantDiscount] = mdVal;
              _order["merchantDiscount"] = mdVal;
            }
          }
          // Enrich balance from offline storage (for pending orders)
          final rb = offline['remaining_balance'] ??
              offline['balance_amount'] ??
              offline['balanceAmount'];
          if (rb != null) {
            final balanceVal = double.tryParse(rb.toString());
            if (balanceVal != null && balanceVal >= 0) {
              balanceAmount = balanceVal;
            }
            _order["remaining_balance"] = rb;
            _order["balance_amount"] = rb;
            _order["balanceAmount"] = rb;
          }
          final tender = offline['tender_amount'] ?? offline['tenderAmount'];
          if (tender != null) {
            tenderAmount = double.tryParse(tender.toString()) ?? 0.0;
          }
          setState(() {});
        }
      }
      // Load balance from local payments for pending/offline orders
      // Load balance from local payments for pending/offline orders
      // Load balance from local payments for pending/offline orders.
      // Always refresh from LocalPayment summary to avoid stale tender/balance
      // after void + re-pay flows.
      if (widget.activeOrderId != null && mounted) {
        try {
          final summary = await LocalPaymentDBHelper.instance
              .getPaymentSummaryForOrder(widget.activeOrderId!);
          final paymentCount = (summary['paymentCount'] ?? 0.0).toDouble();
          // After loading from SQLite / Hive / preview
          final double authoritativeTax =
              (_order[AppDBConst.orderTax] as num?)?.toDouble() ??
                  (_order['wooTax'] as num?)?.toDouble() ??
                  (_order['order_tax'] as num?)?.toDouble() ?? 0.0;

          uiOrderTax = authoritativeTax;
          tax = authoritativeTax;
          _order[AppDBConst.orderTax] = authoritativeTax;

          if (paymentCount > 0) {
            tenderAmount = summary['totalPaid'] ?? 0.0;
            final remaining = summary['remainingBalance'];
            if (remaining != null) {
              balanceAmount = remaining;
            } else {
              final netPay =
              (_order["payable"] ?? _order["net_payable"]) as num?;
              if (netPay != null) {
                balanceAmount = (netPay.toDouble() - tenderAmount)
                    .clamp(0.0, double.infinity);
              }
            }
            setState(() {});
          }
        } catch (e) {
          if (kDebugMode) print("##### LocalPaymentDBHelper error: $e");
        }
      }
      await fetchOrderItems();
    } catch (e, st) {
      if (kDebugMode) {
        print("##### fetchOrdersData error: $e\n$st");
      }
    } finally {
      if (mounted &&
          requestSeq == _fetchOrdersDataSeq &&
          widget.activeOrderId == requestOrderId) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Updated didUpdateWidget to check activeOrderId
  @override
  void didUpdateWidget(OrderScreenPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ FIX: previously this called fetchOrdersData() on every rebuild where
    // widget.fetchOrders was true — and since the parent passes
    // fetchOrders: !isLoading (true almost all the time), that meant nearly
    // every parent setState() re-triggered a fetch here. Each new fetch bumps
    // _fetchOrdersDataSeq, which silently cancels the previous still-in-flight
    // fetch before it can call setState with real data — so if the parent
    // rebuilds faster than one fetch cycle, no fetch ever completes and the
    // panel gets stuck showing default/zero values (Order Status: '',
    // Woo refundTotal: null) until something breaks the rebuild loop, like
    // backgrounding the app.
    final bool fetchJustTurnedOn = widget.fetchOrders && !oldWidget.fetchOrders;
    final bool orderChanged = widget.activeOrderId != oldWidget.activeOrderId;

    if (fetchJustTurnedOn || orderChanged) {
      fetchOrdersData();
      return;
    }

    // Original behavior preserved as a fallback (kept for parity, though the
    // condition above now covers the activeOrderId-change case already).
    if (mounted && widget.activeOrderId != oldWidget.activeOrderId) {
      fetchOrdersData();
    }
  }

  /// Never null: list rows and payment helpers use `_order[...]` immediately after API
  /// preview fills `orderItems`, before `fetchOrder()` completes — `[]` on null was NoSuchMethodError.
  var _order = <String, dynamic>{AppDBConst.orderStatus: ''};
  // Build #1.0.118: Update fetchOrder to use widget.activeOrderId
  Future<void> fetchOrder() async {
    final int? requestOrderId = widget.activeOrderId;
    bool isStaleRequest() => !mounted || widget.activeOrderId != requestOrderId;

    if (requestOrderId == null) {
      _order = {AppDBConst.orderStatus: ''};
      orderServerId = null;
      return;
    }

    //1️⃣ Try normal SQLite order
    List<Map<String, dynamic>> ordersData =
    await orderHelper.getOrderById(requestOrderId);

    if (isStaleRequest()) return;

    if (ordersData.isNotEmpty) {
      _order = Map<String, dynamic>.from(ordersData.first);
      final rawServerId = _order[AppDBConst.orderServerId] ?? _order['order_id'] ?? _order['server_id'];
      final int serverId = rawServerId is num ? rawServerId.toInt() : int.tryParse(rawServerId?.toString() ?? '') ?? 0;
      final int localId = _order[AppDBConst.orderId] as int? ?? requestOrderId;
      orderServerId = serverId > 0 ? serverId : localId;

      // Merge Hive offline financial fields and status if available
      try {
        final offKey = (orderServerId ?? requestOrderId).toString();
        dynamic offRaw = await StorageProvider.offlineOrders.get(offKey);
        if (offRaw == null && localId > 0) {
          offRaw = await StorageProvider.offlineOrders.get(localId.toString());
        }
        if (offRaw is Map) {
          final offMap = Map<String, dynamic>.from(offRaw);
          _order["offline"] = true;
          if (offMap["order_status"] != null) {
            _order[AppDBConst.orderStatus] = offMap["order_status"].toString();
          }
          final gt = offMap["gross_total"] ?? offMap["total"];
          if (gt != null && ((_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0) == 0.0) {
            _order[AppDBConst.orderTotal] = (gt as num).toDouble();
          }
          final ot = offMap["order_tax"] ?? offMap["tax"];
          if (ot != null && ((_order[AppDBConst.orderTax] as num?)?.toDouble() ?? 0.0) == 0.0) {
            _order[AppDBConst.orderTax] = (ot as num).toDouble();
          }
          if (offMap["net_total"] != null) {
            _order["netTotal"] = (offMap["net_total"] as num).toDouble();
          }
          if (offMap["net_payable"] != null) {
            _order["payable"] = (offMap["net_payable"] as num).toDouble();
          }
          if (offMap["order_discount"] != null) {
            _order[AppDBConst.orderDiscount] = (offMap["order_discount"] as num).toDouble();
          }
          if (offMap["merchant_discount"] != null) {
            _order["merchantDiscount"] = (offMap["merchant_discount"] as num).toDouble();
          }
        }
      } catch (_) {}
    } else {
      // 2️⃣ FALLBACK → CHECK HIVE DELETED ORDERS
      final deletedBox = StorageProvider.deletedOrders;

      dynamic deleted = await deletedBox.get(requestOrderId.toString());

// 🔥 FIX: If not found by int → try string key
      if (deleted == null) {
        deleted = await deletedBox.get(requestOrderId.toString());
      }

      if (isStaleRequest()) return;

      if (deleted != null) {
        print("🔥 Deleted order FOUND in Hive for ID $requestOrderId");
        print("🔥 Deleted full data: $deleted");

        final map = Map<String, dynamic>.from(deleted);

        _order = {
          "id": map["order_id"],
          AppDBConst.orderStatus: "cancelled",
          "offline": true,

          // 🟦 FIXED FIELD NAMES (match deletedOrders box)
          AppDBConst.orderTotal:
          (map["gross_total"] as num?)?.toDouble() ?? 0.0,
          AppDBConst.orderDiscount:
          (map["order_discount"] as num?)?.toDouble() ?? 0.0,
          "merchantDiscount":
          (map["merchant_discount"] as num?)?.toDouble() ?? 0.0,
          AppDBConst.orderTax: (map["order_tax"] as num?)?.toDouble() ?? 0.0,

          //  FIXED NET + PAYABLE
          "netTotal": (map["net_total"] as num?)?.toDouble() ?? 0.0,
          "payable": (map["net_payable"] as num?)?.toDouble() ?? 0.0,

          AppDBConst.orderDate: map["created_at"] ?? DateTime.now().toString(),
        };

        print("🔥 Loaded ORDER from Hive = $_order");

        orderServerId = null;
        return;
      }

      // 3️⃣ FALLBACK → CHECK HIVE OFFLINE ORDERS (active orders with payouts/cashback)
      dynamic offlineRaw =
      await StorageProvider.offlineOrders.get(requestOrderId.toString());
      if (offlineRaw == null) {
        try {
          final db = await DBHelper.instance.database;
          final rows = await db.query(
            AppDBConst.orderTable,
            columns: [AppDBConst.orderId, AppDBConst.orderServerId],
            where: '${AppDBConst.orderId} = ? OR ${AppDBConst.orderServerId} = ?',
            whereArgs: [requestOrderId, requestOrderId],
          );
          if (rows.isNotEmpty) {
            final lid = rows.first[AppDBConst.orderId]?.toString();
            final sid = rows.first[AppDBConst.orderServerId]?.toString();
            if (lid != null && lid != requestOrderId.toString()) {
              offlineRaw = await StorageProvider.offlineOrders.get(lid);
            }
            if (offlineRaw == null && sid != null && sid != requestOrderId.toString()) {
              offlineRaw = await StorageProvider.offlineOrders.get(sid);
            }
          }
        } catch (_) {}
      }
      if (offlineRaw == null) {
        try {
          final box = StorageProvider.offlineOrders;
          final allOrders = await box.toMap();
          for (final v in allOrders.values) {
            if (v is Map) {
              final vid = v['order_id'] ?? v['id'] ?? v[AppDBConst.orderServerId];
              if (vid != null && vid.toString() == requestOrderId.toString()) {
                offlineRaw = v;
                break;
              }
            }
          }
        } catch (_) {}
      }
      if (isStaleRequest()) return;
      if (offlineRaw != null && offlineRaw is Map) {
        final map = Map<String, dynamic>.from(offlineRaw);
        final orderId = map["order_id"] ?? map["id"] ?? requestOrderId;
        final od = map["orderDiscount"] ?? map["order_discount"];
        final md = map["merchantDiscount"] ?? map["merchant_discount"];
        final cf = map["cashbackFee"] ?? map["cashback_fee"];
        _order = {
          "id": orderId,
          AppDBConst.orderServerId: orderId,
          AppDBConst.orderStatus:
          map["order_status"]?.toString() ?? "processing",
          AppDBConst.orderTotal:
          (map["gross_total"] as num?)?.toDouble() ?? 0.0,
          AppDBConst.orderDiscount:
          od != null ? (double.tryParse(od.toString()) ?? 0.0) : 0.0,
          "merchantDiscount":
          md != null ? (double.tryParse(md.toString()) ?? 0.0) : 0.0,
          AppDBConst.orderTax: (map["order_tax"] as num?)?.toDouble() ?? 0.0,
          "netTotal": (map["net_total"] as num?)?.toDouble() ?? 0.0,
          "payable": (map["net_payable"] as num?)?.toDouble() ?? 0.0,
          "remaining_balance": (map["remaining_balance"] ??
              map["balance_amount"] ??
              map["balanceAmount"]) as num?,
          "balance_amount": (map["balance_amount"] ??
              map["remaining_balance"] ??
              map["balanceAmount"]) as num?,
          "balanceAmount": (map["balanceAmount"] ??
              map["remaining_balance"] ??
              map["balance_amount"]) as num?,
          "cashbackFee":
          cf != null ? (double.tryParse(cf.toString()) ?? 0.0) : 0.0,
          "cashback_fee":
          cf != null ? (double.tryParse(cf.toString()) ?? 0.0) : 0.0,
          AppDBConst.orderCashbackFee:
          cf != null ? (double.tryParse(cf.toString()) ?? 0.0) : 0.0,
          AppDBConst.orderDate:
          map["created_at"]?.toString() ?? DateTime.now().toString(),
          "offline": true,
        };
        orderServerId = _order[AppDBConst.orderServerId] as int?;
        final rb = map["remaining_balance"] ??
            map["balance_amount"] ??
            map["balanceAmount"];
        if (rb != null) {
          final v = (rb as num?)?.toDouble();
          if (v != null && v >= 0) balanceAmount = v;
        }
        final tender = map["tender_amount"] ?? map["tenderAmount"];
        if (tender != null) tenderAmount = (tender as num).toDouble();
        if (kDebugMode) {
          print(
              "🟦 Loaded offline order from Hive (payouts/cashback): $_order");
        }
        return;
      }

      // No local row yet: keep list API snapshot so status/discounts stay visible until sync.
      final snap = widget.previewOrderFromApi;
      if (snap != null && snap.id == requestOrderId) {
        _order = orderPanelOrderMapFromOrderModel(snap);
        _wooOrder = snap;
        orderServerId = snap.id;
        if (kDebugMode) {
          print(
              '🟦 Order panel: preview OrderModel kept (no SQLite row for id $requestOrderId)');
        }
      } else {
        _order = {AppDBConst.orderStatus: ''};
        orderServerId = null;
      }
    }

    // Fetch payments only for online orders
    if (orderServerId != null) {
      _fetchPaymentsByOrderId();
    }
    // Fetch payments + Woo order
    if (orderServerId != null) {
      _fetchPaymentsByOrderId();
      await _fetchWooOrder(orderServerId!); // ⭐ ADD THIS
    }
  }

  // Build #1.0.10: Fetches order items for the active order

  // Future<void> fetchOrderItems() async {
  //   final int requestId = ++_fetchOrderItemsSeq;
  //   final int? requestOrderId = widget.activeOrderId;
  //   if (requestOrderId == null) {
  //     if (mounted && requestId == _fetchOrderItemsSeq) {
  //       setState(() => orderItems.clear());
  //     }
  //     return;
  //   }
  //
  //   // 1️⃣ Try SQLite items
  //   try {
  //     List<Map<String, dynamic>> items =
  //         await orderHelper.getOrderItems(requestOrderId);
  //
  //     if (!mounted ||
  //         widget.activeOrderId != requestOrderId ||
  //         requestId != _fetchOrderItemsSeq) {
  //       return;
  //     }
  //
  //     if (items.isNotEmpty) {
  //       print("🟦 SQLite Order Items Loaded: $items");
  //
  //       List<Map<String, dynamic>> processedItems = [];
  //
  //       for (var item in items) {
  //         final rawTotal = item[AppDBConst.itemSumPrice];
  //         final rawQty = item[AppDBConst.itemCount];
  //
  //         final name =
  //             item[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
  //
  //         final bool isDiscountItem = name.contains("discount");
  //
  //         final double total = rawTotal is num
  //             ? rawTotal.toDouble()
  //             : double.tryParse(rawTotal?.toString() ?? "0") ?? 0.0;
  //
  //         final int qty = rawQty is int
  //             ? rawQty
  //             : int.tryParse(rawQty?.toString() ?? "1") ?? 1;
  //
  //         final double unitPrice = qty > 0 ? total / qty : 0.0;
  //         final variationId = item[AppDBConst.itemVariationId] ?? 0;
  //         final variationName =
  //             item[AppDBConst.itemVariationCustomName]?.toString() ?? "";
  //
  //         /// 🔍 DEBUG PRINTS (ADD HERE) sql
  //         print("🟡 Variant: ${item[AppDBConst.itemVariationCustomName]}");
  //         print("🟡 Variant ID: ${item[AppDBConst.itemVariationId]}");
  //         print("🟡 EBT Eligible: ${item[AppDBConst.isEbtEligible]}");
  //         processedItems.add({
  //           ...item,
  //
  //           /// store only if real variant
  //           "attribute_variant": variationId > 0 ? variationName : "",
  //           "variant_name": variationId,
  //
  //           "ebt_eligible": item[AppDBConst.isEbtEligible] ?? 0,
  //           AppDBConst.itemPrice: unitPrice,
  //           AppDBConst.itemSumPrice: total,
  //           "is_discount_item": isDiscountItem
  //         });
  //       }
  //
  //       if (requestId != _fetchOrderItemsSeq) return;
  //       setState(() => orderItems = processedItems);
  //       return;
  //     }
  //   } catch (_) {}

  Future<void> fetchOrderItems() async {
    final int requestId = ++_fetchOrderItemsSeq;
    final int? requestOrderId = widget.activeOrderId;
    if (requestOrderId == null) {
      if (mounted && requestId == _fetchOrderItemsSeq) {
        setState(() => orderItems.clear());
      }
      return;
    }

    // 1️⃣ Try SQLite items
    try {
      List<Map<String, dynamic>> items =
      await orderHelper.getOrderItems(requestOrderId);

      if (!mounted ||
          widget.activeOrderId != requestOrderId ||
          requestId != _fetchOrderItemsSeq) {
        return;
      }

      if (items.isNotEmpty) {
        print("🟦 SQLite Order Items Loaded: $items");

        // ── Build a lookup map from the current API-preview orderItems so we
        //    can restore weighted fields that SQLite does not persist. ──────────
        final Map<String, Map<String, dynamic>> previewByName = {};
        for (final prev in orderItems) {
          final n = prev[AppDBConst.itemName]?.toString() ?? '';
          if (n.isNotEmpty) previewByName[n] = prev;
        }

        List<Map<String, dynamic>> processedItems = [];

        for (var item in items) {
          final rawTotal = item[AppDBConst.itemSumPrice];
          final rawQty   = item[AppDBConst.itemCount];
          final name     = item[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
          final bool isDiscountItem = name.contains("discount");

          final double total = rawTotal is num
              ? rawTotal.toDouble()
              : double.tryParse(rawTotal?.toString() ?? "0") ?? 0.0;

          final int qty = rawQty is int
              ? rawQty
              : int.tryParse(rawQty?.toString() ?? "1") ?? 1;

          final double unitPrice = qty > 0 ? total / qty : 0.0;
          final variationId   = item[AppDBConst.itemVariationId] ?? 0;
          final variationName = item[AppDBConst.itemVariationCustomName]?.toString() ?? "";

          print("🟡 Variant: ${item[AppDBConst.itemVariationCustomName]}");
          print("🟡 Variant ID: ${item[AppDBConst.itemVariationId]}");
          print("🟡 EBT Eligible: ${item[AppDBConst.isEbtEligible]}");

          // ── Restore weighted-item fields from the API preview if SQLite
          //    did not persist them (is_weighted, weight_qty, unit_price …) ──
          final String itemNameKey = item[AppDBConst.itemName]?.toString() ?? '';
          final Map<String, dynamic>? previewItem = previewByName[itemNameKey];

          bool   isWeighted  = item['is_weighted'] == true || item['item_type'] == 'weighted';
          double weightQty   = (item['weight_qty']  as num?)?.toDouble() ?? 0.0;
          String weightUnit  = item['weightUnit']?.toString() ?? 'lb';
          double wUnitPrice  = (item['unit_price']  as num?)?.toDouble() ?? 0.0;
          double displayQty  = (item['display_qty'] as num?)?.toDouble() ?? 0.0;

          // If SQLite row is missing weighted data but the API preview had it,
          // restore from preview so the UI never flickers to non-weighted display.
          if (!isWeighted && previewItem != null) {
            final prevWeighted = previewItem['is_weighted'] == true ||
                previewItem['item_type'] == 'weighted';
            if (prevWeighted) {
              isWeighted = true;
              weightQty  = (previewItem['weight_qty']  as num?)?.toDouble() ?? weightQty;
              weightUnit = previewItem['weightUnit']?.toString() ?? weightUnit;
              wUnitPrice = (previewItem['unit_price']  as num?)?.toDouble() ?? wUnitPrice;
              displayQty = (previewItem['display_qty'] as num?)?.toDouble() ?? displayQty;
              print("⚖️ Restored weighted fields from API preview for: $itemNameKey");
            }
          }

          // If still no unit_price for weighted item, derive it from total/weightQty
          if (isWeighted && wUnitPrice == 0 && weightQty > 0) {
            wUnitPrice = total / weightQty;
          }

          processedItems.add({
            ...item,
            "attribute_variant": variationId > 0 ? variationName : "",
            "variant_name":      variationId,
            "ebt_eligible":      item[AppDBConst.isEbtEligible] ?? 0,
            AppDBConst.itemPrice:    unitPrice,
            AppDBConst.itemSumPrice: total,
            "is_discount_item":  isDiscountItem,

            // ── Always write the resolved weighted fields back ──────────────
            'is_weighted':  isWeighted,
            'item_type':    isWeighted ? 'weighted' : (item['item_type'] ?? 'product'),
            'weight_qty':   weightQty,
            'weightUnit':   weightUnit,
            'unit_price':   isWeighted ? wUnitPrice : unitPrice,
            'display_qty':  isWeighted && displayQty > 0 ? displayQty : weightQty,
          });
        }

        if (requestId != _fetchOrderItemsSeq) return;
        setState(() => orderItems = processedItems);
        return;
      }
    } catch (_) {}
    if (!mounted ||
        widget.activeOrderId != requestOrderId ||
        requestId != _fetchOrderItemsSeq) {
      return;
    }

    final deletedBox = StorageProvider.deletedOrders;

    final deleted = await deletedBox.get(requestOrderId.toString());

    if (!mounted ||
        widget.activeOrderId != requestOrderId ||
        requestId != _fetchOrderItemsSeq) {
      return;
    }

    if (deleted != null) {
      print("🔥 Loading DELETED ORDER ITEMS for ID = $requestOrderId");
      if (_order is Map) {
        (_order as Map)[AppDBConst.orderStatus] = "cancelled";
      }

      final List productList = deleted["products"] ?? [];
      final List cashbackList = deleted["cashbacks"] ?? [];
      final List payoutList = deleted["payouts"] ?? [];

      List<Map<String, dynamic>> mergedItems = [];

      // 🔵 PRODUCTS
      for (var p in productList) {
        mergedItems.add({
          AppDBConst.itemName: p["name"],
          AppDBConst.itemPrice: p["price"],
          AppDBConst.itemCount: p["quantity"],
          AppDBConst.itemSumPrice: (p["price"] ?? 0) * (p["quantity"] ?? 1),
          AppDBConst.itemImage: p["image"] ?? "",
          AppDBConst.itemType: "product",
        });
      }

      // 🟢 CASHBACKS
      for (var c in cashbackList) {
        mergedItems.add({
          AppDBConst.itemName: c["item_name"] ?? "Cashback",
          AppDBConst.itemPrice: c["item_price"] ?? c["amount"],
          AppDBConst.itemCount: c["items_count"] ?? 1,
          AppDBConst.itemSumPrice: c["item_sum_price"] ?? c["amount"],
          AppDBConst.itemImage: c["product_image"] ?? "",
          AppDBConst.itemType: "cashback",
        });
      }

      // 🔴 PAYOUTS
      for (var p in payoutList) {
        mergedItems.add({
          AppDBConst.itemName: p["product_name"] ?? "Payout",
          AppDBConst.itemPrice: p["amount"],
          AppDBConst.itemCount: 1,
          AppDBConst.itemSumPrice: p["amount"],
          AppDBConst.itemImage: p["product_image"] ?? "",
          AppDBConst.itemType: "payout",
        });
      }

      orderItems = mergedItems;

      print("🔥 Final Loaded Deleted OrderItems = $orderItems");

      if (requestId != _fetchOrderItemsSeq) return;
      setState(() {});
      return;
    }

    // 3️⃣ Nothing found
    if (mounted &&
        widget.activeOrderId == requestOrderId &&
        requestId == _fetchOrderItemsSeq) {
      setState(() => orderItems.clear());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    // Do not call fetchOrderItems() here: initState/didUpdateWidget already run
    // fetchOrdersData() which awaits fetchOrderItems(). A duplicate call races
    // when switching orders and can leave stale rows or throw.
  }

  @override
  @override
  void dispose() {
    if (_orderPanelRefreshListener != null) {
      OrderHelper.orderPanelRefreshNotifier
          .removeListener(_orderPanelRefreshListener!);
    }
    _updateOrderSubscription?.cancel(); // Cancel the subscription
    // orderBloc.dispose(); // Dispose the bloc if needed // Build #1.0.143: No need
    _fetchOrdersSubscription?.cancel();
    // orderBloc.dispose();
    productBloc.dispose();
    _tabController?.dispose();
    _productBySkuSubscription
        ?.cancel(); // Build #1.0.44 : Added Cancel product subscription
    productBloc.dispose(); // Added: Dispose ProductBloc
    _paymentListSubscription?.cancel(); // Build #1.0.221
    paymentBloc.dispose();
    super.dispose();
  }

  Future<String> getDeviceId() async {
    // Build #1.0.44 : Get Device Id
    final storeValidationRepository = StoreValidationRepository();
    try {
      final deviceDetails = await GlobalUtility
          .getDeviceDetails(); //Build #1.0.126: updated to GlobalUtility
      return deviceDetails['device_id'] ?? 'unknown';
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching device ID: $e');
      }
      return 'unknown';
    }
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.30,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.only(top: 10),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              // Header shimmer
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              // Content shimmer
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 100,
                                height: 10,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer shimmer
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 40,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // final RightOrderPanel orderScreenPanel = RightOrderPanel(formattedDate: '', formattedTime: '', quantities: []);

    // If no order is active, display a blank panel.
    return (!widget.fetchOrders)
        ? _buildShimmerEffect()
    //     ? Container(
    //   width: MediaQuery.of(context).size.width * 0.30,
    //   padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    //   child: Card(
    //     elevation: 4,
    //     margin: const EdgeInsets.only(top: 10),
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    //     child: Container(), // Shows an empty card
    //   ),
    // )

    // If an order is active, build the regular order panel.
        : Container(
      width: MediaQuery.of(context).size.width * 0.31,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(top: 10),

        // ⬅ Rounded corners (works same for dark & light)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          children: [
            // ⬅ Header section
            Container(
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.primaryBackground
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12), // match card rounding
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "#${widget.activeOrderId ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StatusWidget(
                        status: _order?[AppDBConst.orderStatus] ?? '',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ⬅ Content below the header
            Expanded(
              child: buildCurrentOrder(),
            ),
          ],
        ),
      ),
    );
  }

  //Build #1.0.67: Handler methods for response and error
  Future<void> _handleResponse(
      APIResponse response,
      Map<String, dynamic> orderItem, {
        bool isPayout = false,
        bool isCoupon = false,
        bool isCustomItem = false,
        VoidCallback? retryCallback, // Call back
      }) async {
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (response.status == Status.COMPLETED) {
      if (Misc.showDebugSnackBar) {
        // Build #1.0.254
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                "${isPayout ? TextConstants.payout : isCoupon ? TextConstants.coupon : isCustomItem ? TextConstants.customItem : 'Item'}"
                    "${TextConstants.removedSuccessfully}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await orderHelper.deleteItem(orderItem[AppDBConst.itemId]);
      await fetchOrderItems();
      widget.refreshOrderList?.call();
    } else if (response.status == Status.ERROR) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(response.message ??
              "${TextConstants.failedToRemove}"
                  "${isPayout ? TextConstants.payout : isCoupon ? TextConstants.coupon : isCustomItem ? TextConstants.coupon : 'item'}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (isPayout) {
        await CustomDialog.showDiscountNotApplied(
          context,
          errorMessageTitle: TextConstants.removePayoutFailed,
          errorMessageDes:
          response.message ?? TextConstants.discountNotAppliedDescription,
          onRetry: retryCallback, // Pass retry callback
        );
      } else if (isCoupon) {
        await CustomDialog.showCouponNotApplied(
          context,
          errorMessageTitle: TextConstants.removeCouponFailed,
          errorMessageDes:
          response.message ?? TextConstants.couponNotAppliedDescription,
          onRetry: retryCallback, // Pass retry callback
        );
      } else if (isCustomItem) {
        await CustomDialog.showCustomItemNotAdded(
          context,
          errorMessageTitle: TextConstants.removeCustomItemFailed,
          errorMessageDes: response.message ??
              TextConstants.customItemCouldNotBeAddedDescription,
          onRetry: retryCallback,
        );
      }
    }
  }

  DateTime? _getBestDateTime() {
    // Helper to safely parse and localize
    DateTime? parseAndLocal(String? dateStr) {
      if (dateStr == null || dateStr.trim().isEmpty) return null;
      return DateTime.tryParse(dateStr.trim())?.toLocal();
    }

    // 1. Priority from _wooOrder (full API data - most accurate)
    if (_wooOrder != null && _wooOrder!.id == widget.activeOrderId) {
      final dt = parseAndLocal(_wooOrder!.datePaid) ??
          parseAndLocal(_wooOrder!.dateCompleted) ??
          parseAndLocal(_wooOrder!.dateCreated);
      if (dt != null) return dt;
    }

    // 2. Priority from previewOrderFromApi (list API snapshot)
    if (widget.previewOrderFromApi != null &&
        widget.previewOrderFromApi!.id == widget.activeOrderId) {
      final dt = parseAndLocal(widget.previewOrderFromApi!.datePaid) ??
          parseAndLocal(widget.previewOrderFromApi!.dateCompleted) ??
          parseAndLocal(widget.previewOrderFromApi!.dateCreated);
      if (dt != null) return dt;
    }

    // 3. Fallback to local _order map (SQLite / Hive)
    if (_order.isNotEmpty) {
      // Check these keys in priority order
      final candidates = [
        _order['date_paid'],
        _order['datePaid'],
        _order['date_completed'],
        _order['dateCompleted'],
        _order[AppDBConst.orderDate],
        _order['date_created'],
        _order['created_at'],
      ];

      for (final candidate in candidates) {
        final dt = parseAndLocal(candidate?.toString());
        if (dt != null) return dt;
      }
    }

    // 4. Absolute fallback (should rarely hit)
    return null;
  }

  Widget buildCurrentOrder() {
    final theme = Theme.of(context);
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final ScrollController _scrollController = ScrollController();
    final order = _order ?? {};

    String displayDate = "";
    String displayTime = "";

    final DateTime? bestDateTime = _getBestDateTime();



    if (bestDateTime != null) {
      displayDate = DateFormat(TextConstants.dateFormat).format(bestDateTime);

      //  Changed to 12-hour format with AM/PM
      displayTime = DateFormat('hh:mm:ss a').format(bestDateTime);

    } else if (order.isNotEmpty && order[AppDBConst.orderDate] != null) {
      // Fallback
      try {
        final DateTime createdDateTime =
        DateTime.parse(order[AppDBConst.orderDate].toString());

        displayDate = DateFormat(TextConstants.dateFormat).format(createdDateTime);

        //  Changed here also
        displayTime = DateFormat('hh:mm:ss a').format(createdDateTime);

      } catch (e) {
        print("Error parsing date: $e");
        displayDate = order[AppDBConst.orderDate].toString().split(' ').first;
        displayTime = ""; // or handle accordingly
      }
    }

    // Build #1.0.268: Determine Coupon and Merchant Discount exclusively from line items or metadata
    // This avoids double-counting item-level discounts (Multipack, Auto, Combo) which are already in Gross Total.
    double orderDiscount = 0.0;
    double merchantDiscount = 0.0;

    // 1?? Check for explicit metadata for Coupons from API (check multiple possible keys & meta_data array)
    double metaCouponVal = double.tryParse(order['couponValue']?.toString() ??
        order['coupon_total']?.toString() ??
        order['coupon_amount']?.toString() ??
        order['coupon_value']?.toString() ??
        order['discount']?.toString() ?? // From standard WC/POS API field
        order['order_discount']?.toString() ??
        order['discount_total']?.toString() ??
        order['discountTotal']?.toString() ??
        '') ??
        0.0;

    // Check meta_data array for any coupon-related keys
    if (order['meta_data'] is List) {
      for (var m in order['meta_data']) {
        if (m is Map) {
          final key = m['key']?.toString().toLowerCase() ?? '';
          if (key == 'couponvalue' ||
              key == 'coupon_total' ||
              key == 'coupon_amount' ||
              key == 'coupon_value' ||
              key == '_order_discount') {
            final val = double.tryParse(m['value']?.toString() ?? '') ?? 0.0;
            if (val != 0) {
              metaCouponVal += val;
            }
          }
        }
      }
    }


    // 2?? Specifically sum up values from coupon_lines if available (standard WooCommerce structure)
    double couponLinesSum = 0.0;
    bool discountsFromCouponLines = false;

    // === FIXED: PROPER SEPARATION OF COUPON vs MERCHANT DISCOUNT ===
    if (order['coupon_lines'] is List) {
      for (var c in order['coupon_lines']) {
        if (c is Map) {
          final code = (c['code']?.toString() ?? '').toLowerCase();
          final discStr = c['discount']?.toString() ?? '0.0';
          final disc = double.tryParse(discStr) ?? 0.0;

          if (code.contains('merchant_discount')) {
            merchantDiscount += disc;           // ← Merchant Discount
          } else {
            orderDiscount += disc;              // ← Regular Coupon
            couponLinesSum += disc; // <-- bala
          }
        }
      }
    }

    // if (order['coupon_lines'] is List) {
    //   for (var c in order['coupon_lines']) {
    //     if (c is Map) {
    //       final code = (c['code']?.toString() ?? '').toLowerCase();
    //       final disc = (double.tryParse(c['discount']?.toString() ?? '0') ?? 0.0).abs();
    //       if (disc == 0) continue;
    //       discountsFromCouponLines = true;
    //       if (code.contains('merchant_discount')) {
    //         merchantDiscount -= disc;   // always negative
    //       } else {
    //         orderDiscount -= disc;      // always negative
    //       }
    //     }
    //   }
    // }

    if (orderDiscount == 0 && order['meta_data'] is List) {
      for (var m in order['meta_data']) {
        if (m is Map) {
          final key = m['key']?.toString().toLowerCase() ?? '';
          final val = double.tryParse(m['value']?.toString() ?? '0') ?? 0.0;
          if (key.contains('merchant_discount') || key == '_merchant_discount') {
            merchantDiscount += val;
          } else if (key.contains('coupon') || key.contains('discount_total')) {
            orderDiscount += val;
          }
        }
      }
    }

    // Prioritize metadata or coupon_lines
    if (couponLinesSum != 0) {
      orderDiscount = orderDiscount > 0 ? -orderDiscount : orderDiscount;
    } else if (metaCouponVal != 0) {
      merchantDiscount = merchantDiscount > 0 ? -merchantDiscount : merchantDiscount;
    }

    // 3?? Iterate through line items as a fallback for manually added coupons or merchant discounts
    for (var item in orderItems) {
      final nameLower = item['item_name']?.toString().toLowerCase() ?? '';
      final typeLower = item['item_type']?.toString().toLowerCase() ?? '';
      final itemSumPrice = double.tryParse(item['item_sum_price']?.toString() ??
          item['amount']?.toString() ??
          '') ??
          0.0;

      if (nameLower.contains('coupon') || typeLower.contains('coupon')) {
        // If we haven't found a metadata coupon yet, sum up individual coupon items
        // if (orderDiscount == 0) {
        //   orderDiscount += itemSumPrice > 0 ? -itemSumPrice : itemSumPrice;
        // }

        // Final fallback from order level (discount_total usually = coupon only)
        if (orderDiscount == 0) {
          final rawDisc = double.tryParse(order['discount_total']?.toString() ??
              order['discountTotal']?.toString() ?? '0') ?? 0.0;
          orderDiscount = rawDisc;
        }

      } else if (nameLower.contains('merchant discount') ||
          typeLower.contains('merchant discount') ||
          (nameLower == 'discount' && typeLower == 'discount') ||
          nameLower == 'discount') {
        merchantDiscount += itemSumPrice > 0 ? -itemSumPrice : itemSumPrice;
      }
    }

    if (kDebugMode) {
      print("### Evaluated Summary Discounts:");
      print("### orderDiscount (Coupon): $orderDiscount");
      print("### merchantDiscounttttttt: $merchantDiscount");
    }


    // Fallback: some orders store merchant discount at order-level only
    // (without a dedicated discount line item in orderItems).
    // if (merchantDiscount == 0) {
    //   final dynamic rawMerchantDiscount = order[AppDBConst.merchantDiscount] ??
    //       order['merchantDiscount'] ??
    //       order['merchant_discount'] ??
    //       0.0;
    //   final double orderLevelMerchantDiscount = (rawMerchantDiscount is num)
    //       ? rawMerchantDiscount.toDouble()
    //       : (double.tryParse(rawMerchantDiscount.toString()) ?? 0.0);
    //   if (orderLevelMerchantDiscount != 0) {
    //     merchantDiscount = -orderLevelMerchantDiscount.abs();
    //   }
    // }

    if (merchantDiscount == 0) {
      final dynamic rawFallback =
          order['merchantDiscount'] ??
              order[AppDBConst.merchantDiscount] ??
              order['merchant_discount'];
      if (rawFallback != null) {
        final double rawVal = (rawFallback is num)
            ? rawFallback.toDouble()
            : (double.tryParse(rawFallback.toString()) ?? 0.0);
        // Accept any non-zero value, no matter how small
        if (rawVal.abs() > 0) {
          merchantDiscount = -rawVal.abs();
        }
      }
    }

    double grossTotal = 0.0;
    double itemLevelDiscountTotal = 0.0;

    for (var item in orderItems) {
      // Extract item name and type (fallback-safe)
      // final name = (item["item_name"] ?? item["name"] ?? "").toString().toLowerCase();
      // final type = (item["item_type"] ?? item["type"] ?? "").toString().toLowerCase();

      // ❌ SKIP unwanted items
      final name = item["item_name"]?.toString().toLowerCase() ?? "";
      final type = item["item_type"]?.toString().toLowerCase() ?? "";
      final isRefunded = item[AppDBConst.isRefundItem] == 1 ||
          item[AppDBConst.isRefundItem] == true;
      final itemSumPrice =
          double.tryParse(item["item_sum_price"]?.toString() ?? "") ?? 0.0;

      // ✅ FIRST: Extract merchant discount
      if (name.contains("merchant discount") ||
          type.contains("merchant discount") ||
          name == "discount") {
        // merchantDiscount += itemSumPrice > 0 ? -itemSumPrice : itemSumPrice;
        continue; // skip further processing
      }

      final skip = name.contains("discount") ||
          name.contains("merchant discount") ||
          name.contains("coupon") ||
          name.contains("loyalty") || // FIXED
          name.contains("redeemed") ||
          name.contains("points") ||
          type.contains("discount") ||
          type.contains("coupon") ||
          type.contains("loyalty") || // FIXED
          type.contains("points");

      if (skip || isRefunded) {
        print("🚫 EXCLUDED (Refund/Skip) → ${item["item_name"]}");
        continue;
      }

      // Qty fallback logic
      final qty = int.tryParse(item["items_count"]?.toString() ??
          item["itemCount"]?.toString() ??
          "1") ??
          1;

      // Price priority
      // Price priority — use item_sum_price (already discounted) directly
      // Do NOT fall back to item_price/price as those hold original/unit price
      double unitPrice =
          double.tryParse(item["item_sum_price"]?.toString() ?? "") ??
              double.tryParse(item["amount"]?.toString() ?? "") ??
              0.0;
      // If item_sum_price is 0, only then fall back to unit price keys
      if (unitPrice == 0.0) {
        unitPrice =
            double.tryParse(item["item_price"]?.toString() ?? "") ??
                double.tryParse(item["price"]?.toString() ?? "") ??
                0.0;
      }

      // Extract item-level discounts accurately from meta
      String dType = (item['discount_type'] ?? '').toString().toLowerCase();

      double autoD =
          (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;
      double multiD =
          (item[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
      double comboD =
          (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
      double mixD =
          (item['mixmatch_discount_total'] as num?)?.toDouble() ?? 0.0;

      // Logic matching order_summary_screen.dart: Use dType to avoid double-counting same discount under different keys
      double itemSavings = 0.0;
      if (dType == 'multipack') {
        itemSavings = multiD > 0 ? multiD : autoD;
      } else if (dType == 'combo') {
        itemSavings = comboD > 0 ? comboD : autoD;
      } else if (dType == 'mixmatch') {
        itemSavings = mixD > 0 ? mixD : autoD;
      } else {
        itemSavings = autoD; // Default to auto
      }

      // Add to merchant discount (as negative value) only if not already accounted for by a global line item
      // We skip items named "Merchant Discount" already, so we can sum these safely here.
      // merchantDiscount -= itemSavings;
      itemLevelDiscountTotal += itemSavings;

      grossTotal += unitPrice;
    }


    final double couponOnlyDiscount = (() {
      double couponLinesSumLocal = 0.0;
      if (_order['coupon_lines'] is List) {
        for (var c in _order['coupon_lines']) {
          if (c is Map) {
            couponLinesSumLocal += double.tryParse(c['discount']?.toString() ?? '') ?? 0.0;
          }
        }
      }
      if (couponLinesSumLocal > 0) return couponLinesSumLocal;

      // Check if we have item-level discounts in orderItems
      final bool hasItemLevelDiscounts = orderItems.any((item) {
        final autoD = (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;
        final multiD = (item[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
        final comboD = (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
        return autoD > 0 || multiD > 0 || comboD > 0;
      });

      if (hasItemLevelDiscounts) return 0.0;

      return orderDiscount.abs();
    })();

    // ✅ FIX: orderDiscount should only be coupon/order-level discount
// NOT item-level auto/combo/multipack discounts (those are in line items)
// Item-level discounts are already embedded in itemsForSummary line items
// and will be subtracted by _recalculateGrossAndNetFromLineItemDiscounts()
// So pass 0.0 for orderDiscount when it only reflects item-level discounts

    print("### Gross Total Calculated: $grossTotal");

    // Cached values may be numbers or strings depending on whether the
    // snapshot came from SQLite, Isar, or the offline queue.
    double asAmount(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;
    double wooTax = asAmount(order['wooTax']);
    double wooTotal = asAmount(order['wooTotal']);

    double sqliteTax = asAmount(order[AppDBConst.orderTax]);
    double sqliteTotal = asAmount(order[AppDBConst.orderTotal]);

    // TAX: Woo overrides SQLite
    double orderTax = wooTax > 0 ? wooTax : sqliteTax;
    if (orderTax == 0.0) {
      double itemsTax = 0.0;
      for (var item in orderItems) {
        final t = asAmount(
          item['item_tax'] ?? item['tax'] ?? item['total_tax'],
        );
        itemsTax += t;
      }
      if (itemsTax > 0) {
        orderTax = itemsTax;
      } else {
        // Offline snapshots may retain a tax rate but not a precomputed tax
        // amount. Calculate from each stored line, never from another item.
        for (final item in orderItems) {
          final status = item['tax_status']?.toString().toLowerCase() ??
              'taxable';
          final rate = double.tryParse(item['tax_rate']?.toString() ?? '') ??
              0.0;
          if (status != 'taxable' || rate <= 0) continue;
          final lineTotal = asAmount(item[AppDBConst.itemSumPrice]) > 0
              ? asAmount(item[AppDBConst.itemSumPrice])
              : asAmount(item[AppDBConst.itemPrice]) *
              (int.tryParse(item[AppDBConst.itemCount]?.toString() ?? '') ??
                  1);
          orderTax += roundTaxHalfUp(lineTotal * rate / 100);
        }
      }
    }

    double cashbackFee = 0.0;

    final wooOrderId = order['wooOrderId']?.toString() ??
        widget.activeOrderId?.toString() ??
        "";

    // Load Redeem Data from order (pre-loaded from storage by parent)
    if (wooOrderId.isNotEmpty && order["redeemed_value"] != null) {
      hiveRedeemedValue = (order["redeemed_value"] as num).toDouble();
      hiveRedeemedPoints = (order["redeemed_points"] as num?)?.toInt() ?? 0;
      hiveAvailablePoints =
          (order["available_points_after_redeem"] as num?)?.toInt() ?? 0;
      print(
          "💠 Redeem from order → Value: $hiveRedeemedValue | Points: $hiveRedeemedPoints");
    }

    int totalItems = 0;

    for (var item in orderItems) {
      final name = item[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
      final type = item[AppDBConst.itemType]?.toString().toLowerCase() ?? "";

// FILTER OUT ALL DISCOUNT/PAYOUT/COUPON ITEMS
      if (name.contains("discount") ||
          type.contains("discount") ||
          name.contains("merchant discount") ||
          type.contains("merchant discount") ||
          type.contains("payout") ||
          type.contains("coupon") ||
          type.contains("cashback") ||
          name.contains("payout") ||
          name.contains("coupon") ||
          name.contains("cashback")) {
        continue;
      }

      final qty = (item[AppDBConst.itemCount] as num?)?.toInt() ?? 1;
      totalItems += qty;
    }

    final bool isPayoutOrCashbackOnlyOrder = orderItems.isNotEmpty &&
        orderItems.every((item) {
          final name = (item[AppDBConst.itemName] ?? item['item_name'] ?? '')
              .toString()
              .toLowerCase();
          final type = (item[AppDBConst.itemType] ?? item['item_type'] ?? '')
              .toString()
              .toLowerCase();

          final isAdjustmentMeta = name.contains("discount") ||
              name.contains("merchant discount") ||
              name.contains("coupon") ||
              name.contains("loyalty") ||
              name.contains("points") ||
              name.contains("redeemed") ||
              type.contains("discount") ||
              type.contains("merchant discount") ||
              type.contains("coupon") ||
              type.contains("loyalty") ||
              type.contains("points");

          if (isAdjustmentMeta) return true;

          return type.contains("payout") ||
              type.contains("cashback") ||
              name == "payout" ||
              name == "cashback";
        });

    final cf = order["cashbackFee"] ?? order["cashback_fee"] ?? 0.0;
    cashbackFee = double.tryParse(cf.toString()) ?? 0.0;

    // Build #1.0.269: Source of truth for tax (Woo > SQLite)
    // Moving this BEFORE computedNetTotal for accurate math
    if (wooTax > 0) {
      orderTax = wooTax;
    } else if (sqliteTax > 0) {
      orderTax = sqliteTax;
    }

    if (isPayoutOrCashbackOnlyOrder) {
      orderTax = 0.0;
    }

    // Recalculate percentage-based merchant discount w.r.t grossTotal
    final String mdType = order['merchantDiscountType']?.toString() ?? 'fixed';
    final double mdPerc = double.tryParse(order['merchantDiscountPercentage']?.toString() ?? '0') ?? 0.0;

    double calculatedPerc = 0.0;
    if (mdType == 'percentage' && mdPerc > 0) {
      calculatedPerc = mdPerc;
      double base = grossTotal - orderDiscount.abs();
      if (base > 0) {
        merchantDiscount = -(base * mdPerc / 100.0);
      } else {
        merchantDiscount = 0.0;
      }
    } else if (mdType == 'fixed' && merchantDiscount.abs() > 0) {
      double base = grossTotal - orderDiscount.abs();
      if (base > 0) {
        calculatedPerc = (merchantDiscount.abs() / base) * 100.0;
      }
    }
    //
    // if (order['offline'] != true && calculatedPerc > 0) {
    //   orderTax = orderTax * (1 - calculatedPerc / 100.0);
    //   orderTax = roundTaxHalfUp(orderTax);
    // }

    // Only recalculate tax if we don't have a WooCommerce tax value
    if (wooTax == 0 && order['offline'] == true && calculatedPerc > 0) {
      // Offline order with no Woo tax – apply merchant discount percentage to local tax
      orderTax = orderTax * (1 - calculatedPerc / 100.0);
      orderTax = roundTaxHalfUp(orderTax);
    }

    // Prefer Woo fee_lines merchant_discount (total + total_tax) for synced orders.
    final dynamic feeLinesRaw =
        _wooOrder?.feeLines ?? order['fee_lines'] ?? order['feeLines'];
    final double feeLineMerchantDiscount =
    merchantDiscountFromFeeLines(feeLinesRaw);
    if (feeLineMerchantDiscount.abs() > 0) {
      merchantDiscount = feeLineMerchantDiscount < 0
          ? feeLineMerchantDiscount
          : -feeLineMerchantDiscount.abs();
    }

    // ----------- ONLINE TOTAL COMPUTATION -----------
    // NET TOTAL (no tax)
    // Algebraic addition: grossTotal + orderDiscount + merchantDiscount
    // num netTotal = (grossTotal +
    //         (orderDiscount != 0 ? -orderDiscount.abs() : 0.0) +
    //         (merchantDiscount != 0 ? -merchantDiscount.abs() : 0.0))
    //     .clamp(0.0, double.infinity);
    //
    // // NET PAYABLE WITH TAX + CASHBACK
    // // Formula: Gross total + coupon (+ or -ve) + merchant discount (+ve or -ve) + tax + service charges
    // double computedNetPayable = (grossTotal +
    //         (orderDiscount != 0 ? -orderDiscount.abs() : 0.0) +
    //         (merchantDiscount != 0 ? -merchantDiscount.abs() : 0.0) +
    //         orderTax +
    //         cashbackFee)
    //     .clamp(0.0, double.infinity);

    merchantDiscount = -merchantDiscount.abs();

    num netTotal = (grossTotal +
        (orderDiscount != 0 ? orderDiscount : 0.0) +           // already negative usually
        (merchantDiscount != 0 ? merchantDiscount : 0.0))      // already negative
        .clamp(double.negativeInfinity, double.infinity);         // ← Removed 0.0 clamp

// NET PAYABLE WITH TAX + CASHBACK
    double computedNetPayable = (grossTotal +
        (orderDiscount != 0 ? orderDiscount : 0.0) +
        (merchantDiscount != 0 ? merchantDiscount : 0.0) +
        orderTax +
        cashbackFee)
        .clamp(double.negativeInfinity, double.infinity);

    // Woo total overrides only if > 0
    double netPayable = wooTotal >= 0 && (_wooOrder?.id == widget.activeOrderId)
        ? wooTotal
        : computedNetPayable;
    // ---------- DO NOT TOUCH OFFLINE OVERRIDE ----------
    if (order["offline"] == true) {
      final offNet = (order["netTotal"] as num?)?.toDouble();
      if (offNet != null && offNet > 0) {
        netTotal = offNet;
      }
      final offPayable = (order["payable"] as num?)?.toDouble();
      if (offPayable != null && offPayable > 0) {
        netPayable = offPayable;
      }
    }

    // Build #1.0.251 : update UI variables after offline override
    uiGrossTotal = grossTotal;
    // Always store as negative for matching formatting standards (-$5.00)
    uiOrderDiscount = (orderDiscount != 0) ? -orderDiscount.abs() : 0.0;
    // After calculating merchantDiscount
    uiMerchantDiscount = (merchantDiscount != 0)
        ? -merchantDiscount.abs()
        : 0.0;

// Force positive display value for UI (most apps show discount as positive number with "-")
    final double displayMerchantDiscount = uiMerchantDiscount.abs();

    uiOrderTax = orderTax;
    uiNetPayable = netPayable;
    uiCashbackFee = cashbackFee;
    uiTotalItems = totalItems;
    uiRedeemedValue = hiveRedeemedValue;
    final currentOrderStatus = (_wooOrder?.status.isNotEmpty == true
        ? _wooOrder!.status
        : (_order?[AppDBConst.orderStatus]?.toString() ?? ''))
        .toLowerCase()
        .trim();
    final normalizedStatus =
    currentOrderStatus.replaceAll('_', '-').replaceAll(' ', '-');
    final bool isPartialRefundOrder = normalizedStatus == 'partial-refund';

    // Sum refunded items from local DB (isRefundItem == 1) — most reliable source
    double localRefundedItemsTotal = 0.0;
    double localRefundedTaxTotal = 0.0;

    for (final item in orderItems) {
      final refVal = item[AppDBConst.isRefundItem];

      final isRefunded =
          refVal == 1 || refVal == true || refVal == '1' || refVal == 'true';

      if (isRefunded) {
        // ✅ Item price
        final itemPrice = (item[AppDBConst.itemSumPrice] as num?)?.toDouble() ??
            double.tryParse(item["amount"]?.toString() ?? "0") ??
            0.0;

        // ✅ Item tax (check multiple keys safely)
        final itemTax = (item["item_tax"] as num?)?.toDouble() ??
            (item["tax"] as num?)?.toDouble() ??
            (item["total_tax"] as num?)?.toDouble() ??
            (item["item_total_tax"] as num?)?.toDouble() ??
            0.0;

        localRefundedItemsTotal += itemPrice;
        localRefundedTaxTotal += itemTax;

        print("🔁 Refunded Item → ${item[AppDBConst.itemName]}");
        print("   Price → $itemPrice | Tax → $itemTax");
      }
    }


    final double totalRefundWithTax =
        localRefundedItemsTotal + localRefundedTaxTotal;

    print("💰 Refunded Items Total → $localRefundedItemsTotal");
    print("💰 Refunded Tax Total   → $localRefundedTaxTotal");
    print("💰 Final Refund (Incl Tax) → $totalRefundWithTax");

    // Use local items total first; fall back to Woo API totals when local is 0
    final double alreadyRefundedAmount = totalRefundWithTax > 0
        ? totalRefundWithTax
        : (_wooOrder?.refundTotal ?? 0) > 0
        ? (_wooOrder?.refundTotal ?? 0)
        : (_wooOrder?.refundOrderTotal ?? 0);

    final double remainingAmount =
    (netTotal.toDouble() + orderTax).clamp(0.0, double.infinity);

    // Show refund block when there are locally-refunded items OR the order is
    // marked partial-refund by Woo, as long as there is a refund amount to show.
    final bool showRefundBlock =
        (isPartialRefundOrder || localRefundedItemsTotal > 0) &&
            alreadyRefundedAmount > 0;

    final double remainingAfterRefund =
        remainingAmount; // netTotal + orderTax (refunded items already excluded from grossTotal)

    print("🟥 REFUND DEBUG START ----------------");
    print("Local Refunded Items → $localRefundedItemsTotal");
    print("Woo refundTotal      → ${_wooOrder?.refundTotal}");
    print("Woo refundOrderTotal → ${_wooOrder?.refundOrderTotal}");
    print("Final Used Refund    → $alreadyRefundedAmount");
    print("Order Status         → $normalizedStatus");
    print("Is Partial Refund    → $isPartialRefundOrder");
    print("Show Refund Block    → $showRefundBlock");
    print("🟥 REFUND DEBUG END ----------------");

    // ---------- SUMMARY LOGS ----------
    print("🟦 Summary Data:");
    print("Gross Total         → $grossTotal");
    print("SQLite Discount     → $orderDiscount");
    print("SQLite M. Discount  → $merchantDiscount");
    print("Woo Tax             → $wooTax");
    print("Woo Total           → $wooTotal");
    print("SQLite Tax          → $sqliteTax");
    print("SQLite Total        → $sqliteTotal");
    print("Final TAX Used      → $orderTax");
    print("Net Local Total     → $netTotal");
    print("Final Payable       → $netPayable");

    // final bool isPendingOrder =
    //     (_order?[AppDBConst.orderStatus] ?? '').toString() ==
    //         TextConstants.pending;
    final String statusStr =
    (_order?[AppDBConst.orderStatus] ?? '').toString().toLowerCase().trim();
    final bool isPendingOrder = statusStr == TextConstants.pending.toLowerCase() ||
        statusStr == 'pending_offline' ||
        statusStr.contains('pending');

    final double balanceDueFromTotals =
    (netPayable - tenderAmount).clamp(0.0, double.infinity);
    final double panelDisplayBalance = balanceDueFromTotals > 0
        ? balanceDueFromTotals
        : (balanceAmount > 0 ? balanceAmount : balanceDueFromTotals);
    final bool showBalanceForPartialPayment =
        isPendingOrder && !showRefundBlock && panelDisplayBalance > 0;
    final storedBalance = asAmount(
      _order['remaining_balance'] ??
          _order['balance_amount'] ??
          _order['balanceAmount'],
    );
    final effectivePartialBalance =
    storedBalance > 0 ? storedBalance : balanceAmount;
    final bool hasPartialPayment = isPendingOrder &&
        effectivePartialBalance > 0.005 &&
        (tenderAmount > 0.005 || paidAmount > 0.005);
    final double displayedBalanceAmount =
    showBalanceForPartialPayment ? panelDisplayBalance : 0.0;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.primaryBackground
                  : null,
              padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.activeOrderId != null)
                    Row(
                      spacing: 4,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/calendar.svg',
                          width: 22,
                          height: 22,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        Text(displayDate,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.secondaryHeaderColor)),
                        const SizedBox(width: 110),
                        SvgPicture.asset(
                          'assets/svg/clock.svg',
                          width: 22,
                          height: 22,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        Text(displayTime,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.secondaryHeaderColor)),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: DottedLine(
                dashLength: 4,
                dashGapLength: 4,
                lineThickness: 1,
                dashColor: theme.secondaryHeaderColor,
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  // color: themeHelper.themeMode == ThemeMode.dark
                  //     ? const Color(0xFF353848) // dark mode background
                  //     : const Color(0xFFE0E5F7), // light mode background
                  // borderRadius: BorderRadius.circular(12),
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.primaryBackground
                      : null,
                ),
                //color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
                child: Padding(
                  padding: const EdgeInsets.only(left: 0, right: 0),
                  child: Scrollbar(
                    controller: _scrollController,
                    scrollbarOrientation: ScrollbarOrientation.right,
                    thumbVisibility: true,
                    thickness: 8.0,
                    interactive: false,
                    radius: const Radius.circular(8),
                    trackVisibility: true,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      //Build #1.0.4: re-order for list
                      onReorder: (oldIndex, newIndex) {
                        if (kDebugMode) {
                          print("Reordering item from $oldIndex to $newIndex");
                        } // Debug print
                        if (oldIndex < newIndex) newIndex -= 1;

                        setState(() {
                          final movedItem = orderItems.removeAt(oldIndex);
                          orderItems.insert(newIndex, movedItem);
                          //  FORCE CASHBACK TO ALWAYS COME LAST
                          orderItems.sort((a, b) {
                            final typeA = a[AppDBConst.itemType]
                                ?.toString()
                                .toLowerCase() ??
                                '';
                            final typeB = b[AppDBConst.itemType]
                                ?.toString()
                                .toLowerCase() ??
                                '';
                            print("SORT DEBUG → typeA: $typeA   typeB: $typeB");

                            final isCashbackA = typeA.contains("cashback");
                            final isCashbackB = typeB.contains("cashback");

                            // Cashback goes last
                            if (isCashbackA && !isCashbackB) return 1;
                            if (!isCashbackA && isCashbackB) return -1;

                            return 0; // keep original order otherwise
                          });
                        });
                      },
                      scrollController: _scrollController,
                      itemCount: orderItems.length,
                      proxyDecorator: (Widget child, int index,
                          Animation<double> animation) {
                        return Material(
                          color: Colors.transparent, // Removes white background
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final orderItem = orderItems[index];
                        final dynamic refundValue =
                        orderItem[AppDBConst.isRefundItem];

                        final bool isRefunded = refundValue == true ||
                            refundValue == 1 ||
                            refundValue == '1' ||
                            refundValue == 'true';
                        print(
                            "Refund value from DB: ${orderItem[AppDBConst.isRefundItem]}");

                        final itemTypeRaw = orderItem[AppDBConst.itemType]
                            ?.toString()
                            .toLowerCase() ??
                            '';

                        final itemNameRaw = orderItem[AppDBConst.itemName]
                            ?.toString()
                            .toLowerCase() ??
                            '';

                        final bool isEbtEligible = orderItem['ebt_eligible'] ==
                            1 ||
                            orderItem['is_ebt_eligible'] == 1 ||
                            orderItem['ebt_eligible'] == true ||
                            orderItem['is_ebt_eligible'] == true ||
                            orderItem['ebt_eligible']?.toString() == '1' ||
                            orderItem['is_ebt_eligible']?.toString() == '1' ||
                            orderItem['ebt_eligible']
                                ?.toString()
                                .toLowerCase() ==
                                'true' ||
                            orderItem['is_ebt_eligible']
                                ?.toString()
                                .toLowerCase() ==
                                'true';
                        final variationId = orderItem["variant_name"] ?? 0;
                        final variationName =
                            orderItem["attribute_variant"] ?? "";

                        // final bool isCouponRow = itemTypeRaw
                        //         .contains(TextConstants.couponText.toLowerCase()) ||
                        //     itemNameRaw
                        //         .contains(TextConstants.couponText.toLowerCase());
                        // final bool isGeneratedCouponOnly =
                        //     (_order["generated_coupon_only"] == true) ||
                        //         (_order["generated_coupon_only"]
                        //                 ?.toString()
                        //                 .toLowerCase() ==
                        //             "true");
                        // final bool isCouponAppliedOnOrder =
                        //     (_order["coupon_applied"] == true) ||
                        //         (_order["coupon_applied"]?.toString().toLowerCase() ==
                        //             "true");
                        //
                        // /// Hide coupon rows for generated-only coupons and for non-applied coupons.
                        // /// Show coupon rows only when coupon is truly applied to this order.
                        // if (isCouponRow &&
                        //     (!isCouponAppliedOnOrder || isGeneratedCouponOnly)) {
                        //   return Container(
                        //     key: ValueKey("coupon_$index"),
                        //     height: 0,
                        //   );
                        // }

                        final bool isCouponRow = itemTypeRaw.contains(
                            TextConstants.couponText.toLowerCase()) ||
                            itemNameRaw.contains(
                                TextConstants.couponText.toLowerCase());
                        if (isCouponRow) {
                          return Container(
                            key: ValueKey("coupon_$index"),
                            height: 0,
                          );
                        }

                        /// Hide Merchant Discount item from list but keep in summary
                        if (itemTypeRaw.contains("discount") ||
                            itemNameRaw.contains("discount")) {
                          return Container(
                            key: ValueKey("merchant_discount_$index"),
                            height: 0,
                          );
                        }

                        /// 🔥 Hide loyalty products (name-based + type-based)
                        if (itemNameRaw.contains("loyalty") ||
                            itemNameRaw.contains("reward") ||
                            itemNameRaw.contains("points") ||
                            itemTypeRaw.contains("loyalty")) {
                          return Container(
                            key: ValueKey("loyalty_$index"),
                            height: 0,
                          );
                        }

                        ///Build #1.0.64:  added conditions
                        /// Compare item type
                        /// if it is payout change icon, name is empty, show amount in red colour
                        /// if it is coupon change icon, name is coupon code (show last 4 digits, prefix with 'X' for each character before last 4), show amount in red colour
                        final itemType = orderItem[AppDBConst.itemType]
                            ?.toString()
                            .toLowerCase() ??
                            '';
                        final itemName = (orderItem[AppDBConst.itemName]
                            ?.toString()
                            .toLowerCase() ??
                            '');

                        /// Check if the item is a payout or a coupon
                        final isPayout =
                        itemType.contains(TextConstants.payoutText);
                        final isCoupon =
                            itemType.contains(TextConstants.couponText) ||
                                itemName.contains(
                                    TextConstants.couponText.toLowerCase());
                        // ✅ STRONG cashback detection
                        final isCashback = itemType.contains('cashback') ||
                            itemName.contains('cashback');
                        final isCustomItem =
                        itemType.contains(TextConstants.customItemText);
                        final isPayoutOrCouponOrCustomItem =
                            isPayout || isCoupon || isCustomItem || isCashback;

                        final isCouponOrPayout =
                            isPayout || isCoupon || isCashback;

                        // Coupon rows can have zero line amount in order items.
                        // Fall back to order-level coupon fields when applied.
                        final double couponFallbackAmount = () {
                          final dynamic raw = _order["coupon_amount"] ??
                              _order["couponValue"] ??
                              _order["coupon_total"] ??
                              _order["coupon_value"] ??
                              _order["discount"] ??
                              _order["order_discount"];
                          if (raw is num) return raw.toDouble().abs();
                          return double.tryParse(raw?.toString() ?? "0")
                              ?.abs() ??
                              0.0;
                        }();

                        /// Get the original name
                        final originalName =
                            orderItem[AppDBConst.itemName]?.toString() ?? '';
                        // final variationName =
                        //     orderItem[AppDBConst.itemVariationCustomName]?.toString() ?? '';
                        final variationCount =
                            orderItem[AppDBConst.itemVariationCount] ?? 0;
                        final combo = orderItem[AppDBConst.itemCombo] ?? '';

                        final double multipackDiscount =
                            (orderItem[AppDBConst.multipackDiscount] as num?)
                                ?.toDouble() ??
                                0.0;

                        final double autoDiscount =
                            (orderItem[AppDBConst.autoDiscountTotal] as num?)
                                ?.toDouble() ??
                                0.0;

                        // final double comboDiscount =
                        //     (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;

                        final double comboDiscount =
                            (orderItem[AppDBConst.comboDiscountTotal] as num?)
                                ?.toDouble() ??
                                0.0;

                        /// Build #1.0.134: Item Price will check sales price if it is null/empty, check regular price else unit price
                        final salesPrice = (orderItem[
                        AppDBConst.itemSalesPrice] ==
                            null ||
                            (orderItem[AppDBConst.itemSalesPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? (orderItem[AppDBConst.itemRegularPrice] == null ||
                            (orderItem[AppDBConst.itemRegularPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]
                            ?.toDouble() ??
                            0.0
                            : orderItem[AppDBConst.itemRegularPrice]!
                            .toDouble()
                            : orderItem[AppDBConst.itemSalesPrice]!.toDouble();

                        final regularPrice =
                        (orderItem[AppDBConst.itemRegularPrice] == null ||
                            (orderItem[AppDBConst.itemRegularPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]
                            ?.toDouble() ??
                            0.0
                            : orderItem[AppDBConst.itemRegularPrice]!
                            .toDouble();

                        double itemTotalPrice = 0.0;

                        if (isPayout || isCashback) {
                          itemTotalPrice =
                              (orderItem['amount'] as num?)?.toDouble() ??
                                  (orderItem[AppDBConst.itemUnitPrice] as num?)
                                      ?.toDouble() ??
                                  0.0;
                        } else {
                          itemTotalPrice =
                              (orderItem[AppDBConst.itemSumPrice] as num?)
                                  ?.toDouble() ??
                                  0.0;
                        }

                        if (kDebugMode) {
                          print(
                              "#### originalName: $originalName, itemType: $itemType, isPayoutOrCouponOrCustomItem: $isPayoutOrCouponOrCustomItem");
                          print(
                              "#### variationName: $variationName, variationCount: $variationCount, combo: $combo");
                          print(
                              "####  salesPriceeeeeeeeee: $salesPrice, regularPrice: $regularPrice, itemTotalPrice: $itemTotalPrice");
                        }

                        /// Set display name based on item type
                        String displayName = originalName;

                        if (isPayout) {
                          displayName = 'Payout';
                        } else if (isCashback) {
                          displayName = 'Cashback';
                        } else if (isCoupon) {
                          final visiblePartLength = 4;
                          final nameLength = originalName.length;

                          if (nameLength > visiblePartLength) {
                            final maskedLength = nameLength - visiblePartLength;
                            final maskedPart = 'X' * maskedLength;
                            final visiblePart = originalName
                                .substring(nameLength - visiblePartLength);
                            displayName = '$maskedPart$visiblePart';
                          }
                        }
                        return ClipRRect(
                          key: ValueKey(index),
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            // Ensuring Slidable matches the item height
                            height: 70, // reduce height
                            //height: MediaQuery.of(context).size.height * 0.12, // Adjust to match your item height
                            child: Slidable(
                              //Build #1.0.2 : added code for delete the items in list
                              key: ValueKey(index),
                              enabled: false,
                              closeOnScroll: true,
                              direction: Axis.horizontal,
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (context) => {},
                                    backgroundColor: Colors.transparent,
                                    child: Column(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        const SizedBox(height: 4),
                                        const Text(TextConstants.deleteText,
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (isRefunded ||
                                      isPayoutOrCouponOrCustomItem) return;

                                  // Your edit logic here
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 1, horizontal: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeHelper.themeMode ==
                                        ThemeMode.dark
                                        ? Color(0xFF252837)
                                        : Color(
                                        0xFFE8E8E8), // ThemeNotifier.secondaryBackground color of items in order panel
                                    borderRadius: BorderRadius.circular(8),
                                    //   BoxShadow(
                                    //     color: Colors.black12,
                                    //     blurRadius: 5,
                                    //     spreadRadius: 1,
                                    //   )
                                    // ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Replace the ClipRRect widget with this:
                                      // ClipRRect(
                                      //   borderRadius: BorderRadius.circular(5),
                                      //   child: isPayout
                                      //       ? SvgPicture.asset(
                                      //     "assets/svg/payout.svg",
                                      //     height: MediaQuery.of(context).size.height * 0.08,
                                      //     width: MediaQuery.of(context).size.height * 0.075,
                                      //     fit: BoxFit.cover,
                                      //   ) : isCashback
                                      //       ? Image.asset(
                                      //     "assets/cashback.jpeg",
                                      //     height: MediaQuery.of(context).size.height * 0.08,
                                      //     width: MediaQuery.of(context).size.height * 0.075,
                                      //     fit: BoxFit.cover,
                                      //   )
                                      //
                                      //       : buildProductImage(
                                      //     orderItem[AppDBConst.itemImage]?.toString(),
                                      //     height: MediaQuery.of(context).size.height * 0.08,
                                      //     width: MediaQuery.of(context).size.height * 0.075,
                                      //   ),
                                      // ),
                                      const SizedBox(width: 10),

                                      // Expanded(
                                      //   child:
                                      //   Column(
                                      //     crossAxisAlignment:
                                      //         CrossAxisAlignment.start,
                                      //     mainAxisAlignment:
                                      //         MainAxisAlignment.spaceEvenly,
                                      //     children: [
                                      //       Column(
                                      //         crossAxisAlignment:
                                      //             CrossAxisAlignment.start,
                                      //         mainAxisAlignment:
                                      //             MainAxisAlignment.start,
                                      //         children: [
                                      //           RichText(
                                      //             maxLines: 2,
                                      //             softWrap: true,
                                      //             text: TextSpan(
                                      //               children: [
                                      //
                                      //                 TextSpan(
                                      //                   text: displayName,
                                      //                   style: TextStyle(
                                      //                     fontFamily: 'inter',
                                      //                     fontSize: 12,
                                      //                     fontWeight:
                                      //                         FontWeight.w700,
                                      //                     color: isRefunded
                                      //                         ? Colors.grey
                                      //                         : (themeHelper
                                      //                                     .themeMode ==
                                      //                                 ThemeMode
                                      //                                     .dark
                                      //                             ? ThemeNotifier
                                      //                                 .textDark
                                      //                             : ThemeNotifier
                                      //                                 .textLight),
                                      //                     decoration: isRefunded
                                      //                         ? TextDecoration
                                      //                             .lineThrough
                                      //                         : TextDecoration
                                      //                             .none,
                                      //                   ),
                                      //                 ),
                                      //                 TextSpan(
                                      //                   text: combo == ''
                                      //                       ? ''
                                      //                       : " (Combo)",
                                      //                   style: TextStyle(
                                      //                       fontSize: 8,
                                      //                       color: Colors.cyan),
                                      //                 ),
                                      //               ],
                                      //             ),
                                      //           ),
                                      //
                                      //           if (multipackDiscount > 0) ...[
                                      //             const SizedBox(height: 2),
                                      //             Text(
                                      //               "Multipack Discount: -${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
                                      //               style: TextStyle(
                                      //                 fontSize: 10,
                                      //                 fontWeight:
                                      //                     FontWeight.w600,
                                      //                 color: Colors.blue,
                                      //               ),
                                      //             ),
                                      //           ],
                                      //
                                      //           if (autoDiscount > 0) ...[
                                      //             const SizedBox(height: 2),
                                      //             Text(
                                      //               "auto Discount : -${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
                                      //               style: TextStyle(
                                      //                 fontSize: 10,
                                      //                 fontWeight:
                                      //                     FontWeight.w600,
                                      //                 color: Colors.red,
                                      //               ),
                                      //             ),
                                      //           ],
                                      //
                                      //           // if (combo != '' && comboDiscount > 0) ...[
                                      //           //   const SizedBox(height: 2),
                                      //           //   Text(
                                      //           //     "Combo Discount: -${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
                                      //           //     style: TextStyle(
                                      //           //       fontSize: 10,
                                      //           //       fontWeight: FontWeight.w600,
                                      //           //       color: Colors.green,
                                      //           //     ),
                                      //           //   ),
                                      //           // ],
                                      //
                                      //           if (comboDiscount > 0) ...[
                                      //             // ← just check value > 0
                                      //             const SizedBox(height: 2),
                                      //             Text(
                                      //               "Combo Discount: -${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
                                      //               style: TextStyle(
                                      //                   fontSize: 10,
                                      //                   fontWeight:
                                      //                       FontWeight.w600,
                                      //                   color: Colors.orange),
                                      //             ),
                                      //           ],
                                      //           if (variationId > 0 &&
                                      //               variationName
                                      //                   .isNotEmpty) ...[
                                      //             const SizedBox(height: 2),
                                      //             Row(
                                      //               children: [
                                      //                 Text(
                                      //                   "($variationName)",
                                      //                   overflow: TextOverflow
                                      //                       .ellipsis,
                                      //                   style: TextStyle(
                                      //                     fontSize: 10,
                                      //                     color: themeHelper
                                      //                                 .themeMode ==
                                      //                             ThemeMode.dark
                                      //                         ? ThemeNotifier
                                      //                             .textDark
                                      //                         : Colors.grey,
                                      //                   ),
                                      //                 ),
                                      //                 const SizedBox(width: 4),
                                      //                 SvgPicture.asset(
                                      //                   "assets/svg/variation.svg",
                                      //                   height: 10,
                                      //                   width: 10,
                                      //                 ),
                                      //               ],
                                      //             ),
                                      //           ],
                                      //         ],
                                      //       ),
                                      //       if (isEbtEligible) ...[
                                      //         const SizedBox(height: 3),
                                      //         Container(
                                      //           padding:
                                      //               const EdgeInsets.symmetric(
                                      //                   horizontal: 6,
                                      //                   vertical: 2),
                                      //           decoration: BoxDecoration(
                                      //             color: Colors.green,
                                      //             borderRadius:
                                      //                 BorderRadius.circular(4),
                                      //           ),
                                      //           child: const Text(
                                      //             "EBT",
                                      //             style: TextStyle(
                                      //               fontSize: 10,
                                      //               fontWeight: FontWeight.bold,
                                      //               color: Colors.white,
                                      //             ),
                                      //           ),
                                      //         ),
                                      //       ],
                                      //
                                      //       //Modified: Show quantity * price only for non-Payout/Coupon items
                                      //
                                      //       // if (!isPayoutOrCouponOrCustomItem) ...[
                                      //       //   Builder(
                                      //       //     builder: (context) {
                                      //       //       double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1;
                                      //       //
                                      //       //       double unitPrice =
                                      //       //           (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////---
                                      //       //           (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                      //       //               (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                      //       //               (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////
                                      //       //               0.0;   ////
                                      //       //
                                      //       //       // If still zero → derive price from sum price
                                      //       //       if (unitPrice == 0.0) {
                                      //       //         final double sumPrice =
                                      //       //             (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;
                                      //       //
                                      //       //         if (sumPrice > 0 && qty > 0) {
                                      //       //           unitPrice = sumPrice / qty;
                                      //       //         }
                                      //       //       }
                                      //       //
                                      //       //       return Text(
                                      //       //         "${TextConstants.currencySymbol} ${unitPrice.toStringAsFixed(2)} × ${qty.toInt()}",
                                      //       //
                                      //       //
                                      //       //         style: TextStyle(
                                      //       //           color: themeHelper.themeMode == ThemeMode.dark
                                      //       //               ? ThemeNotifier.textDark
                                      //       //               : Colors.black54,
                                      //       //           fontSize: 10,
                                      //       //         ),
                                      //       //       );
                                      //       //     },
                                      //       //   ),
                                      //       // ],
                                      //
                                      //       if (!isPayoutOrCouponOrCustomItem) ...[
                                      //         Builder(
                                      //           builder: (context) {
                                      //             final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1;
                                      //
                                      //             // Get regular price (original price before discount)
                                      //             final double regularPrice =
                                      //                 (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                      //                     (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                      //                     (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
                                      //
                                      //             // Current (discounted) unit price for calculation
                                      //             double displayUnitPrice = (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
                                      //
                                      //             // Check if this item has any discount
                                      //             final bool hasDiscount =
                                      //                 ((orderItem[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0 ||
                                      //                     ((orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0) > 0 ||
                                      //                     ((orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0 ||
                                      //                     ((orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0) > 0;
                                      //
                                      //             // If item has discount → show Regular Price, else show current price
                                      //             if (hasDiscount && regularPrice > displayUnitPrice) {
                                      //               displayUnitPrice = regularPrice;
                                      //             }
                                      //
                                      //             // Fallback if still zero
                                      //             if (displayUnitPrice == 0.0) {
                                      //               final double sumPrice = (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;
                                      //               if (sumPrice > 0 && qty > 0) {
                                      //                 displayUnitPrice = sumPrice / qty;
                                      //               }
                                      //             }
                                      //
                                      //             return Text(
                                      //               "${TextConstants.currencySymbol}${displayUnitPrice.toStringAsFixed(2)} × ${qty.toInt()}",
                                      //               style: TextStyle(
                                      //                 color: themeHelper.themeMode == ThemeMode.dark
                                      //                     ? ThemeNotifier.textDark
                                      //                     : Colors.black54,
                                      //                 fontSize: 10,
                                      //               ),
                                      //             );
                                      //           },
                                      //         ),
                                      //       ],
                                      //     ],
                                      //   ),
                                      // ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                RichText(
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: displayName,
                                                        style: TextStyle(
                                                          fontFamily: 'inter',
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: isRefunded
                                                              ? Colors.grey
                                                              : (themeHelper.themeMode == ThemeMode.dark
                                                              ? ThemeNotifier.textDark
                                                              : ThemeNotifier.textLight),
                                                          decoration: isRefunded
                                                              ? TextDecoration.lineThrough
                                                              : TextDecoration.none,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: combo == '' ? '' : " (Combo)",
                                                        style: TextStyle(fontSize: 8, color: Colors.cyan),
                                                      ),
                                                    ],
                                                  ),
                                                ),


                                                if (multipackDiscount > 0) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Multipack Discount: -${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],

                                                if (autoDiscount > 0) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "auto Discount : -${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],

                                                if (comboDiscount > 0) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Combo Discount: -${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.orange),
                                                  ),
                                                ],

                                                if (variationId > 0 && variationName.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "($variationName)",
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: themeHelper.themeMode == ThemeMode.dark
                                                              ? ThemeNotifier.textDark
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      SvgPicture.asset(
                                                        "assets/svg/variation.svg",
                                                        height: 10,
                                                        width: 10,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),

                                            if (isEbtEligible) ...[
                                              const SizedBox(height: 3),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  "EBT",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],

                                            // Quantity & Price Display (Updated with Weighted Support)
                                            // if (!isPayoutOrCouponOrCustomItem) ...[
                                            //   Builder(
                                            //     builder: (context) {
                                            //       // Weighted item handling
                                            //       final bool isWeighted = orderItem['is_weighted'] == true ||
                                            //           (orderItem['weight_qty'] != null &&
                                            //               (orderItem['weight_qty'] as num) > 0);
                                            //
                                            //       final double displayQty = isWeighted
                                            //           ? (orderItem['weight_qty'] ?? orderItem['display_qty'] ?? 1.0)
                                            //       as double
                                            //           : (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
                                            //
                                            //       final double unitPrice = isWeighted
                                            //           ? (orderItem['unit_price'] as num?)?.toDouble() ??
                                            //           (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                            //           0.0
                                            //           : (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                            //           (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                            //           (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                            //           0.0;
                                            //
                                            //       return Text(
                                            //         "${TextConstants.currencySymbol}${unitPrice.toStringAsFixed(2)} × "
                                            //             "${isWeighted ? displayQty.toStringAsFixed(3) : displayQty.toInt()}",
                                            //         style: TextStyle(
                                            //           color: themeHelper.themeMode == ThemeMode.dark
                                            //               ? ThemeNotifier.textDark
                                            //               : Colors.black54,
                                            //           fontSize: 10,
                                            //         ),
                                            //       );
                                            //     },
                                            //   ),
                                            // ],

                                            if (!isPayoutOrCouponOrCustomItem) ...[
                                              Builder(
                                                builder: (context) {
                                                  // STRICT WEIGHTED ITEM DETECTION - Only use explicit flags
                                                  final bool isWeighted = orderItem['is_weighted'] == true ||
                                                      orderItem['item_type'] == 'weighted';

                                                  if (isWeighted) {
                                                    // ---- WEIGHTED ITEM: USE ONLY WEIGHT FIELDS ----

                                                    // Get weight quantity - ONLY from weight_qty
                                                    final double weightQty = (orderItem['weight_qty'] as num?)?.toDouble() ??
                                                        (orderItem['display_qty'] as num?)?.toDouble() ??
                                                        0.0;

                                                    // Get unit price - ONLY from unit_price
                                                    final double unitPrice = (orderItem['unit_price'] as num?)?.toDouble() ??
                                                        (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                                        0.0;

                                                    // If either is 0, don't display
                                                    if (weightQty <= 0 || unitPrice <= 0) {
                                                      return const SizedBox.shrink();
                                                    }

                                                    // Display weight with 3 decimal places
                                                    final String qtyDisplay = "${weightQty.toStringAsFixed(3)} lb";

                                                    // Show unit price with /lb
                                                    return Text(
                                                      "${TextConstants.currencySymbol}${unitPrice.toStringAsFixed(2)} × $qtyDisplay",
                                                      style: TextStyle(
                                                        color: themeHelper.themeMode == ThemeMode.dark
                                                            ? ThemeNotifier.textDark
                                                            : Colors.black54,
                                                        fontSize: 10,
                                                      ),
                                                    );
                                                  }
                                                  // ---- REGULAR ITEM ----
                                                  else {
                                                    final double displayQty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
                                                    final double unitPrice = (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                                        (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                                        (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                                        0.0;

                                                    // Final fallback safety
                                                    final double finalUnitPrice = unitPrice > 0
                                                        ? unitPrice
                                                        : ((orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0) /
                                                        (displayQty > 0 ? displayQty : 1.0);

                                                    return Text(
                                                      "${TextConstants.currencySymbol}${finalUnitPrice.toStringAsFixed(2)} × ${displayQty.toInt()}",
                                                      style: TextStyle(
                                                        color: themeHelper.themeMode == ThemeMode.dark
                                                            ? ThemeNotifier.textDark
                                                            : Colors.black54,
                                                        fontSize: 10,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],

                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          // Text(
                                          //   isPayout
                                          //       ? "-${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.abs().toStringAsFixed(2)}"
                                          //       : isCashback
                                          //       ? "${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.toStringAsFixed(2)}"
                                          //       : "${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.toStringAsFixed(2)}",
                                          //   style: TextStyle(
                                          //     fontSize: 14,
                                          //     fontWeight: FontWeight.bold,
                                          //     color: isPayout
                                          //         ? Colors.red
                                          //         : isCashback
                                          //         ? (themeHelper.themeMode == ThemeMode.dark
                                          //         ? ThemeNotifier.textDark
                                          //         : ThemeNotifier.textLight)
                                          //         : (isCoupon
                                          //         ? Colors.red
                                          //         : (themeHelper.themeMode == ThemeMode.dark
                                          //         ? ThemeNotifier.textDark
                                          //         : ThemeNotifier.textLight)),
                                          //   ),
                                          // )

                                          Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                            children: [
                                              if (isPayout || isCoupon)
                                                Builder(builder: (_) {
                                                  final double lineAmount =
                                                      (orderItem[AppDBConst
                                                          .itemSumPrice]
                                                      as num?)
                                                          ?.toDouble()
                                                          .abs() ??
                                                          0.0;
                                                  final double displayAmount =
                                                  isCoupon &&
                                                      lineAmount <= 0
                                                      ? couponFallbackAmount
                                                      : lineAmount;
                                                  return Text(
                                                    "-${TextConstants.currencySymbol}${displayAmount.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: Colors.red,
                                                    ),
                                                  );
                                                })
                                              else
                                                Builder(
                                                  builder: (context) {
                                                    final double
                                                    actualSumPrice =
                                                        (orderItem[AppDBConst
                                                            .itemSumPrice]
                                                        as num?)
                                                            ?.toDouble() ??
                                                            0.0;

                                                    double qty = (orderItem[
                                                    AppDBConst
                                                        .itemCount]
                                                    as num?)
                                                        ?.toDouble() ??
                                                        1;
                                                    double unitPrice = (orderItem[
                                                    AppDBConst
                                                        .itemUnitPrice]
                                                    as num?)
                                                        ?.toDouble() ??
                                                        (orderItem[AppDBConst
                                                            .itemPrice]
                                                        as num?)
                                                            ?.toDouble() ??
                                                        (orderItem[AppDBConst
                                                            .itemRegularPrice]
                                                        as num?)
                                                            ?.toDouble() ??
                                                        0.0;

                                                    if (unitPrice == 0.0 &&
                                                        actualSumPrice > 0 &&
                                                        qty > 0) {
                                                      unitPrice =
                                                          actualSumPrice / qty;
                                                    }

                                                    final double originalTotal =
                                                        unitPrice * qty;
                                                    // Refund amount (after discounts)
                                                    final double refundAmount =
                                                        actualSumPrice;
                                                    final double totalDiscount =
                                                        multipackDiscount +
                                                            autoDiscount +
                                                            comboDiscount;

                                                    final bool
                                                    showStrikethrough =
                                                        totalDiscount > 0 &&
                                                            originalTotal >
                                                                actualSumPrice &&
                                                            (originalTotal -
                                                                actualSumPrice)
                                                                .abs() >
                                                                0.01;

                                                    return Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .end,
                                                      children: [
                                                        Text(
                                                          isCashback
                                                              ? "${TextConstants.currencySymbol}${actualSumPrice.toStringAsFixed(2)}"
                                                              : "${TextConstants.currencySymbol}${actualSumPrice.toStringAsFixed(2)}",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            color: isCashback
                                                                ? (themeHelper
                                                                .themeMode ==
                                                                ThemeMode
                                                                    .dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : ThemeNotifier
                                                                .textLight)
                                                                : (showStrikethrough
                                                                ? Colors
                                                                .black87
                                                                : (themeHelper.themeMode ==
                                                                ThemeMode
                                                                    .dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : ThemeNotifier
                                                                .textLight)),
                                                            decoration: isRefunded
                                                                ? TextDecoration
                                                                .lineThrough
                                                                : TextDecoration
                                                                .none,
                                                          ),
                                                        ),
                                                        if (!isRefunded &&
                                                            showStrikethrough)
                                                          Padding(
                                                            padding:
                                                            const EdgeInsets
                                                                .only(
                                                                top: 2),
                                                            child: Text(
                                                              "${TextConstants.currencySymbol}${originalTotal.toStringAsFixed(2)}",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                                color: themeHelper.themeMode ==
                                                                    ThemeMode
                                                                        .dark
                                                                    ? Colors
                                                                    .grey
                                                                    .shade400
                                                                    : Colors
                                                                    .black54,
                                                                decoration:
                                                                TextDecoration
                                                                    .lineThrough,
                                                                decorationColor:
                                                                Colors
                                                                    .black,
                                                                decorationThickness:
                                                                2,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            ///Todo: update ui as per loading from screen
            ///Show print and email invoice buttons if coming from order history screen
            ///else show regular buttons
            Container(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.primaryBackground
                  : null,
              child: Column(
                children: [
                  // Summary container
                  AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showFullSummary
                          ? SizedBox(
                          child: Container(
                              margin: const EdgeInsets.only(
                                  top: 8, right: 7, left: 7),
                              // margin: const EdgeInsets.only(top: 8, right: 8, left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    topLeft: Radius.circular(8)),
                                color:
                                themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.orderPanelSummary
                                    : Colors.white,
                                boxShadow: [
                                  // Shadow at the bottom
                                  BoxShadow(
                                    // color: Colors.black.withOpacity(0.25),
                                    color: themeHelper.themeMode ==
                                        ThemeMode.dark
                                        ? Color(0xFFF0F0F0).withOpacity(
                                        0.15) // stronger shadow for dark mode
                                        : Colors.black.withOpacity(
                                        0.25), // lighter shadow for light mode
                                    offset: Offset(0,
                                        4), // 0 horizontal, 4 vertical (down)
                                    blurRadius: 6,
                                    spreadRadius: -0.5,
                                  ),
                                  // Shadow at the top
                                  BoxShadow(
                                    color: themeHelper.themeMode ==
                                        ThemeMode.dark
                                        ? Color(0xFFF0F0F0).withOpacity(
                                        0.15) // dark mode top shadow
                                        : Colors.black.withOpacity(
                                        0.15), // light mode top shadow
                                    // color: Colors.black.withOpacity(0.15),
                                    offset: Offset(0,
                                        -4), // 0 horizontal, -4 vertical (up)
                                    blurRadius: 6,
                                    spreadRadius: -0.5,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(
                                //  scroll added
                                physics: const BouncingScrollPhysics(),

                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          TextConstants.grossTotal,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                        Text(
                                          grossTotal < 0
                                              ? '-${TextConstants.currencySymbol}${grossTotal.abs().toStringAsFixed(2)}'
                                              : '${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: themeHelper.themeMode ==
                                                ThemeMode.dark
                                                ? ThemeNotifier.textDark
                                                : ThemeNotifier.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    // === MERCHANT DISCOUNT ROW (Corrected) ===
                                    if (uiMerchantDiscount.abs() > 0.000001)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            TextConstants.merchantDiscount,
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            "-${TextConstants.currencySymbol}${uiMerchantDiscount.abs().toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          spacing: 5,
                                          children: [
                                            // SvgPicture.asset(
                                            //   "assets/svg/discount_star.svg",
                                            //   height: 12,
                                            //   width: 12,
                                            // ),
                                            Text(TextConstants.discountText,
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 14)),
                                          ],
                                        ),
                                        Text(
                                          "-${TextConstants.currencySymbol}${orderDiscount.abs().toStringAsFixed(2)}",
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),

                                    SizedBox(
                                      height: 2,
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
                                    SizedBox(
                                      height: 2,
                                    ),
                                    // const DottedLine(),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    // Row(
                                    //   mainAxisAlignment:
                                    //       MainAxisAlignment.spaceBetween,
                                    //   crossAxisAlignment:
                                    //       CrossAxisAlignment.center,
                                    //   children: [
                                    //     Text(
                                    //       TextConstants.netTotalText,
                                    //       style: TextStyle(
                                    //           fontWeight: FontWeight.bold,
                                    //           fontSize: 15),
                                    //     ),
                                    //     Text(
                                    //         netTotal < 0
                                    //             ? '-${TextConstants.currencySymbol}${netTotal.abs().toStringAsFixed(2)}'
                                    //             : '${TextConstants.currencySymbol}${netTotal.toStringAsFixed(2)}',
                                    //         style: TextStyle(
                                    //             fontWeight: FontWeight.bold,
                                    //             fontSize: 15,
                                    //             color: themeHelper
                                    //                 .themeMode ==
                                    //                 ThemeMode.dark
                                    //                 ? ThemeNotifier.textDark
                                    //                 : ThemeNotifier
                                    //                 .textLight)),
                                    //   ],
                                    // ),

                                    // Inside the summary Column, after merchantDiscount row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          TextConstants.netTotalText,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        // 🔁 REPLACE netTotal with netTotal - orderTax
                                        Text(
                                          (netTotal - orderTax) < 0
                                              ? '-${TextConstants.currencySymbol}${(netTotal + orderTax).abs().toStringAsFixed(2)}'
                                              : '${TextConstants.currencySymbol}${(netTotal + orderTax).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.textDark
                                                : ThemeNotifier.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          TextConstants.taxText,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                        Text(
                                            "${TextConstants.currencySymbol}${wooTax.toStringAsFixed(2)}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color:
                                                themeHelper.themeMode ==
                                                    ThemeMode.dark
                                                    ? Colors.white54
                                                    : Colors.grey)),
                                      ],
                                    ),

                                    SizedBox(height: 2),

                                    if (cashbackFee > 0)
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            TextConstants.cashbackFee,
                                            style: const TextStyle(
                                              color: Color(0xFF55CBCD),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              color: Color(0xFF55CBCD),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(TextConstants.servicecharges),
                                        Text(
                                          "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),

                                    SizedBox(
                                      height: 2,
                                    ),
                                    if ((_wooOrder?.refundTotal ?? 0) > 0)
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Refund Amount",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.red,
                                            ),
                                          ),
                                          Text(
                                            " ${TextConstants.currencySymbol}${(_wooOrder?.refundTotal ?? 0).toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(height: 2),
                                    //const DottedLine(),
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
                                    SizedBox(
                                      height: 2,
                                    ),
                                    // if (isPendingOrder) ...[
                                    //   SizedBox(height: 8),
                                    //   Row(
                                    //     mainAxisAlignment:
                                    //         MainAxisAlignment.spaceBetween,
                                    //     crossAxisAlignment:
                                    //         CrossAxisAlignment.center,
                                    //     children: [
                                    //       Text(
                                    //         TextConstants.balanceAmount,
                                    //         style: const TextStyle(
                                    //           fontWeight: FontWeight.bold,
                                    //           fontSize: 14,
                                    //         ),
                                    //       ),
                                    //       Text(
                                    //         "${TextConstants.currencySymbol}"
                                    //         "${panelDisplayBalance.toStringAsFixed(2)}",
                                    //         style: TextStyle(
                                    //           fontWeight: FontWeight.bold,
                                    //           fontSize: 14,
                                    //           color: themeHelper.themeMode ==
                                    //                   ThemeMode.dark
                                    //               ? ThemeNotifier.textDark
                                    //               : ThemeNotifier.textLight,
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    //   // if (tenderAmount > 0.005)
                                    //   //   Padding(
                                    //   //     padding:
                                    //   //         const EdgeInsets.only(top: 6),
                                    //   //     child: Row(
                                    //   //       mainAxisAlignment:
                                    //   //           MainAxisAlignment.spaceBetween,
                                    //   //       children: [
                                    //   //         Text(
                                    //   //           TextConstants.amountTendered,
                                    //   //           style: TextStyle(
                                    //   //             fontSize: 12,
                                    //   //             fontWeight: FontWeight.w600,
                                    //   //             color: themeHelper
                                    //   //                         .themeMode ==
                                    //   //                     ThemeMode.dark
                                    //   //                 ? Colors.white60
                                    //   //                 : Colors.grey[700],
                                    //   //           ),
                                    //   //         ),
                                    //   //         Text(
                                    //   //           "${TextConstants.currencySymbol}"
                                    //   //           "${tenderAmount.toStringAsFixed(2)}",
                                    //   //           style: TextStyle(
                                    //   //             fontSize: 12,
                                    //   //             fontWeight: FontWeight.w600,
                                    //   //             color: themeHelper
                                    //   //                         .themeMode ==
                                    //   //                     ThemeMode.dark
                                    //   //                 ? ThemeNotifier.textDark
                                    //   //                 : ThemeNotifier.textLight,
                                    //   //           ),
                                    //   //         ),
                                    //   //       ],
                                    //   //     ),
                                    //   //   ),
                                    // ],

                                    SizedBox(
                                      height: 2,
                                    ),
                                    if (hiveRedeemedValue > 0)
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Redeemed Value",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.green,
                                            ),
                                          ),
                                          Text(
                                            "- ${TextConstants.currencySymbol}${hiveRedeemedValue.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.green,
                                            ),
                                          ),
                                          SizedBox(
                                            height: 2,
                                          ),
                                          // if (showRefundBlock) ...[
                                          //   Row(
                                          //     mainAxisAlignment:
                                          //         MainAxisAlignment
                                          //             .spaceBetween,
                                          //     children: [
                                          //       Text(
                                          //         "Refunded Amount",
                                          //         style: TextStyle(
                                          //           fontSize: 14,
                                          //           fontWeight:
                                          //               FontWeight.w500,
                                          //           color: Colors.red,
                                          //         ),
                                          //       ),
                                          //       Text(
                                          //         "${TextConstants.currencySymbol}${alreadyRefundedAmount.toStringAsFixed(2)}",
                                          //         style: const TextStyle(
                                          //           fontSize: 16,
                                          //           fontWeight:
                                          //               FontWeight.w600,
                                          //           color: Colors.red,
                                          //         ),
                                          //       ),
                                          //     ],
                                          //   ),
                                          // ],
                                        ],
                                      ),
                                  ],
                                ),
                              )))
                          : SizedBox.shrink()),
                  if (widget.activeOrderId != null)
                    GestureDetector(
                      onTap: _toggleSummary,
                      child: Container(
                        margin:
                        const EdgeInsets.only(top: 0, right: 6, left: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8)),
                          // color: themeHelper.themeMode == ThemeMode.dark ?const Color(0xFF393C48) : Colors.grey.shade300
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(
                              0xFF2A2C36) // ✅ dark mode background 393C48
                              : Colors.grey.shade300, // ✅ light mode background
                          boxShadow: [
                            // Shadow at the bottom
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 4), // moves shadow down
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                            // Shadow at the top
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 4), // moves shadow up
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${TextConstants.totalItemsText}: $totalItems",
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(
                                  '${TextConstants.balanceAmount} : ${TextConstants.currencySymbol}${displayedBalanceAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Icon(_showFullSummary
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(),
                  const SizedBox(height: 4),

                  // Payment button - outside the container
                  if (widget.activeOrderId != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 5),
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.0575,
                      child: (() {
                        final status =
                        (_order?[AppDBConst.orderStatus] ?? '').toString().toLowerCase().trim();

                        final bool isPendingLike = status == TextConstants.pending.toLowerCase() ||
                            status == 'pending_offline' ||
                            status == 'pending' ||
                            status.contains('pending') ||
                            status == 'on-hold' ||
                            status == 'processing';

                        // net payable from the same values the summary already uses
                        final double netPay = (uiNetPayable > 0)
                            ? uiNetPayable
                            : ((_order['payable'] as num?)?.toDouble() ??
                            (_order['net_payable'] as num?)?.toDouble() ??
                            (_order[AppDBConst.orderTotal] as num?)?.toDouble() ??
                            0.0);

                        // Remaining due:
                        // 1) live balanceAmount if set
                        // 2) else netPay - tender (covers unpaid offline pending where balanceAmount is still 0)
                        final double dueFromTotals =
                        (netPay - tenderAmount).clamp(0.0, double.infinity);
                        final double remainingDue =
                        balanceAmount > 0.01 ? balanceAmount : dueFromTotals;

                        final bool stillOwesMoney = remainingDue > 0.01;

                        // Print only when fully paid (or not an open order with balance)
                        // Pay when money is still owed (pending / pending_offline / partial)
                        final bool showPrintInvoice = !stillOwesMoney;

                        if (kDebugMode) {
                          print(
                            "BTN → status=$status | isPendingLike=$isPendingLike | "
                                "balanceAmount=$balanceAmount | tender=$tenderAmount | "
                                "netPay=$netPay | remainingDue=$remainingDue | "
                                "showPrint=$showPrintInvoice",
                          );
                        }

                        return showPrintInvoice;
                      })()
                          ?
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            if (kDebugMode) {
                              print("🖨️ [PRINT] Print Invoice button tapped");
                              print("🖨️ [PRINT] activeOrderId: ${widget.activeOrderId}");
                              print("🖨️ [PRINT] orderHelper.activeOrderId: ${orderHelper.activeOrderId}");
                              print("🖨️ [PRINT] orderItems count: ${orderItems.length}");
                              print("🖨️ [PRINT] _printerReceipt: $_printerReceipt");
                            }

                            // FIX: do not gate on orderHelper.activeOrderId — gate on widget.activeOrderId
                            if (widget.activeOrderId == null) {
                              if (kDebugMode) print("❌ [PRINT] No active order id, aborting print");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No active order selected for printing."),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setState(() => _isPayBtnLoading = true);

                            if (kDebugMode) print("🖨️ [PRINT] Misc.disablePrinter = ${Misc.disablePrinter}");

                            if (!Misc.disablePrinter) {
                              if (kDebugMode) print("🖨️ [PRINT] Calling _preparePrintTicket...");
                              await _preparePrintTicket();
                              if (kDebugMode) print("🖨️ [PRINT] _preparePrintTicket done. bytes length = ${bytes.length}");

                              if (bytes.isEmpty) {
                                if (kDebugMode) print("❌ [PRINT] bytes is empty after _preparePrintTicket — nothing to print");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Print ticket is empty. Check printer/receipt settings."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setState(() => _isPayBtnLoading = false);
                                return;
                              }

                              if (kDebugMode) print("🖨️ [PRINT] Calling _printTicket...");
                              await _printTicket();
                              if (kDebugMode) print("✅ [PRINT] _printTicket completed");
                            } else {
                              if (kDebugMode) print("⚠️ [PRINT] Printer is disabled (Misc.disablePrinter=true), skipping print");
                            }
                          } catch (e, st) {
                            if (kDebugMode) {
                              print("❌ [PRINT] Exception during print: $e");
                              print("❌ [PRINT] StackTrace: $st");
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Print failed: $e"),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isPayBtnLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPayBtnLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          TextConstants.printInvoice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                          : ElevatedButton(
                        //Build 1.1.36: on pay tap calling updateOrderProducts api call
                        onPressed: netPayable >= 0 &&
                            orderItems.isNotEmpty
                            ? () async {
                          if (widget.activeOrderId != null || orderHelper.activeOrderId != null) {
                            final int? orderIdToUse =
                                widget.activeOrderId ?? orderHelper.activeOrderId;

                            if (orderIdToUse == null) {
                              if (kDebugMode) {
                                print("[PAY] No active order id — cannot open summary");
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No active order selected."),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final int frozenSummaryOrderId = orderIdToUse;
                            setState(() => _isPayBtnLoading = true);
                            _initialFetchDone =
                            false; // Build #1.0.143: Track initial fetch of fetchOrdersData
                            // await Navigator.push(
                            //   context,
                            //   MaterialPageRoute(builder: (context) => OrderSummaryScreen()),
                            // );
                            // On the first screen (Screen 1)
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryScreen())).then((result) {
                            //   if (result == 'refresh') {
                            //     setState(() {
                            //       // Update state to refresh the UI
                            //     });
                            //   }
                            // });
                            // Build #1.0.104: refresh when back to this screen
                            List<Map<String, dynamic>>
                            visibleLineItems(
                                List<Map<String, dynamic>> items,
                                ) {
                              return items.where((item) {
                                final nameLower =
                                (item[AppDBConst.itemName] ??
                                    '')
                                    .toString()
                                    .trim()
                                    .toLowerCase();

                                final itemTypeLower =
                                (item['item_type'] ??
                                    '') // ✅ FIXED KEY
                                    .toString()
                                    .trim()
                                    .toLowerCase();

                                final isNonProduct = nameLower
                                    .contains('discount') ||
                                    nameLower.contains('coupon') ||
                                    nameLower.contains('loyalty') ||
                                    nameLower
                                        .contains('redeemed') ||
                                    nameLower.contains('points') ||
                                    itemTypeLower
                                        .contains('discount') ||
                                    itemTypeLower.contains(
                                        'coupon') || // ✅ WILL MATCH
                                    itemTypeLower
                                        .contains('loyalty');



                                return !isNonProduct;
                              }).toList();
                            }

                            final box =
                                StorageProvider.offlineOrders;

                            // Prefer server order id if exists, else offline id
                            final hiveKey =
                            frozenSummaryOrderId.toString();

                            final int? selectedOrderId = widget.activeOrderId;

                            final boxData = await box.get(hiveKey);
                            final double discountAmount = ((boxData
                            is Map
                                ? boxData["discount_amount"]
                                : null) ??
                                0.0)
                                .toDouble();
                            // ADD THIS
                            final double redeemValue = ((boxData is Map
                                ? boxData["redeemed_value"]   // change key if needed
                                : null) ??
                                0.0)
                                .toDouble();

                            print("REDEEM VALUE FROM PENDING ORDER = $redeemValue");

                            if (kDebugMode) {
                              print(
                                  "🏷 Passing Discount Amount = $discountAmount");
                            }

                            final filteredItems = visibleLineItems(orderItems);

// 🔥 NEW: Fix price before sending to OrderSummaryScreen
//                                         final List<Map<String, dynamic>> itemsForSummary = filteredItems.map((item) {
//                                           final Map<String, dynamic> newItem = Map<String, dynamic>.from(item);
//
//                                           final double regularPrice =
//                                               (item[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
//                                                   (item[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
//                                                   (item[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
//
//                                           final double currentPrice = (item[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
//
//                                           // Check if item has any discount
//                                           final bool hasDiscount =
//                                               ((item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0 ||
//                                                   ((item[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0) > 0 ||
//                                                   ((item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0 ||
//                                                   ((item[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0) > 0 ||
//                                                   (item['discount_type']?.toString().isNotEmpty ?? false);
//
//                                           // If has discount → send original price as itemPrice for display in summary
//                                           if (hasDiscount && regularPrice > currentPrice && regularPrice > 0) {
//                                             newItem[AppDBConst.itemPrice] = regularPrice;
//                                             // Optionally also update unit price if used
//                                             newItem[AppDBConst.itemUnitPrice] = regularPrice;
//                                           }
//
//                                           return newItem;
//                                         }).toList();

                            // 🔥 NEW: Fix price before sending to OrderSummaryScreen (Enhanced for all discount types)
                            final List<Map<String, dynamic>> itemsForSummary = filteredItems.map((item) {
                              final Map<String, dynamic> newItem = Map<String, dynamic>.from(item);

                              final double qty = (item[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
                              final double sumPrice = (item[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;

                              // Get all discount amounts for this item
                              final double autoDiscount = (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;
                              final double multipackDiscount = (item[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
                              final double comboDiscount = (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
                              final double totalItemDiscount = autoDiscount + multipackDiscount + comboDiscount;

                              // Current discounted unit price from DB
                              double currentUnitPrice = (item[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                  (item[AppDBConst.itemUnitPrice] as num?)?.toDouble() ?? 0.0;

                              if (currentUnitPrice == 0.0 && sumPrice > 0 && qty > 0) {
                                currentUnitPrice = sumPrice / qty;
                              }

                              // If item has discounts, restore the original pre-discount price for display
                              // The summary screen uses itemPrice as the "unit price" shown with strikethrough
                              if (totalItemDiscount > 0 && qty > 0) {
                                final double originalUnitPrice = currentUnitPrice + (totalItemDiscount / qty);
                                newItem[AppDBConst.itemPrice] = originalUnitPrice;
                                newItem[AppDBConst.itemUnitPrice] = originalUnitPrice;
                                // item_sum_price must also reflect the pre-discount total so the summary
                                // screen can subtract discounts from it and show the correct final price
                                newItem[AppDBConst.itemSumPrice] = originalUnitPrice * qty;
                              }

                              newItem['original_price'] = currentUnitPrice;
                              newItem['regular_price'] = (item[AppDBConst.itemRegularPrice] as num?)?.toDouble() ?? currentUnitPrice;

                              return newItem;
                            }).toList();

                            print("🔎 AFTER PRICE FIX FOR SUMMARY");
                            for (var item in itemsForSummary) {
                              print(
                                  "Name: ${item[AppDBConst.itemName]} | "
                                      "Sent Price: ${item[AppDBConst.itemPrice]} | "
                                      "Regular: ${item[AppDBConst.itemRegularPrice]} | "
                                      "Qty: ${item[AppDBConst.itemCount]}");


                              print("🚀 NAVIGATING TO ORDER SUMMARY");
                              print("   netPayable          : ${netPayable.toStringAsFixed(2)}");
                              print("   uiNetPayable        : ${uiNetPayable.toStringAsFixed(2)}");
                              print("   grossTotal          : ${grossTotal.toStringAsFixed(2)}");
                              print("   orderDiscount       : ${orderDiscount.toStringAsFixed(2)}");
                              print("   merchantDiscount    : ${merchantDiscount.toStringAsFixed(2)}");
                              print("   orderTax            : ${orderTax.toStringAsFixed(2)}");
                              print("   cashbackFee         : ${cashbackFee.toStringAsFixed(2)}");
                              print("   uiGrossTotal        : ${uiGrossTotal.toStringAsFixed(2)}");
                            }

                            // Customer display update
                            try {
                              final customerDisplayItems = itemsForSummary.map((item) {
                                final qty = (item[AppDBConst.itemCount] as num?)?.toInt() ?? 1;
                                final price =
                                    (item[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;

                                // ── Read all discount variants ──────────────────────────────
                                final double _autoD =
                                    (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ??
                                        (item['auto_discount'] as num?)?.toDouble() ??
                                        (item['autoDiscount'] as num?)?.toDouble() ??
                                        (item[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ??
                                        0.0;

                                final double _comboD =
                                    (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ??
                                        (item['combo_discount_total'] as num?)?.toDouble() ??
                                        (item['comboDiscountTotal'] as num?)?.toDouble() ??
                                        (item['mixmatch_discount_total'] as num?)?.toDouble() ??
                                        0.0;

                                final double _multipackD =
                                    (item[AppDBConst.multipackDiscount] as num?)?.toDouble() ??
                                        (item['multipack_discount_total'] as num?)?.toDouble() ??
                                        (item['multipackDiscountTotal'] as num?)?.toDouble() ??
                                        0.0;

                                final String _dtype =
                                (item['discount_type'] ?? '').toString().toLowerCase();

                                // ── Resolve correct discount per type (same logic as summary screen) ──
                                double _resolvedAuto = 0.0;
                                double _resolvedCombo = 0.0;
                                double _resolvedMultipack = 0.0;

                                if (_dtype == 'multipack') {
                                  _resolvedMultipack = _multipackD > 0 ? _multipackD : _autoD;
                                } else if (_dtype == 'combo' || _dtype == 'mixmatch') {
                                  _resolvedCombo = _comboD > 0 ? _comboD : _autoD;
                                } else {
                                  // 'auto' or empty — but also handle when backend puts
                                  // multipack/combo amount into auto_discount key
                                  _resolvedAuto = _autoD;
                                  _resolvedCombo = _comboD;
                                  _resolvedMultipack = _multipackD;
                                }

                                print("REDEEM VALUE FROM PENDING ORDER = $redeemValue");
                                print(
                                  "DISPLAY ITEM => ${item[AppDBConst.itemName]} | Qty: $qty | Price: $price"
                                      " | auto=$_resolvedAuto | combo=$_resolvedCombo | multi=$_resolvedMultipack | type=$_dtype",
                                );

                                return {
                                  "name": item[AppDBConst.itemName]?.toString() ?? "",
                                  "qty": qty,
                                  "price": price,
                                  "original_price":
                                  (item["original_price"] as num?)?.toDouble() ?? price,
                                  "auto_discount": _resolvedAuto,
                                  "combo_discount": _resolvedCombo,
                                  "multipack_discount": _resolvedMultipack,
                                  "discount_type": _dtype,
                                  "image": item["image"]?.toString() ?? "",
                                };
                              }).toList();
                              print("======== CUSTOMER DISPLAY ========");
                              print("Gross Total: $grossTotal");
                              print("Order Discount: $uiOrderDiscount");
                              print("Merchant Discount: $merchantDiscount");
                              print("Tax: $uiOrderTax");
                              print("Net Payable: $netPayable");
                              print("==================================");

                              CustomerDisplayHelper.skipNextPendingOrderRefresh = true;

                              if (selectedOrderId != null) {
                                await CustomerDisplayService.showCustomerData(
                                  orderId: selectedOrderId,
                                  items: customerDisplayItems,
                                  grossTotal: grossTotal.toDouble(),
                                  discount: uiOrderDiscount.toDouble(),
                                  merchantDiscount: merchantDiscount.toDouble(),
                                  tax: wooTax.toDouble(),
                                  cashbackFee: cashbackFee.toDouble(),
                                  netPayable: netPayable.toDouble(),
                                  netTotal: (grossTotal -
                                      uiOrderDiscount -
                                      merchantDiscount)
                                      .toDouble(),
                                  orderDate: displayDate,
                                  orderTime: displayTime,
                                  redeemedAmount: redeemValue,
                                  summaryEnabled: true,
                                );
                              }
                            } catch (e) {
                              print(">>> Customer display update failed: $e");
                            }
                            // navigation to order summary
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                // builder: (_) => OrderSummaryScreen(
                                //   orderItems:itemsForSummary,
                                //   // filteredItems, //  ONLY product items
                                //   formattedDate: displayDate,
                                //   formattedTime: displayTime,
                                //   grossTotal: grossTotal.toDouble(),
                                //   // grossTotal: itemRegularPrice,           // Keep your current gross for totals
                                //   // orderDiscount: orderDiscount,
                                //   orderDiscount: uiOrderDiscount,
                                //
                                //   merchantDiscount:
                                //   merchantDiscount,
                                //   orderTax: uiOrderTax,
                                //   netPayable: netPayable.toDouble(),
                                //
                                //   orderId: selectedOrderId,
                                //
                                //   offlineOrderId:
                                //   frozenSummaryOrderId,
                                //   cashbackFee: cashbackFee,
                                //   ebtAmount: ebtAmount,
                                //   discountAmount: discountAmount,
                                //   itemPricesAlreadyAdjusted: true, // ADD THIS — prices fixed in panel, skip double-subtract
                                //
                                // ),

                                builder: (_) => OrderSummaryScreen(
                                  orderItems:itemsForSummary,
                                  // filteredItems, //  ONLY product items
                                  formattedDate: displayDate,
                                  formattedTime: displayTime,
                                  grossTotal: grossTotal.toDouble(),
                                  // grossTotal: itemRegularPrice,           // Keep your current gross for totals
                                  // orderDiscount: orderDiscount,
                                  orderDiscount: uiOrderDiscount,

                                  merchantDiscount:
                                  uiMerchantDiscount,
                                  orderTax: double.parse(wooTax.toStringAsFixed(2)),                                  netPayable: netPayable.toDouble(),

                                  orderId: selectedOrderId,

                                  offlineOrderId:
                                  frozenSummaryOrderId,
                                  cashbackFee: cashbackFee,
                                  ebtAmount: ebtAmount,
                                  discountAmount: discountAmount,
                                  itemPricesAlreadyAdjusted: true, // ADD THIS — prices fixed in panel, skip double-subtract

                                ),
                              ),
                            );

                            if (kDebugMode) {
                              print(
                                  "###### OrderScreenPanel: Returned from OrderSummaryScreen with result: $result");
                            }
                            // Handle refresh if result is 'refresh'
                            if (result == TextConstants.refresh) {
                              // Build #1.0.175: added TextConstants
                              if (kDebugMode) {
                                print(
                                    "###### OrderScreenPanel: Refresh signal received, reinitializing entire screen");
                              }

                              // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                              widget.refreshOrderList?.call();
                            }
                            setState(
                                    () => _isPayBtnLoading = false);

                            ///No need to update here now, may cause empty items added to order
                            //     // Assign the subscription to your class variable
                            //     _updateOrderSubscription = orderBloc.updateOrderStream.listen((response) async {
                            //       if (!mounted) return; // Safety check
                            //       if (response.status == Status.LOADING) { // Build #1.0.80
                            //         const Center(child: CircularProgressIndicator());
                            //       }else if (response.status == Status.COMPLETED) {
                            //         if (kDebugMode) {
                            //           print("###### updateOrder COMPLETED");
                            //         }
                            //
                            //         setState(() => _isPayBtnLoading = false); // dismiss the loader
                            //
                            //         Navigator.push(
                            //           context,
                            //           MaterialPageRoute(builder: (context) => OrderSummaryScreen()),
                            //         );
                            //       } else if (response.status == Status.ERROR) {
                            //         ScaffoldMessenger.of(context).showSnackBar(
                            //           SnackBar(content: Text(response.message ?? "Failed to update order")),
                            //         );
                            //       }
                            //     });
                            //
                            //     // Prepare line items for API
                            //     List<OrderLineItem> lineItems = orderItems.map((item) => OrderLineItem(
                            //       productId: item[AppDBConst.itemId],
                            //       quantity: item[AppDBConst.itemCount],
                            //     )).toList();
                            //
                            //     // Call API
                            //     await orderBloc.updateOrderProducts(
                            //       dbOrderId: orderHelper.activeOrderId!,
                            //       orderId: serverOrderId,
                            //       lineItems: lineItems,
                            //     );
                          }
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          netPayable >= 0 && orderItems.isNotEmpty
                              ? const Color(0xFFFF6B6B)
                              : Colors.grey, // Coral red color
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                        _isPayBtnLoading //Build 1.1.36: added loader for pay button in order panel
                            ? CircularProgressIndicator(
                            color: Colors.white)
                            : Text(
                          // "${TextConstants.pay} ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                          TextConstants
                              .pay, // Build #1.0.175: No need show amount on PAY button in order screen panel
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(),
                ],
              ),
            )
          ],
        ),
        if (_isLoading) // ADDED PROGRESS INDICATOR
          Container(
            color: Colors.black.withOpacity(0.5), // Black tint overlay
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.black, // Black loader
                strokeWidth: 6.0,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildProductImage(String? imagePath,
      {double height = 60, double width = 60}) {
    const String fallback = 'assets/custom.png';

    // No image at all → use fallback
    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset(
        fallback,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    }

    // HTTP image
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Image.asset(
            fallback,
            height: height,
            width: width,
            fit: BoxFit.cover,
          );
        },
      );
    }

    // Local asset .png/.jpg
    return Image.asset(
      imagePath,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          fallback,
          height: height,
          width: width,
          fit: BoxFit.cover,
        );
      },
    );
  }


  // Future _preparePrintTicket() async {
  //   if (kDebugMode) {
  //     print("OrderScreenPanel _preparePrintTicket call print receipt");
  //   }
  //
  //   await loadPrinterData();
  //   var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
  //   var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
  //   var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
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
  //   // UPDATED: Store Details from Asset Model (Primary Source)
  //   // -------------------------------
  //   final storeDetails = await AssetDBHelper.instance.getStoreDetails();
  //
  //   // Primary values from Asset
  //   final storeName = storeDetails?.name ?? "Store Name";
  //   final address = "${storeDetails?.address ?? ''},";
  //   final cityStateZip =
  //       "${storeDetails?.city ?? ''}, ${storeDetails?.state ?? ''}-${storeDetails?.zipCode ?? ''}";
  //   final storePhone = storeDetails?.phoneNumber ?? "N/A";
  //   // final storeId = storeDetails?.storeId ?? "N/A";        // ← Now safe
  //
  //   final merchant = await StoreDbHelper.instance.getStoreValidationData();
  //   final storeId = "${merchant?[AppDBConst.storeId] ?? 'N/A'}";
  //
  //   // Fallback to old Store Validation (kept for safety - no breaking change)
  //   // final merchant = await StoreDbHelper.instance.getStoreValidationData();
  //   final finalStoreId = storeId != "N/A"
  //       ? storeId
  //       : "${merchant?[AppDBConst.storeId] ?? 'N/A'}";
  //   final finalStorePhone = storePhone != "N/A"
  //       ? storePhone
  //       : "${merchant?[AppDBConst.storePhone] ?? 'N/A'}";
  //
  //   final userData = await UserDbHelper().getUserData();
  //
  //   final cashierName = "${userData?[AppDBConst.userDisplayName] ?? 'Cashier'}";
  //   final cashierRole = "${userData?[AppDBConst.userRole] ?? 'Staff'}";
  //
  //   final orderIdToPrint = '${widget.activeOrderId ?? 'N/A'}';
  //
  //   // // Date & Time from Order (unchanged)
  //   // String dateToPrint = "";
  //   // String timeToPrint = "";
  //   // if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
  //   //   try {
  //   //     final created = DateTime.parse(_order[AppDBConst.orderDate].toString());
  //   //     dateToPrint = DateFormat(TextConstants.dateFormat).format(created);
  //   //     timeToPrint = DateFormat(TextConstants.timeFormat).format(created);
  //   //   } catch (e) {
  //   //     if (kDebugMode) print("Date parse error: $e");
  //   //     dateToPrint = "N/A";
  //   //     timeToPrint = "N/A";
  //   //   }
  //   // }
  //
  //   // Date & Time from Order - SAME LOGIC AS SCREEN PANEL
  //   String dateToPrint = "";
  //   String timeToPrint = "";
  //
  //   final DateTime? bestDateTime = _getBestDateTime();   // Reuse the same method
  //
  //   if (bestDateTime != null) {
  //     dateToPrint = DateFormat(TextConstants.dateFormat).format(bestDateTime);
  //
  //     //  12-Hour format with AM/PM (as requested)
  //     timeToPrint = DateFormat('hh:mm a').format(bestDateTime);   // e.g., 02:35 PM
  //   }
  //   else if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
  //     // Fallback (kept your original logic as safety net)
  //     try {
  //       final created = DateTime.parse(_order[AppDBConst.orderDate].toString());
  //       dateToPrint = DateFormat(TextConstants.dateFormat).format(created);
  //       timeToPrint = DateFormat('hh:mm a').format(created);   // AM/PM
  //     } catch (e) {
  //       if (kDebugMode) print("Date parse error: $e");
  //       dateToPrint = "N/A";
  //       timeToPrint = "N/A";
  //     }
  //   } else {
  //     dateToPrint = "N/A";
  //     timeToPrint = "N/A";
  //   }
  //
  //   // -------------------------------
  //   // HEADER & STORE INFO (using Asset data primarily)
  //   // -------------------------------
  //   if (header.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: "***** INVOICE COPY *****",
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
  //     PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "Phone: $finalStorePhone",
  //         width: 12,
  //         styles: PosStyles(align: PosAlign.center)),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Date: $dateToPrint", width: 7),
  //     PosColumn(text: "Time: $timeToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Cashier: $cashierName", width: 7),
  //     PosColumn(text: "StoreID: $finalStoreId", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Role: $cashierRole", width: 7),
  //     PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // -------------------------------
  //   // ITEM HEADER & ITEMS LOOP (Completely Unchanged)
  //   // -------------------------------
  //   bytes += ticket.row([
  //     PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
  //     PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
  //     PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center, bold: true)),
  //     PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
  //     PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
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
  //   // Align with order_summary_screen receipt: same keys + discount_type routing.
  //   double _printItemDouble(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is num) return v.toDouble();
  //       return double.tryParse(v.toString()) ?? 0.0;
  //     }
  //     return 0.0;
  //   }
  //
  //   int _printItemInt(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is int) return v;
  //       if (v is num) return v.toInt();
  //       return int.tryParse(v.toString()) ?? 0;
  //     }
  //     return 0;
  //   }
  //
  //   String _printItemName(Map<dynamic, dynamic> m) {
  //     final a = m['item_name']?.toString();
  //     if (a != null && a.isNotEmpty) return a;
  //     final b = m[AppDBConst.itemName]?.toString();
  //     return b ?? '';
  //   }
  //
  //   // ITEMS LOOP (unchanged - kept exactly as you had)
  //   int printLineNo = 0;
  //   for (int i = 0; i < orderItems.length; i++) {
  //     final Map<dynamic, dynamic> item = orderItems[i];
  //
  //     String itemName = _printItemName(item);
  //     double unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
  //     int qty = _printItemInt(item, ['items_count', AppDBConst.itemCount]);
  //     if (qty <= 0) qty = 1;
  //
  //     double lineTotal = _printItemDouble(item, ['item_sum_price', AppDBConst.itemSumPrice]);
  //
  //     String type = (item['item_type'] ?? item[AppDBConst.itemType] ?? '')
  //         .toString()
  //         .toLowerCase();
  //
  //     // Skip non-product lines
  //     if (itemName.toLowerCase().contains("discount") ||
  //         itemName.toLowerCase().contains("coupon") ||
  //         itemName.toLowerCase().contains("loyalty") ||
  //         itemName.toLowerCase().contains("redeemed") ||
  //         itemName.toLowerCase().contains("points") ||
  //         type.contains("discount") ||
  //         type.contains("coupon") ||
  //         type.contains("loyalty") ||
  //         type.contains("points")) {
  //       continue;
  //     }
  //
  //     bool isPayout = type.contains(TextConstants.payoutText);
  //     bool isCoupon = type.contains(TextConstants.couponText);
  //     bool isCashback = type.contains("cashback");
  //     bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
  //
  //     String discountType = (item['discount_type'] ?? item['discountType'] ?? '').toString().toLowerCase();
  //
  //     final double autoRaw = _printItemDouble(item, ['auto_discount', AppDBConst.autoDiscountTotal]);
  //     final double comboRaw = _printItemDouble(item, ['combo_discount_total', AppDBConst.comboDiscountTotal]);
  //     final double multipackRaw = _printItemDouble(item, ['multipack_discount_total', AppDBConst.multipackDiscount]);
  //     final double mixRaw = _printItemDouble(item, ['mixmatch_discount_total']);
  //
  //     double autoDiscount = (discountType.isEmpty || discountType == 'auto') ? autoRaw : 0.0;
  //     double multipackDiscount = (discountType == 'multipack') ? (autoRaw > 0 ? autoRaw : multipackRaw) : 0.0;
  //     double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
  //         ? (autoRaw > 0 ? autoRaw : (comboRaw > 0 ? comboRaw : mixRaw))
  //         : 0.0;
  //
  //     if (discountType.isEmpty && autoDiscount == 0 && multipackDiscount == 0 && comboDiscount == 0) {
  //       autoDiscount = autoRaw;
  //       if (autoDiscount == 0) {
  //         multipackDiscount = multipackRaw;
  //         comboDiscount = comboRaw > 0 ? comboRaw : mixRaw;
  //       }
  //     }
  //
  //     if (!isPayoutOrCoupon) {
  //       final double totalLineDiscount = autoDiscount + comboDiscount + multipackDiscount;
  //       if (totalLineDiscount > 0) {
  //         lineTotal = lineTotal + totalLineDiscount;
  //         unitPrice = qty > 0 ? (lineTotal / qty) : lineTotal;
  //       } else if (unitPrice == 0 && qty > 0) {
  //         unitPrice = lineTotal / qty;
  //       }
  //     }
  //
  //     printLineNo++;
  //     bytes += ticket.row([
  //       PosColumn(text: "$printLineNo", width: 1),
  //       PosColumn(text: itemName, width: 5),
  //       PosColumn(text: "$qty", width: 1, styles: PosStyles(align: PosAlign.center)),
  //       PosColumn(text: formatCurrency(unitPrice), width: 2, styles: PosStyles(align: PosAlign.right)),
  //       PosColumn(text: formatCurrency(lineTotal), width: 3, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //
  //     if (autoDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "Auto Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (comboDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "Combo Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (multipackDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "Multipack Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     bytes += ticket.emptyLines(1);
  //   }
  //
  //   // -------------------------------
  //   // TOTALS SECTION (unchanged)
  //   // -------------------------------
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.grossTotal, width: 8),
  //     PosColumn(text: formatCurrency(uiGrossTotal), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.discountText, width: 8),
  //     PosColumn(text: uiOrderDiscount != 0 ? formatCurrency(uiOrderDiscount) : formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.merchantDiscount, width: 8),
  //     PosColumn(text: uiMerchantDiscount != 0 ? "-${TextConstants.currencySymbol}${uiMerchantDiscount.abs().toStringAsFixed(2)}" : "${TextConstants.currencySymbol}0.00", width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   // bytes += ticket.row([
  //   //   PosColumn(text: TextConstants.taxText, width: 8),
  //   //   PosColumn(text: formatCurrency(uiOrderTax), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   // ]);
  //    double wooTax = 0.0;
  //   if (_wooOrder != null) {
  //     wooTax = double.tryParse(_wooOrder!.totalTax ?? '0') ?? 0.0;
  //   } else if (_order.isNotEmpty) {
  //     wooTax = double.tryParse(_order['total_tax']?.toString() ??
  //         _order['wooTax']?.toString() ??
  //         _order['orderTax']?.toString() ?? '0') ?? 0.0;
  //   } else {
  //     wooTax = uiOrderTax; // fallback
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.taxText, width: 8),
  //     PosColumn(text: formatCurrency(wooTax), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //
  //   if (uiCashbackFee > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: TextConstants.cashbackFee, width: 8),
  //       PosColumn(text: formatCurrency(uiCashbackFee), width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.servicecharges, width: 8),
  //     PosColumn(text: formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   double printNetPayable = uiNetPayable;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.netPayable, width: 8),
  //     PosColumn(text: formatCurrency(printNetPayable), width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
  //   ]);
  //
  //   if (uiRedeemedValue > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Redeemed Amount", width: 8),
  //       PosColumn(text: "-${formatCurrency(uiRedeemedValue).replaceAll('-', '')}", width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   // Payment split logic (unchanged)
  //   double printPayByCash = payByCash;
  //   double printPayByEbt = ebtAmount;
  //   double printPayByOther = payByOther;
  //   // ... (your existing payment lookup code remains unchanged)
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByCash, width: 8),
  //     PosColumn(text: formatCurrency(printPayByCash), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Pay by EBT", width: 8),
  //     PosColumn(text: formatCurrency(printPayByEbt), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByOther, width: 8),
  //     PosColumn(text: formatCurrency(printPayByOther), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.tenderAmount, width: 8),
  //     PosColumn(text: formatCurrency(tenderAmount), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   final double effectiveTender = tenderAmount.clamp(0.0, double.infinity);
  //   double printChange = (effectiveTender - printNetPayable).clamp(0.0, double.infinity);
  //   if (balanceAmount > 0) {
  //     printChange = 0.0;
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.change, width: 8),
  //     PosColumn(text: formatCurrency(printChange), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12)
  //   ]);
  //
  //   if (footer != "") {
  //     bytes += ticket.feed(1);
  //     bytes += ticket.row([
  //       PosColumn(text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  // }

  // Future _preparePrintTicket() async {
  //   if (kDebugMode) {
  //     print("OrderScreenPanel _preparePrintTicket call print receipt");
  //   }
  //
  //   await loadPrinterData();
  //   var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
  //   var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
  //   var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
  //
  //   bytes = [];
  //   final ticket = await _printerSettings.getTicket();
  //
  //   // -------------------------------
  //   // LOGO
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
  //     img.Image originalImg = img.copyResize(decodedImage, width: 470, height: 280);
  //     img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
  //     var padding = (originalImg.width - thumbnail.width) / 2;
  //     drawImage(originalImg, thumbnail, dstX: padding.toInt());
  //     var grayscaleImage = img.grayscale(originalImg);
  //     // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
  //   }
  //
  //   // -------------------------------
  //   // STORE DETAILS
  //   // -------------------------------
  //   final storeDetails = await AssetDBHelper.instance.getStoreDetails();
  //
  //   final storeName = storeDetails?.name ?? "Store Name";
  //   final address = "${storeDetails?.address ?? ''},";
  //   final cityStateZip = "${storeDetails?.city ?? ''}, ${storeDetails?.state ?? ''}-${storeDetails?.zipCode ?? ''}";
  //   final storePhone = storeDetails?.phoneNumber ?? "N/A";
  //
  //   final merchant = await StoreDbHelper.instance.getStoreValidationData();
  //   final storeId = "${merchant?[AppDBConst.storeId] ?? 'N/A'}";
  //
  //   final finalStoreId = storeId != "N/A" ? storeId : "${merchant?[AppDBConst.storeId] ?? 'N/A'}";
  //   final finalStorePhone = storePhone != "N/A" ? storePhone : "${merchant?[AppDBConst.storePhone] ?? 'N/A'}";
  //
  //   final userData = await UserDbHelper().getUserData();
  //
  //   final cashierName = "${userData?[AppDBConst.userDisplayName] ?? 'Cashier'}";
  //   final cashierRole = "${userData?[AppDBConst.userRole] ?? 'Staff'}";
  //
  //   final orderIdToPrint = '${widget.activeOrderId ?? 'N/A'}';
  //
  //   // Date & Time
  //   String dateToPrint = "";
  //   String timeToPrint = "";
  //
  //   final DateTime? bestDateTime = _getBestDateTime();
  //
  //   if (bestDateTime != null) {
  //     dateToPrint = DateFormat(TextConstants.dateFormat).format(bestDateTime);
  //     timeToPrint = DateFormat('hh:mm a').format(bestDateTime);
  //   } else if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
  //     try {
  //       final created = DateTime.parse(_order[AppDBConst.orderDate].toString());
  //       dateToPrint = DateFormat(TextConstants.dateFormat).format(created);
  //       timeToPrint = DateFormat('hh:mm a').format(created);
  //     } catch (e) {
  //       if (kDebugMode) print("Date parse error: $e");
  //       dateToPrint = "N/A";
  //       timeToPrint = "N/A";
  //     }
  //   } else {
  //     dateToPrint = "N/A";
  //     timeToPrint = "N/A";
  //   }
  //
  //   // -------------------------------
  //   // HEADER
  //   // -------------------------------
  //   if (header.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: "***** INVOICE COPY *****",
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
  //     PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
  //   ]);
  //   bytes += ticket.row([
  //     PosColumn(
  //         text: "Phone: $finalStorePhone",
  //         width: 12,
  //         styles: PosStyles(align: PosAlign.center)),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Date: $dateToPrint", width: 7),
  //     PosColumn(text: "Time: $timeToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Cashier: $cashierName", width: 7),
  //     PosColumn(text: "StoreID: $finalStoreId", width: 5),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Role: $cashierRole", width: 7),
  //     PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
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
  //     PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center, bold: true)),
  //     PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
  //     PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
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
  //   // Helper to check if item is weighted
  //   bool isWeightedItem(Map<dynamic, dynamic> item) {
  //     final bool flag = item['is_weighted'] == true ||
  //         item['is_weighted'] == 1 ||
  //         item['item_type'] == 'weighted';
  //
  //     if (!flag) {
  //       final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
  //       if (wq != null) {
  //         final double w = wq is num ? wq.toDouble() : double.tryParse(wq.toString()) ?? 0.0;
  //         if (w > 0) return true;
  //       }
  //     }
  //     return flag;
  //   }
  //
  //   // Helper to get weight quantity
  //   double getWeightQty(Map<dynamic, dynamic> item) {
  //     final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
  //     if (wq is num) return wq.toDouble();
  //     return double.tryParse(wq?.toString() ?? '0') ?? 0.0;
  //   }
  //
  //   // Helper to get unit price for weighted items
  //   double getWeightUnitPrice(Map<dynamic, dynamic> item) {
  //     final dynamic up = item['unit_price'];
  //     if (up is num) return up.toDouble();
  //     return double.tryParse(up?.toString() ?? '0') ?? 0.0;
  //   }
  //
  //   double _printItemDouble(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is num) return v.toDouble();
  //       return double.tryParse(v.toString()) ?? 0.0;
  //     }
  //     return 0.0;
  //   }
  //
  //   int _printItemInt(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is int) return v;
  //       if (v is num) return v.toInt();
  //       return int.tryParse(v.toString()) ?? 0;
  //     }
  //     return 0;
  //   }
  //
  //   String _printItemName(Map<dynamic, dynamic> m) {
  //     final a = m['item_name']?.toString();
  //     if (a != null && a.isNotEmpty) return a;
  //     final b = m[AppDBConst.itemName]?.toString();
  //     return b ?? '';
  //   }
  //
  //   // Helper to wrap long item names into multiple lines (max 18 chars per line)
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
  //   // ITEMS LOOP - WITH WEIGHTED ITEM SUPPORT AND NAME WRAPPING
  //   int printLineNo = 0;
  //   for (int i = 0; i < orderItems.length; i++) {
  //     final Map<dynamic, dynamic> item = orderItems[i];
  //
  //     String itemName = _printItemName(item);
  //
  //     // Check if this is a weighted item
  //     final bool isWeighted = isWeightedItem(item);
  //
  //     double unitPrice = 0.0;
  //     double displayQty = 0.0;
  //     String qtyDisplay = "";
  //
  //     if (isWeighted) {
  //       // WEIGHTED ITEM: Use weight_qty and unit_price
  //       unitPrice = getWeightUnitPrice(item);
  //       if (unitPrice == 0) {
  //         unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
  //       }
  //
  //       displayQty = getWeightQty(item);
  //       if (displayQty == 0) {
  //         displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
  //         if (displayQty <= 0) displayQty = 1.0;
  //       }
  //
  //       // NO SPACE between number and "lb"
  //       qtyDisplay = "${displayQty.toStringAsFixed(2)}lb";
  //     } else {
  //       // REGULAR ITEM
  //       unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
  //       displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
  //       if (displayQty <= 0) displayQty = 1.0;
  //       qtyDisplay = displayQty.toInt().toString();
  //     }
  //
  //     double lineTotal = _printItemDouble(item, ['item_sum_price', AppDBConst.itemSumPrice]);
  //
  //     String type = (item['item_type'] ?? item[AppDBConst.itemType] ?? '')
  //         .toString()
  //         .toLowerCase();
  //
  //     // Skip non-product lines
  //     if (itemName.toLowerCase().contains("discount") ||
  //         itemName.toLowerCase().contains("coupon") ||
  //         itemName.toLowerCase().contains("loyalty") ||
  //         itemName.toLowerCase().contains("redeemed") ||
  //         itemName.toLowerCase().contains("points") ||
  //         type.contains("discount") ||
  //         type.contains("coupon") ||
  //         type.contains("loyalty") ||
  //         type.contains("points")) {
  //       continue;
  //     }
  //
  //     bool isPayout = type.contains(TextConstants.payoutText);
  //     bool isCoupon = type.contains(TextConstants.couponText);
  //     bool isCashback = type.contains("cashback");
  //     bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
  //
  //     // For weighted items, recalculate line total if needed
  //     if (isWeighted && unitPrice > 0 && displayQty > 0) {
  //       lineTotal = unitPrice * displayQty;
  //     }
  //
  //     String discountType = (item['discount_type'] ?? item['discountType'] ?? '').toString().toLowerCase();
  //
  //     final double autoRaw = _printItemDouble(item, ['auto_discount', AppDBConst.autoDiscountTotal]);
  //     final double comboRaw = _printItemDouble(item, ['combo_discount_total', AppDBConst.comboDiscountTotal]);
  //     final double multipackRaw = _printItemDouble(item, ['multipack_discount_total', AppDBConst.multipackDiscount]);
  //     final double mixRaw = _printItemDouble(item, ['mixmatch_discount_total']);
  //
  //     double autoDiscount = (discountType.isEmpty || discountType == 'auto') ? autoRaw : 0.0;
  //     double multipackDiscount = (discountType == 'multipack') ? (autoRaw > 0 ? autoRaw : multipackRaw) : 0.0;
  //     double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
  //         ? (autoRaw > 0 ? autoRaw : (comboRaw > 0 ? comboRaw : mixRaw))
  //         : 0.0;
  //
  //     if (discountType.isEmpty && autoDiscount == 0 && multipackDiscount == 0 && comboDiscount == 0) {
  //       autoDiscount = autoRaw;
  //       if (autoDiscount == 0) {
  //         multipackDiscount = multipackRaw;
  //         comboDiscount = comboRaw > 0 ? comboRaw : mixRaw;
  //       }
  //     }
  //
  //     // Apply discounts to line total
  //     if (!isPayoutOrCoupon) {
  //       final double totalLineDiscount = autoDiscount + comboDiscount + multipackDiscount;
  //       if (totalLineDiscount > 0) {
  //         lineTotal = lineTotal - totalLineDiscount;
  //       }
  //     }
  //
  //     // Wrap long item names
  //     List<String> nameLines = wrapItemName(itemName, 18); // Max 18 chars per line
  //
  //     printLineNo++;
  //
  //     // Print first line with all details
  //     bytes += ticket.row([
  //       PosColumn(text: "$printLineNo", width: 1),
  //       PosColumn(text: nameLines[0], width: 5),
  //       PosColumn(text: qtyDisplay, width: 1, styles: PosStyles(align: PosAlign.center)),
  //       PosColumn(text: formatCurrency(unitPrice), width: 2, styles: PosStyles(align: PosAlign.right)),
  //       PosColumn(text: formatCurrency(lineTotal), width: 3, styles: PosStyles(align: PosAlign.right)),
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
  //
  //     // Print discounts
  //     if (autoDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Auto Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (comboDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Combo Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (multipackDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Multipack Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     bytes += ticket.emptyLines(1);
  //   }
  //
  //   // -------------------------------
  //   // TOTALS SECTION
  //   // -------------------------------
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.grossTotal, width: 8),
  //     PosColumn(text: formatCurrency(uiGrossTotal), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.discountText, width: 8),
  //     PosColumn(text: uiOrderDiscount != 0 ? formatCurrency(uiOrderDiscount) : formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.merchantDiscount, width: 8),
  //     PosColumn(text: uiMerchantDiscount != 0 ? "-${TextConstants.currencySymbol}${uiMerchantDiscount.abs().toStringAsFixed(2)}" : "${TextConstants.currencySymbol}0.00", width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   double wooTax = 0.0;
  //   if (_wooOrder != null) {
  //     wooTax = double.tryParse(_wooOrder!.totalTax ?? '0') ?? 0.0;
  //   } else if (_order.isNotEmpty) {
  //     wooTax = double.tryParse(_order['total_tax']?.toString() ??
  //         _order['wooTax']?.toString() ??
  //         _order['orderTax']?.toString() ?? '0') ?? 0.0;
  //   } else {
  //     wooTax = uiOrderTax;
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.taxText, width: 8),
  //     PosColumn(text: formatCurrency(wooTax), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   if (uiCashbackFee > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: TextConstants.cashbackFee, width: 8),
  //       PosColumn(text: formatCurrency(uiCashbackFee), width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.servicecharges, width: 8),
  //     PosColumn(text: formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   double printNetPayable = uiNetPayable;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.netPayable, width: 8),
  //     PosColumn(text: formatCurrency(printNetPayable), width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
  //   ]);
  //
  //   if (uiRedeemedValue > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Redeemed Amount", width: 8),
  //       PosColumn(text: "-${formatCurrency(uiRedeemedValue).replaceAll('-', '')}", width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   // Payment split
  //   double printPayByCash = payByCash;
  //   double printPayByEbt = ebtAmount;
  //   double printPayByOther = payByOther;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByCash, width: 8),
  //     PosColumn(text: formatCurrency(printPayByCash), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Pay by EBT", width: 8),
  //     PosColumn(text: formatCurrency(printPayByEbt), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByOther, width: 8),
  //     PosColumn(text: formatCurrency(printPayByOther), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.tenderAmount, width: 8),
  //     PosColumn(text: formatCurrency(tenderAmount), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   final double effectiveTender = tenderAmount.clamp(0.0, double.infinity);
  //   double printChange = (effectiveTender - printNetPayable).clamp(0.0, double.infinity);
  //   if (balanceAmount > 0) {
  //     printChange = 0.0;
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.change, width: 8),
  //     PosColumn(text: formatCurrency(printChange), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12)
  //   ]);
  //
  //   if (footer != "") {
  //     bytes += ticket.feed(1);
  //     bytes += ticket.row([
  //       PosColumn(text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  // }


  // Future _preparePrintTicket() async {
  //   if (kDebugMode) {
  //     print("OrderScreenPanel _preparePrintTicket call print receipt");
  //   }
  //
  //   await loadPrinterData();
  //   var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
  //   var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
  //   var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
  //
  //   bytes = [];
  //   final ticket = await _printerSettings.getTicket();
  //
  //   // -------------------------------
  //   // LOGO
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
  //     img.Image originalImg = img.copyResize(decodedImage, width: 470, height: 280);
  //     img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
  //     var padding = (originalImg.width - thumbnail.width) / 2;
  //     drawImage(originalImg, thumbnail, dstX: padding.toInt());
  //     var grayscaleImage = img.grayscale(originalImg);
  //     // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
  //   }
  //
  //   // -------------------------------
  //   // STORE DETAILS - FIXED
  //   // -------------------------------
  //   final storeDetails = await AssetDBHelper.instance.getStoreDetails();
  //
  //   final storeName = storeDetails?.name ?? "Store Name";
  //
  //   // ✅ FIX: Only build address if it has content
  //   String address = "";
  //   if (storeDetails?.address != null && storeDetails!.address!.isNotEmpty) {
  //     address = "${storeDetails.address},";
  //   }
  //
  //   // ✅ FIX: Build cityStateZip only with non-empty values - NO COMMA OR DASH IF EMPTY
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
  //   // ✅ FIX: Get phone number properly
  //   String storePhone = storeDetails?.phoneNumber?.isNotEmpty == true
  //       ? storeDetails!.phoneNumber!
  //       : "";
  //
  //   final merchant = await StoreDbHelper.instance.getStoreValidationData();
  //
  //   // ✅ FIX: Get store ID properly
  //   String storeId = "";
  //   if (merchant != null && merchant[AppDBConst.storeId] != null) {
  //     final id = merchant[AppDBConst.storeId].toString();
  //     if (id.isNotEmpty && id != "null") {
  //       storeId = id;
  //     }
  //   }
  //
  //   // If storeId is empty, try to get from storeDetails
  //   if (storeId.isEmpty && storeDetails != null) {
  //     final id = storeDetails!.name?.toString() ?? "";
  //     if (id.isNotEmpty && id != "null" && id != "N/A") {
  //       storeId = id;
  //     }
  //   }
  //
  //   // ✅ FIX: If phone is empty, try merchant as fallback
  //   if (storePhone.isEmpty && merchant != null && merchant[AppDBConst.storePhone] != null) {
  //     final phone = merchant[AppDBConst.storePhone].toString();
  //     if (phone.isNotEmpty && phone != "null") {
  //       storePhone = phone;
  //     }
  //   }
  //
  //   final userData = await UserDbHelper().getUserData();
  //
  //   final cashierName = "${userData?[AppDBConst.userDisplayName] ?? 'Cashier'}";
  //   final cashierRole = "${userData?[AppDBConst.userRole] ?? 'Staff'}";
  //
  //   final orderIdToPrint = '${widget.activeOrderId ?? 'N/A'}';
  //
  //   // Date & Time
  //   String dateToPrint = "";
  //   String timeToPrint = "";
  //
  //   final DateTime? bestDateTime = _getBestDateTime();
  //
  //   if (bestDateTime != null) {
  //     dateToPrint = DateFormat(TextConstants.dateFormat).format(bestDateTime);
  //     timeToPrint = DateFormat('hh:mm a').format(bestDateTime);
  //   } else if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
  //     try {
  //       final created = DateTime.parse(_order[AppDBConst.orderDate].toString());
  //       dateToPrint = DateFormat(TextConstants.dateFormat).format(created);
  //       timeToPrint = DateFormat('hh:mm a').format(created);
  //     } catch (e) {
  //       if (kDebugMode) print("Date parse error: $e");
  //       dateToPrint = "";
  //       timeToPrint = "";
  //     }
  //   } else {
  //     dateToPrint = "";
  //     timeToPrint = "";
  //   }
  //
  //   // -------------------------------
  //   // HEADER
  //   // -------------------------------
  //   if (header.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(
  //       text: "***** INVOICE COPY *****",
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
  //   // ✅ FIX: Only print address if it has content
  //   if (address.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //   }
  //
  //   // ✅ FIX: Only print cityStateZip if it has content
  //   if (cityStateZip.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
  //     ]);
  //   }
  //
  //   // ✅ FIX: Only print phone if it has content
  //   if (storePhone.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(
  //           text: "Phone: $storePhone",
  //           width: 12,
  //           styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   // ✅ FIX: Only print Date if it has content
  //   if (dateToPrint.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Date: $dateToPrint", width: 7),
  //       PosColumn(text: "Time: ${timeToPrint.isNotEmpty ? timeToPrint : ''}", width: 5),
  //     ]);
  //   } else if (timeToPrint.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Time: $timeToPrint", width: 12),
  //     ]);
  //   }
  //
  //   // ✅ FIX: Only print StoreID if it has content
  //   if (storeId.isNotEmpty) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Cashier: $cashierName", width: 7),
  //       PosColumn(text: "StoreID: $storeId", width: 5),
  //     ]);
  //   } else {
  //     bytes += ticket.row([
  //       PosColumn(text: "Cashier: $cashierName", width: 12),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Role: $cashierRole", width: 7),
  //     PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
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
  //     PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center, bold: true)),
  //     PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
  //     PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
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
  //   // Helper to check if item is weighted
  //   bool isWeightedItem(Map<dynamic, dynamic> item) {
  //     final bool flag = item['is_weighted'] == true ||
  //         item['is_weighted'] == 1 ||
  //         item['item_type'] == 'weighted';
  //
  //     if (!flag) {
  //       final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
  //       if (wq != null) {
  //         final double w = wq is num ? wq.toDouble() : double.tryParse(wq.toString()) ?? 0.0;
  //         if (w > 0) return true;
  //       }
  //     }
  //     return flag;
  //   }
  //
  //   // Helper to get weight quantity
  //   double getWeightQty(Map<dynamic, dynamic> item) {
  //     final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
  //     if (wq is num) return wq.toDouble();
  //     return double.tryParse(wq?.toString() ?? '0') ?? 0.0;
  //   }
  //
  //   // Helper to get unit price for weighted items
  //   double getWeightUnitPrice(Map<dynamic, dynamic> item) {
  //     final dynamic up = item['unit_price'];
  //     if (up is num) return up.toDouble();
  //     return double.tryParse(up?.toString() ?? '0') ?? 0.0;
  //   }
  //
  //   double _printItemDouble(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is num) return v.toDouble();
  //       return double.tryParse(v.toString()) ?? 0.0;
  //     }
  //     return 0.0;
  //   }
  //
  //   int _printItemInt(Map<dynamic, dynamic> m, List<dynamic> keys) {
  //     for (final k in keys) {
  //       final v = m[k];
  //       if (v == null) continue;
  //       if (v is int) return v;
  //       if (v is num) return v.toInt();
  //       return int.tryParse(v.toString()) ?? 0;
  //     }
  //     return 0;
  //   }
  //
  //   String _printItemName(Map<dynamic, dynamic> m) {
  //     final a = m['item_name']?.toString();
  //     if (a != null && a.isNotEmpty) return a;
  //     final b = m[AppDBConst.itemName]?.toString();
  //     return b ?? '';
  //   }
  //
  //   // Helper to wrap long item names into multiple lines (max 18 chars per line)
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
  //   // ITEMS LOOP - WITH WEIGHTED ITEM SUPPORT AND NAME WRAPPING
  //   int printLineNo = 0;
  //   for (int i = 0; i < orderItems.length; i++) {
  //     final Map<dynamic, dynamic> item = orderItems[i];
  //
  //     String itemName = _printItemName(item);
  //
  //     // Check if this is a weighted item
  //     final bool isWeighted = isWeightedItem(item);
  //
  //     double unitPrice = 0.0;
  //     double displayQty = 0.0;
  //     String qtyDisplay = "";
  //
  //     if (isWeighted) {
  //       // WEIGHTED ITEM: Use weight_qty and unit_price
  //       unitPrice = getWeightUnitPrice(item);
  //       if (unitPrice == 0) {
  //         unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
  //       }
  //
  //       displayQty = getWeightQty(item);
  //       if (displayQty == 0) {
  //         displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
  //         if (displayQty <= 0) displayQty = 1.0;
  //       }
  //
  //       // NO SPACE between number and "lb"
  //       qtyDisplay = "${displayQty.toStringAsFixed(2)}lb";
  //     } else {
  //       // REGULAR ITEM
  //       unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
  //       displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
  //       if (displayQty <= 0) displayQty = 1.0;
  //       qtyDisplay = displayQty.toInt().toString();
  //     }
  //
  //     double lineTotal = _printItemDouble(item, ['item_sum_price', AppDBConst.itemSumPrice]);
  //
  //     String type = (item['item_type'] ?? item[AppDBConst.itemType] ?? '')
  //         .toString()
  //         .toLowerCase();
  //
  //     // Skip non-product lines
  //     if (itemName.toLowerCase().contains("discount") ||
  //         itemName.toLowerCase().contains("coupon") ||
  //         itemName.toLowerCase().contains("loyalty") ||
  //         itemName.toLowerCase().contains("redeemed") ||
  //         itemName.toLowerCase().contains("points") ||
  //         type.contains("discount") ||
  //         type.contains("coupon") ||
  //         type.contains("loyalty") ||
  //         type.contains("points")) {
  //       continue;
  //     }
  //
  //     bool isPayout = type.contains(TextConstants.payoutText);
  //     bool isCoupon = type.contains(TextConstants.couponText);
  //     bool isCashback = type.contains("cashback");
  //     bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;
  //
  //     // For weighted items, recalculate line total if needed
  //     if (isWeighted && unitPrice > 0 && displayQty > 0) {
  //       lineTotal = unitPrice * displayQty;
  //     }
  //
  //     String discountType = (item['discount_type'] ?? item['discountType'] ?? '').toString().toLowerCase();
  //
  //     final double autoRaw = _printItemDouble(item, ['auto_discount', AppDBConst.autoDiscountTotal]);
  //     final double comboRaw = _printItemDouble(item, ['combo_discount_total', AppDBConst.comboDiscountTotal]);
  //     final double multipackRaw = _printItemDouble(item, ['multipack_discount_total', AppDBConst.multipackDiscount]);
  //     final double mixRaw = _printItemDouble(item, ['mixmatch_discount_total']);
  //
  //     double autoDiscount = (discountType.isEmpty || discountType == 'auto') ? autoRaw : 0.0;
  //     double multipackDiscount = (discountType == 'multipack') ? (autoRaw > 0 ? autoRaw : multipackRaw) : 0.0;
  //     double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
  //         ? (autoRaw > 0 ? autoRaw : (comboRaw > 0 ? comboRaw : mixRaw))
  //         : 0.0;
  //
  //     if (discountType.isEmpty && autoDiscount == 0 && multipackDiscount == 0 && comboDiscount == 0) {
  //       autoDiscount = autoRaw;
  //       if (autoDiscount == 0) {
  //         multipackDiscount = multipackRaw;
  //         comboDiscount = comboRaw > 0 ? comboRaw : mixRaw;
  //       }
  //     }
  //
  //     // Apply discounts to line total
  //     if (!isPayoutOrCoupon) {
  //       final double totalLineDiscount = autoDiscount + comboDiscount + multipackDiscount;
  //       if (totalLineDiscount > 0) {
  //         lineTotal = lineTotal - totalLineDiscount;
  //       }
  //     }
  //
  //     // Wrap long item names
  //     List<String> nameLines = wrapItemName(itemName, 18); // Max 18 chars per line
  //
  //     printLineNo++;
  //
  //     // Print first line with all details
  //     bytes += ticket.row([
  //       PosColumn(text: "$printLineNo", width: 1),
  //       PosColumn(text: nameLines[0], width: 5),
  //       PosColumn(text: qtyDisplay, width: 1, styles: PosStyles(align: PosAlign.center)),
  //       PosColumn(text: formatCurrency(unitPrice), width: 2, styles: PosStyles(align: PosAlign.right)),
  //       PosColumn(text: formatCurrency(lineTotal), width: 3, styles: PosStyles(align: PosAlign.right)),
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
  //
  //     // Print discounts
  //     if (autoDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Auto Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (comboDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Combo Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     if (multipackDiscount > 0 && !isPayoutOrCoupon) {
  //       bytes += ticket.row([
  //         PosColumn(text: "  Multipack Discount", width: 9),
  //         PosColumn(text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
  //       ]);
  //     }
  //
  //     bytes += ticket.emptyLines(1);
  //   }
  //
  //   // -------------------------------
  //   // TOTALS SECTION
  //   // -------------------------------
  //   bytes += ticket.feed(1);
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.grossTotal, width: 8),
  //     PosColumn(text: formatCurrency(uiGrossTotal), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.discountText, width: 8),
  //     PosColumn(text: uiOrderDiscount != 0 ? formatCurrency(uiOrderDiscount) : formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.merchantDiscount, width: 8),
  //     PosColumn(text: uiMerchantDiscount != 0 ? "-${TextConstants.currencySymbol}${uiMerchantDiscount.abs().toStringAsFixed(2)}" : "${TextConstants.currencySymbol}0.00", width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   double wooTax = 0.0;
  //   if (_wooOrder != null) {
  //     wooTax = double.tryParse(_wooOrder!.totalTax ?? '0') ?? 0.0;
  //   } else if (_order.isNotEmpty) {
  //     wooTax = double.tryParse(_order['total_tax']?.toString() ??
  //         _order['wooTax']?.toString() ??
  //         _order['orderTax']?.toString() ?? '0') ?? 0.0;
  //   } else {
  //     wooTax = uiOrderTax;
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.taxText, width: 8),
  //     PosColumn(text: formatCurrency(wooTax), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   if (uiCashbackFee > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: TextConstants.cashbackFee, width: 8),
  //       PosColumn(text: formatCurrency(uiCashbackFee), width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.servicecharges, width: 8),
  //     PosColumn(text: formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12),
  //   ]);
  //
  //   bytes += ticket.feed(1);
  //
  //   double printNetPayable = uiNetPayable;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.netPayable, width: 8),
  //     PosColumn(text: formatCurrency(printNetPayable), width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
  //   ]);
  //
  //   if (uiRedeemedValue > 0) {
  //     bytes += ticket.row([
  //       PosColumn(text: "Redeemed Amount", width: 8),
  //       PosColumn(text: "-${formatCurrency(uiRedeemedValue).replaceAll('-', '')}", width: 4, styles: PosStyles(align: PosAlign.right)),
  //     ]);
  //   }
  //
  //   // Payment split
  //   double printPayByCash = payByCash;
  //   double printPayByEbt = ebtAmount;
  //   double printPayByOther = payByOther;
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByCash, width: 8),
  //     PosColumn(text: formatCurrency(printPayByCash), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "Pay by EBT", width: 8),
  //     PosColumn(text: formatCurrency(printPayByEbt), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.payByOther, width: 8),
  //     PosColumn(text: formatCurrency(printPayByOther), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.tenderAmount, width: 8),
  //     PosColumn(text: formatCurrency(tenderAmount), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   final double effectiveTender = tenderAmount.clamp(0.0, double.infinity);
  //   double printChange = (effectiveTender - printNetPayable).clamp(0.0, double.infinity);
  //   if (balanceAmount > 0) {
  //     printChange = 0.0;
  //   }
  //
  //   bytes += ticket.row([
  //     PosColumn(text: TextConstants.change, width: 8),
  //     PosColumn(text: formatCurrency(printChange), width: 4, styles: PosStyles(align: PosAlign.right)),
  //   ]);
  //
  //   bytes += ticket.row([
  //     PosColumn(text: "-----------------------------------------------", width: 12)
  //   ]);
  //
  //   if (footer != "") {
  //     bytes += ticket.feed(1);
  //     bytes += ticket.row([
  //       PosColumn(text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
  //     ]);
  //   }
  // }



  Future _preparePrintTicket() async {
    if (kDebugMode) {
      print("OrderScreenPanel _preparePrintTicket call print receipt");
    }

    await loadPrinterData();
    var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
    var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
    var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";

    bytes = [];
    final ticket = await _printerSettings.getTicket();

    // -------------------------------
    // LOGO
    // -------------------------------
    final ByteData data;
    if (logo != "") {
      data = await GlobalUtility.fileToByteData(File(logo)) ??
          await rootBundle.load('assets/Bubbas_logo.png');
    } else {
      data = await rootBundle.load('assets/Bubbas_logo.png');
    }

    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes)!;
      img.Image thumbnail = img.copyResize(decodedImage, height: 280);
      img.Image originalImg = img.copyResize(decodedImage, width: 470, height: 280);
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;
      drawImage(originalImg, thumbnail, dstX: padding.toInt());
      var grayscaleImage = img.grayscale(originalImg);
      // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
    }

    // -------------------------------
    // STORE DETAILS - FIXED
    // -------------------------------
    final storeDetails = await AssetDBHelper.instance.getStoreDetails();

    final storeName = storeDetails?.name ?? "Store Name";

    // ✅ FIX: Only build address if it has content
    String address = "";
    if (storeDetails?.address != null && storeDetails!.address!.isNotEmpty) {
      address = "${storeDetails.address},";
    }

    // ✅ FIX: Build cityStateZip only with non-empty values - NO COMMA OR DASH IF EMPTY
    String city = storeDetails?.city?.isNotEmpty == true ? storeDetails!.city! : "";
    String state = storeDetails?.state?.isNotEmpty == true ? storeDetails!.state! : "";
    String zip = storeDetails?.zipCode?.isNotEmpty == true ? storeDetails!.zipCode! : "";

    List<String> locationParts = [];
    if (city.isNotEmpty) locationParts.add(city);
    if (state.isNotEmpty) locationParts.add(state);
    if (zip.isNotEmpty) locationParts.add(zip);

    String cityStateZip = locationParts.isNotEmpty ? locationParts.join(", ") : "";

    // ✅ FIX: Get phone number properly
    String storePhone = storeDetails?.phoneNumber?.isNotEmpty == true
        ? storeDetails!.phoneNumber!
        : "";

    final merchant = await StoreDbHelper.instance.getStoreValidationData();

    // ✅ FIX: Get store ID properly
    String storeId = "";
    if (merchant != null && merchant[AppDBConst.storeId] != null) {
      final id = merchant[AppDBConst.storeId].toString();
      if (id.isNotEmpty && id != "null") {
        storeId = id;
      }
    }

    // If storeId is empty, try to get from storeDetails
    if (storeId.isEmpty && storeDetails != null) {
      final id = storeDetails!.name?.toString() ?? "";
      if (id.isNotEmpty && id != "null" && id != "N/A") {
        storeId = id;
      }
    }

    // ✅ FIX: If phone is empty, try merchant as fallback
    if (storePhone.isEmpty && merchant != null && merchant[AppDBConst.storePhone] != null) {
      final phone = merchant[AppDBConst.storePhone].toString();
      if (phone.isNotEmpty && phone != "null") {
        storePhone = phone;
      }
    }

    final userData = await UserDbHelper().getUserData();

    final cashierName = "${userData?[AppDBConst.userDisplayName] ?? 'Cashier'}";
    final cashierRole = "${userData?[AppDBConst.userRole] ?? 'Staff'}";

    final orderIdToPrint = '${widget.activeOrderId ?? 'N/A'}';

    // Date & Time
    String dateToPrint = "";
    String timeToPrint = "";

    final DateTime? bestDateTime = _getBestDateTime();

    if (bestDateTime != null) {
      dateToPrint = DateFormat(TextConstants.dateFormat).format(bestDateTime);
      timeToPrint = DateFormat('hh:mm a').format(bestDateTime);
    } else if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
      try {
        final created = DateTime.parse(_order[AppDBConst.orderDate].toString());
        dateToPrint = DateFormat(TextConstants.dateFormat).format(created);
        timeToPrint = DateFormat('hh:mm a').format(created);
      } catch (e) {
        if (kDebugMode) print("Date parse error: $e");
        dateToPrint = "";
        timeToPrint = "";
      }
    } else {
      dateToPrint = "";
      timeToPrint = "";
    }

    // -------------------------------
    // HEADER
    // -------------------------------
    if (header.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center))
      ]);
    }

    bytes += ticket.row([
      PosColumn(
        text: "***** INVOICE COPY *****",
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

    bytes += ticket.feed(1);

    // ✅ FIX: Only print address if it has content
    if (address.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
      ]);
    }

    // ✅ FIX: Only print cityStateZip if it has content
    if (cityStateZip.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
      ]);
    }

    // ✅ FIX: Only print phone if it has content
    if (storePhone.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(
            text: "Phone: $storePhone",
            width: 12,
            styles: PosStyles(align: PosAlign.center)),
      ]);
    }

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // ✅ FIX: Only print Date if it has content
    if (dateToPrint.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: "Date: $dateToPrint", width: 7),
        PosColumn(text: "Time: ${timeToPrint.isNotEmpty ? timeToPrint : ''}", width: 5),
      ]);
    } else if (timeToPrint.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: "Time: $timeToPrint", width: 12),
      ]);
    }

    // ✅ FIX: Only print StoreID if it has content
    if (storeId.isNotEmpty) {
      bytes += ticket.row([
        PosColumn(text: "Cashier: $cashierName", width: 7),
        PosColumn(text: "StoreID: $storeId", width: 5),
      ]);
    } else {
      bytes += ticket.row([
        PosColumn(text: "Cashier: $cashierName", width: 12),
      ]);
    }

    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7),
      PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // -------------------------------
    // ITEM HEADER
    // -------------------------------
    bytes += ticket.row([
      PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
      PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
      PosColumn(text: "Qty", width: 2, styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: "Amt", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += ticket.feed(1);

    String formatCurrency(double amount) {
      if (amount < 0) {
        return "-${TextConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}";
      } else {
        return "${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}";
      }
    }

    // Helper to check if item is weighted
    bool isWeightedItem(Map<dynamic, dynamic> item) {
      final bool flag = item['is_weighted'] == true ||
          item['is_weighted'] == 1 ||
          item['item_type'] == 'weighted';

      if (!flag) {
        final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
        if (wq != null) {
          final double w = wq is num ? wq.toDouble() : double.tryParse(wq.toString()) ?? 0.0;
          if (w > 0) return true;
        }
      }
      return flag;
    }

    // Helper to get weight quantity
    double getWeightQty(Map<dynamic, dynamic> item) {
      final dynamic wq = item['weight_qty'] ?? item['weightQty'] ?? item['weight'];
      if (wq is num) return wq.toDouble();
      return double.tryParse(wq?.toString() ?? '0') ?? 0.0;
    }

    // Helper to get unit price for weighted items
    double getWeightUnitPrice(Map<dynamic, dynamic> item) {
      final dynamic up = item['unit_price'];
      if (up is num) return up.toDouble();
      return double.tryParse(up?.toString() ?? '0') ?? 0.0;
    }

    double _printItemDouble(Map<dynamic, dynamic> m, List<dynamic> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0.0;
      }
      return 0.0;
    }

    int _printItemInt(Map<dynamic, dynamic> m, List<dynamic> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    }

    String _printItemName(Map<dynamic, dynamic> m) {
      final a = m['item_name']?.toString();
      if (a != null && a.isNotEmpty) return a;
      final b = m[AppDBConst.itemName]?.toString();
      return b ?? '';
    }

    // Helper to wrap long item names into multiple lines (max 18 chars per line)
    List<String> wrapItemName(String name, int maxLength) {
      List<String> lines = [];
      String remaining = name;

      while (remaining.isNotEmpty) {
        if (remaining.length <= maxLength) {
          lines.add(remaining);
          break;
        } else {
          // Find a good break point (space) within the maxLength
          int breakIndex = remaining.lastIndexOf(' ', maxLength);
          if (breakIndex == -1) {
            // No space found, force break at maxLength
            breakIndex = maxLength;
          }
          lines.add(remaining.substring(0, breakIndex));
          remaining = remaining.substring(breakIndex).trim();
        }
      }
      return lines;
    }

    // ITEMS LOOP - WITH WEIGHTED ITEM SUPPORT AND NAME WRAPPING
    int printLineNo = 0;
    for (int i = 0; i < orderItems.length; i++) {
      final Map<dynamic, dynamic> item = orderItems[i];

      String itemName = _printItemName(item);

      // Check if this is a weighted item
      final bool isWeighted = isWeightedItem(item);

      double unitPrice = 0.0;
      double displayQty = 0.0;
      String qtyDisplay = "";

      if (isWeighted) {
        // WEIGHTED ITEM: Use weight_qty and unit_price
        unitPrice = getWeightUnitPrice(item);
        if (unitPrice == 0) {
          unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
        }

        displayQty = getWeightQty(item);
        if (displayQty == 0) {
          displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
          if (displayQty <= 0) displayQty = 1.0;
        }

        // NO SPACE between number and "lb"
        qtyDisplay = "${displayQty.toStringAsFixed(2)}lb";
      } else {
        // REGULAR ITEM
        unitPrice = _printItemDouble(item, ['item_price', AppDBConst.itemPrice]);
        displayQty = _printItemDouble(item, ['items_count', AppDBConst.itemCount]);
        if (displayQty <= 0) displayQty = 1.0;
        qtyDisplay = displayQty.toInt().toString();
      }

      double lineTotal = _printItemDouble(item, ['item_sum_price', AppDBConst.itemSumPrice]);

      String type = (item['item_type'] ?? item[AppDBConst.itemType] ?? '')
          .toString()
          .toLowerCase();

      // Skip non-product lines
      if (itemName.toLowerCase().contains("discount") ||
          itemName.toLowerCase().contains("coupon") ||
          itemName.toLowerCase().contains("loyalty") ||
          itemName.toLowerCase().contains("redeemed") ||
          itemName.toLowerCase().contains("points") ||
          type.contains("discount") ||
          type.contains("coupon") ||
          type.contains("loyalty") ||
          type.contains("points")) {
        continue;
      }

      bool isPayout = type.contains(TextConstants.payoutText);
      bool isCoupon = type.contains(TextConstants.couponText);
      bool isCashback = type.contains("cashback");
      bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;

      // For weighted items, recalculate line total if needed
      if (isWeighted && unitPrice > 0 && displayQty > 0) {
        lineTotal = unitPrice * displayQty;
      }

      String discountType = (item['discount_type'] ?? item['discountType'] ?? '').toString().toLowerCase();

      final double autoRaw = _printItemDouble(item, ['auto_discount', AppDBConst.autoDiscountTotal]);
      final double comboRaw = _printItemDouble(item, ['combo_discount_total', AppDBConst.comboDiscountTotal]);
      final double multipackRaw = _printItemDouble(item, ['multipack_discount_total', AppDBConst.multipackDiscount]);
      final double mixRaw = _printItemDouble(item, ['mixmatch_discount_total']);

      double autoDiscount = (discountType.isEmpty || discountType == 'auto') ? autoRaw : 0.0;
      double multipackDiscount = (discountType == 'multipack') ? (autoRaw > 0 ? autoRaw : multipackRaw) : 0.0;
      double comboDiscount = (discountType == 'combo' || discountType == 'mixmatch')
          ? (autoRaw > 0 ? autoRaw : (comboRaw > 0 ? comboRaw : mixRaw))
          : 0.0;

      if (discountType.isEmpty && autoDiscount == 0 && multipackDiscount == 0 && comboDiscount == 0) {
        autoDiscount = autoRaw;
        if (autoDiscount == 0) {
          multipackDiscount = multipackRaw;
          comboDiscount = comboRaw > 0 ? comboRaw : mixRaw;
        }
      }

      // Apply discounts to line total
      if (!isPayoutOrCoupon) {
        final double totalLineDiscount = autoDiscount + comboDiscount + multipackDiscount;
        if (totalLineDiscount > 0) {
          lineTotal = lineTotal - totalLineDiscount;
        }
      }

      // Wrap long item names
      List<String> nameLines = wrapItemName(itemName, 18); // Max 18 chars per line

      printLineNo++;

      // Print first line with all details
      bytes += ticket.row([
        PosColumn(text: "$printLineNo", width: 1),
        PosColumn(text: nameLines[0], width: 5),
        PosColumn(text: qtyDisplay, width: 2, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: formatCurrency(unitPrice), width: 2, styles: PosStyles(align: PosAlign.right)),
        PosColumn(text: formatCurrency(lineTotal), width: 2, styles: PosStyles(align: PosAlign.right)),
      ]);

      // Print additional name lines (if any) with indentation
      for (int j = 1; j < nameLines.length; j++) {
        bytes += ticket.row([
          PosColumn(text: "", width: 1),           // Empty # column
          PosColumn(text: "  ${nameLines[j]}", width: 5), // Indented description
          PosColumn(text: "", width: 2),           // Empty qty
          PosColumn(text: "", width: 2),           // Empty rate
          PosColumn(text: "", width: 2),           // Empty amount
        ]);
      }


      // Print discounts
      if (autoDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Auto Discount", width: 9),
          PosColumn(text: "-${formatCurrency(autoDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      if (comboDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Combo Discount", width: 9),
          PosColumn(text: "-${formatCurrency(comboDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      if (multipackDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "  Multipack Discount", width: 9),
          PosColumn(text: "-${formatCurrency(multipackDiscount).replaceAll('-', '')}", width: 3, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += ticket.emptyLines(1);
    }

    // -------------------------------
    // TOTALS SECTION
    // -------------------------------
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    // Gross Total (always printed)
    bytes += ticket.row([
      PosColumn(text: TextConstants.grossTotal, width: 8),
      PosColumn(text: formatCurrency(uiGrossTotal), width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);

    // Order Discount — only if non-zero
    if (uiOrderDiscount != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.discountText, width: 8),
        PosColumn(text: formatCurrency(uiOrderDiscount), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Merchant Discount — only if non-zero
    if (uiMerchantDiscount != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.merchantDiscount, width: 8),
        PosColumn(text: "-${TextConstants.currencySymbol}${uiMerchantDiscount.abs().toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    double wooTax = 0.0;
    if (_wooOrder != null) {
      wooTax = double.tryParse(_wooOrder!.totalTax ?? '0') ?? 0.0;
    } else if (_order.isNotEmpty) {
      wooTax = double.tryParse(_order['total_tax']?.toString() ??
          _order['wooTax']?.toString() ??
          _order['orderTax']?.toString() ?? '0') ?? 0.0;
    } else {
      wooTax = uiOrderTax;
    }

    // Tax — only if non-zero
    if (wooTax != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.taxText, width: 8),
        PosColumn(text: formatCurrency(wooTax), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    if (uiCashbackFee > 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.cashbackFee, width: 8),
        PosColumn(text: formatCurrency(uiCashbackFee), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Service Charges — only if non-zero
    if (0.0 != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.servicecharges, width: 8),
        PosColumn(text: formatCurrency(0.0), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    double printNetPayable = uiNetPayable;

    bytes += ticket.row([
      PosColumn(text: TextConstants.netPayable, width: 8),
      PosColumn(text: formatCurrency(printNetPayable), width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    if (uiRedeemedValue > 0) {
      bytes += ticket.row([
        PosColumn(text: "Redeemed Amount", width: 8),
        PosColumn(text: "-${formatCurrency(uiRedeemedValue).replaceAll('-', '')}", width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Payment split
    double printPayByCash = payByCash;
    double printPayByEbt = ebtAmount;
    double printPayByOther = payByOther;

    // Pay by Cash — only if non-zero
    if (printPayByCash != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.payByCash, width: 8),
        PosColumn(text: formatCurrency(printPayByCash), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Pay by EBT — only if non-zero
    if (printPayByEbt != 0) {
      bytes += ticket.row([
        PosColumn(text: "Pay by EBT", width: 8),
        PosColumn(text: formatCurrency(printPayByEbt), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Pay by Other — only if non-zero
    if (printPayByOther != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.payByOther, width: 8),
        PosColumn(text: formatCurrency(printPayByOther), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Tender Amount — only if non-zero
    if (tenderAmount != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.tenderAmount, width: 8),
        PosColumn(text: formatCurrency(tenderAmount), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    final double effectiveTender = tenderAmount.clamp(0.0, double.infinity);
    double printChange = (effectiveTender - printNetPayable).clamp(0.0, double.infinity);
    if (balanceAmount > 0) {
      printChange = 0.0;
    }

    // Change — only if non-zero
    if (printChange != 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.change, width: 8),
        PosColumn(text: formatCurrency(printChange), width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12)
    ]);

    if (footer != "") {
      bytes += ticket.feed(1);
      bytes += ticket.row([
        PosColumn(text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
    }
  }


/////

  Future _printTicket() async {
    final ticket = await _printerSettings.getTicket();
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

  void _handleError(String message,
      {bool isPayout = false,
        bool isCoupon = false,
        bool isCustomItem = false}) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = false);
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  //Build #1.0.67
  Future<void> _handleLocalDelete(
      Map<String, dynamic> orderItem, BuildContext context) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = false);
    await orderHelper.deleteItem(orderItem[AppDBConst.itemId]);
    await fetchOrderItems();
    widget.refreshOrderList?.call();
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(TextConstants.itemRemoved),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
