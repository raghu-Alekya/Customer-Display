import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Database/db_helper.dart';
import 'package:pinaka_pos/Models/Assets/asset_model.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/widget_order_screen_panel.dart';
import '../../Widgets/widget_order_status.dart';
import '../../Widgets/widget_filter_chip.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_pagination.dart';
import '../../Widgets/widget_range_filter.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Models/Orders/get_orders_model.dart' as model; // Added prefix
import '../../Repositories/Orders/order_repository.dart';
import '../../Helper/api_response.dart';
import '../../Constants/text.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;

import 'package:quickalert/quickalert.dart';

import '../Auth/login_screen.dart';

class TotalOrdersScreen extends StatefulWidget {
  // Build #1.0.226: updated class name
  final int? lastSelectedIndex;

  const TotalOrdersScreen({super.key, this.lastSelectedIndex});

  @override
  State<TotalOrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<TotalOrdersScreen>
    with LayoutSelectionMixin {
  late OrderBloc _orderBloc;
  List<model.OrderModel> _orders = []; // Use model.OrderModel
  int _selectedSidebarIndex = 3;
  DateTime now = DateTime.now();
  List<int> quantities = [1, 1, 1, 1];
  bool isLoading = false; // Build #1.0.104
  String _selectedStatusFilter = "All";
  String _selectedUserFilter = "All";
  String _selectedOrderTypeFilter = "All";
  String _selectedPaymentMethodFilter = "All";
  late double _minSalesAmount;
  late double _maxSalesAmount;
  late RangeValues _salesAmountRange;
  String? _sortColumn;
  bool _isAscending = true;
  StreamSubscription? _fetchOrdersSubscription;
  int _totalOrdersCount = 0;
  bool _fetchInProgress = false;
  Timer? _loadingDelayTimer;

  ///Filters
  // List<String> _availableStatuses = ["All"];
  final List<OrderStatus> _filterStatuses = [
    OrderStatus(slug: "", name: "All")
  ];
  final List<Employees> _filterUsers = [Employees(iD: "", displayName: "All")];
  final List<OrderType> _filterOrderType = [OrderType(slug: "", name: "All")];

  // 🔥 Page-level lazy loading
  final ScrollController _tableScrollController = ScrollController();

  List<model.OrderModel> _pageOrders = [];     // full page data (20)
  List<model.OrderModel> _visibleOrders = [];  // shown data (10 → 20)

  int _chunkSize = 10;
  int _currentChunk = 1;


  Map<String, dynamic>? _selectedOrder;
  // int? _selectedOrderId; // Build #1.0.248: right now saving in order helper class , because state level saving resetting after re build
  /// OrderHelper already singleton class , no need to create instance here again
  // final OrderHelper orderHelper = OrderHelper(); // Helper instance to manage orders
  // final PinakaPreferences _preferences = PinakaPreferences(); //Build #1.0.234: No need
  // Date range filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeApplied = false;
  String? panelDate;
  String?
      panelTime; // Build #1.0.226: UPDATED to widget level to class level declaration // ADD this logic to determine the date and time for the panel

  // Add these variables for pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];
  dynamic _extractMeta(Map map, String key) {
    if (map["request"]?["meta_data"] is List) {
      for (var m in map["request"]["meta_data"]) {
        if (m["key"] == key) return m["value"];
      }
    }
    return null;
  }
  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 3;
    _orderBloc = OrderBloc(OrderRepository());
    // Preserve POS context so when navigating back to Fast Keys/Categories/Add,
    // the order panel shows the order we were working on, not the order viewed here
    final oh = OrderHelper();
    if (oh.activeOrderId != null) {
      oh.saveLastActiveOrderId(oh.activeOrderId!);
    }
    _minSalesAmount = 0.0;
    _maxSalesAmount = 10000.0; // Default max, will be updated from API
    _salesAmountRange = RangeValues(_minSalesAmount, _maxSalesAmount);
    initFilters();
    _tableScrollController.addListener(() {
      if (_rowsPerPage <= _chunkSize) return;

      // ✅ NEW GUARD
      if (!_tableScrollController.position.hasContentDimensions) return;
      if (_tableScrollController.position.maxScrollExtent == 0) return;

      if (_tableScrollController.position.pixels >=
          _tableScrollController.position.maxScrollExtent - 80) {

        final maxChunks = (_pageOrders.length / _chunkSize).ceil();

        if (!isLoading && _currentChunk < maxChunks) {
          setState(() {
            _currentChunk++;
            _visibleOrders =
                _pageOrders.take(_currentChunk * _chunkSize).toList();
            _orders = _visibleOrders;
          });
        }
      }
    });


    // Initialize order fetching
    //_fetchOrders();
    // _orderScreenPanel = OrderScreenPanel( //Build #1.0.234: No need
    //   key: ValueKey(orderHelper.activeOrderId ?? 0),
    //   formattedDate: panelDate ?? '', // Build #1.0.226
    //   formattedTime: panelTime ?? '',
    //   quantities: quantities,
    //   activeOrderId: orderHelper.activeOrderId, // Pass activeOrderId
    //   fetchOrders: false, // Show shimmer initially
    // );
  }
  bool get _hasMoreLazyData {
    if (_rowsPerPage <= _chunkSize) return false;

    final maxChunks = (_pageOrders.length / _chunkSize).ceil();
    return _currentChunk < maxChunks;
  }

