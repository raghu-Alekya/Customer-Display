import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import 'package:flutter/services.dart';
>>>>>>> origin/Grocery_pch_api_integration
import 'package:flutter_svg/svg.dart';
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
<<<<<<< HEAD
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_pagination.dart';
=======
>>>>>>> origin/Grocery_pch_api_integration
import '../../Widgets/widget_range_filter.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Models/Orders/get_orders_model.dart' as model; // Added prefix
import '../../Repositories/Orders/order_repository.dart';
import '../../Helper/api_response.dart';
import '../../Constants/text.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;

<<<<<<< HEAD
import 'package:quickalert/quickalert.dart';

import '../Auth/login_screen.dart';

class TotalOrdersScreen extends StatefulWidget { // Build #1.0.226: updated class name
=======

/// Last successful Total Orders list for the same filters/page (instant paint on return).
class _TotalOrdersListCache {
  static String? _key;
  static List<model.OrderModel> _pageOrders = [];
  static int _totalCount = 0;

  static void update(
      String key,
      List<model.OrderModel> pageOrders,
      int totalCount,
      ) {
    _key = key;
    _pageOrders = List<model.OrderModel>.from(pageOrders);
    _totalCount = totalCount;
  }

  static bool restoreIfMatch(
      String key,
      void Function(List<model.OrderModel> orders, int totalCount) apply,
      ) {
    if (_key != key) return false;
    apply(List<model.OrderModel>.from(_pageOrders), _totalCount);
    return true;
  }
}

class TotalOrdersScreen extends StatefulWidget {
  // Build #1.0.226: updated class name
>>>>>>> origin/Grocery_pch_api_integration
  final int? lastSelectedIndex;

  const TotalOrdersScreen({super.key, this.lastSelectedIndex});

  @override
  State<TotalOrdersScreen> createState() => _OrdersScreenState();
}

<<<<<<< HEAD
class _OrdersScreenState extends State<TotalOrdersScreen> with LayoutSelectionMixin {
=======
class _OrdersScreenState extends State<TotalOrdersScreen>
    with LayoutSelectionMixin {
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD

  ///Filters
  // List<String> _availableStatuses = ["All"];
  final List<OrderStatus> _filterStatuses = [OrderStatus(slug: "", name: "All")];
  final List<Employees> _filterUsers = [Employees(iD: "",displayName: "All")];
  final List<OrderType> _filterOrderType = [OrderType(slug: "",name: "All")];

  Map<String, dynamic>? _selectedOrder;
  int? _selectedOrderId;
  final OrderHelper orderHelper = OrderHelper(); // Helper instance to manage orders
 // final PinakaPreferences _preferences = PinakaPreferences(); //Build #1.0.234: No need
=======
  bool _fetchInProgress = false;
  Timer? _loadingDelayTimer;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  ///Filters
  // List<String> _availableStatuses = ["All"];
  final List<OrderStatus> _filterStatuses = [
    OrderStatus(slug: "", name: "All")
  ];
  final List<Employees> _filterUsers = [Employees(iD: "", displayName: "All")];
  final List<OrderType> _filterOrderType = [OrderType(slug: "", name: "All")];

  // Page-level lazy loading
  final ScrollController _tableScrollController = ScrollController();

  List<model.OrderModel> _pageOrders = []; // full page data (20)
  List<model.OrderModel> _visibleOrders = []; // shown data (10 → 20)

  int _chunkSize = 10;
  int _currentChunk = 1;

  Map<String, dynamic>? _selectedOrder;
  // int? _selectedOrderId; // Build #1.0.248: right now saving in order helper class , because state level saving resetting after re build
  /// OrderHelper already singleton class , no need to create instance here again
  // final OrderHelper orderHelper = OrderHelper(); // Helper instance to manage orders
  // final PinakaPreferences _preferences = PinakaPreferences(); //Build #1.0.234: No need
>>>>>>> origin/Grocery_pch_api_integration
  // Date range filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeApplied = false;
  String? panelDate;
<<<<<<< HEAD
  String? panelTime;  // Build #1.0.226: UPDATED to widget level to class level declaration // ADD this logic to determine the date and time for the panel

=======
  String?
  panelTime; // Build #1.0.226: UPDATED to widget level to class level declaration // ADD this logic to determine the date and time for the panel
>>>>>>> origin/Grocery_pch_api_integration

  // Add these variables for pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];

<<<<<<< HEAD
=======
  // FIX #1: Track the last fetch sequence to cancel stale completions
  int _fetchSequence = 0;

  dynamic _extractMeta(Map map, String key) {
    if (map["request"]?["meta_data"] is List) {
      for (var m in map["request"]["meta_data"]) {
        if (m["key"] == key) return m["value"];
      }
    }
    return null;
  }

  /// Avoids [Iterable.firstWhere] when no match (e.g. filter lists still loading).
  OrderStatus _resolveStatusFilterEntry() {
    for (final e in _filterStatuses) {
      if (e.name == _selectedStatusFilter) return e;
    }
    if (_filterStatuses.isNotEmpty) return _filterStatuses.first;
    return OrderStatus(slug: "", name: "All");
  }

  Employees _resolveUserFilterEntry() {
    for (final e in _filterUsers) {
      if (e.displayName == _selectedUserFilter) return e;
    }
    if (_filterUsers.isNotEmpty) return _filterUsers.first;
    return Employees(iD: "", displayName: "All");
  }

  OrderType _resolveOrderTypeFilterEntry() {
    for (final e in _filterOrderType) {
      if (e.name == _selectedOrderTypeFilter) return e;
    }
    if (_filterOrderType.isNotEmpty) return _filterOrderType.first;
    return OrderType(slug: "", name: "All");
  }

  String _orderTypeLabelForOrder(model.OrderModel order) {
    final apiType = order.orderType?.trim() ?? '';
    final via = order.createdVia.toString().trim();
    final type = apiType.isNotEmpty ? apiType : via;
    for (final e in _filterOrderType) {
      if (e.slug == type) return e.name;
    }
    final normalized = type.toLowerCase();
    if (normalized == 'rest-api') return 'Shop Order';
    if (normalized.isEmpty) return '-';
    return type;
  }

  /// Same line items as the Total Orders API row — used to paint the right panel immediately.
  // List<model.LineItem>? _previewLineItemsForSelectedOrder() {
  //   final id = OrderHelper().selectedOrderId;
  //   if (id == null || id < 0) return null;
  //   for (final o in _pageOrders) {
  //     if (o.id == id) return o.lineItems;
  //   }
  //   for (final o in _orders) {
  //     if (o.id == id) return o.lineItems;
  //   }
  //   return null;
  // }

  /// Same line items as the Total Orders API row — used to paint the right panel immediately.
  List<model.LineItem>? _previewLineItemsForSelectedOrder() {
    final id = OrderHelper().selectedOrderId;
    if (id == null || id < 0) return null;

    // Priority: pageOrders (full data) > _orders
    for (final o in _pageOrders) {
      if (o.id == id) return o.lineItems;
    }
    for (final o in _orders) {
      if (o.id == id) return o.lineItems;
    }
    return null;
  }

  /// NEW: Enhanced preview order with better discount/tax handling
  model.OrderModel? _previewOrderForSelectedOrder() {
    final id = OrderHelper().selectedOrderId;
    if (id == null || id < 0) return null;

    for (final o in _pageOrders) {
      if (o.id == id) return o;
    }
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Same order object as the list row — hydrates panel status, discounts, and tags before SQLite sync.
  // model.OrderModel? _previewOrderForSelectedOrder() {
  //   final id = OrderHelper().selectedOrderId;
  //   if (id == null || id < 0) return null;
  //   for (final o in _pageOrders) {
  //     if (o.id == id) return o;
  //   }
  //   for (final o in _orders) {
  //     if (o.id == id) return o;
  //   }
  //   return null;
  // }

>>>>>>> origin/Grocery_pch_api_integration
  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 3;
    _orderBloc = OrderBloc(OrderRepository());
<<<<<<< HEAD
=======
    // Preserve POS context so when navigating back to Fast Keys/Categories/Add,
    // the order panel shows the order we were working on, not the order viewed here
    final oh = OrderHelper();
    if (oh.activeOrderId != null) {
      oh.saveLastActiveOrderId(oh.activeOrderId!);
    }
    _searchController.addListener(() {
      setState(() {}); // 🔥 Forces UI refresh for suffixIcon
    });
>>>>>>> origin/Grocery_pch_api_integration
    _minSalesAmount = 0.0;
    _maxSalesAmount = 10000.0; // Default max, will be updated from API
    _salesAmountRange = RangeValues(_minSalesAmount, _maxSalesAmount);
    initFilters();
<<<<<<< HEAD
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

=======
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cacheKey = _ordersFetchCacheKey();
      // FIX #2: Cache restore always selects the FIRST order, never a stale ID
      _TotalOrdersListCache.restoreIfMatch(cacheKey, (list, total) {
        if (!mounted) return;
        setState(() {
          _pageOrders = list;
          _currentChunk = 1;
          _visibleOrders = _pageOrders.take(_chunkSize).toList();
          _orders = _visibleOrders;
          _totalOrdersCount = total;
          isLoading = false;
        });
        final sourceOrders = _pageOrders.isNotEmpty ? _pageOrders : _orders;
        if (sourceOrders.isEmpty) {
          OrderHelper().selectedOrderId = null;
        } else {
          // FIX #2: Always default to FIRST order on cache restore
          final firstOrderId = sourceOrders.first.id;
          OrderHelper().selectedOrderId = firstOrderId;
          _onOrderRowSelected(firstOrderId);
        }
      });

      _fetchOrders();

      if (OrderHelper().selectedOrderId == null) {
        _onOrderRowSelected(-1);
      }
    });
  }

