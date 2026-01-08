// models/payment/payment_request_model.dart
class PaymentRequestModel {  // Build #1.0.25 - added by naveen
  final String title;
  final int orderId;
  final double amount;
  final String paymentMethod;
  final int shiftId;
  final int vendorId;
  final int userId;
  final String serviceType;
  final String datetime;
  final String notes;

  PaymentRequestModel({
    required this.title,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.vendorId,
    required this.userId,
    required this.serviceType,
    required this.datetime,
    required this.notes,

  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'order_id': orderId,
      'amount': amount,
      'payment_method': paymentMethod,
      'shift_id': shiftId,
      'vendor_id': vendorId,
      'user_id': userId,
      'service_type': serviceType,
      'datetime': datetime,
      'notes': notes,
    };
  }
}

// models/payment/payment_response_model.dart
class PaymentResponseModel { // Build #1.0.175: Updated -> PaymentResponseModel using create payment, void payment, void order, API response model
  final String message; // Required as the common element
  final bool? success; // Optional for specific APIs
  final int? paymentId; // Optional for payment creation
  final String? voidPaymentId; // Optional for void payment
  final int? orderId; // Optional for specific APIs
  final double? paidAmount; // Optional for payment response
  final double? totalPaid; // Optional for specific APIs
  final double? remainingAmount; // Optional for specific APIs
  final double? orderTotal; // Optional for specific APIs
  final String? orderStatus; // Optional for specific APIs
  final bool? voidStatus; // Optional for payment response
  final List<int>? voidedPayments; // Optional for void order
  // ⭐ ADD THESE TWO
  final int? availableCoupons;
  final List<CouponModel>? coupons;

  PaymentResponseModel({
    required this.message,
    this.success,
    this.paymentId,
    this.voidPaymentId,
    this.orderId,
    this.paidAmount,
    this.totalPaid,
    this.remainingAmount,
    this.orderTotal,
    this.orderStatus,
    this.voidStatus,
    this.voidedPayments,
    this.availableCoupons,
    this.coupons,
  });

  factory PaymentResponseModel.fromJson(Map<String, dynamic> json) => PaymentResponseModel(
    message: json['message'] ?? '',
    success: json['success'],
    paymentId: json['payment_id'],
    voidPaymentId: json['void_payment_id'] ?? json['void_payment_id'],
    orderId: json['order_id'],
    paidAmount: json['paid_amount']?.toDouble(),
    totalPaid: json['total_paid']?.toDouble(),
    remainingAmount: json['remaining_amount']?.toDouble(),
    orderTotal: json['order_total']?.toDouble(),
    orderStatus: json['order_status'],
    voidStatus: json['void'],
    voidedPayments: json['voided_payments'] != null
        ? List<int>.from(json['voided_payments'])
        : null,
    availableCoupons: json['available_coupons'],
    coupons: (json['coupons'] as List?)
        ?.map((e) => CouponModel.fromJson(e))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'message': message,
    if (success != null) 'success': success,
    if (paymentId != null) 'payment_id': paymentId,
    if (voidPaymentId != null) 'void_payment_id': voidPaymentId,
    if (orderId != null) 'order_id': orderId,
    if (paidAmount != null) 'paid_amount': paidAmount,
    if (totalPaid != null) 'total_paid': totalPaid,
    if (remainingAmount != null) 'remaining_amount': remainingAmount,
    if (orderTotal != null) 'order_total': orderTotal,
    if (orderStatus != null) 'order_status': orderStatus,
    if (voidStatus != null) 'void': voidStatus,
    if (voidedPayments != null) 'voided_payments': voidedPayments,
    if (availableCoupons != null)
      'available_coupons': availableCoupons,
    if (coupons != null)
      'coupons': coupons!.map((c) => c.toJson()).toList(),
  };
}

class CouponModel {
  final int id;
  final String code;
  final String discountType;
  final double amount;
  final double minAmount;
  final double maxAmount;
  final String generateType;
  final int generateLimit;
  final String expiryDate;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.amount,
    required this.minAmount,
    required this.maxAmount,
    required this.generateType,
    required this.generateLimit,
    required this.expiryDate,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      minAmount: (json['min_amount'] as num?)?.toDouble() ?? 0.0,
      maxAmount: (json['max_amount'] as num?)?.toDouble() ?? 0.0,
      generateType: json['generate_type'] ?? '',
      generateLimit: json['generate_limit'] ?? 0,
      expiryDate: json['expiry_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'discount_type': discountType,
    'amount': amount,
    'min_amount': minAmount,
    'max_amount': maxAmount,
    'generate_type': generateType,
    'generate_limit': generateLimit,
    'expiry_date': expiryDate,
  };
}


