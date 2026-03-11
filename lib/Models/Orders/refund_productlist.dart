class RefundResponseModel {
  final bool success;
  final String message;
  final int orderId;
  final double total;

  RefundResponseModel({
    required this.success,
    required this.message,
    required this.orderId,
    required this.total,
  });

  factory RefundResponseModel.fromJson(Map<String, dynamic> json) {
    print("Refund Response JSON: $json");
    return RefundResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      orderId: json['order_id'] ?? 0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
    );
  }
}