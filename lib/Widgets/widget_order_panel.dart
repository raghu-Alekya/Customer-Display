
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;
import 'package:pinaka_pos/Models/Search/product_search_model.dart';
import 'package:pinaka_pos/Providers/Auth/product_variation_provider.dart';
import 'package:pinaka_pos/Screens/Home/order_summary_screen.dart';
import 'package:pinaka_pos/Widgets/scanner_guard.dart';
import 'package:pinaka_pos/Widgets/widget_age_verification_popup_dialog.dart';
import 'package:pinaka_pos/Widgets/widget_alert_popup_dialogs.dart';
import 'package:pinaka_pos/Widgets/widget_custom_num_pad.dart';
import 'package:pinaka_pos/Widgets/widget_edit_product_items.dart';
import 'package:pinaka_pos/Widgets/widget_nested_grid_layout.dart';
import 'package:pinaka_pos/Widgets/widget_tabs.dart';
import 'package:pinaka_pos/Widgets/widget_topbar.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/layout_values.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Models/Assets/asset_model.dart';
import '../Preferences/pinaka_preferences.dart';
import '../Screens/Auth/login_screen.dart';
import '../Utilities/global_utility.dart';
import '../Models/Orders/orders_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Auth/store_validation_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Screens/Home/add_screen.dart';
import '../Screens/Home/edit_product_screen.dart';
import '../Utilities/svg_images_utility.dart';
import '../services/CustomerDisplayService.dart';
import 'ManualPriceDialog.dart';
import 'OrderPopupHelper.dart';
import 'widget_logs_toast.dart';

String logString = "";
bool isOrderInForeground = true;  ///Add visibility code to check if order panel is visible or not
class RightOrderPanel extends StatefulWidget {
  final String? formattedDate;
  final String? formattedTime;
  final List<int> quantities;
  final VoidCallback? refreshOrderList;
  final int refreshKey; //Build #1.0.170: Added: Key to trigger refresh only when explicitly needed

  const RightOrderPanel({
    this.formattedDate,
    this.formattedTime,
    required this.quantities,
    this.refreshOrderList,
    this.refreshKey = 0, //Build #1.0.170: Default to 0, increment externally to trigger refresh
    Key? key,
  }) : super(key: key);

  @override
  _RightOrderPanelState createState() => _RightOrderPanelState();
}

class _RightOrderPanelState extends State<RightOrderPanel> with TickerProviderStateMixin {
  List<Map<String, Object>> tabs = []; // List of order tabs
  TabController? _tabController; // Controller for tab switching
  final ScrollController _scrollController = ScrollController(); // Scroll controller for tab scrolling
  List<Map<String, dynamic>> orderItems = []; // List of items in the selected order
  final OrderHelper orderHelper = OrderHelper(); // Helper instance to manage orders
  bool _isLoading = false;
  static bool _isCustomItemLoading = false;
  bool _isPayBtnLoading = false;
  late OrderBloc orderBloc;
  StreamSubscription? _updateOrderSubscription;
  StreamSubscription? _fetchOrdersSubscription;
  final ProductBloc productBloc = ProductBloc(ProductRepository()); // Build #1.0.44 : Added for barcode scanning
  StreamSubscription? _productBySkuSubscription; // Build #1.0.44 : Added for product stream
  StreamSubscription? _removePayoutOrDiscountSubscription;
  StreamSubscription? _removeMerchantDiscountSubscription; // Build #1.0.274
  StreamSubscription? _removeCouponSubscription;
  bool _showFullSummary = false;
  late ScaffoldMessengerState _scaffoldMessenger;
  bool _isFetchingInitialData = false; // Build #1.0.128: Added this flag to track if we're in the middle of initial fetch
  int _listVersion = 0;  // Build 1.0.214: Added this version counter
  double cashbackFee =0.0;
  bool _scanLocked = false;
  bool _ageVerificationActive=false;

  void _toggleSummary() {
    setState(() {
      _showFullSummary = !_showFullSummary;
    });
  }
  String normalizeSku(String sku) {
    return sku.trim().toLowerCase().replaceAll(" ", "");
  }


  @override
  void initState() {
    if (kDebugMode) {
      print("##### OrderPanel initState");
    }
    orderBloc = OrderBloc(OrderRepository());
    // Build #1.0.161 - Fixed Issue: when comes from orders screen to order panel screens selected orderId changing
    orderHelper.restoreActiveOrderId(); // Build #1.0.161:
    if (!_isFetchingInitialData) { //Build #1.0.170: Fixed -  Order Cart Flickering When Clicking on Fast Keys
      fetchOrdersData(); // Build #1.0.104
    } else {
      if (kDebugMode) {
        print("##### RightOrderPanel initState: Fetch already in done, skipping -> _isFetchingInitialData:$_isFetchingInitialData");
      }
    }
    super.initState();
  }

  // Build #1.0.104: created this function for initial call & while back to this screen
  void fetchOrdersData() async {
    if (kDebugMode) {
      print("##### fetchOrdersData called (OFFLINE MODE)");
      print("##### fetchOrdersData -> isOrderPanelLoaded : ${OrderHelper.isOrderPanelLoaded}");
    }

    // ✅ Skip re-fetch if already loaded
    if (OrderHelper.isOrderPanelLoaded) {
      setState(() => _isFetchingInitialData = false);
      _getOrderTabs(); // Load tabs from OrderHelper.orders
      return;
    }

    // ✅ Indicate that we are fetching
    setState(() {
      _isFetchingInitialData = true;
      _isLoading = true;
    });

    try {
      // 🔹 Load offline data directly through OrderHelper
      final helper = OrderHelper();
      await helper.loadData(); // Already loads Hive offline orders

      if (kDebugMode) {
        print("📦 Offline orders loaded: ${helper.orders.length}");
      }

      // ✅ Mark panel loaded and render
      OrderHelper.isOrderPanelLoaded = true;
      _getOrderTabs(); // Use offline OrderHelper.orders

    } catch (e, s) {
      if (kDebugMode) {
        print("❌ Error loading offline orders in fetchOrdersData: $e");
        print("Stack trace: $s");
      }
    } finally {
      setState(() {
        _isFetchingInitialData = false;
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(RightOrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      if (kDebugMode) print("🔄 Refresh key changed — forcing data reload");
      OrderHelper.isOrderPanelLoaded = false;
      fetchOrdersData();
    }
    // if (mounted) {
    //  if(tabs.isNotEmpty){ // Build #1.0.104: Adding this conditions for old orderId's are showing before sync api call
    //    _getOrderTabs(); // Build #1.0.10 : Reload tabs when the widget updates (e.g., after item selection)
    //  }
    // }
    ///Build #1.0.170: Fixed -  Order Cart Flickering When Clicking on Fast Keys
    // Only trigger loading if refreshKey changed (indicating an external update like item add/delete)
    // This prevents unnecessary loading/flickering on unrelated parent rebuilds (e.g., time changes or screen switches)
    if (widget.refreshKey != oldWidget.refreshKey && mounted && !_isFetchingInitialData) { // Build #1.0.128: hOnly update if not in initial fetch
      setState(() => _isLoading = true); // Build #1.0.131: show loader in order panel after selecting item/product
      if (kDebugMode) {
        print("##### _isFetchingInitialData : $_isFetchingInitialData");
      }
      _getOrderTabs();
    }

    if (kDebugMode) {
      print("##### OrderPanel didUpdateWidget");
    }
  }

  // Build #1.0.10: Fetches the list of order tabs from OrderHelper
  Future<void> _getOrderTabs() async { // Build  #1.0.177: add await to loadTabs to fix delay in loading
    if (kDebugMode) {
      print("##### DEBUG: _getOrderTabs - Loading order tabs, loadOrderItems 1");
    }
    await orderHelper.loadProcessingData(); // Load order data from DB

    if (kDebugMode) {
      print("#### Order Panel loadData: activeOrderId = ${orderHelper.activeOrderId}");
      print("#### Order Panel loadData: orderIds = ${orderHelper.orderIds}");
    }
    if (mounted) {
      setState(() {
        // Convert order IDs into tab format
        tabs = orderHelper.orders
            .asMap()
            .entries
            .map((entry) => {
          "title": "#${entry.value[AppDBConst.orderServerId] ?? entry.value[AppDBConst.orderId]}",
          "subtitle": "Tab ${entry.key + 1}",
          "orderId": entry.value[AppDBConst.orderServerId] as Object, // Use db orderId, not serverId
        }).toList();
        if (kDebugMode) {
          print("##### DEBUG: _getOrderTabs - Loaded ${tabs.length} tabs: $tabs");
        }
      });
    }
    if (kDebugMode) {
      print("##### DEBUG: _getOrderTabs - orderHelper.activeOrderId ${orderHelper.activeOrderId} tab: $tabs, index: ${orderHelper.orderIds.indexOf(orderHelper.activeOrderId ?? 0)}"); // Build #1.0.104: unwrap issue fixed
    }

    if (!mounted) return; // Prevent controller initialization if unmounted
    _initializeTabController(); // Initialize tab controller
    if (kDebugMode) {
      print("##### _getOrderTabs saveLastActiveOrderId tabs.isNotEmpty ${tabs.isNotEmpty}");
    }
    if (tabs.isNotEmpty) {
      int index = -1;
      if (orderHelper.activeOrderId != null) {
        index = orderHelper.orderIds.indexOf(orderHelper.activeOrderId!);
        if (kDebugMode) {
          print("##### _getOrderTabs saveLastActiveOrderId index: $index");
        }
        if (index == -1) {
          if (kDebugMode) {
            print("##### DEBUG: _getOrderTabs - Active order ID ${orderHelper.activeOrderId} not found, defaulting to last tab");
          }
          index = tabs.length - 1;
        }
        await orderHelper.setActiveOrder(tabs[index]["orderId"] as int);
        if (kDebugMode) {
          print("saveLastActiveOrderId _getOrderTabs yes active tab, orderHelper.activeOrderId: ${orderHelper.activeOrderId}, orderID: ${tabs[index]["orderId"]}");
        }
        await orderHelper.saveLastActiveOrderId(tabs[index]["orderId"] as int); // Build #1.0.161

      } else {
        if (kDebugMode) {
          print("##### DEBUG: _getOrderTabs - No active order, setting to last tab");
        }
        index = tabs.length - 1;
        await orderHelper.setActiveOrder(tabs[index]["orderId"] as int);
        if (kDebugMode) {
          print("saveLastActiveOrderId _getOrderTabs no active tab, orderHelper.activeOrderId: ${orderHelper.activeOrderId}, orderID: ${tabs[index]["orderId"]}");
        }
        await orderHelper.saveLastActiveOrderId(tabs[index]["orderId"] as int); // Build #1.0.161
      }
      if (mounted && _tabController != null) {
        _tabController?.index = index;
        if (kDebugMode) {
          print("##### DEBUG: _getOrderTabs - Set tab index to $index, orderID: ${tabs[index]["orderId"]} activeOrderId: ${orderHelper.activeOrderId}");
        }
      }

      //Build #1.0.78: FIX: Scroll to ensure active tab is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _tabController != null) {
          final tabWidth = 180.0; // Adjust this based on your actual tab width
          final screenWidth = MediaQuery.of(context).size.width * 0.58; // Panel width
          final activeIndex = _tabController!.index;
          final offset = (activeIndex * tabWidth) - (screenWidth / 2) + (tabWidth / 2);

          _scrollController.animateTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });

      await fetchOrderItems(); // Load items for active order
      if(mounted) {
        setState(() => _isLoading = false); // Build #1.0.104: Hide loader
      }
    } else {
      if (kDebugMode) {
        print("##### DEBUG: _getOrderTabs - No tabs available");
      }
      if (mounted) {
        setState(() {
          orderItems = [];// Build #1.0.104: Clear items if no tabs
        });
      }
      _initializeTabController(); // Build #1.0.189: required here
    }
    if (mounted) {
      setState(() => _isLoading = false); // Hide loader
    }
  }

  void _fetchOrders() { //Build #1.0.40: fetch orders items from API sync & updating to UI
    // updated above
    // setState(() => _isLoading = true); // Build #1.0.104: Show loader
    _fetchOrdersSubscription?.cancel(); //Build #1.0.170
    _fetchOrdersSubscription = orderBloc.fetchOrdersStream.listen((response) async {
      if (!mounted) return;

      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print("##### DEBUG: Fetched orders successfully 33333, total orders: ${orderHelper.orders.length}");
        }
        setState(() => _isFetchingInitialData = false); // Build #1.0.128: Initial fetch complete
        await _getOrderTabs(); // Build  #1.0.177: add await to loadTabs to fix delay in loading
        OrderHelper.isOrderPanelLoaded = true;
        //_fetchOrdersSubscription?.cancel();
      } else if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("categories screen 1  ---- Unauthorised : ${response.message!}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              if (kDebugMode) {
                print("message 1 --- ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        else {
          if (kDebugMode) {
            print("##### ERROR: Fetch orders failed - ${response.message}");
          }
          setState(() {
            _isLoading = false;
            _isFetchingInitialData = false; // Build #1.0.128
          }); // Build #1.0.104: Hide loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? "Failed to fetch orders"),
              backgroundColor: Colors.red, // ✅ Added red background for error
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    orderBloc.fetchOrders();
  }

  // Build #1.0.10: Fetches order items for the active order
  Future<void> fetchOrderItems() async {
    if (kDebugMode) {
      print("##### DEBUG: fetchOrderItems 112233");
    }
    if (orderHelper.activeOrderId != null) {
      if (kDebugMode) {
        print("##### DEBUG: order panel fetchOrderItems - Fetching items for activeOrderId: ${orderHelper.activeOrderId}");
      }
      try { // Build #1.0.189: Refresh tabs to reflect no active order
        var orders = await orderHelper.getOrderById(orderHelper.activeOrderId!);
        if (orders.isEmpty) {
          if (kDebugMode) {
            print("##### DEBUG: fetchOrderItems - No order found for activeOrderId: ${orderHelper.activeOrderId}, clearing items");
          }
          setState(() {
            orderItems = []; // Clear items if no order exists
            orderHelper.activeOrderId = null; // Reset activeOrderId
          });
          //   await orderHelper.saveLastActiveOrderId(null); // Clear saved activeOrderId
          await _getOrderTabs(); // Refresh tabs to reflect no active order
          return;
        }

        var order = orders.first;
        if (kDebugMode) {
          print("##### DEBUG: fetchOrderItems - Retrieved ${order.length}");
          print("##### DEBUG: fetchOrderItems - Retrieved order: ${order[AppDBConst.orderServerId]}");
          print("##### DEBUG: fetchOrderItems - Retrieved items: ${order[AppDBConst.itemProductId]}");
        }
        List<Map<String, dynamic>> items = await orderHelper.getOrderItems(order[AppDBConst.orderServerId]);
        if (kDebugMode) {
          print("##### DEBUG: fetchOrderItems - Retrieved ${items.length} items: $items");
        }

        if (mounted) {
          setState(() {
            orderItems = List<Map<String, dynamic>>.from(items); // Create mutable copy
            _listVersion++; // Build 1.0.214: Increment version when items change
          });
        }
      } catch (e, s) {
        if (kDebugMode) {
          print("##### ERROR: fetchOrderItems failed - $e, Stack: $s");
        }
        if (mounted) {
          setState(() {
            orderItems = []; // Clear items on error
          });
        }
      }
    } else {
      if (kDebugMode) {
        print("##### DEBUG: fetchOrderItems - No active order, clearing items");
      }
      setState(() => _isLoading = false); // Build #1.0.104: Hide loader
      if (mounted) {
        setState(() {
          orderItems = []; // Clear items if no active order
          _listVersion++; // Build 1.0.214: Increment version when items change
        });
      }
    }
  }

  dynamic _convertToJsonSafe(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertToJsonSafe(v)));
    } else if (value is List) {
      return value.map(_convertToJsonSafe).toList();
    } else if (value is Enum) {
      return value.name;
    } else if (value is Object) {
      try {
        final json = (value as dynamic).toJson?.call();
        if (json is Map) return _convertToJsonSafe(json);
      } catch (_) {}
    }
    return value; // primitives
  }

  // Build #1.0.10: Initializes the tab controller and handles tab switching
  Future<void> _initializeTabController() async {
    if (kDebugMode) print("##### _initializeTabController");
    if (!mounted) return;
    if (tabs.isEmpty) {
      orderHelper.activeOrderId = null;
      orderItems = [];

      final storeInfo = PinakaPreferences.getLoggedInStore();
      if (storeInfo.isNotEmpty) {
        await CustomerDisplayHelper.updateWelcomeWithStore(
          storeInfo['storeId']!,
          storeInfo['storeName']!,
          storeLogoUrl: storeInfo['storeLogoUrl'],
          storeBaseUrl: storeInfo['storeBaseUrl'],
        );
      } else {
        await CustomerDisplayService.showWelcome();
      }

      return;
    }

    _tabController?.dispose();

    _tabController = TabController(length: tabs.length, vsync: this);

    _tabController!.addListener(() async {
      if (!_tabController!.indexIsChanging && mounted) {
        int selectedIndex = _tabController!.index;
        int selectedOrderId = tabs[selectedIndex]["orderId"] as int;

        await orderHelper.setActiveOrder(selectedOrderId);
        await orderHelper.saveLastActiveOrderId(selectedOrderId);
        await fetchOrderItems();
        await CustomerDisplayHelper.updateCustomerDisplay(selectedOrderId);

        if (mounted) setState(() {});
      }
    });

    // ✅ Select default tab safely
    int defaultIndex = 0;
    if (orderHelper.activeOrderId != null) {
      int idx = orderHelper.orderIds.indexOf(orderHelper.activeOrderId!);
      if (idx != -1) defaultIndex = idx;
    } else {
      defaultIndex = tabs.length - 1;
      await orderHelper.setActiveOrder(tabs[defaultIndex]["orderId"] as int);
    }

    if (mounted) {
      _tabController!.index = defaultIndex;
      await CustomerDisplayHelper.updateCustomerDisplay(
        tabs[defaultIndex]["orderId"] as int,
      );
    }
  }

