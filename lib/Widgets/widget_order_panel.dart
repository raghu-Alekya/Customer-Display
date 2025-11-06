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
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Screens/Auth/login_screen.dart';
import '../Utilities/global_utility.dart';
import '../Models/Orders/orders_model.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Auth/store_validation_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Screens/Home/add_screen.dart';
import '../Screens/Home/edit_product_screen.dart';
import '../services/CustomerDisplayService.dart';
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

  // Build #1.0.10: Initializes the tab controller and handles tab switching
  Future<void> _initializeTabController() async {
    if (kDebugMode) {
      print("##### _initializeTabController");
    }
    if (!mounted) return; // Prevent initialization if unmounted

    _tabController?.dispose();

    if (tabs.isEmpty) {
      if (kDebugMode) print("##### No tabs available → showing Welcome screen");
      await CustomerDisplayService.showWelcome(); // Use await here
      return;
    }

    _tabController = TabController(length: tabs.length, vsync: this);

    _tabController!.addListener(() async {
      if (!_tabController!.indexIsChanging && mounted) {
        int selectedIndex = _tabController!.index;
        int selectedOrderId = tabs[selectedIndex]["orderId"] as int;

        if (kDebugMode) {
          print("##### DEBUG: Tab changed to index: $selectedIndex, orderId: $selectedOrderId");
        }

        await orderHelper.setActiveOrder(selectedOrderId);
        await orderHelper.saveLastActiveOrderId(selectedOrderId);
        await fetchOrderItems();
        await CustomerDisplayHelper.updateCustomerDisplay(selectedOrderId);

        if (mounted) setState(() {}); // Refresh UI
      }
    });

    // Set default tab index
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
      await CustomerDisplayHelper.updateCustomerDisplay(tabs[defaultIndex]["orderId"] as int);
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
  void deleteItemFromOrder(int itemId) async {

    if (orderHelper.activeOrderId != null) {

      setState(() {
        _isLoading = true;
        if (kDebugMode) {
          print("##### deleteItemFromOrder: _isLoading: $_isLoading");
        }
      }); // Show loader

      // final order = orderHelper.orders.firstWhere(
      //       (order) => order[AppDBConst.orderServerId] == orderHelper.activeOrderId,
      //   orElse: () => {},
      // );
      final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
      // final dbOrderId = orderHelper.activeOrderId!;
      final item = orderItems.firstWhere(
            (item) => item[AppDBConst.itemServerId] == itemId,
        orElse: () => {},
      );
      final itemType = item[AppDBConst.itemType]?.toString().toLowerCase() ?? '';
      final isPayout = false;//itemType.contains(TextConstants.payoutText);// Build #1.0.198: uncomment if want to delete payout from fee_lines
      final isCoupon = itemType.contains(TextConstants.couponText);
      final isCustomItem = itemType.contains(TextConstants.customItemText);

      if (serverOrderId != null) {
        _updateOrderSubscription?.cancel();
        if (isPayout) {
          final db = await DBHelper.instance.database;
          final payoutItem = await db.query(
            AppDBConst.purchasedItemsTable,
            where: '${AppDBConst.itemServerId} = ? AND ${AppDBConst.itemType} = ?',
            whereArgs: [itemId, ItemType.payout.value],
          );
          if (payoutItem.isNotEmpty) {
            final payoutId = payoutItem.first[AppDBConst.itemServerId] as int?;
            if (payoutId != null) {
              _removePayoutOrDiscountSubscription?.cancel(); //Build #1.0.99
              retryCallback() async {
                setState(() => _isLoading = true);
                await orderBloc.removeFeeLine(orderId: serverOrderId, feeLineId: payoutId); //Build #1.0.92: dbOrderId and serverOrderId is same, no need then
                //Build #1.0.99: Dismiss dialog after retry
                Navigator.of(context, rootNavigator: true).pop();
              }
              _removePayoutOrDiscountSubscription = orderBloc.removePayoutStream.listen((response) async {
                await _handleResponse(response, item, isPayout: true, retryCallback: retryCallback);
              });
              await orderBloc.removeFeeLine(orderId: serverOrderId, feeLineId: payoutId); //Build #1.0.92: dbOrderId and serverOrderId is same
            } else {
              await _handleLocalDelete(item, context);
              _handleError("Payout ID not found in database, removed locally", isPayout: true);
            }
          } else {
            _handleError("Payout not found", isPayout: true);
          }
        } else if (isCoupon) {
          final couponCode = item[AppDBConst.itemName]?.toString() ?? '';
          if (couponCode.isNotEmpty) {
            _removeCouponSubscription?.cancel(); //Build #1.0.99
            retryCallback() async {
              setState(() => _isLoading = true);
              await orderBloc.removeCoupon(orderId: serverOrderId, couponCode: couponCode);
              //Build #1.0.99: Dismiss dialog after retry
              Navigator.of(context, rootNavigator: true).pop();
            }
            _removeCouponSubscription = orderBloc.removeCouponStream.listen((response) async {
              await _handleResponse(response, item, isCoupon: true, retryCallback: retryCallback);
            });
            await orderBloc.removeCoupon(orderId: serverOrderId, couponCode: couponCode);
          } else {
            await _handleLocalDelete(item, context);
            _handleError("Coupon code not found in database, removed locally", isCoupon: true);
          }
        } else if (isCustomItem) {
          final db = await DBHelper.instance.database;
          final customItem = await db.query(
            AppDBConst.purchasedItemsTable,
            where: '${AppDBConst.itemServerId} = ? AND ${AppDBConst.itemType} = ?', //Build #1.0.92: updated to itemServerId
            whereArgs: [itemId, ItemType.customProduct.value],
          );
          if (customItem.isNotEmpty) {
            final customItemId = customItem.first[AppDBConst.itemServerId] as int?;
            if (customItemId != null) {
              retryCallback() async {
                setState(() => _isLoading = true);
                await orderBloc.deleteOrderItem(
                  orderId: serverOrderId,
                  // dbOrderId: dbOrderId,
                  dbItemId: itemId,
                  lineItems: [
                    OrderLineItem(
                      id: customItemId,
                      quantity: 0,
                      //  sku: item[AppDBConst.itemSKU] ?? '',
                    ),
                  ],
                );
                //Build #1.0.99 : Dismiss dialog after retry
                Navigator.of(context, rootNavigator: true).pop();
              }
              _updateOrderSubscription = orderBloc.deleteOrderItemStream.listen((response) async {
                await _handleResponse(response, item, isCustomItem: true, retryCallback: retryCallback);
              });
              await orderBloc.deleteOrderItem(
                orderId: serverOrderId,
                //  dbOrderId: dbOrderId,
                dbItemId: itemId,
                lineItems: [
                  OrderLineItem(
                    id: customItemId,
                    quantity: 0,
                    //   sku: item[AppDBConst.itemSKU] ?? '',
                  ),
                ],
              );
            } else {
              await _handleLocalDelete(item, context);
              _handleError("Custom item ID not found in database, removed locally", isCustomItem: true);
            }
          } else {
            _handleError("Custom item not found", isCustomItem: true);
          }
        } else {
          final productId = item[AppDBConst.itemServerId] as int?;
          if (productId != null) {
            retryCallback() async {
              setState(() => _isLoading = true);
              await orderBloc.deleteOrderItem(
                orderId: serverOrderId,
                // dbOrderId: dbOrderId,
                dbItemId: itemId,
                lineItems: [
                  OrderLineItem(
                    id: productId,
                    quantity: 0,
                    //   sku: item[AppDBConst.itemSKU] ?? '',
                  ),
                ],
              );
              //Build #1.0.99 : Dismiss dialog after retry
              Navigator.of(context, rootNavigator: true).pop();
            }
            _updateOrderSubscription = orderBloc.deleteOrderItemStream.listen((response) async {
              await _handleResponse(response, item, retryCallback: retryCallback);
            });
            await orderBloc.deleteOrderItem(
              orderId: serverOrderId,
              //  dbOrderId: dbOrderId,
              dbItemId: itemId,
              lineItems: [
                OrderLineItem(
                  id: productId,
                  quantity: 0,
                  //  sku: item[AppDBConst.itemSKU] ?? '',
                ),
              ],
            );
          } else {
            await _handleLocalDelete(item, context);
          }
        }
      } else {
        await _handleLocalDelete(item, context);
      }
    }
  }

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
        onBarcodeScanned: (barcode) async {
          ///Added logs to show while executing scanning operation
          try{
            //barcode = barcode.trim().replaceAll(' ', '');
            if (kDebugMode) {
              print("##### DEBUG: onBarcodeScanned - Scanned barcode: -$barcode, isOrderInForeground = $isOrderInForeground, _isLoading: $_isLoading, _isCustomItemLoading: $_isCustomItemLoading");
            }
            showLogs = true;
            logString += "##### DEBUG: onBarcodeScanned - Scanned barcode: -$barcode, isOrderInForeground = $isOrderInForeground, _isLoading: $_isLoading, _isCustomItemLoading: $_isCustomItemLoading \n ";
            if(!isOrderInForeground){ // to restrict order panel in background to scanner events
              return;
            }
            if (_isLoading) return; // Build #1.0.256: Prevent multiple simultaneous scans
            if (_isCustomItemLoading) return;
            if(_productBySkuSubscription != null) {
              // _productBySkuSubscription?.cancel();
              logString += "##### DEBUG: onBarcodeScanned - Cancelled _productBySkuSubscription \n ";
            }
            if (barcode.isNotEmpty) {
              var dobScanned = "";
              /// Testing code: not working, Scanner will generate multiple tap events and call when scanned driving licence with PDF417 format irrespective of this code here
              // if (barcode.startsWith('@') || barcode.contains('\n') || barcode.startsWith('ansi') || barcode.startsWith('2') || barcode.startsWith('DBB')) {
              //   // if (barcode.startsWith('@') || barcode.contains('\n')) {
              //   // PDF417 often includes structured data with newlines or starts with '@' (AAMVA standard)
              //   if (kDebugMode) {
              //     print('PDF417 Detected: $barcode');
              //   }
              //   var date = parseDOBFromBarcode(barcode);
              //   dobScanned = "${date?.month}/${date?.day}/${date?.year}";
              //   if (kDebugMode) {
              //     print("##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode, $dobScanned");
              //   }
              //   return;
              // } else {
              //   if (kDebugMode) {
              //     print('Non-PDF417 Barcode: $barcode');
              //   }
              // }
              if (kDebugMode) {
                print("##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode, $dobScanned");
              }
              logString += "##### DEBUG: onBarcodeScanned - Scanned barcode: $barcode \n ";
              // Create new order if none exists
              if (tabs.isEmpty) {
                // addNewTab(); // Build #1.0.256: No need to create order here - updateOrderProducts will handle it if orderId is null time.
                if (kDebugMode) {
                  print("##### DEBUG: onBarcodeScanned - No tabs are available");
                }
                logString += "##### DEBUG: onBarcodeScanned - No tabs are available \n ";
              }
              _isLoading = true;// Show loader
              setState(() {});
              _productBySkuSubscription?.cancel();
              _productBySkuSubscription = productBloc.productBySkuStream.listen((response) async {
                logString += "##### DEBUG: onBarcodeScanned - response.status : ${response.status} \n ";
                if(response.status == Status.LOADING){
                  logString += "##### DEBUG: onBarcodeScanned - fetchProductBySku LOADING started";
                } else if (response.status == Status.COMPLETED && response.data!.isNotEmpty) {
                  _isLoading = false;
                  _productBySkuSubscription?.cancel();
                  _productBySkuSubscription = null; // Fixed Scanner issue creating two order in order panel
                  setState(() {}); //Build #1.0.92
                  final product = response.data!.first;
                  if (kDebugMode) {
                    print("##### DEBUG: onBarcodeScanned - Product found: ${product.name}, variations: ${product.variations.length}");
                  }
                  logString += "##### DEBUG: onBarcodeScanned - Product found: ${product.name}, variations: ${product.variations.length} \n ";
                  // Build #1.0.80: MISSED CODE ADDED
                  /// use product id:22, sku:woo-fashion-socks
                  // var isVerified = await _ageRestrictedProduct(product);
                  // Use the new provider to check for age restriction
                  if(!mounted) {
                    return;
                  }
                  //Build #1.0.234: Checking stored age restriction before verifying -> Age
                  final order = orderHelper.orders.firstWhere(
                        (order) => order[AppDBConst.orderServerId] == orderHelper.activeOrderId,
                    orElse: () => {},
                  );
                  final String ageRestrictedValue = order[AppDBConst.orderAgeRestricted]?.toString() ?? 'false';
                  final bool isAgeRestricted = ageRestrictedValue.toLowerCase() == 'true' || ageRestrictedValue == "1";

                  if (!isAgeRestricted) {
                    ///Age Verification code
                    final ageVerificationProvider = AgeVerificationProvider();
                    var isVerified = await ageVerificationProvider.ageRestrictedProduct(context, product);

                    /// Verify Age and proceed else return
                    if(!isVerified){
                      return;
                    }
                  }
                  ///Todo: Need to call variation service before adding product to the order
                  if (product.variations.isNotEmpty) {
                    ///1. Call _productBloc.fetchProductVariations(product.id!);
                    ///2. load Variation popup
                    ///3. On add button from variation popup -> add to order list
                    VariationPopup(product.id, product.name, orderHelper, onProductSelected: ({required bool isVariant}) async {
                      if (kDebugMode) {
                        print("VariationPopup returned with isVariant $isVariant");
                      }
                      logString += " VariationPopup returned with isVariant $isVariant \n ";
                      Navigator.pop(context);
                      // fetchOrderItems(); //onItemTapped(index, variantAdded: isVariant); //Build #1.0.78: Pass isVariant to onItemTapped
                      final serverOrderId = orderHelper.activeOrderId;
                      if (serverOrderId != null) {
                        await fetchOrderItems();
                      } else {
                        await _getOrderTabs(); //Build #1.0.258: fix loading order tab when product is getting scanned with no order available
                      }
                    },
                    ).showVariantDialog(context: context);

                    // Show variants dialog for products with variations
                    if (kDebugMode) {
                      print("##### DEBUG: onBarcodeScanned - Showing variants dialog");
                    }
                    logString += " ##### DEBUG: onBarcodeScanned - Showing variants dialog \n ";
                  } else {

                    ///Comment below code not we are using only server order id as to check orders, skip checking db order id
                    // final order = orderHelper.orders.firstWhere(
                    //       (order) => order[AppDBConst.orderId] == orderHelper.activeOrderId,
                    //   orElse: () => {},
                    // );
                    final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
                    final dbOrderId = orderHelper.activeOrderId;
                    if (product.id != null) { // Build #1.0.128
                      setState(() => _isLoading = true);
                      _updateOrderSubscription?.cancel();
                      _updateOrderSubscription = orderBloc.updateOrderStream.listen((response) async {
                        if (response.status == Status.LOADING) { // Build #1.0.80
                          const Center(child: CircularProgressIndicator()); // Added Loader
                        }else if (response.status == Status.COMPLETED) {
                          if (kDebugMode) {
                            print("##### DEBUG: onBarcodeScanned - Product added successfully");
                          }
                          logString += "##### DEBUG: onBarcodeScanned - Product added successfully \n ";
                          if (serverOrderId != null) {
                            await fetchOrderItems();
                          } else {
                            await _getOrderTabs(); //Build #1.0.258: fix loading order tab when product is getting scanned with no order available
                          }
                          setState(() {
                            _isLoading = false;
                            // barcode = "";
                          });
                          if (Misc.showDebugSnackBar) { // Build #1.0.254
                            _scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text("Product added successfully"),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else if (response.status == Status.ERROR) {
                          setState(() {
                            _isLoading = false;
                            // barcode = "";
                          }); //Build #1.0.99 : Hide loader
                          if (response.message!.contains('Unauthorised')) {
                            if (kDebugMode) {
                              print("categories 4 ---- Unauthorised : ${response.message!}");
                            }
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                Navigator.pushReplacement(context,
                                    MaterialPageRoute(builder: (context) => LoginScreen()));

                                if (kDebugMode) {
                                  print("message 4 --- ${response.message}");
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
                              print("##### ERROR: onBarcodeScanned - Failed to add product: ${response.message}");
                            }
                            logString += "##### ERROR: onBarcodeScanned - Failed to add product: ${response.message} \n ";
                            _scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    response.message ?? "Failed to add product"),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      });
                      logString += await orderBloc.updateOrderProducts(
                        orderId: serverOrderId,
                        dbOrderId: dbOrderId,
                        lineItems: [
                          OrderLineItem(
                            productId: product.id,
                            quantity: 1,
                            // sku: product.sku ?? '',
                          ),
                        ],
                      );
                      setState(() {});
                    } else {
                      // Add product directly to order
                      if (kDebugMode) {
                        print("##### DEBUG: onBarcodeScanned - Not Adding product to DB directly: ${product.name}");
                      }
                      logString += "##### DEBUG: onBarcodeScanned - Not Adding product to DB directly: ${product.name} \n ";
                      // await orderHelper.addItemToOrder(
                      //   product.id,
                      //   product.name,
                      //   product.images.isNotEmpty ? product.images.first.src : '',
                      //   double.parse(product.price.isNotEmpty ? product.price : '0.0'),
                      //   1,
                      //   product.sku ?? barcode,
                      //   type: ItemType.product.value,
                      //   onItemAdded: (){
                      //     if (kDebugMode) {
                      //       print("Item Added stop loading ");
                      //       _isLoading = false;
                      //       setState(() {
                      //
                      //       });
                      //     }
                      //   }
                      // );
                      await fetchOrderItems();
                      _scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text("Product did not added to order. OrderId not found."),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      setState(() {
                        _isLoading = false;
                        // barcode = "";
                      });
                    }
                  }
                } else {
                  // Show error if product not found
                  if (kDebugMode) {
                    print("##### DEBUG: onBarcodeScanned - Product not found for SKU: $barcode, _isCustomItemLoading: $_isCustomItemLoading");
                  }
                  logString += "##### DEBUG: onBarcodeScanned - Product not found for SKU: $barcode, _isCustomItemLoading: $_isCustomItemLoading \n ";
                  _isLoading = false;
                  _productBySkuSubscription?.cancel();
                  _productBySkuSubscription = null; // Fixed Scanner issue creating two order in order panel
                  setState(() {
                    // barcode = "";
                  });
                  if (!mounted) return;
                  if (!_isCustomItemLoading) {
                    _isCustomItemLoading = true; // added to avoid showing dialog twice as per scan

                    await CustomDialog.showCustomItemNotAdded(
                        context, onRetry: () {
                      // Navigate to AddScreen when "Let's Try Again" is pressed
                      Navigator.of(context).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddScreen(
                                barcode: barcode,
                                selectedTabIndex: 2, // Custom items tab
                              ),
                        ),(route) => false,
                      );
                    }).then((_) { //Build #1.0.54: added
                      if (kDebugMode) {
                        print(
                            "OrderPanel CustomDialog.showCustomItemNotAdded is dismissed and _isCustomItemLoading was $_isCustomItemLoading");
                      }
                      _isCustomItemLoading = false;
                    });
                  }
                }
              });
              _productBySkuSubscription?.onError((handleError){
                if (kDebugMode) {
                  print("Error while scanning custom item handleError : $handleError");
                }
                logString += "Error while scanning custom item handleError : $handleError \n";
              });
              logString += await productBloc.fetchProductBySku(barcode);
              logString += "##### DEBUG: onBarcodeScanned - fetchProductBySku completed";
              setState(() {});
            }
          } catch(e,s) {
            if (kDebugMode) {
              print("Exception in Barcode scanning : $e,\n Stack: $s");
            }
            logString += "Exception in Barcode scanning : $e,\n *** Stack: $s ***\n ";
            //1. Stop loading
            setState(() {
              _isLoading = false;
            });

            //2. Show toast with error message
            _scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text("Failed to add product, Exception: $e, Stack: $s"), ///remove this exception from toast message
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );

          }
        },
        child: Stack(
          children: [
            // 🔹 Main Order Panel (Card + Tabs)
            Container(
              width: MediaQuery.of(context).size.width * 0.30,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.only(top: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
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
    if (tabs.isEmpty) return;

    final int orderId = tabs[index]["orderId"] as int;
    final bool isRemovedTabActive = orderId == orderHelper.activeOrderId;
    setState(() => _isLoading = true);

    try {
      final offlineBox = Hive.box('offlineOrders');
      final bool isOfflineOrder = offlineBox.containsKey(orderId.toString());

      // ✅ If it's an offline order (stored in Hive)
      if (isOfflineOrder) {
        if (kDebugMode) {
          print("🟡 removeTab → Detected offline order ($orderId), deleting from Hive and DB...");
        }

        // 1️⃣ Delete from Hive
        await offlineBox.delete(orderId.toString());
        if (kDebugMode) print("✅ Offline order $orderId deleted from Hive");

        // 2️⃣ Delete from SQLite
        await orderHelper.deleteOrder(orderId);
        if (kDebugMode) print("✅ Offline order $orderId deleted from SQLite");

        // 3️⃣ Remove from local memory
        orderHelper.orders.removeWhere((o) =>
        o[AppDBConst.orderServerId] == orderId ||
            o[AppDBConst.orderId] == orderId);
        orderHelper.orderIds.remove(orderId);

        // 4️⃣ Update UI
        setState(() {
          tabs.removeAt(index);
          for (int i = 0; i < tabs.length; i++) {
            tabs[i]["subtitle"] = "Tab ${i + 1}";
          }
        });

        // 5️⃣ Handle active order
        if (tabs.isNotEmpty) {
          final int newIndex = index >= tabs.length ? tabs.length - 1 : index;
          final int newActiveOrderId = tabs[newIndex]["orderId"] as int;

          if (isRemovedTabActive) {
            await orderHelper.setActiveOrder(newActiveOrderId);
            await orderHelper.saveLastActiveOrderId(newActiveOrderId);
          }

          await _initializeTabController();
          _tabController!.index = newIndex;
          await fetchOrderItems();

          // 🟢 Update Customer Display
          await CustomerDisplayHelper.updateCustomerDisplay(newActiveOrderId);
        } else {
          setState(() {
            orderHelper.activeOrderId = null;
            orderItems = [];
          });
          await _initializeTabController();

          // 🟢 Show welcome screen when no tabs left
          await CustomerDisplayService.showWelcome();
        }

        setState(() => _isLoading = false);
        _scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("Offline order cancelled"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // ✅ Otherwise → Online Order (use API)
      final int serverOrderId = orderId;
      if (kDebugMode) print("🌐 removeTab → Online order $serverOrderId, calling API...");

      _updateOrderSubscription?.cancel();
      _updateOrderSubscription = orderBloc.changeOrderStatusStream.listen((response) async {
        if (!mounted) return;

        if (response.status == Status.COMPLETED) {
          if (kDebugMode) print("✅ Online order $orderId successfully cancelled");

          await orderHelper.deleteOrder(orderId);
          orderHelper.cancelledOrderId = serverOrderId;

          setState(() {
            tabs.removeAt(index);
            for (int i = 0; i < tabs.length; i++) {
              tabs[i]["subtitle"] = "Tab ${i + 1}";
            }
          });

          if (tabs.isNotEmpty) {
            final int newIndex = index >= tabs.length ? tabs.length - 1 : index;
            final int newActiveOrderId = tabs[newIndex]["orderId"] as int;

            if (isRemovedTabActive) {
              await orderHelper.setActiveOrder(newActiveOrderId);
              await orderHelper.saveLastActiveOrderId(newActiveOrderId);
            }

            await _initializeTabController();

            // 🛑 Only reload if exists in Hive
            if (offlineBox.containsKey(newActiveOrderId.toString())) {
              await fetchOrderItems();
            } else {
              setState(() => orderItems = []);
            }

            _tabController!.index = newIndex;

            // 🟢 Update Customer Display for new active order
            await CustomerDisplayHelper.updateCustomerDisplay(newActiveOrderId);
          } else {
            setState(() {
              orderHelper.activeOrderId = null;
              orderItems = [];
            });
            await _initializeTabController();

            // 🟢 Show welcome screen when all tabs removed
            await CustomerDisplayService.showWelcome();
          }

          setState(() => _isLoading = false);
          _scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text("Order cancelled successfully"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (response.status == Status.ERROR) {
          setState(() => _isLoading = false);

          if (response.message?.contains('Unauthorised') ?? false) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unauthorised. Session expired."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            _scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(response.message ?? "Failed to cancel order"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      });

      await orderBloc.changeOrderStatus(
        orderId: serverOrderId,
        status: TextConstants.cancelled,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print("❌ ERROR: removeTab exception → $e");
        print(stack);
      }
      setState(() => _isLoading = false);
    }
  }


  Future<void> deleteOfflineItem(Map<String, dynamic> orderItem) async {
    if (orderHelper.activeOrderId == null) return;

    final offlineBox = Hive.box('offlineOrders');
    final String orderKey = orderHelper.activeOrderId.toString();
    final rawOfflineOrder = offlineBox.get(orderKey);

    if (rawOfflineOrder == null) return;

    final Map<String, dynamic> offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);

    // ✅ Determine if item is product or payout
    final String itemType = (orderItem['item_type'] ?? '').toString().toLowerCase();

    // Extract current product and payout lists
    final List<Map<String, dynamic>> products =
        (offlineOrder['products'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    final List<Map<String, dynamic>> payouts =
        (offlineOrder['payouts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    if (itemType == 'payout') {
      // 🧾 Match and remove payout
      payouts.removeWhere((p) {
        final amt1 = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        final amt2 = double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;
        return amt1 == amt2;
      });
      offlineOrder['payouts'] = payouts;
    } else {
      // 🛒 Match and remove product
      products.removeWhere((p) {
        final name1 = (p['name'] ?? p['product_name'] ?? p['fast_key_item_name'] ?? '').toString().toLowerCase();
        final name2 = (orderItem['item_name'] ?? '').toString().toLowerCase();
        final price1 = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        final price2 = double.tryParse(orderItem['item_price']?.toString() ?? '0') ?? 0;
        return name1 == name2 && price1 == price2;
      });
      offlineOrder['products'] = products;
    }

    // 💾 Save updated order back to Hive
    await offlineBox.put(orderKey, offlineOrder);

    await CustomerDisplayHelper.updateCustomerDisplay(orderHelper.activeOrderId!);

    if (kDebugMode) {
      print("🗑️ Deleted offline $itemType successfully!");
      print("Updated offline order:");
      print(const JsonEncoder.withIndent('  ').convert(offlineOrder));
    }

    // 🔁 Refresh local UI list
    setState(() {
      orderItems.remove(orderItem);
    });
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
    double orderTax = 0.0;
    num grossTotal = GlobalUtility.getGrossTotal(orderItems);  // Get Items Gross Total
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

        // 🛍️ Load products and payouts
        final offlineProducts = ((offlineOrder['products'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (kDebugMode) {
          print("🧩 Offline products raw data:");
          for (var p in offlineProducts) {
            print(const JsonEncoder.withIndent('  ').convert(p));
          }
        }


        final offlinePayouts = ((offlineOrder['payouts'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // 🧾 Combine both for display
        final offlineItems = [
          ...offlineProducts.map((item) => {
            'item_name': item['name'] ?? item['product_name'] ?? '',
            'item_price': double.tryParse(
                item['price']?.toString() ??
                    item['unit_price']?.toString() ??   // ✅ added
                    item['sales_price']?.toString() ??  // ✅ added
                    item['regular_price']?.toString() ??// ✅ added
                    item['unitPrice']?.toString() ??
                    item['salesPrice']?.toString() ??
                    item['regularPrice']?.toString() ??
                    item['fast_key_item_price']?.toString() ??
                    '0'
            ) ?? 0.0,


            'items_count': int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
            'item_sum_price': (double.tryParse(
                item['price']?.toString() ??
                    item['unit_price']?.toString() ??
                    item['sales_price']?.toString() ??
                    item['regular_price']?.toString() ??
                    '0'
            ) ?? 0.0) *
                (double.tryParse(item['quantity']?.toString() ?? '1') ?? 1),

            'item_image': item['image'] ?? '',
            'item_type': 'Product',
          }),
          ...offlinePayouts.map((payout) => {
            'item_name': 'Payout',
            'item_price': double.tryParse(payout['amount']?.toString() ?? '0') ?? 0.0,
            'items_count': 1,
            'item_sum_price': double.tryParse(payout['amount']?.toString() ?? '0') ?? 0.0,
            'item_image': 'assets/svg/payout.svg',
            'item_type': 'payout',
          }),
        ];


        // ✅ Assign to your global/UI list
        orderItems = offlineItems;

        // 🧮 Calculate totals
        double productTotal = offlineProducts.fold<double>(0, (sum, item) {
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
          final qtyValue = item['quantity'];
          final qty = qtyValue is int
              ? qtyValue
              : int.tryParse(qtyValue?.toString() ?? '0') ?? 0;

        return sum + (price * qty);
        });


        double payoutTotal = offlinePayouts.fold<num>(0, (sum, payout) {
          return sum + (payout['amount'] ?? 0.0);
        }).toDouble();

        grossTotal = productTotal + payoutTotal;

        orderDiscount = 0.0;
        merchantDiscount = 0.0;
        orderTax = 0.0;

        netTotal = grossTotal - orderDiscount - merchantDiscount;
        netPayable = netTotal + orderTax;

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
          print("   grossTotal: $grossTotal");
          print("   netPayable: $netPayable");
          print("🧾 Offline items for UI → ${jsonEncode(orderItems)}");
        }
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
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground: null,
              padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (orderHelper.activeOrderId != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/calendar.svg',
                          width: 20,
                          height: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black, // or your light mode color
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 112),
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
                            color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
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
                        /// Check if the item is a payout or a coupon
                        final isPayout = itemType.contains(TextConstants.payoutText);
                        final isCoupon = itemType.contains(TextConstants.couponText);
                        final isCustomItem = itemType.contains(TextConstants.customItemText);
                        final isPayoutOrCouponOrCustomItem = isPayout || isCoupon || isCustomItem;
                        final isCouponOrPayout = isPayout || isCoupon;
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

                        return ClipRRect(
                          // Build #1.0.151: FIXED - change ensures that sliding an item in one order does not affect the Slidable state of items at the same index in other orders.
                          key: ValueKey('${orderItem[AppDBConst.itemServerId]}_${_listVersion}_ClipRRect_$index'), // Build 1.0.214: Fixed Issue [SCRUM - 366] -> Swipe-to-Delete UI State Not Resetting After Add/Delete Operations // Updated key to include order ID
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.10,
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
                                        orderItem: orderItem,
                                        onQuantityUpdated: (newQuantity) async {
                                          try {
                                            if (orderHelper.activeOrderId == null) return;

                                            final String orderKey = orderHelper.activeOrderId.toString();
                                            final offlineBox = Hive.box('offlineOrders');
                                            final rawOfflineOrder = offlineBox.get(orderKey);

                                            if (rawOfflineOrder == null) return;

                                            // Convert to editable map
                                            final Map<String, dynamic> offlineOrder = Map<String, dynamic>.from(rawOfflineOrder);
                                            final List<Map<String, dynamic>> products =
                                                (offlineOrder['products'] as List?)
                                                    ?.map((e) => Map<String, dynamic>.from(e))
                                                    .toList() ?? [];

                                            // 🔍 Locate and update the tapped product
                                            for (var product in products) {
                                              final name1 = (product['name'] ??
                                                  product['product_name'] ??
                                                  product['fast_key_item_name'] ??
                                                  '')
                                                  .toString();
                                              final name2 = (orderItem['item_name'] ?? '').toString();

                                              if (name1 == name2) {
                                                final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                                                product['quantity'] = newQuantity;
                                                product['items_count'] = newQuantity;
                                                product['subtotal'] = price * newQuantity;

                                                if (kDebugMode) {
                                                  print("🧾 Updated offline product → $name1 | Qty: $newQuantity | Subtotal: ${product['subtotal']}");
                                                }
                                                break;
                                              }
                                            }

                                            // Save updated order back to Hive
                                            offlineOrder['products'] = products;
                                            await offlineBox.put(orderKey, offlineOrder);
                                            await CustomerDisplayHelper.updateCustomerDisplay(orderHelper.activeOrderId!);

                                            if (kDebugMode) {
                                              final offlineBox = Hive.box('offlineOrders');
                                              final data = offlineBox.get(orderHelper.activeOrderId!.toString());
                                              print("🖥️ Customer Display Updated for Order: ${orderHelper.activeOrderId}");
                                              print("📦 Customer Display Data → ${jsonEncode(data)}");
                                            }

                                            // 🔁 Rebuild Current Order UI instantly
                                            if (mounted) {
                                              setState(() {
                                                // Recalculate and reload from Hive directly
                                                final updatedProducts = products
                                                    .map((item) => {
                                                  'item_name': item['name'] ??
                                                      item['product_name'] ??
                                                      '',
                                                  'item_price': double.tryParse(
                                                      item['price']?.toString() ?? '0') ??
                                                      0.0,
                                                  'items_count':
                                                  double.tryParse(item['quantity']?.toString() ?? '1') ??
                                                      1,
                                                  'item_sum_price': (double.tryParse(
                                                      item['price']?.toString() ?? '0') ??
                                                      0.0) *
                                                      (double.tryParse(
                                                          item['quantity']?.toString() ?? '1') ??
                                                          1),
                                                  'item_type': 'Product',
                                                  'item_image': item['image'] ?? '',
                                                })
                                                    .toList();

                                                final updatedPayouts = ((offlineOrder['payouts'] ?? []) as List)
                                                    .map((e) => Map<String, dynamic>.from(e))
                                                    .toList();

                                                final updatedItems = [
                                                  ...updatedProducts,
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
                                                ];

                                                orderItems = updatedItems;
                                              });
                                            }

                                            if (kDebugMode) {
                                              print("✅ Offline quantity updated and UI refreshed from Hive");
                                            }
                                          } catch (e) {
                                            if (kDebugMode) {
                                              print("❌ Failed to update offline item quantity: $e");
                                            }
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
                                              return SvgPicture.asset(
                                                'assets/svg/password_placeholder.svg',
                                                height: MediaQuery.of(context).size.height * 0.08,
                                                width: MediaQuery.of(context).size.height * 0.08,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          ),
                                        )
                                            : orderItem[AppDBConst.itemImage].toString().startsWith('assets/')
                                            ? SvgPicture.asset(
                                          orderItem[AppDBConst.itemImage],
                                          height: MediaQuery.of(context).size.height * 0.08,
                                          width: MediaQuery.of(context).size.height * 0.075,
                                          fit: BoxFit.cover,
                                        )
                                            : Platform.isWindows
                                            ? Image.asset(
                                          'assets/default.png',
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
                                            return SvgPicture.asset(
                                              'assets/svg/password_placeholder.svg',
                                              height: MediaQuery.of(context).size.height * 0.08,
                                              width: MediaQuery.of(context).size.height * 0.075,
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
                                                RichText(
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: displayName,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            fontFamily: 'inter',
                                                            fontWeight: FontWeight.bold,
                                                            color: themeHelper.themeMode == ThemeMode.dark
                                                                ? ThemeNotifier.textDark
                                                                : ThemeNotifier.textLight
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:///Todo: use combo here
                                                        combo == '' ? '' : " (Combo)",
                                                        style: TextStyle(fontSize: 8, color: Colors.cyan),
                                                      ),
                                                    ],
                                                  ),
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
                                      Text(
                                        isPayout
                                            ? "-${TextConstants.currencySymbol}${(
                                            ((orderItem['items_count'] ?? orderItem['quantity'] ?? orderItem[AppDBConst.itemCount] ?? 1) *
                                                ((orderItem['item_price'] ?? orderItem['price'] ?? orderItem[AppDBConst.itemPrice] ?? 0).abs()))
                                        ).toStringAsFixed(2)}"
                                            : "${TextConstants.currencySymbol}${(
                                            ((orderItem['items_count'] ?? orderItem['quantity'] ?? orderItem[AppDBConst.itemCount] ?? 1) *
                                                (isCoupon
                                                    ? (orderItem['item_price'] ?? orderItem['price'] ?? orderItem[AppDBConst.itemPrice] ?? 0).abs()
                                                    : (orderItem['item_price'] ?? orderItem['price'] ?? orderItem[AppDBConst.itemSalesPrice] ?? orderItem[AppDBConst.itemRegularPrice] ?? orderItem[AppDBConst.itemUnitPrice] ?? 0)))
                                        ).toStringAsFixed(2)}",
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
                                Text(TextConstants.grossTotal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight), ),
                                Text("${TextConstants.currencySymbol}${grossTotal.toStringAsFixed(2)}", //Build #1.0.68
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  spacing: 5,
                                  children: [
                                    SvgPicture.asset("assets/svg/discount_star.svg", height: 12, width: 12),
                                    Text(TextConstants.discountText, style: TextStyle(color: Colors.green, fontSize: 14)),
                                  ],
                                ),
                                Text("-${TextConstants.currencySymbol}${orderDiscount.toStringAsFixed(2)}",
                                    style: TextStyle(color: Color(0xFF05B10C), fontSize: 12)),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  spacing: 5,
                                  children: [
                                    SvgPicture.asset("assets/svg/discount_star.svg",
                                      height: 12, width: 12,
                                      colorFilter: ColorFilter.mode(Colors.blueAccent, BlendMode.srcIn),),
                                    Text(TextConstants.merchantDiscount, style: TextStyle(color: Color(0xFF007BFF), fontSize: 14)),
                                    merchantDiscount.toStringAsFixed(2) == '0.00' ? SizedBox() : GestureDetector(
                                      onTap: () async {
                                        //Passed dbOrderId to removeFeeLines.
                                        // Removed database operations, as they’re now in OrderBloc.removeFeeLines.
                                        // Ensured loader is shown during API calls.
                                        if (kDebugMode) {
                                          print("####################### Merchant Discount onTap");
                                        }
                                        if (orderHelper.activeOrderId != null) {
                                          // Step 1: Show confirmation dialog
                                          await CustomDialog.showRemoveSpecialOrderItemsConfirmation(context, confirm: () async {
                                            // Step 2: Show loader
                                            setState(() => _isLoading = true);
                                            // final order = orderHelper.orders.firstWhere(
                                            //       (order) => order[AppDBConst.orderServerId] == orderHelper.activeOrderId,
                                            //   orElse: () => {},
                                            // );
                                            final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
                                            final dbOrderId = orderHelper.activeOrderId!;

                                            if (serverOrderId != null) {
                                              final db = await DBHelper.instance.database;
                                              ///TODO : Update below table code for new discount id code
                                              final merchantDiscountValue = await db.query(
                                                AppDBConst.orderTable,
                                                where: '${AppDBConst.orderServerId} = ? AND ${AppDBConst.merchantDiscount} = ?',
                                                whereArgs: [dbOrderId, merchantDiscount],
                                              );

                                              if (merchantDiscountValue.isNotEmpty) {
                                                // final payoutIds = merchantDiscountValue.first[AppDBConst.merchantDiscountIds].toString().split(',') ?? [];
                                                // //remove the empty id
                                                // payoutIds.removeAt(0);
                                                // With this fixed version:
                                                // Build #1.0.216: FIXED Issue - Merchant discount not deleting, showing error "Payout ID not found"
                                                String discountIdsString = merchantDiscountValue.first[AppDBConst.merchantDiscountIds].toString();
                                                List<String> discountIds = discountIdsString.split(',').where((id) => id.isNotEmpty).toList();
                                                if (kDebugMode) {
                                                  print("OrderPanel - payouts to delete $discountIds");
                                                }
                                                if (discountIds.isNotEmpty) {
                                                  //Build #1.0.99: Cancel any existing subscription to prevent multiple listeners
                                                  _removeMerchantDiscountSubscription?.cancel();
                                                  retryCallback() async {
                                                    setState(() => _isLoading = true);
                                                    //  await orderBloc.removeFeeLines(orderId: serverOrderId, feeLineIds: payoutIds);
                                                    // Creating line items for deletion (quantity = 0 to remove)
                                                    List<OrderLineItem> merchantDiscountToDelete = discountIds.map((id) =>
                                                        OrderLineItem(id: int.parse(id), quantity: 0)
                                                    ).toList();
                                                    await orderBloc.deleteOrderItem( // Build #1.0.274: Updated to deleteOrderItem api call for removing merchant discount
                                                      orderId: serverOrderId,
                                                      lineItems: merchantDiscountToDelete,
                                                      //  dbItemId: int.parse(discountIds.first) // No need for merchant Discount // Using first ID as representative
                                                    );
                                                    // Dismiss dialog after retry
                                                    Navigator.of(context, rootNavigator: true).pop();
                                                  };
                                                  _removeMerchantDiscountSubscription =
                                                      orderBloc.deleteOrderItemStream.listen((response) async {
                                                        if (response.status == Status.COMPLETED) {
                                                          setState(() => _isLoading = false); //Build #1.0.92
                                                          await fetchOrderItems();
                                                          widget.refreshOrderList?.call();
                                                          if (Misc.showDebugSnackBar) { // Build #1.0.254
                                                            _scaffoldMessenger.showSnackBar(
                                                              SnackBar(content: Text("Merchant Discount removed successfully"),
                                                                backgroundColor: Colors.green,
                                                                duration: const Duration(seconds: 2),
                                                              ),
                                                            );
                                                          }
                                                        } else if (response.status == Status.ERROR) {
                                                          if (response.message!.contains('Unauthorised')) {
                                                            if (kDebugMode) {
                                                              print("categories screen 7 ---- Unauthorised : ${response.message!}");
                                                            }
                                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                                              if (mounted) {
                                                                Navigator.pushReplacement(context,
                                                                    MaterialPageRoute(builder: (context) => LoginScreen()));

                                                                if (kDebugMode) {
                                                                  print("message 7 --- ${response.message}");
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
                                                          } else {
                                                            if (kDebugMode) {
                                                              print("###### Delete Discount API error");
                                                            }
                                                            setState(() => _isLoading = false);
                                                            _scaffoldMessenger.showSnackBar(
                                                              SnackBar(
                                                                content: Text("Failed to remove discount"),
                                                                backgroundColor: Colors.red,
                                                                duration: const Duration(seconds: 2),
                                                              ),
                                                            );
                                                          }
                                                          await CustomDialog.showDiscountNotApplied(context,
                                                            errorMessageTitle: TextConstants.removeDiscountFailed,
                                                            errorMessageDes: response.message ?? TextConstants.discountNotAppliedDescription,
                                                            onRetry: retryCallback,
                                                          );
                                                        }
                                                      });
                                                  // Creating line items for deletion (quantity = 0 to remove)
                                                  List<OrderLineItem> merchantDiscountToDelete = discountIds.map((id) =>
                                                      OrderLineItem(id: int.parse(id), quantity: 0)
                                                  ).toList();

                                                  await orderBloc.deleteOrderItem( // Build #1.0.274 : Added api call
                                                    orderId: serverOrderId,
                                                    lineItems: merchantDiscountToDelete,
                                                    // dbItemId: int.parse(discountIds.first) // No need for merchant Discount // Using first ID as representative
                                                  );
                                                  //  await orderBloc.removeFeeLines(orderId: serverOrderId,feeLineIds: discountIds);
                                                } else {
                                                  setState(() => _isLoading = false);
                                                  _scaffoldMessenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text("Payout ID not found"),
                                                      backgroundColor: Colors.red,
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                setState(() => _isLoading = false);
                                                _scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text("No payout found for this order"),
                                                    backgroundColor: Colors.red,
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            } else {
                                              setState(() => _isLoading = false);
                                              _scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text("Server Order ID not found"),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      },
                                      child: SvgPicture.asset("assets/svg/delete.svg", height: 24, width: 24),
                                    ),
                                  ],
                                ),
                                Text("-${TextConstants.currencySymbol}${merchantDiscount.toStringAsFixed(2)}",
                                    style: TextStyle(color: Colors.blue, fontSize: 12)),
                              ],
                            ),
                            SizedBox(height: 2),
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
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(TextConstants.netTotalText,style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight),),
                                Text("${TextConstants.currencySymbol}${netTotal.toStringAsFixed(2)}",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(TextConstants.taxText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 : Colors.grey),),
                                Text("${TextConstants.currencySymbol}${orderTax.toStringAsFixed(2)}", //Build #1.0.92: removed minus "-"
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeHelper.themeMode == ThemeMode.dark ? Colors.white54 :Colors.grey)),
                              ],
                            ),
                            SizedBox(height: 2),
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
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(TextConstants.netPayable, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                                Text("${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : ThemeNotifier.textLight)),
                              ],
                            ),
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
                            Text("${TextConstants.totalItemsText}: ${orderItems.length}",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(
                                    _showFullSummary
                                        ? 'Net Payable: ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}'
                                        : 'Net Payable: ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}',
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
                        // Build 1.1.36: on pay tap calling updateOrderProducts api call
                        onPressed: orderItems.isNotEmpty
                            ? () async {
                          setState(() => _isPayBtnLoading = true);

                          try {
                            int? serverOrderId;

                            if (orderHelper.activeOrderId != null) {
                              final box = Hive.box('offlineOrders');
                              final rawOrder = box.get(orderHelper.activeOrderId.toString());

                              if (rawOrder != null) {
                                if (kDebugMode) print("🌀 Syncing offline order to server...");

                                final syncResult = await OrderRepository()
                                    .syncSingleOfflineOrder(Map<String, dynamic>.from(rawOrder));

                                if (syncResult != null) {
                                  serverOrderId = syncResult["order_id"];
                                  final syncedTax = syncResult["tax"] ?? 0.0;

                                  if (kDebugMode) {
                                    print("✅ Offline order sync completed → Server ID: $serverOrderId, Tax: $syncedTax");
                                  }

                                  // Update local tax
                                  orderTax = syncedTax;

                                  // // ✅ Immediately delete synced offline order from Hive
                                  // final offlineOrderId = orderHelper.activeOrderId;
                                  // if (offlineOrderId != null) {
                                  //   if (kDebugMode) print("🧹 Removing synced offline order $offlineOrderId from Hive...");
                                  //   final offlineBox = Hive.box('offlineOrders');
                                  //
                                  //   if (offlineBox.containsKey(offlineOrderId.toString())) {
                                  //     await offlineBox.delete(offlineOrderId.toString());
                                  //     if (kDebugMode) print("✅ Deleted offline order $offlineOrderId from Hive");
                                  //   }
                                  //
                                  //   // ✅ Also remove from SQLite
                                  //   await orderHelper.deleteOrder(offlineOrderId);
                                  //   if (kDebugMode) print("✅ Deleted offline order $offlineOrderId from SQLite");
                                  // }
                                } else {
                                  if (kDebugMode) print("⚠️ Sync succeeded but no server data found");
                                }

                                if (serverOrderId != null) {
                                  if (kDebugMode) print("✅ Offline order sync completed → Server ID: $serverOrderId");
                                } else {
                                  if (kDebugMode) print("⚠️ Sync succeeded but no server ID found");
                                }
                              } else {
                                if (kDebugMode) print("⚠️ No offline order found for sync");
                              }
                            }

                            // ✅ Print before navigating to summary
                            if (kDebugMode) {
                              print("🧾 Using order ID in OrderSummaryScreen → ${serverOrderId ?? orderHelper.activeOrderId}");
                            }

                            // ✅ Pass the actual WooCommerce order ID
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderSummaryScreen(
                                  formattedDate: displayDate,
                                  formattedTime: displayTime,
                                  orderItems: orderItems,
                                  grossTotal: grossTotal.toDouble(),
                                  orderDiscount: orderDiscount,
                                  merchantDiscount: merchantDiscount,
                                  orderTax: orderTax,
                                  netPayable: netPayable.toDouble(),
                                  orderId: serverOrderId ?? orderHelper.activeOrderId,
                                  isOfflineSynced: serverOrderId != null,
                                  offlineOrderId: orderHelper.activeOrderId,
                                ),
                              ),
                            );

                            if (result == TextConstants.refresh) {
                              setState(() {
                                OrderHelper.isOrderPanelLoaded = false;
                                fetchOrdersData();
                              });
                            }
                          } catch (e) {
                            if (kDebugMode) print("❌ Error syncing order: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to sync order: $e")),
                            );
                          } finally {
                            setState(() => _isPayBtnLoading = false);
                          }
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orderItems.isNotEmpty ? const Color(0xFFFF6B6B) : Colors.grey,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPayBtnLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                          "Pay  ${TextConstants.currencySymbol}${netPayable.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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