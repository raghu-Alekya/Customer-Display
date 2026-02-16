import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:pinaka_pos/Screens/Home/apps_dashboard_screen.dart';
import 'package:pinaka_pos/Screens/Home/categories_screen.dart';
import 'package:pinaka_pos/Screens/Home/fast_key_screen.dart';
import 'package:pinaka_pos/Screens/Home/pos_home_screen.dart';
import 'package:pinaka_pos/Widgets/scanner_guard.dart';
import 'package:pinaka_pos/Widgets/widget_topbar.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_animtype.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constants/misc_features.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';

import '../Constants/text.dart';
import '../Blocs/Auth/logout_bloc.dart';
import '../Helper/api_response.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Preferences/pinaka_preferences.dart';
import '../Repositories/Auth/logout_repository.dart';
import '../Screens/Home/add_screen.dart';
import '../Screens/Home/Settings/settings_screen.dart';
import '../Screens/Home/shift_open_close_balance.dart';
import '../Screens/Home/total_orders_screen.dart';
import '../Utilities/svg_images_utility.dart';
import '../services/CustomerDisplayService.dart';
import 'widget_alert_popup_dialogs.dart';

class NavigationBar extends StatelessWidget {
  final int selectedSidebarIndex;
  final Function(int) onSidebarItemSelected;
  final bool isVertical;
  final bool isShiftScreen; // ✅ ADD THIS
  /// When non-null, tapping these indices only calls onSidebarItemSelected (no Navigator push).
  /// Used by POSHomeScreen to switch tabs without replacing route.
  final Set<int>? callbackOnlyIndices;

