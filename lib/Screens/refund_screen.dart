import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:pinaka_pos/Screens/Home/refund_screen.dart';
import 'package:provider/provider.dart';

// import '../../Blocs/Orders/refund_order_list_bloc.dart';
import '../../Constants/text.dart';
import '../../Helper/Extentions/theme_notifier.dart';
// import '../../Models/Orders/refund_order_list.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Widgets/widget_order_screen_panel.dart';
import '../../Widgets/widget_topbar.dart';
import '../Blocs/Orders/refund_orderlist_bloc.dart';
import '../Models/Orders/refund_orderlist_model.dart';

enum SidebarPosition { left, right, bottom }
enum OrderPanelPosition { left, right }
// List<int> quantities = [];
// // int _currentPage = 1;
// List<CompletedOrder> _allOrders = [];
// // List<CompletedOrder> _allOrders = [];
// List<CompletedOrder> _pagedOrders = [];
// List<CompletedOrder> _visibleOrders = [];
// final int _rowsPerPage = 10;
// int _currentPage = 1;
// int _totalPages = 1;



List<String> allData = List.generate(27, (i) => "Item ${i + 1}");


class CompletedOrdersScreen extends StatefulWidget {
  const CompletedOrdersScreen({super.key, required int lastSelectedIndex});

  @override
  State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  int _selectedSidebarIndex = 5;
  int _currentPage = 1;

  int itemsPerPage = 10;


  final int _rowsPerPage = 10;
  List<int> quantities = [];
// int _currentPage = 1;
  List<CompletedOrder> _allOrders = [];
  List<CompletedOrder> filteredOrders = [];
// List<CompletedOrder> _allOrders = [];
  List<CompletedOrder> _pagedOrders = [];
  List<CompletedOrder> _visibleOrders = [];
  // final int _rowsPerPage = 10;
  // int _currentPage = 1;
  int _totalPages = 1;
  TextEditingController searchController = TextEditingController();
  String selectedStatus = 'Completed';


  List<CompletedOrder> _orders = [];
  // int _totalPages = 1;
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
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;

    _pagedOrders = _allOrders.sublist(
      startIndex,
      endIndex > _allOrders.length ? _allOrders.length : endIndex,
    );
  }



  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
      _paginate();
    });
  }
  void _updatePagination() {
    final startIndex = (_currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    setState(() {
      _pagedOrders = filteredOrders.sublist(
        startIndex,
        endIndex > filteredOrders.length
            ? filteredOrders.length
            : endIndex,
      );
    });
  }



  // @override
  @override
  void initState() {
    super.initState();
    // _allOrders = widget.orders; // or loaded data
    filteredOrders = _allOrders;

    context.read<CompletedOrdersBloc>().add(
      FetchCompletedOrders(
        page: 1,
        perPage: 100, // ✅ required
      ),
    );
  }

  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final layout = PinakaPreferences.layoutSelectionNotifier.value;

// Defaults
    SidebarPosition sidebarPosition = SidebarPosition.left;
    OrderPanelPosition orderPanelPosition = OrderPanelPosition.right;

// 🔥 SAME LOGIC AS OrdersScreen
    if (layout == SharedPreferenceTextConstants.navRightOrderLeft) {
      sidebarPosition = SidebarPosition.right;
      orderPanelPosition = OrderPanelPosition.left;
    } else if (layout == SharedPreferenceTextConstants.navBottomOrderLeft) {
      sidebarPosition = SidebarPosition.bottom;
      orderPanelPosition = OrderPanelPosition.left;
    } else if (layout == SharedPreferenceTextConstants.navBottomOrderRight) {
      sidebarPosition = SidebarPosition.bottom;
      orderPanelPosition = OrderPanelPosition.right;
    } else {
      sidebarPosition = SidebarPosition.left;
      orderPanelPosition = OrderPanelPosition.right;
    }


    return Scaffold(
      body: Column(
        children: [
          /// 🔹 TOP BAR (same as Orders screen)
          TopBar(
            screen: Screen.ORDERS,
            onModeChanged: () {
              setState(() {});
            },
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
                  child: BlocConsumer<CompletedOrdersBloc, CompletedOrdersState>(
                    listener: (context, state) {
                      if (state is CompletedOrdersLoaded) {
                        setState(() {
                          _allOrders = state.orders;
                          _currentPage = 1;
                          _totalPages = (_allOrders.length / _rowsPerPage).ceil();
                          _paginate();
                        });
                      }
                    },

                    builder: (context, state) {
                      if (state is CompletedOrdersLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is CompletedOrdersError) {
                        return Center(
                          child: Text(
                            state.message,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      // Loaded / Initial
                      return Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.primaryBackground
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            /// 🔹 HEADER
                            _buildHeader(),

                            const SizedBox(height: 8),

                            /// 🔹 TABLE
                            Expanded(child: _buildOrderTable(themeHelper)),

                            /// 🔹 PAGINATION
                            const SizedBox(height: 8),
                            _buildPagination(),
                          ],
                        ),
                      );
                    },
                  ),
                ),


                /// 🔹 RIGHT ORDER PANEL (same behavior as Orders)
                // if (sidebarPosition != SidebarPosition.right)
                //   OrderScreenPanel(
                //     fetchOrders: true,
                //     formattedDate: '',
                //     formattedTime: '',
                //     quantities: quantities,
                //     activeOrderId: null,
                //     refreshOrderList: () {},
                //   ),

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
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          "status",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        SizedBox(
          width: 220,
          child: TextField(
            controller: searchController,
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

                _currentPage = 1; // Reset to first page after search
                _updatePagination();
              });
            },
            decoration: InputDecoration(
              hintText: "Search Order ID",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    filteredOrders = _allOrders;
                    _currentPage = 1;
                    _updatePagination();
                  });
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: selectedStatus,
          items: const [
            DropdownMenuItem(
              value: "Completed",
              child: Text("Completed"),
            ),
            DropdownMenuItem(
              value: "Refund",
              child: Text("Refund"),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              selectedStatus = value;
            });
          },
        ),
      ],
    );
  }

  // ================= TABLE =================

  Widget _buildOrderTable(ThemeNotifier themeHelper) {
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF6F6F70),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                _HeaderCell("Order ID"),
                _HeaderCell("Order Type"),
                _HeaderCell("Date"),
                _HeaderCell("Transaction ID"),
                const SizedBox(width:10),
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
              itemBuilder: (_, index) {
                final order = _pagedOrders[index];

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFD8D7D7)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _DataCell("#${order.orderId}"),
                      _DataCell(order.orderType),
                      _DataCell(order.completedAt.toString().split(' ').first),
                      _DataCell(order.transactionId),
                      const SizedBox(width: 25),
                      _DataCell(order.paymentMethod),
                      _DataCell(order.amount.toStringAsFixed(2)),
                      _DataCell(order.tax.toStringAsFixed(2)),
                      _DataCell(order.discount.toStringAsFixed(2)),
                      _DataCell(order.total.toStringAsFixed(2)),
                      const _StatusCell(),
                    ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _currentPage > 1
              ? () => _loadPage(_currentPage - 1)
              : null,
          child: const Text("Previous"),
        ),

        for (int i = 1; i <= _totalPages; i++)
          InkWell(
            onTap: () => _loadPage(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _currentPage == i ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                "$i",
                style: TextStyle(
                  color: _currentPage == i ? Colors.white : Colors.red,
                ),
              ),
            ),
          ),

        TextButton(
          onPressed: _currentPage < _totalPages
              ? () => _loadPage(_currentPage + 1)
              : null,
          child: const Text("Next"),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Completed",
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }
}