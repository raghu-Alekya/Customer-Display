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
  });

  factory CompletedOrder.fromJson(Map<String, dynamic> json) {
    return CompletedOrder(
      orderId: json['order_id'],
      status: json['status'],
      completedAt: DateTime.parse(json['date_completed']),
      paymentMethod: json['payment_method'],
      orderType: json['order_type'],

      transactionId: json['transaction_id']?.toString() ?? '',

      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount_total']?.toString() ?? '0') ?? 0,
      tax: double.tryParse(json['items_tax']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,

      author: int.tryParse(json['author']?.toString() ?? '0') ?? 0,

      items: (json['line_items'] as List? ?? [])
          .map((e) => LineItem.fromJson(e))
          .toList(),

      coupons: (json['coupon_lines'] as List? ?? [])
          .map((e) => CouponModel.fromJson(e))
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
      id: json['id'],
      name: json['name'],
      productId: json['product_id'],
      quantity: json['quantity'],
      total: double.parse(json['total']),
      image: json['image']?['src'] ?? '',
      totalTax: double.tryParse(json['total_tax']?.toString() ?? '0') ?? 0.0,
      isItemsHasDiscount: json['is_items_has_discount'] ?? "No",
      itemDiscountType: json['item_discount_type'] ?? "",
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
      code: json['code'],
      discount: double.parse(json['discount']),
    );
  }
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