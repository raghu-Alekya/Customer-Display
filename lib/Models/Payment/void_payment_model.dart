// models/void_payment_model.dart
class VoidPaymentRequestModel {
final int orderId;
final String? paymentId; // Build #1.0.175: Updated -> Made optional for void order API

VoidPaymentRequestModel({required this.orderId, this.paymentId});

Map<String, dynamic> toJson() => {
  'order_id': orderId,
  if (paymentId != null) 'payment_id': paymentId, // Include only if provided
};
}

// class VoidPaymentResponseModel { // Build #1.0.175: No need -> from using PaymentResponseModel for all create payment, void payment, void order, API response
//   final bool success;
//   final String message;
//
//   VoidPaymentResponseModel({required this.success, required this.message});
//
//   factory VoidPaymentResponseModel.fromJson(Map<String, dynamic> json) =>
//       VoidPaymentResponseModel(
//         success: json['success'] ?? false,
//         message: json['message'] ?? '',
//       );
// }