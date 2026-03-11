class ApplyDiscountResponse {  // Build #1.0.49
  final bool success;
  final String message;
  final String discountCode;
  final String discountAmount;
  final int orderId;

  ApplyDiscountResponse({
    required this.success,
    required this.message,
    required this.discountCode,
    required this.discountAmount,
    required this.orderId,
  });

  factory ApplyDiscountResponse.fromJson(Map<String, dynamic> json) {
    return ApplyDiscountResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      discountCode: json['discount_code'] ?? '',
      discountAmount: json['discount_amount'] ?? '',
      orderId: json['order_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'discount_code': discountCode,
      'discount_amount': discountAmount,
      'order_id': orderId,
    };
  }
}