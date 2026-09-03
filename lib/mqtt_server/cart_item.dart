class CartItem {
  final String productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double discount;
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
  };

  factory CartItem.fromOrderItem(Map<String, dynamic> item) {
    final String type =
    (item['item_type'] ?? item['type'] ?? 'product').toString().toLowerCase();
    final bool isWeighted = type.contains('weighted');

    final double unitPrice = isWeighted
        ? _toD(item['unit_price'] ??
        item['regular_price'] ??
        item['item_price'] ??
        item['price'])
        : _toD(item['item_price'] ?? item['price']);

    final int qty = _toI(item['items_count'] ?? item['quantity'] ?? 1);

    final double weightQty = isWeighted
        ? _toD(item['weight_qty'] ?? item['weightQty'] ?? item['weight'] ?? 0)
        : 0.0;

    final double discount = _toD(item['auto_discount']);
    final double lineTotal = isWeighted && weightQty > 0
        ? (unitPrice * weightQty) - discount
        : (unitPrice * qty) - discount;

    return CartItem(
      productId:
      (item['product_id'] ?? item['itemProductId'] ?? item['id'] ?? '')
          .toString(),
      name: (item['item_name'] ?? item['name'] ?? 'Item').toString(),
      qty: qty,
      unitPrice: unitPrice,
      discount: discount,
      sku: (item['sku'] ?? '').toString().isEmpty
          ? null
          : item['sku']?.toString(),
      itemType: type,
      image: (item['item_image'] ?? item['image'] ?? '').toString().isEmpty
          ? null
          : (item['item_image'] ?? item['image'])?.toString(),
      weightQty: weightQty,
      itemTax: _toD(item['item_tax'] ?? item['tax_after_discount']),
      loyaltyPoints: _toI(item['loyalty_points'] ?? item['loyaltyPoints'] ?? 0),
      variationId: item['variation_id'] != null
          ? int.tryParse(item['variation_id'].toString())
          : null,
      isEbtEligible:
      item['is_ebt_eligible'] == true || item['isEbtEligible'] == true,
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