class CartItem {
  final String productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double discount;
  final double autoDiscount;
  final double comboDiscount;
  final double multipackDiscount;
  final double mixmatchDiscount;
  final String? discountType;
  final String? sku;
  final String? itemType;
  final String? image;
  final double weightQty;
  final double itemTax;
  final int loyaltyPoints;
  final int? variationId;
  final bool isEbtEligible;
  final double lineTotal;

  CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.discount = 0,
    this.autoDiscount = 0,
    this.comboDiscount = 0,
    this.multipackDiscount = 0,
    this.mixmatchDiscount = 0,
    this.discountType,
    this.sku,
    this.itemType,
    this.image,
    this.weightQty = 0,
    this.itemTax = 0,
    this.loyaltyPoints = 0,
    this.variationId,
    this.isEbtEligible = false,
    double? lineTotal,
  }) : lineTotal = lineTotal ?? ((unitPrice * qty) - discount);

  double get total => lineTotal;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'product_id': productId,
    'name': name,
    'item_name': name,
    'qty': qty,
    'quantity': qty,
    'items_count': qty,
    'unitPrice': unitPrice,
    'unit_price': unitPrice,
    'price': unitPrice,
    'discount': discount,
    'auto_discount': autoDiscount,
    'autoDiscount': autoDiscount,
    'combo_discount': comboDiscount,
    'comboDiscount': comboDiscount,
    'multipack_discount': multipackDiscount,
    'multipackDiscount': multipackDiscount,
    'mixmatch_discount': mixmatchDiscount,
    'mixmatchDiscount': mixmatchDiscount,
    if (discountType != null) 'discount_type': discountType,
    if (discountType != null) 'discountType': discountType,
    'total': total,
    'lineTotal': total,
    'item_sum_price': total,
    if (sku != null) 'sku': sku,
    if (itemType != null) 'itemType': itemType,
    if (itemType != null) 'item_type': itemType,
    if (image != null) 'image': image,
    if (weightQty > 0) 'weightQty': weightQty,
    if (weightQty > 0) 'weight_qty': weightQty,
    if (itemTax > 0) 'itemTax': itemTax,
    if (loyaltyPoints > 0) 'loyaltyPoints': loyaltyPoints,
    if (variationId != null) 'variationId': variationId,
    'isEbtEligible': isEbtEligible,
    'is_ebt_eligible': isEbtEligible,
    'ebt_eligible': isEbtEligible,
  };

  factory CartItem.fromOrderItem(Map<String, dynamic> item) {
    final String type =
    (item['item_type'] ?? item['type'] ?? 'product').toString().toLowerCase();
    final bool isWeighted = type.contains('weighted');

    final double rawPrice = isWeighted
        ? _toD(item['unit_price'] ??
        item['regular_price'] ??
        item['item_price'] ??
        item['price'] ??
        item['amount'] ??
        item['payout_amount'])
        : _toD(item['item_price'] ??
        item['price'] ??
        item['amount'] ??
        item['payout_amount']);
    final double unitPrice = rawPrice.abs();

    final int qty = _toI(item['items_count'] ?? item['quantity'] ?? 1);

    final double weightQty = isWeighted
        ? _toD(item['weight_qty'] ?? item['weightQty'] ?? item['weight'] ?? 0)
        : 0.0;

    final double posAuto = [
      _toD(item['_pos_auto_discount']),
      _toD(item['auto_discount']),
      _toD(item['autoDiscount']),
      _toD(item['auto_discount_total']),
      _toD(item['display_auto_discount']),
    ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    final double combo = [
      _toD(item['combo_discount_total']),
      _toD(item['comboDiscountTotal']),
      _toD(item['combo_discount']),
    ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    final double multipack = [
      _toD(item['multipack_discount_total']),
      _toD(item['multipackDiscountTotal']),
      _toD(item['multipack_discount']),
    ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    final double mixmatch = [
      _toD(item['mixmatch_discount_total']),
      _toD(item['mixMatchDiscountTotal']),
      _toD(item['mixmatch_discount']),
    ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    final double general = [
      _toD(item['discount']),
      _toD(item['item_discount']),
      _toD(item['manual_discount']),
    ].where((v) => v > 0).fold(0.0, (max, v) => v > max ? v : max);

    double discount = [posAuto, combo, multipack, mixmatch, general]
        .fold(0.0, (max, v) => v > max ? v : max);
    if (discount <= 0) {
      discount = posAuto + combo + multipack + mixmatch + general;
    }

    String? dType = (item['discount_type'] ?? item['discountType'])?.toString();
    if (dType != null && dType.isNotEmpty) {
      final String dtLower = dType.toLowerCase();
      if (dtLower.contains('combo')) {
        dType = 'combo';
      } else if (dtLower.contains('multi')) {
        dType = 'multipack';
      } else if (dtLower.contains('mix')) {
        dType = 'mixmatch';
      } else if (dtLower.contains('auto')) {
        dType = 'auto';
      }
    } else {
      if (combo > 0) {
        dType = 'combo';
      } else if (multipack > 0) {
        dType = 'multipack';
      } else if (mixmatch > 0) {
        dType = 'mixmatch';
      } else if (posAuto > 0) {
        dType = 'auto';
      }
    }

    final double lineTotal = isWeighted && weightQty > 0
        ? (unitPrice * weightQty) - discount
        : (unitPrice * qty) - discount;

    final bool ebtFlag = item['is_ebt_eligible'] == true ||
        item['isEbtEligible'] == true ||
        item['ebt_eligible'] == true ||
        item['is_ebt_eligible'] == 1 ||
        item['isEbtEligible'] == 1 ||
        item['ebt_eligible'] == 1 ||
        item['is_ebt_eligible']?.toString() == '1' ||
        item['isEbtEligible']?.toString() == '1' ||
        item['ebt_eligible']?.toString() == '1' ||
        item['is_ebt_eligible']?.toString() == 'true' ||
        item['isEbtEligible']?.toString() == 'true' ||
        item['ebt_eligible']?.toString() == 'true';

    final String nameStr = (item['product_name'] ??
            item['item_name'] ??
            item['name'] ??
            item['title'] ??
            'Item')
        .toString();

    final String imgStr = (item['product_image'] ??
            item['image'] ??
            item['item_image'] ??
            '')
        .toString();

    return CartItem(
      productId: (item['payout_product_id'] ??
              item['product_id'] ??
              item['itemProductId'] ??
              item['id'] ??
              '')
          .toString(),
      name: nameStr.isNotEmpty ? nameStr : 'Item',
      qty: qty,
      unitPrice: unitPrice,
      discount: discount,
      autoDiscount: posAuto,
      comboDiscount: combo,
      multipackDiscount: multipack,
      mixmatchDiscount: mixmatch,
      discountType: dType,
      sku: (item['sku'] ?? '').toString().isEmpty
          ? null
          : item['sku']?.toString(),
      itemType: type,
      image: imgStr.isNotEmpty ? imgStr : null,
      weightQty: weightQty,
      itemTax: _toD(item['item_tax'] ?? item['tax_after_discount']),
      loyaltyPoints: _toI(item['loyalty_points'] ?? item['loyaltyPoints'] ?? 0),
      variationId: item['variation_id'] != null
          ? int.tryParse(item['variation_id'].toString())
          : null,
      isEbtEligible: ebtFlag,
      lineTotal: lineTotal,
    );
  }

  static double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toI(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}