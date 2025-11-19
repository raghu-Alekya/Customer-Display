import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_payment_dialog.dart';
import '../../services/CustomerDisplayService.dart';
import '../Auth/login_screen.dart';
import 'Settings/image_utils.dart';
import 'Settings/printer_setup_screen.dart';
import 'edit_product_screen.dart';

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
    this.isOfflineSynced = false,
    this.offlineOrderId,
    super.key,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  List<Map<String, dynamic>> orderItems = [];
  String selectedPaymentMethod = TextConstants.cash;
  TextEditingController amountController = TextEditingController();
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
  double cashbackFee =0.0;

  double NetTotal=0.0;
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

  double discountValue = 0.0;

  // Determine the date and time to display
  String _displayDate = "";
  String _displayTime = "";
  int _rawAmount = 0;
  double computedNetPayable = 0.0;
// holds value in paise/cents, e.g. 2345
  bool showCustomerInput = false;
  final TextEditingController mobileController = TextEditingController();
  bool isPhoneValid = false;
  int availablePoints = 0;        // from backend API
  double orderTotalAmount = 0.0;  // from order helper / cart total
  bool isMobileValid = false;
  double redeemedValue = 0.0;

  @override
  void initState() {
    super.initState();
    orderBloc = OrderBloc(OrderRepository()); // Build #1.0.49
    orderItems = widget.orderItems;
    grossTotal = widget.grossTotal;
    discount = widget.orderDiscount;
    merchantDiscount = widget.merchantDiscount;
    tax = widget.orderTax;
    orderId = widget.orderId;
    _displayDate = widget.formattedDate;
    _displayTime = widget.formattedTime;
    computedNetPayable = grossTotal + tax - discount - merchantDiscount;
    balanceAmount = computedNetPayable;
    orderTotal = computedNetPayable;
    cashbackFee = widget.cashbackFee;
    NetTotal = grossTotal - discount;

    //redeeem points
    mobileController.addListener(() {
      setState(() {
        isMobileValid = RegExp(r'^[0-9]{10}$').hasMatch(mobileController.text);

        // If mobile becomes invalid, auto-disable redeem
        if (!isMobileValid) {
          isRedeemActive = false;
        }
        });
      });

    _fetchUserId();
    if (kDebugMode) {
      print("🧾 Order Summary Init:");
      print("Items: ${widget.orderItems.length}");
      print("Gross: ${widget.grossTotal}");
      print("Discount: ${widget.orderDiscount}");
      print("Tax: ${widget.orderTax}");
      print("Net Payable: ${widget.netPayable}");
      print("📦 Full Order Items Data:");
      print("Cashback Fee: $cashbackFee");
      for (var item in orderItems) {
        print(jsonEncode(item)); // pretty-print each item as JSON
      }
    }
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

  //Build #1.0.99: getPaymentsByOrderId API call for payment by cash and payment by other details
  void _fetchPaymentsByOrderId() {
    if (kDebugMode) {
      print("###### _fetchPaymentsByOrderId");
    }
    if (orderId != null) {
      setState(() {
        isSummaryLoading = true; // Show loader
      });
      paymentBloc.getPaymentsByOrderId(orderId!);
      // Build #1.0.151: Fixed - too much of loading in order summary screen of order panel
      _paymentListSubscription?.cancel(); // Cancel any existing subscription
      _paymentListSubscription =
          paymentBloc.paymentsListStream.listen((response) {
            if (response.status == Status.COMPLETED) {
              if (kDebugMode) {
                print("###### _fetchPaymentsByOrderId Api call COMPLETED");
              }
              if (response.data!.isNotEmpty) {
                // Build #1.0.175: check empty or not
                orderStatus =
                    response.data?.first.orderStatus ?? TextConstants.processing;
              }
              _processPaymentList(response.data!);
            } else if (response.status == Status.ERROR) {
              if (kDebugMode) {
                print("Error fetching payments: ${response.message}");
              }
            }
            setState(() {
              isSummaryLoading = false; // Hide loader
            });
          });
    } else {
      if (kDebugMode) {
        print("###### orderId is null");
      }
    }
  }

  //Build #1.0.99: Added new method to process payment list
  void _processPaymentList(List<PaymentListModel> payments) {
    double cashTotal = 0.0;
    double otherTotal = 0.0;

    for (var payment in payments) {
      double amount = double.tryParse(payment.amount) ?? 0.0;
      if (payment.paymentMethod == TextConstants.cash &&
          payment.voidStatus == false) {
        // Build #1.0.175: addition of all payment method cash & if it is not void
        cashTotal += amount;
      } else if (payment.paymentMethod != TextConstants.cash &&
          payment.voidStatus == false) {
        // Build #1.0.175: addition of all payment method others & if it is not void
        otherTotal += amount;
      }
    }

    if (kDebugMode) {
      print(
          "###### _processPaymentList ->>> payByCash1: $cashTotal, payByOther1: $otherTotal");
      print(
          "###### _processPaymentList ->>> payByCash2: $payByCash, payByOther2: $payByOther, tenderAmount: $tenderAmount");
    }
    setState(() {
      payByCash = cashTotal;
      payByOther = otherTotal;
      // Build #1.0.151: Fixed - Partial Payment Not Reflected After Voiding in On-Hold Order
      // Update balanceAmount / tenderAmount after getPaymentsByOrderId api call, because payByCash 'amount' avlue getting from this api only
      balanceAmount = orderTotal - payByCash - payByOther;
      var isBalanceZero = balanceAmount <= 0;
      // Build  #1.0.177: -ve balanace will be shown as balance if order status is processing
      changeAmount = isBalanceZero && (orderStatus != TextConstants.processing)
          ? balanceAmount.abs()
          : changeAmount;
      balanceAmount = isBalanceZero && (orderStatus != TextConstants.processing)
          ? 0
          : balanceAmount;
      tenderAmount = payByCash + payByOther;
    });
    if (kDebugMode) {
      print(
          "###### _processPaymentList ->>> payByCash3: $payByCash, payByOther3: $payByOther, tenderAmount: $tenderAmount");
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

  void _callCreatePaymentAPI({double amount = 0.0}) {
    // Build #1.0.29
    if (kDebugMode) {
      print(
          "###### _callCreatePaymentAPI called, balanceAmount: $balanceAmount");
    }
    if (balanceAmount > 0) {
      if (amountController.text.isEmpty) {
        //Build #1.0.34: updated code
        if (kDebugMode) {
          print("Error: Amount TextField is empty");
        }
        return;
      }
    }

    String cleanAmount = amountController.text
        .replaceAll(TextConstants.currencySymbol, '')
        .trim();
    final double amount = double.tryParse(cleanAmount) ?? 0.0;
    if (amount < 0.0) {
      if (kDebugMode) {
        print("Error: Invalid amount: $cleanAmount");
      }
      return;
    }
    if (kDebugMode) {
      print(
          "_callCreatePaymentAPI cleanAmount: $cleanAmount, balanceAmount: $balanceAmount");
    }

    setState(() {
      isLoading = true; //Build 1.1.36: Show loader on PAY tap
    });

    // Prepare payment request
    final String datetime =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final paymentRequest = PaymentRequestModel(
      title: selectedPaymentMethod,
      orderId: orderId ?? 0,
      amount: amount,
      paymentMethod: selectedPaymentMethod,
      shiftId: shiftId,
      vendorId: vendorId,
      userId: userId ?? 0,
      serviceType: serviceType,
      datetime: datetime,
      notes: '',
    );

    if (kDebugMode) {
      print("Creating payment with request: $paymentRequest");
    }

    //Build #1.0.34: updated code for API response and listen to stream then show popup
    paymentBloc.createPayment(paymentRequest);
    StreamSubscription? subscription;
    subscription =
        paymentBloc.createPaymentStream.listen((paymentResponse) async {
          if (kDebugMode) {
            print("Payment stream response: $paymentResponse ++++ end of message");
          }
          if (paymentResponse.data != null) {
            if (paymentResponse.status == Status.ERROR) {
              if (kDebugMode) {
                print("Payment API Error: ${paymentResponse.message}");
              }
              setState(() {
                isLoading = false; // Hide loader on error
              });
              subscription?.cancel();
            } else if (paymentResponse.status == Status.COMPLETED) {
              final paymentData = paymentResponse.data!;
              if (paymentData.message == "Payment Created Successfully") {
                // // Build #1.0.99: Call fetch payment details by order id API call
                // _fetchPaymentsByOrderId(); // Refresh payments after successful payment

                if (widget.isOfflineSynced && widget.offlineOrderId != null) {
                  try {
                    final offlineId = widget.offlineOrderId!;
                    final offlineBox = Hive.box('offlineOrders');

                    if (offlineBox.containsKey(offlineId.toString())) {
                      await offlineBox.delete(offlineId.toString());
                      if (kDebugMode)
                        print(
                            "✅ Deleted offline order $offlineId from Hive after payment");
                    }

                    await orderHelper.deleteOrder(offlineId);
                    if (kDebugMode)
                      print(
                          "✅ Deleted offline order $offlineId from SQLite after payment");
                  } catch (e) {
                    if (kDebugMode)
                      print("⚠️ Failed to delete offline order after payment: $e");
                  }
                }

                setState(() {
                  isLoading = false; // Hide loader on success
                });
                paidAmount = amount; // Current payment amount

                // Capture paymentId for wallet payments
                /// Build #1.0.175: Commented below code, because its only checking wallet payments
                /// We need to save paymentId always
                /// if required un-comment below line & change selectedPaymentMethod to wallet/cash
                //  if (selectedPaymentMethod == TextConstants.wallet) {
                //  paymentId = paymentData.paymentId; // Assuming the API response includes paymentId
                // paymentId = "TXT_123456789"; // For testing purpose added here
                paymentId = paymentData.paymentId.toString(); // paymentId
                orderStatus = paymentData.orderStatus ?? TextConstants.processing;
                if (kDebugMode) {
                  print("Wallet payment successful. Transaction ID: $paymentId");
                }
                //  }

                // Determine payment type
                final bool isExactPayment = (amount == balanceAmount);
                final bool isOverPayment = (amount > balanceAmount);
                final bool isPartialPayment = (amount < balanceAmount);

                if (kDebugMode) {
                  // Build #1.0.168: Debug prints
                  print("#### DEBUG 101 : $amount");
                  print("#### DEBUG 102 : $balanceAmount");
                }

                if (isOverPayment) {
                  if (kDebugMode) {
                    print("#### isOverPayment");
                  }
                  changeAmount = amount -
                      balanceAmount; // Build #1.0.168: Updated - Set changeAmount directly
                  balanceAmount = 0.0; // Balance fully paid
                  tenderAmount += amount;
                } else if (isExactPayment) {
                  if (kDebugMode) {
                    print("#### isExactPayment");
                  }
                  tenderAmount += amount;
                  changeAmount = 0.0; // No change for exact payment
                  balanceAmount = 0.0; // Balance fully paid
                } else if (isPartialPayment) {
                  if (kDebugMode) {
                    print("#### isPartialPayment");
                  }
                  tenderAmount += amount;
                  balanceAmount -= amount; // Reduce balance for partial payment
                  changeAmount = 0.0; // No change for partial payment
                } else if (balanceAmount == 0 && amount > 0) {
                  if (kDebugMode) {
                    print("#### balanceAmount is 0");
                  }
                  // Case where balance is already 0, return the entire amount as change
                  changeAmount =
                      amount; // Build #1.0.168: Updated - Set change to the full amount
                  tenderAmount += amount; // Reset tender to current payment
                }

                amountController.clear(); // Clear input textField
                setState(() {}); // Update UI

                balanceAmount =
                    double.tryParse(balanceAmount.toStringAsFixed(2)) ?? 0.00;
                if (kDebugMode) {
                  print(
                      "Payment successful - Paid: $paidAmount, Balance: $balanceAmount, Change: $changeAmount, Tender: $tenderAmount");
                }

                // Show appropriate dialog based on payment amount
                if (isPartialPayment && (balanceAmount != 0)) {
                  if (kDebugMode) {
                    print(
                        "Showing partial payment dialog: Paid=$paidAmount, Remaining Balance=$balanceAmount");
                  }
                  _showPartialPaymentDialog(context, amount);
                } else if (isExactPayment ||
                    isOverPayment ||
                    (balanceAmount == 0 && amount > 0)) {
                  if (kDebugMode) {
                    print(
                        "Showing payment dialog: Paid=$paidAmount, Change=$changeAmount");
                  }
                  _fetchPaymentsByOrderId(); // Refresh payments after successful payment
                  _showPaymentDialog(
                    context,
                    amount,
                    changeAmount: changeAmount,
                    showChange: changeAmount > 0,
                  );
                }
              }
              subscription?.cancel(); // Cancel subscription after handling
            }
          } else if (paymentResponse.status == Status.ERROR) {
            if (kDebugMode) {
              print(
                  "Unauthorised : response.message ${paymentResponse.message!} ++ end");
            }
            setState(() {
              isLoading = false; // Build #1.0.248: Hide loader on ERROR
            });
            //Build #1.0.180
            if (paymentResponse.message!.contains('Unauthorised')) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (context) => LoginScreen()));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unauthorised. Session is expired on this device."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
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
          : Colors.grey[100],
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
          left: ResponsiveLayout.getPadding(20),
          right: ResponsiveLayout.getPadding(20),
          top: ResponsiveLayout.getPadding(20),
          bottom: ResponsiveLayout.getPadding(15),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.appBarBackground
              : Colors.grey[100],
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
            SizedBox(width: ResponsiveLayout.getWidth(6)),

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
                const SizedBox(width: 4),

                // Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: ResponsiveLayout.getIconSize(14),
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
                  children: [
                    Icon(
                      Icons.access_time,
                      size: ResponsiveLayout.getIconSize(14),
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

    // ✅ NEW: Correct total items based on qty
    int totalItems = orderItems.fold(0, (sum, item) {
      final qty = int.tryParse(item['items_count']?.toString() ?? '1') ?? 1;
      return sum + qty;
    });

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            left: ResponsiveLayout.getPadding(20),
            right: ResponsiveLayout.getPadding(20),
            bottom: ResponsiveLayout.getPadding(20)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.primaryBackground
              : Colors.grey[100],
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
              left: ResponsiveLayout.getPadding(15),
              right: ResponsiveLayout.getPadding(15),
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
                                  keyboardType: TextInputType.number,
                                  maxLength: 10,

                                  // ⛔ Block alphabets & symbols
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],

                                  textAlign: TextAlign.start,
                                  textAlignVertical: TextAlignVertical.center,

                                  onChanged: (value) {
                                    innerSetState(() {});
                                    setState(() {
                                      isPhoneValid = value.length == 10;
                                    });
                                  },

                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),

                                  decoration: InputDecoration(
                                    counterText: "",
                                    hintText: "Add Customer number",
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade500
                                          : const Color(0xFFCCCCCC),
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Add / Cancel button
                          InkWell(
                            onTap: isPhoneValid
                                ? () {
                              setState(() {
                                showCustomerInput = !showCustomerInput;

                                if (!showCustomerInput) {
                                  mobileController.clear();
                                  isPhoneValid = false;
                                }

                                isRedeemActive = showCustomerInput;
                              });
                            }
                                : null,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.fromLTRB(20, 8, 28, 8),
                              decoration: BoxDecoration(
                                color: !isPhoneValid
                                    ? Colors.grey.shade400
                                    : showCustomerInput
                                    ? Colors.red
                                    : Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF262D41) // Dark mode add button color
                                    : const Color(0xFF3B4259), // Light mode add button color
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
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
                  child: Scrollbar(
                    controller: _scrollController,
                    scrollbarOrientation: ScrollbarOrientation.right,
                    thumbVisibility: true,
                    thickness: 8.0,
                    interactive: false,
                    radius: const Radius.circular(8),
                    trackVisibility: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: orderItems.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        return _buildOrderItem(index);
                      },
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(ResponsiveLayout.getRadius(10)),
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
                    margin: EdgeInsets.all(ResponsiveLayout.getPadding(8)),
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
                        : Scrollbar(
                      thumbVisibility: true,
                      radius: Radius.circular(10),
                      child: SingleChildScrollView(
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
                              dashColor: themeHelper.themeMode == ThemeMode.dark
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
                              dashColor: themeHelper.themeMode == ThemeMode.dark
                                  ? Colors.grey
                                  : Colors.black54,
                              lineThickness: 1.5,
                              dashGapLength: 4,
                            ),

                            _buildOrderCalculation(
                                TextConstants.netPayable,
                                '${TextConstants.currencySymbol}${computedNetPayable.toStringAsFixed(2)}',
                                isTotal: true),

                            _buildOrderCalculation(
                                TextConstants.payByCash,
                                '${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.payByOther,
                                '${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.tenderAmount,
                                '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}'),

                            _buildOrderCalculation(
                                TextConstants.change,
                                '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}'),

                            if (redeemedValue > 0) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Rewards Redeemed',
                                  style: TextStyle(
                                    color: Color(0xFF2FC921),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              _buildOrderCalculation(
                                "Rewards Redeemed",
                                "-${TextConstants.currencySymbol}${redeemedValue.toStringAsFixed(2)}",
                                isDiscount: true,
                              ),
                            ],
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
                  margin: EdgeInsets.only(
                    top: _showFullSummary
                        ? ResponsiveLayout.getPadding(2)
                        : ResponsiveLayout.getPadding(8),
                    right: ResponsiveLayout.getPadding(8),
                    left: ResponsiveLayout.getPadding(8),
                    bottom: ResponsiveLayout.getPadding(8),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomRight:
                      Radius.circular(ResponsiveLayout.getRadius(10)),
                      bottomLeft:
                      Radius.circular(ResponsiveLayout.getRadius(10)),
                      topLeft: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(10)),
                      topRight: _showFullSummary
                          ? Radius.zero
                          : Radius.circular(ResponsiveLayout.getRadius(10)),
                    ),
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.orderPanelSummary
                        : Colors.grey.shade300,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(8),
                    vertical: ResponsiveLayout.getPadding(14),
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
          cashbackFee = (orderData.first[AppDBConst.orderCashbackFee] as num?)?.toDouble()??0.0;
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

    final String itemName = orderItem['item_name']?.toString() ?? '';
    final double itemPrice = (orderItem['item_price'] ?? 0).toDouble();
    final int itemCount = (orderItem['items_count'] ?? 0).toInt();
    final double itemSumPrice = (orderItem['item_sum_price'] ?? 0).toDouble();
    final String itemImage = orderItem['item_image']?.toString() ?? '';
    final String itemType =
        orderItem['item_type']?.toString().toLowerCase() ?? '';

    final bool isPayout = itemType.contains(TextConstants.payoutText);
    final bool isCoupon = itemType.contains(TextConstants.couponText);
    final bool isCustomItem = itemType.contains(TextConstants.customItemText);
    final bool isCashback = itemType.contains("cashback");

    final bool isPayoutOrCouponOrCustomItem =
        isPayout || isCoupon || isCustomItem||isCashback;
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
      imageWidget = SvgPicture.asset(
        'assets/svg/custom_item.svg', // 👈 custom item icon
        fit: BoxFit.contain,
      );
    } else if (itemImage.startsWith('http')) {
      imageWidget = Image.network(
        itemImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            SvgPicture.asset('assets/svg/password_placeholder.svg'),
      );
    } else if (itemImage.startsWith('assets/')) {
      imageWidget = SvgPicture.asset(
        itemImage,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Image.asset(
        'assets/default.png',
        fit: BoxFit.cover,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.085,
        child: Row(
          children: [
            // 🖼️ Image Section
            Container(
              width: 50,
              height: 50,
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
                  Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.textDark
                          : ThemeNotifier.textLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isPayoutOrCouponOrCustomItem)
                    Text(
                      "${TextConstants.currencySymbol}${itemPrice.toStringAsFixed(2)} x $itemCount",
                      style: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.black87,
                        fontSize: 13,
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
      leadingIcon = SvgPicture.asset(
        'assets/svg/discount_star.svg',
        // width: ResponsiveLayout.getIconSize(16),
        // height: ResponsiveLayout.getIconSize(16),
        // color: Colors.green[600],
      );
    } else if (label == TextConstants.merchantDiscount) {
      labelColor = Colors.blue[600]!;
      amountColor = Colors.blue[600]!;
      leadingIcon = SvgPicture.asset(
        'assets/svg/discount_star.svg',
        colorFilter: ColorFilter.mode(Colors.blueAccent, BlendMode.srcIn),
        // width: ResponsiveLayout.getIconSize(16),
        // height: ResponsiveLayout.getIconSize(16),
        // color: Colors.blue[600],
      );
    }
    // ---------------- CASHBACK ( #55CBCD ) ----------------
    else if (label == TextConstants.cashbackFee || label.toLowerCase().contains("cashback")) {
      labelColor = const Color(0xFF55CBCD);
      amountColor = const Color(0xFF55CBCD);
      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update your asset name if needed
        colorFilter: const ColorFilter.mode(Color(0xFF55CBCD), BlendMode.srcIn),
      );
    }

// ---------------- SERVICE CHARGE ( #0A122D ) ----------------
    else if (label == TextConstants.servicecharges || label.toLowerCase().contains("service")) {
      labelColor = const Color(0xFF0A122D);
      amountColor = const Color(0xFF0A122D);
      leadingIcon = SvgPicture.asset(
        'assets/cashicon.svg', // update asset name
        colorFilter: const ColorFilter.mode(Color(0xFF0A122D), BlendMode.srcIn),
      );
    }
    // ---------------- NET TOTAL ( #373535 ) ----------------
    else if (label == TextConstants.NetTotal ||
        label.toLowerCase().contains("net total"))
    {
      labelColor = const Color(0xFF373535);
      amountColor = const Color(0xFF373535);

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
              if ((label == TextConstants.discountText || isDiscount) && discount > 0)
                GestureDetector(
                  onTap: () async => await _removeAppliedCoupon(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.delete_forever,
                      color: Colors.red,
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

  Widget _buildPaymentSection() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      // Remove the fixed height constraint to let it match the left container
      margin: EdgeInsets.only(
        bottom: ResponsiveLayout.getPadding(20),
        right: ResponsiveLayout.getPadding(20),
        top: ResponsiveLayout.getPadding(20),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveLayout.getRadius(10)),
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground
            : Colors.grey[100],
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
                        TextConstants.balanceAmount,
                        '${TextConstants.currencySymbol}${balanceAmount.toStringAsFixed(2)}',
                        amountColor: Colors.red,
                      ),
                      _buildAmountDisplay(TextConstants.tenderAmount,
                          '${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}',
                          amountColor: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : null),
                      _buildAmountDisplay(
                        TextConstants.change,
                        '${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}',
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
                                            ResponsiveLayout.getPadding(7)),
                                        decoration: BoxDecoration(
                                          color: themeHelper.themeMode ==
                                              ThemeMode.dark
                                              ? ThemeNotifier.tabsBackground
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                              ResponsiveLayout.getRadius(6)),
                                        ),
                                        child: Text(
                                          TextConstants.cashPayment,
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                            fontSize:
                                            ResponsiveLayout.getFontSize(
                                                12),
                                          ),
                                        ),
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
                                              borderRadius:
                                              BorderRadius.circular(ResponsiveLayout.getRadius(6)),
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
                                              readOnly: true,
                                              enabled: true,
                                              textAlign: TextAlign.right,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.only(
                                                    right: ResponsiveLayout.getPadding(16)),
                                                hintText: '${TextConstants.currencySymbol}0.00',
                                                hintStyle: TextStyle(
                                                  color: themeHelper.themeMode == ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.grey[400],
                                                  fontSize: ResponsiveLayout.getFontSize(20),
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                              style: TextStyle(
                                                color: _isAmountEntered
                                                    ? (themeHelper.themeMode == ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : Colors.grey[800])
                                                    : (themeHelper.themeMode == ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : Colors.grey[400]),
                                                fontSize: ResponsiveLayout.getFontSize(20),
                                                fontWeight: _isAmountEntered ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),

                                          if (_amountErrorText != null)
                                            Text(
                                              _amountErrorText!,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: ResponsiveLayout.getFontSize(12),
                                              ),
                                            ),
                                        ],
                                      ),

                                      SizedBox(height: ResponsiveLayout.getHeight(8)),

// QUICK AMOUNT BUTTONS - FIXED
                                      if (balanceAmount > 0)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: _generateQuickAmounts(balanceAmount)
                                              .map(
                                                (amount) => GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _rawAmount = (amount * 100).toInt();  // <-- FIX: Overwrite
                                                  amountController.text =
                                                  '${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}';
                                                  _isAmountEntered = true;
                                                });
                                              },
                                              child: _buildQuickAmountButton(
                                                  '${TextConstants.currencySymbol} ${amount.toStringAsFixed(2)}'),
                                            ),
                                          )
                                              .toList(),
                                        ),

                                      SizedBox(height: ResponsiveLayout.getHeight(12)),

// NUM PAD - FIXED LOGIC
                                      Expanded(
                                        child: CustomNumPad(
                                          numPadType: NumPadType.payment,
                                          isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
                                          getPaidAmount: () => amountController.text,
                                          balanceAmount: balanceAmount,

                                          onDigitPressed: (value) {
                                            if (balanceAmount <= 0) return;

                                            if (_amountErrorText != null) {
                                              _amountErrorText = null;
                                            }

                                            // Reset for next partial payment if previous one finished
                                            if (_rawAmount > balanceAmount * 100) {
                                              _rawAmount = 0; // <-- IMPORTANT FIX
                                            }

                                            if (value == '00') {
                                              _rawAmount = (_rawAmount * 100) % 100000000;
                                            } else {
                                              int digit = int.tryParse(value) ?? 0;
                                              _rawAmount = (_rawAmount * 10 + digit) % 100000000;
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

                                            double displayValue = _rawAmount / 100.0;
                                            amountController.text =
                                            '${TextConstants.currencySymbol}${displayValue.toStringAsFixed(2)}';

                                            setState(() {
                                              _isAmountEntered = _rawAmount != 0;
                                            });
                                          },

                                          onPayPressed: () {
                                            String cleanAmount = amountController.text
                                                .replaceAll(TextConstants.currencySymbol, '')
                                                .trim();

                                            double amount = double.tryParse(cleanAmount) ?? 0.0;

                                            if (amount == 0.0) {
                                              setState(() {
                                                _amountErrorText = TextConstants.amountValidation;
                                              });
                                              return;
                                            }

                                            _amountErrorText = null;
                                            _callCreatePaymentAPI();

                                            // Reset after successful payment
                                            _rawAmount = 0;
                                            amountController.text =
                                            '${TextConstants.currencySymbol}0.00';
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
                  Text(
                    TextConstants.selectPaymentMode,
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getFontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveLayout.getHeight(1)),

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
                              TextConstants.cash, Icons.money,
                              isSelected: selectedPaymentMethod ==
                                  TextConstants.cash, onTap: () {
                            setState(() {
                              selectedPaymentMethod = TextConstants.cash;
                            });
                          }),
                          SizedBox(height: ResponsiveLayout.getHeight(10)),
                          _buildPaymentModeButton(
                              TextConstants.card, Icons.credit_card, onTap: () {
                            setState(() {
                              selectedPaymentMethod = TextConstants.card;
                            });
                          }),
                          SizedBox(height: ResponsiveLayout.getHeight(10)),
                          _buildPaymentModeButton(TextConstants.wallet,
                              Icons.account_balance_wallet, onTap: () {
                                setState(() {
                                  selectedPaymentMethod = TextConstants.wallet;
                                });
                              }),
                          SizedBox(height: ResponsiveLayout.getHeight(10)),
                          _buildPaymentModeButton(
                              TextConstants.ebtText, Icons.payment, onTap: () {
                            setState(() {
                              selectedPaymentMethod = TextConstants.ebtText;
                            });
                          }),
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
                                "assets/redeem.jpg",
                                isActive: isRedeemActive,
                                onTap: () {
                                  // If button is not active, block the tap
                                  if (!isRedeemActive) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Enter valid 10-digit mobile number"),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }

                                  // If active but mobile invalid → still block
                                  if (!isMobileValid) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Enter valid 10-digit mobile number"),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }

                                  // ✔ Redeem is active
                                  // ✔ Mobile is valid
                                  // → OPEN POPUP
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) {
                                      return RedeemPointsDialog(
                                        customerMobile: mobileController.text,
                                        availablePoints: availablePoints,
                                        orderTotal: orderTotalAmount,
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildCouponButton(
                                TextConstants.coupon,
                                "assets/coupon.jpg",
                                onTap: () {
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
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue, // 🔵 Always blue
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ColorFiltered(
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn), // White icon
              child: Image.asset(iconPath, width: 20, height: 20),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white, // White text
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _removeAppliedCoupon() async {
    if (widget.orderId == null || widget.orderId == 0) return;

    setState(() => isSummaryLoading = true);

    try {
      await orderBloc.removeCoupon(
        orderId: widget.orderId!,
        couponCode: "",
      );

      print("✔ Coupon Removed");

      setState(() {
        discount = 0.0;
        discountValue = 0.0;
        NetTotal = grossTotal;

        tax = oldTax;
        computedNetPayable =
            grossTotal + tax - merchantDiscount;

        balanceAmount = computedNetPayable;
      });

    } catch (e) {
      print("❌ ERROR removing coupon: $e");
    } finally {
      setState(() => isSummaryLoading = false);
    }
  }

  void _openCouponPopup() {
    final TextEditingController _couponCtrl = TextEditingController();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // THEME COLORS
    final Color dialogBg = isDark ? const Color(0xFF252837) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade300;
    final Color textPrimary = isDark ? Colors.white : Colors.black87;
    final Color textSecondary = isDark ? Colors.white70 : Colors.black54;
    final Color hintColor = isDark ? Colors.white38 : Colors.grey;
    final Color redPrimary = const Color(0xFFFD6464); // SAME for both modes

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
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

                // ---------- TITLE ----------
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

                // ---------- TEXTFIELD ----------
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

                // ---------- BUTTONS ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                    // CANCEL BUTTON
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: redPrimary,
                        side: BorderSide(color: redPrimary, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // APPLY BUTTON
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        );
      },
    );
  }
  Future<void> _applyCoupon(String code) async {
    if (widget.orderId == null || widget.orderId == 0) return;

    setState(() => isSummaryLoading = true);

    try {
      final response = await orderBloc.applyCouponToOrder(
        orderId: widget.orderId!,
        couponCode: code,
      );

      if (response != null) {

        oldTax = tax;

        double appliedDiscount =
            double.tryParse(response.discountTotal) ?? 0.0;

        double updatedTax =
            double.tryParse(response.totalTax) ?? tax;
        double backendNet =
            double.tryParse(response.total) ?? computedNetPayable;

        print("✔ Discount = $appliedDiscount");
        print("✔ Updated Tax = $updatedTax");
        print("✔ Final Net = $backendNet");

        setState(() {
          discount = appliedDiscount;
          tax = updatedTax;
          NetTotal = grossTotal - discount;
          computedNetPayable = backendNet;
          balanceAmount = backendNet;
        });
      }

    } catch (e) {
      print("❌ ERROR applying coupon: $e");
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

  Widget _buildPaymentModeButton(String label, IconData icon,
      {bool isSelected = false, VoidCallback? onTap}) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      width: ResponsiveLayout.getWidth(128),
      height: ResponsiveLayout.getHeight(54),
      padding: ResponsiveLayout.getResponsivePadding(vertical: 10),
      margin: EdgeInsets.symmetric(vertical: 5),
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
                  : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? Colors.red
                : themeHelper.themeMode == ThemeMode.dark
                ? Color(0xFFE1E1E1)
                : Colors.grey,
            size: ResponsiveLayout.getIconSize(25),
          ),
          SizedBox(width: ResponsiveLayout.getWidth(8)),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.red
                  : themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: ResponsiveLayout.getFontSize(14),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF27AE60) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ColorFiltered(
              colorFilter: (title == TextConstants.redeemPoints && isActive)
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
              child: Image.asset(iconPath, width: 20, height: 20),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.black87,
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
        onVoid: () => showVoidExitConfirmation(context, false),
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
    for (int i = 0; i < orderItems.length; i++) {
      var item = orderItems[i];

      String itemName = item['item_name'] ?? '';
      double unitPrice = (item['item_price'] ?? 0).toDouble();
      int qty = (item['items_count'] ?? 0).toInt();
      double lineTotal = (item['item_sum_price'] ?? 0).toDouble();
      String type = item['item_type']?.toString().toLowerCase() ?? '';

      bool isPayout = type.contains(TextConstants.payoutText);
      bool isCoupon = type.contains(TextConstants.couponText);

      // Format payout/coupon as negative
      String formattedTotal = isCoupon || isPayout
          ? "-${TextConstants.currencySymbol}${lineTotal.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${lineTotal.toStringAsFixed(2)}";

      // ✅ LOG ITEM DETAILS
      if (kDebugMode) {
        print("🟩 ITEM ${i + 1}");
        print("Name       : $itemName");
        print("Qty        : $qty");
        print("Unit Price : $unitPrice");
        print("Line Total : $lineTotal");
        print("Type       : $type");
        print("Formatted  : $formattedTotal");
        print("--------------------------------------------");
      }

      bytes += ticket.row([
        PosColumn(text: "${i + 1}", width: 1),
        PosColumn(text: itemName, width: 5),
        PosColumn(
            text: "$qty", width: 1, styles: PosStyles(align: PosAlign.center)),
        PosColumn(
            text:
            "${TextConstants.currencySymbol}${unitPrice.toStringAsFixed(2)}",
            width: 2,
            styles: PosStyles(align: PosAlign.right)),
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
    final grossTotal = GlobalUtility.getGrossTotal(orderItems);

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
      PosColumn(text: TextConstants.merchantDiscount, width: 10),
      PosColumn(
          text:
          "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += ticket.row([
      PosColumn(text: TextConstants.taxText, width: 10),
      PosColumn(
          text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}",
          width: 2,
          styles: PosStyles(align: PosAlign.right)),
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