import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:image/image.dart' as img;
import 'package:pinaka_pos/Helper/Extentions/extensions.dart';
import 'package:shimmer/shimmer.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Screens/Home/order_summary_screen.dart';
import 'package:pinaka_pos/Widgets/widget_order_panel.dart';
import 'package:pinaka_pos/Widgets/widget_order_status.dart';
import 'package:pinaka_pos/Widgets/widget_alert_popup_dialogs.dart';
import 'package:provider/provider.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Payment/payment_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/assets_db_helper.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/printer_db_helper.dart';
import '../Database/store_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Payment/payment_model.dart';
import '../Repositories/Payment/payment_repository.dart';
import '../Utilities/global_utility.dart';
import '../Models/Orders/orders_model.dart';
import '../Repositories/Auth/store_validation_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Screens/Home/Settings/image_utils.dart';
import '../Screens/Home/Settings/printer_setup_screen.dart';
import '../Screens/Home/edit_product_screen.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/responsive_layout.dart';
import '../Utilities/result_utility.dart';

class OrderScreenPanel extends StatefulWidget {
  final String formattedDate;
  final String formattedTime;
  final List<int> quantities;
  final VoidCallback? refreshOrderList;
  int? activeOrderId; // Build #1.0.251 : updated
  final bool fetchOrders; //Build #1.0.234:  Mark as final

  OrderScreenPanel({
    required this.formattedDate,
    required this.formattedTime,
    required this.quantities,
    this.refreshOrderList,
    this.activeOrderId,
    this.fetchOrders = false,
    Key? key,
  }) : super(key: key);

  @override
  _OrderScreenPanelState createState() => _OrderScreenPanelState();
}

class _OrderScreenPanelState extends State<OrderScreenPanel> with TickerProviderStateMixin {
  List<Map<String, Object>> tabs = []; // List of order tabs
  TabController? _tabController; // Controller for tab switching
  List<Map<String, dynamic>> orderItems = []; // List of items in the selected order
  final OrderHelper orderHelper = OrderHelper(); // Helper instance to manage orders

  bool _isLoading = false;
  bool _isPayBtnLoading = false;
  bool _initialFetchDone = false; // Build #1.0.143: Track initial fetch of fetchOrdersData
  // late OrderBloc orderBloc;
  StreamSubscription? _updateOrderSubscription;
  StreamSubscription? _fetchOrdersSubscription;
  final ProductBloc productBloc = ProductBloc(ProductRepository()); // Build #1.0.44 : Added for barcode scanning
  StreamSubscription? _productBySkuSubscription; // Build #1.0.44 : Added for product stream

  bool _showFullSummary = false;
  late ScaffoldMessengerState _scaffoldMessenger;
  var _printerReceipt;

  // Build #1.0.221 : Added these variables
  late PaymentBloc paymentBloc;
  StreamSubscription? _paymentListSubscription;
  double payByCash = 0.0;
  double payByOther = 0.0;
  double tenderAmount = 0.0;
  double changeAmount = 0.0;
  double cashbackFee = 0.0;
  double ebtAmount = 0.0;

  double hiveRedeemedValue = 0.0;
  int hiveRedeemedPoints = 0;
  int hiveAvailablePoints = 0;
  double uiGrossTotal = 0.0;
  double uiOrderDiscount = 0.0;
  double uiMerchantDiscount = 0.0;
  double uiOrderTax = 0.0;
  double uiNetPayable = 0.0;
  double uiCashbackFee = 0.0;
  int uiTotalItems = 0;
  double uiRedeemedValue = 0.0;



  String orderStatus = TextConstants.processing;
  int? orderServerId; // Server order ID for API calls
  double total = 0.0;
  double balanceAmount = 0.0;
  double paidAmount = 0.0;
  double discount = 0.0; // Add this to track discount
  double merchantDiscount = 0.0; // Add this to track merchant discount
  double servicecharges = 0.0;
  double tax = 0.0; // AddED tax variable
  final _printerSettings =  PrinterSettings();
  List<int> bytes = [];

  void _toggleSummary() {
    setState(() {
      _showFullSummary = !_showFullSummary;
    });
  }

  @override
  void initState() {
    if (kDebugMode) {
      print("##### OrderPanel initState");
    }
    //  orderBloc = OrderBloc(OrderRepository()); // Build #1.0.143: no need
    fetchOrdersData(); // Build #1.0.104
    _initialFetchDone = true; // Build #1.0.143: Track initial fetch of fetchOrdersData, after return from order summary screen we are updating order screen panel in didUpdateWidget, added this flag for multiple re-calls of fetchOrdersData()
    super.initState();
    // _getOrderTabs(); //Build #1.0.40: Load existing orders into tabs
    //_fetchOrders(); //Build #1.0.40: Fetch orders on initialization
    loadPrinterData();
    // Initialize payment bloc
    paymentBloc = PaymentBloc(PaymentRepository());
  }

  // Build #1.0.221 : getPaymentsByOrderId API call for payment details
  // we need to call payment by order id api in order screen panel and load the details payByCash, payByOther, tender amount, change amount
  void _fetchPaymentsByOrderId() {
    if (kDebugMode) {
      print("###### _fetchPaymentsByOrderId - OrderScreenPanel");
    }

    if (orderServerId != null) {
      paymentBloc.getPaymentsByOrderId(orderServerId!);

      _paymentListSubscription?.cancel();
      _paymentListSubscription = paymentBloc.paymentsListStream.listen((response) {
        if (response.status == Status.COMPLETED) {
          if (kDebugMode) {
            print("###### _fetchPaymentsByOrderId Api call COMPLETED - OrderScreenPanel");
            print("###### Response data: ${response.data}");
          }

          if (response.data!.isNotEmpty) {
            orderStatus = response.data?.first.orderStatus ?? TextConstants.processing;
            if (kDebugMode) {
              print("###### Order status updated to: $orderStatus");
            }
          }

          _processPaymentList(response.data!);
        } else if (response.status == Status.ERROR) {
          if (kDebugMode) {
            print("Error fetching payments: ${response.message}");
          }
        }

      });
    } else {
      if (kDebugMode) {
        print("###### orderServerId is null - Cannot fetch payments");
      }
    }
  }

