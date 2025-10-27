// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../Database/order_panel_db_helper.dart';
// import '../../Widgets/widget_category_list.dart';
// import '../../Widgets/widget_nested_grid_layout.dart';
// import '../../Widgets/widget_order_panel.dart';
// import '../../Widgets/widget_topbar.dart';
// import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
//
// // Enum for sidebar position
// enum SidebarPosition { left, right, bottom }
// // Enum for order panel position
// enum OrderPanelPosition { left, right }
//
// class FastKeyScreen extends StatefulWidget {
//   final int? lastSelectedIndex; //Build #1.0.7: Make it nullable
//
//   const FastKeyScreen({super.key, this.lastSelectedIndex}); // Optional, no default value
//
//   @override
//   State<FastKeyScreen> createState() => _FastKeyScreenState();
// }
//
// class _FastKeyScreenState extends State<FastKeyScreen> {
//   final List<String> items = List.generate(18, (index) => 'Bud Light');
//   int _selectedSidebarIndex = 0; //Build #1.0.2 : By default fast key should be selected after login
//   DateTime now = DateTime.now();
//   List<int> quantities = [1, 1, 1, 1];
//   SidebarPosition sidebarPosition = SidebarPosition.left; // Default to bottom sidebar
//   OrderPanelPosition orderPanelPosition = OrderPanelPosition.right; // Default to right
//   bool isLoading = true; // Add a loading state
//   final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null); // Add this
//   final OrderHelper orderHelper = OrderHelper();
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedSidebarIndex = widget.lastSelectedIndex ?? 0; // Build #1.0.7: Restore previous selection
//
//     // Simulate a loading delay
//     Future.delayed(const Duration(seconds: 3), () {
//       if(mounted) {
//         setState(() {
//           isLoading = false; // Set loading to false after 3 seconds
//         });
//       }
//     });
//   }
//
//   void _refreshOrderList() { // Build #1.0.10 - Naveen: This will trigger a rebuild of the RightOrderPanel (Callback)
//     setState(() {
//       if (kDebugMode) {
//         print("###### FastKeyScreen _refreshOrderList");
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
//             onProductSelected: (product) { // Build #1.0.13 : Added product search
//               // Convert price from String to double safely
//               double price;
//               try {
//                 price = double.tryParse(product.price ?? '0.00') ?? 0.00;
//               } catch (e) {
//                 price = 0.00;
//               }
//
//               orderHelper.addItemToOrder(
//                 product.name ?? 'Unknown',
//                 product.images?.isNotEmpty == true ? product.images!.first : '',
//                 price, // Now properly converted to double
//                 1, // quantity
//                 'SKU${product.name}', // SKU
//               );
//             },
//           ),
//           Divider( // Build #1.0.6
//             color: Colors.grey,
//             thickness: 0.4,
//             height: 1,
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
//                       // Add the CategoryScroll widget here
//                       CategoryList(isHorizontal: true, isLoading: isLoading,isAddButtonEnabled: true, fastKeyTabIdNotifier: fastKeyTabIdNotifier),// Build #1.0.7
//
//                       // Grid Layout
//                       ValueListenableBuilder<int?>( // Build #1.0.11 : Added Notifier for update list and counts
//                         valueListenable: fastKeyTabIdNotifier,
//                         builder: (context, fastKeyTabId, child) {
//                           return NestedGridWidget(
//                             isHorizontal: true,
//                             isLoading: isLoading,
//                             onItemAdded: _refreshOrderList,
//                             fastKeyTabIdNotifier: fastKeyTabIdNotifier,
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
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/auto_search.dart';
import '../../Utilities/global_utility.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Search/product_by_sku_model.dart' as SKU;
import '../../Models/Search/product_search_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
import '../../Utilities/textfield_search.dart';
import '../../Widgets/widget_logs_toast.dart';
import '../../Widgets/widget_alert_popup_dialogs.dart';
import '../../Widgets/widget_category_list.dart';
import '../../Widgets/widget_nested_grid_layout.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Blocs/FastKey/fastkey_bloc.dart';
import '../../Repositories/FastKey/fastkey_repository.dart';
import '../../Database/fast_key_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/FastKey/fastkey_model.dart';
import '../../Blocs/FastKey/fastkey_product_bloc.dart';
import '../../Repositories/FastKey/fastkey_product_repository.dart';
import '../../Utilities/shimmer_effect.dart';
import '../../Database/db_helper.dart';
import '../Auth/login_screen.dart';

class FastKeyScreen extends StatefulWidget {
  final int? lastSelectedIndex;

  const FastKeyScreen({super.key, this.lastSelectedIndex});

  @override
  State<FastKeyScreen> createState() => _FastKeyScreenState();
}

