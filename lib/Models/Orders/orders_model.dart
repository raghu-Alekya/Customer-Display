// models/order/order_models.dart
class OrderMetaData {  //Build 1.1.36: Updated
  final int? id; //Build #1.0.234: Made nullable to handle cases where id might not be present
  final String key;
  final String value;

  static const String posDeviceId = "pos_device_id";
  static const String posPlacedBy = "pos_placed_by";
  static const String shiftId     = "shift_id"; //Build #1.0.78: added shift id to order meta data

  // {
  // "id": 3962,
  // "key": "age_restricted",
  // "value": "18"
  // },

  OrderMetaData({this.id, required this.key, required this.value});

  Map<String, dynamic> toJson() => { //Build #1.0.234: updated model
    if (id != null) 'id': id,
    'key': key,
    'value': value,
  };

  factory OrderMetaData.fromJson(Map<String, dynamic> json) => OrderMetaData(
    id: json['id'] as int?,
    key: json['key'] ?? '',
    value: json['value']?.toString() ?? '',
  );
}

class Billing {
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final String? email;
  final String? phone;

  Billing({
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    if (firstName != null) 'first_name': firstName,
    if (lastName != null) 'last_name': lastName,
    if (company != null) 'company': company,
    if (address1 != null) 'address_1': address1,
    if (address2 != null) 'address_2': address2,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (postcode != null) 'postcode': postcode,
    if (country != null) 'country': country,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
  };

  factory Billing.fromJson(Map<String, dynamic> json) => Billing(
    firstName: json['first_name'],
    lastName: json['last_name'],
    company: json['company'],
    address1: json['address_1'],
    address2: json['address_2'],
    city: json['city'],
    state: json['state'],
    postcode: json['postcode'],
    country: json['country'],
    email: json['email'],
    phone: json['phone'],
  );
}

class Shipping {
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final String? phone;

  Shipping({
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    if (firstName != null) 'first_name': firstName,
    if (lastName != null) 'last_name': lastName,
    if (company != null) 'company': company,
    if (address1 != null) 'address_1': address1,
    if (address2 != null) 'address_2': address2,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (postcode != null) 'postcode': postcode,
    if (country != null) 'country': country,
    if (phone != null) 'phone': phone,
  };

  factory Shipping.fromJson(Map<String, dynamic> json) => Shipping(
    firstName: json['first_name'],
    lastName: json['last_name'],
    company: json['company'],
    address1: json['address_1'],
    address2: json['address_2'],
    city: json['city'],
    state: json['state'],
    postcode: json['postcode'],
    country: json['country'],
    phone: json['phone'],
  );
}

class OrderLineItem {
  final int? id;
  final int? productId;
  final int? variationId;
  final int quantity;
  final String? sku; // Build #1.0.80
  final List<OrderMetaData>? metaData;

  OrderLineItem({
    this.id,
    this.productId,
    this.variationId,
    this.sku,
    required this.quantity,
    this.metaData,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'quantity': quantity,
    // Only include productId if explicitly provided and not null
    if (productId != null) 'product_id': productId,
    if (sku != null) 'sku': sku,
    // Only include variationId if explicitly provided and not null
    if (variationId != null) 'variation_id': variationId,
    // Only include metaData if explicitly provided and not null
    if (metaData != null && metaData!.isNotEmpty)
      'meta_data': metaData!.map((e) => e.toJson()).toList(),
  };
}

class OrderLineItemResponse {
  final int id;
  final String name;
  final int productId;
  final int variationId;
  final int quantity;
  final String taxClass;
  final String subtotal;
  final String subtotalTax;
  final String total;
  final String totalTax;
  final List<OrderMetaData> metaData;
  final String sku;
  final double price; // Use double to handle both int and double
  final Map<String, dynamic> image;

  OrderLineItemResponse({
    required this.id,
    required this.name,
    required this.productId,
    required this.variationId,
    required this.quantity,
    required this.taxClass,
    required this.subtotal,
    required this.subtotalTax,
    required this.total,
    required this.totalTax,
    required this.metaData,
    required this.sku,
    required this.price,
    required this.image,
  });

