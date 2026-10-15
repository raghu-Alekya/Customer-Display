import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:pinaka_pos/Screens/Home/fast_key_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Blocs/Auth/logout_bloc.dart';
import '../../Blocs/Auth/shift_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Models/Assets/asset_model.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/logout_repository.dart';
import '../../Repositories/Auth/shift_repository.dart';
import '../../Widgets/widget_age_verification_popup_dialog.dart';
import '../../Widgets/widget_alert_popup_dialogs.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import 'pos_home_screen.dart';

/// Tube counts returned by [SafeOpenScreen] to the shift balance screen.
/// Each denomination map has denomValue, symbol, tubeLimit, tubeCount, amount.
class SafeTubeCount {
  final List<Map<String, dynamic>> denominations;
  final double cashTubes;

  const SafeTubeCount({required this.denominations, required this.cashTubes});
}

class SafeOpenScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  final double cashNotesCoins;  // Build #1.0.70
  final String? previousScreen;
  const SafeOpenScreen({super.key, this.lastSelectedIndex, required this.cashNotesCoins, this.previousScreen});

  @override
  State<SafeOpenScreen> createState() => _SafeOpenScreenState();
}

class _SafeOpenScreenState extends State<SafeOpenScreen> with LayoutSelectionMixin {
  // Build #1.0.70
  List<Denom> _tubeDenominations = [];

