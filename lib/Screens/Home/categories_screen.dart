// import 'package:flutter/foundation.dart';
//
// import '../../Widgets/widget_category_list.dart';
// import '../../Widgets/widget_nested_grid_layout.dart';
// import '../../Widgets/widget_order_panel.dart';
// import '../../Widgets/widget_topbar.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
//
// // Enum for sidebar position
// enum SidebarPosition { left, right, bottom }
// // Enum for order panel position
// enum OrderPanelPosition { left, right }
//
// class CategoriesScreen extends StatefulWidget { // Build #1.0.6 - Updated Horizontal & Vertical Scrolling
//   final int? lastSelectedIndex; // Make it nullable
//
//   const CategoriesScreen({super.key, this.lastSelectedIndex}); // Optional, no default value
//
//
//   @override
//   State<CategoriesScreen> createState() => _CategoriesScreenState();
// }
//
// class _CategoriesScreenState extends State<CategoriesScreen> {
//   final List<String> items = List.generate(18, (index) => 'Bud Light');
//   int _selectedSidebarIndex = 1; //Build #1.0.2 : By default fast key should be selected after login
//   DateTime now = DateTime.now();
//   List<int> quantities = [1, 1, 1, 1];
//   SidebarPosition sidebarPosition = SidebarPosition.left; // Default to bottom sidebar
//   OrderPanelPosition orderPanelPosition = OrderPanelPosition.right; // Default to right
//   bool isLoading = true; // Add a loading state
//   final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null); // Add this
//
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedSidebarIndex = widget.lastSelectedIndex ?? 1; // Build #1.0.7: Restore previous selection
//     // Simulate a loading delay
//     Future.delayed(const Duration(seconds: 3), () {
//       setState(() {
//         isLoading = false; // Set loading to false after 3 seconds
//       });
//     });
//   }
//
//   void _refreshOrderList() { // Build #1.0.10 - Naveen: This will trigger a rebuild of the RightOrderPanel (Callback)
//     setState(() {
//       if (kDebugMode) {
//         print("###### CategoriesScreen _refreshOrderList");
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     String formattedDate = DateFormat("EEE, MMM d' ${now.year}'").format(now);
//     String formattedTime = DateFormat('hh:mm a').format(now);
//
//     return Scaffold(
//       body: Column(
//         children: [
//           // Top Bar
//           TopBar(
//             onModeChanged: () {
//               setState(() {
//                 if (sidebarPosition == SidebarPosition.left) {
//                   sidebarPosition = SidebarPosition.right;
//                 } else if (sidebarPosition == SidebarPosition.right) {
//                   sidebarPosition = SidebarPosition.bottom;
//                 } else {
//                   sidebarPosition = SidebarPosition.left;
//                 }
//               });
//             },
//           ),
//           Divider(
//             color: Colors.grey, // Light grey color
//             thickness: 0.4, // Very thin line
//             height: 1, // Minimal height
//           ),
//           // Main Content
//           Expanded(
//             child: Row(
//               children: [
//                 // Left Sidebar (Conditional)
//                 if (sidebarPosition == SidebarPosition.left)
//                   custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
//                     selectedSidebarIndex: _selectedSidebarIndex,
//                     onSidebarItemSelected: (index) {
//                       setState(() {
//                         _selectedSidebarIndex = index;
//                       });
//                     },
//                     isVertical: true, // Vertical layout for left sidebar
//                   ),
//
//                 // Order Panel on the Left (Conditional: Only when sidebar is right or bottom with left order panel)
//                 if (sidebarPosition == SidebarPosition.right ||
//                     (sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
//                   RightOrderPanel(
//                     formattedDate: formattedDate,
//                     formattedTime: formattedTime,
//                     quantities: quantities,
//                     refreshOrderList: _refreshOrderList, // Pass the callback
//                   ),
//
//                 // Main Content (Horizontal Scroll and Grid View)
//                 Expanded(
//                   child: Column(
//                     children: [
//                       CategoryList(isHorizontal: true, isLoading: isLoading, isAddButtonEnabled: false, fastKeyTabIdNotifier: fastKeyTabIdNotifier),
//                       // Grid Layout
//                       ValueListenableBuilder<int?>( // Build #1.0.11
//                         valueListenable: fastKeyTabIdNotifier,
//                         builder: (context, fastKeyTabId, child) {
//                           return NestedGridWidget(
//                             isHorizontal: true,
//                             isLoading: isLoading,
//                             onItemAdded: _refreshOrderList,
//                             fastKeyTabIdNotifier: fastKeyTabIdNotifier,
//                             showAddButton: false, // Build #1.0.12: This will hide the add button in CategoriesScreen
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Order Panel on the Right (Conditional: Only when sidebar is left or bottom with right order panel)
//                 if (sidebarPosition != SidebarPosition.right &&
//                     !(sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
//                   RightOrderPanel(
//                     formattedDate: formattedDate,
//                     formattedTime: formattedTime,
//                     quantities: quantities,
//                     refreshOrderList: _refreshOrderList, // Pass the callback
//                   ),
//
//                 // Right Sidebar (Conditional)
//                 if (sidebarPosition == SidebarPosition.right)
//                   custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
//                     selectedSidebarIndex: _selectedSidebarIndex,
//                     onSidebarItemSelected: (index) {
//                       setState(() {
//                         _selectedSidebarIndex = index;
//                       });
//                     },
//                     isVertical: true, // Vertical layout for right sidebar
//                   ),
//               ],
//             ),
//           ),
//
//           // Bottom Sidebar (Conditional)
//           if (sidebarPosition == SidebarPosition.bottom)
//             custom_widgets.NavigationBar( //Build #1.0.4 : Updated class name LeftSidebar to NavigationBar
//               selectedSidebarIndex: _selectedSidebarIndex,
//               onSidebarItemSelected: (index) {
//                 setState(() {
//                   _selectedSidebarIndex = index;
//                 });
//               },
//               isVertical: false, // Horizontal layout for bottom sidebar
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Utilities/global_utility.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
import '../../Widgets/widget_logs_toast.dart';
import '../../Widgets/widget_category_list.dart';
import '../../Widgets/widget_nested_grid_layout.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_sub_category.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Blocs/Category/category_bloc.dart';
import '../../Repositories/Category/category_repository.dart';
import '../../Helper/api_response.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Constants/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/login_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final int? lastSelectedIndex;

  const CategoriesScreen({super.key, this.lastSelectedIndex});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with WidgetsBindingObserver, LayoutSelectionMixin{
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 1;
  List<int> quantities = [1, 1, 1, 1];
  // SidebarPosition sidebarPosition = SidebarPosition.left;
  // OrderPanelPosition orderPanelPosition = OrderPanelPosition.right;
  bool isLoading = true;
  bool isAddingItemLoading = false; // Loader for adding items to order
  bool isLoadingNestedContent = false; //Build #1.0.34: added for shimmer effect issue
  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null);
  final OrderHelper orderHelper = OrderHelper();
  final productBloc = ProductBloc(ProductRepository());
  final PinakaPreferences _preferences = PinakaPreferences(); // Add this

  late CategoryBloc _categoryBloc;
  List<CategoryModel> categories = []; // Build #1.0.27 : Top-level categories only
  List<CategoryModel> subCategories = []; // Build #1.0.27 : Subcategories for the selected category
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
  int? _selectedSubCategoryIndex;

  List<Map<String, dynamic>> categoryProducts = [];
  int? selectedItemIndex;
  List<int?> reorderedIndices = [];
  List<String> navigationPath = [];
  List<int> categoryHierarchy = [0];
  int currentCategoryLevel = 0;
  String? lastSelectedProduct;
  bool isShowingSubCategories = false;
  StreamSubscription? _updateOrderSubscription;
  late OrderBloc orderBloc;
  int _refreshCounter = 0; //Build #1.0.170: Added: Counter to trigger RightOrderPanel refresh only when needed

  @override
  void initState() {
    super.initState();
    orderBloc = OrderBloc(OrderRepository());
    WidgetsBinding.instance.addObserver(this);
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 1;
    _categoryBloc = CategoryBloc(CategoryRepository());
    reorderedIndices = List.filled(categoryProducts.length, null);

    _loadTopLevelCategories(); // Build #1.0.27 : Load top-level categories once
    // Add delay to check shimmer effect
    // Future.delayed(const Duration(seconds: 3), () {
    //   setState(() {
    //     isLoading = false;
    //   });
    // });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _loadLastSelectedCategory will be called after _loadTopLevelCategories
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLastSelectedCategory();
    }
  }

  Future<void> _loadLastSelectedCategory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastSelectedIndex = prefs.getInt('lastSelectedCategoryIndex');

    if (lastSelectedIndex != null && lastSelectedIndex >= 0 && lastSelectedIndex < categories.length) {
      setState(() {
        _selectedCategoryIndex = lastSelectedIndex;
        // Start with just the category name
        navigationPath = [categories[_selectedCategoryIndex!].name];
        categoryHierarchy = [0, categories[_selectedCategoryIndex!].id];
        currentCategoryLevel = 1;
        isShowingSubCategories = true;
      });
      await _loadSubCategories(categories[_selectedCategoryIndex!].id); // Build #1.0.166: added await to complete
    } else if (categories.isNotEmpty) {
      setState(() {
        _selectedCategoryIndex = 0;
        // Start with just the category name
        navigationPath = [categories[0].name];
        categoryHierarchy = [0, categories[0].id];
        currentCategoryLevel = 1;
        isShowingSubCategories = true;
      });
      await prefs.setInt('lastSelectedCategoryIndex', 0);
      await _loadSubCategories(categories[0].id); // Build #1.0.166: added await to complete
    }
  }

  Future<void> _saveLastSelectedCategory(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSelectedCategoryIndex', index);
  }

  // Load top-level categories (parentId = 0) once
  Future<void> _loadTopLevelCategories() async { // Build #1.0.27
    setState(() {
      isLoadingNestedContent = true; //Build #1.0.126: Added this line to show shimmer from starting
    });
    _categoryBloc.fetchCategories(0);
    await for (var response in _categoryBloc.categoriesStream) {
      if (response.status == Status.COMPLETED && response.data != null) {
        setState(() {
          categories = response.data!.categories;
          isLoading = false;
        });
        // After loading categories, apply the last selected category
        // Build #1.0.166: Only after top categories are loaded, load last selected
        if (categories.isNotEmpty) {
          await _loadLastSelectedCategory();
        }
        break; // Break after loading top-level categories
      } else if (response.status == Status.ERROR) {
        //Build #1.0.179
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Unauthorised : response.message ${response.message!}");
          }
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unauthorised. Session is expired on this device."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        if (kDebugMode) {
          print("CategoriesScreen: Error loading top-level categories: ${response.message}");
        }
      }
    }
  }

  // Load subcategories for a specific parent category
  Future<void> _loadSubCategories(int parentId) async {
    // setState(() {
    //   isLoadingNestedContent = true; // no need from here above _loadTopLevelCategories added
    // });
    _categoryBloc.fetchCategories(parentId);
    await for (var response in _categoryBloc.categoriesStream) {
      if (response.status == Status.COMPLETED && response.data != null) {
        if (kDebugMode) {
          print("#### DEBUG 200: ${response.data!.categories.length}");
        }
        setState(() {
          subCategories = response.data!.categories;
          isShowingSubCategories = true;
          categoryProducts.clear();
          _selectedSubCategoryIndex = null;
          isLoadingNestedContent = false; // Hide shimmer when data is loaded
        });
        if(Misc.enableCategoryProductWithSubCategoryList || subCategories.isEmpty){
          _loadProductsByCategory(parentId);
        }
        break; // Break after loading subcategories
      } else if (response.status == Status.ERROR) {
        setState(() {
          isLoadingNestedContent = false; // Hide shimmer on error
        });
        if (kDebugMode) {
          print("CategoriesScreen: Error loading subcategories: ${response.message}");
        }
      }
    }
  }

  Future<void> _loadProductsByCategory(int categoryId) async {
    setState(() {
      isLoadingNestedContent = true;
      categoryProducts.clear(); // Clear existing products to prevent duplicates
    });

    _categoryBloc.fetchProductsByCategory(categoryId);
    await for (var response in _categoryBloc.productsStream) {
      if (response.status == Status.COMPLETED && response.data != null) {
        setState(() {
          // Deduplicate products by id
          final uniqueProducts = <int, Map<String, dynamic>>{};
          for (var product in response.data!.products) {
            var tagg = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => Tags());
            var hasAgeRestriction = tagg?.name?.contains(TextConstants.age_restricted);
            if (kDebugMode) {
              print("CategoriesScreen: _loadProductsByCategory hasAgeRestriction $hasAgeRestriction, minAge: ${tagg?.slug ?? "0"}");
            }
            uniqueProducts[product.id] = {
              'fast_key_product_id': product.id,
              'fast_key_item_name': product.name,
              'fast_key_item_image': product.images.isNotEmpty ? product.images.first : '',
              'fast_key_item_price': product.price,
              'fast_key_item_sku': product.sku ?? '', // Ensure SKU
              ///Todo: add minAge in category product item
              'fast_key_item_min_age': int.parse(tagg?.slug ?? "0"),
              'variations': product.variations, // Build #1.0.157: pass variations & type values to nested grid
              'type': product.type,
            };
          }
          categoryProducts = uniqueProducts.values.toList();
          reorderedIndices = List.filled(categoryProducts.length, null);
          isShowingSubCategories = false;
          isLoadingNestedContent = false; // Hide shimmer when data is loaded
        });
        break;
      } else if (response.status == Status.ERROR) {
        setState(() {
          isLoadingNestedContent = false; // Hide shimmer on error
        });
        if (kDebugMode) {
          print("CategoriesScreen: Error loading products: ${response.message}");
        }
      }
    }
  }

  void _onCategoryTapped(int index) {
    // Prevent tapping the same category again
    if (_selectedCategoryIndex == index) { // Build #1.0.254: Fixed - Disable double click on category tabs & fast key tabs
      if (kDebugMode) {
        print("### CategoriesScreen: Same category tapped, ignoring: $index");
      }
      return;
    }
    if (index < 0 || index >= categories.length) return; // Prevent RangeError
    setState(() {
      _selectedCategoryIndex = index;
      // Always show the category name first
      navigationPath = [categories[index].name]; // Reset path with just category name
      subCategories.clear();
      categoryProducts.clear();
      isShowingSubCategories = true;
      categoryHierarchy = [0, categories[index].id]; // Reset hierarchy
      currentCategoryLevel = 1;
      _selectedSubCategoryIndex = null;
      _editingCategoryIndex = null;
      isLoadingNestedContent = true; // Add this line to show shimmer
    });

    _saveLastSelectedCategory(index);
    _loadSubCategories(categories[index].id);
  }

  void _onSubCategoryTapped(int index) { //Build #1.0.34: updated code for navigation path issues
    if (index < 0 || index >= subCategories.length) return;

    final selectedSubCategory = subCategories[index];

    setState(() {
      _selectedSubCategoryIndex = index;
      // Only add to navigation path if moving to a new subcategory level
      if (currentCategoryLevel < categoryHierarchy.length) {
        navigationPath = navigationPath.sublist(0, currentCategoryLevel);
        categoryHierarchy = categoryHierarchy.sublist(0, currentCategoryLevel + 1);
      }
      navigationPath.add(selectedSubCategory.name);
      categoryHierarchy.add(selectedSubCategory.id);
      currentCategoryLevel++;
      isShowingSubCategories = true;
      categoryProducts.clear();
      isLoadingNestedContent = true; // Add this line to show shimmer
    });

    if (kDebugMode) print("_onSubCategoryTapped: currentCategoryLevel -> $currentCategoryLevel");
    if (kDebugMode) print("_onSubCategoryTapped: selectedSubCategory ID -> ${selectedSubCategory.id}"); // DEBUG
    if (kDebugMode) print("_onSubCategoryTapped: subCategories length -> ${subCategories.length}");
    _loadSubCategories(selectedSubCategory.id);
  }

  void _onBackToCategories() {
    if (currentCategoryLevel > 0) {
      setState(() {
        currentCategoryLevel--;
        navigationPath.removeLast();
        categoryHierarchy.removeLast();
        isShowingSubCategories = true;
        categoryProducts.clear();
        _selectedSubCategoryIndex = null;
      });

      if (currentCategoryLevel == 0) {
        _loadSubCategories(categories[_selectedCategoryIndex!].id);
      } else {
        _loadSubCategories(categoryHierarchy.last);
      }
    }
  }

  //Build 1.1.36: Update the products loading to not add to navigation path
  // Explanation:
  // Added sku to OrderLineItem in the API call, using the same placeholder format (SKU${name}) as the original code.
  // Moved database operations to OrderBloc.updateOrderProducts (already updated to handle database updates).
  // Added dbOrderId parameter to updateOrderProducts.
  // Kept local insertion via orderHelper.addItemToOrder for non-API orders.
  // Added isAddingItemLoading to show a loader during API calls.
  // Added alert dialog with retry option for API failures.
  // Added success toasts for both API and local cases.
  // Preserved debug prints, variantAdded logic, and back button functionality.
  Stopwatch? refreshUIStopwatch; // Build #1.0.256
  void _onItemSelected(int index, bool variantAdded) async {
    if (index == 0 && showBackButton) {
      _onBackToCategories();
      return;
    }

    // fix for parent product also adding along with variant product , we have to restrict that like categories screen
    if(variantAdded == true){
      // Build #1.0.148: we have to show loader until product adds into order panel, then hide
      // Navigator.pop(context); // Hide Loader / VariationPopup dialog
      if (!Misc.enableUILogMessages) { // Build #1.0.256
        if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
          Navigator.pop(context);
        }
      }
      _refreshOrderList(); // refresh UI
      return;
    }

    final adjustedIndex = index - (showBackButton ? 1 : 0);
    if (adjustedIndex < 0 || adjustedIndex >= categoryProducts.length) return;

    /// Build #1.0.108: No need if condition same as fast key screen _onItemSelected
    // if (!variantAdded) { //Build 1.1.36
    // Only add the base product if no variant was added
    final selectedProduct = categoryProducts[adjustedIndex];
    ///Comment below code not we are using only server order id as to check orders, skip checking db order id
    // final order = orderHelper.orders.firstWhere(
    //       (order) => order[AppDBConst.orderId] == orderHelper.activeOrderId,
    //   orElse: () => {},
    // );
    final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
    final dbOrderId = orderHelper.activeOrderId;
    ///Build #1.0.128: No need to check this condition
    // if (dbOrderId == null) { //Build #1.0.78
    //   if (kDebugMode) print("No active order selected");
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text("No active order selected"),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 2),
    //     ),
    //   );
    //   return;
    // }

    try {
      // if (serverOrderId != null) { //Build #1.0.78: if server id is available use API call and save to db else save to db
      _updateOrderSubscription?.cancel();
      StreamSubscription? subscription;
      // Build #1.0.256: Measure time for Add Product to Order (for non-variant or empty variations)
      Stopwatch? addProductStopwatch;
      if (Misc.enableUILogMessages) {
        addProductStopwatch = Stopwatch()..start();
      }
      subscription = orderBloc.updateOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        //  setState(() => isAddingItemLoading = false);
        if (response.status == Status.LOADING) { // Build #1.0.80
          const Center(child: CircularProgressIndicator());
        }else if (response.status == Status.COMPLETED) {
          // Build #1.0.148: we have to show loader until product adds into order panel, then hide
          // Navigator.pop(context); // Hide Loader / VariationPopup dialog
          if (!Misc.enableUILogMessages){ // Build #1.0.256
            if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
              Navigator.pop(context);
            }
          }
          if (kDebugMode) print("Item added to order $dbOrderId via API");
          if (Misc.showDebugSnackBar) { // Build #1.0.254
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Item '${selectedProduct[AppDBConst.fastKeyItemName]}' added to order"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Build #1.0.256: Store logs and display on toast for testing
          if (Misc.enableUILogMessages && addProductStopwatch != null) {
            addProductStopwatch.stop();
            globalProcessSteps.add(
              ProcessStep(
                name: TextConstants.addProductToOrder,
                timeTaken: addProductStopwatch.elapsedMilliseconds / 1000.0,
              ),
            );
            if (kDebugMode) {
              print("Add Product to Order completed in ${globalProcessSteps.last.timeTaken}s");
            }
          }

          if (Misc.enableUILogMessages) {
            refreshUIStopwatch = Stopwatch()..start();
          }
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
            Navigator.pop(context);
          }
          if (kDebugMode) print("Failed to add item to order: ${response.message}");
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(response.message ?? TextConstants.failedToAddItemToOrder), // Build #1.0.144
          //     backgroundColor: Colors.red,
          //     duration: const Duration(seconds: 2),
          //   ),
          // );
          // Build #1.0.256: Stop stopwatch and add to steps only if enabled
          if (Misc.enableUILogMessages && addProductStopwatch != null) {
            addProductStopwatch.stop();
            // Clear global steps when toast is closed
            globalProcessSteps.clear();
            // globalProcessSteps.add(
            //   ProcessStep(
            //     name: TextConstants.addProductToOrder,
            //     timeTaken: addProductStopwatch.elapsedMilliseconds / 1000.0,
            //   ),
            // );
          }
          _refreshOrderList();
          subscription?.cancel();
        }
      });

      await orderBloc.updateOrderProducts(
        orderId: serverOrderId,
        dbOrderId: dbOrderId,
        lineItems: [
          OrderLineItem(
            productId: selectedProduct[AppDBConst.fastKeyProductId],
            quantity: 1,
          ),
        ],
      );
      // } else { ///Build #1.0.128: No need
      //   // await orderHelper.addItemToOrder(
      //   //   selectedProduct[AppDBConst.fastKeyProductId],
      //   //   selectedProduct[AppDBConst.fastKeyItemName],
      //   //   selectedProduct[AppDBConst.fastKeyItemImage],
      //   //   double.tryParse(selectedProduct[AppDBConst.fastKeyItemPrice].toString()) ?? 0.0,
      //   //   1,
      //   //   selectedProduct[AppDBConst.fastKeyItemSKU],
      //   //   onItemAdded: _refreshOrderList,
      //   // );
      // //  setState(() => isAddingItemLoading = false);
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text("Item '${selectedProduct[AppDBConst.fastKeyItemName]}' did not added to order. OrderId not found."),
      //       backgroundColor: Colors.green,
      //       duration: const Duration(seconds: 2),
      //     ),
      //   );
      //   _refreshOrderList();
      // }
    } catch (e) {
      if (kDebugMode) print("Exception in _onItemSelected: $e");
      // setState(() => isAddingItemLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextConstants.errorAddingItem), // Build #1.0.144
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      _updateOrderSubscription?.cancel(); // Build #1.0.108: Ensure cleanup
      _updateOrderSubscription = null;
    }
    // } else {
    //   // If a variant was added, just refresh the UI
    //   _refreshOrderList();
    // }
  }

  void _onNavigationPathTapped(int index) { //Build #1.0.34: fixed code for navigation path issues
    if (index < 0 || index >= navigationPath.length) return;

    // Don't reload if tapping the currently active path item
    if (index == currentCategoryLevel - 1) return;

    setState(() {
      // Truncate path and hierarchy to clicked level
      navigationPath = navigationPath.sublist(0, index + 1);
      categoryHierarchy = categoryHierarchy.sublist(0, index + 2);
      currentCategoryLevel = index + 1;
      isShowingSubCategories = true;
      categoryProducts.clear();
      _selectedSubCategoryIndex = null;
    });

    // Load appropriate subcategories
    if (index == 0) {
      _loadSubCategories(categories[_selectedCategoryIndex!].id);
    } else {
      _loadSubCategories(categoryHierarchy.last);
    }
  }

  void _refreshOrderList() {
    setState(() {
      if (kDebugMode) {
        print("##### _refreshOrderList: Incrementing _refreshCounter to $_refreshCounter to trigger RightOrderPanel refresh");
      }
      _refreshCounter++; //Build #1.0.170: Increment to signal refresh, causing didUpdateWidget to load with loader
    });
    // Build #1.0.256: Stop stopwatch and add to steps only if enabled
    if (Misc.enableUILogMessages && refreshUIStopwatch != null) {
      refreshUIStopwatch?.stop();
      globalProcessSteps.add(
        ProcessStep(
          name: TextConstants.refreshDBUITime,
          timeTaken: refreshUIStopwatch!.elapsedMilliseconds / 1000.0,
        ),
      );
      if (kDebugMode) {
        print("Add Product to Order completed in ${globalProcessSteps.last.timeTaken}s");
      }
    }
    /// Show Toast
    if (Misc.enableUILogMessages && globalProcessSteps.isNotEmpty) {
      if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
        Navigator.pop(context);
      }
      if (kDebugMode) {
        print("VariationPopup - Showing toast with process timings: ${globalProcessSteps.map((s) => '${s.name}: ${s.timeTaken}s').toList()}");
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return LogsToast(
            steps: globalProcessSteps,
            onClose: () {
              if (kDebugMode) {
                print("VariationPopup - Toast closed by user");
              }
              // Clear global steps when toast is closed
              globalProcessSteps.clear();
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    }
  }

  // bool get showBackButton => categoryProducts.isNotEmpty;
  // Build #1.0.197: Fixed [SCRUM - 341] -> Unnecessary "Back to Categories" Button
  /// user is at least one level deep in the category hierarchy (e.g., inside a subcategory or deeper).
  bool get showBackButton => currentCategoryLevel >= 2;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _categoryBloc.dispose();
    orderBloc.dispose(); // Build 1.0.171
    fastKeyTabIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryListItems = categories.map((category) {
      return {
        'title': category.name,
        'image': category.image ?? 'assets/default.png',
        'itemCount': category.count,
      };
    }).toList();

    final subCategoryListItems = subCategories.map((subCategory) {
      return {
        'name': subCategory.name,
        'image': subCategory.image ?? 'assets/default.png',
        'count': subCategory.count,
      };
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          //Build #1.0.78: Explanation!
          // Added sku to OrderLineItem in the API call, using product.sku with a fallback to SKU${product.name}.
          // Moved database operations to OrderBloc.updateOrderProducts.
          // Added dbOrderId parameter to updateOrderProducts.
          // Kept local insertion for non-API orders.
          // Added isAddingItemLoading to show a loader.
          // Added success toasts for both API and local cases.
          // Preserved debug prints and layout change logic.
          TopBar(
            screen: Screen.CATEGORY,
            onModeChanged: () async{ /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
                newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
              }

              //Build #1.0.54: Update the notifier which will trigger _onLayoutChanged
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              // No need to call saveLayoutSelection here as it's handled in the notifier
              // _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
              // update UI
              setState(() {});
            },
            onProductSelected: (product) async {
              double price;
              try {
                price = double.tryParse(product.price ?? '0.00') ?? 0.00;
              } catch (e) {
                price = 0.00;
              }
              ///Comment below code not we are using only server order id as to check orders, skip checking db order id
              // final order = orderHelper.orders.firstWhere(
              //       (order) => order[AppDBConst.orderId] == orderHelper.activeOrderId,
              //   orElse: () => {},
              // );
              final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
              final dbOrderId = orderHelper.activeOrderId;
              ///Build #1.0.128: No need to check this condition
              // if (dbOrderId == null) {
              //   if (kDebugMode) print("No active order selected");
              //   ScaffoldMessenger.of(context).showSnackBar(
              //     const SnackBar(
              //       content: Text("No active order selected"),
              //       backgroundColor: Colors.red,
              //       duration: Duration(seconds: 2),
              //     ),
              //   );
              //   return;
              // }

              try {
                // if (serverOrderId != null) {  ///Build #1.0.128: No need
                if (kDebugMode) {
                  print("###### serverOrderId: $serverOrderId");
                }
                _refreshOrderList(); // Build #1.0.80: Fix: refresh the order items in order panel after search item selected
                // } else {
                //   // await orderHelper.addItemToOrder(
                //   //   product.id,
                //   //   product.name ?? 'Unknown',
                //   //   product.images?.isNotEmpty == true ? product.images!.first : '',
                //   //   price,
                //   //   1,
                //   //   product.sku ?? '',
                //   //   onItemAdded: _refreshOrderList,
                //   // );
                // //  setState(() => isAddingItemLoading = false);
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(
                //       content: Text("Item '${product.name}' did not added to order. OrderId not found."),
                //       backgroundColor: Colors.green,
                //       duration: const Duration(seconds: 2),
                //     ),
                //   );
                //   _refreshOrderList();
                // }
              } catch (e, s) {
                if (kDebugMode) print("Exception in onProductSelected: $e, Stack: $s");
                //  setState(() => isAddingItemLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(TextConstants.errorAddingItem), // Build #1.0.144
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const Divider(
            color: Colors.grey,
            thickness: 0.4,
            height: 1,
          ),
          Expanded(
            child: Row(
              children: [
                if (sidebarPosition == SidebarPosition.left)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) {
                      setState(() {
                        _selectedSidebarIndex = index;
                      });
                    },
                    isVertical: true,
                  ),
                if (sidebarPosition == SidebarPosition.right ||
                    (sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey: _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
                  ),
                Expanded(
                  child: Column(
                    children: [
                      // Always show the CategoryList
                      CategoryList(
                        isHorizontal: true,
                        isLoading: isLoading,
                        isAddButtonEnabled: false,
                        categories: categoryListItems,
                        selectedIndex: _selectedCategoryIndex,
                        editingIndex: _editingCategoryIndex,
                        onAddButtonPressed: null,
                        onCategoryTapped: _onCategoryTapped,
                        // In CategoriesScreen.dart, update the onReorder callback in the CategoryList widget
                        onReorder: (oldIndex, newIndex) { //Build 1.1.36: code updated
                          if (kDebugMode) {
                            print("### CategoriesScreen: Reordering category from index $oldIndex to $newIndex");
                          }
                          setState(() {
                            // Create a copy of categories to ensure proper reordering
                            final List<CategoryModel> tempCategories = List.from(categories);
                            // Remove the item from oldIndex
                            final item = tempCategories.removeAt(oldIndex);
                            // Insert the item at newIndex
                            tempCategories.insert(newIndex, item);
                            // Update the categories list
                            categories = tempCategories;

                            // Update selectedCategoryIndex to maintain selection
                            if (_selectedCategoryIndex == oldIndex) {
                              _selectedCategoryIndex = newIndex;
                            } else if (oldIndex < _selectedCategoryIndex! && newIndex >= _selectedCategoryIndex!) {
                              _selectedCategoryIndex = _selectedCategoryIndex! - 1;
                            } else if (oldIndex > _selectedCategoryIndex! && newIndex <= _selectedCategoryIndex!) {
                              _selectedCategoryIndex = _selectedCategoryIndex! + 1;
                            }

                            if (kDebugMode) {
                              print("### CategoriesScreen: Updated categories order: ${categories.map((c) => c.name).toList()}");
                              print("### CategoriesScreen: Updated selectedCategoryIndex: $_selectedCategoryIndex");
                            }
                          });
                        },
                      ),
                      if (currentCategoryLevel > 0)
                      // Padding(
                      //   padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      //   child: Row(
                      //     children: [
                      //       Expanded(
                      //         child: SingleChildScrollView(
                      //           scrollDirection: Axis.horizontal,
                      //           child: Row(
                      //             children: List.generate(navigationPath.length, (index) {
                      //               return GestureDetector(
                      //                 onTap: () => _onNavigationPathTapped(index),
                      //                 child: Row(
                      //                   children: [
                      //                     Text(
                      //                       navigationPath[index],
                      //                       style: const TextStyle(
                      //                         fontSize: 16,
                      //                         fontWeight: FontWeight.bold,
                      //                         color: Colors.blue,
                      //                         decoration: TextDecoration.underline,
                      //                       ),
                      //                     ),
                      //                     if (index < navigationPath.length - 1)
                      //                       const Padding(
                      //                         padding: EdgeInsets.symmetric(horizontal: 8.0),
                      //                         child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.blue),
                      //                       ),
                      //                   ],
                      //                 ),
                      //               );
                      //             }),
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                            child: Container(
                              margin: EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? const Color(0xFF1D1C2C) // dark background
                                    : Colors.white, // light background
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).brightness ==
                                        Brightness.dark
                                        ? Colors.black.withOpacity(
                                        0.3) // softer shadow in dark mode
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ---------- BREADCRUMB ----------
                                  if (navigationPath.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 5, 10, 4),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: List.generate(
                                              navigationPath.length, (index) {
                                            final isDark =
                                                Theme.of(context).brightness ==
                                                    Brightness.dark;

                                            return GestureDetector(
                                              onTap: () =>
                                                  _onNavigationPathTapped(
                                                      index),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    navigationPath[index],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontFamily: 'poppins',
                                                      fontWeight:
                                                      FontWeight.w800,
                                                      color: isDark
                                                          ? const Color(
                                                          0xFFE0E0E0) // light grey for dark
                                                          : const Color(
                                                          0xFF4C5F7D), // dark blue for light
                                                    ),
                                                  ),
                                                  if (index <
                                                      navigationPath.length - 1)
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8.0),
                                                      child: Icon(
                                                        Icons
                                                            .arrow_forward_ios_rounded,
                                                        size: 16,
                                                        color: isDark
                                                            ? const Color(
                                                            0xFFB0B0B0) // grey arrow for dark
                                                            : Colors
                                                            .blue, // blue arrow for light
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                    child: Divider(
                                      thickness: 3,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFF1F1F3),
                                    ),
                                  ),

                                  // ---------- SUBCATEGORY + PRODUCTS ----------
                                  Expanded(
                                    child: Misc
                                        .enableCategoryProductWithSubCategoryList
                                        ? Column(
                                      children: [
                                        SizedBox(
                                          height: 140,
                                          child: SubCategoryGridWidget(
                                            isLoading:
                                            isLoadingNestedContent,
                                            subCategories:
                                            subCategoryListItems,
                                            selectedSubCategoryIndex:
                                            _selectedSubCategoryIndex,
                                            onSubCategoryTapped:
                                            _onSubCategoryTapped,
                                          ),
                                        ),
                                        Expanded(
                                          child: NestedGridWidget(
                                            productBloc: productBloc,
                                            orderHelper: orderHelper,
                                            isHorizontal: true,
                                            isLoading:
                                            isLoadingNestedContent,
                                            showAddButton: false,
                                            showBackButton:
                                            showBackButton,
                                            items: categoryProducts,
                                            selectedItemIndex:
                                            selectedItemIndex,
                                            reorderedIndices:
                                            reorderedIndices,
                                            onAddButtonPressed: null,
                                            onBackButtonPressed:
                                            _onBackToCategories,
                                            onItemTapped: (index,
                                                {bool?
                                                variantAdded}) =>
                                                _onItemSelected(
                                                    index,
                                                    variantAdded ??
                                                        false),
                                            onReorder:
                                                (oldIndex, newIndex) {
                                              if (oldIndex == 0 ||
                                                  newIndex == 0) return;
                                              final adjustedOldIndex =
                                                  oldIndex -
                                                      (showBackButton
                                                          ? 1
                                                          : 0);
                                              final adjustedNewIndex =
                                                  newIndex -
                                                      (showBackButton
                                                          ? 1
                                                          : 0);
                                              if (adjustedOldIndex < 0 ||
                                                  adjustedNewIndex < 0 ||
                                                  adjustedOldIndex >=
                                                      categoryProducts
                                                          .length ||
                                                  adjustedNewIndex >=
                                                      categoryProducts
                                                          .length) {
                                                return;
                                              }
                                              setState(() {
                                                categoryProducts = List<
                                                    Map<String,
                                                        dynamic>>.from(
                                                    categoryProducts);
                                                final item = categoryProducts
                                                    .removeAt(
                                                    adjustedOldIndex);
                                                categoryProducts.insert(
                                                    adjustedNewIndex,
                                                    item);
                                                reorderedIndices =
                                                    List.filled(
                                                        categoryProducts
                                                            .length,
                                                        null);
                                                reorderedIndices[
                                                adjustedNewIndex] =
                                                    adjustedNewIndex;
                                                selectedItemIndex =
                                                    adjustedNewIndex;
                                              });
                                            },
                                            onDeleteItem: (index) {},
                                            onCancelReorder: () {
                                              setState(() {
                                                reorderedIndices =
                                                    List.filled(
                                                        categoryProducts
                                                            .length,
                                                        null);
                                              });
                                            },
                                            showDeleteButton: false,
                                          ),
                                        ),
                                      ],
                                    )
                                        : NestedGridWidget(
                                      productBloc: productBloc,
                                      orderHelper: orderHelper,
                                      isHorizontal: true,
                                      isLoading: isLoadingNestedContent,
                                      showAddButton: false,
                                      showBackButton: showBackButton,
                                      items: categoryProducts,
                                      selectedItemIndex:
                                      selectedItemIndex,
                                      reorderedIndices: reorderedIndices,
                                      onAddButtonPressed: null,
                                      onBackButtonPressed:
                                      _onBackToCategories,
                                      onItemTapped: (index,
                                          {bool? variantAdded}) =>
                                          _onItemSelected(index,
                                              variantAdded ?? false),
                                      onReorder: (oldIndex, newIndex) {
                                        if (oldIndex == 0 ||
                                            newIndex == 0) return;
                                        final adjustedOldIndex =
                                            oldIndex -
                                                (showBackButton ? 1 : 0);
                                        final adjustedNewIndex =
                                            newIndex -
                                                (showBackButton ? 1 : 0);
                                        if (adjustedOldIndex < 0 ||
                                            adjustedNewIndex < 0 ||
                                            adjustedOldIndex >=
                                                categoryProducts.length ||
                                            adjustedNewIndex >=
                                                categoryProducts.length) {
                                          return;
                                        }
                                        setState(() {
                                          categoryProducts = List<
                                              Map<String,
                                                  dynamic>>.from(
                                              categoryProducts);
                                          final item = categoryProducts
                                              .removeAt(adjustedOldIndex);
                                          categoryProducts.insert(
                                              adjustedNewIndex, item);
                                          reorderedIndices = List.filled(
                                              categoryProducts.length,
                                              null);
                                          reorderedIndices[
                                          adjustedNewIndex] =
                                              adjustedNewIndex;
                                          selectedItemIndex =
                                              adjustedNewIndex;
                                        });
                                      },
                                      onDeleteItem: (index) {},
                                      onCancelReorder: () {
                                        setState(() {
                                          reorderedIndices = List.filled(
                                              categoryProducts.length,
                                              null);
                                        });
                                      },
                                      showDeleteButton: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
                if (sidebarPosition != SidebarPosition.right &&
                    !(sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey: _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
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
            ),
        ],
      ),
    );
  }
}