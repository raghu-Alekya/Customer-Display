import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Home/safe_drop_screen.dart';
import 'package:pinaka_pos/Screens/Home/shift_history_dashboard_screen.dart';
import 'package:pinaka_pos/Screens/Home/shift_open_close_balance.dart';
import 'package:provider/provider.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
<<<<<<< HEAD
import '../../Preferences/pinaka_preferences.dart';
=======
import '../../Inventory_screen/InventoryScreen.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Widgets/SafeStorageHelper.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Widgets/widget_topbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;

<<<<<<< HEAD
=======
import 'package:flutter/services.dart';

import 'Nmi_payments.dart';

>>>>>>> origin/Grocery_pch_api_integration
class AppsDashboardScreen extends StatefulWidget {
  // Build #1.0.6 - Updated Horizontal & Vertical Scrolling
  final int? lastSelectedIndex; // Make it nullable

  const AppsDashboardScreen(
      {super.key, this.lastSelectedIndex}); // Optional, no default value

  @override
  State<AppsDashboardScreen> createState() => _AppsDashboardScreenState();
}

<<<<<<< HEAD
class _AppsDashboardScreenState extends State<AppsDashboardScreen> with LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex =
  4; //Build #1.0.2 : By default fast key should be selected after login
=======
class _AppsDashboardScreenState extends State<AppsDashboardScreen>
    with LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex =
      4; //Build #1.0.2 : By default fast key should be selected after login
>>>>>>> origin/Grocery_pch_api_integration
  DateTime now = DateTime.now();
  List<int> quantities = [1, 1, 1, 1];
  bool isLoading = true; // Add a loading state
  final PinakaPreferences _preferences = PinakaPreferences(); // Add this
  // Add variables to track which card is being pressed
  int? _pressedCardIndex;
<<<<<<< HEAD
=======
  bool _isSafeEnabled = false;
  bool _isSafeDropEnabled = false;
>>>>>>> origin/Grocery_pch_api_integration

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _selectedSidebarIndex = widget.lastSelectedIndex ??
        4; // Build #1.0.7: Restore previous selection
    // Simulate a loading delay
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        isLoading = false; // Set loading to false after 3 seconds
      });
    });
