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
import '../Blocs/Orders/refund_validation_bloc.dart';
import '../Database/db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Models/Orders/refund_orderlist_model.dart';
import '../Repositories/Orders/refund_validation_repository.dart';
import '../Widgets/refund_checkin_popup.dart';

enum SidebarPosition { left, right, bottom }
enum OrderPanelPosition { left, right }


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
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];
  int _rowsPerPage = 10;

  // final int _rowsPerPage = 10;
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
  String? selectedTransactionId;
  List<String> transactionIds = [];
  Map<int, String?> selectedTxnPerOrder = {};
  List<String> transactionIdOptions = [];


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
            onModeChanged: () async {
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

              // Update notifier
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;

              // Save to DB
              await UserDbHelper().saveUserSettings(
                {AppDBConst.layoutSelection: newLayout},
                modeChange: true,
              );

              // Refresh UI
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

                          // ✅ collect unique transaction IDs
                          transactionIds = _allOrders
                              .map((o) => o.transactionId)
                              .where((id) => id.isNotEmpty)
                              .toSet()
                              .toList();

                          filteredOrders = _allOrders;
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
          "completed orderlist",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        SizedBox(
          width: 200,
          height: 35,
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
        const SizedBox(width: 18),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: DropdownButton<String>(
              value: selectedStatus,
              isDense: true,

              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),

              dropdownColor: Theme.of(context).colorScheme.surface,

              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),

              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedStatus = value;

                  filteredOrders = value == "Completed"
                      ? _allOrders.where((o) => o.status == "completed").toList()
                      : _allOrders.where((o) => o.status == "refund").toList();

                  _currentPage = 1;
                  _updatePagination();
                });
              },

              items: const [
                DropdownMenuItem(
                    value: "Completed", child: Text("Completed")),
                DropdownMenuItem(
                    value: "Refund", child: Text("Refund")),
              ],
            ),
          ),
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF6F6F70),
              borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 10),

                _HeaderCell("Order ID"),
                _HeaderCell("Order Type"),
                _HeaderCell("Date"),
                _HeaderCell("Transaction ID"),
                // SizedBox(width: 10),
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
                              baseUrl: "https://merchantretail.alektasolutions.com",
                            ),
                          ),
                          child: PinCheckInDialog(order: order),
                        );
                      },
                    );
                  },
                  child: Container(
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
                        _DataCell(
                            order.completedAt.toString().split(' ').first),
                        // _DataCell(order.transactionId),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            behavior: HitTestBehavior.opaque,
                            child: DropdownButtonHideUnderline(
                              child: Builder(
                                builder: (context) {
                                  final List<String> itemsList = [
                                    order.transactionId.toString(),
                                    ...transactionIdOptions.map((e) => e.toString()),
                                  ].toSet().toList();

                                  // ✅ Show only first 2 IDs in display
                                  String displayText = "";

                                  if (itemsList.length == 1) {
                                    displayText = itemsList[0];
                                  } else if (itemsList.length == 2) {
                                    displayText = "${itemsList[0]}, ${itemsList[1]}";
                                  } else if (itemsList.length > 2) {
                                    displayText = "${itemsList[0]}, ${itemsList[1]}...";
                                  }
                                  return DropdownButton<String>(
                                    value: itemsList.first,
                                    isDense: true,
                                    isExpanded: true,
                                    icon: const SizedBox.shrink(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedTxnPerOrder[order.orderId] = value!;
                                      });
                                    },
                                    selectedItemBuilder: (context) {
                                      return itemsList.map((e) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            displayText,
                                            style: const TextStyle(fontSize: 14),
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
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // const SizedBox(width:5),
                        _DataCell(order.paymentMethod),
                        _DataCell(order.amount.toStringAsFixed(2)),
                        _DataCell(order.tax.toStringAsFixed(2)),
                        _DataCell(order.discount.toStringAsFixed(2)),
                        _DataCell(order.total.toStringAsFixed(2)),
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
    final int totalItems = _allOrders.length; // make sure you have this
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "Completed",
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }
}