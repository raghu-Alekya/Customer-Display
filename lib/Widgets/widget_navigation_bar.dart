// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:isar/isar.dart';
// import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
// import 'package:pinaka_pos/Screens/Home/apps_dashboard_screen.dart';
// import 'package:pinaka_pos/Screens/Home/categories_screen.dart';
// import 'package:pinaka_pos/Screens/Home/fast_key_screen.dart';
// import 'package:pinaka_pos/Screens/Home/pos_home_screen.dart';
// import 'package:pinaka_pos/Widgets/scanner_guard.dart';
// import 'package:pinaka_pos/Widgets/widget_topbar.dart';
// import 'package:provider/provider.dart';
// import 'package:quickalert/models/quickalert_animtype.dart';
// import 'package:quickalert/models/quickalert_type.dart';
// import 'package:quickalert/widgets/quickalert_dialog.dart';
// import 'package:flutter_swipe_button/flutter_swipe_button.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Blocs/Orders/refund_orderlist_bloc.dart';
// import '../Constants/misc_features.dart';
// import '../Database/isar_cache_entry.dart';
// import '../Database/isar_service.dart';
// import '../Database/order_panel_db_helper.dart';
// import '../Database/user_db_helper.dart';
// import '../Helper/Extentions/theme_notifier.dart';
//
// import '../Constants/text.dart';
// import '../Blocs/Auth/logout_bloc.dart';
// import '../Helper/api_response.dart';
// import '../Helper/customerdisplayhelper.dart';
// import '../Preferences/pinaka_preferences.dart';
// import '../Repositories/Auth/logout_repository.dart';
// import '../Repositories/Orders/refund_orderlist_repository.dart';
// import '../Screens/Auth/store_id_screen.dart';
// import '../Screens/Home/add_screen.dart';
// import '../Screens/Home/Settings/settings_screen.dart';
// import '../Screens/Home/shift_open_close_balance.dart';
// import '../Screens/Home/total_orders_screen.dart';
// import '../Screens/refund_screen.dart';
// import '../Utilities/svg_images_utility.dart';
// import '../services/CustomerDisplayService.dart';
// import 'widget_alert_popup_dialogs.dart';
//
// class NavigationBar extends StatelessWidget {
//   final int selectedSidebarIndex;
//   final Function(int) onSidebarItemSelected;
//   final bool isVertical;
//   final bool isShiftScreen; // ✅ ADD THIS
//   final Future<bool> Function(int index)? onWillNavigate;
//
//   /// When non-null, tapping these indices only calls onSidebarItemSelected (no Navigator push).
//   /// Used by POSHomeScreen to switch tabs without replacing route.
//   final Set<int>? callbackOnlyIndices;
//
//   const NavigationBar({
//     required this.selectedSidebarIndex,
//     required this.onSidebarItemSelected,
//     this.isVertical = true,
//     this.isShiftScreen = false, // default
//     this.onWillNavigate,
//     this.callbackOnlyIndices,
//     Key? key,
//   }) : super(key: key);
//
//   Future<bool> _canNavigate(int index) async {
//     return await onWillNavigate?.call(index) ?? true;
//   }
//
//   String todayStart() {
//     final now = DateTime.now();
//     return DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
//   }
//
//   String todayEnd() {
//     final now = DateTime.now();
//     return DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
//   }
//
//   Future<void> _clearAllCategoryCaches() async {
//     try {
//       final isar = await IsarService.instance;
//
//       await isar.writeTxn(() async {
//         await isar.isarCacheEntrys.clear(); // Clears ALL cached entries
//       });
//
//       if (kDebugMode) {
//         print("🧹 All Isar cache cleared on logout");
//       }
//     } catch (e) {
//       if (kDebugMode) print("⚠️ Failed to clear Isar cache: $e");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(
//       context,
//     ); // Build #1.0.6 - Added theme for navigation bar
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     final logoutBloc = LogoutBloc(
//       LogoutRepository(),
//     ); // Build #1.0.163: Initialize LogoutBloc with repository
//     return Container(
//       width: isVertical ? MediaQuery.of(context).size.width * 0.07 : null,
//       height: isVertical ? null : MediaQuery.of(context).size.height * 0.125,
//       color: theme.scaffoldBackgroundColor,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
//         child: Container(
//           decoration: BoxDecoration(
//             color: const Color(0xFF0B1023), // latest color
//             // color: theme.primaryColor,
//             borderRadius: BorderRadius.all(Radius.circular(10)),
//           ),
//           child: FutureBuilder<String?>(
//             //Build #1.0.78: restrict user don't select any other nav buttons first login
//             future: _getShiftId(),
//             builder: (context, snapshot) {
//               // if (snapshot.connectionState == ConnectionState.waiting) {
//               //   return Center(child: CircularProgressIndicator());
//               // }
//               final shiftId = snapshot.data;
//               return isVertical
//                   ? _buildVerticalLayout(
//                       context,
//                       shiftId,
//                       logoutBloc,
//                     ) // Build #1.0.163
//                   : _buildHorizontalLayout(context, shiftId, logoutBloc);
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<String?> _getShiftId() async {
//     //Build #1.0.78
//     if (kDebugMode) {
//       print("### Getting shiftId from database");
//     }
//     int? shiftId = await UserDbHelper()
//         .getUserShiftId(); // Build #1.0.161: added debug prints
//     if (kDebugMode) {
//       print("### Retrieved shiftId: $shiftId");
//     }
//     return shiftId.toString();
//   }
//
//   Widget _buildVerticalLayout(
//     BuildContext context,
//     String? shiftId,
//     LogoutBloc logoutBloc,
//   ) {
//     int lastSelectedIndex = 0;
//     final BuildContext scaffoldContext = context;
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
//     bool isShiftInvalid =
//         shiftId == null || shiftId == "null" || shiftId.isEmpty;
//     // Build #1.0.221 : Fixed Issue -> Disable navigation bar menu icons while shift create,update,close
//     // bool isShiftScreen = ModalRoute.of(context)?.settings.arguments == TextConstants.navLogout ||
//     //     ModalRoute.of(context)?.settings.arguments == TextConstants.navShiftHistory;
//     bool isShiftScreen = this.isShiftScreen;
//
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         if (kDebugMode) {
//           print("#### _buildVerticalLayout constraints: $constraints");
//         }
//         // Dynamic items (scrollable if needed)
//         List<Widget> dynamicItems = [
//           SidebarButton(
//             svgAsset: selectedSidebarIndex == 0
//                 ? SvgUtils.fastKeySelectedIcon
//                 : SvgUtils
//                     .fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
//             label: TextConstants.fastKeyText,
//             isSelected: selectedSidebarIndex == 0,
//             onTap: isShiftScreen ||
//                     selectedSidebarIndex ==
//                         0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//
//                     if (!await _canNavigate(0)) return;
//                     lastSelectedIndex = 0;
//                     onSidebarItemSelected(0);
//                     if (callbackOnlyIndices?.contains(0) == true) return;
//
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         // Build #1.0.254 : Fixed - Push and replace is showing jump animation for nav bar
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 0),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Build #1.0.247 : Updated pushReplacement TO pushAndRemoveUntil
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
//                     // );
//                   },
//             isVertical: isVertical,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.categoriesIcon,
//             label: TextConstants.categoriesText,
//             isSelected: selectedSidebarIndex == 1,
//             onTap: (isShiftScreen || selectedSidebarIndex == 1)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(1)) return;
//                     lastSelectedIndex = 1;
//                     onSidebarItemSelected(1);
//                     if (callbackOnlyIndices?.contains(1) == true) return;
//
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 1),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => CategoriesScreen( lastSelectedIndex: lastSelectedIndex)),
//                     // );
//                   },
//             isVertical: isVertical,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.addIcon,
//             label: TextConstants.addText,
//             isSelected: selectedSidebarIndex == 2,
//             onTap: (isShiftScreen || selectedSidebarIndex == 2)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(2)) return;
//                     lastSelectedIndex = 2;
//                     onSidebarItemSelected(2);
//                     if (callbackOnlyIndices?.contains(2) == true) return;
//
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 2),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     //  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //  );
//                   },
//             isVertical: isVertical,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.ordersIcon,
//             label: TextConstants.ordersText,
//             isSelected: selectedSidebarIndex == 3,
//             onTap: (isShiftScreen || selectedSidebarIndex == 3)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(3)) return;
//                     lastSelectedIndex = 3;
//                     onSidebarItemSelected(3);
//                     if (callbackOnlyIndices?.contains(3) == true) return;
//
//                     /// OrdersScreen
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   TotalOrdersScreen(
//                             lastSelectedIndex: 3,
//                           ),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Build #1.0.245: Fixed Re-Opened [SCRUM - 356] Issue -> Order items not displaying in Bottom Mode
//                     // -> the processing order is showing when we switch to bottom mode
//                     // -> Empty Cart/ Items shown for pending orders when move navigation bar to bottom mode.
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushAndRemoveUntil(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)), // Build #1.0.226: Updated class name
//                     // );
//                   },
//             isVertical: isVertical,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.appsIcon,
//             label: TextConstants.appsText,
//             isSelected: selectedSidebarIndex == 4,
//             onTap: (selectedSidebarIndex == 4)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(4)) return;
//                     lastSelectedIndex = 4;
//                     onSidebarItemSelected(4);
//                     if (callbackOnlyIndices?.contains(4) == true) return;
//
//                     /// AppsDashboardScreen
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   AppsDashboardScreen(
//                             lastSelectedIndex: 4,
//                           ),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(
//                     //       builder: (context) =>
//                     //           AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
//                     // );
//                   },
//             isVertical: isVertical,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             imageAsset: 'assets/refund.png',
//             label: "Refund",
//             isSelected: selectedSidebarIndex == 5,
//             isDisabled: isShiftInvalid || isShiftScreen,
//             onTap: (isShiftInvalid ||
//                     isShiftScreen ||
//                     selectedSidebarIndex == 5)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(5)) return;
//                     lastSelectedIndex = 5;
//                     onSidebarItemSelected(5);
//                     if (callbackOnlyIndices?.contains(5) == true) return;
//
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   const CompletedOrdersScreen(
//                             lastSelectedIndex: 5,
//                           ),
//                           transitionsBuilder:
//                               (context, animation, secondaryAnimation, child) {
//                             return child; // No animation
//                           },
//                           transitionDuration: Duration.zero,
//                         ),
//                         (route) => false,
//                       );
//                     });
//                   },
//             isVertical: isVertical,
//           ),
//         ];
//
//         // Fixed items (always visible at the bottom)
//         Widget fixedItems = Column(
//           children: [
//             const Divider(color: Colors.black54),
//             SidebarButton(
//               svgAsset: SvgUtils.settingsIcon,
//               label: TextConstants.settingsHeaderText,
//               isSelected: selectedSidebarIndex == 6,
//               onTap: isShiftScreen || selectedSidebarIndex == 6
//                   ? () {}
//                   : () async {
//                       if (!await _canNavigate(6)) return;
//                       if (kDebugMode) {
//                         print("##### Settings button tapped");
//                       }
//                       lastSelectedIndex =
//                           selectedSidebarIndex; // Build #1.0.7: Store before navigating
//
//                       onSidebarItemSelected(6); // Highlight settings
//
//                       Navigator.push(
//                         context,
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   SettingsScreen(),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                       ).then((_) {
//                         // Restore the sidebar selection when coming back
//                         onSidebarItemSelected(lastSelectedIndex);
//                       });
//                       // Navigator.push(
//                       //   context,
//                       //   MaterialPageRoute(
//                       //     builder: (context) => SettingsScreen(),
//                       //   ),
//                       // ).then((_) {
//                       //   // Restore the sidebar selection when coming back
//                       //   onSidebarItemSelected(lastSelectedIndex);
//                       // });
//                     },
//               isVertical: isVertical,
//               isDisabled: isShiftScreen,
//             ),
//             const SizedBox(height: 10),
//             SidebarButton(
//               svgAsset: SvgUtils.logoutIcon,
//               label: TextConstants.logoutText,
//               isSelected: selectedSidebarIndex == 7,
//               onTap:
//                   isShiftScreen // Build #1.0.247: Enabled Multiple click for Logout
//                       ? () {}
//                       : () async {
//                           if (!await _canNavigate(7)) return;
//                           final previousIndex = selectedSidebarIndex;
//                           onSidebarItemSelected(7);
//                           if (kDebugMode) {
//                             print("nav logout called");
//                           }
//                           _showLogoutDialog(
//                             context,
//                             logoutBloc,
//                             themeHelper,
//                             previousIndex,
//                           );
//                         },
//               isVertical: isVertical,
//               isDisabled: isShiftScreen,
//             ),
//             const SizedBox(height: 10),
//           ],
//         );
//
//         return Padding(
//           padding: const EdgeInsets.only(top: 10.0), // Adjust padding as needed
//           child: Column(
//             children: [
//               // Dynamic part: scrollable on small screens, fixed layout on larger screens.
//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.only(top: 0),
//                   children: dynamicItems,
//                 ),
//               ),
//               fixedItems,
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildHorizontalLayout(
//     BuildContext context,
//     String? shiftId,
//     LogoutBloc logoutBloc,
//   ) {
//     int lastSelectedIndex = 0;
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
//     bool isShiftInvalid =
//         shiftId == null || shiftId == "null" || shiftId.isEmpty;
//     // // Build #1.0.221 : Fixed Issue -> Disable navigation bar menu icons while shift create,update,close
//     // bool isShiftScreen = ModalRoute.of(context)?.settings.arguments == TextConstants.navLogout ||
//     //     ModalRoute.of(context)?.settings.arguments == TextConstants.navShiftHistory;
//     bool isShiftScreen = this.isShiftScreen;
//
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         if (kDebugMode) {
//           print("#### _buildHorizontalLayout constraints: $constraints");
//         }
//         // Dynamic items (scrollable horizontally if needed)
//         List<Widget> dynamicItems = [
//           SidebarButton(
//             svgAsset: selectedSidebarIndex == 0
//                 ? SvgUtils.fastKeySelectedIcon
//                 : SvgUtils
//                     .fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
//             label: TextConstants.fastKeyText,
//             isSelected: selectedSidebarIndex == 0,
//             onTap: isShiftScreen ||
//                     selectedSidebarIndex ==
//                         0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(0)) return;
//                     lastSelectedIndex = 0;
//                     onSidebarItemSelected(0);
//                     if (callbackOnlyIndices?.contains(0) == true) return;
//
//                     /// POSHomeScreen (Fast Keys tab)
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         // Build #1.0.254 : Fixed - Push and replace is showing jump animation for nav bar
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 0),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => FastKeyScreen(lastSelectedIndex: lastSelectedIndex)),
//                     // );
//                   },
//             isVertical: false, //Build #1.0.54: updated
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.categoriesIcon,
//             label: TextConstants.categoriesText,
//             isSelected: selectedSidebarIndex == 1,
//             onTap: (isShiftScreen || selectedSidebarIndex == 1)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(1)) return;
//                     lastSelectedIndex = 1;
//                     onSidebarItemSelected(1);
//                     if (callbackOnlyIndices?.contains(1) == true) return;
//
//                     /// POSHomeScreen (Categories tab)
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 1),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(
//                     //       builder: (context) =>
//                     //           CategoriesScreen(lastSelectedIndex: lastSelectedIndex)),
//                     // );
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.addIcon,
//             label: TextConstants.addText,
//             isSelected: selectedSidebarIndex == 2,
//             onTap: (isShiftScreen || selectedSidebarIndex == 2)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(2)) return;
//                     lastSelectedIndex = 2;
//                     onSidebarItemSelected(2);
//                     if (callbackOnlyIndices?.contains(2) == true) return;
//
//                     /// POSHomeScreen (Add tab)
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   POSHomeScreen(lastSelectedIndex: 2),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => AddScreen()),
//                     // );
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.ordersIcon,
//             label: TextConstants.ordersText,
//             isSelected: selectedSidebarIndex == 3,
//             onTap: (isShiftScreen || selectedSidebarIndex == 3)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(3)) return;
//                     lastSelectedIndex = 3;
//                     onSidebarItemSelected(3);
//                     if (callbackOnlyIndices?.contains(3) == true) return;
//
//                     /// OrdersScreen
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   TotalOrdersScreen(
//                             lastSelectedIndex: 3,
//                           ),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => TotalOrdersScreen(lastSelectedIndex: lastSelectedIndex)), // Build #1.0.226: Updated class name
//                     // );
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.appsIcon,
//             label: TextConstants.appsText,
//             isSelected: selectedSidebarIndex == 4,
//             onTap: (selectedSidebarIndex == 4)
//                 ? () {}
//                 : () async {
//                     final oh = OrderHelper();
//                     if (oh.activeOrderId != null) {
//                       await oh.saveLastActiveOrderId(oh.activeOrderId!);
//                     }
//                     if (!await _canNavigate(4)) return;
//                     lastSelectedIndex = 4;
//                     onSidebarItemSelected(4);
//                     if (callbackOnlyIndices?.contains(4) == true) return;
//
//                     /// AppsDashboardScreen
//                     Future.microtask(() {
//                       if (!context.mounted) return;
//                       Navigator.of(context).pushAndRemoveUntil(
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   AppsDashboardScreen(
//                             lastSelectedIndex: 4,
//                           ),
//                           transitionsBuilder: (
//                             context,
//                             animation,
//                             secondaryAnimation,
//                             child,
//                           ) {
//                             return child; // No transition animation
//                           },
//                           transitionDuration:
//                               Duration.zero, // Instant transition
//                         ),
//                         (route) => false,
//                       );
//                     });
//                     // Navigator.of(context).pushAndRemoveUntil(
//                     //   MaterialPageRoute(builder: (context) => AppsDashboardScreen(lastSelectedIndex: lastSelectedIndex)),
//                     //       (route) => false,
//                     // );
//                     // Navigator.pushReplacement(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => AppsDashboardScreen()),
//                     // );
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(height: 10),
//           SidebarButton(
//             imageAsset: 'assets/refund.png',
//             label: "Refund",
//             isSelected: selectedSidebarIndex == 5,
//             isDisabled: isShiftInvalid || isShiftScreen,
//             onTap: (isShiftInvalid || isShiftScreen || selectedSidebarIndex == 5)
//                 ? () {}
//                 : () async {
//               final oh = OrderHelper();
//               if (oh.activeOrderId != null) {
//                 await oh.saveLastActiveOrderId(oh.activeOrderId!);
//               }
//               if (!await _canNavigate(5)) return;
//
//               lastSelectedIndex = 5;
//               onSidebarItemSelected(5);
//               if (callbackOnlyIndices?.contains(5) == true) return;
//
//               // Strong delay to let old screen dispose properly
//               await Future.delayed(const Duration(milliseconds: 250));
//
//               if (!context.mounted) return;
//
//               Future.microtask(() {
//                 if (!context.mounted) return;
//                 Navigator.of(context).pushAndRemoveUntil(
//                   PageRouteBuilder(
//                     pageBuilder: (context, animation, secondaryAnimation) =>
//                     const CompletedOrdersScreen(lastSelectedIndex: 5),
//                     transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
//                     transitionDuration: Duration.zero,
//                   ),
//                       (route) => false,
//                 );
//               });
//             },
//             isVertical: isVertical,
//           ),
//           // Additional dynamic items can be added here.
//         ];
//
//         // Fixed items that remain visible (on the right)
//         List<Widget> fixedItems = [
//           const VerticalDivider(color: Colors.black54),
//           SidebarButton(
//             svgAsset: SvgUtils.settingsIcon,
//             label: TextConstants.settingsHeaderText,
//             isSelected: selectedSidebarIndex == 6,
//             onTap: isShiftScreen || selectedSidebarIndex == 6
//                 ? () {}
//                 : () async {
//                     if (!await _canNavigate(6)) return;
//                     if (kDebugMode) {
//                       print("##### Settings button tapped");
//                     }
//                     lastSelectedIndex =
//                         selectedSidebarIndex; // Store before navigating
//
//                     onSidebarItemSelected(6); // Highlight settings
//
//                     Navigator.push(
//                       context,
//                       PageRouteBuilder(
//                         pageBuilder: (context, animation, secondaryAnimation) =>
//                             SettingsScreen(),
//                         transitionsBuilder: (
//                           context,
//                           animation,
//                           secondaryAnimation,
//                           child,
//                         ) {
//                           return child; // No transition animation
//                         },
//                         transitionDuration: Duration.zero, // Instant transition
//                       ),
//                     ).then((_) {
//                       // Restore the sidebar selection when coming back
//                       onSidebarItemSelected(lastSelectedIndex);
//                     });
//                     // Navigator.push(
//                     //   context,
//                     //   MaterialPageRoute(builder: (context) => SettingsScreen()),
//                     // ).then((_) {
//                     //   // Restore the sidebar selection when coming back
//                     //   onSidebarItemSelected(lastSelectedIndex);
//                     // });
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(width: 10),
//           SidebarButton(
//             svgAsset: SvgUtils.logoutIcon,
//             label: TextConstants.logoutText,
//             isSelected: selectedSidebarIndex == 7,
//             onTap: isShiftScreen
//                 ? () {}
//                 : () async {
//                     if (!await _canNavigate(7)) return;
//                     final previousIndex = selectedSidebarIndex;
//                     onSidebarItemSelected(7);
//                     if (kDebugMode) {
//                       print("nav logout called");
//                     }
//                     _showLogoutDialog(
//                       context,
//                       logoutBloc,
//                       themeHelper,
//                       previousIndex,
//                     );
//                   },
//             isVertical: false,
//             isDisabled: isShiftScreen,
//           ),
//           const SizedBox(width: 10),
//         ];
//
//         // Dynamic part: scrollable if small, evenly spaced if not.
//         Widget dynamicRow = SingleChildScrollView(
//           scrollDirection: Axis.horizontal,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             spacing: 10,
//             children: dynamicItems,
//           ),
//         );
//
//         return Padding(
//           padding: const EdgeInsets.fromLTRB(
//             16,
//             0,
//             16,
//             0,
//           ), // Adjust padding as needed
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               // Dynamic part takes the available space.
//               Expanded(child: dynamicRow),
//               // Fixed items remain at the end.
//               Row(children: fixedItems),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   /// Handles swipe-to-close-shift: checks for open orders, then navigates to close shift screen or shows warning.
//   void _handleSwipeToCloseShift(
//     BuildContext context,
//     NavigatorState navigator,
//     bool isDarkMode,
//   ) async {
//     final orderHelper = OrderHelper();
//
//     // Build #1.0.281: Check if there are any ACTIVE orders (with items or payments)
//     final bool hasActiveOrders = await orderHelper.hasActiveOrders();
//
//     if (hasActiveOrders) {
//       if (kDebugMode) {
//         print("===== ACTIVE ORDERS FOUND =====");
//         print("Total Orders in Hive: ${orderHelper.orders.length}");
//
//         for (var order in orderHelper.orders) {
//           print("---------- ORDER ----------");
//           print("Order data : ${order.values}");
//           print("----------------------------");
//         }
//         print("===== END ACTIVE ORDERS =====");
//       }
//
//       navigator.pop(); // close logout dialog
//
//       // Show Close Shift Warning popup
//       showDialog(
//         context: navigator.context,
//         barrierDismissible: false,
//         builder: (BuildContext dialogContext) {
//           return Dialog(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(15),
//             ),
//             backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
//             insetPadding: const EdgeInsets.symmetric(horizontal: 60),
//             child: SizedBox(
//               width: 500,
//               child: Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.error_outline,
//                       color: Colors.red,
//                       size: 40,
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       "Close Shift Warning",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: isDarkMode ? Colors.white : Colors.black87,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       "Please close all open orders before closing shift",
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: isDarkMode ? Colors.white : Colors.black87,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 45,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         onPressed: () {
//                           ScannerGuard.isCouponPopupOpen = false;
//                           Navigator.of(dialogContext).pop();
//                         },
//                         child: const Text(
//                           "OK",
//                           style: TextStyle(fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//     } else {
//       if (kDebugMode) {
//         print("No active orders found -> Navigating to Close Shift screen");
//       }
//
//       navigator.pop(); // close logout dialog
//       ScannerGuard.isCouponPopupOpen = false;
//
//       navigator.push(
//         MaterialPageRoute(
//           builder: (context) => ShiftOpenCloseBalanceScreen(),
//           settings: const RouteSettings(arguments: TextConstants.navLogout),
//         ),
//       );
//     }
//   }
//
//   void _showLogoutDialog(
//     BuildContext context,
//     LogoutBloc logoutBloc,
//     ThemeNotifier themeHelper,
//     int previousIndex,
//   ) {
//     ScannerGuard.isCouponPopupOpen = true;
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         bool isDarkMode = themeHelper.themeMode == ThemeMode.dark;
//
//         return Dialog(
//           backgroundColor:
//               Colors.transparent, // transparent to show tilted container
//           insetPadding: const EdgeInsets.all(16),
//           child: Stack(
//             alignment:
//                 Alignment.center, // centers both horizontally & vertically
//             children: [
//               // 🔹 Tilted outer container
//               Transform.rotate(
//                 angle: 0.04,
//                 child: Container(
//                   width: 380,
//                   height: 400,
//                   decoration: BoxDecoration(
//                     color: Colors.transparent,
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(
//                       color: isDarkMode
//                           ? const Color(0xFF434242) // dark mode border
//                           : Colors.white, // light mode border
//                       width: 3,
//                     ),
//                   ),
//                 ),
//               ),
//
//               // Inner dialog
//               SizedBox(
//                 width: 370,
//                 height: 400,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: isDarkMode ? const Color(0xFF434242) : Colors.white,
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.25),
//                         blurRadius: 12,
//                         offset: const Offset(0, 6),
//                       ),
//                     ],
//                   ),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 24,
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     mainAxisAlignment:
//                         MainAxisAlignment.center, // vertical center
//                     crossAxisAlignment:
//                         CrossAxisAlignment.center, // horizontal center
//                     children: [
//                       Image.asset(
//                         "assets/logout.png",
//                         height: 80,
//                         width: 80,
//                         fit: BoxFit.contain,
//                         errorBuilder: (context, error, stackTrace) =>
//                             const SizedBox.shrink(),
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         "Are you sure?",
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: isDarkMode ? Colors.white : Colors.black,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         "Choose what would you like to do before leaving",
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: isDarkMode ? Colors.white : Colors.black,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 24),
//
//                       // 🔹 Swipe Button
//                       SizedBox(
//                         width: 300,
//                         child: SwipeButton(
//                           thumb: Container(
//                             width: 70,
//                             height: 35,
//                             decoration: const BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [Color(0xFF033495), Color(0xFF3CCBFF)],
//                                 begin: Alignment.topLeft,
//                                 end: Alignment.bottomRight,
//                               ),
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Icon(
//                               Icons.double_arrow_rounded,
//                               color: Colors.white,
//                               size: 18,
//                             ),
//                           ),
//                           borderRadius: BorderRadius.circular(18),
//                           activeTrackColor: Colors.transparent,
//                           inactiveTrackColor: Colors.transparent,
//                           height: 42,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xFF033495), Color(0xFF3CCBFF)],
//                                 begin: Alignment.centerLeft,
//                                 end: Alignment.centerRight,
//                               ),
//                               borderRadius: BorderRadius.circular(18),
//                             ),
//                             alignment: Alignment.center,
//                             child: Text(
//                               TextConstants.swipeToCloseShift,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 13,
//                               ),
//                             ),
//                           ),
//                           onSwipe: () {
//                             // Capture navigator before any async work - context may be invalid after pop
//                             final navigator = Navigator.of(context);
//                             _handleSwipeToCloseShift(
//                               context,
//                               navigator,
//                               isDarkMode,
//                             );
//                           },
//                         ),
//                       ),
//
//                       const SizedBox(height: 35),
//
//                       // 🔹 Cancel & Logout buttons
//                       Row(
//                         children: [
//                           SizedBox(
//                             width: 160, // 🔹 set your desired width here
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: isDarkMode
//                                     ? const Color(0xFF4C5F7D)
//                                     : const Color(0xFFF6F6F6),
//                                 fixedSize: const Size(double.infinity, 45),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(
//                                     6,
//                                   ), // ✅ reduced border radius
//                                 ),
//                               ),
//                               onPressed: () {
//                                 ScannerGuard.isCouponPopupOpen = false;
//                                 Navigator.of(context).pop();
//                                 onSidebarItemSelected(previousIndex);
//                               },
//                               child: Text(
//                                 TextConstants.cancelText,
//                                 style: TextStyle(
//                                   color: isDarkMode
//                                       ? ThemeNotifier.textDark
//                                       : const Color(0xFF4C5F7D),
//                                   fontSize: 16,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 10),
//                           SizedBox(
//                             width: 150, // 🔹 Set desired width here
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFFFE6464),
//                                 fixedSize: const Size(
//                                   double.infinity,
//                                   45,
//                                 ), // keeps fixed height = 45
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(
//                                     6,
//                                   ), // ✅ reduced border radius
//                                 ),
//                               ),
//                               onPressed: () async {
//                                 if (kDebugMode)
//                                   print(
//                                     "Logout confirmed, initiating logout process",
//                                   );
//
//                                 // Show loader
//                                 showDialog(
//                                   context: context,
//                                   barrierDismissible: false,
//                                   builder: (_) => const Center(
//                                     child: CircularProgressIndicator(),
//                                   ),
//                                 );
//
//                                 await logoutBloc.performLogout();
//
//                                 // 1️⃣ Logout user from DB
//                                 await UserDbHelper().logout();
//
//                                 // 2️⃣ Clear SharedPreferences
//                                 await PinakaPreferences.clearUserPreferences();
//
//                                 // 3️⃣ Clear TopBar cached user data 🔥 USE PUBLIC METHOD
//                                 TopBar.clearUserCache();
//
//                                 // 4️⃣ Clear any other runtime cache
//                                 // VendorData.clearAll();
//
//                                 // await _clearAllCategoryCaches();
//                                 //
//                                 // await PinakaPreferences.clearUserPreferences();
//
//                                 if (kDebugMode) {
//                                   print("#### User data cleared during logout");
//                                 }
//
//                                 // 5️⃣ Close loader
//                                 Navigator.of(context).pop();
//
//                                 // 6️⃣ Navigate to login screen
//                                 ScannerGuard.isCouponPopupOpen = false;
//
//                                 Navigator.pushReplacement(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (_) => LoginScreen(),
//                                   ),
//                                 );
//
//                                 // Navigator.pushReplacement(
//                                 //   context,
//                                 //   MaterialPageRoute(
//                                 //     builder: (_) => StoreIdScreen(),
//                                 //   ),
//                                 // );
//                               },
//                               child: Text(
//                                 TextConstants.logoutText,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
//
// class SidebarButton extends StatelessWidget {
//   final IconData? icon;
//   final String? svgAsset;
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;
//   final bool isVertical;
//   final bool isDisabled;
//   final String? imageAsset; // PNG / JPG
//
//   const SidebarButton({
//     this.icon,
//     this.svgAsset,
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//     this.isVertical = true,
//     this.isDisabled = false,
//     this.imageAsset,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
//       child: GestureDetector(
//         onTap: onTap,
//         child: isVertical
//             ? _buildVerticalLayout(context)
//             : _buildHorizontalLayout(),
//       ),
//     );
//   }
//
//   Widget _buildVerticalLayout(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           width: MediaQuery.of(context).size.width * 0.05,
//           padding: const EdgeInsets.only(
//             top: 10.0,
//             bottom: 10,
//             left: 2,
//             right: 2,
//           ),
//           decoration: BoxDecoration(
//             shape: BoxShape.rectangle,
//             color: isSelected ? Color(0xFFFE6464) : Color(0xFF3B4259),
//             // latest color
//             // color: isSelected ? Colors.red : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // 🔹 ICON (SVG / PNG / ICONDATA)
//               if (svgAsset != null)
//                 SvgPicture.asset(
//                   svgAsset!,
//                   height: 15,
//                   colorFilter: ColorFilter.mode(
//                     isSelected
//                         ? Colors.white
//                         : isDisabled
//                             ? Colors.grey.shade800
//                             : Colors.white70,
//                     BlendMode.srcIn,
//                   ),
//                 )
//               else if (imageAsset != null)
//                 Image.asset(
//                   imageAsset!,
//                   height: 15,
//                   color: isSelected
//                       ? Colors.white
//                       : isDisabled
//                           ? Colors.grey.shade800
//                           : Colors.white70,
//                 )
//               else
//                 Icon(
//                   icon,
//                   color: isSelected
//                       ? Colors.white
//                       : isDisabled
//                           ? Colors.grey.shade800
//                           : Colors.white70,
//                 ),
//
//               const SizedBox(height: 7),
//
//               // 🔹 LABEL
//               Text(
//                 label,
//                 style: TextStyle(
//                   color: isSelected
//                       ? Colors.white
//                       : isDisabled
//                           ? Colors.grey.shade800
//                           : Colors.white70,
//                   fontWeight: FontWeight.bold,
//                   fontSize: isSelected ? 10.0 : 9.0,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildHorizontalLayout() {
//     return Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
//         decoration: BoxDecoration(
//           shape: BoxShape.rectangle,
//           color: isSelected ? Color(0xFFFE6464) : const Color(0xFF3B4259),
//           borderRadius: const BorderRadius.all(Radius.circular(8)),
//         ),
//         child: Row(
//           children: [
//             if (svgAsset != null)
//               SvgPicture.asset(
//                 svgAsset!,
//                 colorFilter: ColorFilter.mode(
//                   isSelected
//                       ? Colors.white
//                       : isDisabled
//                           ? Colors.grey.shade800
//                           : Colors.white70,
//                   BlendMode.srcIn,
//                 ),
//                 height: 22,
//               )
//             else if (imageAsset != null)
//               Image.asset(
//                 imageAsset!,
//                 height: 22,
//                 color: isSelected
//                     ? Colors.white
//                     : isDisabled
//                         ? Colors.grey.shade800
//                         : Colors.white70,
//               )
//             else
//               Icon(
//                 icon,
//                 color: isSelected
//                     ? Colors.white
//                     : isDisabled
//                         ? Colors.grey.shade800
//                         : Colors.white,
//               ),
//             SizedBox(width: isSelected ? 6.0 : 4.0),
//             Text(
//               label,
//               style: TextStyle(
//                 color: isSelected
//                     ? Colors.white
//                     : isDisabled
//                         ? Colors.grey.shade800
//                         : Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: isSelected ? 16.0 : 14.0,
//               ),
//             ),
//           ],
//         ));
//   }
// }


///////////////


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:isar/isar.dart';
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
import '../Blocs/Orders/refund_orderlist_bloc.dart';
import '../Constants/misc_features.dart';
import '../Database/isar_cache_entry.dart';
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';

import '../Constants/text.dart';
import '../Blocs/Auth/logout_bloc.dart';
import '../Helper/api_response.dart';
import '../Helper/customerdisplayhelper.dart';
import '../Preferences/pinaka_preferences.dart';
import '../Repositories/Auth/logout_repository.dart';
import '../Repositories/Orders/refund_orderlist_repository.dart';
import '../Screens/Auth/store_id_screen.dart';
import '../Screens/Home/add_screen.dart';
import '../Screens/Home/Settings/settings_screen.dart';
import '../Screens/Home/shift_open_close_balance.dart';
import '../Screens/Home/total_orders_screen.dart';
import '../Screens/refund_screen.dart';
import '../Utilities/svg_images_utility.dart';
import '../services/CustomerDisplayService.dart';
import 'widget_alert_popup_dialogs.dart';

class NavigationBar extends StatelessWidget {
  final int selectedSidebarIndex;
  final Function(int) onSidebarItemSelected;
  final bool isVertical;
  final bool isShiftScreen; // ✅ ADD THIS
  final Future<bool> Function(int index)? onWillNavigate;

  /// When non-null, tapping these indices only calls onSidebarItemSelected (no Navigator push).
  /// Used by POSHomeScreen to switch tabs without replacing route.
  final Set<int>? callbackOnlyIndices;

  const NavigationBar({
    required this.selectedSidebarIndex,
    required this.onSidebarItemSelected,
    this.isVertical = true,
    this.isShiftScreen = false, // default
    this.onWillNavigate,
    this.callbackOnlyIndices,
    Key? key,
  }) : super(key: key);

  Future<bool> _canNavigate(int index) async {
    return await onWillNavigate?.call(index) ?? true;
  }

  // ✅ FIX: shared lock so a fast double-tap can't fire two navigations at once
  // (one of the causes of the intermittent blank screen on Android).
  static bool _isSidebarNavigating = false;

  // ✅ FIX: replaces the old `Future.microtask(...)` (vertical layout) and
  // `Future.delayed(milliseconds: 250)` (horizontal layout) patterns, which were
  // inconsistent with each other and timing-fragile. `addPostFrameCallback`
  // guarantees navigation only happens after the current frame has fully finished
  // building/laying out, which is what actually avoids the blank/black screen some
  // Android devices showed. Wrapped in try/catch + one retry so a transient failure
  // never leaves the user stuck on a blank screen.
  static void _safeNavigateReplace(
      BuildContext context,
      Widget Function() screenBuilder,
      ) {
    if (_isSidebarNavigating) return;
    _isSidebarNavigating = true;

    bool navigated = false;

    void doNavigate() {
      if (navigated) return; // guards against the callback AND the fallback firing
      navigated = true;

      if (!context.mounted) {
        _isSidebarNavigating = false;
        return;
      }
      try {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                screenBuilder(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
          ),
              (route) => false,
        );
      } catch (e) {
        if (kDebugMode) print("⚠️ Sidebar navigation failed, retrying: $e");
        try {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  screenBuilder(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
                (route) => false,
          );
        } catch (_) {}
      } finally {
        _isSidebarNavigating = false;
      }
    }

    // Primary path — unchanged from before.
    WidgetsBinding.instance.addPostFrameCallback((_) => doNavigate());

    // ✅ FIX: safety-net. On some Android devices addPostFrameCallback can be
    // delayed indefinitely if no new frame gets scheduled right after the tap —
    // that's what was causing the blank screen. This fires the same navigation
    // if the frame callback hasn't run within 300ms.
    Future.delayed(const Duration(milliseconds: 300), doNavigate);

    // ✅ FIX: this is what was freezing every other sidebar button — the shared
    // lock could stay "true" forever if navigation never resolved. This
    // guarantees the lock always releases within 2 seconds no matter what.
    Future.delayed(const Duration(seconds: 2), () {
      _isSidebarNavigating = false;
    });
  }

  String todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
  }

  String todayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
  }

  Future<void> _clearAllCategoryCaches() async {
    try {
      final isar = await IsarService.instance;

      await isar.writeTxn(() async {
        await isar.isarCacheEntrys.clear(); // Clears ALL cached entries
      });

      if (kDebugMode) {
        print("🧹 All Isar cache cleared on logout");
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ Failed to clear Isar cache: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(
      context,
    ); // Build #1.0.6 - Added theme for navigation bar
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final logoutBloc = LogoutBloc(
      LogoutRepository(),
    ); // Build #1.0.163: Initialize LogoutBloc with repository
    return Container(
      width: isVertical ? MediaQuery.of(context).size.width * 0.07 : null,
      height: isVertical ? null : MediaQuery.of(context).size.height * 0.125,
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1023), // latest color
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
                context,
                shiftId,
                logoutBloc,
              ) // Build #1.0.163
                  : _buildHorizontalLayout(context, shiftId, logoutBloc);
            },
          ),
        ),
      ),
    );
  }

  Future<String?> _getShiftId() async {
    //Build #1.0.78
    if (kDebugMode) {
      print("### Getting shiftId from database");
    }
    int? shiftId = await UserDbHelper()
        .getUserShiftId(); // Build #1.0.161: added debug prints
    if (kDebugMode) {
      print("### Retrieved shiftId: $shiftId");
    }
    return shiftId.toString();
  }

  Widget _buildVerticalLayout(
      BuildContext context,
      String? shiftId,
      LogoutBloc logoutBloc,
      ) {
    int lastSelectedIndex = 0;
    final BuildContext scaffoldContext = context;
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
    bool isShiftInvalid =
        shiftId == null || shiftId == "null" || shiftId.isEmpty;
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
            svgAsset: selectedSidebarIndex == 0
                ? SvgUtils.fastKeySelectedIcon
                : SvgUtils
                .fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
            label: TextConstants.fastKeyText,
            isSelected: selectedSidebarIndex == 0,
            onTap: isShiftScreen ||
                selectedSidebarIndex ==
                    0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
                ? () {}
                : () async {
              final oh = OrderHelper();

              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }

              if (!await _canNavigate(0)) return;
              lastSelectedIndex = 0;
              onSidebarItemSelected(0);
              if (callbackOnlyIndices?.contains(0) == true) return;

              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 0),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.categoriesIcon,
            label: TextConstants.categoriesText,
            isSelected: selectedSidebarIndex == 1,
            onTap: (isShiftScreen || selectedSidebarIndex == 1)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(1)) return;
              lastSelectedIndex = 1;
              onSidebarItemSelected(1);
              if (callbackOnlyIndices?.contains(1) == true) return;

              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 1),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.addIcon,
            label: TextConstants.addText,
            isSelected: selectedSidebarIndex == 2,
            onTap: (isShiftScreen || selectedSidebarIndex == 2)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(2)) return;
              lastSelectedIndex = 2;
              onSidebarItemSelected(2);
              if (callbackOnlyIndices?.contains(2) == true) return;

              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 2),
              );
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
              //       (route) => false,
              // );
              //  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AddScreen(lastSelectedIndex: lastSelectedIndex)),
              //  );
            },
            isVertical: isVertical,
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.ordersIcon,
            label: TextConstants.ordersText,
            isSelected: selectedSidebarIndex == 3,
            onTap: (isShiftScreen || selectedSidebarIndex == 3)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(3)) return;
              lastSelectedIndex = 3;
              onSidebarItemSelected(3);
              if (callbackOnlyIndices?.contains(3) == true) return;

              /// OrdersScreen
              _safeNavigateReplace(
                context,
                    () => TotalOrdersScreen(lastSelectedIndex: 3),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.appsIcon,
            label: TextConstants.appsText,
            isSelected: selectedSidebarIndex == 4,
            onTap: (selectedSidebarIndex == 4)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(4)) return;
              lastSelectedIndex = 4;
              onSidebarItemSelected(4);
              if (callbackOnlyIndices?.contains(4) == true) return;

              /// AppsDashboardScreen
              _safeNavigateReplace(
                context,
                    () => AppsDashboardScreen(lastSelectedIndex: 4),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            imageAsset: 'assets/refund.png',
            label: "Refund",
            isSelected: selectedSidebarIndex == 5,
            isDisabled: isShiftInvalid || isShiftScreen,
            onTap: (isShiftInvalid ||
                isShiftScreen ||
                selectedSidebarIndex == 5)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(5)) return;
              lastSelectedIndex = 5;
              onSidebarItemSelected(5);
              if (callbackOnlyIndices?.contains(5) == true) return;

              // ✅ FIX: was Future.microtask(...) — replaced with the shared
              // frame-safe navigator so the Refund screen always opens
              // reliably on Android instead of showing a blank screen.
              _safeNavigateReplace(
                context,
                    () => const CompletedOrdersScreen(lastSelectedIndex: 5),
              );
            },
            isVertical: isVertical,
          ),
        ];

        // Fixed items (always visible at the bottom)
        Widget fixedItems = Column(
          children: [
            const Divider(color: Colors.black54),
            SidebarButton(
              svgAsset: SvgUtils.settingsIcon,
              label: TextConstants.settingsHeaderText,
              isSelected: selectedSidebarIndex == 6,
              onTap: isShiftScreen || selectedSidebarIndex == 6
                  ? () {}
                  : () async {
                if (!await _canNavigate(6)) return;
                if (kDebugMode) {
                  print("##### Settings button tapped");
                }
                lastSelectedIndex =
                    selectedSidebarIndex; // Build #1.0.7: Store before navigating

                onSidebarItemSelected(6); // Highlight settings

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                        SettingsScreen(),
                    transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                        ) {
                      return child; // No transition animation
                    },
                    transitionDuration:
                    Duration.zero, // Instant transition
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
              isDisabled: isShiftScreen,
            ),
            const SizedBox(height: 10),
            SidebarButton(
              svgAsset: SvgUtils.logoutIcon,
              label: TextConstants.logoutText,
              isSelected: selectedSidebarIndex == 7,
              onTap:
              isShiftScreen // Build #1.0.247: Enabled Multiple click for Logout
                  ? () {}
                  : () async {
                if (!await _canNavigate(7)) return;
                final previousIndex = selectedSidebarIndex;
                onSidebarItemSelected(7);
                if (kDebugMode) {
                  print("nav logout called");
                }
                _showLogoutDialog(
                  context,
                  logoutBloc,
                  themeHelper,
                  previousIndex,
                );
              },
              isVertical: isVertical,
              isDisabled: isShiftScreen,
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

  Widget _buildHorizontalLayout(
      BuildContext context,
      String? shiftId,
      LogoutBloc logoutBloc,
      ) {
    int lastSelectedIndex = 0;
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Build #1.0.161: Fixed Issue - navigation bar icons are not disabled before create shift
    bool isShiftInvalid =
        shiftId == null || shiftId == "null" || shiftId.isEmpty;
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
            svgAsset: selectedSidebarIndex == 0
                ? SvgUtils.fastKeySelectedIcon
                : SvgUtils
                .fastKeyIcon, // Build #1.0.148: Fixed Issue: Menu Bar Icons not matching with latest Figma Design , now using from assets/svg/navigation/
            label: TextConstants.fastKeyText,
            isSelected: selectedSidebarIndex == 0,
            onTap: isShiftScreen ||
                selectedSidebarIndex ==
                    0 // Build #1.0.240 : Disabled Multiple tap on same SidebarButton
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(0)) return;
              lastSelectedIndex = 0;
              onSidebarItemSelected(0);
              if (callbackOnlyIndices?.contains(0) == true) return;

              /// POSHomeScreen (Fast Keys tab)
              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 0),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.categoriesIcon,
            label: TextConstants.categoriesText,
            isSelected: selectedSidebarIndex == 1,
            onTap: (isShiftScreen || selectedSidebarIndex == 1)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(1)) return;
              lastSelectedIndex = 1;
              onSidebarItemSelected(1);
              if (callbackOnlyIndices?.contains(1) == true) return;

              /// POSHomeScreen (Categories tab)
              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 1),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.addIcon,
            label: TextConstants.addText,
            isSelected: selectedSidebarIndex == 2,
            onTap: (isShiftScreen || selectedSidebarIndex == 2)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(2)) return;
              lastSelectedIndex = 2;
              onSidebarItemSelected(2);
              if (callbackOnlyIndices?.contains(2) == true) return;

              /// POSHomeScreen (Add tab)
              _safeNavigateReplace(
                context,
                    () => POSHomeScreen(lastSelectedIndex: 2),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.ordersIcon,
            label: TextConstants.ordersText,
            isSelected: selectedSidebarIndex == 3,
            onTap: (isShiftScreen || selectedSidebarIndex == 3)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(3)) return;
              lastSelectedIndex = 3;
              onSidebarItemSelected(3);
              if (callbackOnlyIndices?.contains(3) == true) return;

              /// OrdersScreen
              _safeNavigateReplace(
                context,
                    () => TotalOrdersScreen(lastSelectedIndex: 3),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            svgAsset: SvgUtils.appsIcon,
            label: TextConstants.appsText,
            isSelected: selectedSidebarIndex == 4,
            onTap: (selectedSidebarIndex == 4)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(4)) return;
              lastSelectedIndex = 4;
              onSidebarItemSelected(4);
              if (callbackOnlyIndices?.contains(4) == true) return;

              /// AppsDashboardScreen
              _safeNavigateReplace(
                context,
                    () => AppsDashboardScreen(lastSelectedIndex: 4),
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(height: 10),
          SidebarButton(
            imageAsset: 'assets/refund.png',
            label: "Refund",
            isSelected: selectedSidebarIndex == 5,
            isDisabled: isShiftInvalid || isShiftScreen,
            onTap: (isShiftInvalid || isShiftScreen || selectedSidebarIndex == 5)
                ? () {}
                : () async {
              final oh = OrderHelper();
              if (oh.activeOrderId != null) {
                await oh.saveLastActiveOrderId(oh.activeOrderId!);
              }
              if (!await _canNavigate(5)) return;

              lastSelectedIndex = 5;
              onSidebarItemSelected(5);
              if (callbackOnlyIndices?.contains(5) == true) return;

              // ✅ FIX: was `await Future.delayed(const Duration(milliseconds: 250))`
              // followed by a raw pushAndRemoveUntil — that fixed delay is what was
              // causing the Refund screen to sometimes open blank on Android (too
              // short on slow devices, and just an unreliable way to sequence a
              // navigation in general). Now uses the same frame-safe navigator as
              // the vertical layout, so behavior is consistent both ways.
              _safeNavigateReplace(
                context,
                    () => const CompletedOrdersScreen(lastSelectedIndex: 5),
              );
            },
            isVertical: isVertical,
          ),
          // Additional dynamic items can be added here.
        ];

        // Fixed items that remain visible (on the right)
        List<Widget> fixedItems = [
          const VerticalDivider(color: Colors.black54),
          SidebarButton(
            svgAsset: SvgUtils.settingsIcon,
            label: TextConstants.settingsHeaderText,
            isSelected: selectedSidebarIndex == 6,
            onTap: isShiftScreen || selectedSidebarIndex == 6
                ? () {}
                : () async {
              if (!await _canNavigate(6)) return;
              if (kDebugMode) {
                print("##### Settings button tapped");
              }
              lastSelectedIndex =
                  selectedSidebarIndex; // Store before navigating

              onSidebarItemSelected(6); // Highlight settings

              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      SettingsScreen(),
                  transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                      ) {
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
            isDisabled: isShiftScreen,
          ),
          const SizedBox(width: 10),
          SidebarButton(
            svgAsset: SvgUtils.logoutIcon,
            label: TextConstants.logoutText,
            isSelected: selectedSidebarIndex == 7,
            onTap: isShiftScreen
                ? () {}
                : () async {
              if (!await _canNavigate(7)) return;
              final previousIndex = selectedSidebarIndex;
              onSidebarItemSelected(7);
              if (kDebugMode) {
                print("nav logout called");
              }
              _showLogoutDialog(
                context,
                logoutBloc,
                themeHelper,
                previousIndex,
              );
            },
            isVertical: false,
            isDisabled: isShiftScreen,
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
            16,
            0,
            16,
            0,
          ), // Adjust padding as needed
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dynamic part takes the available space.
              Expanded(child: dynamicRow),
              // Fixed items remain at the end.
              Row(children: fixedItems),
            ],
          ),
        );
      },
    );
  }

  /// Handles swipe-to-close-shift: checks for open orders, then navigates to close shift screen or shows warning.
  void _handleSwipeToCloseShift(
      BuildContext context,
      NavigatorState navigator,
      bool isDarkMode,
      ) async {
    final orderHelper = OrderHelper();

    // Build #1.0.281: Check if there are any ACTIVE orders (with items or payments)
    final bool hasActiveOrders = await orderHelper.hasActiveOrders();

    if (hasActiveOrders) {
      if (kDebugMode) {
        print("===== ACTIVE ORDERS FOUND =====");
        print("Total Orders in Hive: ${orderHelper.orders.length}");

        for (var order in orderHelper.orders) {
          print("---------- ORDER ----------");
          print("Order data : ${order.values}");
          print("----------------------------");
        }
        print("===== END ACTIVE ORDERS =====");
      }

      navigator.pop(); // close logout dialog

      // Show Close Shift Warning popup
      showDialog(
        context: navigator.context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 60),
            child: SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          ScannerGuard.isCouponPopupOpen = false;
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text(
                          "OK",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
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
      if (kDebugMode) {
        print("No active orders found -> Navigating to Close Shift screen");
      }

      navigator.pop(); // close logout dialog
      ScannerGuard.isCouponPopupOpen = false;

      bool navigated = false;
      void doNavigate() {
        if (navigated) return;
        navigated = true;
        try {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => ShiftOpenCloseBalanceScreen(),
              settings: const RouteSettings(arguments: TextConstants.navLogout),
            ),
          );
        } catch (e) {
          if (kDebugMode) print(" Close-shift navigation failed: $e");
        }
      }

      // ✅ FIX: same blank-screen cause as the sidebar — addPostFrameCallback
      // alone could stall on some Android devices. Added a 300ms fallback so
      // the balance screen always opens.
      WidgetsBinding.instance.addPostFrameCallback((_) => doNavigate());
      Future.delayed(const Duration(milliseconds: 300), doNavigate)
      ;
    }
  }

  void _showLogoutDialog(
      BuildContext context,
      LogoutBloc logoutBloc,
      ThemeNotifier themeHelper,
      int previousIndex,
      ) {
    ScannerGuard.isCouponPopupOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDarkMode = themeHelper.themeMode == ThemeMode.dark;

        return Dialog(
          backgroundColor:
          Colors.transparent, // transparent to show tilted container
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment:
            Alignment.center, // centers both horizontally & vertically
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
                          : Colors.white, // light mode border
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
                    color: isDarkMode ? const Color(0xFF434242) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                    MainAxisAlignment.center, // vertical center
                    crossAxisAlignment:
                    CrossAxisAlignment.center, // horizontal center
                    children: [
                      Image.asset(
                        "assets/logout.png",
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          onSwipe: () {
                            // Capture navigator before any async work - context may be invalid after pop
                            final navigator = Navigator.of(context);
                            _handleSwipeToCloseShift(
                              context,
                              navigator,
                              isDarkMode,
                            );
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
                                  borderRadius: BorderRadius.circular(
                                    6,
                                  ), // ✅ reduced border radius
                                ),
                              ),
                              onPressed: () {
                                ScannerGuard.isCouponPopupOpen = false;
                                Navigator.of(context).pop();
                                onSidebarItemSelected(previousIndex);
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
                                fixedSize: const Size(
                                  double.infinity,
                                  45,
                                ), // keeps fixed height = 45
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    6,
                                  ), // ✅ reduced border radius
                                ),
                              ),
                              onPressed: () async {
                                if (kDebugMode)
                                  print(
                                    "Logout confirmed, initiating logout process",
                                  );

                                // Show loader
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                await logoutBloc.performLogout();

                                // 1️⃣ Logout user from DB
                                await UserDbHelper().logout();

                                // 2️⃣ Clear SharedPreferences
                                await PinakaPreferences.clearUserPreferences();

                                // 3️⃣ Clear TopBar cached user data 🔥 USE PUBLIC METHOD
                                TopBar.clearUserCache();

                                // 4️⃣ Clear any other runtime cache
                                // VendorData.clearAll();

                                // await _clearAllCategoryCaches();
                                //
                                // await PinakaPreferences.clearUserPreferences();

                                if (kDebugMode) {
                                  print("#### User data cleared during logout");
                                }

                                // 5️⃣ Close loader
                                Navigator.of(context).pop();

                                // 6️⃣ Navigate to login screen
                                ScannerGuard.isCouponPopupOpen = false;

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(),
                                  ),
                                );

                                // Navigator.pushReplacement(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (_) => StoreIdScreen(),
                                //   ),
                                // );
                              },
                              child: Text(
                                TextConstants.logoutText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
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
  final String? imageAsset; // PNG / JPG

  const SidebarButton({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isVertical = true,
    this.isDisabled = false,
    this.imageAsset,
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
          width: MediaQuery.of(context).size.width * 0.05,
          padding: const EdgeInsets.only(
            top: 10.0,
            bottom: 10,
            left: 2,
            right: 2,
          ),
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
              // 🔹 ICON (SVG / PNG / ICONDATA)
              if (svgAsset != null)
                SvgPicture.asset(
                  svgAsset!,
                  height: 15,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? Colors.white
                        : isDisabled
                        ? Colors.grey.shade800
                        : Colors.white70,
                    BlendMode.srcIn,
                  ),
                )
              else if (imageAsset != null)
                Image.asset(
                  imageAsset!,
                  height: 15,
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                      ? Colors.grey.shade800
                      : Colors.white70,
                )
              else
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                      ? Colors.grey.shade800
                      : Colors.white70,
                ),

              const SizedBox(height: 7),

              // 🔹 LABEL
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                      ? Colors.grey.shade800
                      : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: isSelected ? 10.0 : 9.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
            if (svgAsset != null)
              SvgPicture.asset(
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
            else if (imageAsset != null)
              Image.asset(
                imageAsset!,
                height: 22,
                color: isSelected
                    ? Colors.white
                    : isDisabled
                    ? Colors.grey.shade800
                    : Colors.white70,
              )
            else
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : isDisabled
                    ? Colors.grey.shade800
                    : Colors.white,
              ),
            SizedBox(width: isSelected ? 6.0 : 4.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isDisabled
                    ? Colors.grey.shade800
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSelected ? 16.0 : 14.0,
              ),
            ),
          ],
        ));
  }
}