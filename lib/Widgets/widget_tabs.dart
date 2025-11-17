import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';

// Import your custom numpad
import '../Blocs/Assets/asset_bloc.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/misc_features.dart';
import '../Constants/text.dart';
import '../Database/assets_db_helper.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Assets/asset_model.dart';
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_custom_item_model.dart' as model;
import '../Repositories/Assets/asset_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/svg_images_utility.dart';
import 'widget_custom_num_pad.dart';

class AppScreenTabWidget extends StatefulWidget {
  AppScreenTabWidget({this.selectedTabIndex = 0, this.barcode = "", this.refreshOrderList, required this.scaffoldMessengerContext, super.key});
  int selectedTabIndex = 0;
  String barcode = "";
  final BuildContext scaffoldMessengerContext;
  final VoidCallback? refreshOrderList; // Callback to refresh order panel

  @override
  State<AppScreenTabWidget> createState() => _AppScreenTabWidgetState();
}

class _AppScreenTabWidgetState extends State<AppScreenTabWidget> with LayoutSelectionMixin {
  // Tab selection
  bool _isPayoutLoading = false;
  // bool _isCouponLoading = false;
  bool _isCashbackLoading = false;
  bool _isDiscountLoading = false;
  bool _isCustomItemLoading = false;
  final OrderHelper _orderHelper = OrderHelper(); // Add OrderHelper instance
  late OrderBloc orderBloc;
  late ProductBloc productBloc;
  int? orderId; // Store order ID
  double orderTotal = 0.0; // Store order total
  // Discount values
  String _discountValue = "0.00%";
  bool _isPercentageSelected = true;

  // Coupon value
  String _couponCode = "";
  String _cashbackAmount = "";

  // Custom item values
  String _customItemName = "";
  String _customItemPrice = "";
  String _sku = "";

  // Tax slab options
  late List<String> _taxSlabOptions = [];
  String _selectedTaxSlab = '';
  final AssetDBHelper _assetDBHelper = AssetDBHelper.instance;
  bool _isTaxAvailable = false;

  // Payout value
  String _payoutAmount = "";

  // Adding a separate state variable for selected tab
  late int _selectedTabIndex;

  // Text editing controllers
  final TextEditingController _customItemNameController = TextEditingController();
  final TextEditingController _customItemPriceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  // Add this boolean variable to track when user is entering item price
  bool _isEnteringItemPrice = false;
  bool _isAmountEntered = false;

  // Function to check if the item name is empty
  bool _isItemNameEmpty() {
    return _customItemNameController.text
        .trim()
        .isEmpty;
  }

