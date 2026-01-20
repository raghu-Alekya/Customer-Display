import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:pinaka_pos/Helper/Extentions/extensions.dart';
import 'package:pinaka_pos/Screens/Home/redeem_points_popup_screen.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:provider/provider.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Payment/payment_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/printer_db_helper.dart';
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Helper/customerdisplayhelper.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Payment/payment_model.dart';
import '../../Models/Payment/void_payment_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Payment/payment_repository.dart';
import '../../Utilities/global_utility.dart';
import '../../Utilities/responsive_layout.dart';
import '../../Utilities/result_utility.dart';
import '../../Utilities/svg_images_utility.dart';
import '../../Widgets/PaymentNumPad.dart';
import '../../Widgets/scanner_guard.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_payment_dialog.dart';
import '../../services/CustomerDisplayService.dart';
import '../Auth/login_screen.dart';
import 'Settings/image_utils.dart';
import 'Settings/printer_setup_screen.dart';
import 'edit_product_screen.dart';
import 'package:android_intent_plus/android_intent.dart';

import 'package:thermal_printer/thermal_printer.dart';

import 'fast_key_screen.dart';
class LastPaymentInfo {
  final String method;
  final double amount;
  final String? paymentId;

  // ⭐ SUNMI FIELDS
  final String? sunmiTxnId;
  final String? sunmiOrderId;
  final String? sunmiDeviceId; // ⭐ ADD THIS

  LastPaymentInfo({
    required this.method,
    required this.amount,
    this.paymentId,
    this.sunmiTxnId,
    this.sunmiOrderId,
    this.sunmiDeviceId,
  });

  Map<String, dynamic> toJson() => {
    "method": method,
    "amount": amount,
    "paymentId": paymentId,
    "sunmiTxnId": sunmiTxnId,
    "sunmiOrderId": sunmiOrderId,
    "sunmiDeviceId": sunmiDeviceId,
  };

  factory LastPaymentInfo.fromJson(Map<String, dynamic> json) {
    return LastPaymentInfo(
      method: json["method"],
      amount: (json["amount"] as num).toDouble(),
      paymentId: json["paymentId"],
      sunmiTxnId: json["sunmiTxnId"],
      sunmiOrderId: json["sunmiOrderId"],
      sunmiDeviceId: json["sunmiDeviceId"],
    );
  }
}


class OrderSummaryScreen extends StatefulWidget {
  final String formattedDate;
  final String formattedTime;
  final List<Map<String, dynamic>> orderItems;
  final double grossTotal;
  final double orderDiscount;
  final double merchantDiscount;
  final double orderTax;
  final double netPayable;
  final int? orderId;
  final bool isOfflineSynced;
  final int? offlineOrderId;
  final double cashbackFee;
  final double ?balanceamount;
  final double ebtAmount;   // ✅ NEW
  final double discountAmount;

