// import 'cart_item.dart';

// class CartState {
//   final String sessionId;
//   final int sequence;
//   final String screen; // IDLE | CART | PAYMENT | SUCCESS | REFUND | WELCOME | THANK_YOU
//   final List<CartItem> items;
//   final double tax;
//   final String? message;
//
//   final int? orderId;
//   final double subtotalOverride;
//   final double orderDiscount;
//   final double merchantDiscount;
//   final double cashbackFee;
//   final double netPayable;
//   final int totalItems;
//
//   final String? orderDate;
//   final String? orderTime;
//   final bool summaryEnabled;
//
//   // Store branding + banners
//   final String? storeId;
//   final String? storeName;
//   final String? storeLogoUrl;
//   final String? storeBaseUrl;
//   final List<String> slideshowUrls;
//
//   CartState({
//     required this.sessionId,
//     required this.sequence,
//     required this.screen,
//     this.items = const [],
//     this.tax = 0,
//     this.message,
//     this.orderId,
//     this.subtotalOverride = 0,
//     this.orderDiscount = 0,
//     this.merchantDiscount = 0,
//     this.cashbackFee = 0,
//     this.netPayable = 0,
//     this.totalItems = 0,
//     this.orderDate,
//     this.orderTime,
//     this.summaryEnabled = false,
//     this.storeId,
//     this.storeName,
//     this.storeLogoUrl,
//     this.storeBaseUrl,
//     this.slideshowUrls = const [],
//   });
//
//   double get subtotal =>
//       subtotalOverride > 0
//           ? subtotalOverride
//           : items.fold(0.0, (sum, i) => sum + i.total);
//
//   double get discount =>
//       items.fold(0.0, (sum, i) => sum + i.discount) +
//           orderDiscount +
//           merchantDiscount;
//
//   double get total =>
//       netPayable > 0
//           ? netPayable
//           : (subtotal + tax + cashbackFee - orderDiscount - merchantDiscount);
//
//   Map<String, dynamic> toJson() {
//     final resolvedOrderId = orderId ??
//         (sessionId.startsWith('ORDER-')
//             ? int.tryParse(sessionId.replaceFirst('ORDER-', ''))
//             : null);
//
//     final computedSubtotal = subtotal;
//     final computedNetTotal =
//         computedSubtotal - orderDiscount - merchantDiscount;
//     final computedTotal = netPayable > 0
//         ? netPayable
//         : (computedNetTotal + tax + cashbackFee);
//
//     return {
//       'schemaVersion': 2,
//       'sequence': sequence,
//       'screen': screen,
//
//       'order_id': resolvedOrderId?.toString() ?? '',
//       'orderId': resolvedOrderId?.toString() ?? '',
//       'sessionId': sessionId,
//
//       'items': items.map((i) => i.toJson()).toList(),
//
//       'subtotal': _r2(computedSubtotal),
//       'grossTotal': _r2(computedSubtotal),
//       'discount': _r2(orderDiscount),
//       'orderDiscount': _r2(orderDiscount),
//       'merchantDiscount': _r2(merchantDiscount),
//       'tax': _r2(tax),
//       'cashbackFee': _r2(cashbackFee),
//       'netTotal': _r2(computedNetTotal),
//       'total': _r2(computedTotal),
//       'netPayable': _r2(computedTotal),
//
//       'totalItems': totalItems > 0
//           ? totalItems
//           : items.fold(0, (s, i) => s + i.qty),
//
//       if (message != null) 'message': message,
//       if (orderDate != null && orderDate!.isNotEmpty) 'orderDate': orderDate,
//       if (orderTime != null && orderTime!.isNotEmpty) 'orderTime': orderTime,
//       'summaryEnabled': summaryEnabled,
//
//       // Store + banners
//       if (storeId != null && storeId!.isNotEmpty) 'storeId': storeId,
//       if (storeName != null && storeName!.isNotEmpty) 'storeName': storeName,
//       if (storeLogoUrl != null && storeLogoUrl!.isNotEmpty)
//         'storeLogoUrl': storeLogoUrl,
//       if (storeBaseUrl != null && storeBaseUrl!.isNotEmpty)
//         'storeBaseUrl': storeBaseUrl,
//       if (slideshowUrls.isNotEmpty) 'slideshowUrls': slideshowUrls,
//     };
//   }
//
//   static double _r2(double v) => double.parse(v.toStringAsFixed(2));
// }



