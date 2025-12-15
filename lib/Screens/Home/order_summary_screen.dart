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
  // final TextEditingController _paymentController = TextEditingController();
  var _printerSettings = PrinterSettings();
  List<int> bytes = [];
  String? paymentId; // To store the transaction ID after wallet payment
  late OrderBloc orderBloc;
  bool _showFullSummary = false;
  String? _amountErrorText;
  bool _isAmountEntered = false;
  double payByCard = 0.0;


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

  Future<void> _fetchShiftId() async {
    final data = await UserDbHelper().getUserData();
    if (data != null && data["shift_id"] != null) {
      setState(() {
        shiftId = data["shift_id"];
      });
    }
  }


  @override
  void initState() {
    super.initState();

    _fetchShiftId();
    orderBloc = OrderBloc(OrderRepository());
    selectedPaymentMethod = TextConstants.cash;

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
      final Map<String, dynamic> offlineOrder =
      Map<String, dynamic>.from(offlineBox.get(orderIdKey));

      if (offlineOrder['tenderAmount'] != null &&
          offlineOrder['balanceAmount'] != null)
      {
        // main restore
        tenderAmount = (offlineOrder['tenderAmount'] as num).toDouble();
        balanceAmount = (offlineOrder['balanceAmount'] as num).toDouble();

        // ⭐ Restore split values for cash & other
        payByCash = (offlineOrder['payByCash'] as num?)?.toDouble() ?? 0.0;
        payByOther = (offlineOrder['payByOther'] as num?)?.toDouble() ?? 0.0;

        if (offlineOrder.containsKey('ebtTotal') && offlineOrder['ebtTotal'] != null) {
          ebtTotal = (offlineOrder['ebtTotal'] as num).toDouble();
          print("🟩 Restored EBT from Hive = $ebtTotal");
        } else {
          print("⚠ No EBT found in Hive — keeping widget EBT = $ebtTotal");


          print("🟩 Restored Pending Payment:");
          print("   → payByCash = $payByCash");
          print("   → payByOther = $payByOther");
          print("   → ebtTotal = $ebtTotal");
          print("   → Tender Amount = $tenderAmount");
          print("   → Balance Amount = $balanceAmount");
        }

        print("🟩 Restored Pending Payment:");
        print("   → payByCash = $payByCash");
        print("   → payByOther = $payByOther");
        print("   → Tender Amount = $tenderAmount");
        print("   → Balance Amount = $balanceAmount");
      }
      else {
        balanceAmount = orderTotal;
      }
    }
    else {
      balanceAmount = orderTotal;
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

    // Fetch payments from API (if needed)
    _fetchPaymentsByOrderId();
  }

  @override
  void dispose() {
    //Build #1.0.99: Added Dispose
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
      "orderId": orderId,
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

    // -------------------------------
    // ✅ CALL EXISTING VOID API
    // -------------------------------
    _handleVoidPayment(context, isPartial: true);
  }

  Future<void> _openSunmiSaleScreen({
    required double amount,
    required String orderId,
  }) async {

    final result = await _paymentChannel.invokeMethod("startSale", {
      "amount": amount.toString(),
      "orderId": orderId,
    });

    final data = jsonDecode(result);
    final fullSunmi = jsonDecode(data["fullResponse"]);

    double paidAmount = double.tryParse(fullSunmi["processedAmount"] ?? "0") ?? 0.0;

    // 1️⃣ Add to card total
    payByCard += paidAmount;

    // 2️⃣ Apply your balance logic
    selectedPaymentMethod = TextConstants.card;
    _recalculateAfterPayment(paidAmount);

    // 3️⃣ Increase tender
    tenderAmount += paidAmount;

    setState(() {});

    // 4️⃣ Auto-create payment API entry
    _createPaymentFromSunmi(paidAmount, fullSunmi);

    // -------------------------------
    // ⭐ ADD THIS POPUP LOGIC HERE
    // -------------------------------
    if (balanceAmount > 0) {
      // Partial payment → show partial payment dialog
      _showPartialPaymentDialog(context, paidAmount);
    } else {
      // Full card payment completed → show completed dialog
      _showPaymentDialog(
        context,
        paidAmount,
        changeAmount: 0,
        showChange: false,
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
      paymentMethod: TextConstants.card,   // ⭐ correct method
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

    paymentBloc.createPayment(paymentRequest);
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

    print("🗑 [Hive] Redeemed points REMOVED → ID: $orderId");
  }


  void _fetchPaymentsByOrderId() {
    if (kDebugMode) print("###### _fetchPaymentsByOrderId");

    if (orderId != null) {
      setState(() {
        isSummaryLoading = true; // Show loader
      });

      paymentBloc.getPaymentsByOrderId(orderId!);

      _paymentListSubscription?.cancel(); // Cancel any existing subscription
      _paymentListSubscription =
          paymentBloc.paymentsListStream.listen((response) {
            if (response.status == Status.COMPLETED) {
              if (kDebugMode) print("###### _fetchPaymentsByOrderId Api call COMPLETED");

              if (response.data!.isNotEmpty) {
                orderStatus = response.data!.last.orderStatus ?? TextConstants.processing;
              }

              // 🔹 Preserve current EBT value before processing
              final currentEbt = ebtTotal;

              _processPaymentList(response.data!);

              // 🔹 Restore EBT if not updated by payments
              if (ebtTotal == 0.0 && currentEbt > 0.0) {
                ebtTotal = currentEbt;
                if (kDebugMode) print("⭐ Preserved EBT after payment refresh = $ebtTotal");
              }

            } else if (response.status == Status.ERROR) {
              if (kDebugMode) print("Error fetching payments: ${response.message}");
            }

            setState(() {
              isSummaryLoading = false; // Hide loader
            });
          });
    } else {
      if (kDebugMode) print("###### orderId is null");
    }
  }
  void _processPaymentList(List<PaymentListModel> payments) {
    double cashTotal = 0.0;
    double otherTotal = 0.0;
    double ebtPaid = 0.0;

    // ---------------------------
    // 1️⃣ Accumulate Paid Amounts
    // ---------------------------
    for (var payment in payments) {
      double amount = double.tryParse(payment.amount) ?? 0.0;

      if (!payment.voidStatus) {
        if (payment.paymentMethod == TextConstants.ebtText) {
          ebtPaid += amount;
        }
        else if (payment.paymentMethod == TextConstants.cash) {
          cashTotal += amount;
        }
        else {
          otherTotal += amount;
        }
      }
    }

    if (kDebugMode) {
      print("EBT Paid: $ebtPaid");
      print("Cash Paid: $cashTotal, Other Paid: $otherTotal");
    }

    // ---------------------------
    // 2️⃣ Restore Base EBT
    // ---------------------------
    double originalEbt = widget.ebtAmount;
    double remainingEbt = originalEbt - ebtPaid;

    // ---------------------------
    // 3️⃣ Cash Overpayment Should Reduce EBT  ⭐ FIX
    // ---------------------------
    double effectiveOrderTotal = orderTotal - redeemedValue;

    // Cash can only pay this portion:
    double nonEbtBalance = effectiveOrderTotal - originalEbt;

    // ALL non-EBT payments: cash + card + others
    double nonEbtPaid = cashTotal + otherTotal;

// If non-EBT paid exceeds allowed portion → extra reduces EBT
    if (nonEbtPaid > nonEbtBalance) {
      double extra = nonEbtPaid - nonEbtBalance;
      remainingEbt -= extra;
    }

    // Clamp after adjustment
    remainingEbt = remainingEbt.clamp(0, originalEbt);
    ebtTotal = remainingEbt;

    // ---------------------------
    // 4️⃣ Recalculate Final Balance
    // ---------------------------
    double totalPaid = cashTotal + otherTotal + ebtPaid;
    double newBalance = effectiveOrderTotal - totalPaid;

    bool isBalanceZero = newBalance <= 0;

    setState(() {
      payByCash = cashTotal;
      payByOther = otherTotal;
      payByEbt = ebtPaid;

      balanceAmount = newBalance.clamp(0.0, double.infinity);

      if (isBalanceZero && orderStatus != TextConstants.processing) {
        changeAmount = newBalance.abs();
        balanceAmount = 0;
      } else {
        changeAmount = 0;
      }

      tenderAmount = totalPaid;
    });

    if (kDebugMode) {
      print("⭐ EBT Remaining After Adjust: $ebtTotal");
      print("⭐ Updated Balance: $balanceAmount");
      print("⭐ Updated Tender: $tenderAmount");
    }

    // ---------------------------
// 5️⃣ SHOW PAYMENT DIALOG WHEN FULLY PAID
// ---------------------------
    if (balanceAmount == 0 &&
        !_paymentDialogShown &&
        payments.isNotEmpty) {

      _paymentDialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentDialog(
          context,
          tenderAmount,
          changeAmount: changeAmount,
          showChange: changeAmount > 0,
        );
      });
    }

  }


  // void fetchOrderItems() async {
  //   // TODO: Implement actual data fetching from database
  //   setState(() {
  //     // Temporary sample data
  //     orderItems = [];
  //   });
  // }
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

    setState(() => isLoading = true);

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
          setState(() => isLoading = false);
          subscription?.cancel();
          return;
        }

        if (paymentResponse.status == Status.COMPLETED &&
            paymentResponse.data != null &&
            paymentResponse.data!.message == "Payment Created Successfully") {
          setState(() {
            isPaymentStarted = true;
          });

          setState(() => isLoading = false);

          final paymentData = paymentResponse.data!;
          paidAmount = amount;
          paymentId = paymentData.paymentId.toString();
          orderStatus =
              paymentData.orderStatus ?? TextConstants.processing;

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
            _showPaymentDialog(
              context,
              amount,
              changeAmount: changeAmount,
              showChange: changeAmount > 0,
            );
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
          : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with logo and user info
            _buildHeader(),

            // Main content area: split horizontally
            Expanded(
              child: Row(
                children: [
                  // Left Side: Navigation bar + Order Summary stacked vertically
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildNavigationBar(),

                        // Order summary takes the rest of the vertical space
                        Expanded(
                          child: _buildOrderSummary(),
                        ),
                      ],
                    ),
                  ),

                  // Right Side: Payment Section
                  Expanded(
                    flex: 4,
                    child: _buildPaymentSection(),
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: ResponsiveLayout.getHeight(52),
        width: ResponsiveLayout.getWidth(640),
        margin: EdgeInsets.only(
          left: ResponsiveLayout.getPadding(10),
          right: ResponsiveLayout.getPadding(10),
          top: ResponsiveLayout.getPadding(10),
          bottom: ResponsiveLayout.getPadding(10),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.appBarBackground
              : Color(0xFFE4E4E4),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: ResponsiveLayout.getPadding(6),
            vertical: ResponsiveLayout.getPadding(6)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            InkWell(
              borderRadius:
              BorderRadius.circular(ResponsiveLayout.getRadius(8)),
              onTap: () {
                _showExitPaymentConfirmation(context);
              },
              child: Container(
                width: ResponsiveLayout.getWidth(80),
                padding: EdgeInsets.all(ResponsiveLayout.getPadding(5)),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(8)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        spreadRadius: 1),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.secondaryBackground
                                    : Colors.black12)),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textLight
                              : Colors.black,
                        )),
                    // BackButton(
                    //   style: ButtonStyle(
                    //       alignment: Alignment.centerLeft,
                    //       iconSize: WidgetStatePropertyAll(ResponsiveLayout.getIconSize(20))
                    //   ),
                    //   // onPressed: () {
                    //   //   _showExitPaymentConfirmation(context);
                    //   //   },
                    // ),
                    const SizedBox(width: 10),
                    Text(
                      TextConstants.back,
                      style:
                      TextStyle(fontSize: ResponsiveLayout.getFontSize(15)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: ResponsiveLayout.getWidth(2)),

            // Date and Time Container
            Row(
              children: [
                // Order ID
                Text(
                  '${TextConstants.orderId} #$orderId', // e.g., Build #1.0.29
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveLayout.getFontSize(14),
                  ),
                ),
                const SizedBox(width: 20),

                // Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,   // centers horizontally
                  crossAxisAlignment: CrossAxisAlignment.center, // centers vertically
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: ResponsiveLayout.getIconSize(12),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(4)),
                    Text(
                      _displayDate, //'Sunday, 16 March 2025',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                        fontSize: ResponsiveLayout.getFontSize(12),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: ResponsiveLayout.getWidth(4)),

                // Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,   // centers horizontally
                  crossAxisAlignment: CrossAxisAlignment.center, // centers vertically
                  children: [
                    Icon(
                      Icons.access_time,
                      size: ResponsiveLayout.getIconSize(12),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                    SizedBox(width: ResponsiveLayout.getWidth(4)),
                    Text(
                      _displayTime, //'11:41 A.M',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                        fontSize: ResponsiveLayout.getFontSize(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 2)
          ],
        ),
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
              : Color(0xFFE4E4E4),
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
                  // Label
                  Text(
                    "Cust Info:",
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getFontSize(16),
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Input container
                  Expanded(
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2C2C2E) // Dark mode background
                            : const Color(0xFFFFFDFD), // Light mode background
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          width: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : const Color(0xFFF1EEEE),
                        ),
                      ),
                      child: Row(
                        children: [
                          // TextField
                          Expanded(
                            child: StatefulBuilder(
                              builder: (context, innerSetState) {
                                return TextField(
                                  controller: mobileController,
                                  keyboardType: TextInputType
                                      .emailAddress, // supports email + numbers
                                  maxLength:
                                  50, // allow longer input for emails

                                  textAlign: TextAlign.start,
                                  textAlignVertical: TextAlignVertical.center,

                                  onChanged: (value) {
                                    innerSetState(() {});
                                    setState(() {
                                      // Check if numeric 10-digit phone
                                      isPhoneValid = RegExp(r'^[0-9]{10}$')
                                          .hasMatch(value);

                                      // Check if valid email
                                      isEmailValid = RegExp(
                                          r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                                          .hasMatch(value);
                                    });
                                  },

                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),

                                  decoration: InputDecoration(
                                    counterText: "",
                                    hintText: "Add Mobile No or Email",
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).brightness ==
                                          Brightness.dark
                                          ? Colors.grey.shade500
                                          : const Color(0xFFCCCCCC),
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.only(
                                        left: 8, top: 8, bottom: 8),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Add / Cancel button
                          InkWell(
                            onTap: isPaymentDone       // <--- FIX
                                ? null                 // disable tap after any payment
                                : () async {
                              if (showCustomerInput) {
                                setState(() {
                                  mobileController.clear();
                                  showCustomerInput = false;
                                  isPhoneValid = false;
                                  isEmailValid = false;
                                  isRedeemActive = false;
                                });

                                // ---------------- CLEAR LOYALTY CONTACT FROM HIVE ----------------
                                final offlineBox = Hive.box('offlineOrders');
                                final localKey = widget.offlineOrderId?.toString();

                                if (localKey != null) {
                                  final existing = offlineBox.get(localKey);

                                  if (existing != null) {
                                    final d = Map<String, dynamic>.from(existing);
                                    d["loyaltyContact"] = "";  // <---- IMPORTANT
                                    offlineBox.put(localKey, d);

                                    print("🟡 Loyalty contact removed for $localKey");
                                  }
                                }

                                // ---------------- UPDATE CUSTOMER DISPLAY WITH NO LOYALTY ----------------
                                final localOrderId = widget.offlineOrderId;
                                if (localOrderId != null) {
                                  print("📺 Customer Display → loyalty cleared");
                                  await CustomerDisplayHelper.updateCustomerDisplay(localOrderId);
                                }

                                return;
                              }

                              if (!(isPhoneValid || isEmailValid) || redeemedValue > 0) return;

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

                                final int pts = int.tryParse(data["available_points"].toString()) ?? 0;

                                setState(() {
                                  loyaltyData = data;
                                  availablePoints = pts;
                                  isRedeemActive = true;
                                  showCustomerInput = true;
                                });

                                // ---------------- SAVE CONTACT INTO HIVE ----------------
                                final offlineBox = Hive.box('offlineOrders');
                                final localKey = widget.offlineOrderId?.toString();

                                if (localKey != null) {
                                  final existing = offlineBox.get(localKey);

                                  if (existing != null) {
                                    final d = Map<String, dynamic>.from(existing);
                                    d["loyaltyContact"] = contact;   // <---- SAVE CONTACT
                                    offlineBox.put(localKey, d);

                                    print("🟢 Loyalty contact saved into Hive for $localKey → $contact");
                                  }
                                }

                                // -------------- UPDATE CUSTOMER DISPLAY -----------------
                                final localOrderId = widget.offlineOrderId;
                                if (localOrderId != null) {
                                  print("📌 Updating Customer Display → loyalty added");
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
                                print("❌ Loyalty API Error: $e");

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
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
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.fromLTRB(20, 8, 28, 8),
                              decoration: BoxDecoration(
                                color: isPaymentDone
                                    ? Colors.grey.shade400                 // <--- Disabled
                                    : (redeemedValue > 0)
                                    ? Colors.grey.shade400
                                    : !(isPhoneValid || isEmailValid)
                                    ? Colors.grey.shade400
                                    : showCustomerInput
                                    ? Colors.red
                                    : Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF262D41)
                                    : const Color(0xFF3B4259),

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
                                showCustomerInput ? "× Cancel" : "+ Add",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: orderItems.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? Colors.black26
                          : Colors.grey.shade300,
                    ),
                    itemBuilder: (context, index) {
                      return _buildOrderItem(index);
                    },
                  ),
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
                    margin:
                    EdgeInsets.all(ResponsiveLayout.getPadding(8)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          ResponsiveLayout.getRadius(10)),
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.primaryBackground
                          : Colors.white,
                      border: Border.all(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.borderColor
                            : Colors.grey.shade200,
                      ),
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

                            DottedLine(
                              dashColor: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? Colors.grey
                                  : Colors.black54,
                              lineThickness: 1.5,
                              dashGapLength: 4,
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

                            DottedLine(
                              dashColor: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? Colors.grey
                                  : Colors.black54,
                              lineThickness: 1.5,
                              dashGapLength: 4,
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
      // final db = await DBHelper.instance.database;
      // final List<Map<String, dynamic>> orderData = await db.query(
      //   AppDBConst.orderTable,
      //   columns: [AppDBConst.orderServerId,
      //   AppDBConst.orderDiscount,
      //   AppDBConst.orderTax,
      //   AppDBConst.merchantDiscount // Build #1.0.80
      //   ],
      //   where: '${AppDBConst.orderId} = ?',
      //   whereArgs: [order.first[AppDBConst.orderServerId]],
      // );

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
    final itemType = orderItem['item_type']?.toString().toLowerCase() ?? '';

    final bool isVariant =
        (orderItem['is_variant'] == true) ||
            (itemType == 'variant') ||
            (orderItem['variation_name'] != null &&
                orderItem['variation_name'].toString().trim().isNotEmpty) ||
            (orderItem['variation_id'] != null &&
                orderItem['variation_id'] != 0);
    final bool isEbtEligible = orderItem['is_ebt_eligible'] == true;


    final String itemName = orderItem['item_name']?.toString() ?? '';
    final double itemPrice = (orderItem['item_price'] ?? 0).toDouble();
    final int itemCount = (orderItem['items_count'] ?? 0).toInt();
    final double itemSumPrice = (orderItem['item_sum_price'] ?? 0).toDouble();
    final String itemImage = orderItem['item_image']?.toString() ?? '';

    final bool isPayout = itemType.contains(TextConstants.payoutText);
    final bool isCoupon = itemType.contains(TextConstants.couponText);
    final bool isCustomItem = itemType.contains(TextConstants.customItemText);
    final bool isCashback = itemType.contains("cashback");

    final bool isPayoutOrCoupon =
        isPayout || isCoupon || isCashback;
    if (kDebugMode) {
      print("🧩 Building Order Item #$index → $itemName | $itemType");
    }

    /// ✅ Select image based on item type
    Widget imageWidget;
    if (isPayout) {
      imageWidget = SvgPicture.asset(
        'assets/svg/payout.svg', // 👈 your existing payout icon path
        fit: BoxFit.contain,
      );
    } else if (isCoupon) {
      imageWidget = SvgPicture.asset(
        'assets/svg/coupon.svg', // 👈 coupon icon
        fit: BoxFit.contain,
      );
    } else if (isCustomItem) {
      // Custom item MUST show PNG
      imageWidget = Image.asset(
        'assets/custom.png',
        fit: BoxFit.cover,
      );
    } else if (itemImage.startsWith('http')) {
      // HTTP product image
      imageWidget = Image.network(
        itemImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/custom.png'), // PNG fallback instead of SVG
      );
    } else if (itemImage.startsWith('assets/')) {
      // Local asset image (.png / .jpg)
      imageWidget = Image.asset(
        itemImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/custom.png'), // fallback PNG
      );
    } else {
      // Final fallback
      imageWidget = Image.asset(
        'assets/custom.png',
        fit: BoxFit.cover,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.097,
        child: Row(
          children: [
            // 🖼️ Image Section
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
            ),

            const SizedBox(width: 12),

            // 🧾 Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🔹 Item Name
                        Text(
                          itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ),

                        Row(
                          children: [
                            // 🔹 Price × Qty (not for payouts/custom/coupon)
                            if (!isPayoutOrCoupon)
                              Text(
                                "${TextConstants.currencySymbol}${itemPrice.toStringAsFixed(2)} x $itemCount",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? ThemeNotifier.textDark
                                      : Colors.black87,
                                ),
                              ),

                            // spacing after price
                            if (!isPayoutOrCoupon) const SizedBox(width: 6),

                            // 🟢 EBT Badge
                            if (isEbtEligible)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "EBT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // spacing after EBT
                            if (isEbtEligible) const SizedBox(width: 6),

                            // 🔻 Variant Icon
                            if (isVariant)
                              SvgPicture.asset(
                                SvgUtils.variationIcon,
                                height: 10,
                                width: 10,
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 💰 Right-side total
            Text(
              isCoupon || isPayout
                  ? "-${TextConstants.currencySymbol}${itemSumPrice.abs().toStringAsFixed(2)}"
                  : "${TextConstants.currencySymbol}${itemSumPrice.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isCoupon || isPayout
                    ? Colors.red
                    : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : ThemeNotifier.textLight,
              ),
            ),
          ],
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
      // leadingIcon = SvgPicture.asset(
      //   'assets/svg/discount_star.svg',
      //   // width: ResponsiveLayout.getIconSize(16),
      //   // height: ResponsiveLayout.getIconSize(16),
      //   // color: Colors.green[600],
      // );
    } else if (label == TextConstants.merchantDiscount) {
      labelColor = Colors.blue[600]!;
      amountColor = Colors.blue[600]!;
      // leadingIcon = SvgPicture.asset(
      //   'assets/svg/discount_star.svg',
      //   colorFilter: ColorFilter.mode(Colors.blueAccent, BlendMode.srcIn),
      //   // width: ResponsiveLayout.getIconSize(16),
      //   // height: ResponsiveLayout.getIconSize(16),
      //   // color: Colors.blue[600],
      // );
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
    final int order = widget.orderId ?? orderId ?? 0;

    setState(() => isSummaryLoading = true);

    try {
      final rawRes = await OrderRepository().removeLoyaltyPoints(
        orderId: order,
        contact: contact,
      );

      final result = jsonDecode(rawRes);

      if (result["success"] == true) {
        final data = result["data"];

        setState(() {
          redeemedValue = 0;

          /// Update balance using order_total returned by API
          balanceAmount = (data["order_total"] as num?)?.toDouble() ?? balanceAmount;

          /// Keep remaining available points
          availablePoints = loyaltyData?["available_points"] ?? availablePoints;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Redeemed points removed successfully."),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      else {
        throw Exception(result["message"] ?? "Unable to remove points");
      }
    } catch (e) {
      print("❌ Remove Loyalty Points Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
        bottom: ResponsiveLayout.getPadding(10),
        right: ResponsiveLayout.getPadding(10),
        top: ResponsiveLayout.getPadding(10),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground
            :  Color(0xFFE4E4E4),
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
                  // Payment amount display row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    spacing: ResponsiveLayout.getWidth(12),
                    children: [
                      _buildAmountDisplay(
                        TextConstants.netPayable,
                        '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                        amountColor: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : null,
                      ),
                      _buildAmountDisplay(
                        TextConstants.balanceAmount,
                        '${TextConstants.currencySymbol}${balanceAmount.toStringAsFixed(2)}',
                        amountColor: Colors.red,
                      ),
                      // _buildAmountDisplay(
                      //   TextConstants.change,
                      //   '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}',
                      //   amountColor: Colors.green,
                      // ),
                      _buildAmountDisplay(
                        TextConstants.EBTAmount,
                        '${TextConstants.currencySymbol}${ebtTotal.toStringAsFixed(2)}',
                        amountColor: Colors.green,
                      ),

                    ],
                  ),

                  SizedBox(height: ResponsiveLayout.getHeight(12)),

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
                                    top: ResponsiveLayout.getPadding(10),
                                    bottom: ResponsiveLayout.getPadding(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    themeHelper.themeMode == ThemeMode.dark
                                        ? ThemeNotifier.secondaryBackground
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveLayout.getRadius(8)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Label container
                                      Container(
                                          height: ResponsiveLayout.getHeight(36),
                                          width: double.infinity,
                                          padding: EdgeInsets.only(
                                              top: ResponsiveLayout.getPadding(7),
                                              left:
                                              ResponsiveLayout.getPadding(12)),
                                          decoration: BoxDecoration(
                                            color: themeHelper.themeMode ==
                                                ThemeMode.dark
                                                ? ThemeNotifier.tabsBackground
                                                : Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                                ResponsiveLayout.getRadius(6)),
                                          ),
                                          child: Text(
                                            _getPaymentHeader(),
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                              fontSize: ResponsiveLayout.getFontSize(14),
                                            ),
                                          )

                                      ),
                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(8)),

                                      // Amount TextField
                                      // Amount TextField
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: ResponsiveLayout.getHeight(43),
                                            decoration: BoxDecoration(
                                              color: themeHelper.themeMode == ThemeMode.dark
                                                  ? ThemeNotifier.paymentEntryContainerColor
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(
                                                  ResponsiveLayout.getRadius(6)),
                                              border: Border.all(
                                                color: _amountErrorText != null
                                                    ? Colors.red
                                                    : themeHelper.themeMode == ThemeMode.dark
                                                    ? ThemeNotifier.borderColor
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: TextField(
                                              controller: amountController,
                                              readOnly: false,
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              enabled: balanceAmount >= 0,
                                              textAlign: TextAlign.right,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.only(
                                                  right: ResponsiveLayout.getPadding(16),
                                                ),
                                                hintText: '${TextConstants.currencySymbol}0.00',
                                                hintStyle: TextStyle(
                                                  color: themeHelper.themeMode == ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.grey[400],
                                                  fontSize: ResponsiveLayout.getFontSize(20),
                                                ),
                                              ),
                                              style: TextStyle(
                                                color: themeHelper.themeMode == ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : Colors.grey[900],
                                                fontSize: ResponsiveLayout.getFontSize(20),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (computedNetPayable > 0 && _amountErrorText != null)
                                            Text(
                                              _amountErrorText!,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: ResponsiveLayout.getFontSize(12),
                                              ),
                                            ),

                                        ],
                                      ),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(8)),

// QUICK AMOUNT BUTTONS - FIXED
                                      if (balanceAmount > 0 && selectedPaymentMethod != TextConstants.ebtText && selectedPaymentMethod != TextConstants.card)

                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                          children: _generateQuickAmounts(
                                              balanceAmount)
                                              .map(
                                                (amount) => GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  double allowedAmount = balanceAmount;

                                                  // --- EBT PAYMENT CASE ---
                                                  if (selectedPaymentMethod == TextConstants.ebtText) {
                                                    allowedAmount = min(balanceAmount, ebtTotal);
                                                  }

                                                  // --- CARD PAYMENT CASE ---
                                                  else if (selectedPaymentMethod == TextConstants.card) {
                                                    allowedAmount = balanceAmount;   // full remaining balance allowed
                                                  }

                                                  // UPDATE RAW AMOUNT
                                                  _rawAmount = (allowedAmount * 100).toInt();

                                                  // UPDATE TEXT FIELD
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}${allowedAmount.toStringAsFixed(2)}';

                                                  _amountErrorText = null;
                                                  _isAmountEntered = true;
                                                });
                                              },
                                              child: _buildQuickAmountButton(
                                                  '${TextConstants.currencySymbol} ${amount.toStringAsFixed(2)}'),
                                            ),
                                          )
                                              .toList(),
                                        ),

                                      SizedBox(
                                          height:
                                          ResponsiveLayout.getHeight(12)),

// NUM PAD - FIXED LOGIC
                                      Expanded(
                                        child: CustomNumPad(
                                          numPadType: NumPadType.payment,
                                          isDarkTheme: themeHelper.themeMode ==
                                              ThemeMode.dark,
                                          getPaidAmount: () =>
                                          amountController.text,
                                          balanceAmount: balanceAmount,
                                          onDigitPressed: (value) {
                                            if (selectedPaymentMethod == TextConstants.ebtText) {
                                              int maxAmount = (min(ebtTotal, balanceAmount) * 100).toInt();

                                              int digit = value == '00'
                                                  ? 0
                                                  : int.tryParse(value) ?? 0;

                                              int newAmount = value == '00'
                                                  ? _rawAmount * 100
                                                  : _rawAmount * 10 + digit;

                                              if (newAmount > maxAmount) return;

                                              _rawAmount = newAmount;
                                            }

                                            else {
                                              // ---------- CARD LIMIT LOGIC ----------
                                              int maxAmount = (balanceAmount * 100).toInt();

                                              if (value == '00') {
                                                int newAmount = _rawAmount * 100;
                                                if (newAmount > maxAmount) return;
                                                _rawAmount = newAmount;
                                              } else {
                                                int digit = int.tryParse(value) ?? 0;
                                                int newAmount = _rawAmount * 10 + digit;
                                                if (newAmount > maxAmount) return;
                                                _rawAmount = newAmount;
                                              }
                                            }

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
                                          onPayPressed: () {
                                            String cleanAmount = amountController.text
                                                .replaceAll(TextConstants.currencySymbol, '')
                                                .trim();

                                            double amount = double.tryParse(cleanAmount) ?? 0.0;

                                            // ❗ Block when amount = 0 (except netPayable = 0)
                                            if (amount == 0.0 && computedNetPayable > 0) {
                                              setState(() {
                                                _amountErrorText = TextConstants.amountValidation;
                                              });
                                              return;
                                            }

                                            _amountErrorText = null;

                                            // ⭐ ONLY HERE → check payment mode
                                            if (selectedPaymentMethod == TextConstants.card) {
                                              print("💳 Opening Sunmi ONLY after Pay click");

                                              _openSunmiSaleScreen(
                                                amount: amount,
                                                orderId: (widget.orderId ?? widget.offlineOrderId).toString(),
                                              );

                                              // Clear amount field after transaction call
                                              _rawAmount = 0;
                                              amountController.text = '${TextConstants.currencySymbol}0.00';
                                              _isAmountEntered = false;
                                              return;  // Prevent calling API twice
                                            }

                                            // ⭐ For all other payment modes → normal flow
                                            _callCreatePaymentAPI();

                                            _rawAmount = 0;
                                            amountController.text = '${TextConstants.currencySymbol}0.00';
                                            _isAmountEntered = false;
                                          },

                                          isLoading: isLoading,
                                        ),
                                      ),

                                      // Expanded numpad to fill remaining space
                                      // Expanded(
                                      //   child: CustomNumPad(
                                      //     numPadType: NumPadType.payment,
                                      //     isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
                                      //     getPaidAmount: () => amountController.text,
                                      //     balanceAmount: balanceAmount,
                                      //     onDigitPressed: (value) {
                                      //       if (balanceAmount <= 0) {
                                      //         return;
                                      //       }
                                      //       if (_amountErrorText != null) {
                                      //         setState(() {
                                      //           _amountErrorText = null;
                                      //         });
                                      //       }
                                      //       String cleanText = amountController.text.replaceAll(TextConstants.currencySymbol, '');
                                      //       amountController.text = '${TextConstants.currencySymbol}' + cleanText + value;
                                      //       setState(() {});
                                      //     },
                                      //     onClearPressed: () {
                                      //       if (_amountErrorText != null) {
                                      //         setState(() {
                                      //           _amountErrorText = null;
                                      //         });
                                      //       }
                                      //       amountController.clear();
                                      //       setState(() {});
                                      //     },
                                      //     onDeletePressed: () {
                                      //       if (amountController.text.isNotEmpty) {
                                      //         amountController.text = amountController.text.substring(0, amountController.text.length - 1);
                                      //         setState(() {});
                                      //       }
                                      //     },
                                      //     onPayPressed: () {
                                      //       if (balanceAmount <= 0) {
                                      //         setState(() {
                                      //           _amountErrorText = null;
                                      //           _callCreatePaymentAPI(amount: 0.0);
                                      //         });
                                      //       } else {
                                      //         String paidAmount = amountController.text;
                                      //         String cleanAmount = paidAmount.replaceAll('${TextConstants.currencySymbol}', '').trim();
                                      //         double amount = double.tryParse(cleanAmount) ?? 0.0;
                                      //
                                      //         setState(() {
                                      //           if (amount == 0.0) {
                                      //             _amountErrorText = TextConstants.amountValidation;
                                      //           } else {
                                      //             _amountErrorText = null;
                                      //             _callCreatePaymentAPI();
                                      //           }
                                      //         });
                                      //       }
                                      //     },
                                      //     isLoading: isLoading,
                                      //   ),
                                      // ),
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
                  SizedBox(height: ResponsiveLayout.getHeight(3)),
                  Text(
                    TextConstants.selectPaymentMode,
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getFontSize(14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveLayout.getHeight(3)),

                  // Payment mode buttons - make flexible
                  Expanded(
                    flex: 3, // Give more space to payment modes
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveLayout.getPadding(8)),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                            ResponsiveLayout.getRadius(5)),
                      ),
                      child: Column(
                        children: [
                          _buildPaymentModeButton(
                            TextConstants.cash,
                            Icons.money,
                            isSelected: selectedPaymentMethod == TextConstants.cash,
                            onTap: () {
                              setState(() {
                                selectedPaymentMethod = TextConstants.cash;
                                _resetAmount();
                              });
                            },
                          ),
                          SizedBox(height: ResponsiveLayout.getHeight(10)),
                          _buildPaymentModeButton(
                            TextConstants.card,
                            Icons.credit_card,
                            isSelected: selectedPaymentMethod == TextConstants.card,
                            onTap: () {
                              setState(() {
                                selectedPaymentMethod = TextConstants.card;
                                double allowedAmount = balanceAmount;

                                _rawAmount = (allowedAmount * 100).toInt();

                                amountController.text =
                                '${TextConstants.currencySymbol}${allowedAmount.toStringAsFixed(2)}';

                                _amountErrorText = null;
                                _isAmountEntered = true;
                              });
                            },
                          ),

                          SizedBox(height: ResponsiveLayout.getHeight(10)),

                          _buildPaymentModeButton(
                            TextConstants.wallet,
                            Icons.account_balance_wallet,
                            isSelected: selectedPaymentMethod == TextConstants.wallet,
                            onTap: () {
                              setState(() {
                                selectedPaymentMethod = TextConstants.wallet;
                                _resetAmount();
                              });
                            },
                          ),

                          SizedBox(height: ResponsiveLayout.getHeight(10)),

                          _buildPaymentModeButton(
                            TextConstants.ebtText,
                            Icons.payment,
                            isSelected: selectedPaymentMethod == TextConstants.ebtText,
                            onTap: () {
                              setState(() {
                                selectedPaymentMethod = TextConstants.ebtText;

                                // ALWAYS allow only the smaller amount
                                double allowedAmount = min(ebtTotal, balanceAmount);

                                _rawAmount = (allowedAmount * 100).toInt();

                                amountController.text =
                                '${TextConstants.currencySymbol}${allowedAmount.toStringAsFixed(2)}';

                                _amountErrorText = null;
                                _isAmountEntered = true;
                              });
                            },
                          ),

                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveLayout.getHeight(20)),

                  // Payment options - make flexible
                  Expanded(
                    flex: 2, // Give less space to payment options
                    child: Container(
                      width: double.infinity,
                      padding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                            ResponsiveLayout.getRadius(5)),
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
                                    !hasEbtItem,
                                onTap: () async {
                                  if (hasEbtItem) return; // block redeem

                                  if (!isRedeemActive) return;

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

                              const SizedBox(height: 20),
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
        bool isActive = true, // 🔹 NEW
      }) {
    return InkWell(
      onTap: isActive ? onTap : null, // 🔹 Disable tap
      child: Container(
        height: 70,
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFF27AE60) : Colors.grey,
          // 🔹 Grey if disabled
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ColorFiltered(
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: Image.asset(iconPath, width: 25, height: 25),
            ),
            const SizedBox(width: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
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
    final localKey = widget.offlineOrderId?.toString();  // 🔥 ALWAYS LOCAL KEY

    if (localKey == null) {
      print("❌ No offlineOrderId found");
      return;
    }

    setState(() => isSummaryLoading = true);

    try {
      // 🔥 Woo API call uses Woo ID only
      await orderBloc.removeCoupon(
        orderId: widget.orderId!,
        couponCode: "",
      );

      // --------- UPDATE UI TOTALS ---------
      setState(() {
        discount = 0.0;
        discountValue = 0.0;
        NetTotal = grossTotal;
        tax = oldTax;
        computedNetPayable = grossTotal + tax - merchantDiscount + cashbackFee;
        balanceAmount = computedNetPayable;
      });

      // --------- UPDATE HIVE TOTALS ONLY ----------
      final existing = offlineBox.get(localKey);

      if (existing != null) {
        final data = Map<String, dynamic>.from(existing);

        // ONLY update totals
        data["orderDiscount"] = 0.0;
        data["wooTax"] = oldTax;

        offlineBox.put(localKey, data);

        print("🟢 Hive totals updated (LOCAL KEY: $localKey) — no product changes");
      } else {
        print("⚠ No hive order found for localKey → $localKey");
      }

      // --------- CUSTOMER DISPLAY ----------
      print("📌 Updating Customer Display using LOCAL ORDER ID = $localKey");
      await CustomerDisplayHelper.updateCustomerDisplay(widget.offlineOrderId!);

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
        Color? amountColor = Colors.black,
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    var size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: ResponsiveLayout.getFontSize(12),
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : Colors.black54),
        ),
        SizedBox(height: ResponsiveLayout.getHeight(4)),
        Container(
          width: MediaQuery.of(context).size.width * 0.145,
          height: ResponsiveLayout.getHeight(43),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.secondaryBackground
                : Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(8)),
          ),
          child: Text(
            amount,
            style: TextStyle(
              fontSize: ResponsiveLayout.getFontSize(18),
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildQuickAmountButton(String amount, {bool isHighlighted = false}) {
  //   return GestureDetector(
  //     onTap: () {
  //       amountController.text = amount.replaceAll(r'$', '');
  //       setState(() {});
  //     },
  //     child: Container(
  //       height: 60,
  //       width: 90,
  //       alignment: Alignment.center,
  //       padding: const EdgeInsets.all(16.0),
  //       decoration: BoxDecoration(
  //       //  color: isHighlighted ? Color(0xFFBFF1C0) : Color(0xFFE0E0E0),
  //         color: Color(0xFFBFF1C0),
  //         borderRadius: BorderRadius.circular(8),
  //       ),
  //       child: Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isHighlighted ? Colors.green : Colors.black, fontSize: 18)),
  //     ),
  //   );
  // }

  // Update _buildQuickAmountButton to remove isHighlighted logic for enabling
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
      IconData icon, {
        bool isSelected = false,
        VoidCallback? onTap,
      }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return GestureDetector(
      onTap: onTap, // ← FIX: This enables clicking
      child: Container(
        width: ResponsiveLayout.getWidth(168),
        height: ResponsiveLayout.getHeight(64),
        padding: ResponsiveLayout.getResponsivePadding(vertical: 10),
        margin: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.shade100
              : themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(5)),
          border: isSelected
              ? Border.all(color: Colors.red.shade300)
              : Border.all(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.borderColor
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.red : Colors.grey,
              size: ResponsiveLayout.getIconSize(32),
            ),
            SizedBox(width: ResponsiveLayout.getWidth(8)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.red : Colors.grey,
                fontFamily: 'Montserrat',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isSelected
                    ? ResponsiveLayout.getFontSize(18)
                    : ResponsiveLayout.getFontSize(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionButton(
      String title,
      String iconPath, {
        required bool isActive,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ?  Colors.blue.shade900
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ColorFiltered(
              colorFilter: (title == TextConstants.redeemPoints && isActive)
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
              child: Image.asset(iconPath, width: 24, height: 24),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.white : Colors.grey,
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
          // orderTotal = response.data!.orderTotal ?? orderTotal;
          // tenderAmount = response.data!.totalPaid ?? tenderAmount;
          // balanceAmount = response.data!.remainingAmount ?? balanceAmount;
          // changeAmount = tenderAmount > orderTotal ? (tenderAmount - orderTotal) : 0.0;
          orderStatus = response.data!.orderStatus ?? orderStatus;
          // Subtract the voided amount (paidAmount) from payByCash or payByOther based on selectedPaymentMethod
          // if (selectedPaymentMethod == TextConstants.cash) {
          //   payByCash = (payByCash - paidAmount).clamp(0.0, double.infinity);
          // } else {
          //   payByOther = (payByOther - paidAmount).clamp(0.0, double.infinity);
          // }

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
        onVoid: () {
          if (selectedPaymentMethod == TextConstants.card &&
              paymentId != null &&
              paymentId!.isNotEmpty) {

            _openSunmiVoidScreen(
              amount: payByCard,
              orderId: orderId.toString(),
              originTransactionId: paymentId!,
            );
          } else {
            // Cash / EBT / Wallet → normal API void
            showVoidExitConfirmation(context, true);
          }
        },


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
        onVoid: () {
          if (selectedPaymentMethod == TextConstants.card &&
              paymentId != null &&
              paymentId!.isNotEmpty) {

            _openSunmiVoidScreen(
              amount: payByCard,
              orderId: orderId.toString(),
              originTransactionId: paymentId!,
            );
          } else {
            // Cash / EBT / Wallet → normal API void
            showVoidExitConfirmation(context, true);
          }
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
        PosColumn(
          text: header,
          width: 12,
          styles: PosStyles(align: PosAlign.center),
        ),
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

    // Store Name
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

    // Address and Phone
    bytes += ticket.row([
      PosColumn(
          text: address, width: 12, styles: PosStyles(align: PosAlign.center))
    ]);
    bytes += ticket.row([
      PosColumn(
          text: cityStateZip,
          width: 12,
          styles: PosStyles(align: PosAlign.center))
    ]);
    bytes += ticket.row([
      PosColumn(
          text: "Phone: $storePhone",
          width: 12,
          styles: PosStyles(align: PosAlign.center)),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // Date & Time
    bytes += ticket.row([
      PosColumn(text: "Date: $_displayDate", width: 7),
      PosColumn(text: "Time: $_displayTime", width: 5),
    ]);

    // Cashier & Store ID
    bytes += ticket.row([
      PosColumn(text: "Cashier: $cashierName", width: 7),
      PosColumn(text: "StoreID: $storeId", width: 5),
    ]);

    // Role & Order ID
    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7),
      PosColumn(text: "OrderID: $orderIdToPrint", width: 5),
    ]);

    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    // -------------------------------
    // ITEM HEADER
    // -------------------------------
    bytes += ticket.row([
      PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
      PosColumn(text: "Description", width: 5, styles: PosStyles(bold: true)),
      PosColumn(
          text: "Qty",
          width: 1,
          styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(
          text: "Rate",
          width: 2,
          styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(
          text: "Amt",
          width: 3,
          styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += ticket.feed(1);

// -------------------------------
// ITEMS LOOP
// -------------------------------
    // -------------------------------
// ITEMS LOOP (CLEANED & FIXED)
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

      // ⭐ Correct rate formatting
      String formattedRate = isCoupon || isPayout
          ? "-${TextConstants.currencySymbol}${unitPrice.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${unitPrice.toStringAsFixed(2)}";

      // ⭐ Correct total formatting
      String formattedTotal = isCoupon || isPayout
          ? "-${TextConstants.currencySymbol}${lineTotal.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${lineTotal.toStringAsFixed(2)}";

      if (kDebugMode) {
        print("🟩 ITEM ${i + 1}");
        print("Name: $itemName  Qty: $qty  Rate: $formattedRate  Total: $formattedTotal  Type: $type");
      }

      bytes += ticket.row([
        PosColumn(text: "${i + 1}", width: 1),
        PosColumn(text: itemName, width: 5),
        PosColumn(
            text: "$qty",
            width: 1,
            styles: PosStyles(align: PosAlign.center)),

        // ⭐ ONLY ONE RATE COLUMN NOW
        PosColumn(
            text: formattedRate,
            width: 2,
            styles: PosStyles(align: PosAlign.right)),

        // ⭐ Correct AMOUNT column
        PosColumn(
            text: formattedTotal,
            width: 3,
            styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += ticket.emptyLines(1);
    }


    // -------------------------------
    // TOTALS
    // -------------------------------
    final double grossTotal = this.grossTotal;

    print("🟩 Totals Computed:");
    print("Gross Total: $grossTotal");
    print("Discount: $discount");
    print("Merchant Disc: $merchantDiscount");
    print("Tax: $tax");
    print("Cashback Fee: $cashbackFee");
    print("Service Charge: $servicecharges");
    print("Redeemed Value: $redeemedValue");
    print("Net Payable: $computedNetPayable");
    print("Cash: $payByCash");
    print("Other: $payByOther");
    print("Tender: $tenderAmount");
    print("Change: $changeAmount");

    print("================================================");
    print("🟩 _preparePrintTicket() COMPLETED SUCCESSFULLY");
    print("================================================");
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: TextConstants.grossTotal, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.discountText, width: 10),
      PosColumn(
          text:
          "-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.taxText, width: 10),
      PosColumn(
          text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);


    bytes += ticket.row([
      PosColumn(text: TextConstants.merchantDiscount, width: 10),
      PosColumn(
          text:
          "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);


    // Cashback Fee
    if (cashbackFee > 0) {
      bytes += ticket.row([
        PosColumn(text: TextConstants.cashbackFee, width: 10),
        PosColumn(
          text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

// Service Charges

    bytes += ticket.row([
      PosColumn(text: TextConstants.servicecharges, width: 10),
      PosColumn(
        text: "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}",
        width: 2,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);



    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    bytes += ticket.feed(1);

    bytes += ticket.row([
      PosColumn(text: TextConstants.netPayable, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${orderTotal.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    // Redeemed Value
    if (redeemedValue > 0) {
      bytes += ticket.row([
        PosColumn(text: "Redeemed Amount", width: 10),
        PosColumn(
          text: "-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }


    bytes += ticket.row([
      PosColumn(text: TextConstants.payByCash, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.payByOther, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.tenderAmount, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.change, width: 10),
      PosColumn(
          text:
          "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(
          text: "-----------------------------------------------", width: 12),
    ]);

    // Footer
    if (footer != "") {
      bytes += ticket.row([
        PosColumn(
            text: footer, width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
      bytes += ticket.feed(1);
    }
  }

  // Future _printTicket() async{
  //   // if(true) return;
  //   final ticket =  await _printerSettings.getTicket();
  //   final result = await _printerSettings.printTicket(bytes, ticket);
  //
  //   if (kDebugMode) {
  //     print(">>>> PrintTicket result $result");
  //   }
  //   switch (result) {
  //     case Ok<BluetoothPrinter>():
  //     // BluetoothPrinter printer = result.value;
  //       break;
  //     case Error<BluetoothPrinter>():
  //       WidgetsBinding.instance.addPostFrameCallback((_) { // Build #1.0.16
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               result.error.getMessage,
  //               style: const TextStyle(color: Colors.red),
  //             ),
  //             backgroundColor: Colors.black, // ✅ Black background
  //             duration: const Duration(seconds: 3),
  //           ),
  //         );
  //         /// call printer setup screen
  //         if (kDebugMode) {
  //           print("call printer setup screen");
  //         }
  //         Navigator.push(context, MaterialPageRoute(
  //           builder: (context) => PrinterSetup(),
  //         )).then((result) {
  //           if (result == TextConstants.refresh) { // Build #1.0.175: added TextConstants
  //             _printerSettings.loadPrinter();
  //             setState(() {
  //               // Update state to refresh the UI
  //               if (kDebugMode) {
  //                 print("OrderSummaryScreen - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
  //               }
  //               if(!Misc.disablePrinter) {
  //                 _printTicket();
  //               }
  //             });
  //           } else {
  //             if (kDebugMode) {
  //               print("OrderSummaryScreen - printer setup is NOT done, or user cancels printer setup");
  //             }
  //             // Build #1.0.168: If user cancels printer setup, show receipt dialog again
  //             if(mounted) {
  //               _showReceiptDialog(context, paidAmount);
  //             }
  //           }
  //         });
  //       });
  //       break;
  //   }
  // }
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
        if (manual) return; // ✅ Stop retry when called manually

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
    // setState(() {
    //   changeAmount = 0.0; // Reset change after returning
    //   if (balanceAmount == 0) tenderAmount = 0.0; // Reset tender if order is fully paid
    // });

    if (kDebugMode) {
      print(
          "OrderSummaryScreen _showReceiptDialog Done call print receipt = $isReceipt");
    }

    // if (selectedOption == TextConstants.print) {
    //   // Call print callback if selected
    //   if (isReceipt) {
    //     if(!Misc.disablePrinter) {
    //       _printTicket();
    //     }
    //     if (kDebugMode) {
    //       print("printing the ticket --- $isReceipt");
    //     }
    //   }
    //   // } else if (selectedOption == TextConstants.email) { // Build #1.0.159: Email receipt -> No need
    //   //   ScaffoldMessenger.of(context).showSnackBar(
    //   //     SnackBar(
    //   //       content: Text(TextConstants.emailConfiguration),
    //   //       backgroundColor: Colors.red,
    //   //       duration: const Duration(seconds: 2),
    //   //     ),
    //   //   );
    //
    // }
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
    // orderBloc.changeOrderStatus(orderId: orderId!, status: TextConstants.completed);
    // StreamSubscription? subscription;
    // subscription = orderBloc.changeOrderStatusStream.listen((response) {
    //   if (response.status == Status.COMPLETED) {
    //     if (kDebugMode) {
    //       print("OrderPanel - Order #@# $orderId, successfully completed");
    //     }
    //     if (!isReceipt) { //Build #1.0.134: IF USER TAP ON "NO RECEIPT" -> POP THE DIALOG & POP THE SCREEN
    //       // Build #1.0.104:  Pop the receipt dialog
    //       Navigator.of(context).pop();
    //       // Build #1.0.104:  Pop back to the previous screen with a refresh signal
    //       Navigator.of(context).pop(TextConstants.refresh);
    //     }else{ //Build #1.0.134: IF USER TAP ON "DONE" -> POP THE PRINTER SCREEN & THE DIALOG & POP THE SCREEN
    //       // Navigator.of(context).pop();
    //       // Build #1.0.104:  Pop the receipt dialog
    //       Navigator.of(context).pop();
    //       // Build #1.0.104:  Pop back to the previous screen with a refresh signal
    //       Navigator.of(context).pop(TextConstants.refresh);
    //     }
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
    // Optionally refresh UI or remove tab
    // fetchOrderItems();
    //   } else if (response.status == Status.ERROR) {
    //     if (kDebugMode) {
    //       print("OrderPanel - completed failed: ${response.message}");
    //     }
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           response.message ?? "Failed to complete order",
    //           style: const TextStyle(color: Colors.red),
    //         ),
    //         backgroundColor: Colors.black,
    //         duration: const Duration(seconds: 3),
    //       ),
    //     );
    //     Navigator.of(context).pop(); // Build #1.0.104: close dialog on error
    //   }
    //   subscription?.cancel();
    // });
  }

  // Build #1.0.49: _showVoidExitConfirmation
  // Build #1.0.175: Modified _showVoidExitConfirmation to handle partial and complete void scenarios
  void showVoidExitConfirmation(BuildContext context, bool isPartial) {
    // DEBUG: Log void confirmation details
    if (kDebugMode) {
      print(
          "showVoidExitConfirmation -> isPartial: $isPartial, orderId: $orderId, paymentId: $paymentId");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog.voidConfirmation(
        onVoidCancel: () {
          if (kDebugMode) {
            print(
                "showVoidExitConfirmation -> User canceled void, closing dialog");
          }
          Navigator.of(context).pop(); // Dismiss the confirm dialog
        },
        onVoidConfirm: () {
          if (isPartial) {
            // Build #1.0.175: For partial payment void - call voidPayment API
            if (kDebugMode) {
              print(
                  "showVoidExitConfirmation -> Partial payment void: calling voidPayment API");
            }
            _handleVoidPayment(context, isPartial: true);
          } else {
            // Build #1.0.175: For complete payment void - call voidOrder API
            if (kDebugMode) {
              print(
                  "showVoidExitConfirmation -> Complete payment void: calling voidOrder API");
            }
            // _handleVoidOrder(context);
            _handleVoidPayment(context, isPartial: true);
          }
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