  const OrderSummaryScreen({
    required this.formattedDate,
    required this.formattedTime,
    required this.orderItems,
    required this.grossTotal,
    required this.orderDiscount,
    required this.merchantDiscount,
    required this.orderTax,
    required this.netPayable,
    required this.orderId,
    required this.cashbackFee,
    required this.ebtAmount,
    this.isOfflineSynced = false,
    this.offlineOrderId,
    super.key,
    this.balanceamount,
    required this.discountAmount,

  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // prevents scrollbar from showing
  }
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  List<Map<String, dynamic>> orderItems = [];
  String selectedPaymentMethod = "";
  TextEditingController amountController = TextEditingController();
  bool _paymentDialogShown = false;
  bool get isOrderPending => orderStatus == 'pending';
  LastPaymentInfo? _lastPayment;



  final PaymentBloc paymentBloc =
  PaymentBloc(PaymentRepository()); // Added PaymentBloc
  final ScrollController _scrollController = ScrollController();
  int? userId; // Build #1.0.29: To store user ID
  String? userDisplayName; // Build #1.0.29: To store user ID
  String? userRole;
  int? orderId; // server id from order table
  String? orderDateTime = "";
  double oldTax = 0.0;
  int shiftId = 1; // Hardcoded as per requirement
  int vendorId = 1; // Hardcoded as per requirement
  String serviceType = "default"; // Hardcoded as per requirement
  double total = 0.0;
  double orderTotal = 0.0; // Build #1.0.137
  String orderStatus = TextConstants.processing; // Build  #1.0.177
  double grossTotal = 0.0;
  double balanceAmount = 0.0;
  double tenderAmount = 0.0; // Build #1.0.33 : added new variables
  double paidAmount = 0.0;
  double changeAmount = 0.0;
  double discount = 0.0; // Add this to track discount
  double merchantDiscount = 0.0; // Add this to track merchant discount
  double tax = 0.0;
  double cashback = 0.0;
  double servicecharges = 0.0;
  bool isRedeemActive = false;
  bool isCouponActive = false;
  bool isGiftReceiptActive = false;
  double cashbackFee = 0.0;
  bool isPhoneValid = false;
  bool isEmailValid = false;
  Map<String, dynamic>? loyaltyData;
  bool isAddLoading = false;
// ⭐ store full API data globally
  bool isPaymentDone = false;
  Map<String, dynamic> _order = {};
  bool couponPopupActive = false;



  double ebtTotal = 0.0; // will be loaded from widget.ebtAmount
  double payByEbt = 0.0;   // ADD THIS
  TextEditingController ebtAmountController = TextEditingController();



  double NetTotal = 0.0;
  // AddED tax variable
  double payByCash = 0.0;
  double payByOther = 0.0;
  // String? orderStatus = ""; // Build #1.0.175: save orderStatus value
  StreamSubscription? _paymentListSubscription;
  bool isLoading = false; // Add this to track loading state
  bool isSummaryLoading = false;
  String? _processingPaymentMethod; // Track which payment method is currently processing
  // final TextEditingController _paymentController = TextEditingController();
  var _printerSettings = PrinterSettings();
  List<int> bytes = [];
  String? paymentId; // To store the transaction ID after wallet payment
  late OrderBloc orderBloc;
  bool _showFullSummary = false;
  String? _amountErrorText;
  bool _isAmountEntered = false;
  double payByCard = 0.0;
  Map<String, dynamic>? offlineOrder;



  double discountValue = 0.0;

  // Determine the date and time to display
  String _displayDate = "";
  String _displayTime = "";
  int _rawAmount = 0;
  double computedNetPayable = 0.0;
// holds value in paise/cents, e.g. 2345
  bool showCustomerInput = false;
  final TextEditingController mobileController = TextEditingController();
  int availablePoints = 0; // from backend API
  double orderTotalAmount = 0.0; // from order helper / cart total
  bool isMobileValid = false;
  double redeemedValue = 0.0;
  bool isPaymentStarted = false;
  bool isRedeemAppliedFromApi = false;
  bool isCouponAppliedFromApi = false;
  double couponValue= 0;
  double couponDiscount = 0.0;

  Future<void> _fetchShiftId() async {
    final data = await UserDbHelper().getUserData();
    if (data != null && data["shift_id"] != null) {
      setState(() {
        shiftId = data["shift_id"];
      });
    }
  }

  void _selectPaymentMethod(
      String method, {
        bool autoFillAmount = false,
        double? maxAllowedAmount,
      }) {
    setState(() {
      selectedPaymentMethod = method;

      if (autoFillAmount && maxAllowedAmount != null) {
        _rawAmount = (maxAllowedAmount * 100).toInt();
        amountController.text =
        '${TextConstants.currencySymbol}${maxAllowedAmount.toStringAsFixed(2)}';
        _isAmountEntered = true;
        _amountErrorText = null;
      }
    });
  }


  void _onQuickAmountSelected(double amount) {
    setState(() {
      double allowedAmount = amount;

      // ---------- EBT LIMIT ----------
      if (selectedPaymentMethod == TextConstants.ebtText) {
        allowedAmount = min(amount, ebtTotal);
      }

      // ---------- CARD LIMIT ----------
      else if (selectedPaymentMethod == TextConstants.card) {
        allowedAmount = min(amount, balanceAmount);
      }

      // Convert to paise/cents
      _rawAmount = (allowedAmount * 100).round();

      amountController.text =
      '${TextConstants.currencySymbol}${allowedAmount.toStringAsFixed(2)}';

      _amountErrorText = null;
      _isAmountEntered = _rawAmount > 0;
    });
  }
  void _handlePay() {
    final cleanAmount = amountController.text
        .replaceAll(TextConstants.currencySymbol, '')
        .trim();

    final double amount = double.tryParse(cleanAmount) ?? 0.0;

    // Convert to cents to avoid floating point issues
    final int enteredCents = (amount * 100).round();
    final int ebtCents = (ebtTotal * 100).round();

    // ❌ Basic validation
    if (enteredCents <= 0 && computedNetPayable > 0) {
      setState(() {
        _amountErrorText = TextConstants.amountValidation;
      });
      return;
    }

    _amountErrorText = null;

    // ⭐ EBT validation
    if (selectedPaymentMethod == TextConstants.ebtText) {
      // ❌ No EBT balance
      if (ebtCents <= 0) {
        setState(() {
          _amountErrorText = "No EBT balance available";
        });
        return;
      }

      // ❌ Amount exceeds EBT balance (even by 1 cent)
      if (enteredCents > ebtCents) {
        setState(() {
          _amountErrorText =
          "Amount cannot exceed available EBT balance (\$${ebtTotal.toStringAsFixed(2)})";
        });
        return;
      }
    }

    // ⭐ CARD → Sunmi ONLY
    if (selectedPaymentMethod == TextConstants.card) {
      _openSunmiSaleScreen(
        amount: amount,
        orderId: (widget.orderId ?? widget.offlineOrderId).toString(),
      );
      _resetAmountAfterPay();
      return;
    }

    // ⭐ Wallet / Cash / EBT → API
    _callCreatePaymentAPI(); // uses validated amount
    _resetAmountAfterPay();
  }

  void _resetAmountAfterPay() {
    _rawAmount = 0;
    amountController.text = '${TextConstants.currencySymbol}0.00';
    _isAmountEntered = false;
  }


  @override
  void initState() {
    super.initState();
    ScannerGuard.isCouponPopupOpen = true;

    amountController.addListener(() {
      if (balanceAmount < 0 && amountController.text != '${TextConstants.currencySymbol}0.00') {
        final value = '${TextConstants.currencySymbol}0.00';
        amountController.text = value;
        amountController.selection =
            TextSelection.collapsed(offset: value.length);
      }
    });

    _fetchShiftId();
    orderBloc = OrderBloc(OrderRepository());
    selectedPaymentMethod = TextConstants.cash;
    final bool isNegativeOrder = widget.grossTotal < 0;


    // Load order values
    orderItems = widget.orderItems;
    grossTotal = widget.grossTotal;
    discount = widget.orderDiscount;
    merchantDiscount = widget.merchantDiscount;
    tax = widget.orderTax;
    orderId = widget.orderId;
    ebtTotal = widget.ebtAmount;
    _displayDate = widget.formattedDate;
    _displayTime = widget.formattedTime;
    cashbackFee = widget.cashbackFee;
    discountValue = widget.discountAmount;

    print("🏷 q = $discountValue");


    print("💳 EBT Total in Summary Screen = $ebtTotal");

    // Compute totals
    NetTotal = grossTotal - discount;
    computedNetPayable =
        grossTotal + tax - discount - merchantDiscount + cashbackFee;

    orderTotal = computedNetPayable;

    print("🧮 Computed Net Payable (Order Total) = $orderTotal");
// ================================
// ⭐ RESTORE PAYMENT FROM HIVE
// ================================
    final offlineBox = Hive.box('offlineOrders');
    final orderIdKey = (orderId ?? 0).toString();

    if (offlineBox.containsKey(orderIdKey)) {
      offlineOrder =
      Map<String, dynamic>.from(offlineBox.get(orderIdKey));

      if (offlineOrder!['tenderAmount'] != null &&
          offlineOrder!['balanceAmount'] != null) {

        tenderAmount = (offlineOrder!['tenderAmount'] as num).toDouble();
        balanceAmount = orderTotal; // always start fresh

        payByCash =
            (offlineOrder!['payByCash'] as num?)?.toDouble() ?? 0.0;
        payByOther =
            (offlineOrder!['payByOther'] as num?)?.toDouble() ?? 0.0;

        if (offlineOrder!.containsKey('ebtTotal') &&
            offlineOrder!['ebtTotal'] != null) {
          ebtTotal = (offlineOrder!['ebtTotal'] as num).toDouble();
        }
      } else {
        balanceAmount = orderTotal;
      }
    } else {
      balanceAmount = orderTotal;
    }

// ⭐ Restore last payment (VOID support)
    if (offlineOrder != null &&
        offlineOrder!.containsKey("lastPayment")) {

      _lastPayment = LastPaymentInfo.fromJson(
        Map<String, dynamic>.from(offlineOrder!["lastPayment"]),
      );
    }


    // Show restored payment state
    print("💵 Current Payment Breakdown:");
    print("   → payByCash = $payByCash");
    print("   → payByOther = $payByOther");
    print("   → tenderAmount = $tenderAmount");
    print("   → balanceAmount = $balanceAmount");

    // Redeem listener
    mobileController.addListener(() {
      setState(() {
        isMobileValid =
            RegExp(r'^[0-9]{10}$').hasMatch(mobileController.text);

        if (!isMobileValid) {
          isRedeemActive = false;
        }
      });
    });

    _fetchUserId();

    // Debug dump
    print("🧾 Order Summary Init:"
        "\nItems: ${widget.orderItems.length}"
        "\nGross: ${widget.grossTotal}"
        "\nDiscount: ${widget.orderDiscount}"
        "\nTax: ${widget.orderTax}"
        "\nCashback Fee: $cashbackFee"
        "\nNet Payable: ${widget.netPayable}");

    for (var item in orderItems) {
      print(jsonEncode(item));
    }

    print("💵 INITIAL PAYMENT STATE:");
    print("   payByCash = $payByCash");
    print("   payByOther = $payByOther");
    print("   tenderAmount = $tenderAmount");
    print("   balanceAmount = $balanceAmount");
    print("   orderTotal = $orderTotal");

    if (!isNegativeOrder) {
      _fetchPaymentsByOrderId(); // sale only
    } else {
      // 🔥 payout → no API, no loading
      setState(() {
        isLoading = false;
        isSummaryLoading = false;
        balanceAmount = widget.grossTotal; // negative
      });
    }

  }

  @override
  void dispose() {
    //Build #1.0.99: Added Dispose
    ScannerGuard.isCouponPopupOpen = false;
    _paymentListSubscription?.cancel();
    paymentBloc.dispose();
    _scrollController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserId() async {
    // Build #1.0.29: get the userId from db
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        userRole = userData[AppDBConst.userRole];
      });
    }
  }
  static const MethodChannel _paymentChannel =
  MethodChannel("sunmi_payment_channel");

  Future<void> _openSunmiVoidScreen({
    required double amount,
    required String orderId,
    required String originTransactionId,
  }) async {
    if (kDebugMode) {
      print("🚫 Starting CARD VOID → amount=$amount, orderId=$orderId");
    }

    final result = await _paymentChannel.invokeMethod("startVoid", {
      "amount": amount.toString(),
      "originOrderId": orderId,
      "originTransactionId": originTransactionId,
    });

    final data = jsonDecode(result);
    final fullSunmi = jsonDecode(data["fullResponse"]);

    final bool success = data["status"] == "SUCCESS";
    final double voidedAmount =
        double.tryParse(fullSunmi["processedAmount"] ?? "0") ?? 0.0;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Card void failed")),
      );
      return;
    }

    // -------------------------------
    // ✅ UPDATE FLUTTER TOTALS
    // -------------------------------
    payByCard = (payByCard - voidedAmount).clamp(0, double.infinity);
    tenderAmount = (tenderAmount - voidedAmount).clamp(0, double.infinity);

    balanceAmount =
        (orderTotal - tenderAmount).clamp(0, double.infinity);

    changeAmount = 0;

    if (kDebugMode) {
      print("✅ VOID SUCCESS");
      print("payByCard = $payByCard");
      print("tenderAmount = $tenderAmount");
      print("balanceAmount = $balanceAmount");
    }

    setState(() {});
    // --------------------------------------------------
    // 5️⃣ OFFLINE DELETE (same as cash flow)
    // --------------------------------------------------
    if (widget.isOfflineSynced && widget.offlineOrderId != null) {
      try {
        final offlineId = widget.offlineOrderId!;
        final box = Hive.box('offlineOrders');

        if (box.containsKey(offlineId.toString())) {
          await box.delete(offlineId.toString());
        }

        await orderHelper.deleteOrder(offlineId);
      } catch (e) {
        print("⚠ Failed deleting offline order: $e");
      }
    }

    // -------------------------------
    // ✅ CALL EXISTING VOID API
    // -------------------------------
    _handleVoidPayment(context, isPartial: true);
  }
  Future<void> _openSunmiSaleScreen({
    required double amount,
    required String orderId,
  }) async {
    setState(() {
      _processingPaymentMethod = TextConstants.card;
      isLoading = true;
    });

    try {
      final result = await _paymentChannel.invokeMethod("startSale", {
        "amount": amount.toString(),
        "orderId": orderId,
      });

      final data = jsonDecode(result);
      final fullSunmi = jsonDecode(data["fullResponse"]);

      double paidAmount =
          double.tryParse(fullSunmi["processedAmount"] ?? "0") ?? 0.0;

      // --------------------------------------------------
      // 1️⃣ CARD TOTAL
      // --------------------------------------------------
      payByCard += paidAmount;
      selectedPaymentMethod = TextConstants.card;

      // --------------------------------------------------
      // 2️⃣ BALANCE CALCULATION (same logic as API flow)
      // --------------------------------------------------
      final double previousBalance = balanceAmount;

      if (paidAmount >= previousBalance) {
        changeAmount = paidAmount - previousBalance;
        balanceAmount = 0.0;
      } else {
        balanceAmount = previousBalance - paidAmount;
        changeAmount = 0.0;
      }

      balanceAmount =
          double.tryParse(balanceAmount.toStringAsFixed(2)) ?? 0.0;

      // --------------------------------------------------
      // 3️⃣ TENDER UPDATE
      // --------------------------------------------------
      tenderAmount += paidAmount;

      _order["balanceAmount"] = balanceAmount;
      _order["paidAmount"] = tenderAmount;
      _order["tenderAmount"] = tenderAmount;

      setState(() {});

      // --------------------------------------------------
      // 4️⃣ AUTO CREATE PAYMENT ENTRY (SERVER)
      // --------------------------------------------------
      _createPaymentFromSunmi(paidAmount, fullSunmi);

      // --------------------------------------------------
      // 5️⃣ OFFLINE DELETE (same as cash flow)
      // --------------------------------------------------
      if (widget.isOfflineSynced && widget.offlineOrderId != null) {
        try {
          final offlineId = widget.offlineOrderId!;
          final box = Hive.box('offlineOrders');

          if (box.containsKey(offlineId.toString())) {
            await box.delete(offlineId.toString());
          }

          await orderHelper.deleteOrder(offlineId);
        } catch (e) {
          print("⚠ Failed deleting offline order: $e");
        }
      }

      // --------------------------------------------------
      // 6️⃣ SAVE TO HIVE (balance + tender + ebt)
      // --------------------------------------------------
      try {
        final offlineBox = Hive.box('offlineOrders');
        final key = (this.orderId ?? 0).toString();

        if (offlineBox.containsKey(key)) {
          final updated =
          Map<String, dynamic>.from(offlineBox.get(key));

          updated["balanceAmount"] = balanceAmount;
          updated["paidAmount"] = tenderAmount;
          updated["tenderAmount"] = tenderAmount;
          updated["ebtTotal"] = ebtTotal;

          offlineBox.put(key, updated);
        } else {
          offlineBox.put(key, {
            "balanceAmount": balanceAmount,
            "paidAmount": tenderAmount,
            "tenderAmount": tenderAmount,
            "payByCard": payByCard,
            "ebtTotal": ebtTotal,
          });
        }

        print(
            "✔ Hive updated → balance=$balanceAmount paid=$tenderAmount card=$payByCard");
      } catch (e) {
        print("⚠ Hive update error: $e");
      }

      // --------------------------------------------------
      // 7️⃣ POPUPS
      // --------------------------------------------------
      if (balanceAmount > 0) {
        _showPartialPaymentDialog(context, paidAmount);
      } else {
        _showPaymentDialog(
          context,
          paidAmount,
          changeAmount: 0,
          showChange: false,
        );
      }

      // Reset loading state after successful payment
      setState(() {
        _processingPaymentMethod = null;
        isLoading = false;
      });
    } catch (e) {
      // Reset loading state on error
      setState(() {
        _processingPaymentMethod = null;
        isLoading = false;
      });
      print("⚠ Card payment error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Card payment failed: ${e.toString()}")),
      );
    }
  }
  Future<void> _createPaymentFromSunmi(
      double amount,
      Map<String, dynamic> sunmi,
      ) async {
    final String datetime =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final paymentRequest = PaymentRequestModel(
      title: "Card",
      orderId: orderId ?? 0,
      amount: amount,
      paymentMethod: TextConstants.card,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetime,
      notes: jsonEncode({
        "sunmiTransactionId": sunmi["transactionId"],
        "sunmiOrderId": sunmi["orderId"],
        "authCode": sunmi["authCode"],
        "cardType": sunmi["cardType"],
        "maskedCard": sunmi["maskedCardNumber"],
        "hostRef": sunmi["hostReferenceNumber"],
      }),
    );

    // 🔹 REQUEST LOG
    print("🟡 ================= SUNMI PAYMENT REQUEST =================");
    print(paymentRequest);
    print("🟡 =========================================================");

    paymentBloc.createPayment(paymentRequest);

    StreamSubscription? subscription;
    subscription = paymentBloc.createPaymentStream.listen((paymentResponse) {
      print("");
      print("🟢 ================= SUNMI PAYMENT FULL RESPONSE =================");

      print("STATUS → ${paymentResponse.status}");
      print("RAW RESPONSE OBJECT → $paymentResponse");

      // ❌ ERROR
      if (paymentResponse.status == Status.ERROR) {
        print("❌ ERROR MESSAGE → ${paymentResponse.message}");
        print("❌ ERROR DATA → ${paymentResponse.data}");
        print("🟢 ===============================================================");
        subscription?.cancel();
        return;
      }

      // ✅ SUCCESS
      if (paymentResponse.status == Status.COMPLETED &&
          paymentResponse.data != null) {
        final data = paymentResponse.data!;

        print("✅ MESSAGE → ${data.message}");
        print("✅ PAYMENT ID → ${data.paymentId}");
        print("✅ ORDER ID → ${data.orderId}");
        print("✅ ORDER STATUS → ${data.orderStatus}");

        // =====================================================
        // ⭐ STORE LAST PAYMENT INFO (FOR VOID)
        // =====================================================
        // =====================================================
// ⭐ STORE LAST PAYMENT INFO (FOR VOID)
// =====================================================
        _lastPayment = LastPaymentInfo(
          method: TextConstants.card,
          amount: amount,
          paymentId: data.paymentId?.toString(),

          sunmiTxnId: sunmi["transactionId"]?.toString(),
          sunmiOrderId: sunmi["orderId"]?.toString(),
          sunmiDeviceId: sunmi["deviceID"]?.toString(), // ⭐ FIX
        );


// Keep for API void usage
        paymentId = data.paymentId?.toString();

        // =====================================================
        // ⭐ SAVE TO HIVE (SURVIVES APP RESTART)
        // =====================================================
        try {
          final box = Hive.box('offlineOrders');
          final key = (orderId ?? 0).toString();

          final existing = box.containsKey(key)
              ? Map<String, dynamic>.from(box.get(key))
              : <String, dynamic>{};

          existing["lastPayment"] = _lastPayment!.toJson();
          box.put(key, existing);

          print("💾 LAST PAYMENT SAVED TO HIVE");
          print("   → method = ${_lastPayment!.method}");
          print("   → amount = ${_lastPayment!.amount}");
          print("   → sunmiTxn = ${_lastPayment!.sunmiTxnId}");
          print("   → paymentId = ${_lastPayment!.paymentId}");
        } catch (e) {
          print("⚠ Failed saving last payment to Hive: $e");
        }

        // 🔹 FULL DATA DUMP
        try {
          print("📦 FULL DATA JSON ↓↓↓");
          print(jsonEncode(data.toJson()));
        } catch (e) {
          print("⚠ toJson() not available");
          print(data);
        }
      }

      print("🟢 ===============================================================");
      subscription?.cancel();
    });
  }


  Future<void> updateOfflineOrderRedeem(
      String orderId,
      double redeemedValue,
      int redeemedPoints,
      int updatedAvailablePoints,
      ) async {
    final box = Hive.box('offlineOrders');
    final existing = box.get(orderId);

    if (existing == null) {
      print("⚠ [Hive] Cannot update redeem → Order not found: $orderId");
      return;
    }

    final updated = Map<String, dynamic>.from(existing);

    updated["redeemed_value"] = redeemedValue;
    updated["redeemed_points"] = redeemedPoints;
    updated["available_points_after_redeem"] = updatedAvailablePoints;

    await box.put(orderId, updated);

    print("💾 [Hive] Saved redeem → ID: $orderId | value: $redeemedValue | points: $redeemedPoints | left: $updatedAvailablePoints");
  }
  void _recalculateAfterPayment(double amount) {
    double remaining = balanceAmount;

    // 1️⃣ If paying by EBT
    if (selectedPaymentMethod == TextConstants.ebtText) {

      if (amount >= ebtTotal) {
        // Full EBT paid
        amount -= ebtTotal;
        remaining -= ebtTotal;
        ebtTotal = 0;
      } else {
        // Partial EBT payment
        ebtTotal -= amount;
        remaining -= amount;
        amount = 0;
      }
    }

    // 2️⃣ If paying by CASH or CARD etc.
    else {
      double nonEbtBalance = remaining - ebtTotal; // balance that cash CAN pay safely

      if (amount <= nonEbtBalance) {
        // Case 1 → cash does NOT affect EBT
        remaining -= amount;
      } else {
        // Case 2 → extra cash reduces EBT
        double extraCash = amount - nonEbtBalance;

        // Reduce EBT by that extra amount
        ebtTotal = (ebtTotal - extraCash).clamp(0, double.infinity);

        // New remaining balance becomes exactly new EBT
        remaining = ebtTotal;
      }
    }

    balanceAmount = remaining.clamp(0, double.infinity);

    setState(() {});
  }

  Future<void> removeOfflineOrderRedeem(String orderId) async {
    final box = Hive.box('offlineOrders');
    final existing = box.get(orderId);

    if (existing == null) return;

    final updated = Map<String, dynamic>.from(existing);

    updated.remove("redeemed_value");
    updated.remove("redeemed_points");
    updated.remove("available_points_after_redeem");

    await box.put(orderId, updated);

    if (kDebugMode) {
      print("🗑 [Hive] Redeem REMOVED → OrderId: $orderId");
    }
  }
  void _fetchPaymentsByOrderId() {
    if (kDebugMode) print("###### _fetchPaymentsByOrderId");

    if (orderId == null) return;

    final box = Hive.box('offlineOrders');
    final key = orderId.toString();

    // ================================
    // 🎁 RESTORE REDEEM
    // ================================
    try {
      if (box.containsKey(key)) {
        final stored = Map<String, dynamic>.from(box.get(key));
        redeemedValue =
            (stored["redeemed_value"] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {
      redeemedValue = 0.0;
    }

    // ================================
    // 🥗 RESTORE ORIGINAL EBT
    // ================================
    try {
      if (box.containsKey(key)) {
        final stored = Map<String, dynamic>.from(box.get(key));
        if (stored["originalEbt"] != null) {
          ebtTotal = (stored["originalEbt"] as num).toDouble();
        }
      }
    } catch (_) {}

    setState(() => isSummaryLoading = true);

    paymentBloc.getPaymentsByOrderId(orderId!);

    _paymentListSubscription?.cancel();
    _paymentListSubscription =
        paymentBloc.paymentsListStream.listen((response) {
          if (response.status == Status.COMPLETED) {
            _processPaymentList(response.data!);
          }
          setState(() => isSummaryLoading = false);
        });
  }
  void _processPaymentList(List<PaymentListModel> payments) {
    double cashTotal = 0.0;
    double otherTotal = 0.0;
    double ebtPaid = 0.0;

    // ===================================================
    // 1️⃣ ACCUMULATE NON-VOID PAYMENTS
    // ===================================================
    for (final payment in payments) {
      if (payment.voidStatus) continue;

      final amount = double.tryParse(payment.amount) ?? 0.0;

      if (payment.paymentMethod == TextConstants.ebtText) {
        ebtPaid += amount;
      } else if (payment.paymentMethod == TextConstants.cash) {
        cashTotal += amount;
      } else {
        otherTotal += amount;
      }
    }

    final box = Hive.box('offlineOrders');
    final key = orderId.toString();

    final existing = box.containsKey(key)
        ? Map<String, dynamic>.from(box.get(key))
        : <String, dynamic>{};

    // ===================================================
    // 🔥 SINGLE SOURCE OF TRUTH
    // ===================================================
    final double basePayable = computedNetPayable;

    // ===================================================
    // 🥗 LOCK ORIGINAL EBT
    // ===================================================
    final double originalEbt =
        (existing["originalEbt"] as num?)?.toDouble() ?? ebtTotal;

    existing["originalEbt"] ??= originalEbt;

    // ===================================================
    // 🧮 REMAINING EBT AFTER EBT PAYMENTS
    // ===================================================
    final double remainingEbt =
    originalEbt - ebtPaid < 0 ? 0.0 : originalEbt - ebtPaid;

    // ===================================================
    // 💵 NON-EBT PORTION
    // ===================================================
    final double nonEbtOrderValue =
    basePayable - originalEbt < 0 ? 0.0 : basePayable - originalEbt;

    final double nonEbtPaid = cashTotal + otherTotal;

    // ===================================================
    // 🔁 CASH / CARD OVERFLOW REDUCES EBT
    // ===================================================
    final double overflowToEbt =
    nonEbtPaid > nonEbtOrderValue
        ? nonEbtPaid - nonEbtOrderValue
        : 0.0;

    final double finalRemainingEbt =
    remainingEbt - overflowToEbt < 0 ? 0.0 : remainingEbt - overflowToEbt;

    // ===================================================
    // 🎁 APPLY REDEEM (DISCOUNT ONLY)
    // ===================================================
    final double effectiveOrderTotal =
        basePayable - redeemedValue;

    // ===================================================
    // 💰 TOTAL PAID
    // ===================================================
    final double totalPaid = cashTotal + otherTotal + ebtPaid;

    final double rawBalance = effectiveOrderTotal - totalPaid;

// Balance should NEVER be negative
    final double finalBalance =
    rawBalance > 0 ? rawBalance : 0.0;

// Change only if overpaid
    final double changeAmount =
    rawBalance < 0 ? rawBalance.abs() : 0.0;

    final Map<String, dynamic> couponResponse =
        (existing["coupon_response"] as Map?)?.cast<String, dynamic>() ?? {};


    // ===================================================
    // 🔄 UPDATE UI
    // ===================================================
    setState(() {
      payByCash = cashTotal;
      payByOther = otherTotal;
      payByEbt = ebtPaid;

      ebtTotal = finalRemainingEbt;
      tenderAmount = totalPaid;

      balanceAmount = finalBalance;   // ✅ never negative
      isPaymentStarted = totalPaid > 0;

      if (isPaymentStarted) {
        isRedeemActive = false;
      }

      _paymentDialogShown = false;
    });


    // ===================================================
    // 💾 SAVE TO HIVE
    // ===================================================
    existing["remainingEbt"] = finalRemainingEbt;
    existing["redeemed_value"] = redeemedValue;
    existing["remainingBalance"] = finalBalance;

    box.put(key, existing);

    if (kDebugMode) {
      print("📊 PAYMENT SUMMARY");
      print("Base Payable      = $basePayable");
      print("Redeem            = $redeemedValue");
      print("Cash              = $cashTotal");
      print("Other             = $otherTotal");
      print("EBT Paid          = $ebtPaid");
      print("Remaining EBT     = $finalRemainingEbt");
      print("Total Paid        = $totalPaid");
      print("Balance           = $finalBalance");
    }

    // ===================================================
    // 🔔 PAYMENT COMPLETE (ZERO OR NEGATIVE)
    // ===================================================
    if (payments.isNotEmpty && finalBalance <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentDialog(
          context,
          tenderAmount,
          changeAmount: changeAmount, // 👈 negative allowed
          showChange: true,
          couponResponse: couponResponse,
        );
      });
    }
  }


  void _toggleSummary() {
    setState(() {
      _showFullSummary = !_showFullSummary;
    });
  }

  void deleteItemFromOrder(dynamic itemId) async {
    // TODO: Implement actual deletion logic
    setState(() {
      orderItems.removeWhere((item) => item[AppDBConst.itemId] == itemId);
    });
  }
  void _callCreatePaymentAPI() {
    if (kDebugMode) {
      print("###### _callCreatePaymentAPI called, balanceAmount: $balanceAmount");
    }

    // ------------------------------------------------------
    // ⭐ RULE 0: Ensure user selected a payment method
    // ------------------------------------------------------
    if (selectedPaymentMethod == null || selectedPaymentMethod!.isEmpty) {
      print("❌ ERROR: No payment method selected");
      return;
    }

    final bool isCard = selectedPaymentMethod == TextConstants.card;

    // ------------------------------------------------------
    // ⭐ RULE 1: If method is NOT card, amount is required
    // ------------------------------------------------------
    if (!isCard && balanceAmount > 0 && amountController.text.isEmpty) {
      print("❌ ERROR: Amount required for Cash / Wallet / EBT");
      return;
    }

    // Clean amount
    String cleanAmount = amountController.text
        .replaceAll(TextConstants.currencySymbol, '')
        .trim();

    double amount = double.tryParse(cleanAmount) ?? 0.0;

    // ------------------------------------------------------
    // ⭐ RULE 2: CARD amount handled by Sunmi, ignore validation
    // ------------------------------------------------------
    if (isCard) {
      print("💳 CARD PAYMENT → Skipping amount validation, Sunmi handles it.");
      amount = amount > 0 ? amount : 0.0;
    } else {
      // ------------------------------------------------------
      // ⭐ RULE 3: No negative amount
      // ------------------------------------------------------
      if (amount < 0) {
        print("❌ ERROR: Negative amount");
        return;
      }

      // ------------------------------------------------------
      // ⭐ RULE 4: Amount cannot be zero IF balance > 0
      // ------------------------------------------------------
      if (amount == 0 && computedNetPayable > 0) {
        setState(() => _amountErrorText = TextConstants.amountValidation);
        return;
      }
    }

    _amountErrorText = null;
    double remainingBalance = balanceAmount;

    setState(() {
      _processingPaymentMethod = selectedPaymentMethod;
      isLoading = true;
    });

    final String datetime =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // ⭐ Important fix: Dynamic paymentMethod
    final paymentRequest = PaymentRequestModel(
      title: selectedPaymentMethod!,
      orderId: orderId ?? 0,
      amount: amount,
      paymentMethod: selectedPaymentMethod!, // <-- correct method passed
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetime,
      notes: '',
    );

    if (kDebugMode) print("Creating payment with request: $paymentRequest");

    paymentBloc.createPayment(paymentRequest);

    StreamSubscription? subscription;
    subscription = paymentBloc.createPaymentStream.listen(
          (paymentResponse) async {


        if (kDebugMode) {
          print("Payment stream response: $paymentResponse");
        }

        if (paymentResponse.status == Status.ERROR) {
          setState(() {
            _processingPaymentMethod = null;
            isLoading = false;
          });
          subscription?.cancel();
          return;
        }

        if (paymentResponse.status == Status.COMPLETED &&
            paymentResponse.data != null &&
            paymentResponse.data!.message == "Payment Created Successfully") {
          setState(() {
            isPaymentStarted = true;
            _processingPaymentMethod = null;
            isLoading = false;
          });

          final paymentData = paymentResponse.data!;
          paidAmount = amount;
          paymentId = paymentData.paymentId.toString();
          orderStatus =
              paymentData.orderStatus ?? TextConstants.processing;

          try {
            final box = Hive.box('offlineOrders');
            final key = (orderId ?? 0).toString();

            final existing = box.containsKey(key)
                ? Map<String, dynamic>.from(box.get(key))
                : <String, dynamic>{};

            existing["coupon_response"] = {
              "available_coupons": paymentData.availableCoupons,
              "coupons": paymentData.coupons
                  ?.map((c) => c.toJson())
                  .toList(),
            };

            box.put(key, existing);

            if (kDebugMode) {
              print("🎁 FULL COUPON RESPONSE SAVED");
              print(existing["coupon_response"]);
            }
          } catch (e) {
            print("⚠ Coupon save failed: $e");
          }

          // ------------------------------------------
          // OFFLINE DELETE (unchanged)
          // ------------------------------------------
          if (widget.isOfflineSynced && widget.offlineOrderId != null) {
            try {
              final offlineId = widget.offlineOrderId!;
              final box = Hive.box('offlineOrders');

              if (box.containsKey(offlineId.toString())) {
                await box.delete(offlineId.toString());
              }

              await orderHelper.deleteOrder(offlineId);
            } catch (e) {
              print("⚠ Failed deleting offline order: $e");
            }
          }

          // =====================================================
// ⭐ STORE LAST PAYMENT INFO (FOR VOID)
// =====================================================
          _lastPayment = LastPaymentInfo(
            method: selectedPaymentMethod!,
            amount: amount,
            paymentId: paymentId,
            sunmiTxnId: null, // ❗ only card has this
          );

// Save to Hive
          try {
            final box = Hive.box('offlineOrders');
            final key = (orderId ?? 0).toString();

            final existing = box.containsKey(key)
                ? Map<String, dynamic>.from(box.get(key))
                : <String, dynamic>{};

            existing["lastPayment"] = _lastPayment!.toJson();
            box.put(key, existing);

            if (kDebugMode) {
              print("💾 LAST PAYMENT SAVED (NON-CARD)");
              print("   → method = ${_lastPayment!.method}");
              print("   → amount = ${_lastPayment!.amount}");
              print("   → paymentId = ${_lastPayment!.paymentId}");
            }
          } catch (e) {
            print("⚠ Failed saving last payment to Hive: $e");
          }


          // ------------------------------------------
          // BALANCE CALCULATION (unchanged)
          // ------------------------------------------
          final bool isExactPayment = (amount == remainingBalance);
          final bool isOverPayment = (amount > remainingBalance);
          final bool isPartialPayment = (amount < remainingBalance);

          tenderAmount += amount;

          if (isOverPayment) {
            changeAmount = amount - remainingBalance;
            balanceAmount = 0.0;
          } else if (isExactPayment) {
            changeAmount = 0.0;
            balanceAmount = 0.0;
          } else if (isPartialPayment) {
            balanceAmount = remainingBalance - amount;
            changeAmount = 0.0;
          }

          balanceAmount =
              double.tryParse(balanceAmount.toStringAsFixed(2)) ?? 0.0;
          if (changeAmount != null && changeAmount! > 0) {
            final repo = PaymentRepository();
            await repo.updatePaymentMeta(
              paymentId: int.parse(paymentId!),
              key: "_payment_remaining_change",
              value: changeAmount!.toStringAsFixed(2),
            );
          }

          _order["balanceAmount"] = balanceAmount;
          _order["paidAmount"] = tenderAmount;
          _order["tenderAmount"] = tenderAmount;

          // ------------------------------------------------------
          // ⭐ SAVE BALANCE + TENDER AMOUNT TO ORDER + HIVE
          // ------------------------------------------------------
          try {
            final offlineBox = Hive.box('offlineOrders');
            final key = (orderId ?? 0).toString();

            if (offlineBox.containsKey(key)) {
              final updated = Map<String, dynamic>.from(offlineBox.get(key));

              updated["balanceAmount"] = balanceAmount;
              updated["paidAmount"] = tenderAmount;
              updated["tenderAmount"] = tenderAmount;

              // ⭐ Add this line to store EBT
              updated["ebtTotal"] = ebtTotal;

              offlineBox.put(key, updated);

              print("✔ Hive updated → balance=$balanceAmount paid=$tenderAmount ebt=$ebtTotal");
            } else {
              // If order not in Hive yet, create it
              offlineBox.put(key, {
                "balanceAmount": balanceAmount,
                "paidAmount": tenderAmount,
                "tenderAmount": tenderAmount,
                "payByCash": payByCash,
                "payByOther": payByOther,
                "ebtTotal": ebtTotal,   // ⭐ Add here too
              });
              print("✔ Hive created → balance=$balanceAmount paid=$tenderAmount ebt=$ebtTotal");
            }
          } catch (e) {
            print("⚠ Hive update error: $e");
          }
          amountController.clear();

          if (mounted) setState(() {});

          // ------------------------------------------
          // SHOW POPUPS (unchanged)
          // ------------------------------------------
          if (isPartialPayment && balanceAmount > 0) {
            _showPartialPaymentDialog(context, amount);
          } else {
            _fetchPaymentsByOrderId();
            // _showPaymentDialog(
            //   context,
            //   amount,
            //   changeAmount: changeAmount,
            //   showChange: changeAmount > 0,
            // );
          }

          subscription?.cancel();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeHelper = Provider.of<ThemeNotifier>(context);
    ResponsiveLayout.init(context);

    return Scaffold(
      backgroundColor: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Color(0xFFF1F1F3),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with logo and user info
            // _buildHeader(),
            _buildNavigationBar(),

            // Main content area: split horizontally
            Expanded(
              child: Row(
                children: [
                  // Left Side: Navigation bar + Order Summary stacked vertically
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildOrderSummary(),
                        ),
                      ],
                    ),
                  ),

                  // Right Side: Payment Section
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        // Payment content takes remaining space
                        Expanded(
                          child: _buildPaymentSection(),
                        ),

                        Container(
                          margin: const EdgeInsets.only(
                            left: 0,
                            right: 8,
                            top: 0,
                            bottom: 8,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                          decoration: themeHelper.themeMode == ThemeMode.dark
                              ? ShapeDecoration(
                            color: const Color(0xFF1F1D2B), // dark background
                            shape: RoundedRectangleBorder(
                              // side: BorderSide(
                              //   width: 0,
                              //   color: Colors.black.withOpacity(0.20),
                              // ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(ResponsiveLayout.getRadius(10)),
                                bottomRight: Radius.circular(ResponsiveLayout.getRadius(10)),
                              ),
                            ),
                          )
                              : BoxDecoration(
                            color: Colors.white, // light background
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(ResponsiveLayout.getRadius(10)),
                              bottomRight: Radius.circular(ResponsiveLayout.getRadius(10)),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? const Color(0xFF303136) // dark mode background
                                  : Colors.white,           // light mode background
                              border: Border.all(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ?Color(0xFF303136)    // optional darker border for dark mode
                                    : const Color(0xFFEDF2F9),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? Colors.black.withOpacity(0.3) // subtle shadow in dark mode
                                      : Colors.white,
                                  blurRadius: 8,
                                  offset: const Offset(2, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),                            child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPaymentModeButton(
                                TextConstants.cash,
                                Image.asset(
                                  'assets/cash.png',
                                  width: ResponsiveLayout.getIconSize(24),
                                  height: ResponsiveLayout.getIconSize(24),
                                  fit: BoxFit.contain,
                                ),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9CCD7B), Color(0xFF9CCD7B)],
                                ),
                                borderColor: const Color(0xFF9CCD7B),
                                iconColor: Color(0xFF9CCD7B),
                                isLoading: _processingPaymentMethod == TextConstants.cash && isLoading,
                                isDisabled: _processingPaymentMethod != null && _processingPaymentMethod != TextConstants.cash,
                                onTap: () {
                                  _selectPaymentMethod(TextConstants.cash);
                                  _handlePay();
                                },
                              ),

                              _buildPaymentModeButton(
                                TextConstants.card,
                                Image.asset(
                                  'assets/card.png',
                                  width: ResponsiveLayout.getIconSize(24),
                                  height: ResponsiveLayout.getIconSize(24),
                                  fit: BoxFit.contain,
                                ),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFA484C8), Color(0xFFA484C8)],
                                ),
                                borderColor: const Color(0xFFA484C8),
                                iconColor: Color(0xFFA484C8),
                                isLoading: _processingPaymentMethod == TextConstants.card && isLoading,
                                isDisabled: _processingPaymentMethod != null && _processingPaymentMethod != TextConstants.card,
                                onTap: () {
                                  _selectPaymentMethod(
                                    TextConstants.card,
                                    //autoFillAmount: true,
                                    maxAllowedAmount: balanceAmount,
                                  );
                                  _handlePay();
                                },
                              ),

                              _buildPaymentModeButton(
                                TextConstants.wallet,
                                Image.asset(
                                  'assets/wallet.png',
                                  width: ResponsiveLayout.getIconSize(24),
                                  height: ResponsiveLayout.getIconSize(24),
                                  fit: BoxFit.contain,
                                ),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFCCB985), Color(0xFFCCB985)],
                                ),
                                borderColor: const Color(0xFFCCB985),
                                iconColor: Color(0xFFCCB985),
                                isLoading: _processingPaymentMethod == TextConstants.wallet && isLoading,
                                isDisabled: _processingPaymentMethod != null && _processingPaymentMethod != TextConstants.wallet,
                                onTap: () {
                                  _selectPaymentMethod(
                                    TextConstants.wallet,
                                    //autoFillAmount: true,
                                    maxAllowedAmount: balanceAmount,
                                  );
                                  _handlePay();
                                },
                              ),

                              _buildPaymentModeButton(
                                TextConstants.ebtText,
                                Image.asset(
                                  'assets/ebt.png',
                                  width: ResponsiveLayout.getIconSize(24),
                                  height: ResponsiveLayout.getIconSize(24),
                                  fit: BoxFit.contain,
                                ),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF84A2CB), Color(0xFF84A2CB)],
                                ),
                                borderColor: const Color(0xFF84A2CB),
                                iconColor: Colors.white,
                                isLoading: _processingPaymentMethod == TextConstants.ebtText && isLoading,
                                isDisabled: _processingPaymentMethod != null && _processingPaymentMethod != TextConstants.ebtText,
                                onTap: () {
                                  // 1️⃣ Check if there is any EBT left
                                  if (ebtTotal <= 0) {
                                    setState(() => _amountErrorText = "No EBT balance available");
                                    return;
                                  }

                                  // 2️⃣ Determine the maximum allowed amount
                                  final allowedAmount = balanceAmount.clamp(0.0, ebtTotal);

                                  if (allowedAmount <= 0) {
                                    setState(() => _amountErrorText = "Cannot pay with EBT, balance is zero");
                                    return;
                                  }

                                  // 3️⃣ Select EBT payment method with the allowed amount
                                  _selectPaymentMethod(
                                    TextConstants.ebtText,
                                    maxAllowedAmount: allowedAmount,
                                  );

                                  // 4️⃣ Trigger the payment process
                                  _handlePay();
                                },
                              ),


                            ],
                          ),
                          ),
                        )

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      height: ResponsiveLayout.getHeight(60),
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.primaryBackground
          : Color(0xFFE4E4E4),
      padding: ResponsiveLayout.getResponsivePadding(
        horizontal: 16,
        vertical: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pinaka logo with triangle above it
          SvgPicture.asset(
            themeHelper.themeMode == ThemeMode.dark
                ? 'assets/svg/app_logo.svg'
                : 'assets/svg/app_icon.svg',
            height: ResponsiveLayout.getHeight(40),
            width: ResponsiveLayout.getWidth(40),
          ),

          // User profile section with container and notification bell
          Row(
            children: [
              Container(
                height: ResponsiveLayout.getHeight(45), //45
                margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(16), vertical: 0),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: ResponsiveLayout.getRadius(18),
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userDisplayName ?? TextConstants.unknown).substring(
                            0, 1), //"A", /// use initial for the login user
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveLayout.getFontSize(14)),
                      ),
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userDisplayName ??
                              "", //'A Raghav Kumar', /// use login user display name
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark
                                  : ThemeNotifier.textLight,
                              fontSize: ResponsiveLayout.getFontSize(14)),
                        ),
                        Text(
                          userRole ??
                              TextConstants
                                  .unknown, //'I am Cashier', /// use user role
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveLayout.getWidth(16)),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                child: Icon(
                  Icons.notifications_outlined,
                  size: ResponsiveLayout.getIconSize(24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showCouponAppliedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Coupon already applied. Remove coupon to go back.",
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }


  Widget _buildNavigationBar() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    // Determine the date and time to display
    _displayDate = widget.formattedDate;
    _displayTime = widget.formattedTime;

    final order = orderHelper.activeOrderId != null
        ? orderHelper.orders.firstWhere(
          (o) => o[AppDBConst.orderServerId] == orderHelper.activeOrderId,
      orElse: () => {},
    )
        : {};

    if (order.isNotEmpty && order[AppDBConst.orderDate] != null) {
      try {
        final DateTime createdDateTime =
        DateTime.parse(order[AppDBConst.orderDate].toString());
        _displayDate =
            DateFormat(TextConstants.dateFormat).format(createdDateTime);
        _displayTime =
            DateFormat(TextConstants.timeFormat).format(createdDateTime);
      } catch (e) {
        if (kDebugMode) {
          print("Error parsing order creation date: $e");
        }
        // Fallback to raw data or default if parsing fails
        _displayDate = order[AppDBConst.orderDate].toString().split(' ').first;
      }
    }

    bool isCustomerFieldDisabled =
        redeemedValue > 0;
    final bool isButtonDisabled =
        isPaymentDone ||
            redeemedValue > 0 ||
            isOrderPending ||
            (!(isPhoneValid || isEmailValid) && !showCustomerInput);

    return Container(
      height: ResponsiveLayout.getHeight(60),
      width: double.infinity,
      margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
      padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.getPadding(6)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.appBarBackground
            : const Color(0xFFFFFFFF),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          InkWell(
            borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(8)),
            onTap: () {
              final bool hasPartialPayment = tenderAmount > 0 && balanceAmount > 0;
              if (hasPartialPayment) {
                _showExitPaymentConfirmation(context);
                return;
              }
              if (discount > 0) {
                _showCouponAppliedSnackBar(context);
                return;
              }
              _showExitPaymentConfirmation(context);
            },
            child: Container(
              height: 40,
              width: ResponsiveLayout.getWidth(90),
              padding: EdgeInsets.all(ResponsiveLayout.getPadding(5)),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Color(0xFF46566F),
                borderRadius:
                BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                      alignment: Alignment.center,
                      // decoration: BoxDecoration(
                      //     shape: BoxShape.circle,
                      //     color: Colors.white,
                      //     border: Border.all(
                      //         color: themeHelper.themeMode == ThemeMode.dark
                      //             ? ThemeNotifier.secondaryBackground
                      //             : Colors.black12)),
                      child: Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? Colors.white
                            : Colors.white,
                      )),
                  const SizedBox(width: 10),
                  Text(
                    TextConstants.back,
                    style:
                    TextStyle(fontSize: ResponsiveLayout.getFontSize(15), color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 70),


          const SizedBox(width: 160),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ---------------- CUSTOMER INPUT CONTAINER ----------------
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.only(
                      top: 4,
                      left: 16,
                      right: 10,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF40424F)
                          : const Color(0xFFE5EFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Customer :',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF115ACD),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                width: 1,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.black.withOpacity(0.20),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: StatefulBuilder(
                              builder: (context, innerSetState) {
                                return TextField(
                                  controller: mobileController,
                                  enabled: !isCustomerFieldDisabled,
                                  keyboardType: TextInputType.emailAddress,

                                  inputFormatters: [
                                    TextInputFormatter.withFunction((oldValue, newValue) {
                                      final text = newValue.text;

                                      // If input is only digits → Mobile number
                                      if (RegExp(r'^\d*$').hasMatch(text)) {
                                        if (text.length > 10) {
                                          return oldValue; // block extra digits
                                        }
                                      }
                                      // Otherwise → Email
                                      else {
                                        if (text.length > 50) {
                                          return oldValue; // block extra characters
                                        }
                                      }

                                      return newValue;
                                    }),
                                  ],

                                  onChanged: (value) {
                                    setState(() {
                                      isPhoneValid = RegExp(r'^[0-9]{10}$').hasMatch(value);
                                      isEmailValid = RegExp(
                                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                      ).hasMatch(value);
                                    });
                                  },

                                  decoration: const InputDecoration(
                                    hintText: 'Add Mobile No or Email',
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    counterText: '',
                                  ),

                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF313131),
                                  ),
                                );

                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 18),

                // ---------------- ADD / CANCEL BUTTON (SAME LOGIC) ----------------
                InkWell(
                  onTap: isButtonDisabled
                      ? null
                      : () async {
                    // ---------- CANCEL ----------
                    if (showCustomerInput) {
                      // Only allow cancel if not disabled
                      if (isPaymentDone || redeemedValue > 0) return;

                      setState(() {
                        mobileController.clear();
                        showCustomerInput = false;
                        isPhoneValid = false;
                        isEmailValid = false;
                        isRedeemActive = false;
                      });

                      final offlineBox = Hive.box('offlineOrders');
                      final localKey = widget.offlineOrderId?.toString();

                      if (localKey != null) {
                        final existing = offlineBox.get(localKey);
                        if (existing != null) {
                          final d = Map<String, dynamic>.from(existing);
                          d["loyaltyContact"] = "";
                          offlineBox.put(localKey, d);
                        }
                      }

                      final localOrderId = widget.offlineOrderId;
                      if (localOrderId != null) {
                        await CustomerDisplayHelper.updateCustomerDisplay(localOrderId);
                      }
                      return;
                    }

                    // ---------- ADD ----------
                    if (!(isPhoneValid || isEmailValid)) return;

                    setState(() => isAddLoading = true);

                    final contact = mobileController.text.trim();
                    final orderId = widget.orderId ?? 0;

                    try {
                      final rawResponse = await orderBloc.addLoyaltyPoints(
                        orderId: orderId,
                        contact: contact,
                      );

                      final result = jsonDecode(rawResponse);
                      final data = result["data"];
                      final pts = int.tryParse(data["available_points"].toString()) ?? 0;

                      setState(() {
                        loyaltyData = data;
                        availablePoints = pts;
                        isRedeemActive = true;
                        showCustomerInput = true;
                      });

                      final offlineBox = Hive.box('offlineOrders');
                      final localKey = widget.offlineOrderId?.toString();

                      if (localKey != null) {
                        final existing = offlineBox.get(localKey);
                        if (existing != null) {
                          final d = Map<String, dynamic>.from(existing);
                          d["loyaltyContact"] = contact;
                          offlineBox.put(localKey, d);
                        }
                      }

                      final localOrderId = widget.offlineOrderId;
                      if (localOrderId != null) {
                        await CustomerDisplayHelper.updateCustomerDisplay(localOrderId);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Loyalty Points Added Successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Failed to add loyalty points. Please try again."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isAddLoading = false);
                    }
                  },
                  child: Container(
                    height: 44,
                    width: 126,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isButtonDisabled
                          ? Colors.grey.shade400       // 🔒 Disabled / Pending
                          : showCustomerInput
                          ? Colors.red             // ❌ Cancel
                          : const Color(0xFF3B4259),// ➕ Add
                      borderRadius: BorderRadius.circular(6),
                    ),

                    child: isAddLoading
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      showCustomerInput ? '× Cancel' : '+ Add',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )

              ],
            ),
          ),
          const SizedBox(width: 90),
          // User profile section with container and notification bell
          Row(
            children: [
              Container(
                height: ResponsiveLayout.getHeight(45),
                margin: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.getPadding(16),
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        themeHelper.themeMode == ThemeMode.dark ? 0.3 : 0.12,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: ResponsiveLayout.getRadius(18),
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userDisplayName ?? TextConstants.unknown)
                            .substring(0, 1),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userDisplayName ?? "",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                            fontSize: ResponsiveLayout.getFontSize(14),
                          ),
                        ),
                        Text(
                          userRole ?? TextConstants.unknown,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: ResponsiveLayout.getWidth(16)),
              Container(
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        themeHelper.themeMode == ThemeMode.dark ? 0.3 : 0.15,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(ResponsiveLayout.getPadding(10)),
                child: Icon(
                  Icons.notifications_outlined,
                  size: ResponsiveLayout.getIconSize(24),
                ),
              ),
            ],
          ),

          const SizedBox(width: 18),
        ],
      ),
    );
  }
  Widget _buildOrderSummary() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    int totalItems = orderItems.fold(0, (sum, item) {
      final name = item['item_name']?.toString().toLowerCase() ?? '';

      if (name == 'payout' || name == 'cashback') {
        return sum;
      }

      final qty = int.tryParse(item['items_count']?.toString() ?? '1') ?? 1;
      return sum + qty;
    });

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            left: ResponsiveLayout.getPadding(10),
            right: ResponsiveLayout.getPadding(10),
            bottom: ResponsiveLayout.getPadding(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Color(0xFFFFFFFF),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
              left: ResponsiveLayout.getPadding(12),
              right: ResponsiveLayout.getPadding(10),
              bottom: ResponsiveLayout.getPadding(15),
              top: ResponsiveLayout.getPadding(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// LEFT — Order ID
                  Row(
                    children: [
                      Text(
                        '${TextConstants.orderId}: ',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(16),
                        ),
                      ),
                      Text(
                        '# $orderId',
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(16),
                        ),
                      ),
                    ],
                  ),

                  /// PUSH RIGHT CONTENT TO END
                  const Spacer(),

                  /// RIGHT — Date + Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: ResponsiveLayout.getIconSize(20),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white      // Dark mode color
                            : const Color(0xFF4C5F7D), // Light mode color
                      ),

                      const SizedBox(width: 6),
                      Text(
                        _displayDate,
                        style: TextStyle(
                          fontSize: ResponsiveLayout.getFontSize(13),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// Divider
                      Container(
                        height: ResponsiveLayout.getHeight(16),
                        width: 1,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54 // slightly lighter for dark mode
                            : Colors.grey.shade400,
                      ),

                      const SizedBox(width: 8),

                      /// Time
                      Text(
                        _displayTime,
                        style: TextStyle(
                          fontSize: ResponsiveLayout.getFontSize(13),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    ],
                  ),
                ],
              ),

              Container(
                height: 30,
                margin: EdgeInsets.fromLTRB(
                  ResponsiveLayout.getPadding(2),
                  ResponsiveLayout.getPadding(5),
                  ResponsiveLayout.getPadding(2),
                  0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE6464),
                  borderRadius: BorderRadius.circular(4),
                ),
                child:Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Item Name
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Item Name",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14), // SAME
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),

                    // Unit
                    Expanded(
                      flex: 1,
                      child: Text(
                        "Unit",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                    // Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Price",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveLayout.getFontSize(14), // SAME
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),



              SizedBox(height: ResponsiveLayout.getHeight(8)),
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(ResponsiveLayout.getRadius(10)),
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.secondaryBackground
                        : Colors.white,
                    border: Border.all(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.borderColor
                            : Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: orderItems.length,
                    itemBuilder: (context, index) {
                      return _buildOrderItem(index);
                    },
                  )

                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(6)),
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                ),
                margin: EdgeInsets.only(top: ResponsiveLayout.getPadding(10)),
                child: AnimatedSize(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showFullSummary
                      ? Container(
                    height: ResponsiveLayout.getHeight(205),
                    margin: EdgeInsets.only(
                      top:  ResponsiveLayout.getPadding(0),
                      right: ResponsiveLayout.getPadding(1),
                      left: ResponsiveLayout.getPadding(1),
                      bottom: ResponsiveLayout.getPadding(3),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(8), topLeft: Radius.circular(8)),
                      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.orderPanelSummary : Colors.white,
                      boxShadow: [
                        // Shadow at the top
                        BoxShadow(
                          color:
                          themeHelper.themeMode == ThemeMode.dark
                              ? Color(0xFFF0F0F0).withOpacity(
                              0.15) // dark mode top shadow
                              : Colors.black.withOpacity(
                              0.15), // light mode top shadow
                          // color: Colors.black.withOpacity(0.15),
                          offset: Offset(0,
                              -4), // 0 horizontal, -4 vertical (up)
                          blurRadius: 6,
                          spreadRadius: -0.5,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.getPadding(8),
                    ),
                    child: isSummaryLoading
                        ? Center(child: CircularProgressIndicator())
                        : ScrollConfiguration(
                      behavior: NoScrollbarBehavior().copyWith(overscroll: false),
                      // thumbVisibility: true,
                      // radius: Radius.circular(10),
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _buildOrderCalculation(
                                TextConstants.grossTotal,
                                '${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}',
                                isTotal: true),
                            _buildOrderCalculation(
                                TextConstants.discountText,
                                '-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}',
                                isDiscount: true),

                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: themeHelper.themeMode ==
                                      ThemeMode.dark
                                      ? [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.7),
                                    Colors.white.withOpacity(0.1),
                                  ]
                                      : [
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.7),
                                    Colors.black.withOpacity(0.1),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: DottedLine(
                                dashLength: 6,
                                dashGapLength: 4,
                                lineThickness: 1,
                                direction: Axis.horizontal,
                                dashColor: themeHelper.themeMode ==
                                    ThemeMode.dark
                                    ? Colors.white
                                    : Colors
                                    .black, // ✅ ensures gradient works correctly
                              ),
                            ),

                            _buildOrderCalculation(
                              TextConstants.NetTotal,
                              '${TextConstants.currencySymbol}${NetTotal.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                                TextConstants.taxText,
                                '${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}'),
                            if(merchantDiscount>0)
                              _buildOrderCalculation(
                                  TextConstants.merchantDiscount,
                                  '-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}'),

                            if (cashbackFee > 0)
                              _buildOrderCalculation(
                                TextConstants.cashbackFee,
                                '${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}',
                              ),

                            /// Service Charges
                            _buildOrderCalculation(
                                TextConstants.servicecharges,
                                '${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}'),

                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: themeHelper.themeMode ==
                                      ThemeMode.dark
                                      ? [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.7),
                                    Colors.white.withOpacity(0.1),
                                  ]
                                      : [
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.7),
                                    Colors.black.withOpacity(0.1),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: DottedLine(
                                dashLength: 6,
                                dashGapLength: 4,
                                lineThickness: 1,
                                direction: Axis.horizontal,
                                dashColor: themeHelper.themeMode ==
                                    ThemeMode.dark
                                    ? Colors.white
                                    : Colors
                                    .black, // ✅ ensures gradient works correctly
                              ),
                            ),


                            _buildOrderCalculation(
                                TextConstants.netPayable,
                                '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                                isTotal: true),

                            if (redeemedValue > 0)
                              _buildOrderCalculation(
                                "Redeemed Amount",
                                '-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}',
                              ),
                            _buildOrderCalculation(
                              "Pay by Card",
                              '${TextConstants.currencySymbol}${payByCard.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                                TextConstants.payByCash,
                                '${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}'),
                            _buildOrderCalculation(
                              "Pay by EBT",
                              '${TextConstants.currencySymbol}${payByEbt.toStringAsFixed(2)}',
                            ),

                            _buildOrderCalculation(
                                TextConstants.payByOther,
                                '${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.tenderAmount,
                                '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.change,
                                '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ),
                  )
                      : SizedBox.shrink(),
                ),
              ),
              GestureDetector(
                onTap: _toggleSummary,
                child: Container(
                  height: 32,
                  margin: EdgeInsets.only(
                    top: _showFullSummary
                        ? ResponsiveLayout.getPadding(0)
                        : ResponsiveLayout.getPadding(0),
                    right: ResponsiveLayout.getPadding(1),
                    left: ResponsiveLayout.getPadding(1),
                    bottom: ResponsiveLayout.getPadding(3),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(ResponsiveLayout.getRadius(6)),
                      bottomLeft: Radius.circular(ResponsiveLayout.getRadius(6)),
                      topLeft: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(6)),
                      topRight: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(6)),
                    ),
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Color(0xFF32343E)
                        : const Color(0xFFEAEDFE),

                    /// ⭐ ADD THIS SHADOW
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            themeHelper.themeMode == ThemeMode.dark ? 0.3 : 0.15),
                        offset: const Offset(0, 3),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),

                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(18),
                    vertical: ResponsiveLayout.getPadding(0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${TextConstants.totalItemsText}: $totalItems",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            _showFullSummary
                                ? ' ${TextConstants.netPayable} : ${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}'
                                : '${TextConstants.netPayable} ${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark
                                  : ThemeNotifier.textLight,
                            ),
                          ),
                          SizedBox(width: ResponsiveLayout.getPadding(8)),
                          Icon(
                            _showFullSummary
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 0, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  final OrderHelper orderHelper =
  OrderHelper(); // Helper instance to manage orders

  // Build #1.0.10: Fetches order items for the active order
  Future<void> fetchOrderItems() async {
    if (orderHelper.activeOrderId != null) {
      var orderData =
      await orderHelper.getOrderById(orderHelper.activeOrderId!);
      List<Map<String, dynamic>> items = await orderHelper
          .getOrderItems(orderData.first[AppDBConst.orderServerId]);

      //Build #1.0.29:  Fetch the orderServerId from the database



      if (orderData.isNotEmpty) {
        setState(() {
          orderId = orderData.first[AppDBConst.orderServerId] as int? ?? 0;
          orderDateTime =
          "${orderData.first[AppDBConst.orderDate]} ${orderData.first[AppDBConst.orderTime]}";
          discount =
              (orderData.first[AppDBConst.orderDiscount] as num?)?.toDouble() ??
                  0.0; // Fetch discount
          merchantDiscount =
              (orderData.first[AppDBConst.merchantDiscount] as num?)
                  ?.toDouble() ??
                  0.0; // Build #1.0.80
          tax =
              (orderData.first[AppDBConst.orderTax] as num?)?.toDouble() ?? 0.0;
          orderTotal =
              (orderData.first[AppDBConst.orderTotal] as num?)?.toDouble() ??
                  0.0; // Build #1.0.80
          cashbackFee = (orderData.first[AppDBConst.orderCashbackFee] as num?)
              ?.toDouble() ??
              0.0;
          orderStatus = (orderData.first[AppDBConst.orderStatus] as String?) ??
              TextConstants.processing; // Build  #1.0.177
          if (kDebugMode) {
            print(
                "Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${orderHelper.activeOrderId}, Time: $orderDateTime");
          }
        });
      } else {
        if (kDebugMode) {
          print(
              "No orderServerId found for activeOrderId: ${orderHelper.activeOrderId}");
        }
      }

      /// Call fetch payment details by order id API call after order id assigned here above, otherwise we get null order id
      _fetchPaymentsByOrderId();

      // Build #1.0.29: Calculate balance amount from order items
      for (var item in items) {
        double price = (item[AppDBConst.itemPrice] as num).toDouble();
        int count = item[AppDBConst.itemCount] as int;
        total += price * count;
      }

      if (kDebugMode) {
        print("##### fetchOrderItems :$items");
        print("Calculated balance amount: $total");
        print(
            "##### DEBUG 1001 orderTotal: $orderTotal, payByCash: $payByCash");
      }

      setState(() {
        orderItems = items;
        grossTotal = GlobalUtility.getGrossTotal(
            orderItems); // Build #1.0.138: GrossTotal calculation form global class for code re usability
        balanceAmount =
            orderTotal; // Build #1.0.138: using orderTotal from API value #No need our calculation here
        tenderAmount = 0.0; // Reset for new order
        changeAmount = 0.0; // Reset for new order
        paidAmount = 0.0; // Reset for new order
      });
    } else {
      setState(() {
        orderItems.clear();
        balanceAmount = 0.0;
        tenderAmount = 0.0; // Reset
        changeAmount = 0.0; // Reset
        paidAmount = 0.0; // Reset
        discount = 0.0; // Reset discount
      });
    }
  }
  Widget _buildOrderItem(int index) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final orderItem = orderItems[index];

    final String itemType =
        orderItem['item_type']?.toString().toLowerCase() ?? '';

    final bool isVariant =
        (orderItem['is_variant'] == true) ||
            (itemType == 'variant') ||
            (orderItem['variation_name']
                ?.toString()
                .trim()
                .isNotEmpty ?? false) ||
            ((orderItem['variation_id'] ?? 0) != 0);

    final bool isEbtEligible = orderItem['is_ebt_eligible'] == true;

    final String itemName = orderItem['item_name']?.toString() ?? '';
    final double itemPrice = (orderItem['item_price'] ?? 0).toDouble();
    final int itemCount = (orderItem['items_count'] ?? 0).toInt();

    final double originalTotal =
    (orderItem['item_sum_price'] ?? 0).toDouble();

    // --------------------------------------------------
    // ✅ DISCOUNT EXTRACTION
    // --------------------------------------------------
    final String discountType =
        orderItem['discount_type']?.toString() ?? '';

    final double autoDiscount =
    discountType.isEmpty || discountType == 'auto'
        ? (orderItem['auto_discount'] ?? 0).toDouble()
        : 0.0;

    final double comboDiscount =
    discountType == 'combo'
        ? (orderItem['auto_discount'] ?? 0).toDouble()
        : 0.0;

    final double multipackDiscount =
    discountType == 'multipack'
        ? (orderItem['auto_discount'] ?? 0).toDouble()
        : 0.0;

    final bool isComboDiscount = comboDiscount > 0;
    final bool isMultipackDiscount = multipackDiscount > 0;
    final bool hasAutoDiscount = autoDiscount > 0;

    // --------------------------------------------------
    // ✅ FINAL PRICE
    // --------------------------------------------------
    final double finalItemTotal =
        originalTotal - autoDiscount - comboDiscount - multipackDiscount;

    final bool isPayout = itemType.contains(TextConstants.payoutText);
    final bool isCoupon = itemType.contains(TextConstants.couponText);
    final bool isCashback = itemType.contains("cashback");
    final bool isPayoutOrCoupon = isPayout || isCoupon || isCashback;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// LEFT + CENTER COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ROW 1 — NAME + QTY
                      SizedBox(
                        height: 16,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(
                                itemName.length > 30
                                    ? '${itemName.substring(0, 30)}...'
                                    : itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.bold,
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? ThemeNotifier.textDark
                                      : ThemeNotifier.textLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            if (!isPayoutOrCoupon)
                              Text(
                                "${TextConstants.currencySymbol}${itemPrice.toStringAsFixed(2)} x $itemCount",
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.0,
                                  fontWeight: FontWeight.bold,
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? ThemeNotifier.textDark
                                      : Colors.black87,
                                ),
                              ),

                          ],
                        ),
                      ),

                      /// ROW 2 — BADGES
                      if (isEbtEligible ||
                          isVariant ||
                          isComboDiscount ||
                          isMultipackDiscount)
                        SizedBox(
                          height: 12,
                          child: Row(
                            children: [

                              if (isEbtEligible)
                                Container(
                                  height: 14,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    "EBT",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),


                              if (isVariant) ...[
                                const SizedBox(width: 5),
                                SvgPicture.asset(
                                  SvgUtils.variationIcon,
                                  height: 8,
                                  width: 8,
                                ),
                              ],

                              if (isComboDiscount) ...[
                                const SizedBox(width: 5),
                                _discountBadge("MM", Colors.orange),
                              ],

                              if (isMultipackDiscount) ...[
                                const SizedBox(width: 5),
                                _discountBadge("MP", Colors.blue),
                              ],
                            ],
                          ),
                        ),

                      /// ROW 3 — AUTO DISCOUNT
                      if (hasAutoDiscount && !isPayoutOrCoupon)
                        SizedBox(
                          height: 12,
                          child: Text(
                            "Auto Discount: -${TextConstants
                                .currencySymbol}${autoDiscount.toStringAsFixed(
                                2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.0,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      /// ROW 4 — COMBO DISCOUNT
                      if (isComboDiscount && !isPayoutOrCoupon)
                        SizedBox(
                          height: 12,
                          child: Text(
                            "Combo Discount: -${TextConstants
                                .currencySymbol}${comboDiscount.toStringAsFixed(
                                2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.0,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      /// ROW 5 — MULTIPACK DISCOUNT
                      if (isMultipackDiscount && !isPayoutOrCoupon)
                        SizedBox(
                          height: 12,
                          child: Text(
                            "Multipack Discount: -${TextConstants
                                .currencySymbol}${multipackDiscount
                                .toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.0,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                /// RIGHT PRICE COLUMN
                SizedBox(
                  //width: 55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// FINAL PRICE
                      SizedBox(
                        height: 16,
                        child: Text(
                          isCoupon || isPayout
                              ? "-${TextConstants.currencySymbol}${originalTotal
                              .abs().toStringAsFixed(2)}"
                              : "${TextConstants.currencySymbol}${finalItemTotal
                              .toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: isCoupon || isPayout
                                ? Colors.red
                                : themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ),
                      ),

                      /// STRIKED ORIGINAL
                      SizedBox(
                        height: 12,
                        child: ((hasAutoDiscount ||
                            isComboDiscount ||
                            isMultipackDiscount) &&
                            !isPayoutOrCoupon)
                            ? Text(
                          "${TextConstants.currencySymbol}${originalTotal
                              .toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.0,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        /// ✅ DIVIDER — NOW IT WILL SHOW
        Divider(
          height: 1,
          thickness: 0.8,
          color: themeHelper.themeMode == ThemeMode.dark
              ? Colors.black26
              : Colors.grey.shade300,
        ),
      ],
    );
  }

  /// 🔹 Reusable badge widget
  Widget _discountBadge(String text, Color color) {
    return Container(
      height: 16, // 👈 increases badge height
      padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3 // 👈 increases inner height
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 7,
          height: 1.0, // 👈 increases text line height
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  FontWeight labelFontWeight = FontWeight.w500;
  FontWeight amountFontWeight = FontWeight.w600;

  Widget _buildOrderCalculation(String label, String amount,
      {bool isTotal = false, bool isDiscount = false}) {
    // //Build #1.0.34: Update the amount based on the label
    final themeHelper = Provider.of<ThemeNotifier>(context);
    if (label == TextConstants.tenderAmount) {
      amount =
      '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}';
    } else if (label == TextConstants.change) {
      amount =
      '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}';
    } else if (label == TextConstants.total) {
      amount =
      '${TextConstants.currencySymbol}${(grossTotal - discount).toStringAsFixed(2)}'; // Adjust total with discount
    } else if (label == TextConstants.payByCash) {
      amount =
      '${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}'; //Build #1.0.99: updated from api
    } else if (label == TextConstants.payByOther) {
      amount =
      '${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}';
    } else if (label == TextConstants.discountText) {
      amount =
      '-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}'; // Display discount from DB
    }

    // Determine colors and icons based on label
    Color labelColor = themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.textDark
        : (isTotal ? Colors.black87 : Colors.grey[700]!);
    Color amountColor = themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.textDark
        : (isTotal ? Colors.black87 : Colors.grey[800]!);
    Widget? leadingIcon;

    if (isTotal) {
      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.textDark
          : Colors.black87;
    } else if (label == TextConstants.discountText || isDiscount) {
      labelColor = Colors.green[600]!;
      amountColor = Colors.green[600]!;

    } else if (label == TextConstants.merchantDiscount) {
      labelColor = Colors.blue[600]!;
      amountColor = Colors.blue[600]!;

    }
    // ---------------- CASHBACK ( #55CBCD ) ----------------
    else if (label == TextConstants.cashbackFee ||
        label.toLowerCase().contains("cashback")) {
      labelColor = const Color(0xFF55CBCD);
      amountColor = const Color(0xFF55CBCD);
      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update your asset name if needed
        colorFilter: const ColorFilter.mode(Color(0xFF55CBCD), BlendMode.srcIn),
      );
    }

// ---------------- SERVICE CHARGE ( #0A122D ) ----------------
    else if (label == TextConstants.servicecharges ||
        label.toLowerCase().contains("service")) {
      labelColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF)   // White for dark mode
          : const Color(0xFF0A122D);  // Dark blue for light mode

      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF)   // White in dark mode
          : const Color(0xFF0A122D);  // Dark blue in light mode

      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update asset name
        colorFilter: const ColorFilter.mode(Color(0xFF0A122D), BlendMode.srcIn),
      );
    }
    // ---------------- NET TOTAL ( #373535 ) ----------------
    else if (label == TextConstants.NetTotal ||
        label.toLowerCase().contains("net total")) {
      labelColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF)   // White in dark mode
          : const Color(0xFF373535);  // Dark grey in light mode


      amountColor = themeHelper.themeMode == ThemeMode.dark
          ? const Color(0xFFFFFFFF)   // White in dark mode
          : const Color(0xFF373535);  // Dark blue in light mode

      // Make NET TOTAL bold
      labelFontWeight = FontWeight.w900;
      amountFontWeight = FontWeight.w900;

      leadingIcon = SvgPicture.asset(
        'assets/svg/net_total.svg',
        colorFilter: const ColorFilter.mode(Color(0xFF373535), BlendMode.srcIn),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
          vertical: ResponsiveLayout.getPadding(
              2)), //ResponsiveLayout.getResponsiveMargin(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
              ],

              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  fontSize: ResponsiveLayout.getFontSize(isTotal ? 14 : 12),
                  color: labelColor,
                ),
              ),
              // ---------------- DELETE ICON FOR DISCOUNT ----------------
              if ((label == TextConstants.discountText || isDiscount)
                  && discount > 0
                  && redeemedValue == 0)
                GestureDetector(
                  onTap: isPaymentStarted ? null : () async => await _removeAppliedCoupon(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.delete_forever,
                      color: isPaymentStarted ? Colors.grey : Colors.red,
                      size: 20,
                    ),
                  ),
                ),

              if (label == "Redeemed Amount" && redeemedValue > 0)
                GestureDetector(
                  onTap: isPaymentStarted
                      ? null
                      : () async {
                    setState(() => redeemedValue = 0);
                    await _removeRedeemedAmount();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.delete_forever,
                      color: isPaymentStarted ? Colors.grey : Colors.red,
                      size: 20,
                    ),
                  ),
                ),


            ],
          ),
          Row(
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  fontSize: ResponsiveLayout.getFontSize(isTotal ? 14 : 12),
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _removeRedeemedAmount() async {
    // 🔴 Contact is mandatory for API
    if (mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Customer contact not found."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String contact = mobileController.text.trim();
    final int order =
        widget.orderId ?? widget.offlineOrderId ?? 0;

    setState(() => isSummaryLoading = true);

    try {
      // 🔥 API is the SOURCE OF TRUTH
      final rawRes = await OrderRepository().removeLoyaltyPoints(
        orderId: order,
        contact: contact,
      );

      final result = jsonDecode(rawRes);

      if (result["success"] != true) {
        throw Exception(result["message"] ?? "Unable to remove points");
      }

      final data = result["data"];

      // 🧠 Update UI strictly from API response
      setState(() {
        redeemedValue = 0;
        isRedeemAppliedFromApi = false;

        /// API-driven balance
        balanceAmount =
            (data["order_total"] as num?)?.toDouble() ?? balanceAmount;

        /// Keep available points from API
        availablePoints =
            (data["available_points"] as num?)?.toInt() ?? availablePoints;
      });

      // 🧹 FORCE DELETE FROM HIVE
      final String orderKey = order.toString();
      await removeOfflineOrderRedeem(orderKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Redeemed points removed successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (kDebugMode) {
        print("🧹 Redeem removed → API + UI + Hive");
      }
    } catch (e) {
      print("❌ Remove Loyalty Points Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to remove redeemed points. Try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSummaryLoading = false);
    }
  }


  String _getPaymentHeader() {
    switch (selectedPaymentMethod) {
      case TextConstants.cash:
        return TextConstants.cashPayment;

      case TextConstants.card:
        return TextConstants.cardPayment;

      case TextConstants.wallet:
        return TextConstants.walletPayment;

      case TextConstants.ebtText:
        return TextConstants.ebtPayment;

      default:
        return TextConstants.cashPayment;
    }
  }

  void _resetAmount() {
    _rawAmount = 0;
    amountController.text = '${TextConstants.currencySymbol}0.00';
    _amountErrorText = null;
    _isAmountEntered = false;
  }
  Widget _buildPaymentSection() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    bool hasEbtItem = orderItems.any((item) => item["is_ebt_eligible"] == true);
    return Container(
      // Remove the fixed height constraint to let it match the left container
      margin: EdgeInsets.only(
        bottom: ResponsiveLayout.getPadding(0),
        right: ResponsiveLayout.getPadding(10),
        top: ResponsiveLayout.getPadding(2),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ResponsiveLayout.getRadius(10)),
          topRight: Radius.circular(ResponsiveLayout.getRadius(10)),
          bottomLeft: Radius.circular(ResponsiveLayout.getRadius(0)),
          bottomRight: Radius.circular(ResponsiveLayout.getRadius(0)),
        ),

        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground
            : Color(0xFFFFFFFF),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: ResponsiveLayout.getPadding(18),
          right: ResponsiveLayout.getPadding(18),
          top: ResponsiveLayout.getPadding(15),
          bottom: ResponsiveLayout.getPadding(18), // Add bottom padding
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment:
          CrossAxisAlignment.start, // Changed to start for better alignment
          children: [
            Expanded(
              flex: 3,
              child: Column(
                // Remove SingleChildScrollView to avoid height issues
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                MainAxisAlignment.start, // Changed from spaceEvenly
                children: [

                  SizedBox(height: ResponsiveLayout.getHeight(6)),

                  // Payment methods section
                  Expanded(
                    // Make this expand to fill available space
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cash payment section - make it flexible
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                // Make the payment container expand to fill space
                                child: Container(
                                  width: double.infinity, // Take full width
                                  padding: EdgeInsets.only(
                                    left: ResponsiveLayout.getPadding(16),
                                    right: ResponsiveLayout.getPadding(16),
                                    top: ResponsiveLayout.getPadding(0),
                                    bottom: ResponsiveLayout.getPadding(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    themeHelper.themeMode == ThemeMode.dark
                                        ? Color(0xFF1F1D2B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveLayout.getRadius(8)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: ResponsiveLayout.getHeight(60),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: ResponsiveLayout.getPadding(16),
                                            ),
                                            decoration: BoxDecoration(
                                              color: themeHelper.themeMode == ThemeMode.dark
                                                  ? const Color(0xFF40424F)
                                                  : const Color(0xFFF9FBFF),
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x22000000),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                /// 🔵 LABEL
                                                Text(
                                                  "Tender Amount :",
                                                  style: TextStyle(
                                                    fontSize: ResponsiveLayout.getFontSize(18),
                                                    fontWeight: FontWeight.w600,
                                                    color: themeHelper.themeMode == ThemeMode.dark
                                                        ? Colors.white
                                                        : const Color(0xFF0D47A1),
                                                  ),
                                                ),

                                                const SizedBox(width: 16),

                                                /// 🔹 AMOUNT FIELD
                                                Expanded(
                                                  child: Container(
                                                    height: ResponsiveLayout.getHeight(44),
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: ResponsiveLayout.getPadding(12),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: themeHelper.themeMode == ThemeMode.dark
                                                          ? const Color(0xFF1F1D2B)
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: _amountErrorText != null
                                                            ? Colors.red
                                                            : themeHelper.themeMode == ThemeMode.dark
                                                            ? Colors.white24
                                                            : const Color(0xFFB6C6E3),
                                                      ),
                                                    ),
                                                    alignment: Alignment.centerRight,
                                                    child: TextField(
                                                      controller: amountController,
                                                      keyboardType:
                                                      const TextInputType.numberWithOptions(decimal: true),
                                                      enabled: balanceAmount >= 0,
                                                      readOnly: balanceAmount < 0, // 🔒 extra safety
                                                      textAlign: TextAlign.right,
                                                      decoration: InputDecoration(
                                                        border: InputBorder.none,
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.zero,
                                                        hintText: '${TextConstants.currencySymbol}0.00',
                                                        hintStyle: TextStyle(
                                                          color: themeHelper.themeMode == ThemeMode.dark
                                                              ? Colors.white38
                                                              : Colors.grey[400],
                                                        ),
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: ResponsiveLayout.getFontSize(22),
                                                        fontWeight: FontWeight.bold,
                                                        color: themeHelper.themeMode == ThemeMode.dark
                                                            ? const Color(0xFFFFFFFF)
                                                            : const Color(0xFF1F1D2B),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),


                                          /// 🔴 ERROR TEXT BELOW FIELD
                                          if (computedNetPayable > 0 && _amountErrorText != null)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: ResponsiveLayout.getPadding(4),
                                                left: ResponsiveLayout.getPadding(12),
                                              ),
                                              child: Text(
                                                _amountErrorText!,
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: ResponsiveLayout.getFontSize(12),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(8)),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(12)),

// NUM PAD - FIXED LOGIC
                                      Expanded(
                                        child: PaymentNumPad(
                                          numPadType: CustomTypeNumPad.payment,
                                          isDarkTheme: themeHelper.themeMode ==
                                              ThemeMode.dark,
                                          getPaidAmount: () =>
                                          amountController.text,
                                          balanceAmount: balanceAmount,
                                          onDigitPressed: (value) {
                                            int digit = value == '00' ? 0 : int.tryParse(value) ?? 0;

                                            int newAmount = value == '00'
                                                ? _rawAmount * 100
                                                : _rawAmount * 10 + digit;

                                            // ---------------- LIMITS ----------------
                                            int maxAmount;

                                            if (selectedPaymentMethod == TextConstants.ebtText) {
                                              maxAmount = (min(ebtTotal, balanceAmount) * 100).toInt();
                                            } else if (selectedPaymentMethod == TextConstants.card) {
                                              maxAmount = (balanceAmount * 100).toInt();
                                            } else {
                                              maxAmount = 999999999;
                                            }

                                            // ❗ Stop only if limit exceeded
                                            if (newAmount > maxAmount) return;

                                            // ---------------- UPDATE ----------------
                                            _rawAmount = newAmount;

                                            double displayValue = _rawAmount / 100.0;
                                            amountController.text =
                                            '${TextConstants.currencySymbol}${displayValue.toStringAsFixed(2)}';

                                            setState(() {
                                              _isAmountEntered = _rawAmount != 0;
                                            });
                                          },

                                          onClearPressed: () {
                                            _rawAmount = 0;
                                            amountController.text =
                                            '${TextConstants.currencySymbol}0.00';
                                            _amountErrorText = null;

                                            setState(() {
                                              _isAmountEntered = false;
                                            });
                                          },
                                          onDeletePressed: () {
                                            _rawAmount = _rawAmount ~/ 10;

                                            double displayValue =
                                                _rawAmount / 100.0;
                                            amountController.text =
                                            '${TextConstants.currencySymbol}${displayValue.toStringAsFixed(2)}';

                                            setState(() {
                                              _isAmountEntered =
                                                  _rawAmount != 0;
                                            });
                                          },
                                          onQuickAmountSelected: _onQuickAmountSelected,
                                          onPayPressed: () {
                                            String cleanAmount = amountController.text
                                                .replaceAll(TextConstants.currencySymbol, '')
                                                .trim();

                                            double amount = double.tryParse(cleanAmount) ?? 0.0;

                                            if (amount == 0.0 && computedNetPayable > 0) {
                                              setState(() {
                                                _amountErrorText = TextConstants.amountValidation;
                                              });
                                              return;
                                            }

                                            _amountErrorText = null;

                                            if (selectedPaymentMethod == TextConstants.card) {
                                              print("💳 Opening Sunmi ONLY after Pay click");

                                              _openSunmiSaleScreen(
                                                amount: amount,
                                                orderId: (widget.orderId ?? widget.offlineOrderId).toString(),
                                              );
                                              _rawAmount = 0;
                                              amountController.text = '${TextConstants.currencySymbol}0.00';
                                              _isAmountEntered = false;
                                              return;
                                            }

                                            _callCreatePaymentAPI();

                                            _rawAmount = 0;
                                            amountController.text = '${TextConstants.currencySymbol}0.00';
                                            _isAmountEntered = false;
                                          },

                                          isLoading: isLoading,
                                        ),
                                      ),

                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveLayout.getWidth(16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right side - Payment mode selection
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // SizedBox(height: ResponsiveLayout.getHeight(3)),

                  SizedBox(height: ResponsiveLayout.getHeight(3)),

                  // Payment mode buttons - make flexible
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveLayout.getPadding(8)),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? const Color(0xFF303136)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveLayout.getRadius(8),
                        ),
                        border: Border.all(
                          color: const Color(0x2E4C5F7D), // #4C5F7D2E
                          width: 2, // adjust as needed
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black12,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Net Payable
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(ResponsiveLayout.getPadding(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // Net Payable
                                  Container(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 6,
                                      bottom: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? const Color(0xFF091B34) // dark background
                                          : const Color(0xFFF4FCF7), // light mode background
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border(
                                        top: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3EAE4C),
                                          width: 1,
                                        ),
                                        right: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3EAE4C),
                                          width: 1,
                                        ),
                                        bottom: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3EAE4C),
                                          width: 1,
                                        ),
                                        left: BorderSide.none, // 🚫 no left border
                                      ),
                                    ),
                                    child: _buildAmountDisplay(
                                      TextConstants.netPayable,
                                      '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                                      leftBarColor: const Color(0xFF3EAE4C),
                                      amountColor: themeHelper.themeMode == ThemeMode.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),

                                  SizedBox(height: ResponsiveLayout.getHeight(15)),


                                  // Balance Amount
                                  Container(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 6,
                                      bottom: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? const Color(0xFF091B34)
                                          : const Color(0xFFFCF4F4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border(
                                        top: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFFE85C43),
                                          width: 1,
                                        ),
                                        right: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFFE85C43),
                                          width: 1,
                                        ),
                                        bottom: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFFE85C43),
                                          width: 1,
                                        ),
                                        left: BorderSide.none, // 🚫 no left border
                                      ),
                                    ),
                                    child: _buildAmountDisplay(
                                      TextConstants.balanceAmount,
                                      '${TextConstants.currencySymbol}${balanceAmount.toStringAsFixed(2)}',
                                      leftBarColor: const Color(0xFFE85C43),
                                      amountColor: themeHelper.themeMode == ThemeMode.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),

                                  SizedBox(height: ResponsiveLayout.getHeight(15)),


                                  // EBT Amount
                                  Container(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 6,
                                      bottom: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? const Color(0xFF091B34)
                                          : const Color(0xFFF4F7FC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border(
                                        top: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3B7DDD),
                                          width: 1,
                                        ),
                                        right: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3B7DDD),
                                          width: 1,
                                        ),
                                        bottom: BorderSide(
                                          color: themeHelper.themeMode == ThemeMode.dark
                                              ? const Color(0xFF091B34)
                                              : const Color(0xFF3B7DDD),
                                          width: 1,
                                        ),
                                        left: BorderSide.none, // 🚫 no left border
                                      ),
                                    ),
                                    child: _buildAmountDisplay(
                                      TextConstants.EBTAmount,
                                      '${TextConstants.currencySymbol}${ebtTotal.toStringAsFixed(2)}',
                                      leftBarColor: const Color(0xFF3B7DDD),
                                      amountColor: themeHelper.themeMode == ThemeMode.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),

                                ],
                              ),
                            )

                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveLayout.getHeight(10)),

                  // Payment options - make flexible
                  Expanded(
                    flex: 1, // Give less space to payment options
                    child: Container(
                      width: double.infinity,
                      padding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? const Color(0xFF303136)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveLayout.getRadius(8),
                        ),
                        border: Border.all(
                          color: const Color(0x2E4C5F7D), // #4C5F7D2E
                          width: 1.5, // adjust as needed
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black12,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              /// ⭐ Redeem Points
                              _buildPaymentOptionButton(
                                TextConstants.redeemPoints,
                                "assets/redeem.png",
                                isActive: redeemedValue == 0 &&
                                    availablePoints > 0 &&
                                    isRedeemActive &&
                                    !isPaymentStarted &&
                                    !hasEbtItem && !isOrderPending,
                                onTap: () async {
                                  if (hasEbtItem) return; // block redeem

                                  if (!isRedeemActive) return;
                                  if (isOrderPending) {
                                    print("⛔ Redeem blocked: Order is pending");
                                    return;
                                  }


                                  // ⭐ Block redeem when partial payment has started
                                  if (isPaymentStarted) {
                                    print("⛔ Redeem blocked: Payment already started");
                                    return;
                                  }

                                  print("🔍 Current State Before Action:");
                                  print("➡ redeemedValue: $redeemedValue");
                                  print("➡ availablePoints: $availablePoints");
                                  print("➡ isMobileValid: $isMobileValid");
                                  print("➡ isEmailValid: $isEmailValid");

                                  if (redeemedValue > 0) {
                                    print("⛔ Redeem blocked: Already redeemedValue > 0");
                                    return;
                                  }

                                  if (availablePoints == 0) {
                                    print("⛔ Redeem blocked: No availablePoints");
                                    return;
                                  }

                                  if (!isMobileValid && !isEmailValid) {
                                    print("⛔ Invalid Contact: Neither mobile nor email valid");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Enter valid mobile number or email"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  print("📨 Opening RedeemPointsDialog...");
                                  final result = await showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => RedeemPointsDialog(apiData: loyaltyData!),
                                  );

                                  print("📨 Dialog Result: $result");

                                  if (result == null) {
                                    print("⛔ Dialog closed manually (null result)");
                                    return;
                                  }

                                  // User removed redeem
                                  if (result["remove"] == true) {
                                    print("🗑 REMOVE REDEEM SELECTED");
                                    setState(() {
                                      redeemedValue = 0;
                                      computedNetPayable = NetTotal;
                                    });

                                    final String orderKey =
                                        widget.orderId?.toString() ??
                                            widget.offlineOrderId?.toString() ??
                                            "";

                                    print("🗑 Removing redeem from Hive → OrderKey: $orderKey");

                                    if (orderKey.isNotEmpty) {
                                      await removeOfflineOrderRedeem(orderKey);
                                    }

                                    print("🧹 Redeem removed successfully.");
                                    return;
                                  }

                                  print("🟦 Processing API response...");

                                  final redeemApi = jsonDecode(result["apiResponse"]);
                                  print("📦 API Raw Response: $redeemApi");

                                  if (redeemApi == null) {
                                    print("❌ ERROR: Redeem API is null");
                                    return;
                                  }

                                  if (redeemApi["success"] != true) {
                                    print("❌ API reported failure: ${redeemApi["message"]}");
                                    return;
                                  }

                                  final data = redeemApi["data"];
                                  print("📦 Parsed Data: $data");

                                  // Extract values
                                  final double newRedeemValue =
                                      double.tryParse(data["redeem_amount"].toString()) ?? 0.0;

                                  final int usedPoints =
                                      int.tryParse(data["redeem_points"].toString()) ?? 0;

                                  final int newAvailablePoints =
                                      int.tryParse(data["available_points"].toString()) ??
                                          availablePoints;

                                  final double newBalanceAmount =
                                      double.tryParse(data["order_total"].toString()) ??
                                          computedNetPayable;

                                  print("🔢 Extracted API Values:");
                                  print("➡ newRedeemValue: $newRedeemValue");
                                  print("➡ usedPoints: $usedPoints");
                                  print("➡ newAvailablePoints: $newAvailablePoints");
                                  print("➡ newBalanceAmount: $newBalanceAmount");

                                  // Update UI
                                  setState(() {
                                    redeemedValue = newRedeemValue;
                                    availablePoints = newAvailablePoints;
                                    balanceAmount = newBalanceAmount;
                                    isRedeemAppliedFromApi = true;
                                  });

                                  print("🟩 UI Updated:");
                                  print("➡ redeemedValue: $redeemedValue");
                                  print("➡ availablePoints: $availablePoints");
                                  print("➡ balanceAmount: $balanceAmount");

                                  // Save to Hive
                                  final String orderKey =
                                      widget.orderId?.toString() ??
                                          widget.offlineOrderId?.toString() ??
                                          "";

                                  print("💾 Saving redeem to Hive → OrderKey: $orderKey");

                                  if (orderKey.isNotEmpty) {
                                    await updateOfflineOrderRedeem(
                                      orderKey,
                                      newRedeemValue,
                                      usedPoints,
                                      newAvailablePoints,
                                    );
                                  }

                                  print("💾 Redeem successfully saved to Hive");
                                  print("======== 🟩 REDEEM PROCESS COMPLETED 🟩 ========");
                                },

                              ),

                              const SizedBox(height: 10),
                              _buildCouponButton(
                                TextConstants.coupon,
                                "assets/coupon.png",
                                isActive: redeemedValue == 0 &&
                                    !isPaymentStarted &&
                                    !hasEbtItem &&
                                    !isOrderPending,
                                onTap: () {
                                  if (hasEbtItem ||
                                      redeemedValue > 0 ||
                                      isPaymentStarted ||
                                      isOrderPending) {
                                    return;
                                  }
                                  _openCouponPopup();
                                },
                              ),

                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCouponButton(
      String title,
      String iconPath, {
        required VoidCallback onTap,
        bool isActive = true,
      }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Container(
        height: 50,
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 24), // ✅ SAME PADDING
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFFEB910E) : Colors.grey,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 LEFT: TEXT
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isActive ? const Color(0xFFEB910E) : Colors.grey,
                ),
              ),
            ),

            // 🔹 RIGHT: ICON (ALIGNED)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFFEB910E) : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAppliedCoupon() async {
    if (widget.orderId == null || widget.orderId == 0) return;

    final offlineBox = Hive.box('offlineOrders');
    final localKey = widget.offlineOrderId?.toString(); // 🔥 LOCAL KEY ONLY

    if (localKey == null) {
      print("❌ No offlineOrderId found");
      return;
    }

    setState(() => isSummaryLoading = true);

    try {
      // 🔥 Remove coupon from Woo
      await orderBloc.removeCoupon(
        orderId: widget.orderId!,
        couponCode: "",
      );

      // 🔥 RESTORE ORIGINAL PAYABLE
      final double restoredPayable =
          grossTotal + oldTax - merchantDiscount + cashbackFee;

      setState(() {
        discount = 0.0;
        discountValue = 0.0;
        couponDiscount = 0.0;

        computedNetPayable = restoredPayable;
        balanceAmount = restoredPayable - tenderAmount;

        isCouponAppliedFromApi = false;
      });

      // ----------------- UPDATE HIVE -----------------
      final existing = offlineBox.get(localKey);
      if (existing != null) {
        final data = Map<String, dynamic>.from(existing);

        // 🧹 CLEAR COUPON DATA
        data.remove("appliedCoupon");
        data.remove("couponCode");
        data.remove("couponDiscount");
        data.remove("orderDiscount");

        // 🔥 SINGLE SOURCE OF TRUTH
        data["basePayableAmount"] = restoredPayable;
        data["wooTax"] = oldTax;
        data["couponRemoved"] = true;

        offlineBox.put(localKey, data);

        print("🗑 Coupon removed | Base payable restored = $restoredPayable");
      }

      await CustomerDisplayHelper.updateCustomerDisplay(
        widget.offlineOrderId!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Coupon removed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("❌ Error removing coupon: $e");
    } finally {
      setState(() => isSummaryLoading = false);
    }
  }

  void _openCouponPopup() {
    ScannerGuard.isCouponPopupOpen = true;

    final TextEditingController _couponCtrl = TextEditingController();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // THEME COLORS
    final Color dialogBg = isDark ? const Color(0xFF252837) : Colors.white;
    final Color borderColor =
    isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade300;
    final Color textPrimary = isDark ? Colors.white : Colors.black87;
    final Color textSecondary = isDark ? Colors.white70 : Colors.black54;
    final Color hintColor = isDark ? Colors.white38 : Colors.grey;
    final Color redPrimary = const Color(0xFFFD6464);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            ScannerGuard.isCouponPopupOpen = false;   // 🔓 enable scanner again
            return true;
          },
          child: BarcodeKeyboardListener(
            bufferDuration: const Duration(milliseconds: 600),
            onBarcodeScanned: (barcode) {
              final code = barcode.trim();
              print("🎯 Coupon QR/Barcode scanned → $code");

              _couponCtrl.text = code;  // ✅ Correct prefill
            },
            child: Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(26),
                width: MediaQuery.of(context).size.width * 0.30,
                decoration: BoxDecoration(
                  color: dialogBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(0.15),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Apply Coupon",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: redPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: _couponCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "Enter Coupon Code",
                        labelStyle: TextStyle(color: textSecondary),
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: redPrimary, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor, width: 1.0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: redPrimary,
                            side: BorderSide(color: redPrimary, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            ScannerGuard.isCouponPopupOpen = false; // CLOSE FLAG
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: redPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            final code = _couponCtrl.text.trim();

                            if (code.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Please enter coupon code"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            ScannerGuard.isCouponPopupOpen = false; // CLOSE FLAG
                            Navigator.pop(context);
                            await _applyCoupon(code);
                          },
                          child: const Text("Apply"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      ScannerGuard.isCouponPopupOpen = false;   // 🔓 Ensure scanner re-enables
    });
  }


  Future<void> _applyCoupon(String code) async {
    if (widget.orderId == null || widget.orderId == 0) return;

    setState(() => isSummaryLoading = true);

    try {
      final response = await orderBloc.applyCouponToOrder(
        orderId: widget.orderId!,
        couponCode: code,
      );

      // ----------- SHOW REPOSITORY ERROR MESSAGE -----------
      if (response == null) {
        final errorMessage = orderBloc.lastApplyCouponError.isNotEmpty
            ? orderBloc.lastApplyCouponError
            : "Invalid coupon or unable to apply coupon";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ---------------- SUCCESS FLOW ----------------
      oldTax = tax;

      final appliedDiscount = double.tryParse(response.discountTotal) ?? 0.0;
      final updatedTax = double.tryParse(response.totalTax) ?? tax;
      setState(() {
        discount = appliedDiscount;
        tax = updatedTax;
        NetTotal = grossTotal - discount;
        computedNetPayable =
            NetTotal + tax - merchantDiscount + cashbackFee;
        orderTotal = computedNetPayable;
        balanceAmount = computedNetPayable;
        isCouponAppliedFromApi = true; // 🔥 IMPORTANT
        if (loyaltyData != null) {
          loyaltyData = {
            ...loyaltyData!,
            "existing_net_payable": computedNetPayable,
            "new_payable_amount": computedNetPayable - redeemedValue,
          };
        }
      });

      final offlineBox = Hive.box('offlineOrders');
      final localKey = widget.offlineOrderId?.toString();

      if (localKey != null) {
        final existing = offlineBox.get(localKey);
        if (existing != null) {
          final data = Map<String, dynamic>.from(existing);
          data["orderDiscount"] = appliedDiscount;
          data["wooTax"] = updatedTax;
          offlineBox.put(localKey, data);
        }
      }

      // Customer Display
      final localOrderId = widget.offlineOrderId;
      if (localOrderId != null) {
        await CustomerDisplayHelper.updateCustomerDisplay(localOrderId);
      }

    } catch (e) {
      print("❌ ERROR applying coupon: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSummaryLoading = false);
    }
  }
  Widget _buildAmountDisplay(
      String label,
      String amount, {
        required Color leftBarColor,
        Color? amountColor = Colors.black,
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      width: MediaQuery.of(context).size.width * 0.240, // fixed width
      height: ResponsiveLayout.getHeight(63),           // fixed height
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔴 LEFT INDICATOR BAR (VERTICALLY CENTERED)
          Container(
            width: 4,
            height: ResponsiveLayout.getHeight(45), // slightly taller for visual effect
            decoration: BoxDecoration(
              color: leftBarColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: leftBarColor.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 📄 TEXT CONTENT
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(12),
                  fontWeight: FontWeight.w500,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: TextStyle(
                  fontSize: ResponsiveLayout.getFontSize(22),
                  fontWeight: FontWeight.w700,
                  color: amountColor ??
                      (themeHelper.themeMode == ThemeMode.dark
                          ? Colors.white
                          : const Color(0xFF222222)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildQuickAmountButton(String amount) {
    // Build #1.0.29: updated
    return GestureDetector(
      onTap: () {
        // Remove '$' and ensure the value is numeric
        String cleanAmount =
        amount.replaceAll(TextConstants.currencySymbol, '');
        double numericValue = double.parse(cleanAmount);
        amountController.text =
        '${TextConstants.currencySymbol} ${numericValue.toStringAsFixed(2)}';
        setState(() {});
      },
      child: Container(
        height: ResponsiveLayout.getHeight(43),
        width: ResponsiveLayout.getWidth(100),
        alignment: Alignment.center,
        padding: EdgeInsets.all(ResponsiveLayout.getPadding(5.0)),
        decoration: BoxDecoration(
          color: Color(0xFFE1F8DC),
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(5)),
        ),
        child: Text(
          amount,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveLayout.getFontSize(16),
              color: Color(0xFF518C3A)),
        ),
      ),
    );
  }

  // Helper method to generate exactly 5 unique quick amounts
  List<double> _generateQuickAmounts(double balanceAmount) {
    Set<double> amounts = {};

    // 1. Exact balance amount
    amounts.add(balanceAmount);

    // 2. Round up to next whole number
    amounts.add(balanceAmount.ceilToDouble());

    // 3. Round up to next 5
    double nextFive = ((balanceAmount / 5).ceil() * 5).toDouble();
    amounts.add(nextFive);

    // 4. Round up to next 10
    double nextTen = ((balanceAmount / 10).ceil() * 10).toDouble();
    amounts.add(nextTen);

    // Keep adding logical amounts until we have at least 5
    List<double> additionalAmounts = [];

    if (balanceAmount < 20) {
      additionalAmounts = [20.0, 25.0, 50.0, 100.0];
    } else if (balanceAmount < 50) {
      additionalAmounts = [50.0, 75.0, 100.0, 150.0];
    } else if (balanceAmount < 100) {
      additionalAmounts = [100.0, 150.0, 200.0, 250.0];
    } else if (balanceAmount < 500) {
      additionalAmounts = [
        ((balanceAmount / 50).ceil() * 50).toDouble(),
        ((balanceAmount / 100).ceil() * 100).toDouble(),
        ((balanceAmount / 100).ceil() * 100 + 100).toDouble(),
        ((balanceAmount / 100).ceil() * 100 + 200).toDouble(),
      ];
    } else {
      additionalAmounts = [
        ((balanceAmount / 100).ceil() * 100).toDouble(),
        ((balanceAmount / 500).ceil() * 500).toDouble(),
        ((balanceAmount / 1000).ceil() * 1000).toDouble(),
        ((balanceAmount / 1000).ceil() * 1000 + 500).toDouble(),
      ];
    }

    // Add additional amounts to ensure we have enough
    for (double amount in additionalAmounts) {
      amounts.add(amount);
      if (amounts.length >= 7) break; // Get more than 5 to have options
    }

    // Convert to sorted list and take exactly 5 unique values
    List<double> sortedAmounts = amounts.toList()..sort();

    // Ensure we always return exactly 5 amounts
    if (sortedAmounts.length >= 5) {
      return sortedAmounts.take(5).toList();
    } else {
      // If somehow we don't have 5, pad with increments
      while (sortedAmounts.length < 5) {
        double lastAmount = sortedAmounts.last;
        double increment = lastAmount < 100 ? 25 : 100;
        sortedAmounts.add(lastAmount + increment);
      }
      return sortedAmounts.take(5).toList();
    }
  }

  Widget _buildPaymentModeButton(
      String label,
      Widget iconWidget, {
        required LinearGradient gradient,
        required Color borderColor,
        Color? iconColor, // optional
        VoidCallback? onTap,
        bool isLoading = false,
        bool isDisabled = false,
      }) {
    double _scale = 1.0;
    final bool isEnabled = !isDisabled && !isLoading && onTap != null;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTapDown: isEnabled ? (_) {
            setState(() {
              _scale = 0.95; // press effect
            });
          } : null,
          onTapUp: isEnabled ? (_) {
            setState(() {
              _scale = 1.0;
            });
            if (onTap != null) onTap();
          } : null,
          onTapCancel: isEnabled ? () {
            setState(() {
              _scale = 1.0;
            });
          } : null,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Container(
                width: ResponsiveLayout.getWidth(178),
                height: ResponsiveLayout.getHeight(54),
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 4,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                    onTap: isEnabled ? onTap : null,
                    splashColor: Colors.white24,
                    highlightColor: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon inside circle or loading indicator
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: isLoading
                              ? SizedBox(
                            width: ResponsiveLayout.getIconSize(24),
                            height: ResponsiveLayout.getIconSize(24),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                            ),
                          )
                              : iconWidget,
                        ),
                        SizedBox(width: ResponsiveLayout.getWidth(12)),
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveLayout.getFontSize(18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionButton(
      String title,
      String iconPath, {
        required bool isActive,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      child: Container(
        height: 50,
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 24), // ✅ SAME PADDING
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF817ACC) : Colors.grey,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 LEFT: TEXT
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isActive ? const Color(0xFF817ACC) : Colors.grey,
                ),
              ),
            ),

            // 🔹 RIGHT: ICON (ALIGNED)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF817ACC) : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build #1.0.49: Added _handleVoidPayment for void payment api call code
  // Build #1.0.175: Modified _handleVoidPayment for partial void with API call
  void _handleVoidPayment(BuildContext context, {required bool isPartial}) {
    if (orderId == null || orderId == 0) {
      if (kDebugMode) {
        print(
            "_handleVoidPayment -> Invalid order ID: $orderId. Cannot void transaction.");
      }
      Navigator.of(context).pop(); // Close the dialog
      return;
    }

    // DEBUG: Log the void payment attempt
    if (kDebugMode) {
      print(
          "_handleVoidPayment -> Attempting to void payment for order ID: $orderId, paymentId: $paymentId, isPartial: $isPartial");
    }

    final request = VoidPaymentRequestModel(
      orderId: orderId!,
      //  paymentId: selectedPaymentMethod == TextConstants.wallet ? paymentId ?? "" : "", // Build #1.0.175: We have to pass paymentId for partial payment if void , then it will became processing
      paymentId: paymentId ?? "",
    );

    paymentBloc.voidPayment(request);
    StreamSubscription? subscription;
    subscription = paymentBloc.voidPaymentStream.listen((response) {
      if (!mounted) {
        if (kDebugMode) {
          print(
              "_handleVoidPayment -> Widget not mounted, skipping UI updates");
        }
        subscription?.cancel();
        return;
      }

      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print(
              "_handleVoidPayment -> Void successful: ${response.data!.message}");
        }

        // Update UI with response values for partial void
        setState(() {
          if (kDebugMode) {
            print("🔹 Before Update:");
            print(
                "orderTotal: $orderTotal, tenderAmount: $tenderAmount, balanceAmount: $balanceAmount, changeAmount: $changeAmount, orderStatus: $orderStatus");

            print("🔹 Response Data:");
            print(
                "orderTotal: ${response.data!.orderTotal}, totalPaid: ${response.data!.totalPaid}, remainingAmount: ${response.data!.remainingAmount}, orderStatus: ${response.data!.orderStatus}");
          }

          // Build #1.0.175: Call fetch payment details by order id API call
          _fetchPaymentsByOrderId(); // Refresh payments after successful payment
          /// Build #1.0.175: We are already updating all the values in _callCreatePaymentAPI method, after that again here updating again no need
          /// If required un-comment and use it!

          orderStatus = response.data!.orderStatus ?? orderStatus;


          if (kDebugMode) {
            print("✅ After Update:");
            print(
                "orderTotal: $orderTotal, tenderAmount: $tenderAmount, balanceAmount: $balanceAmount, changeAmount: $changeAmount, orderStatus: $orderStatus");
            print("payByCash: $payByCash, payByOther: $payByOther");
          }
        });

        if (Misc.showDebugSnackBar) {
          // Build #1.0.254
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data!.message ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Build #1.0.175: For partial void, stay on same screen; for complete void, navigate back
        Navigator.of(context).pop(); // Close void confirmation dialog
        Navigator.of(context).pop(); // Close payment dialog
        if (!isPartial) {
          if (kDebugMode) {
            print("_handleVoidPayment -> 1: ${response.data!.message}");
          }
          // Navigator.of(context).pop(TextConstants.refresh); // Navigate back for complete void
          OrderHelper.isOrderPanelLoaded = false;

          ///Update! on 9-Sep-25: asked by Shravan, void button click will result in cancelling of payment only, no need to change order status to cancelled now. If balance amount is changed then order will be pending else it will be processing
          // Navigator.pushReplacement(result: TextConstants.refresh,
          //   context,
          //   MaterialPageRoute(builder: (_) => FastKeyScreen()),
          // );
        }
      } else if (response.status == Status.ERROR) {
        if (kDebugMode) {
          print("_handleVoidPayment -> Void failed: ${response.data!.message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data!.message ?? '',
              style: const TextStyle(color: Colors.red),
            ),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Close the dialog
      }
      subscription?.cancel();
    });
  }

  // Build #1.0.175: New method for void order API call
  void _handleVoidOrder(BuildContext context) {
    if (orderId == null || orderId == 0) {
      if (kDebugMode) {
        print(
            "_handleVoidOrder -> Invalid order ID: $orderId. Cannot void order.");
      }
      Navigator.of(context).pop(); // Close the dialog
      return;
    }

    // DEBUG: Log the void order attempt
    if (kDebugMode) {
      print("_handleVoidOrder -> Attempting to void order ID: $orderId");
    }

    paymentBloc.voidOrder(orderId!);
    StreamSubscription? subscription;
    subscription = paymentBloc.voidOrderStream.listen((response) {
      if (!mounted) {
        if (kDebugMode) {
          print("_handleVoidOrder -> Widget not mounted, skipping UI updates");
        }
        subscription?.cancel();
        return;
      }

      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print(
              "_handleVoidOrder -> Void order successful: ${response.data!.message}");
        }

        // Reset UI values after voiding order
        setState(() {
          payByCash = 0.0;
          payByOther = 0.0;
          tenderAmount = 0.0;
          changeAmount = 0.0;
          balanceAmount = orderTotal; // Reset to original order total
          if (kDebugMode) {
            print(
                "_handleVoidOrder -> Balance reset to original order total: $balanceAmount");
          }
        });

        if (Misc.showDebugSnackBar) {
          // Build #1.0.254
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data!.message ?? TextConstants.voidSuccess,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Build #1.0.175
        Navigator.of(context).pop(); // Close void confirmation dialog
        Navigator.of(context).pop(); // Close payment dialog
        // Navigator.of(context).pop(TextConstants.refresh); // Navigate back to previous screen
        if (kDebugMode) {
          print("_handleVoidOrder -> 2: ${response.data!.message}");
        }

        ///This is for voiding completed payment
        OrderHelper.isOrderPanelLoaded = false;

        ///Update! on 9-Sep-25: asked by Shravan, void button click will result in cancelling of payment only, no need to change order status to cancelled now. If balance amount is changed then order will be pending else it will be processing
        // Navigator.pushReplacement(result: TextConstants.refresh,
        //   context,
        //   MaterialPageRoute(builder: (_) => FastKeyScreen()),
        // );
      } else if (response.status == Status.ERROR) {
        if (kDebugMode) {
          print(
              "_handleVoidOrder -> Void order failed: ${response.data!.message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data!.message ?? '',
              style: const TextStyle(color: Colors.red),
            ),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Close the dialog
      }
      subscription?.cancel();
    });
  }

  // --------------------
  void _showPartialPaymentDialog(BuildContext context, double amount) {
    if (kDebugMode) {
      print(
          "Showing Partial Payment Dialog with amount: $amount, Remaining Balance: $balanceAmount");
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        status: PaymentStatus.partial,
        mode: PaymentMode.cash,
        amount: amount,
        onVoid: () => showVoidExitConfirmation(context, true),
        /// pass true to change order status to pending, as this is partial payment , voided by user
        onNextPayment: () {
          if (kDebugMode) {
            print("Proceeding to next payment");
          }
          // Build #1.0.175: Call fetch payment details by order id API call
          _fetchPaymentsByOrderId(); // Refresh payments after successful payment
          Navigator.of(context).pop();
        },
      ),
    );
  }


  void _showPaymentDialog(
      BuildContext context,
      double amount, {
        double? changeAmount,
        required bool showChange,
        Map<String, dynamic>? couponResponse,
      }) async {
    if (kDebugMode) {
      print(
          "Showing Payment Dialog: amount=$amount, showChange=$showChange, changeAmount=$changeAmount");
    }
    final storeInfo = PinakaPreferences.getLoggedInStore();
    Future<void> _updateCustomerDisplayWelcome(
        Map<String, String?> storeInfo) async {
      if (storeInfo.isNotEmpty) {
        if (kDebugMode) {
          print(">>> Updating Customer Display with store info:");
          print("Store ID: ${storeInfo['storeId']}");
          print("Store Name: ${storeInfo['storeName']}");
          print("Store Logo URL: ${storeInfo['storeLogoUrl']}");
          print("Store Base URL: ${storeInfo['storeBaseUrl']}");
        }

        await CustomerDisplayHelper.updateWelcomeWithStore(
          storeInfo['storeId'] ?? '0',
          storeInfo['storeName'] ?? 'Store',
          storeLogoUrl: storeInfo['storeLogoUrl'] ?? '',
          storeBaseUrl: storeInfo['storeBaseUrl'] ?? '',
        );
      } else {
        if (kDebugMode) {
          print(">>> No store info found, showing default welcome screen");
        }
        await CustomerDisplayService.showWelcome();
      }
    }

    try {
      if (kDebugMode)
        print(">>> Showing THANK YOU screen before receipt options");
      await CustomerDisplayService.showThankYou();
    } catch (e) {
      if (kDebugMode) print(">>> Error showing Thank You screen: $e");
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        status: PaymentStatus.successful,
        mode: PaymentMode.cash,
        amount: amount,
        changeAmount: showChange ? changeAmount : null,
        couponResponse: couponResponse,
        onVoid: () {
          // Navigator.of(context).pop();
          showVoidExitConfirmation(context, true);
        },

        onNoReceipt: () async {
          if (kDebugMode) print(">>> NoReceipt pressed");
          await _updateCustomerDisplayWelcome(storeInfo);
          changeStatusToCompletedAndExit(false);
        },
        onDone: (selectedOption, {String? email}) async {
          if (kDebugMode) {
            print("DEBUG 0011 : $selectedOption, $email, ${email?.isNotEmpty}");
          }
          if (selectedOption == TextConstants.email &&
              email != null &&
              email.isNotEmpty) {
            if (orderId == null || orderId == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TextConstants.canNotSendEmail),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }

            paymentBloc.sendOrderDetails(orderId!, email);
            StreamSubscription? subscription;
            subscription =
                paymentBloc.sendOrderDetailsStream.listen((response) async {
                  subscription?.cancel();
                  if (kDebugMode)
                    print(">>> Email sent, updating customer display");
                  await _updateCustomerDisplayWelcome(storeInfo);
                  changeStatusToCompletedAndExit(true,
                      selectedOption: selectedOption);
                });
            return;
          }
          if (selectedOption == TextConstants.print && !Misc.disablePrinter) {
            if (kDebugMode) print(">>> Printing receipt");
            await _preparePrintTicket();
            await _printTicket(manual: true);
          }
          if (kDebugMode) print(">>> Returning to Welcome after Thank You");
          await _updateCustomerDisplayWelcome(storeInfo);
          changeStatusToCompletedAndExit(true, selectedOption: selectedOption);
        },
      ),
    );
  }
  Future<Map<String, dynamic>?> loadPrinterData() async {
    var printerDB = await PrinterDBHelper().getPrinterFromDB();
    if (printerDB.isEmpty) {
      if (kDebugMode) {
        print(">>>>> OrderSummaryScreen : printerDB is empty");
      }
      return null;
    }
    return printerDB.first;
  }
  Future _preparePrintTicket() async {
    if (kDebugMode) {
      print("OrderSummaryScreen _preparePrintTicket call print receipt");
    }

    var printerData = await loadPrinterData();
    var header = printerData?[AppDBConst.receiptHeaderText] ?? "";
    var footer = printerData?[AppDBConst.receiptFooterText] ?? "";
    var logo = printerData?[AppDBConst.receiptIconPath] ?? "";

    bytes = [];
    final ticket = await _printerSettings.getTicket();

    // -------------------------------
    // LOGO
    // -------------------------------
    final ByteData data;
    if (logo != "") {
      data = await GlobalUtility.fileToByteData(File(logo)) ??
          await rootBundle.load('assets/Bubbas_logo.png');
    } else {
      data = await rootBundle.load('assets/Bubbas_logo.png');
    }

    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes)!;
      img.Image thumbnail = img.copyResize(decodedImage, height: 280);
      img.Image originalImg =
      img.copyResize(decodedImage, width: 470, height: 280);
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;
      drawImage(originalImg, thumbnail, dstX: padding.toInt());
      var grayscaleImage = img.grayscale(originalImg);
      // bytes += ticket.imageRaster(grayscaleImage, align: PosAlign.center);
    }

    // -------------------------------
    // HEADER
    // -------------------------------
    var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
    var storeId = "${merchantDetails?[AppDBConst.storeId]}";
    var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";

    var storeDetails = await AssetDBHelper.instance.getStoreDetails();
    var storeName = "${storeDetails?.name}";
    var address = "${storeDetails?.address},";
    var cityStateZip =
        "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
    var orderIdToPrint = '$orderId';

    final userData = await UserDbHelper().getUserData();
    var cashierName =
        "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
    var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";

    if (header != "") {
      bytes += ticket.row([
        PosColumn(text: header, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
    }

    bytes += ticket.row([
      PosColumn(
        text: "***** CUST-INVOICE *****",
        width: 12,
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(
        text: storeName,
        width: 12,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: address, width: 12, styles: PosStyles(align: PosAlign.center))
    ]);
    bytes += ticket.row([
      PosColumn(text: cityStateZip, width: 12, styles: PosStyles(align: PosAlign.center))
    ]);
    bytes += ticket.row([
      PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: "Date: $_displayDate", width: 7),
      PosColumn(text: "Time: $_displayTime", width: 5),
    ]);

    bytes += ticket.row([
      PosColumn(text: "Cashier: $cashierName", width: 7),
      PosColumn(text: "StoreID: $storeId", width: 5),
    ]);

    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7),
      PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // -------------------------------
    // ITEM HEADER
    // -------------------------------
    bytes += ticket.row([
      PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
      PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
      PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += ticket.feed(1);

    // -------------------------------
    // ITEMS LOOP
    // -------------------------------
    for (int i = 0; i < orderItems.length; i++) {
      var item = orderItems[i];

      String itemName = item['item_name'] ?? '';
      double unitPrice = (item['item_price'] ?? 0).toDouble();
      int qty = (item['items_count'] ?? 0).toInt();
      double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
      String type = item['item_type']?.toString().toLowerCase() ?? '';

      bool isPayout = type.contains(TextConstants.payoutText);
      bool isCoupon = type.contains(TextConstants.couponText);
      bool isPayoutOrCoupon = isPayout || isCoupon;

      String formattedRate = isCoupon || isPayout
          ? "-${TextConstants.currencySymbol}${unitPrice.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${unitPrice.toStringAsFixed(2)}";

      String formattedTotal = isCoupon || isPayout
          ? "-${TextConstants.currencySymbol}${lineTotal.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${lineTotal.toStringAsFixed(2)}";

      bytes += ticket.row([
        PosColumn(text: "${i + 1}", width: 1),
        PosColumn(text: itemName, width: 5),
        PosColumn(text: "$qty", width: 1, styles: PosStyles(align: PosAlign.center)),
        PosColumn(text: formattedRate, width: 2, styles: PosStyles(align: PosAlign.right)),
        PosColumn(text: formattedTotal, width: 3, styles: PosStyles(align: PosAlign.right)),
      ]);

      String discountType = item['discount_type']?.toString() ?? '';

      double autoDiscount =
      (discountType.isEmpty || discountType == 'auto')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;

      double multipackDiscount =
      (discountType == 'multipack')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;

      double comboDiscount = (discountType == 'combo')
          ? (item['auto_discount'] ?? 0).toDouble()
          : 0.0;

      if (autoDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "   Auto Discount", width: 9),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      // Combo Discount (new)
      if (comboDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "   Combo Discount", width: 9),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (multipackDiscount > 0 && !isPayoutOrCoupon) {
        bytes += ticket.row([
          PosColumn(text: "   Multipack Discount", width: 9),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += ticket.emptyLines(1);
    }

    // -------------------------------
    // TOTALS
    // -------------------------------
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.grossTotal, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.discountText, width:8),
      PosColumn(
        text: "-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.taxText, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.merchantDiscount, width: 8),
      PosColumn(
        text: "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    if (cashbackFee > 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.cashbackFee, width: 8),
        PosColumn(
          text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}",
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += ticket.row([
      PosColumn(text: TextConstants.servicecharges, width: 8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: TextConstants.netPayable, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${orderTotal.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    if (redeemedValue > 0) {
      bytes += ticket.row([
        PosColumn(text: "Redeemed Amount", width: 8),
        PosColumn(
          text: "-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}",
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += ticket.row([
      PosColumn(text: TextConstants.payByCash, width: 8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.payByOther, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.tenderAmount, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.change, width:8),
      PosColumn(
        text: "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}",
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    if (footer != "") {
      bytes += ticket.feed(1);
      bytes += ticket.row([
        PosColumn(text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
    }
  }

////

  Future _printTicket({bool manual = false}) async {
    final ticket = await _printerSettings.getTicket();
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }

    switch (result) {
      case Ok<BluetoothPrinter>():
        break;
      case Error<BluetoothPrinter>():
        if (manual) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error.getMessage,
                style: const TextStyle(color: Colors.red),
              ),
              backgroundColor: Colors.black,
              duration: const Duration(seconds: 3),
            ),
          );

          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrinterSetup(),
              )).then((result) {
            if (result == TextConstants.refresh) {
              _printerSettings.loadPrinter();
              setState(() {
                if (!Misc.disablePrinter) {
                  _printTicket(); // retry only when NOT manual
                }
              });
            } else {
              if (mounted) {
                _showReceiptDialog(context, paidAmount);
              }
            }
          });
        });
        break;
    }
  }

  Future _printCustomTest() async {
    if (kDebugMode) {
      print("OrderSummaryScreen _printCustomTest call print reciept");
    }
    List<int> bytes = [];

    final ticket = await _printerSettings.getTicket();
    bytes += ticket.row([
      PosColumn(text: "#", width: 1),
      PosColumn(text: "Description", width: 5),
      PosColumn(text: "Qty", width: 1),
      PosColumn(text: "Rate", width: 2),
      PosColumn(text: "Dis", width: 1),
      PosColumn(text: "Amt", width: 2),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "1", width: 1),
      PosColumn(text: "Shan Haleem Masala Mix", width: 5),
      PosColumn(text: "1.0", width: 1),
      PosColumn(text: "420.0", width: 2),
      PosColumn(text: "0.0", width: 1),
      PosColumn(text: "420.0", width: 2),
    ]);
    bytes += ticket.row([
      PosColumn(
          text: "sfgasa sdfasdfasdf asdfasdfasdfsdfasdfasdf adfasdfasdfasdf",
          width: 12),
    ]);
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }
    switch (result) {
      case Ok<BluetoothPrinter>():
      // BluetoothPrinter printer = result.value;
        break;
      case Error<BluetoothPrinter>():
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Build #1.0.16
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error.getMessage,
                style: const TextStyle(color: Colors.red),
              ),
              backgroundColor: Colors.black, // ✅ Black background
              duration: const Duration(seconds: 3),
            ),
          );

          /// call printer setup screen
          if (kDebugMode) {
            print("call printer setup screen");
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrinterSetup(),
              )).then((result) {
            if (result == TextConstants.refresh) {
              // Build #1.0.175: added TextConstants
              _printerSettings.loadPrinter();
              setState(() {
                // Update state to refresh the UI
                if (kDebugMode) {
                  print(
                      "SettingScreen - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
                }
                if (!Misc.disablePrinter) {
                  _printTicket();
                }
              });
            }
          });
        });
        break;
    }
  }

  void _showReceiptDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        status: PaymentStatus.receipt,
        mode: PaymentMode.cash,
        amount: amount,
        onPrint: () {
          if (kDebugMode) {
            print("Printing receipt for amount: $amount");
          }
        },
        onEmail: (email) {
          if (kDebugMode) {
            print("Email option selected with email: $email");
          }
        },
        onSMS: (phone) {},
        onNoReceipt: () {
          changeStatusToCompletedAndExit(false);
        },
        onDone: (selectedOption, {String? email}) {
          // Build #1.0.159: Integrated Send Email Order Details API
          if (kDebugMode) {
            print("DEBUG 0011 : $selectedOption, $email, ${email?.isNotEmpty}");
          }
          // Call API only if email option is selected and an email is provided
          if (selectedOption == TextConstants.email &&
              email != null &&
              email.isNotEmpty) {
            if (orderId == null || orderId == 0) {
              if (kDebugMode) {
                print("Invalid order ID: $orderId. Cannot send email.");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TextConstants.canNotSendEmail),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }

            if (kDebugMode) {
              print(
                  "Sending receipt to email: $email for order ID: $orderId on Done button click");
            }

            paymentBloc.sendOrderDetails(orderId!, email);
            StreamSubscription? subscription;
            subscription =
                paymentBloc.sendOrderDetailsStream.listen((response) {
                  if (response.status == Status.COMPLETED) {
                    if (kDebugMode) {
                      print("Email sent successfully: ${response.data!.message}");
                    }
                    if (Misc.showDebugSnackBar) {
                      // Build #1.0.254
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response.data!.message),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else if (response.status == Status.ERROR) {
                    if (kDebugMode) {
                      print("Failed to send email: ${response.message}");
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(TextConstants.failedSendEmail),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  subscription?.cancel();
                  // Proceed to complete the order after email API response
                  changeStatusToCompletedAndExit(true,
                      selectedOption: selectedOption);
                });
          } else {
            // For non-email options, proceed directly to complete the order
            changeStatusToCompletedAndExit(true,
                selectedOption: selectedOption);
          }
        },
      ),
    );
  }

  ///Use this function to change status to complete the order after payment
  ///it is used called by no receipt and print receipt on order payment completed - print button tap
  void changeStatusToCompletedAndExit(bool isReceipt,
      {String selectedOption = TextConstants.print}) {
    /// Build #1.0.168: Fixed Issue - Change is showing as zero only
    /// No need here to reset changeAmount,balanceAmount or tenderAmount
    /// Every time comes to this screen we are already resetting initially in fetchOrderItems method


    if (kDebugMode) {
      print(
          "OrderSummaryScreen _showReceiptDialog Done call print receipt = $isReceipt");
    }

    if (kDebugMode) {
      print(
          "changeStatusToCompletedAndExit called with isReceipt=$isReceipt, selectedOption=$selectedOption");
    } else if (selectedOption == TextConstants.sms) {
      // SMS receipt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextConstants.smsConfiguration),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    ///ToDO: Change the status of order to 'completed' here
    // Build #1.0.49: Added Call Order Status Update API code


    /// Build #1.0.175: No need change status to completed API call
    /// It was handling from backend
    Navigator.of(context).pop(); // Dismiss the receipt dialog
    // Navigator.of(context).pop(TextConstants.refresh); // Dismiss back to the previous screen with a refresh signal
    if (kDebugMode) {
      print("changeStatusToCompletedAndExit -> 3:");
    }

    ///Completed order
    OrderHelper.isOrderPanelLoaded = false;
    Navigator.pushReplacement(
      result: TextConstants.refresh,
      context,
      MaterialPageRoute(builder: (_) => FastKeyScreen()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          TextConstants.orderCompleted,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green, // Build #1.0.104: updated to green
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showVoidExitConfirmation(BuildContext context, bool isPartial) {
    if (kDebugMode) {
      print(
        "showVoidExitConfirmation -> isPartial: $isPartial, orderId: $orderId",
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PaymentDialog.voidConfirmation(
        onVoidCancel: () {
          if (kDebugMode) {
            print("❌ VOID CANCELED BY USER");
          }
          Navigator.of(dialogContext).pop(); // ✅ CLOSE DIALOG
        },

        onVoidConfirm: () async {
          // Navigator.of(dialogContext).pop(); // ✅ ALWAYS CLOSE FIRST

          if (_lastPayment == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No payment to void")),
            );
            return;
          }

          final method = _lastPayment!.method.toLowerCase();

          // ⭐ CARD → SUNMI VOID
          if (method == TextConstants.card.toLowerCase() &&
              _lastPayment!.sunmiTxnId != null &&
              _lastPayment!.sunmiOrderId != null) {

            if (kDebugMode) {
              print("🔁 VOID CONFIRM → CARD → SUNMI");
            }

            await _openSunmiVoidScreen(
              amount: _lastPayment!.amount,
              orderId: _lastPayment!.sunmiOrderId!,
              originTransactionId: _lastPayment!.sunmiTxnId!,
            );

            return;
          }

          // ⭐ CASH / WALLET / EBT → API VOID
          if (kDebugMode) {
            print(
              "🔁 VOID CONFIRM → NON-CARD (${_lastPayment!.method}) → API VOID",
            );
          }

          _handleVoidPayment(context, isPartial: isPartial);
        },
      ),
    );
  }


  // Build #1.0.175: Modified _showExitPaymentConfirmation to check order_status
  void _showExitPaymentConfirmation(BuildContext context) {
    // DEBUG: Log the current payment and balance status
    if (kDebugMode) {
      print(
          "_showExitPaymentConfirmation -> payByCash: $payByCash, payByOther: $payByOther, balanceAmount: $balanceAmount, orderTotal: $orderTotal, orderStatus: $orderStatus");
    }

    // Build #1.0.175: If order_status is pending, show confirmation dialog
    if (orderStatus == TextConstants.pending) {
      if (kDebugMode) {
        print(
            "_showExitPaymentConfirmation -> Order status is pending, showing confirmation dialog");
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PaymentDialog(
          status: PaymentStatus.exitConfirmation,
          onExitCancel: () {
            if (kDebugMode) {
              print(
                  "_showExitPaymentConfirmation -> User canceled exit, closing dialog");
            }
            Navigator.of(context).pop(); // Close the dialog
          },
          onExitConfirm: () {
            if (kDebugMode) {
              print(
                  "_showExitPaymentConfirmation -> User confirmed exit, navigating back");
            }

            ///Partial payment back button exit
            Navigator.of(context).pop(); // Close exit confirmation dialog
            // Navigator.of(context).pop(TextConstants.refresh); // Navigate back to previous screen
            OrderHelper.isOrderPanelLoaded = false;
            Navigator.pushReplacement(
              result: TextConstants.refresh,
              context,
              MaterialPageRoute(builder: (_) => FastKeyScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  TextConstants.orderPending,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.yellow,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
      );
    } else {
      // Build #1.0.175: If order_status is not pending, navigate back without popup
      if (kDebugMode) {
        print(
            "_showExitPaymentConfirmation -> Order status is not pending, navigating back directly");
      }
      Navigator.of(context).pop(); // Direct navigation back to previous screen
    }
  }

}
