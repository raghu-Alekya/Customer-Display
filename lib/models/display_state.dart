class DisplayItem {
  final String productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double total;
  final String itemType;
  final double weightQty;
  final String? sku;
  final bool isEbtEligible;

  DisplayItem.fromJson(Map<String, dynamic> j)
      : productId = (j['productId'] ?? j['product_id'] ?? '').toString(),
        name = (j['name'] ?? j['item_name'] ?? '').toString(),
        qty = _toInt(j['qty'] ?? j['quantity'] ?? j['items_count']),
        unitPrice = _toDouble(
          j['unitPrice'] ?? j['unit_price'] ?? j['price'] ?? j['item_price'],
        ),
        total = _toDouble(
          j['total'] ?? j['item_sum_price'] ?? j['lineTotal'] ?? j['item_price'],
        ),
        itemType = (j['itemType'] ?? j['item_type'] ?? 'product').toString(),
        weightQty = _toDouble(
          j['weightQty'] ?? j['weight_qty'] ?? j['weight'],
        ),
        sku = j['sku']?.toString(),
        isEbtEligible =
            j['isEbtEligible'] == true || j['is_ebt_eligible'] == true;

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }
}

class DisplayState {
  final int sequence;
  final String screen;
  final String orderId;
  final List<DisplayItem> items;

  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? message;

  final double netTotal;
  final double merchantDiscount;
  final double cashbackFee;
  final double redeemedAmount;

  final String orderDate;
  final String orderTime;

  final String storeId;
  final String storeName;
  final String? storeLogoUrl;
  final String storeBaseUrl;
  final List<String> slideshowUrls;

  final String loyaltyContact;
  final int availablePoints;
  final bool summaryEnabled;
  final bool phoneInputUnlocked;

  DisplayState.fromJson(Map<String, dynamic> j)
      : sequence = DisplayItem._toInt(j['sequence']),
        screen = (j['screen'] ?? 'IDLE').toString(),
        orderId = _readOrderId(j),
        items = _readItems(j),
        subtotal = DisplayItem._toDouble(j['subtotal'] ?? j['grossTotal']),
        discount = DisplayItem._toDouble(
          j['discount'] ?? j['orderDiscount'],
        ),
        tax = DisplayItem._toDouble(j['tax']),
        total = DisplayItem._toDouble(j['total'] ?? j['netPayable']),
        message = j['message']?.toString(),
        netTotal = DisplayItem._toDouble(j['netTotal']),
        merchantDiscount = DisplayItem._toDouble(j['merchantDiscount']),
        cashbackFee = DisplayItem._toDouble(j['cashbackFee']),
        redeemedAmount = DisplayItem._toDouble(j['redeemedAmount']),
        orderDate = (j['orderDate'] ?? '').toString(),
        orderTime = (j['orderTime'] ?? '').toString(),
        storeId = (j['storeId'] ?? j['store_id'] ?? '').toString(),
        storeName = (j['storeName'] ?? j['store_name'] ?? '').toString(),
        storeLogoUrl = _readStringOrNull(
          j['storeLogoUrl'] ?? j['store_logo_url'],
        ),
        storeBaseUrl =
        (j['storeBaseUrl'] ?? j['store_base_url'] ?? '').toString(),
        slideshowUrls = _readStringList(
          j['slideshowUrls'] ??
              j['slideshow_urls'] ??
              j['banners'] ??
              j['slides'],
        ),
        loyaltyContact = (j['loyaltyContact'] ?? '').toString(),
        availablePoints = DisplayItem._toInt(j['availablePoints']),
        summaryEnabled = j['summaryEnabled'] as bool? ?? false,
        phoneInputUnlocked = j['phoneInputUnlocked'] as bool? ?? false;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _readOrderId(Map<String, dynamic> j) {
    final dynamic value =
        j['order_id'] ?? j['orderId'] ?? j['orderID'] ?? j['order'];
    if (value == null) return '';
    return value.toString().trim();
  }