  @override
  void initState() {
    orderBloc = OrderBloc(OrderRepository()); // Build #1.0.53
    productBloc = ProductBloc(ProductRepository());
    super.initState();
    _customItemNameController.addListener(() {
      _customItemName = _customItemNameController.text;
    });
    _customItemPriceController.addListener(() {
      _customItemPrice = _customItemPriceController.text;
    });
    _skuController.addListener(() {
      _sku = _skuController.text;
    });
    _loadOrderData(); // Load order data on initialization
    _loadTaxSlabs();
    // Initialize the selected tab index from widget
    _selectedTabIndex = widget.selectedTabIndex;
    // Add a listener to _customItemNameController to track changes in the text field
    _customItemNameController.addListener(() {
      setState(() {}); // Trigger a rebuild when the text changes
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ///It will load sku and text field both with barcode from scanner initially
    if (kDebugMode) {
      print(
          "WidgetTabs.didChangeDependencies assign text field with barcode value ${_skuController
              .text} = ${widget.barcode}");
    }
    //Build #1.0.234: Fixed Issue [SCRUM - 388] -> SKU Disappears After Device Keyboard is Hidden
    // Only set the barcode value if it's different from current value and not empty
    if (widget.barcode.isNotEmpty && _skuController.text != widget.barcode) {
      if (kDebugMode) {
        print(
            "WidgetTabs.didChangeDependencies assign text field with barcode value ${widget
                .barcode}");
      }
      _skuController.text = widget.barcode;
      _sku = widget.barcode;
      if (kDebugMode) {
        print(
            "WidgetTabs.didChangeDependencies are text field and sku same?  ${_skuController
                .text} = $_sku");
      }
    } else {
      if (kDebugMode) {
        print("#### DEBUG 200 ${_skuController.text}, $_sku");
      }
    }
  }

  Future<void> _loadTaxSlabs() async {
    try {
      List<Tax> taxes = await _assetDBHelper.getTaxList();
      if (kDebugMode) print(
          "#### _loadTaxSlabs: Loaded ${taxes.length} taxes: ${taxes.map((t) =>
              t.toMap()).toList()},  widget.barcode: -${widget.barcode},");
      setState(() {
        _taxSlabOptions = taxes.map((tax) => tax.name).toSet().toList();
        if (_taxSlabOptions.isNotEmpty) {
          _selectedTaxSlab = _taxSlabOptions.first;
          if (kDebugMode) print(
              "#### _loadTaxSlabs: Set selected tax slab to: $_selectedTaxSlab");
        } else {
          if (kDebugMode) print("#### _loadTaxSlabs: Tax slabs are empty");
          _selectedTaxSlab = ''; // Ensure reset if no options
        }
      });
    } catch (e) {
      if (kDebugMode) print("#### _loadTaxSlabs: Error loading tax slabs: $e");
      setState(() {
        _taxSlabOptions = [];
        _selectedTaxSlab = '';
      });
    }
  }

  @override
  void dispose() {
    _customItemNameController.dispose();
    _customItemPriceController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  // Fetch order ID and total from OrderHelper
  Future<void> _loadOrderData() async {
    await _orderHelper.loadProcessingData();
    setState(() {
      orderId = _orderHelper.activeOrderId;
      if (kDebugMode) {
        print("####_loadOrderData, orderId: $orderId");
      }
      if (orderId != null) {
        _orderHelper.getOrderById(orderId!).then((order) {
          if (order.isNotEmpty) {
            setState(() {
              orderTotal = order.first[AppDBConst.orderTotal] as double? ?? 0.0;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return
      //backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white,
      // const Color(0xFFF1F5F9),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .primaryBackground : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark ? Color(
                    0xFF1A1A1A) : Color(0xFFE1E1E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // Ensures children conform to the rounded corners
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Top Tabs
              _buildTabs(),

              // Content based on selected tab
              Expanded(
                  child: ClipPath(
                      clipper: ContentSideClipper(
                          selectedIndex: _selectedTabIndex),
                      child: _buildTabContent()
                  )
              ),
            ],
          ),
        ),
      );
  }

  //Build the top tabs
  Widget _buildTabs() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return ClipPath(
      clipper: TabSideClipper(selectedIndex: _selectedTabIndex),
      child: Container(
          width: MediaQuery
              .of(context)
              .size
              .width * 0.12,
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .tabsBackground : ThemeNotifier.tabsLightBackground,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab(0, SvgUtils.addDiscountIcon, TextConstants.discounts),
              // Build #1.0.168: Updated - Changed the icons to figma svg icons
              const SizedBox(width: 10),
              // Hide divider if current tab (0) or next tab (1) is selected
              if (_selectedTabIndex != 0 && _selectedTabIndex != 1)
                Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
              _buildTab(1, SvgUtils.addCouponIcon, TextConstants.cashback),
              const SizedBox(width: 10),
              // Hide divider if current tab (1) or next tab (2) is selected
              if (_selectedTabIndex != 1 && _selectedTabIndex != 2)
                Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
              _buildTab(
                  2, SvgUtils.addCustomItemIcon, TextConstants.customItem),
              const SizedBox(width: 10),
              // Hide divider if current tab (2) or next tab (3) is selected
              if (_selectedTabIndex != 2 && _selectedTabIndex != 3)
                Divider(height: 1, thickness: 0.1, indent: 10, endIndent: 10),
              _buildTab(3, SvgUtils.addPayoutIcon, TextConstants.payoutsText),
            ],
          )
      ),
    );
  }

  // Build individual tab
  Widget _buildTab(int index, String svgPath, String text) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    if (kDebugMode) {
      print("Widget_tabs _buildTab index : $index");
    }
    // Use the state variable instead of widget property
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (kDebugMode) {
            print("Widget_tabs _buildTab onTap index : $index");
          }
          setState(() {
            // Update the state variable instead of widget property
            _selectedTabIndex = index;
            // Reset highlighting when switching away from custom item tab
            if (index != 2) {
              _isEnteringItemPrice = false;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : Colors.white)
                : (themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.tabsBackground
                : ThemeNotifier.tabsLightBackground), //Color(0xFF1E2745))
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture
                  .asset( // Build #1.0.168: Updated - Changed the icons to figma svg icons
                svgPath,
                height: 32,
                width: 32,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : Colors.black)
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Padding(padding: EdgeInsets.only(right: 5), child:
              Text(
                text,
                style: TextStyle(
                  color: isSelected
                      ? (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white
                      : Colors.black)
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildDiscountsTab();
      case 1:
        return _buildCashbackTab();
      case 2:
        return _buildCustomItemTab(context);
      case 3:
        return _buildPayoutsTab();
      default:
        return const SizedBox();
    }
  }

  // DISCOUNTS TAB
  Widget _buildDiscountsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          // 🏷️ Title
          Text(
            TextConstants.applyDiscountToSale,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),

          const SizedBox(height: 20),

          // 🔘 Toggle Between % / ₹
          _buildDiscountToggle(),

          const SizedBox(height: 20),

          // 💬 Discount Entry Field (Styled like payout, centered)
          Container(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              textAlign: TextAlign.center,
              // ✅ Center alignment
              controller: TextEditingController(
                text: _isPercentageSelected
                    ? "${_discountValue.replaceAll('%', '')}%"
                    : "${TextConstants.currencySymbol}${_discountValue
                    .replaceAll(TextConstants.currencySymbol, '')}",
              ),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔢 Custom Numpad
          SizedBox(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 2.25,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
                  String cleanValue = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '')
                      .trim();

                  int rawValue =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  // ✅ Handle both "digit" and "00" properly like payout tab
                  if (digit == '00') {
                    rawValue = (rawValue * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawValue = (rawValue * 10 + d) % 100000000;
                  }

                  double displayValue = rawValue / 100.0;
                  _discountValue = displayValue.toStringAsFixed(2);

                  if (_isPercentageSelected) {
                    _discountValue = "$_discountValue%";
                  }
                });
              },

              onDeletePressed: () {
                setState(() {
                  String cleanValue = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '')
                      .trim();

                  int rawValue =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawValue = rawValue ~/ 10;

                  double displayValue = rawValue / 100.0;
                  _discountValue = displayValue.toStringAsFixed(2);

                  if (_isPercentageSelected) {
                    _discountValue = "$_discountValue%";
                  }
                });
              },

              onClearPressed: () {
                setState(() {
                  _discountValue = "0.00";
                  if (_isPercentageSelected) {
                    _discountValue = "0.00%";
                  }
                });
              },

              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleAddDiscount,
              isLoading: _isDiscountLoading,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
            ),
          ),
        ],
      ),
    );
  }

  // COUPONS TAB
  // Widget _buildCouponsTab() {
  //   final themeHelper = Provider.of<ThemeNotifier>(context);
  //   return Padding(
  //     padding: const EdgeInsets.only(top: 20),
  //     child: Column(
  //       children: [
  //         // Title
  //         Text(
  //           TextConstants.enterCouponCode,
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                 .textDark : Color(0xFF1E2745),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Coupon Code Display
  //         Container(
  //           width: MediaQuery
  //               .of(context)
  //               .size
  //               .width / 2.75,
  //           height: MediaQuery
  //               .of(context)
  //               .size
  //               .height / 12,
  //           padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
  //           decoration: BoxDecoration(
  //             color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                 .paymentEntryContainerColor : Colors.white,
  //             borderRadius: BorderRadius.circular(10),
  //             border: Border.all(
  //                 color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
  //                     .secondaryBackground : Colors.grey.shade300),
  //           ),
  //           alignment: Alignment.center,
  //           child: Text(
  //             _couponCode.isEmpty ? "Ex: 123456789" : _couponCode,
  //             // Build #1.0.53 : updated code
  //             style: TextStyle(
  //               fontSize: 24,
  //               fontWeight: FontWeight.bold,
  //               color: _couponCode.isEmpty ? Colors.grey : themeHelper
  //                   .themeMode == ThemeMode.dark
  //                   ? ThemeNotifier.textDark
  //                   : const Color(0xFF1E2745),
  //             ),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Custom Numpad
  //         SizedBox(
  //           width: MediaQuery
  //               .of(context)
  //               .size
  //               .width / 2.75,
  //           height: MediaQuery
  //               .of(context)
  //               .size
  //               .height / 2.25,
  //           child: CustomNumPad(
  //             onDigitPressed: (digit) {
  //               setState(() {
  //                 _couponCode += digit;
  //               });
  //             },
  //             onClearPressed: () {
  //               setState(() {
  //                 _couponCode = "";
  //               });
  //             },
  //             onDeletePressed: () { // Build #1.0.53 : updated code
  //               setState(() {
  //                 _couponCode = _couponCode.isNotEmpty ? _couponCode.substring(
  //                     0, _couponCode.length - 1) : "";
  //               });
  //             },
  //             actionButtonType: ActionButtonType.add,
  //             onAddPressed: _handleAddCoupon,
  //             isLoading: _isCouponLoading,
  //             isDarkTheme: true,
  //             numPadType: NumPadType.payment,
  //             showAddInsteadOfPay: true,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCashbackTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            TextConstants.addCashbackAmount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 20),

          // 💰 Payout Display
          Container(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                // ✅ Add the symbol only here
                text:
                "${TextConstants.currencySymbol}${_cashbackAmount.isEmpty
                    ? "0.00"
                    : _cashbackAmount}",
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                _isAmountEntered ? FontWeight.bold : FontWeight.normal,
                color: _cashbackAmount.isEmpty
                    ? Colors.grey.shade400
                    : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔢 Custom Numpad
          SizedBox(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 2.25,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
                  // Clean numeric part only
                  String cleanValue = _cashbackAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  if (digit == '00') {
                    rawAmount = (rawAmount * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawAmount = (rawAmount * 10 + d) % 100000000;
                  }

                  double displayValue = rawAmount / 100.0;
                  _cashbackAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },

              onDeletePressed: () {
                setState(() {
                  String cleanValue = _cashbackAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawAmount = rawAmount ~/ 10;

                  double displayValue = rawAmount / 100.0;
                  _cashbackAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },

              onClearPressed: () {
                setState(() {
                  _cashbackAmount = "0.00"; // ✅ no symbol
                  _isAmountEntered = false;
                });
              },

              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleCashbackpayout,
              isLoading: _isCashbackLoading,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
            ),
          ),
        ],
      ),
    );
  }

  // CUSTOM ITEM TAB
  // Widget _buildCustomItemTab() {
  //   return
  //     Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         // First Row: Name & SKU
  //         Row(
  //           children: [
  //             // Name Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Name",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height / 15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       textAlign: TextAlign.left,
  //                       controller: _customItemNameController,
  //                       decoration: InputDecoration(
  //                         contentPadding: EdgeInsets.all(5),
  //                         border: InputBorder.none,
  //                         hintText: "Custom Item Name",
  //                         hintStyle: TextStyle(
  //                           color: Colors.grey,
  //                           fontSize: 14
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(width: 10),
  //             // SKU Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "SKU",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height /15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       controller: _skuController,
  //                       textAlign: TextAlign.center,
  //                       decoration: InputDecoration(
  //                         border: InputBorder.none,
  //                         hintText: "Generate the SKU",
  //                         hintStyle: TextStyle(
  //                             color: Colors.grey,
  //                             fontSize: 14
  //                         ),
  //                         contentPadding: const EdgeInsets.only(right: 5),
  //                         suffix: Container(
  //                           margin: const EdgeInsets.all(5.0),
  //                           child: ElevatedButton(
  //                             onPressed: _generateSku,
  //                             style: ElevatedButton.styleFrom(
  //                               backgroundColor: Colors.red.shade400,
  //                               foregroundColor: Colors.white,
  //                               elevation: 0,
  //                               shape: RoundedRectangleBorder(
  //                                 borderRadius: BorderRadius.circular(8),
  //                               ),
  //                               minimumSize: const Size(70, 40),
  //                             ),
  //                             child: const Text(
  //                               "Generate",
  //                               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 10),
  //
  //         // Second Row: Item Price & Tax
  //         Row(
  //           children: [
  //             // Item Price Field
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Item Price",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height / 15,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: TextField(
  //                       controller: _customItemPriceController,
  //                       //keyboardType: TextInputType.number,
  //                       decoration: const InputDecoration(
  //                         hintText: "Enter the Price",
  //                         hintStyle: TextStyle(
  //                             color: Colors.grey,
  //                             fontSize: 14
  //                         ),
  //                         border: InputBorder.none,
  //                         prefixText: "\$",
  //                         prefixStyle: TextStyle(fontSize: 14),
  //                         contentPadding: EdgeInsets.all(5),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(width: 10),
  //             // Tax Dropdown
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Text(
  //                     "Tax",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Color(0xFF1E2745),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 5),
  //                   Container(
  //                     height: MediaQuery.of(context).size.height /15,
  //                     padding: const EdgeInsets.symmetric(horizontal: 15),
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       borderRadius: BorderRadius.circular(10),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                     child: DropdownButton<String>(
  //                       value: _selectedTaxSlab.isEmpty ? null : _selectedTaxSlab,
  //                       hint: const Text(
  //                         'Choose a Tax Slab',
  //                         style: TextStyle(color: Colors.grey, fontSize: 14),
  //                       ),
  //                       icon: const Icon(Icons.arrow_drop_down),
  //                       isExpanded: true,
  //                       underline: Container(),
  //                       items: _taxSlabOptions.map((String value) {
  //                         return DropdownMenuItem<String>(
  //                           value: value,
  //                           child: Text(value),
  //                         );
  //                       }).toList(),
  //                       onChanged: (newValue) {
  //                         setState(() {
  //                           _selectedTaxSlab = newValue!;
  //                         });
  //                       },
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Custom Numpad
  //         Center(
  //           child: SizedBox(
  //             width: MediaQuery.of(context).size.width / 2.5,
  //             height: MediaQuery.of(context).size.height / 2.275,
  //             child: CustomNumPad(
  //               onDigitPressed: (digit) {
  //                 setState(() {
  //                   if (_customItemPrice == "0.00") {
  //                     _customItemPrice = digit;
  //                     _customItemPriceController.text = digit;
  //                   } else {
  //                     _customItemPrice += digit;
  //                     _customItemPriceController.text = _customItemPrice;
  //                   }
  //                 });
  //               },
  //               onClearPressed: () {
  //                 setState(() {
  //                   _customItemPrice = "";
  //                   _customItemPriceController.text = "";
  //                 });
  //               },
  //               actionButtonType: ActionButtonType.add,
  //               onAddPressed: () {
  //                 _handleAddCustomItem();
  //               },
  //             ),
  //           ),
  //         ),
  //       ],
  //     );
  //
  // }

  // CUSTOM ITEM TAB
  Widget _buildCustomItemTab(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    final themeHelper = Provider.of<ThemeNotifier>(context);

    // return Container(
    //   width: screenWidth * 0.75,
    //   height: screenHeight * 0.75,
    //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 5),
    //   decoration: BoxDecoration(
    //       color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.red,
    //     borderRadius: BorderRadius.circular(16),
    //   ),
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Text(
            TextConstants.customItem,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                  .textDark : Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLabeledTextField(
                title: TextConstants.nameText,
                hintText: TextConstants.customItemName,
                controller: _customItemNameController,
              ),
              const SizedBox(width: 20),
              _buildSkuField(),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            //mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLabeledTextField(
                title: TextConstants.itemPrice,
                hintText: "${TextConstants.currencySymbol} 0.00",
                //TextConstants.enterThePrice,
                controller: _customItemPriceController,
                readOnly: true,
                isHighlighted: _isEnteringItemPrice, // Use dynamic highlighting instead of hardcoded true
              ),
              const SizedBox(width: 20),
              _buildTaxDropdown(),
            ],
          ),
          const SizedBox(height: 10),
          _buildCustomNumpad(context),
        ],
      ),
    );
  }

  Widget _buildCustomNumpad(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery
            .of(context)
            .size
            .width / 2.75,
        height: MediaQuery
            .of(context)
            .size
            .height / 2.75,
        child: CustomNumPad(
          onDigitPressed: (digit) {
            setState(() {
              // Extract numeric part from current value (ignore ₹ or commas)
              String cleanValue = _customItemPrice.replaceAll(
                  RegExp(r'[^\d.]'), '');

              // Convert current value (e.g. "12.34") to integer cents → 1234
              int rawAmount = ((double.tryParse(cleanValue) ?? 0.0) * 100)
                  .round();

              // Append digit(s)
              if (digit == '00') {
                rawAmount =
                    (rawAmount * 100) % 100000000; // shift left two digits
              } else {
                int d = int.tryParse(digit) ?? 0;
                rawAmount =
                    (rawAmount * 10 + d) % 100000000; // shift left one digit
              }

              // Convert back to display value
              double displayValue = rawAmount / 100.0;

              // Update both internal value and controller text
              _customItemPrice = displayValue.toStringAsFixed(2);
              _customItemPriceController.text =
              "${TextConstants.currencySymbol}${_customItemPrice}";

              // Highlight only when price > 0
              _isEnteringItemPrice = rawAmount > 0;
            });
          },

          onClearPressed: () {
            setState(() {
              _customItemPrice = "0.00";
              _customItemPriceController.text =
              "${TextConstants.currencySymbol}0.00";
              _isEnteringItemPrice = false;
            });
          },

          onDeletePressed: () {
            setState(() {
              // Extract numeric value (ignore ₹ or commas)
              String cleanValue = _customItemPrice.replaceAll(
                  RegExp(r'[^\d.]'), '');

              // Convert to integer cents
              int rawAmount = ((double.tryParse(cleanValue) ?? 0.0) * 100)
                  .round();

              // Remove one digit from the end
              rawAmount = rawAmount ~/ 10;

              // Convert back to display value
              double displayValue = rawAmount / 100.0;

              // Update UI + controller
              _customItemPrice = displayValue.toStringAsFixed(2);
              _customItemPriceController.text =
              "${TextConstants.currencySymbol}${_customItemPrice}";

              _isEnteringItemPrice = rawAmount > 0;
            });
          },

          actionButtonType: ActionButtonType.add,
          onAddPressed: () {
            if (kDebugMode) {
              print("✅ onAddPressed triggered — raw price: $_customItemPrice");
            }

            setState(() {
              _isEnteringItemPrice = false;
            });

            // Remove symbols, spaces, etc.
            final cleanedPrice = _customItemPrice.replaceAll(
                RegExp(r'[^0-9.]'), '');
            double? price = double.tryParse(cleanedPrice);

            if (price == null || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter valid price')),
              );
              return;
            }

            // Update the variable with cleaned numeric string
            _customItemPrice = price.toString();

            _handleAddCustomItem();
          },

          isLoading: _isCustomItemLoading,
          isDarkTheme: true,
          numPadType: NumPadType.payment,
          showAddInsteadOfPay: true,
        ),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required String title,
    required String hintText,
    required TextEditingController controller,
    bool readOnly = false,
    bool isHighlighted = false,
  }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    // Conditionally set the border color and width based on the highlight status
    final borderColor = isHighlighted
        ? Colors.deepPurpleAccent
        : (themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.borderColor
        : Colors.grey.shade300);
    final borderWidth = isHighlighted ? 2.0 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(height: 5,),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .textDark : Color(0xFF1E2745),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery
              .of(context)
              .size
              .height / 14,
          width: MediaQuery
              .of(context)
              .size
              .width * 0.2,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
          decoration: BoxDecoration(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .paymentEntryContainerColor : null,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                      .textDark : Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkuField() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5,),
        Text(
          TextConstants.sku,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .textDark : Color(0xFF1E2745),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery
              .of(context)
              .size
              .height / 14,
          width: MediaQuery
              .of(context)
              .size
              .width * 0.2,
          decoration: BoxDecoration(
            border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                    .borderColor : Colors.grey.shade300),
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .paymentEntryContainerColor : Color(0xFFECE9E9),
            // Custom background color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skuController,
                  readOnly: true,
                  textAlign: TextAlign.start,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    hintText: TextConstants.generateTheSku,
                    hintStyle: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: ElevatedButton(
                  onPressed: _isItemNameEmpty() ? null : _generateSku,
                  // Disable functionality if item name is empty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isItemNameEmpty() ? Colors.grey : Colors
                        .redAccent, // Change color based on button state
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    //minimumSize: const Size(60, 36),
                  ),
                  child: const Text(
                    TextConstants.generate,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaxDropdown() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5,),
        Text(
          TextConstants.taxText,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .textDark : Color(0xFF1E2745),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          alignment: Alignment.topLeft,
          height: MediaQuery
              .of(context)
              .size
              .height / 14,
          width: MediaQuery
              .of(context)
              .size
              .width * 0.2,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          decoration: BoxDecoration(
              border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                      .borderColor : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                  .paymentEntryContainerColor : null
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedTaxSlab.isEmpty ? null : _selectedTaxSlab,
            isExpanded: true,
            alignment: Alignment.centerLeft,
            dropdownColor: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : null,
            //underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down),
            items: _taxSlabOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Color(0xFF1E2745),
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (kDebugMode) {
                print("##### _buildTaxDropdown onChanged: $newValue");
              }
              setState(() {
                _selectedTaxSlab = newValue!;
              });
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(top: 0, bottom: 5),
              // left + vertical center
              border: InputBorder.none,
              // No border at all
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            hint: Container(
              //color: Colors.blue,
                padding: EdgeInsets.only(bottom: 0),
                child: Text(TextConstants.chooseTaxSlab,
                  style: TextStyle(
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.textDark
                          : Colors.grey, fontSize: 14),)),
          ),
        ),
      ],
    );
  }


  Widget _buildPayoutsTab() {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            TextConstants.addPaymentAmount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.textDark
                  : const Color(0xFF1E2745),
            ),
          ),
          const SizedBox(height: 20),

          // 💰 Payout Display
          Container(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 12,
            margin: const EdgeInsets.only(top: 10),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                // ✅ Add the symbol only here
                text:
                "${TextConstants.currencySymbol}${_payoutAmount.isEmpty
                    ? "0.00"
                    : _payoutAmount}",
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                _isAmountEntered ? FontWeight.bold : FontWeight.normal,
                color: _payoutAmount.isEmpty
                    ? Colors.grey.shade400
                    : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : const Color(0xFF1E2745),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.paymentEntryContainerColor
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2745),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔢 Custom Numpad
          SizedBox(
            width: MediaQuery
                .of(context)
                .size
                .width / 2.75,
            height: MediaQuery
                .of(context)
                .size
                .height / 2.25,
            child: CustomNumPad(
              onDigitPressed: (digit) {
                setState(() {
                  // Clean numeric part only
                  String cleanValue = _payoutAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();

                  if (digit == '00') {
                    rawAmount = (rawAmount * 100) % 100000000;
                  } else {
                    int d = int.tryParse(digit) ?? 0;
                    rawAmount = (rawAmount * 10 + d) % 100000000;
                  }

                  double displayValue = rawAmount / 100.0;
                  _payoutAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },

              onDeletePressed: () {
                setState(() {
                  String cleanValue = _payoutAmount.replaceAll(',', '').trim();
                  int rawAmount =
                  ((double.tryParse(cleanValue) ?? 0.0) * 100).round();
                  rawAmount = rawAmount ~/ 10;

                  double displayValue = rawAmount / 100.0;
                  _payoutAmount =
                      displayValue.toStringAsFixed(2); // ✅ no symbol
                  _isAmountEntered = rawAmount != 0;
                });
              },

              onClearPressed: () {
                setState(() {
                  _payoutAmount = "0.00"; // ✅ no symbol
                  _isAmountEntered = false;
                });
              },

              actionButtonType: ActionButtonType.add,
              onAddPressed: _handleAddPayout,
              isLoading: _isPayoutLoading,
              numPadType: NumPadType.payment,
              showAddInsteadOfPay: true,
              isDarkTheme: themeHelper.themeMode == ThemeMode.dark,
            ),
          ),
        ],
      ),
    );
  }

  // Generate SKU function
  void _generateSku() {
    // Simple SKU generation logic - prefix + timestamp
    String timestamp = DateTime
        .now()
        .millisecondsSinceEpoch
        .toString()
        .substring(0, 12);
    // String prefix = _customItemName.isNotEmpty
    //     ? _customItemName.substring(0, _customItemName.length > 3 ? 3 : _customItemName.length).toUpperCase()
    //     : "C";

    String prefix = 'C';
    setState(() {
      _sku = "$prefix-$timestamp";
      _skuController.text = _sku;
    });

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(TextConstants.skuGeneratedSuccessfully),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Build the percentage/amount toggle
  Widget _buildDiscountToggle() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      width: MediaQuery
          .of(context)
          .size
          .width / 2.75,
      height: MediaQuery
          .of(context)
          .size
          .height / 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .secondaryBackground : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Percentage option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (!_isPercentageSelected) {
                    _isPercentageSelected = true;
                    // Convert to percentage format
                    _discountValue = "${_discountValue.replaceAll(
                        TextConstants.currencySymbol,
                        '')}%"; // Build #1.0.181: 1. Replaced Hard coded ‘\$’ with TextConstants.currencySymbol
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isPercentageSelected
                      ? Colors.red.shade400
                      : themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                      .tabsBackground : Colors.white,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(9),
                      bottomLeft: Radius.circular(9),
                      topRight: Radius.circular(9),
                      bottomRight: Radius.circular(9)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "%",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isPercentageSelected ? Colors.white : themeHelper
                        .themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // Dollar option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_isPercentageSelected) {
                    _isPercentageSelected = false;
                    // Convert to dollar format
                    _discountValue = _discountValue.replaceAll('%', '');
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                  !_isPercentageSelected ? Colors.redAccent : themeHelper
                      .themeMode == ThemeMode.dark ? ThemeNotifier
                      .tabsBackground : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  TextConstants.currencySymbol,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: !_isPercentageSelected ? Colors.white : themeHelper
                        .themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the discount value display
  Widget _buildDiscountDisplay() {
    // Build #1.0.53 : updated code
    final themeHelper = Provider.of<ThemeNotifier>(context);
    String displayValue = _isPercentageSelected
        ? _discountValue
        : "${TextConstants.currencySymbol}$_discountValue";
    bool isPlaceholder = _discountValue == "0.00%" ||
        _discountValue == "0.00" || _discountValue == "0%" ||
        _discountValue == "0";

    return Container(
      width: MediaQuery
          .of(context)
          .size
          .width / 2.75,
      height: MediaQuery
          .of(context)
          .size
          .height / 14,
      padding: const EdgeInsets.symmetric(vertical: 2),

      /// use this value for all inset paddings
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
            .paymentEntryContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier
                .secondaryBackground : Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        displayValue,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isPlaceholder ? Colors.grey : themeHelper.themeMode ==
              ThemeMode.dark ? ThemeNotifier.textDark : const Color(0xFF1E2745),
        ),
      ),
    );
  }

  // Handle adding the discount
  //Build #1.0.78: Explanation!
  // Moved merchantDiscount update to OrderBloc.addPayout (already updated in OrderBloc to handle this).
  // Added dbOrderId parameter to addPayout call.
  // Kept local update for non-API orders (serverOrderId == null).
  // Added alert dialog with retry option for API failures.
  // Ensured _isDiscountLoading is shown during API calls and cleared afterward.
  // Preserved success toast and UI refresh logic.
  void _handleAddDiscount() async {
    if (kDebugMode) print("#### DEBUG: _handleAddDiscount called");

    final orderId = OrderHelper().activeOrderId;
    if (orderId == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.noActiveOrderError),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isDiscountLoading = true);

    try {
      final box = Hive.box('offlineOrders');
      final orderKey = orderId.toString();

      if (!box.containsKey(orderKey)) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cannot apply discount to empty order"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final order = Map<String, dynamic>.from(box.get(orderKey));

      // Prevent changing an existing discount
      final existingDiscount = (order['merchantDiscount'] is num)
          ? (order['merchantDiscount'] as num).toDouble()
          : 0.0;
      if (existingDiscount > 0) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(
                "Discount already applied. Delete it first to modify."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final productsRaw = order['products'] as List? ?? [];
      if (productsRaw.isEmpty) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cannot apply discount to empty order"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      // Validate discount input
      String discountValue = _discountValue
          .replaceAll('%', '')
          .replaceAll(TextConstants.currencySymbol, '');
      if (discountValue.isEmpty ||
          discountValue == "0" ||
          double.tryParse(discountValue) == null) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text(TextConstants.invalidDiscountError),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final products = productsRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Calculate gross total
      double grossTotal = products.fold(0.0, (sum, item) {
        final price = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        final qty = (item['quantity'] is num)
            ? (item['quantity'] as num).toDouble()
            : double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
        return sum + (price * qty);
      });

      // Calculate discount
      double discountAmount = double.parse(discountValue);
      if (_isPercentageSelected) {
        discountAmount = (discountAmount / 100) * grossTotal;
      }

      // Save discount
      order['merchantDiscount'] = discountAmount;
      order['merchantDiscountIsPercentage'] = _isPercentageSelected;

      // Calculate totals
      double orderTax = (order['orderTax'] is num)
          ? (order['orderTax'] as num).toDouble()
          : 0.0;
      double netTotal = grossTotal - discountAmount;
      double netPayable = netTotal + orderTax;

      order['grossTotal'] = grossTotal;
      order['netTotal'] = netTotal;
      order['netPayable'] = netPayable;

      await box.put(orderKey, order);

      // Reset UI
      setState(() {
        _discountValue = _isPercentageSelected ? "0.00%" : "0.00";
        _isDiscountLoading = false;
      });

      await _orderHelper.loadData();
      await _loadOrderData();
      widget.refreshOrderList?.call();

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text(
              "Discount of ${TextConstants.currencySymbol}${discountAmount.toStringAsFixed(2)} applied"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      if (kDebugMode) print(
          "✅ Merchant discount applied locally: $discountAmount, NetPayable: $netPayable");

    } catch (e) {
      if (kDebugMode) print("Error applying discount: $e");
      setState(() => _isDiscountLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error applying discount: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
// Handle adding the coupon
//   void _handleAddCoupon() async {
//     if (_couponCode.isEmpty || _couponCode == "0") {
//       if (kDebugMode) print("### _couponCode is empty");
//       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//         const SnackBar(
//           content: Text(TextConstants.invalidCouponError),
//           // Build #1.0.181: Added through TextConstants
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     final orderId = OrderHelper()
//         .activeOrderId; //Build #1.0.134: get activeOrderId
//     if (orderId == null) {
//       if (kDebugMode) print("No active order selected");
//       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//         const SnackBar(
//           content: Text(TextConstants.noActiveOrderError),
//           // Build #1.0.181: Added through TextConstants
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isCouponLoading = true;
//     });
//
//     try {
//       final db = await DBHelper.instance.database;
//
//       final orderData = await db
//           .query( // Build #1.0.128: updated missed condition
//         AppDBConst.orderTable,
//         where: '${AppDBConst.orderServerId} = ?',
//         whereArgs: [orderId],
//       );
//
//       if (orderData.isEmpty) {
//         if (kDebugMode) print("Order $orderId not found in database");
//         setState(() => _isCouponLoading = false);
//         ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//           const SnackBar(
//             content: Text(TextConstants.orderNotFoundError),
//             // Build #1.0.181: Added through TextConstants
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         return;
//       }
//
//       // Check for existing coupon with the same couponCode
//       final existingCoupons = await db.query(
//         AppDBConst.purchasedItemsTable,
//         where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst
//             .itemName} = ? AND ${AppDBConst.itemType} = ?',
//         whereArgs: [orderId, _couponCode, ItemType.coupon.value],
//       );
//
//       if (existingCoupons.isNotEmpty) {
//         if (kDebugMode) print(
//             "Coupon with code $_couponCode already exists for order $orderId");
//         ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//           const SnackBar(
//             content: Text(TextConstants.couponAlreadyApplied),
//             // Build #1.0.181: Added through TextConstants
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 2),
//           ),
//         );
//         setState(() {
//           _isCouponLoading = false;
//         });
//         return;
//       }
//
//       StreamSubscription? subscription;
//       if (kDebugMode) print("### Subscribing to applyCouponStream");
//       subscription = orderBloc.applyCouponStream.listen((response) async {
//         if (!mounted) {
//           subscription?.cancel();
//           return;
//         }
//         if (response.status == Status.COMPLETED) {
//           // Insert coupons into DB, ensuring no duplicates
//           for (var coupon in response.data?.couponLines ?? []) {
//             if (coupon.code == null || coupon.id == null) {
//               if (kDebugMode) print("Invalid coupon data: code or id is null");
//               continue;
//             }
//
//             // Double-check for itemServerId to be extra safe
//             final duplicateCheck = await db.query(
//               AppDBConst.purchasedItemsTable,
//               where: '${AppDBConst.orderIdForeignKey} = ? AND ${AppDBConst
//                   .itemServerId} = ?',
//               whereArgs: [orderId, coupon.id],
//             );
//
//             if (duplicateCheck.isEmpty) {
//               await db.insert(AppDBConst.purchasedItemsTable, {
//                 AppDBConst.orderIdForeignKey: orderId!,
//                 AppDBConst.itemServerId: coupon.id,
//                 AppDBConst.itemName: coupon.code!,
//                 AppDBConst.itemSKU: '',
//                 AppDBConst.itemPrice: coupon.nominalAmount?.toDouble() ?? 0.0,
//                 AppDBConst.itemCount: 1,
//                 AppDBConst.itemSumPrice: coupon.nominalAmount?.toDouble() ??
//                     0.0,
//                 AppDBConst.itemImage: 'assets/svg/coupon.svg',
//                 AppDBConst.itemType: ItemType.coupon.value,
//               });
//             }
//           }
//           if (Misc.showDebugSnackBar) {
//             ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//               SnackBar(
//                 content: Text("Coupon '${_couponCode}' applied successfully"),
//                 backgroundColor: Colors.green,
//                 duration: const Duration(seconds: 2),
//               ),
//             );
//           }
//
//           setState(() { // Build #1.0.248: Fixed [SCRUM-400] -> Inappropriate Toast Message Displaying After Custom Item & Coupon Addition
//             _couponCode = "";
//             _isCouponLoading = false;
//           });
//
//           // Refresh UI
//           await _orderHelper.loadData();
//           await _loadOrderData();
//           widget.refreshOrderList?.call();
//           subscription?.cancel();
//         } else if (response.status == Status.ERROR) {
//           if (kDebugMode) print("Failed to apply coupon: ${response.message}");
//           ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
//             SnackBar(
//               content: Text(response.message ?? "Failed to apply coupon"),
//               backgroundColor: Colors.red,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//           setState(() {
//             _isCouponLoading = false;
//           });
//           subscription?.cancel();
//         }
//       }, onError: (error) {
//         if (kDebugMode) print("### applyCouponStream error: $error");
//         setState(() {
//           _isCouponLoading = false;
//         });
//         subscription?.cancel();
//       });
//
//       if (kDebugMode) print("### Calling orderBloc.applyCouponToOrder");
//       await orderBloc.applyCouponToOrder(
//           orderId: orderId!, couponCode: _couponCode);
//     } catch (e) {
//       if (kDebugMode) print("Error applying coupon: $e");
//       setState(() {
//         _isCouponLoading = false;
//       });
//     }
//   }

  void _handleCashbackpayout() async {
    print("🟩 [CASHBACK] START ---- _handleCashbackpayout() ----");

    if (_cashbackAmount.isEmpty ||
        _cashbackAmount == "0" ||
        double.tryParse(_cashbackAmount) == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Invalid cashback amount"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isCashbackLoading = true);

    try {
      final offlineBox = Hive.box('offlineOrders');
      final productBox = Hive.box('productCache');
      final cashbackAmount = double.parse(_cashbackAmount);

      int? orderId = OrderHelper().activeOrderId;

      // Create new order if none exists
      if (orderId == null) {
        orderId = DateTime.now().millisecondsSinceEpoch;
        await offlineBox.put(orderId.toString(), {
          "order_id": orderId,
          "created_at": DateTime.now().toIso8601String(),
          "products": [],
          "payouts": [],
          "cashbacks": [],
          "gross_total": 0.0,
        });
        OrderHelper().activeOrderId = orderId;
      }

      final key = orderId.toString();
      final existingOrder =
      Map<String, dynamic>.from(offlineBox.get(key) ?? {});

      final List<Map<String, dynamic>> cashbacks =
      (existingOrder["cashbacks"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ❌ Only 1 cashback allowed
      if (cashbacks.isNotEmpty) {
        setState(() => _isCashbackLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cashback already applied."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // -------------------------------------------------------
      // 🟢 UNIVERSAL PRODUCT SEARCH FOR "Cashback"
      // -------------------------------------------------------
      Map<String, dynamic>? cashbackProduct;

      for (final k in productBox.keys) {
        final data = productBox.get(k);

        if (data == null) continue;

        // Case A: Direct product map (YOUR MAIN storage)
        if (data is Map) {
          final name = (data["fast_key_item_name"] ??
              data["name"] ??
              "").toString().toLowerCase();

          if (name.contains("cashback")) {
            cashbackProduct = Map<String, dynamic>.from(data);
            break;
          }
        }

        // Case B: { "products": [ ... ] } format
        if (data is Map && data.containsKey("products")) {
          final list = data["products"];
          if (list is List) {
            for (final item in list) {
              final name = (item["fast_key_item_name"] ??
                  item["name"] ??
                  "").toString().toLowerCase();

              if (name.contains("cashback")) {
                cashbackProduct = Map<String, dynamic>.from(item);
                break;
              }
            }
          }
        }

        // Case C: { "data": [...] } format
        if (data is Map && data.containsKey("data")) {
          final list = json.decode(data["data"]);
          if (list is List) {
            for (final item in list) {
              final name = (item["fast_key_item_name"] ??
                  item["name"] ??
                  "").toString().toLowerCase();

              if (name.contains("cashback")) {
                cashbackProduct = Map<String, dynamic>.from(item);
                break;
              }
            }
          }
        }

        if (cashbackProduct != null) break;
      }

      if (cashbackProduct == null) {
        throw "Dynamic cashback product not found in productCache!";
      }

      print("🟢 FOUND CASHBACK PRODUCT → $cashbackProduct");



      // -------------------------------------------------------
      // 🧾 PREPARE CASHBACK ENTRY
      // -------------------------------------------------------
      final cashbackEntry = {
        "order_id": orderId,
        "cashback_product_id": cashbackProduct["fast_key_product_id"],
        "product_name": cashbackProduct["fast_key_item_name"],
    "product_image": "https://merchantretail.alektasolutions.com/wp-content/uploads/2025/11/cashback-line-item.jpg",


    // ---- your amount ----
        "amount": cashbackAmount,

        // ---- REQUIRED FOR ORDER PANEL ----
        AppDBConst.itemPrice: cashbackAmount.abs(),          // ⭐ MUST
        AppDBConst.itemSumPrice: cashbackAmount.abs(),       // ⭐ MUST
        AppDBConst.itemCount: 1,                             // ⭐ MUST
        AppDBConst.itemName: "Cashback",                     // optional but clean
        AppDBConst.itemType: "cashback",

        "timestamp": DateTime.now().toIso8601String(),
      };



      cashbacks.add(cashbackEntry);

      print("🟦 Cashback Entry Added → $cashbackEntry");

      // -------------------------------------------------------
      // 🔄 Recalculate total
      // -------------------------------------------------------
      final List<Map<String, dynamic>> products =
      (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      double productsTotal = 0.0;
      for (var p in products) {
        productsTotal +=
            (double.tryParse(p["price"].toString()) ?? 0.0) *
                (double.tryParse(p["quantity"].toString()) ?? 1.0);
      }

      // Cashback reduces total
      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "cashbacks": cashbacks,
        "gross_total": productsTotal - cashbackAmount,
      };

      await offlineBox.put(key, updatedOrder);
      print("🟩 SAVED ORDER → $updatedOrder");

      // -------------------------------------------------------
      // ✔ UI feedback
      // -------------------------------------------------------
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Cashback ₹${cashbackAmount.toStringAsFixed(2)} applied"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _cashbackAmount = "";
        _isCashbackLoading = false;
      });

      await _loadOrderData();
      widget.refreshOrderList?.call();

    } catch (e, s) {
      print("🟥 [CASHBACK ERROR] $e\n$s");
      setState(() => _isCashbackLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(content: Text("Error adding cashback: $e"), backgroundColor: Colors.red),
      );
    }
  }




  // Handle adding the custom item
  //Build #1.0.78: Explanation!
  // Moved custom item insertion and order total update to OrderBloc.updateOrderProducts.
  // Added sku to OrderLineItem for API calls.
  // Added dbOrderId parameter to updateOrderProducts.
  // Kept local insertion for non-API orders.
  // Added alert dialog with retry option for API failures.
  // Ensured _isCustomItemLoading is shown during API calls.
  // Preserved success toast, UI refresh, and field clearing logic.
  // Removed commented-out navigation code, as it’s marked as not working.
  Future<void> _handleAddCustomItem() async {
    if (kDebugMode) print("#### DEBUG 55@99 _handleAddCustomItem");

    // 🔹 Validate name
    if (_customItemName.isEmpty) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.itemNameRequired),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 🔹 Validate price
    if (_customItemPrice.isEmpty ||
        double.tryParse(_customItemPrice) == null ||
        double.parse(_customItemPrice) == 0) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.invalidPriceError),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isCustomItemLoading = true);

    try {
      final orderHelper = OrderHelper();
      final serverOrderId =
          orderHelper.activeOrderId ?? DateTime.now().millisecondsSinceEpoch;
      orderHelper.activeOrderId ??= serverOrderId;

      final box = Hive.box('offlineOrders');

      // ✅ Ensure order exists
      if (!box.containsKey(serverOrderId.toString())) {
        await box.put(serverOrderId.toString(), {
          'order_id': serverOrderId,
          'products': [],
          'orderAgeRestricted': false,
        });
      }

      // ✅ TAX slab logic
      final List<Tax> taxes = await _assetDBHelper.getTaxList();
      String taxStatus = "";
      String taxClass = "";
      if (_selectedTaxSlab.isNotEmpty) {
        final selectedTax = taxes.firstWhere(
              (tax) => tax.name == _selectedTaxSlab,
          orElse: () =>
          taxes.isNotEmpty ? taxes.first : Tax(slug: 'none', name: _selectedTaxSlab),
        );
        if (selectedTax.slug.isNotEmpty) {
          taxStatus = TextConstants.taxable;
          taxClass = selectedTax.slug;
        }
      }

      // ✅ Always normalize SKU consistently
      _sku = _sku.trim().isEmpty
          ? _customItemName.trim().toLowerCase().replaceAll(' ', '')
          : _sku.trim().toLowerCase();
      final normalizedSku = _sku;

      // ✅ Load order safely
      final rawOrder = box.get(serverOrderId.toString()) ?? {};
      final orderData = Map<String, dynamic>.from(_convertToJsonSafe(rawOrder));
      final products = (orderData['products'] as List? ?? [])
          .map((p) => Map<String, dynamic>.from(_convertToJsonSafe(p)))
          .toList();

      // ✅ Match existing by SKU ONLY (no name match)
      final existingIndex = products.indexWhere((p) {
        final storedSku = (p['sku'] ?? '').toString().trim().toLowerCase();
        return storedSku == normalizedSku;
      });

      if (existingIndex != -1) {
        // 🔁 Increase quantity
        final existingItem = products[existingIndex];
        final currentQty = (existingItem['quantity'] ?? 1);
        existingItem['quantity'] = currentQty + 1;
        products[existingIndex] = existingItem;
        if (kDebugMode) print("🔁 Increased quantity for SKU: $normalizedSku");
      } else {
        // 🆕 Add new
        final customItem = {
          'id': normalizedSku.hashCode,
          'name': _customItemName,
          'price': double.parse(_customItemPrice),
          'sku': normalizedSku,
          'taxStatus': taxStatus,
          'taxClass': taxClass,
          'tags': [TextConstants.customItem],
          'quantity': 1,
        };
        products.add(customItem);
        if (kDebugMode) print("🆕 Added new custom item SKU: $normalizedSku");
      }

      // ✅ Save back
      await box.put(serverOrderId.toString(), {...orderData, 'products': products});

      // ✅ Cache in Hive + memory
      final productBox = Hive.box('productCache');
      final cacheKey = "sku_$normalizedSku";
      final customProductJson = {
        "id": normalizedSku.hashCode,
        "name": _customItemName,
        "type": "custom",
        "price": _customItemPrice,
        "sku": normalizedSku,
        "taxStatus": taxStatus,
        "taxClass": taxClass,
        "images": [],
        "variations": [],
      };
      await productBox.put(cacheKey, {"products": [customProductJson]});
      OrderHelper.addToCache(normalizedSku, customProductJson);

      if (kDebugMode) {
        print("💾 Custom item cached under key: $cacheKey");
        print("⚡ In-memory cache ready for instant scan recognition");
      }

      // ✅ Reset UI
      setState(() {
        _isCustomItemLoading = false;
        _customItemName = "";
        _customItemPrice = "";
        _sku = "";
        _selectedTaxSlab = _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first : "";
        _customItemNameController.clear();
        _customItemPriceController.clear();
        _skuController.clear();
      });

      await _orderHelper.loadData();
      await _loadOrderData();
      widget.refreshOrderList?.call();

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("✅ Custom item added/updated successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (kDebugMode) print("❌ Exception in _handleAddCustomItem: $e");
      setState(() => _isCustomItemLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error adding custom item: $e"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  /// ✅ Converts any deeply nested Map/List from Hive into JSON-safe Map<String, dynamic>
  dynamic _convertToJsonSafe(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      // Convert keys to String and recursively clean nested structures
      return value.map((k, v) => MapEntry(k.toString(), _convertToJsonSafe(v)));
    } else if (value is List) {
      return value.map(_convertToJsonSafe).toList();
    } else {
      return value; // primitives remain unchanged
    }
  }

  // Handle adding the payout
  //Build #1.0.78: Explanation!
  // Moved payout insertion to OrderBloc.addPayout.
  // Added dbOrderId parameter to addPayout.
  // Kept local insertion for non-API orders.
  // Added alert dialog with retry option for API failures.
  // Ensured _isPayoutLoading is shown during API calls.
  // Preserved success toast and UI refresh logic.
  void _handleAddPayout() async {
    print("🟦 [PAYOUT] START ---- _handleAddPayout() ----");

    if (_payoutAmount.isEmpty ||
        _payoutAmount == "0" ||
        double.tryParse(_payoutAmount) == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Invalid payout amount"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isPayoutLoading = true);

    try {
      final offlineBox = Hive.box('offlineOrders');
      final productBox = Hive.box('productCache');
      final payoutAmount = double.parse(_payoutAmount);

      int? orderId = OrderHelper().activeOrderId;
      if (orderId == null) {
        orderId = DateTime.now().millisecondsSinceEpoch;
        await offlineBox.put(orderId.toString(), {
          "order_id": orderId,
          "created_at": DateTime.now().toIso8601String(),
          "products": [],
          "payouts": [],
          "gross_total": 0.0,
        });
        OrderHelper().activeOrderId = orderId;
      }

      final key = orderId.toString();
      final existingOrder = Map<String, dynamic>.from(offlineBox.get(key));

      final payouts = (existingOrder["payouts"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (payouts.isNotEmpty) {
        setState(() => _isPayoutLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("A payout already exists for this order."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Map<String, dynamic>? payoutProduct;
      for (final k in productBox.keys) {
        if (k.toString().startsWith("products_")) {
          final data = productBox.get(k);
          if (data == null) continue;

          final list = json.decode(data["data"]);
          for (final item in list) {
            final name = (item["fast_key_item_name"] ?? "").toString().toLowerCase();
            if (name.contains("payout")) {
              payoutProduct = Map<String, dynamic>.from(item);
              print("✅ [PAYOUT] Found dynamic payout product in Hive → $payoutProduct");
              break;
            }
          }
        }
        if (payoutProduct != null) break;
      }
      payoutProduct ??= {
        "fast_key_product_id": DateTime.now().millisecondsSinceEpoch,
        "fast_key_item_name": "Payout",
        "fast_key_item_price": 0,
        "fast_key_item_image":
        "https://merchantretail.alektasolutions.com/wp-content/uploads/2025/11/payout-2-1.png",
        "type": "simple",
      };
      final payoutEntry = {
        "order_id": orderId,
        "payout_product_id": payoutProduct["fast_key_product_id"],
        "product_name": payoutProduct["fast_key_item_name"],
        "product_image": payoutProduct["fast_key_item_image"],
        "amount": -payoutAmount,
        "type": "payout",
        "timestamp": DateTime.now().toIso8601String(),
      };

      payouts.add(payoutEntry);

      final products = (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      double total = 0.0;
      for (var p in products) {
        total += (p["price"] ?? 0) * (p["quantity"] ?? 1);
      }

      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "payouts": payouts,
        "gross_total": total + (-payoutAmount),
      };

      await offlineBox.put(key, updatedOrder);

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Payout of ₹${payoutAmount.toStringAsFixed(2)} added successfully"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _payoutAmount = "";
        _isPayoutLoading = false;
      });

      await _loadOrderData();
      widget.refreshOrderList?.call();

      print("✅ [PAYOUT] DONE ---- _handleAddPayout() ----");
    } catch (e, s) {
      print("🟥 [PAYOUT] ERROR: $e\n$s");
      setState(() => _isPayoutLoading = false);
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error adding payout: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
class TabSideClipper extends CustomClipper<Path> {
  final int selectedIndex;

  TabSideClipper({required this.selectedIndex});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double tabHeight = size.height / 4;
    double selectedTabTop = selectedIndex * tabHeight;
    double selectedTabBottom = selectedTabTop + tabHeight;
    double curveRadius = 16.0; // Your specified curve radius

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    // Top curve around selected tab
    if (selectedIndex > 0) {
      path.lineTo(size.width, selectedTabTop - curveRadius);
      // Smooth curve into the tab indent
      path.quadraticBezierTo(
          size.width, selectedTabTop,
          size.width - curveRadius, selectedTabTop
      );
      path.lineTo(size.width - curveRadius, selectedTabTop);
    } else {
      // If first tab is selected, start the indent from top
      path.lineTo(size.width - curveRadius, 0);
    }

    // Straight line along the tab indent
    path.lineTo(size.width - curveRadius, selectedTabBottom);

    // Bottom curve around selected tab
    if (selectedIndex < 3) {
      // Smooth curve out of the tab indent
      path.quadraticBezierTo(
          size.width, selectedTabBottom,
          size.width, selectedTabBottom + curveRadius
      );
      path.lineTo(size.width, size.height);
    } else {
      // If last tab is selected, end the indent at bottom
      path.lineTo(size.width, size.height);
    }

    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class ContentSideClipper extends CustomClipper<Path> {
  final int selectedIndex;

  ContentSideClipper({required this.selectedIndex});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double tabHeight = size.height / 4;
    double selectedTabTop = selectedIndex * tabHeight;
    double selectedTabBottom = selectedTabTop + tabHeight;
    double cornerRadius = 16.0;
    double indentDepth = 16.0;

    // Start with rounded top-left corner
    path.moveTo(cornerRadius, 0);
    path.quadraticBezierTo(0, 0, 0, cornerRadius);

    // Top part before the selected tab indent
    if (selectedIndex > 0) {
      path.lineTo(0, selectedTabTop - cornerRadius);
      // Smooth curve into the indent (curves inward)
      path.quadraticBezierTo(0, selectedTabTop, cornerRadius, selectedTabTop);
      path.quadraticBezierTo(indentDepth, selectedTabTop + cornerRadius, indentDepth, selectedTabTop + cornerRadius * 2);
    } else {
      // If first tab is selected, start indent from top
      path.lineTo(0, cornerRadius);
      path.quadraticBezierTo(cornerRadius, cornerRadius, indentDepth, cornerRadius * 2);
    }

    // Middle of the indent (straight line)
    path.lineTo(indentDepth, selectedTabBottom - cornerRadius * 2);

    // Bottom part - curve out of the selected tab indent
    path.quadraticBezierTo(indentDepth, selectedTabBottom - cornerRadius, cornerRadius, selectedTabBottom);
    path.quadraticBezierTo(0, selectedTabBottom, 0, selectedTabBottom + cornerRadius);

    // Now add the outward bulge for the tab below the selected one
    if (selectedIndex < 3) {
      double nextTabTop = selectedTabBottom + cornerRadius;
      double nextTabBottom = nextTabTop + tabHeight - (cornerRadius * 2);

      // Go down a bit then curve outward (bulge)
      path.lineTo(0, nextTabTop);
      path.quadraticBezierTo(-cornerRadius, nextTabTop + cornerRadius, -cornerRadius, nextTabTop + cornerRadius * 2);
      path.lineTo(-cornerRadius, nextTabBottom - cornerRadius);
      path.quadraticBezierTo(-cornerRadius, nextTabBottom, 0, nextTabBottom + cornerRadius);

      if (selectedIndex < 2) {
        // Continue to bottom if not the second-to-last tab
        path.lineTo(0, size.height - cornerRadius);
      } else {
        // Go to bottom
        path.lineTo(0, size.height - cornerRadius);
      }
    } else {
      // Last tab selected, just go to bottom
      path.lineTo(0, size.height - cornerRadius);
    }

    // Rounded bottom-left corner
    path.quadraticBezierTo(0, size.height, cornerRadius, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}