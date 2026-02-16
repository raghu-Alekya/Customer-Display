import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Widgets/widget_tabs.dart';

import '../../Constants/misc_features.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/widget_category_list.dart';
import '../../Widgets/widget_logs_toast.dart';
import '../../Widgets/widget_nested_grid_layout.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_topbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Widgets/widget_custom_num_pad.dart';

class AddScreen extends StatefulWidget { // Build #1.0.6 - Updated Horizontal & Vertical Scrolling
  final int? lastSelectedIndex; // Make it nullable
  int selectedTabIndex = 0;
  String barcode = "";
  /// When true, only the center content is shown (no TopBar, NavBar, RightOrderPanel).
  final bool embedInShell;
  AddScreen({super.key, this.lastSelectedIndex, this.selectedTabIndex = 0, this.barcode = "", this.embedInShell = false}); // Optional, no default value


  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> with LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 2; //Build #1.0.2 : By default fast key should be selected after login
  List<int> quantities = [1, 1, 1, 1];
  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null); // Add this
  final PinakaPreferences _preferences = PinakaPreferences(); //Build #1.0.84: Added this
  final OrderHelper orderHelper = OrderHelper();
  int _refreshCounter = 0; //Build #1.0.170: Added - Counter to trigger RightOrderPanel refresh only when needed

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 2; // Build #1.0.7: Restore previous selection
  }

  // //Build 1.1.36: Update the products loading to not add to navigation path
  // // Explanation:
  // // Added sku to OrderLineItem in the API call, using the same placeholder format (SKU${name}) as the original code.
  // // Moved database operations to OrderBloc.updateOrderProducts (already updated to handle database updates).
  // // Added dbOrderId parameter to updateOrderProducts.
  // // Kept local insertion via orderHelper.addItemToOrder for non-API orders.
  // // Added isAddingItemLoading to show a loader during API calls.
  // // Added alert dialog with retry option for API failures.
  // // Added success toasts for both API and local cases.
  // // Preserved debug prints, variantAdded logic, and back button functionality.
  // Stopwatch? refreshUIStopwatch; // Build #1.0.256
  void _refreshOrderList() {
    setState(() { // Build #1.0.128
      if (kDebugMode) {
        print("##### _refreshOrderList: Incrementing _refreshCounter to $_refreshCounter to trigger RightOrderPanel refresh");
      }
      _refreshCounter++; //Build #1.0.170: Increment to signal refresh, causing didUpdateWidget to load with loader
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedInShell) {
      return AppScreenTabWidget(
        selectedTabIndex: widget.selectedTabIndex,
        barcode: widget.barcode,
        scaffoldMessengerContext: context,
        refreshOrderList: _refreshOrderList,
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            TopBar(
              screen: Screen.ADD,
              onModeChanged: () async{ /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
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

                //Update the notifier which will trigger _onLayoutChanged
                PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                // No need to call saveLayoutSelection here as it's handled in the notifier
                // _preferences.saveLayoutSelection(newLayout);
                //Build #1.0.122: update layout mode change selection to DB
                await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
                // update UI
                setState(() {});
              },
              onProductSelected: (product) async { //Build #1.0.126: Missed code added
                if (kDebugMode) print("#### AddScreen onProductSelected");
                double price;
                try {
                  price = double.tryParse(product.price ?? '0.00') ?? 0.00;
                } catch (e) {
                  price = 0.00;
                }

                final serverOrderId = orderHelper.activeOrderId;
                final dbOrderId = orderHelper.activeOrderId;

                try {
                  //  if (serverOrderId != null) { ///Build #1.0.128: No need to check this condition
                  if (kDebugMode) print("#### AddScreen serverOrderId");
                  _refreshOrderList();
                } catch (e, s) {
                  if (kDebugMode) print("Exception in onProductSelected: $e, Stack: $s");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error adding item"),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            Divider(
              color: Colors.grey, // Light grey color
              thickness: 0.4, // Very thin line
              height: 1, // Minimal height
            ),
            // Main Content
            Expanded(
              child: Row(
                children: [
                  // Left Sidebar (Conditional)
                  if (sidebarPosition == SidebarPosition.left)
                    custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
                      selectedSidebarIndex: _selectedSidebarIndex,
                      onSidebarItemSelected: (index) {
                        setState(() {
                          _selectedSidebarIndex = index;
                        });
                      },
                      isVertical: true, // Vertical layout for left sidebar
                    ),

                  // Order Panel on the Left (Conditional: Only when sidebar is right or bottom with left order panel)
                  if (sidebarPosition == SidebarPosition.right ||
                      (sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
                    RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList, // Pass the callback
                      refreshKey: _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
                    ),

                  Expanded(child: AppScreenTabWidget(selectedTabIndex: widget.selectedTabIndex,barcode: widget.barcode, scaffoldMessengerContext: context, refreshOrderList: _refreshOrderList)), // Build #1.0.53

                  // Order Panel on the Right (Conditional: Only when sidebar is left or bottom with right order panel)
                  if (sidebarPosition != SidebarPosition.right &&
                      !(sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
                    RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList, // Pass the callback
                      refreshKey: _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
                    ),

                  // Right Sidebar (Conditional)
                  if (sidebarPosition == SidebarPosition.right)
                    custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
                      selectedSidebarIndex: _selectedSidebarIndex,
                      onSidebarItemSelected: (index) {
                        setState(() {
                          _selectedSidebarIndex = index;
                        });
                      },
                      isVertical: true, // Vertical layout for right sidebar
                    ),
                ],
              ),
            ),

            // Bottom Sidebar (Conditional)
            if (sidebarPosition == SidebarPosition.bottom)
              custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
                selectedSidebarIndex: _selectedSidebarIndex,
                onSidebarItemSelected: (index) {
                  setState(() {
                    _selectedSidebarIndex = index;
                  });
                },
                isVertical: false, // Horizontal layout for bottom sidebar
              ),
          ],
        ),
      ),
    );
  }

}