  factory OrderLineItemResponse.fromJson(Map<String, dynamic> json) =>
      OrderLineItemResponse(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        productId: json['product_id'] ?? 0,
        variationId: json['variation_id'] ?? 0,
        quantity: json['quantity'] ?? 0,
        taxClass: json['tax_class'] ?? '',
        subtotal: json['subtotal'] ?? '0.00',
        subtotalTax: json['subtotal_tax'] ?? '0.00',
        total: json['total'] ?? '0.00',
        totalTax: json['total_tax'] ?? '0.00',
        metaData: (json['meta_data'] as List<dynamic>?)
            ?.map((e) => OrderMetaData.fromJson(e))
            .toList() ??
            [],
        sku: json['sku'] ?? '',
        price: (json['price'] is int
            ? (json['price'] as int).toDouble() // Convert int to double
            : json['price'] ?? 0.0), // Use double directly or default to 0.0
        image: json['image'] ?? {'id': '0', 'src': ''},
      );
}

class ShippingLine {
  final int? id;
  final String? methodId;
  final String? methodTitle;
  final String? total;

  ShippingLine({
    this.id,
    this.methodId,
    this.methodTitle,
    this.total,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (methodId != null) 'method_id': methodId,
    if (methodTitle != null) 'method_title': methodTitle,
    if (total != null) 'total': total,
  };

  factory ShippingLine.fromJson(Map<String, dynamic> json) => ShippingLine(
    id: json['id'],
    methodId: json['method_id'],
    methodTitle: json['method_title'],
    total: json['total'],
  );
}

class FeeLine {
  final int? id;
  final String? name;
  final String? taxClass;
  final String? taxStatus;
  final String? total;
  final String? originalValue; // Build #1.0.53

  FeeLine({
    this.id,
    this.name,
    this.taxClass,
    this.taxStatus,
    this.total,
    this.originalValue,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name, // Build #1.0.92: updated because while deleting payout, discount pass name as null
    if (taxClass != null) 'tax_class': taxClass,
    if (taxStatus != null) 'tax_status': taxStatus,
    if (total != null) 'total': total,
    if (originalValue != null) 'original_value': originalValue,
  };

  factory FeeLine.fromJson(Map<String, dynamic> json) => FeeLine(
    id: json['id'],
    name: json['name'],
    taxClass: json['tax_class'],
    taxStatus: json['tax_status'],
    total: json['total'],
    originalValue: json['original_value'],
  );
}

class TaxLine {
  final int? id;
  final String? rateCode;
  final int? rateId;
  final String? label;
  final bool? compound;
  final String? taxTotal;
  final String? shippingTaxTotal;

  TaxLine({
    this.id,
    this.rateCode,
    this.rateId,
    this.label,
    this.compound,
    this.taxTotal,
    this.shippingTaxTotal,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (rateCode != null) 'rate_code': rateCode,
    if (rateId != null) 'rate_id': rateId,
    if (label != null) 'label': label,
    if (compound != null) 'compound': compound,
    if (taxTotal != null) 'tax_total': taxTotal,
    if (shippingTaxTotal != null) 'shipping_tax_total': shippingTaxTotal,
  };

  factory TaxLine.fromJson(Map<String, dynamic> json) => TaxLine(
    id: json['id'],
    rateCode: json['rate_code'],
    rateId: json['rate_id'],
    label: json['label'],
    compound: json['compound'],
    taxTotal: json['tax_total'],
    shippingTaxTotal: json['shipping_tax_total'],
  );
}

class CouponLine {
  final int? id;
  final String code;
  final String? discount;
  final String? discountTax;
  final List<OrderMetaData>? metaData;
  final String? discountType;
  final num? nominalAmount; // Keep as num? to handle int or double from API
  final bool? freeShipping;
  final bool? remove; // Added for remove coupon

  CouponLine({
    this.id,
    required this.code,
    this.discount,
    this.discountTax,
    this.metaData,
    this.discountType,
    this.nominalAmount,
    this.freeShipping,
    this.remove,
  });

  factory CouponLine.fromJson(Map<String, dynamic> json) => CouponLine(
    id: json['id'],
    code: json['code'] ?? '',
    discount: json['discount'],
    discountTax: json['discount_tax'],
    metaData: (json['meta_data'] as List<dynamic>?)
        ?.map((e) => OrderMetaData.fromJson(e))
        .toList(),
    discountType: json['discount_type'], // Build #1.0.64
    nominalAmount: json['nominal_amount'], // Keep as num? for flexibility
    freeShipping: json['free_shipping'],
    remove: json['remove'],
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'code': code,
    if (discount != null) 'discount': discount,
    if (discountTax != null) 'discount_tax': discountTax,
    if (metaData != null)
      'meta_data': metaData!.map((e) => e.toJson()).toList(),
    if (discountType != null) 'discount_type': discountType,
    if (nominalAmount != null) 'nominal_amount': nominalAmount,
    if (freeShipping != null) 'free_shipping': freeShipping,
    if (remove != null) 'remove': remove,
  };
}

// Create Order Models
class CreateOrderRequestModel {
  final String? status;
  final String? currency;
  final Billing? billing;
  final Shipping? shipping;
  final List<OrderMetaData>? metaData;
  final List<FeeLine>? feeLines;
  final List<OrderLineItem>? lineItems;
  final List<TaxLine>? taxLines;
  final List<ShippingLine>? shippingLines;