// models/payment/payment_detail_model.dart
class PaymentDetailModel {
  final int id;
  final String title;
  final String date;
  final String orderId;
  final String amount;
  final String paymentMethod;
  final String shiftId;
  final String vendorId;
  final String userId;
  final String serviceType;
  final String datetime;
  final String notes;
  final String transactionId;
  final String transactionDetails;

  PaymentDetailModel({
    required this.id,
    required this.title,
    required this.date,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.vendorId,
    required this.userId,
    required this.serviceType,
    required this.datetime,
    required this.notes,
    required this.transactionId,
    required this.transactionDetails,
  });

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) {
    return PaymentDetailModel(
      id: json['ID'] ?? 0,
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      orderId: json['order_id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      paymentMethod: json['payment_method'] ?? '',
      shiftId: json['shift_id']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      serviceType: json['service_type'] ?? '',
      datetime: json['datetime'] ?? '',
      notes: json['notes'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      transactionDetails: json['transaction_details'] ?? '',
    );
  }
}

// models/payment/payment_list_model.dart
class PaymentListModel { // Build #1.0.175: Updated -> getPaymentsByOrderId API response
  final int id;
  final String postAuthor;
  final String postDate;
  final String postDateGmt;
  final String postContent;
  final String postTitle;
  final String postExcerpt;
  final String postStatus;
  final String commentStatus;
  final String pingStatus;
  final String postPassword;
  final String postName;
  final String toPing;
  final String pinged;
  final String postModified;
  final String postModifiedGmt;
  final String postContentFiltered;
  final int postParent;
  final String guid;
  final int menuOrder;
  final String postType;
  final String postMimeType;
  final String commentCount;
  final String filter;
  final String orderId;
  final String amount;
  final String paymentMethod;
  final String shiftId;
  final String vendorId;
  final String userId;
  final String serviceType;
  final String datetime;
  final String notes;
  final String transactionId;
  final String transactionDetails;
  final bool voidStatus;
  final String orderStatus;

  PaymentListModel({
    required this.id,
    required this.postAuthor,
    required this.postDate,
    required this.postDateGmt,
    required this.postContent,
    required this.postTitle,
    required this.postExcerpt,
    required this.postStatus,
    required this.commentStatus,
    required this.pingStatus,
    required this.postPassword,
    required this.postName,
    required this.toPing,
    required this.pinged,
    required this.postModified,
    required this.postModifiedGmt,
    required this.postContentFiltered,
    required this.postParent,
    required this.guid,
    required this.menuOrder,
    required this.postType,
    required this.postMimeType,
    required this.commentCount,
    required this.filter,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.shiftId,
    required this.vendorId,
    required this.userId,
    required this.serviceType,
    required this.datetime,
    required this.notes,
    required this.transactionId,
    required this.transactionDetails,
    required this.voidStatus,
    required this.orderStatus,
  });

  factory PaymentListModel.fromJson(Map<String, dynamic> json) {
    return PaymentListModel(
      id: json['ID'] ?? 0,
      postAuthor: json['post_author']?.toString() ?? '',
      postDate: json['post_date'] ?? '',
      postDateGmt: json['post_date_gmt'] ?? '',
      postContent: json['post_content'] ?? '',
      postTitle: json['post_title'] ?? '',
      postExcerpt: json['post_excerpt'] ?? '',
      postStatus: json['post_status'] ?? '',
      commentStatus: json['comment_status'] ?? '',
      pingStatus: json['ping_status'] ?? '',
      postPassword: json['post_password'] ?? '',
      postName: json['post_name'] ?? '',
      toPing: json['to_ping'] ?? '',
      pinged: json['pinged'] ?? '',
      postModified: json['post_modified'] ?? '',
      postModifiedGmt: json['post_modified_gmt'] ?? '',
      postContentFiltered: json['post_content_filtered'] ?? '',
      postParent: json['post_parent'] ?? 0,
      guid: json['guid'] ?? '',
      menuOrder: json['menu_order'] ?? 0,
      postType: json['post_type'] ?? '',
      postMimeType: json['post_mime_type'] ?? '',
      commentCount: json['comment_count']?.toString() ?? '',
      filter: json['filter'] ?? '',
      orderId: json['order_id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      paymentMethod: json['payment_method'] ?? '',
      shiftId: json['shift_id']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      serviceType: json['service_type'] ?? '',
      datetime: json['datetime'] ?? '',
      notes: json['notes'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      transactionDetails: json['transaction_details'] ?? '',
      voidStatus: json['void'] ?? false,
      orderStatus: json['order_status'] ?? '',
    );
  }
}