  bool get _hasMoreLazyData {
    if (_rowsPerPage <= _chunkSize) return false;

    final maxChunks = (_pageOrders.length / _chunkSize).ceil();
    return _currentChunk < maxChunks;
  }
>>>>>>> origin/Grocery_pch_api_integration

  Future<void> initFilters() async {
    var filterStatuses = await AssetDBHelper.instance.getOrderStatusList();
    filterStatuses.removeWhere((e) => e.slug == TextConstants.processing);
    _filterStatuses.addAll(filterStatuses);

    var filterUsers = await AssetDBHelper.instance.getEmployeeList();
    _filterUsers.addAll(filterUsers);

    var filterOrderType = await AssetDBHelper.instance.getOrderTypeList();
    _filterOrderType.addAll(filterOrderType);
  }

<<<<<<< HEAD
  //Build #1.0.54: added Fetch orders from API
  void _fetchOrders() {
    debugPrint("OrdersScreen: Initiating fetch orders");
    _fetchOrdersSubscription?.cancel();
    _fetchOrdersSubscription = _orderBloc.fetchTotalOrdersStream.listen((response) {
      if (!mounted) return;

      if (response.status == Status.COMPLETED) {
        debugPrint("OrdersScreen: Successfully fetched ${response.data!.ordersData.length} orders, Total Count: ${response.data!.orderTotalCount}");
        setState(() {
          _orders = response.data!.ordersData; //Build #1.0.134
          _totalOrdersCount = response.data!.orderTotalCount;
          isLoading = false;

          if (_orders.isEmpty) {
            _selectedOrderId = null; // Reset only if no orders
            return;
          }

          // Only set _selectedOrderId if it's null or not in the new _orders list
          if (_selectedOrderId == null || !_orders.any((order) => order.id == _selectedOrderId)) {
            _selectedOrderId = _orders.first.id;
            _onOrderRowSelected(_selectedOrderId!);
          }
        });
      } else if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Unauthorised : response.message ${response.message!}");
          }
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => LoginScreen()));

