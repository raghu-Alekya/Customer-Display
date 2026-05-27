import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_topbar.dart';
import 'add_screen.dart';
import 'categories_screen.dart';
import 'fast_key_screen.dart';

/// Single shell for Fast Keys, Categories, and Add tabs.
/// Uses IndexedStack so RightOrderPanel is shared.
class POSHomeScreen extends StatefulWidget {
  final int? lastSelectedIndex;

  const POSHomeScreen({super.key, this.lastSelectedIndex});

  @override
  State<POSHomeScreen> createState() => _POSHomeScreenState();
}

class _POSHomeScreenState extends State<POSHomeScreen> with LayoutSelectionMixin {
  int _selectedSidebarIndex = 0;
  int _activeTabIndex = 0;
  int _refreshCounter = 0;
  final OrderHelper orderHelper = OrderHelper();
  final List<int> quantities = [1, 1, 1, 1];

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 0;
    _activeTabIndex = _selectedSidebarIndex.clamp(0, 2);

    // ✅ Prevent mode change listener from firing during tab navigation
    // TopBar.modeChangedNotifier.addListener(_onModeChanged);
  }

  // void _onModeChanged() {
  //   // Guard: Ignore mode change if we are navigating via sidebar to other screens
  //   final routeName = ModalRoute.of(context)?.settings.name;
  //   if (routeName != null && routeName.contains('_tab')) {
  //     print("🚫 Blocked unwanted mode change during tab navigation");
  //     return;
  //   }
  //
  //   print("✅ Mode changed via TopBar button");
  //   setState(() {}); // Rebuild layout
  // }

  @override
  void dispose() {
    // TopBar.modeChangedNotifier.removeListener(_onModeChanged);
    super.dispose();
  }

  void _refreshOrderList() {
    setState(() => _refreshCounter++);
  }

  Screen _getScreenForIndex(int index) {
    switch (index) {
      case 0:
        return Screen.FASTKEY;
      case 1:
        return Screen.CATEGORY;
      case 2:
        return Screen.ADD;
      default:
        return Screen.FASTKEY;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              screen: _getScreenForIndex(_activeTabIndex),
              onModeChanged: () async {
                // ✅ This is the ONLY place mode changes happen now
                print("🔄 [POSHomeScreen] Mode change triggered from button");

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

                PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true,
                );
                setState(() {});
              },
              onProductSelected: (product) async {
                try {
                  _refreshOrderList();
                } catch (e, s) {
                  if (kDebugMode) print("Exception in onProductSelected: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(TextConstants.errorAddingItem),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(color: Colors.grey, thickness: 0.4, height: 1),
            Expanded(
              child: Row(
                children: [
                  if (sidebarPosition == SidebarPosition.left)
                    custom_widgets.NavigationBar(
                      selectedSidebarIndex: _selectedSidebarIndex,
                      onSidebarItemSelected: _handleSidebarSelection,
                      isVertical: true,
                      callbackOnlyIndices: const {0, 1, 2},
                    ),
                  if (sidebarPosition == SidebarPosition.right ||
                      (sidebarPosition == SidebarPosition.bottom &&
                          orderPanelPosition == OrderPanelPosition.left))
                    RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList,
                      refreshKey: _refreshCounter,
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTabIndex,
                      children: [
                        const FastKeyScreen(embedInShell: true),
                        const CategoriesScreen(embedInShell: true),
                        AddScreen(embedInShell: true),
                      ],
                    ),
                  ),
                  if (sidebarPosition != SidebarPosition.right &&
                      !(sidebarPosition == SidebarPosition.bottom &&
                          orderPanelPosition == OrderPanelPosition.left))
                    RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList,
                      refreshKey: _refreshCounter,
                    ),
                  if (sidebarPosition == SidebarPosition.right)
                    custom_widgets.NavigationBar(
                      selectedSidebarIndex: _selectedSidebarIndex,
                      onSidebarItemSelected: _handleSidebarSelection,
                      isVertical: true,
                      callbackOnlyIndices: const {0, 1, 2},
                    ),
                ],
              ),
            ),
            if (sidebarPosition == SidebarPosition.bottom)
              custom_widgets.NavigationBar(
                selectedSidebarIndex: _selectedSidebarIndex,
                onSidebarItemSelected: _handleSidebarSelection,
                isVertical: false,
                callbackOnlyIndices: const {0, 1, 2},
              ),
          ],
        ),
      ),
    );
  }

  // ✅ Centralized handler to avoid duplication and race conditions
  void _handleSidebarSelection(int index) {
    // ✅ Pure tab switch — never touches mode
    setState(() {
      _selectedSidebarIndex = index;
      if (index < 3) {
        _activeTabIndex = index;
      }
    });
    print("📍 Sidebar selected: $index (Tab: $_activeTabIndex)");
  }
}
