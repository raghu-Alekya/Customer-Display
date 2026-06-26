// import 'line_item_model.dart';
// import 'coupon_model.dart';

class CompletedOrder {
  final int orderId;
  final String status;
  final DateTime completedAt;
  final String paymentMethod;
  final String orderType;

  final String transactionId;
  final double amount;
  final double discount;
  final double tax;
  final double total;

  final int? author;
  final List<LineItem> items;
  final List<CouponModel> coupons;
  final List<Payment> payments;

  CompletedOrder({
    required this.orderId,
    required this.status,
    required this.completedAt,
    required this.paymentMethod,
    required this.orderType,
    required this.transactionId,
    required this.amount,
    required this.discount,
    required this.tax,
    required this.total,
    this.author,
    required this.items,
    required this.coupons,
    required this.payments,
  });

  factory CompletedOrder.fromJson(Map<String, dynamic> json) {
    return CompletedOrder(
      orderId: _parseInt(json['order_id']) ?? 0,
      status: json['status']?.toString() ?? '',
      completedAt: DateTime.tryParse(json['date_completed']?.toString() ?? '') ?? DateTime.now(),
      paymentMethod: json['payment_method']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',

      transactionId: json['transaction_id']?.toString() ?? '',

      amount: _parseDouble(json['amount']) ?? 0.0,
      discount: _parseDouble(json['discount']) ?? 0.0,
      tax: _parseDouble(json['items_tax']) ?? 0.0,
      total: _parseDouble(json['total']) ?? 0.0,

      author: _parseInt(json['author']),

      items: (json['line_items'] as List? ?? [])
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),

      coupons: (json['coupon_lines'] as List? ?? [])
          .map((e) => CouponModel.fromJson(e as Map<String, dynamic>))
          .toList(),

      payments: (json['payments'] as List? ?? [])
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LineItem {
  final int id;
  final String name;
  final int productId;
  final int quantity;
  final double total;
  final String image;
  final double totalTax;
  final String isItemsHasDiscount;
  final String itemDiscountType;

  LineItem({
    required this.id,
    required this.name,
    required this.productId,
    required this.quantity,
    required this.total,
    required this.image,
    required this.totalTax,
    required this.isItemsHasDiscount,
    required this.itemDiscountType,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      productId: _parseInt(json['product_id']) ?? 0,
      quantity: _parseInt(json['quantity']) ?? 0,
      total: _parseDouble(json['total']) ?? 0.0,
      image: json['image']?['src']?.toString() ?? '',
      totalTax: _parseDouble(json['total_tax']) ?? 0.0,
      isItemsHasDiscount: json['is_items_has_discount']?.toString() ?? "No",
      itemDiscountType: json['item_discount_type']?.toString() ?? "",
    );
  }
}

class CouponModel {
  final String code;
  final double discount;

  CouponModel({
    required this.code,
    required this.discount,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: json['code']?.toString() ?? '',
      discount: _parseDouble(json['discount']) ?? 0.0,
    );
  }
}

class Payment {
  final int id;
  final String orderId;
  final String paymentMethod;
  final String paymentId;
  final double paymentAmount;

  Payment({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentId,
    required this.paymentAmount,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: _parseInt(json['id']) ?? 0,
      orderId: json['order_id']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentId: json['payment_id']?.toString() ?? '',
      paymentAmount: _parseDouble(json['payment_amount']) ?? 0.0,
    );
  }
}

// Helper functions (add these at the bottom of the file)
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class RefundItem {
  final int orderItemId;
  final double orderItemAmount;

  RefundItem({
    required this.orderItemId,
    required this.orderItemAmount,
  });

  Map<String, dynamic> toJson() => {
    "order_item_id": orderItemId,
    "order_item_amount": orderItemAmount,
  };
}

class RefundRequestModel {
  final int orderId;
  final String refundType; // "Full" or "Partial"
  final List<RefundItem>? items;

  RefundRequestModel({
    required this.orderId,
    required this.refundType,
    this.items,
  });

  Map<String, dynamic> toJson() {
    final data = {
      "order_id": orderId,
      "refund_type": refundType,
    };

    if (refundType == "Partial" && items != null) {
      data["items"] = items!.map((e) => e.toJson()).toList();
    }

    return data;
  }
}