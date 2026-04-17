// blocs/payment_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Payment/payment_model.dart';
import '../../Models/Payment/send_order_details_model.dart';
import '../../Models/Payment/void_payment_model.dart';
import '../../Repositories/Payment/payment_repository.dart';
import '../../services/CustomerDisplayService.dart';

class PaymentBloc {  // Build #1.0.25 - added by naveen
  final PaymentRepository _paymentRepository;

  // Stream Controllers
  final StreamController<APIResponse<PaymentResponseModel>> _createPaymentController =
  StreamController<APIResponse<PaymentResponseModel>>.broadcast();

  final StreamController<APIResponse<List<PaymentDetailModel>>> _paymentDetailController =
  StreamController<APIResponse<List<PaymentDetailModel>>>.broadcast();

  final StreamController<APIResponse<List<PaymentListModel>>> _paymentsListController =
  StreamController<APIResponse<List<PaymentListModel>>>.broadcast();

  final StreamController<APIResponse<PaymentResponseModel>> _voidPaymentController =
  StreamController<APIResponse<PaymentResponseModel>>.broadcast();

  final StreamController<APIResponse<SendOrderDetailsResponseModel>> _sendOrderDetailsController =
  StreamController<APIResponse<SendOrderDetailsResponseModel>>.broadcast();

  final StreamController<APIResponse<PaymentResponseModel>> _voidOrderController =
  StreamController<APIResponse<PaymentResponseModel>>.broadcast(); // Build #1.0.175: Added void order API call for cancel the payment completed order if it is void

  StreamSink<APIResponse<PaymentResponseModel>> get voidPaymentSink => _voidPaymentController.sink;
  Stream<APIResponse<PaymentResponseModel>> get voidPaymentStream => _voidPaymentController.stream;

  StreamSink<APIResponse<PaymentResponseModel>> get voidOrderSink => _voidOrderController.sink;
  Stream<APIResponse<PaymentResponseModel>> get voidOrderStream => _voidOrderController.stream;

  // Getters for Streams
  StreamSink<APIResponse<PaymentResponseModel>> get createPaymentSink => _createPaymentController.sink;
  Stream<APIResponse<PaymentResponseModel>> get createPaymentStream => _createPaymentController.stream;

  StreamSink<APIResponse<List<PaymentDetailModel>>> get paymentDetailSink => _paymentDetailController.sink;
  Stream<APIResponse<List<PaymentDetailModel>>> get paymentDetailStream => _paymentDetailController.stream;

  StreamSink<APIResponse<List<PaymentListModel>>> get paymentsListSink => _paymentsListController.sink;
  Stream<APIResponse<List<PaymentListModel>>> get paymentsListStream => _paymentsListController.stream;

  StreamSink<APIResponse<SendOrderDetailsResponseModel>> get sendOrderDetailsSink => _sendOrderDetailsController.sink;
  Stream<APIResponse<SendOrderDetailsResponseModel>> get sendOrderDetailsStream => _sendOrderDetailsController.stream;

  PaymentBloc(this._paymentRepository) {
    if (kDebugMode) {
      print("PaymentBloc Initialized with all 3 payment APIs");
    }
  }

  // 1. Create Payment
  // Future<void> createPayment(PaymentRequestModel request) async {
  //   if (_createPaymentController.isClosed) return;
  //
  //   createPaymentSink.add(APIResponse.loading(TextConstants.loading));
  //   try {
  //     final response = await _paymentRepository.createPayment(request);
  //
  //     if (kDebugMode) {
  //       //  print("PaymentBloc - Payment created with ID: ${response.postId}");
  //       print("PaymentBloc - Payment Message: ${response.message}");
  //     }
  //
  //     ///Response is coming as below:
  //     //{
  //     //     "payment_id": 3592,
  //     //     "message": "Payment Created Successfully"
  //     // }
  //     //await CustomerDisplayService.showThankYou();
  //     createPaymentSink.add(APIResponse.completed(response));
  //   } catch (e) {
  //     //Build #1.0.180
  //     if (e.toString().contains('UnauthorisedException')) {
  //       if (kDebugMode) print("UnAutherized $e");
  //       createPaymentSink.add(APIResponse.error("Unauthorised. Session is expired."));
  //     }
  //     if (e.toString().contains('SocketException')) {
  //       createPaymentSink.add(APIResponse.error("Network error. Please check your connection."));
  //     } else {
  //       createPaymentSink.add(APIResponse.error("Failed to create payment: ${e.toString()}"));
  //     }
  //     if (kDebugMode) print("Exception in createPayment: $e");
  //   }
  // }