  double totalAmount = 0.0;
  double cashTubes = 0.0;
  double cashNotesCoin = 0.0;
  bool isLoading = true;
  int _selectedSidebarIndex = 4;
  // List to store denomination data
  final List<Map<String, dynamic>> denominations = [];
  bool _isSubmitting = false;
  final PinakaPreferences _preferences = PinakaPreferences(); // Added this

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    cashNotesCoin = widget.cashNotesCoins;
    _fetchTubeDenominations();
    updateAmounts();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    });
  }

  // Build #1.0.70: Calculate tube amounts and totals
  void updateAmounts() {
    if (kDebugMode) {
      print("Updating amounts for tube denominations");
    }

    double calculatedTotalAmount = 0.0;
    double calculatedCashTubes = 0.0;

    for (var denomination in denominations) {
      // Get the denomination value and symbol
      final denomValue = denomination['denomValue'] as num;
      final symbol = denomination['symbol'] as String;
      final tubeCount = denomination['tubeCount'] as int;
      final tubeLimit = denomination['tubeLimit'] as int;

      // Calculate amount for this denomination
      final amount = denomValue * tubeCount * tubeLimit;
      denomination['amount'] = amount;

      // Update totals
      calculatedTotalAmount += amount;
      calculatedCashTubes += amount;

      if (kDebugMode) {
        print("Denom: $symbol$denomValue, Tubes: $tubeCount, Limit: $tubeLimit, Amount: $amount");
      }
    }

    setState(() {
      totalAmount = calculatedTotalAmount + cashNotesCoin;
      cashTubes = calculatedCashTubes;

      if (kDebugMode) {
        print("Updated totals - Cash Tubes: $cashTubes, Total Amount: $totalAmount");
      }
    });
  }

  // Build #1.0.70: _fetchTubeDenominations
  Future<void> _fetchTubeDenominations() async {
    if (kDebugMode) {
      print("Fetching tube denominations from database...");
    }

    _tubeDenominations = await AssetDBHelper.instance.getTubesDenomList();

    if (kDebugMode) {
      print("Fetched ${_tubeDenominations.length} tube denominations");
    }

    setState(() {
      denominations.clear();
      for (var denom in _tubeDenominations) {
        final numericValue = num.parse(denom.denom);
        denominations.add({
          'value': '${denom.symbol}${denom.denom}', // Display value with symbol
          'denomValue': numericValue, // Numeric value for calculations
          'symbol': denom.symbol, // Currency symbol
          'tubeLimit': denom.tubeLimit, // Tube limit from API
          'color': _getColorForDenom(numericValue),
          'tubeCount': 0,
          'amount': 0.0,
        });

        if (kDebugMode) {
          print("Added denomination: ${denom.denom} with symbol ${denom.symbol}");
        }
      }
    });
  }

  Color _getColorForDenom(num denom) {
    // switch (denom) {
    final List<Color> colorPalette = [
      //Color(0xFFAAD576), Here i comment these colour i change these colours
      Color(0xFFACD670), // blended color
      Color(0xFF55CBCD),
      Color(0xFF1BA672),
      Color(0xFF88ED7F),
      Color(0xFF1F7192),
      Color(0xFF9CC5A1),
      Color(0xFF5ECEC6),
      Color(0xFFFFB347),
      Color(0xFFFFE4B5),
      Color(0xFFAFEEEE),
      Color(0xFFFFA07A),
      Color(0xFFD3D3D3),
      Color(0xFFE6E6FA),
      Color(0xFFF5DEB3),
      Color(0xFFF0E68C),
    ];
    //}
    // Get the index of the denomination in the sorted list
    final sortedDenoms = _tubeDenominations
        .map((d) => num.parse(d.denom))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort in descending order

    final index = sortedDenoms.indexOf(denom);

    // Return color from palette, cycling through if more denoms than colors
    return index >= 0
        ? colorPalette[index % colorPalette.length]
        : colorPalette[0]; // Default to first color if not found
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          TopBar(
            screen: Screen.SAFE,
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
              // No need to call saveLayoutSelection here as it's handled in the notifier
              // _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
              // update UI
              setState(() {});
            },
          ),
          Divider(
            color: Colors.grey, // Light grey color
            thickness: 0.4, // Very thin line
            height: 1, // Minimal height
          ),
          Expanded(
            child: Row(
              children: [
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
                    isShiftScreen: true,
                  ),
                Expanded(
                  child: Padding(
                    // need to change the top for bottom mode
                    padding: EdgeInsets.fromLTRB(
                        8,
                        sidebarPosition == SidebarPosition.bottom ? 2 : 5,
                        12,
                        sidebarPosition == SidebarPosition.bottom ? 0 : 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.primaryBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.shadow_F7
                                : Colors.grey.shade100,
                            blurRadius: 2,
                            // spreadRadius: 1
                          )
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: sidebarPosition == SidebarPosition.bottom
                                    ? 3
                                    : 16,
                                right: 16,
                                left: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Safe',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      SizedBox(
                                        height:
                                        MediaQuery.of(context).size.height *
                                            0.06,
                                        width:
                                        MediaQuery.of(context).size.width *
                                            0.1,
                                        child: OutlinedButton(
                                          // Build #1.0.148: Fixed Issue : Disable Back Button in Safe open screen while tap on submit button
                                          onPressed: _isSubmitting
                                              ? null
                                              : () => Navigator.pop(
                                              context), // Disable button when _isSubmitting is true
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            side: BorderSide(
                                              color: _isSubmitting
                                                  ? Colors.grey.shade400
                                                  : Colors.grey
                                                  .shade300, // Greyed-out border when disabled, active border when enabled
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            foregroundColor: _isSubmitting
                                                ? Colors.grey.shade400
                                                : Colors
                                                .blueGrey, // Greyed-out text when disabled, active text when enabled
                                            backgroundColor: _isSubmitting
                                                ? Colors.grey.shade100
                                                : Colors
                                                .transparent, // Subtle background when disabled, no background when active
                                          ),
                                          child: Text(
                                            'Back',
                                            style: TextStyle(
                                              color: _isSubmitting
                                                  ? Colors.grey
                                                  .shade400 // Greyed-out text when disabled
                                                  : (themeHelper.themeMode ==
                                                  ThemeMode.dark
                                                  ? ThemeNotifier.textDark
                                                  : Colors
                                                  .blueGrey), // Active text color
                                              fontSize:
                                              16, // Keep your font size
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      SizedBox(
                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.06,
                                          width: MediaQuery.of(context)
                                              .size
                                              .width *
                                              0.1,
                                          child: ElevatedButton(
                                            // Build #1.0.70: updated code
                                            // Only collects the tube counts; the balance screen submits the
                                            // shift with them through its shared open/update/close flow.
                                            onPressed: _isSubmitting
                                                ? null
                                                : () {
                                                    setState(() => _isSubmitting = true);
                                                    Navigator.pop(
                                                      context,
                                                      SafeTubeCount(
                                                        denominations: denominations
                                                            .map((d) => Map<String, dynamic>.from(d))
                                                            .toList(),
                                                        cashTubes: cashTubes,
                                                      ),
                                                    );
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(
                                                  0xFFFF6B6B), //Build #1.0.78: no need to change bg
                                              foregroundColor: Colors.white,
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(8)),
                                            ),
                                            child:
                                            _isSubmitting // Build #1.0.70:
                                                ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                              CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                                : const Text('Submit',
                                                style: TextStyle(
                                                    fontSize: 16)),
                                          )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Bottom labels section - shown only once
                                // Bottom input section - labels in separate rows
                                Container(
                                  width: MediaQuery.of(context).size.width *
                                      0.0725,
                                  //color: Colors.green,
                                  alignment: Alignment.bottomLeft,
                                  padding: EdgeInsets.only(left: 5, bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Left label column
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.065,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                TextConstants.noOfTubes,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: themeHelper
                                                      .themeMode ==
                                                      ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.045,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                TextConstants.amount,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: themeHelper
                                                      .themeMode ==
                                                      ThemeMode.dark
                                                      ? ThemeNotifier.textDark
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // const SizedBox(width: 5),
                                      // // Right input columns
                                      // Expanded(
                                      //   child: Column(
                                      //     crossAxisAlignment: CrossAxisAlignment.start,
                                      //     children: [
                                      //       // Row of dropdowns
                                      //       Row(
                                      //         mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      //         children: List.generate(
                                      //           denominations.length,
                                      //               (index) => Container(
                                      //             width: 70,
                                      //             height: 35,
                                      //             decoration: BoxDecoration(
                                      //               border: Border.all(color: Colors.grey.shade300),
                                      //               borderRadius: BorderRadius.circular(5),
                                      //             ),
                                      //             padding: EdgeInsets.symmetric(horizontal: 8),
                                      //             child: DropdownButtonHideUnderline(
                                      //               child: DropdownButton<int>(
                                      //                 value: denominations[index]['tubeCount'],
                                      //                 onChanged: (value) {
                                      //                   setState(() {
                                      //                     denominations[index]['tubeCount'] = value ?? 0;
                                      //                   });
                                      //                   updateAmounts();
                                      //                 },
                                      //                 items: List.generate(11, (i) => i).map((value) {
                                      //                   return DropdownMenuItem<int>(
                                      //                     value: value,
                                      //                     child: Text(
                                      //                       value.toString().padLeft(2, '0'),
                                      //                       style: TextStyle(fontWeight: FontWeight.w500),
                                      //                     ),
                                      //                   );
                                      //                 }).toList(),
                                      //               ),
                                      //             ),
                                      //           ),
                                      //         ),
                                      //       ),
                                      //       const SizedBox(height: 12),
                                      //       // Row of amount boxes
                                      //       Row(
                                      //         mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      //         children: List.generate(
                                      //           denominations.length,
                                      //               (index) => Container(
                                      //             width: 70,
                                      //             height: 35,
                                      //             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      //             decoration: BoxDecoration(
                                      //               border: Border.all(color: Colors.grey.shade300),
                                      //               borderRadius: BorderRadius.circular(5),
                                      //             ),
                                      //             child: Text(
                                      //               '${TextConstants.currencySymbol}${denominations[index]['amount'].toStringAsFixed(0)}',
                                      //               style: TextStyle(fontWeight: FontWeight.w500),
                                      //               textAlign: TextAlign.center,
                                      //             ),
                                      //           ),
                                      //         ),
                                      //       ),
                                      //     ],
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                ),
                                // Build #1.0.70: Money columns with horizontal scroll
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Container(
                                      height:
                                      MediaQuery.of(context).size.height *
                                          0.65,
                                      padding:
                                      EdgeInsets.only(left: 5, right: 5),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            child: Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.start,
                                              crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                              children: List.generate(
                                                denominations.length,
                                                    (index) => MoneyColumn(
                                                  denomination:
                                                  denominations[index]
                                                  ['value'],
                                                  color: denominations[index]
                                                  ['color'],
                                                  tubeCount:
                                                  denominations[index]
                                                  ['tubeCount'],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      denominations[index]
                                                      ['tubeCount'] = value;
                                                    });
                                                    updateAmounts();
                                                  },
                                                  amount: denominations[index]
                                                  ['amount']
                                                      .toDouble(),
                                                  updateTubes: (value) {
                                                    setState(() {
                                                      denominations[index]
                                                      ['tubeCount'] =
                                                          value ?? 0;
                                                    });
                                                    updateAmounts();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Right side summary section
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    height: MediaQuery.of(context).size.height *
                                        0.70,
                                    margin: EdgeInsets.all(sidebarPosition ==
                                        SidebarPosition.bottom
                                        ? 8
                                        : 10),
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: themeHelper.themeMode ==
                                          ThemeMode.dark
                                          ? Color(0xFF31354A)
                                          : Color(
                                          0xFFFEF4F4), // move color here
                                      borderRadius: BorderRadius.circular(
                                          15), // your radius
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        // Total Columns
                                        Center(
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width *
                                                0.35,
                                            margin: EdgeInsets.only(top: 20),
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: themeHelper.themeMode ==
                                                  ThemeMode.dark
                                                  ? ThemeNotifier
                                                  .secondaryBackground
                                                  : Colors.white,
                                              borderRadius:
                                              BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: themeHelper
                                                      .themeMode ==
                                                      ThemeMode.dark
                                                      ? ThemeNotifier
                                                      .borderColor
                                                      : Colors.grey.shade300),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              children: [
                                                Text(TextConstants.totalColumns,
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: themeHelper
                                                            .themeMode ==
                                                            ThemeMode.dark
                                                            ? ThemeNotifier
                                                            .textDark
                                                            : Colors.grey
                                                            .shade700)),
                                                const SizedBox(height: 8),
                                                Text(
                                                    denominations.length
                                                        .toString()
                                                        .padLeft(2, '0'),
                                                    style: TextStyle(
                                                        fontSize: 28,
                                                        fontWeight:
                                                        FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            // Cash (Tubes)
                                            Row(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .center,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(left: 20),
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                                TextConstants
                                                                    .cash,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                    18,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                                TextConstants
                                                                    .tubes,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                    12,
                                                                    color: Colors
                                                                        .grey)),
                                                          ],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(left: 20),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .info_outline,
                                                                size: 16,
                                                                color: Colors
                                                                    .grey),
                                                            const SizedBox(
                                                                width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                  TextConstants
                                                                      .safeTotalAmount,
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                      12,
                                                                      color: Colors
                                                                          .grey)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 20),
                                                  child: Text(
                                                    ':',
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 20),
                                                  child: Container(
                                                    margin: EdgeInsets.all(8.0),
                                                    width:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                        0.125,
                                                    padding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade300),
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                            '${TextConstants.currencySymbol}${cashTubes.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 25),
                                            // Cash (Notes/coins)
                                            Row(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(left: 20),
                                                        child: Row(
                                                          children: [
                                                            Text('Cash',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                    18,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                                '(Notes/coins)',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                    14,
                                                                    color: Colors
                                                                        .grey)),
                                                          ],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(left: 20),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .info_outline,
                                                                size: 16,
                                                                color: Colors
                                                                    .grey),
                                                            const SizedBox(
                                                                width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                  'Total Amount of Physical money in the form of notes and coins',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                      12,
                                                                      color: Colors
                                                                          .grey)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 10),
                                                  child: Text(' : ',
                                                      style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                          FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 8),
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 20),
                                                  child: Container(
                                                    margin: EdgeInsets.all(8.0),
                                                    width:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                        0.125,
                                                    padding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade300),
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                            '${TextConstants.currencySymbol}${cashNotesCoin.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .blue
                                                                    .shade300)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Total Amount
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 20),
                                                child: Row(
                                                  children: [
                                                    Text('Total Amount',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold)),
                                                    const SizedBox(width: 5),
                                                    const Text(' : ',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 20),
                                              child: Container(
                                                margin: EdgeInsets.all(8.0),
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                    0.15,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color:
                                                      Colors.grey.shade300),
                                                  borderRadius:
                                                  BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                        '${TextConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold)),
                                                  ],
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
                      });
                    },
                    isVertical: true,
                    isShiftScreen: true,
                  ),
              ],
            ),
          ),
          if (sidebarPosition == SidebarPosition.bottom)
            custom_widgets.NavigationBar(
              selectedSidebarIndex: _selectedSidebarIndex,
              onSidebarItemSelected: (index) {
                setState(() {
                  _selectedSidebarIndex = index;
                });
              },
              isVertical: false,
              isShiftScreen: true,
            ),
        ],
      ),
    );
  }
}