          if (kDebugMode) {
            print("message --- ${response.message}");
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Unauthorised. Session is expired on this device."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        else {
          debugPrint(
              "OrdersScreen: Error fetching orders - ${response.message}");
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextConstants.failedToFetchOrders),
              // Build #1.0.149 : added to constant & added background to red
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    else if (response.status == Status.LOADING) {
        setState(() => isLoading = true);
      }
    });

    var selectedStatus = _filterStatuses.firstWhere((element) => element.name == _selectedStatusFilter).slug;
    var selectedUserId = _filterUsers.firstWhere((element) => element.displayName == _selectedUserFilter).iD ?? "";
    var selectedOrderType = _filterOrderType.firstWhere((element) => element.name == _selectedOrderTypeFilter).slug ?? "";

    //Build #1.0.134: Format dates without milliseconds
    DateFormat format = DateFormat('yyyy-MM-dd'); // #Build 1.0.172 removed them (time - Thh:mm:ss), so that when applied date filter, data is fetching properly.
    String? startDateFormatted = '';//_startDate?.toString().split('.')[0];
    String? endDateFormatted = '';//_endDate?.toString().split('.')[0];
    if(_startDate != null){
=======
  /// Stable key for [_TotalOrdersListCache] (must match params sent to [OrderBloc.fetchTotalOrdersCount]).
  String _ordersFetchCacheKey() {
    final selectedStatus = _resolveStatusFilterEntry().slug ?? "";
    final selectedUserId = _resolveUserFilterEntry().iD ?? "";
    final selectedOrderType = _resolveOrderTypeFilterEntry().slug ?? "";
    final format = DateFormat('yyyy-MM-dd');
    final searchQuery = _searchController.text.trim(); // ✅ NO encoding
    String startDateFormatted = "";
    String endDateFormatted = "";
    if (_startDate != null && _endDate != null) {
      startDateFormatted = format.format(_startDate!);
      endDateFormatted = format.format(_endDate!);
    }
    return '${_currentPage}_${_rowsPerPage}_${selectedStatus}_${selectedUserId}_${selectedOrderType}_${startDateFormatted}_${endDateFormatted}_${searchQuery}';
  }

  void _fetchOrders() {
    debugPrint("OrdersScreen: Initiating fetch orders");
    debugPrint("🚀 Fetch Orders Called");

    // FIX #3: Increment sequence so any stale stream callbacks can be ignored
    final int mySequence = ++_fetchSequence;

    final String fetchCacheKey = _ordersFetchCacheKey();
    final searchQuery = _searchController.text.trim(); // ✅ NO encoding
    debugPrint("🔎 Search Query (RAW): $searchQuery");
    debugPrint("📄 Current Page: $_currentPage");

    debugPrint("🔥 FETCH CALLED AT: ${DateTime.now()}");
    _fetchOrdersSubscription?.cancel();
    _loadingDelayTimer?.cancel();
    _loadingDelayTimer = null;
    _fetchInProgress = false;

    _fetchOrdersSubscription =
        _orderBloc.fetchTotalOrdersStream.listen((response) {
          if (!mounted) return;
          // FIX #3: Ignore stale responses from previous fetch calls
          if (mySequence != _fetchSequence) return;

          if (response.status == Status.COMPLETED) {
            _fetchInProgress = false;
            _loadingDelayTimer?.cancel();
            _loadingDelayTimer = null;

            final orders = response.data?.ordersData ?? [];

            _TotalOrdersListCache.update(
              fetchCacheKey,
              orders,
              response.data?.orderTotalCount ?? 0,
            );

            setState(() {
              _pageOrders = orders;
              _currentChunk = 1;

              _visibleOrders = _pageOrders.take(_chunkSize).toList();
              _orders = _visibleOrders;

              _totalOrdersCount = response.data?.orderTotalCount ?? 0;
              isLoading = false;
            });

            // FIX #4: Always select FIRST order after every fetch
            // This fixes: new order arrives → 2nd order was selected instead of 1st
            final sourceOrders = _pageOrders.isNotEmpty ? _pageOrders : _orders;
            if (sourceOrders.isEmpty) {
              OrderHelper().selectedOrderId = null;
              return;
            }

            // Always select the first order in the list
            final int firstOrderId = sourceOrders.first.id;
            OrderHelper().selectedOrderId = firstOrderId;
            _onOrderRowSelected(firstOrderId);
          }

          // ERROR
          else if (response.status == Status.ERROR) {
            _fetchInProgress = false;
            _loadingDelayTimer?.cancel();
            _loadingDelayTimer = null;

            setState(() => isLoading = false);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to fetch orders"),
                backgroundColor: Colors.red,
              ),
            );
          }

          // LOADING
          else if (response.status == Status.LOADING) {
            _fetchInProgress = true;
            _loadingDelayTimer?.cancel();

            // Avoid full-screen loader when we already have rows (silent refresh).
            if (_pageOrders.isEmpty) {
              _loadingDelayTimer = Timer(
                const Duration(milliseconds: 300),
                    () {
                  if (mounted && _fetchInProgress) {
                    setState(() => isLoading = true);
                  }
                },
              );
            }
          }
        });

    // 🔥 Call Bloc (NOT repository directly)
    final selectedStatus = _resolveStatusFilterEntry().slug ?? "";

    final selectedUserId = _resolveUserFilterEntry().iD ?? "";

    final selectedOrderType = _resolveOrderTypeFilterEntry().slug ?? "";

    DateFormat format = DateFormat('yyyy-MM-dd');
    String startDateFormatted = "";
    String endDateFormatted = "";

    if (_startDate != null && _endDate != null) {
>>>>>>> origin/Grocery_pch_api_integration
      startDateFormatted = format.format(_startDate!);
      endDateFormatted = format.format(_endDate!);
    }

    _orderBloc.fetchTotalOrdersCount(
      allStatuses: true,
      pageNumber: _currentPage,
      pageLimit: _rowsPerPage,
      status: selectedStatus,
      orderType: selectedOrderType,
      userId: selectedUserId,
<<<<<<< HEAD
      startDate: startDateFormatted ?? '', //after=2025-07-22 01:08:35&  != 2025-07-1T17:28:09
      endDate: endDateFormatted ?? '', //before=2025-07-20 01:08:35&  != 2025-07-22T17:28:09
=======
      startDate: startDateFormatted,
      endDate: endDateFormatted,
      search: searchQuery,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
              return _isAscending
                  ? a.id.compareTo(b.id)
                  : b.id.compareTo(a.id);
=======
              return _isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
    debugPrint("OrdersScreen: Sorted data by $column, ascending: $_isAscending");
=======
    debugPrint(
        "OrdersScreen: Sorted data by $column, ascending: $_isAscending");
>>>>>>> origin/Grocery_pch_api_integration
  }

  // Extract sales amount from string
  double _extractSalesAmount(String sales) {
    return double.tryParse(sales.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  // Open range filter dialog
  void _openRangeFilterDialog() {
    showDialog(
      context: context,
<<<<<<< HEAD
=======
      barrierDismissible: false,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                  debugPrint("OrdersScreen: Sales amount range updated to ${_salesAmountRange.start} - ${_salesAmountRange.end}");
=======
                  debugPrint(
                      "OrdersScreen: Sales amount range updated to ${_salesAmountRange.start} - ${_salesAmountRange.end}");
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.secondaryBackground : null,
=======
      barrierDismissible: false,

      builder: (context) {
        return AlertDialog(
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.secondaryBackground
              : null,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
      setState(() { //Build #1.0.134: integrated date filter
        _startDate = range.startDate != null
            ? DateTime(range.startDate!.year, range.startDate!.month, range.startDate!.day, currentTime.hour, currentTime.minute, currentTime.second)
            : null;
        _endDate = range.endDate != null
            ? DateTime(range.endDate!.year, range.endDate!.month, range.endDate!.day, currentTime.hour, currentTime.minute, currentTime.second)
            : range.startDate != null
            ? DateTime(range.startDate!.year, range.startDate!.month, range.startDate!.day, currentTime.hour, currentTime.minute, currentTime.second)
=======
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
>>>>>>> origin/Grocery_pch_api_integration
            : null;
        _isDateRangeApplied = _startDate != null && _endDate != null;
        _currentPage = 1;

<<<<<<< HEAD
      //  if(_isDateRangeApplied) {
          debugPrint("#### _isDateRangeApplied: $_isDateRangeApplied");
          debugPrint("Start Date: $_startDate");
          debugPrint("End Date: $_endDate");
          // Fetch new data with updated date range
          _fetchOrders();
     //   }
        debugPrint("OrdersScreen: Date range selected from $_startDate to $_endDate");
=======
        debugPrint("#### _isDateRangeApplied: $_isDateRangeApplied");
        debugPrint("Start Date: $_startDate");
        debugPrint("End Date: $_endDate");
        // Fetch new data with updated date range
        _fetchOrders();
        debugPrint(
            "OrdersScreen: Date range selected from $_startDate to $_endDate");
>>>>>>> origin/Grocery_pch_api_integration
      });
    }
  }

  // Clear all filters
  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = "All";
<<<<<<< HEAD
      _selectedUserFilter = "All"; // Changed from "User 1" to match initialization
=======
      _selectedUserFilter =
      "All"; // Changed from "User 1" to match initialization
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
    final orderDateOnly = DateTime(orderDate.year, orderDate.month, orderDate.day);
    final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    return orderDateOnly.isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
=======
    final orderDateOnly =
    DateTime(orderDate.year, orderDate.month, orderDate.day);
    final startDateOnly =
    DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final endDateOnly =
    DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    return orderDateOnly
        .isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
>>>>>>> origin/Grocery_pch_api_integration
        orderDateOnly.isBefore(endDateOnly.add(const Duration(days: 1)));
  }

  @override
  void dispose() {
    _fetchOrdersSubscription?.cancel();
<<<<<<< HEAD
    _orderBloc.dispose();
=======
    _loadingDelayTimer?.cancel();
    OrderHelper().selectedOrderId =
    null; // Build #1.0.248: remove selected order when leave the screen !
    _orderBloc.dispose();
    _searchController.dispose();
>>>>>>> origin/Grocery_pch_api_integration
    debugPrint("OrdersScreen: Disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("????? OrdersScreen: didChangeDependencies");
<<<<<<< HEAD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
      _onOrderRowSelected(-1);
      ///initialise order panel
    });
  }
 // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
 void _refreshOrderList() {
   if (kDebugMode) print("_refreshOrderList called");
  //  setState(() {
   _fetchOrders();
  //  });
=======
  }

  // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
  void _refreshOrderList() {
    if (kDebugMode) print("_refreshOrderList called");

    if (!isLoading) {
      setState(() => isLoading = true);
    }

    OrderHelper.notifyOrderPanelToRefresh();
    _fetchOrders();   // This already handles loading via stream
>>>>>>> origin/Grocery_pch_api_integration
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
<<<<<<< HEAD
    // String formattedDate = DateFormat("EEE, MMM d' ${now.year}'").format(now);
    // String formattedTime = DateFormat('hh:mm a').format(now);
=======
>>>>>>> origin/Grocery_pch_api_integration
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Update filteredData where clause
    List<model.OrderModel> filteredData = _orders;

    // Pagination Logic
    final int totalItems = _totalOrdersCount; // Use API-provided total count
    final int totalPages = (totalItems / _rowsPerPage).ceil();
<<<<<<< HEAD
    final List<model.OrderModel> paginatedData = _orders; // Use _orders directly

    // Update isFilterApplied check
    bool isFilterApplied = _selectedStatusFilter != "All" || _selectedUserFilter != "All" ||
=======
    final List<model.OrderModel> paginatedData =
        _orders; // Use _orders directly

    // Update isFilterApplied check
    bool isFilterApplied = _selectedStatusFilter != "All" ||
        _selectedUserFilter != "All" ||
>>>>>>> origin/Grocery_pch_api_integration
        _selectedOrderTypeFilter != "All";
    bool isRangeFilterApplied = _salesAmountRange.start > _minSalesAmount ||
        _salesAmountRange.end < _maxSalesAmount;
    return Scaffold(
      body: Column(
        children: [
          // Top Bar
          TopBar(
            screen: Screen.ORDERS,
<<<<<<< HEAD
            onModeChanged: () async{ /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
              String newLayout;
                if (sidebarPosition == SidebarPosition.left) {
                  newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
                } else if (sidebarPosition == SidebarPosition.right) {
                  newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
                } else {
                  newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
                }

                // Update the notifier which will trigger _onLayoutChanged
                PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                // No need to call saveLayoutSelection here as it's handled in the notifier
                //_preferences.saveLayoutSelection(newLayout);
                //Build #1.0.122: update layout mode change selection to DB
                await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
=======
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
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                        debugPrint("OrdersScreen: Sidebar index changed to $index");
=======
                        debugPrint(
                            "OrdersScreen: Sidebar index changed to $index");
>>>>>>> origin/Grocery_pch_api_integration
                      });
                    },
                    isVertical: true, // Vertical layout for left sidebar
                  ),

                // Order Panel on the Left (Conditional: Only when sidebar is right or bottom with left order panel)
                if (sidebarPosition == SidebarPosition.right ||
                    (sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
<<<<<<< HEAD
                // Replace your OrderScreenPanel instances with:
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey('order_screen_panel_${_selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate: panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: orderHelper.activeOrderId ?? _selectedOrderId,  /// <- ADDED NULL CHECK // BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-356]: Order items not displaying in Bottom Mode
                    refreshOrderList: _refreshOrderList, // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                  ),

                SizedBox(
                  width: sidebarPosition == SidebarPosition.bottom ? 0 : null,
                ),
                // Main Content (Table layout View)
                Expanded(
                    child: Container(
                      margin: sidebarPosition == SidebarPosition.bottom
                          ? EdgeInsets.zero
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
                                options: _filterUsers.map((filter) => filter.displayName ?? "").toList(),
                                selectedValue: _selectedUserFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedUserFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint("OrdersScreen: User filter changed to $value");
                                  });
                                },
                              ),
                              // Order Type Filter
                              FilterChipWidget(
                                label: "OrderType",
                                options: _filterOrderType.map((e) => e.name).toList(),
                                selectedValue: _selectedOrderTypeFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedOrderTypeFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint("OrdersScreen: Order type filter changed to $value");
                                  });
                                },
                              ),
                              // Status Filter
                              FilterChipWidget(
                                label: "Status",
                                options: _filterStatuses.map((filter) => filter.name).toList(),
                                selectedValue: _selectedStatusFilter,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedStatusFilter = value;
                                    _currentPage = 1;
                                    _fetchOrders();
                                    debugPrint("OrdersScreen: Status filter changed to $value");
                                  });
                                },
                              ),
                             // Range Filter
                              // Container(
                              //   height: MediaQuery.of(context).size.height * 0.06,
                              //   margin: EdgeInsets.symmetric(vertical: 10),
                              //   padding: const EdgeInsets.symmetric(horizontal: 4),
                              //   child: ChoiceChip(
                              //     shape: const RoundedRectangleBorder(
                              //       side: BorderSide(color: Colors.black),
                              //       borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              //     ),
                              //     visualDensity: VisualDensity.compact,
                              //     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              //     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              //     label: Row(
                              //       mainAxisSize: MainAxisSize.min,
                              //       children: [
                              //         Text(
                              //           "Select Range",
                              //           style: TextStyle(
                              //             color: isRangeFilterApplied
                              //                 ? Colors.white
                              //                 : Colors.black,
                              //           ),
                              //         ),
                              //         const SizedBox(width: 4),
                              //         Icon(
                              //           Icons.filter_list,
                              //           size: 18,
                              //           color: isRangeFilterApplied
                              //               ? Colors.white
                              //               : Colors.black,
                              //         ),
                              //       ],
                              //     ),
                              //     showCheckmark: false,
                              //     selected: isRangeFilterApplied,
                              //     selectedColor: Colors.redAccent,
                              //     backgroundColor: Colors.grey[200],
                              //     onSelected: (selected) {
                              //       _openRangeFilterDialog();
                              //       _currentPage = 1;
                              //     },
                              //   ),
                              // ),
                              // Date Range Filter
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
                                        width: MediaQuery.of(context).size.width * 0.1,
                                        height: MediaQuery.of(context).size.height * 0.06,
                                        colorFilter: ColorFilter.mode(
                                          _isDateRangeApplied ? Colors.redAccent :themeHelper.themeMode == ThemeMode.dark
                                              ? Colors.grey : Color(0xFF6F6F70),
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
                              if (isFilterApplied || isRangeFilterApplied || _isDateRangeApplied)
                                Container(
                                  margin:EdgeInsets.symmetric(vertical: 5),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isFilterApplied || isRangeFilterApplied || _isDateRangeApplied
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
                      const SizedBox(height: 10),

                      // Data Table and Pagination controls
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Container(
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.primaryBackground
                                : Colors.white, // 🔹 White background for whole table
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
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Table Header with colored container
                                  Container(
                                    padding: const EdgeInsets.only(left: 0.0, top: 12.0, bottom: 12.0),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode == ThemeMode.dark
                                          ? const Color(0xFF252837) // Dark mode → #252837
                                          : const Color(0xFF6F6F70), // Light mode → #6F6F70
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(0),
                                        bottomRight: Radius.circular(0),
                                      ),
                                      border: Border.all(color:themeHelper.themeMode == ThemeMode.dark
                                          ? ThemeNotifier.borderColor : Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        _buildSortableColumn("ID", 'id'),
                                        _buildSortableColumn("Order Type", 'orderType'),
                                        _buildSortableColumn("Date", 'date'),
                                        _buildSortableColumn("Time", 'time'),
                                        _buildSortableColumn("Total", 'sales_amount'), //Build #1.0.134: changed to "Total"
                                        _buildSortableColumn("Status", 'status'),
                                        //_buildHeaderCell(""),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Data Rows
                                  //...filteredData.map((order)
                                  ...paginatedData.map((order){
                                    final date = DateTime.tryParse(order.dateCreated)?.toLocal();
                                    final formattedDate = date != null
                                        ? DateFormat("EEE, MMM d' '${now.year}'").format(date)
                                        : '';
                                    final formattedTime = date != null
                                        ? DateFormat('HH:mm:ss').format(date)
                                        : '';
                                    final isSelected = orderHelper.activeOrderId == order.id; // Check if the row is selected

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 0),
                                      child: GestureDetector( // Add GestureDetector for row click
                                        onTap: () => _onOrderRowSelected(order.id),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (themeHelper.themeMode == ThemeMode.dark
                                                ? Color(0xFF383B4C)  // Dark selection color for dark mode 334756
                                                : Color(0xFFDFDFDF)) // Light selection color for light mode F3ECEC
                                                : (themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.primaryBackground
                                                : Colors.white),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(0),
                                              topRight: Radius.circular(0),
                                              bottomLeft: Radius.circular(0),
                                              bottomRight: Radius.circular(0),
                                            ),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: themeHelper.themeMode == ThemeMode.dark
                                                    ? const Color(0xFF474646) // Dark mode bottom border
                                                    : const Color(0xFFD8D7D7), // Light mode bottom border
                                                width: 1.0,
                                              ),
                                            ),
                                            // boxShadow: [
                                            // BoxShadow(
                                            // color: themeHelper.themeMode == ThemeMode.dark
                                            // ? ThemeNotifier.shadow_F7 : Color(0xFF000000).withValues(alpha: 0.2),
                                            //blurRadius: 2,
                                            //offset: const Offset(0, 0),
                                            // ),
                                            // ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              _buildDataCell(order.id.toString()),
                                              _buildDataCell(_filterOrderType.firstWhere((e) => e.slug == order.createdVia.toString()).name), //AppDBConst.orderType
                                              _buildDataCell(formattedDate),
                                              _buildDataCell(formattedTime),
                                              _buildDataCell('${order.currencySymbol}${order.total}'),
                                              //  _buildDataCell('N/A'), // Over/short not in API response
                                              _buildDataCell(order.status, isStatus: true),
                                              // Add action buttons if needed
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  // Show message when no data available
                                  if (paginatedData.isEmpty && filteredData.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      child: Center(
                                        child: Text(
                                          'No orders found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.textDark : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Show message when filters result in no data
                                  if (paginatedData.isEmpty && filteredData.isEmpty && _orders.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      child: Center(
                                        child: Text(
                                          'No orders match the selected filters',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: themeHelper.themeMode == ThemeMode.dark
                                                ? ThemeNotifier.textDark : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
=======
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey(
                        'order_screen_panel_${OrderHelper().selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate:
                    panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: OrderHelper().selectedOrderId ??
                        OrderHelper().activeOrderId,
                    previewLineItemsFromApi:
                    _previewLineItemsForSelectedOrder(),
                    previewOrderFromApi: _previewOrderForSelectedOrder(),

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
                      children: [
                        // Filters
                        Row(
                          children: [
                            Spacer(),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.085,
                              child: Container(
                                width: 180,
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _searchController.text.isNotEmpty
                                      ? Colors.redAccent
                                      : themeHelper.themeMode == ThemeMode.dark
                                      ? const Color(0xFF252837)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: themeHelper.themeMode == ThemeMode.dark
                                        ? ThemeNotifier.borderColor
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 18,
                                      color: _searchController.text.isNotEmpty
                                          ? Colors.white
                                          : themeHelper.themeMode == ThemeMode.dark
                                          ? ThemeNotifier.textDark
                                          : Colors.black,
                                    ),

                                    const SizedBox(width: 6),

                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        textAlignVertical: TextAlignVertical.center,
                                        onChanged: (value) {
                                          print("🔍 User typed: $value");

                                          _searchDebounce?.cancel();

                                          _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                                            if (!mounted) return;

                                            print("⏱ Debounced: ${_searchController.text}");

                                            setState(() {
                                              _currentPage = 1;
                                            });

                                            _fetchOrders();
                                          });
                                        },
                                        style: TextStyle(
                                          color: _searchController.text.isNotEmpty
                                              ? Colors.white
                                              : themeHelper.themeMode == ThemeMode.dark
                                              ? ThemeNotifier.textDark
                                              : Colors.black,
                                          fontSize: 13,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: "Search Order ID",
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),

                                    // ✅ CLEAR BUTTON
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          print("❌ Clear button clicked");

                                          _searchDebounce?.cancel();

                                          _searchController.clear();

                                          setState(() {
                                            _currentPage = 1;
                                            _orders.clear();
                                            _pageOrders.clear();
                                            _visibleOrders.clear();
                                          });

                                          _fetchOrders();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.close, size: 18, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20,),
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
                                        SvgPicture.asset(
                                          'assets/svg/filter_calendar.svg',
                                          width: MediaQuery.of(context)
                                              .size
                                              .width *
                                              0.1,
                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
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
                                        ),
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
                              color:
                              themeHelper.themeMode == ThemeMode.dark
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode ==
                                          ThemeMode.dark
                                          ? const Color(0xFF252837)
                                          : const Color(0xFF6F6F70),
                                      borderRadius:
                                      const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildSortableColumn("ID", 'id'),
                                        _buildSortableColumn(
                                            "Order Type", 'orderType'),
                                        _buildSortableColumn(
                                            "Date", 'date'),
                                        _buildSortableColumn(
                                            "Time", 'time'),
                                        _buildSortableColumn(
                                            "Total", 'sales_amount'),
                                        _buildSortableColumn(
                                            "Status", 'status'),
                                      ],
                                    ),
                                  ),

                                  // ================= BODY =================
                                  Expanded(
                                    child: _orders.isEmpty
                                        ? Center(
                                      child: Text(
                                        _searchController.text.isNotEmpty
                                            ? "No orders found"
                                            : "No orders available",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    )
                                        : ListView.builder(
                                      controller: _tableScrollController,
                                      physics:
                                      const BouncingScrollPhysics(),
                                      itemCount: _orders.length +
                                          (_hasMoreLazyData ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        // 🔥 Lazy loader
                                        if (index >= _orders.length) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Center(
                                              child: SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        final order = _orders[index];
                                        final date = DateTime.tryParse(
                                            order.dateCreated)
                                            ?.toLocal();
                                        final isSelected = OrderHelper()
                                            .selectedOrderId ==
                                            order.id;

                                        final double total =
                                            double.tryParse(order.total
                                                .toString()) ??
                                                0.0;

                                        return GestureDetector(
                                          onTap: () =>
                                              _onOrderRowSelected(
                                                  order.id),
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (themeHelper
                                                  .themeMode ==
                                                  ThemeMode.dark
                                                  ? const Color(
                                                  0xFF383B4C)
                                                  : const Color(
                                                  0xFFDFDFDF))
                                                  : (themeHelper
                                                  .themeMode ==
                                                  ThemeMode.dark
                                                  ? const Color(
                                                  0xFF201F29)
                                                  : const Color(
                                                  0xFFF9F9F9)),
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: themeHelper
                                                      .themeMode ==
                                                      ThemeMode.dark
                                                      ? const Color(
                                                      0xFF474646)
                                                      : const Color(
                                                      0xFFD8D7D7),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _buildDataCell(
                                                    order.id.toString()),
                                                _buildDataCell(
                                                  _orderTypeLabelForOrder(
                                                      order),
                                                ),
                                                _buildDataCell(
                                                  date != null
                                                      ? DateFormat(
                                                      TextConstants
                                                          .dateFormat)
                                                      .format(date)
                                                      : '',
                                                ),
                                                _buildDataCell(
                                                  date != null
                                                      ? DateFormat(
                                                      'HH:mm:ss')
                                                      .format(date)
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
>>>>>>> origin/Grocery_pch_api_integration
                                ],
                              ),
                            ),
                          ),
                        ),
<<<<<<< HEAD
                      ),
                      // ADDED: Pagination Controls
                      //if (!isLoading && totalItems > 0)
                      if (!isLoading && _totalOrdersCount > _rowsPerPage)
                        _buildPaginationControls(totalItems, totalPages),
                      // REUSABLE PAGINATION WIDGET
                      // PaginationWidget(
                      //   currentPage: _currentPage,
                      //   totalItems: filteredData.length,
                      //   rowsPerPage: _rowsPerPage,
                      //   rowsPerPageOptions: _rowsPerPageOptions,
                      //   onPageChanged: (page) {
                      //     setState(() {
                      //       _currentPage = page;
                      //     });
                      //     debugPrint("OrdersScreen: Page changed to $page");
                      //   },
                      //   onRowsPerPageChanged: (rowsPerPage) {
                      //     setState(() {
                      //       _rowsPerPage = rowsPerPage;
                      //       _currentPage = 1; // Reset to first page
                      //     });
                      //     debugPrint("OrdersScreen: Rows per page changed to $rowsPerPage");
                      //   },
                      //   showFirstLastButtons: true,
                      //   showPageNumbers: true,
                      //   emptyMessage: "No orders found",
                      //   // Optional customization
                      //   backgroundColor: Colors.grey[50],
                      //   textStyle: const TextStyle(fontSize: 14, color: Colors.black87),
                      //   buttonColor: Colors.blue,
                      //   disabledButtonColor: Colors.grey,
                      // ),
                    ],
                  ),
                ),
                ),

                if(sidebarPosition == SidebarPosition.bottom)
                  SizedBox(
                    width: sidebarPosition == SidebarPosition.bottom ? 20 : null,
=======

                        // ADDED: Pagination Controls
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
>>>>>>> origin/Grocery_pch_api_integration
                  ),
                // Order Panel on the Right
                if (sidebarPosition != SidebarPosition.right &&
                    !(sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
<<<<<<< HEAD
                // Replace your OrderScreenPanel instances with:
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey('order_screen_panel_${_selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate: panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: orderHelper.activeOrderId ?? _selectedOrderId,  /// <- ADDED NULL CHECK // BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-356]: Order items not displaying in Bottom Mode
                    refreshOrderList: _refreshOrderList, // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                  ),

=======
                  OrderScreenPanel(
                    fetchOrders: !isLoading, // Sync with parent's loading state
                    key: ValueKey(
                        'order_screen_panel_${OrderHelper().selectedOrderId}_${sidebarPosition}_$orderPanelPosition'), //Build #1.0.234: Fixed Issue -> Processing Orders showing in order screen bottom mode
                    formattedDate:
                    panelDate ?? '', // Build #1.0.226: updated values
                    formattedTime: panelTime ?? '',
                    quantities: quantities,
                    activeOrderId: OrderHelper().selectedOrderId ??
                        OrderHelper().activeOrderId,
                    previewLineItemsFromApi:
                    _previewLineItemsForSelectedOrder(),
                    previewOrderFromApi: _previewOrderForSelectedOrder(),

                    /// <- ADDED NULL CHECK // BUILD 1.0.213: FIXED RE-OPENED ISSUE [SCRUM-356]: Order items not displaying in Bottom Mode
                    refreshOrderList:
                    _refreshOrderList, // Build #1.0.143: Fixed Issue : After return from order summary screen , total order screen not refreshing with updated response
                  ),
>>>>>>> origin/Grocery_pch_api_integration

                // Right Sidebar
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
<<<<<<< HEAD
                        debugPrint("OrdersScreen: Sidebar index changed to $index");
=======
                        debugPrint(
                            "OrdersScreen: Sidebar index changed to $index");
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
  // method to handle row selection
  void _onOrderRowSelected(int orderId) async {
    debugPrint("OrdersScreen: _onOrderRowSelected id $orderId");
    // Explicitly declare selectedOrder as a nullable OrderModel
    model.OrderModel? selectedOrder;

    if(orderId == -1){
      orderId = _orders.first.id; //Build #1.0.165: to fix issue in windows, not able to save lastActiveOrderID
    }

    if (_selectedOrderId != null) {
      // Use indexWhere to safely find the index of the selected order.
      // It returns -1 if no element is found, preventing errors.
      final index = _orders.indexWhere((order) => order.id == _selectedOrderId);

      if (index != -1) {
        // If the index is valid, get the order from the list.
        selectedOrder = _orders[index];
=======
  // FIX #6: Show loading when new order comes + improved refresh
  void _onOrderRowSelected(int orderId) async {
    debugPrint("OrdersScreen: _onOrderRowSelected id $orderId");

    // Build #1.0.248: Preserve the selection
    OrderHelper().selectedOrderId = orderId;

    // NEW: If this is called from refresh after new order, show loading
    bool shouldShowLoading = orderId == -1 ||
        (OrderHelper().selectedOrderId != null && _pageOrders.isEmpty);

    if (shouldShowLoading && !isLoading) {
      setState(() => isLoading = true);
    }

    // Explicitly declare selectedOrder as a nullable OrderModel
    model.OrderModel? selectedOrder;

    if (orderId == -1 && _orders.isNotEmpty) {
      orderId = _orders.first.id;
      OrderHelper().selectedOrderId = orderId;
    }

    if (OrderHelper().selectedOrderId != null) {
      final selectedId = OrderHelper().selectedOrderId!;
      // FIX #5: Search _pageOrders first (full dataset), then _orders (visible chunk)
      for (final order in _pageOrders) {
        if (order.id == selectedId) {
          selectedOrder = order;
          break;
        }
      }
      if (selectedOrder == null) {
        for (final order in _orders) {
          if (order.id == selectedId) {
            selectedOrder = order;
            break;
          }
        }
>>>>>>> origin/Grocery_pch_api_integration
      }
    }

    if (selectedOrder != null) {
<<<<<<< HEAD
      // If an order is selected, parse and format its date and time
      final date = DateTime.tryParse(selectedOrder.dateCreated)?.toLocal();
      if (date != null) {
        panelDate = DateFormat("EEE, MMM d, yyyy").format(date);
        panelTime = DateFormat('hh:mm a').format(date);
      } else {
        // Fallback if the date string is invalid
=======
      final date = DateTime.tryParse(selectedOrder.dateCreated)?.toLocal();
      if (date != null) {
        panelDate = DateFormat(TextConstants.dateFormat).format(date);
        panelTime = DateFormat('hh:mm a').format(date);
      } else {
>>>>>>> origin/Grocery_pch_api_integration
        panelDate = 'Invalid Date';
        panelTime = 'Invalid Time';
      }
    } else {
<<<<<<< HEAD
      // If no order is selected, default to the current date and time
      final now = DateTime.now();
      panelDate = DateFormat("EEE, MMM d, yyyy").format(now);
      panelTime = DateFormat('hh:mm a').format(now);
    }

    if (orderHelper.activeOrderId != orderId) {
      // Create or switch to order tab in RightOrderPanel
      await orderHelper.setActiveOrder(orderId);
      // Notify RightOrderPanel to refresh
      // Set the state with the selected order's ID
      setState(() {
        // If the user taps the same row, you might want to deselect it
        if (_selectedOrderId == orderId) {
          _selectedOrderId = null;
          // Consider clearing the helper as well if needed
          // orderHelper.clearActiveOrder();
        } else {
          _selectedOrderId = orderId;
        }
      });
      debugPrint("OrdersScreen: Selected order ID $_selectedOrderId");
    }
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

=======
      final now = DateTime.now();
      panelDate = DateFormat(TextConstants.dateFormat).format(now);
      panelTime = DateFormat('hh:mm a').format(now);
    }

    // Build #1.0.248: Force UI to update with the new selection
    setState(() {});

    debugPrint("OrdersScreen: Selected order ID ${OrderHelper().selectedOrderId}");
>>>>>>> origin/Grocery_pch_api_integration
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text("Rows per page:"),
          const SizedBox(width: 8),
<<<<<<< HEAD
=======

          // ---------------- ROWS PER PAGE ----------------
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                    _currentPage = 1; // Reset to first page
                    _fetchOrders(); // Fetch new data
=======
                    _currentPage = 1;

                    // 🔥 RESET LAZY STATE
                    _currentChunk = 1;
                    _pageOrders.clear();
                    _visibleOrders.clear();

                    _fetchOrders();
>>>>>>> origin/Grocery_pch_api_integration
                  });
                }
              },
            ),
          ),
<<<<<<< HEAD
          const SizedBox(width: 24),
          Text(
            totalItems == 0
                ? '0-0 of 0'
                : '${(_currentPage - 1) * _rowsPerPage + 1}-${(_currentPage * _rowsPerPage) > totalItems ? totalItems : (_currentPage * _rowsPerPage)} of $totalItems',
          ),
          const SizedBox(width: 24),
=======

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
>>>>>>> origin/Grocery_pch_api_integration
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage == 1 || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage = 1;
<<<<<<< HEAD
                _fetchOrders(); // Fetch new data
              });
            },
          ),
=======

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- PREVIOUS PAGE ----------------
>>>>>>> origin/Grocery_pch_api_integration
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage == 1 || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage--;
<<<<<<< HEAD
                _fetchOrders(); // Fetch new data
              });
            },
          ),