  CreateOrderRequestModel({
    this.status = 'processing',
    this.currency,
    this.billing,
    this.shipping,
    this.metaData = const [],
    this.feeLines = const [],
    this.lineItems = const [],
    this.taxLines = const [],
    this.shippingLines = const [],
  });

  Map<String, dynamic> toJson() => {
    if (status != null) 'status': status,
    if (currency != null) 'currency': currency,
    if (billing != null) 'billing': billing!.toJson(),
    if (shipping != null) 'shipping': shipping!.toJson(),
    if (metaData != null)
      'meta_data': metaData!.map((e) => e.toJson()).toList(),
    if (feeLines != null)
      'fee_lines': feeLines!.map((e) => e.toJson()).toList(),
    if (lineItems != null)
      'line_items': lineItems!.map((e) => e.toJson()).toList(),
    if (taxLines != null)
      'tax_lines': taxLines!.map((e) => e.toJson()).toList(),
    if (shippingLines != null)
      'shipping_lines': shippingLines!.map((e) => e.toJson()).toList(),
  };
}

class CreateOrderResponseModel {
  final int id;
  final int parentId;
  final String status;
  final String currency;
  final String discountTotal;
  final String total;
  final Billing? billing;
  final Shipping? shipping;
  final List<OrderMetaData> metaData;
  final List<OrderLineItemResponse> lineItems;
  final List<TaxLine> taxLines;
  final List<ShippingLine> shippingLines;
  final List<FeeLine> feeLines;
  final List<CouponLine> couponLines;

  CreateOrderResponseModel({
    required this.id,
    required this.parentId,
    required this.status,
    required this.currency,
    required this.discountTotal,
    required this.total,
    this.billing,
    this.shipping,
    required this.metaData,
    required this.lineItems,
    required this.taxLines,
    required this.shippingLines,
    required this.feeLines,
    required this.couponLines,
  });

  factory CreateOrderResponseModel.fromJson(Map<String, dynamic> json) =>
      CreateOrderResponseModel(
        id: json['id'] ?? 0,
        parentId: json['parent_id'] ?? 0,
        status: json['status'] ?? '',
        currency: json['currency'] ?? '',
        discountTotal: json['discount_total'] ?? '0.00',
        total: json['total'] ?? '0.00',
        billing: json['billing'] != null ? Billing.fromJson(json['billing']) : null,
        shipping: json['shipping'] != null ? Shipping.fromJson(json['shipping']) : null,
        metaData: (json['meta_data'] as List<dynamic>?)
            ?.map((e) => OrderMetaData.fromJson(e))
            .toList() ??
            [],
        lineItems: (json['line_items'] as List<dynamic>?)
            ?.map((e) => OrderLineItemResponse.fromJson(e))
            .toList() ??
            [],
        taxLines: (json['tax_lines'] as List<dynamic>?)
            ?.map((e) => TaxLine.fromJson(e))
            .toList() ??
            [],
        shippingLines: (json['shipping_lines'] as List<dynamic>?)
            ?.map((e) => ShippingLine.fromJson(e))
            .toList() ??
            [],
        feeLines: (json['fee_lines'] as List<dynamic>?)
            ?.map((e) => FeeLine.fromJson(e))
            .toList() ??
            [],
        couponLines: (json['coupon_lines'] as List<dynamic>?)
            ?.map((e) => CouponLine.fromJson(e))
            .toList() ??
            [],
      );
}

class OrderStatusRequest {  // Build #1.0.49: Added Update order status request code
  final String status;

  OrderStatusRequest({required this.status});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
    };
  }
}

// Update Order Models
class UpdateOrderRequestModel {
  final List<OrderLineItem> lineItems;
  final List<CouponLine>? couponLines;

  UpdateOrderRequestModel({
    required this.lineItems,
    this.couponLines = const [],
  });

