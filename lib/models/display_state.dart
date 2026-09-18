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
  final double autoDiscount;
  final double comboDiscount;
  final double multipackDiscount;
  final double mixAndMatchDiscount;
  final double merchantDiscount;
  final String? discountType;
  final double itemDiscount;

  DisplayItem._({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.total,
    required this.itemType,
    required this.weightQty,
    required this.sku,
    required this.isEbtEligible,
    required this.autoDiscount,
    required this.comboDiscount,
    required this.multipackDiscount,
    required this.mixAndMatchDiscount,
    required this.merchantDiscount,
    required this.discountType,
    required this.itemDiscount,
  });

  factory DisplayItem.fromJson(Map<String, dynamic> j) {
    final productId = (j['productId'] ?? j['product_id'] ?? '').toString();
    final name = (j['name'] ?? j['item_name'] ?? '').toString();
    final qty = _toInt(j['qty'] ?? j['quantity'] ?? j['items_count']);
    final unitPrice = _toDouble(
      j['unitPrice'] ?? j['unit_price'] ?? j['price'] ?? j['item_price'],
    );
    final total = _toDouble(
      j['total'] ?? j['item_sum_price'] ?? j['lineTotal'] ?? j['item_price'],
    );
    final itemType = (j['itemType'] ?? j['item_type'] ?? 'product').toString();
    final weightQty = _toDouble(
      j['weightQty'] ?? j['weight_qty'] ?? j['weight'],
    );
    final sku = j['sku']?.toString();
    final isEbtEligible = j['isEbtEligible'] == true ||
        j['is_ebt_eligible'] == true ||
        j['is_ebt_eligible'] == 1 ||
        j['is_ebt_eligible'] == '1' ||
        j['isEbs'] == true ||
        j['is_ebs'] == true ||
        j['is_ebs_eligible'] == true ||
        j['is_ebs_eligible'] == 1 ||
        j['is_ebs_eligible'] == '1';

    final rawAuto = _toDouble(
      j['autoDiscount'] ?? j['auto_discount'] ?? j['auto_discount_total'] ?? j['autoDiscountTotal'] ?? j['autodiscount'] ?? j['auto_discount_amount'],
    );
    final rawCombo = _toDouble(
      j['comboDiscount'] ?? j['combo_discount'] ?? j['combo_discount_total'] ?? j['comboDiscountTotal'] ?? j['combo_amount'] ?? j['combo'] ?? j['combo_discount_amount'],
    );
    final rawMulti = _toDouble(
      j['multipackDiscount'] ?? j['multipack_discount'] ?? j['multipack_discount_total'] ?? j['multipackDiscountTotal'] ?? j['multipack_amount'] ?? j['multipack'] ?? j['multi_pack_discount'] ?? j['multiPackDiscount'] ?? j['multipack_discount_amount'],
    );
    final rawMix = _toDouble(
      j['mixAndMatchDiscount'] ?? j['mix_and_match'] ?? j['mix_match_discount'] ?? j['mix_match'] ?? j['mix_discount'],
    );
    final rawMerchant = _toDouble(
      j['merchantDiscount'] ?? j['merchant_discount'] ?? j['merchant_discount_total'] ?? j['merchantDiscountTotal'] ?? j['merchant_amount'] ?? j['merchant_discount_amount'],
    );
    final discountType = _readStringOrNull(
      j['discountType'] ?? j['discount_type'] ?? j['discount_source'] ?? j['discountSource'] ?? j['discount_title'] ?? j['discountTitle'] ?? j['discount_name'] ?? j['discountName'] ?? j['discount_label'] ?? j['discountLabel'] ?? j['discount_text'] ?? j['discountText'] ?? j['subtitle'] ?? j['sub_title'],
    );
    final itemDiscount = _toDouble(
      j['itemDiscount'] ?? j['item_discount'] ?? j['discount'] ?? j['discount_amount'] ?? j['discountAmount'] ?? j['unit_discount'],
    );

    double autoDiscount = rawAuto;
    double comboDiscount = rawCombo;
    double multipackDiscount = rawMulti;
    double mixAndMatchDiscount = rawMix;
    double merchantDiscount = rawMerchant;

    final dTypeLower = (discountType ?? '').toLowerCase();
    final itemTypeLower = itemType.toLowerCase();
    final nameLower = name.toLowerCase();

    if (multipackDiscount == 0 && (dTypeLower.contains('multi') || dTypeLower.contains('pack') || itemTypeLower.contains('multi') || itemTypeLower.contains('pack') || nameLower.contains('multi') || nameLower.contains('pack'))) {
      multipackDiscount = itemDiscount > 0 ? itemDiscount : 0.0;
    } else if (comboDiscount == 0 && (dTypeLower.contains('combo') || itemTypeLower.contains('combo') || nameLower.contains('combo'))) {
      comboDiscount = itemDiscount > 0 ? itemDiscount : 0.0;
    } else if (mixAndMatchDiscount == 0 && (dTypeLower.contains('mix') || itemTypeLower.contains('mix') || nameLower.contains('mix'))) {
      mixAndMatchDiscount = itemDiscount > 0 ? itemDiscount : 0.0;
    } else if (merchantDiscount == 0 && (dTypeLower.contains('merchant') || itemTypeLower.contains('merchant') || nameLower.contains('merchant'))) {
      merchantDiscount = itemDiscount > 0 ? itemDiscount : 0.0;
    } else if (autoDiscount == 0 && (dTypeLower.contains('auto') || itemTypeLower.contains('auto') || nameLower.contains('auto'))) {
      autoDiscount = itemDiscount > 0 ? itemDiscount : 0.0;
    } else if (itemDiscount > 0 && autoDiscount == 0 && comboDiscount == 0 && multipackDiscount == 0 && mixAndMatchDiscount == 0 && merchantDiscount == 0) {
      autoDiscount = itemDiscount;
    }

    return DisplayItem._(
      productId: productId,
      name: name,
      qty: qty,
      unitPrice: unitPrice,
      total: total,
      itemType: itemType,
      weightQty: weightQty,
      sku: sku,
      isEbtEligible: isEbtEligible,
      autoDiscount: autoDiscount,
      comboDiscount: comboDiscount,
      multipackDiscount: multipackDiscount,
      mixAndMatchDiscount: mixAndMatchDiscount,
      merchantDiscount: merchantDiscount,
      discountType: discountType,
      itemDiscount: itemDiscount,
    );
  }

  String? get activeDiscountLabel {
    if (multipackDiscount > 0) return discountType ?? 'Multi Pack Discount';
    if (comboDiscount > 0) return discountType ?? 'Combo Discount';
    if (mixAndMatchDiscount > 0) return discountType ?? 'Mix & Match Discount';
    if (autoDiscount > 0) return discountType ?? 'Auto Discount';
    if (merchantDiscount > 0) return discountType ?? 'Merchant Discount';
    if (itemDiscount > 0) return discountType ?? 'Discount';
    return null;
  }

  double get activeDiscountAmount {
    if (multipackDiscount > 0) return multipackDiscount;
    if (comboDiscount > 0) return comboDiscount;
    if (mixAndMatchDiscount > 0) return mixAndMatchDiscount;
    if (autoDiscount > 0) return autoDiscount;
    if (merchantDiscount > 0) return merchantDiscount;
    if (itemDiscount > 0) return itemDiscount;
    return 0.0;
  }

  bool get isDiscountLine {
    final typeLower = itemType.toLowerCase().trim();
    final nameLower = name.toLowerCase().trim();

    if (typeLower.contains('discount') ||
        typeLower.contains('coupon') ||
        typeLower == 'merchant_discount' ||
        typeLower == 'auto_discount' ||
        typeLower == 'combo_discount' ||
        typeLower == 'multipack_discount' ||
        typeLower == 'mix_match_discount') {
      return true;
    }

    final isNegative = total < 0 || unitPrice < 0;
    if (isNegative &&
        (nameLower.contains('discount') ||
            nameLower.contains('coupon') ||
            nameLower.contains('combo') ||
            nameLower.contains('auto') ||
            nameLower.contains('merchant'))) {
      return true;
    }

    if (nameLower == 'discount' ||
        nameLower == 'coupon' ||
        nameLower == 'auto discount' ||
        nameLower == 'merchant discount' ||
        nameLower == 'combo discount' ||
        nameLower == 'order discount' ||
        nameLower == 'multipack discount' ||
        nameLower == 'mix & match discount' ||
        nameLower == 'mix and match discount') {
      return true;
    }

    return false;
  }

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

  static String? _readStringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}