  // 2. Get Payment by ID
  Future<void> getPaymentById(int paymentId) async {
    if (_paymentDetailController.isClosed) return;

    paymentDetailSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _paymentRepository.getPaymentById(paymentId);

      if (kDebugMode) {
        print("PaymentBloc - Retrieved payment details for ID: $paymentId");
        print("PaymentBloc - Found ${response.length} payment(s)");
        if (response.isNotEmpty) {
          print("PaymentBloc - First payment amount: ${response.first.amount}");
        }
      }

      paymentDetailSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        paymentDetailSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        paymentDetailSink.add(APIResponse.error("Failed to get payment details: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in getPaymentById: $e");
    }
  }

  // 3. Get Payments by Order ID
  Future<void> getPaymentsByOrderId(int orderId) async {
    if (_paymentsListController.isClosed) return;

    paymentsListSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _paymentRepository.getPaymentsByOrderId(orderId);

      if (kDebugMode) {
        print("PaymentBloc - Retrieved payments for order ID: $orderId");
        print("PaymentBloc - Found ${response.length} payment(s)");
        if (response.isNotEmpty) {
          print("PaymentBloc - First payment method: ${response.first.paymentMethod}");
        }
      }

      paymentsListSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        paymentsListSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        paymentsListSink.add(APIResponse.error("Failed to get payments list: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in getPaymentsByOrderId: $e");
    }
  }

  // 4.  Build #1.0.49: Added Void Payment api func
  Future<void> voidPayment(VoidPaymentRequestModel request) async {
    if (_voidPaymentController.isClosed) return;

    voidPaymentSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _paymentRepository.voidPayment(request);

      if (kDebugMode) {
        print("PaymentBloc - Voided payment for order ID: ${request.orderId}");
        print("PaymentBloc - Void Payment Message: ${response.message}");
      }

      voidPaymentSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        voidPaymentSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        voidPaymentSink.add(APIResponse.error("Failed to void payment: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in voidPayment: $e");
    }
  }

  // Build #1.0.175: Added void order API call for cancel the payment completed order if it is void
  Future<void> voidOrder(int orderId) async {
    if (_voidOrderController.isClosed) return;

    voidOrderSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final response = await _paymentRepository.voidOrder(orderId);

      if (kDebugMode) {
        print("PaymentBloc - Voided order ID: $orderId");
        print("PaymentBloc - Void Order Message: ${response.message}");
        if (response.voidedPayments != null) {
          print("PaymentBloc - Voided Payments: ${response.voidedPayments}");
        }
      }

      voidOrderSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        voidOrderSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        voidOrderSink.add(APIResponse.error("Failed to void order: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in voidOrder: $e");
    }
  }

  // Build #1.0.159
  // 5. Send Order Details API Call
  Future<void> sendOrderDetails(int orderId, String email) async {
    if (_sendOrderDetailsController.isClosed) return;

    sendOrderDetailsSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final request = SendOrderDetailsRequestModel(email: email);
      final response = await _paymentRepository.sendOrderDetails(orderId, request);

      if (kDebugMode) {
        print("PaymentBloc - Send order details for order ID: $orderId, Email: $email");
        print("PaymentBloc - Send Order Details Message: ${response.message}");
      }

      sendOrderDetailsSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        sendOrderDetailsSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        sendOrderDetailsSink.add(APIResponse.error("Failed to send order details: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in sendOrderDetails: $e");
    }
  }

  void dispose() {
    if (!_createPaymentController.isClosed) _createPaymentController.close();
    if (!_paymentDetailController.isClosed) _paymentDetailController.close();
    if (!_paymentsListController.isClosed) _paymentsListController.close();
    if (!_voidPaymentController.isClosed) _voidPaymentController.close();
    if (!_sendOrderDetailsController.isClosed) _sendOrderDetailsController.close();
    if (!_voidOrderController.isClosed) _createPaymentController.close();
    if (kDebugMode) print("PaymentBloc disposed with all controllers");
  }
}