  // Build #1.0.10: Creates a new order and adds it as a new tab
  //Build #1.0.78: Explanation!
  // Removed orderHelper.createOrder and setActiveOrder as they’re now handled in OrderBloc.
  // Updated UI (tabs, tab controller, items) after API success.
  // Added alert dialog for error handling with retry option.
  // Loader is shown via _isLoading during the API call.
  void addNewTab() async {
    // Create new order if none exists
    if (kDebugMode) {
      print("##### DEBUG: addNewTab - Creating new order");
    }
    showLogs = true;
    logString += "##### DEBUG: addNewTab - Creating new order \n ";
    /// Build #1.0.128: No need here , now we are handling from Order repository class
    // final prefs = await SharedPreferences.getInstance();
    // final shiftId = prefs.getString(TextConstants.shiftId);
    //
    // //Build #1.0.78: Validation required : if shift id is empty show toast or alert user to start the shift first
    // if (shiftId == null || shiftId.isEmpty) {
    //   if (kDebugMode) print("####### _createOrder() : shiftId -> $shiftId");
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text("Please start your shift before creating an order."),
    //       backgroundColor: Colors.green,
    //       duration: const Duration(seconds: 2),
    //     ),
    //   );
    // }
    setState(() => _isLoading = true); // Show loader
    // String deviceId = await getDeviceId();
    // OrderMetaData device = OrderMetaData(key: OrderMetaData.posDeviceId, value: deviceId);
    // OrderMetaData placedBy = OrderMetaData(key: OrderMetaData.posPlacedBy, value: '${orderHelper.activeUserId ?? 1}');
    // OrderMetaData shiftIdValue = OrderMetaData(key: OrderMetaData.shiftId, value: shiftId!);
    // List<OrderMetaData> metaData = [device, placedBy, shiftIdValue];

    _updateOrderSubscription?.cancel();
    _updateOrderSubscription = orderBloc.createOrderStream.listen((response) async {
      if (!mounted) return;

      if (response.status == Status.COMPLETED) {
        setState(() => _isLoading = false); // Hide loader
        if (kDebugMode) {
          print("##### DEBUG: addNewTab - Order created successfully, serverOrderId: ${response.data!.id}");
        }
        setState(() {
          tabs.add({
            "title": "#${response.data!.id}",
            "subtitle": "Tab ${tabs.length + 1}",
            "orderId": response.data!.id as Object,
          });
        });

        _initializeTabController();
        _tabController?.index = tabs.length - 1;
        _scrollToSelectedTab();
        await fetchOrderItems();

        if (Misc.showDebugSnackBar) { // Build #1.0.254
          _scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("Order created successfully"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("categories screen 2  ---- Unauthorised : ${response.message!}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              if (kDebugMode) {
                print("message 2 --- ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        else {
          setState(() => _isLoading = false); //Build #1.0.99: Hide loader
          if (kDebugMode) {
            print("##### ERROR: addNewTab - Failed to create order: ${response
                .message}");
          }
          _scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(response.message ?? "Failed to create order"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    logString += await orderBloc.createOrder(); // Build #1.0.128
    setState(() {});
  }
  // =============================================================
// GLOBAL HELPER — FIXES ALL MAP<dynamic, dynamic> ERRORS
// =============================================================
  dynamic deepCast(dynamic source) {
    if (source is Map) {
      return source.map(
            (key, value) => MapEntry(key.toString(), deepCast(value)),
      );
    }

    if (source is List) {
      return source.map((e) => deepCast(e)).toList();
    }

    return source;
  }

  // Scrolls to the last tab to ensure visibility
  void _scrollToSelectedTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Build #1.0.10: Removes a tab (order) from the UI and database
  //Build #1.0.78:Explanation:
  // Removed orderHelper.deleteOrder from the API success block, as it’s now handled in OrderBloc.changeOrderStatus.
  // Kept local deletion for non-API orders (serverOrderId == null).
  // Ensured loader is shown (_isLoading = true) and hidden appropriately.
  // Added alert dialog for error handling with retry option.

  // Build #1.0.10: Deletes an item from the active order
  //Build #1.0.78: Explanation!
  // Removed database operations (orderHelper.deleteItem) as they’re now in OrderBloc.
  // Added dbOrderId and dbItemId to deleteOrderItem, removeFeeLines, and removeCoupon calls.
  // Used sku in OrderLineItem for custom items and products.
  // Ensured loader is shown during API calls.
  // Kept local deletion for non-API orders.
  bool _isDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _updateOrderSubscription?.cancel(); // Cancel the subscription
    //orderBloc.dispose(); // Dispose the bloc if needed
    _fetchOrdersSubscription?.cancel();
    _removeMerchantDiscountSubscription?.cancel();
    orderBloc.dispose();
    productBloc.dispose();
    _tabController?.dispose();
    _scrollController.dispose(); // Dispose ScrollController
    _productBySkuSubscription?.cancel(); // Build #1.0.44 : Added Cancel product subscription
    // productBloc.dispose(); // Added: Dispose ProductBloc
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

  /// Extract DOB from barcode: expects "DBBMMDDYYYY"
  DateTime? parseDOBFromBarcode(String barcodeData) {
    try {
      if (kDebugMode) {
        print("Order Panel parseDOBFromBarcode: $barcodeData");
      }
      final dobMatch = RegExp(r'DBB(\d{8})').firstMatch(barcodeData);
      if (dobMatch != null) {
        final dobStr = dobMatch.group(1)!;
        final month = int.parse(dobStr.substring(0, 2));
        final day = int.parse(dobStr.substring(2, 4));
        final year = int.parse(dobStr.substring(4, 8));
        if (kDebugMode) {
          print("Order Panel parseDOBFromBarcode: $month/$day/$year");
        }
        return DateTime(year, month, day);
      }
    } catch (e) {
      if (kDebugMode) print("Error parsing DOB: $e");
    }
    return null;
  }

  Future<void> _openCustomItemDialog(BuildContext context, String barcode) async {
    if (_isCustomItemLoading) return;
    _isCustomItemLoading = true;

    await CustomDialog.showCustomItemNotAdded(
      context,
      onRetry: () {
        Navigator.of(context).pop();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => AddScreen(
              barcode: barcode,
              selectedTabIndex: 2, // Custom Item tab
            ),
          ),
              (route) => false,
        );
      },
    ).then((_) {
      _isCustomItemLoading = false;
      if (kDebugMode) {
        print("🧩 Custom Item dialog closed for SKU: $barcode");
      }
    });
  }
//Build #1.0.268: 1. add below function in  BarcodeKeyboardListenerState lib
  // void callback(String barcode){
  //   _onBarcodeScannedCallback.call(barcode);
  // }
  // final GlobalKey<BarcodeKeyboardListenerState> _scannerKey = GlobalKey();//Build #1.0.268: 2. create global key
  @override
  Widget build(BuildContext context) {

    final themeHelper = Provider.of<ThemeNotifier>(context);
    return FocusDetector(
      onFocusLost: () { // Build #1.0.219 -> FIXED ISSUE [SCRUM - 366] : Swipe-to-Delete UI State Not Resetting
        // When this widget regains focus, reset slidable states
        if(!mounted) return;
        setState(() {
          _listVersion++;
        });
      },
      child: BarcodeKeyboardListener( // Build #1.0.44 : Added - Wrap with BarcodeKeyboardListener for barcode scanning
        // key:  _scannerKey,//Build #1.0.268: 3. Add key for scanner event
        bufferDuration: Duration(milliseconds: 700),
        //Build #1.0.78: Removed orderHelper.addItemToOrder from the API success block, as it’s now in OrderBloc.updateOrderProducts.
        // Kept local addItemToOrder for non-API orders.
        // Ensured loader is shown during API calls and hidden afterward.
        useKeyDownEvent: Platform.isWindows,
        caseSensitive: true,
//         onBarcodeScanned: (barcode) async {
//           //  ⛔ HARD BLOCK — prevents duplicate scans
//           if (_scanLocked || _ageVerificationActive) return;
//
//           final trimmedBarcode = barcode;
//
//           // ⛔ Ignore junk frames
//           if (trimmedBarcode.length < 6) return;
//           try {
//             final trimmedBarcode = barcode;
//             if (kDebugMode) print("🔹 Scanned → $trimmedBarcode");
//
//             final upper = trimmedBarcode.toUpperCase();
//
//             final bool isDriverLicense =
//                 upper.contains("ANSI") ||
//                     upper.contains("DBB") ||
//                     upper.contains("DAQ") ||
//                     upper.contains("DL");
//
//             if (isDriverLicense) {
//
//               if (kDebugMode) {
//                 print("🪪 Driver License detected → stopping product flow");
//                 print("🪪 DRIVER LICENSE RAW BARCODE ↓↓↓");
//                 print(trimmedBarcode); // ✅ FULL PDF417 DATA
//                 print("🪪 DRIVER LICENSE RAW BARCODE ↑↑↑");
//               }
//               _ageVerificationActive = true;
//               _scanLocked = true;
//
//               // ⏳ Absorb trailing scanner frames
//               await Future.delayed(const Duration(milliseconds: 1200));
//
//               _ageVerificationActive = false;
//
//               // 🔥 VERY IMPORTANT — STOP HERE
//               return;
//             }
//
//
//             if (!isOrderInForeground ||
//                 trimmedBarcode.isEmpty ||
//                 _isLoading ||
//                 _isCustomItemLoading) return;
//
//             _isLoading = true;
//             if (mounted) setState(() {});
//
//             final orderHelper = OrderHelper();
//             final activeOrderId = orderHelper.activeOrderId;
//
//             if (activeOrderId == null) {
//               await OrderPopupHelper.showNoOrderPopup(context);
//               return;
//             }
//
//
//             final productBox = Hive.box('productCache');
//             final cacheKey = "sku_${trimmedBarcode.toLowerCase()}";
//
//             SKU.ProductBySkuResponse? product;
//             bool foundOffline = false;
//
//             // ---------------------------------------------------------------------------
//             // 1️⃣ MEMORY CACHE
//             // ---------------------------------------------------------------------------
// // 1️⃣ MEMORY CACHE
// // ---------------------------------------------------------------------------
//             try {
//               final memoryData = OrderHelper.getFromCache(trimmedBarcode);
//
//               if (memoryData != null) {
//                 if (kDebugMode) {
//                   print("💾 MEMORY CACHE HIT");
//                   print("💾 memoryData (raw) → $memoryData");
//                   try {
//                     print("💾 memoryData (json) → ${jsonEncode(memoryData)}");
//                   } catch (_) {
//                     print("💾 memoryData NOT JSON serializable");
//                   }
//                 }
//
//                 Map<String, dynamic> productMap;
//
//                 // Case A → stored as {products:[{...}]}
//                 if (memoryData is Map &&
//                     memoryData["products"] is List &&
//                     memoryData["products"].isNotEmpty) {
//                   productMap = Map<String, dynamic>.from(memoryData["products"][0]);
//                 }
//                 // Case B → stored as flat map
//                 else {
//                   productMap = Map<String, dynamic>.from(memoryData);
//                 }
//
//                 if (kDebugMode) {
//                   print("💾 Extracted productMap from memory → $productMap");
//                   try {
//                     print("💾 productMap JSON → ${jsonEncode(productMap)}");
//                   } catch (_) {
//                     print("💾 productMap not JSON encodable");
//                   }
//                   // ⭐⭐⭐ ADD THESE THREE ⭐⭐⭐
//                   print("🖼 MEMORY productMap['images'] → ${productMap['images']}");
//
//                   if (productMap['images'] is List && productMap['images'].isNotEmpty) {
//                     print("🖼 MEMORY image src → ${productMap['images'][0]['src']}");
//                   } else {
//                     print("🖼 MEMORY image src → NONE");
//                   }
//                 }
//
//                 product = SKU.ProductBySkuResponse.fromJson(productMap);
//                 foundOffline = true;
//
//                 if (kDebugMode) {
//                   print("🧠 MEMORY → PRODUCT → name=${product?.name}, price=${product?.price}, sku=${product?.sku}");
//                 }
//               }
//             } catch (e, s) {
//               print("❌ MEMORY CACHE ERROR → $e");
//               print("📌 STACKTRACE → $s");
//             }
//
// // ---------------------------------------------------------------------------
// // 2️⃣ PRODUCT CACHE (Custom Items + Normal SKU)
// // ---------------------------------------------------------------------------
//             try {
//               if (product == null) {
//                 final cached = productBox.get(cacheKey);
//
//                 if (cached != null) {
//                   if (kDebugMode) {
//                     print("💽 HIVE productCache[$cacheKey] RAW → $cached");
//                     try {
//                       print("💽 HIVE JSON → ${jsonEncode(cached)}");
//                     } catch (_) {
//                       print("💽 HIVE map not JSON encodable");
//                     }
//                   }
//
//                   List<dynamic> items = [];
//
//                   if (cached is Map && cached["products"] is List) {
//                     items = cached["products"];
//                   }
//
//                   if (items.isNotEmpty) {
//                     final productMap = Map<String, dynamic>.from(items[0]);
//
//                     if (kDebugMode) {
//                       print("💽 Extracted productMap from Hive → $productMap");
//                       try {
//                         print("💽 productMap JSON → ${jsonEncode(productMap)}");
//                       } catch (_) {
//                         print("💽 productMap not JSON encodable");
//                       }
//                     }
//
//                     product = SKU.ProductBySkuResponse.fromJson(productMap);
//                     foundOffline = true;
//
//                     if (kDebugMode) {
//                       print("🟢 productCache → PRODUCT → name=${product?.name}, price=${product?.price}");
//                     }
//                   }
//                 }
//               }
//             } catch (e, s) {
//               print("❌ PRODUCT CACHE ERROR → $e");
//               print("📌 STACKTRACE → $s");
//             }
//
//             // ---------------------------------------------------------------------------
//             // 3️⃣ CUSTOM ITEM → Increment quantity if already in order
//             // ---------------------------------------------------------------------------
//             try {
//               final offlineBox = Hive.box('offlineOrders');
//               final raw = offlineBox.get(activeOrderId.toString());
//
//               if (raw != null) {
//                 List<Map<String, dynamic>> orderProducts =
//                 List<Map<String, dynamic>>.from(raw["products"] ?? []);
//
//                 final existingIndex = orderProducts
//                     .indexWhere((p) => normalizeSku(p["sku"]) == trimmedBarcode);
//
//                 if (existingIndex != -1) {
//                   if (kDebugMode) print("🔼 Custom item found → incrementing");
//
//                   orderProducts[existingIndex]["quantity"] =
//                       (orderProducts[existingIndex]["quantity"] ?? 1) + 1;
//
//                   await offlineBox.put(activeOrderId.toString(), {
//                     ...raw,
//                     "products": orderProducts,
//                   });
//
//                   await fetchOrderItems();
//                   await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);
//
//
//                   _isLoading = false;
//                   if (mounted) setState(() {});
//                   return;
//                 }
//               }
//             } catch (e) {
//               print("⚠ Offline custom increment error: $e");
//             }
//
//             // ---------------------------------------------------------------------------
//             // 4️⃣ FULL LIST CACHE
//             // ---------------------------------------------------------------------------
//             try {
//               if (product == null) {
//                 final allData = productBox.get("all_products_list");
//
//                 if (allData is List) {
//                   for (var item in allData) {
//                     final p =
//                     SKU.ProductBySkuResponse.fromJson({"products": [deepCast(item)]});
//                     if ((p.sku ?? "").toLowerCase() == trimmedBarcode.toLowerCase()) {
//                       product = p;
//                       foundOffline = true;
//                       break;
//                     }
//                   }
//                 }
//               }
//             } catch (e) {
//               if (kDebugMode) print("⚠ full list error: $e");
//             }
//
//             // ---------------------------------------------------------------------------
//             // 5️⃣ ONLINE API FETCH
//             // ---------------------------------------------------------------------------
//             if (product == null) {
//               try {
//                 final products =
//                 await ProductRepository().fetchProductBySku(trimmedBarcode);
//
//                 if (products.isNotEmpty) {
//                   product = products.first;
//
//                   await productBox.put(cacheKey, {
//                     "products": products.map((p) => deepCast(p.toJson())).toList(),
//                     "timestamp": DateTime.now().toIso8601String(),
//                   });
//
//                   if (kDebugMode) print("🌐 Online fetch → ${product?.name}");
//                 }
//               } catch (e) {
//                 print("📴 API error: $e");
//               }
//             }
//
//             // ---------------------------------------------------------------------------
//             // 6️⃣ STILL NULL → CUSTOM ITEM POPUP
//             // ---------------------------------------------------------------------------
//             // 6️⃣ STILL NULL → CUSTOM ITEM POPUP
//             if (product == null) {
//               if (_scanLocked || _ageVerificationActive || isDriverLicense) {
//                 if (kDebugMode) {
//                   print("🚫 Custom Item popup BLOCKED (DL / Age / Locked)");
//                 }
//
//                 _isLoading = false;
//                 if (mounted) setState(() {});
//                 return;
//               }
//
//               await _openCustomItemDialog(context, trimmedBarcode);
//               return;
//             }
//
//             // ---------------------------------------------------------------------------
//             // 7️⃣ EXTRACT PRODUCT DATA
//             // ---------------------------------------------------------------------------
//             final productId = product.id ?? -1;
//             final productName = product.name ?? "Unnamed Product";
//             final productSku = product.sku ?? trimmedBarcode;
//             final productPrice =
//                 double.tryParse(product.price?.toString() ?? "0") ?? 0;
//
//             String image = "";
//             if ((product.images ?? []).isNotEmpty) {
//               image = product.images!.first.src ?? "";
//             }
//
//             // ⭐ AGE RESTRICTION CHECK — ONE TIME PER ORDER (FINAL FIX)
//             // ----------------------------------------------------------- */
//
//             if (kDebugMode) {
//               print("\n---------------- AGE CHECK START ----------------");
//               print("Product Scanned: ID=${product.id}, Name=${product.name}");
//             }
//
// // ======================================================
// // 1️⃣ INIT
// // ======================================================
//             bool isRestricted = false;
//             int minimumAge = 0;
//
// // ======================================================
// // 2️⃣ CHECK METADATA
// // ======================================================
//             for (final m in (product.metaData ?? [])) {
//               final key = (m.key ?? "");
//               final val = (m.value ?? "");
//
//               if (key == "age_restricted") {
//                 if (val == "1" || val == "true") {
//                   isRestricted = true;
//                 }
//
//                 final int? parsedAge = int.tryParse(val);
//                 if (parsedAge != null && parsedAge > 0) {
//                   minimumAge = parsedAge;
//                   isRestricted = true;
//                 }
//               }
//             }
//
// // ======================================================
// // 3️⃣ CHECK TAGS
// // ======================================================
//             for (final tag in (product.tags ?? [])) {
//               final name = (tag.name ?? "").toLowerCase();
//               final slug = (tag.slug ?? "").toLowerCase();
//
//               if (name.contains("alcohol") || slug.contains("alcohol")) {
//                 isRestricted = true;
//               }
//
//               final bool looksAgeTag =
//                   name.contains("18+") ||
//                       name.contains("21+") ||
//                       slug.contains("18+") ||
//                       slug.contains("21+") ||
//                       name.contains("age") ||
//                       slug.contains("age") ||
//                       name.contains("restricted") ||
//                       slug.contains("restricted");
//
//               if (looksAgeTag) {
//                 final cleaned = slug.replaceAll(RegExp(r"[^0-9]"), "");
//                 final int? parsedAge = int.tryParse(cleaned);
//
//                 if (parsedAge != null && parsedAge > 0) {
//                   minimumAge = parsedAge;
//                   isRestricted = true;
//                 }
//               }
//             }
//
// // ======================================================
// // 4️⃣ GET ORDER HIVE DATA
// // ======================================================
//             final hiveBox = Hive.box('offlineOrders');
//             final orderKey = orderHelper.activeOrderId.toString();
//
//             final Map<String, dynamic> hiveOrder = Map<String, dynamic>.from(
//               hiveBox.get(orderKey, defaultValue: {}),
//             );
//
//             final bool alreadyVerified =
//                 hiveOrder["age_verified"] == true ||
//                     hiveOrder["age_verified"] == 1 ||
//                     hiveOrder["age_verified"]?.toString().toLowerCase() == "true";
//
//             if (kDebugMode) print("Already verified? → $alreadyVerified");
//
// // ======================================================
// // 5️⃣ SKIP ENTIRE AGE FLOW IF ALREADY VERIFIED
// // ======================================================
//             if (alreadyVerified) {
//               if (kDebugMode) print("✔ Age already verified → skipping popup.");
//             } else if (isRestricted) {
//               // FIRST TIME ONLY → SHOW POPUP THROUGH PROVIDER
//               if (kDebugMode) print("🔔 Showing Age Verification Popup (FIRST TIME)");
//
//               final prov = AgeVerificationProvider();
//               final bool ok = await prov.ageRestrictedProduct(context, product);
//
//               // User failed age verification
//               if (!ok) {
//                 _isLoading = false;
//                 if (mounted) setState(() {});
//                 _scaffoldMessenger.showSnackBar(
//                   const SnackBar(
//                     content: Text("❌ Age verification failed"),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//                 return;
//               }
//
//               // SUCCESS → SAVE FLAG
//               hiveOrder["age_verified"] = true;
//               await hiveBox.put(orderKey, hiveOrder);
//
//               if (kDebugMode) print("💾 Saved age_verified = TRUE for order $orderKey");
//             } else {
//               if (kDebugMode) print("✔ Product is NOT age restricted.");
//             }
//
//             if (kDebugMode) print("---------------- AGE CHECK END ----------------\n");
//
//
//             // ---------------------------------------------------------------------------
//             // 8️⃣ VARIATIONS FLOW
//             // =====================================================================
//             if ((product.variations ?? []).isNotEmpty) {
//               final id = product.id ?? -1;
//               productBloc.fetchProductVariations(id);
//
//               final response = await productBloc.variationStream
//                   .firstWhere((r) => r.status == Status.COMPLETED);
//
//               if (response.data != null && response.data!.isNotEmpty) {
//                 final variants = response.data!.map((v) {
//                   return {
//                     "id": v.id ?? -1,
//                     "name": v.name ?? productName,
//                     "price": v.price ?? "0",
//                     "image": v.image?.src ?? "",
//                     "sku": v.sku ?? "",
//                   };
//                 }).toList();
//
//                 await showDialog(
//                   context: context,
//                   barrierDismissible: false,
//                   builder: (_) => VariantsDialog(
//                     title: productName,
//                     variations: variants,
//                     onAddVariant: (selected, qty) async {
//                       await orderHelper.addItemToOrder(
//                         selected["id"],
//                         selected["name"],
//                         selected["image"],
//                         double.tryParse(selected["price"].toString()) ?? 0,
//                         qty,
//                         selected["sku"],
//                         activeOrderId,
//                         type: ItemType.product.value,
//                         productId: id,
//                         variationId: selected["id"],
//                       );
//                       await fetchOrderItems();
//                       await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);
//                     },
//                   ),
//                 );
//
//                 _isLoading = false;
//                 if (mounted) setState(() {});
//                 return;
//               }
//             }
//
//             // ---------------------------------------------------------------------------
//             // 9️⃣ ADD ITEM TO ORDER
//             // ---------------------------------------------------------------------------
//             await orderHelper.addItemToOrder(
//               productId,
//               productName,
//               image,
//               productPrice,
//               1,
//               productSku,
//               activeOrderId,
//               type: ItemType.product.value,
//               productId: productId,
//               variationId: -1,
//             );
//
//             await fetchOrderItems();
//             await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);
//
//             _isLoading = false;
//             if (mounted) setState(() {});
//           } catch (e, s) {
//             print("❌ Scan failed: $e\n$s");
//             _isLoading = false;
//             if (mounted) setState(() {});
//           }
//
//           finally {
//             // 🔓 ALWAYS UNLOCK HERE
//             await Future.delayed(const Duration(milliseconds: 800));
//             _scanLocked = false;
//
//             if (kDebugMode) {
//               print("🔓 Scanner unlocked (finally)");
//             }
//           }
//         },
        onBarcodeScanned: (barcode) async {
          //  ⛔ HARD BLOCK — prevents duplicate scans
          if (_scanLocked) return;


          final trimmedBarcode = barcode;

          // ⛔ Ignore junk frames
          if (trimmedBarcode.length < 6) return;
          try {
            final trimmedBarcode = barcode;
            if (kDebugMode) print("🔹 Scanned → $trimmedBarcode");

            final upper = trimmedBarcode.toUpperCase();

            final bool isDriverLicense =
                upper.contains("ANSI") ||
                    upper.contains("DBB") ||
                    upper.contains("DAQ") ||
                    upper.contains("DL");

            if (isDriverLicense) {

              if (kDebugMode) {
                print("🪪 Driver License detected → stopping product flow");
                print("🪪 DRIVER LICENSE RAW BARCODE ↓↓↓");
                print(trimmedBarcode); // ✅ FULL PDF417 DATA
                print("🪪 DRIVER LICENSE RAW BARCODE ↑↑↑");
              }
              _ageVerificationActive = true;
              _scanLocked = true;

              // ⏳ Absorb trailing scanner frames
              await Future.delayed(const Duration(milliseconds: 1200));

              _ageVerificationActive = false;

              // 🔥 VERY IMPORTANT — STOP HERE
              return;
            }


            if (!isOrderInForeground ||
                trimmedBarcode.isEmpty ||
                _isLoading ||
                _isCustomItemLoading) return;

            _isLoading = true;
            if (mounted) setState(() {});

            final orderHelper = OrderHelper();
            final activeOrderId = orderHelper.activeOrderId;

            if (activeOrderId == null) {
              await OrderPopupHelper.showNoOrderPopup(context);
              return;
            }


            final productBox = Hive.box('productCache');
            final cacheKey = "sku_${trimmedBarcode.toLowerCase()}";

            SKU.ProductBySkuResponse? product;
            bool foundOffline = false;

            // ---------------------------------------------------------------------------
            // 1️⃣ MEMORY CACHE
            // ---------------------------------------------------------------------------
// 1️⃣ MEMORY CACHE
// ---------------------------------------------------------------------------
            try {
              final memoryData = OrderHelper.getFromCache(trimmedBarcode);

              if (memoryData != null) {
                if (kDebugMode) {
                  print("💾 MEMORY CACHE HIT");
                  print("💾 memoryData (raw) → $memoryData");
                  try {
                    print("💾 memoryData (json) → ${jsonEncode(memoryData)}");
                  } catch (_) {
                    print("💾 memoryData NOT JSON serializable");
                  }
                }

                Map<String, dynamic> productMap;

                // Case A → stored as {products:[{...}]}
                if (memoryData is Map &&
                    memoryData["products"] is List &&
                    memoryData["products"].isNotEmpty) {

                  productMap = Map<String, dynamic>.from(memoryData["products"][0]);

                  // 🔐 Restore meta_data safely
                  if (productMap["meta_data"] is List) {
                    productMap["meta_data"] =
                    List<Map<String, dynamic>>.from(productMap["meta_data"]);
                  }

                  // 🔐 Restore tags safely
                  if (productMap["tags"] is List) {
                    productMap["tags"] =
                    List<Map<String, dynamic>>.from(productMap["tags"]);
                  }
                }

                // Case B → stored as flat map
                else {
                  productMap = Map<String, dynamic>.from(memoryData);
                }

                if (kDebugMode) {
                  print("💾 Extracted productMap from memory → $productMap");
                  try {
                    print("💾 productMap JSON → ${jsonEncode(productMap)}");
                  } catch (_) {
                    print("💾 productMap not JSON encodable");
                  }
                  // ⭐⭐⭐ ADD THESE THREE ⭐⭐⭐
                  print("🖼 MEMORY productMap['images'] → ${productMap['images']}");

                  if (productMap['images'] is List && productMap['images'].isNotEmpty) {
                    print("🖼 MEMORY image src → ${productMap['images'][0]['src']}");
                  } else {
                    print("🖼 MEMORY image src → NONE");
                  }
                }

                product = SKU.ProductBySkuResponse.fromJson(productMap);
                foundOffline = true;

                if (kDebugMode) {
                  print("🧠 MEMORY → PRODUCT → name=${product?.name}, price=${product?.price}, sku=${product?.sku}");
                }
              }
            } catch (e, s) {
              print("❌ MEMORY CACHE ERROR → $e");
              print("📌 STACKTRACE → $s");
            }

// ---------------------------------------------------------------------------
// 2️⃣ PRODUCT CACHE (Custom Items + Normal SKU)
// ---------------------------------------------------------------------------
            try {
              if (product == null) {
                final cached = productBox.get(cacheKey);

                if (cached != null) {
                  if (kDebugMode) {
                    print("💽 HIVE productCache[$cacheKey] RAW → $cached");
                    try {
                      print("💽 HIVE JSON → ${jsonEncode(cached)}");
                    } catch (_) {
                      print("💽 HIVE map not JSON encodable");
                    }
                  }

                  List<dynamic> items = [];

                  if (cached is Map && cached["products"] is List) {
                    items = cached["products"];
                  }

                  if (items.isNotEmpty) {
                    final productMap = Map<String, dynamic>.from(items[0]);

                    if (kDebugMode) {
                      print("💽 Extracted productMap from Hive → $productMap");
                      try {
                        print("💽 productMap JSON → ${jsonEncode(productMap)}");
                      } catch (_) {
                        print("💽 productMap not JSON encodable");
                      }
                    }

                    product = SKU.ProductBySkuResponse.fromJson(productMap);
                    foundOffline = true;

                    if (kDebugMode) {
                      print("🟢 productCache → PRODUCT → name=${product?.name}, price=${product?.price}");
                    }
                  }
                }
              }
            } catch (e, s) {
              print("❌ PRODUCT CACHE ERROR → $e");
              print("📌 STACKTRACE → $s");
            }

            // ---------------------------------------------------------------------------
            // 3️⃣ CUSTOM ITEM → Increment quantity if already in order
            // ---------------------------------------------------------------------------
            try {
              final offlineBox = Hive.box('offlineOrders');
              final raw = offlineBox.get(activeOrderId.toString());

              if (raw != null) {
                List<Map<String, dynamic>> orderProducts =
                List<Map<String, dynamic>>.from(raw["products"] ?? []);

                final existingIndex = orderProducts
                    .indexWhere((p) => normalizeSku(p["sku"]) == trimmedBarcode);

                // 🚫 DO NOT AUTO-INCREMENT IF PRODUCT HAS VARIANTS
                if (existingIndex != -1 && (product?.variations?.isEmpty ?? true)) {
                  // Only non-variant products reach here
                  orderProducts[existingIndex]["quantity"] += 1;

                  await offlineBox.put(activeOrderId.toString(), {
                    ...raw,
                    "products": orderProducts,
                  });

                  await fetchOrderItems();
                  await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);

                  _isLoading = false;
                  if (mounted) setState(() {});
                  return;
                }

              }
            } catch (e) {
              print("⚠ Offline custom increment error: $e");
            }

            // ---------------------------------------------------------------------------
            // 4️⃣ FULL LIST CACHE
            // ---------------------------------------------------------------------------
            try {
              if (product == null) {
                final allData = productBox.get("all_products_list");

                if (allData is List) {
                  for (var item in allData) {
                    final p =
                    SKU.ProductBySkuResponse.fromJson({"products": [deepCast(item)]});
                    if ((p.sku ?? "").toLowerCase() == trimmedBarcode.toLowerCase()) {
                      product = p;
                      foundOffline = true;
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) print("⚠ full list error: $e");
            }

            // ---------------------------------------------------------------------------
            // 5️⃣ ONLINE API FETCH
            // ---------------------------------------------------------------------------
            if (product == null) {
              try {
                final products =
                await ProductRepository().fetchProductBySku(trimmedBarcode);

                if (products.isNotEmpty) {
                  product = products.first;

                  await productBox.put(cacheKey, {
                    "products": products.map((p) {
                      final map = p.toJson();

                      // 🔥 FIX: Persist tags
                      map["tags"] = p.tags?.map((t) => {
                        "id": t.id,
                        "name": t.name,
                        "slug": t.slug,
                      }).toList();

                      // 🔥 Also persist meta_data if present
                      map["meta_data"] = p.metaData?.map((m) => {
                        "key": m.key,
                        "value": m.value,
                      }).toList();

                      return map;
                    }).toList(),
                  });



                  if (kDebugMode) print("🌐 Online fetch → ${product?.name}");
                }
              } catch (e) {
                print("📴 API error: $e");
              }
            }

            // ---------------------------------------------------------------------------
            // 6️⃣ STILL NULL → CUSTOM ITEM POPUP
            // ---------------------------------------------------------------------------
            // 6️⃣ STILL NULL → CUSTOM ITEM POPUP
            if (product == null) {
              if (_scanLocked || _ageVerificationActive || isDriverLicense) {
                if (kDebugMode) {
                  print("🚫 Custom Item popup BLOCKED (DL / Age / Locked)");
                }

                _isLoading = false;
                if (mounted) setState(() {});
                return;
              }

              await _openCustomItemDialog(context, trimmedBarcode);
              return;
            }

            // ---------------------------------------------------------------------------
            // 7️⃣ EXTRACT PRODUCT DATA
            // ---------------------------------------------------------------------------
            final productId = product.id ?? -1;
            final productName = product.name ?? "Unnamed Product";
            final productSku = product.sku ?? trimmedBarcode;
            final productPrice =
                double.tryParse(product.price?.toString() ?? "0") ?? 0;

// 🖼 Image
            String image = "";
            if ((product.images ?? []).isNotEmpty) {
              image = product.images!.first.src ?? "";
            }

// 🧠 Metadata & Tags
            final metaData = product.metaData ?? [];
            final tags = product.tags ?? [];

            if (kDebugMode) {
              debugPrint("──────── PRODUCT DEBUG ────────");
              debugPrint("ID        : $productId");
              debugPrint("Name      : $productName");
              debugPrint("SKU       : $productSku");
              debugPrint("Price     : $productPrice");
              debugPrint("Image     : $image");

              // 🧠 META DATA
              if (metaData.isNotEmpty) {
                debugPrint("📦 META DATA:");
                for (final m in metaData) {
                  debugPrint("  • ${m.key} = ${m.value}");
                }
              } else {
                debugPrint("📦 META DATA: none");
              }

              // 🏷 TAGS
              if (tags.isNotEmpty) {
                debugPrint("🏷 TAGS:");
                for (final tag in tags) {
                  debugPrint("  • ${tag.name ?? tag.slug ?? tag.id}");
                }
              } else {
                debugPrint("🏷 TAGS: none");
              }

              debugPrint("──────────────────────────────");
            }
            // SKIP POPUP IF PRODUCT ALREADY EXISTS IN ORDERPANEL
// ------------------------------------------------------------
            final bool exists = OrderHelper.existsInOrderBySku(
              activeOrderId,
              productSku,
            );

            // 🔥 ONLY AUTO-INCREMENT NON-VARIANT PRODUCTS
            if (exists && (product.variations ?? []).isEmpty) {
              print("🔁 NON-VARIANT → Auto increment");

              await orderHelper.addItemToOrder(
                productId,
                productName,
                image,
                productPrice,
                1,
                productSku,
                activeOrderId,
                type: ItemType.product.value,
                productId: productId,
                variationId: -1,
              );



              await fetchOrderItems();
              await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);

              _isLoading = false;
              if (mounted) setState(() {});
              return; // 🚫 STOP HERE — POPUP NEVER OPENS
            }

            // VARIABLE PRICE PRODUCT CHECK
// ------------------------------------------------------------
            final hasVariablePriceTag = (product.tags ?? []).any((tag) {
              final name = (tag.name ?? "").toLowerCase();
              final slug = (tag.slug ?? "").toLowerCase();
              return name.contains("variable product") || slug.contains("variable-product");
            });

            print("🧪 hasVariablePriceTag = $hasVariablePriceTag");
            print("⏳ _isLoading before popup = $_isLoading");



// ------------------------------------------------------------
// ⭐ SHOW VARIABLE PRICE POPUP (ONLY FIRST TIME)
// ------------------------------------------------------------
            if (hasVariablePriceTag) {
              print("💡 Triggering ManualPriceDialog for variable product");

              try {
                final double? enteredPrice = await ManualPriceDialog.show(
                  context,
                  productName: productName,
                  productImage: image,
                  minPrice: productPrice,
                );


                print("💬 ManualPriceDialog returned → $enteredPrice");

                if (enteredPrice == null) {
                  print("❌ User cancelled ManualPriceDialog");
                  return;
                }

                print("✅ Adding variable product to order with price $enteredPrice");

                await orderHelper.addItemToOrder(
                  productId,
                  productName,
                  image,
                  enteredPrice,
                  1,
                  productSku,
                  activeOrderId,
                  type: ItemType.product.value,
                  productId: productId,
                  variationId: -1,
                );

                print("🛒 Product added to order");

                // / ⭐ FIX: MARK VARIABLE PRICE AS ALREADY ADDED
// ------------------------------------------------------------
                // ⭐ FIX: MARK VARIABLE PRICE AS ALREADY ADDED
                final box = Hive.box('offlineOrders');
                final orderKey = activeOrderId.toString();
                final hiveOrder = Map<String, dynamic>.from(
                  box.get(orderKey, defaultValue: {}),
                );

// Mark that popup has been shown once
                hiveOrder["variable_price_added_$productId"] = true;

// VERY IMPORTANT: Store the actual manual price user entered
                hiveOrder["selected_price_$productId"] = enteredPrice;

                await box.put(orderKey, hiveOrder);

                print("💾 FIX APPLIED → Variable price flags saved for scanned product");
                print("  → variable_price_added_$productId = true");
                print("  → selected_price_$productId = $enteredPrice");

                await fetchOrderItems();
                await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);

                print("📊 Customer display updated");

              } finally {
                _isLoading = false;
                if (mounted) setState(() {});
                print("⏳ _isLoading after popup = $_isLoading");
              }

              return; // STOP FURTHER EXECUTION
            }



// ------------------------------------------------------------
// ⭐ NORMAL PRODUCT FLOW
// ------------------------------------------------------------
            print("➡ Not a variable product, continuing normal flow");

            // ---------------------------------------------------------------------------
// ⭐ FINAL EBT ELIGIBILITY CHECK (NOW PRODUCT IS LOADED) ✅
// ---------------------------------------------------------------------------
            bool isEbtEligible = false;

            try {
              final tags = product?.tags ?? [];

              isEbtEligible = tags.any((t) {
                final name = (t.name ?? "").toLowerCase();
                final slug = (t.slug ?? "").toLowerCase();

                return name == "ebt" ||
                    name == "ebt eligible" ||
                    slug == "ebt" ||
                    slug == "ebt-eligible";
              });

              print("💳 FINAL EBT Eligible? → $isEbtEligible (via product.tags)");
            } catch (e) {
              print("⚠ EBT eligibility error → $e");
            }


            // ======================================================
// ⭐ AGE RESTRICTION CHECK — FINAL STABLE VERSION
// ======================================================

            if (kDebugMode) {
              print("\n---------------- AGE CHECK START ----------------");
              print("Product Scanned: ID=${product.id}, Name=${product.name}");
            }

// ------------------------------------------------------
// 1️⃣ INIT
// ------------------------------------------------------
            bool isRestricted = false;
            int minimumAge = 0;

// ------------------------------------------------------
// 2️⃣ CHECK PRODUCT METADATA
// ------------------------------------------------------
            for (final meta in (product.metaData ?? [])) {
              final key = (meta.key ?? "").toLowerCase().trim();
              final rawValue = (meta.value ?? "").toString().toLowerCase().trim();

              // Only process relevant keys
              if (!(key.contains("age") || key.contains("age_restricted"))) continue;

              // Case 1: Boolean restriction (true / yes / 1)
              if (rawValue == "true" || rawValue == "yes" || rawValue == "1") {
                isRestricted = true;
                continue;
              }

              // Case 2: Extract numeric age (18, 21, etc.)
              final match = RegExp(r'\d+').firstMatch(rawValue);
              if (match != null) {
                final parsedAge = int.tryParse(match.group(0)!);
                if (parsedAge != null && parsedAge > minimumAge) {
                  minimumAge = parsedAge;
                  isRestricted = true;
                }
              }
            }

// ------------------------------------------------------
// 3️⃣ CHECK PRODUCT TAGS (Backup Validation)
// ------------------------------------------------------
            for (final tag in (product.tags ?? [])) {
              final name = (tag.name ?? "").toLowerCase();
              final slug = (tag.slug ?? "").toLowerCase();

              if (name.contains("alcohol") || slug.contains("alcohol")) {
                isRestricted = true;
              }

              final hasAge =
                  name.contains("18+") ||
                      name.contains("21+") ||
                      name.contains("age") ||
                      slug.contains("18+") ||
                      slug.contains("21+") ||
                      slug.contains("age");

              if (hasAge) {
                final match = RegExp(r'\d+').firstMatch(name + slug);
                if (match != null) {
                  final parsedAge = int.tryParse(match.group(0)!);
                  if (parsedAge != null && parsedAge > minimumAge) {
                    minimumAge = parsedAge;
                    isRestricted = true;
                  }
                }
              }
            }

// ------------------------------------------------------
// 4️⃣ LOAD ORDER DATA (Hive)
// ------------------------------------------------------
            final hiveBox = Hive.box('offlineOrders');
            final orderKey = orderHelper.activeOrderId.toString();

// Ensure order exists
            if (!hiveBox.containsKey(orderKey)) {
              await hiveBox.put(orderKey, {
                "age_verified": false,
              });
            }

            final Map<String, dynamic> hiveOrder =
            Map<String, dynamic>.from(hiveBox.get(orderKey));

// ------------------------------------------------------
// 5️⃣ CHECK IF ALREADY VERIFIED
// ------------------------------------------------------
            final bool alreadyVerified =
                hiveOrder["age_verified"] == true ||
                    hiveOrder["age_verified"] == 1 ||
                    hiveOrder["age_verified"]?.toString().toLowerCase() == "true";

            if (kDebugMode) {
              print("Age restricted: $isRestricted");
              print("Minimum age   : $minimumAge");
              print("Already verified: $alreadyVerified");
            }

// ------------------------------------------------------
// 6️⃣ SHOW AGE VERIFICATION (ONCE)
// ------------------------------------------------------
            if (isRestricted && !alreadyVerified) {
              final verified = await AgeVerificationProvider()
                  .ageRestrictedProduct(context, product);

              if (!verified) {
                return; // stop item add
              }

              // Mark verified for this order
              hiveOrder["age_verified"] = true;
              await hiveBox.put(orderKey, hiveOrder);
            }


            if (kDebugMode) {
              print("---------------- AGE CHECK END ----------------\n");
            }

            // ---------------------------------------------------------------------------
            // 8️⃣ VARIATIONS FLOW
            // =====================================================================
            if ((product.variations ?? []).isNotEmpty) {

              // 1️⃣ Fetch variants
              productBloc.fetchProductVariations(product.id!);

              final response = await productBloc.variationStream
                  .firstWhere((r) => r.status == Status.COMPLETED);

              if (response.data == null || response.data!.isEmpty) return;

              final variants = response.data!.map((v) => {
                "id": v.id,
                "name": v.name,
                "price": v.price,
                "image": v.image?.src,
                "sku": v.sku,
              }).toList();

              // 2️⃣ SHOW VARIANT POPUP (ALWAYS)
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => VariantsDialog(
                  title: product?.name ?? "",
                  variations: variants,
                  onAddVariant: (selected, qty) async {
                    await orderHelper.addItemToOrder(
                      selected["id"],
                      selected["name"],
                      selected["image"],
                      double.tryParse(selected["price"].toString()) ?? 0,
                      qty,
                      selected["sku"],
                      activeOrderId,
                      productId: product?.id,
                      variationId: selected["id"],
                    );

                    Navigator.of(_).pop();
                  },
                ),
              );

              // 🔥 THIS LINE IS CRITICAL
              // ⛔ STOP EVERYTHING ELSE
              _isLoading = false;
              if (mounted) setState(() {});
              return;
            }

            // ---------------------------------------------------------------------------
            // 9️⃣ ADD ITEM TO ORDER
            // ---------------------------------------------------------------------------
            await orderHelper.addItemToOrder(
              productId,
              productName,
              image,
              productPrice,
              1,
              productSku,
              activeOrderId,
              type: ItemType.product.value,
              productId: productId,
              variationId: -1,
              isEbtEligible: isEbtEligible,
            );

            await fetchOrderItems();
            await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);

            _isLoading = false;
            if (mounted) setState(() {});
          } catch (e, s) {
            print("❌ Scan failed: $e\n$s");
            _isLoading = false;
            if (mounted) setState(() {});
          }

          finally {
            // 🔓 ALWAYS UNLOCK HERE
            await Future.delayed(const Duration(milliseconds: 800));
            _scanLocked = false;

            if (kDebugMode) {
              print("🔓 Scanner unlocked (finally)");
            }
          }
        },

        child: Stack(
          children: [
            // 🔹 Main Order Panel (Card + Tabs)
            Container(
              width: MediaQuery.of(context).size.width * 0.31,
              padding: const EdgeInsets.fromLTRB(2, 0, 10, 10),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.only(top: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      // 🔹 Tabs header
                      Container(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.primaryBackground
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 🔹 Tabs row
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _scrollController,
                                child: Row(
                                  children: List.generate(tabs.length, (index) {
                                    final bool isSelected = _tabController!.index == index;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _tabController!.index = index;
                                          });
                                        },
                                        child: Container(
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFFCDFDC)
                                                : (themeHelper.themeMode == ThemeMode.dark
                                                ? const Color(0xFF31354A)
                                                : const Color(0xFFEFEEEE)),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                tabs[index]["title"] as String,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFFFE6464)
                                                      : const Color(0xFF999393),
                                                  fontWeight:
                                                  isSelected ? FontWeight.bold : FontWeight.w500,
                                                  fontSize: isSelected ? 15 : 14,
                                                ),
                                              ),
                                              const SizedBox(width: 40),
                                              if (isSelected)
                                                GestureDetector(
                                                  onTap: () {
                                                    CustomDialog.showAreYouSure(context, confirm: () {
                                                      removeTab(index);
                                                    });
                                                  },
                                                  child: Image.asset(
                                                    "assets/deletecircle.png",
                                                    width: 20,
                                                    height: 20,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            // 🔹 New tab button
                            ElevatedButton(
                              onPressed: addNewTab,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.only(right: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Container(
                                width: 85,
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: themeHelper.themeMode == ThemeMode.dark
                                      ? const Color(0xFF000000)
                                      : const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFE6464),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? const Color(0xFF525252)
                                          : const Color(0xFFB2AFAF),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFFE6464),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Color(0xFFFE6464),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "New",
                                      style: TextStyle(
                                        color: Color(0xFFFE6464),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🔹 Content area
                      Expanded(child: buildCurrentOrder()),
                    ],
                  ),
                ),
              ),
            ),

            // 🔹 Empty Order Panel Overlay (when tabs list is empty)
            if (tabs.isEmpty)
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/scannerandsearch.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No items in the Order panel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? Colors.white
                              : const Color(0xFF373535),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Order panel is empty. Add items by scanning,\nsearching, or selecting from the list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? Colors.grey[400]
                              : Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  //Build #1.0.268: 5. (optional) to show logs on screen
  bool showLogs = false;
  Widget _showLogString(){
    return Container(
      width: MediaQuery.of(context).size.width * 0.30,
      color: const Color(0x7A000000),
      child:
      Stack(children: [
        Text(logString,style: TextStyle(color: Colors.white70),),
        Positioned(
            top: 2,
            right: 2,
            child: CloseButton(onPressed: (){
              showLogs = false;
              logString = "";
              setState(() {

              });
            },))
        ,
      ]),
    );
  }

//   Future<bool> _ageRestrictedProduct(SKU.ProductBySkuResponse product) async {
//     ///@
// //
// // ANSI 636026100102DL00410277ZA03180012DLDAQD05848559 DCSBELE SHRAVAN DDEN DACKUMAR DDFNvDADNONEaDDGNrDCAD DCBNONEtDCDNONEaDBD02052025gDBB07181978gDBA09032030 DBC1=DAU070 in DAYBROpDAG233 W FELLARS DRrDAIPHOENIXoDAJAZdDAK850237501  uDCF003402EB0B124005cDCGUSAtDCK48102972534.DDAFtDDB02282023aDDD1gDAZBLKsDAW196?DDK1
// //     ZAZAAN.ZACN
//
//     var isVerified = false;
//     var tagg = product.tags?.firstWhere((element) => element.name == "Age Restricted", orElse: () => SKU.Tags());
//     var hasAgeRestriction = tagg?.name?.contains("Age Restricted");
//
//     if (kDebugMode) {
//       print("Order Panel _ageRestrictedProduct hasAgeRestriction = $hasAgeRestriction");
//     }
//
//     if (hasAgeRestriction ?? false) {
//       var tag = product.tags?.firstWhere((element) => element.name == "Age Restricted", orElse: () => SKU.Tags());
//       if (kDebugMode) {
//         print("Order Panel _ageRestrictedProduct hasAgeRestriction tag = ${tag?.id}, ${tag?.name}, ${tag?.slug}");
//       }
//       if (tag?.slug == "") {
//         return isVerified;
//       }
//       await AgeVerificationHelper.showAgeVerification(
//         context: context,
//         // productName: product.name,
//         minimumAge: int.parse(tag?.slug ?? "0"),
//         onManualVerify: () {
//           // Add product to cart - manually verified
//           // _addToCart(product);
//           isVerified = true;
//         },
//         onAgeVerified: () {
//           // Add product to cart - age verified
//           // _addToCart(product);
//           isVerified = true;
//         },
//         onCancel: () {
//           // User cancelled - don't add to cart
//           isVerified = false;
//           Navigator.pop(context);
//         },
//       );
//     } else {
//       // No age restriction - add directly
//       // _addToCart(product);
//       isVerified = true;
//     }
//     return isVerified;
//   }

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
    if (response.status == Status.COMPLETED) {
      //Build #1.0.170: Updated - No need to make _isLoading is false here , we are doing after refresh!
      // setState(() => _isLoading = false); //Build #1.0.92
      if (Misc.showDebugSnackBar) { // Build #1.0.254
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("${isPayout ? 'Payout' : isCoupon ? 'Coupon' : isCustomItem ? 'Custom Item' : 'Item'} removed successfully"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await orderHelper.deleteItem(orderItem[AppDBConst.itemServerId]);
      await fetchOrderItems();
      widget.refreshOrderList?.call();
    } else if (response.status == Status.ERROR) {
      if (response.message!.contains('Unauthorised')) {
        if (kDebugMode) {
          print("categories screen 5 ---- Unauthorised : ${response.message!}");
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => LoginScreen()));

            if (kDebugMode) {
              print("message 5 --- ${response.message}");
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Unauthorised. Session is expired on this device."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
      else {
        setState(() => _isLoading = false); //Build #1.0.99 : hide loader
        _scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Failed to remove ${isPayout ? 'payout' : isCoupon
                ? 'coupon'
                : isCustomItem ? 'custom item' : 'item'}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        if (isPayout) {
          await CustomDialog.showDiscountNotApplied(
            context,
            errorMessageTitle: TextConstants.removePayoutFailed,
            errorMessageDes: response.message ??
                TextConstants.discountNotAppliedDescription,
            onRetry: retryCallback, // Pass retry callback
          );
        } else if (isCoupon) {
          await CustomDialog.showCouponNotApplied(
            context,
            errorMessageTitle: TextConstants.removeCouponFailed,
            errorMessageDes: response.message ??
                TextConstants.couponNotAppliedDescription,
            onRetry: retryCallback, // Pass retry callback
          );
        } else if (isCustomItem) {
          await CustomDialog.showCustomItemNotAdded(
            context,
            errorMessageTitle: TextConstants.removeCustomItemFailed,
            errorMessageDes: response.message ??
                TextConstants.customItemCouldNotBeAddedDescription,
            onRetry: retryCallback,
          );
        }
      }
    }
  }


  //Build #1.0.67
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
    //Build #1.0.99: Dismiss any open dialog
    Navigator.of(context, rootNavigator: true).pop();
  }

  //Build #1.0.67
  Future<void> _handleLocalDelete(Map<String, dynamic> orderItem, BuildContext context) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = false);
    await orderHelper.deleteItem(orderItem[AppDBConst.itemServerId]); //Build #1.0.92
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
  Future<void> removeTab(int index) async {
    if (tabs.isEmpty) {
      print("❌ removeTab called but tabs is empty");
      return;
    }

    final int orderId = tabs[index]["orderId"] as int;
    final bool isRemovedTabActive = orderId == orderHelper.activeOrderId;

    print("\n================= 🗑 REMOVE TAB START =================");
    print("👉 Removing Tab Index: $index");
    print("👉 Removing Order ID: $orderId");
    print("👉 Is Active Order Being Removed? $isRemovedTabActive");
    print("======================================================\n");

    setState(() => _isLoading = true);

    try {
      final offlineBox = Hive.box('offlineOrders');
      Box deletedBox;
      if (Hive.isBoxOpen('deletedOrders')) {
        deletedBox = Hive.box('deletedOrders');
        print("📦 deletedOrders box already open");
      } else {
        print("📦 deletedOrders was NOT open — opening now...");
        deletedBox = await Hive.openBox('deletedOrders');
        print("📦 deletedOrders box opened successfully");
      }


      print("📦 Offline Orders Box Contains ID? ${offlineBox.containsKey(orderId.toString())}");
      print("📦 Deleted Orders Box Ready: ${deletedBox != null}");

      final bool isOfflineOrder = offlineBox.containsKey(orderId.toString());
      if (isOfflineOrder) {
        print("\n🟡 OFFLINE ORDER DETECTED — Performing Offline Delete Flow");
        await OrderRepository().saveOfflineOrderTotals(orderId);

        // ⭐ 1️⃣ READ ORDER DATA BEFORE DELETE
        final orderData = offlineBox.get(orderId.toString());
        print("📤 Original Offline Order Data:\n$orderData");

        if (orderData == null) {
          print("⚠️ orderData is NULL — cannot sync or backup!");
          return;
        }

        // ⭐ 2️⃣ Sync attempt BEFORE deleting locally
        print("🌐 Attempting to sync deleted offline order to backend…");

        final result = await OrderRepository().syncOfflineDeletedOrders([orderData]);
        final bool syncSuccess = result["success"] == true;
        final int? syncedWooId = result["wooOrderId"];

// ******************************************************************
// 🔥 ALWAYS SAVE CASHBACK + TAX + WOO ORDER ID IN orderExtras BOX
// ******************************************************************
        final extrasBox = Hive.box("orderExtras");

// 1️⃣ Resolve Woo Order ID correctly (supports all key formats)
        // if server returned Woo Order ID → use it
        final wooOrderId = (syncedWooId ??
            orderData["woo_order_id"] ??
            orderData["wooOrderId"] ??
            orderId).toString();


// 2️⃣ Resolve Cashback Fee from ALL possible key names
        final cashbackFee = (
            orderData["cashbackFee"] ??
                orderData["order_cashback_fee"] ??
                orderData["cashback_fee"] ??
                orderData["cashbackFeeTotal"] ??
                orderData["cashback"] ??
                0
        ).toDouble();

// 3️⃣ Resolve Tax (all supported variations)
        final tax = (
            orderData["tax"] ??
                orderData["wooTax"] ??
                orderData["order_tax"] ??
                orderData["totalTax"] ??
                0
        ).toDouble();

// 4️⃣ Save final extras
        await extrasBox.put(wooOrderId, {
          "woo_order_id": wooOrderId,
          "local_offline_id": orderId,
          "cashback_fee": cashbackFee,
          "tax": tax,
          "synced": syncSuccess,
          "saved_at": DateTime.now().toIso8601String(),
        });

        print("💾 SAVED TO orderExtras BOX:");
        print("   WooID: $wooOrderId");
        print("   Cashback Fee: $cashbackFee");
        print("   Tax: $tax");
        print("   Synced: $syncSuccess");
        print("📦 Current orderExtras: ${extrasBox.get(wooOrderId)}");
// ******************************************************************


        if (syncSuccess) {
          print("✅ Deleted order synced successfully → No Hive backup needed");

          await offlineBox.delete(orderId.toString());
          await orderHelper.deleteOrder(orderId);

          // UI cleanup
          setState(() {
            tabs.removeAt(index);
            if (tabs.isEmpty) {
              orderHelper.activeOrderId = null;
              orderItems = [];
            }
          });

          setState(() => _isLoading = false);
          return;
        }

        // ❌ Sync failed → store in deletedOrders
        print("⚠️ Sync FAILED → Storing in deletedOrders Hive box...");

        final userData = await UserDbHelper().getUserData();
        final currentUserId = userData?[AppDBConst.userId];
        final currentUserName = userData?[AppDBConst.username] ?? "";
        final currentShiftId = await UserDbHelper().getUserShiftId();

        final enhancedDeletedOrder = {
          ...orderData,
          "deleted_order_id": orderId,
          "client_order_id": orderId.toString(),
          "deleted_by_user_id": currentUserId,
          "deleted_by_user_name": currentUserName,
          "deleted_shift_id": currentShiftId,
          "deleted_at": DateTime.now().toIso8601String(),
        };
        await deletedBox.put(orderId.toString(), enhancedDeletedOrder);

        // Delete from offline and UI cleanup
        await offlineBox.delete(orderId.toString());
        await orderHelper.deleteOrder(orderId);

        orderHelper.orders.removeWhere((o) =>
        o[AppDBConst.orderServerId] == orderId ||
            o[AppDBConst.orderId] == orderId);
        orderHelper.orderIds.remove(orderId);

        setState(() {
          tabs.removeAt(index);
          for (int i = 0; i < tabs.length; i++) {
            tabs[i]["subtitle"] = "Tab ${i + 1}";
          }
        });

        if (tabs.isEmpty) {
          orderHelper.activeOrderId = null;
          orderItems = [];
          await _initializeTabController();
          setState(() => _isLoading = false);
          return;
        }

        final int newIndex =
        index >= tabs.length ? tabs.length - 1 : index;
        final int newActiveOrderId =
        tabs[newIndex]["orderId"] as int;

        if (isRemovedTabActive) {
          await orderHelper.setActiveOrder(newActiveOrderId);
          await orderHelper.saveLastActiveOrderId(newActiveOrderId);
        }

        await _initializeTabController();
        await fetchOrderItems();

        _tabController!.index = newIndex;

        setState(() => _isLoading = false);
        return;
      }


      // ============================================================
      // ===============  ONLINE ORDER DELETE AREA  ================
      // ============================================================

      print("\n🔵 ONLINE ORDER DETECTED — Calling API to cancel order…");

      final int serverOrderId = orderId;

      _updateOrderSubscription?.cancel();
      _updateOrderSubscription =
          orderBloc.changeOrderStatusStream.listen((response) async {
            if (!mounted) return;

            print("🌐 Server Cancel Status: ${response.status}");

            if (response.status == Status.COMPLETED) {
              print("✅ Server confirmed order cancellation");

              await orderHelper.deleteOrder(orderId);
              orderHelper.cancelledOrderId = serverOrderId;

              print("🧹 Removing order tab from UI…");
              setState(() {
                tabs.removeAt(index);
                for (int i = 0; i < tabs.length; i++) {
                  tabs[i]["subtitle"] = "Tab ${i + 1}";
                }
              });

              if (tabs.isEmpty) {
                print("❗ All tabs closed after delete");
                orderHelper.activeOrderId = null;
                orderItems = [];
                await _initializeTabController();
                setState(() => _isLoading = false);
                return;
              }

              final int newIndex = index >= tabs.length ? tabs.length - 1 : index;
              final int newActiveOrderId = tabs[newIndex]["orderId"] as int;

              print("🔄 New active tab index: $newIndex, OrderId: $newActiveOrderId");

              if (isRemovedTabActive) {
                print("🔄 Updating active order due to removal");
                await orderHelper.setActiveOrder(newActiveOrderId);
                await orderHelper.saveLastActiveOrderId(newActiveOrderId);
              }

              print("🔧 Reinitializing tab controller…");
              await _initializeTabController();

              if (offlineBox.containsKey(newActiveOrderId.toString())) {
                print("📥 Loading offline items for new order");
                await fetchOrderItems();
              } else {
                print("⚠️ No offline items found for this order");
                setState(() => orderItems = []);
              }

              _tabController!.index = newIndex;

              print("================= 🗑 REMOVE TAB END (ONLINE) ================\n");

              setState(() => _isLoading = false);
            }
          });

      print("🌐 Sending cancel order request to server…");
      await orderBloc.changeOrderStatus(
        orderId: serverOrderId,
        status: TextConstants.cancelled,
      );
    } catch (e) {
      print("❌ ERROR in removeTab(): $e");
      setState(() => _isLoading = false);
    }
  }

  double getProductDiscountFromHive(int productId, int qty) {
    try {
      final box = Hive.box('productCache');

      for (var key in box.keys) {
        if (!key.toString().startsWith("products_")) continue;

        final cached = box.get(key);
        if (cached == null) continue;

        final List products = json.decode(cached['data']);

        final product = products.firstWhere(
              (p) => p['fast_key_product_id'] == productId ||
              p['id'] == productId,
          orElse: () => null,
        );

        if (product == null) continue;

        final bool enabled = product['auto_discount_enabled'] == true;
        final double discount =
            double.tryParse(product['discount_amount']?.toString() ?? '0') ?? 0.0;

        if (!enabled || discount <= 0) return 0.0;

        final totalDiscount = discount * qty;

        print("💸 PRODUCT DISCOUNT → ID:$productId | ₹$discount × $qty = ₹$totalDiscount");

        return totalDiscount;
      }
    } catch (e) {
      print("❌ Discount error → $e");
    }

    return 0.0;
  }


  int totalItems = 0;
  Future<void> deleteOfflineItem(Map<String, dynamic> orderItem) async {
    if (orderHelper.activeOrderId == null) return;

    final offlineBox = Hive.box('offlineOrders');
    final String orderKey = orderHelper.activeOrderId.toString();
    final rawOfflineOrder = offlineBox.get(orderKey);

    if (rawOfflineOrder == null) return;

    final Map<String, dynamic> offlineOrder =
    Map<String, dynamic>.from(rawOfflineOrder);

    // ============================
    // 🛑 CHECK: LAST ITEM + MERCHANT DISCOUNT
    // ============================

    // ============================
// 🛑 CHECK: MERCHANT DISCOUNT & NEGATIVE TOTAL PREVENTION
// ============================

    final double merchantDiscount = (offlineOrder['merchantDiscount'] is num)
        ? (offlineOrder['merchantDiscount'] as num).toDouble()
        : 0.0;

// If no discount → allow delete
    if (merchantDiscount > 0) {

      // 1️⃣ Calculate current total amount
      double productsTotal = ((offlineOrder['products'] as List?) ?? [])
          .fold(0.0, (sum, p) => sum + (double.tryParse(p['price']?.toString() ?? '0') ?? 0));

      double payoutsTotal = ((offlineOrder['payouts'] as List?) ?? [])
          .fold(0.0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));

      double cashbacksTotal = ((offlineOrder['cashbacks'] as List?) ?? [])
          .fold(0.0, (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0));

      double currentTotal = productsTotal + payoutsTotal + cashbacksTotal;

      // 2️⃣ Get price of the item being deleted
      double itemPrice =
          double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;

      // 3️⃣ New total after deletion
      double newTotal = currentTotal - itemPrice;

      // 4️⃣ Check if discount is greater than new total
      if (newTotal < merchantDiscount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Merchant discount exists. Deleting this item will make the order total negative. Please remove discount first.",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return; // ⛔ STOP DELETE
      }
    }

    // ============================
    // CONTINUE WITH NORMAL DELETE LOGIC
    // ============================

    // 🔍 Detect type: product / payout / cashback
    final String itemType =
    (orderItem['item_type'] ?? '').toString().toLowerCase();

    final List<Map<String, dynamic>> products =
        (offlineOrder['products'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
            [];

    final List<Map<String, dynamic>> payouts =
        (offlineOrder['payouts'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
            [];

    final List<Map<String, dynamic>> cashbacks =
        (offlineOrder['cashbacks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
            [];

    // 🟦 DELETE PAYOUT
    if (itemType == 'payout') {
      payouts.removeWhere((p) {
        final amt1 = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        final amt2 =
            double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;
        return amt1 == amt2;
      });
      offlineOrder['payouts'] = payouts;
    }

    // 🟩 DELETE CASHBACK
    else if (itemType == 'cashback') {
      cashbacks.removeWhere((cb) {
        final amt1 = double.tryParse(cb['amount']?.toString() ?? '0') ?? 0;
        final amt2 =
            double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;
        return amt1 == amt2;
      });
      offlineOrder['cashbacks'] = cashbacks;
    }

    // 🛒 DELETE PRODUCT
    // 🛒 DELETE PRODUCT
    else {
      int deletedProductId = -1;
      String matchedSku = ""; // ⭐ Add this

      products.removeWhere((p) {
        final name1 = (p['name'] ??
            p['product_name'] ??
            p['fast_key_item_name'] ??
            '')
            .toString()
            .toLowerCase();

        final name2 = (orderItem['item_name'] ?? '').toString().toLowerCase();

        final price1 = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        final price2 = double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;

        final match = name1 == name2 && price1 == price2;

        if (match) {
          // Capture product_id
          deletedProductId =
              p['product_id'] ??
                  p['id'] ??
                  p['fast_key_product_id'] ??
                  p['serverItemId'] ??
                  -1;

          // ⭐ Capture SKU BEFORE removing product
          matchedSku = (p['sku'] ??
              p['item_sku'] ??
              p['product_sku'] ??
              p['fast_key_item_sku'] ??
              '')
              .toString()
              .toLowerCase()
              .trim();
        }

        return match; // Now remove the product
      });

      offlineOrder['products'] = products;

      // -------------------------------
      // RESET VARIABLE PRICE FLAGS
      // -------------------------------
      if (deletedProductId != -1) {
        offlineOrder.remove("variable_price_added_$deletedProductId");
        offlineOrder.remove("selected_price_$deletedProductId");

        print("🧹 Cleared variable price flags for product → $deletedProductId");
      } else {
        print("⚠️ Could not determine product_id for cleanup.");
      }

      // ---------------------------------
      // CLEAN MEMORY & HIVE SKU CACHE
      // ---------------------------------
      if (matchedSku.isNotEmpty) {
        print("🔍 Cleaning caches for SKU → $matchedSku");

        try {
          OrderHelper.removeFromCache(matchedSku);
          print("🧠 In-memory product cache cleared → $matchedSku");
        } catch (e) {
          print("⚠️ Memory cache cleanup failed → $e");
        }

        try {
          final productBox = Hive.box('productCache');
          final cacheKey = "sku_$matchedSku";

          if (productBox.containsKey(cacheKey)) {
            await productBox.delete(cacheKey);
            print("💽 HIVE productCache cleared → $cacheKey");
          } else {
            print("💽 No Hive cache entry found for $cacheKey");
          }
        } catch (e) {
          print("⚠️ Hive cache cleanup failed → $e");
        }
      } else {
        print("⚠️ SKU could not be extracted → Cannot clean cache.");
      }
    }

    // 💾 Save updated order back to Hive
    await offlineBox.put(orderKey, offlineOrder);

    await CustomerDisplayHelper.updateCustomerDisplay(
        orderHelper.activeOrderId!);

    // 🔁 Refresh UI
    setState(() {
      orderItems.remove(orderItem);
    });
  }


  double getCustomItemTax({
    required String taxClass,
    required double price,
    required int qty,
    required List<Tax> taxes,
  }) {
    try {
      // Find tax rate from your local tax list
      final selected = taxes.firstWhere(
            (t) => t.slug == taxClass,
        orElse: () => Tax(slug: "", name: ""),
      );

      if (selected.slug.isEmpty) {
        print("⚠ No tax class match → tax = 0.0");
        return 0.0;
      }

      // Example: "gst_18" → extract "18"
      final rateString = selected.slug.replaceAll(RegExp(r'[^0-9]'), "");
      final rate = double.tryParse(rateString) ?? 0.0;

      final taxAmount = ((price * rate) / 100) * qty;

      print("🔥 Custom Item Tax:");
      print("   price: $price, qty: $qty, rate: $rate%, tax: $taxAmount");

      return taxAmount;
    } catch (e) {
      print("❌ ERROR in getCustomItemTax → $e");
      return 0.0;
    }
  }

  double getProductTaxFromHive(
      int productId,
      double price,
      int qty,
      ) {
    try {
      final box = Hive.box('productCache');

      // 🔹 get auto discount FIRST
      final double autoDiscount = getProductDiscountFromHive(productId, qty);

      final double originalTotal = price * qty;

      // ✅ discounted base (never negative)
      final double taxableBase =
      (originalTotal - autoDiscount).clamp(0.0, double.infinity);

      for (var key in box.keys) {
        if (!key.toString().startsWith("products_")) continue;

        final cached = box.get(key);
        if (cached == null) continue;

        final List products = json.decode(cached['data']);

        final product = products.firstWhere(
              (p) => p['id'] == productId,
          orElse: () => null,
        );

        if (product == null) continue;

        if (product['tax'] != null &&
            product['tax']['tax_rates'] is List &&
            product['tax']['tax_rates'].isNotEmpty) {

          double taxTotal = 0.0;

          for (final tax in product['tax']['tax_rates']) {
            final rate =
                double.tryParse(tax['rate']?.toString() ?? '0') ?? 0.0;

            final taxAmount = (taxableBase * rate) / 100;

            taxTotal += double.parse(taxAmount.toStringAsFixed(2));
          }

          return taxTotal;
        }
      }
    } catch (e) {
      print("❌ Tax error (discounted base) → $e");
    }

    return 0.0;
  }



// Current Order UI
  Widget buildCurrentOrder() {
    final theme = Theme.of(context); // Build #1.0.6 - added theme for order panel
    bool isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (kDebugMode) {
      print("keyBoard visible : $isKeyboardVisible");
    }
    if(_isLoading == true){
      if (kDebugMode) {
        print("###### buildCurrentOrder: _isLoading: $_isLoading");
      }
    }
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // ADD THIS: Create a ScrollController for the scrollbar
    final ScrollController scrollController = ScrollController();
    if (kDebugMode) {
      print("Building Current Order Widget _isLoading: $_isLoading and orderHelper.activeOrderId : ${orderHelper.activeOrderId}");
    } // Debug print
    // Fetch discount and tax for the active order
    double orderDiscount = 0.0;
    double merchantDiscount = 0.0;
    double autoProductDiscount = 0.0;
    double orderTax = 0.0;
    num grossTotal = 0.0;
    // Get Items Gross Total
    num netTotal = 0.0;
    num netPayable = 0.0;  //Build #1.0.67

    // Initialize display date and time variables
    DateTime now = DateTime.now();
    String formattedDate = DateFormat(TextConstants.dateFormat).format(now);
    String formattedTime = DateFormat(TextConstants.timeFormat).format(now);
    String displayDate = formattedDate;
    String displayTime = formattedTime;

    if (kDebugMode) {
      print("display date === $displayDate");
    }
    if (kDebugMode) {
      print("display time === $displayTime");
    }

    if (orderHelper.activeOrderId != null) {
      final offlineBox = Hive.box('offlineOrders');
      final rawOfflineOrder = offlineBox.get(orderHelper.activeOrderId.toString());

      if (rawOfflineOrder != null) {
        if (kDebugMode) {
          print("📦 Detected offline order (${orderHelper.activeOrderId})");
        }

        final Map<String, dynamic> offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);

        // / ⭐ OPTIONAL: auto-remove cashback if amount is 0
        if (offlineOrder['cashbacks'] != null &&
            offlineOrder['cashbacks'] is List &&
            (offlineOrder['cashbacks'] as List).isNotEmpty) {

          final firstCashback = offlineOrder['cashbacks'][0];
          final cashbackAmount =
              double.tryParse(firstCashback['amount']?.toString() ?? '0') ?? 0.0;

          if (cashbackAmount == 0) {
            if (kDebugMode) {
              print("🧹 Auto-removing cashback because amount is 0");
            }
            offlineOrder['cashbacks'] = [];
            offlineOrder['cashbackFee'] = 0.0;
          }
        }

        // 🛍️ Load products
        final offlineProducts = ((offlineOrder['products'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // 🧾 Load payouts
        final offlinePayouts = ((offlineOrder['payouts'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // 💰 Load cashback
        final offlineCashback = ((offlineOrder['cashbacks'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        cashbackFee = (offlineOrder['cashbackFee'] is num)
            ? (offlineOrder['cashbackFee'] as num).toDouble()
            : 0.0;

// If no cashback entries, force fee to 0
        if (offlineCashback.isEmpty) {
          cashbackFee = 0.0;
        }

        // final productBox = Hive.box('productCache');
        // final cashbackProduct = productBox.values.firstWhere(
        //       (p) =>
        //   p['title']?.toString().toLowerCase().contains('cashback') == true ||
        //       p['name']?.toString().toLowerCase().contains('cashback') == true,
        //   orElse: () => null,
        // );
        //
        //
        //
        // final cashbackImageUrl = cashbackProduct?['image'] ?? '';


        // 🧾 Combine for UI
        orderItems = [
          // ---------------------- Products ----------------------
          ...offlineProducts.map((item) {
            final itemType =
            (item['item_type'] ?? item['type'] ?? '')
                .toString()
                .toLowerCase();

            final isCustom   = itemType.contains("custom");
            final isPayout   = itemType.contains("payout");
            final isCashback = itemType.contains("cashback");
            final isCoupon   = itemType.contains("coupon");

            // ---------------- CUSTOM / NON-PRODUCT ITEMS ----------------
            if (isCustom || isPayout || isCashback || isCoupon) {
              final name = item['name'] ??
                  item['custom_item_name'] ??
                  item['item_name'] ??
                  "Item";

              final price = double.tryParse(
                  item['price']?.toString() ??
                      item['amount']?.toString() ??
                      item['custom_item_price']?.toString() ??
                      "0"
              ) ?? 0.0;

              final qty = int.tryParse(
                  item['quantity']?.toString() ??
                      item['items_count']?.toString() ??
                      "1"
              ) ?? 1;

              return {
                'item_name': name,
                'item_price': price,
                'items_count': qty,
                'item_sum_price': price * qty,
                'item_image': item['image'] ?? "",
                'item_type': itemType,
                'item_tax': 0.0,
              };
            }

            // ---------------- REAL PRODUCTS ONLY ----------------
            final qty =
                int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

            final price =
                double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;

            double itemTax = 0.0;
            double itemDiscount = 0.0;

            final String productIdStr =
                (item['product_id'] ?? item['id'])?.toString() ?? '';

            final int productId =
                int.tryParse(productIdStr) ?? 0;

            itemTax = getProductTaxFromHive(productId, price, qty);
            itemDiscount = getProductDiscountFromHive(productId, qty);

            item['auto_discount_per_unit'] =
            qty > 0 ? itemDiscount / qty : 0.0;
            item['auto_discount_total'] = itemDiscount;

            orderTax += itemTax;
            autoProductDiscount += itemDiscount;

            print("🧾 ORDER PANEL ITEM → "
                "Name: ${item['name']} | "
                "Qty: $qty | "
                "Price: $price | "
                "EBT: ${item['is_ebt_eligible']}");

            return {
              'item_name': item['name'] ?? item['product_name'] ?? '',
              'item_price': price,
              'items_count': qty,
              'item_sum_price': price * qty,
              'item_image': item['image'] ?? '',
              'item_type': itemType,
              'item_tax': itemTax,
              'is_ebt_eligible': item['is_ebt_eligible'] == true,
              'auto_discount': itemDiscount,
              'original_total': price * qty,
            };
          }),


          // ---------------------- Payouts ----------------------
          ...offlinePayouts.map((payout) {
            final price = double.tryParse(payout['amount']?.toString() ?? '0') ?? 0.0;

            return {
              'item_name': 'Payout',
              'item_price': price,
              'items_count': 1,
              'item_sum_price': price,
              'item_image': 'assets/svg/payout.svg',
              'item_type': 'payout',
              'item_tax': 0.0,
            };
          }),

          // ---------------------- Cashback ----------------------
          ...offlineCashback.map((cash) {
            final price = double.tryParse(cash['amount']?.toString() ?? '0') ?? 0.0;

            return {
              'item_name': 'Cashback',
              'item_price': price,
              'items_count': 1,
              'item_sum_price': price,
              'item_image': cash['product_image'] ??
                  cash['item_image'] ??
                  cash['image'] ??
                  "",
              'item_type': 'cashback',
              'item_tax': 0.0,
            };
          }),
        ];

        totalItems = offlineProducts.fold(0, (sum, product) {
          final qty = int.tryParse(product['quantity']?.toString() ?? '1') ?? 1;
          return sum + qty;
        });

        double productTotal = 0.0;

        for (final item in offlineProducts) {
          final itemType =
          (item['item_type'] ?? item['type'] ?? '')
              .toString()
              .toLowerCase();

          final bool isCustom = itemType.contains("custom");

          final qty =
              int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

          final price =
              double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;

          double itemDiscount = 0.0;

          // 🔐 Only real products have product_id
          if (!isCustom) {
            final String productIdStr =
                (item['product_id'] ?? item['id'])?.toString() ?? '';

            final int productId =
                int.tryParse(productIdStr) ?? 0;

            itemDiscount = getProductDiscountFromHive(productId, qty);
          }

          productTotal += (price * qty) - itemDiscount;
        }


        double payoutTotal = offlinePayouts.fold<double>(0, (sum, payout) {
          return sum + (double.tryParse(payout['amount']?.toString() ?? '0') ?? 0.0);
        });
        double cashbackTotal = offlineCashback.fold(0, (sum, cash) {
          return sum + (double.tryParse(cash['amount']?.toString() ?? '0') ?? 0.0);
        });

        grossTotal = productTotal + payoutTotal+ cashbackTotal;

        orderDiscount = (offlineOrder['orderDiscount'] is num)
            ? (offlineOrder['orderDiscount'] as num).toDouble()
            : 0.0;

        merchantDiscount = (offlineOrder['merchantDiscount'] is num)
            ? (offlineOrder['merchantDiscount'] as num).toDouble()
            : 0.0;

        final isPercentageDiscount = (offlineOrder['merchantDiscountIsPercentage'] as bool?) ?? false;
        print("🔥 FINAL orderTax CALCULATED from Hive products = $orderTax");

        netTotal = grossTotal - orderDiscount - merchantDiscount;
        netPayable = netTotal + orderTax + cashbackFee;

        if (orderHelper.activeOrderId != null) {
          final updatedOrder = Map<String, dynamic>.from(rawOfflineOrder);
          updatedOrder['gross_total'] = grossTotal;
          updatedOrder['orderDiscount'] = orderDiscount;
          updatedOrder['merchantDiscount'] = merchantDiscount;
          updatedOrder['cashbackFee'] = cashbackFee;
          // updatedOrder['orderCashbackFee'] = cashbackFee;

          updatedOrder['order_tax'] = orderTax;
          updatedOrder['net_total'] = netTotal;
          updatedOrder['net_payable'] = netPayable;
          updatedOrder['autoProductDiscount'] = autoProductDiscount;


          offlineBox.put(orderHelper.activeOrderId.toString(), updatedOrder);
          print("💾 Saved latest totals into offlineOrders Hive");
        }



        // 🔹 Format date/time
        if (offlineOrder['created_at'] != null) {
          try {
            final createdAt = DateTime.parse(offlineOrder['created_at']);
            displayDate = DateFormat(TextConstants.dateFormat).format(createdAt);
            displayTime = DateFormat(TextConstants.timeFormat).format(createdAt);
          } catch (e) {
            if (kDebugMode) print("⚠️ Failed to parse offline order date: $e");
          }
        }


        if (kDebugMode) {
          print("💾 Offline Order Calculation:");
          print("   productTotal: $productTotal");
          print("   payoutTotal: $payoutTotal");
          print("cashbackTotal: $cashbackTotal");
          print("   grossTotal: $grossTotal");
          print("   merchantDiscount: $merchantDiscount (${isPercentageDiscount ? 'Percentage' : 'Fixed'})");
          print("   netTotal: $netTotal");
          print("   netPayable: $netPayable");
          print("🧾 Offline items for UI → ${jsonEncode(orderItems)}");
        }

        setState(() {}); // Refresh UI
      }
    }

    if (kDebugMode) {
      print("✅ Final Totals → gross: $grossTotal, discount: $orderDiscount, tax: $orderTax, net: $netTotal, payable: $netPayable");
    }

    if (kDebugMode) {
      print("#### ACTIVE ORDER ID: ${orderHelper.activeOrderId}");
      print("#### orderItems: $orderItems");
      print("#### grossTotal: $grossTotal");
      print("#### orderDiscount: $orderDiscount");
      print("#### merchantDiscount: $merchantDiscount");
      print("#### orderTax: $orderTax");
      print("#### netTotal: $netTotal");
      print("#### netPayable: $netPayable");
    }


    return Stack(
      children: [
        Column(
          children: [
            Container(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.primaryBackground
                  : null,
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔹 TOP TEXT
                  if (orderHelper.activeOrderId != null)
                    Text(
                      "All updated discounts will be reflected after checkout.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF1878DE),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 6),

                  // 🔹 BOTTOM ROW (DATE LEFT, TIME RIGHT)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      // 📅 DATE (LEFT)
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/svg/calendar.svg',
                            width: 20,
                            height: 20,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayDate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),

                      // ⏰ TIME (RIGHT)
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/svg/clock.svg',
                            width: 20,
                            height: 20,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayTime,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if(tabs.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: DottedLine(
                  dashLength: 4,
                  dashGapLength: 4,
                  lineThickness: 1,
                  dashColor: theme.secondaryHeaderColor,
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: (orderItems.isEmpty)
                  ? Container() ///Add your widget if needed to show empty tab contents
                  : Container(
                color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
                child: Padding(
                  padding: const EdgeInsets.only(left:0, right: 0),
                  child: Scrollbar(
                    controller: scrollController,
                    scrollbarOrientation: ScrollbarOrientation.right,
                    thumbVisibility: true,
                    thickness: 8.0,
                    interactive: false,
                    radius: const Radius.circular(8),
                    trackVisibility: true,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        if (kDebugMode) {
                          print("Reordering item from $oldIndex to $newIndex");
                        } // Debug print
                        if (oldIndex < newIndex) newIndex -= 1;

                        setState(() {
                          final movedItem = orderItems.removeAt(oldIndex);
                          orderItems.insert(newIndex, movedItem);
                        });
                      },
                      scrollController: scrollController,
                      itemCount: orderItems.length,
                      proxyDecorator: (Widget child, int index, Animation<double> animation) {
                        return Material(
                          color: Colors.transparent,// Removes white background
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final orderItem = orderItems[index];
                        if (kDebugMode) {
                          print("@@@@@@@@@@@@@@@@@ orderItem Data : $orderItem");
                        }
                        ///Build #1.0.64:  added conditions
                        /// Compare item type
                        /// if it is payout change icon, name is empty, show amount in red colour
                        /// if it is coupon change icon, name is coupon code (show last 4 digits, prefix with 'X' for each character before last 4), show amount in red colour
                        final itemType = orderItem[AppDBConst.itemType]?.toString().toLowerCase() ?? '';

                        final bool isVariant =
                            (orderItem['is_variant'] == true) ||
                                (itemType == 'variant');

                        /// Check if the item is a payout or a coupon
                        final isCashback = itemType.contains("cashback");
                        final isPayout = itemType.contains(TextConstants.payoutText);
                        final isCoupon = itemType.contains(TextConstants.couponText);
                        final isCustomItem = itemType.contains(TextConstants.customItemText);
                        final isPayoutOrCouponOrCustomItem = isPayout || isCoupon || isCustomItem;
                        final isCouponOrPayout = isPayout || isCoupon|| isCashback;
                        /// Get the original name
                        final originalName = orderItem[AppDBConst.itemName]?.toString() ?? '';
                        final variationName = orderItem[AppDBConst.itemVariationCustomName]?.toString() ?? 'N/A';
                        final variationCount = orderItem[AppDBConst.itemVariationCount] ?? 0;
                        final combo = orderItem[AppDBConst.itemCombo] ?? '';
                        if (kDebugMode) {
                          print("#### originalName: $originalName, itemType: $itemType, isPayoutOrCouponOrCustomItem: $isPayoutOrCouponOrCustomItem");
                          print("#### variationName: $variationName, variationCount: $variationCount");
                          print("#### isCouponOrPayout: $isCouponOrPayout"); // Build #1.0.181: Debug print
                        }
                        /// Set display name based on item type
                        String displayName = originalName;


                        if (isPayout) {
                          displayName = 'Payout';
                        } else if (isCashback) {
                          displayName = 'Cashback';
                        } else if (isCoupon) {
                          // masking logic for coupon
                          final visiblePartLength = 4;
                          final nameLength = originalName.length;
                          if (nameLength > visiblePartLength) {
                            final maskedLength = nameLength - visiblePartLength;
                            final maskedPart = 'X' * maskedLength;
                            final visiblePart = originalName.substring(nameLength - visiblePartLength);
                            displayName = '$maskedPart$visiblePart';
                          }
                        }


                        /// Build #1.0.134: Item Price will check sales price if it is null/empty, check regular price else unit price
                        final salesPrice =
                        (orderItem[AppDBConst.itemSalesPrice] == null || (orderItem[AppDBConst.itemSalesPrice]?.toDouble() ?? 0.0) == 0.0)
                            ? (orderItem[AppDBConst.itemRegularPrice] == null || (orderItem[AppDBConst.itemRegularPrice]?.toDouble() ?? 0.0) == 0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]?.toDouble() ?? 0.0
                            : orderItem[AppDBConst.itemRegularPrice]!.toDouble()
                            : orderItem[AppDBConst.itemSalesPrice]!.toDouble();

                        final regularPrice =  (orderItem[AppDBConst.itemRegularPrice] == null || (orderItem[AppDBConst.itemRegularPrice]?.toDouble() ?? 0.0) == 0.0)
                            ? orderItem[AppDBConst.itemUnitPrice]?.toDouble() ?? 0.0
                            : orderItem[AppDBConst.itemRegularPrice]!.toDouble();
                        final bool isEbtEligible = orderItem["is_ebt_eligible"] == true;

                        return ClipRRect(
                          // Build #1.0.151: FIXED - change ensures that sliding an item in one order does not affect the Slidable state of items at the same index in other orders.
                          key: ValueKey('${orderItem[AppDBConst.itemServerId]}_${_listVersion}_ClipRRect_$index'), // Build 1.0.214: Fixed Issue [SCRUM - 366] -> Swipe-to-Delete UI State Not Resetting After Add/Delete Operations // Updated key to include order ID
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.11,
                            child: Slidable(
                              // Build #1.0.151: FIXED - change ensures that sliding an item in one order does not affect the Slidable state of items at the same index in other orders.
                              key: ValueKey('${orderItem[AppDBConst.itemServerId]}_${_listVersion}_Slidable_$index'), // Build 1.0.214: Fixed Issue [SCRUM - 366] -> Swipe-to-Delete UI State Not Resetting After Add/Delete Operations // Updated key to include order ID
                              closeOnScroll: true,
                              direction: Axis.horizontal,
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (context) async {
                                      if (kDebugMode) {
                                        print("🗑️ Delete tapped for item: $orderItem");
                                      }

                                      final bool isOffline = orderHelper.activeOrderId != null &&
                                          Hive.box('offlineOrders').containsKey(orderHelper.activeOrderId.toString());

                                      await deleteOfflineItem(orderItem);

                                      if (kDebugMode) {
                                        print(isOffline
                                            ? "✅ Offline item deleted immediately."
                                            : "✅ Online item deleted immediately.");
                                      }
                                    },
                                    backgroundColor: Colors.transparent,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        const SizedBox(height: 4),
                                        const Text(TextConstants.deleteText, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                //Removed orderHelper.updateItemQuantity from the API success block, as it’s now in OrderBloc.updateOrderProducts.
                                // Kept local updateItemQuantity for non-API orders.
                                // Ensured loader is shown during API calls.
                                onTap: () async {
                                  if (isCouponOrPayout) return; // Skip coupon or payout
                                  if (kDebugMode) {
                                    print("🟩 Tapped on product item (offline mode)");
                                  }

                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black.withValues(alpha: 0.5),
                                    builder: (BuildContext dialogContext) {
                                      return EditProduct(
                                        orderItem: {
                                          AppDBConst.itemName: orderItem['item_name'],
                                          AppDBConst.itemUnitPrice: orderItem['item_price'],
                                          AppDBConst.itemRegularPrice: orderItem['item_price'],
                                          AppDBConst.itemCount: orderItem['items_count'],
                                          AppDBConst.itemImage: orderItem['item_image'],
                                        },
                                        onQuantityUpdated: (newQuantity) async {
                                          try {
                                            if (orderHelper.activeOrderId == null) return;

                                            final String orderKey = orderHelper.activeOrderId.toString();
                                            final offlineBox = Hive.box('offlineOrders');
                                            final rawOfflineOrder = offlineBox.get(orderKey);

                                            if (rawOfflineOrder == null) return;

                                            // Convert to editable map
                                            final Map<String, dynamic> offlineOrder =
                                            Map<String, dynamic>.from(rawOfflineOrder);

                                            // -------- NORMAL PRODUCTS ----------
                                            final List<Map<String, dynamic>> products =
                                                (offlineOrder['products'] as List?)
                                                    ?.map((e) => Map<String, dynamic>.from(e))
                                                    .toList() ??
                                                    [];

                                            // -------- CUSTOM ITEMS ----------
                                            final List<Map<String, dynamic>> customItems =
                                                (offlineOrder['custom_items'] as List?)
                                                    ?.map((e) => Map<String, dynamic>.from(e))
                                                    .toList() ??
                                                    [];

                                            final tappedItemName = (orderItem['item_name'] ?? '').toString();

                                            // 🔍 UPDATE NORMAL PRODUCTS
                                            for (var product in products) {
                                              final productName = (product['name'] ??
                                                  product['product_name'] ??
                                                  product['fast_key_item_name'] ??
                                                  '')
                                                  .toString();

                                              if (productName == tappedItemName) {
                                                final price =
                                                    double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;

                                                product['quantity'] = newQuantity;
                                                product['items_count'] = newQuantity;
                                                product['subtotal'] = price * newQuantity;

                                                if (kDebugMode) {
                                                  print("🟢 Updated PRODUCT → $productName | Qty: $newQuantity");
                                                }
                                                break;
                                              }
                                            }


                                            // 🔍 UPDATE CUSTOM ITEMS
                                            for (var custom in customItems) {
                                              final customName =
                                              (custom['custom_item_name'] ?? custom['item_name'] ?? '').toString();

                                              if (customName == tappedItemName) {
                                                final price = double.tryParse(
                                                    custom['custom_item_price']?.toString() ??
                                                        custom['amount']?.toString() ??
                                                        '0') ??
                                                    0.0;

                                                custom['quantity'] = newQuantity;
                                                custom['items_count'] = newQuantity;
                                                custom['subtotal'] = price * newQuantity;

                                                if (kDebugMode) {
                                                  print("🟣 Updated CUSTOM ITEM → $customName | Qty: $newQuantity");
                                                }
                                                break;
                                              }
                                            }

                                            // Save updated lists back to Hive
                                            offlineOrder['products'] = products;
                                            offlineOrder['custom_items'] = customItems;

                                            await offlineBox.put(orderKey, offlineOrder);

                                            // 🖥 Update customer display
                                            await CustomerDisplayHelper.updateCustomerDisplay(orderHelper.activeOrderId!);

                                            // 🔁 Refresh UI instantly
                                            if (mounted) {
                                              setState(() {
                                                // Rebuild products
                                                final updatedProducts = products.map((item) {
                                                  final price =
                                                      double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                                                  final qty =
                                                      int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

                                                  return {
                                                    'item_name':
                                                    item['name'] ?? item['product_name'] ?? '',
                                                    'item_price': price,
                                                    'items_count': qty,
                                                    'item_sum_price': price * qty,
                                                    'item_type': 'product',
                                                    'item_image': item['image'] ?? '',
                                                  };
                                                }).toList();


                                                // Rebuild custom items
                                                final updatedCustom = customItems.map((item) {
                                                  final price = double.tryParse(
                                                      item['custom_item_price']?.toString() ??
                                                          item['amount']?.toString() ??
                                                          '0') ??
                                                      0.0;
                                                  final qty =
                                                      int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

                                                  return {
                                                    'item_name': item['custom_item_name'] ?? item['item_name'] ?? "",
                                                    'item_price': price,
                                                    'items_count': qty,
                                                    'item_sum_price': price * qty,
                                                    'item_type': 'custom item',
                                                    'item_image': item['item_image']
                                                        ?? item['custom_item_image']
                                                        ?? item['image']
                                                        ?? 'assets/custom.png',
                                                  };
                                                }).toList();

                                                // Payout & Cashback maps intact
                                                final updatedPayouts =
                                                ((offlineOrder['payouts'] ?? []) as List)
                                                    .map((e) => Map<String, dynamic>.from(e))
                                                    .toList();

                                                final updatedCashbacks =
                                                ((offlineOrder['cashbacks'] ?? []) as List)
                                                    .map((e) => Map<String, dynamic>.from(e))
                                                    .toList();

                                                // FINAL ORDER ITEMS
                                                orderItems = [
                                                  ...updatedProducts,
                                                  ...updatedCustom,
                                                  ...updatedPayouts.map((payout) => {
                                                    'item_name': 'Payout',
                                                    'item_price': double.tryParse(
                                                        payout['amount']?.toString() ?? '0') ??
                                                        0.0,
                                                    'items_count': 1,
                                                    'item_sum_price': double.tryParse(
                                                        payout['amount']?.toString() ?? '0') ??
                                                        0.0,
                                                    'item_image': 'assets/svg/payout.svg',
                                                    'item_type': 'payout',
                                                  }),
                                                  ...updatedCashbacks.map((cb) => {
                                                    'item_name': 'Cashback',
                                                    'item_price': double.tryParse(
                                                        cb['amount']?.toString() ?? '0') ??
                                                        0.0,
                                                    'items_count': 1,
                                                    'item_sum_price': double.tryParse(
                                                        cb['amount']?.toString() ?? '0') ??
                                                        0.0,
                                                    'item_image': cb['product_image'] ??
                                                        cb['item_image'] ??
                                                        cb['image'] ??
                                                        "",
                                                    'item_type': 'cashback',
                                                  }),
                                                ];
                                              });
                                            }

                                            if (kDebugMode) {
                                              print("✅ Quantity updated for PRODUCT or CUSTOM ITEM");
                                            }
                                          } catch (e) {
                                            if (kDebugMode) print("❌ Failed updating quantity: $e");
                                          }
                                        },

                                        isDialog: true,
                                      );
                                    },
                                  );
                                },

                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeHelper.themeMode ==
                                        ThemeMode.dark
                                        ? Color(0xFF252837)
                                        : Color(0xFFE8E8E8), // ThemeNotifier.secondaryBackground color of items in order panel
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: orderItem[AppDBConst.itemImage].toString().startsWith('http')
                                            ? SizedBox(
                                          height: MediaQuery.of(context).size.height * 0.08,
                                          width: MediaQuery.of(context).size.height * 0.075,
                                          child: Image.network(
                                            orderItem[AppDBConst.itemImage],
                                            height: MediaQuery.of(context).size.height * 0.08,
                                            width: MediaQuery.of(context).size.height * 0.075,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                stackTrace) {
                                              return Image.asset(
                                                'assets/custom.png',
                                                height: MediaQuery.of(context).size.height * 0.08,
                                                width: MediaQuery.of(context).size.height * 0.08,
                                                fit: BoxFit.cover,
                                              );

                                            },
                                          ),
                                        )
                                            : orderItem[AppDBConst.itemImage].toString().startsWith('assets/')
                                            ? (
                                            orderItem[AppDBConst.itemImage].toString().endsWith('.svg')
                                                ? SvgPicture.asset(
                                              orderItem[AppDBConst.itemImage],
                                              height: MediaQuery.of(context).size.height * 0.08,
                                              width: MediaQuery.of(context).size.height * 0.075,
                                              fit: BoxFit.cover,
                                            )
                                                : Image.asset(
                                              orderItem[AppDBConst.itemImage],
                                              height: MediaQuery.of(context).size.height * 0.08,
                                              width: MediaQuery.of(context).size.height * 0.075,
                                              fit: BoxFit.cover,
                                            )
                                        )

                                            : Platform.isWindows
                                            ? Image.asset(
                                          'assets/custom.png',
                                          height: MediaQuery.of(context).size.height * 0.08,
                                          width: MediaQuery.of(context).size.height * 0.075,
                                          fit: BoxFit.cover,
                                        )
                                            : Image.file(
                                          File(orderItem[AppDBConst.itemImage]),
                                          height: MediaQuery.of(context).size.height * 0.08,
                                          width: MediaQuery.of(context).size.height * 0.075,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.asset(
                                              'assets/custom.png',
                                              height: MediaQuery.of(context).size.height * 0.08,
                                              width: MediaQuery.of(context).size.height * 0.08,
                                              fit: BoxFit.cover,
                                            );

                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            /// TODO: Change here to apply meta values for (mix & match) "combo" and "variation"
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      displayName.length > 40
                                                                          ? displayName.substring(0, 40) + "..."
                                                                          : displayName,
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: themeHelper.themeMode == ThemeMode.dark
                                                                            ? ThemeNotifier.textDark
                                                                            : ThemeNotifier.textLight,
                                                                      ),
                                                                    ),
                                                                    if ((orderItem['auto_discount'] ?? 0) > 0)
                                                                      Padding(
                                                                        padding: const EdgeInsets.only(top: 2),
                                                                        child: Text(
                                                                          "Auto Discount: -${TextConstants.currencySymbol}${orderItem['auto_discount'].toStringAsFixed(2)}",
                                                                          style: const TextStyle(
                                                                            fontSize: 11,
                                                                            color: Colors.red,
                                                                            fontWeight: FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ),

                                                                    // if (isVariant) ...[
                                                                    //   const SizedBox(height: 4),
                                                                    //   Icon(Icons.link, size: 15, color: Colors.red),
                                                                    // ],

                                                                    // ⭐ ADD EBT TAG HERE
                                                                    // if (isEbtEligible) ...[
                                                                    //   const SizedBox(height: 4),
                                                                    //   Container(
                                                                    //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                    //     decoration: BoxDecoration(
                                                                    //       color: Colors.green,
                                                                    //       borderRadius: BorderRadius.circular(4),
                                                                    //     ),
                                                                    //     child: const Text(
                                                                    //       "EBT",
                                                                    //       style: TextStyle(
                                                                    //         color: Colors.white,
                                                                    //         fontSize: 10,
                                                                    //         fontWeight: FontWeight.bold,
                                                                    //       ),
                                                                    //     ),
                                                                    //   ),
                                                                    // ],

                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                variationCount == 0 ? SizedBox(width: 0,) : Row(
                                                  children: [
                                                    Text(
                                                      ///Todo: use variation name here
                                                      variationName == '' ? "" : "(${variationName ?? ''})",
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 10, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey),
                                                    ),
                                                    SizedBox(
                                                      width: 4,
                                                    ),
                                                    ///Todo: show variation icon if variation count is no zero
                                                    SvgPicture.asset("assets/svg/variation.svg",height: 10, width: 10,),
                                                    SizedBox(
                                                      width: 4,
                                                    ),
                                                    Text(///Todo: show variation count if no zero
                                                      "${variationCount ?? 0}",
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 10, color: Color(0xFFFE6464)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            // Build #1.0.181: Fixed - Quantity for Custom Item Not Displayed After Switching Screens [JIRA #319]
                                            // we have to show price * qty for custom item also / condition updated, only dont show for payout and coupons
                                            Row(
                                              children: [
                                                // PRICE × QTY
                                                if (!isCouponOrPayout)
                                                  Text(
                                                    "${TextConstants.currencySymbol}${(orderItem['item_price'] ?? orderItem['price'] ?? 0).toStringAsFixed(2)} × ${(orderItem['items_count'] ?? orderItem['quantity'] ?? 1)}",
                                                    style: TextStyle(
                                                      color: themeHelper.themeMode == ThemeMode.dark
                                                          ? ThemeNotifier.textDark
                                                          : Colors.black54,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),

                                                // Space only when price exists AND (EBT or Variant to show)
                                                if (!isCouponOrPayout && (isEbtEligible || isVariant))
                                                  const SizedBox(width: 6),

                                                // EBT BADGE
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
                                                        color: Colors.white,
                                                        fontSize: 6,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),

                                                // Spacing ONLY if EBT is shown AND variant icon also needs to appear
                                                if (isEbtEligible && isVariant)
                                                  const SizedBox(width: 6),

                                                // VARIANT LINK ICON
                                                if (isVariant)
                                                  Row(
                                                    children: [
                                                      SvgPicture.asset(
                                                          SvgUtils
                                                              .variationIcon,
                                                          height: 10,
                                                          width: 10),
                                                      // SizedBox(width: 4),
                                                      // Text(
                                                      //   '${item["variations"].length}',
                                                      //   style: TextStyle(
                                                      //     fontSize: 12,
                                                      //     color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight,
                                                      //   ),
                                                      // ),
                                                    ],
                                                  ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                      // SizedBox(width: 8,),
                                      // if (!isCouponOrPayout)
                                      //   Text(
                                      //     "${TextConstants.currencySymbol} ${(regularPrice * orderItem[AppDBConst.itemCount]).toStringAsFixed(2)}",
                                      //     style: TextStyle(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.blueGrey, fontSize: 14),
                                      //   ),
                                      SizedBox(width: 20,),
                                      SizedBox(width: 20),

                                      Builder(
                                        builder: (context) {
                                          final int qty =
                                          (orderItem['items_count'] ??
                                              orderItem['quantity'] ??
                                              orderItem[AppDBConst.itemCount] ??
                                              1);

                                          final double originalTotal =
                                          (orderItem['original_total'] ??
                                              ((orderItem['item_price'] ?? orderItem['price'] ?? 0) * qty))
                                              .toDouble();

                                          final double discount =
                                          (orderItem['auto_discount'] ?? 0).toDouble();

                                          final double finalTotal = originalTotal - discount;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [

                                              /// 🔴 ORIGINAL PRICE (STRIKE)
                                              if (discount > 0)
                                                Text(
                                                  "${TextConstants.currencySymbol}${originalTotal.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),

                                              /// 🟢 FINAL PRICE (AFTER DISCOUNT)
                                              Text(
                                                isPayout
                                                    ? "-${TextConstants.currencySymbol}${finalTotal.toStringAsFixed(2)}"
                                                    : "${TextConstants.currencySymbol}${finalTotal.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPayout || isCoupon
                                                      ? Colors.red
                                                      : themeHelper.themeMode == ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : ThemeNotifier.textLight,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
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
                  if (tabs.isNotEmpty)
                    AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: (!isKeyboardVisible && _showFullSummary)
                          ? Container(
                        margin: const EdgeInsets.only(top: 8, right: 6, left: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(topRight: Radius.circular(8), topLeft: Radius.circular(8)),
                          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.orderPanelSummary : Colors.white,
                          boxShadow: [
                            // Shadow at the bottom
                            BoxShadow(
                              // color: Colors.black.withOpacity(0.25),
                              color: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? Color(0xFFF0F0F0).withOpacity(
                                  0.15) // stronger shadow for dark mode
                                  : Colors.black.withOpacity(
                                  0.25), // lighter shadow for light mode
                              offset: Offset(0,
                                  4), // 0 horizontal, 4 vertical (down)
                              blurRadius: 6,
                              spreadRadius: -0.5,
                            ),
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
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(TextConstants.subTotalText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight), ),
                                Text("${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}", //Build #1.0.68
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(TextConstants.taxText, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13,color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 : Colors.grey),),
                                Text("${TextConstants.currencySymbol}${orderTax.toStringAsFixed(2)}", //Build #1.0.92: removed minus "-"
                                    style: TextStyle( fontWeight: FontWeight.w600,fontSize: 12, color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 :Colors.grey)),
                              ],
                            ),
                            SizedBox(height: 2),
                            if(merchantDiscount>0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    spacing: 5,
                                    children: [
                                      // SvgPicture.asset("assets/svg/discount_star.svg",
                                      //   height: 12, width: 12,
                                      //   colorFilter: ColorFilter.mode(Colors.blueAccent, BlendMode.srcIn),),
                                      Text(TextConstants.merchantDiscount, style: TextStyle(color: Color(0xFF007BFF), fontSize: 12,fontWeight: FontWeight.w600,)),
                                      merchantDiscount.toStringAsFixed(2) == '0.00' ? SizedBox() : GestureDetector(
                                        onTap: () async {
                                          if (kDebugMode) print("####################### Remove Merchant Discount locally");

                                          final activeOrderId = orderHelper.activeOrderId;
                                          if (activeOrderId == null) {
                                            _scaffoldMessenger.showSnackBar(
                                              const SnackBar(
                                                content: Text("No active order found"),
                                                backgroundColor: Colors.red,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                            return;
                                          }

                                          // Step 1: Show confirmation dialog
                                          await CustomDialog.showRemoveSpecialOrderItemsConfirmation(
                                            context,
                                            confirm: () async {
                                              setState(() => _isLoading = true);

                                              final offlineBox = Hive.box('offlineOrders');
                                              final rawOrder = offlineBox.get(activeOrderId.toString());

                                              if (rawOrder == null) {
                                                setState(() => _isLoading = false);
                                                _scaffoldMessenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text("No offline order found"),
                                                    backgroundColor: Colors.red,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                                return;
                                              }

                                              // Convert to Map
                                              final Map<String, dynamic> order = Map<String, dynamic>.from(rawOrder);

                                              // Remove merchant discount completely
                                              if (order.containsKey('merchantDiscount') || order.containsKey('merchantDiscountIds')) {

                                                order.remove('merchantDiscount');
                                                order.remove('merchantDiscountIds');
                                                order.remove('discounts');

                                                await offlineBox.put(activeOrderId.toString(), order);

                                                setState(() => _isLoading = false);
                                                _scaffoldMessenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text("Merchant discount removed locally"),
                                                    backgroundColor: Colors.green,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );

                                                widget.refreshOrderList?.call();  // Refresh summary & order panel

                                              } else {
                                                setState(() => _isLoading = false);
                                                _scaffoldMessenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text("No merchant discount found on this order"),
                                                    backgroundColor: Colors.red,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },


                                        child: SvgPicture.asset("assets/svg/delete.svg", height: 24, width: 24),
                                      ),
                                    ],
                                  ),
                                  Text("-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
                                      style: TextStyle(color: Colors.blue, fontSize: 12,fontWeight: FontWeight.w600,)),
                                ],
                              ),
                            SizedBox(height: 2),
                            Builder(
                              builder: (_) {
                                print("🔥 SUMMARY → cashbackFee = $cashbackFee");
                                return SizedBox.shrink();
                              },
                            ),
                            if (cashbackFee > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    spacing: 5,
                                    children: [
                                      // Icon(Icons.wallet_giftcard,
                                      //     size: 14,
                                      //     color: Color(0XFF55CBCD)),
                                      Text(
                                        TextConstants.cashbackFee,
                                        style: TextStyle(
                                          color: Color(0XFF55CBCD),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "${TextConstants.currencySymbol}${cashbackFee.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: Color(0XFF55CBCD),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            // ShaderMask(
                            //   shaderCallback: (Rect bounds) {
                            //     return LinearGradient(
                            //       begin: Alignment.centerLeft,
                            //       end: Alignment.centerRight,
                            //       colors: themeHelper.themeMode ==
                            //           ThemeMode.dark
                            //           ? [
                            //         Colors.white.withOpacity(0.1),
                            //         Colors.white.withOpacity(0.7),
                            //         Colors.white.withOpacity(0.1),
                            //       ]
                            //           : [
                            //         Colors.black.withOpacity(0.1),
                            //         Colors.black.withOpacity(0.7),
                            //         Colors.black.withOpacity(0.1),
                            //       ],
                            //       stops: const [0.0, 0.5, 1.0],
                            //     ).createShader(bounds);
                            //   },
                            //   blendMode: BlendMode.srcIn,
                            //   child: DottedLine(
                            //     dashLength: 6,
                            //     dashGapLength: 4,
                            //     lineThickness: 1,
                            //     direction: Axis.horizontal,
                            //     dashColor: themeHelper.themeMode ==
                            //         ThemeMode.dark
                            //         ? Colors.white
                            //         : Colors
                            //         .black, // ✅ ensures gradient works correctly
                            //   ),
                            // ),
                            // SizedBox(height: 2),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            //   crossAxisAlignment: CrossAxisAlignment.center,
                            //   children: [
                            //     Text(TextConstants.taxText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 : Colors.grey),),
                            //     Text("${TextConstants.currencySymbol}${orderTax.toStringAsFixed(2)}", //Build #1.0.92: removed minus "-"
                            //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 :Colors.grey)),
                            //   ],
                            // ),
                            // SizedBox(height: 2),
                            // ShaderMask(
                            //   shaderCallback: (Rect bounds) {
                            //     return LinearGradient(
                            //       begin: Alignment.centerLeft,
                            //       end: Alignment.centerRight,
                            //       colors: themeHelper.themeMode ==
                            //           ThemeMode.dark
                            //           ? [
                            //         Colors.white.withOpacity(0.1),
                            //         Colors.white.withOpacity(0.7),
                            //         Colors.white.withOpacity(0.1),
                            //       ]
                            //           : [
                            //         Colors.black.withOpacity(0.1),
                            //         Colors.black.withOpacity(0.7),
                            //         Colors.black.withOpacity(0.1),
                            //       ],
                            //       stops: const [0.0, 0.5, 1.0],
                            //     ).createShader(bounds);
                            //   },
                            //   blendMode: BlendMode.srcIn,
                            //   child: DottedLine(
                            //     dashLength: 6,
                            //     dashGapLength: 4,
                            //     lineThickness: 1,
                            //     direction: Axis.horizontal,
                            //     dashColor: themeHelper.themeMode ==
                            //         ThemeMode.dark
                            //         ? Colors.white
                            //         : Colors
                            //         .black, // ✅ ensures gradient works correctly
                            //   ),
                            // ),
                            // SizedBox(height: 2),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            //   crossAxisAlignment: CrossAxisAlignment.center,
                            //   children: [
                            //     Text(TextConstants.netPayable, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                            //     Text("${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                            //         style: TextStyle(fontWeight: FontWeight.bold, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                            //   ],
                            // ),
                          ],
                        ),
                      )
                          : SizedBox.shrink(),
                    ),
                  if (tabs.isNotEmpty)
                    GestureDetector(
                      onTap: isKeyboardVisible ? null : _toggleSummary,
                      child: Container(
                        margin: const EdgeInsets.only(top: 0, right: 6, left: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(8), bottomLeft: Radius.circular(8)),
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(
                              0xFF2A2C36) // ✅ dark mode background 393C48
                              : Colors.grey.shade300,
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
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(
                                    _showFullSummary
                                        ? 'Amount: ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}'
                                        : 'Amount: ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Icon(_showFullSummary ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Payment button - outside the container
                  if (tabs.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.0585,
                      // 👇 outer container adds shadow
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Colors.black.withOpacity(0.5),
                        //     offset: const Offset(0, 4), // push shadow downward
                        //     blurRadius: 4, // soft, natural spread
                        //     spreadRadius: 0, // makes shadow fuller
                        //   ),
                        // ],
                      ),
                      //Build 1.1.36: on pay tap calling updateOrderProducts api call
                      child: ElevatedButton(
                        onPressed: orderItems.isNotEmpty
                            ? () async {
                          setState(() => _isPayBtnLoading = true);

                          try {
                            int? serverOrderId;
                            List wooLineItems = [];

                            // =======================================================
                            // 🔹 SYNC OFFLINE ORDER → WOO
                            // =======================================================
                            if (orderHelper.activeOrderId != null) {
                              final String orderId = orderHelper.activeOrderId.toString();
                              final rawOrder = getOfflineOrder(orderId);

                              if (rawOrder != null) {
                                if (kDebugMode) {
                                  print("🌀 Syncing offline order to server...");
                                }

                                final syncResult = await OrderRepository()
                                    .syncSingleOfflineOrder(
                                    Map<String, dynamic>.from(rawOrder));

                                if (syncResult != null) {
                                  serverOrderId = syncResult["order_id"];
                                  wooLineItems = syncResult["line_items"] ?? [];

                                  // -----------------------------
                                  // ✅ FETCH VALUES FROM SERVER
                                  // -----------------------------
                                  orderTax = double.tryParse(
                                      syncResult["tax"]?.toString() ?? "0") ??
                                      0.0;

                                  cashbackFee = double.tryParse(
                                      syncResult["cashback_fee"]?.toString() ?? "0") ??
                                      0.0;

                                  final syncedEbt = double.tryParse(
                                      syncResult["ebt_total"]?.toString() ?? "0") ??
                                      0.0;

                                  final syncedDiscountAmount = double.tryParse(
                                      syncResult["discount_amount"]?.toString() ?? "0") ??
                                      0.0;

                                  // -----------------------------
                                  // ✅ SAVE TO HIVE
                                  // -----------------------------
                                  final box = Hive.box('offlineOrders');
                                  final localKey = orderHelper.activeOrderId.toString();
                                  final wooKey = serverOrderId.toString();

                                  final existing = box.get(localKey);
                                  if (existing != null) {
                                    final updated = Map<String, dynamic>.from(existing);
                                    updated["wooOrderId"] = wooKey;
                                    updated["tax"] = orderTax;
                                    updated["cashback_fee"] = cashbackFee;
                                    updated["ebt_total"] = syncedEbt;
                                    updated["discount_amount"] = syncedDiscountAmount;

                                    await box.put(localKey, updated);
                                    await box.put(wooKey, updated);
                                  }
                                }
                              }
                            }


                            // =======================================================
                            // 🔹 LOAD VALUES FOR SUMMARY
                            // =======================================================
                            final box = Hive.box('offlineOrders');
                            final hiveKey =
                                serverOrderId?.toString() ??
                                    orderHelper.activeOrderId.toString();

                            final double ebtAmount =
                            (box.get(hiveKey)?["ebt_total"] ?? 0.0).toDouble();

                            final double discountAmount =
                            (box.get(hiveKey)?["discount_amount"] ?? 0.0).toDouble();
// =======================================================
// ⭐ MAP AUTO / COMBO / MULTIPACK DISCOUNT FROM WOO → UI ITEMS
// =======================================================
                            for (final item in orderItems) {
                              final int localPid =
                                  int.tryParse(item['product_id']?.toString() ?? '0') ?? 0;

                              final String name =
                                  item['item_name']?.toString().trim() ?? '';

                              final wooItem = wooLineItems.firstWhere(
                                    (w) {
                                  final int wooPid =
                                      int.tryParse(w['product_id']?.toString() ?? '0') ?? 0;

                                  return (localPid > 0 && wooPid == localPid) ||
                                      w['name']?.toString().trim() == name;
                                },
                                orElse: () => null,
                              );

                              if (wooItem == null) continue;

                              final List meta = wooItem['meta_data'] ?? [];

                              bool isCombo = false;
                              bool isMultipack = false;

                              double comboDiscount = 0.0;
                              double multipackDiscount = 0.0;

                              for (final m in meta) {
                                // ---------- COMBO ----------
                                if (m['key'] == 'Discount Type' &&
                                    m['value'] == 'Combo Discount') {
                                  isCombo = true;
                                }

                                if (m['key'] == 'Discount Applied') {
                                  comboDiscount =
                                      double.tryParse(m['value']?.toString() ?? '0') ?? 0.0;
                                }

                                // ---------- MULTIPACK ----------
                                if (m['key'] == '_pinaka_multipack_applied' &&
                                    m['value'] == 'yes') {
                                  isMultipack = true;
                                }

                                if (m['key'] == '_pinaka_multipack_product_discount') {
                                  multipackDiscount =
                                      double.tryParse(m['value']?.toString() ?? '0') ?? 0.0;
                                }
                              }

                              // ---------- APPLY PRIORITY ----------
                              if (isCombo && comboDiscount > 0) {
                                item['auto_discount'] = comboDiscount;
                                item['discount_type'] = 'combo';
                                item['discount_source'] = 'woo';
                              } else if (isMultipack && multipackDiscount > 0) {
                                item['auto_discount'] = multipackDiscount;
                                item['discount_type'] = 'multipack';
                                item['discount_source'] = 'woo';
                              }
                            }

// =======================================================
// ⭐ CALCULATE TOTAL AUTO DISCOUNT (COMBO + MULTIPACK)
// =======================================================
                            double totalAutoDiscount = 0.0;

                            for (final item in orderItems) {
                              final double d = double.tryParse(
                                  item['auto_discount']?.toString() ?? '0') ?? 0.0;

                              if ((item['discount_type'] == 'combo' ||
                                  item['discount_type'] == 'multipack') &&
                                  d > 0) {
                                totalAutoDiscount += d;
                              }
                            }

                            if (kDebugMode) {
                              print("🧮 TOTAL AUTO DISCOUNT = $totalAutoDiscount");
                            }

                            final double grossAfterDiscount =
                                grossTotal.toDouble() - totalAutoDiscount;

                            final double safeGrossAfterDiscount =
                            grossAfterDiscount < 0 ? 0 : grossAfterDiscount;

                            // =======================================================
                            // 🔹 NAVIGATE TO SUMMARY
                            // =======================================================
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderSummaryScreen(
                                  formattedDate: displayDate,
                                  formattedTime: displayTime,
                                  orderItems: orderItems,
                                  grossTotal: safeGrossAfterDiscount,
                                  orderDiscount: orderDiscount,
                                  merchantDiscount: merchantDiscount,
                                  orderTax: orderTax,
                                  netPayable: netPayable.toDouble(),
                                  orderId: serverOrderId ?? orderHelper.activeOrderId,
                                  isOfflineSynced: serverOrderId != null,
                                  offlineOrderId: orderHelper.activeOrderId,
                                  cashbackFee: cashbackFee,
                                  ebtAmount: ebtAmount,
                                  discountAmount: discountAmount,
                                ),
                              ),
                            );

                            if (result == TextConstants.refresh) {
                              setState(() {
                                OrderHelper.isOrderPanelLoaded = false;
                                fetchOrdersData();
                              });
                            }
                          } catch (e, s) {
                            print("❌ Error syncing order: $e");
                            print(s);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to sync order")),
                            );
                          } finally {
                            setState(() => _isPayBtnLoading = false);
                          }
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          orderItems.isNotEmpty ? const Color(0xFFFF6B6B) : Colors.grey,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPayBtnLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "Check Out",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),

                    ),
                ],
              ),
            ),
          ],
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 6.0,
              ),
            ),
          ),
      ],
    );
  }
  /// //Build #1.0.2 : Added showNumPadDialog if user tap on order layout list item
// ========================
// HIVE HELPER FUNCTIONS
// ========================

  Map<String, dynamic>? getOfflineOrder(String orderId) {
    final box = Hive.box('offlineOrders');
    final data = box.get(orderId);

    if (kDebugMode) {
      print("📥 [Hive] Fetched offline order → ID: $orderId | Data: $data");
    }

    if (data == null) return null;

    return Map<String, dynamic>.from(data);
  }

  Future<void> updateOfflineOrderTaxAndCashback(
      String orderId, double tax, double cashback) async {
    final box = Hive.box('offlineOrders');
    final existing = box.get(orderId);

    if (existing == null) {
      if (kDebugMode) {
        print("⚠ [Hive] Cannot update order → Not found for ID: $orderId");
      }
      return;
    }

    final updatedOrder = Map<String, dynamic>.from(existing);

    updatedOrder["tax"] = tax;
    updatedOrder["cashback_fee"] = cashback;

    await box.put(orderId, updatedOrder);

    if (kDebugMode) {
      print("💾 [Hive] Updated offline order → ID: $orderId | tax: $tax | cashback_fee: $cashback");
    }
  }
/// //Build #1.0.2 : Added showNumPadDialog if user tap on order layout list item

// New method to show product edit screen (replace the existing showNumPadDialog)
// void showProductEditScreen(BuildContext context, Map<String, dynamic> orderItem) {
//   showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//     return ProductEditScreen(
//       orderItem: orderItem,
//       onQuantityUpdated: (newQuantity) {
//         setState(() {
//           orderItem[AppDBConst.itemCount] = newQuantity;
//         });
//         // Here you would update the database if needed
//         // For now we're just updating the UI state
//         fetchOrderItems();
//       },
//     );
//   }
//   );
// }
// void showNumPadDialog(BuildContext context, String itemName, Function(int) onQuantitySelected) {
//   TextEditingController controller = TextEditingController();
//   int quantity = 0;
//
//   showDialog(
//     context: context,
//     builder: (context) {
//       return StatefulBuilder(
//         builder: (context, setState) {
//           void updateQuantity(int newQuantity) {
//             setState(() {
//               quantity = newQuantity;
//               controller.text = quantity == 0 ? "" : quantity.toString();
//             });
//           }
//
//           return Dialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 100),
//             child: Container(
//               width: 600,
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Title
//                   Text(TextConstants.enterQuanText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
//                   Text(itemName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                   SizedBox(height: 12),
//
//                   // TextField with + and - buttons
//                   Container(
//                     width: 500,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.grey.shade400, width: 1.5),
//                       color: Colors.grey.shade100,
//                     ),
//                     padding: EdgeInsets.symmetric(horizontal: 20), // Match NumPad padding
//                     child: Row(
//                       children: [
//                         // Decrement Button
//                         IconButton(
//                           icon: Icon(Icons.remove_circle, size: 32, color: Colors.redAccent),
//                           onPressed: () {
//                             if (quantity > 0) updateQuantity(quantity - 1);
//                           },
//                         ),
//
//                         // Quantity TextField
//                         Expanded(
//                           child: TextField(
//                             controller: controller,
//                             textAlign: TextAlign.center,
//                             readOnly: true,
//                             style: TextStyle(
//                               fontSize: 28,
//                               fontWeight: controller.text.isEmpty ? FontWeight.normal : FontWeight.bold,
//                               color: controller.text.isEmpty ? Colors.grey : Colors.black87, // Fix: Color updates correctly
//                             ),
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                               hintText: "00", // Fix: Shows properly when empty
//                               hintStyle: TextStyle(fontSize: 28, color: Colors.grey),
//                               contentPadding: EdgeInsets.symmetric(vertical: 12), // Fix: Consistent padding
//                             ),
//                           ),
//                         ),
//
//                         // Increment Button
//                         IconButton(
//                           icon: Icon(Icons.add_circle, size: 32, color: Colors.green),
//                           onPressed: () {
//                             updateQuantity(quantity + 1);
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 16),
//
//                   // CustomNumPad with OK button
//                   CustomNumPad(
//                     onDigitPressed: (digit) {
//                       setState(() {
//                         int newQty = int.tryParse((controller.text.isEmpty ? "0" : controller.text) + digit) ?? quantity;
//                         updateQuantity(newQty);
//                       });
//                     },
//                     onClearPressed: () => updateQuantity(0),
//                     onConfirmPressed: () {
//                       onQuantitySelected(quantity);
//                       Navigator.pop(context);
//                     },
//                     actionButtonType: ActionButtonType.ok, // OK instead of Delete
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       );
//     },
//   );
// }
// void showProductEditScreen(BuildContext context, Map<String, dynamic> orderItem) {
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext dialogContext) {
//       return ProductEditScreen(
//         orderItem: orderItem,
//         onQuantityUpdated: (newQuantity) async {
//           // Update the item in the database first
//           // if (orderHelper.activeOrderId != null) {
//           //   await orderHelper.updateItemQuantity(
//           //       orderItem[AppDBConst.itemId],
//           //       newQuantity
//           //   );
//           // }
//
//           // Then update the UI state
//           setState(() {
//             orderItem[AppDBConst.itemCount] = newQuantity;
//             // Also update the sum price to maintain consistency
//             orderItem[AppDBConst.itemSumPrice] =
//                 orderItem[AppDBConst.itemPrice] * newQuantity;
//           });
//
//           // Refresh the order items
//           fetchOrderItems();
//         },
//       );
//     },
//   );
// }
}

// extension on Box {
//   void clearCache() {}
// }