class DisplayState {
  final int sequence;
  final String screen;
  final String orderId;
  final List<DisplayItem> items;

  final double subtotal;
  final double discount;
  final double autoDiscount;
  final double merchantDiscount;
  final double comboDiscount;
  final double multipackDiscount;
  final double mixAndMatchDiscount;
  final double couponDiscount;

  final double tax;
  final double total;
  final String? message;

  final double netTotal;
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
      : this._internal(
          j: j,
          items: _readItems(j),
        );

  DisplayState._internal({
    required Map<String, dynamic> j,
    required this.items,
  })  : sequence = DisplayItem._toInt(j['sequence']),
        screen = (j['screen'] ?? 'IDLE').toString(),
        orderId = _readOrderId(j),
        subtotal = DisplayItem._toDouble(j['subtotal'] ?? j['grossTotal']),
        tax = DisplayItem._toDouble(j['tax']),
        total = DisplayItem._toDouble(j['total'] ?? j['netPayable']),
        message = j['message']?.toString(),
        netTotal = DisplayItem._toDouble(j['netTotal']),
        cashbackFee = DisplayItem._toDouble(j['cashbackFee'] ?? j['cashback_fee']),
        redeemedAmount = DisplayItem._toDouble(j['redeemedAmount'] ?? j['redeemed_amount']),
        orderDate = (j['orderDate'] ?? '').toString(),
        orderTime = (j['orderTime'] ?? '').toString(),
        storeId = (j['storeId'] ?? j['store_id'] ?? '').toString(),
        storeName = (j['storeName'] ?? j['store_name'] ?? '').toString(),
        storeLogoUrl = _readStringOrNull(
          j['storeLogoUrl'] ??
              j['store_logo_url'] ??
              j['storeLogo'] ??
              j['store_logo'] ??
              j['logo'] ??
              j['logo_url'] ??
              j['logoUrl'] ??
              j['shop_logo'] ??
              j['shopLogo'] ??
              j['merchant_logo'] ??
              j['merchantLogo'] ??
              j['site_logo'] ??
              j['siteLogo'] ??
              j['header_logo'] ??
              j['headerLogo'],
        ),
        storeBaseUrl = (j['storeBaseUrl'] ?? j['store_base_url'] ?? j['baseUrl'] ?? j['base_url'] ?? '').toString(),
        slideshowUrls = _readStringList(
          j['slideshowUrls'] ??
              j['slideshow_urls'] ??
              j['banners'] ??
              j['banner_urls'] ??
              j['bannerUrls'] ??
              j['storeBanners'] ??
              j['store_banners'] ??
              j['customer_display_banners'] ??
              j['customerDisplayBanners'] ??
              j['cfd_banners'] ??
              j['cfdBanners'] ??
              j['slides'],
        ),
        loyaltyContact = (j['loyaltyContact'] ?? '').toString(),
        availablePoints = DisplayItem._toInt(j['availablePoints']),
        summaryEnabled = j['summaryEnabled'] as bool? ?? false,
        phoneInputUnlocked = j['phoneInputUnlocked'] as bool? ?? false,
        autoDiscount = _readDiscount(j, items, 'auto'),
        merchantDiscount = _readDiscount(j, items, 'merchant'),
        comboDiscount = _readDiscount(j, items, 'combo'),
        multipackDiscount = _readDiscount(j, items, 'multipack'),
        mixAndMatchDiscount = _readDiscount(j, items, 'mix'),
        couponDiscount = _readDiscount(j, items, 'coupon'),
        discount = _readDiscount(j, items, 'general');

