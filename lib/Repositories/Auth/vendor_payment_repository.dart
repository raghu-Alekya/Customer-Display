import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/vendor_payment_model.dart';

// Repository for Vendor Payments
class VendorPaymentRepository {  //Build #1.0.74: Naveen Added
  final APIHelper _helper = APIHelper();

  // Create Vendor Payment
  Future<VendorPaymentResponse> createVendorPayment(VendorPaymentRequest request) async {
    const url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.vendorPayments}${EndUrlConstants.createVendorPayment}";

    if (kDebugMode) {
      print("VendorPaymentRepository - POST URL: $url");
      print("VendorPaymentRepository - POST Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("VendorPaymentRepository - POST Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return VendorPaymentResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing create vendor payment response: $e");
        throw Exception("Failed to parse create vendor payment response");
      }
    } else if (response is Map<String, dynamic>) {
      return VendorPaymentResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in create vendor payment");
    }
  }

  // Get Vendor Payments by User ID
  Future<VendorPaymentsResponse> getVendorPaymentsByUserId(int userId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.vendorPayments}${EndUrlConstants.getVendorPaymentById}$userId";

    if (kDebugMode) {
      print("VendorPaymentRepository - GET URL for Vendor Payments: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("VendorPaymentRepository - GET Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return VendorPaymentsResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing vendor payments response: $e");
        throw Exception("Failed to parse vendor payments response");
      }
    } else if (response is List<dynamic>) {
      return VendorPaymentsResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in get vendor payments");
    }
  }

  // Delete Vendor Payment
  Future<VendorPaymentResponse> deleteVendorPayment(int paymentId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.vendorPayments}${UrlParameterConstants.deleteVendorPayment}${EndUrlConstants.vendorPaymentById}$paymentId";

    if (kDebugMode) {
      print("VendorPaymentRepository - DELETE URL: $url");
    }

    final response = await _helper.delete(url);

    if (kDebugMode) {
      print("VendorPaymentRepository - DELETE Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return VendorPaymentResponse.fromJson({
          'vendor_payment_id': responseData['post_id'],
          'message': responseData['message'],
        });
      } catch (e) {
        if (kDebugMode) print("Error parsing delete vendor payment response: $e");
        throw Exception("Failed to parse delete vendor payment response");
      }
    } else if (response is Map<String, dynamic>) {
      return VendorPaymentResponse.fromJson({
        'vendor_payment_id': response['post_id'],
        'message': response['message'],
      });
    } else {
      throw Exception("Unexpected response type in delete vendor payment");
    }
  }

  // Update Vendor Payment
  Future<VendorPaymentResponse> updateVendorPayment(VendorPaymentRequest request, int vendorPaymentId) async {
    const url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.vendorPayments}${EndUrlConstants.updateVendorPayment}";

    if (kDebugMode) {
      print("VendorPaymentRepository - POST URL for Update: $url");
      print("VendorPaymentRepository - POST Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("VendorPaymentRepository - POST Raw Response for Update: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return VendorPaymentResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing update vendor payment response: $e");
        throw Exception("Failed to parse update vendor payment response");
      }
    } else if (response is Map<String, dynamic>) {
      return VendorPaymentResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in update vendor payment");
    }
  }
}