class _FastKeyScreenState extends State<FastKeyScreen> with WidgetsBindingObserver, LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 0;
  List<int> quantities = [1, 1, 1, 1];
  // SidebarPosition sidebarPosition = SidebarPosition.left;
  // OrderPanelPosition orderPanelPosition = OrderPanelPosition.right;
  bool isLoading = true;

  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null);
  final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
  late FastKeyBloc _fastKeyBloc;
  List<FastKey> fastKeyTabs = [];
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
  int? userId;

  late FastKeyProductBloc _fastKeyProductBloc;
  List<Map<String, dynamic>> fastKeyProductItems = [];
  int? _fastKeyTabId;
  List<int?> reorderedIndices = [];
  int? selectedItemIndex;
  bool? enableIcons; // Build #1.0.204: Added this to track grid item delete/cancel icon visibility
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  final OrderHelper orderHelper = OrderHelper();
  final DBHelper dbHelper = DBHelper.instance;

  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  Map<String, dynamic>? selectedProduct;
  TextEditingController _productSearchController = TextEditingController();
  final _searchTextGridKey = GlobalKey<TextFieldSearchState>();
  late SearchProduct _autoSuggest;
  final productBloc = ProductBloc(ProductRepository());
  final PinakaPreferences _preferences = PinakaPreferences(); // Add this
  StreamSubscription? _updateOrderSubscription;
  late OrderBloc orderBloc;
  bool isTabsLoading = true; //Build #1.0.68
  bool isItemsLoading = true;
  bool _isDeleting = false; // Build #1.0.104 : Track delete button loading state
  bool isAddingItemLoading = false; // Loader for adding items to order
  final ScrollController _scrollController = ScrollController();
  int _refreshCounter = 0; //Build #1.0.170: Added: Counter to trigger RightOrderPanel refresh only when needed

  @override
  void initState() {
    super.initState();
    orderBloc = OrderBloc(OrderRepository());
    WidgetsBinding.instance.addObserver(this);
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 0;
    _fastKeyBloc = FastKeyBloc(FastKeyRepository());
    _fastKeyProductBloc = FastKeyProductBloc(FastKeyProductRepository());
    _autoSuggest = SearchProduct();
    _productSearchController.addListener(_listenProductItemSearch);

    //Build #1.0.84: Initialize user ID and load tabs sequentially
    // getUserIdFromDB().then((_) {
    //   if (kDebugMode) {
    //     print("### FastKeyScreen: initState - User ID fetched, loading active tab");
    //   }
    ///   _loadActiveFastKeyTabId(); // Don't need here , we are already calling inside getUserIdFromDB -> loadTabs -> _loadActiveFastKeyTabId
    // });
    _initializeData(); // Build #1.0.200: Code Updated for issue: Empty fastkey folders show at first logon to multiple fastkeys loaded on created by the user
    fastKeyTabIdNotifier.addListener(_onTabChanged);
  }

  Future<void> _initializeData() async {
    try {
      await getUserIdFromDB();
      if (kDebugMode) {
        print("### FastKeyScreen: _initializeData - User ID fetched");
      }
    } catch (e) {
      if (kDebugMode) print("Initialization error: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //Build #1.0.84, Explanation:
    // Only call _loadActiveFastKeyTabId if _fastKeyTabId is null and tabs exist, preventing override of an already selected tab.
    // This ensures state retention when navigating back to the screen.
    if (kDebugMode) {
      print("### FastKeyScreen: didChangeDependencies called, _fastKeyTabId: $_fastKeyTabId");
    }
    if (_fastKeyTabId == null && fastKeyTabs.isNotEmpty) {
      _loadActiveFastKeyTabId();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadActiveFastKeyTabId();
    }
  }

  // Build #1.0.204: Added this to track grid item delete/cancel icon visibility
  void _onLongPress(int itemIndex) {
    setState(() {
      enableIcons = true; // Show icons
      selectedItemIndex = itemIndex; // Track the long-pressed item
    });
  }

  void _onCancelReorder() { // Build #1.0.204
    setState(() {
      reorderedIndices = List.filled(fastKeyProductItems.length, null);
      enableIcons = false; // Hide icons
      selectedItemIndex = null; // Clear selection
    });
  }

  void _listenProductItemSearch() {
    if (_productSearchController.text.isEmpty) {
      _searchTextGridKey.currentState?.resetList();
    }
    _autoSuggest.listentextchange(_productSearchController.text ?? "");
  }

  Future<void> _onTabChanged() async {
    if (kDebugMode) {
      print("### FastKeyScreen: _onTabChanged: New Tab ID: ${fastKeyTabIdNotifier.value}");
    }
    setState(() {
      _fastKeyTabId = fastKeyTabIdNotifier.value;
      fastKeyProductItems.clear();
      isItemsLoading = true; //Build #1.0.92: Fixed Issue: Loader is not working at fast key grid for selected tab
    });
    if (_fastKeyTabId != null) { //Build #1.0.84
      await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId!);
      if (kDebugMode) {
        print("### FastKeyScreen: Saved active tab ID in _onTabChanged: $_fastKeyTabId");
      }
      await _loadFastKeyTabItems();
    }
  }

  Future<void> getUserIdFromDB() async {
    try {
      final userData = await UserDbHelper().getUserData();
      if (userData != null && userData[AppDBConst.userId] != null) {
        userId = userData[AppDBConst.userId] as int;
        ///stop loading fast key every time
        if (kDebugMode) {
          print("FastKeyScreen.getUserIdFromDB -> FastKeyDBHelper.isFastkeyLoaded = ${FastKeyDBHelper.isFastkeyLoaded}");
        }
        if(FastKeyDBHelper.isFastkeyLoaded){
          loadTabs();
          return;
        }
        _fastKeyBloc.fetchFastKeysByUser(userId ?? 0);
        await _fastKeyBloc.getFastKeysStream.listen((onData) async {
          if (onData.status == Status.ERROR) {
            if (onData.message!.contains('Unauthorised')) {
              if (kDebugMode) {
                print("Fast key 1 ---- Unauthorised : ${onData.message!}");
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => LoginScreen()));

                  if (kDebugMode) {
                    print("message 1--- ${onData.message}");
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Unauthorised. Session is expired on this device."),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              });
            }
            else {
              _fastKeyBloc.getFastKeysSink.add(
                  APIResponse.error(TextConstants.retryText));
            }
          } else if (onData.status == Status.COMPLETED) {
            if (onData.data != null) {
              final fastKeysResponse = onData.data!;
              if (fastKeysResponse.status != "success") {
                _fastKeyBloc.getFastKeysSink.add(APIResponse.error(TextConstants.retryText));
              }
              await loadTabs(); // Build  #1.0.177: add await to loadTabs to fix delay in loading
              FastKeyDBHelper.isFastkeyLoaded = true;
            }
          }
        });
      } else {
        if (kDebugMode) {
          print("FastKeyScreen: No user ID found in the database.");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("FastKeyScreen: Exception in getUserId: $e");
      }
    }
  }

  //Build #1.0.84, Explanation:
  // Call _loadActiveFastKeyTabId after loading tabs to ensure the active tab is set once fastKeyTabs is populated.
  // Update isTabsLoading to reflect the loading state and trigger a UI refresh.
  Future<void> loadTabs() async { // Build  #1.0.177: add await to loadTabs to fix delay in loading
    if (kDebugMode) {
      print("### FastKeyScreen: loadTabs called");
    }
    await _loadFastKeysTabs();
    setState(() {
      isTabsLoading = false;
      if (kDebugMode) {
        print("### FastKeyScreen: Tabs loaded, count: ${fastKeyTabs.length}");
      }
    });
    await _loadActiveFastKeyTabId(); // Ensure active tab is loaded after tabs
  }

  //Build #1.0.84, Explanation:
  // Since _loadActiveFastKeyTabId already handles tab selection and persistence, _loadLastSelectedTab can simply call it to avoid code duplication.
  // This ensures consistent state management.
  Future<void> _loadLastSelectedTab() async {
    if (kDebugMode) {
      print("### FastKeyScreen: _loadLastSelectedTab called");
    }
    // No need to duplicate logic; rely on _loadActiveFastKeyTabId
    await _loadActiveFastKeyTabId();
  }

  Future<void> _loadFastKeysTabs() async {
    final fastKeyTabsData = await fastKeyDBHelper.getFastKeyTabsByUserId(userId ?? 1);
    if (kDebugMode) {
      print("##### _loadFastKeysTabs: $fastKeyTabsData");
    }
    if (mounted) {
      setState(() {
        fastKeyTabs = fastKeyTabsData.map((product) {
          return FastKey(
            fastkeyServerId: product[AppDBConst.fastKeyServerId],
            userId: userId ?? 1,
            fastkeyTitle: product[AppDBConst.fastKeyTabTitle],
            fastkeyImage: product[AppDBConst.fastKeyTabImage],
            fastkeyIndex: product[AppDBConst.fastKeyTabIndex]?.toString() ?? '0',
            itemCount: int.tryParse(product[AppDBConst.fastKeyTabItemCount]?.toString() ?? '0') ?? 0,
          );
        }).toList();
      });
    }
  }

  // Build #1.0.87: code updated , db handing inside bloc only, remove here
  Future<void> _addFastKeyTab(String title, String image) async {

    //Build #1.0.279: Fixed Issue - after creating fastkey it is showing default icon
    String imageToSend = image;
    if (image.startsWith('assets/')) {
      imageToSend = '';
    }

    if (kDebugMode) {
      print("### FastKeyScreen: _addFastKeyTab started with title: $title, image: $imageToSend");
    }
    // Call API to create FastKey on server via BLoC
    _fastKeyBloc.createFastKey(title: title, index: fastKeyTabs.length+1, imageUrl: imageToSend, userId: userId ?? 1);

    // Listen for API response
    final response = await _fastKeyBloc.createFastKeyStream.firstWhere((response) => response.status == Status.COMPLETED || response.status == Status.ERROR);
    if (response.status == Status.COMPLETED && response.data != null) {
      if (kDebugMode) {
        print("### FastKeyScreen: API createFastKey success, server ID: ${response.data!.fastkeyId}");
      }
      // Update UI with new tab (BLoC handles DB insertion)
      setState(() {
        fastKeyTabs.add(FastKey(
          fastkeyServerId: response.data!.fastkeyId,
          userId: userId ?? 1,
          fastkeyTitle: response.data!.fastkeyTitle,
          fastkeyImage: response.data!.fastkeyImage,
          fastkeyIndex: fastKeyTabs.length.toString(),
          itemCount: 0,
        ));
        _selectedCategoryIndex = fastKeyTabs.length - 1;
        _fastKeyTabId = response.data!.fastkeyId; // Use server ID
        fastKeyTabIdNotifier.value = response.data!.fastkeyId;
        if (kDebugMode) {
          print("### FastKeyScreen: Updated UI, selected tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      });
    }
    else if(response.status == Status.ERROR){// Build #1.0.189: Only Show when it comes response as error
      if (response.message!.contains('Unauthorised')) {
        if (kDebugMode) {
          print("Fast key 2---- Unauthorised : ${response.message!}");
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => LoginScreen()));

            if (kDebugMode) {
              print("message --- ${response.message}");
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Unauthorised. Session is expired on this device."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
      else {
        // Handle API error
        if (kDebugMode) {
          print("### FastKeyScreen: API createFastKey failed: ${response
              .message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                response.message ?? TextConstants.failedToCreateFastKey),
            // Build #1.0.189: Updated from api response - Proper error not showing while getting error in create fast key
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteFastKeyTab({required int fastKeyTabServerId}) async {
    if (kDebugMode) {
      print("### FastKeyScreen: _deleteFastKeyTab started with server ID: $fastKeyTabServerId");
    }
    _fastKeyBloc.deleteFastKey(fastKeyTabServerId, userId ?? 1);

    setState(() {
      fastKeyTabs.removeWhere((tab) => tab.fastkeyServerId == fastKeyTabServerId);
      if (_selectedCategoryIndex != null) {
        if (_selectedCategoryIndex! >= fastKeyTabs.length) {
          _selectedCategoryIndex = fastKeyTabs.isNotEmpty ? fastKeyTabs.length - 1 : null;
          _fastKeyTabId = _selectedCategoryIndex != null ? fastKeyTabs[_selectedCategoryIndex!].fastkeyServerId : null;
          fastKeyTabIdNotifier.value = _fastKeyTabId;
        }
      }
      _editingCategoryIndex = null; //Build 1.1.36: Clear edit mode
      fastKeyProductItems.clear(); //Build #1.0.279: Fixed Issue - Deleted Fast Key Products Are Shifting to Next Fast Key
      if (kDebugMode) {
        print("### FastKeyScreen: Updated UI after tab deletion, new tab count: ${fastKeyTabs.length}");
      }
    });

    await _fastKeyBloc.deleteFastKeyStream.firstWhere((response) => response.status == Status.COMPLETED || response.status == Status.ERROR).then((response) async {
      if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Fast key 3 ---- Unauthorised : ${response.message!}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              if (kDebugMode) {
                print("message --- ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        else {
          if (kDebugMode) {
            print("### FastKeyScreen: API deleteFastKey failed: ${response
                .message}");
          }
        }
        await _loadFastKeysTabs(); // Revert UI if server deletion fails
      }
    });
  }

  //Build #1.0.84 , Explanation:
  // Check if lastSelectedTabId exists and corresponds to a valid tab in fastKeyTabs.
  // If no valid tab is found but fastKeyTabs is not empty, default to the first tab and save it to SharedPreferences.
  // If no tabs exist, reset _selectedCategoryIndex and _fastKeyTabId to null.
  // Trigger _loadFastKeyTabItems only when a valid _fastKeyTabId is set.
  // Update fastKeyTabIdNotifier to reflect the selected tab and trigger UI updates.
  Future<void> _loadActiveFastKeyTabId() async {
    if (kDebugMode) {
      print("### FastKeyScreen: _loadActiveFastKeyTabId called");
    }
    final lastSelectedTabId = await fastKeyDBHelper.getActiveFastKeyTab();
    if (kDebugMode) {
      print("### FastKeyScreen: Last selected tab ID from SharedPreferences: $lastSelectedTabId");
    }

    setState(() {
      if (lastSelectedTabId != null && fastKeyTabs.any((tab) => tab.fastkeyServerId == lastSelectedTabId)) {
        _selectedCategoryIndex = fastKeyTabs.indexWhere((tab) => tab.fastkeyServerId == lastSelectedTabId);
        _fastKeyTabId = lastSelectedTabId;
        if (kDebugMode) {
          print("### FastKeyScreen: Restored tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      } else if (fastKeyTabs.isNotEmpty) {
        _selectedCategoryIndex = 0;
        _fastKeyTabId = fastKeyTabs[0].fastkeyServerId;
        fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId); // Save default tab
        if (kDebugMode) {
          print("### FastKeyScreen: No valid last tab, defaulting to first tab ID: $_fastKeyTabId");
        }
      } else {
        _selectedCategoryIndex = null;
        _fastKeyTabId = null;
        if (kDebugMode) {
          print("### FastKeyScreen: No tabs available, resetting selection");
        }
      }
      fastKeyTabIdNotifier.value = _fastKeyTabId;
    });

    if (_fastKeyTabId != null) {
      await _loadFastKeyTabItems();
    }
  }

  Future<void> _loadFastKeyTabItems() async {
    if (kDebugMode) {
      print("FastKey Screen _loadFastKeyTabItems $_fastKeyTabId");
    }
    if (_fastKeyTabId == null) {
      setState(() { //Build #1.0.68
        isItemsLoading = false;
      });
      return;
    }
    if(FastKeyDBHelper.isFastkeyLoaded){ ///stops loading every time
      final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = List<Map<String, dynamic>>.from(items);
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      }
      return;
    }

    var tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) {
      setState(() {
        fastKeyProductItems = [];
        isItemsLoading = false;
      });
      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems selected tab is empty: ${tabs.length}");
      }
      return;
    }
    fastKeyProductItems.clear(); //Build #1.0.78: Clear existing items
    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    if (kDebugMode) {
      print("FastKey Screen _loadFastKeyTabItems selected tab server id: $fastKeyServerId");
    }
    await _fastKeyProductBloc.fetchProductsByFastKeyId(_fastKeyTabId ?? 1, fastKeyServerId).whenComplete(() async {
      final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = List<Map<String, dynamic>>.from(items);
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      }
    });
  }

  // Build #1.0.87 : Reload fastKey tab products after adding new item into fastKey
  Future<void> _refreshFastKeyTabItems() async {
    if (_fastKeyTabId == null) {
      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems aborted, no tab selected");
      }
      return;
    }
    if (kDebugMode) {
      print("FastKey Screen _loadFastKeyTabItems $_fastKeyTabId");
    }
    setState(() => isItemsLoading = true);
    try {
      final tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
      if (tabs.isNotEmpty) {
        final fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
        if (kDebugMode) {
          print("FastKey Screen _loadFastKeyTabItems selected tab server id: $fastKeyServerId");
        }
        final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId ?? 1);
        if (kDebugMode) {
          print("#### Retrieved ${items.length} FastKey Items for Tab ID: $_fastKeyTabId");
        }
        setState(() {
          fastKeyProductItems = List<Map<String, dynamic>>.from(items); // Ensure mutable copy
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      } else {
        setState(() {
          fastKeyProductItems = [];
          isItemsLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading FastKey tab items: $e");
      }
      setState(() => isItemsLoading = false);
    }
  }

  // Build #1.0.87: code updated
  Future<void> _addFastKeyTabItem(String name, String image, String price) async {
    if (_fastKeyTabId == null) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, no tab selected");
      }
      return;
    }
    var tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, tab not found");
      }
      return;
    }
    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    var countProductInFastKey = fastKeyProductItems.length; // Use current UI state
    FastKeyProductItem item = FastKeyProductItem(productId: selectedProduct!['id'], slNumber: countProductInFastKey + 1);

    StreamSubscription? subscription;
    subscription = _fastKeyProductBloc.addProductsStream.listen((response) async {

      if (!mounted) {
        subscription?.cancel();
        return;
      }
      print("response ---- ${response.status}");
      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print("#### FastKeyScreen: addProducts Status COMPLETED");
        }
        setState(() => isAddingItemLoading = false); // Build #1.0.204: Added missed loader on "Add"  button of search product dialouge after tap on add
        // Reload items using existing method
        _refreshFastKeyTabItems();
        subscription?.cancel();
      } else if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Fast key 4 ---- Unauthorised : ${response.message!}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              if (kDebugMode) {
                print("message --- ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        else {
          if (kDebugMode) {
            print("Failed to add item to fastkey: ${response.message}");
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextConstants.failedToAddItemToFastKey),
              // Build #1.0.144
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        subscription?.cancel();
      } else if (response.status == Status.LOADING) {
        if (kDebugMode) {
          print("### FastKeyScreen: Adding item to FastKey, loading...");
        }
        setState(() => isItemsLoading = true);
      }
    });
    /// addProducts API CALL
    await _fastKeyProductBloc.addProducts(fastKeyId: fastKeyServerId, products: [item]);
  }

  Future<void> _deleteFastKeyTabItem(int fastKeyTabItemServerId) async { // Build #1.0.104
    if (_fastKeyTabId == null) return;

    // Build #1.0.89: delete FastKey product API integrated
    var tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) return;

    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    /// Build #1.0.104: No need to check again we already doing in _showDeleteConfirmationDialog
    // var item = fastKeyProductItems.firstWhere((item) => item[AppDBConst.fastKeyIdForeignKey] == fastKeyTabItemId);
    // String productId = item[AppDBConst.fastKeyProductId];

    StreamSubscription? subscription;
    subscription = _fastKeyProductBloc.deleteProductStream.listen((response) async {
      if (!mounted) {
        subscription?.cancel();
        return;
      }
      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print("### FastKeyScreen: Product deleted successfully from FastKey: ${response.data!.fastkeyId}");
        }
        await _refreshFastKeyTabItems(); // refresh UI
        if (Misc.showDebugSnackBar) { // Build #1.0.254
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data?.message ?? "Product deleted from Fast Key"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        subscription?.cancel();
      } else if (response.status == Status.ERROR) {
        if (response.message!.contains('Unauthorised')) {
          if (kDebugMode) {
            print("Fast key 5---- Unauthorised : ${response.message!}");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginScreen()));

              if (kDebugMode) {
                print("message --- ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        else {
          if (kDebugMode) {
            print("### FastKeyScreen: Failed to delete product: ${response
                .message}");
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextConstants.failedToDeleteProductFromFastKey),
              // Build #1.0.144
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        subscription?.cancel();
      }
    });

    /// delete FastKey product API call
    // await _fastKeyProductBloc.deleteProduct(fastKeyServerId, fastKeyTabItemId);
    await _fastKeyProductBloc.deleteProduct(fastKeyServerId, fastKeyTabItemServerId); // Build #1.0.104
  }

  Future<void> _pickImage() async {
    final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
    if (imageFile != null) {
      setState(() {
        _pickedImage = File(imageFile.path);
      });
    }
  }
  Stopwatch? refreshUIStopwatch; // Build #1.0.256
  void _onItemSelected(int index, bool showAddButton, bool variantAdded) async {

    //Build #1.0.78: fix for parent product also adding along with variant product , we have to restrict that like categories screen
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

    if (kDebugMode) {
      print("Fast Key _onItemSelected");
    }
    final adjustedIndex = index - (showAddButton ? 1 : 0);
    if (adjustedIndex < 0 || adjustedIndex >= fastKeyProductItems.length) return;

    final selectedProduct = fastKeyProductItems[adjustedIndex];
    // final order = orderHelper.orders.firstWhere(
    //       (order) => order[AppDBConst.orderServerId] == orderHelper.activeOrderId,
    //   orElse: () => {},
    // );
    final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
    final dbOrderId = orderHelper.activeOrderId;
    /// Build #1.0.128: No need to check this condition
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
      // For API orders
      //  if (serverOrderId != null) { // Build #1.0.128: No need
      _updateOrderSubscription?.cancel();
      StreamSubscription? subscription;
      // setState(() => isAddingItemLoading = true);
      // Measure time for Add Product to Order (for non-variant or empty variations)
      // Initialize stopwatch only if Misc.enableUILogMessages is true
      Stopwatch? addProductStopwatch;
      if (Misc.enableUILogMessages) {
        addProductStopwatch = Stopwatch()..start();
      }
      subscription = orderBloc.updateOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.LOADING) { // Build #1.0.80
          if (kDebugMode) print("Loading stated in fastkey under _onItemSelected ...");
          const Center(child: CircularProgressIndicator());
        } else if (response.status == Status.COMPLETED) {
          // Build #1.0.148: we have to show loader until product adds into order panel, then hide
          // Navigator.pop(context); // Hide Loader / VariationPopup dialog
          if (!Misc.enableUILogMessages){
            if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
              Navigator.pop(context);
            }
          }
          // setState(() => isAddingItemLoading = false);
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
          // Build #1.0.256: Stop stopwatch and add to steps only if enabled
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
          if (response.message!.contains('Unauthorised')) {
            if (kDebugMode) {
              print("Fast key 6---- Unauthorised : ${response.message!}");
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => LoginScreen()));

                if (kDebugMode) {
                  print("message --- ${response.message}");
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Unauthorised. Session is expired on this device."),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          } else {
            if (kDebugMode) print("Failed to add item to order: ${response.message}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? TextConstants.failedToAddItemToOrder),
                // Build #1.0.144
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          // Stop stopwatch and add to steps only if enabled
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
            if (kDebugMode) {
              print("Add Product to Order (error) completed in ${globalProcessSteps.last.timeTaken}s");
            }
          }
          subscription?.cancel();
        }
      });

      /// API CALL
      await orderBloc.updateOrderProducts(
        orderId: serverOrderId,
        dbOrderId: dbOrderId,
        lineItems: [
          OrderLineItem(
            productId: int.parse(selectedProduct[AppDBConst.fastKeyProductId]),
            quantity: 1,
            //  sku: selectedProduct[AppDBConst.fastKeyItemSKU] ?? 'N/A',
          ),
        ],
      );
      //  } else { // Build #1.0.128: No need
      //    // For local orders
      //    // await orderHelper.addItemToOrder(
      //    //   int.parse(selectedProduct[AppDBConst.fastKeyProductId]),
      //    //   selectedProduct[AppDBConst.fastKeyItemName],
      //    //   selectedProduct[AppDBConst.fastKeyItemImage],
      //    //   double.tryParse(selectedProduct[AppDBConst.fastKeyItemPrice].toString()) ?? 0.0,
      //    //   1,
      //    //   selectedProduct[AppDBConst.fastKeyItemSKU],
      //    //   serverOrderId ?? 0,
      //    //   onItemAdded: _createOrder,
      //    // );
      // //   setState(() => isAddingItemLoading = false);
      //    ScaffoldMessenger.of(context).showSnackBar(
      //      SnackBar(
      //        content: Text("Item '${selectedProduct[AppDBConst.fastKeyItemName]}'did not added to order. OrderId not found."),
      //        backgroundColor: Colors.green,
      //        duration: const Duration(seconds: 2),
      //      ),
      //    );
      //    _refreshOrderList();
      //  }
    } catch (e, s) {
      if (kDebugMode) print("Exception in _onItemSelected: $e, Stack: $s");
      //  setState(() => isAddingItemLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextConstants.errorAddingItem), // Build #1.0.144
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  //Build #1.0.78: Explanation:
  // Removed commented-out stream listener code and integrated it directly.
  // Database update (updateServerOrderIDInDB) is assumed to be handled in OrderBloc.createOrder (already updated).
  // Added alert dialog with retry option for API failures.
  // Added success toast for order creation.
  // Preserved debug prints and device ID placeholder logic.
  // Future<void> _createOrder() async {
  //   try {
  //     var orders = await orderHelper.getOrderById(orderHelper.activeOrderId ?? 0);
  //     if (kDebugMode) {
  //       print("Fast Key screen createOrder - Orders in DB $orders");
  //     }
  //     int? shiftId = await UserDbHelper().getUserShiftId();
  //
  //     //Build #1.0.78: Validation required : if shift id is empty show toast or alert user to start the shift first
  //     if (shiftId == null) {
  //       if (kDebugMode) print("####### _createOrder() : shiftId -> $shiftId");
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(TextConstants.pleaseStartShiftBeforeCreatingOrder), // Build #1.0.144
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //     if (orders.isNotEmpty && orders.first[AppDBConst.orderServerId] != null) {
  //       _refreshOrderList();
  //       return;
  //     }
  //
  //     final deviceDetails = await GlobalUtility.getDeviceDetails(); //Build #1.0.126: using from GlobalUtility
  //     String deviceId = deviceDetails['device_id'] ?? 'unknown';
  //     OrderMetaData device = OrderMetaData(key: OrderMetaData.posDeviceId, value: deviceId); // TODO: Implement dynamic device ID
  //     OrderMetaData placedBy = OrderMetaData(key: OrderMetaData.posPlacedBy, value: '${userId ?? 1}');
  //     OrderMetaData shiftIdValue = OrderMetaData(key: OrderMetaData.shiftId, value: shiftId.toString()); // Build #1.0.149
  //     List<OrderMetaData> metaData = [device, placedBy, shiftIdValue];
  //
  //     StreamSubscription? subscription;
  //
  //     subscription = orderBloc.createOrderStream.listen((response) async {
  //       if (!mounted) {
  //         subscription?.cancel();
  //         return;
  //       }
  //       if (response.status == Status.COMPLETED) {
  //         if (kDebugMode) print("Order created successfully with server ID: ${response.data!.id}");
  //         if (Misc.showDebugSnackBar) { // Build #1.0.254
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(TextConstants.orderCreatedSuccessfully), // Build #1.0.144
  //             backgroundColor: Colors.green,
  //             duration: const Duration(seconds: 2),
  //           ),
  //         );
  //         }
  //         _refreshOrderList();
  //         subscription?.cancel();
  //       } else if (response.status == Status.ERROR) {
  //         if (response.message!.contains('Unauthorised')) {
  //           if (kDebugMode) {
  //             print("Fast key 7 ---- Unauthorised : ${response.message!}");
  //           }
  //           WidgetsBinding.instance.addPostFrameCallback((_) {
  //             if (mounted) {
  //               Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
  //
  //               if (kDebugMode) {
  //                 print("message --- ${response.message}");
  //               }
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(
  //                   content: Text(
  //                       "Unauthorised. Session is expired on this device."),
  //                   backgroundColor: Colors.red,
  //                   duration: Duration(seconds: 2),
  //                 ),
  //               );
  //             }
  //           });
  //         }
  //         else {
  //           if (kDebugMode) print("Failed to create order: ${response.message}");
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text(TextConstants.failedToCreateOrder),
  //               // Build #1.0.144
  //               backgroundColor: Colors.red,
  //               duration: const Duration(seconds: 2),
  //             ),
  //           );
  //         }
  //         subscription?.cancel();
  //       }
  //     });
  //
  //     await orderBloc.createOrder(); // Build #1.0.128
  //   } catch (e) {
  //     if (kDebugMode) print("Exception in _createOrder: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(TextConstants.errorCreatingOrder), // Build #1.0.144
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  void _refreshOrderList() {
    setState(() { // Build #1.0.128
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

  Future<void> _showAddItemDialog() async {
    var size = MediaQuery.of(context).size;
    searchController.clear();
    selectedProduct = null;
    bool errorShown = false;
    searchResults.clear();
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    final productBloc = ProductBloc(ProductRepository());

    return showDialog<void>(
      context: context, // Use the current context
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            titleTextStyle: TextStyle(fontSize: 18, color: Colors.black),
            backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : null,
            title: Text(TextConstants.searchAddItemText,style: TextStyle(color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark : Colors.black87),),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: TextConstants.searchItemText,
                          hintText: TextConstants.typeSearchText,
                        ),
                        onChanged: (value) {
                          productBloc.fetchProducts(searchQuery: value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: StreamBuilder<APIResponse<List<ProductResponse>>>(
                        stream: productBloc.productStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            switch (snapshot.data!.status) {
                              case Status.LOADING:
                                return const Center(child: CircularProgressIndicator());
                              case Status.COMPLETED:
                                final products = snapshot.data!.data;
                                if (products == null || products.isEmpty) {
                                  return const Center(child: Text("No products found"));
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : ThemeNotifier.lightBackground,
                                  ),
                                  height: size.height * 0.5,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 3, right:3),
                                    child: Scrollbar(
                                      controller: _scrollController,
                                      scrollbarOrientation: ScrollbarOrientation.right,
                                      thumbVisibility: true,
                                      thickness: 8.0,
                                      interactive: false,
                                      radius: const Radius.circular(8),
                                      trackVisibility: true,
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: products.length,
                                        itemBuilder: (context, index) {
                                          final product = products[index];
                                          return ListTile(
                                            leading: product.images != null && product.images!.isNotEmpty
                                                ? Image.network(
                                              product.images!.first,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                            )
                                                : const Icon(Icons.image),
                                            title: Text(product.name ?? 'No Name'),
                                            subtitle: Text('${TextConstants.currencySymbol}${double.tryParse(product.price.toString())?.toStringAsFixed(2) ?? "0.00"}'),
                                            onTap: () {
                                              setStateDialog(() {
                                                var tag = product.tags?.firstWhere((element) => element.name == TextConstants.age_restricted, orElse: () => SKU.Tags());
                                                if (kDebugMode) {
                                                  print("FaskKey setStateDialog hasAgeRestriction tag = ${tag?.id}, ${tag?.name}, ${tag?.slug}");
                                                  print("FaskKey setStateDialog ${product.name ?? 'Unknown'}");
                                                }
                                                selectedProduct = {
                                                  'title': product.name ?? 'Unknown',
                                                  'image': product.images?.isNotEmpty == true ? product.images!.first : '',
                                                  'price': product.regularPrice ?? '0.00',
                                                  'id': product.id,
                                                  'sku': product.sku ?? 'N/A',
                                                  'minAge': int.parse(tag?.slug ?? "0"),
                                                };
                                              });
                                            },
                                            selected: selectedProduct != null && selectedProduct!['id'] == product.id,
                                            selectedTileColor: Colors.grey[300],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              case Status.ERROR:
                                if (snapshot.data!.message!.contains('Unauthorised')) {
                                  if (!errorShown) { // Set the flag to true IMMEDIATELY to prevent this block from running again
                                    errorShown = true;
                                    if (kDebugMode) {
                                      print(
                                          "Fast key 8 ---- Unauthorised : ${snapshot.data!.message!}");
                                    }
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    LoginScreen()));

                                        if (kDebugMode) {
                                          print(
                                              "message 2  --- ${snapshot.data!.message}");
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Unauthorised. Session is expired on this device."),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                } else {
                                  return Center(
                                    child: Text(snapshot.data!.message ??
                                        "Error loading products"),
                                  );
                                }
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  productBloc.dispose();
                },
                child: const Text(TextConstants.cancelText),
              ),
              TextButton( //Build #1.0.68 : updated code for exist item alert
                onPressed: selectedProduct != null && !isAddingItemLoading // Add condition
                    ? () async {
                  setStateDialog(() => isAddingItemLoading = true); // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add

                  final existingItems = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
                  if (kDebugMode) {
                    print("#### existingItems: $existingItems");
                    print("#### selectedProduct ID : ${selectedProduct!['id']}");
                  }
                  final selectedProductId = selectedProduct!['id'].toString();
                  final existingItem = existingItems.firstWhere(
                        (item) => item[AppDBConst.fastKeyProductId].toString() == selectedProductId,
                    orElse: () => {},
                  );

                  if (existingItem.isNotEmpty) {
                    if (kDebugMode) {
                      print("#### Product EXIST");
                    }
                    // Navigator.of(dialogContext).pop(); // Close the add item dialog
                    final tab = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId!); // Build #1.0.87
                    final tabName = tab.isNotEmpty ? tab.first[AppDBConst.fastKeyTabTitle] : 'Fast Key';

                    setStateDialog(() => isAddingItemLoading = false); // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add
                    // Show custom item alert with dismissal using parent context
                    await CustomDialog.showCustomItemAlert(
                      context, // Use parent context
                      title: TextConstants.alreadyExistTitle,
                      description: '${TextConstants.alreadyExistSubTitle} $tabName',
                      buttonText: TextConstants.okText,
                      onButtonPressed: () {
                        Navigator.of(context).pop(); // Dismiss the alert dialog
                      },
                    );
                  } else {
                    if (kDebugMode) {
                      print("#### Product not EXIST");
                    }
                    await _addFastKeyTabItem(
                      selectedProduct!['title'],
                      selectedProduct!['image'],
                      selectedProduct!['price'],
                    );
                    //  await fastKeyDBHelper.updateFastKeyTabCount(_fastKeyTabId!, fastKeyProductItems.length);
                    // await _loadFastKeyTabItems();
                    if (mounted) {
                      setState(() {});
                    }
                    fastKeyTabIdNotifier.notifyListeners();
                    Navigator.of(dialogContext).pop(); // Close the add item dialog
                  }
                  // Build #1.0.87: after exist dialog ok tap search not working because of bloc dispose , no need here to dispose , after dialog pop we are doing
                  //    _productSearchController.text = "";
                  //    Navigator.of(context).pop();
                  //    productBloc.dispose();
                }
                    : null,
                child: isAddingItemLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2), // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add
                ) : Text(TextConstants.addText),
              ),
            ],
          );
        });
      },
    ).then((_) {
      if (kDebugMode) {
        print("#### productBloc disposed");
      }
      productBloc.dispose();
    });
  }

  void _showCategoryDialog({required BuildContext context, int? index}) {
    bool isEditing = index != null;
    TextEditingController nameController = TextEditingController(text: isEditing ? fastKeyTabs[index!].fastkeyTitle : '');
    String imagePath = isEditing ? fastKeyTabs[index!].fastkeyImage : 'assets/default.png';
    bool showError = false;
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return
              AlertDialog(
                backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                contentPadding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 0),
                // titlePadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
                actionsPadding: EdgeInsets.only(right: 24, top: 10),
                // insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? TextConstants.editFastKeyNameText
                          : TextConstants.addFastKeyNameText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black87,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                      width: 175,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.orderPanelTabBackground : Color(0xFFFFF7F7),
                                            blurRadius: 3,
                                            spreadRadius: 3,
                                            offset: Offset(0,0),
                                          ),
                                        ],
                                      ),
                                      child: _buildImageWidget(imagePath)),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      margin: EdgeInsets.all(10.0),
                                      padding: EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 3,
                                            spreadRadius: 3,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: GestureDetector(
                                        onTap: () async {
                                          ///Use below code to select from device space
                                          // final pickedFile = await ImagePicker()
                                          //     .pickImage(
                                          //     source: ImageSource.gallery);
                                          // if (pickedFile != null) {
                                          //   setStateDialog(() =>
                                          //   imagePath = pickedFile.path);
                                          // }
                                          ///Use below code to select from woocomerce space
                                          var image = await _showSelectImageDialog(context: context);
                                          ///update the selected image
                                          if (kDebugMode) {
                                            print("2 image path selected is : $image");
                                          }
                                          setStateDialog(() =>
                                          imagePath = image);
                                        },
                                        child: Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.red[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                TextConstants.uploadImage,
                                style: TextStyle(
                                  color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // if (!isEditing && showError && imagePath.isEmpty)
                        //   const Padding(
                        //     padding: EdgeInsets.only(top: 8.0),
                        //     child: Text(
                        //       TextConstants.imgRequiredText,
                        //       style: TextStyle(color: Colors.red, fontSize: 12),
                        //     ),
                        //   ),
                        SizedBox(height: 20),
                        Text(
                          TextConstants.nameText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: TextConstants.categoryNameText,
                              hintStyle: TextStyle(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey[400],fontWeight: FontWeight.bold),
                              errorText: (showError && nameController.text.trim().isEmpty)
                                  ? TextConstants.categoryNameReqText
                                  : null,
                              errorStyle:
                              const TextStyle(color: Colors.red, fontSize: 12),
                              // suffixIcon: isEditing
                              //     ? const Icon(Icons.edit, size: 18, color: Colors.red)
                              //     : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[400]!),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            // Clear error when user starts typing
                            onChanged: (value) {
                              if (showError && value.trim().isNotEmpty) {
                                setStateDialog(() => showError = false);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 16, right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 50, // Increased button height
                          width: 120, // Added fixed width
                          child: TextButton(
                            onPressed: () {
                              nameController.clear();
                              //Navigator.pop(context); //Build #1.0.68: Close dialog on clear, Updated Build #1.0.229; SCRUM-386
                            },
                            // => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              TextConstants.clearText,
                              style: TextStyle(
                                  color: Colors.red[400],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          height: 50, // Increased button height
                          width: 120, // Added fixed width
                          child: TextButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) {
                                setStateDialog(() => showError = true);
                                return;
                              }
                              setStateDialog(() =>isLoading = true);
                              if (isEditing) {
                                if (kDebugMode) {
                                  print("##### isEditing : $isEditing, $index, serverId: ${fastKeyTabs[index].fastkeyServerId}, Title : ${nameController.text}");
                                }
                                // Build #1.0.89: updateFastKey API call integrated
                                _fastKeyBloc.updateFastKey(
                                    title: nameController.text.trim(), // Trim whitespace
                                    index: index+1,//backend uses non zero indexes to be passed so increase index to 1 onwards
                                    imageUrl: imagePath,
                                    fastKeyServerId: fastKeyTabs[index].fastkeyServerId,
                                    userId: userId ?? 0
                                );

                                // Listen for API response
                                final response = await _fastKeyBloc.updateFastKeyStream.firstWhere(
                                      (response) => response.status == Status.COMPLETED || response.status == Status.ERROR,
                                );

                                if (response.status == Status.COMPLETED && response.data != null) {
                                  if (kDebugMode) {
                                    print("### FastKeyScreen: API updateFastKey success, server ID: ${response.data!.fastkeyId}");
                                  }
                                  // Update the local list
                                  setState(() {
                                    isLoading = false;
                                    _editingCategoryIndex = null;
                                    _loadFastKeysTabs();
                                  });
                                  if (Misc.showDebugSnackBar) { // Build #1.0.254
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(response.data?.message ?? "Fast Key updated successfully"),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                                else if(response.status == Status.ERROR){
                                  setStateDialog(() =>isLoading = false);
                                  if (response.message!.contains('Unauthorised')) {
                                    if (kDebugMode) {
                                      print("Fast key 9 ---- Unauthorised : ${response.message!}");
                                    }
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        Navigator.pushReplacement(context,
                                            MaterialPageRoute(builder: (context) => LoginScreen()));

                                        if (kDebugMode) {
                                          print("message 9 --- ${response.message}");
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Unauthorised. Session is expired on this device."),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                  else {
                                    if (kDebugMode) {
                                      print(
                                          "### FastKeyScreen: API updateFastKey failed: ${response
                                              .message}");
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(TextConstants
                                            .failedToUpdateFastKey),
                                        // Build #1.0.144
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Add new FastKey tab
                                await _addFastKeyTab(nameController.text, imagePath);
                              }

                              // Close the dialog
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white,)) : Text(
                              isEditing ? TextConstants.saveText : TextConstants.addText,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isEditing)
                    TextButton(
                      onPressed: () => _showDeleteConfirmationDialog(tabIndex: index), // Build #1.0.104: updated delete dialog
                      child: const Text(TextConstants.deleteText, style: TextStyle(color: Colors.red)),
                    ),
                ],
              );
          },
        );
      },
    );
  }


  Future<String> _showSelectImageDialog({required BuildContext context, int? index}) async {
    // bool isEditing = index != null;
    // TextEditingController nameController = TextEditingController(text: isEditing ? fastKeyTabs[index!].fastkeyTitle : '');
    // String imagePath = isEditing ? fastKeyTabs[index!].fastkeyImage : 'assets/default.png';
    // bool showError = false;
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    String imagePath = "";
    var size = MediaQuery.of(context).size;
    List<Widget> images = [];
    // images.add(Image.asset('assets/default.png', height: 35));
    var mediaImages = await AssetDBHelper.instance.getMediaList();
    for(var image in mediaImages){
      images.add(
          GestureDetector(
            onTap: () async {
              imagePath = image.url;
              if (kDebugMode) {
                print("1 image path selected is : $imagePath");
              }
              Navigator.pop(context);
              await Future.delayed(Duration(milliseconds: 500));
              setState(() {
              });
            },
            child:
            Container(
              padding: EdgeInsets.all(10),
              child:
              _buildImageWidget(image.url),),
          )

      );
    }

    var image = await showDialog(
      context: context,
      builder: (context) {
        return
          /*Dialog(
            child: SingleChildScrollView(
              child:
              CustomScrollView(
                primary: false,
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.all(3.0),
                    sliver: SliverGrid.count(
                      mainAxisSpacing: 1, //horizontal space
                      crossAxisSpacing: 1, //vertical space
                      crossAxisCount: 3, //number of images for a row
                      children: images,
                    ),
                  ),
                ],
              ),
            ),
          );*/
          StatefulBuilder(
            builder: (context, setStateDialog) {
              return
                AlertDialog(

                  backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 0),
                  // titlePadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
                  actionsPadding: EdgeInsets.only(right: 24, top: 10),
                  // insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        TextConstants.selectImageText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black87,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  content:
                  Container(
                    width: size.width *0.6,
                    height:size.height *0.6,
                    child:
                    CustomScrollView(

                      primary: false,
                      slivers: <Widget>[
                        SliverPadding(
                          padding: const EdgeInsets.all(3.0),
                          sliver: SliverGrid.count(
                            mainAxisSpacing: 1, //horizontal space
                            crossAxisSpacing: 1, //vertical space
                            crossAxisCount: 7, //number of images for a row
                            children: images,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            },
          );
      },
    ).whenComplete(() async {
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        if (kDebugMode) {
          print("3 image path selected is : $imagePath");
        }
      });
    });
    return image ?? imagePath;
  }

  Widget _buildImageWidget(String imagePath) {
    if (kDebugMode) {
      print("_buildImageWidget for imagePath: $imagePath");
    }
    if (imagePath.isEmpty) return _safeSvgPicture('assets/svg/password_placeholder.svg');
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return _safeSvgPicture(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return
        ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.asset(imagePath, height: 80, width: 80, fit: BoxFit.cover));
    } else if (imagePath.startsWith("http")) {
      return Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white38
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.network(
              imagePath,
              width: 75,
              height: 75,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 75,
                  height: 75,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            )),
      );
    } else {
      return Platform.isWindows
          ? Image.asset(
        'assets/default.png',
        height: 75,
        width: 75,
      )
          :Image.file(
        File(imagePath),
        height: 80,
        width: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _safeSvgPicture('assets/svg/password_placeholder.svg'),
      );
    }
  }

  Widget _safeSvgPicture(String assetPath) {
    try {
      return ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: SvgPicture.asset(
            assetPath,
            height: 80,
            width: 80,
            placeholderBuilder: (context) => const Icon(Icons.image, size: 40),
          ));
    } catch (e) {
      debugPrint("FastKeyScreen: SVG Parsing Error: $e");
      return ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child:Image.asset('assets/default.png', height: 80, width: 80));
    }
  }

  // Build #1.0.104: updated delete dialog with this new implementation
  void _showDeleteConfirmationDialog({
    int? tabIndex,
    int? itemIndex,
  }) async {
    bool? result = await CustomDialog.showAreYouSure(
      context,
      confirm: () async {
        // This callback only runs if user confirms (clicks Yes)
        try {
          setState(() => _isDeleting = true);

          if (tabIndex != null) {
            final tab = fastKeyTabs[tabIndex];
            await _deleteFastKeyTab(fastKeyTabServerId: tab.fastkeyServerId);
          } else if (itemIndex != null) {
            final fastKeyTabItemServerId = fastKeyProductItems[itemIndex][AppDBConst.fastKeyProductId];
            await _deleteFastKeyTabItem(int.parse(fastKeyTabItemServerId));
            setState(() {
              enableIcons = false; // Build #1.0.204: Hide icons after deletion
              selectedItemIndex = null; // Clear selection
            });
          }
        } finally {
          if (mounted) {
            setState(() => _isDeleting = false);
          }
        }
      },
      isDeleting: _isDeleting,
    );

    // Only close the category dialog if deleting a tab AND user confirmed
    if (result == true && tabIndex != null && mounted) {
      Navigator.pop(context);
    }
  }
  /// No need : old pop up alert dialog
  // void _showDeleteConfirmationDialog(int index) {
  //   bool isDeleting = false;
  //   final tab = fastKeyTabs[index];
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setStateDialog) {
  //           return AlertDialog(
  //             title: const Text(TextConstants.deleteTabText),
  //             content: const Text(TextConstants.deleteConfirmText),
  //             actions: [
  //               TextButton(
  //                 onPressed: isDeleting ? null : () => Navigator.pop(context),
  //                 child: const Text(TextConstants.noText),
  //               ),
  //               TextButton(
  //                 onPressed: isDeleting
  //                     ? null
  //                     : () async {
  //                   setStateDialog(() => isDeleting = true);
  //                   await _deleteFastKeyTab(fastKeyTabServerId: tab.fastkeyServerId);
  //                   if (mounted) {
  //                     Navigator.pop(context);
  //                     Navigator.pop(context);
  //                   }
  //                 },
  //                 child: isDeleting
  //                     ? const CircularProgressIndicator()
  //                     : const Text(TextConstants.yesText, style: TextStyle(color: Colors.red)),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fastKeyBloc.dispose();
    orderBloc.dispose(); // Build 1.0.171
    _fastKeyProductBloc.dispose();
    _productSearchController.dispose();
    fastKeyTabIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = fastKeyTabs.map((tab) {
      return {
        'title': tab.fastkeyTitle,
        'image': tab.fastkeyImage,
        'itemCount': tab.itemCount,
      };
    }).toList();

    // Define showAddButton here to match the value passed to NestedGridWidget
    const bool showAddButton = true;

    return Scaffold(
      body: Column(
        children: [
          TopBar(
            screen: Screen.FASTKEY,
            onModeChanged: () async{ /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
                newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
              }

              // Update the notifier which will trigger _onLayoutChanged
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              // No need to call saveLayoutSelection here as it's handled in the notifier
              //   _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
              // update UI
              setState(() {});
            },
            onProductSelected: (product) async {
              if (kDebugMode) print("#### FastKey onProductSelected");
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
              // final serverOrderId = orderHelper.activeOrderId;//order[AppDBConst.orderServerId] as int?;
              // final dbOrderId = orderHelper.activeOrderId;
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
                //  if (serverOrderId != null) { ///Build #1.0.128: No need to check this condition
                if (kDebugMode) print("#### FastKey serverOrderId");
                _refreshOrderList();
                // } else {
                //   // await orderHelper.addItemToOrder(
                //   //   product.id,
                //   //   product.name ?? 'Unknown',
                //   //   product.images?.isNotEmpty == true ? product.images!.first : '',
                //   //   price,
                //   //   1,
                //   //   product.sku ?? '',
                //   //   onItemAdded: _createOrder,
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
                if(fastKeyTabs.isNotEmpty) await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId ?? fastKeyTabs[_selectedCategoryIndex ?? 0].fastkeyServerId);
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
                      CategoryList(
                        isHorizontal: true,
                        isLoading: isTabsLoading,
                        isAddButtonEnabled: true,
                        categories: categories,
                        selectedIndex: _selectedCategoryIndex,
                        editingIndex: _editingCategoryIndex,
                        onAddButtonPressed: () => _showCategoryDialog(context: context),
                        onCategoryTapped: (index) async {
                          // Prevent tapping the same category again
                          if (_selectedCategoryIndex == index) { // Build #1.0.254: Fixed - Disable double click on category tabs & fast key tabs
                            if (kDebugMode) {
                              print("### FastKeyScreen: Same category tapped, ignoring: $index");
                            }
                            return;
                          }
                          if (kDebugMode) {
                            print("### FastKeyScreen: onCategoryTapped called for index: $index, ID: ${fastKeyTabs[index].fastkeyServerId}");
                          }
                          //Build #1.0.68: updated
                          if (_editingCategoryIndex != index) {
                            setState(() {
                              _selectedCategoryIndex = index;
                              _editingCategoryIndex = null;
                              _fastKeyTabId = fastKeyTabs[index].fastkeyServerId;
                              fastKeyTabIdNotifier.value = _fastKeyTabId;
                            });
                            await fastKeyDBHelper.saveActiveFastKeyTab(fastKeyTabs[index].fastkeyServerId);
                            if (kDebugMode) { //Build #1.0.84
                              print("### FastKeyScreen: Saved active tab ID: ${fastKeyTabs[index].fastkeyServerId}");
                            }
                          } else {
                            setState(() {
                              _editingCategoryIndex = null;
                            });
                          }
                        },
                        onReorder: (oldIndex, newIndex) async {
                          if (kDebugMode) {
                            print("### FastKeyScreen: onReorder called from $oldIndex to $newIndex");
                          }
                          setState(() {
                            final item = fastKeyTabs.removeAt(oldIndex);
                            fastKeyTabs.insert(newIndex, item);
                            if (_selectedCategoryIndex == oldIndex) {
                              _selectedCategoryIndex = newIndex;
                            } else if (oldIndex < _selectedCategoryIndex! && newIndex >= _selectedCategoryIndex!) {
                              _selectedCategoryIndex = _selectedCategoryIndex! - 1;
                            } else if (oldIndex > _selectedCategoryIndex! && newIndex <= _selectedCategoryIndex!) {
                              _selectedCategoryIndex = _selectedCategoryIndex! + 1;
                            }
                            //Build 1.1.36: Update editingIndex to the new position
                            if (_editingCategoryIndex == oldIndex) {
                              _editingCategoryIndex = newIndex;
                            }
                            ///update the index in backend as well
                            _fastKeyBloc.updateFastKey(title: item.fastkeyTitle, index: newIndex+1, imageUrl: item.fastkeyImage, fastKeyServerId: item.fastkeyServerId, userId: item.userId);
                          });
                          // Update indices in the database
                          for (int i = 0; i < fastKeyTabs.length; i++) {
                            await fastKeyDBHelper.updateFastKeyTab(fastKeyTabs[i].fastkeyServerId, {
                              AppDBConst.fastKeyTabIndex: i.toString(),
                            });
                          }
                        },
                        onReorderStarted: (index) {
                          if (kDebugMode) {
                            print("### FastKeyScreen: onReorderStarted called for index: $index");
                          }
                          setState(() {
                            _editingCategoryIndex = index; // Set editing index for the item being reordered
                          });
                        },
                        onEditButtonPressed: (index) {
                          if (kDebugMode) {
                            print("### FastKeyScreen: onEditButtonPressed called for index: $index");
                          }
                          setState(() {
                            _editingCategoryIndex = index; // Set editing index for the item
                          });
                          _showCategoryDialog(context: context, index: index);
                        },
                        onDismissEditMode: () {
                          if (kDebugMode) {
                            print("### FastKeyScreen: onDismissEditMode called");
                          }
                          setState(() {
                            _editingCategoryIndex = null; // Clear editing index
                          });
                        },
                      ),
                      // In _FastKeyScreenState.build, modify the NestedGridWidget section
                      ValueListenableBuilder<int?>(
                        valueListenable: fastKeyTabIdNotifier,
                        builder: (context, fastKeyTabId, child) {
                          return fastKeyTabId != null //Build #1.0.68: updated
                              ? NestedGridWidget(
                            productBloc: productBloc,
                            orderHelper: orderHelper,
                            isHorizontal: true,
                            isLoading: isTabsLoading || isItemsLoading,
                            showAddButton: showAddButton,
                            items: fastKeyProductItems,
                            selectedItemIndex: selectedItemIndex,
                            reorderedIndices: reorderedIndices,
                            onAddButtonPressed: () => _showAddItemDialog(),
                            onItemTapped: (index, {bool? variantAdded}) => _onItemSelected(index, showAddButton, variantAdded!),
                            onReorder: (oldIndex, newIndex) {
                              if (oldIndex == 0 || newIndex == 0) return;
                              final adjustedOldIndex = oldIndex - 1;
                              final adjustedNewIndex = newIndex - 1;
                              if (adjustedOldIndex < 0 || adjustedNewIndex < 0 || adjustedOldIndex >= fastKeyProductItems.length || adjustedNewIndex >= fastKeyProductItems.length) {
                                return;
                              }
                              setState(() {
                                fastKeyProductItems = List<Map<String, dynamic>>.from(fastKeyProductItems);
                                final item = fastKeyProductItems.removeAt(adjustedOldIndex);
                                fastKeyProductItems.insert(adjustedNewIndex, item);
                                reorderedIndices = List.filled(fastKeyProductItems.length, null);
                                reorderedIndices[adjustedNewIndex] = adjustedNewIndex;
                                selectedItemIndex = adjustedNewIndex;
                              });
                              // Update database with new order
                              fastKeyDBHelper.updateFastKeyItemOrder(_fastKeyTabId!, fastKeyProductItems);
                            },
                            onDeleteItem: (index) {
                              // final itemId = fastKeyProductItems[index][AppDBConst.fastKeyProductId]; //Build #1.0.89
                              // if (kDebugMode) {
                              //   print('FastkeyScreen - Delete Fastkey item at index: $index, itemId: $itemId');
                              // }
                              // _deleteFastKeyTabItem(int.parse(itemId));
                              _showDeleteConfirmationDialog(itemIndex: index); // Build #1.0.104: updated delete dialog
                            },
                            // onCancelReorder: () {
                            //   setState(() {
                            //     reorderedIndices = List.filled(fastKeyProductItems.length, null);
                            //   });
                            // },
                            onCancelReorder: _onCancelReorder, // Build #1.0.204: Updated method
                            showBackButton: false,
                            enableIcons: enableIcons, // Build #1.0.204: Passing enableIcons
                            onLongPress: _onLongPress, // Passing onLongPress callback
                          )
                              : Container();
                          // : const Center(child: Text("Please select a category"));
                        },
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
                if (mounted) { //Build #1.0.54
                  setState(() {
                    _selectedSidebarIndex = index;
                  });
                }
              },
              isVertical: false,
            ),
        ],
      ),
    );
  }
}