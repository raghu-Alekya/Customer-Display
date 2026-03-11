import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/vendor_payment_model.dart';
import '../../Repositories/Auth/vendor_payment_repository.dart';

// BLoC for Vendor Payments
class VendorPaymentBloc {  //Build #1.0.74: Naveen Added
  final VendorPaymentRepository _vendorPaymentRepository;

  // Stream controller for create vendor payment
  final StreamController<APIResponse<VendorPaymentResponse>> _createVendorPaymentController =
  StreamController<APIResponse<VendorPaymentResponse>>.broadcast();
  StreamSink<APIResponse<VendorPaymentResponse>> get createVendorPaymentSink =>
      _createVendorPaymentController.sink;
  Stream<APIResponse<VendorPaymentResponse>> get createVendorPaymentStream =>
      _createVendorPaymentController.stream;

  // Stream controller for vendor payments by user
  final StreamController<APIResponse<VendorPaymentsResponse>> _vendorPaymentsByUserController =
  StreamController<APIResponse<VendorPaymentsResponse>>.broadcast();
  StreamSink<APIResponse<VendorPaymentsResponse>> get vendorPaymentsByUserSink =>
      _vendorPaymentsByUserController.sink;
  Stream<APIResponse<VendorPaymentsResponse>> get vendorPaymentsByUserStream =>
      _vendorPaymentsByUserController.stream;

  // Stream controller for delete vendor payment
  final StreamController<APIResponse<VendorPaymentResponse>> _deleteVendorPaymentController =
  StreamController<APIResponse<VendorPaymentResponse>>.broadcast();
  StreamSink<APIResponse<VendorPaymentResponse>> get deleteVendorPaymentSink =>
      _deleteVendorPaymentController.sink;
  Stream<APIResponse<VendorPaymentResponse>> get deleteVendorPaymentStream =>
      _deleteVendorPaymentController.stream;

  // Stream controller for update vendor payment
  final StreamController<APIResponse<VendorPaymentResponse>> _updateVendorPaymentController =
  StreamController<APIResponse<VendorPaymentResponse>>.broadcast();
  StreamSink<APIResponse<VendorPaymentResponse>> get updateVendorPaymentSink =>
      _updateVendorPaymentController.sink;
  Stream<APIResponse<VendorPaymentResponse>> get updateVendorPaymentStream =>
      _updateVendorPaymentController.stream;

  VendorPaymentBloc(this._vendorPaymentRepository) {
    if (kDebugMode) {
      print("************** VendorPaymentBloc Initialized");
    }
  }

  // Create Vendor Payment
  Future<void> createVendorPayment(VendorPaymentRequest request) async {
    if (_createVendorPaymentController.isClosed) return;

    createVendorPaymentSink.add(APIResponse.loading(TextConstants.loading));
    try {
      // Debug print to verify vendor_id before API call
      if (kDebugMode) {
        print("VendorPaymentBloc - Creating vendor payment with request: ${request.toJson()}");
      }
      VendorPaymentResponse response = await _vendorPaymentRepository.createVendorPayment(request);
      if (kDebugMode) {
        print("VendorPaymentBloc - Successfully created vendor payment with ID ${response.vendorPaymentId}");
      }
      createVendorPaymentSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        createVendorPaymentSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        createVendorPaymentSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        createVendorPaymentSink.add(APIResponse.error("Failed to create vendor payment: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in createVendorPayment: $e");
    }
  }

  // Get Vendor Payments by User ID
  Future<void> getVendorPaymentsByUserId(int userId) async {
    if (_vendorPaymentsByUserController.isClosed) return;

    vendorPaymentsByUserSink.add(APIResponse.loading(TextConstants.loading));
    try {
      VendorPaymentsResponse response = await _vendorPaymentRepository.getVendorPaymentsByUserId(userId);
      if (kDebugMode) {
        print("VendorPaymentBloc - Successfully fetched ${response.payments.length} vendor payments for user $userId");
      }
      vendorPaymentsByUserSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        vendorPaymentsByUserSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        vendorPaymentsByUserSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        vendorPaymentsByUserSink.add(APIResponse.error("Failed to fetch vendor payments: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in getVendorPaymentsByUserId: $e");
    }
  }

  // Delete Vendor Payment
  Future<void> deleteVendorPayment(int paymentId) async {
    if (_deleteVendorPaymentController.isClosed) return;

    deleteVendorPaymentSink.add(APIResponse.loading(TextConstants.loading));
    try {
      // Debug print to verify payment_id
      if (kDebugMode) {
        print("VendorPaymentBloc - Deleting vendor payment with ID: $paymentId");
      }
      VendorPaymentResponse response = await _vendorPaymentRepository.deleteVendorPayment(paymentId);
      if (kDebugMode) {
        print("VendorPaymentBloc - Successfully deleted vendor payment with ID $paymentId");
      }
      deleteVendorPaymentSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        deleteVendorPaymentSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        deleteVendorPaymentSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        deleteVendorPaymentSink.add(APIResponse.error("Failed to delete vendor payment: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in deleteVendorPayment: $e");
    }
  }

  // Update Vendor Payment
  Future<void> updateVendorPayment(VendorPaymentRequest request, int vendorPaymentId) async {
    if (_updateVendorPaymentController.isClosed) return;

    updateVendorPaymentSink.add(APIResponse.loading(TextConstants.loading));
    try {
      // Debug print to verify request and vendor_payment_id
      if (kDebugMode) {
        print("VendorPaymentBloc - Updating vendor payment ID: $vendorPaymentId with request: ${request.toJson()}");
      }
      VendorPaymentResponse response = await _vendorPaymentRepository.updateVendorPayment(request, vendorPaymentId);
      if (kDebugMode) {
        print("VendorPaymentBloc - Successfully updated vendor payment with ID $vendorPaymentId");
      }
      updateVendorPaymentSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        updateVendorPaymentSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        updateVendorPaymentSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        updateVendorPaymentSink.add(APIResponse.error("Failed to update vendor payment: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in updateVendorPayment: $e");
    }
  }

  void dispose() {
    if (!_createVendorPaymentController.isClosed) {
      _createVendorPaymentController.close();
    }
    if (!_vendorPaymentsByUserController.isClosed) {
      _vendorPaymentsByUserController.close();
    }
    if (!_deleteVendorPaymentController.isClosed) {
      _deleteVendorPaymentController.close();
    }
    if (!_updateVendorPaymentController.isClosed) {
      _updateVendorPaymentController.close();
    }
    if (kDebugMode) print("VendorPaymentBloc disposed");
  }
}