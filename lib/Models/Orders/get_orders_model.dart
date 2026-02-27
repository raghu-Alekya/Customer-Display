import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Constants/text.dart';

class OrdersListModel {
  final List<OrderModel> orders;
  OrdersListModel({required this.orders});

  factory OrdersListModel.fromJson(List<dynamic> json) {
    return OrdersListModel(
      orders: json.map((item) => OrderModel.fromJson(item)).toList(),
    );
  }
}

class OrderModel {
  final int id;
  final int parentId;
  final String status;
  final String currency;
  final String version;
  final bool pricesIncludeTax;
  final String dateCreated;
  final String dateModified;
  final String discountTotal;
  final String discountTax;
  final String shippingTotal;
  final String shippingTax;
  final String cartTax;
  final String total;
  final String totalTax;
  final int customerId;
  final String orderKey;
  // final Billing billing;
  // final Shipping shipping;
  final List<LineItem> lineItems;
  List<FeeLine>? feeLines;
  List<CouponLine> couponLines;
  final List<MetaData> metaData;
  final String? datePaid;
  final String? dateCompleted;
  final String paymentMethod;
  final String createdVia;
  final String number;
  final String currencySymbol;

  final String? multipackDiscountTotal;
  final String? autoDiscountTotal;
  final String? getTime;
  final String? autoDiscountMeta;

  final double orderLevelAutoDiscountAmount;
  final double refundTotal;
  final double refundOrderTotal;
  final double netPayment;