  Map<String, dynamic> toJson() => {
    'line_items': lineItems.map((e) => e.toJson()).toList(),
    if (couponLines != null && couponLines!.isNotEmpty)  //Build #1.0.68
      'coupon_lines': couponLines!.map((e) => e.toJson()).toList(),
  };
}

class UpdateOrderResponseModel {
  final int id;
  final int parentId;
  final String status;
  final String currency;
  final String discountTotal;
  final String total;
  final String totalTax;
  final Billing? billing;
  final Shipping? shipping;
  final List<OrderMetaData> metaData;
  final List<OrderLineItemResponse> lineItems;
  final List<TaxLine> taxLines;
  final List<ShippingLine> shippingLines;
  final List<FeeLine> feeLines;
  final List<CouponLine> couponLines;

  UpdateOrderResponseModel({
    required this.id,
    required this.parentId,
    required this.status,
    required this.currency,
    required this.discountTotal,
    required this.total,
    required this.totalTax,
    this.billing,
    this.shipping,
    required this.metaData,
    required this.lineItems,
    required this.taxLines,
    required this.shippingLines,
    required this.feeLines,
    required this.couponLines,
  });

  factory UpdateOrderResponseModel.fromJson(Map<String, dynamic> json) =>
      UpdateOrderResponseModel(
        id: json['id'] ?? 0,
        parentId: json['parent_id'] ?? 0,
        status: json['status'] ?? '',
        currency: json['currency'] ?? '',
        discountTotal: json['discount_total'] ?? '0.00',
        total: json['total'] ?? '0.00',
        totalTax: json['total_tax'] ?? '0.00',
        billing: json['billing'] != null ? Billing.fromJson(json['billing']) : null,
        shipping: json['shipping'] != null ? Shipping.fromJson(json['shipping']) : null,
        metaData: (json['meta_data'] as List<dynamic>?)
            ?.map((e) => OrderMetaData.fromJson(e))
            .toList() ??
            [],
        lineItems: (json['line_items'] as List<dynamic>?)
            ?.map((e) => OrderLineItemResponse.fromJson(e))
            .toList() ??
            [],
        taxLines: (json['tax_lines'] as List<dynamic>?)
            ?.map((e) => TaxLine.fromJson(e))
            .toList() ??
            [],
        shippingLines: (json['shipping_lines'] as List<dynamic>?)
            ?.map((e) => ShippingLine.fromJson(e))
            .toList() ??
            [],
        feeLines: (json['fee_lines'] as List<dynamic>?)
            ?.map((e) => FeeLine.fromJson(e))
            .toList() ??
            [],
        couponLines: (json['coupon_lines'] as List<dynamic>?)
            ?.map((e) => CouponLine.fromJson(e))
            .toList() ??
            [],
      );
}

// Apply Coupon Models
class ApplyCouponRequestModel {
  final List<CouponLine> couponLines;

  ApplyCouponRequestModel({required this.couponLines});

  Map<String, dynamic> toJson() => {
    'coupon_lines': couponLines.map((e) => e.toJson()).toList(),
  };
}

class AddPayoutRequestModel { // Build #1.0.53 : Added
  final List<FeeLine> feeLines;

  AddPayoutRequestModel({required this.feeLines});

  Map<String, dynamic> toJson() => {
    'fee_lines': feeLines.map((e) => e.toJson()).toList(),
  };
}

class AddPayoutAsProductRequestModel {
  // Build #1.0.198 : Added

  final int? orderId;
  final double amount;

  AddPayoutAsProductRequestModel({required this.orderId, required this.amount});

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
    };
  }
}

class AddMerchantDiscountRequestModel { // Build #1.0.274: Added for merchant discount api raw body data.
  final int orderId;
  final double amount;

  AddMerchantDiscountRequestModel({required this.orderId, required this.amount});

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'amount': amount,
  };
}

class RemoveFeeLinesRequestModel { // Build #1.0.53 : Added; Build #1.0.73: updated
  final List<FeeLine> feeLines;

  RemoveFeeLinesRequestModel({required this.feeLines});

  Map<String, dynamic> toJson() => {
    'fee_lines': feeLines.map((e) => e.toJson()).toList(),
  };
}

class RemoveCouponRequestModel {// Build #1.0.64
  final List<CouponLine> couponLines;

  RemoveCouponRequestModel({required this.couponLines});

  Map<String, dynamic> toJson() => {
    'coupon_lines': couponLines.map((e) => e.toJson()).toList(),
  };
}