=======
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    _initApps();
  }

  Future<void> _initApps() async {
    final isSafeEnabled = await SafeStorageHelper.getSafeEnable();
    final isSafeDropEnabled = await SafeStorageHelper.getSafeEnableDrop();
    if (mounted) {
      setState(() {
        _isSafeEnabled = isSafeEnabled;
        _isSafeDropEnabled = isSafeDropEnabled;
        isLoading = false;
      });
    }
>>>>>>> origin/Grocery_pch_api_integration
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      body: Column(
        children: [
          // Top Bar
          TopBar(
            screen: Screen.APPS,
<<<<<<< HEAD
            onModeChanged: () async{ /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
=======
            onModeChanged: () async {
              /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
>>>>>>> origin/Grocery_pch_api_integration
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
<<<<<<< HEAD
                newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
=======
                newLayout = orderPanelPosition == OrderPanelPosition.left
                    ? SharedPreferenceTextConstants.navBottomOrderRight
                    : SharedPreferenceTextConstants.navLeftOrderRight;
>>>>>>> origin/Grocery_pch_api_integration
              }

              //Update the notifier which will trigger _onLayoutChanged
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              // No need to call saveLayoutSelection here as it's handled in the notifier
              // _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
<<<<<<< HEAD
              await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
=======
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
>>>>>>> origin/Grocery_pch_api_integration
              // update UI
              setState(() {});
            },
          ),
          Divider(
            color: Colors.grey, // Light grey color
            thickness: 0.4, // Very thin line
            height: 1, // Minimal height
          ),

          // SizedBox(
          //   height: 10,
          // ),

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
                      });
                    },
                    isVertical: true, // Vertical layout for left sidebar
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
<<<<<<< HEAD
                    child: GridView.count(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      children: [
                        _buildCard(
                          //title: TextConstants.cashier,
                          icon: themeHelper.themeMode == ThemeMode.dark
                              ? Image.asset(
                            "assets/cashier_dark.png",
                          )
                              : Image.asset(
                            "assets/cashier_lite.png",
                          ),
                          cardIndex: 0,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      ShiftHistoryDashboardScreen() //Build #1.0.74
                                //  settings: RouteSettings(arguments: TextConstants.navCashier),  // Build #1.0.70
                              ),
                            );
                          },
                        ),
                        _buildCard(
                          // title: TextConstants.safeDrop,
                          icon: themeHelper.themeMode == ThemeMode.dark
                              ? Image.asset(
                            "assets/safedrop_dark.png",
                          )
                              : Image.asset(
                            "assets/safedrop_lite.png",
                          ),
                          cardIndex: 1,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SafeDropScreen(),
                              ),
                            );

                            // Handle Safe Drop tap
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Expanded(
                //   child: Padding(
                //     padding: const EdgeInsets.all(8.0),
                //     child: GridView.count(
                //       crossAxisCount: 4,
                //       childAspectRatio: 1 ,
                //       crossAxisSpacing: 16.0,
                //       mainAxisSpacing: 16.0,
                //       children: [
                //         _buildCard(
                //           title: TextConstants.cashier,
                //           icon: 'assets/svg/cashier.svg',
                //           cardIndex: 0,
                //           onTap: () {
                //             Navigator.push(
                //               context,
                //               MaterialPageRoute(
                //                 builder: (context) => ShiftHistoryDashboardScreen()  //Build #1.0.74
                //               //  settings: RouteSettings(arguments: TextConstants.navCashier),  // Build #1.0.70
                //               ),
                //             );
                //           },
                //         ),
                //         _buildCard(
                //           title: TextConstants.safeDrop,
                //           icon: 'assets/svg/safe_drop.svg',
                //           cardIndex: 1,
                //           onTap: () {
                //             Navigator.push(
                //               context,
                //               MaterialPageRoute(
                //                 builder: (context) => SafeDropScreen(),
                //               ),
                //             );
                //
                //             // Handle Safe Drop tap
                //           },
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
=======
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        // : GridView.count(
                        //     crossAxisCount: 4,
                        //     childAspectRatio: 1,
                        //     children: [
                        //       _buildCard(
                        //         //title: TextConstants.cashier,
                        //         icon: themeHelper.themeMode == ThemeMode.dark
                        //             ? Image.asset(
                        //                 "assets/cashier_dark.png",
                        //               )
                        //             : Image.asset(
                        //                 "assets/cashier_lite.png",
                        //               ),
                        //         cardIndex: 0,
                        //         onTap: () {
                        //           Navigator.push(
                        //             context,
                        //             MaterialPageRoute(
                        //                 builder: (context) =>
                        //                     ShiftHistoryDashboardScreen() //Build #1.0.74
                        //                 //  settings: RouteSettings(arguments: TextConstants.navCashier),  // Build #1.0.70
                        //                 ),
                        //           );
                        //         },
                        //       ),
                        //       if (_isSafeDropEnabled)
                        //         _buildCard(
                        //           icon: themeHelper.themeMode == ThemeMode.dark
                        //               ? Image.asset("assets/safedrop_dark.png")
                        //               : Image.asset("assets/safedrop_lite.png"),
                        //           cardIndex: 1,
                        //           onTap: () {
                        //             Navigator.push(
                        //               context,
                        //               MaterialPageRoute(
                        //                   builder: (_) => SafeDropScreen()),
                        //             );
                        //           },
                        //         ),
                        //
                        //       _buildCard(
                        //         //title: TextConstants.cashier,
                        //         icon: themeHelper.themeMode == ThemeMode.dark
                        //             ? Image.asset(
                        //                 "assets/stock_inventory_dark.png",
                        //               )
                        //             : Image.asset("assets/img.png"),
                        //         cardIndex: 0,
                        //         onTap: () {
                        //           Navigator.push(
                        //             context,
                        //             MaterialPageRoute(
                        //                 builder: (context) =>
                        //                     InventoryScreen() //Build #1.0.386
                        //                 //  settings: RouteSettings(arguments: TextConstants.navCashier),  // Build #1.0.70
                        //                 ),
                        //           );
                        //         },
                        //       ),
                        //
                        //       ///////
                        //
                        //
                        //     ],
                        //   ),
                        : GridView.count(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      children: (() {
                        // Build cards into a list first, skip disabled ones,
                        // so no empty slot is ever reserved in the grid.
                        final List<Widget> dashboardCards = [];

                        dashboardCards.add(
                          _buildCard(
                            icon: themeHelper.themeMode == ThemeMode.dark
                                ? Image.asset("assets/cashier_dark.png")
                                : Image.asset("assets/cashier_lite.png"),
                            cardIndex: 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ShiftHistoryDashboardScreen()),
                              );
                            },
                          ),
                        );

                        if (_isSafeDropEnabled) {
                          dashboardCards.add(
                            _buildCard(
                              icon: themeHelper.themeMode == ThemeMode.dark
                                  ? Image.asset("assets/safedrop_dark.png")
                                  : Image.asset("assets/safedrop_lite.png"),
                              cardIndex: 1,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SafeDropScreen()),
                                );
                              },
                            ),
                          );
                        }

                        dashboardCards.add(
                          _buildCard(
                            icon: themeHelper.themeMode == ThemeMode.dark
                                ? Image.asset("assets/stock_inventory_dark.png")
                                : Image.asset("assets/img.png"),
                            cardIndex: 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => InventoryScreen()),
                              );
                            },
                          ),
                        );

                        return dashboardCards;
                      })(),
                    ),

                  ),
                ),
>>>>>>> origin/Grocery_pch_api_integration

                // Right Sidebar (Conditional)
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
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
            custom_widgets.NavigationBar(
              //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
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
    );
  }

  Widget _buildCard({
    required Widget icon,
    required VoidCallback onTap,
    required int cardIndex,
  }) {
    return GestureDetector(
      onTap: onTap,
<<<<<<< HEAD
      child:  SizedBox(
=======
      child: SizedBox(
>>>>>>> origin/Grocery_pch_api_integration
        width: 330,
        height: 330,
        child: icon,
      ),
    );
  }
}
<<<<<<< HEAD

//   Widget _buildCard({
//     required String title,
//     required String icon,
//     required VoidCallback onTap,
//     required int cardIndex,
//   }) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return Material(
//       elevation: 2,
//       borderRadius: BorderRadius.circular(12),
//       color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : null,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         //splashColor: Colors.blue.withValues(alpha: 0.3),
//         highlightColor: Colors.blue.withValues(alpha: 0.3),
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(18),
//             color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : null,
//           ),
//           child: Column(
//             children: [
//               Expanded(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Color(0xFFECF7FF),
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(18),
//                       topRight: Radius.circular(18),
//                     ),
//                   ),
//                   width: double.infinity,
//                   child: SvgPicture.asset(
//                     icon,
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(25.0),
//                 child: Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
=======
>>>>>>> origin/Grocery_pch_api_integration
