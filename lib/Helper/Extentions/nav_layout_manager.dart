import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Preferences/pinaka_preferences.dart';

enum SidebarPosition { left, right, bottom }
enum OrderPanelPosition { left, right }

mixin LayoutSelectionMixin<T extends StatefulWidget> on State<T> { // Build #1.0.240 : UPDATED CODE
  final PinakaPreferences _preferences = PinakaPreferences();

  /// Build #1.0.240 : Updated LayoutSelectionMixin code to fix the Issue [SCRUM - 389] - Mode Switching Between Left & Bottom is Not Static
  // Shared across all instances - loaded once per app session
  static SidebarPosition _currentSidebarPosition = SidebarPosition.left;
  static OrderPanelPosition _currentOrderPanelPosition = OrderPanelPosition.right;
  static bool _isInitialLoadComplete = false;

  SidebarPosition get sidebarPosition => _currentSidebarPosition;
  OrderPanelPosition get orderPanelPosition => _currentOrderPanelPosition;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      print("#### LayoutSelectionMixin[${widget.runtimeType}]: initState");
    }

    if (!_isInitialLoadComplete) {
      // First time loading from DB
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLayoutSelection().then((_) {
          PinakaPreferences.layoutSelectionNotifier.addListener(_onLayoutChanged);
          _isInitialLoadComplete = true;
          if (kDebugMode) {
            print("#### LayoutSelectionMixin: Initial load complete");
          }
        });
      });
    } else {
      // Subsequent screens - use cached values
      PinakaPreferences.layoutSelectionNotifier.addListener(_onLayoutChanged);
    }
  }

  Future<void> _loadLayoutSelection() async {
    final userData = await UserDbHelper().getUserData();
    var savedLayout = userData?[AppDBConst.layoutSelection]; //Build #1.0.122: using from DB

    if (kDebugMode) {
      print("#### LayoutSelectionMixin: DB layout: '$savedLayout'");
    }

    // Only update if we have a saved layout
    if (savedLayout != null && savedLayout.isNotEmpty) {
      _updateLayoutFromPreference(savedLayout, false);
    } else {
      // Set default only if nothing is saved
      String defaultLayout = SharedPreferenceTextConstants.navLeftOrderRight;
    //  await _preferences.saveLayoutSelection(defaultLayout);
      //Build #1.0.122 : update layout mode change selection to DB
      await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: defaultLayout}, modeChange: false);
      _updateLayoutFromPreference(defaultLayout, false);
    }
  }

  void _onLayoutChanged() {
    if (kDebugMode) {
      print("#### LayoutSelectionMixin: Layout changed to: ${PinakaPreferences.layoutSelectionNotifier.value}");
    }
    _updateLayoutFromPreference(PinakaPreferences.layoutSelectionNotifier.value, true);
    // Force order panel to refresh when layout changes (fixes stale orders on navbar toggle)
    OrderHelper.isOrderPanelLoaded = false;
    OrderHelper.notifyOrderPanelToRefresh();
  }

  void _updateLayoutFromPreference(String savedLayout, bool shouldSetState) {
    SidebarPosition newSidebarPosition;
    OrderPanelPosition newOrderPanelPosition;

    switch (savedLayout) {
      case SharedPreferenceTextConstants.navLeftOrderRight:
        newSidebarPosition = SidebarPosition.left;
        newOrderPanelPosition = OrderPanelPosition.right;
        break;
      case SharedPreferenceTextConstants.navRightOrderLeft:
        newSidebarPosition = SidebarPosition.right;
        newOrderPanelPosition = OrderPanelPosition.left;
        break;
      case SharedPreferenceTextConstants.navBottomOrderLeft:
        newSidebarPosition = SidebarPosition.bottom;
        newOrderPanelPosition = OrderPanelPosition.left;
        break;
      case SharedPreferenceTextConstants.navBottomOrderRight:
        newSidebarPosition = SidebarPosition.bottom;
        newOrderPanelPosition = OrderPanelPosition.right;
        break;
      default:
        return;
    }

    // Only update if layout actually changed
    if (newSidebarPosition != _currentSidebarPosition ||
        newOrderPanelPosition != _currentOrderPanelPosition) {

      if (kDebugMode) {
        print("#### LayoutSelectionMixin: Updating layout from $_currentSidebarPosition->$newSidebarPosition");
      }

      _currentSidebarPosition = newSidebarPosition;
      _currentOrderPanelPosition = newOrderPanelPosition;

      if (shouldSetState && mounted) {
        setState(() {});
      }
    } else if (kDebugMode) {
      print("#### LayoutSelectionMixin: Layout unchanged, skipping update");
    }
  }

  @override
  void dispose() {
    PinakaPreferences.layoutSelectionNotifier.removeListener(_onLayoutChanged);
    if (kDebugMode) {
      print("#### LayoutSelectionMixin: Removed listener for layoutSelectionNotifier in ${widget.runtimeType}");
    }
    super.dispose();
  }
}