  const NavigationBar({
    required this.selectedSidebarIndex,
    required this.onSidebarItemSelected,
    this.isVertical = true,
    this.isShiftScreen = false, // default
    this.callbackOnlyIndices,
    Key? key,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context); // Build #1.0.6 - Added theme for navigation bar
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final logoutBloc = LogoutBloc(
        LogoutRepository()); // Build #1.0.163: Initialize LogoutBloc with repository
    return Container(
      width: isVertical ? MediaQuery.of(context).size.width * 0.07 : null,
      height: isVertical ? null : MediaQuery.of(context).size.height * 0.125,
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1023),// latest color
            // color: theme.primaryColor,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: FutureBuilder<String?>(
            //Build #1.0.78: restrict user don't select any other nav buttons first login
            future: _getShiftId(),
            builder: (context, snapshot) {
              // if (snapshot.connectionState == ConnectionState.waiting) {
              //   return Center(child: CircularProgressIndicator());
              // }
              final shiftId = snapshot.data;
              return isVertical
                  ? _buildVerticalLayout(
                  context, shiftId, logoutBloc) // Build #1.0.163
                  : _buildHorizontalLayout(context, shiftId, logoutBloc);
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _getShiftId() async { //Build #1.0.78
    if (kDebugMode) {
      print("### Getting shiftId from database");
    }
    int? shiftId = await UserDbHelper().getUserShiftId(); // Build #1.0.161: added debug prints
    if (kDebugMode) {
      print("### Retrieved shiftId: $shiftId");
    }
    return shiftId.toString();
  }

  Widget _buildVerticalLayout(BuildContext context, String? shiftId, LogoutBloc logoutBloc) {
    int lastSelectedIndex = 0;
    final BuildContext scaffoldContext = context;
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
    bool isShiftInvalid = shiftId == null || shiftId == "null" || shiftId.isEmpty;
    // Build #1.0.221 : Fixed Issue -> Disable navigation bar menu icons while shift create,update,close
    // bool isShiftScreen = ModalRoute.of(context)?.settings.arguments == TextConstants.navLogout ||
    //     ModalRoute.of(context)?.settings.arguments == TextConstants.navShiftHistory;
    bool isShiftScreen = this.isShiftScreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (kDebugMode) {
          print("#### _buildVerticalLayout constraints: $constraints");
        }
        // Dynamic items (scrollable if needed)
        List<Widget> dynamicItems = [
          SidebarButton(
            svgAsset: selectedSidebarIndex == 0 ? SvgUtils.fastKeySelectedIcon : SvgUtils.fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
            label: TextConstants.fastKeyText,
            isSelected: selectedSidebarIndex == 0,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### Fast Keys button tapped");
              }
              lastSelectedIndex = 0; // Store last selection
              onSidebarItemSelected(0);
              if (callbackOnlyIndices?.contains(0) == true) return;

              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              /// POSHomeScreen (Fast Keys tab)
              Navigator.of(context).pushAndRemoveUntil( // Build #1.0.254 : Fixed - Push and replace is showing jump animation for nav bar
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => POSHomeScreen(lastSelectedIndex: 0),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Build #1.0.247 : Updated pushReplacement TO pushAndRemoveUntil
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
              // );
            },
            isVertical: isVertical,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.categoriesIcon,
            label: TextConstants.categoriesText,
            isSelected: selectedSidebarIndex == 1,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 1
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### Categories button tapped");
              }
              lastSelectedIndex = 1; //Build #1.0.7: Store last selection
              onSidebarItemSelected(1);
              if (callbackOnlyIndices?.contains(1) == true) return;

              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              /// POSHomeScreen (Categories tab)
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => POSHomeScreen(lastSelectedIndex: 1),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => CategoriesScreen( lastSelectedIndex: lastSelectedIndex)),
              // );
            },
            isVertical: isVertical,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.addIcon,
            label: TextConstants.addText,
            isSelected: selectedSidebarIndex == 2,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 2
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### AddScreen button tapped");
              }
              lastSelectedIndex = 2;
              onSidebarItemSelected(2);
              if (callbackOnlyIndices?.contains(2) == true) return;
              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              /// POSHomeScreen (Add tab)
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => POSHomeScreen(lastSelectedIndex: 2),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              //  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
              //  );
            },
            isVertical: isVertical,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.ordersIcon,
            label: TextConstants.ordersText,
            isSelected: selectedSidebarIndex == 3,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 3
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### OrdersScreen button tapped");
              }
              lastSelectedIndex = 3;
              onSidebarItemSelected(3);

              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              // Save current POS order before switching to Orders tab
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              /// OrdersScreen
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Build #1.0.245: Fixed Re-Opened [SCRUM - 356] Issue -> Order items not displaying in Bottom Mode
              // -> the processing order is showing when we switch to bottom mode
              // -> Empty Cart/ Items shown for pending orders when move navigation bar to bottom mode.
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushAndRemoveUntil(
              //   context,
              //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)), // Build #1.0.226: Updated class name
              // );
            },
            isVertical: isVertical,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.appsIcon,
            label: TextConstants.appsText,
            isSelected: selectedSidebarIndex == 4,
            onTap: selectedSidebarIndex == 4
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### AppsScreen button tapped");
              }
              lastSelectedIndex = 4;
              onSidebarItemSelected(4);
              /// AppsDashboardScreen
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) =>
              //           AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
              // );
            },
            isVertical: isVertical,
          ),
          // You can add more dynamic items here in the future.
        ];

        // Fixed items (always visible at the bottom)
        Widget fixedItems = Column(
          children: [
            const Divider(color: Colors.black54),
            SidebarButton(
              svgAsset: SvgUtils.settingsIcon,
              label: TextConstants.settingsHeaderText,
              isSelected: selectedSidebarIndex == 5,
              onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 5
                  ? () {}
                  : () {
                if (kDebugMode) {
                  print("##### Settings button tapped");
                }
                lastSelectedIndex = selectedSidebarIndex; // Build #1.0.7: Store before navigating

                onSidebarItemSelected(5); // Highlight settings

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child; // No transition animation
                    },
                    transitionDuration: Duration.zero, // Instant transition
                  ),
                ).then((_) {
                  // Restore the sidebar selection when coming back
                  onSidebarItemSelected(lastSelectedIndex);
                });
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => SettingsScreen(),
                //   ),
                // ).then((_) {
                //   // Restore the sidebar selection when coming back
                //   onSidebarItemSelected(lastSelectedIndex);
                // });
              },
              isVertical: isVertical,
              isDisabled: isShiftInvalid || isShiftScreen,
            ),
            const SizedBox(height: 10),
            SidebarButton(
              svgAsset: SvgUtils.logoutIcon,
              label: TextConstants.logoutText,
              isSelected: selectedSidebarIndex == 6,
              onTap: isShiftInvalid || isShiftScreen // Build #1.0.247: Enabled Multiple click for Logout
                  ? () {}
                  : () {
                onSidebarItemSelected(6);
                if (kDebugMode) {
                  print("nav logout called");
                }
                _showLogoutDialog(context,logoutBloc,themeHelper);
              },
              isVertical: isVertical,
              isDisabled: isShiftInvalid || isShiftScreen,
            ),
            const SizedBox(height: 10),
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(top: 10.0), // Adjust padding as needed
          child: Column(
            children: [
              // Dynamic part: scrollable on small screens, fixed layout on larger screens.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(top: 0),
                  children: dynamicItems,
                ),
              ),
              fixedItems,
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, String? shiftId, LogoutBloc logoutBloc) {
    int lastSelectedIndex = 0;
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
    bool isShiftInvalid = shiftId == null || shiftId == "null" || shiftId.isEmpty;
    // // Build #1.0.221 : Fixed Issue -> Disable navigation bar menu icons while shift create,update,close
    // bool isShiftScreen = ModalRoute.of(context)?.settings.arguments == TextConstants.navLogout ||
    //     ModalRoute.of(context)?.settings.arguments == TextConstants.navShiftHistory;
    bool isShiftScreen = this.isShiftScreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (kDebugMode) {
          print("#### _buildHorizontalLayout constraints: $constraints");
        }
        // Dynamic items (scrollable horizontally if needed)
        List<Widget> dynamicItems = [
          SidebarButton(
            svgAsset: selectedSidebarIndex == 0 ? SvgUtils.fastKeySelectedIcon : SvgUtils.fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
            label: TextConstants.fastKeyText,
            isSelected: selectedSidebarIndex == 0,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### Fast Keys button tapped");
              }
              lastSelectedIndex = 0; // Store last selection
              onSidebarItemSelected(0);
              if (callbackOnlyIndices?.contains(0) == true) return;

              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              /// POSHomeScreen (Fast Keys tab)
              Navigator.of(context).pushAndRemoveUntil( // Build #1.0.254 : Fixed - Push and replace is showing jump animation for nav bar
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => POSHomeScreen(lastSelectedIndex: 0),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
              // );
            },
            isVertical: false, //Build #1.0.54: updated
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.categoriesIcon,
            label: TextConstants.categoriesText,
            isSelected: selectedSidebarIndex == 1,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 1
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### Categories button tapped");
              }
              lastSelectedIndex = 1; // Store last selection
              onSidebarItemSelected(1);
              if (callbackOnlyIndices?.contains(1) == true) return;
              /// CategoriesScreen
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => CategoriesScreen(lastSelectedIndex: lastSelectedIndex),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) =>
              //           CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
              // );
            },
            isVertical: false,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.addIcon,
            label: TextConstants.addText,
            isSelected: selectedSidebarIndex == 2,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 2
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### AddScreen button tapped");
              }
              lastSelectedIndex = 2;
              onSidebarItemSelected(2);
              if (callbackOnlyIndices?.contains(2) == true) return;
              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              /// POSHomeScreen (Add tab)
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => POSHomeScreen(lastSelectedIndex: 2),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => AddScreen()),
              // );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
            },
            isVertical: false,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.ordersIcon,
            label: TextConstants.ordersText,
            isSelected: selectedSidebarIndex == 3,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 3
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### OrdersScreen button tapped");
              }
              lastSelectedIndex = 3;
              onSidebarItemSelected(3);

              OrderHelper.isOrderPanelLoaded = false;
              OrderHelper.notifyOrderPanelToRefresh();
              // Save current POS order before switching to Orders tab
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              /// OrdersScreen
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)), // Build #1.0.226: Updated class name
              // );
            },
            isVertical: false,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.appsIcon,
            label: TextConstants.appsText,
            isSelected: selectedSidebarIndex == 4,
            onTap: selectedSidebarIndex == 4
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### AppsScreen button tapped");
              }
              lastSelectedIndex = 4;
              onSidebarItemSelected(4);
              ///
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
                    (route) => false,
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => AppsDashboardScreen()),
              // );
            },
            isVertical: false,
          ),
          // Additional dynamic items can be added here.
        ];

        // Fixed items that remain visible (on the right)
        List<Widget> fixedItems = [
          const VerticalDivider(color: Colors.black54),
          SidebarButton(
            svgAsset: SvgUtils.settingsIcon,
            label: TextConstants.settingsHeaderText,
            isSelected: selectedSidebarIndex == 5,
            onTap: isShiftInvalid || isShiftScreen || selectedSidebarIndex == 5
                ? () {}
                : () {
              if (kDebugMode) {
                print("##### Settings button tapped");
              }
              lastSelectedIndex = selectedSidebarIndex; // Store before navigating

              onSidebarItemSelected(5); // Highlight settings

              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return child; // No transition animation
                  },
                  transitionDuration: Duration.zero, // Instant transition
                ),
              ).then((_) {
                // Restore the sidebar selection when coming back
                onSidebarItemSelected(lastSelectedIndex);
              });
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => SettingsScreen()),
              // ).then((_) {
              //   // Restore the sidebar selection when coming back
              //   onSidebarItemSelected(lastSelectedIndex);
              // });
            },
            isVertical: false,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(width: 10),
          SidebarButton(
            svgAsset: SvgUtils.logoutIcon,
            label: TextConstants.logoutText,
            isSelected: selectedSidebarIndex == 6,
            onTap: isShiftInvalid || isShiftScreen
                ? () {}
                : () {
              onSidebarItemSelected(6);
              if (kDebugMode) {
                print("nav logout called");
              }
              _showLogoutDialog(context,logoutBloc,themeHelper);
            },
            isVertical: false,
            isDisabled: isShiftInvalid || isShiftScreen,
          ),
          const SizedBox(width: 10),
        ];

        // Dynamic part: scrollable if small, evenly spaced if not.
        Widget dynamicRow = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: dynamicItems,
          ),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              16, 0, 16, 0), // Adjust padding as needed
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dynamic part takes the available space.
              Expanded(child: dynamicRow),
              // Fixed items remain at the end.
              Row(
                children: fixedItems,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handles swipe-to-close-shift: checks for open orders, then navigates to close shift screen or shows warning.
  void _handleSwipeToCloseShift(BuildContext context, NavigatorState navigator, bool isDarkMode) async {
    final orderHelper = OrderHelper();
    // Use loadData (Hive) - app's primary order storage - not loadProcessingData (SQLite)
    await orderHelper.loadData();

    if (orderHelper.orders.isNotEmpty) {
      if (kDebugMode) {
        print("Processing Orders > 0 -> orders length: ${orderHelper.orders.length}");
      }
      navigator.pop(); // close logout dialog
      // Show Close Shift Warning popup (use navigator.context - dialog context may be invalid after pop)
      showDialog(
        context: navigator.context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 60),
            child: SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      "Close Shift Warning",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please close all open orders before closing shift",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScannerGuard.isCouponPopupOpen = false;
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text("OK", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      if (kDebugMode) print("No open orders -> navigating to close shift");
      navigator.pop(); // close logout dialog
      ScannerGuard.isCouponPopupOpen = false;
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ShiftOpenCloseBalanceScreen(),
          settings: const RouteSettings(arguments: TextConstants.navLogout),
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context,LogoutBloc logoutBloc, ThemeNotifier themeHelper){
    ScannerGuard.isCouponPopupOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDarkMode = themeHelper.themeMode == ThemeMode.dark;

        return Dialog(
          backgroundColor: Colors.transparent, // transparent to show tilted container
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center, // centers both horizontally & vertically
            children: [
              // 🔹 Tilted outer container
              Transform.rotate(
                angle: 0.04,
                child: Container(
                  width: 380,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF434242) // dark mode border
                          : Colors.white,           // light mode border
                      width: 3,
                    ),
                  ),
                ),
              ),

              // Inner dialog
              SizedBox(
                width: 370,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF434242)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center, // vertical center
                    crossAxisAlignment: CrossAxisAlignment.center, // horizontal center
                    children: [
                      Image.asset(
                        "assets/logout.png",
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Are you sure?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Choose what would you like to do before leaving",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // 🔹 Swipe Button
                      SizedBox(
                        width: 300,
                        child: SwipeButton(
                          thumb: Container(
                            width: 70,
                            height: 35,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF033495), Color(0xFF3CCBFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.double_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(18),
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF033495), Color(0xFF3CCBFF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              TextConstants.swipeToCloseShift,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          onSwipe: () {
                            // Capture navigator before any async work - context may be invalid after pop
                            final navigator = Navigator.of(context);
                            _handleSwipeToCloseShift(context, navigator, isDarkMode);
                          },
                        ),
                      ),

                      const SizedBox(height: 35),

                      // 🔹 Cancel & Logout buttons
                      Row(
                        children: [
                          SizedBox(
                            width: 160, // 🔹 set your desired width here
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode
                                    ? const Color(0xFF4C5F7D)
                                    : const Color(0xFFF6F6F6),
                                fixedSize: const Size(double.infinity, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6), // ✅ reduced border radius
                                ),
                              ),
                              onPressed: () {
                                ScannerGuard.isCouponPopupOpen = false;
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                TextConstants.cancelText,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? ThemeNotifier.textDark
                                      : const Color(0xFF4C5F7D),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),
                          SizedBox(
                            width: 150, // 🔹 Set desired width here
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFE6464),
                                fixedSize: const Size(double.infinity, 45), // keeps fixed height = 45
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6), // ✅ reduced border radius
                                ),
                              ),
                              onPressed: () async {
                                if (kDebugMode) print("Logout confirmed, initiating logout process");

                                // Show loader
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(child: CircularProgressIndicator()),
                                );

                                // 1️⃣ Logout user from DB
                                await UserDbHelper().logout();

                                // 2️⃣ Clear SharedPreferences
                                await PinakaPreferences.clearUserPreferences();

                                // 3️⃣ Clear TopBar cached user data 🔥 USE PUBLIC METHOD
                                TopBar.clearUserCache();

                                // 4️⃣ Clear any other runtime cache
                                // VendorData.clearAll();

                                if (kDebugMode) {
                                  print("#### User data cleared during logout");
                                }

                                // 5️⃣ Close loader
                                Navigator.of(context).pop();

                                // 6️⃣ Navigate to login screen
                                ScannerGuard.isCouponPopupOpen = false;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: Text(
                                TextConstants.logoutText,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          )

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SidebarButton extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isVertical;
  final bool isDisabled;

  const SidebarButton({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isVertical = true,
    this.isDisabled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
      child: GestureDetector(
        onTap: onTap,
        child: isVertical
            ? _buildVerticalLayout(context)
            : _buildHorizontalLayout(),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: [
        Container(
          width: MediaQuery
              .of(context)
              .size
              .width * 0.05,
          padding: const EdgeInsets.only(
              top: 10.0, bottom: 10, left: 2, right: 2),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: isSelected ? Color(0xFFFE6464) : Color(0xFF3B4259),
            // latest color
            // color: isSelected ? Colors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              svgAsset != null
                  ? SvgPicture
                  .asset( // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
                svgAsset!,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? Colors.white
                      : isDisabled
                      ? Colors.grey.shade800
                      : Colors.white70,
                  BlendMode.srcIn,
                ),
                height: 20,
              )
                  : Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : isDisabled
                    ? Colors.grey.shade800
                    : Colors.white70,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                      ? Colors.grey.shade800
                      : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: isSelected ? 11.0 : 10.0, // Increase if selected
                ),
                textAlign: TextAlign.center,
              ),

            ],
          ),
        )
      ],
    );
  }

  Widget _buildHorizontalLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: isSelected ? Color(0xFFFE6464) : const Color(0xFF3B4259),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          svgAsset != null
              ? SvgPicture.asset(
            svgAsset!,
            colorFilter: ColorFilter.mode(
              isSelected
                  ? Colors.white
                  : isDisabled
                  ? Colors.grey.shade800
                  : Colors.white70,
              BlendMode.srcIn,
            ),

            height: 22,
          )
              : Icon(
            icon,
            color: isSelected
                ? Colors.white
                : isDisabled
                ? Colors.grey.shade800
                : Colors.white,
          ),
          SizedBox(width: isSelected ? 6.0 : 4.0),
          // const SizedBox(width: 6), // reduced from 10
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isDisabled
                  ? Colors.grey.shade800
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isSelected ? 16.0 : 14.0, // Slight increase if selected
            ),
          ),

        ],
      ),
    );
  }
}