  OrderModel({
    required this.id,
    required this.parentId,
    required this.status,
    required this.currency,
    required this.version,
    required this.pricesIncludeTax,
    required this.dateCreated,
    required this.dateModified,
    required this.discountTotal,
    required this.discountTax,
    required this.shippingTotal,
    required this.shippingTax,
    required this.cartTax,
    required this.total,
    required this.totalTax,
    required this.customerId,
    required this.orderKey,
    // required this.billing,
    // required this.shipping,
    required this.lineItems,
    this.feeLines,
    required this.couponLines,
    required this.metaData,
    this.datePaid,
    this.dateCompleted,
    required this.paymentMethod,
    required this.createdVia,
    required this.number,
    required this.currencySymbol,
    this.multipackDiscountTotal,
    this.autoDiscountTotal,
    this.getTime,
    this.autoDiscountMeta,
    required this.orderLevelAutoDiscountAmount,
    required this.refundTotal,
    required this.refundOrderTotal,
    required this.netPayment,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final metaList = (json['meta_data'] as List<dynamic>?)
        ?.map((e) => MetaData.fromJson(e as Map<String, dynamic>))
        .toList() ??
        <MetaData>[];

    String? getOrderMetaValue(String key) {
      try {
        return metaList
            .firstWhere(
              (m) => m.key == key,
          orElse: () => MetaData(id: 0, key: '', value: null),
        )
            .value
            ?.toString();
      } catch (e) {
        return null;
      }
    }

    final orderDiscountStr = getOrderMetaValue('_discount_amount');
    final orderLevelAutoDiscountAmount = double.tryParse(orderDiscountStr ?? '0') ?? 0.0;
    final refundTotal =
        double.tryParse(json['refund_total']?.toString() ?? '0') ?? 0.0;

    final refundOrderTotal =
        double.tryParse(json['refund_order_total']?.toString() ?? '0') ?? 0.0;

    final netPayment =
        double.tryParse(json['net_payment']?.toString() ?? '0') ?? 0.0;

    return OrderModel(
      id: json['id'] ?? 0,
      parentId: json['parent_id'] ?? 0,
      status: json['status'] ?? '',
      currency: json['currency'] ?? 'INR',
      version: json['version'] ?? '',
      pricesIncludeTax: json['prices_include_tax'] ?? false,
      dateCreated: json['date_created'] ?? '',
      dateModified: json['date_modified'] ?? '',
      discountTotal: json['discount_total'] ?? '0.00',
      discountTax: json['discount_tax'] ?? '0.00',
      shippingTotal: json['shipping_total'] ?? '0.00',
      shippingTax: json['shipping_tax'] ?? '0.00',
      cartTax: json['cart_tax'] ?? '0.00',
      total: json['total'] ?? '0.00',
      totalTax: json['total_tax'] ?? '0.00',
      customerId: json['customer_id'] ?? 0,
      orderKey: json['order_key'] ?? '',
      // billing: Billing.fromJson(json['billing'] ?? {}),
      // shipping: Shipping.fromJson(json['shipping'] ?? {}),
      lineItems: (json['line_items'] as List<dynamic>?)
          ?.map((item) => LineItem.fromJson(item))
          .toList() ??
          [],
      feeLines: (json['fee_lines'] is List)
          ? (json['fee_lines'] as List<dynamic>?)
          ?.map((e) => FeeLine.fromJson(e as Map<String, dynamic>))
          .toList()
          : (json['fee_lines'] is Map)
          ? (json['fee_lines'] as Map<String, dynamic>)
          .values
          .map((e) => FeeLine.fromJson(e as Map<String, dynamic>))
          .toList()
          : null,
      couponLines: (json['coupon_lines'] as List<dynamic>?)
          ?.map((e) => CouponLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      metaData: metaList,
      datePaid: json['date_paid'],
      dateCompleted: json['date_completed'],
      paymentMethod: json['payment_method'] ?? '',
      createdVia: json['created_via'] ?? '',
      number: json['number'] ?? '',
      currencySymbol: json['currency_symbol'] ?? TextConstants.currencySymbol,
      multipackDiscountTotal: json['multipack_discount_total'] as String?,
      autoDiscountTotal: json['auto_discount_total'] as String?,
      getTime: json['get_time'] as String?,
      autoDiscountMeta: json['auto_discount_meta'] as String?,
      orderLevelAutoDiscountAmount: orderLevelAutoDiscountAmount,
      refundTotal: refundTotal,
      refundOrderTotal: refundOrderTotal,
      netPayment: netPayment,
    );
  }

  double get totalMultipackDiscount =>
      lineItems.fold(0.0, (sum, item) => sum + item.multipackDiscountAmount);

  double get totalAutoDiscount =>
      lineItems.fold(0.0, (sum, item) => sum + item.autoDiscountAmount);

  double get totalComboDiscount =>
      lineItems.fold(0.0, (sum, item) => sum + item.comboDiscountAmount);

  double get totalDisplayAutoDiscount =>
      lineItems.fold(0.0, (sum, item) => sum + item.displayAutoDiscountAmount);

  double get totalCombinedAutoDiscount =>
      orderLevelAutoDiscountAmount + totalAutoDiscount;

  double get totalAllDiscounts {
    final discount = double.tryParse(discountTotal) ?? 0.0;

    return discount +
        totalMultipackDiscount +
        totalAutoDiscount +
        orderLevelAutoDiscountAmount +
        totalComboDiscount +
        totalDisplayAutoDiscount;
  }

  double get cashbackFee {
    if (feeLines == null || feeLines!.isEmpty) return 0.0;

    for (final fee in feeLines!) {
      final name = (fee.name ?? '').toLowerCase();

      if (name.contains('cashback')) {
        return double.tryParse(fee.total ?? '0') ?? 0.0;
      }
    }

    return 0.0;
  }

  bool get hasMultipackDiscount => totalMultipackDiscount > 0;
  bool get hasAutoDiscount => totalCombinedAutoDiscount > 0;
  bool get hasComboDiscount => totalComboDiscount > 0;
  bool get hasDisplayAutoDiscount => totalDisplayAutoDiscount > 0;
  bool get hasOrderLevelAutoDiscount => orderLevelAutoDiscountAmount > 0;
}

class FeeLine {
  int? id;
  String? name;
  String? taxClass;
  String? taxStatus;
  String? amount;
  String? total;
  String? totalTax;
  List<dynamic>? taxes;
  List<dynamic>? metaData;

  FeeLine({
    this.id,
    this.name,
    this.taxClass,
    this.taxStatus,
    this.amount,
    this.total,
    this.totalTax,
    this.taxes,
    this.metaData,
  });

  factory FeeLine.fromJson(Map<String, dynamic> json) {
    return FeeLine(
      id: json['id'] as int?,
      name: json['name'] as String?,
      taxClass: json['tax_class'] as String?,
      taxStatus: json['tax_status'] as String?,
      amount: json['amount'] as String?,
      total: json['total'] as String?,
      totalTax: json['total_tax'] as String?,
      taxes: json['taxes'] as List<dynamic>?,
      metaData: json['meta_data'] as List<dynamic>?,
    );
  }
}

class CouponLine {
  int? id;
  String? code;
  String? discount;
  String? discountTax;
  double? nominalAmount;
  String? discountType;
  bool? freeShipping;
  List<MetaData>? metaData;

  CouponLine({
    this.id,
    this.code,
    this.discount,
    this.discountTax,
    this.nominalAmount,
    this.discountType,
    this.freeShipping,
    this.metaData,
  });

  factory CouponLine.fromJson(Map<String, dynamic> json) {
    return CouponLine(
      id: json['id'] as int?,
      code: json['code'] as String?,
      discount: json['discount'] as String?,
      discountTax: json['discount_tax'] as String?,
      nominalAmount: double.tryParse(json['nominal_amount'].toString()) ?? 0.0,
      discountType: json['discount_type'] as String?,
      freeShipping: json['free_shipping'] as bool?,
      metaData: (json['meta_data'] as List<dynamic>?)
          ?.map((item) => MetaData.fromJson(item))
          .toList(),
    );
  }
}

// class Billing {
//   final String firstName;
//   final String lastName;
//   final String email;
//   final String phone;
//
//   Billing({
//     required this.firstName,
//     required this.lastName,
//     required this.email,
//     required this.phone,
//   });
//
//   factory Billing.fromJson(Map<String, dynamic> json) {
//     return Billing(
//       firstName: json['first_name'] ?? '',
//       lastName: json['last_name'] ?? '',
//       email: json['email'] ?? '',
//       phone: json['phone'] ?? '',
//     );
//   }
// }
//
// class Shipping {
//   final String firstName;
//   final String lastName;
//   final String phone;
//
//   Shipping({
//     required this.firstName,
//     required this.lastName,
//     required this.phone,
//   });
//
//   factory Shipping.fromJson(Map<String, dynamic> json) {
//     return Shipping(
//       firstName: json['first_name'] ?? '',
//       lastName: json['last_name'] ?? '',
//       phone: json['phone'] ?? '',
//     );
//   }
// }

class LineItem {
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
  final List<MetaData> metaData;
  final String? sku;
  final double price;
  final ImageData image;
  final ProductData productData;
  final ProductVariationData? productVariationData;
  final bool isRefundItem;

  // Multipack legacy fields
  final String? originalSubtotal;
  final String? multipackUnitPriceBefore;
  final String? multipackUnitPriceAfter;

  // Discount fields
  final double multipackDiscountAmount;
  final bool multipackApplied;

  final double autoDiscountAmount;
  final bool autoDiscountApplied;

  final double comboDiscountAmount; // mixmatch
  final bool comboDiscountApplied;

  final double displayAutoDiscountAmount;

  LineItem({
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
    this.sku,
    required this.price,
    required this.image,
    required this.productData,
    this.productVariationData,
    this.originalSubtotal,
    this.multipackUnitPriceBefore,
    this.multipackUnitPriceAfter,
    required this.multipackDiscountAmount,
    required this.multipackApplied,
    required this.autoDiscountAmount,
    required this.autoDiscountApplied,
    required this.comboDiscountAmount,
    required this.comboDiscountApplied,
    required this.displayAutoDiscountAmount,
    required this.isRefundItem,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    final metaList = (json['meta_data'] as List<dynamic>?)
        ?.map((e) => MetaData.fromJson(e as Map<String, dynamic>))
        .toList() ??
        <MetaData>[];

    String? getMetaValue(String key) {
      try {
        return metaList
            .firstWhere(
              (m) => m.key == key,
          orElse: () => MetaData(id: 0, key: '', value: null),
        )
            .value
            ?.toString();
      } catch (e) {
        return null;
      }
    }

    final String? posAutoDiscountStr = getMetaValue('_pos_auto_discount');
    final String? posDiscountTypeRaw = getMetaValue('_pos_discount_type');

    final double discountValue = double.tryParse(posAutoDiscountStr ?? '0.00') ?? 0.0;
    final String discountType = (posDiscountTypeRaw ?? '').trim().toLowerCase();

    double multipackDiscountAmount = 0.0;
    bool multipackApplied = false;

    double autoDiscountAmount = 0.0;
    bool autoDiscountApplied = false;

    double comboDiscountAmount = 0.0;
    bool comboDiscountApplied = false;

    if (discountValue > 0 && discountType.isNotEmpty) {
      switch (discountType) {
        case 'multipack':
          multipackDiscountAmount = discountValue;
          multipackApplied = true;
          break;
        case 'mixmatch':
          comboDiscountAmount = discountValue;
          comboDiscountApplied = true;
          break;
        case 'auto':
          autoDiscountAmount = discountValue;
          autoDiscountApplied = true;
          break;
      }
    }

    // Legacy multipack fields (kept for backward compatibility)
    final String? originalSubtotal = getMetaValue('_pinaka_multipack_original_subtotal');
    final String? multipackUnitPriceBefore =
    getMetaValue('_pinaka_multipack_unit_price_before');
    final String? multipackUnitPriceAfter =
    getMetaValue('_pinaka_multipack_unit_price_after');

    // ────────────────────────────────────────────────
    // Auto discount display logic – modern has highest priority
    // ────────────────────────────────────────────────
    double displayAutoDiscountAmount = 0.0;

    // Prefer modern auto discount when it exists
    if (autoDiscountApplied && autoDiscountAmount > 0) {
      displayAutoDiscountAmount = autoDiscountAmount;
    } else {
      // Only use legacy value if no modern auto discount
      final String? displayAutoStr = getMetaValue('auto_discount_amount') ??
          _extractDisplayMetaValue(
            metaList,
            'auto_discount_amount',
            keyToMatch: 'display_key',
          );
      displayAutoDiscountAmount = double.tryParse(displayAutoStr ?? '0') ?? 0.0;
    }
    // ────────────────────────────────────────────────

    return LineItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      productId: json['product_id'] ?? 0,
      variationId: json['variation_id'] ?? 0,
      taxClass: json['tax_class'] ?? '',
      subtotal: json['subtotal'] ?? '0.00',
      subtotalTax: json['subtotal_tax'] ?? '0.00',
      total: json['total'] ?? '0.00',
      totalTax: json['total_tax'] ?? '0.00',
      metaData: metaList,
      sku: json['sku'] as String?,
      price: (json['price'] is int
          ? (json['price'] as int).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0),
      image: ImageData.fromJson(json['image'] ?? {}),
      productData: ProductData.fromJson(json['product_data'] ?? {}),
      productVariationData: json['product_variation_data'] != null
          ? ProductVariationData.fromJson(json['product_variation_data'])
          : null,
      originalSubtotal: originalSubtotal,
      multipackUnitPriceBefore: multipackUnitPriceBefore,
      multipackUnitPriceAfter: multipackUnitPriceAfter,
      multipackDiscountAmount: multipackDiscountAmount,
      multipackApplied: multipackApplied,
      autoDiscountAmount: autoDiscountAmount,
      autoDiscountApplied: autoDiscountApplied,
      comboDiscountAmount: comboDiscountAmount,
      comboDiscountApplied: comboDiscountApplied,
      displayAutoDiscountAmount: displayAutoDiscountAmount,
      isRefundItem: json['is_refund_item'] ?? false,
    );
  }

  static String? _extractDisplayMetaValue(
      List<MetaData> metaList,
      String valueToFind, {
        String keyToMatch = 'display_key',
      }) {
    try {
      for (var meta in metaList) {
        if (meta.value is Map<String, dynamic>) {
          final valueMap = meta.value as Map<String, dynamic>;
          if (valueMap[keyToMatch]?.toString() == valueToFind) {
            return valueMap['display_value']?.toString();
          }
        }
      }
      for (var meta in metaList) {
        if (meta.value is String) {
          try {
            final parsed = jsonDecode(meta.value as String) as Map<String, dynamic>;
            if (parsed[keyToMatch]?.toString() == valueToFind) {
              return parsed['display_value']?.toString();
            }
          } catch (_) {}
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // DISPLAY PRIORITY HELPERS – Auto shows first / has highest priority
  // ────────────────────────────────────────────────────────────────

  /// Returns the discount type with highest display priority
  String? get primaryDiscountType {
    if (autoDiscountApplied && autoDiscountAmount > 0) return 'auto';
    if (comboDiscountApplied && comboDiscountAmount > 0) return 'mixmatch';
    if (multipackApplied && multipackDiscountAmount > 0) return 'multipack';
    if (displayAutoDiscountAmount > 0) return 'auto (legacy)';
    return null;
  }

  /// Returns the discount amount with highest display priority
  double get primaryDiscountAmount {
    if (autoDiscountApplied && autoDiscountAmount > 0) return autoDiscountAmount;
    if (comboDiscountApplied && comboDiscountAmount > 0) return comboDiscountAmount;
    if (multipackApplied && multipackDiscountAmount > 0) return multipackDiscountAmount;
    if (displayAutoDiscountAmount > 0) return displayAutoDiscountAmount;
    return 0.0;
  }

  bool get hasAnyDiscount =>
      multipackDiscountAmount > 0 ||
          autoDiscountAmount > 0 ||
          comboDiscountAmount > 0 ||
          displayAutoDiscountAmount > 0;

  bool get hasMultipackDiscount => multipackApplied && multipackDiscountAmount > 0;
  bool get hasAutoDiscount => autoDiscountApplied && autoDiscountAmount > 0;
  bool get hasComboDiscount => comboDiscountApplied && comboDiscountAmount > 0;
  bool get hasDisplayAutoDiscount => displayAutoDiscountAmount > 0;

  double get totalDiscountAmount =>
      multipackDiscountAmount +
          autoDiscountAmount +
          comboDiscountAmount +
          displayAutoDiscountAmount;
}

class Tag {
  final int id;
  final String name;
  final String slug;

  Tag({required this.id, required this.name, required this.slug});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class ProductData {
  final int id;
  final String name;
  final List<Tag> tags;
  final List<int>? variations;
  final String? regularPrice;
  final String? salePrice;
  final String? price;

  ProductData({
    this.regularPrice,
    this.salePrice,
    this.price,
    this.variations,
    required this.id,
    required this.name,
    required this.tags,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    return ProductData(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      tags: (json['tags'] as List<dynamic>?)
          ?.map((tag) => Tag.fromJson(tag))
          .toList() ??
          [],
      variations: (json['variations'] as List?)
          ?.map((item) => item as int)
          .toList(),
      price: json['price'] == "" ? "0" : json['price'] ?? "0",
      regularPrice: json['regular_price'] == "" ? "0" : json['regular_price'] ?? "0",
      salePrice: json['sale_price'] == "" ? "0" : json['sale_price'] ?? "0",
    );
  }
}

class ProductVariationData {
  final int id;
  final String type;
  final String sku;
  final List<MetaData>? metaData;
  final String? regularPrice;
  final String? salePrice;
  final String? price;

  ProductVariationData({
    this.regularPrice,
    this.salePrice,
    this.price,
    this.metaData,
    required this.id,
    required this.type,
    required this.sku,
  });

  factory ProductVariationData.fromJson(Map<String, dynamic> json) {
    return ProductVariationData(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      metaData: (json['meta_data'] as List<dynamic>?)
          ?.map((item) => MetaData.fromJson(item))
          .toList(),
      sku: json['sku'] ?? "",
      price: json['price'] ?? "",
      regularPrice: json['regular_price'] ?? "",
      salePrice: json['sale_price'] ?? "",
    );
  }
}

class MetaData {
  final int id;
  final String key;
  final dynamic value;

  MetaData({required this.id, required this.key, required this.value});

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
      value: json['value'],
    );
  }
}

class ImageData {
  final String id;
  final String src;

  ImageData({required this.id, required this.src});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      id: json['id']?.toString() ?? '0',
      src: json['src'] ?? '',
    );
  }
}