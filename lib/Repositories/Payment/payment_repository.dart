// repositories/payment_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Payment/payment_model.dart';
import '../../Models/Payment/send_order_details_model.dart';
import '../../Models/Payment/void_payment_model.dart';

class PaymentRepository {  // Build #1.0.25 - added by naveen
  final APIHelper _helper = APIHelper();

  // 1. Create Payment
  // Future<PaymentResponseModel> createPayment(PaymentRequestModel request) async {
  //   final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.createPaymentEndUrl}";
  //
  //   if (kDebugMode) {
  //     print("PaymentRepository - POST URL: $url");
  //     print("PaymentRepository - Request Body: ${request.toJson()}");
  //   }
  //
  //   final response = await _helper.post(url, request.toJson(), true);
  //
  //   if (kDebugMode) {
  //     print("PaymentRepository - Raw Response: $response");
  //   }
  //
  //   if (response is String) {
  //     try {
  //       final responseData = json.decode(response);
  //       return PaymentResponseModel.fromJson(responseData);
  //     } catch (e) {
  //       if (kDebugMode) print("Error parsing payment response: $e");
  //       throw Exception("Failed to parse payment response");
  //     }
  //   } else if (response is Map<String, dynamic>) {
  //     return PaymentResponseModel.fromJson(response);
  //   } else {
  //     throw Exception("Unexpected response type in payment POST");
  //   }
  // }

  // 2. Get Payment by ID
  Future<List<PaymentDetailModel>> getPaymentById(int paymentId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.paymentByIdEndUrl}$paymentId";

    if (kDebugMode) {
      print("PaymentRepository - GET URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("PaymentRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response) as List;
        return responseData.map((e) => PaymentDetailModel.fromJson(e)).toList();
      } catch (e) {
        if (kDebugMode) print("Error parsing payment detail response: $e");
        throw Exception("Failed to parse payment detail response");
      }
    } else if (response is List) {
      return response.map((e) => PaymentDetailModel.fromJson(e)).toList();
    } else {
      throw Exception("Unexpected response type in payment detail GET");
    }
  }

  // 3. Update Payment Meta (NEW)
  Future<bool> updatePaymentMeta({
    required int paymentId,
    required String key,
    required String value,
  }) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.paymentmeta}";
    final body = {
      "payment_id": paymentId,
      "key": key,
      "value": value,
    };

    if (kDebugMode) {
      print("Updating Payment Meta URL: $url");
      print("Updating Payment Meta Body: $body");
    }

    final response = await _helper.post(url, body, true);

    if (kDebugMode) {
      print("Payment Meta Update Response: $response");
    }

    if (response is Map && response["success"] == true) {
      return true;
    }

    return false;
  }


  // 3. Get Payments by Order ID

  Future<List<PaymentListModel>> getPaymentsByOrderId(int orderId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.paymentByOrderIdEndUrl}$orderId";

    if (kDebugMode) {
      print("PaymentRepository - GET URL: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("PaymentRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response) as List;
        return responseData.map((e) => PaymentListModel.fromJson(e)).toList();
      } catch (e) {
        if (kDebugMode) print("Error parsing payments list response: $e");
        throw Exception("Failed to parse payments list response");
      }
    } else if (response is List) {
      return response.map((e) => PaymentListModel.fromJson(e)).toList();
    } else {
      throw Exception("Unexpected response type in payments list GET");
    }
  }

  // Build #1.0.49: Added voidPayment api call code

  Future<PaymentResponseModel> voidPayment(VoidPaymentRequestModel request) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.voidPaymentEndUrl}";

    if (kDebugMode) {
      print("PaymentRepository - POST URL: $url");
      print("PaymentRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("PaymentRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return PaymentResponseModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing void payment response: $e");
        throw Exception("Failed to parse void payment response");
      }
    } else if (response is Map<String, dynamic>) {
      return PaymentResponseModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in void payment POST");
    }
  }

  // Build #1.0.175: Added void order API call for cancel the payment completed order if it is void
  Future<PaymentResponseModel> voidOrder(int orderId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.payments}${EndUrlConstants.voidOrderEndUrl}";
    final body = {"order_id": orderId};

    if (kDebugMode) {
      print("PaymentRepository - Void Order POST URL: $url");
      print("PaymentRepository - Void Order Request Body: $body");
    }

    final response = await _helper.post(url, body, true);

    if (kDebugMode) {
      print("PaymentRepository - Void Order Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return PaymentResponseModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing void order response: $e");
        throw Exception("Failed to parse void order response");
      }
    } else if (response is Map<String, dynamic>) {
      return PaymentResponseModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in void order POST");
    }
  }

  // Build #1.0.159
  // 5. Send Order Details API Call
  Future<SendOrderDetailsResponseModel> sendOrderDetails(int orderId, SendOrderDetailsRequestModel request) async {
    final url = "${UrlHelper.wooCommerceV3}${UrlMethodConstants.orders}/$orderId${EndUrlConstants.sendEmailOrderDetailsEndUrl}";

    if (kDebugMode) {
      print("PaymentRepository - POST URL: $url");
      print("PaymentRepository - Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("PaymentRepository - Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return SendOrderDetailsResponseModel.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing send order details response: $e");
        throw Exception("Failed to parse send order details response");
      }
    } else if (response is Map<String, dynamic>) {
      return SendOrderDetailsResponseModel.fromJson(response);
    } else {
      throw Exception("Unexpected response type in send order details POST");
    }
  }
}