  static List<DisplayItem> _readItems(Map<String, dynamic> j) {
    final dynamic rawItems =
        j['items'] ?? j['cart'] ?? j['order_items'] ?? j['orderItems'];
    if (rawItems is! List) return <DisplayItem>[];
    return rawItems
        .whereType<Map>()
        .map((item) => DisplayItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static String? _readStringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Idle (fully resets order data)
  // ---------------------------------------------------------------------------

  static DisplayState idle() {
    return DisplayState.fromJson({
      'screen': 'IDLE',
      'sequence': 0,
      'order_id': '',
      'items': <Map<String, dynamic>>[],
      'subtotal': 0,
      'discount': 0,
      'tax': 0,
      'total': 0,
      'netTotal': 0,
      'merchantDiscount': 0,
      'cashbackFee': 0,
      'redeemedAmount': 0,
      'orderDate': '',
      'orderTime': '',
      'loyaltyContact': '',
      'availablePoints': 0,
      'summaryEnabled': false,
      'phoneInputUnlocked': false,
    });
  }

  // ---------------------------------------------------------------------------
  // Merge branding from previous state (keeps store info)
  // ---------------------------------------------------------------------------

  DisplayState mergeBranding(DisplayState previous) {
    return DisplayState.fromJson({
      ..._toJson(),
      // Keep previous branding when the new payload does not bring it
      'storeName':
      storeName.isNotEmpty ? storeName : previous.storeName,
      'storeLogoUrl': (storeLogoUrl != null && storeLogoUrl!.trim().isNotEmpty)
          ? storeLogoUrl
          : previous.storeLogoUrl,
      'storeBaseUrl':
      storeBaseUrl.isNotEmpty ? storeBaseUrl : previous.storeBaseUrl,
      'storeId': storeId.isNotEmpty ? storeId : previous.storeId,
      'slideshowUrls': slideshowUrls.isNotEmpty
          ? slideshowUrls
          : previous.slideshowUrls,
      // Optional – keep date/time if new state omits them
      'orderDate':
      orderDate.isNotEmpty ? orderDate : previous.orderDate,
      'orderTime':
      orderTime.isNotEmpty ? orderTime : previous.orderTime,
    });
  }

  // ---------------------------------------------------------------------------
  // copyWith (used by loyalty / phone unlock)
  // ---------------------------------------------------------------------------

  DisplayState copyWith({
    int? sequence,
    String? screen,
    String? orderId,
    List<DisplayItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? message,
    double? netTotal,
    double? merchantDiscount,
    double? cashbackFee,
    double? redeemedAmount,
    String? orderDate,
    String? orderTime,
    String? storeId,
    String? storeName,
    String? storeLogoUrl,
    String? storeBaseUrl,
    List<String>? slideshowUrls,
    String? loyaltyContact,
    int? availablePoints,
    bool? summaryEnabled,
    bool? phoneInputUnlocked,
  }) {
    return DisplayState.fromJson({
      ..._toJson(),
      if (sequence != null) 'sequence': sequence,
      if (screen != null) 'screen': screen,
      if (orderId != null) 'order_id': orderId,
      if (items != null) 'items': items.map((i) => {
        'productId': i.productId,
        'name': i.name,
        'qty': i.qty,
        'unitPrice': i.unitPrice,
        'total': i.total,
        'itemType': i.itemType,
        'weightQty': i.weightQty,
        'sku': i.sku,
        'isEbtEligible': i.isEbtEligible,
      }).toList(),
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (total != null) 'total': total,
      if (message != null) 'message': message,
      if (netTotal != null) 'netTotal': netTotal,
      if (merchantDiscount != null) 'merchantDiscount': merchantDiscount,
      if (cashbackFee != null) 'cashbackFee': cashbackFee,
      if (redeemedAmount != null) 'redeemedAmount': redeemedAmount,
      if (orderDate != null) 'orderDate': orderDate,
      if (orderTime != null) 'orderTime': orderTime,
      if (storeId != null) 'storeId': storeId,
      if (storeName != null) 'storeName': storeName,
      if (storeLogoUrl != null) 'storeLogoUrl': storeLogoUrl,
      if (storeBaseUrl != null) 'storeBaseUrl': storeBaseUrl,
      if (slideshowUrls != null) 'slideshowUrls': slideshowUrls,
      if (loyaltyContact != null) 'loyaltyContact': loyaltyContact,
      if (availablePoints != null) 'availablePoints': availablePoints,
      if (summaryEnabled != null) 'summaryEnabled': summaryEnabled,
      if (phoneInputUnlocked != null) 'phoneInputUnlocked': phoneInputUnlocked,
    });
  }

  Map<String, dynamic> _toJson() {
    return {
      'screen': screen,
      'sequence': sequence,
      'order_id': orderId,
      'orderId': orderId,
      'items': items
          .map((i) => {
        'productId': i.productId,
        'name': i.name,
        'qty': i.qty,
        'unitPrice': i.unitPrice,
        'total': i.total,
        'itemType': i.itemType,
        'weightQty': i.weightQty,
        'sku': i.sku,
        'isEbtEligible': i.isEbtEligible,
      })
          .toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'message': message,
      'netTotal': netTotal,
      'merchantDiscount': merchantDiscount,
      'cashbackFee': cashbackFee,
      'redeemedAmount': redeemedAmount,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'storeId': storeId,
      'storeName': storeName,
      'storeLogoUrl': storeLogoUrl,
      'storeBaseUrl': storeBaseUrl,
      'slideshowUrls': slideshowUrls,
      'loyaltyContact': loyaltyContact,
      'availablePoints': availablePoints,
      'summaryEnabled': summaryEnabled,
      'phoneInputUnlocked': phoneInputUnlocked,
    };
  }
}