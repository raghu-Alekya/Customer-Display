// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:syncfusion_flutter_datepicker/datepicker.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';
//
// import '../../Constants/text.dart';
// import '../../Helper/Extentions/theme_notifier.dart';
// import '../../Preferences/pinaka_preferences.dart';
// import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
// import '../../Widgets/widget_topbar.dart';
// import '../Database/db_helper.dart';
// import '../Database/user_db_helper.dart';
// import '../Helper/Extentions/nav_layout_manager.dart';
// import '../Helper/url_helper.dart';
// import '../Models/Orders/refund_orderlist_model.dart';
// import '../Repositories/Orders/refund_validation_repository.dart';
// import '../Widgets/refund_checkin_popup.dart';
// import '../Blocs/Orders/refund_validation_bloc.dart';
//
// enum SidebarPosition { left, right, bottom }
//
// enum OrderPanelPosition { left, right }
//
// List<String> allData = List.generate(27, (i) => "Item ${i + 1}");
//
// class CompletedOrdersScreen extends StatefulWidget {
//   final int lastSelectedIndex;
//   const CompletedOrdersScreen({super.key, required this.lastSelectedIndex});
//
//   @override
//   State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
// }
//
// class _CompletedOrdersScreenState extends State<CompletedOrdersScreen>
//     with WidgetsBindingObserver, LayoutSelectionMixin {
//
//   int _selectedSidebarIndex = 5;
//   int _currentPage = 1;
//   int itemsPerPage = 10;
//   final List<int> _rowsPerPageOptions = [10, 20, 50, 100];
//   int _rowsPerPage = 10;
//   DateTime? selectedDate;
//   List<int> quantities = [];
//   DateTime? _startDate;
//   DateTime? _endDate;
//   bool _isDateRangeApplied = false;
//   static bool isActive = false;
//
//   List<CompletedOrder> _allOrders = [];
//   List<CompletedOrder> filteredOrders = [];
//   List<CompletedOrder> _pagedOrders = [];
//   List<CompletedOrder> _visibleOrders = [];
//
//   // ✅ NEW: Loading and error states
//   bool _isLoading = false;
//   String? _errorMessage;
//
//   int get _totalPages {
//     final pages = _rowsPerPage > 0 ? (filteredOrders.length / _rowsPerPage).ceil() : 1;
//     return pages == 0 ? 1 : pages;
//   }
//
//   TextEditingController searchController = TextEditingController();
//   String selectedStatus = 'Completed';
//   String? selectedTransactionId;
//   List<String> transactionIds = [];
//   Map<int, String?> selectedTxnPerOrder = {};
//   List<String> transactionIdOptions = [];
//   bool _isModeChangePending = false;
//   bool _isNavigatingAway = false;
//
//   List<CompletedOrder> _orders = [];
//
//   String _todayStart() {
//     final now = DateTime.now();
//     final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
//     return start.toIso8601String();
//   }
//
//   String _todayEnd() {
//     final now = DateTime.now();
//     final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
//     return end.toIso8601String();
//   }
//
//   void _paginate() {
//     final int totalPages = _totalPages;
//     if (_currentPage > totalPages) {
//       _currentPage = totalPages;
//     }
//     if (_currentPage < 1) {
//       _currentPage = 1;
//     }
//
//     final startIndex = (_currentPage - 1) * _rowsPerPage;
//     final endIndex = startIndex + _rowsPerPage;
//
//     if (startIndex >= filteredOrders.length) {
//       _pagedOrders = [];
//     } else {
//       _pagedOrders = filteredOrders.sublist(
//         startIndex,
//         endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
//       );
//     }
//   }
//
//   void _loadPage(int page) {
//     setState(() {
//       _currentPage = page;
//       _paginate();
//     });
//   }
//
//   @override
//   void deactivate() {
//     _isNavigatingAway = true;
//     super.deactivate();
//   }
//
//   void _updatePagination() {
//     final startIndex = (_currentPage - 1) * itemsPerPage;
//     final endIndex = startIndex + itemsPerPage;
//
//     setState(() {
//       _pagedOrders = filteredOrders.sublist(
//         startIndex,
//         endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
//       );
//     });
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedSidebarIndex = widget.lastSelectedIndex;
//     _loadCompletedOrders();
//   }
//
//   @override
//   void dispose() {
//     _isNavigatingAway = true;
//     searchController.dispose();
//     super.dispose();
//   }
//
//   //  NEW: Direct API call to load completed orders
//   Future<void> _loadCompletedOrders() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final orders = await _fetchCompletedOrders(
//         page: 1,
//         perPage: 100, // Load all orders at once for client-side filtering
//       );
//
//       setState(() {
//         _allOrders = orders;
//         filteredOrders = List.from(_allOrders);
//
//         transactionIds = _allOrders
//             .map((o) => o.transactionId)
//             .where((id) => id.isNotEmpty)
//             .toSet()
//             .toList();
//
//         _currentPage = 1;
//         _isLoading = false;
//         _paginate();
//       });
//
//       if (kDebugMode) {
//         debugPrint("✅ Loaded ${orders.length} completed orders");
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = e.toString();
//         _isLoading = false;
//       });
//       if (kDebugMode) {
//         debugPrint(" Error loading completed orders: $e");
//       }
//     }
//   }
//
//   // ✅ NEW: Direct fetch method (moved from repository)
//   Future<List<CompletedOrder>> _fetchCompletedOrders({
//     required int page,
//     int? perPage,
//     int? authorId,
//     String? from,
//     String? to,
//   }) async {
//     final token = await _getTokenFromDb();
//
//     // ✅ Build query parameters dynamically
//     final queryParams = {
//       'page': page.toString(),
//       if (perPage != null) 'per_page': perPage.toString(),
//       if (authorId != null) 'author': authorId.toString(),
//       if (from != null && from.isNotEmpty) 'after': from,
//       if (to != null && to.isNotEmpty) 'before': to,
//     };
//
//     final uri = Uri.parse(
//       '${UrlHelper.baseUrl}pinaka-pos/v1/orders/completed-orders',
//     ).replace(queryParameters: queryParams);
//
//     final response = await http.get(
//       uri,
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Accept': 'application/json',
//       },
//     );
//
//     if (kDebugMode) {
//       print("completed orders Status Code: ${response.statusCode}");
//       print("Body: ${response.body}");
//     }
//
//     if (response.statusCode != 200) {
//       throw Exception(
//         'Failed to load completed orders (status: ${response.statusCode})',
//       );
//     }
//
//     final decoded = jsonDecode(response.body);
//     if (kDebugMode) {
//       print("DECODED JSON:");
//       debugPrint(decoded.toString());
//     }
//
//     // ✅ Safe parsing
//     if (decoded == null ||
//         decoded['orders_data'] == null ||
//         decoded['orders_data'] is! List) {
//       return [];
//     }
//
//     final List ordersList = decoded['orders_data'];
//
//     return ordersList
//         .map((e) => CompletedOrder.fromJson(e))
//         .toList();
//   }
//
//   // ✅ Helper to get token from DB
//   Future<String> _getTokenFromDb() async {
//     final db = await DBHelper.instance.database;
//
//     final result = await db.query(
//       AppDBConst.userTable,
//       where:
//       '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
//       orderBy: '${AppDBConst.userId} DESC',
//       limit: 1,
//     );
//
//     if (result.isEmpty) {
//       throw Exception('No active user token found in database');
//     }
//
//     final token = result.first[AppDBConst.userToken] as String;
//
//     if (kDebugMode) {
//       print('Using JWT token: ${token.length > 20 ? token.substring(0, 20) : token}...');
//     }
//
//     return token;
//   }
//
//   // ✅ FIX: Helper to compute sidebar position fresh from notifier
//   SidebarPosition _getSidebarPosition(String layout) {
//     if (layout == SharedPreferenceTextConstants.navRightOrderLeft) return SidebarPosition.right;
//     if (layout == SharedPreferenceTextConstants.navBottomOrderLeft) return SidebarPosition.bottom;
//     if (layout == SharedPreferenceTextConstants.navBottomOrderRight) return SidebarPosition.bottom;
//     return SidebarPosition.left;
//   }
//
//   // ✅ FIX: Helper to compute order panel position fresh from notifier
//   OrderPanelPosition _getOrderPanelPosition(String layout) {
//     if (layout == SharedPreferenceTextConstants.navRightOrderLeft) return OrderPanelPosition.left;
//     if (layout == SharedPreferenceTextConstants.navBottomOrderLeft) return OrderPanelPosition.left;
//     if (layout == SharedPreferenceTextConstants.navBottomOrderRight) return OrderPanelPosition.right;
//     return OrderPanelPosition.right;
//   }
//
//   /// ✅ FINAL SAFE MODE CHANGE HANDLER
//   void _handleModeChange() async {
//     if (_isNavigatingAway || _isModeChangePending) {
//       print("🚫 [Refund] Mode change BLOCKED - navigating away");
//       return;
//     }
//
//     _isModeChangePending = true;
//     print("🔄 [Refund] Mode toggle requested");
//
//     final String currentLayout = PinakaPreferences.layoutSelectionNotifier.value;
//     final SidebarPosition currentSidebar = _getSidebarPosition(currentLayout);
//     final OrderPanelPosition currentOrderPanel = _getOrderPanelPosition(currentLayout);
//
//     String newLayout;
//     if (currentSidebar == SidebarPosition.left) {
//       newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
//     } else if (currentSidebar == SidebarPosition.right) {
//       newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
//     } else {
//       newLayout = currentOrderPanel == OrderPanelPosition.left
//           ? SharedPreferenceTextConstants.navBottomOrderRight
//           : SharedPreferenceTextConstants.navLeftOrderRight;
//     }
//
//     print("🔄 [Refund] Changing mode to: $newLayout");
//
//     PinakaPreferences.layoutSelectionNotifier.value = newLayout;
//
//     await UserDbHelper().saveUserSettings(
//       {AppDBConst.layoutSelection: newLayout},
//       modeChange: true,
//     );
//
//     // Reset after small delay
//     Future.delayed(const Duration(milliseconds: 400), () {
//       if (mounted) _isModeChangePending = false;
//     });
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   // ✅ Refresh method
//   Future<void> _refreshOrders() async {
//     await _loadCompletedOrders();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//
//     return ValueListenableBuilder<String>(
//       valueListenable: PinakaPreferences.layoutSelectionNotifier,
//       builder: (context, layout, _) {
//         final SidebarPosition sidebarPosition = _getSidebarPosition(layout);
//         final OrderPanelPosition orderPanelPosition = _getOrderPanelPosition(layout);
//
//         return Scaffold(
//           body: Column(
//             children: [
//               /// 🔹 TOP BAR (same as Orders screen)
//               TopBar(
//                 screen: Screen.ORDERS,
//                 onModeChanged: _handleModeChange,
//               ),
//               const Divider(height: 1, thickness: 0.4),
//
//               /// 🔹 MAIN CONTENT
//               Expanded(
//                 child: Row(
//                   children: [
//                     /// 🔹 LEFT SIDEBAR
//                     if (sidebarPosition == SidebarPosition.left)
//                       custom_widgets.NavigationBar(
//                         selectedSidebarIndex: _selectedSidebarIndex,
//                         isVertical: true,
//                         onSidebarItemSelected: (index) {
//                           setState(() => _selectedSidebarIndex = index);
//                         },
//                       ),
//
//                     /// 🔹 CENTER CONTENT (Completed Orders Table)
//                     Expanded(
//                       child: _buildContent(themeHelper),
//                     ),
//
//                     /// 🔹 RIGHT SIDEBAR
//                     if (sidebarPosition == SidebarPosition.right)
//                       custom_widgets.NavigationBar(
//                         selectedSidebarIndex: _selectedSidebarIndex,
//                         isVertical: true,
//                         onSidebarItemSelected: (index) {
//                           setState(() => _selectedSidebarIndex = index);
//                         },
//                       ),
//                   ],
//                 ),
//               ),
//
//               /// 🔹 BOTTOM SIDEBAR
//               if (sidebarPosition == SidebarPosition.bottom)
//                 custom_widgets.NavigationBar(
//                   selectedSidebarIndex: _selectedSidebarIndex,
//                   isVertical: false,
//                   onSidebarItemSelected: (index) {
//                     setState(() => _selectedSidebarIndex = index);
//                   },
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   // ✅ NEW: Content builder replacing BlocConsumer
//   Widget _buildContent(ThemeNotifier themeHelper) {
//     if (_isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     }
//
//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               _errorMessage!,
//               style: const TextStyle(color: Colors.red),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _refreshOrders,
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (filteredOrders.isEmpty) {
//       return const Center(
//         child: Text("No completed orders found"),
//       );
//     }
//
//     return Container(
//       margin: const EdgeInsets.all(12),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: themeHelper.themeMode == ThemeMode.dark
//             ? ThemeNotifier.primaryBackground
//             : Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 6,
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           _buildHeader(),
//           const SizedBox(height: 12),
//           Expanded(
//             child: _buildOrderTable(themeHelper),
//           ),
//           const SizedBox(height: 8),
//           _buildPagination(),
//         ],
//       ),
//     );
//   }
//
//   // ================= HEADER =================
//
//   Widget _buildHeader() {
//     bool isDark = Theme.of(context).brightness == Brightness.dark;
//     return Row(
//       children: [
//         const Text(
//           "Completed Order List",
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         const Spacer(),
//         Container(
//           width: 200,
//           height: 35,
//           decoration: BoxDecoration(
//             color: isDark
//                 ? const Color(0xFF29313F)
//                 : Colors.white,
//             borderRadius: BorderRadius.circular(8),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.15),
//                 blurRadius: 6,
//                 spreadRadius: 1,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: TextField(
//             controller: searchController,
//             textAlignVertical: TextAlignVertical.center,
//             onChanged: (value) {
//               setState(() {
//                 if (value.isEmpty) {
//                   filteredOrders = _allOrders;
//                 } else {
//                   filteredOrders = _allOrders.where((order) {
//                     return order.orderId
//                         .toString()
//                         .toLowerCase()
//                         .contains(value.toLowerCase());
//                   }).toList();
//                 }
//
//                 _currentPage = 1;
//                 _paginate();
//               });
//             },
//             decoration: InputDecoration(
//               hintText: "Search Order ID",
//               hintStyle: TextStyle(
//                 fontFamily: "Inter",
//                 fontSize: 13,
//                 fontWeight: FontWeight.w400,
//                 color: isDark ? Colors.white : const Color(0xFF999393),
//               ),
//               prefixIcon: Icon(
//                 Icons.search,
//                 color: isDark ? Colors.white : const Color(0xFF999393),
//                 size: 18,
//               ),
//               suffixIcon: searchController.text.isNotEmpty
//                   ? IconButton(
//                 icon: Icon(
//                   Icons.close,
//                   color: isDark
//                       ? Colors.white
//                       : const Color(0xFF6B7280),
//                   size: 18,
//                 ),
//                 onPressed: () {
//                   searchController.clear();
//                   setState(() {
//                     filteredOrders = _allOrders;
//                     _currentPage = 1;
//                     _paginate();
//                   });
//                 },
//               )
//                   : null,
//               border: InputBorder.none,
//               enabledBorder: InputBorder.none,
//               focusedBorder: InputBorder.none,
//               contentPadding: const EdgeInsets.symmetric(
//                   vertical: 0),
//               isDense: true,
//             ),
//           ),
//         ),
//         const SizedBox(width: 18),
//         Row(
//           children: [
//             const SizedBox(width: 8),
//
//             // CALENDAR ICON FILTER
//             InkWell(
//               onTap: _openDateRangePickerDialog,
//               child: Container(
//                 padding: const EdgeInsets.all(7),
//                 child: SvgPicture.asset(
//                   'assets/svg/filter_calendar.svg',
//                   width: 32,
//                   height: 32,
//                   colorFilter: ColorFilter.mode(
//                     _isDateRangeApplied
//                         ? Colors.redAccent
//                         : Theme.of(context).colorScheme.onSurface,
//                     BlendMode.srcIn,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         )
//       ],
//     );
//   }
//
//   void _openDateRangePickerDialog() {
//     final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return AlertDialog(
//           backgroundColor: themeHelper.themeMode == ThemeMode.dark
//               ? ThemeNotifier.secondaryBackground
//               : null,
//           title: const Text("Select Date Range"),
//           content: SizedBox(
//             height: 400,
//             width: 350,
//             child: SfDateRangePicker(
//               selectionMode: DateRangePickerSelectionMode.range,
//               showActionButtons: true,
//               onSelectionChanged: _onDateRangeSelectionChanged,
//               initialSelectedRange: _startDate != null && _endDate != null
//                   ? PickerDateRange(_startDate, _endDate)
//                   : null,
//               onSubmit: (value) => Navigator.pop(context),
//               onCancel: () => Navigator.pop(context),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _onDateRangeSelectionChanged(DateRangePickerSelectionChangedArgs args) {
//     if (args.value is PickerDateRange) {
//       final range = args.value as PickerDateRange;
//
//       setState(() {
//         _startDate = range.startDate;
//         _endDate = range.endDate ?? range.startDate;
//
//         _isDateRangeApplied = _startDate != null && _endDate != null;
//
//         _applyDateFilter();
//       });
//     }
//   }
//
//   void _applyDateFilter() {
//     if (!_isDateRangeApplied || _startDate == null || _endDate == null) {
//       filteredOrders = _allOrders;
//     } else {
//       filteredOrders = _allOrders.where((order) {
//         final orderDate = order.completedAt;
//
//         final dateOnly =
//         DateTime(orderDate.year, orderDate.month, orderDate.day);
//
//         final start =
//         DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
//
//         final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
//
//         return dateOnly.isAfter(start.subtract(const Duration(days: 1))) &&
//             dateOnly.isBefore(end.add(const Duration(days: 1)));
//       }).toList();
//     }
//
//     _currentPage = 1;
//     _paginate();
//   }
//
//   // ================= TABLE =================
//
//   Widget _buildOrderTable(ThemeNotifier themeHelper) {
//     bool isDark = Theme.of(context).brightness == Brightness.dark;
//
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         color: themeHelper.themeMode == ThemeMode.dark
//             ? const Color(0xFF201F29)
//             : const Color(0xFFF9F9F9),
//       ),
//       child: Column(
//         children: [
//           /// 🔹 TABLE HEADER
//           Container(
//             padding: const EdgeInsets.only(
//               left: 8,
//               right: 0,
//               top: 14,
//               bottom: 14,
//             ),
//             decoration: BoxDecoration(
//               color: themeHelper.themeMode == ThemeMode.dark
//                   ? const Color(0xFF29313F)
//                   : const Color(0xFF6F6F70),
//               borderRadius:
//               const BorderRadius.vertical(top: Radius.circular(10)),
//             ),
//             child: Row(
//               children: const [
//                 SizedBox(width: 10),
//                 _HeaderCell("Order ID"),
//                 _HeaderCell("Order Type"),
//                 _HeaderCell("Date"),
//                 _HeaderCell("Transaction ID"),
//                 _HeaderCell("Payment Type"),
//                 _HeaderCell("Amount"),
//                 _HeaderCell("Item Tax"),
//                 _HeaderCell("Discount"),
//                 _HeaderCell("Total"),
//                 _HeaderCell("Status"),
//               ],
//             ),
//           ),
//
//           /// 🔹 TABLE BODY
//           Expanded(
//             child: ListView.builder(
//               itemCount: _pagedOrders.length,
//               itemBuilder: (context, index) {
//                 final order = _pagedOrders[index];
//
//                 return InkWell(
//                   onTap: () {
//                     showDialog(
//                       context: context,
//                       barrierDismissible: false,
//                       builder: (dialogContext) {
//                         return BlocProvider(
//                           create: (_) => RefundValidationBloc(
//                             repository: RefundValidationRepository(
//                               baseUrl:
//                               "https://merchantretail.alektasolutions.com",
//                             ),
//                           ),
//                           child: PinCheckInDialog(order: order),
//                         );
//                       },
//                     );
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.only(
//                       left: 10,
//                       right: 10,
//                       top: 10,
//                       bottom: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isDark ? const Color(0xFF212231) : Colors.white,
//                       border: Border(
//                         bottom: BorderSide(
//                           color: isDark
//                               ? const Color(0xFF4D4E63)
//                               : const Color(0xFFD8D7D7),
//                         ),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         _DataCell("#${order.orderId}"),
//                         _DataCell(order.orderType),
//                         _DataCell(
//                           DateFormat('dd-MM-yyyy').format(order.completedAt),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: () {},
//                             behavior: HitTestBehavior.opaque,
//                             child: DropdownButtonHideUnderline(
//                               child: Builder(
//                                 builder: (context) {
//                                   final List<String> itemsList = [
//                                     order.transactionId.toString(),
//                                     ...transactionIdOptions
//                                         .map((e) => e.toString()),
//                                   ].toSet().toList();
//
//                                   // ✅ Show only first 2 IDs in display
//                                   String displayText = "";
//
//                                   if (itemsList.length == 1) {
//                                     displayText = itemsList[0];
//                                   } else if (itemsList.length == 2) {
//                                     displayText =
//                                     "${itemsList[0]}, ${itemsList[1]}";
//                                   } else if (itemsList.length > 2) {
//                                     displayText =
//                                     "${itemsList[0]}, ${itemsList[1]}...";
//                                   }
//                                   return DropdownButton<String>(
//                                     value: selectedTxnPerOrder[order.orderId] ?? itemsList.first,
//                                     isDense: true,
//                                     isExpanded: true,
//                                     icon: const SizedBox.shrink(),
//                                     onChanged: (value) {
//                                       setState(() {
//                                         selectedTxnPerOrder[order.orderId] =
//                                         value!;
//                                       });
//                                     },
//                                     selectedItemBuilder: (context) {
//                                       return itemsList.map((e) {
//                                         return Align(
//                                           alignment: Alignment.centerLeft,
//                                           child: Text(
//                                             displayText,
//                                             style: const TextStyle(
//                                                 fontSize: 14),
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                         );
//                                       }).toList();
//                                     },
//                                     items: itemsList.map((txn) {
//                                       return DropdownMenuItem<String>(
//                                         value: txn,
//                                         child: Text(
//                                           txn,
//                                           style:
//                                           const TextStyle(fontSize: 12),
//                                         ),
//                                       );
//                                     }).toList(),
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),
//                         ),
//                         _DataCell(order.paymentMethod),
//                         _DataCell(
//                             _formatCurrency(order.amount)),
//                         _DataCell(
//                             _formatCurrency(order.tax)),
//                         _DataCell(
//                             _formatCurrency(order.discount)),
//                         _DataCell(
//                             _formatCurrency(order.total)),
//                         const _StatusCell(),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ================= PAGINATION =================
//   Widget _buildPagination() {
//     final int totalItems = filteredOrders.length;
//     final int totalPages = _totalPages;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           const Text("Rows per page:"),
//           const SizedBox(width: 8),
//
//           // ---------------- ROWS PER PAGE ----------------
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(8.0),
//               border: Border.all(color: Colors.grey.shade400),
//             ),
//             child: DropdownButton<int>(
//               value: _rowsPerPage,
//               underline: const SizedBox.shrink(),
//               items: _rowsPerPageOptions.map((int value) {
//                 return DropdownMenuItem<int>(
//                   value: value,
//                   child: Text(value.toString()),
//                 );
//               }).toList(),
//               onChanged: (int? newValue) {
//                 if (newValue != null) {
//                   setState(() {
//                     _rowsPerPage = newValue;
//                     _currentPage = 1;
//                     _loadPage(1);
//                   });
//                 }
//               },
//             ),
//           ),
//
//           const SizedBox(width: 24),
//
//           // ---------------- PAGE INFO ----------------
//           Text(
//             totalItems == 0
//                 ? '0-0 of 0'
//                 : '${(_currentPage - 1) * _rowsPerPage + 1}'
//                 '-${(_currentPage * _rowsPerPage) > totalItems ? totalItems : (_currentPage * _rowsPerPage)}'
//                 ' of $totalItems',
//           ),
//
//           const SizedBox(width: 24),
//
//           // ---------------- FIRST PAGE ----------------
//           IconButton(
//             icon: const Icon(Icons.first_page),
//             onPressed: _currentPage == 1 || totalItems == 0
//                 ? null
//                 : () => _loadPage(1),
//           ),
//
//           // ---------------- PREVIOUS PAGE ----------------
//           IconButton(
//             icon: const Icon(Icons.chevron_left),
//             onPressed: _currentPage == 1 || totalItems == 0
//                 ? null
//                 : () => _loadPage(_currentPage - 1),
//           ),
//
//           // ---------------- NEXT PAGE ----------------
//           IconButton(
//             icon: const Icon(Icons.chevron_right),
//             onPressed: _currentPage == totalPages || totalItems == 0
//                 ? null
//                 : () => _loadPage(_currentPage + 1),
//           ),
//
//           // ---------------- LAST PAGE ----------------
//           IconButton(
//             icon: const Icon(Icons.last_page),
//             onPressed: _currentPage == totalPages || totalItems == 0
//                 ? null
//                 : () => _loadPage(totalPages),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _pageButton(int page) {
//     final bool selected = _currentPage == page;
//
//     return InkWell(
//       onTap: () {
//         setState(() {
//           _currentPage = page;
//         });
//       },
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(
//           color: selected ? Colors.red : Colors.transparent,
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(color: Colors.red),
//         ),
//         child: Text(
//           page.toString(),
//           style: TextStyle(
//             color: selected ? Colors.white : Colors.red,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /// ================= SHARED CELLS =================
//
// class _HeaderCell extends StatelessWidget {
//   final String text;
//   const _HeaderCell(this.text);
//
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: Text(
//         text,
//         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }
//
// class _DataCell extends StatelessWidget {
//   final String text;
//   const _DataCell(this.text);
//
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(child: Text(text));
//   }
// }
//
// class _StatusCell extends StatelessWidget {
//   const _StatusCell();
//
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
//         decoration: BoxDecoration(
//           color: Colors.green.shade100,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: const Text(
//           "Completed",
//           style: TextStyle(color: Colors.green),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../Constants/text.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Widgets/widget_topbar.dart';
import '../Database/db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/nav_layout_manager.dart';
import '../Helper/url_helper.dart';
import '../Helper/offline_helper.dart';
import '../Models/Orders/refund_orderlist_model.dart';
import '../Repositories/Orders/refund_validation_repository.dart';
import '../Widgets/refund_checkin_popup.dart';
import '../Blocs/Orders/refund_validation_bloc.dart';

enum SidebarPosition { left, right, bottom }

enum OrderPanelPosition { left, right }

List<String> allData = List.generate(27, (i) => "Item ${i + 1}");

class CompletedOrdersScreen extends StatefulWidget {
  final int lastSelectedIndex;
  const CompletedOrdersScreen({super.key, required this.lastSelectedIndex});

  @override
  State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen>
    with WidgetsBindingObserver, LayoutSelectionMixin {

  int _selectedSidebarIndex = 5;
  int _currentPage = 1;
  int itemsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];
  int _rowsPerPage = 10;
  DateTime? selectedDate;
  List<int> quantities = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeApplied = false;
  static bool isActive = false;

  List<CompletedOrder> _allOrders = [];
  List<CompletedOrder> filteredOrders = [];
  List<CompletedOrder> _pagedOrders = [];
  List<CompletedOrder> _visibleOrders = [];

  // ✅ NEW: Loading and error states
  bool _isLoading = false;
  String? _errorMessage;

  // Store currency is persisted in the local asset table.  Keep the last
  // known symbol in memory so offline Refund never falls back to a hard-coded
  // '$' or the TextConstants default '€'.
  String _currencySymbol = TextConstants.currencySymbol;

  // ✅ NEW: Cache management
  static List<CompletedOrder> _cachedOrders = [];
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 10);
  static Set<int> _cachedOrderIds = {};
  static bool _isInitialLoad = true;
  static Future<void>? _backgroundRefreshInFlight;

  int get _totalPages {
    final pages = _rowsPerPage > 0 ? (filteredOrders.length / _rowsPerPage).ceil() : 1;
    return pages == 0 ? 1 : pages;
  }

  TextEditingController searchController = TextEditingController();
  String selectedStatus = 'Completed';
  String? selectedTransactionId;
  List<String> transactionIds = [];
  Map<int, String?> selectedTxnPerOrder = {};
  List<String> transactionIdOptions = [];
  bool _isModeChangePending = false;
  bool _isNavigatingAway = false;

  List<CompletedOrder> _orders = [];

  String _todayStart() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    return start.toIso8601String();
  }

  String _todayEnd() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return end.toIso8601String();
  }

  void _paginate() {
    final int totalPages = _totalPages;
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;

    if (startIndex >= filteredOrders.length) {
      _pagedOrders = [];
    } else {
      _pagedOrders = filteredOrders.sublist(
        startIndex,
        endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
      );
    }
  }

  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
      _paginate();
    });
  }

  @override
  void deactivate() {
    _isNavigatingAway = true;
    super.deactivate();
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    setState(() {
      _pagedOrders = filteredOrders.sublist(
        startIndex,
        endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
      );
    });
  }

  Future<void> _restoreCurrencyForOfflineUse() async {
    try {
      await OfflineHelper.restoreStoredCurrency();
      final symbol = await OfflineHelper.getStoredCurrencySymbol();

      if (!mounted) return;
      if (symbol.trim().isNotEmpty) {
        _currencySymbol = symbol.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Refund] Currency restore failed: $e');
      }
    }
  }

  String _formatCurrency(double value) {
    final sign = value < 0 ? '-' : '';
    return '$sign$_currencySymbol${value.abs().toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex;
    // Restore currency from SQLite before offline orders are rendered. This
    // is local-only and does not add a network/DNS wait.
    _loadCompletedOrders();
  }

  @override
  void dispose() {
    _isNavigatingAway = true;
    searchController.dispose();
    super.dispose();
  }

  // Smart loading with a cache-first strategy.
  //
  // Important performance rules:
  // 1. If this screen already has cached orders, render them immediately.
  // 2. Do NOT run DNS/network checks just because the screen was opened.
  // 3. Only refresh from the server when the cache is stale or the user
  //    explicitly presses Refresh.
  // 4. When there is no memory cache (for example after app restart), read
  //    SQLite first so offline users see data without waiting for DNS.
  Future<void> _loadCompletedOrders({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Load the last known store currency from SQLite. This is intentionally
    // before any network check, so offline mode uses the correct symbol.
    await _restoreCurrencyForOfflineUse();
    if (!mounted) return;

    final hasCache = _cachedOrders.isNotEmpty;
    final cacheAge = _lastFetchTime == null
        ? const Duration(days: 999)
        : DateTime.now().difference(_lastFetchTime!);
    final cacheFresh = hasCache && cacheAge < _cacheDuration;

    // ---------------------------------------------------------------
    // CACHE-FIRST: normal navigation should be instant.
    // ---------------------------------------------------------------
    if (hasCache && !forceRefresh) {
      _showOrdersImmediately(_cachedOrders);

      // Fresh cache: nothing else is needed. This prevents reloading all
      // orders every time the Refund screen is opened.
      if (cacheFresh) {
        return;
      }

      // Stale cache: keep showing the old data and refresh in the background.
      _fetchLatestOrdersInBackground();
      return;
    }

    // ---------------------------------------------------------------
    // FIRST LOAD / APP RESTART: SQLite first.
    // ---------------------------------------------------------------
    if (!hasCache) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      // Read local data BEFORE doing DNS. This makes an offline first-open
      // fast even when Windows reports Wi-Fi as connected.
      try {
        final localOrders =
        await OfflineHelper.buildOfflineCompletedOrdersFromDb(
          page: 1,
          perPage: 100,
        );

        if (localOrders.isNotEmpty) {
          _cachedOrders = List<CompletedOrder>.from(localOrders);
          _cachedOrderIds = _cachedOrders.map((o) => o.orderId).toSet();
          _lastFetchTime = DateTime.now();
          if (mounted) {
            _showOrdersImmediately(localOrders);
            _isInitialLoad = false;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Refund] Local load failed: $e');
      }
    } else {
      // Manual refresh: never hide the current orders behind a spinner.
      _showOrdersImmediately(_cachedOrders);
    }

    // ---------------------------------------------------------------
    // NETWORK: only now decide whether a server refresh is possible.
    // ---------------------------------------------------------------
    final bool online = await OfflineHelper.isNetworkAvailable(
      forceRefresh: forceRefresh,
    );

    if (!online) {
      // If SQLite was empty, keep the screen usable without an error page.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          _errorMessage = null;
        });
      }
      return;
    }

    // ---------------------------------------------------------------
    // ONLINE: update only what is needed.
    // Normal navigation with stale cache uses a small background request.
    // Manual Refresh can fetch the full first page.
    // ---------------------------------------------------------------
    if (!forceRefresh && _cachedOrders.isNotEmpty) {
      _fetchLatestOrdersInBackground();
      return;
    }

    try {
      final orders = await _fetchCompletedOrders(
        page: 1,
        perPage: 100,
        // A manual refresh intentionally gets the first page again.
      );

      if (orders.isNotEmpty) {
        _mergeOrdersWithCache(orders);
      } else {
        _lastFetchTime = DateTime.now();
      }

      if (!mounted) return;
      _showOrdersImmediately(_cachedOrders);
      _isInitialLoad = false;
    } catch (e) {
      // Never replace usable local data with an error/loading screen.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          _errorMessage = null;
        });
      }
      if (kDebugMode) debugPrint('⚠️ [Refund] Refresh failed: $e');
    }
  }

  void _showOrdersImmediately(List<CompletedOrder> orders) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _allOrders = List<CompletedOrder>.from(orders);
      filteredOrders = List<CompletedOrder>.from(orders);
      _updateTransactionIds();
      _currentPage = 1;
      _paginate();
    });
  }

  // Background fetch for latest updates. It is deliberately deduplicated so
  // opening/rebuilding the screen cannot start multiple API calls.
  void _fetchLatestOrdersInBackground() {
    if (_backgroundRefreshInFlight != null) return;

    final future = Future<void>(() async {
      try {
        if (!await OfflineHelper.isNetworkAvailable()) {
          if (kDebugMode) {
            debugPrint('📴 [Refund] Background refresh skipped while offline');
          }
          return;
        }

        final lastOrderId =
        _cachedOrders.isNotEmpty ? _cachedOrders.first.orderId : null;

        final newOrders = await _fetchCompletedOrders(
          page: 1,
          perPage: 50,
          lastOrderId: lastOrderId,
        );

        // Even an empty successful response means the cache was checked.
        _lastFetchTime = DateTime.now();

        if (newOrders.isNotEmpty) {
          _mergeOrdersWithCache(newOrders);

          if (mounted) {
            _showOrdersImmediately(_cachedOrders);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [Refund] Background update failed: $e');
        }
      }
    });

    _backgroundRefreshInFlight = future;
    future.whenComplete(() {
      if (identical(_backgroundRefreshInFlight, future)) {
        _backgroundRefreshInFlight = null;
      }
    });
  }

  // ✅ MODIFIED: Merge orders with cache - now sorts by completedAt (latest first)
  void _mergeOrdersWithCache(List<CompletedOrder> newOrders) {
    // Create a map of existing orders by ID
    final Map<int, CompletedOrder> existingOrderMap = {
      for (var order in _cachedOrders) order.orderId: order
    };

    // Add or update orders
    for (var order in newOrders) {
      // Check if this is a newer version of an existing order
      if (existingOrderMap.containsKey(order.orderId)) {
        final existing = existingOrderMap[order.orderId]!;
        // Compare timestamps to determine if update is needed
        if (order.completedAt.isAfter(existing.completedAt)) {
          existingOrderMap[order.orderId] = order;
        }
      } else {
        // New order - add it
        existingOrderMap[order.orderId] = order;
      }
    }

    // Convert back to list and sort by completedAt (newest first)
    _cachedOrders = existingOrderMap.values.toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    _cachedOrderIds = _cachedOrders.map((o) => o.orderId).toSet();
    _lastFetchTime = DateTime.now();
  }

  // ✅ NEW: Update transaction IDs
  void _updateTransactionIds() {
    transactionIds = _allOrders
        .map((o) => o.transactionId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  // ✅ MODIFIED: Direct fetch method with incremental support
  Future<List<CompletedOrder>> _fetchCompletedOrders({
    required int page,
    int? perPage,
    int? authorId,
    String? from,
    String? to,
    int? lastOrderId, // ✅ NEW: For incremental updates
  }) async {
    // Never start a remote request while the POS is offline. The local
    // SQLite order store is the source for the Refund screen in this mode.
    final isOnline = await OfflineHelper.isNetworkAvailable();
    if (!isOnline) {
      return OfflineHelper.buildOfflineCompletedOrdersFromDb(
        page: page,
        perPage: perPage ?? 20,
        authorId: authorId,
        from: from,
        to: to,
      );
    }

    final token = await _getTokenFromDb();

    // ✅ Build query parameters dynamically
    final queryParams = {
      'page': page.toString(),
      if (perPage != null) 'per_page': perPage.toString(),
      if (authorId != null) 'author': authorId.toString(),
      if (from != null && from.isNotEmpty) 'after': from,
      if (to != null && to.isNotEmpty) 'before': to,
      // ✅ NEW: Add incremental parameter if provided
      if (lastOrderId != null) 'since_id': lastOrderId.toString(),
    };

    final uri = Uri.parse(
      '${UrlHelper.baseUrl}pinaka-pos/v1/orders/completed-orders',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      if (kDebugMode) {
        print("completed orders Status Code: ${response.statusCode}");
        print("Body: ${response.body}");
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load completed orders (status: ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      if (kDebugMode) {
        print("DECODED JSON:");
        debugPrint(decoded.toString());
      }

      // ✅ Safe parsing
      if (decoded == null ||
          decoded['orders_data'] == null ||
          decoded['orders_data'] is! List) {
        return [];
      }

      final List ordersList = decoded['orders_data'];

      return ordersList
          .map((e) => CompletedOrder.fromJson(e))
          .toList();
    } catch (e) {
      if (OfflineHelper.isSessionError(e)) rethrow;
      if (kDebugMode) {
        debugPrint('⚠️ Refund screen network fetch failed; using local orders: $e');
      }
      return OfflineHelper.buildOfflineCompletedOrdersFromDb(
        page: page,
        perPage: perPage ?? 20,
        authorId: authorId,
        from: from,
        to: to,
      );
    }
  }

  // ✅ Helper to get token from DB
  Future<String> _getTokenFromDb() async {
    final db = await DBHelper.instance.database;

    final result = await db.query(
      AppDBConst.userTable,
      where:
      '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('No active user token found in database');
    }

    final token = result.first[AppDBConst.userToken] as String;

    if (kDebugMode) {
      print('Using JWT token: ${token.length > 20 ? token.substring(0, 20) : token}...');
    }

    return token;
  }

  // ✅ FIX: Helper to compute sidebar position fresh from notifier
  SidebarPosition _getSidebarPosition(String layout) {
    if (layout == SharedPreferenceTextConstants.navRightOrderLeft) return SidebarPosition.right;
    if (layout == SharedPreferenceTextConstants.navBottomOrderLeft) return SidebarPosition.bottom;
    if (layout == SharedPreferenceTextConstants.navBottomOrderRight) return SidebarPosition.bottom;
    return SidebarPosition.left;
  }

  // ✅ FIX: Helper to compute order panel position fresh from notifier
  OrderPanelPosition _getOrderPanelPosition(String layout) {
    if (layout == SharedPreferenceTextConstants.navRightOrderLeft) return OrderPanelPosition.left;
    if (layout == SharedPreferenceTextConstants.navBottomOrderLeft) return OrderPanelPosition.left;
    if (layout == SharedPreferenceTextConstants.navBottomOrderRight) return OrderPanelPosition.right;
    return OrderPanelPosition.right;
  }

  /// ✅ FINAL SAFE MODE CHANGE HANDLER
  void _handleModeChange() async {
    if (_isNavigatingAway || _isModeChangePending) {
      print("🚫 [Refund] Mode change BLOCKED - navigating away");
      return;
    }

    _isModeChangePending = true;
    print("🔄 [Refund] Mode toggle requested");

    final String currentLayout = PinakaPreferences.layoutSelectionNotifier.value;
    final SidebarPosition currentSidebar = _getSidebarPosition(currentLayout);
    final OrderPanelPosition currentOrderPanel = _getOrderPanelPosition(currentLayout);

    String newLayout;
    if (currentSidebar == SidebarPosition.left) {
      newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
    } else if (currentSidebar == SidebarPosition.right) {
      newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
    } else {
      newLayout = currentOrderPanel == OrderPanelPosition.left
          ? SharedPreferenceTextConstants.navBottomOrderRight
          : SharedPreferenceTextConstants.navLeftOrderRight;
    }

    print("🔄 [Refund] Changing mode to: $newLayout");

    PinakaPreferences.layoutSelectionNotifier.value = newLayout;

    await UserDbHelper().saveUserSettings(
      {AppDBConst.layoutSelection: newLayout},
      modeChange: true,
    );

    // Reset after small delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _isModeChangePending = false;
    });
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ Refresh method
  Future<void> _refreshOrders() async {
    _lastFetchTime = null;
    _isInitialLoad = true;
    OfflineHelper.invalidateNetworkCache();
    await _loadCompletedOrders(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return ValueListenableBuilder<String>(
      valueListenable: PinakaPreferences.layoutSelectionNotifier,
      builder: (context, layout, _) {
        final SidebarPosition sidebarPosition = _getSidebarPosition(layout);
        final OrderPanelPosition orderPanelPosition = _getOrderPanelPosition(layout);

        return Scaffold(
          body: Column(
            children: [
              /// 🔹 TOP BAR (same as Orders screen)
              TopBar(
                screen: Screen.ORDERS,
                onModeChanged: _handleModeChange,
              ),
              const Divider(height: 1, thickness: 0.4),

              /// 🔹 MAIN CONTENT
              Expanded(
                child: Row(
                  children: [
                    /// 🔹 LEFT SIDEBAR
                    if (sidebarPosition == SidebarPosition.left)
                      custom_widgets.NavigationBar(
                        selectedSidebarIndex: _selectedSidebarIndex,
                        isVertical: true,
                        onSidebarItemSelected: (index) {
                          setState(() => _selectedSidebarIndex = index);
                        },
                      ),

                    /// 🔹 CENTER CONTENT (Completed Orders Table)
                    Expanded(
                      child: _buildContent(themeHelper),
                    ),

                    /// 🔹 RIGHT SIDEBAR
                    if (sidebarPosition == SidebarPosition.right)
                      custom_widgets.NavigationBar(
                        selectedSidebarIndex: _selectedSidebarIndex,
                        isVertical: true,
                        onSidebarItemSelected: (index) {
                          setState(() => _selectedSidebarIndex = index);
                        },
                      ),
                  ],
                ),
              ),

              /// 🔹 BOTTOM SIDEBAR
              if (sidebarPosition == SidebarPosition.bottom)
                custom_widgets.NavigationBar(
                  selectedSidebarIndex: _selectedSidebarIndex,
                  isVertical: false,
                  onSidebarItemSelected: (index) {
                    setState(() => _selectedSidebarIndex = index);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NEW: Content builder replacing BlocConsumer
  Widget _buildContent(ThemeNotifier themeHelper) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (filteredOrders.isEmpty) {
      return const Center(
        child: Text("No completed orders found"),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildOrderTable(themeHelper),
          ),
          const SizedBox(height: 8),
          _buildPagination(),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        const Text(
          "Completed Order List",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Container(
          width: 200,
          height: 35,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF29313F)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (value) {
              setState(() {
                if (value.isEmpty) {
                  filteredOrders = _allOrders;
                } else {
                  filteredOrders = _allOrders.where((order) {
                    return order.orderId
                        .toString()
                        .toLowerCase()
                        .contains(value.toLowerCase());
                  }).toList();
                }

                _currentPage = 1;
                _paginate();
              });
            },
            decoration: InputDecoration(
              hintText: "Search Order ID",
              hintStyle: TextStyle(
                fontFamily: "Inter",
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : const Color(0xFF999393),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? Colors.white : const Color(0xFF999393),
                size: 18,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF6B7280),
                  size: 18,
                ),
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    filteredOrders = _allOrders;
                    _currentPage = 1;
                    _paginate();
                  });
                },
              )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 0),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Row(
          children: [
            const SizedBox(width: 8),

            // CALENDAR ICON FILTER
            InkWell(
              onTap: _openDateRangePickerDialog,
              child: Container(
                padding: const EdgeInsets.all(7),
                child: SvgPicture.asset(
                  'assets/svg/filter_calendar.svg',
                  width: 32,
                  height: 32,
                  colorFilter: ColorFilter.mode(
                    _isDateRangeApplied
                        ? Colors.redAccent
                        : Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _openDateRangePickerDialog() {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
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
              selectionMode: DateRangePickerSelectionMode.range,
              showActionButtons: true,
              onSelectionChanged: _onDateRangeSelectionChanged,
              initialSelectedRange: _startDate != null && _endDate != null
                  ? PickerDateRange(_startDate, _endDate)
                  : null,
              onSubmit: (value) => Navigator.pop(context),
              onCancel: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }

  void _onDateRangeSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is PickerDateRange) {
      final range = args.value as PickerDateRange;

      setState(() {
        _startDate = range.startDate;
        _endDate = range.endDate ?? range.startDate;

        _isDateRangeApplied = _startDate != null && _endDate != null;

        _applyDateFilter();
      });
    }
  }

  void _applyDateFilter() {
    if (!_isDateRangeApplied || _startDate == null || _endDate == null) {
      filteredOrders = _allOrders;
    } else {
      filteredOrders = _allOrders.where((order) {
        final orderDate = order.completedAt;

        final dateOnly =
        DateTime(orderDate.year, orderDate.month, orderDate.day);

        final start =
        DateTime(_startDate!.year, _startDate!.month, _startDate!.day);

        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

        return dateOnly.isAfter(start.subtract(const Duration(days: 1))) &&
            dateOnly.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    _currentPage = 1;
    _paginate();
  }

  // ================= TABLE =================

  Widget _buildOrderTable(ThemeNotifier themeHelper) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: themeHelper.themeMode == ThemeMode.dark
            ? const Color(0xFF201F29)
            : const Color(0xFFF9F9F9),
      ),
      child: Column(
        children: [
          /// 🔹 TABLE HEADER
          Container(
            padding: const EdgeInsets.only(
              left: 8,
              right: 0,
              top: 14,
              bottom: 14,
            ),
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? const Color(0xFF29313F)
                  : const Color(0xFF6F6F70),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 10),
                _HeaderCell("Order ID"),
                _HeaderCell("Order Type"),
                _HeaderCell("Date"),
                _HeaderCell("Transaction ID"),
                _HeaderCell("Payment Type"),
                _HeaderCell("Amount"),
                _HeaderCell("Item Tax"),
                _HeaderCell("Discount"),
                _HeaderCell("Total"),
                _HeaderCell("Status"),
              ],
            ),
          ),

          /// 🔹 TABLE BODY
          Expanded(
            child: ListView.builder(
              itemCount: _pagedOrders.length,
              itemBuilder: (context, index) {
                final order = _pagedOrders[index];

                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) {
                        return BlocProvider(
                          create: (_) => RefundValidationBloc(
                            repository: RefundValidationRepository(
                              baseUrl: UrlHelper.wooBaseUrl,
                            ),
                          ),
                          child: PinCheckInDialog(order: order),
                        );
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 10,
                      bottom: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF212231) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF4D4E63)
                              : const Color(0xFFD8D7D7),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _DataCell("#${order.orderId}"),
                        _DataCell(order.orderType),
                        _DataCell(
                          DateFormat('dd-MM-yyyy').format(order.completedAt),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            behavior: HitTestBehavior.opaque,
                            child: DropdownButtonHideUnderline(
                              child: Builder(
                                builder: (context) {
                                  final List<String> itemsList = [
                                    order.transactionId.toString(),
                                    ...transactionIdOptions
                                        .map((e) => e.toString()),
                                  ].toSet().toList();

                                  // ✅ Show only first 2 IDs in display
                                  String displayText = "";

                                  if (itemsList.length == 1) {
                                    displayText = itemsList[0];
                                  } else if (itemsList.length == 2) {
                                    displayText =
                                    "${itemsList[0]}, ${itemsList[1]}";
                                  } else if (itemsList.length > 2) {
                                    displayText =
                                    "${itemsList[0]}, ${itemsList[1]}...";
                                  }
                                  return DropdownButton<String>(
                                    value: selectedTxnPerOrder[order.orderId] ?? itemsList.first,
                                    isDense: true,
                                    isExpanded: true,
                                    icon: const SizedBox.shrink(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTxnPerOrder[order.orderId] =
                                        value!;
                                      });
                                    },
                                    selectedItemBuilder: (context) {
                                      return itemsList.map((e) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            displayText,
                                            style: const TextStyle(
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    items: itemsList.map((txn) {
                                      return DropdownMenuItem<String>(
                                        value: txn,
                                        child: Text(
                                          txn,
                                          style:
                                          const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        _DataCell(order.paymentMethod),
                        _DataCell(
                            _formatCurrency(order.amount)),
                        _DataCell(
                            _formatCurrency(order.tax)),
                        _DataCell(
                            _formatCurrency(order.discount)),
                        _DataCell(
                            _formatCurrency(order.total)),
                        const _StatusCell(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= PAGINATION =================
  Widget _buildPagination() {
    final int totalItems = filteredOrders.length;
    final int totalPages = _totalPages;

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
                    _loadPage(1);
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
                : () => _loadPage(1),
          ),

          // ---------------- PREVIOUS PAGE ----------------
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage == 1 || totalItems == 0
                ? null
                : () => _loadPage(_currentPage - 1),
          ),

          // ---------------- NEXT PAGE ----------------
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () => _loadPage(_currentPage + 1),
          ),

          // ---------------- LAST PAGE ----------------
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage == totalPages || totalItems == 0
                ? null
                : () => _loadPage(totalPages),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(int page) {
    final bool selected = _currentPage == page;

    return InkWell(
      onTap: () {
        setState(() {
          _currentPage = page;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: selected ? Colors.white : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// ================= SHARED CELLS =================

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  const _DataCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Text(text));
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "Completed",
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }
}