  // Build #1.0.221 Process payment list and update UI
  void _processPaymentList(List<PaymentListModel> payments) {
    double cashTotal = 0.0;
    double otherTotal = 0.0;

    for (var payment in payments) {
      double amount = double.tryParse(payment.amount) ?? 0.0;
      if (payment.paymentMethod == TextConstants.cash && payment.voidStatus == false) {
        cashTotal += amount;
      } else if (payment.paymentMethod != TextConstants.cash && payment.voidStatus == false) {
        otherTotal += amount;
      }
    }

    if (kDebugMode) {
      print("###### _processPaymentList - OrderScreenPanel");
      print("###### activeOrderIdddddddddd: ${widget}- OrderScreenPanel");
      print("###### Cash Total: $cashTotal, Other Total: $otherTotal");
    }

    setState(() {
      payByCash = cashTotal;
      payByOther = otherTotal;
      tenderAmount = payByCash + payByOther;

      // -------------------------------
      // ⭐ READ ALL NECESSARY TOTAL FIELDS
      // -------------------------------
      double grossTotal = (_order["grossTotal"] as num?)?.toDouble() ?? 0.0;
      double merchantDiscount = (_order["merchantDiscount"] as num?)?.toDouble() ?? 0.0;
      double cashbackFee = (_order["cashbackFee"] as num?)?.toDouble() ?? 0.0;
      double couponDiscount = (_order["couponDiscount"] as num?)?.toDouble() ?? 0.0;
      double redeemedValue = (_order["redeemedValue"] as num?)?.toDouble() ?? 0.0;

      // If grossTotal missing → fallback to old orderTotal (net)
      if (grossTotal <= 0) {
        grossTotal = (_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;
      }

      // -------------------------------
      // ⭐ EFFECTIVE ORDER TOTAL (REAL NET TOTAL)
      // -------------------------------
      double effectiveOrderTotal = grossTotal;


      // -------------------------------
      // ⭐ REMAINING BALANCE
      // -------------------------------
      balanceAmount = effectiveOrderTotal - tenderAmount;

      // -------------------------------
      // ⭐ CHANGE CALCULATION
      // -------------------------------
      if (balanceAmount <= 0) {
        if (orderStatus != TextConstants.processing) {
          changeAmount = balanceAmount.abs();
          balanceAmount = 0;
        } else {
          changeAmount = 0;
        }
      } else {
        changeAmount = 0;
      }
    });



    if (kDebugMode) {
      print("##### AFTER API REFRESH — remainingBalance = $balanceAmount");

      print("###### Updated values - PayByCash: $payByCash, PayByOther: $payByOther");
      print("###### TenderAmount: $tenderAmount, ChangeAmount: $changeAmount, BalanceAmount: $balanceAmount");
    }
  }

  Future<void> loadPrinterData() async {
    var printerDB = await PrinterDBHelper().getPrinterFromDB();
    if(printerDB.isEmpty){
      if (kDebugMode) {
        print(">>>>> OrderScreenPanel : printerDB is empty");
      }
      return;
    }
    _printerReceipt = printerDB.first;

  }

  // Build #1.0.118: Updated fetchOrdersData to use widget.activeOrderId
  Future<void> fetchOrdersData() async { // Build #1.0.104: created this function for initial load and back button refresh
    if (!mounted) return; // Build #1.0.240 : Added
    setState(() => _isLoading = true); // show loader
    if (kDebugMode) {
      print("##### fetchOrdersData called for activeOrderId: ${widget.activeOrderId}");
    }
    await fetchOrder();
    await fetchOrderItems();

    if (!mounted) return; // Added this check first
    setState(() => _isLoading = false); // Hide loader
  }

  // Updated didUpdateWidget to check activeOrderId
  @override
  void didUpdateWidget(OrderScreenPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Always refresh when instructed by parent
    if (widget.fetchOrders) {
      fetchOrdersData();
      return;
    }

    // Refresh when the activeOrderId changes
    if (mounted && widget.activeOrderId != oldWidget.activeOrderId) {
      fetchOrdersData();
    }
  }
  var _order;
  // Build #1.0.118: Update fetchOrder to use widget.activeOrderId
  Future<void> fetchOrder() async {
    if (widget.activeOrderId == null) {
      _order = {AppDBConst.orderStatus: ''};
      orderServerId = null;
      return;
    }

    //1️⃣ Try normal SQLite order
    List<Map<String, dynamic>> ordersData =
    await orderHelper.getOrderById(widget.activeOrderId!);

    if (ordersData.isNotEmpty) {
      _order = ordersData.first;
      orderServerId = _order[AppDBConst.orderServerId] as int?;
    } else {
      // 2️⃣ FALLBACK → CHECK HIVE DELETED ORDERS
      final deletedBox = StorageProvider.deletedOrders;

      dynamic deleted = await deletedBox.get(widget.activeOrderId.toString());

// 🔥 FIX: If not found by int → try string key
      if (deleted == null) {
        deleted = await deletedBox.get(widget.activeOrderId.toString());
      }

      if (deleted != null) {
        print("🔥 Deleted order FOUND in Hive for ID ${widget.activeOrderId}");
        print("🔥 Deleted full data: $deleted");

        final map = Map<String, dynamic>.from(deleted);

        _order = {
          "id": map["order_id"],
          AppDBConst.orderStatus: "cancelled",
          "offline": true,

          // 🟦 FIXED FIELD NAMES (match deletedOrders box)
          AppDBConst.orderTotal: (map["gross_total"] as num?)?.toDouble() ?? 0.0,
          AppDBConst.orderDiscount: (map["order_discount"] as num?)?.toDouble() ?? 0.0,
          "merchantDiscount": (map["merchant_discount"] as num?)?.toDouble() ?? 0.0,
          AppDBConst.orderTax: (map["order_tax"] as num?)?.toDouble() ?? 0.0,

          //  FIXED NET + PAYABLE
          "netTotal": (map["net_total"] as num?)?.toDouble() ?? 0.0,
          "payable": (map["net_payable"] as num?)?.toDouble() ?? 0.0,

          AppDBConst.orderDate: map["created_at"] ?? DateTime.now().toString(),
        };

        print("🔥 Loaded ORDER from Hive = $_order");

        orderServerId = null;
        return;
      }

      //  No order found at all
      _order = {AppDBConst.orderStatus: ''};
      orderServerId = null;
    }

    // Fetch payments only for online orders
    if (orderServerId != null) {
      _fetchPaymentsByOrderId();
    }
  }

  Future<void> fetchOrderItems() async {
    if (widget.activeOrderId == null) {
      orderItems.clear();
      return;
    }

    // 1️⃣ Try SQLite items
    try {
      List<Map<String, dynamic>> items =
      await orderHelper.getOrderItems(widget.activeOrderId!);

      if (items.isNotEmpty) {
        print("🟦 SQLite Order Items Loaded: $items");

        setState(() => orderItems = items);
        return;
      }
    } catch (_) {}

    // 2️⃣ FALLBACK → Load deleted offline order items
    final deletedBox = StorageProvider.deletedOrders;
    dynamic deleted = await deletedBox.get(widget.activeOrderId.toString());

    if (deleted == null) {
      deleted = deletedBox.get(widget.activeOrderId.toString());
    }

    if (deleted != null) {
      print("🔥 Loading DELETED ORDER ITEMS for ID = ${widget.activeOrderId}");
      _order[AppDBConst.orderStatus] = "cancelled";

      final List productList = deleted["products"] ?? [];
      final List cashbackList = deleted["cashbacks"] ?? [];
      final List payoutList = deleted["payouts"] ?? [];

      List<Map<String, dynamic>> mergedItems = [];

      // 🔵 PRODUCTS
      for (var p in productList) {
        mergedItems.add({
          AppDBConst.itemName: p["name"],
          AppDBConst.itemPrice: p["price"],
          AppDBConst.itemCount: p["quantity"],
          AppDBConst.itemSumPrice: (p["price"] ?? 0) * (p["quantity"] ?? 1),
          AppDBConst.itemImage: p["image"] ?? "",
          AppDBConst.itemType: "product",
        });
      }

      // 🟢 CASHBACKS
      for (var c in cashbackList) {
        mergedItems.add({
          AppDBConst.itemName: c["item_name"] ?? "Cashback",
          AppDBConst.itemPrice: c["item_price"] ?? c["amount"],
          AppDBConst.itemCount: c["items_count"] ?? 1,
          AppDBConst.itemSumPrice: c["item_sum_price"] ?? c["amount"],
          AppDBConst.itemImage: c["product_image"] ?? "",
          AppDBConst.itemType: "cashback",
        });
      }

      // 🔴 PAYOUTS
      for (var p in payoutList) {
        mergedItems.add({
          AppDBConst.itemName: p["product_name"] ?? "Payout",
          AppDBConst.itemPrice: p["amount"],
          AppDBConst.itemCount: 1,
          AppDBConst.itemSumPrice: p["amount"],
          AppDBConst.itemImage: p["product_image"] ?? "",
          AppDBConst.itemType: "payout",
        });
      }

      orderItems = mergedItems;

      print("🔥 Final Loaded Deleted OrderItems = $orderItems");

      setState(() {});
      return;
    }

    // 3️⃣ Nothing found
    orderItems.clear();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    debugPrint("????? OrdersScreenPanel: didChangeDependencies");
    fetchOrderItems();
  }

  @override
  void dispose() {
    _updateOrderSubscription?.cancel(); // Cancel the subscription
    // orderBloc.dispose(); // Dispose the bloc if needed // Build #1.0.143: No need
    _fetchOrdersSubscription?.cancel();
    // orderBloc.dispose();
    productBloc.dispose();
    _tabController?.dispose();
    _productBySkuSubscription?.cancel(); // Build #1.0.44 : Added Cancel product subscription
    productBloc.dispose(); // Added: Dispose ProductBloc
    _paymentListSubscription?.cancel();  // Build #1.0.221
    paymentBloc.dispose();
    super.dispose();
  }

  Future<String> getDeviceId() async { // Build #1.0.44 : Get Device Id
    final storeValidationRepository = StoreValidationRepository();
    try {
      final deviceDetails = await GlobalUtility.getDeviceDetails(); //Build #1.0.126: updated to GlobalUtility
      return deviceDetails['device_id'] ?? 'unknown';
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching device ID: $e');
      }
      return 'unknown';
    }
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.30,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.only(top: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              // Header shimmer
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              // Content shimmer
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 100,
                                height: 10,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer shimmer
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 40,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final themeHelper = Provider.of<ThemeNotifier>(context);
    // final RightOrderPanel orderScreenPanel = RightOrderPanel(formattedDate: '', formattedTime: '', quantities: []);

    // If no order is active, display a blank panel.
    return (!widget.fetchOrders) ? _buildShimmerEffect()
    //     ? Container(
    //   width: MediaQuery.of(context).size.width * 0.30,
    //   padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    //   child: Card(
    //     elevation: 4,
    //     margin: const EdgeInsets.only(top: 10),
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    //     child: Container(), // Shows an empty card
    //   ),
    // )

    // If an order is active, build the regular order panel.
        : Container(
      width: MediaQuery.of(context).size.width * 0.31,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(top: 10),

        // ⬅ Rounded corners (works same for dark & light)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          children: [
            // ⬅ Header section
            Container(
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.primaryBackground
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),   // match card rounding
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "#${widget.activeOrderId ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      StatusWidget(
                        status: _order?[AppDBConst.orderStatus] ?? '',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ⬅ Content below the header
            Expanded(
              child: buildCurrentOrder(),
            ),
          ],
        ),
      ),
    );

  }

  //Build #1.0.67: Handler methods for response and error
  Future<void> _handleResponse(
      APIResponse response,
      Map<String, dynamic> orderItem, {
        bool isPayout = false,
        bool isCoupon = false,
        bool isCustomItem = false,
        VoidCallback? retryCallback, // Call back
      }) async {
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (response.status == Status.COMPLETED) {
      if (Misc.showDebugSnackBar) { // Build #1.0.254
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("${isPayout ? TextConstants.payout : isCoupon ? TextConstants.coupon : isCustomItem ? TextConstants.customItem : 'Item'}" "${TextConstants.removedSuccessfully}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await orderHelper.deleteItem(orderItem[AppDBConst.itemId]);
      await fetchOrderItems();
      widget.refreshOrderList?.call();
    } else if (response.status == Status.ERROR) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(response.message ?? "${TextConstants.failedToRemove}" "${isPayout ? TextConstants.payout : isCoupon ? TextConstants.coupon : isCustomItem ? TextConstants.coupon : 'item'}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (isPayout) {
        await CustomDialog.showDiscountNotApplied(
          context,
          errorMessageTitle: TextConstants.removePayoutFailed,
          errorMessageDes: response.message ?? TextConstants.discountNotAppliedDescription,
          onRetry: retryCallback, // Pass retry callback
        );
      } else if (isCoupon) {
        await CustomDialog.showCouponNotApplied(
          context,
          errorMessageTitle: TextConstants.removeCouponFailed,
          errorMessageDes: response.message ?? TextConstants.couponNotAppliedDescription,
          onRetry: retryCallback, // Pass retry callback
        );
      } else if (isCustomItem) {
        await CustomDialog.showCustomItemNotAdded(
          context,
          errorMessageTitle: TextConstants.removeCustomItemFailed,
          errorMessageDes: response.message ?? TextConstants.customItemCouldNotBeAddedDescription,
          onRetry: retryCallback,
        );
      }
    }
  }
  Future<double> loadCashbackFee({
    required String offlineOrderId,
  }) async {
    // 🟢 1️⃣ orderExtras (persistent, survives sync & delete)
    final extras = await StorageProvider.orderExtras.get(offlineOrderId);
    if (extras != null && extras is Map && extras["cashback_fee"] != null) {
      final cashback = (extras["cashback_fee"] as num).toDouble();
      debugPrint("💰 Cashback from orderExtras (local) → $cashback");
      return cashback;
    }

    // 🟡 2️⃣ offlineOrders (while order exists)
    final offline = await StorageProvider.offlineOrders.get(offlineOrderId);
    if (offline != null && offline is Map && offline["cashback_fee"] != null) {
      final cashback = (offline["cashback_fee"] as num).toDouble();
      debugPrint("💰 Cashback from offlineOrders → $cashback");
      return cashback;
    }

    debugPrint("💰 Cashback not found → 0.0");
    return 0.0;
  }



  Widget buildCurrentOrder() {
    final theme = Theme.of(context);
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final ScrollController _scrollController = ScrollController();
    final order = _order ?? {};
    String displayDate = widget.formattedDate;
    String displayTime = widget.formattedTime;

    if (order.isNotEmpty && order[AppDBConst.orderDate] != null) {
      try {
        final DateTime createdDateTime =
        DateTime.parse(order[AppDBConst.orderDate].toString());
        displayDate =
            DateFormat(TextConstants.dateFormat).format(createdDateTime);
        displayTime =
            DateFormat(TextConstants.timeFormat).format(createdDateTime);
      } catch (e) {
        print("Error parsing date: $e");
        displayDate = order[AppDBConst.orderDate].toString().split(' ').first;
      }
    }

    double orderDiscount =
        (order[AppDBConst.orderDiscount] as num?)?.toDouble() ?? 0.0;
    double merchantDiscount = 0.0;

    // MERCHANT DISCOUNT FROM ITEMS
    for (var item in orderItems) {
      if (item['item_name'] != null &&
          item['item_name'].toString().toLowerCase() == "discount") {
        double? discountValue =
        double.tryParse(item['item_sum_price'].toString());
        if (discountValue != null && discountValue < 0) {
          merchantDiscount = discountValue.abs();
          print("### Merchant Discount Found in Items: $merchantDiscount");
        }
      }
    }

    double grossTotal = 0.0;

    for (var item in orderItems) {
      // Extract item name and type (fallback-safe)
      // final name = (item["item_name"] ?? item["name"] ?? "").toString().toLowerCase();
      // final type = (item["item_type"] ?? item["type"] ?? "").toString().toLowerCase();

      // ❌ SKIP unwanted items
      final name = item["item_name"]?.toString().toLowerCase() ?? "";
      final type = item["item_type"]?.toString().toLowerCase() ?? "";



      final skip =
          name.contains("discount") ||
              name.contains("merchant discount") ||
              name.contains("coupon") ||
              name.contains("loyalty") ||     // FIXED
              name.contains("redeemed") ||
              name.contains("points") ||
              type.contains("discount") ||
              type.contains("coupon") ||
              type.contains("loyalty") ||     // FIXED
              type.contains("points");

      if (skip) {
        print("🚫 EXCLUDED FROM GROSS TOTAL → ${item["item_name"]}");
        continue;
      }



      // Qty fallback logic
      final qty = int.tryParse(
          item["items_count"]?.toString() ??
              item["itemCount"]?.toString() ??
              "1"
      ) ?? 1;


      final double multipackDiscount =
          (item[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;

      final double autoDiscount =
          (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;

      // final double comboDiscount =
      //     (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;

      final double comboDiscount    = (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;


      // Price priority
      double unitPrice =
          double.tryParse(item["item_sum_price"]?.toString() ?? "") ??
              double.tryParse(item["amount"]?.toString() ?? "") ??
              double.tryParse(item["item_price"]?.toString() ?? "") ??
              double.tryParse(item["price"]?.toString() ?? "") ??
              0.0;

      grossTotal += unitPrice -multipackDiscount- autoDiscount -comboDiscount ;

    }



    print("### Gross Total Calculated: $grossTotal");

    double wooTax = (order['wooTax'] as num?)?.toDouble() ?? 0.0;
    double wooTotal = (order['wooTotal'] as num?)?.toDouble() ?? 0.0;

    double sqliteTax = (order[AppDBConst.orderTax] as num?)?.toDouble() ?? 0.0;
    double sqliteTotal =
        (order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;

    // TAX: Woo overrides SQLite
    double orderTax = wooTax > 0 ? wooTax : sqliteTax;

    double cashbackFee = 0.0;

    final wooOrderId =
        order['wooOrderId']?.toString() ?? widget.activeOrderId?.toString() ?? "";

    // Load Redeem Data from order (pre-loaded from storage by parent)
    if (wooOrderId.isNotEmpty && order["redeemed_value"] != null) {
      hiveRedeemedValue = (order["redeemed_value"] as num).toDouble();
      hiveRedeemedPoints = (order["redeemed_points"] as num?)?.toInt() ?? 0;
      hiveAvailablePoints = (order["available_points_after_redeem"] as num?)?.toInt() ?? 0;
      print("💠 Redeem from order → Value: $hiveRedeemedValue | Points: $hiveRedeemedPoints");
    }

    int totalItems = 0;

    for (var item in orderItems) {
      final name = item[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
      final type = item[AppDBConst.itemType]?.toString().toLowerCase() ?? "";

// FILTER OUT ALL DISCOUNT/PAYOUT/COUPON ITEMS
      if (name.contains("discount") ||
          type.contains("discount") ||
          name.contains("merchant discount") ||
          type.contains("merchant discount") ||
          type.contains("payout") ||
          type.contains("coupon") ||
          type.contains("cashback") ||
          name.contains("payout") ||
          name.contains("coupon") ||
          name.contains("cashback")) {
        continue;
      }


      final qty = (item[AppDBConst.itemCount] as num?)?.toInt() ?? 1;
      totalItems += qty;
    }


    final cf = order["cashbackFee"] ?? order["cashback_fee"] ?? 0.0;
    cashbackFee = (cf is num) ? (cf as num).toDouble() : 0.0;



    // ----------- ONLINE TOTAL COMPUTATION -----------
    // NET TOTAL (no tax)
    num netTotal = grossTotal - orderDiscount;
    if (netTotal < 0) netTotal = 0;

    // NET PAYABLE WITH TAX + CASHBACK
    double computedNetPayable =
        grossTotal + orderTax - orderDiscount - merchantDiscount + cashbackFee;

    if (computedNetPayable < 0) computedNetPayable = 0;

    // Woo total overrides only if > 0
    double netPayable =
    wooTotal > 0 ? wooTotal : computedNetPayable;
    uiGrossTotal = grossTotal;
    uiOrderDiscount = orderDiscount;
    uiMerchantDiscount = merchantDiscount;
    uiOrderTax = orderTax;
    uiNetPayable = netPayable;
    uiCashbackFee = cashbackFee;
    uiTotalItems = totalItems;
    uiRedeemedValue = hiveRedeemedValue;


    // ---------- DO NOT TOUCH OFFLINE OVERRIDE ----------
    if (order["offline"] == true) {
      grossTotal =
          (order[AppDBConst.orderTotal] as num?)?.toDouble() ?? grossTotal;
      orderDiscount =
          (order[AppDBConst.orderDiscount] as num?)?.toDouble() ?? orderDiscount;
      merchantDiscount =
          (order["merchantDiscount"] as num?)?.toDouble() ?? merchantDiscount;
      orderTax =
          (order[AppDBConst.orderTax] as num?)?.toDouble() ?? orderTax;
      netTotal =
          (order["netTotal"] as num?)?.toDouble() ?? netTotal;
      netPayable =
          (order["payable"] as num?)?.toDouble() ?? netPayable;


      print("🔥 OFFLINE OVERRIDE APPLIED:");
      print("grossTotal       = $grossTotal");
      print("orderDiscount    = $orderDiscount");
      print("merchantDiscount = $merchantDiscount");
      print("orderTax         = $orderTax");
      print("netTotal         = $netTotal");
      print("netPayable       = $netPayable");
    }

    // ---------- SUMMARY LOGS ----------
    print("🟦 Summary Data:");
    print("Gross Total         → $grossTotal");
    print("SQLite Discount     → $orderDiscount");
    print("SQLite M. Discount  → $merchantDiscount");
    print("Woo Tax             → $wooTax");
    print("Woo Total           → $wooTotal");
    print("SQLite Tax          → $sqliteTax");
    print("SQLite Total        → $sqliteTotal");
    print("Final TAX Used      → $orderTax");
    print("Net Local Total     → $netTotal");
    print("Final Payable       → $netPayable");


    return Stack(
      children: [
        Column(
          children: [
            Container(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
              padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if(widget.activeOrderId != null)
                    Row(
                      spacing: 4,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset('assets/svg/calendar.svg',width: 22,height: 22,color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,),
                        Text(displayDate,  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.secondaryHeaderColor)),
                        const SizedBox(width: 110),
                        SvgPicture.asset('assets/svg/clock.svg',width: 22,height: 22,color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,),
                        Text(displayTime ,style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.secondaryHeaderColor)),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: DottedLine(
                dashLength: 4,
                dashGapLength: 4,
                lineThickness: 1,
                dashColor: theme.secondaryHeaderColor,
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  // color: themeHelper.themeMode == ThemeMode.dark
                  //     ? const Color(0xFF353848) // dark mode background
                  //     : const Color(0xFFE0E5F7), // light mode background
                  // borderRadius: BorderRadius.circular(12),
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
                ),
                //color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
                child: Padding(
                  padding: const EdgeInsets.only(left: 0, right: 0),
                  child: Scrollbar(
                    controller: _scrollController,
                    scrollbarOrientation: ScrollbarOrientation.right,
                    thumbVisibility: true,
                    thickness: 8.0,
                    interactive: false,
                    radius: const Radius.circular(8),
                    trackVisibility: true,
                    child:
                    ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      //Build #1.0.4: re-order for list
                      onReorder: (oldIndex, newIndex) {
                        if (kDebugMode) {
                          print("Reordering item from $oldIndex to $newIndex");
                        } // Debug print
                        if (oldIndex < newIndex) newIndex -= 1;

                        setState(() {
                          final movedItem = orderItems.removeAt(oldIndex);
                          orderItems.insert(newIndex, movedItem);
                          //  FORCE CASHBACK TO ALWAYS COME LAST
                          orderItems.sort((a, b) {
                            final typeA = a[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
                            final typeB = b[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
                            print("SORT DEBUG → typeA: $typeA   typeB: $typeB");

                            final isCashbackA = typeA.contains("cashback");
                            final isCashbackB = typeB.contains("cashback");

                            // Cashback goes last
                            if (isCashbackA && !isCashbackB) return 1;
                            if (!isCashbackA && isCashbackB) return -1;

                            return 0; // keep original order otherwise
                          });
                        });
                      },
                      scrollController: _scrollController,
                      itemCount: orderItems.length,
                      proxyDecorator: (Widget child, int index,
                          Animation<double> animation) {
                        return Material(
                          color: Colors.transparent, // Removes white background
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final orderItem = orderItems[index];


                        final itemTypeRaw = orderItem[AppDBConst.itemType]
                            ?.toString()
                            .toLowerCase() ?? '';

                        final itemNameRaw = orderItem[AppDBConst.itemName]
                            ?.toString()
                            .toLowerCase() ?? '';

                        final bool isEbtEligible = orderItem['is_ebt_eligible'] == true;  // ✅ FIXED


                        /// Hide coupons
                        if (itemTypeRaw.contains(TextConstants.couponText.toLowerCase())) {
                          return Container(
                            key: ValueKey("coupon_$index"),
                            height: 0,
                          );
                        }

                        /// Hide Merchant Discount item from list but keep in summary
                        if (itemTypeRaw.contains("discount") ||
                            itemNameRaw.contains("discount")) {
                          return Container(
                            key: ValueKey("merchant_discount_$index"),
                            height: 0,
                          );
                        }

                        /// 🔥 Hide loyalty products (name-based + type-based)
                        if (itemNameRaw.contains("loyalty") ||
                            itemNameRaw.contains("reward") ||
                            itemNameRaw.contains("points") ||
                            itemTypeRaw.contains("loyalty")) {
                          return Container(
                            key: ValueKey("loyalty_$index"),
                            height: 0,
                          );
                        }


                        ///Build #1.0.64:  added conditions
                        /// Compare item type
                        /// if it is payout change icon, name is empty, show amount in red colour
                        /// if it is coupon change icon, name is coupon code (show last 4 digits, prefix with 'X' for each character before last 4), show amount in red colour
                        final itemType = orderItem[AppDBConst.itemType]
                            ?.toString()
                            .toLowerCase() ??
                            '';
                        final itemName =
                        (orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? '');
                        /// Check if the item is a payout or a coupon
                        final isPayout =
                        itemType.contains(TextConstants.payoutText);
                        final isCoupon =
                        itemType.contains(TextConstants.couponText);
                        // ✅ STRONG cashback detection
                        final isCashback =
                            itemType.contains('cashback') || itemName.contains('cashback');
                        final isCustomItem =
                        itemType.contains(TextConstants.customItemText);
                        final isPayoutOrCouponOrCustomItem =
                            isPayout || isCoupon || isCustomItem || isCashback;

                        final isCouponOrPayout = isPayout || isCoupon || isCashback;

                        /// Get the original name
                        final originalName =
                            orderItem[AppDBConst.itemName]?.toString() ?? '';
                        final variationName =
                            orderItem[AppDBConst.itemVariationCustomName]
                                ?.toString() ??
                                'N/A';
                        final variationCount =
                            orderItem[AppDBConst.itemVariationCount] ?? 0;
                        final combo = orderItem[AppDBConst.itemCombo] ?? '';


                        final double multipackDiscount =
                            (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;

                        final double autoDiscount =
                            (orderItem[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;

                        // final double comboDiscount =
                        //     (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;

                        final double comboDiscount    = (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;

                        /// Build #1.0.134: Item Price will check sales price if it is null/empty, check regular price else unit price
                        final salesPrice = (orderItem[
                        AppDBConst.itemSalesPrice] ==
                            null ||
                            (orderItem[AppDBConst.itemSalesPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? (orderItem[AppDBConst.itemRegularPrice] == null ||
                            (orderItem[AppDBConst.itemRegularPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]
                            ?.toDouble() ??
                            0.0
                            : orderItem[AppDBConst.itemRegularPrice]!
                            .toDouble()
                            : orderItem[AppDBConst.itemSalesPrice]!.toDouble();

                        final regularPrice =
                        (orderItem[AppDBConst.itemRegularPrice] == null ||
                            (orderItem[AppDBConst.itemRegularPrice]
                                ?.toDouble() ??
                                0.0) ==
                                0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]
                            ?.toDouble() ??
                            0.0
                            : orderItem[AppDBConst.itemRegularPrice]!
                            .toDouble();

                        double itemTotalPrice = 0.0;

                        if (isPayout || isCashback) {
                          itemTotalPrice =
                              (orderItem['amount'] as num?)?.toDouble() ??
                                  (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                  0.0;
                        } else {
                          itemTotalPrice =
                              (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;
                        }


                        if (kDebugMode) {
                          print(
                              "#### originalName: $originalName, itemType: $itemType, isPayoutOrCouponOrCustomItem: $isPayoutOrCouponOrCustomItem");
                          print(
                              "#### variationName: $variationName, variationCount: $variationCount, combo: $combo");
                          print(
                              "#### salesPrice: $salesPrice, regularPrice: $regularPrice, itemTotalPrice: $itemTotalPrice");
                        }

                        /// Set display name based on item type
                        String displayName = originalName;

                        if (isPayout) {
                          displayName = 'Payout';

                        } else if (isCashback) {
                          displayName = 'Cashback';

                        } else if (isCoupon) {
                          final visiblePartLength = 4;
                          final nameLength = originalName.length;

                          if (nameLength > visiblePartLength) {
                            final maskedLength = nameLength - visiblePartLength;
                            final maskedPart = 'X' * maskedLength;
                            final visiblePart = originalName.substring(nameLength - visiblePartLength);
                            displayName = '$maskedPart$visiblePart';
                          }
                        }
                        return
                          ClipRRect(
                            key: ValueKey(index),
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              // Ensuring Slidable matches the item height
                              height: 70, // reduce height
                              //height: MediaQuery.of(context).size.height * 0.12, // Adjust to match your item height
                              child: Slidable(
                                //Build #1.0.2 : added code for delete the items in list
                                key: ValueKey(index),
                                enabled: false,
                                closeOnScroll: true,
                                direction: Axis.horizontal,
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  children: [
                                    CustomSlidableAction(
                                      onPressed: (context) => {},
                                      backgroundColor: Colors.transparent,
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          const SizedBox(height: 4),
                                          const Text(TextConstants.deleteText,
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    if (isPayoutOrCouponOrCustomItem) return;
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute(
                                    //     builder: (context) => EditProductScreen(
                                    //       orderItem: orderItem,
                                    //       onQuantityUpdated: (newQuantity) async {
                                    //
                                    //         if (orderHelper.activeOrderId != null) {
                                    //           final order = orderHelper.orders.firstWhere(
                                    //                 (order) => order[AppDBConst.orderId] == orderHelper.activeOrderId,
                                    //             orElse: () => {},
                                    //           );
                                    //           final serverOrderId = order[AppDBConst.orderServerId] as int?;
                                    //           final dbOrderId = orderHelper.activeOrderId;
                                    //           // final lineItemId = orderItem[AppDBConst.itemServerId] as int?;
                                    //           final productId = orderItem[AppDBConst.itemServerId] as int?;
                                    //
                                    //           if (serverOrderId != null && dbOrderId != null && productId != null) {
                                    //             _updateOrderSubscription?.cancel();
                                    //             _updateOrderSubscription = orderBloc.updateOrderStream.listen((response) async {
                                    //               if (response.status == Status.COMPLETED) {
                                    //                 await orderHelper.updateItemQuantity(
                                    //                   orderItem[AppDBConst.itemId],
                                    //                   newQuantity,
                                    //                 );
                                    //                 await fetchOrderItems();
                                    //               } else if (response.status == Status.ERROR) {
                                    //                 _scaffoldMessenger.showSnackBar(
                                    //                   SnackBar(
                                    //                     content: Text(response.message ?? "Failed to update quantity"),
                                    //                     backgroundColor: Colors.red,
                                    //                     duration: const Duration(seconds: 2),
                                    //                   ),
                                    //                 );
                                    //               }
                                    //             });
                                    //             // API CALL WHILE EDITING THE PRODUCT QUANTITY
                                    //             await orderBloc.updateOrderProducts(
                                    //               orderId: serverOrderId,
                                    //               dbOrderId: dbOrderId,
                                    //               lineItems: [
                                    //                 OrderLineItem(
                                    //                   productId: productId,
                                    //                   quantity: newQuantity,
                                    //                 ),
                                    //               ],
                                    //             );
                                    //           } else {
                                    //             await orderHelper.updateItemQuantity(
                                    //               orderItem[AppDBConst.itemId],
                                    //               newQuantity,
                                    //             );
                                    //             await fetchOrderItems();
                                    //           }
                                    //         }
                                    //       },
                                    //     ),
                                    //   ),
                                    // );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 1, horizontal: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode ==
                                          ThemeMode.dark
                                          ? Color(0xFF252837)
                                          : Color(0xFFE8E8E8), // ThemeNotifier.secondaryBackground color of items in order panel
                                      borderRadius: BorderRadius.circular(8),
                                      //   BoxShadow(
                                      //     color: Colors.black12,
                                      //     blurRadius: 5,
                                      //     spreadRadius: 1,
                                      //   )
                                      // ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Replace the ClipRRect widget with this:
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(5),
                                          child: isPayout
                                              ? SvgPicture.asset(
                                            "assets/svg/payout.svg",
                                            height: MediaQuery.of(context).size.height * 0.08,
                                            width: MediaQuery.of(context).size.height * 0.075,
                                            fit: BoxFit.cover,
                                          ) : isCashback
                                              ? Image.asset(
                                            "assets/cashback.jpeg",
                                            height: MediaQuery.of(context).size.height * 0.08,
                                            width: MediaQuery.of(context).size.height * 0.075,
                                            fit: BoxFit.cover,
                                          )

                                              : buildProductImage(
                                            orderItem[AppDBConst.itemImage]?.toString(),
                                            height: MediaQuery.of(context).size.height * 0.08,
                                            width: MediaQuery.of(context).size.height * 0.075,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                MainAxisAlignment.start,
                                                children: [
                                                  RichText(
                                                    maxLines: 2,
                                                    softWrap: true,
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: displayName,
                                                          style: TextStyle(
                                                              fontFamily: 'inter',
                                                              fontSize: 12,
                                                              fontWeight:
                                                              FontWeight.w700,
                                                              color: themeHelper
                                                                  .themeMode ==
                                                                  ThemeMode
                                                                      .dark
                                                                  ? ThemeNotifier
                                                                  .textDark
                                                                  : ThemeNotifier
                                                                  .textLight),
                                                        ),


                                                        TextSpan(
                                                          text: combo == ''
                                                              ? ''
                                                              : " (Combo)",
                                                          style: TextStyle(
                                                              fontSize: 8,
                                                              color: Colors.cyan),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  if (multipackDiscount > 0) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "Multipack Discount: -${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],


                                                  if (autoDiscount > 0) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "auto Discount : -${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],

                                                  // if (combo != '' && comboDiscount > 0) ...[
                                                  //   const SizedBox(height: 2),
                                                  //   Text(
                                                  //     "Combo Discount: -${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
                                                  //     style: TextStyle(
                                                  //       fontSize: 10,
                                                  //       fontWeight: FontWeight.w600,
                                                  //       color: Colors.green,
                                                  //     ),
                                                  //   ),
                                                  // ],

                                                  if (comboDiscount > 0) ...[   // ← just check value > 0
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "Combo Discount: -${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                                                    ),
                                                  ],
                                                  variationCount == 0
                                                      ? SizedBox(
                                                    width: 0,
                                                  )
                                                      : Row(
                                                    children: [
                                                      Text(
                                                        variationName == ''
                                                            ? ""
                                                            : "(${variationName ?? ''})",
                                                        overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: themeHelper
                                                                .themeMode ==
                                                                ThemeMode
                                                                    .dark
                                                                ? ThemeNotifier
                                                                .textDark
                                                                : Colors
                                                                .grey),
                                                      ),
                                                      SizedBox(
                                                        width: 4,
                                                      ),
                                                      SvgPicture.asset(
                                                        "assets/svg/variation.svg",
                                                        height: 10,
                                                        width: 10,
                                                      ),
                                                      SizedBox(
                                                        width: 4,
                                                      ),
                                                      Text(
                                                        "${variationCount ?? 0}",
                                                        overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Color(
                                                                0xFFFE6464)),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (isEbtEligible) ...[
                                                const SizedBox(height: 3),
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
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],

                                              //Modified: Show quantity * price only for non-Payout/Coupon items

                                              // if (!isPayoutOrCouponOrCustomItem) ...[
                                              //   Builder(
                                              //     builder: (context) {
                                              //       double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1;
                                              //
                                              //       double unitPrice =
                                              //           (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////---
                                              //           (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                              //               (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                              //               (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////
                                              //               0.0;   ////
                                              //
                                              //       // If still zero → derive price from sum price
                                              //       if (unitPrice == 0.0) {
                                              //         final double sumPrice =
                                              //             (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;
                                              //
                                              //         if (sumPrice > 0 && qty > 0) {
                                              //           unitPrice = sumPrice / qty;
                                              //         }
                                              //       }
                                              //
                                              //       return Text(
                                              //         "${TextConstants.currencySymbol} ${unitPrice.toStringAsFixed(2)} × ${qty.toInt()}",
                                              //
                                              //
                                              //         style: TextStyle(
                                              //           color: themeHelper.themeMode == ThemeMode.dark
                                              //               ? ThemeNotifier.textDark
                                              //               : Colors.black54,
                                              //           fontSize: 10,
                                              //         ),
                                              //       );
                                              //     },
                                              //   ),
                                              // ],

                                              if (!isPayoutOrCouponOrCustomItem) ...[
                                                Builder(
                                                  builder: (context) {
                                                    double qty =
                                                        (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1;

                                                    double unitPrice =
                                                    // (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////---
                                                    (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                                        (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                                        (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??  ////
                                                        0.0;   ////

                                                    // If still zero → derive price from sum price
                                                    if (unitPrice == 0.0) {
                                                      final double sumPrice =
                                                          (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;

                                                      if (sumPrice > 0 && qty > 0) {
                                                        unitPrice = sumPrice / qty;
                                                      }
                                                    }

                                                    // 🔹 NEW: calculate total amount
                                                    final double totalAmount = unitPrice * qty;

                                                    return Text(
                                                      // 🔹 OLD: only unit price × qty
                                                      // "${TextConstants.currencySymbol} ${unitPrice.toStringAsFixed(2)} × ${qty.toInt()}",

                                                      // 🔹 NEW: show unit price × qty = total amount
                                                      "${TextConstants.currencySymbol} ${unitPrice.toStringAsFixed(2)} × ${qty.toInt()} ",
                                                      // "= ${TextConstants.currencySymbol} ${totalAmount.toStringAsFixed(2)}",

                                                      style: TextStyle(
                                                        color: themeHelper.themeMode == ThemeMode.dark
                                                            ? ThemeNotifier.textDark
                                                            : Colors.black54,
                                                        fontSize: 10,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],


                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [


                                            // Text(
                                            //   isPayout
                                            //       ? "-${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.abs().toStringAsFixed(2)}"
                                            //       : isCashback
                                            //       ? "${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.toStringAsFixed(2)}"
                                            //       : "${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.toStringAsFixed(2)}",
                                            //   style: TextStyle(
                                            //     fontSize: 14,
                                            //     fontWeight: FontWeight.bold,
                                            //     color: isPayout
                                            //         ? Colors.red
                                            //         : isCashback
                                            //         ? (themeHelper.themeMode == ThemeMode.dark
                                            //         ? ThemeNotifier.textDark
                                            //         : ThemeNotifier.textLight)
                                            //         : (isCoupon
                                            //         ? Colors.red
                                            //         : (themeHelper.themeMode == ThemeMode.dark
                                            //         ? ThemeNotifier.textDark
                                            //         : ThemeNotifier.textLight)),
                                            //   ),
                                            // )


                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                if (isPayout || isCoupon )
                                                  Text(
                                                    "-${TextConstants.currencySymbol}${(orderItem[AppDBConst.itemSumPrice] as num?)!.abs().toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red,
                                                    ),
                                                  )
                                                else
                                                  Builder(
                                                    builder: (context) {
                                                      final double actualSumPrice = (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;

                                                      double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1;
                                                      double unitPrice = (orderItem[AppDBConst.itemUnitPrice] as num?)?.toDouble() ??
                                                          (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ??
                                                          (orderItem[AppDBConst.itemRegularPrice] as num?)?.toDouble() ??
                                                          0.0;

                                                      if (unitPrice == 0.0 && actualSumPrice > 0 && qty > 0) {
                                                        unitPrice = actualSumPrice / qty;
                                                      }

                                                      final double originalTotal = unitPrice * qty;
                                                      final double totalDiscount = multipackDiscount + autoDiscount + comboDiscount;

                                                      final bool showStrikethrough = totalDiscount > 0 &&
                                                          originalTotal > actualSumPrice &&
                                                          (originalTotal - actualSumPrice).abs() > 0.01;

                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Text(
                                                            isCashback
                                                                ? "${TextConstants.currencySymbol}${actualSumPrice.toStringAsFixed(2)}"
                                                                : "${TextConstants.currencySymbol}${actualSumPrice.toStringAsFixed(2)}",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: isCashback
                                                                  ? (themeHelper.themeMode == ThemeMode.dark
                                                                  ? ThemeNotifier.textDark
                                                                  : ThemeNotifier.textLight)
                                                                  : (showStrikethrough
                                                                  ? Colors.black87
                                                                  : (themeHelper.themeMode == ThemeMode.dark
                                                                  ? ThemeNotifier.textDark
                                                                  : ThemeNotifier.textLight)),
                                                            ),
                                                          ),
                                                          if (showStrikethrough)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                "${TextConstants.currencySymbol}${originalTotal.toStringAsFixed(2)}",
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: themeHelper.themeMode == ThemeMode.dark
                                                                      ? Colors.grey.shade400
                                                                      : Colors.black54,
                                                                  decoration: TextDecoration.lineThrough,
                                                                  decorationColor: Colors.black,
                                                                  decorationThickness: 2,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                              ],
                                            )                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                      },
                    ),
                  ),
                ),
              ),
            ),

            ///Todo: update ui as per loading from screen
            ///Show print and email invoice buttons if coming from order history screen
            ///else show regular buttons
            Container(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
              child: Column(
                children: [
                  // Summary container
                  AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showFullSummary
                          ? SizedBox(
                          child: Container(
                              margin: const EdgeInsets.only(
                                  top: 8, right: 7, left: 7),
                              // margin: const EdgeInsets.only(top: 8, right: 8, left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    topLeft: Radius.circular(8)),
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.orderPanelSummary
                                    : Colors.white,
                                boxShadow: [
                                  // Shadow at the bottom
                                  BoxShadow(
                                    // color: Colors.black.withOpacity(0.25),
                                    color: themeHelper.themeMode == ThemeMode.dark
                                        ? Color(0xFFF0F0F0).withOpacity(
                                        0.15) // stronger shadow for dark mode
                                        : Colors.black.withOpacity(
                                        0.25), // lighter shadow for light mode
                                    offset: Offset(
                                        0, 4), // 0 horizontal, 4 vertical (down)
                                    blurRadius: 6,
                                    spreadRadius: -0.5,
                                  ),
                                  // Shadow at the top
                                  BoxShadow(
                                    color: themeHelper.themeMode == ThemeMode.dark
                                        ? Color(0xFFF0F0F0).withOpacity(
                                        0.15) // dark mode top shadow
                                        : Colors.black.withOpacity(
                                        0.15), // light mode top shadow
                                    // color: Colors.black.withOpacity(0.15),
                                    offset: Offset(
                                        0, -4), // 0 horizontal, -4 vertical (up)
                                    blurRadius: 6,
                                    spreadRadius: -0.5,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(        // ✅ scroll added
                                physics: const BouncingScrollPhysics(),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          TextConstants.grossTotal,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                        Text(
                                          grossTotal < 0
                                              ? '-${TextConstants.currencySymbol}${grossTotal.abs().toStringAsFixed(2)}'
                                              : '${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.textDark
                                                : ThemeNotifier.textLight,
                                          ),
                                        ),

                                      ],
                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          spacing: 5,
                                          children: [
                                            // SvgPicture.asset(
                                            //   "assets/svg/discount_star.svg",
                                            //   height: 12,
                                            //   width: 12,
                                            // ),
                                            Text(TextConstants.discountText,
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 14)),
                                          ],
                                        ),
                                        Text(
                                            "-${TextConstants.currencySymbol}${orderDiscount.toStringAsFixed(2)}",
                                            style: TextStyle(
                                                color: Colors.green, fontSize: 14)),
                                      ],
                                    ),

                                    SizedBox(
                                      height: 2,
                                    ),
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
                                    SizedBox(
                                      height: 2,
                                    ),
                                    // const DottedLine(),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          TextConstants.netTotalText,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                        Text(
                                            "${TextConstants.currencySymbol}${netTotal.toStringAsFixed(2)}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: themeHelper.themeMode ==
                                                    ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : ThemeNotifier.textLight)),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          TextConstants.taxText,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.grey),
                                        ),
                                        Text(
                                            "${TextConstants.currencySymbol}${orderTax.toStringAsFixed(2)}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: themeHelper.themeMode ==
                                                    ThemeMode.dark
                                                    ? Colors.white54
                                                    : Colors.grey)),
                                      ],
                                    ),
                                    if(merchantDiscount>0)
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            spacing: 5,
                                            children: [
                                              // SvgPicture.asset(
                                              //   "assets/svg/discount_star.svg",
                                              //   height: 12,
                                              //   width: 12,
                                              //   color: Colors.blue, // 👈 apply blue color
                                              // ),
                                              Text(TextConstants.merchantDiscount,
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 14)),


                                            ],
                                          ),
                                          Text(
                                              "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                  color: Colors.blue, fontSize: 14)),
                                        ],
                                      ),
                                    SizedBox(
                                      height: 2,
                                    ),

                                    if (cashbackFee > 0)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            TextConstants.cashbackFee,
                                            style: const TextStyle(
                                              color: Color(0xFF55CBCD),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              color: Color(0xFF55CBCD),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                        ],
                                      ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(TextConstants.servicecharges),
                                        Text(
                                          "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}",
                                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                                        ),
                                      ],
                                    ),

                                    SizedBox(
                                      height: 2,
                                    ),
                                    //const DottedLine(),
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
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(TextConstants.netPayable,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            "${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: themeHelper.themeMode ==
                                                    ThemeMode.dark
                                                    ? ThemeNotifier.textDark
                                                    : ThemeNotifier.textLight)),
                                      ],

                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    if (hiveRedeemedValue > 0)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Redeemed Value",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.green,
                                            ),
                                          ),
                                          Text(
                                            "- ${TextConstants.currencySymbol}${hiveRedeemedValue.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),

                                  ],
                                ),
                              )))
                          : SizedBox.shrink()

                  ),
                  if(widget.activeOrderId != null)
                    GestureDetector(
                      onTap: _toggleSummary,
                      child: Container(
                        margin: const EdgeInsets.only(top:0 , right: 6, left: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(8), bottomLeft: Radius.circular(8)),
                          // color: themeHelper.themeMode == ThemeMode.dark ?const Color(0xFF393C48) : Colors.grey.shade300
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(0xFF2A2C36) // ✅ dark mode background 393C48
                              : Colors.grey.shade300,   // ✅ light mode background
                          boxShadow: [
                            // Shadow at the bottom
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 4), // moves shadow down
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                            // Shadow at the top
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 4), // moves shadow up
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${TextConstants.totalItemsText}: $totalItems",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(
                                    _showFullSummary
                                        ? 'Net Payable : ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}'
                                        : 'Net Payable : ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Icon(_showFullSummary ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                              ],
                            ),
                          ],
                        ),


                      ),
                    )
                  else
                    SizedBox(),
                  const SizedBox(height: 4),

                  // Payment button - outside the container
                  if (widget.activeOrderId != null)
                    Container(

                      margin: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 5),
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.0575,
                      child: ((_order?[AppDBConst.orderStatus] ?? '') !=
                          TextConstants.pending)
                          ? ElevatedButton(
                        //Build 1.1.36: on pay tap calling updateOrderProducts api call
                        onPressed: () async {
                          if (orderHelper.activeOrderId != null) {
                            setState(() {
                              _isPayBtnLoading = true;
                            });

                            if (kDebugMode) {
                              print(
                                  "OrderScreenPanel - call printer setup screen, $_printerReceipt");
                            }
                            if (!Misc.disablePrinter) {
                              ///prepare receipt
                              await _preparePrintTicket();

                              ///print invoice
                              await _printTicket();
                            }
                            setState(() => _isPayBtnLoading = false);
                            // if(_printerReceipt == null || (_printerReceipt != null && _printerReceipt[AppDBConst.printerDeviceName] == '')){
                            //   /// call printer setup screen
                            //   if (kDebugMode) {
                            //     print("OrderScreenPanel - call printer setup screen");
                            //   }
                            //   Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) => PrinterSetup(),
                            //       )).then((result) async {
                            //     if (result == 'refresh') {
                            //       await _printerSettings.loadPrinter();
                            //       await loadPrinterData();
                            //       setState(() async {
                            //         // Update state to refresh the UI
                            //         if (kDebugMode) {
                            //           print(
                            //               "OrderScreenPanel - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
                            //         }
                            //         ///print invoice
                            //         await _printTicket();
                            //         setState(() => _isPayBtnLoading = false);
                            //       });
                            //     }
                            //   });
                            // } else {
                            //
                            // }
                          }
                        },
                        // style: ElevatedButton.styleFrom(
                        //   backgroundColor: Colors.transparent, // 🔑 keep transparent
                        //   shadowColor: Colors.transparent, // 🔑 remove shadow blending
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(16),
                        //   ),
                        //   padding: EdgeInsets.zero, // 🔑 so gradient fills entire button
                        // ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFFF6B6B), // Coral red color
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        //

                        child:
                        _isPayBtnLoading //Build 1.1.36: added loader for pay button in order panel
                            ? CircularProgressIndicator(
                            color: Colors.white)
                            : Text(
                          TextConstants.printInvoice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                          : ElevatedButton(
                        //Build 1.1.36: on pay tap calling updateOrderProducts api call
                        onPressed: netPayable >= 0 &&
                            orderItems.isNotEmpty
                            ? () async {
                          if (orderHelper.activeOrderId != null) {
                            setState(() => _isPayBtnLoading = true);
                            _initialFetchDone =
                            false; // Build #1.0.143: Track initial fetch of fetchOrdersData
                            // await Navigator.push(
                            //   context,
                            //   MaterialPageRoute(builder: (context) => OrderSummaryScreen()),
                            // );
                            // On the first screen (Screen 1)
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => OrderSummaryScreen())).then((result) {
                            //   if (result == 'refresh') {
                            //     setState(() {
                            //       // Update state to refresh the UI
                            //     });
                            //   }
                            // });
                            // Build #1.0.104: refresh when back to this screen
                            List<Map<String, dynamic>> visibleLineItems(
                                List<Map<String, dynamic>> items,
                                ) {
                              return items.where((item) {
                                final nameLower = (item[AppDBConst.itemName] ?? '')
                                    .toString()
                                    .trim()
                                    .toLowerCase();

                                final itemTypeLower = (item['item_type'] ?? '') // ✅ FIXED KEY
                                    .toString()
                                    .trim()
                                    .toLowerCase();

                                final isNonProduct =
                                    nameLower.contains('discount') ||
                                        nameLower.contains('coupon') ||
                                        nameLower.contains('loyalty') ||
                                        nameLower.contains('redeemed') ||
                                        nameLower.contains('points') ||
                                        itemTypeLower.contains('discount') ||
                                        itemTypeLower.contains('coupon') ||   // ✅ WILL MATCH
                                        itemTypeLower.contains('loyalty') ;


                                return !isNonProduct;
                              }).toList();
                            }
                            final box = StorageProvider.offlineOrders;

// Prefer server order id if exists, else offline id
                            final hiveKey = orderHelper.activeOrderId.toString();

                            final boxData = await box.get(hiveKey);
                            final double discountAmount =
                            ((boxData is Map ? boxData["discount_amount"] : null) ?? 0.0).toDouble();

                            if (kDebugMode) {
                              print("🏷 Passing Discount Amount = $discountAmount");
                            }

                            final filteredItems = visibleLineItems(orderItems);

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderSummaryScreen(
                                  orderItems: filteredItems, // ✅ ONLY product items
                                  formattedDate: displayDate,
                                  formattedTime: displayTime,
                                  grossTotal: grossTotal.toDouble(),
                                  orderDiscount: orderDiscount,
                                  merchantDiscount: merchantDiscount,
                                  orderTax: orderTax,
                                  netPayable: netPayable.toDouble(),
                                  orderId: orderHelper.activeOrderId,
                                  cashbackFee: cashbackFee,
                                  ebtAmount: ebtAmount,
                                  discountAmount: discountAmount,
                                ),
                              ),
                            );

                            if (kDebugMode) {
                              print(
                                  "###### OrderScreenPanel: Returned from OrderSummaryScreen with result: $result");
                            }
                            // Handle refresh if result is 'refresh'
                            if (result == TextConstants.refresh) {
                              // Build #1.0.175: added TextConstants
                              if (kDebugMode) {
                                print(
                                    "###### OrderScreenPanel: Refresh signal received, reinitializing entire screen");
                              }

                              // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                              widget.refreshOrderList?.call();
                            }
                            setState(
                                    () => _isPayBtnLoading = false);

                            ///No need to update here now, may cause empty items added to order
                            //     // Assign the subscription to your class variable
                            //     _updateOrderSubscription = orderBloc.updateOrderStream.listen((response) async {
                            //       if (!mounted) return; // Safety check
                            //       if (response.status == Status.LOADING) { // Build #1.0.80
                            //         const Center(child: CircularProgressIndicator());
                            //       }else if (response.status == Status.COMPLETED) {
                            //         if (kDebugMode) {
                            //           print("###### updateOrder COMPLETED");
                            //         }
                            //
                            //         setState(() => _isPayBtnLoading = false); // dismiss the loader
                            //
                            //         Navigator.push(
                            //           context,
                            //           MaterialPageRoute(builder: (context) => OrderSummaryScreen()),
                            //         );
                            //       } else if (response.status == Status.ERROR) {
                            //         ScaffoldMessenger.of(context).showSnackBar(
                            //           SnackBar(content: Text(response.message ?? "Failed to update order")),
                            //         );
                            //       }
                            //     });
                            //
                            //     // Prepare line items for API
                            //     List<OrderLineItem> lineItems = orderItems.map((item) => OrderLineItem(
                            //       productId: item[AppDBConst.itemId],
                            //       quantity: item[AppDBConst.itemCount],
                            //     )).toList();
                            //
                            //     // Call API
                            //     await orderBloc.updateOrderProducts(
                            //       dbOrderId: orderHelper.activeOrderId!,
                            //       orderId: serverOrderId,
                            //       lineItems: lineItems,
                            //     );
                          }
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          netPayable >= 0 && orderItems.isNotEmpty
                              ? const Color(0xFFFF6B6B)
                              : Colors.grey, // Coral red color
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                        _isPayBtnLoading //Build 1.1.36: added loader for pay button in order panel
                            ? CircularProgressIndicator(
                            color: Colors.white)
                            : Text(
                          // "${TextConstants.pay} ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                          TextConstants
                              .pay, // Build #1.0.175: No need show amount on PAY button in order screen panel
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  else SizedBox(),
                ],
              ),
            )
          ],
        ),
        if (_isLoading) // ADDED PROGRESS INDICATOR
          Container(
            color: Colors.black.withOpacity(0.5), // Black tint overlay
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.black, // Black loader
                strokeWidth: 6.0,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildProductImage(String? imagePath,
      {double height = 60, double width = 60}) {
    const String fallback = 'assets/custom.png';

    // No image at all → use fallback
    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset(
        fallback,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    }

    // HTTP image
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Image.asset(
            fallback,
            height: height,
            width: width,
            fit: BoxFit.cover,
          );
        },
      );
    }

    // Local asset .png/.jpg
    return Image.asset(
      imagePath,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          fallback,
          height: height,
          width: width,
          fit: BoxFit.cover,
        );
      },
    );
  }


//   Future _preparePrintTicket() async{
//     var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
//     var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
//     var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
//
//     if (kDebugMode) {
//       print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $header");
//       print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $footer");
//       print("OrderSummaryScreen _preparePrintTicket logo: $logo");
//     }
//     if (_order != null) {
//       setState(() {
//         var orderId = _order[AppDBConst.orderServerId] as int? ?? 0;
//         var orderDateTime = "${_order[AppDBConst.orderDate]} ${_order[AppDBConst.orderTime]}" ;
//         balanceAmount = (_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0; // Fetch total
//         final discount = uiOrderDiscount;
//         final merchantDiscount = uiMerchantDiscount;
//         final tax = uiOrderTax;
//         final cashbackFee = uiCashbackFee;
//         var balanceAmt = total - discount - merchantDiscount + tax -cashbackFee;
//         if (kDebugMode) {
//           print("Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${widget.activeOrderId}, Time: $orderDateTime");
//           print("Balance amount calculated is $balanceAmt and balance from API is $balanceAmount");
//         }
//       });
//     } else {
//       if (kDebugMode) {
//         print("No orderServerId found for activeOrderId: ${widget.activeOrderId}");
//       }
//     }
//
//     bytes = [];
//     final ticket =  await _printerSettings.getTicket();
//
//     var dateToPrint = "";
//     var timeToPrint = "";
//
//     if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
//       try {
//         final DateTime createdDateTime = DateTime.parse(_order[AppDBConst.orderDate].toString());
//         dateToPrint = DateFormat(TextConstants.dateFormat).format(createdDateTime);
//         timeToPrint = DateFormat(TextConstants.timeFormat).format(createdDateTime);
//       } catch (e) {
//         if (kDebugMode) {
//           print("Error parsing order creation date: $e");
//         }
//         // Fallback to raw data or default if parsing fails
//         // displayDate = order[AppDBConst.orderDate].toString().split(' ').first;
//       }
//     }
//
//     var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
//     var storeId = "${merchantDetails?[AppDBConst.storeId]}";
//     var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
//
//     var storeDetails = await AssetDBHelper.instance.getStoreDetails();
//     var storeName = "${storeDetails?.name}";
//     var address = "${storeDetails?.address},";
//     var cityStateZip = "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
//     var orderIdToPrint = '${widget.activeOrderId}';
//
//     final userData = await UserDbHelper().getUserData();
//     var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
//     var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
//
//     final grossTotal = uiGrossTotal;
//     final discount = uiOrderDiscount;
//     final merchantDiscount = uiMerchantDiscount;
//     final tax = uiOrderTax;
//     final cashbackFee = uiCashbackFee;
//     final hiveRedeemedValue = uiRedeemedValue;
//     final netpayable= uiNetPayable;
//
//
//     if (kDebugMode) {
//       print(" >>>>> PrintOrder  dateToPrint $dateToPrint ");
//       print(" >>>>> PrintOrder  timeToPrint $timeToPrint ");
//       print(" >>>>> PrintOrder  storeId $storeId ");
//       print(" >>>>> PrintOrder  storeName $storeName ");
//       print(" >>>>> PrintOrder  address $address ");
//       print(" >>>>> PrintOrder  cityStateZip $cityStateZip ");
//       print(" >>>>> PrintOrder  storePhone $storePhone ");
//       print(" >>>>> PrintOrder  orderIdToPrint $orderIdToPrint ");
//       print(" >>>>> PrintOrder  cashierName $cashierName ");
//       print(" >>>>> PrintOrder  cashierRole $cashierRole ");
//     }
//
//     if (kDebugMode) {
//       print("=============== 🧾 PRINT TICKET DEBUG INFO ===============");
//
//       print("HEADER TEXT        : $header");
//       print("FOOTER TEXT        : $footer");
//       print("LOGO PATH          : $logo");
//
//       print("\n------------------- ORDER DETAILS ------------------------");
//       print("Order Server ID    : ${_order[AppDBConst.orderServerId]}");
//       print("Order Local ID     : ${widget.activeOrderId}");
//       print("Order Date         : ${_order[AppDBConst.orderDate]}");
//       print("Order Time         : ${_order[AppDBConst.orderTime]}");
//
//       print("Parsed Date        : $dateToPrint");
//       print("Parsed Time        : $timeToPrint");
//
//       print("\n------------------- STORE DETAILS ------------------------");
//       print("Store ID           : $storeId");
//       print("Store Name         : $storeName");
//       print("Address            : $address");
//       print("City/State/Zip     : $cityStateZip");
//       print("Store Phone        : $storePhone");
//
//       print("\n------------------- CASHIER DETAILS ----------------------");
//       print("Cashier Name       : $cashierName");
//       print("Cashier Role       : $cashierRole");
//
//       print("\n------------------- ORDER AMOUNTS ------------------------");
//       print("Gross Total        : ${grossTotal.toStringAsFixed(2)}");
//       print("Discount           : ${discount.toStringAsFixed(2)}");
//       print("Merchant Discount  : ${merchantDiscount.toStringAsFixed(2)}");
//       print("Tax                : ${tax.toStringAsFixed(2)}");
//       print("Cashback Fee       : ${cashbackFee.toStringAsFixed(2)}");
//       print("Service Charges    : ${servicecharges.toStringAsFixed(2)}");
//
//       print("Balance (NetPay)   : ${balanceAmount.toStringAsFixed(2)}");
//
//       print("\n------------------- PAYMENT DETAILS ----------------------");
//       print("Redeemed Points    : ${hiveRedeemedValue.toStringAsFixed(2)}");
//       print("Pay By Cash        : ${payByCash.toStringAsFixed(2)}");
//       print("Pay By Other       : ${payByOther.toStringAsFixed(2)}");
//       print("Tender Amount      : ${tenderAmount.toStringAsFixed(2)}");
//       print("Change Amount      : ${changeAmount.toStringAsFixed(2)}");
//
//       print("=============== END DEBUG PRINT ==========================\n\n");
//     }
//
//
//     if(header != "") {
//       bytes += ticket.row([
//         PosColumn(
//             text: "$header",
//             width: 12,
//             styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//     bytes += ticket.row([
//       PosColumn(
//         text: "***** INVOICE COPY *****",
//         width: 12,
//         styles: PosStyles(align: PosAlign.center, bold: true),
//       ),
//     ]);
//     bytes += ticket.feed(1);
//     //Store Name
//     bytes += ticket.row([
//       PosColumn(text: "$storeName", width: 12, styles: PosStyles(align: PosAlign.center,bold: true, height: PosTextSize.size2, width: PosTextSize.size2)), //Build #1.0.257: increase font to 5 and bold
//     ]);
//     bytes += ticket.feed(1); /// Add space between store name and address
//     //Address
//     bytes += ticket.row([
//       PosColumn(text: "$address", width: 12, styles: PosStyles(align: PosAlign.center)),
//     ]);
//     //cityStateZip
//     bytes += ticket.row([
//       PosColumn(text: "$cityStateZip", width: 12, styles: PosStyles(align: PosAlign.center)),
//     ]);
//     // Store Phone (Centered)
//     bytes += ticket.row([
//       PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center, bold: true)),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: "Date: $dateToPrint", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "Time: $timeToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     //cashier and  store id
//     bytes += ticket.row([
//       PosColumn(text: "Cashier: $cashierName", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "StoreID: $storeId", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     //role and order Id
//     bytes += ticket.row([
//       PosColumn(text: "Role: $cashierRole", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "OrderID: $orderIdToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//     // bytes += ticket.feed(1);
//
//     //Item header
//     bytes += ticket.row([
//       PosColumn(text: "#", width: 1,styles: PosStyles(align: PosAlign.left,bold:true)),
//       PosColumn(text: "Description", width:5,styles: PosStyles(align: PosAlign.left,bold:true)),
//       PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center,bold:true)),
//       PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right,bold:true)),
//       // PosColumn(text: "Dis", width: 1, styles: PosStyles(align: PosAlign.right)), ///removed based on request on 3-Sep-25
//       PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right,bold:true)),
//     ]);
//     bytes += ticket.feed(1);
//
//     if (kDebugMode) {
//       print(" >>>>> Order items count ${orderItems.length} ");
//
//     }
//
//     //Product Items
//     for (int i = 0; i < orderItems.length; i++) {
//       var orderItem = orderItems[i];
//       // --------------------------------------------------
// // HIDE discount, coupons, redeem points from printing
// // --------------------------------------------------
//       final nameLower = orderItem[AppDBConst.itemName]
//           ?.toString()
//           .toLowerCase() ?? "";
//
//       final itemTypeLower = orderItem[AppDBConst.itemType]
//           ?.toString()
//           .toLowerCase() ?? "";
//
//       bool hideItem =
//           nameLower.contains("discount") ||
//               nameLower.contains("coupon") ||
//               nameLower.contains("loyalty") ||      // FIXED
//               nameLower.contains("redeemed") ||
//               nameLower.contains("points") ||
//               itemTypeLower.contains("discount") ||
//               itemTypeLower.contains("coupon") ||
//               itemTypeLower.contains("loyalty") ||  // FIXED
//               itemTypeLower.contains("points");
//
//       if (hideItem) {
//         print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//         continue;
//       }
//
//
//       final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//       final isPayout = itemType.contains(TextConstants.payoutText);
//       final isCoupon = itemType.contains(TextConstants.couponText);
//       final isCashback = itemType.contains("cashback") ||
//           (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//
//       final isCouponOrPayout = isCoupon || isPayout;
//
//       // Determine sales price
//       final double salesPrice =
//       (orderItem[AppDBConst.itemSumPrice] != null &&
//           (orderItem[AppDBConst.itemCount] ?? 0) > 0)
//           ? (orderItem[AppDBConst.itemSumPrice] /
//           orderItem[AppDBConst.itemCount])
//           : 0.0;
//
//       double negativeItemPrice =
//           orderItem[AppDBConst.itemCount] * orderItem[AppDBConst.itemPrice];
//
//       // ----- RATE -----
//       double rateValue;
//       if (isCashback) {
//         rateValue = salesPrice.abs();
//
//       } else if (isCouponOrPayout) {
//         rateValue = negativeItemPrice; // negative
//       } else {
//         rateValue = salesPrice;
//       }
//
// // ----- AMOUNT -----
//       double amountValue;
//       if (isCashback) {
//         amountValue = (orderItem[AppDBConst.itemCount] * salesPrice).abs();
//
//       } else if (isCouponOrPayout) {
//         amountValue = negativeItemPrice; // negative
//       } else {
//         amountValue = orderItem[AppDBConst.itemCount] * salesPrice;
//       }
//
// // ----- SPECIAL FIX: Payout must display sales price also -----
//       double displaySalesPrice = salesPrice;
//
//
//
// // Payout must also show abs value
//       if (isPayout && salesPrice == 0) {
//         displaySalesPrice = negativeItemPrice.abs();
//       }
//
//
// // ----- FORMAT AMOUNT -----
//       String formattedAmount = amountValue < 0
//           ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//           : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//
// // ----- FORMAT RATE (sign before $) -----
//       String formattedRate;
//       if (rateValue < 0) {
//         formattedRate =
//         "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}";
//       } else {
//         formattedRate =
//         "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//       }
//       String formattedSalesPrice;
//       if (isPayout) {
//         formattedSalesPrice =
//         "-${TextConstants.currencySymbol}${displaySalesPrice.toStringAsFixed(2)}";
//       } else {
//         formattedSalesPrice =
//         "${TextConstants.currencySymbol}${displaySalesPrice.toStringAsFixed(2)}";
//       }
//
//       if (isCashback) {
//         double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//
//         double cashbackValue =
//             (orderItem['amount'] as num?)?.toDouble() ??
//                 (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ??
//                 (orderItem['itemTotalPrice'] as num?)?.toDouble() ??
//                 0.0;
//
//         double rateValueCashback = cashbackValue / qty;
//
//         formattedRate =
//         "${TextConstants.currencySymbol}${rateValueCashback.toStringAsFixed(2)}";
//
//         formattedAmount =
//         "${TextConstants.currencySymbol}${cashbackValue.toStringAsFixed(2)}";
//
//         formattedSalesPrice =
//         "${TextConstants.currencySymbol}${cashbackValue.toStringAsFixed(2)}";
//
//
//         // -----------------------------------
//         // DEBUG PRINT
//         // -----------------------------------
//         print("🟦 -----------------------------");
//         print("🟦 Cashback ITEM");
//         print("🟦 Qty          : $qty");
//         print("🟦 Sales Price  : $formattedSalesPrice");
//         print("🟦 Rate Value   : $formattedRate");
//         print("🟦 Amount Value : $formattedAmount");
//         print("🟦 -----------------------------");
//       }
//
//       // ------------------------------------
//       // DEBUG PRINT FOR EACH PRODUCT
//       // ------------------------------------
//       if (kDebugMode) {
//         print("🟦 -----------------------------");
//         print("🟦 ITEM #${i + 1}");
//         print("🟦 Name         : ${orderItem[AppDBConst.itemName]}");
//         print("🟦 Qty          : ${orderItem[AppDBConst.itemCount]}");
//         // INSERT THIS FIX HERE ⬇
//         // String formattedSalesPrice;
//         // if (isPayout) {
//         //   formattedSalesPrice =
//         //   "-${TextConstants.currencySymbol}${displaySalesPrice.toStringAsFixed(2)}";
//         // } else {
//         //   formattedSalesPrice =
//         //   "${TextConstants.currencySymbol}${displaySalesPrice.toStringAsFixed(2)}";
//         // }
//         // if (isCashback) {
//         //   double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//         //
//         //   double cashbackValue =
//         //       (orderItem['amount'] as num?)?.toDouble() ??
//         //           (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ??
//         //           (orderItem['itemTotalPrice'] as num?)?.toDouble() ??
//         //           0.0;
//         //
//         //   double rateValueCashback = cashbackValue / qty;
//         //
//         //   formattedRate =
//         //   "${TextConstants.currencySymbol}${rateValueCashback.toStringAsFixed(2)}";
//         //
//         //   formattedAmount =
//         //   "${TextConstants.currencySymbol}${cashbackValue.toStringAsFixed(2)}";
//         //
//         //   formattedSalesPrice =
//         //   "${TextConstants.currencySymbol}${cashbackValue.toStringAsFixed(2)}";
//         //
//         //
//         //   // -----------------------------------
//         //   // DEBUG PRINT
//         //   // -----------------------------------
//         //   print("🟦 -----------------------------");
//         //   print("🟦 Cashback ITEM");
//         //   print("🟦 Qty          : $qty");
//         //   print("🟦 Sales Price  : $formattedSalesPrice");
//         //   print("🟦 Rate Value   : $formattedRate");
//         //   print("🟦 Amount Value : $formattedAmount");
//         //   print("🟦 -----------------------------");
//         // }
//
//
//         print("🟦 Sales Price  : $formattedSalesPrice");
//         // END FIX ⬆
//         print("🟦 Raw Neg Price: $negativeItemPrice");
//         print("🟦 Rate Value   : $formattedRate");
//         print("🟦 Amount Value : $formattedAmount");
//         print("🟦 isCashback   : $isCashback");
//         print("🟦 isCoupon     : $isCoupon");
//         print("🟦 isPayout     : $isPayout");
//         print("🟦 -----------------------------");
//       }
//
//       // -------------------------
//       // ESC/POS VALID 12-WIDTH ROW
//       // -------------------------
//       bytes += ticket.row([
//         PosColumn(text: "${i + 1}", width: 1),
//         PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//         PosColumn(
//           text: "${orderItem[AppDBConst.itemCount]}",
//           width: 1,
//           styles: PosStyles(align: PosAlign.center),
//         ),
//         PosColumn(
//           text: formattedRate,
//           width: 2,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//         PosColumn(
//           text: formattedAmount,
//           width: 3,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//       ]);
//
//       bytes += ticket.emptyLines(1);
//     }
//
//
//
//
//     //bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//     bytes += ticket.feed(1);
//
//     if (kDebugMode) {
//       print(" >>>>> Printer Order merchantDiscount -${merchantDiscount.toStringAsFixed(2)} ");
//       print(" >>>>> Printer Order discount -${discount.toStringAsFixed(2)} ");
//       print(" >>>>> Printer Order balanceAmount  $balanceAmount ");
//       print(" >>>>> Printer Order gross total  $grossTotal ");
//       print(" >>>>> Printer Order tenderAmount $tenderAmount ");
//       print(" >>>>> Printer Order changeAmount $changeAmount ");
//       print(" >>>>> Printer Order paidAmount $paidAmount ");
//
//     }
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.grossTotal, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//     // bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.discountText, width: 10), // Build #1.0.148: deleted duplicate discount string from constants , already we have discountText using !
//       PosColumn(text: "-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.taxText, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.merchantDiscount, width: 10),
//       PosColumn(text: "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.cashbackFee, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.servicecharges, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//     //Net Payable
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.netPayable, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${netpayable.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.redeemPoints, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${hiveRedeemedValue.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//
//     ///Todo: get pay by cash amount
//     // bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByCash, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}", width:2,styles: PosStyles(align: PosAlign.right)),
//     ]);
//     ///Todo: get pay by other amount
//     // bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByOther, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//     // bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.tenderAmount, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     ]);
//     // bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.change, width: 10),
//       PosColumn(text: "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//     //bytes += ticket.feed(1);
//
//     //Footer
//     // bytes += ticket.row([
//     //   PosColumn(text: "Thank You, Visit Again", width: 12),
//     // ]);
//
//     if(footer != "") {
//       bytes += ticket.row([
//         PosColumn(text: "$footer",
//             width: 12,
//             styles: PosStyles(align: PosAlign.center)),
//       ]);
//       bytes += ticket.feed(1);
//     }
//   }

//   Future _preparePrintTicket() async {
//     var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
//     var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
//     var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
//
//     if (kDebugMode) {
//       print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $header");
//       print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $footer");
//       print("OrderSummaryScreen _preparePrintTicket logo: $logo");
//     }
//
//     if (_order != null) {
//       setState(() {
//         var orderId = _order[AppDBConst.orderServerId] as int? ?? 0;
//         var orderDateTime = "${_order[AppDBConst.orderDate]} ${_order[AppDBConst.orderTime]}" ;
//         balanceAmount = (_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;
//         final discount = uiOrderDiscount;
//         final merchantDiscount = uiMerchantDiscount;
//         final tax = uiOrderTax;
//         final cashbackFee = uiCashbackFee;
//         var balanceAmt = total - discount - merchantDiscount + tax - cashbackFee;
//         if (kDebugMode) {
//           print("Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${widget.activeOrderId}, Time: $orderDateTime");
//           print("Balance amount calculated is $balanceAmt and balance from API is $balanceAmount");
//         }
//       });
//     } else {
//       if (kDebugMode) {
//         print("No orderServerId found for activeOrderId: ${widget.activeOrderId}");
//       }
//     }
//
//     bytes = [];
//     final ticket = await _printerSettings.getTicket();
//
//     var dateToPrint = "";
//     var timeToPrint = "";
//
//     if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
//       try {
//         final DateTime createdDateTime = DateTime.parse(_order[AppDBConst.orderDate].toString());
//         dateToPrint = DateFormat(TextConstants.dateFormat).format(createdDateTime);
//         timeToPrint = DateFormat(TextConstants.timeFormat).format(createdDateTime);
//       } catch (e) {
//         if (kDebugMode) {
//           print("Error parsing order creation date: $e");
//         }
//       }
//     }
//
//     var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
//     var storeId = "${merchantDetails?[AppDBConst.storeId]}";
//     var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
//
//     var storeDetails = await AssetDBHelper.instance.getStoreDetails();
//     var storeName = "${storeDetails?.name}";
//     var address = "${storeDetails?.address},";
//     var cityStateZip = "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
//     var orderIdToPrint = '${widget.activeOrderId}';
//
//     final userData = await UserDbHelper().getUserData();
//     var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
//     var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
//
//     final grossTotal = uiGrossTotal;
//     final discount = uiOrderDiscount;
//     final merchantDiscount = uiMerchantDiscount;
//     final tax = uiOrderTax;
//     final cashbackFee = uiCashbackFee;
//     final hiveRedeemedValue = uiRedeemedValue;
//     final netpayable = uiNetPayable;
//
//     if (kDebugMode) {
//       print(" >>>>> PrintOrder  dateToPrint $dateToPrint ");
//       print(" >>>>> PrintOrder  timeToPrint $timeToPrint ");
//       print(" >>>>> PrintOrder  storeId $storeId ");
//       print(" >>>>> PrintOrder  storeName $storeName ");
//       print(" >>>>> PrintOrder  address $address ");
//       print(" >>>>> PrintOrder  cityStateZip $cityStateZip ");
//       print(" >>>>> PrintOrder  storePhone $storePhone ");
//       print(" >>>>> PrintOrder  orderIdToPrint $orderIdToPrint ");
//       print(" >>>>> PrintOrder  cashierName $cashierName ");
//       print(" >>>>> PrintOrder  cashierRole $cashierRole ");
//     }
//
//     if (kDebugMode) {
//       print("=============== 🧾 PRINT TICKET DEBUG INFO ===============");
//       print("HEADER TEXT        : $header");
//       print("FOOTER TEXT        : $footer");
//       print("LOGO PATH          : $logo");
//
//       print("\n------------------- ORDER DETAILS ------------------------");
//       print("Order Server ID    : ${_order[AppDBConst.orderServerId]}");
//       print("Order Local ID     : ${widget.activeOrderId}");
//       print("Order Date         : ${_order[AppDBConst.orderDate]}");
//       print("Order Time         : ${_order[AppDBConst.orderTime]}");
//
//       print("Parsed Date        : $dateToPrint");
//       print("Parsed Time        : $timeToPrint");
//
//       print("\n------------------- STORE DETAILS ------------------------");
//       print("Store ID           : $storeId");
//       print("Store Name         : $storeName");
//       print("Address            : $address");
//       print("City/State/Zip     : $cityStateZip");
//       print("Store Phone        : $storePhone");
//
//       print("\n------------------- CASHIER DETAILS ----------------------");
//       print("Cashier Name       : $cashierName");
//       print("Cashier Role       : $cashierRole");
//
//       print("\n------------------- ORDER AMOUNTS ------------------------");
//       print("Gross Total        : ${grossTotal.toStringAsFixed(2)}");
//       print("Discount           : ${discount.toStringAsFixed(2)}");
//       print("Merchant Discount  : ${merchantDiscount.toStringAsFixed(2)}");
//       print("Tax                : ${tax.toStringAsFixed(2)}");
//       print("Cashback Fee       : ${cashbackFee.toStringAsFixed(2)}");
//       print("Service Charges    : ${servicecharges.toStringAsFixed(2)}");
//
//       print("Balance (NetPay)   : ${balanceAmount.toStringAsFixed(2)}");
//
//       print("\n------------------- PAYMENT DETAILS ----------------------");
//       print("Redeemed Points    : ${hiveRedeemedValue.toStringAsFixed(2)}");
//       print("Pay By Cash        : ${payByCash.toStringAsFixed(2)}");
//       print("Pay By Other       : ${payByOther.toStringAsFixed(2)}");
//       print("Tender Amount      : ${tenderAmount.toStringAsFixed(2)}");
//       print("Change Amount      : ${changeAmount.toStringAsFixed(2)}");
//
//       print("=============== END DEBUG PRINT ==========================\n\n");
//     }
//
//     // ---------------- HEADER PRINT ----------------
//     if(header != "") {
//       bytes += ticket.row([
//         PosColumn(
//             text: "$header",
//             width: 12,
//             styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//
//     bytes += ticket.row([
//       PosColumn(
//         text: "***** INVOICE COPY *****",
//         width: 12,
//         styles: PosStyles(align: PosAlign.center, bold: true),
//       ),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "$storeName", width: 12, styles: PosStyles(align: PosAlign.center,bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "$address", width: 12, styles: PosStyles(align: PosAlign.center)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "$cityStateZip", width: 12, styles: PosStyles(align: PosAlign.center)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center, bold: true)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "Date: $dateToPrint", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "Time: $timeToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Cashier: $cashierName", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "StoreID: $storeId", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Role: $cashierRole", width: 7, styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "OrderID: $orderIdToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     // ---------------- ITEMS HEADER ----------------
//     bytes += ticket.row([
//       PosColumn(text: "#", width: 1,styles: PosStyles(align: PosAlign.left,bold:true)),
//       PosColumn(text: "Description", width:5,styles: PosStyles(align: PosAlign.left,bold:true)),
//       PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center,bold:true)),
//       PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right,bold:true)),
//       PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right,bold:true)),
//     ]);
//     bytes += ticket.feed(1);
//
//     // 🔥 MULTIPACK DISCOUNT TOTAL
//     double totalMultipackDiscount = 0.0;
//     double totalComboDiscount = 0.0;
//     double totalAutoDiscount = 0.0;
//
//     // ---------------- ITEMS LOOP ----------------    ////impo
//     // for (int i = 0; i < orderItems.length; i++) {
//     //
//     //
//     //   var orderItem = orderItems[i];
//     //
//     //   final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
//     //   final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";
//     //
//     //   bool hideItem =
//     //       nameLower.contains("discount") ||
//     //           nameLower.contains("coupon") ||
//     //           nameLower.contains("loyalty") ||
//     //           nameLower.contains("redeemed") ||
//     //           nameLower.contains("points") ||
//     //           itemTypeLower.contains("discount") ||
//     //           itemTypeLower.contains("coupon") ||
//     //           itemTypeLower.contains("loyalty") ||
//     //           itemTypeLower.contains("points");
//     //
//     //   if (hideItem) {
//     //     print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//     //     continue;
//     //   }
//     //
//     //   final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//     //   final isPayout = itemType.contains(TextConstants.payoutText);
//     //   final isCoupon = itemType.contains(TextConstants.couponText);
//     //   final isCashback = itemType.contains("cashback") || (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//     //   final isCouponOrPayout = isCoupon || isPayout;
//     //
//     //   final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//     //   final double salesPrice = (orderItem[AppDBConst.itemSumPrice] != null && qty > 0)
//     //       ? (orderItem[AppDBConst.itemSumPrice] / qty)
//     //       : 0.0;
//     //
//     //   double negativeItemPrice = qty * (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//     //
//     //   double rateValue;
//     //   if (isCashback) {
//     //     rateValue = salesPrice.abs();
//     //   } else if (isCouponOrPayout) {
//     //     rateValue = negativeItemPrice;
//     //   } else {
//     //     rateValue = salesPrice;
//     //   }
//     //
//     //   double amountValue;
//     //   if (isCashback) {
//     //     amountValue = (qty * salesPrice).abs();
//     //   } else if (isCouponOrPayout) {
//     //     amountValue = negativeItemPrice;
//     //   } else {
//     //     amountValue = qty * salesPrice;
//     //   }
//     //
//     //   // 🔥 MULTIPACK DISCOUNT
//     //   final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
//     //   if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//     //     amountValue -= multipackDiscount;
//     //     totalMultipackDiscount += multipackDiscount;
//     //   }
//     //
//     //   final double comboDiscount =
//     //       (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//     //
//     //   final double autoDiscount =
//     //       (orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//     //
//     //   if (!isPayout && !isCoupon && !isCashback) {
//     //     if (comboDiscount > 0) {
//     //       amountValue -= comboDiscount;
//     //       totalComboDiscount += comboDiscount;
//     //     }
//     //
//     //     if (autoDiscount > 0) {
//     //       amountValue -= autoDiscount;
//     //       totalAutoDiscount += autoDiscount;
//     //     }
//     //   }
//     //
//     //
//     //   String formattedRate = rateValue < 0
//     //       ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//     //
//     //   String formattedAmount = amountValue < 0
//     //       ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //
//     //
//     //
//     //   // ---------------- ITEM ROW ----------------
//     //   bytes += ticket.row([
//     //     PosColumn(text: "${i + 1}", width: 1),
//     //
//     //     PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//     //     PosColumn(
//     //       text: qty.toInt().toString(),
//     //       width: 1,
//     //       styles: PosStyles(align: PosAlign.center),
//     //     ),
//     //     PosColumn(
//     //       text: formattedRate,
//     //       width: 2,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //     PosColumn(
//     //       text: formattedAmount,
//     //       width: 3,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //   ]);
//     //
//     //   //  PRINT MULTIPACK DISCOUNT LINE
//     //   if (multipackDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Multipack Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (comboDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Combo Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (autoDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Auto Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //
//     //
//     //
//     //
//     //   bytes += ticket.emptyLines(1);
//     // }
//
//     // ---------------- ITEMS LOOP ----------------
//
//     // for (int i = 0; i < orderItems.length; i++) {
//     //   var orderItem = orderItems[i];
//     //
//     //   final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
//     //   final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";
//     //
//     //   bool hideItem =
//     //       nameLower.contains("discount") ||
//     //           nameLower.contains("coupon") ||
//     //           nameLower.contains("loyalty") ||
//     //           nameLower.contains("redeemed") ||
//     //           nameLower.contains("points") ||
//     //           itemTypeLower.contains("discount") ||
//     //           itemTypeLower.contains("coupon") ||
//     //           itemTypeLower.contains("loyalty") ||
//     //           itemTypeLower.contains("points");
//     //
//     //   if (hideItem) {
//     //     print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//     //     continue;
//     //   }
//     //
//     //   final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//     //   final isPayout = itemType.contains(TextConstants.payoutText);
//     //   final isCoupon = itemType.contains(TextConstants.couponText);
//     //   final isCashback = itemType.contains("cashback") || (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//     //   final isCouponOrPayout = isCoupon || isPayout;
//     //
//     //   final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//     //   final double salesPrice = (orderItem[AppDBConst.itemSumPrice] != null && qty > 0)
//     //       ? (orderItem[AppDBConst.itemSumPrice] / qty)
//     //       : 0.0;
//     //
//     //   double negativeItemPrice = qty * (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//     //
//     //   double rateValue;
//     //   if (isCashback) {
//     //     rateValue = salesPrice.abs();
//     //   } else if (isCouponOrPayout) {
//     //     rateValue = negativeItemPrice;
//     //   } else {
//     //     rateValue = salesPrice;
//     //   }
//     //
//     //   double amountValue;
//     //   if (isCashback) {
//     //     amountValue = (qty * salesPrice).abs();
//     //   } else if (isCouponOrPayout) {
//     //     amountValue = negativeItemPrice;
//     //   } else {
//     //     amountValue = qty * salesPrice;
//     //   }
//     //
//     //   // 🔥 GET DISCOUNTS
//     //   final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
//     //   final double comboDiscount = (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//     //   final double autoDiscount = (orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//     //
//     //   // 🔥 CALCULATE ORIGINAL AMOUNT (before any discount)
//     //   final double originalAmount = qty * salesPrice;
//     //
//     //   // 🔥 CHECK IF THERE'S ANY DISCOUNT
//     //   final bool hasDiscount = (multipackDiscount > 0 || comboDiscount > 0 || autoDiscount > 0)
//     //       && !isPayout && !isCoupon && !isCashback;
//     //
//     //   // 🔥 APPLY DISCOUNTS TO AMOUNT
//     //   if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//     //     amountValue -= multipackDiscount;
//     //     totalMultipackDiscount += multipackDiscount;
//     //   }
//     //
//     //   if (!isPayout && !isCoupon && !isCashback) {
//     //     if (comboDiscount > 0) {
//     //       amountValue -= comboDiscount;
//     //       totalComboDiscount += comboDiscount;
//     //     }
//     //
//     //     if (autoDiscount > 0) {
//     //       amountValue -= autoDiscount;
//     //       totalAutoDiscount += autoDiscount;
//     //     }
//     //   }
//     //
//     //   String formattedRate = rateValue < 0
//     //       ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//     //
//     //   String formattedAmount = amountValue < 0
//     //       ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //
//     //
//     //   // ---------------- ITEM ROW ----------------
//     //   String displayAmount;
//     //   if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//     //     // Show original price with strikethrough inline (or just as text with "-" for printer)
//     //     displayAmount = "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)} → ${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //   } else {
//     //     displayAmount = formattedAmount;
//     //   }
//     //   print("Itemmmmmm: ${orderItem[AppDBConst.displayAmount]} | Qty: ${qty.toInt()} | Rate: $formattedRate | Amount: $displayAmount");
//     //
//     //   bytes += ticket.row([
//     //     PosColumn(text: "${i + 1}", width: 1),
//     //     PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//     //     PosColumn(
//     //       text: qty.toInt().toString(),
//     //       width: 1,
//     //       styles: PosStyles(align: PosAlign.center),
//     //     ),
//     //     PosColumn(
//     //       text: formattedRate,
//     //       width: 2,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //     PosColumn(
//     //       text: displayAmount, // <-- INLINE ORIGINAL PRICE HERE
//     //       width: 3,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //   ]);
//     //
//     //
//     //   // PRINT MULTIPACK DISCOUNT LINE
//     //   if (multipackDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Multipack Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (comboDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Combo Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (autoDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Auto Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   bytes += ticket.emptyLines(1);
//     // }
//
//
//     for (int i = 0; i < orderItems.length; i++) {
//       var orderItem = orderItems[i];
//
//       final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
//       final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";
//
//       bool hideItem =
//           nameLower.contains("discount") ||
//               nameLower.contains("coupon") ||
//               nameLower.contains("loyalty") ||
//               nameLower.contains("redeemed") ||
//               nameLower.contains("points") ||
//               itemTypeLower.contains("discount") ||
//               itemTypeLower.contains("coupon") ||
//               itemTypeLower.contains("loyalty") ||
//               itemTypeLower.contains("points");
//
//       if (hideItem) {
//         print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//         continue;
//       }
//
//       final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//       final isPayout = itemType.contains(TextConstants.payoutText);
//       final isCoupon = itemType.contains(TextConstants.couponText);
//       final isCashback = itemType.contains("cashback") || (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//       final isCouponOrPayout = isCoupon || isPayout;
//
//       final double qty =
//           (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//
//       final double salesPrice =
//       (orderItem[AppDBConst.itemPrice] != null && qty > 0)
//           ? (orderItem[AppDBConst.itemPrice])
//           : 0.0;
//
//       final double cashbackPrice =
//       (orderItem[AppDBConst.itemPrice] != null && qty > 0)
//           ? (orderItem[AppDBConst.itemPrice])
//           : 0.0;
//
//       print('Quantity: $qty');
//       print('Sales Priceeeee: $salesPrice');
//
//       print('Sales cashbackPrice: $cashbackPrice');
//
//
//       double negativeItemPrice = qty * (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//
//       double rateValue;
//       if (isCashback) {
//         rateValue = cashbackPrice.abs();
//       } else if (isCouponOrPayout) {
//         rateValue = negativeItemPrice;
//       } else {
//         rateValue = cashbackPrice;
//       }
//
//       double amountValue;
//       if (isCashback) {
//         amountValue = (qty * cashbackPrice).abs();
//       } else if (isCouponOrPayout) {
//         amountValue = negativeItemPrice;
//       } else {
//         amountValue = qty * salesPrice;
//       }
//
//       // 🔥 GET DISCOUNTS
//       final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
//       final double comboDiscount = (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//       final double autoDiscount = (orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//
//       // 🔥 CALCULATE ORIGINAL AMOUNT (before any discount)
//       final double originalAmount = qty * salesPrice;
//
//       // 🔥 CHECK IF THERE'S ANY DISCOUNT
//       final bool hasDiscount = (multipackDiscount > 0 || comboDiscount > 0 || autoDiscount > 0)
//           && !isPayout && !isCoupon && !isCashback;
//
//       // 🔥 APPLY DISCOUNTS TO AMOUNT
//       if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//         amountValue -= multipackDiscount;
//         totalMultipackDiscount += multipackDiscount;
//       }
//
//       if (!isPayout && !isCoupon && !isCashback) {
//         if (comboDiscount > 0) {
//           amountValue -= comboDiscount;
//           totalComboDiscount += comboDiscount;
//         }
//
//         if (autoDiscount > 0) {
//           amountValue -= autoDiscount;
//           totalAutoDiscount += autoDiscount;
//         }
//       }
//
//       String formattedRate = rateValue < 0
//           ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
//           : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//
//       // String formattedAmount = amountValue < 0
//       //     ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//       //     : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//
//       final double itemRowAmount = isCashback
//           ? cashbackPrice
//           : qty * salesPrice;
//
//       String formattedAmount = itemRowAmount < 0
//           ? "-${TextConstants.currencySymbol}${itemRowAmount.abs().toStringAsFixed(2)}"
//           : "${TextConstants.currencySymbol}${itemRowAmount.toStringAsFixed(2)}";
//
//       print(
//         'Rate: $rateValue → $formattedRate | Amounteeeee: $itemRowAmount → $formattedAmount',
//       );
//
//
//
//       print(
//         'Rate: $rateValue → $formattedRate | '
//             'Amounteeeee: $amountValue → $formattedAmount',
//       );
//
//       // ---------------- ITEM ROW ----------------
//
//       bytes += ticket.row([
//         PosColumn(text: "${i + 1}", width: 1),
//         PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//         PosColumn(
//           text: qty.toInt().toString(),
//           width: 1,
//           styles: PosStyles(align: PosAlign.center),
//         ),
//         PosColumn(
//           text: formattedRate,
//           width: 2,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//         PosColumn(
//           text: formattedAmount,
//           width: 3,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//
//
//       ]);
//
//       // 🔥 NEW: SHOW ORIGINAL PRICE WITH STRIKETHROUGH IF DISCOUNT EXISTS
//       // if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//       //   bytes += ticket.row([
//       //     PosColumn(text: "", width: 1),
//       //     PosColumn(text: "Original Price:", width: 7),
//       //     PosColumn(
//       //       text: "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)}",
//       //       width: 4,
//       //       styles: PosStyles(align: PosAlign.right),
//       //     ),
//       //   ]);
//       // }
//
//       // ---------------- ITEM ROW ----------------
//       // String displayAmount;
//       // if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//       //   // Show discounted amount as primary
//       //   displayAmount = formattedAmount;
//       // } else {
//       //   displayAmount = formattedAmount;
//       // }
//       //
//       // bytes += ticket.row([
//       //   PosColumn(text: "${i + 1}", width: 1),
//       //   PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//       //   PosColumn(
//       //     text: qty.toInt().toString(),
//       //     width: 1,
//       //     styles: PosStyles(align: PosAlign.center),
//       //   ),
//       //   PosColumn(
//       //     text: formattedRate,
//       //     width: 2,
//       //     styles: PosStyles(align: PosAlign.right),
//       //   ),
//       //   PosColumn(
//       //     text: hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01
//       //         ? "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)}"  // Show original price
//       //         : formattedAmount,  // Show regular amount if no discount
//       //     width: 3,
//       //     styles: PosStyles(align: PosAlign.right),
//       //   ),
//       // ]);
//
// // // 🔥 NEW: SHOW DISCOUNTED PRICE BELOW IF DISCOUNT EXISTS
// //       if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
// //         bytes += ticket.row([
// //           PosColumn(text: "", width: 9),
// //           PosColumn(
// //             text: "After Discount: ${formattedAmount}",
// //             width: 3,
// //             styles: PosStyles(align: PosAlign.right),
// //           ),
// //         ]);
// //       }
//
//       // PRINT MULTIPACK DISCOUNT LINE
//
//       if (multipackDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Multipack Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       if (comboDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Combo Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       if (autoDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Auto Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       bytes += ticket.emptyLines(1);
//     }
//
//
//     // ---------------- SUMMARY ----------------
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.grossTotal, width:8),
//       PosColumn(text: "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.discountText, width:8),
//       PosColumn(text: "-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     // if (totalMultipackDiscount > 0) {
//     //   bytes += ticket.row([
//     //     PosColumn(text: "Multipack Discount", width: 10),
//     //     PosColumn(text: "-${TextConstants.currencySymbol}${totalMultipackDiscount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     //   ]);
//     // }
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.taxText, width:8),
//       PosColumn(text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.merchantDiscount, width:8),
//       PosColumn(text: "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.cashbackFee, width:8),
//       PosColumn(text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.servicecharges, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     // ---------------- NET PAYABLE & PAYMENT ----------------
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.netPayable, width:8),
//       PosColumn(text: "${TextConstants.currencySymbol}${netpayable.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.redeemPoints, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${hiveRedeemedValue.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByCash, width:8),
//       PosColumn(text: "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}", width:4,styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByOther, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.tenderAmount, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.change, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}", width:4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.feed(2);
//
//     // ---------------- FOOTER ----------------
//     if(footer != ""){
//       bytes += ticket.row([
//         PosColumn(text: "$footer", width: 12, styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//
//     bytes += ticket.feed(2);
//
//     bytes += ticket.row([
//       PosColumn(text: "-----------------------------------------------", width: 12),
//     ]);
//   }



//   Future _preparePrintTicket() async {
//     var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
//     var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
//     var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";
//
//     if (kDebugMode) {
//       print(
//           "OrderSummaryScreen _preparePrintTicket call print receipt ---- $header");
//       print(
//           "OrderSummaryScreen _preparePrintTicket call print receipt ---- $footer");
//       print("OrderSummaryScreen _preparePrintTicket logo: $logo");
//     }
//
//     if (_order != null) {
//       setState(() {
//         var orderId = _order[AppDBConst.orderServerId] as int? ?? 0;
//         var orderDateTime = "${_order[AppDBConst.orderDate]} ${_order[AppDBConst
//             .orderTime]}";
//         balanceAmount =
//             (_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;
//         final discount = uiOrderDiscount;
//         final merchantDiscount = uiMerchantDiscount;
//         final tax = uiOrderTax;
//         final cashbackFee = uiCashbackFee;
//         var balanceAmt = total - discount - merchantDiscount + tax -
//             cashbackFee;
//         if (kDebugMode) {
//           print(
//               "Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${widget
//                   .activeOrderId}, Time: $orderDateTime");
//           print(
//               "Balance amount calculated is $balanceAmt and balance from API is $balanceAmount");
//         }
//       });
//     } else {
//       if (kDebugMode) {
//         print("No orderServerId found for activeOrderId: ${widget
//             .activeOrderId}");
//       }
//     }
//
//     bytes = [];
//     final ticket = await _printerSettings.getTicket();
//
//     var dateToPrint = "";
//     var timeToPrint = "";
//
//     if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
//       try {
//         final DateTime createdDateTime = DateTime.parse(
//             _order[AppDBConst.orderDate].toString());
//         dateToPrint =
//             DateFormat(TextConstants.dateFormat).format(createdDateTime);
//         timeToPrint =
//             DateFormat(TextConstants.timeFormat).format(createdDateTime);
//       } catch (e) {
//         if (kDebugMode) {
//           print("Error parsing order creation date: $e");
//         }
//       }
//     }
//
//     var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
//     var storeId = "${merchantDetails?[AppDBConst.storeId]}";
//     var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
//
//     var storeDetails = await AssetDBHelper.instance.getStoreDetails();
//     var storeName = "${storeDetails?.name}";
//     var address = "${storeDetails?.address},";
//     var cityStateZip = "${storeDetails?.city},${storeDetails
//         ?.state}-${storeDetails?.zipCode}";
//     var orderIdToPrint = '${widget.activeOrderId}';
//
//     final userData = await UserDbHelper().getUserData();
//     var cashierName = "${userData?[AppDBConst.userDisplayName] ??
//         "Unknown Name"}";
//     var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";
//
//     final grossTotal = uiGrossTotal;
//     final discount = uiOrderDiscount;
//     final merchantDiscount = uiMerchantDiscount;
//     final tax = uiOrderTax;
//     final cashbackFee = uiCashbackFee;
//     final hiveRedeemedValue = uiRedeemedValue;
//     final netpayable = uiNetPayable;
//
//     if (kDebugMode) {
//       print(" >>>>> PrintOrder  dateToPrint $dateToPrint ");
//       print(" >>>>> PrintOrder  timeToPrint $timeToPrint ");
//       print(" >>>>> PrintOrder  storeId $storeId ");
//       print(" >>>>> PrintOrder  storeName $storeName ");
//       print(" >>>>> PrintOrder  address $address ");
//       print(" >>>>> PrintOrder  cityStateZip $cityStateZip ");
//       print(" >>>>> PrintOrder  storePhone $storePhone ");
//       print(" >>>>> PrintOrder  orderIdToPrint $orderIdToPrint ");
//       print(" >>>>> PrintOrder  cashierName $cashierName ");
//       print(" >>>>> PrintOrder  cashierRole $cashierRole ");
//     }
//
//     if (kDebugMode) {
//       print("=============== 🧾 PRINT TICKET DEBUG INFO ===============");
//       print("HEADER TEXT        : $header");
//       print("FOOTER TEXT        : $footer");
//       print("LOGO PATH          : $logo");
//
//       print("\n------------------- ORDER DETAILS ------------------------");
//       print("Order Server ID    : ${_order[AppDBConst.orderServerId]}");
//       print("Order Local ID     : ${widget.activeOrderId}");
//       print("Order Date         : ${_order[AppDBConst.orderDate]}");
//       print("Order Time         : ${_order[AppDBConst.orderTime]}");
//
//       print("Parsed Date        : $dateToPrint");
//       print("Parsed Time        : $timeToPrint");
//
//       print("\n------------------- STORE DETAILS ------------------------");
//       print("Store ID           : $storeId");
//       print("Store Name         : $storeName");
//       print("Address            : $address");
//       print("City/State/Zip     : $cityStateZip");
//       print("Store Phone        : $storePhone");
//
//       print("\n------------------- CASHIER DETAILS ----------------------");
//       print("Cashier Name       : $cashierName");
//       print("Cashier Role       : $cashierRole");
//
//       print("\n------------------- ORDER AMOUNTS ------------------------");
//       print("Gross Total        : ${grossTotal.toStringAsFixed(2)}");
//       print("Discount           : ${discount.toStringAsFixed(2)}");
//       print("Merchant Discount  : ${merchantDiscount.toStringAsFixed(2)}");
//       print("Tax                : ${tax.toStringAsFixed(2)}");
//       print("Cashback Fee       : ${cashbackFee.toStringAsFixed(2)}");
//       print("Service Charges    : ${servicecharges.toStringAsFixed(2)}");
//
//       print("Balance (NetPay)   : ${balanceAmount.toStringAsFixed(2)}");
//
//       print("\n------------------- PAYMENT DETAILS ----------------------");
//       print("Redeemed Points    : ${hiveRedeemedValue.toStringAsFixed(2)}");
//       print("Pay By Cash        : ${payByCash.toStringAsFixed(2)}");
//       print("Pay By Other       : ${payByOther.toStringAsFixed(2)}");
//       print("Tender Amount      : ${tenderAmount.toStringAsFixed(2)}");
//       print("Change Amount      : ${changeAmount.toStringAsFixed(2)}");
//
//       print("=============== END DEBUG PRINT ==========================\n\n");
//     }
//
//     // ---------------- HEADER PRINT ----------------
//     if (header != "") {
//       bytes += ticket.row([
//         PosColumn(
//             text: "$header",
//             width: 12,
//             styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//
//     bytes += ticket.row([
//       PosColumn(
//         text: "***** INVOICE COPY *****",
//         width: 12,
//         styles: PosStyles(align: PosAlign.center, bold: true),
//       ),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "$storeName",
//           width: 12,
//           styles: PosStyles(align: PosAlign.center,
//               bold: true,
//               height: PosTextSize.size2,
//               width: PosTextSize.size2)),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "$address",
//           width: 12,
//           styles: PosStyles(align: PosAlign.center)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "$cityStateZip",
//           width: 12,
//           styles: PosStyles(align: PosAlign.center)),
//     ]);
//     bytes += ticket.row([
//       PosColumn(text: "Phone: $storePhone",
//           width: 12,
//           styles: PosStyles(align: PosAlign.center, bold: true)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//     bytes += ticket.feed(1);
//
//     bytes += ticket.row([
//       PosColumn(text: "Date: $dateToPrint",
//           width: 7,
//           styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "Time: $timeToPrint",
//           width: 5,
//           styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Cashier: $cashierName",
//           width: 7,
//           styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "StoreID: $storeId",
//           width: 5,
//           styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: "Role: $cashierRole",
//           width: 7,
//           styles: PosStyles(align: PosAlign.left)),
//       PosColumn(text: "OrderID: $orderIdToPrint",
//           width: 5,
//           styles: PosStyles(align: PosAlign.left)),
//     ]);
//
//     bytes += ticket.feed(1);
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     // ---------------- ITEMS HEADER ----------------
//     bytes += ticket.row([
//       PosColumn(text: "#",
//           width: 1,
//           styles: PosStyles(align: PosAlign.left, bold: true)),
//       PosColumn(text: "Description",
//           width: 5,
//           styles: PosStyles(align: PosAlign.left, bold: true)),
//       PosColumn(text: "Qty",
//           width: 1,
//           styles: PosStyles(align: PosAlign.center, bold: true)),
//       PosColumn(text: "Rate",
//           width: 2,
//           styles: PosStyles(align: PosAlign.right, bold: true)),
//       PosColumn(text: "Amt",
//           width: 3,
//           styles: PosStyles(align: PosAlign.right, bold: true)),
//     ]);
//     bytes += ticket.feed(1);
//
//     // 🔥 MULTIPACK DISCOUNT TOTAL
//     double totalMultipackDiscount = 0.0;
//     double totalComboDiscount = 0.0;
//     double totalAutoDiscount = 0.0;
//
//     // ---------------- ITEMS LOOP ----------------    ////impo
//     // for (int i = 0; i < orderItems.length; i++) {
//     //
//     //
//     //   var orderItem = orderItems[i];
//     //
//     //   final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
//     //   final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";
//     //
//     //   bool hideItem =
//     //       nameLower.contains("discount") ||
//     //           nameLower.contains("coupon") ||
//     //           nameLower.contains("loyalty") ||
//     //           nameLower.contains("redeemed") ||
//     //           nameLower.contains("points") ||
//     //           itemTypeLower.contains("discount") ||
//     //           itemTypeLower.contains("coupon") ||
//     //           itemTypeLower.contains("loyalty") ||
//     //           itemTypeLower.contains("points");
//     //
//     //   if (hideItem) {
//     //     print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//     //     continue;
//     //   }
//     //
//     //   final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//     //   final isPayout = itemType.contains(TextConstants.payoutText);
//     //   final isCoupon = itemType.contains(TextConstants.couponText);
//     //   final isCashback = itemType.contains("cashback") || (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//     //   final isCouponOrPayout = isCoupon || isPayout;
//     //
//     //   final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//     //   final double salesPrice = (orderItem[AppDBConst.itemSumPrice] != null && qty > 0)
//     //       ? (orderItem[AppDBConst.itemSumPrice] / qty)
//     //       : 0.0;
//     //
//     //   double negativeItemPrice = qty * (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//     //
//     //   double rateValue;
//     //   if (isCashback) {
//     //     rateValue = salesPrice.abs();
//     //   } else if (isCouponOrPayout) {
//     //     rateValue = negativeItemPrice;
//     //   } else {
//     //     rateValue = salesPrice;
//     //   }
//     //
//     //   double amountValue;
//     //   if (isCashback) {
//     //     amountValue = (qty * salesPrice).abs();
//     //   } else if (isCouponOrPayout) {
//     //     amountValue = negativeItemPrice;
//     //   } else {
//     //     amountValue = qty * salesPrice;
//     //   }
//     //
//     //   // 🔥 MULTIPACK DISCOUNT
//     //   final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
//     //   if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//     //     amountValue -= multipackDiscount;
//     //     totalMultipackDiscount += multipackDiscount;
//     //   }
//     //
//     //   final double comboDiscount =
//     //       (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//     //
//     //   final double autoDiscount =
//     //       (orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//     //
//     //   if (!isPayout && !isCoupon && !isCashback) {
//     //     if (comboDiscount > 0) {
//     //       amountValue -= comboDiscount;
//     //       totalComboDiscount += comboDiscount;
//     //     }
//     //
//     //     if (autoDiscount > 0) {
//     //       amountValue -= autoDiscount;
//     //       totalAutoDiscount += autoDiscount;
//     //     }
//     //   }
//     //
//     //
//     //   String formattedRate = rateValue < 0
//     //       ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//     //
//     //   String formattedAmount = amountValue < 0
//     //       ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //
//     //
//     //
//     //   // ---------------- ITEM ROW ----------------
//     //   bytes += ticket.row([
//     //     PosColumn(text: "${i + 1}", width: 1),
//     //
//     //     PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//     //     PosColumn(
//     //       text: qty.toInt().toString(),
//     //       width: 1,
//     //       styles: PosStyles(align: PosAlign.center),
//     //     ),
//     //     PosColumn(
//     //       text: formattedRate,
//     //       width: 2,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //     PosColumn(
//     //       text: formattedAmount,
//     //       width: 3,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //   ]);
//     //
//     //   //  PRINT MULTIPACK DISCOUNT LINE
//     //   if (multipackDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Multipack Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (comboDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Combo Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (autoDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "Auto Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //
//     //
//     //
//     //
//     //   bytes += ticket.emptyLines(1);
//     // }
//
//     // ---------------- ITEMS LOOP ----------------
//
//     // for (int i = 0; i < orderItems.length; i++) {
//     //   var orderItem = orderItems[i];
//     //
//     //   final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
//     //   final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";
//     //
//     //   bool hideItem =
//     //       nameLower.contains("discount") ||
//     //           nameLower.contains("coupon") ||
//     //           nameLower.contains("loyalty") ||
//     //           nameLower.contains("redeemed") ||
//     //           nameLower.contains("points") ||
//     //           itemTypeLower.contains("discount") ||
//     //           itemTypeLower.contains("coupon") ||
//     //           itemTypeLower.contains("loyalty") ||
//     //           itemTypeLower.contains("points");
//     //
//     //   if (hideItem) {
//     //     print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//     //     continue;
//     //   }
//     //
//     //   final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
//     //   final isPayout = itemType.contains(TextConstants.payoutText);
//     //   final isCoupon = itemType.contains(TextConstants.couponText);
//     //   final isCashback = itemType.contains("cashback") || (orderItem[AppDBConst.itemName]?.toString().toLowerCase() == "cashback");
//     //   final isCouponOrPayout = isCoupon || isPayout;
//     //
//     //   final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//     //   final double salesPrice = (orderItem[AppDBConst.itemSumPrice] != null && qty > 0)
//     //       ? (orderItem[AppDBConst.itemSumPrice] / qty)
//     //       : 0.0;
//     //
//     //   double negativeItemPrice = qty * (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//     //
//     //   double rateValue;
//     //   if (isCashback) {
//     //     rateValue = salesPrice.abs();
//     //   } else if (isCouponOrPayout) {
//     //     rateValue = negativeItemPrice;
//     //   } else {
//     //     rateValue = salesPrice;
//     //   }
//     //
//     //   double amountValue;
//     //   if (isCashback) {
//     //     amountValue = (qty * salesPrice).abs();
//     //   } else if (isCouponOrPayout) {
//     //     amountValue = negativeItemPrice;
//     //   } else {
//     //     amountValue = qty * salesPrice;
//     //   }
//     //
//     //   // 🔥 GET DISCOUNTS
//     //   final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
//     //   final double comboDiscount = (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//     //   final double autoDiscount = (orderItem[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//     //
//     //   // 🔥 CALCULATE ORIGINAL AMOUNT (before any discount)
//     //   final double originalAmount = qty * salesPrice;
//     //
//     //   // 🔥 CHECK IF THERE'S ANY DISCOUNT
//     //   final bool hasDiscount = (multipackDiscount > 0 || comboDiscount > 0 || autoDiscount > 0)
//     //       && !isPayout && !isCoupon && !isCashback;
//     //
//     //   // 🔥 APPLY DISCOUNTS TO AMOUNT
//     //   if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//     //     amountValue -= multipackDiscount;
//     //     totalMultipackDiscount += multipackDiscount;
//     //   }
//     //
//     //   if (!isPayout && !isCoupon && !isCashback) {
//     //     if (comboDiscount > 0) {
//     //       amountValue -= comboDiscount;
//     //       totalComboDiscount += comboDiscount;
//     //     }
//     //
//     //     if (autoDiscount > 0) {
//     //       amountValue -= autoDiscount;
//     //       totalAutoDiscount += autoDiscount;
//     //     }
//     //   }
//     //
//     //   String formattedRate = rateValue < 0
//     //       ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//     //
//     //   String formattedAmount = amountValue < 0
//     //       ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//     //       : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //
//     //
//     //   // ---------------- ITEM ROW ----------------
//     //   String displayAmount;
//     //   if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//     //     // Show original price with strikethrough inline (or just as text with "-" for printer)
//     //     displayAmount = "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)} → ${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//     //   } else {
//     //     displayAmount = formattedAmount;
//     //   }
//     //   print("Itemmmmmm: ${orderItem[AppDBConst.displayAmount]} | Qty: ${qty.toInt()} | Rate: $formattedRate | Amount: $displayAmount");
//     //
//     //   bytes += ticket.row([
//     //     PosColumn(text: "${i + 1}", width: 1),
//     //     PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//     //     PosColumn(
//     //       text: qty.toInt().toString(),
//     //       width: 1,
//     //       styles: PosStyles(align: PosAlign.center),
//     //     ),
//     //     PosColumn(
//     //       text: formattedRate,
//     //       width: 2,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //     PosColumn(
//     //       text: displayAmount, // <-- INLINE ORIGINAL PRICE HERE
//     //       width: 3,
//     //       styles: PosStyles(align: PosAlign.right),
//     //     ),
//     //   ]);
//     //
//     //
//     //   // PRINT MULTIPACK DISCOUNT LINE
//     //   if (multipackDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Multipack Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (comboDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Combo Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   if (autoDiscount > 0) {
//     //     bytes += ticket.row([
//     //       PosColumn(text: "", width: 1),
//     //       PosColumn(text: "  Auto Discount", width: 7),
//     //       PosColumn(
//     //         text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
//     //         width: 4,
//     //         styles: PosStyles(align: PosAlign.right),
//     //       ),
//     //     ]);
//     //   }
//     //
//     //   bytes += ticket.emptyLines(1);
//     // }
//
//
//     for (int i = 0; i < orderItems.length; i++) {
//       var orderItem = orderItems[i];
//
//       final nameLower = orderItem[AppDBConst.itemName]
//           ?.toString()
//           .toLowerCase() ?? "";
//       final itemTypeLower = orderItem[AppDBConst.itemType]
//           ?.toString()
//           .toLowerCase() ?? "";
//
//       bool hideItem =
//           nameLower.contains("discount") ||
//               nameLower.contains("coupon") ||
//               nameLower.contains("loyalty") ||
//               nameLower.contains("redeemed") ||
//               nameLower.contains("points") ||
//               itemTypeLower.contains("discount") ||
//               itemTypeLower.contains("coupon") ||
//               itemTypeLower.contains("loyalty") ||
//               itemTypeLower.contains("points");
//
//       if (hideItem) {
//         print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
//         continue;
//       }
//
//       final itemType = orderItem[AppDBConst.itemType]
//           ?.toString()
//           .toLowerCase() ?? '';
//       final isPayout = itemType.contains(TextConstants.payoutText);
//       final isCoupon = itemType.contains(TextConstants.couponText);
//       final isCashback = itemType.contains("cashback") ||
//           (orderItem[AppDBConst.itemName]?.toString().toLowerCase() ==
//               "cashback");
//       final isCouponOrPayout = isCoupon || isPayout;
//
//       final double qty =
//           (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;
//
//       final double salesPrice =
//       (orderItem[AppDBConst.itemPrice] != null && qty > 0)
//           ? (orderItem[AppDBConst.itemPrice])
//           : 0.0;
//
//       final double cashbackPrice =
//       (orderItem[AppDBConst.itemPrice] != null && qty > 0)
//           ? (orderItem[AppDBConst.itemPrice])
//           : 0.0;
//
//       print('Quantity: $qty');
//       print('Sales Priceeeee: $salesPrice');
//
//       print('Sales cashbackPrice: $cashbackPrice');
//
//
//       double negativeItemPrice = qty *
//           (orderItem[AppDBConst.itemPrice] as num? ?? 0);
//
//       double rateValue;
//       if (isCashback) {
//         rateValue = cashbackPrice.abs();
//       } else if (isCouponOrPayout) {
//         rateValue = negativeItemPrice;
//       } else {
//         rateValue = cashbackPrice;
//       }
//
//       double amountValue;
//       if (isCashback) {
//         amountValue = (qty * cashbackPrice).abs();
//       } else if (isCouponOrPayout) {
//         amountValue = negativeItemPrice;
//       } else {
//         amountValue = qty * salesPrice;
//       }
//
//       // 🔥 GET DISCOUNTS
//       final double multipackDiscount = (orderItem[AppDBConst
//           .multipackDiscount] as num?)?.toDouble() ?? 0.0;
//       final double comboDiscount = (orderItem[AppDBConst
//           .comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
//       final double autoDiscount = (orderItem[AppDBConst
//           .displayAutoDiscount] as num?)?.toDouble() ?? 0.0;
//
//       // 🔥 CALCULATE ORIGINAL AMOUNT (before any discount)
//       final double originalAmount = qty * salesPrice;
//
//       // 🔥 CHECK IF THERE'S ANY DISCOUNT
//       final bool hasDiscount = (multipackDiscount > 0 || comboDiscount > 0 ||
//           autoDiscount > 0)
//           && !isPayout && !isCoupon && !isCashback;
//
//       // 🔥 APPLY DISCOUNTS TO AMOUNT
//       if (multipackDiscount > 0 && !isPayout && !isCoupon && !isCashback) {
//         amountValue -= multipackDiscount;
//         totalMultipackDiscount += multipackDiscount;
//       }
//
//       if (!isPayout && !isCoupon && !isCashback) {
//         if (comboDiscount > 0) {
//           amountValue -= comboDiscount;
//           totalComboDiscount += comboDiscount;
//         }
//
//         if (autoDiscount > 0) {
//           amountValue -= autoDiscount;
//           totalAutoDiscount += autoDiscount;
//         }
//       }
//
//       String formattedRate = rateValue < 0
//           ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(
//           2)}"
//           : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";
//
//       // String formattedAmount = amountValue < 0
//       //     ? "-${TextConstants.currencySymbol}${amountValue.abs().toStringAsFixed(2)}"
//       //     : "${TextConstants.currencySymbol}${amountValue.toStringAsFixed(2)}";
//
//       final double itemRowAmount = isCashback
//           ? cashbackPrice
//           : qty * salesPrice;
//
//       String formattedAmount = itemRowAmount < 0
//           ? "-${TextConstants.currencySymbol}${itemRowAmount
//           .abs()
//           .toStringAsFixed(2)}"
//           : "${TextConstants.currencySymbol}${itemRowAmount.toStringAsFixed(
//           2)}";
//
//       print(
//         'Rate: $rateValue → $formattedRate | Amounteeeee: $itemRowAmount → $formattedAmount',
//       );
//
//
//       print(
//         'Rate: $rateValue → $formattedRate | '
//             'Amounteeeee: $amountValue → $formattedAmount',
//       );
//
//       // ---------------- ITEM ROW ----------------
//
//       bytes += ticket.row([
//         PosColumn(text: "${i + 1}", width: 1),
//         PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//         PosColumn(
//           text: qty.toInt().toString(),
//           width: 1,
//           styles: PosStyles(align: PosAlign.center),
//         ),
//         PosColumn(
//           text: formattedRate,
//           width: 2,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//         PosColumn(
//           text: formattedAmount,
//           width: 3,
//           styles: PosStyles(align: PosAlign.right),
//         ),
//
//
//       ]);
//
//       // 🔥 NEW: SHOW ORIGINAL PRICE WITH STRIKETHROUGH IF DISCOUNT EXISTS
//       // if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//       //   bytes += ticket.row([
//       //     PosColumn(text: "", width: 1),
//       //     PosColumn(text: "Original Price:", width: 7),
//       //     PosColumn(
//       //       text: "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)}",
//       //       width: 4,
//       //       styles: PosStyles(align: PosAlign.right),
//       //     ),
//       //   ]);
//       // }
//
//       // ---------------- ITEM ROW ----------------
//       // String displayAmount;
//       // if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
//       //   // Show discounted amount as primary
//       //   displayAmount = formattedAmount;
//       // } else {
//       //   displayAmount = formattedAmount;
//       // }
//       //
//       // bytes += ticket.row([
//       //   PosColumn(text: "${i + 1}", width: 1),
//       //   PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
//       //   PosColumn(
//       //     text: qty.toInt().toString(),
//       //     width: 1,
//       //     styles: PosStyles(align: PosAlign.center),
//       //   ),
//       //   PosColumn(
//       //     text: formattedRate,
//       //     width: 2,
//       //     styles: PosStyles(align: PosAlign.right),
//       //   ),
//       //   PosColumn(
//       //     text: hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01
//       //         ? "${TextConstants.currencySymbol}${originalAmount.toStringAsFixed(2)}"  // Show original price
//       //         : formattedAmount,  // Show regular amount if no discount
//       //     width: 3,
//       //     styles: PosStyles(align: PosAlign.right),
//       //   ),
//       // ]);
//
// // // 🔥 NEW: SHOW DISCOUNTED PRICE BELOW IF DISCOUNT EXISTS
// //       if (hasDiscount && originalAmount > amountValue && (originalAmount - amountValue).abs() > 0.01) {
// //         bytes += ticket.row([
// //           PosColumn(text: "", width: 9),
// //           PosColumn(
// //             text: "After Discount: ${formattedAmount}",
// //             width: 3,
// //             styles: PosStyles(align: PosAlign.right),
// //           ),
// //         ]);
// //       }
//
//       // PRINT MULTIPACK DISCOUNT LINE
//
//       if (multipackDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Multipack Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${multipackDiscount
//                 .toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       if (comboDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Combo Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${comboDiscount
//                 .toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       if (autoDiscount > 0) {
//         bytes += ticket.row([
//           PosColumn(text: "", width: 1),
//           PosColumn(text: "Auto Discount", width: 7),
//           PosColumn(
//             text: "-${TextConstants.currencySymbol}${autoDiscount
//                 .toStringAsFixed(2)}",
//             width: 4,
//             styles: PosStyles(align: PosAlign.right),
//           ),
//         ]);
//       }
//
//       bytes += ticket.emptyLines(1);
//     }
//
//
//     // ---------------- SUMMARY ----------------
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.grossTotal, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.discountText, width: 8),
//       PosColumn(
//           text: "-${TextConstants.currencySymbol}${discount.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     // if (totalMultipackDiscount > 0) {
//     //   bytes += ticket.row([
//     //     PosColumn(text: "Multipack Discount", width: 10),
//     //     PosColumn(text: "-${TextConstants.currencySymbol}${totalMultipackDiscount.toStringAsFixed(2)}", width:2, styles: PosStyles(align: PosAlign.right)),
//     //   ]);
//     // }
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.taxText, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}",
//           width: 4,
//           styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.merchantDiscount, width: 8),
//       PosColumn(text: "-${TextConstants.currencySymbol}${merchantDiscount
//           .toStringAsFixed(2)}",
//           width: 4,
//           styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.cashbackFee, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.servicecharges, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${servicecharges
//           .toStringAsFixed(2)}",
//           width: 4,
//           styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//
//     bytes += ticket.feed(1);
//
//     // ---------------- NET PAYABLE & PAYMENT ----------------
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.netPayable, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${netpayable.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.redeemPoints, width: 8),
//       PosColumn(text: "${TextConstants.currencySymbol}${hiveRedeemedValue
//           .toStringAsFixed(2)}",
//           width: 4,
//           styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByCash, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.payByOther, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.tenderAmount, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.row([
//       PosColumn(text: TextConstants.change, width: 8),
//       PosColumn(
//           text: "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(
//               2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
//     ]);
//
//     bytes += ticket.feed(2);
//
//     // ---------------- FOOTER ----------------
//     if (footer != "") {
//       bytes += ticket.row([
//         PosColumn(text: "$footer",
//             width: 12,
//             styles: PosStyles(align: PosAlign.center)),
//       ]);
//     }
//
//     bytes += ticket.feed(2);
//
//     bytes += ticket.row([
//       PosColumn(
//           text: "-----------------------------------------------", width: 12),
//     ]);
//   }


  Future _preparePrintTicket() async {
    var header = _printerReceipt?[AppDBConst.receiptHeaderText] ?? "";
    var footer = _printerReceipt?[AppDBConst.receiptFooterText] ?? "";
    var logo = _printerReceipt?[AppDBConst.receiptIconPath] ?? "";

    if (kDebugMode) {
      print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $header");
      print("OrderSummaryScreen _preparePrintTicket call print receipt ---- $footer");
      print("OrderSummaryScreen _preparePrintTicket logo: $logo");
    }

    if (_order != null) {
      setState(() {
        var orderId = _order[AppDBConst.orderServerId] as int? ?? 0;
        var orderDateTime = "${_order[AppDBConst.orderDate]} ${_order[AppDBConst.orderTime]}";
        balanceAmount = (_order[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;
        final discount = uiOrderDiscount;
        final merchantDiscount = uiMerchantDiscount;
        final tax = uiOrderTax;
        final cashbackFee = uiCashbackFee;
        var balanceAmt = total - discount - merchantDiscount + tax - cashbackFee;
        if (kDebugMode) {
          print("Fetched orderServerId: $orderId, Discount: $discount for activeOrderId: ${widget.activeOrderId}, Time: $orderDateTime");
          print("Balance amount calculated is $balanceAmt and balance from API is $balanceAmount");
        }
      });
    } else {
      if (kDebugMode) {
        print("No orderServerId found for activeOrderId: ${widget.activeOrderId}");
      }
    }

    bytes = [];
    final ticket = await _printerSettings.getTicket();

    var dateToPrint = "";
    var timeToPrint = "";
    if (_order.isNotEmpty && _order[AppDBConst.orderDate] != null) {
      try {
        final DateTime createdDateTime = DateTime.parse(_order[AppDBConst.orderDate].toString());
        dateToPrint = DateFormat(TextConstants.dateFormat).format(createdDateTime);
        timeToPrint = DateFormat(TextConstants.timeFormat).format(createdDateTime);
      } catch (e) {
        if (kDebugMode) {
          print("Error parsing order creation date: $e");
        }
      }
    }

    var merchantDetails = await StoreDbHelper.instance.getStoreValidationData();
    var storeId = "${merchantDetails?[AppDBConst.storeId]}";
    var storePhone = "${merchantDetails?[AppDBConst.storePhone]}";
    var storeDetails = await AssetDBHelper.instance.getStoreDetails();
    var storeName = "${storeDetails?.name}";
    var address = "${storeDetails?.address},";
    var cityStateZip = "${storeDetails?.city},${storeDetails?.state}-${storeDetails?.zipCode}";
    var orderIdToPrint = '${widget.activeOrderId}';
    final userData = await UserDbHelper().getUserData();
    var cashierName = "${userData?[AppDBConst.userDisplayName] ?? "Unknown Name"}";
    var cashierRole = "${userData?[AppDBConst.userRole] ?? "Unknown Role"}";

    final grossTotal = uiGrossTotal;
    final discount = uiOrderDiscount;
    final merchantDiscount = uiMerchantDiscount;
    final tax = uiOrderTax;
    final cashbackFee = uiCashbackFee;
    final hiveRedeemedValue = uiRedeemedValue;
    final netpayable = uiNetPayable;

    if (kDebugMode) {
      print(" >>>>> PrintOrder dateToPrint $dateToPrint ");
      print(" >>>>> PrintOrder timeToPrint $timeToPrint ");
      print(" >>>>> PrintOrder storeId $storeId ");
      print(" >>>>> PrintOrder storeName $storeName ");
      print(" >>>>> PrintOrder address $address ");
      print(" >>>>> PrintOrder cityStateZip $cityStateZip ");
      print(" >>>>> PrintOrder storePhone $storePhone ");
      print(" >>>>> PrintOrder orderIdToPrint $orderIdToPrint ");
      print(" >>>>> PrintOrder cashierName $cashierName ");
      print(" >>>>> PrintOrder cashierRole $cashierRole ");
    }

    if (kDebugMode) {
      print("=============== 🧾 PRINT TICKET DEBUG INFO ===============");
      // ... (your original debug prints remain unchanged)
    }

    // ---------------- HEADER PRINT ----------------
    if (header != "") {
      bytes += ticket.row([
        PosColumn(
            text: "$header",
            width: 12,
            styles: PosStyles(align: PosAlign.center)),
      ]);
    }
    bytes += ticket.row([
      PosColumn(
        text: "***** INVOICE COPY *****",
        width: 12,
        styles: PosStyles(align: PosAlign.center, bold: true),
      ),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "$storeName", width: 12, styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "$address", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "$cityStateZip", width: 12, styles: PosStyles(align: PosAlign.center)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "Phone: $storePhone", width: 12, styles: PosStyles(align: PosAlign.center, bold: true)),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "Date: $dateToPrint", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "Time: $timeToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "Cashier: $cashierName", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "StoreID: $storeId", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "Role: $cashierRole", width: 7, styles: PosStyles(align: PosAlign.left)),
      PosColumn(text: "OrderID: $orderIdToPrint", width: 5, styles: PosStyles(align: PosAlign.left)),
    ]);
    bytes += ticket.feed(1);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);

    // ---------------- ITEMS HEADER ----------------
    bytes += ticket.row([
      PosColumn(text: "#", width: 1, styles: PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(text: "Description", width: 5, styles: PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(text: "Qty", width: 1, styles: PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: "Rate", width: 2, styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: "Amt", width: 3, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += ticket.feed(1);

    // 🔥 MULTIPACK DISCOUNT TOTAL
    double totalMultipackDiscount = 0.0;
    double totalComboDiscount = 0.0;
    double totalAutoDiscount = 0.0;

    // ---------------- ITEMS LOOP (only cashback handling improved) ----------------
    for (int i = 0; i < orderItems.length; i++) {
      var orderItem = orderItems[i];

      final nameLower = orderItem[AppDBConst.itemName]?.toString().toLowerCase() ?? "";
      final itemTypeLower = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? "";

      bool hideItem = nameLower.contains("discount") ||
          nameLower.contains("coupon") ||
          nameLower.contains("loyalty") ||
          nameLower.contains("redeemed") ||
          nameLower.contains("points") ||
          itemTypeLower.contains("discount") ||
          itemTypeLower.contains("coupon") ||
          itemTypeLower.contains("loyalty") ||
          itemTypeLower.contains("points");

      if (hideItem) {
        if (kDebugMode) print("🚫 HIDDEN FROM PRINT → ${orderItem[AppDBConst.itemName]}");
        continue;
      }

      final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
      final isPayout = itemType.contains(TextConstants.payoutText);
      final isCoupon = itemType.contains(TextConstants.couponText);
      final isCashback = itemType.contains("cashback") || (nameLower == "cashback");
      final isCouponOrPayout = isCoupon || isPayout;

      final double qty = (orderItem[AppDBConst.itemCount] as num?)?.toDouble() ?? 1.0;

      // ── Improved cashback value detection ───────────────────────────────
      final double basePrice = (orderItem[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
      final double sumPrice = (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ?? 0.0;
      final double cashbackValue = (orderItem['amount'] as num?)?.toDouble() ??
          (orderItem[AppDBConst.itemSumPrice] as num?)?.toDouble() ??
          sumPrice ??
          0.0;

      final double salesPrice =
      (orderItem[AppDBConst.itemPrice] != null && qty > 0)
          ? (orderItem[AppDBConst.itemPrice])
          : 0.0;

      final double cashbackPrice =
      (orderItem[AppDBConst.itemSumPrice] != null && qty > 0)
          ? (orderItem[AppDBConst.itemSumPrice])
          : 0.0;

      double rateValue;
      double amountValue;

      if (isCashback) {
        rateValue = (cashbackValue / qty).abs();     // Positive rate
        amountValue = cashbackValue.abs();           // Positive total amount
      } else if (isCouponOrPayout) {
        rateValue = basePrice;                       // usually negative
        amountValue = qty * basePrice;
      } else {
        rateValue = basePrice;
        amountValue = qty * basePrice;
      }

      // 🔥 MULTIPACK / COMBO / AUTO DISCOUNT (only for normal items)
      final double multipackDiscount = (orderItem[AppDBConst.multipackDiscount] as num?)?.toDouble() ?? 0.0;
      final double comboDiscount = (orderItem[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0;
      final double autoDiscount = (orderItem[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0;

      if (!isPayout && !isCoupon && !isCashback) {
        if (multipackDiscount > 0) {
          amountValue -= multipackDiscount;
          totalMultipackDiscount += multipackDiscount;
        }
        if (comboDiscount > 0) {
          amountValue -= comboDiscount;
          totalComboDiscount += comboDiscount;
        }
        if (autoDiscount > 0) {
          amountValue -= autoDiscount;
          totalAutoDiscount += autoDiscount;
        }
      }

      String formattedRate = rateValue < 0
          ? "-${TextConstants.currencySymbol}${rateValue.abs().toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${rateValue.toStringAsFixed(2)}";

      final double itemRowAmount = isCashback
          ? cashbackPrice
          : qty * salesPrice;

      String formattedAmount = itemRowAmount < 0
          ? "-${TextConstants.currencySymbol}${itemRowAmount
          .abs()
          .toStringAsFixed(2)}"
          : "${TextConstants.currencySymbol}${itemRowAmount.toStringAsFixed(
          2)}";

      print(
        'Rate: $rateValue → $formattedRate | Amounteeeee: $itemRowAmount → $formattedAmount',
      );

      // ---------------- ITEM ROW ----------------
      bytes += ticket.row([
        PosColumn(text: "${i + 1}", width: 1),
        PosColumn(text: "${orderItem[AppDBConst.itemName]}", width: 5),
        PosColumn(
          text: qty.toInt().toString(),
          width: 1,
          styles: PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: formattedRate,
          width: 2,
          styles: PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: formattedAmount,
          width: 3,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      // PRINT MULTIPACK DISCOUNT LINE
      if (multipackDiscount > 0) {
        bytes += ticket.row([
          PosColumn(text: "", width: 1),
          PosColumn(text: "Multipack Discount", width: 7),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${multipackDiscount.toStringAsFixed(2)}",
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (comboDiscount > 0) {
        bytes += ticket.row([
          PosColumn(text: "", width: 1),
          PosColumn(text: "Combo Discount", width: 7),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${comboDiscount.toStringAsFixed(2)}",
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (autoDiscount > 0) {
        bytes += ticket.row([
          PosColumn(text: "", width: 1),
          PosColumn(text: "Auto Discount", width: 7),
          PosColumn(
            text: "-${TextConstants.currencySymbol}${autoDiscount.toStringAsFixed(2)}",
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += ticket.emptyLines(1);
    }

    // ---------------- SUMMARY ----------------
    // ... (everything from here to the end remains 100% unchanged)
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.grossTotal, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.discountText, width: 8),
      PosColumn(text: "-${TextConstants.currencySymbol}${discount.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.taxText, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${tax.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.merchantDiscount, width: 8),
      PosColumn(text: "-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.cashbackFee, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.servicecharges, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${servicecharges.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
    bytes += ticket.feed(1);

    // NET PAYABLE & PAYMENT
    bytes += ticket.row([
      PosColumn(text: TextConstants.netPayable, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${netpayable.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.redeemPoints, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${hiveRedeemedValue.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.payByCash, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${payByCash.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.payByOther, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${payByOther.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.tenderAmount, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${tenderAmount.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.row([
      PosColumn(text: TextConstants.change, width: 8),
      PosColumn(text: "${TextConstants.currencySymbol}${changeAmount.toStringAsFixed(2)}", width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += ticket.feed(2);

    // ---------------- FOOTER ----------------
    if (footer != "") {
      bytes += ticket.row([
        PosColumn(text: "$footer", width: 12, styles: PosStyles(align: PosAlign.center)),
      ]);
    }
    bytes += ticket.feed(2);
    bytes += ticket.row([
      PosColumn(text: "-----------------------------------------------", width: 12),
    ]);
  }

/////

  Future _printTicket() async{
    final ticket =  await _printerSettings.getTicket();
    final result = await _printerSettings.printTicket(bytes, ticket);

    if (kDebugMode) {
      print(">>>> PrintTicket result $result");
    }
    switch (result) {
      case Ok<BluetoothPrinter>():
      // BluetoothPrinter printer = result.value;
        break;
      case Error<BluetoothPrinter>():
        WidgetsBinding.instance.addPostFrameCallback((_) { // Build #1.0.16
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
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => PrinterSetup(),
          )).then((result) {
            if (result == TextConstants.refresh) { // Build #1.0.175: added TextConstants
              _printerSettings.loadPrinter();
              setState(() {
                // Update state to refresh the UI
                if (kDebugMode) {
                  print("SettingScreen - printer setup is done, connected printer is ${_printerSettings.selectedPrinter?.deviceName}");
                }
                if(!Misc.disablePrinter) {
                  _printTicket();
                }
              });
            }
          });
        });
        break;
    }
  }

  void _handleError(String message, {bool isPayout = false, bool isCoupon = false, bool isCustomItem = false}) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = false);
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }
  //Build #1.0.67
  Future<void> _handleLocalDelete(Map<String, dynamic> orderItem, BuildContext context) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = false);
    await orderHelper.deleteItem(orderItem[AppDBConst.itemId]);
    await fetchOrderItems();
    widget.refreshOrderList?.call();
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(TextConstants.itemRemoved),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}