import 'cart_item.dart';

class CartState {
  final String sessionId;
  final int sequence;
  final String screen; // IDLE | CART | PAYMENT | SUCCESS | REFUND | WELCOME | THANK_YOU
  final List<CartItem> items;
  final double tax;
  final String? message;

  final int? orderId;
  final double subtotalOverride;
  final double orderDiscount;
  final double merchantDiscount;
  final double cashbackFee;
  final double netPayable;
  final int totalItems;

  final String? orderDate;
  final String? orderTime;
  final bool summaryEnabled;

  // Store branding + banners
  final String? storeId;
  final String? storeName;
  final String? storeLogoUrl;
  final String? storeBaseUrl;
  final List<String> slideshowUrls;

  // ── NEW FIELDS ──
  final String loyaltyContact;
  final int availablePoints;

  CartState({
    required this.sessionId,
    required this.sequence,
    required this.screen,
    this.items = const [],
    this.tax = 0,
    this.message,
    this.orderId,
    this.subtotalOverride = 0,
    this.orderDiscount = 0,
    this.merchantDiscount = 0,
    this.cashbackFee = 0,
    this.netPayable = 0,
    this.totalItems = 0,
    this.orderDate,
    this.orderTime,
    this.summaryEnabled = false,
    this.storeId,
    this.storeName,
    this.storeLogoUrl,
    this.storeBaseUrl,
    this.slideshowUrls = const [],
    // ── NEW PARAMETERS (defaults) ──
    this.loyaltyContact = '',
    this.availablePoints = 0,
  });

  double get subtotal =>
      subtotalOverride > 0
          ? subtotalOverride
          : items.fold(0.0, (sum, i) => sum + i.total);

  double get discount =>
      items.fold(0.0, (sum, i) => sum + i.discount) +
          orderDiscount +
          merchantDiscount;

  double get total =>
      netPayable > 0
          ? netPayable
          : (subtotal + tax + cashbackFee - orderDiscount - merchantDiscount);

  Map<String, dynamic> toJson() {
    final resolvedOrderId = orderId ??
        (sessionId.startsWith('ORDER-')
            ? int.tryParse(sessionId.replaceFirst('ORDER-', ''))
            : null);

    final computedSubtotal = subtotal;
    final computedNetTotal =
        computedSubtotal - orderDiscount - merchantDiscount;
    final computedTotal = netPayable > 0
        ? netPayable
        : (computedNetTotal + tax + cashbackFee);

    return {
      'schemaVersion': 2,
      'sequence': sequence,
      'screen': screen,

      'order_id': resolvedOrderId?.toString() ?? '',
      'orderId': resolvedOrderId?.toString() ?? '',
      'sessionId': sessionId,

      'items': items.map((i) => i.toJson()).toList(),

      'subtotal': _r2(computedSubtotal),
      'grossTotal': _r2(computedSubtotal),
      'discount': _r2(orderDiscount),
      'orderDiscount': _r2(orderDiscount),
      'merchantDiscount': _r2(merchantDiscount),
      'tax': _r2(tax),
      'cashbackFee': _r2(cashbackFee),
      'netTotal': _r2(computedNetTotal),
      'total': _r2(computedTotal),
      'netPayable': _r2(computedTotal),

      'totalItems': totalItems > 0
          ? totalItems
          : items.fold(0, (s, i) => s + i.qty),

      if (message != null) 'message': message,
      if (orderDate != null && orderDate!.isNotEmpty) 'orderDate': orderDate,
      if (orderTime != null && orderTime!.isNotEmpty) 'orderTime': orderTime,
      'summaryEnabled': summaryEnabled,

      // Store + banners
      if (storeId != null && storeId!.isNotEmpty) 'storeId': storeId,
      if (storeName != null && storeName!.isNotEmpty) 'storeName': storeName,
      if (storeLogoUrl != null && storeLogoUrl!.isNotEmpty)
        'storeLogoUrl': storeLogoUrl,
      if (storeBaseUrl != null && storeBaseUrl!.isNotEmpty)
        'storeBaseUrl': storeBaseUrl,
      if (slideshowUrls.isNotEmpty) 'slideshowUrls': slideshowUrls,

      // ── NEW FIELDS ──
      'loyaltyContact': loyaltyContact,
      'availablePoints': availablePoints,
    };
  }

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
}