=======

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- NEXT PAGE ----------------
>>>>>>> origin/Grocery_pch_api_integration
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage++;
<<<<<<< HEAD
                _fetchOrders(); // Fetch new data
              });
            },
          ),
=======

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
              });
            },
          ),

          // ---------------- LAST PAGE ----------------
>>>>>>> origin/Grocery_pch_api_integration
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () {
              setState(() {
                _currentPage = totalPages;
<<<<<<< HEAD
                _fetchOrders(); // Fetch new data
=======

                // 🔥 RESET LAZY STATE
                _currentChunk = 1;
                _pageOrders.clear();
                _visibleOrders.clear();

                _fetchOrders();
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
      width: MediaQuery.of(context).size.width * 0.103,
=======
      width: MediaQuery.of(context).size.width * 0.100,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                        ? ThemeNotifier.textDark : Color(0xFFFFFFFF),
=======
                        ? ThemeNotifier.textDark
                        : Color(0xFFFFFFFF),
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                  color:  Colors.blue,
=======
                  color: Colors.blue,
>>>>>>> origin/Grocery_pch_api_integration
                  size: 16,
                )
              else
                Icon(
                  Icons.unfold_more,
                  color: themeHelper.themeMode == ThemeMode.dark
<<<<<<< HEAD
                      ? ThemeNotifier.textDark : Colors.white,
=======
                      ? ThemeNotifier.textDark
                      : Colors.white,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
  // Build data cell
  Widget _buildDataCell(String text, {bool isStatus = false}) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.103,
=======
  Widget _buildDataCell(String text, {bool isStatus = false}) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.100,
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
                ? ThemeNotifier.textDark : Colors.black87,
=======
                ? ThemeNotifier.textDark
                : Colors.black87,
>>>>>>> origin/Grocery_pch_api_integration
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
<<<<<<< HEAD

=======
>>>>>>> origin/Grocery_pch_api_integration
}