  static double _readDiscount(
      Map<String, dynamic> j, List<DisplayItem> items, String type) {
    switch (type) {
      case 'auto':
        final val = DisplayItem._toDouble(
          j['autoDiscount'] ?? j['auto_discount'] ?? j['auto_discount_total'] ?? j['autoDiscountTotal'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('auto') || t.contains('auto')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          } else {
            sum += i.autoDiscount;
          }
        }
        return sum;

      case 'merchant':
        final val = DisplayItem._toDouble(
          j['merchantDiscount'] ?? j['merchant_discount'] ?? j['merchant_discount_total'] ?? j['merchantDiscountTotal'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('merchant') || t.contains('merchant')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          } else {
            sum += i.merchantDiscount;
          }
        }
        return sum;

      case 'combo':
        final val = DisplayItem._toDouble(
          j['comboDiscount'] ?? j['combo_discount'] ?? j['combo_discount_total'] ?? j['comboDiscountTotal'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('combo') || t.contains('combo')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          } else {
            sum += i.comboDiscount;
          }
        }
        return sum;

      case 'multipack':
        final val = DisplayItem._toDouble(
          j['multipackDiscount'] ?? j['multipack_discount'] ?? j['multipack_discount_total'] ?? j['multipackDiscountTotal'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('multipack') || t.contains('multipack')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          } else {
            sum += i.multipackDiscount;
          }
        }
        return sum;

      case 'mix':
        final val = DisplayItem._toDouble(
          j['mixAndMatchDiscount'] ?? j['mix_and_match'] ?? j['mix_match_discount'] ?? j['mix_match'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('mix') || t.contains('mix')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          } else {
            sum += i.mixAndMatchDiscount;
          }
        }
        return sum;

      case 'coupon':
        final val = DisplayItem._toDouble(
          j['couponDiscount'] ?? j['coupon_discount'] ?? j['coupon_discount_total'] ?? j['coupon'] ?? j['coupons'] ?? j['couponAmount'] ?? j['coupon_amount'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (n.contains('coupon') || t.contains('coupon')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          }
        }
        return sum;

      case 'general':
      default:
        final val = DisplayItem._toDouble(
          j['discount'] ?? j['orderDiscount'] ?? j['order_discount'],
        );
        if (val > 0) return val;
        double sum = 0.0;
        for (final i in items) {
          if (i.isDiscountLine) {
            final n = i.name.toLowerCase();
            final t = i.itemType.toLowerCase();
            if (!n.contains('auto') &&
                !t.contains('auto') &&
                !n.contains('merchant') &&
                !t.contains('merchant') &&
                !n.contains('combo') &&
                !t.contains('combo') &&
                !n.contains('multipack') &&
                !t.contains('multipack') &&
                !n.contains('mix') &&
                !t.contains('mix') &&
                !n.contains('coupon') &&
                !t.contains('coupon')) {
              sum += i.total.abs() > 0 ? i.total.abs() : i.unitPrice.abs();
            }
          }
        }
        return sum;
    }
  }

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
      'autoDiscount': 0,
      'merchantDiscount': 0,
      'comboDiscount': 0,
      'multipackDiscount': 0,
      'mixAndMatchDiscount': 0,
      'couponDiscount': 0,
      'tax': 0,
      'total': 0,
      'netTotal': 0,
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
      'orderDate':
          orderDate.isNotEmpty ? orderDate : previous.orderDate,
      'orderTime':
          orderTime.isNotEmpty ? orderTime : previous.orderTime,
    });
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  DisplayState copyWith({
    int? sequence,
    String? screen,
    String? orderId,
    List<DisplayItem>? items,
    double? subtotal,
    double? discount,
    double? autoDiscount,
    double? merchantDiscount,
    double? comboDiscount,
    double? multipackDiscount,
    double? mixAndMatchDiscount,
    double? couponDiscount,
    double? tax,
    double? total,
    String? message,
    double? netTotal,
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
      if (items != null)
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
                  'autoDiscount': i.autoDiscount,
                  'comboDiscount': i.comboDiscount,
                  'multipackDiscount': i.multipackDiscount,
                  'mixAndMatchDiscount': i.mixAndMatchDiscount,
                  'merchantDiscount': i.merchantDiscount,
                  'discountType': i.discountType,
                  'itemDiscount': i.itemDiscount,
                })
            .toList(),
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (autoDiscount != null) 'autoDiscount': autoDiscount,
      if (merchantDiscount != null) 'merchantDiscount': merchantDiscount,
      if (comboDiscount != null) 'comboDiscount': comboDiscount,
      if (multipackDiscount != null) 'multipackDiscount': multipackDiscount,
      if (mixAndMatchDiscount != null)
        'mixAndMatchDiscount': mixAndMatchDiscount,
      if (couponDiscount != null) 'couponDiscount': couponDiscount,
      if (tax != null) 'tax': tax,
      if (total != null) 'total': total,
      if (message != null) 'message': message,
      if (netTotal != null) 'netTotal': netTotal,
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
                'autoDiscount': i.autoDiscount,
                'comboDiscount': i.comboDiscount,
                'multipackDiscount': i.multipackDiscount,
                'mixAndMatchDiscount': i.mixAndMatchDiscount,
                'merchantDiscount': i.merchantDiscount,
                'discountType': i.discountType,
                'itemDiscount': i.itemDiscount,
              })
          .toList(),
      'subtotal': subtotal,
      'discount': discount,
      'autoDiscount': autoDiscount,
      'merchantDiscount': merchantDiscount,
      'comboDiscount': comboDiscount,
      'multipackDiscount': multipackDiscount,
      'mixAndMatchDiscount': mixAndMatchDiscount,
      'couponDiscount': couponDiscount,
      'tax': tax,
      'total': total,
      'message': message,
      'netTotal': netTotal,
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