class MoneyColumn extends StatelessWidget {
  final String denomination;
  final Color color;
  final int tubeCount;
  final Function(int) onChanged;
  final double amount;
  final Function? updateTubes;

  const MoneyColumn(
      {Key? key,
        required this.denomination,
        required this.color,
        required this.tubeCount,
        required this.onChanged,
        required this.amount,
        this.updateTubes})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build #1.0.70: updated
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Padding(
      padding: EdgeInsets.only(left: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Denomination label with symbol
          Text(denomination, style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),

          // Money tube visualization
          Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.056,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Stack(
                  alignment:
                  Alignment.bottomCenter, // keep vertical center by default
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(30),
                        ),
                        border: Border(
                          left:
                          BorderSide(color: Colors.grey.shade300, width: 1),
                          right:
                          BorderSide(color: Colors.grey.shade300, width: 1),
                          bottom:
                          BorderSide(color: Colors.grey.shade300, width: 1),
                          top: BorderSide.none,
                        ),
                      ),
                    ),

                    /// 🔹 Center the cube column horizontally
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.05,
                          height: 296, // full height for 10 cubes
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              10,
                                  (index) {
                                int reversedIndex = 9 - index;
                                return Container(
                                  height: 29, // height of each cube
                                  decoration: BoxDecoration(
                                    color: reversedIndex < tubeCount
                                        ? color
                                        : themeHelper.themeMode ==
                                        ThemeMode.dark
                                        ? const Color(0xFF8E8D8D)
                                        : const Color(0xFFD9D9D9),
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (tubeCount > 0)
                      Positioned(
                        bottom: 1,
                        left: (MediaQuery.of(context).size.width * 0.06 -
                            MediaQuery.of(context).size.width * 0.05) /
                            2, // 🔹 center horizontally
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.05,
                          height: (296 * (tubeCount / 10)).clamp(30.0, 296.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              tubeCount - 1,
                                  (index) => Container(
                                height: 1,
                                width: MediaQuery.of(context).size.width * 0.05,
                                //color: Colors.white.withValues(alpha: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )),
          SizedBox(height: 5),
          // Tube count dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(
                width: 70,
                height: 35,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.secondaryBackground
                        : null,
                    value: tubeCount,
                    onChanged: (value) {
                      updateTubes!(value);
                    },
                    items: List.generate(11, (i) => i).map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          value.toString().padLeft(2, '0'),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Amount display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(
                width: 70,
                height: 35,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${amount.toStringAsFixed(2)}', // Display amount with symbol from denomination
                  style: TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}