  Future<void> initFilters() async {
    var filterStatuses = await AssetDBHelper.instance.getOrderStatusList();
    filterStatuses.removeWhere((e) => e.slug == TextConstants.processing);
    _filterStatuses.addAll(filterStatuses);

    var filterUsers = await AssetDBHelper.instance.getEmployeeList();
    _filterUsers.addAll(filterUsers);

    var filterOrderType = await AssetDBHelper.instance.getOrderTypeList();
    _filterOrderType.addAll(filterOrderType);

    // ⭐ ADD OFFLINE ORDER TYPE MANUALLY
    _filterOrderType.add(OrderType(slug: "offline Order", name: "offline Order"));
  }
  //Build #1.0.54: added Fetch orders from API
  void _fetchOrders() {
    debugPrint("OrdersScreen: Initiating fetch orders");
    _fetchOrdersSubscription?.cancel();
    _loadingDelayTimer?.cancel();
    _loadingDelayTimer = null;
    _fetchInProgress = false;
    _fetchOrdersSubscription =
        _orderBloc.fetchTotalOrdersStream.listen((response) async {
          if (!mounted) return;

          if (response.status == Status.COMPLETED) {
            _fetchInProgress = false;
            _loadingDelayTimer?.cancel();
            _loadingDelayTimer = null;

            debugPrint(
                "OrdersScreen: Successfully fetched ${response.data!.ordersData.length} orders, Total Count: ${response.data!.orderTotalCount}");

            final deletedBox = StorageProvider.deletedOrders;
            final deletedMap = await deletedBox.toMap();

            setState(() {
              _pageOrders = response.data!.ordersData;

              _currentChunk = 1;

              // 👇 ALWAYS start with only chunkSize
              _visibleOrders = _pageOrders.take(_chunkSize).toList();
              _orders = _visibleOrders;

              _totalOrdersCount = response.data!.orderTotalCount;
              isLoading = false;

            // -------------------------------------------------------------
              // ⭐ MERGE OFFLINE DELETED ORDERS WITH USER FILTER LOGIC
              // -------------------------------------------------------------

              // Get selected user filter
              final String selectedUserId = _filterUsers
                  .firstWhere((e) => e.displayName == _selectedUserFilter)
                  .iD ??
                  "";

              if (deletedMap.isNotEmpty) {
                debugPrint("Merging ${deletedMap.length} deleted offline orders...");

                final deletedOrderModels = deletedMap.values.map((json) {
                  final map = Map<String, dynamic>.from(json);

                  // ⭐ FIX 1: Convert order_id → id
                  map["id"] ??= map["order_id"];

                  // ⭐ FIX 2: Convert created_at → date_created
                  if (map["created_at"] != null) {
                    map["date_created"] = map["created_at"]
                        .toString()
                        .replaceAll("T", " ")
                        .split(".")
                        .first;
                  }

                  final payable = (map["net_payable"] as num?)?.toDouble() ?? 0.0;

// ⭐ FINAL TOTAL (SHOW IN LIST)
                  map["total"] = payable.toStringAsFixed(2);


                  // ⭐ FIX 4: Force offline order meta
                  map["status"] = "cancelled";
                  map["order_type"] = "offline Order";
                  map["created_via"] = "offline Order";
                  map["createdVia"] = "offline Order";

                  // ⭐ FIX 5: USER & SHIFT LOGIC
                  final metaUserId =
                      _extractMeta(map, "user_id") ?? _extractMeta(map, "pos_placed_by");
                  map["user_id"] = metaUserId != null
                      ? int.tryParse(metaUserId.toString())
                      : -1;

                  map["createdBy"] = map["user_id"];
                  map["employee_name"] = map["employee_name"] ??
                      _extractMeta(map, "user_name") ??
                      "Offline User";
                  map["shift_id"] ??= _extractMeta(map, "shift_id") ?? -1;

                  // ⭐ USER FILTER APPLIED (MATCH ONLINE FILTER BEHAVIOR)
                  if (selectedUserId.isNotEmpty && selectedUserId != "All") {
                    if (map["user_id"].toString() != selectedUserId.toString()) {
                      return null; // ❌ Skip unrelated deleted order
                    }
                  }

                  try {
                    return model.OrderModel.fromJson(map);
                  } catch (e) {
                    debugPrint("❌ Error converting deleted order: $e\nMAP: $map");
                    return null;
                  }
                }).where((e) => e != null).cast<model.OrderModel>().toList();

                // ⭐ Remove duplicates
                final existingIds = _orders.map((o) => o.id ?? 0).toSet();
                final uniqueDeleted = deletedOrderModels.where((order) {
                  final deletedId = order.id ?? 0;
                  return !existingIds.contains(deletedId);
                }).toList();

                debugPrint("Added deleted offline orders: ${uniqueDeleted.length}");

                // ⭐ PREPEND offline deleted orders
                if (_currentPage == 1) {
                  _pageOrders = [...uniqueDeleted, ..._pageOrders];
                  _visibleOrders = _pageOrders.take(_chunkSize).toList();
                  _orders = _visibleOrders;
                }

                // ⭐ SORT latest first
                _orders.sort((a, b) {
                  final da = DateTime.tryParse(a.dateCreated ?? "") ?? DateTime(1970);
                  final db = DateTime.tryParse(b.dateCreated ?? "") ?? DateTime(1970);
                  return db.compareTo(da);
                });
              }

              // -------------------------------------------------------------

              if (_orders.isEmpty) {
                debugPrint("_orders empty:");
                OrderHelper().selectedOrderId = null;
                return;
              }

              if (OrderHelper().selectedOrderId == null ||
                  !_orders.any((order) =>
                  order.id == OrderHelper().selectedOrderId)) {
                OrderHelper().selectedOrderId = _orders.first.id;
                _onOrderRowSelected(OrderHelper().selectedOrderId!);
              } else {
                _onOrderRowSelected(OrderHelper().selectedOrderId!);
              }
            });
          }

          // ---------------- ERROR HANDLING ----------------
          else if (response.status == Status.ERROR) {
            _fetchInProgress = false;
            _loadingDelayTimer?.cancel();
            _loadingDelayTimer = null;

            if (response.message!.contains('Unauthorised')) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              debugPrint("OrdersScreen: Error fetching orders - ${response.message}");
              setState(() => isLoading = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(TextConstants.failedToFetchOrders),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }

          // ---------------- LOADING STATE (delayed to avoid flash for quick loads) ----------------
          else if (response.status == Status.LOADING) {
            _fetchInProgress = true;
            _loadingDelayTimer?.cancel();
            _loadingDelayTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted && _fetchInProgress) {
                setState(() => isLoading = true);
              }
            });
          }
        });

    // ---------------- API FILTER PARAMS ----------------
    var selectedStatus = _filterStatuses
        .firstWhere((element) => element.name == _selectedStatusFilter)
        .slug;

    var selectedUserId = _filterUsers
        .firstWhere((element) =>
    element.displayName == _selectedUserFilter)
        .iD ??
        "";

    var selectedOrderType = _filterOrderType
        .firstWhere((element) =>
    element.name == _selectedOrderTypeFilter)
        .slug ??
        "";

    DateFormat format = DateFormat('yyyy-MM-dd');
    String? startDateFormatted = '';
    String? endDateFormatted = '';

    if (_startDate != null) {
      startDateFormatted = format.format(_startDate!);
      endDateFormatted = format.format(_endDate!);
    }

    // API CALL
    _orderBloc.fetchTotalOrdersCount(
      allStatuses: true,
      pageNumber: _currentPage,
      pageLimit: _rowsPerPage,
      status: selectedStatus,
      orderType: selectedOrderType,
      userId: selectedUserId,
      startDate: startDateFormatted ?? '',
      endDate: endDateFormatted ?? '',
    );
  }

  // Sort orders based on column
  void _sortData(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }

      if (_sortColumn != null) {
        _orders.sort((a, b) {
          switch (column) {
            case 'id':
              return _isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
            case 'date':
              return _isAscending
                  ? a.dateCreated.compareTo(b.dateCreated)
                  : b.dateCreated.compareTo(a.dateCreated);
            case 'time':
              return _isAscending
                  ? a.dateCreated.compareTo(b.dateCreated)
                  : b.dateCreated.compareTo(a.dateCreated);
            case 'sales_amount':
              final aValue = double.tryParse(a.total) ?? 0.0;
              final bValue = double.tryParse(b.total) ?? 0.0;
              return _isAscending
                  ? aValue.compareTo(bValue)
                  : bValue.compareTo(aValue);
            case 'status':
              return _isAscending
                  ? a.status.compareTo(b.status)
                  : b.status.compareTo(a.status);
            default:
              return 0;
          }
        });
      }
    });
    debugPrint(
        "OrdersScreen: Sorted data by $column, ascending: $_isAscending");
  }

  // Extract sales amount from string
  double _extractSalesAmount(String sales) {
    return double.tryParse(sales.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  // Open range filter dialog
  void _openRangeFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Sales Amount Range"),
          content: SingleChildScrollView(
            child: RangeFilter(
              label: "Sales Amount",
              minValue: _minSalesAmount,
              maxValue: _maxSalesAmount,
              initialRange: _salesAmountRange,
              onRangeChanged: (range) {
                setState(() {
                  _salesAmountRange = range;
                  debugPrint(
                      "OrdersScreen: Sales amount range updated to ${_salesAmountRange.start} - ${_salesAmountRange.end}");
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // Open date range picker dialog
  void _openDateRangePickerDialog() {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.secondaryBackground
              : null,
          title: const Text("Select Date Range"),
          content: SizedBox(
            height: 400,
            width: 350,
            child: SfDateRangePicker(
              onSelectionChanged: _onDateRangeSelectionChanged,
              selectionMode: DateRangePickerSelectionMode.range,
              initialSelectedRange: _startDate != null && _endDate != null
                  ? PickerDateRange(_startDate, _endDate)
                  : null,
              showActionButtons: true,
              onSubmit: (Object? value) {
                Navigator.pop(context);
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  // Handle date range selection
  void _onDateRangeSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is PickerDateRange) {
      final PickerDateRange range = args.value;
      final currentTime = DateTime.now(); // Get current time
      setState(() {
        //Build #1.0.134: integrated date filter
        _startDate = range.startDate != null
            ? DateTime(
                range.startDate!.year,
                range.startDate!.month,
                range.startDate!.day,
                currentTime.hour,
                currentTime.minute,
                currentTime.second)
            : null;
        _endDate = range.endDate != null
            ? DateTime(
                range.endDate!.year,
                range.endDate!.month,
                range.endDate!.day,
                currentTime.hour,
                currentTime.minute,
                currentTime.second)
            : range.startDate != null
                ? DateTime(
                    range.startDate!.year,
                    range.startDate!.month,
                    range.startDate!.day,
                    currentTime.hour,
                    currentTime.minute,
                    currentTime.second)
                : null;
        _isDateRangeApplied = _startDate != null && _endDate != null;
        _currentPage = 1;

        //  if(_isDateRangeApplied) {
        debugPrint("#### _isDateRangeApplied: $_isDateRangeApplied");
        debugPrint("Start Date: $_startDate");
        debugPrint("End Date: $_endDate");
        // Fetch new data with updated date range
        _fetchOrders();
        //   }
        debugPrint(
            "OrdersScreen: Date range selected from $_startDate to $_endDate");
      });
    }
  }

  // Clear all filters
  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = "All";
      _selectedUserFilter =
          "All"; // Changed from "User 1" to match initialization
      _selectedPaymentMethodFilter = "All";
      _selectedOrderTypeFilter = "All";
      _salesAmountRange = RangeValues(_minSalesAmount, _maxSalesAmount);
      _startDate = null;
      _endDate = null;
      _isDateRangeApplied = false;
      _currentPage = 1;
      _fetchOrders(); // Fetch new data with cleared filters
      debugPrint("OrdersScreen: Filters cleared");
    });
  }

  // Check if order date falls within selected range
  bool _isDateInRange(String dateCreated) {
    if (!_isDateRangeApplied || _startDate == null || _endDate == null) {
      return true;
    }

    final orderDate = DateTime.tryParse(dateCreated);
    if (orderDate == null) return true;

    final orderDateOnly =
        DateTime(orderDate.year, orderDate.month, orderDate.day);
    final startDateOnly =
        DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final endDateOnly =
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    return orderDateOnly
            .isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
        orderDateOnly.isBefore(endDateOnly.add(const Duration(days: 1)));
  }

  @override
  void dispose() {
    _fetchOrdersSubscription?.cancel();
    _loadingDelayTimer?.cancel();
    OrderHelper().selectedOrderId =
        null; // Build #1.0.248: remove selected order when leave the screen !
    _orderBloc.dispose();
    debugPrint("OrdersScreen: Disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("????? OrdersScreen: didChangeDependencies");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
      // Build #1.0.248: Only call _onOrderRowSelected if we don't have a preserved selection
      if (OrderHelper().selectedOrderId == null) {
        _onOrderRowSelected(-1);
      }

      ///initialise order panel
    });
  }

  // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
  void _refreshOrderList() {
    if (kDebugMode) print("_refreshOrderList called");
    OrderHelper.notifyOrderPanelToRefresh();
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // String formattedDate = DateFormat("EEE, MMM d' ${now.year}'").format(now);
    // String formattedTime = DateFormat('hh:mm a').format(now);
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Update filteredData where clause
    List<model.OrderModel> filteredData = _orders;

    // Pagination Logic
    final int totalItems = _totalOrdersCount; // Use API-provided total count
    final int totalPages = (totalItems / _rowsPerPage).ceil();
    final List<model.OrderModel> paginatedData =
        _orders; // Use _orders directly

    // Update isFilterApplied check
    bool isFilterApplied = _selectedStatusFilter != "All" ||
        _selectedUserFilter != "All" ||
        _selectedOrderTypeFilter != "All";
    bool isRangeFilterApplied = _salesAmountRange.start > _minSalesAmount ||
        _salesAmountRange.end < _maxSalesAmount;
    return Scaffold(
      body: Column(
        children: [
          // Top Bar
          TopBar(
            screen: Screen.ORDERS,
            onModeChanged: () async {
              /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
                newLayout = orderPanelPosition == OrderPanelPosition.left
                    ? SharedPreferenceTextConstants.navBottomOrderRight
                    : SharedPreferenceTextConstants.navLeftOrderRight;
              }

              // Update the notifier which will trigger _onLayoutChanged
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              // No need to call saveLayoutSelection here as it's handled in the notifier
              //_preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
              // update UI
              setState(() {});
            },
          ),
          const Divider(
            color: Colors.grey,
            thickness: 0.4,
            height: 1,
          ),

          // Main Content
          Expanded(
            child: Row(
              children: [
                // Left Sidebar (Conditional)
                if (sidebarPosition == SidebarPosition.left)
                  custom_widgets.NavigationBar(
                    //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
                        debugPrint(
                            "OrdersScreen: Sidebar index changed to $index");
                      });
                    },
                    isVertical: true, // Vertical layout for left sidebar
                  ),

                // Order Panel on the Left (Conditional: Only when sidebar is right or bottom with left order panel)
                if (sidebarPosition == SidebarPosition.right ||
                    (sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  // Replace your OrderScreenPanel instances with:
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey(
                        'order_screen_panel_${OrderHelper().selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate:
                        panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: OrderHelper().activeOrderId ??
                        OrderHelper().selectedOrderId,

                    /// <- ADDED NULL CHECK // BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-356]: Order items not displaying in Bottom Mode
                    refreshOrderList:
                        _refreshOrderList, // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                  ),

                SizedBox(
                  width: sidebarPosition == SidebarPosition.bottom ? 20 : null,
                ),
                // Main Content (Table layout View)
                Expanded(
                    child: Container(
                      margin: sidebarPosition == SidebarPosition.bottom
                          ? const EdgeInsets.fromLTRB(2, 8, 2, 8)
                          : const EdgeInsets.fromLTRB(2, 12, 0, 12),
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.primaryBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                  child: Column(
                    //mainAxisAlignment: MainAxisAlignment.start,
                    // crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Filters
                      Row(
                        children: [
                          Spacer(),
                          Wrap(
                            spacing: 8.0,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            alignment: WrapAlignment.end,
                            runAlignment: WrapAlignment.end,
                            children: [
                              // User Filter
                              FilterChipWidget(
                                label: "User",
                                options: _filterUsers
                                    .map((filter) => filter.displayName ?? "")
                                    .toList(),
                                selectedValue: _selectedUserFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedUserFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint(
                                        "OrdersScreen: User filter changed to $value");
                                  });
                                },
                              ),
                              // Order Type Filter
                              FilterChipWidget(
                                label: "OrderType",
                                options: _filterOrderType
                                    .map((e) => e.name)
                                    .toList(),
                                selectedValue: _selectedOrderTypeFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedOrderTypeFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint(
                                        "OrdersScreen: Order type filter changed to $value");
                                  });
                                },
                              ),
                              // Status Filter
                              FilterChipWidget(
                                label: "Status",
                                options: _filterStatuses
                                    .map((filter) => filter.name)
                                    .toList(),
                                selectedValue: _selectedStatusFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedStatusFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint(
                                        "OrdersScreen: Status filter changed to $value");
                                  });
                                },
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(vertical: 10),
                                child: GestureDetector(
                                  onTap: _openDateRangePickerDialog,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // if (_isDateRangeApplied) ...[
                                      //   Text(
                                      //     "${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}",
                                      //     style: TextStyle(
                                      //       color: _isDateRangeApplied ? Colors.white : Colors.black,
                                      //       fontSize: 14,
                                      //     ),
                                      //   ),
                                      //   const SizedBox(width: 8),
                                      // ],
                                      SvgPicture.asset(
                                        'assets/svg/filter_calendar.svg',
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.1,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.06,
                                        colorFilter: ColorFilter.mode(
                                          _isDateRangeApplied
                                              ? Colors.redAccent
                                              : themeHelper.themeMode ==
                                                      ThemeMode.dark
                                                  ? Colors.grey
                                                  : Color(0xFF6F6F70),
                                          BlendMode.srcIn,
                                        ),
                                        //color: _isDateRangeApplied ? Colors.white : Colors.black,
                                      ),
                                      // if (!_isDateRangeApplied) ...[
                                      //   const SizedBox(width: 8),
                                      //   Text(
                                      //     "Date Range",
                                      //     style: TextStyle(
                                      //       color: Colors.black,
                                      //       fontSize: 14,
                                      //     ),
                                      //   ),
                                      // ],
                                    ],
                                  ),
                                ),
                              ),
                              // Clear Filters
                              if (isFilterApplied ||
                                  isRangeFilterApplied ||
                                  _isDateRangeApplied)
                                Container(
                                  margin: EdgeInsets.symmetric(vertical: 5),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isFilterApplied ||
                                              isRangeFilterApplied ||
                                              _isDateRangeApplied
                                          ? Colors.redAccent
                                          : Colors.black,
                                    ),
                                    onPressed: _clearFilters,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Data Table and Pagination controls
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Container(
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.primaryBackground
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),

                          // 🔥 Horizontal scroll ONLY
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Column(
                              children: [
                                // ================= HEADER =================
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: themeHelper.themeMode == ThemeMode.dark
                                        ? const Color(0xFF252837)
                                        : const Color(0xFF6F6F70),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildSortableColumn("ID", 'id'),
                                      _buildSortableColumn("Order Type", 'orderType'),
                                      _buildSortableColumn("Date", 'date'),
                                      _buildSortableColumn("Time", 'time'),
                                      _buildSortableColumn("Total", 'sales_amount'),
                                      _buildSortableColumn("Status", 'status'),
                                    ],
                                  ),
                                ),

                                // ================= BODY =================
                                Expanded(
                                  child: ListView.builder(
                                    controller: _tableScrollController,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount:
                                    _orders.length + (_hasMoreLazyData ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // 🔥 Lazy loader
                                      if (index >= _orders.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          child: Center(
                                            child: SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final order = _orders[index];
                                      final date = DateTime.tryParse(order.dateCreated)
                                          ?.toLocal();
                                      final isSelected =
                                          OrderHelper().selectedOrderId == order.id;

                                      final double total = double.tryParse(order.total.toString()) ?? 0.0;


                                      return GestureDetector(
                                        onTap: () => _onOrderRowSelected(order.id),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (themeHelper.themeMode == ThemeMode.dark
                                                ? const Color(0xFF383B4C)
                                                : const Color(0xFFDFDFDF))
                                                : (themeHelper.themeMode == ThemeMode.dark
                                                ? const Color(0xFF201F29)
                                                : const Color(0xFFF9F9F9)),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: themeHelper.themeMode == ThemeMode.dark
                                                    ? const Color(0xFF474646)
                                                    : const Color(0xFFD8D7D7),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildDataCell(order.id.toString()),
                                              _buildDataCell(
                                                _filterOrderType
                                                    .firstWhere(
                                                      (e) =>
                                                  e.slug ==
                                                      order.createdVia.toString(),
                                                )
                                                    .name,
                                              ),
                                              _buildDataCell(
                                                date != null
                                                    ? DateFormat(
                                                    TextConstants.dateFormat)
                                                    .format(date)
                                                    : '',
                                              ),
                                              _buildDataCell(
                                                date != null
                                                    ? DateFormat('HH:mm:ss').format(date)
                                                    : '',
                                              ),
                                              _buildDataCell(
                                                '${total < 0 ? '-' : ''}${order.currencySymbol}${total.abs().toStringAsFixed(2)}',
                                              ),
                                              _buildDataCell(
                                                order.status,
                                                isStatus: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ADDED: Pagination Controls
                      //if (!isLoading && totalItems > 0)
                      if (!isLoading && _totalOrdersCount > _rowsPerPage)
                        _buildPaginationControls(totalItems, totalPages),
                    ],
                  ),
                ),
                ),

                if (sidebarPosition == SidebarPosition.bottom)
                  SizedBox(
                    width:
                        sidebarPosition == SidebarPosition.bottom ? 20 : null,
                  ),
                // Order Panel on the Right
                if (sidebarPosition != SidebarPosition.right &&
                    !(sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  // Replace your OrderScreenPanel instances with:
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey(
                        'order_screen_panel_${OrderHelper().selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate:
                        panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: OrderHelper().activeOrderId ??
                        OrderHelper().selectedOrderId,

                    /// <- ADDED NULL CHECK // BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-356]: Order items not displaying in Bottom Mode
                    refreshOrderList:
                        _refreshOrderList, // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                  ),

                // Right Sidebar
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
                        debugPrint(
                            "OrdersScreen: Sidebar index changed to $index");
                      });
                    },
                    isVertical: true,
                  ),
              ],
            ),
          ),

          // Bottom Sidebar
          if (sidebarPosition == SidebarPosition.bottom)
            custom_widgets.NavigationBar(
              selectedSidebarIndex: _selectedSidebarIndex,
              onSidebarItemSelected: (index) {
                setState(() {
                  _selectedSidebarIndex = index;
                  debugPrint("OrdersScreen: Sidebar index changed to $index");
                });
              },
              isVertical: false,
            ),
        ],
      ),
    );
  }

  // method to handle row selection
  void _onOrderRowSelected(int orderId) async {
    debugPrint("OrdersScreen: _onOrderRowSelected id $orderId");

    // Build #1.0.248: Preserve the selection
    OrderHelper().selectedOrderId = orderId;
    // Explicitly declare selectedOrder as a nullable OrderModel
    model.OrderModel? selectedOrder;

    if (orderId == -1) {
      orderId = _orders.first
          .id; //Build #1.0.165: to fix issue in windows, not able to save lastActiveOrderID
      OrderHelper().selectedOrderId = orderId;
    }

    if (OrderHelper().selectedOrderId != null) {
      // Use indexWhere to safely find the index of the selected order.
      // It returns -1 if no element is found, preventing errors.
      final index = _orders
          .indexWhere((order) => order.id == OrderHelper().selectedOrderId);

      if (index != -1) {
        // If the index is valid, get the order from the list.
        selectedOrder = _orders[index];
      }
    }

    if (selectedOrder != null) {
      // If an order is selected, parse and format its date and time
      final date = DateTime.tryParse(selectedOrder.dateCreated)?.toLocal();
      if (date != null) {
        panelDate = DateFormat(TextConstants.dateFormat).format(date);
        panelTime = DateFormat('hh:mm a').format(date);
      } else {
        // Fallback if the date string is invalid
        panelDate = 'Invalid Date';
        panelTime = 'Invalid Time';
      }
    } else {
      // If no order is selected, default to the current date and time
      final now = DateTime.now();
      panelDate = DateFormat(TextConstants.dateFormat).format(now);
      panelTime = DateFormat('hh:mm a').format(now);
    }

    if (OrderHelper().activeOrderId != orderId) {
      // Create or switch to order tab in RightOrderPanel
      await OrderHelper().setActiveOrder(orderId);
      // Notify RightOrderPanel to refresh
      // Set the state with the selected order's ID
      setState(() {
        /// we don't have to use de-select order
        /// when ever changing theme on topBar , selected order preserve correctly , otherwise it will remove
        // // If the user taps the same row, you might want to deselect it
        // if (OrderHelper().selectedOrderId == orderId) {
        //   OrderHelper().selectedOrderId = null;
        //   // Consider clearing the helper as well if needed
        //   // OrderHelper().clearActiveOrder();
        // } else {
        //   OrderHelper().selectedOrderId = orderId;
        // }
      });
      debugPrint(
          "OrdersScreen: Selected order ID $OrderHelper().selectedOrderId");
    }
    setState(
        () {}); // Build #1.0.248: Force UI to update with the new selection
    // _orderScreenPanel = OrderScreenPanel( //Build #1.0.234: No need , we already setting values in widget build method
    //   key: ValueKey(orderId), // Use orderId as key
    //   formattedDate: panelDate ?? '', // Build #1.0.226: updated values
    //   formattedTime: panelTime ?? '',
    //   quantities: quantities,
    //   activeOrderId: orderId, // Pass activeOrderId
    //   fetchOrders: !isLoading,
    // );
    // _orderScreenPanel.setFormattedDate = panelDate;
    // _orderScreenPanel.setFormattedTime = panelTime;
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text("Rows per page:"),
          const SizedBox(width: 8),

          // ---------------- ROWS PER PAGE ----------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox.shrink(),
              items: _rowsPerPageOptions.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _rowsPerPage = newValue;
                    _currentPage = 1;

                    // 🔥 RESET LAZY STATE
                    _currentChunk = 1;
                    _pageOrders.clear();
                    _visibleOrders.clear();

                    _fetchOrders();
                  });
                }
              },
            ),
          ),

          const SizedBox(width: 24),

          // ---------------- PAGE INFO ----------------
          Text(
            totalItems == 0
                ? '0-0 of 0'
                : '${(_currentPage - 1) * _rowsPerPage + 1}'
                '-${(_currentPage * _rowsPerPage) > totalItems ? totalItems : (_currentPage * _rowsPerPage)}'
                ' of $totalItems',
          ),

          const SizedBox(width: 24),

          // ---------------- FIRST PAGE ----------------
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage == 1 || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage = 1;

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- PREVIOUS PAGE ----------------
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage == 1 || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage--;

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- NEXT PAGE ----------------
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage++;

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- LAST PAGE ----------------
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage = totalPages;

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),
        ],
      ),
    );
  }


  // Build sortable column header
  Widget _buildSortableColumn(String label, String columnKey) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 4.0),
        child: InkWell(
          onTap: () {
            _sortData(columnKey);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (_sortColumn == columnKey)
                Icon(
                  _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.blue,
                  size: 16,
                )
              else
                Icon(
                  Icons.unfold_more,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.white,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build header cell
  Widget _buildHeaderCell(String text) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.105,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Build data cell
  Widget _buildDataCell(String text, {bool isStatus = false}) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: isStatus
            ? StatusWidget(
                status: text,
                dotSize: 8.0,
                fontSize: 14.0,
              )
            : Text(
                text,
                style: TextStyle(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.black87,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
