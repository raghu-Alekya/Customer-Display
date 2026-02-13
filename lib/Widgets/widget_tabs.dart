import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
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
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Helper/cashbackhelper.dart';
import '../Models/Assets/asset_model.dart';
import '../Models/Orders/orders_model.dart';
import '../Models/Search/product_custom_item_model.dart' as model;
import '../Repositories/Assets/asset_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Utilities/svg_images_utility.dart';
import 'OrderPopupHelper.dart';
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
  List<TaxModel> _taxList = [];
  TaxModel? _selectedTax;
  bool _isTaxLoading = false;


  // Tax slab options
  late List<String> _taxSlabOptions = [];
  String _selectedTaxSlab = '';
  final AssetDBHelper _assetDBHelper = AssetDBHelper.instance;
  bool _isTaxAvailable = false;

  // Payout value
  String _payoutAmount = "";
  double _maxCashbackLimit = 0.0;
  late final OrderRepository _orderRepository;



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
  String normalizeSku(String s) {
    return (s ?? "")
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
  }


  @override
  void initState() {
    _orderRepository = OrderRepository();
    orderBloc = OrderBloc(OrderRepository()); // Build #1.0.53
    productBloc = ProductBloc(ProductRepository());
    super.initState();
    _loadCashbackLimit();
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
    _loadTaxes();
    // Initialize the selected tab index from widget
    _selectedTabIndex = widget.selectedTabIndex;
    // Add a listener to _customItemNameController to track changes in the text field
    _customItemNameController.addListener(() {
      setState(() {}); // Trigger a rebuild when the text changes
    });
  }
  Future<void> _loadTaxes() async {
    setState(() => _isTaxLoading = true);

    _taxList = await _orderRepository.getAllTaxes();

    setState(() => _isTaxLoading = false);
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
  void _loadCashbackLimit() async {
    final config = await CashbackHelper.getCashbackConfig();

    if (config != null &&
        config["cash_back_service"] != null &&
        config["cash_back_service"]["max_cashback"] != null) {

      setState(() {
        _maxCashbackLimit =
            double.tryParse(config["cash_back_service"]["max_cashback"].toString()) ?? 0.0;
      });

      print("🟢 Loaded Max Cashback Limit = $_maxCashbackLimit");
    } else {
      print("❌ max_cashback NOT FOUND");
    }
  }


  // Fetch order ID and total from OrderHelper (use loadData for offline orders)
  Future<void> _loadOrderData() async {
    await _orderHelper.loadData();
    setState(() {
      orderId = _orderHelper.activeOrderId;
      if (kDebugMode) {
        print("####_loadOrderData, orderId: $orderId");
      }
      if (orderId != null) {
        final order = _orderHelper.orders.cast<Map<String, dynamic>>()
            .where((o) {
          final oid = o['order_id'] ?? o['id'] ?? o[AppDBConst.orderServerId];
          return oid != null && (oid == orderId || oid.toString() == orderId.toString());
        }).toList();
        if (order.isNotEmpty) {
          final o = order.first;
          orderTotal = (o['gross_total'] ?? o['net_payable'] ?? o['net_total'] ?? o[AppDBConst.orderTotal] ?? 0.0) is num
              ? ((o['gross_total'] ?? o['net_payable'] ?? o['net_total'] ?? o[AppDBConst.orderTotal]) as num).toDouble()
              : 0.0;
        }
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
        padding: const EdgeInsets.fromLTRB(4, 10, 2, 10),
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
                .tabsBackground :Color(0xFFEAEDFF),
            // borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTab(
                0,
                SvgUtils.addDiscountIcon,
                "Merchant \nDiscounts",

                const Color(0xFFFFFFFF), // default = white for logo
                const Color(0xFFFFFFFF),// Foreground text color
                // Color(0xFF007BFF),      // icon color
                // Color(0xFF007BFF),    // text color
                // color: isSelected
                //     ? const Color(0xFFFFFFFF) // default = white
                //     : Colors.blue,          // selected = blue

                //themeHelper: themeHelper,
              ),

              const SizedBox(width: 10),

              if (_selectedTabIndex != 0 && _selectedTabIndex != 1)
                Divider(height: 1, thickness: 1, indent: 1, endIndent: 1,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.black
                        : Color(0xFF2B367F)),

              _buildTab(
                  1,
                  SvgUtils.cashbackIcon,
                  "Cashback",
                  // Color(0xFF55CBCD),    // icon color
                  // Color(0xFF55CBCD),     // text color
                  const Color(0xFFFFFFFF), // default = white for logo
                  const Color(0xFFFFFFFF)

              ),

              const SizedBox(width: 10),

              if (_selectedTabIndex != 1 && _selectedTabIndex != 2)
                Divider(height: 1, thickness: 1, indent: 10, endIndent: 10,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? Colors.black
                        : Color(0xFFB6BFF9)),

              _buildTab(
                  2,
                  SvgUtils.addCustomItemIcon,
                  "Custom\nItem",
                  // Color(0xFF55709A),    // icon color
                  // Color(0xFF55709A),
                  const Color(0xFFFFFFFF), // default = white for logo
                  const Color(0xFFFFFFFF)


              ),

              const SizedBox(width: 10),

              if (_selectedTabIndex != 2 && _selectedTabIndex != 3)
                Divider(height: 1, thickness: 1, indent: 10, endIndent: 10,   color: themeHelper.themeMode == ThemeMode.dark
                    ? Colors.black
                    : Color(0xFFB6BFF9)),

              _buildTab(
                  3,
                  SvgUtils.addPayoutIcon,
                  "Payouts",
                  // Color(0xFFD93535),    // icon color
                  // Color(0xFFD93535),   // text color
                  const Color(0xFFFFFFFF), // default = white for logo
                  const Color(0xFFFFFFFF)
              ),
            ],
          )

      ),
    );
  }
  Widget _buildTab(
      int index,
      String svgPath,
      String text,
      Color iconColor,
      Color textColor,

      ) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    bool isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(

        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            if (index != 2) _isEnteringItemPrice = false;
          });
        },
        child: SizedBox( // 🔒 LOCK HEIGHT
          //height: 80,
          //width: 20,
          // adjust if needed (same for all tabs)
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(

              //   color: isSelected
              //       ? (themeHelper.themeMode == ThemeMode.dark
              //       ? ThemeNotifier.primaryBackground
              //       : Colors.white) // this will set the card background
              //       : (themeHelper.themeMode == ThemeMode.dark
              //       ? ThemeNotifier.tabsBackground
              //       : ThemeNotifier.tabsLightBackground),
              //   borderRadius: BorderRadius.circular(16.0),
              // ),//**8Raghu modified the code below, with blue cards when selected it shows white

              color: isSelected
                  ? const Color(0xFFB5BCDE)  // selected light color
                  : const Color(0xFF2E657E),  // unselected blue
              //borderRadius: BorderRadius.circular(2.0),
              /// borderRadius: BorderRadius.circular(0), // REMOVE rounded corners for now
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                SvgPicture.asset(
                  svgPath,
                  height: 32,
                  width: 32,
                  colorFilter: ColorFilter.mode(
                    isSelected ? iconColor : iconColor.withOpacity(0.8),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 5),
                //Padding(
                // padding: const EdgeInsets.only(right: 8, top: 3),
                //child:
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    //color: isSelected
                    //? textColor
                    //: textColor.withOpacity(0.8),
                    //fontSize: isSelected ? 18 : 16,
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    // fontWeight:
                    //isSelected ? FontWeight.bold : FontWeight.bold,
                  ),
                ),

              ],
            ),
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
          // 🏷 Title
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

                // ✔ Bold only when non-zero
                fontWeight: (() {
                  final clean = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '');
                  return (clean == "0.00" || clean.isEmpty)
                      ? FontWeight.normal
                      : FontWeight.bold;
                })(),

                // ✔ Light grey when zero or empty
                color: (() {
                  final clean = _discountValue
                      .replaceAll('%', '')
                      .replaceAll(TextConstants.currencySymbol, '');
                  return (clean == "0.00" || clean.isEmpty)
                      ? Colors.grey.shade400
                      : (themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : const Color(0xFF1E2745));
                })(),
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
                .height / 2.85,
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
          const SizedBox(height: 10),
          // ⭐ MAX Cashback Info (from backend)
          if (_maxCashbackLimit > 0)
            Column(
              children: [
                Text(
                  "Max Allowed Cashback: ${TextConstants.currencySymbol}${_maxCashbackLimit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),


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
        const SizedBox(height: 5),
        Text(
          TextConstants.taxText,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : const Color(0xFF1E2745),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery.of(context).size.height / 14,
          width: MediaQuery.of(context).size.width * 0.2,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.borderColor
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(10),
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.paymentEntryContainerColor
                : null,
          ),
          child: _isTaxLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : DropdownButtonFormField<TaxModel>(
            value: _selectedTax,
            isExpanded: true,
            dropdownColor: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.primaryBackground
                : null,
            icon: const Icon(Icons.keyboard_arrow_down),
            items: _taxList.map((tax) {
              return DropdownMenuItem<TaxModel>(
                value: tax,
                child: Text(
                  tax.name, // ✅ DISPLAY NAME FROM API
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark
                        : const Color(0xFF1E2745),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (kDebugMode) {
                print("✅ Selected Tax: ${value?.name} | Rate: ${value?.rate}");
              }
              setState(() {
                _selectedTax = value;
              });
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            hint: Text(
              TextConstants.chooseTaxSlab,
              style: TextStyle(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark
                    : Colors.grey,
                fontSize: 14,
              ),
            ),
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

  static final Map<int, Map<String, dynamic>> _productMetaCache = {};
  static bool _productMetaInitialized = false;


  Future<Map<String, dynamic>?> _getCashbackProductFromIsar() async {
    // ⚡ FAST PATH — already cached
    if (_productMetaInitialized && _productMetaCache.isNotEmpty) {
      for (final p in _productMetaCache.values) {
        final name =
        (p["fast_key_item_name"] ?? p["name"] ?? "")
            .toString()
            .toLowerCase();

        if (name.contains("cashback")) {
          return p;
        }
      }
    }

    try {
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      for (final entry in entries) {
        if (!entry.key.startsWith("products_")) continue;

        final List<dynamic> products = jsonDecode(entry.json);

        for (final raw in products) {
          if (raw is! Map) continue;

          final map = Map<String, dynamic>.from(raw);
          final name =
          (map["fast_key_item_name"] ?? map["name"] ?? "")
              .toString()
              .toLowerCase();

          if (name.contains("cashback")) {
            final pid = int.tryParse(
                (map["fast_key_product_id"] ?? map["id"])?.toString() ?? "");

            if (pid != null) {
              _productMetaCache[pid] = map;
              _productMetaInitialized = true;
            }
            return map;
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Cashback Isar lookup failed → $e");
    }

    return null;
  }


  Future<Map<String, dynamic>?> _getDiscountProductFromIsar() async {
    // 🔁 Fast path: already cached
    if (_productMetaInitialized && _productMetaCache.isNotEmpty) {
      for (final p in _productMetaCache.values) {
        final name =
        (p["fast_key_item_name"] ?? p["name"] ?? "")
            .toString()
            .toLowerCase();
        if (name.contains("discount")) return p;
      }
    }

    try {
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      for (final entry in entries) {
        if (!entry.key.startsWith("products_")) continue;

        final List<dynamic> products = jsonDecode(entry.json);
        for (final raw in products) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);

          final name =
          (map["fast_key_item_name"] ?? map["name"] ?? "")
              .toString()
              .toLowerCase();

          if (name.contains("discount")) {
            // cache it for future
            final pid = int.tryParse(
                (map["fast_key_product_id"] ?? map["id"])?.toString() ?? "");
            if (pid != null) {
              _productMetaCache[pid] = map;
              _productMetaInitialized = true;
            }
            return map;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Discount lookup failed → $e");
      }
    }

    return null;
  }


  // Build the discount value display

  // Handle adding the discount
  //Build #1.0.78: Explanation!
  // Moved merchantDiscount update to OrderBloc.addPayout (already updated in OrderBloc to handle this).
  // Added dbOrderId parameter to addPayout call.
  // Kept local update for non-API orders (serverOrderId == null).
  // Added alert dialog with retry option for API failures.
  // Ensured _isDiscountLoading is shown during API calls and cleared afterward.
  // Preserved success toast and UI refresh logic.
  // Future<void> _handleAddDiscount() async {
  //   print("🟦 [DISCOUNT] START ---- _handleAddDiscount() ----");
  //
  //   if (_discountValue.isEmpty ||
  //       _discountValue == "0" ||
  //       double.tryParse(_discountValue.replaceAll('%', '')) == null) {
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       const SnackBar(
  //         content: Text("Invalid discount amount"),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() => _isDiscountLoading = true);
  //
  //   try {
  //     final offlineBox = StorageProvider.offlineOrders;
  //     final orderHelper = OrderHelper();
  //
  //     int? orderId = orderHelper.activeOrderId;
  //
  //     if (orderId == null) {
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("No active order found"),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //       setState(() => _isDiscountLoading = false);
  //       return;
  //     }
  //
  //     final key = orderId.toString();
  //     final existingOrder = Map<String, dynamic>.from(offlineBox.get(key));
  //
  //     // Load existing discount list
  //     final discounts = (existingOrder["discounts"] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     if (discounts.isNotEmpty) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("A discount already exists for this order."),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // ------------------------------
  //     // 🔎 UNIVERSAL SEARCH FOR DISCOUNT PRODUCT
  //     // Same logic as cashback
  //     // ------------------------------
  //
  //     // 🔎 DISCOUNT PRODUCT FROM ISAR (FAST)
  //     final discountProduct = await _getDiscountProductFromIsar();
  //
  //     if (discountProduct == null) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Discount product not found!"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     print("🟢 FOUND DISCOUNT PRODUCT → $discountProduct");
  //
  //     // Map<String, dynamic>? discountProduct;
  //     //
  //     // for (final k in productBox.keys) {
  //     //   final data = productBox.get(k);
  //     //   if (data == null) continue;
  //     //
  //     //   // Case A: Direct map
  //     //   if (data is Map) {
  //     //     final n = (data["fast_key_item_name"] ?? data["name"] ?? "")
  //     //         .toString()
  //     //         .toLowerCase();
  //     //
  //     //     if (n.contains("discount")) {
  //     //       discountProduct = Map<String, dynamic>.from(data);
  //     //       break;
  //     //     }
  //     //   }
  //     //
  //     //   // Case B: products list
  //     //   if (data is Map && data.containsKey("products")) {
  //     //     for (final item in data["products"]) {
  //     //       final n = (item["fast_key_item_name"] ?? item["name"] ?? "")
  //     //           .toString()
  //     //           .toLowerCase();
  //     //
  //     //       if (n.contains("discount")) {
  //     //         discountProduct = Map<String, dynamic>.from(item);
  //     //         break;
  //     //       }
  //     //     }
  //     //     if (discountProduct != null) break;
  //     //   }
  //     //
  //     //   // Case C: data: JSON array
  //     //   if (data is Map && data.containsKey("data")) {
  //     //     final list = json.decode(data["data"]);
  //     //     for (final item in list) {
  //     //       final n = (item["fast_key_item_name"] ?? item["name"] ?? "")
  //     //           .toString()
  //     //           .toLowerCase();
  //     //
  //     //       if (n.contains("discount")) {
  //     //         discountProduct = Map<String, dynamic>.from(item);
  //     //         break;
  //     //       }
  //     //     }
  //     //     if (discountProduct != null) break;
  //     //   }
  //     // }
  //     //
  //     // if (discountProduct == null) {
  //     //   print("🟥 Discount Product Not Found in Cache!");
  //     //   setState(() => _isDiscountLoading = false);
  //     //
  //     //   ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //     //     const SnackBar(
  //     //       content: Text("Discount product not found!"),
  //     //       backgroundColor: Colors.red,
  //     //     ),
  //     //   );
  //     //   return;
  //     // }
  //
  //     print("🟢 FOUND DISCOUNT PRODUCT → $discountProduct");
  //
  //     // ------------------------------
  //     // Load products
  //     // ------------------------------
  //     final products = (existingOrder["products"] as List? ?? [])
  //         .map((e) => Map<String, dynamic>.from(e))
  //         .toList();
  //
  //     // / ⛔ ADD CHECK HERE
  //     if (products.isEmpty) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Cannot apply discount on an empty order"),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }
  //
  //
  //     // Calculate gross total
  //     double grossTotal = 0.0;
  //     for (var p in products) {
  //       grossTotal +=
  //           (double.tryParse(p["price"].toString()) ?? 0.0) *
  //               (double.tryParse(p["quantity"].toString()) ?? 1.0);
  //     }
  //
  //     // Parse discount amount
  //     String parsedValue =
  //     _discountValue.replaceAll('%', '').replaceAll("₹", "").trim();
  //
  //     double discountAmount = double.parse(parsedValue);
  //     bool isPercentage = _isPercentageSelected;
  //
  //     if (isPercentage) {
  //       discountAmount = (discountAmount / 100) * grossTotal;
  //     }
  //
  //     if (discountAmount > grossTotal) {
  //       setState(() => _isDiscountLoading = false);
  //       ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //         const SnackBar(
  //           content: Text("Discount cannot exceed total amount"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }
  //
  //     // ------------------------------
  //     // 🧾 CREATE DISCOUNT ENTRY
  //     // ------------------------------
  //     final discountEntry = {
  //       "order_id": orderId,
  //       "discount_product_id":
  //       discountProduct["product_id"] ??
  //           discountProduct["id"] ??
  //           discountProduct["fast_key_product_id"],
  //       // ⭐ SAME AS CASHBACK
  //       "name": discountProduct["fast_key_item_name"] ?? "Discount",
  //       "product_image": discountProduct["fast_key_item_image"] ?? "",
  //
  //       "discount_amount": -discountAmount,     // Negative for Woo
  //       "display_amount": discountAmount,       // Shown positive in UI
  //
  //       "discount_type": isPercentage ? "percentage" : "fixed",
  //       "original_input": _discountValue,
  //
  //       // Required for summary panel
  //       AppDBConst.itemName: "Discount",
  //       AppDBConst.itemType: "discount",
  //       AppDBConst.itemPrice: discountAmount.abs(),
  //       AppDBConst.itemSumPrice: discountAmount.abs(),
  //       AppDBConst.itemCount: 1,
  //
  //       "timestamp": DateTime.now().toIso8601String(),
  //     };
  //
  //     discounts.add(discountEntry);
  //
  //     // Recalculate totals
  //     double finalTotal = grossTotal - discountAmount;
  //
  //     final updatedOrder = {
  //       ...existingOrder,
  //       "products": products,
  //       "discounts": discounts,
  //       "gross_total": grossTotal,
  //       "net_total": grossTotal - discountAmount,
  //       "net_payable": finalTotal,
  //
  //       // ⭐ REQUIRED FIELDS FOR SUMMARY PANEL ⭐
  //       "merchantDiscount": discountAmount,              // <--- You MISSED THIS
  //       "merchantDiscountIsPercentage": isPercentage,    // <--- You MISSED THIS
  //       "merchantDiscountIds": [
  //         discountProduct["product_id"] ??
  //             discountProduct["id"] ??
  //             discountProduct["fast_key_product_id"]
  //       ],
  //     };
  //
  //
  //
  //     await offlineBox.put(key, updatedOrder);
  //
  //     // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //     //   SnackBar(
  //     //     content:
  //     //     Text("Discount of ₹${discountAmount.toStringAsFixed(2)} applied"),
  //     //     backgroundColor: Colors.green,
  //     //   ),
  //     // );
  //
  //     setState(() {
  //       _discountValue = isPercentage ? "0%" : "0";
  //       _isDiscountLoading = false;
  //     });
  //
  //     await _loadOrderData();
  //     widget.refreshOrderList?.call();
  //
  //     print("✅ [DISCOUNT] DONE ---- _handleAddDiscount() ----");
  //
  //   } catch (e, s) {
  //     print("🟥 [DISCOUNT] ERROR: $e\n$s");
  //     setState(() => _isDiscountLoading = false);
  //
  //     ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
  //       SnackBar(
  //         content: Text("Error applying discount: $e"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }


  Future<void> _handleAddDiscount() async {
    print("🟦 [DISCOUNT] START ---- _handleAddDiscount() ----");

    // ────────────────────────────────────────
    // 1. Basic input validation
    // ────────────────────────────────────────
    if (_discountValue.isEmpty ||
        _discountValue == "0" ||
        _discountValue == "0%" ||
        double.tryParse(_discountValue.replaceAll('%', '').replaceAll("₹", "").trim()) == null) {
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid discount amount"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isDiscountLoading = true);

    try {
      final offlineBox = StorageProvider.offlineOrders;
      final orderHelper = OrderHelper();

      final orderId = orderHelper.activeOrderId;
      if (orderId == null) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("No active order found"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final key = orderId.toString();
      final rawOrder = await offlineBox.get(key);
      if (rawOrder == null) {
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Order data not found"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isDiscountLoading = false);
        return;
      }

      final existingOrder = Map<String, dynamic>.from(rawOrder);

      // ────────────────────────────────────────
      // 2. Prevent multiple discounts (your current rule)
      // ────────────────────────────────────────
      final discounts = (existingOrder["discounts"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (discounts.isNotEmpty) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("A discount is already applied to this order."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ────────────────────────────────────────
      // 3. Find discount product
      // ────────────────────────────────────────
      final discountProduct = await _getDiscountProductFromIsar();

      if (discountProduct == null) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Discount product not found in catalog"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print("🟢 Discount product found → ${discountProduct['name'] ?? 'Discount'}");

      // ────────────────────────────────────────
      // 4. Calculate current gross total (before discount)
      // ────────────────────────────────────────
      final products = (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (products.isEmpty) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cannot apply discount on an empty order"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      double grossTotal = 0.0;
      for (var p in products) {
        final price = double.tryParse(p["price"]?.toString() ?? '0') ?? 0.0;
        final qty = int.tryParse(p["quantity"]?.toString() ?? '1') ?? 1;
        grossTotal += price * qty;
      }

      print("Current gross total before discount: ₹${grossTotal.toStringAsFixed(2)}");

      // ────────────────────────────────────────
      // 5. Parse discount value
      // ────────────────────────────────────────
      String parsedValue = _discountValue
          .replaceAll('%', '')
          .replaceAll(TextConstants.currencySymbol, '')
          .replaceAll("₹", "")
          .trim();

      double inputValue = double.parse(parsedValue);
      bool isPercentage = _isPercentageSelected;

      double discountAmount = isPercentage
          ? (inputValue / 100) * grossTotal
          : inputValue;

      if (discountAmount > grossTotal) {
        setState(() => _isDiscountLoading = false);
        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Discount cannot exceed the current order total"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ────────────────────────────────────────
      // 6. Create discount line item (for order panel / receipt)
      // ────────────────────────────────────────
      final discountEntry = {
        "order_id": orderId,
        "discount_product_id": discountProduct["product_id"] ??
            discountProduct["id"] ??
            discountProduct["fast_key_product_id"],
        "name": discountProduct["fast_key_item_name"] ?? "Merchant Discount",
        "product_image": discountProduct["fast_key_item_image"] ?? "",
        "discount_amount": -discountAmount,       // negative for accounting
        "display_amount": discountAmount,         // positive for display
        "discount_type": isPercentage ? "percentage" : "fixed",
        "discount_percentage": isPercentage ? inputValue : 0.0,
        "original_input": _discountValue,
        AppDBConst.itemName: "Merchant Discount",
        AppDBConst.itemType: "discount",
        AppDBConst.itemPrice: discountAmount.abs(),
        AppDBConst.itemSumPrice: discountAmount.abs(),
        AppDBConst.itemCount: 1,
        "timestamp": DateTime.now().toIso8601String(),
      };

      discounts.add(discountEntry);

      // ────────────────────────────────────────
      // 7. Save updated order with better fields for future recalculation
      // ────────────────────────────────────────
      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "discounts": discounts,
        "gross_total": grossTotal,
        "net_total": grossTotal - discountAmount,
        "net_payable": grossTotal - discountAmount,

        // ──────── Fields for dynamic recalculation ────────
        "merchantDiscount": discountAmount,                    // current calculated value
        "merchantDiscountType": isPercentage ? "percentage" : "fixed",
        "merchantDiscountPercentage": isPercentage ? inputValue : 0.0,
        "merchantDiscountFixed": isPercentage ? 0.0 : discountAmount,
        "merchantDiscountBaseGross": grossTotal,               // snapshot of total when applied
        "merchantDiscountIds": [
          discountProduct["product_id"] ??
              discountProduct["id"] ??
              discountProduct["fast_key_product_id"]
        ],
      };

      await offlineBox.put(key, updatedOrder);

      print("💾 Discount saved successfully");
      print("   • Type:        ${updatedOrder['merchantDiscountType']}");
      print("   • Percentage:  ${updatedOrder['merchantDiscountPercentage']}%");
      print("   • Fixed:       ₹${updatedOrder['merchantDiscountFixed']}");
      print("   • Current amt: ₹${updatedOrder['merchantDiscount']?.toStringAsFixed(2)}");

      // ────────────────────────────────────────
      // 8. UI feedback & cleanup
      // ────────────────────────────────────────
      setState(() {
        _discountValue = isPercentage ? "0%" : "0.00";
        _isDiscountLoading = false;
      });

      await _orderHelper.loadData();
      await _loadOrderData();
      widget.refreshOrderList?.call();

      print(" [DISCOUNT] DONE ---- _handleAddDiscount() ----");

    } catch (e, stack) {
      print("🟥 [DISCOUNT] ERROR: $e");
      print("Stack trace: $stack");
      setState(() => _isDiscountLoading = false);

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        SnackBar(
          content: Text("Error applying discount: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      final offlineBox = StorageProvider.offlineOrders;
      final productBox = StorageProvider.productCache;
      final cashbackAmount = double.parse(_cashbackAmount);
      // 🔥 MAX CASHBACK VALIDATION
      if (_maxCashbackLimit > 0 && cashbackAmount > _maxCashbackLimit) {
        setState(() => _isCashbackLoading = false);

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          SnackBar(
            content: Text(
              "Cashback cannot exceed ${TextConstants.currencySymbol}${_maxCashbackLimit.toStringAsFixed(2)}",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return; // ❗ STOP here → Do NOT add cashback
      }

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
      final rawKey = await offlineBox.get(key);
      final existingOrder =
      Map<String, dynamic>.from(rawKey is Map ? rawKey : {});

      // -------------------------------------------------------
// 🚫 STOP Cashback if order panel has EBT eligible product
// -------------------------------------------------------
      final List<Map<String, dynamic>> existingProducts =
      (existingOrder["products"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      bool hasEbtProduct = existingProducts.any((p) {
        return p["is_ebt_eligible"] == true;
      });

      if (hasEbtProduct) {
        setState(() => _isCashbackLoading = false);

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Cashback is not allowed when EBT products are in the order."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );

        return; // ❗ STOP here — Do NOT add cashback
      }


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
      final cashbackProduct = await _getCashbackProductFromIsar();

      if (cashbackProduct == null) {
        throw "Dynamic cashback product not found in Isar cache!";
      }

      print("🟢 FOUND CASHBACK PRODUCT → $cashbackProduct");

      // -------------------------------------------------------
      // 🟢 UNIVERSAL PRODUCT SEARCH FOR "Cashback"
      // -------------------------------------------------------
      // Map<String, dynamic>? cashbackProduct;
      //
      // for (final k in productBox.keys) {
      //   final data = productBox.get(k);
      //
      //   if (data == null) continue;
      //
      //   // Case A: Direct product map (YOUR MAIN storage)
      //   if (data is Map) {
      //     final name = (data["fast_key_item_name"] ??
      //         data["name"] ??
      //         "").toString().toLowerCase();
      //
      //     if (name.contains("cashback")) {
      //       cashbackProduct = Map<String, dynamic>.from(data);
      //       break;
      //     }
      //   }
      //
      //   // Case B: { "products": [ ... ] } format
      //   if (data is Map && data.containsKey("products")) {
      //     final list = data["products"];
      //     if (list is List) {
      //       for (final item in list) {
      //         final name = (item["fast_key_item_name"] ??
      //             item["name"] ??
      //             "").toString().toLowerCase();
      //
      //         if (name.contains("cashback")) {
      //           cashbackProduct = Map<String, dynamic>.from(item);
      //           break;
      //         }
      //       }
      //     }
      //   }
      //
      //   // Case C: { "data": [...] } format
      //   if (data is Map && data.containsKey("data")) {
      //     final list = json.decode(data["data"]);
      //     if (list is List) {
      //       for (final item in list) {
      //         final name = (item["fast_key_item_name"] ??
      //             item["name"] ??
      //             "").toString().toLowerCase();
      //
      //         if (name.contains("cashback")) {
      //           cashbackProduct = Map<String, dynamic>.from(item);
      //           break;
      //         }
      //       }
      //     }
      //   }
      //
      //   if (cashbackProduct != null) break;
      // }
      //
      // if (cashbackProduct == null) {
      //   throw "Dynamic cashback product not found in productCache!";
      // }
      //
      // print("🟢 FOUND CASHBACK PRODUCT → $cashbackProduct");



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
      // 1️⃣ Calculate cashback fee from config
      final double fee = await CashbackHelper.getCashbackFee(cashbackAmount);

      print("💰 CashbackAmount = $cashbackAmount → Fee = $fee");

      final updatedOrder = {
        ...existingOrder,
        "products": products,
        "cashbacks": cashbacks,

        // 2️⃣ Cashback reduces total, fee increases total
        "gross_total": productsTotal + cashbackAmount ,

        // 3️⃣ Store cashback fee (NOT cashbackAmount)
        "cashbackFee": fee,
        AppDBConst.orderCashbackFee: fee,
      };


      await offlineBox.put(key, updatedOrder);
      print("🟩 SAVED ORDER → $updatedOrder");

      final extrasBox = StorageProvider.orderExtras;

// 🔒 NEVER overwrite an existing cashback
      final existingExtras = await extrasBox.get(orderId.toString());

      final double finalCashbackFee =
      existingExtras != null && existingExtras['cashback_fee'] != null
          ? (existingExtras['cashback_fee'] as num).toDouble()
          : fee;

      await extrasBox.put(orderId.toString(), {
        "local_order_id": orderId,
        "cashback_fee": finalCashbackFee,
        "cashback_amount": cashbackAmount, // optional, useful for audit
        "source": "cashback_payout",
        "saved_at": DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print("""
💾 [orderExtras] Cashback SAVED DIRECTLY
  Local Order ID : $orderId
  Cashback Amt  : $cashbackAmount
  Cashback Fee  : $finalCashbackFee
""");
      }


      // -------------------------------------------------------
      // ✔ UI feedback
      // -------------------------------------------------------
      // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //   SnackBar(
      //     content: Text("Cashback ₹${cashbackAmount.toStringAsFixed(2)} applied"),
      //     backgroundColor: Colors.green,
      //   ),
      // );

      setState(() {
        _cashbackAmount = "";
        _isCashbackLoading = false;
      });

      await _orderHelper.loadData();
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

    final orderHelper = OrderHelper();

    final int? ensuredOrderId = await orderHelper.ensureOrderExists();

    if (ensuredOrderId == null) {
      if (kDebugMode) {
        print("❌ Failed to create or restore order");
      }

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("Unable to create order. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (kDebugMode) {
      print("🆔 Active Order ID (ensured): $ensuredOrderId");
    }

    if (kDebugMode) print("🟢 [STEP 0] ENTER _handleAddCustomItem()");

    // -----------------------------
    // VALIDATION
    // -----------------------------
    if (kDebugMode) {
      print("🟢 [STEP 1] VALIDATION INPUTS:");
      print("     • Name:        '$_customItemName'");
      print("     • Price:       '$_customItemPrice'");
      print("     • Tax Slab:    '$_selectedTaxSlab'");
      print("     • SKU:         '$_sku'");
    }

    if (_customItemName.isEmpty) {
      if (kDebugMode) print("❌ [STEP 1A] Name is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.itemNameRequired),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_customItemPrice.isEmpty ||
        double.tryParse(_customItemPrice) == null ||
        double.parse(_customItemPrice) == 0) {
      if (kDebugMode) {
        print("❌ [STEP 1B] Invalid price: '$_customItemPrice'");
      }
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.invalidPriceError),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedTaxSlab.isEmpty) {
      if (kDebugMode) print("❌ [STEP 1C] Tax slab is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.taxSlabRequired),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_sku.isEmpty) {
      if (kDebugMode) print("❌ [STEP 1D] SKU is empty");
      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.skuRequired),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (kDebugMode) print("✅ [STEP 1] VALIDATION PASSED");

    setState(() => _isCustomItemLoading = true);

    try {
      // -----------------------------
      // PREP ORDER
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 2] PREP ORDER");

      final orderHelper = OrderHelper();
      final int serverOrderId = ensuredOrderId;
      orderHelper.activeOrderId = serverOrderId;


      if (kDebugMode) {
        print("   • Existing activeOrderId: ${orderHelper.activeOrderId}");
        print("   • Using serverOrderId:    $serverOrderId");
      }

      orderHelper.activeOrderId ??= serverOrderId;

      final box = StorageProvider.offlineOrders;
      final orderKey = serverOrderId.toString();

      if (!(await box.containsKey(orderKey))) {
        if (kDebugMode) {
          print("   • No existing offline order for $orderKey, creating new...");
        }
        await box.put(orderKey, {
          "order_id": serverOrderId,
          "created_at": DateTime.now().toIso8601String(),
          "products": [],
          "payouts": [],
          "cashbacks": [],
          "orderAgeRestricted": false,
        });
      } else {
        if (kDebugMode) {
          print("   • Found existing offline order for $orderKey");
        }
      }

      final rawOrder = await box.get(orderKey);
      if (kDebugMode) {
        print("   • rawOrder from Hive: $rawOrder");
      }

      final Map<String, dynamic> orderData =
      Map<String, dynamic>.from(_convertToJsonSafe(rawOrder));

      final List products = (orderData["products"] ?? [])
          .map((e) => Map<String, dynamic>.from(_convertToJsonSafe(e)))
          .toList();

      if (kDebugMode) {
        print("   • Current products count: ${products.length}");
        for (var p in products) {
          print("     - Product in order: sku=${p['sku']}, qty=${p['quantity']}");
        }
      }

      // -----------------------------
// TAX TAB SELECTION VALIDATION
// -----------------------------
      if (_selectedTax == null) {
        if (kDebugMode) {
          print("❌ [STEP 1E] Tax tab not selected");
        }

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Please select a tax slab before adding the item"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }


      // -----------------------------
      // TAX SLAB
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 3] TAX SLAB LOOKUP");

      final taxes = await _assetDBHelper.getTaxList();
      if (kDebugMode) {
        print("   • Available taxes (${taxes.length}): "
            "${taxes.map((t) => '${t.name}(${t.slug})').join(', ')}");
        print("   • Selected tax slab: $_selectedTaxSlab");
      }


      // if (_selectedTaxSlab.isNotEmpty) {
      //   final selectedTax = taxes.firstWhere(
      //         (t) => t.name == _selectedTaxSlab,
      //     orElse: () => taxes.isNotEmpty
      //         ? taxes.first
      //         : Tax(slug: "none", name: _selectedTaxSlab),
      //   );
      //
      //   taxStatus =
      //   selectedTax.slug.isNotEmpty ? TextConstants.taxable : "";
      //   taxClass = selectedTax.slug;
      //
      //   if (kDebugMode) {
      //     print("   • Resolved tax → status: '$taxStatus', class: '$taxClass'");
      //   }
      // }
      // -----------------------------
// TAX FROM API (FIXED)
// -----------------------------
      if (kDebugMode) print("🟡 [STEP 3] TAX FROM API");
      double taxRate = 0.0;
      String taxStatus = "";
      String taxClass = "";

      if (_selectedTax != null) {
        taxStatus = TextConstants.taxable;
        taxClass  = _selectedTax!.taxClass; // ✅ FROM API
        taxRate   = _selectedTax!.rate;     // ✅ FROM API
      }

      if (kDebugMode) {
        print("   • Tax Status : $taxStatus");
        print("   • Tax Class  : $taxClass");
        print("   • Tax Rate   : $taxRate%");
      }



      // -----------------------------
      // NORMALIZE SKU
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 4] NORMALIZE SKU");

      final normalizedSku = normalizeSku(_sku);
      if (kDebugMode) {
        print("   • Original SKU:  '${_sku}'");
        print("   • Normalized:    '$normalizedSku'");
      }

      // -----------------------------
      // CHECK IN EXISTING ORDER
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 5] CHECK EXISTING PRODUCT IN ORDER");

      final existingIndex = products.indexWhere((item) {
        final raw = (item["sku"] ?? "").toString();
        final stored = normalizeSku(raw);
        return stored == normalizedSku ||
            raw == normalizedSku ||
            raw.toLowerCase() == normalizedSku ||
            raw.trim() == normalizedSku ||
            raw.replaceAll(" ", "") == normalizedSku;
      });

      if (kDebugMode) {
        print("   • existingIndex: $existingIndex");
      }

      if (existingIndex != -1) {
        final oldQty = (products[existingIndex]["quantity"] ?? 1);
        products[existingIndex]["quantity"] = oldQty + 1;

        if (kDebugMode) {
          print(
              "🔁 [STEP 5A] Increased quantity of '$normalizedSku' from $oldQty to ${products[existingIndex]["quantity"]}");
        }
      } else {
        if (kDebugMode) print("🆕 [STEP 5B] Creating NEW custom item");

        final customItem = {
          "server_item_id": null,
          // "product_id": normalizedSku.hashCode,
          // "variation_id": -1,
          "type": "custom",
          "name": _customItemName.trim(),
          "price": double.parse(_customItemPrice),
          "sku": normalizedSku,

          // ✅ TAX (API BASED)
          "tax_status": taxStatus,
          "tax_class": taxClass,
          "tax_rate": taxRate,
          "tags": [TextConstants.customItem],
          "quantity": 1,
          /// 🔥 FIXED IMAGE KEYS → MUST MATCH YOUR ORDER PANEL UI
          AppDBConst.itemImage: "assets/custom.png",
          "item_image": "assets/custom.png",
          "product_image": "assets/custom.png",

          AppDBConst.itemType: TextConstants.customItemText,
        };

        products.add(customItem);

        if (kDebugMode) {
          print("   • Added new custom item:");
          print("       name: ${customItem['name']}");
          print("       price: ${customItem['price']}");
          print("       sku: ${customItem['sku']}");
        }
      }

      // -----------------------------
      // SAVE ORDER BACK
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 6] SAVE ORDER BACK TO HIVE");

      orderData["products"] = products;
      await box.put(orderKey, orderData);

      if (kDebugMode) {
        final debugOrder = await box.get(orderKey);
        print("   • Saved order snapshot: $debugOrder");
      }

      // -----------------------------
      // CACHE IN productCache
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 7] UPDATE productCache");

      final productBox = StorageProvider.productCache;
      final cacheKey = "sku_$normalizedSku";
      final cacheItem = {
        // "id": normalizedSku.hashCode,
        // "product_id": normalizedSku.hashCode,
        // "variation_id": -1,
        "name": _customItemName.trim(),
        "type": "custom",
        "is_custom_item": true,
        "price": double.parse(_customItemPrice).toString(),
        "sku": normalizedSku,

        // ✅ TAX (API BASED)
        "tax_status": taxStatus,
        "tax_class": taxClass,
        "tax_rate": taxRate,
        "variations": [],

        /// FIXED IMAGE KEYS
        "images": [
          {"src": "assets/custom.png"}
        ],
        AppDBConst.itemImage: "assets/custom.png",
        "item_image": "assets/custom.png",
        "product_image": "assets/custom.png",

        AppDBConst.itemType: TextConstants.customItemText,
      };

      await productBox.put(cacheKey, {"products": [cacheItem]});

      if (kDebugMode) {
        print("   • productCache[$cacheKey] = ${await productBox.get(cacheKey)}");
      }

      // -----------------------------
      // UPDATE IN-MEMORY CACHE
      // -----------------------------
      // -----------------------------
// UPDATE IN-MEMORY CACHE
// -----------------------------
      if (kDebugMode) print("🟡 [STEP 8] UPDATE IN-MEMORY CACHE");

// Save custom item into memory cache
      OrderHelper.addToCache(normalizedSku, cacheItem);

// PRINT EXACT VALUE STORED IN MEMORY CACHE
      if (kDebugMode) {
        final mem = OrderHelper.getFromCache(normalizedSku);

        print("🔥 In-memory cache updated for custom SKU: $normalizedSku");
        print("🧠 [MEMORY] STORED VALUE → $mem");

        try {
          print("🧠 [MEMORY] STORED JSON → ${jsonEncode(mem)}");
        } catch (_) {
          print("⚠ [MEMORY] Could not encode to JSON");
        }
      }

      // -----------------------------
      // RESET UI
      // -----------------------------
      if (kDebugMode) print("🟡 [STEP 9] RESET UI & RELOAD ORDER");

      setState(() {
        _isCustomItemLoading = false;
        _customItemName = "";
        _customItemPrice = "";
        _sku = "";
        _customItemNameController.clear();
        _customItemPriceController.clear();
        _skuController.clear();
        _selectedTaxSlab =
        _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first : "";
      });

      await _orderHelper.loadData();
      await _loadOrderData();
      widget.refreshOrderList?.call();

      if (kDebugMode) print("✅ [STEP 10] Custom item added successfully!");

      ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
        const SnackBar(
          content: Text("✅ Custom item added successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      print("❌ [ERROR] Exception in _handleAddCustomItem: $e");
      print("🧵 StackTrace: $st");

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
  Future<Map<String, dynamic>?> _getPayoutProductFromIsar() async {
    // ⚡ FAST PATH — in-memory cache
    if (_productMetaInitialized && _productMetaCache.isNotEmpty) {
      for (final p in _productMetaCache.values) {
        final name =
        (p["fast_key_item_name"] ?? p["name"] ?? "")
            .toString()
            .toLowerCase();

        if (name.contains("payout")) {
          return p;
        }
      }
    }

    try {
      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys.where().findAll();

      for (final entry in entries) {
        if (!entry.key.startsWith("products_")) continue;

        final List<dynamic> products = jsonDecode(entry.json);
        for (final raw in products) {
          if (raw is! Map) continue;

          final map = Map<String, dynamic>.from(raw);
          final name =
          (map["fast_key_item_name"] ?? map["name"] ?? "")
              .toString()
              .toLowerCase();

          if (name.contains("payout")) {
            final pid = int.tryParse(
                (map["fast_key_product_id"] ?? map["id"])?.toString() ?? "");

            if (pid != null) {
              _productMetaCache[pid] = map;
              _productMetaInitialized = true;
            }
            return map;
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Payout Isar lookup failed → $e");
    }

    return null;
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
      final offlineBox = StorageProvider.offlineOrders;
      final productBox = StorageProvider.productCache;
      final payoutAmount = double.parse(_payoutAmount);

      final orderHelper = OrderHelper();

      final int? ensuredOrderId = await orderHelper.ensureOrderExists();

      if (ensuredOrderId == null) {
        setState(() => _isPayoutLoading = false);

        ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
          const SnackBar(
            content: Text("Unable to create order. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }


      if (kDebugMode) {
        print("🆔 [PAYOUT] Active Order ID (ensured): $ensuredOrderId");
      }
      final int orderId = ensuredOrderId;
      orderHelper.activeOrderId = orderId;

      final key = orderId.toString();
      final rawExisting = await offlineBox.get(key);
      final existingOrder = Map<String, dynamic>.from(rawExisting is Map ? rawExisting : {});

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
      Map<String, dynamic>? payoutProduct =
      await _getPayoutProductFromIsar();

// Fallback only if not found in catalog
      payoutProduct ??= {
        "fast_key_product_id": DateTime.now().millisecondsSinceEpoch,
        "fast_key_item_name": "Payout",
        "fast_key_item_price": 0,
        "fast_key_item_image":
        "https://merchantretail.alektasolutions.com/wp-content/uploads/2025/11/payout-2-1.png",
        "type": "simple",
      };

      print("🟢 FOUND PAYOUT PRODUCT → $payoutProduct");
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

      // ScaffoldMessenger.of(widget.scaffoldMessengerContext).showSnackBar(
      //   SnackBar(
      //     content: Text("Payout of ₹${payoutAmount.toStringAsFixed(2)} added successfully"),
      //     backgroundColor: Colors.green,
      //   ),
      // );

      setState(() {
        _payoutAmount = "";
        _isPayoutLoading = false;
      });

      await _orderHelper.loadData();
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
    double tabHeight = size.height / 550;
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
    if (selectedIndex < 4) {
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