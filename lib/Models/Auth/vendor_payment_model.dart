// Model for Create/Update Vendor Payment Request
class VendorPaymentRequest {  //Build #1.0.74: Naveen Added
  final String title;
  final int vendorId;
  final double amount;
  final String paymentMethod;
  final int shiftId;
  final String serviceType;
  final String notes;
  final int? vendorPaymentId; // Added for update request

  VendorPaymentRequest({
    required this.title,
    required this.vendorId,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.serviceType,
    required this.notes,
    this.vendorPaymentId,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'title': title,
      'vendor_id': vendorId,
      'amount': amount,
      'payment_method': paymentMethod,
      'shift_id': shiftId,
      'service_type': serviceType,
      'notes': notes,
    };
    if (vendorPaymentId != null) {
      json['vendor_payment_id'] = vendorPaymentId ?? 0;
    }
    return json;
  }
}

// Model for Create/Delete/Update Vendor Payment Response
class VendorPaymentResponse {
  final int vendorPaymentId;
  final String message;

  VendorPaymentResponse({
    required this.vendorPaymentId,
    required this.message,
  });

  factory VendorPaymentResponse.fromJson(Map<String, dynamic> json) {
    return VendorPaymentResponse(
      vendorPaymentId: int.parse(json['vendor_payment_id'].toString()) ?? 0,
      message: json['message'] ?? '',
    );
  }
}

// Model for Vendor Payment
class VendorPayment {
  final int id;
  final String postAuthor;
  final String postDate;
  final String postTitle;
  final String? vendorName;
  final String amount;
  final String method;
  final String shiftId;
  final String vendorId;
  final String serviceType;
  final String notes;

  VendorPayment({
    required this.id,
    required this.postAuthor,
    required this.postDate,
    required this.postTitle,
    this.vendorName,
    required this.amount,
    required this.method,
    required this.shiftId,
    required this.vendorId,
    required this.serviceType,
    required this.notes,
  });

  factory VendorPayment.fromJson(Map<String, dynamic> json) {
    return VendorPayment(
      id: json['ID'] ?? 0,
      postAuthor: json['post_author'] ?? '',
      postDate: json['post_date'] ?? '',
      postTitle: json['post_title'] ?? '',
      vendorName: json['vendor_name'],
      amount: json['amount'] ?? '0',
      method: json['method'] ?? '',
      shiftId: json['shift_id'] ?? '0',
      vendorId: json['_vendor_id'] ?? '0',
      serviceType: json['service_type'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

// Model for Get Vendor Payments Response
class VendorPaymentsResponse {
  final List<VendorPayment> payments;

  VendorPaymentsResponse({required this.payments});

  factory VendorPaymentsResponse.fromJson(List<dynamic> json) {
    return VendorPaymentsResponse(
      payments: json.map((item) => VendorPayment.fromJson(item)).toList(),
    );
  }
}