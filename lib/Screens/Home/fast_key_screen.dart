<<<<<<< HEAD
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
=======
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
>>>>>>> origin/Grocery_pch_api_integration

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
<<<<<<< HEAD
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinaka_pos/Database/assets_db_helper.dart';
=======
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
>>>>>>> origin/Grocery_pch_api_integration
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
<<<<<<< HEAD
=======
import '../../Constants/misc_features.dart';
import '../../Database/isar_service.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Database/order_panel_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/auto_search.dart';
<<<<<<< HEAD
=======
import '../../Helper/customerdisplayhelper.dart';
import '../../Helper/url_helper.dart';
import '../../Providers/Age/age_verification_provider.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Utilities/global_utility.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Search/product_by_sku_model.dart' as SKU;
import '../../Models/Search/product_search_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
<<<<<<< HEAD
import '../../Utilities/textfield_search.dart';
=======
import '../../Utilities/svg_images_utility.dart';
import '../../Utilities/textfield_search.dart';
import '../../Widgets/weighing_scale_widget.dart';
import '../../Widgets/widget_logs_toast.dart';
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
import '../../Database/db_helper.dart';
=======
import '../../Utilities/svg_images_utility.dart';
import '../../Database/db_helper.dart';
import '../../Widgets/widget_variants_dialog.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../Auth/login_screen.dart';

class FastKeyScreen extends StatefulWidget {
  final int? lastSelectedIndex;

<<<<<<< HEAD
  const FastKeyScreen({super.key, this.lastSelectedIndex});
=======
  /// When true, only the center content is shown (no TopBar, NavBar, RightOrderPanel).
  /// Used by POSHomeScreen to embed in IndexedStack.
  final bool embedInShell;

  /// Called by TopBar after a product sync completes.
  static VoidCallback? onRefreshCompleted;

  const FastKeyScreen(
      {super.key, this.lastSelectedIndex, this.embedInShell = false});
>>>>>>> origin/Grocery_pch_api_integration

  @override
  State<FastKeyScreen> createState() => _FastKeyScreenState();
}

class _FastKeyScreenState extends State<FastKeyScreen>
    with WidgetsBindingObserver, LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 0;
<<<<<<< HEAD
  DateTime now = DateTime.now();
  List<int> quantities = [1, 1, 1, 1];
  // SidebarPosition sidebarPosition = SidebarPosition.left;
  // OrderPanelPosition orderPanelPosition = OrderPanelPosition.right;
  bool isLoading = true;

  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null);
=======
  List<int> quantities = [1, 1, 1, 1];
  bool isLoading = true;
  bool isBulkAdding = false;
  bool isimageLoading = false;

  final ValueNotifier<dynamic> fastKeyTabIdNotifier =
  ValueNotifier<dynamic>(null);
>>>>>>> origin/Grocery_pch_api_integration
  final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
  late FastKeyBloc _fastKeyBloc;
  List<FastKey> fastKeyTabs = [];
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
<<<<<<< HEAD
  int? userId;

  late FastKeyProductBloc _fastKeyProductBloc;
  List<Map<String, dynamic>> fastKeyProductItems = [];
  int? _fastKeyTabId;
  List<int?> reorderedIndices = [];
  int? selectedItemIndex;
  bool?
      enableIcons; // Build #1.0.204: Added this to track grid item delete/cancel icon visibility
=======
  bool _isPaginating = false;
  int? userId;

  bool _isRefreshing = false; // Add this flag
  bool _isLoadingItems = false;
  // ── PRODUCT META CACHE ─────────────────────────────────────────────────────
  static final Map<int, Map<String, dynamic>> _productMetaCache = {};

  static final Map<dynamic, List<Map<String, dynamic>>> _fastKeyItemsCache = {};

  static final Map<String, List<Map<String, dynamic>>> _fastKeyApiSearchCache =
  {};

  static int? _productMetaIdFromCacheMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final dynamic idRaw =
        m["fast_key_product_id"] ?? m["product_id"] ?? m["id"];
    if (idRaw is int) return idRaw;
    return int.tryParse(idRaw?.toString() ?? "");
  }

  /// Merges Indigo/Hive/Isar product caches into [_productMetaCache] for EBT/tags.
  static Future<void> _ingestProductMetaFromMerged() async {
    try {
      final allCached = await TopBar.mergedCachedProductsForSearch();
      for (final raw in allCached) {
        final pid = _productMetaIdFromCacheMap(raw);
        if (pid == null) continue;
        _productMetaCache[pid] = Map<String, dynamic>.from(raw as Map);
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Product meta ingest failed → $e");
      }
    }
  }

  late FastKeyProductBloc _fastKeyProductBloc;
  List<Map<String, dynamic>> fastKeyProductItems = [];
  dynamic _fastKeyTabId;
  List<int?> reorderedIndices = [];
  int? selectedItemIndex;
  bool?
  enableIcons; // Build #1.0.204: Added this to track grid item delete/cancel icon visibility
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
  final PinakaPreferences _preferences = PinakaPreferences(); // Add this
  StreamSubscription? _updateOrderSubscription;
  late OrderBloc orderBloc;
  bool isTabsLoading = true; //Build #1.0.68
  bool isItemsLoading = true;
  bool _isDeleting =
      false; // Build #1.0.104 : Track delete button loading state
  bool isAddingItemLoading = false; // Loader for adding items to order
  final ScrollController _scrollController = ScrollController();
  int _refreshCounter =
      0; //Build #1.0.170: Added: Counter to trigger RightOrderPanel refresh only when needed
=======
  final PinakaPreferences _preferences = PinakaPreferences();
  StreamSubscription? _updateOrderSubscription;
  late OrderBloc orderBloc;
  bool isTabsLoading = true;
  bool isItemsLoading = true;
  bool _isDeleting = false;
  bool isAddingItemLoading = false;
  final ScrollController _scrollController = ScrollController();
  int _refreshCounter = 0;
>>>>>>> origin/Grocery_pch_api_integration

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

<<<<<<< HEAD
    //Build #1.0.84: Initialize user ID and load tabs sequentially
    // getUserIdFromDB().then((_) {
    //   if (kDebugMode) {
    //     print("### FastKeyScreen: initState - User ID fetched, loading active tab");
    //   }
    ///   _loadActiveFastKeyTabId(); // Don't need here , we are already calling inside getUserIdFromDB -> loadTabs -> _loadActiveFastKeyTabId
    // });
    _initializeData(); // Build #1.0.200: Code Updated for issue: Empty fastkey folders show at first logon to multiple fastkeys loaded on created by the user
    fastKeyTabIdNotifier.addListener(_onTabChanged);
=======
    _initializeData();
    fastKeyTabIdNotifier.addListener(_onTabChanged);

    // Listen to product cache revision changes
    TopBar.mergedProductCacheRevision
        .addListener(_onMergedProductCacheRevision);

    TopBar.onRefreshCompleted = () async {
      if (!mounted) return;

      debugPrint("🔄 FastKeyScreen: Refreshing after TopBar sync");

      // Add a flag to prevent multiple simultaneous refreshes
      if (_isRefreshing) return;
      _isRefreshing = true;

      try {
        setState(() => isItemsLoading = true);

        // Clear all in-memory caches
        _productMetaCache.clear();
        NestedGridWidget.clearProductMetaCache();
        _clearFastKeyCache(); // Clear ALL tab caches

        // Re-ingest product meta from updated Isar/Hive
        await _ingestProductMetaFromMerged();

        // Force reload from DB (not from cache) - ONLY ONCE
        if (_fastKeyTabId != null) {
          _fastKeyItemsCache.remove(_fastKeyTabId);
          await _loadFastKeyTabItems();

          //  NEW: Ensure SQLite FastKey items get latest product data
          await fastKeyDBHelper.refreshFastKeyItemMetadata(_fastKeyTabId!);
        }

        // Refresh tab list (item counts may have changed)
        await _loadFastKeysTabs();
        await _resolveFastKeyMeta();

        setState(() => isItemsLoading = false);
        debugPrint("✅ FastKeyScreen: Refresh complete");
      } finally {
        _isRefreshing = false;
      }
    };
>>>>>>> origin/Grocery_pch_api_integration
  }

  Future<void> _initializeData() async {
    try {
      await getUserIdFromDB();
      if (kDebugMode) {
        print("### FastKeyScreen: _initializeData - User ID fetched");
      }
    } catch (e) {
      if (kDebugMode) print("Initialization error: $e");
<<<<<<< HEAD
=======
      if (mounted) {
        setState(() => isTabsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Fast Keys: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
>>>>>>> origin/Grocery_pch_api_integration
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
<<<<<<< HEAD
    //Build #1.0.84, Explanation:
    // Only call _loadActiveFastKeyTabId if _fastKeyTabId is null and tabs exist, preventing override of an already selected tab.
    // This ensures state retention when navigating back to the screen.
=======
>>>>>>> origin/Grocery_pch_api_integration
    if (kDebugMode) {
      print(
          "### FastKeyScreen: didChangeDependencies called, _fastKeyTabId: $_fastKeyTabId");
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
<<<<<<< HEAD
      enableIcons = true; // Show icons
      selectedItemIndex = itemIndex; // Track the long-pressed item
=======
      enableIcons = true;
      selectedItemIndex = itemIndex;
>>>>>>> origin/Grocery_pch_api_integration
    });
  }

  void _onCancelReorder() {
    // Build #1.0.204
    setState(() {
      reorderedIndices = List.filled(fastKeyProductItems.length, null);
<<<<<<< HEAD
      enableIcons = false; // Hide icons
      selectedItemIndex = null; // Clear selection
=======
      enableIcons = false;
      selectedItemIndex = null;
>>>>>>> origin/Grocery_pch_api_integration
    });
  }

  void _listenProductItemSearch() {
<<<<<<< HEAD
    if (_productSearchController.text.isEmpty) {
=======
    final t = _productSearchController.text.trim();
    if (t.isEmpty || t.length < 3) {
>>>>>>> origin/Grocery_pch_api_integration
      _searchTextGridKey.currentState?.resetList();
    }
    _autoSuggest.listentextchange(_productSearchController.text ?? "");
  }

<<<<<<< HEAD
=======
// ── REPLACE _onTabChanged ────────────────────────────────────────────────────
>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _onTabChanged() async {
    if (kDebugMode) {
      print(
          "### FastKeyScreen: _onTabChanged: New Tab ID: ${fastKeyTabIdNotifier.value}");
    }
<<<<<<< HEAD
    setState(() {
      _fastKeyTabId = fastKeyTabIdNotifier.value;
      fastKeyProductItems.clear();
      isItemsLoading =
          true; //Build #1.0.92: Fixed Issue: Loader is not working at fast key grid for selected tab
    });
    if (_fastKeyTabId != null) {
      //Build #1.0.84
=======

    final newTabId = fastKeyTabIdNotifier.value;

    // ✅ FIX: If the tab's items are already in memory, swap instantly — no
    //         loading state, no flicker, no extra DB/API call.
    if (newTabId != null && _fastKeyItemsCache.containsKey(newTabId)) {
      if (kDebugMode) {
        print("⚡ _onTabChanged: instant swap from cache for tab $newTabId");
      }
      if (mounted) {
        setState(() {
          _fastKeyTabId = newTabId;
          fastKeyProductItems =
          List<Map<String, dynamic>>.from(_fastKeyItemsCache[newTabId]!);
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false; // never show spinner for cached tabs
        });
      }
      await fastKeyDBHelper.saveActiveFastKeyTab(newTabId);
      await _loadFastKeyTabItems();
      await _resolveFastKeyMeta();
      return;
    }

    // Cache miss — show loading only when we truly have to fetch
    setState(() {
      _fastKeyTabId = newTabId;
      fastKeyProductItems.clear();
      isItemsLoading = true;
    });

    if (_fastKeyTabId != null) {
>>>>>>> origin/Grocery_pch_api_integration
      await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId!);
      if (kDebugMode) {
        print(
            "### FastKeyScreen: Saved active tab ID in _onTabChanged: $_fastKeyTabId");
      }
      await _loadFastKeyTabItems();
<<<<<<< HEAD
    }
  }

=======
      await _resolveFastKeyMeta();
    } else if (mounted) {
      setState(() => isItemsLoading = false);
    }
  }

  /// Align Fast Keys with TopBar's merged Isar/Hive read so EBT resolves on first paint.
  Future<void> _awaitMergedProductCacheReadyForFastKeys() async {
    try {
      await TopBar.waitForFirstMergedProductCacheReload()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  bool _pendingMergedMetaRefresh = false;

  void _onMergedProductCacheRevision() {
    if (_pendingMergedMetaRefresh) return;
    _pendingMergedMetaRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pendingMergedMetaRefresh = false;
      if (!mounted || _fastKeyTabId == null) return;

      debugPrint("🔄 FastKeyScreen: Product cache revision changed");

      setState(() => isItemsLoading = true);

      _clearFastKeyCache(tabId: _fastKeyTabId);
      _productMetaCache.clear();
      NestedGridWidget.clearProductMetaCache();

      // Remove the redundant calls and keep only one clean refresh
      await _loadFastKeyTabItems();

      // Only call this if metadata needs refreshing
      await fastKeyDBHelper.refreshFastKeyItemMetadata(_fastKeyTabId!);

      if (!mounted) return;
      await _resolveFastKeyMeta();

      setState(() => isItemsLoading = false);
    });
  }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> getUserIdFromDB() async {
    try {
      final userData = await UserDbHelper().getUserData();
      if (userData != null && userData[AppDBConst.userId] != null) {
<<<<<<< HEAD
        userId = userData[AppDBConst.userId] as int;

        ///stop loading fast key every time
=======
        final rawUserId = userData[AppDBConst.userId];
        userId = rawUserId is num
            ? rawUserId.toInt()
            : int.tryParse(rawUserId.toString());
        if (userId == null) {
          throw FormatException('The logged-in user ID is invalid.');
        }

>>>>>>> origin/Grocery_pch_api_integration
        if (kDebugMode) {
          print(
              "FastKeyScreen.getUserIdFromDB -> FastKeyDBHelper.isFastkeyLoaded = ${FastKeyDBHelper.isFastkeyLoaded}");
        }
<<<<<<< HEAD
        if (FastKeyDBHelper.isFastkeyLoaded) {
          loadTabs();
          return;
        }
        _fastKeyBloc.fetchFastKeysByUser(userId ?? 0);
=======
        _fastKeyBloc.fetchFastKeysByUser(userId!);
>>>>>>> origin/Grocery_pch_api_integration
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
            } else {
<<<<<<< HEAD
              _fastKeyBloc.getFastKeysSink
                  .add(APIResponse.error(TextConstants.retryText));
=======
              if (kDebugMode) {
                print(
                    "FastKey offline / error -> Loading cached tabs from local database");
              }
              await loadTabs();
              FastKeyDBHelper.isFastkeyLoaded = true;
>>>>>>> origin/Grocery_pch_api_integration
            }
          } else if (onData.status == Status.COMPLETED) {
            if (onData.data != null) {
              final fastKeysResponse = onData.data!;
              if (fastKeysResponse.status != "success") {
<<<<<<< HEAD
                _fastKeyBloc.getFastKeysSink
                    .add(APIResponse.error(TextConstants.retryText));
              }
              await loadTabs(); // Build  #1.0.177: add await to loadTabs to fix delay in loading
              FastKeyDBHelper.isFastkeyLoaded = true;
=======
                await loadTabs();
                FastKeyDBHelper.isFastkeyLoaded = true;
              } else {
                await loadTabs();
                FastKeyDBHelper.isFastkeyLoaded = true;
              }
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
  //Build #1.0.84, Explanation:
  // Call _loadActiveFastKeyTabId after loading tabs to ensure the active tab is set once fastKeyTabs is populated.
  // Update isTabsLoading to reflect the loading state and trigger a UI refresh.
  Future<void> loadTabs() async {
    // Build  #1.0.177: add await to loadTabs to fix delay in loading
=======
  // Add this method to _FastKeyScreenState (mirrors TopBar's version)
  // Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(int productId) async {
  //   try {
  //     final db = await DBHelper.instance.database;
  //     final result = await db.query(
  //       AppDBConst.userTable,
  //       where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
  //       orderBy: '${AppDBConst.userId} DESC',
  //       limit: 1,
  //     );
  //     if (result.isEmpty) return <Map<String, dynamic>>[];
  //     final token = result.first[AppDBConst.userToken] as String;
  //
  //     final url = Uri.parse(
  //         "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations");
  //     final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
  //
  //     if (kDebugMode) {
  //       print("🌍 [FastKey Variations API] status: ${response.statusCode}");
  //     }
  //     if (response.statusCode != 200) return <Map<String, dynamic>>[];
  //
  //     final decoded = jsonDecode(response.body);
  //     if (decoded is! List) return <Map<String, dynamic>>[];
  //
  //     return decoded.whereType<Map>().map<Map<String, dynamic>>((v) {
  //       final map = v.map((key, value) => MapEntry(key.toString(), value));
  //       final attrs = map["attributes"];
  //       final String fallbackName = attrs is List
  //           ? attrs.whereType<Map>().map((a) => (a["option"] ?? "").toString())
  //           .where((x) => x.isNotEmpty).join(" - ")
  //           : "";
  //       final List<Map<String, dynamic>> metaData = (map["meta_data"] is List)
  //           ? (map["meta_data"] as List).whereType<Map>()
  //           .map((m) => Map<String, dynamic>.from(m)).toList()
  //           : <Map<String, dynamic>>[];
  //
  //       if (kDebugMode) {
  //         final loyalty = metaData.firstWhere(
  //               (m) => m['key'] == '_product_loyalty_points',
  //           orElse: () => <String, dynamic>{},
  //         );
  //         print("🔹 [FastKey Variations] id=${map['id']} loyalty=${loyalty['value']}");
  //       }
  //
  //       return {
  //         "id": map["id"],
  //         "name": (map["name"] ?? "").toString().isNotEmpty
  //             ? map["name"] : (fallbackName.isNotEmpty ? fallbackName : "Unnamed Variant"),
  //         "price": (map["price"] ?? map["regular_price"] ?? "0").toString(),
  //         "sku": map["sku"] ?? "",
  //         "image": (map["image"] is Map && map["image"]["src"] != null)
  //             ? map["image"]["src"] : (map["image"] is String ? map["image"] : ""),
  //         "meta_data": metaData,
  //       };
  //     }).where((v) => v["id"] != null).toList();
  //   } catch (e) {
  //     if (kDebugMode) print("❌ [FastKey Variations API] error: $e");
  //     return <Map<String, dynamic>>[];
  //   }
  // }

  // Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(int productId) async {
  //   try {
  //     final db = await DBHelper.instance.database;
  //     final result = await db.query(
  //       AppDBConst.userTable,
  //       where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
  //       orderBy: '${AppDBConst.userId} DESC',
  //       limit: 1,
  //     );
  //     if (result.isEmpty) return <Map<String, dynamic>>[];
  //     final token = result.first[AppDBConst.userToken] as String;
  //
  //     final url = Uri.parse(
  //         "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations");
  //     final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
  //
  //     if (kDebugMode) {
  //       print("🌍 [FastKey Variations API] status: ${response.statusCode}");
  //     }
  //     if (response.statusCode != 200) return <Map<String, dynamic>>[];
  //
  //     final decoded = jsonDecode(response.body);
  //     if (decoded is! List) return <Map<String, dynamic>>[];
  //
  //     return decoded.whereType<Map>().map<Map<String, dynamic>>((v) {
  //       final map = v.map((key, value) => MapEntry(key.toString(), value));
  //       final attrs = map["attributes"];
  //       final String fallbackName = attrs is List
  //           ? attrs.whereType<Map>().map((a) => (a["option"] ?? "").toString())
  //           .where((x) => x.isNotEmpty).join(" - ")
  //           : "";
  //
  //       // ✅ CRITICAL: Extract meta_data from the variant
  //       final List<Map<String, dynamic>> metaData = (map["meta_data"] is List)
  //           ? (map["meta_data"] as List).whereType<Map>()
  //           .map((m) => Map<String, dynamic>.from(m)).toList()
  //           : <Map<String, dynamic>>[];
  //
  //       // ✅ Extract loyalty points from meta_data
  //       final loyaltyEntry = metaData.firstWhere(
  //             (m) => m['key'] == '_product_loyalty_points',
  //         orElse: () => <String, dynamic>{},
  //       );
  //       final int loyaltyPoints = loyaltyEntry.isNotEmpty
  //           ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
  //           : 0;
  //
  //       if (kDebugMode) {
  //         print("🔹 [FastKey Variations API] id=${map['id']} loyalty=$loyaltyPoints metaCount=${metaData.length}");
  //       }
  //
  //       return {
  //         "id": map["id"],
  //         "name": (map["name"] ?? "").toString().isNotEmpty
  //             ? map["name"] : (fallbackName.isNotEmpty ? fallbackName : "Unnamed Variant"),
  //         "price": (map["price"] ?? map["regular_price"] ?? "0").toString(),
  //         "sku": map["sku"] ?? "",
  //         "image": (map["image"] is Map && map["image"]["src"] != null)
  //             ? map["image"]["src"] : (map["image"] is String ? map["image"] : ""),
  //         "meta_data": metaData,  // ✅ Store meta_data in cached variant
  //         "loyalty_points": loyaltyPoints,  // ✅ Store loyalty points directly for quick access
  //       };
  //     }).where((v) => v["id"] != null).toList();
  //   } catch (e) {
  //     if (kDebugMode) print(" [FastKey Variations API] error: $e");
  //     return <Map<String, dynamic>>[];
  //   }
  // }

  Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(
      int productId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        AppDBConst.userTable,
        where:
        '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );
      if (result.isEmpty) return <Map<String, dynamic>>[];
      final token = result.first[AppDBConst.userToken] as String;

      // Connector: GET /store/{storeId}/products/{productId}/variations
      final urlString =
      await ProductRepository.buildVariationsUrl(productId);
      final url = Uri.parse(urlString);
      final response =
      await http.get(url, headers: {"Authorization": "Bearer $token"});

      if (kDebugMode) {
        print("🌍 [FastKey Variations API] status: ${response.statusCode}");
      }
      if (response.statusCode != 200) return <Map<String, dynamic>>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return <Map<String, dynamic>>[];

      return decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>((v) {
        final map = v.map((key, value) => MapEntry(key.toString(), value));
        final attrs = map["attributes"];
        final String fallbackName = attrs is List
            ? attrs
            .whereType<Map>()
            .map((a) => (a["option"] ?? "").toString())
            .where((x) => x.isNotEmpty)
            .join(" - ")
            : "";

        // ✅ CRITICAL: Extract meta_data from the variant
        final List<Map<String, dynamic>> metaData =
        (map["meta_data"] is List)
            ? (map["meta_data"] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
            : <Map<String, dynamic>>[];

        // ✅ Extract loyalty points from meta_data
        final loyaltyEntry = metaData.firstWhere(
              (m) => m['key'] == '_product_loyalty_points',
          orElse: () => <String, dynamic>{},
        );
        final int loyaltyPoints = loyaltyEntry.isNotEmpty
            ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
            : 0;

        if (kDebugMode) {
          print(
              "🔹 [FastKey Variations API] id=${map['id']} loyalty=$loyaltyPoints metaCount=${metaData.length}");
        }

        return {
          "id": map["id"],
          "name": (map["name"] ?? "").toString().isNotEmpty
              ? map["name"]
              : (fallbackName.isNotEmpty
              ? fallbackName
              : "Unnamed Variant"),
          "price": (map["price"] ?? map["regular_price"] ?? "0").toString(),
          "sku": map["sku"] ?? "",
          "image": (map["image"] is Map && map["image"]["src"] != null)
              ? map["image"]["src"]
              : (map["image"] is String ? map["image"] : ""),
          "meta_data": metaData, // ✅ Store meta_data in cached variant
          "loyalty_points":
          loyaltyPoints, // ✅ Store loyalty points directly for quick access
        };
      })
          .where((v) => v["id"] != null)
          .toList();
    } catch (e) {
      if (kDebugMode) print(" [FastKey Variations API] error: $e");
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> loadTabs() async {
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
    await _loadActiveFastKeyTabId(); // Ensure active tab is loaded after tabs
  }

  //Build #1.0.84, Explanation:
  // Since _loadActiveFastKeyTabId already handles tab selection and persistence, _loadLastSelectedTab can simply call it to avoid code duplication.
  // This ensures consistent state management.
=======
    await _loadActiveFastKeyTabId();
  }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _loadLastSelectedTab() async {
    if (kDebugMode) {
      print("### FastKeyScreen: _loadLastSelectedTab called");
    }
<<<<<<< HEAD
    // No need to duplicate logic; rely on _loadActiveFastKeyTabId
=======
>>>>>>> origin/Grocery_pch_api_integration
    await _loadActiveFastKeyTabId();
  }

  Future<void> _loadFastKeysTabs() async {
    final fastKeyTabsData =
<<<<<<< HEAD
        await fastKeyDBHelper.getFastKeyTabsByUserId(userId ?? 1);
=======
    await fastKeyDBHelper.getFastKeyTabsByUserId(userId ?? 1);
>>>>>>> origin/Grocery_pch_api_integration
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
            fastkeyIndex:
<<<<<<< HEAD
                product[AppDBConst.fastKeyTabIndex]?.toString() ?? '0',
            itemCount: int.tryParse(
                    product[AppDBConst.fastKeyTabItemCount]?.toString() ??
                        '0') ??
=======
            product[AppDBConst.fastKeyTabIndex]?.toString() ?? '0',
            itemCount: int.tryParse(
                product[AppDBConst.fastKeyTabItemCount]?.toString() ??
                    '0') ??
>>>>>>> origin/Grocery_pch_api_integration
                0,
          );
        }).toList();
      });
    }
  }

  // Build #1.0.87: code updated , db handing inside bloc only, remove here
  Future<void> _addFastKeyTab(String title, String image) async {
<<<<<<< HEAD
    if (kDebugMode) {
      print(
          "### FastKeyScreen: _addFastKeyTab started with title: $title, image: $image");
    }
    // Call API to create FastKey on server via BLoC
    _fastKeyBloc.createFastKey(
        title: title,
        index: fastKeyTabs.length + 1,
        imageUrl: image,
        userId: userId ?? 1);

    // Listen for API response
    final response = await _fastKeyBloc.createFastKeyStream.firstWhere(
        (response) =>
            response.status == Status.COMPLETED ||
=======
    //Build #1.0.279: Fixed Issue - after creating fastkey it is showing default icon
    String imageToSend = image;
    if (image.startsWith('assets/')) {
      imageToSend = '';
    }

    if (kDebugMode) {
      print(
          "### FastKeyScreen: _addFastKeyTab started with title: $title, image: $imageToSend");
    }
    _fastKeyBloc.createFastKey(
        title: title,
        index: fastKeyTabs.length + 1,
        imageUrl: imageToSend,
        userId: userId ?? 1);

    final response = await _fastKeyBloc.createFastKeyStream.firstWhere(
            (response) =>
        response.status == Status.COMPLETED ||
>>>>>>> origin/Grocery_pch_api_integration
            response.status == Status.ERROR);
    if (response.status == Status.COMPLETED && response.data != null) {
      if (kDebugMode) {
        print(
            "### FastKeyScreen: API createFastKey success, server ID: ${response.data!.fastkeyId}");
      }
<<<<<<< HEAD
      // Update UI with new tab (BLoC handles DB insertion)
=======
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
        _fastKeyTabId = response.data!.fastkeyId; // Use server ID
=======
        _fastKeyTabId = response.data!.fastkeyId;
>>>>>>> origin/Grocery_pch_api_integration
        fastKeyTabIdNotifier.value = response.data!.fastkeyId;
        if (kDebugMode) {
          print(
              "### FastKeyScreen: Updated UI, selected tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      });
    } else if (response.status == Status.ERROR) {
<<<<<<< HEAD
      // Build #1.0.189: Only Show when it comes response as error
=======
>>>>>>> origin/Grocery_pch_api_integration
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
                content:
<<<<<<< HEAD
                    Text("Unauthorised. Session is expired on this device."),
=======
                Text("Unauthorised. Session is expired on this device."),
>>>>>>> origin/Grocery_pch_api_integration
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
<<<<<<< HEAD
        // Handle API error
=======
>>>>>>> origin/Grocery_pch_api_integration
        if (kDebugMode) {
          print(
              "### FastKeyScreen: API createFastKey failed: ${response.message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
<<<<<<< HEAD
                Text(response.message ?? TextConstants.failedToCreateFastKey),
            // Build #1.0.189: Updated from api response - Proper error not showing while getting error in create fast key
=======
            Text(response.message ?? TextConstants.failedToCreateFastKey),
>>>>>>> origin/Grocery_pch_api_integration
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

<<<<<<< HEAD
  Future<void> _deleteFastKeyTab({required int fastKeyTabServerId}) async {
=======
  Future<void> _deleteFastKeyTab({required dynamic fastKeyTabServerId}) async {
>>>>>>> origin/Grocery_pch_api_integration
    if (kDebugMode) {
      print(
          "### FastKeyScreen: _deleteFastKeyTab started with server ID: $fastKeyTabServerId");
    }
<<<<<<< HEAD
    _fastKeyBloc.deleteFastKey(fastKeyTabServerId, userId ?? 1);

    setState(() {
      fastKeyTabs
          .removeWhere((tab) => tab.fastkeyServerId == fastKeyTabServerId);
      if (_selectedCategoryIndex != null) {
        if (_selectedCategoryIndex! >= fastKeyTabs.length) {
          _selectedCategoryIndex =
              fastKeyTabs.isNotEmpty ? fastKeyTabs.length - 1 : null;
          _fastKeyTabId = _selectedCategoryIndex != null
              ? fastKeyTabs[_selectedCategoryIndex!].fastkeyServerId
              : null;
          fastKeyTabIdNotifier.value = _fastKeyTabId;
        }
      }
      _editingCategoryIndex = null; //Build 1.1.36: Clear edit mode
      if (kDebugMode) {
        print(
            "### FastKeyScreen: Updated UI after tab deletion, new tab count: ${fastKeyTabs.length}");
      }
    });

    await _fastKeyBloc.deleteFastKeyStream
        .firstWhere((response) =>
            response.status == Status.COMPLETED ||
            response.status == Status.ERROR)
        .then((response) async {
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
                  content:
                      Text("Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        } else {
          if (kDebugMode) {
            print(
                "### FastKeyScreen: API deleteFastKey failed: ${response.message}");
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
=======
    final deletedIndex = fastKeyTabs.indexWhere(
          (tab) => tab.fastkeyServerId.toString() == fastKeyTabServerId.toString(),
    );
    final selectedTabId = _fastKeyTabId;
    final resultFuture = _fastKeyBloc.deleteFastKeyStream.firstWhere(
          (response) =>
      response.status == Status.COMPLETED ||
          response.status == Status.ERROR,
    );
    await _fastKeyBloc.deleteFastKey(fastKeyTabServerId, userId ?? 1);
    final response = await resultFuture;

    if (response.status == Status.ERROR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to delete Fast Key.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (response.message?.contains('Unauthorised') ?? false) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      }
      return;
    }

    _clearFastKeyCache(tabId: fastKeyTabServerId);
    await _loadFastKeysTabs();
    if (!mounted) return;

    if (selectedTabId?.toString() == fastKeyTabServerId.toString()) {
      if (fastKeyTabs.isEmpty) {
        setState(() {
          _selectedCategoryIndex = null;
          _fastKeyTabId = null;
          fastKeyProductItems.clear();
          _editingCategoryIndex = null;
        });
        fastKeyTabIdNotifier.value = null;
        await fastKeyDBHelper.saveActiveFastKeyTab(null);
      } else {
        final newIndex = (deletedIndex < 0 ? 0 : deletedIndex)
            .clamp(0, fastKeyTabs.length - 1);
        final nextTabId = fastKeyTabs[newIndex].fastkeyServerId;
        setState(() {
          _selectedCategoryIndex = newIndex;
          _fastKeyTabId = nextTabId;
          fastKeyProductItems.clear();
          isItemsLoading = true;
          _editingCategoryIndex = null;
        });
        fastKeyTabIdNotifier.value = nextTabId;
        await fastKeyDBHelper.saveActiveFastKeyTab(nextTabId);
      }
    } else {
      setState(() {
        _selectedCategoryIndex = fastKeyTabs.indexWhere(
              (tab) => tab.fastkeyServerId.toString() == selectedTabId.toString(),
        );
        _editingCategoryIndex = null;
      });
    }
  }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _loadActiveFastKeyTabId() async {
    if (kDebugMode) {
      print("### FastKeyScreen: _loadActiveFastKeyTabId called");
    }
    final lastSelectedTabId = await fastKeyDBHelper.getActiveFastKeyTab();
    if (kDebugMode) {
      print(
          "### FastKeyScreen: Last selected tab ID from SharedPreferences: $lastSelectedTabId");
    }

    setState(() {
      if (lastSelectedTabId != null &&
<<<<<<< HEAD
          fastKeyTabs.any((tab) => tab.fastkeyServerId == lastSelectedTabId)) {
        _selectedCategoryIndex = fastKeyTabs
            .indexWhere((tab) => tab.fastkeyServerId == lastSelectedTabId);
=======
          fastKeyTabs.any((tab) =>
          tab.fastkeyServerId.toString() == lastSelectedTabId.toString())) {
        _selectedCategoryIndex = fastKeyTabs.indexWhere((tab) =>
        tab.fastkeyServerId.toString() == lastSelectedTabId.toString());
>>>>>>> origin/Grocery_pch_api_integration
        _fastKeyTabId = lastSelectedTabId;
        if (kDebugMode) {
          print(
              "### FastKeyScreen: Restored tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      } else if (fastKeyTabs.isNotEmpty) {
        _selectedCategoryIndex = 0;
        _fastKeyTabId = fastKeyTabs[0].fastkeyServerId;
<<<<<<< HEAD
        fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId); // Save default tab
=======
        fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId);
>>>>>>> origin/Grocery_pch_api_integration
        if (kDebugMode) {
          print(
              "### FastKeyScreen: No valid last tab, defaulting to first tab ID: $_fastKeyTabId");
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
<<<<<<< HEAD
    }
  }

  Future<void> _loadFastKeyTabItems() async {
    if (kDebugMode) {
      print("FastKey Screen _loadFastKeyTabItems $_fastKeyTabId");
    }
    if (_fastKeyTabId == null) {
      setState(() {
        //Build #1.0.68
        isItemsLoading = false;
      });
      return;
    }
    if (FastKeyDBHelper.isFastkeyLoaded) {
      ///stops loading every time
      final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
      if (kDebugMode) {
        print(
            "FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = List<Map<String, dynamic>>.from(items);
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
=======
      await _resolveFastKeyMeta();
    } else if (mounted) {
      setState(() => isItemsLoading = false);
    }
  }

  // ── REPLACE _loadFastKeyTabItems ─────────────────────────────────────────────
  Future<void> _loadFastKeyTabItems() async {
    if (_fastKeyTabId == null) {
      setState(() => isItemsLoading = false);
      return;
    }

    // ── 1. In-memory cache (instant, no spinner) ───────────────────────────
    if (_fastKeyItemsCache.containsKey(_fastKeyTabId!)) {
      if (kDebugMode) {
        print(
            "⚡ FastKeyScreen: Loading from IN-MEMORY CACHE for tab $_fastKeyTabId");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = List<Map<String, dynamic>>.from(
              _fastKeyItemsCache[_fastKeyTabId!]!);
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false; // ✅ never flicker for cached data
        });
      }
      _resolveFastKeyMeta(); // background refresh, non-blocking
      // Continue to the API below so server-side removals are reflected.
    }

    // ── 2. Cache miss → show spinner, then try local DB ────────────────────
    //    (isItemsLoading is already true when we reach here from _onTabChanged)
    await _awaitMergedProductCacheReadyForFastKeys();

    final cachedItems = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);

    if (cachedItems.isNotEmpty) {
      if (kDebugMode) {
        print("✅ Loading FastKey items from LOCAL DB CACHE");
      }

      final preparedItems = await _prepareFastKeyItemsForInitialUi(cachedItems);

      // Store in memory so next switch is instant
      _fastKeyItemsCache[_fastKeyTabId!] =
      List<Map<String, dynamic>>.from(preparedItems);

      if (mounted) {
        setState(() {
          fastKeyProductItems = preparedItems;
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      }
      // Continue to the API below; an empty server list must clear this cached list.
    }

    // ── 3. Refresh from API and reconcile local cache ───────────────────────
    if (kDebugMode) {
      print("Cache miss → Fetching FastKey items from API ");
    }

    final tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId!);
    if (tabs.isEmpty) {
      if (mounted) {
        setState(() {
          fastKeyProductItems = [];
>>>>>>> origin/Grocery_pch_api_integration
          isItemsLoading = false;
        });
      }
      return;
    }

<<<<<<< HEAD
    var tabs =
        await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) {
      setState(() {
        fastKeyProductItems = [];
        isItemsLoading = false;
      });
      if (kDebugMode) {
        print(
            "FastKey Screen _loadFastKeyTabItems selected tab is empty: ${tabs.length}");
      }
      return;
    }
    fastKeyProductItems.clear(); //Build #1.0.78: Clear existing items
    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    if (kDebugMode) {
      print(
          "FastKey Screen _loadFastKeyTabItems selected tab server id: $fastKeyServerId");
    }
    await _fastKeyProductBloc
        .fetchProductsByFastKeyId(_fastKeyTabId ?? 1, fastKeyServerId)
        .whenComplete(() async {
      final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
      if (kDebugMode) {
        print(
            "FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
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
=======
    final fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    final fetchResultFuture = _fastKeyProductBloc.getProductsStream.firstWhere(
          (response) =>
      response.status == Status.COMPLETED ||
          response.status == Status.ERROR,
    );
    await _fastKeyProductBloc.fetchProductsByFastKeyId(
      _fastKeyTabId,
      fastKeyServerId,
    );
    final fetchResult = await fetchResultFuture;
    if (fetchResult.status == Status.ERROR) {
      if (mounted) {
        setState(() => isItemsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                fetchResult.message ?? 'Unable to refresh Fast Key products.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final apiItems = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
    final preparedItems = await _prepareFastKeyItemsForInitialUi(apiItems);

    // Store in memory so every subsequent switch is instant
    _fastKeyItemsCache[_fastKeyTabId!] =
    List<Map<String, dynamic>>.from(preparedItems);

    if (mounted) {
      setState(() {
        fastKeyProductItems = preparedItems;
        reorderedIndices = List.filled(fastKeyProductItems.length, null);
        isItemsLoading = false;
      });
    }
  }

  void _clearFastKeyCache({dynamic tabId}) {
    if (tabId != null) {
      _fastKeyItemsCache.remove(tabId);
      if (kDebugMode) print("🧹 Cleared FastKey cache for tab: $tabId");
    } else {
      _fastKeyItemsCache.clear();
      if (kDebugMode) print("🧹 Cleared ALL FastKey caches");
    }
  }

  // Future<List<Map<String, dynamic>>> _prepareFastKeyItemsForInitialUi(
  //     List<Map<String, dynamic>> items) async {
  //   await _ingestProductMetaFromMerged();
  //   final List<Map<String, dynamic>> prepared = [];
  //
  //   for (final raw in items) {
  //     final item = Map<String, dynamic>.from(raw);
  //     final tagsCol = item["fast_key_item_tags"];
  //     if (tagsCol is String && tagsCol.isNotEmpty) {
  //       try {
  //         final decoded = jsonDecode(tagsCol);
  //         if (decoded is List) {
  //           item["fast_key_item_tags"] = decoded;
  //         }
  //       } catch (_) {}
  //     }
  //     final int? productId =
  //     int.tryParse(item["fast_key_product_id"]?.toString() ?? "");
  //
  //     await _enrichFastKeyItemFromSkuHive(item);
  //
  //     final cached =
  //     productId != null ? await _getCachedProductFromIsar(productId) : null;
  //
  //     item["has_variants"] = await _fastKeyHasVariants(item);
  //
  //     final isEbt = _isProductEbtEligible({
  //       "is_ebt_eligible": item["is_ebt_eligible"] ?? cached?["is_ebt_eligible"],
  //       "meta_data": item["meta_data"] ?? cached?["meta_data"],
  //       "fast_key_item_tags": item["fast_key_item_tags"] ?? cached?["tags"],
  //       "tags": cached?["tags"],
  //     });
  //     item["is_ebt_eligible"] = isEbt;
  //     if (item["meta_data"] == null &&
  //         cached != null &&
  //         cached["meta_data"] != null) {
  //       item["meta_data"] = cached["meta_data"];
  //     }
  //
  //     prepared.add(item);
  //   }
  //
  //   return prepared;
  // }

  Future<List<Map<String, dynamic>>> _prepareFastKeyItemsForInitialUi(
      List<Map<String, dynamic>> items) async {
    await _ingestProductMetaFromMerged();
    final List<Map<String, dynamic>> prepared = [];

    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw);
      final tagsCol = item["fast_key_item_tags"];
      if (tagsCol is String && tagsCol.isNotEmpty) {
        try {
          final decoded = jsonDecode(tagsCol);
          if (decoded is List) {
            item["fast_key_item_tags"] = decoded;
          }
        } catch (_) {}
      }
      final int? productId =
      int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

      await _enrichFastKeyItemFromSkuHive(item);

      // ✅ FIX: Check if meta_data is already in the FastKey item (from API)
      // The FastKey API already returns meta_data for each product
      List<Map<String, dynamic>> fastKeyMetaData = [];
      int fastKeyLoyaltyPoints = 0;

      // Check if item already has meta_data (from FastKey API)
      if (item["meta_data"] is List) {
        fastKeyMetaData = (item["meta_data"] as List)
            .whereType<Map>()
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();

        // Extract loyalty points from FastKey API meta_data
        final loyaltyEntry = fastKeyMetaData.firstWhere(
              (m) => m['key'] == '_product_loyalty_points',
          orElse: () => <String, dynamic>{},
        );
        if (loyaltyEntry.isNotEmpty) {
          fastKeyLoyaltyPoints =
              int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
        }
      }

      // Also check if loyalty_points is directly on the item from FastKey API
      if (fastKeyLoyaltyPoints == 0 && item["loyalty_points"] != null) {
        fastKeyLoyaltyPoints =
            int.tryParse(item["loyalty_points"].toString()) ?? 0;
      }

      // ✅ PRIORITIZE: Use FastKey API data FIRST (it's the source of truth for FastKey)
      if (fastKeyLoyaltyPoints > 0) {
        // Store loyalty points directly on the item
        item["loyalty_points"] = fastKeyLoyaltyPoints;

        // Ensure meta_data is preserved
        if (fastKeyMetaData.isNotEmpty) {
          item["meta_data"] = fastKeyMetaData;
        } else {
          // Create meta_data if not present
          item["meta_data"] = [
            {
              "key": "_product_loyalty_points",
              "value": fastKeyLoyaltyPoints.toString()
            }
          ];
        }
        print(
            "✅ [FastKey] Using loyalty points from FastKey API: $fastKeyLoyaltyPoints for ${item["fast_key_item_name"]}");
      } else {
        // Fallback: Try to get from product cache only if FastKey API doesn't have it
        final cached = productId != null
            ? await _getCachedProductFromIsar(productId)
            : null;

        if (cached != null && cached["meta_data"] != null) {
          item["meta_data"] = cached["meta_data"];
          final loyaltyEntry = (cached["meta_data"] as List).firstWhere(
                (m) => m['key'] == '_product_loyalty_points',
            orElse: () => <String, dynamic>{},
          );
          if (loyaltyEntry.isNotEmpty) {
            item["loyalty_points"] =
                int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
          }
        }
      }

      // Check variants
      final cached =
      productId != null ? await _getCachedProductFromIsar(productId) : null;
      item["has_variants"] = await _fastKeyHasVariants(item);

      // Check EBT
      final isEbt = _isProductEbtEligible({
        "is_ebt_eligible":
        item["is_ebt_eligible"] ?? cached?["is_ebt_eligible"],
        "meta_data": item["meta_data"] ?? cached?["meta_data"],
        "fast_key_item_tags": item["fast_key_item_tags"] ?? cached?["tags"],
        "tags": cached?["tags"],
      });
      item["is_ebt_eligible"] = isEbt;

      prepared.add(item);
    }

    return prepared;
  }

  Future<void> _enrichFastKeyItemFromSkuHive(Map<String, dynamic> item) async {
    final sku = (item['fast_key_item_sku'] ?? '').toString().trim();
    if (sku.isEmpty || sku == 'N/A') return;
    try {
      final box = StorageProvider.productCache;
      final raw = await box.get('sku_${sku.toLowerCase()}');
      if (raw is! Map) return;
      final products = raw['products'];
      if (products is! List || products.isEmpty) return;
      final first = products.first;
      if (first is! Map) return;
      final p = Map<String, dynamic>.from(first);
      final typeStr = (p['type'] ?? item['type'] ?? '').toString();
      if (typeStr.isNotEmpty) item['type'] = typeStr;
      if (item['variations'] == null && p['variations'] is List) {
        item['variations'] = p['variations'];
      }
      if ((item['fast_key_item_tags'] == null ||
          (item['fast_key_item_tags'] is List &&
              (item['fast_key_item_tags'] as List).isEmpty)) &&
          p['tags'] != null) {
        item['fast_key_item_tags'] = p['tags'];
      }
      if (_truthyEbtValue(p['is_ebt_eligible']) ||
          _ebtEligibleFromMetaData(p['meta_data'])) {
        item['is_ebt_eligible'] = true;
      }
      if (item['meta_data'] == null && p['meta_data'] != null) {
        item['meta_data'] = p['meta_data'];
      }
    } catch (_) {}
  }

  static bool _truthyEbtValue(dynamic v) {
    if (v == true || v == 1) return true;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  static bool _ebtEligibleFromMetaData(dynamic meta) {
    if (meta is! List) return false;
    for (final m in meta) {
      if (m is! Map) continue;
      final key = (m['key'] ?? '').toString().toLowerCase();
      if (key != '_is_ebt_eligible' &&
          key != 'is_ebt_eligible' &&
          key != '_ebt_eligible') {
        continue;
      }
      final val = m['value'];
      if (_truthyEbtValue(val)) return true;
    }
    return false;
  }

  Future<void> _resolveFastKeyVariants() async {
    for (final item in fastKeyProductItems) {
      if (item.containsKey('has_variants')) continue;
      item['has_variants'] = await _fastKeyHasVariants(item);
    }
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
    if (!_productMetaCache.containsKey(productId)) {
      await _ingestProductMetaFromMerged();
    }
    return _productMetaCache[productId];
  }

  Future<bool> _fastKeyHasVariants(Map<String, dynamic> item) async {
    final int? productId =
    int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

    if (productId == null) return false;

    // 0️⃣ Persisted when Fast Key syncs from API
    final dynamic hv = item['fast_key_item_has_variant'];
    if (hv == 1 || hv == true || hv == '1') return true;

    // 1️⃣ Fast item-level check
    if ((item["type"]?.toString().toLowerCase() ?? "") == "variable") {
      return true;
    }
    if (item["variations"] is List && item["variations"].isNotEmpty)
      return true;

    // 2️⃣ Check product meta cache
    final cached = await _getCachedProductFromIsar(productId);

    if ((cached?["type"]?.toString().toLowerCase() ?? "") == "variable") {
      return true;
    }
    if (cached?["has_variants"] == true) return true;

    // 3️⃣ CHECK VARIATION CACHE
    try {
      final box = StorageProvider.productCache;
      final variationKey = "product_${productId}_variations";
      final variationData = await box.get(variationKey);

      if (variationData is Map &&
          variationData["variations"] is List &&
          (variationData["variations"] as List).isNotEmpty) {
        return true;
      }

      if (variationData is List && variationData.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  // Build #1.0.87 : Reload fastKey tab products after adding new item into fastKey

  // Build #1.0.87: code updated
  // Future<void> _addFastKeyTabItem(
  //     String name, String image, String price) async {
  //   if (_fastKeyTabId == null) {
  //     if (kDebugMode) {
  //       print("### FastKeyScreen: _addFastKeyTabItem aborted, no tab selected");
  //     }
  //     return;
  //   }
  //   var tabs =
  //   await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
  //   if (tabs.isEmpty) {
  //     if (kDebugMode) {
  //       print("### FastKeyScreen: _addFastKeyTabItem aborted, tab not found");
  //     }
  //     return;
  //   }
  //   var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
  //   var countProductInFastKey = fastKeyProductItems.length;
  //   FastKeyProductItem item = FastKeyProductItem(
  //       productId: selectedProduct!['id'], slNumber: countProductInFastKey + 1);
  //
  //   StreamSubscription? subscription;
  //   subscription =
  //       _fastKeyProductBloc.addProductsStream.listen((response) async {
  //         if (!mounted) {
  //           subscription?.cancel();
  //           return;
  //         }
  //         print("response ---- ${response.status}");
  //         if (response.status == Status.COMPLETED) {
  //           if (kDebugMode) {
  //             print("#### FastKeyScreen: addProducts Status COMPLETED");
  //           }
  //           setState(() => isAddingItemLoading = false);
  //           if (!isBulkAdding) {
  //             _refreshFastKeyTabItems();
  //           }
  //           subscription?.cancel();
  //         } else if (response.status == Status.ERROR) {
  //           if (response.message!.contains('Unauthorised')) {
  //             if (kDebugMode) {
  //               print("Fast key 4 ---- Unauthorised : ${response.message!}");
  //             }
  //             WidgetsBinding.instance.addPostFrameCallback((_) {
  //               if (mounted) {
  //                 Navigator.pushReplacement(context,
  //                     MaterialPageRoute(builder: (context) => LoginScreen()));
  //
  //                 if (kDebugMode) {
  //                   print("message --- ${response.message}");
  //                 }
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   const SnackBar(
  //                     content:
  //                     Text("Unauthorised. Session is expired on this device."),
  //                     backgroundColor: Colors.red,
  //                     duration: Duration(seconds: 2),
  //                   ),
  //                 );
  //               }
  //             });
  //           } else {
  //             if (kDebugMode) {
  //               print("Failed to add item to fastkey: ${response.message}");
  //             }
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text(TextConstants.failedToAddItemToFastKey),
  //                 backgroundColor: Colors.red,
  //                 duration: const Duration(seconds: 2),
  //               ),
  //             );
  //           }
  //           subscription?.cancel();
  //         } else if (response.status == Status.LOADING) {
  //           if (kDebugMode) {
  //             print("### FastKeyScreen: Adding item to FastKey, loading...");
  //           }
  //           setState(() => isItemsLoading = true);
  //         }
  //       });
  //
  //   /// addProducts API CALL
  //   await _fastKeyProductBloc
  //       .addProducts(fastKeyId: fastKeyServerId, products: [item]);
  // }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _refreshFastKeyTabItems() async {
    if (_fastKeyTabId == null) {
      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems aborted, no tab selected");
      }
      return;
    }
<<<<<<< HEAD
    if (kDebugMode) {
      print("FastKey Screen _loadFastKeyTabItems $_fastKeyTabId");
    }
    setState(() => isItemsLoading = true);
    try {
      final tabs =
          await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
=======

    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // ✅ Clear memory cache before refresh
      _clearFastKeyCache(tabId: _fastKeyTabId);

      if (kDebugMode) {
        print("FastKey Screen _loadFastKeyTabItems $_fastKeyTabId");
      }
      setState(() => isItemsLoading = true);

      final tabs = await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId);
>>>>>>> origin/Grocery_pch_api_integration
      if (tabs.isNotEmpty) {
        final fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
        if (kDebugMode) {
          print(
              "FastKey Screen _loadFastKeyTabItems selected tab server id: $fastKeyServerId");
        }
<<<<<<< HEAD
        final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId ?? 1);
=======
        final fetchResultFuture =
        _fastKeyProductBloc.getProductsStream.firstWhere(
              (response) =>
          response.status == Status.COMPLETED ||
              response.status == Status.ERROR,
        );
        await _fastKeyProductBloc.fetchProductsByFastKeyId(
          _fastKeyTabId,
          fastKeyServerId,
        );
        final fetchResult = await fetchResultFuture;
        if (fetchResult.status == Status.ERROR) {
          throw Exception(
              fetchResult.message ?? 'Unable to refresh Fast Key products.');
        }

        final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId);
        final preparedItems = await _prepareFastKeyItemsForInitialUi(items);
>>>>>>> origin/Grocery_pch_api_integration
        if (kDebugMode) {
          print(
              "#### Retrieved ${items.length} FastKey Items for Tab ID: $_fastKeyTabId");
        }
        setState(() {
<<<<<<< HEAD
          fastKeyProductItems =
              List<Map<String, dynamic>>.from(items); // Ensure mutable copy
=======
          fastKeyProductItems = preparedItems;
>>>>>>> origin/Grocery_pch_api_integration
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      } else {
        setState(() {
          fastKeyProductItems = [];
          isItemsLoading = false;
        });
      }
<<<<<<< HEAD
=======
      await _resolveFastKeyMeta();
>>>>>>> origin/Grocery_pch_api_integration
    } catch (e) {
      if (kDebugMode) {
        print("Error loading FastKey tab items: $e");
      }
<<<<<<< HEAD
      setState(() => isItemsLoading = false);
    }
  }

  // Build #1.0.87: code updated
=======
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh Fast Key products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => isItemsLoading = false);
    } finally {
      _isRefreshing = false;
    }
  }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _addFastKeyTabItem(
      String name, String image, String price) async {
    if (_fastKeyTabId == null) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, no tab selected");
      }
      return;
    }
    var tabs =
<<<<<<< HEAD
        await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
=======
    await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
>>>>>>> origin/Grocery_pch_api_integration
    if (tabs.isEmpty) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, tab not found");
      }
      return;
    }
    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
<<<<<<< HEAD
    var countProductInFastKey =
        fastKeyProductItems.length; // Use current UI state
    FastKeyProductItem item = FastKeyProductItem(
        productId: selectedProduct!['id'], slNumber: countProductInFastKey + 1);
=======
    var countProductInFastKey = fastKeyProductItems.length;
    final rawProductId = selectedProduct!['fast_key_product_id'] ??
        selectedProduct!['product_id'] ??
        selectedProduct!['id'];
    final productId = rawProductId is num
        ? rawProductId.toInt()
        : int.tryParse(rawProductId?.toString() ?? '');
    if (productId == null || productId <= 0) {
      throw FormatException('The selected product has an invalid product ID.');
    }
    final item = FastKeyProductItem(
      productId: productId,
      slNumber: countProductInFastKey + 1,
    );
>>>>>>> origin/Grocery_pch_api_integration

    StreamSubscription? subscription;
    subscription =
        _fastKeyProductBloc.addProductsStream.listen((response) async {
<<<<<<< HEAD
      if (!mounted) {
        subscription?.cancel();
        return;
      }
      print("response ---- ${response.status}");
      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print("#### FastKeyScreen: addProducts Status COMPLETED");
        }
        setState(() => isAddingItemLoading =
            false); // Build #1.0.204: Added missed loader on "Add"  button of search product dialouge after tap on add
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
                  content:
                      Text("Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        } else {
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
=======
          if (!mounted) {
            subscription?.cancel();
            return;
          }
          print("response ---- ${response.status}");
          if (response.status == Status.COMPLETED) {
            if (kDebugMode) {
              print("#### FastKeyScreen: addProducts Status COMPLETED");
            }

            // ✅ CLEAR CACHE so next load gets fresh data
            _clearFastKeyCache(tabId: _fastKeyTabId);

            setState(() => isAddingItemLoading = false);
            if (!isBulkAdding) {
              await _refreshFastKeyTabItems();
            }
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
                      content:
                      Text("Unauthorised. Session is expired on this device."),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              });
            } else {
              if (kDebugMode) {
                print("Failed to add item to fastkey: ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    response.message ?? TextConstants.failedToAddItemToFastKey,
                  ),
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
>>>>>>> origin/Grocery_pch_api_integration

    /// addProducts API CALL
    await _fastKeyProductBloc
        .addProducts(fastKeyId: fastKeyServerId, products: [item]);
  }

  Future<void> _deleteFastKeyTabItem(int fastKeyTabItemServerId) async {
    // Build #1.0.104
    if (_fastKeyTabId == null) return;

<<<<<<< HEAD
    // Build #1.0.89: delete FastKey product API integrated
    var tabs =
        await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
=======
    var tabs =
    await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
>>>>>>> origin/Grocery_pch_api_integration
    if (tabs.isEmpty) return;

    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];

<<<<<<< HEAD
    /// Build #1.0.104: No need to check again we already doing in _showDeleteConfirmationDialog
    // var item = fastKeyProductItems.firstWhere((item) => item[AppDBConst.fastKeyIdForeignKey] == fastKeyTabItemId);
    // String productId = item[AppDBConst.fastKeyProductId];

    StreamSubscription? subscription;
    subscription =
        _fastKeyProductBloc.deleteProductStream.listen((response) async {
      if (!mounted) {
        subscription?.cancel();
        return;
      }
      if (response.status == Status.COMPLETED) {
        if (kDebugMode) {
          print(
              "### FastKeyScreen: Product deleted successfully from FastKey: ${response.data!.fastkeyId}");
        }
        await _refreshFastKeyTabItems(); // refresh UI

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response.data?.message ?? "Product deleted from Fast Key"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
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
                  content:
                      Text("Unauthorised. Session is expired on this device."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        } else {
          if (kDebugMode) {
            print(
                "### FastKeyScreen: Failed to delete product: ${response.message}");
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
    await _fastKeyProductBloc.deleteProduct(
        fastKeyServerId, fastKeyTabItemServerId); // Build #1.0.104
=======
    StreamSubscription? subscription;
    subscription =
        _fastKeyProductBloc.deleteProductStream.listen((response) async {
          if (!mounted) {
            subscription?.cancel();
            return;
          }
          if (response.status == Status.COMPLETED) {
            if (kDebugMode) {
              print(
                  "### FastKeyScreen: Product deleted successfully from FastKey: ${response.data!.fastkeyId}");
            }
            await _refreshFastKeyTabItems();

            if (Misc.showDebugSnackBar) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      response.data?.message ?? "Product deleted from Fast Key"),
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
                      content:
                      Text("Unauthorised. Session is expired on this device."),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              });
            } else {
              if (kDebugMode) {
                print(
                    "### FastKeyScreen: Failed to delete product: ${response.message}");
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    response.message ??
                        TextConstants.failedToDeleteProductFromFastKey,
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            subscription?.cancel();
          }
        });

    await _fastKeyProductBloc.deleteProduct(
        fastKeyServerId, fastKeyTabItemServerId);
>>>>>>> origin/Grocery_pch_api_integration
  }

  Future<void> _pickImage() async {
    final XFile? imageFile =
<<<<<<< HEAD
        await _picker.pickImage(source: ImageSource.gallery);
=======
    await _picker.pickImage(source: ImageSource.gallery);
>>>>>>> origin/Grocery_pch_api_integration
    if (imageFile != null) {
      setState(() {
        _pickedImage = File(imageFile.path);
      });
    }
  }

<<<<<<< HEAD
  void _onItemSelected(int index, bool showAddButton, bool variantAdded) async {
    //Build #1.0.78: fix for parent product also adding along with variant product , we have to restrict that like categories screen
    if (variantAdded == true) {
      // Build #1.0.148: we have to show loader until product adds into order panel, then hide
      // Navigator.pop(context); // Hide Loader / VariationPopup dialog
      if (Navigator.canPop(context)) {
        // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
        Navigator.pop(context);
      }
      _refreshOrderList(); // refresh UI
      return;
    }

    if (kDebugMode) {
      print("Fast Key _onItemSelected");
    }
    final adjustedIndex = index - (showAddButton ? 1 : 0);
    if (adjustedIndex < 0 || adjustedIndex >= fastKeyProductItems.length)
      return;

    final selectedProduct = fastKeyProductItems[adjustedIndex];
    // final order = orderHelper.orders.firstWhere(
    //       (order) => order[AppDBConst.orderServerId] == orderHelper.activeOrderId,
    //   orElse: () => {},
    // );
    final serverOrderId =
        orderHelper.activeOrderId; //order[AppDBConst.orderServerId] as int?;
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
      //  setState(() => isAddingItemLoading = true);
      subscription = orderBloc.updateOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.LOADING) {
          // Build #1.0.80
          if (kDebugMode)
            print("Loading stated in fastkey under _onItemSelected ...");
          const Center(child: CircularProgressIndicator());
        } else if (response.status == Status.COMPLETED) {
          // Build #1.0.148: we have to show loader until product adds into order panel, then hide
          //  Navigator.pop(context); // Hide Loader / VariationPopup dialog
          if (Navigator.canPop(context)) {
            // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
            Navigator.pop(context);
          }
          //   setState(() => isAddingItemLoading = false);
          if (kDebugMode) print("Item added to order $dbOrderId via API");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Item '${selectedProduct[AppDBConst.fastKeyItemName]}' added to order"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (Navigator.canPop(context)) {
            // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
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
                    content: Text(
                        "Unauthorised. Session is expired on this device."),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          } else {
            if (kDebugMode)
              print("Failed to add item to order: ${response.message}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    response.message ?? TextConstants.failedToAddItemToOrder),
                // Build #1.0.144
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
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
  Future<void> _createOrder() async {
    try {
      var orders =
          await orderHelper.getOrderById(orderHelper.activeOrderId ?? 0);
      if (kDebugMode) {
        print("Fast Key screen createOrder - Orders in DB $orders");
      }
      int? shiftId = await UserDbHelper().getUserShiftId();

      //Build #1.0.78: Validation required : if shift id is empty show toast or alert user to start the shift first
      if (shiftId == null) {
        if (kDebugMode) print("####### _createOrder() : shiftId -> $shiftId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TextConstants
                .pleaseStartShiftBeforeCreatingOrder), // Build #1.0.144
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (orders.isNotEmpty && orders.first[AppDBConst.orderServerId] != null) {
=======
  Stopwatch? refreshUIStopwatch; // Build #1.0.256

  Future<void> _onItemSelected(
      int index, bool showAddButton, bool variantAdded) async {
    try {
      // ✅ FIX: NestedGridWidget already adds the item to the order itself
      // (weighted/produce, variable-price, variant, and simple product paths
      // all call orderHelper.addItemToOrder before invoking this callback).
      // Re-running the add logic below caused a duplicate add (qty showing 2).
      // We only need to refresh here — and must NOT pop navigation, since
      // Navigator.pop(context) here pops the screen's own route, not a
      // dialog, which was sending users back to the previous tab/screen.
      _refreshOrderList();
      return;

      if (variantAdded) {
        if (!Misc.enableUILogMessages) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
>>>>>>> origin/Grocery_pch_api_integration
        _refreshOrderList();
        return;
      }

<<<<<<< HEAD
      final deviceDetails = await GlobalUtility
          .getDeviceDetails(); //Build #1.0.126: using from GlobalUtility
      String deviceId = deviceDetails['device_id'] ?? 'unknown';
      OrderMetaData device = OrderMetaData(
          key: OrderMetaData.posDeviceId,
          value: deviceId); // TODO: Implement dynamic device ID
      OrderMetaData placedBy = OrderMetaData(
          key: OrderMetaData.posPlacedBy, value: '${userId ?? 1}');
      OrderMetaData shiftIdValue = OrderMetaData(
          key: OrderMetaData.shiftId,
          value: shiftId.toString()); // Build #1.0.149
      List<OrderMetaData> metaData = [device, placedBy, shiftIdValue];

      StreamSubscription? subscription;

      subscription = orderBloc.createOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.COMPLETED) {
          if (kDebugMode)
            print(
                "Order created successfully with server ID: ${response.data!.id}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  TextConstants.orderCreatedSuccessfully), // Build #1.0.144
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (response.message!.contains('Unauthorised')) {
            if (kDebugMode) {
              print("Fast key 7 ---- Unauthorised : ${response.message!}");
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
          } else {
            if (kDebugMode)
              print("Failed to create order: ${response.message}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(TextConstants.failedToCreateOrder),
                // Build #1.0.144
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          subscription?.cancel();
        }
      });

      await orderBloc.createOrder(); // Build #1.0.128
    } catch (e) {
      if (kDebugMode) print("Exception in _createOrder: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TextConstants.errorCreatingOrder), // Build #1.0.144
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _refreshOrderList() {
    setState(() {
      // Build #1.0.128
=======
      if (kDebugMode) print("⚡ Fast Key _onItemSelected");

      final adjustedIndex = index - (showAddButton ? 1 : 0);
      if (adjustedIndex < 0 || adjustedIndex >= fastKeyProductItems.length)
        return;

      final item = fastKeyProductItems[adjustedIndex];

      // 🧩 Extract product info
      final productId =
          int.tryParse(item["fast_key_product_id"].toString()) ?? -1;
      final productName = (item["fast_key_item_name"] is String)
          ? item["fast_key_item_name"]
          : item["fast_key_item_name"]?["rendered"] ?? "Unnamed Product";
      final productPrice =
          double.tryParse(item["fast_key_item_price"].toString()) ?? 0.0;
      final productSku = item["fast_key_item_sku"] ?? "SKU-$productId";
      final productImage = (item["fast_key_item_image"] is String)
          ? item["fast_key_item_image"]
          : item["fast_key_item_image"]?["src"] ?? "";

      final minAge =
          int.tryParse(item["fast_key_item_min_age"]?.toString() ?? "0") ?? 0;
      final hasAgeRestriction = minAge > 0;

      bool isEbtEligible = item["is_ebt_eligible"] == true;
      if (!isEbtEligible) {
        isEbtEligible = _isProductEbtEligible(item);
      }

      // ✅ FIX: Extract meta_data and loyalty points - USE WHAT'S IN THE FASTKEY ITEM
      List<Map<String, dynamic>> metaDataList = [];
      int loyaltyPoints = 0;

      // FIRST: Check if loyalty_points is directly stored on the FastKey item
      if (item["loyalty_points"] != null) {
        loyaltyPoints = int.tryParse(item["loyalty_points"].toString()) ?? 0;
        print(
            "✅ [FastKey] Using loyalty points from FastKey item: $loyaltyPoints");
      }

      // SECOND: Check meta_data from FastKey item
      final rawMeta = item["meta_data"] ?? item["metaData"];
      if (rawMeta is List) {
        metaDataList = rawMeta
            .whereType<Map>()
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();

        // If loyalty not found directly, try from meta_data
        if (loyaltyPoints == 0) {
          final loyaltyEntry = metaDataList.firstWhere(
                (m) => m['key'] == '_product_loyalty_points',
            orElse: () => <String, dynamic>{},
          );
          if (loyaltyEntry.isNotEmpty) {
            loyaltyPoints =
                int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
          }
        }
      }

      // THIRD: Try to get from product cache ONLY if FastKey item doesn't have it
      if (loyaltyPoints == 0 && productId > 0) {
        final cached = await _getCachedProductFromIsar(productId);
        if (cached != null && cached["meta_data"] is List) {
          final loyaltyEntry = (cached["meta_data"] as List).firstWhere(
                (m) => m['key'] == '_product_loyalty_points',
            orElse: () => <String, dynamic>{},
          );
          if (loyaltyEntry.isNotEmpty) {
            loyaltyPoints =
                int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
            print(
                "⚠️ [FastKey] Using product cache loyalty points (fallback): $loyaltyPoints");
          }
        }
      }

      print(
          "🎯 [FastKey] Final loyalty points for $productName: $loyaltyPoints");

      final box = StorageProvider.offlineOrders;
      final isOfflineOrder =
      box.containsKey(orderHelper.activeOrderId.toString());
      final activeOrderId =
          orderHelper.activeOrderId ?? (await box.get('lastOrderId')) ?? 1000;

      if (orderHelper.activeOrderId == null) {
        orderHelper.activeOrderId = activeOrderId;
        await box.put('lastOrderId', activeOrderId);
      }

      // ─────────────────────────────────────────────────────────────
      // PRODUCE / WEIGHTED ITEM HANDLING
      // ─────────────────────────────────────────────────────────────
      final tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
      final bool hasProduceTag = (tagsRaw is List)
          ? tagsRaw.any((t) {
        if (t is! Map) return false;
        final slug = (t["slug"] ?? "").toString().toLowerCase();
        final name = (t["name"] ?? "").toString().toLowerCase();
        return slug.contains("produce") || name.contains("produce");
      })
          : false;

      if (hasProduceTag) {
        final weightProvider =
        Provider.of<WeightProvider>(context, listen: false);
        double liveWeight = 0.0;

        try {
          final parts = weightProvider.weightText.trim().split(' ');
          if (parts.isNotEmpty) {
            liveWeight = double.tryParse(parts[0]) ?? 0.0;
          }
        } catch (_) {}

        final double weightKg = liveWeight > 0 ? liveWeight * 0.453592 : 0.0;
        final double weightToUse = weightKg > 0.00001 ? weightKg : 0.0001;
        final double finalPrice = productPrice * weightToUse;

        if (weightKg <= 0.0001 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scale not detected — using 100g default'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // ✅ Pass loyalty points to order
        await orderHelper.addItemToOrder(
          null,
          productName,
          productImage,
          finalPrice,
          1,
          productSku,
          activeOrderId,
          type: 'weighted',
          weightQty: weightToUse,
          productId: productId,
          variationId: -1,
          salesPrice: finalPrice,
          regularPrice: productPrice,
          unitPrice: productPrice,
          isEbtEligible: isEbtEligible,
          metaData: metaDataList,
          loyaltyPoints: loyaltyPoints,
          onItemAdded: () async {
            print("✅ Weighted item added locally");
            weightProvider.updateWeight(0.0);
          },
        );
        return;
      }

      // ─────────────────────────────────────────────────────────────
      // ORIGINAL LOGIC FOR NORMAL + VARIABLE PRODUCTS
      // ─────────────────────────────────────────────────────────────
      final hasVariants = (item["type"] == "variable" ||
          (item["variations"] != null && item["variations"].isNotEmpty));

      if (hasVariants) {
        List<Map<String, dynamic>> offlineVariations = [];

        try {
          final productBox = StorageProvider.productCache;
          final cacheKey = "product_${productId}_variations";
          final cachedData = await productBox.get(cacheKey);
          List rawVariations = [];

          if (cachedData != null) {
            if (cachedData is Map && cachedData["variations"] is List) {
              rawVariations = cachedData["variations"];
            } else if (cachedData is List) {
              rawVariations = cachedData;
            } else if (cachedData is String) {
              try {
                final decoded = jsonDecode(cachedData);
                rawVariations =
                decoded is Map ? decoded["variations"] ?? [] : decoded;
              } catch (_) {}
            }
          }

          if (rawVariations.isEmpty && item["variations"] != null) {
            for (var id in item["variations"]) {
              var variantData = await productBox.get("product_$id");
              if (variantData is String) {
                try {
                  variantData = jsonDecode(variantData);
                } catch (_) {}
              }
              final name = variantData?["name"] ?? "Variant $id";
              final price = (variantData?["price"] ??
                  variantData?["regular_price"] ??
                  productPrice)
                  .toString();
              final image = (variantData?["image"] is Map)
                  ? variantData["image"]["src"]
                  : (variantData?["image"] ?? productImage);

              // ✅ Extract meta_data if available
              List<Map<String, dynamic>> metaData = [];
              if (variantData?["meta_data"] is List) {
                metaData = (variantData["meta_data"] as List)
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList();
              }

              final loyaltyEntry = metaData.firstWhere(
                    (m) => m['key'] == '_product_loyalty_points',
                orElse: () => <String, dynamic>{},
              );
              final int loyaltyPoints = loyaltyEntry.isNotEmpty
                  ? int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0
                  : 0;

              rawVariations.add({
                "id": id,
                "name": name,
                "price": price,
                "sku": variantData?["sku"] ?? "",
                "image": image,
                "meta_data": metaData, // ✅ Preserve meta_data
                "loyalty_points": loyaltyPoints, // ✅ Store loyalty points
              });
            }
          }

          // ✅ CRITICAL: Preserve meta_data when parsing variations
          offlineVariations = rawVariations.map<Map<String, dynamic>>((v) {
            if (v is String) v = jsonDecode(v);
            final map = Map<String, dynamic>.from(v);
            map["price"] = map["price"]?.toString() ?? "0";

            // ✅ Preserve meta_data
            if (map["meta_data"] is! List) {
              map["meta_data"] = <Map<String, dynamic>>[];
            }

            // ✅ Ensure loyalty_points is set from meta_data
            if (map["loyalty_points"] == null || map["loyalty_points"] == 0) {
              final metaData = map["meta_data"] as List<Map<String, dynamic>>;
              final loyaltyEntry = metaData.firstWhere(
                    (m) => m['key'] == '_product_loyalty_points',
                orElse: () => <String, dynamic>{},
              );
              if (loyaltyEntry.isNotEmpty) {
                map["loyalty_points"] =
                    int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
              } else {
                map["loyalty_points"] = 0;
              }
            }

            return map;
          }).toList();

          // ✅ Only fetch fresh if cache is empty OR lacks meta_data
          final bool needsFreshFetch = offlineVariations.isEmpty ||
              offlineVariations.every((v) {
                final meta = v["meta_data"] as List?;
                return meta == null || meta.isEmpty;
              });

          if (needsFreshFetch && productId > 0) {
            print(
                "🔄 [FastKey] Fetching fresh variants for product $productId (cache missing meta_data)");
            final fetched = await _fetchVariationsFromApi(productId);
            if (fetched.isNotEmpty) {
              offlineVariations = fetched;
              await StorageProvider.productCache.put(
                "product_${productId}_variations",
                {
                  "variations": fetched,
                  "timestamp": DateTime.now().toIso8601String()
                },
              );
            }
          }
        } catch (e) {
          print("⚠️ Error loading variants: $e");
        }

        // ✅ Show dialog with variations
        await showDialog(
          context: context,
          builder: (ctx) => VariantsDialog(
            title: productName,
            variations: offlineVariations,
            onAddVariant: (selectedVariant, qty) async {
              final variantId =
                  int.tryParse(selectedVariant["id"].toString()) ?? -1;
              final variantName = selectedVariant["name"] ?? "Variant";
              final variantPrice =
                  double.tryParse(selectedVariant["price"].toString()) ??
                      productPrice;
              final variantImage = selectedVariant["image"] ?? productImage;
              final variantSku = selectedVariant["sku"] ?? productSku;

              // ✅ CRITICAL: Extract meta_data from selected variant
              List<Map<String, dynamic>> variantMetaData = [];
              int variantLoyaltyPoints = 0;

              // Try to get meta_data from selectedVariant
              if (selectedVariant["meta_data"] is List) {
                variantMetaData = (selectedVariant["meta_data"] as List)
                    .whereType<Map>()
                    .map<Map<String, dynamic>>(
                        (m) => Map<String, dynamic>.from(m))
                    .toList();

                // Extract loyalty from meta_data
                final loyaltyEntry = variantMetaData.firstWhere(
                      (m) => m['key'] == '_product_loyalty_points',
                  orElse: () => <String, dynamic>{},
                );
                if (loyaltyEntry.isNotEmpty) {
                  variantLoyaltyPoints =
                      int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ??
                          0;
                }
              }

              // If no loyalty from meta_data, try direct field
              if (variantLoyaltyPoints == 0 &&
                  selectedVariant["loyalty_points"] != null) {
                variantLoyaltyPoints = int.tryParse(
                    selectedVariant["loyalty_points"].toString()) ??
                    0;
              }

              // If still 0, try parent product's loyalty points (fallback)
              if (variantLoyaltyPoints == 0 && metaDataList.isNotEmpty) {
                final parentLoyalty = metaDataList.firstWhere(
                      (m) => m['key'] == '_product_loyalty_points',
                  orElse: () => <String, dynamic>{},
                );
                if (parentLoyalty.isNotEmpty) {
                  variantLoyaltyPoints =
                      int.tryParse(parentLoyalty['value']?.toString() ?? '0') ??
                          0;
                  print(
                      '🔄 [FastKey] Using parent loyalty points: $variantLoyaltyPoints');
                }
              }

              print('🛒 [FastKey] Added variant: $variantName');
              print('  → Variant ID: $variantId');
              print('  → Variant Price: $variantPrice');
              print('  → MetaData count: ${variantMetaData.length}');
              print('  → Loyalty Points: $variantLoyaltyPoints');

              // ✅ Pass variant loyalty points to order
              await orderHelper.addItemToOrder(
                0,
                "$productName - $variantName",
                variantImage,
                variantPrice,
                qty,
                variantSku,
                activeOrderId,
                type: 'variant',
                productId: productId,
                variationId: variantId,
                variationName: variantName,
                salesPrice: variantPrice,
                regularPrice: variantPrice,
                unitPrice: variantPrice,
                isEbtEligible: isEbtEligible,
                metaData: variantMetaData, // ✅ Pass variant's meta_data
                loyaltyPoints:
                variantLoyaltyPoints, // ✅ Pass variant's loyalty points
                onItemAdded: () async {
                  print("✅ Variant added locally");
                  await CustomerDisplayHelper.updateCustomerDisplay(
                      activeOrderId);
                  await _refreshOrderList();
                },
              );
            },
          ),
        );
      } else {
        // ✅ Pass loyalty points from FastKey item to order
        await orderHelper.addItemToOrder(
          0,
          productName,
          productImage,
          productPrice,
          1,
          productSku,
          activeOrderId,
          type: 'product',
          productId: productId,
          variationId: -1,
          salesPrice: productPrice,
          regularPrice: productPrice,
          unitPrice: productPrice,
          isEbtEligible: isEbtEligible,
          metaData: metaDataList,
          loyaltyPoints: loyaltyPoints,
          onItemAdded: () async {
            print("✅ Product added locally");
            await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);
            await _refreshOrderList();
          },
        );
      }

      print("🎉 Product flow completed for → $productName");
    } catch (e, s) {
      print("❌ ERROR in _onItemSelected: $e");
      print(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to add product"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshOrderList() async {
    setState(() {
>>>>>>> origin/Grocery_pch_api_integration
      if (kDebugMode) {
        print(
            "##### _refreshOrderList: Incrementing _refreshCounter to $_refreshCounter to trigger RightOrderPanel refresh");
      }
<<<<<<< HEAD
      _refreshCounter++; //Build #1.0.170: Increment to signal refresh, causing didUpdateWidget to load with loader
    });
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
            backgroundColor: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.secondaryBackground
                : null,
            title: Text(
              TextConstants.searchAddItemText,
              style: TextStyle(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.black87),
            ),
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
                                return const Center(
                                    child: CircularProgressIndicator());
                              case Status.COMPLETED:
                                final products = snapshot.data!.data;
                                if (products == null || products.isEmpty) {
                                  return const Center(
                                      child: Text("No products found"));
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color:
                                        themeHelper.themeMode == ThemeMode.dark
                                            ? ThemeNotifier.primaryBackground
                                            : ThemeNotifier.lightBackground,
                                  ),
                                  height: size.height * 0.5,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 3, right: 3),
                                    child: Scrollbar(
                                      controller: _scrollController,
                                      scrollbarOrientation:
                                          ScrollbarOrientation.right,
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
                                            leading: product.images != null &&
                                                    product.images!.isNotEmpty
                                                ? Image.network(
                                                    product.images!.first,
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        themeHelper.themeMode ==
                                                                ThemeMode.dark
                                                            ? Image.asset(
                                                                "assets/dark_mode_image.png",
                                                                fit: BoxFit
                                                                    .contain,
                                                                color: Colors
                                                                    .white,
                                                              )
                                                            : Image.asset(
                                                                "assets/lite_mode_image.png",
                                                                fit: BoxFit
                                                                    .contain,
                                                              ),
                                                  )
                                                : const Icon(Icons.image),
                                            title:
                                                Text(product.name ?? 'No Name'),
                                            subtitle: Text(
                                                '${TextConstants.currencySymbol}${double.tryParse(product.price.toString())?.toStringAsFixed(2) ?? "0.00"}'),
                                            onTap: () {
                                              setStateDialog(() {
                                                var tag = product.tags
                                                    ?.firstWhere(
                                                        (element) =>
                                                            element.name ==
                                                            TextConstants
                                                                .age_restricted,
                                                        orElse: () =>
                                                            SKU.Tags());
                                                if (kDebugMode) {
                                                  print(
                                                      "FaskKey setStateDialog hasAgeRestriction tag = ${tag?.id}, ${tag?.name}, ${tag?.slug}");
                                                  print(
                                                      "FaskKey setStateDialog ${product.name ?? 'Unknown'}");
                                                }
                                                selectedProduct = {
                                                  'title':
                                                      product.name ?? 'Unknown',
                                                  'image': product.images
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? product.images!.first
                                                      : '',
                                                  'price':
                                                      product.regularPrice ??
                                                          '0.00',
                                                  'id': product.id,
                                                  'sku': product.sku ?? 'N/A',
                                                  'minAge': int.parse(
                                                      tag?.slug ?? "0"),
                                                };
                                              });
                                            },
                                            selected: selectedProduct != null &&
                                                selectedProduct!['id'] ==
                                                    product.id,
                                            selectedTileColor: Colors.grey[300],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              case Status.ERROR:
                                if (snapshot.data!.message!
                                    .contains('Unauthorised')) {
                                  if (!errorShown) {
                                    // Set the flag to true IMMEDIATELY to prevent this block from running again
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
              TextButton(
                //Build #1.0.68 : updated code for exist item alert
                onPressed: selectedProduct != null &&
                        !isAddingItemLoading // Add condition
                    ? () async {
                        setStateDialog(() => isAddingItemLoading =
                            true); // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add

                        final existingItems = await fastKeyDBHelper
                            .getFastKeyItems(_fastKeyTabId!);
                        if (kDebugMode) {
                          print("#### existingItems: $existingItems");
                          print(
                              "#### selectedProduct ID : ${selectedProduct!['id']}");
                        }
                        final selectedProductId =
                            selectedProduct!['id'].toString();
                        final existingItem = existingItems.firstWhere(
                          (item) =>
                              item[AppDBConst.fastKeyProductId].toString() ==
                              selectedProductId,
                          orElse: () => {},
                        );

                        if (existingItem.isNotEmpty) {
                          if (kDebugMode) {
                            print("#### Product EXIST");
                          }
                          // Navigator.of(dialogContext).pop(); // Close the add item dialog
                          final tab =
                              await fastKeyDBHelper.getFastKeyByServerTabId(
                                  _fastKeyTabId!); // Build #1.0.87
                          final tabName = tab.isNotEmpty
                              ? tab.first[AppDBConst.fastKeyTabTitle]
                              : 'Fast Key';

                          setStateDialog(() => isAddingItemLoading =
                              false); // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add
                          // Show custom item alert with dismissal using parent context
                          await CustomDialog.showCustomItemAlert(
                            context, // Use parent context
                            title: TextConstants.alreadyExistTitle,
                            description:
                                '${TextConstants.alreadyExistSubTitle} $tabName',
                            buttonText: TextConstants.okText,
                            onButtonPressed: () {
                              Navigator.of(context)
                                  .pop(); // Dismiss the alert dialog
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
                          Navigator.of(dialogContext)
                              .pop(); // Close the add item dialog
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
                        child: CircularProgressIndicator(
                            strokeWidth:
                                2), // Build #1.0.204: Added missed loader on "Add"  button of search product dialog after tap on add
                      )
                    : Text(TextConstants.addText),
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
    TextEditingController nameController = TextEditingController(
        text: isEditing ? fastKeyTabs[index!].fastkeyTitle : '');
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    String imagePath = isEditing
        ? fastKeyTabs[index!].fastkeyImage
        : themeHelper.themeMode == ThemeMode.dark
            ? 'assets/new_fast_dark.png'
            : 'assets/new_icon_fastkey.png';
    bool showError = false;
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
=======
      _refreshCounter++;
    });
    await orderHelper.loadData();

    if (Misc.enableUILogMessages && refreshUIStopwatch != null) {
      refreshUIStopwatch?.stop();
      globalProcessSteps.add(
        ProcessStep(
          name: TextConstants.refreshDBUITime,
          timeTaken: refreshUIStopwatch!.elapsedMilliseconds / 1000.0,
        ),
      );
      if (kDebugMode) {
        print(
            "Add Product to Order completed in ${globalProcessSteps.last.timeTaken}s");
      }
    }

    if (Misc.enableUILogMessages && globalProcessSteps.isNotEmpty) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (kDebugMode) {
        print(
            "VariationPopup - Showing toast with process timings: ${globalProcessSteps.map((s) => '${s.name}: ${s.timeTaken}s').toList()}");
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
              globalProcessSteps.clear();
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // _showAddItemDialog — TopBar-identical search: local cache + API + session cache
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _showAddItemDialog() async {
    searchController.clear();
    isBulkAdding = true;

    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);

    List<Map<String, dynamic>> selectedProducts = [];
    List<dynamic> _allCached = [];
    List<dynamic> _filteredList = [];
    bool _isApiSearching = false;
    bool isSubmittingBulk = false;

    // ── Load initial merged cache (same source as TopBar) ──────────────────
    try {
      _allCached = await TopBar.mergedCachedProductsForSearch();
      debugPrint(
          "✅ FastKey Dialog: Loaded ${_allCached.length} products from merged cache");
    } catch (e) {
      debugPrint('FastKey Add Dialog: cache load error → $e');
    }

    // ── Resolver helpers (identical to TopBar's _buildLocalResultsList) ────

    int? _resolveProductId(dynamic p) {
      final dynamic raw =
          p['fast_key_product_id'] ?? p['product_id'] ?? p['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }

    String _resolveName(dynamic p) {
      final dynamic rawName = p["fast_key_item_name"] ?? p["name"];
      if (rawName is Map && rawName["rendered"] != null) {
        return rawName["rendered"].toString();
      }
      return (rawName ?? "Unknown").toString();
    }

    String _resolvePrice(dynamic p) {
      final dynamic raw = p["fast_key_item_price"] ??
          p["price"] ??
          p["regular_price"] ??
          "0.00";
      return raw.toString();
    }

    String _resolveImage(dynamic p) {
      try {
        final imagesRaw = p["images"] ?? p["fast_key_item_image"];
        if (imagesRaw is String && imagesRaw.isNotEmpty) return imagesRaw;
        if (imagesRaw is List && imagesRaw.isNotEmpty) {
          final first = imagesRaw.first;
          if (first is String && first.isNotEmpty) return first;
          if (first is Map && first["src"] != null) {
            return first["src"].toString();
          }
        }
      } catch (_) {}
      return p["fast_key_item_image"]?.toString() ?? '';
    }

    // ── Same normalize + match logic as TopBar ─────────────────────────────

    String _normalize(String input) =>
        input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    bool _matchesProduct(String q, dynamic p) {
      final nq = _normalize(q);
      if (nq.isEmpty) return true;
      final name = _normalize(_resolveName(p));
      final sku =
      _normalize((p["sku"] ?? p["fast_key_item_sku"] ?? "").toString());
      if (name.contains(nq) || sku.contains(nq)) return true;
      final parts = q
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((e) => _normalize(e))
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return false;
      return parts.every((part) => name.contains(part) || sku.contains(part));
    }

    void _filterLocal(String query) {
      final q = query.trim();
      if (q.length < 3) {
        _filteredList = [];
        return;
      }
      final Map<int, dynamic> unique = {};
      for (final p in _allCached) {
        final int? pid = _resolveProductId(p);
        if (pid == null) continue;
        if (_matchesProduct(q, p)) unique[pid] = p;
      }
      _filteredList = unique.values.toList()
        ..sort((a, b) {
          final na = _resolveName(a).toLowerCase();
          final nb = _resolveName(b).toLowerCase();
          final ql = q.toLowerCase();
          final sa = na.startsWith(ql);
          final sb = nb.startsWith(ql);
          if (sa && !sb) return -1;
          if (!sa && sb) return 1;
          return na.compareTo(nb);
        });
    }

    // ── TopBar-identical API search: direct HTTP + session cache ───────────
    // Uses _fastKeyApiSearchCache (static Map on _FastKeyScreenState).
    // Merges API results into _allCached without overwriting Isar entries,
    // then re-applies the local filter — exactly like TopBar._mergeApiResults.

    Future<void> _searchFromApi(
        String query,
        StateSetter setStateDialog,
        ) async {
      final normQuery = query.toLowerCase().trim();
      if (normQuery.length < 3) return;

      // Session-level cache hit → instant, no HTTP call
      if (_fastKeyApiSearchCache.containsKey(normQuery)) {
        if (kDebugMode) {
          print('⚡ FastKey API cache hit for "$normQuery"');
        }
        final cached = _fastKeyApiSearchCache[normQuery]!;
        final Map<int, dynamic> existing = {};
        for (final p in _allCached) {
          final pid = _resolveProductId(p);
          if (pid != null) existing[pid] = p;
        }
        bool changed = false;
        for (final ap in cached) {
          final pid = _resolveProductId(ap);
          if (pid == null) continue;
          if (!existing.containsKey(pid)) {
            existing[pid] = ap;
            changed = true;
          }
        }
        if (changed) _allCached = existing.values.toList();
        setStateDialog(() => _filterLocal(query));
        return;
      }

      setStateDialog(() => _isApiSearching = true);

      try {
        final db = await DBHelper.instance.database;
        final result = await db.query(
          AppDBConst.userTable,
          where:
          '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
          orderBy: '${AppDBConst.userId} DESC',
          limit: 1,
        );
        if (result.isEmpty) throw Exception('No active user token found');
        final token = result.first[AppDBConst.userToken] as String;

        final encodedQuery = Uri.encodeQueryComponent(normQuery);
        final url = Uri.parse(
          '${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}'
              'products?search=$encodedQuery&page=1&per_page=20',
        );

        if (kDebugMode) print('🔍 FastKey API Search → $url');

        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode != 200) {
          if (kDebugMode) {
            print('⚠️ FastKey API search ${response.statusCode}');
          }
          return;
        }

        final List<dynamic> decoded =
        jsonDecode(response.body) as List<dynamic>;

        // Normalise into the same map shape used everywhere in the app
        final List<Map<String, dynamic>> apiProducts =
        decoded.whereType<Map>().map<Map<String, dynamic>>((p) {
          final List<dynamic> images = (p['images'] as List?) ?? [];
          final String imageUrl = images.isNotEmpty && images.first is Map
              ? (images.first['src'] ?? '').toString()
              : '';
          final List<dynamic> rawTags = (p['tags'] as List?) ?? [];
          final List<Map<String, dynamic>> tags = rawTags
              .whereType<Map>()
              .map((t) => {
            'id': t['id'],
            'name': (t['name'] ?? '').toString(),
            'slug': (t['slug'] ?? '').toString(),
          })
              .toList();
          return {
            'fast_key_product_id': p['id'],
            'fast_key_item_name': p['name'] ?? '',
            'fast_key_item_image': imageUrl,
            'fast_key_item_price': p['price'] ?? p['regular_price'] ?? '0',
            'fast_key_item_sku': p['sku'] ?? '',
            'fast_key_item_tags': tags,
            'id': p['id'],
            'name': p['name'] ?? '',
            'price': p['price'] ?? p['regular_price'] ?? '0',
            'regular_price': p['regular_price'] ?? '',
            'sku': p['sku'] ?? '',
            'images': images,
            'tags': tags,
            'variations': p['variations'] ?? [],
            'type': p['type'] ?? 'simple',
            'categories': (p['categories'] as List?) ?? [],
            'is_ebt_eligible': tags.any((t) {
              final name = (t['name'] ?? '').toString().toLowerCase();
              final slug = (t['slug'] ?? '').toString().toLowerCase();
              return name == 'ebt' ||
                  name == 'ebt eligible' ||
                  slug == 'ebt' ||
                  slug == 'ebt-eligible';
            }),
          };
        }).toList();

        // Store in session cache — same query next time costs 0 API calls
        _fastKeyApiSearchCache[normQuery] = apiProducts;

        if (kDebugMode) {
          print(
              '✅ FastKey API returned ${apiProducts.length} products for "$normQuery"');
        }

        // Merge: Isar data takes priority (same as TopBar._mergeApiResults)
        final Map<int, dynamic> existing = {};
        for (final p in _allCached) {
          final pid = _resolveProductId(p);
          if (pid != null) existing[pid] = p;
        }
        bool changed = false;
        for (final ap in apiProducts) {
          final pid = _resolveProductId(ap);
          if (pid == null) continue;
          if (!existing.containsKey(pid)) {
            existing[pid] = ap;
            changed = true;
          }
        }
        if (changed) _allCached = existing.values.toList();

        setStateDialog(() => _filterLocal(query));
      } catch (e) {
        if (kDebugMode) print('❌ FastKey _searchFromApi error: $e');
      } finally {
        setStateDialog(() => _isApiSearching = false);
      }
    }

    // ── Dialog ─────────────────────────────────────────────────────────────
    Timer? _debounce;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
>>>>>>> origin/Grocery_pch_api_integration
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeHelper.themeMode == ThemeMode.dark
<<<<<<< HEAD
                  ? Color(0xFF201E2B)
                  : Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              contentPadding:
                  EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 0),
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
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.textDark
                          : Colors.black87,
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
                  width: MediaQuery.of(context).size.width * 0.33,
                  height: 250,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize
                              .min, // keep column as small as needed
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 125,
                                  height: 125,
                                  decoration: BoxDecoration(
                                    color:
                                        themeHelper.themeMode == ThemeMode.dark
                                            ? Color(0xFF393B4C)
                                            : Color(0xFFFFFFFF),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      themeHelper.themeMode == ThemeMode.dark
                                          ? BoxShadow(
                                              color: Color(0x20FFFFFF),
                                              blurRadius: 10,
                                              spreadRadius: 4,
                                              offset: Offset(0, 0),
                                            )
                                          : BoxShadow(
                                              color: Color(0x10373535),
                                              blurRadius: 10,
                                              spreadRadius: 10,
                                              offset: Offset(0, 2),
                                            ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: _buildImageWidget(imagePath),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        TextConstants.uploadImage,
                                        style: TextStyle(
                                          color: themeHelper.themeMode ==
                                                  ThemeMode.dark
                                              ? Color(0xFFFFFFFF)
                                              : Color(0xFF312E2E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    margin: const EdgeInsets.all(10.0),
                                    padding: const EdgeInsets.all(4.0),
                                    decoration: themeHelper.themeMode ==
                                            ThemeMode.dark
                                        ? BoxDecoration(
                                            color: const Color(0xFF393B4C),
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            border: Border.all(
                                                color: const Color(0xFFFE6464)),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x15000000),
                                                blurRadius: 10,
                                                spreadRadius: 0,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          )
                                        : BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            border: Border.all(
                                                color: const Color(0xFFFE6464)),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x15000000),
                                                blurRadius: 10,
                                                spreadRadius: 0,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                    child: GestureDetector(
                                      onTap: () async {
                                        var image =
                                            await _showSelectImageDialog(
                                                context: context);
                                        if (kDebugMode) {
                                          print(
                                              "2 image path selected is : $image");
                                        }
                                        setStateDialog(() => imagePath = image);
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
                          fontWeight: FontWeight.w600,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 400,
                        height: 50,
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? const Color(0xFF393B4C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? const Color(0xFF5A5A5A)
                                : const Color(0xFFE7E2E2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x10000000),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: nameController,
                          style: themeHelper.themeMode == ThemeMode.dark
                              ? TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                )
                              : TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                          decoration: InputDecoration(
                            hintText: TextConstants.categoryNameText,
                            hintStyle: TextStyle(
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? Color(0xFFB9B6B6)
                                  : Colors.grey[400],
                              fontWeight: FontWeight.bold,
                            ),
                            errorText: (!isEditing &&
                                    showError &&
                                    nameController.text.isEmpty)
                                ? TextConstants.categoryNameReqText
                                : null,
                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
=======
                  ? ThemeNotifier.secondaryBackground
                  : null,
              title: Text(TextConstants.searchAddItemText),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 700,
                  child: Row(
                    children: [
                      // ── Search field ──────────────────────────────────────
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: TextConstants.searchItemText,
                            hintText: TextConstants.typeSearchText,
                          ),
                          onChanged: (value) {
                            // 1. Immediately update local filter results
                            setStateDialog(() => _filterLocal(value));

                            // 2. Debounce API call — 500 ms (same as TopBar)
                            _debounce?.cancel();
                            if (value.trim().length >= 3) {
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                    () {
                                  if (searchController.text.trim() ==
                                      value.trim()) {
                                    _searchFromApi(
                                        value.trim(), setStateDialog);
                                  }
                                },
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // ── Results list ──────────────────────────────────────
                      Expanded(
                        child: Container(
                          height: 420,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              _filteredList.isEmpty
                                  ? Center(
                                child: Text(
                                  _isApiSearching
                                      ? "Searching..."
                                      : "Type at least 3 characters to search...",
                                  textAlign: TextAlign.center,
                                ),
                              )
                                  : Scrollbar(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredList.length,
                                  itemBuilder: (context, i) {
                                    final p = _filteredList[i];
                                    final name = _resolveName(p);
                                    final price = _resolvePrice(p);
                                    final imageUrl = _resolveImage(p);
                                    final isSelected =
                                    selectedProducts.any(
                                          (s) =>
                                      _resolveProductId(s) ==
                                          _resolveProductId(p),
                                    );

                                    return ListTile(
                                      leading: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (ctx,
                                                child,
                                                progress) =>
                                            progress == null
                                                ? child
                                                : const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth:
                                                  2),
                                            ),
                                            errorBuilder: (_, __,
                                                ___) =>
                                            const Icon(Icons
                                                .broken_image),
                                          )
                                              : const Icon(Icons.image,
                                              size: 40),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text("\$$price"),
                                      selected: isSelected,
                                      selectedTileColor:
                                      Colors.red.withOpacity(0.15),
                                      onTap: () {
                                        setStateDialog(() {
                                          final pid =
                                          _resolveProductId(p);
                                          if (pid == null) return;
                                          if (isSelected) {
                                            selectedProducts.removeWhere(
                                                    (s) =>
                                                _resolveProductId(
                                                    s) ==
                                                    pid);
                                          } else {
                                            selectedProducts.add(
                                              Map<String, dynamic>.from(
                                                p as Map,
                                              ),
                                            );
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),

                              // Thin progress bar while API loads
                              if (_isApiSearching)
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(minHeight: 3),
                                ),
                            ],
>>>>>>> origin/Grocery_pch_api_integration
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
<<<<<<< HEAD
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
                                fontSize: 16),
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
                            setStateDialog(() => isLoading = true);
                            if (isEditing) {
                              if (kDebugMode) {
                                print(
                                    "##### isEditing : $isEditing, $index, serverId: ${fastKeyTabs[index].fastkeyServerId}, Title : ${nameController.text}");
                              }
                              // Build #1.0.89: updateFastKey API call integrated
                              _fastKeyBloc.updateFastKey(
                                  title: nameController.text
                                      .trim(), // Trim whitespace
                                  index: index +
                                      1, //backend uses non zero indexes to be passed so increase index to 1 onwards
                                  imageUrl: imagePath,
                                  fastKeyServerId:
                                      fastKeyTabs[index].fastkeyServerId,
                                  userId: userId ?? 0);

                              // Listen for API response
                              final response = await _fastKeyBloc
                                  .updateFastKeyStream
                                  .firstWhere(
                                (response) =>
                                    response.status == Status.COMPLETED ||
                                    response.status == Status.ERROR,
                              );

                              if (response.status == Status.COMPLETED &&
                                  response.data != null) {
                                if (kDebugMode) {
                                  print(
                                      "### FastKeyScreen: API updateFastKey success, server ID: ${response.data!.fastkeyId}");
                                }
                                // Update the local list
                                setState(() {
                                  isLoading = false;
                                  _editingCategoryIndex = null;
                                  _loadFastKeysTabs();
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(response.data?.message ??
                                        "Fast Key updated successfully"),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else if (response.status == Status.ERROR) {
                                setStateDialog(() => isLoading = false);
                                if (response.message!
                                    .contains('Unauthorised')) {
                                  if (kDebugMode) {
                                    print(
                                        "Fast key 9 ---- Unauthorised : ${response.message!}");
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
                                            "message 9 --- ${response.message}");
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
                                } else {
                                  if (kDebugMode) {
                                    print(
                                        "### FastKeyScreen: API updateFastKey failed: ${response.message}");
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          TextConstants.failedToUpdateFastKey),
                                      // Build #1.0.144
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            } else {
                              // Add new FastKey tab
                              await _addFastKeyTab(
                                  nameController.text, imagePath);
                            }

                            // Close the dialog
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                  color: Colors.white,
                                ))
                              : Text(
                                  isEditing
                                      ? TextConstants.saveText
                                      : TextConstants.addText,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEditing)
                  TextButton(
                    onPressed: () => _showDeleteConfirmationDialog(
                        tabIndex:
                            index), // Build #1.0.104: updated delete dialog
                    child: const Text(TextConstants.deleteText,
                        style: TextStyle(color: Colors.red)),
                  ),
=======
                TextButton(
                  onPressed: () {
                    _debounce?.cancel();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedProducts.isEmpty || isSubmittingBulk
                      ? null
                      : () async {
                    _debounce?.cancel();
                    setStateDialog(() => isSubmittingBulk = true);
                    try {
                      if (_fastKeyTabId == null) {
                        throw StateError(
                            'Select a Fast Key before adding products.');
                      }
                      final tabs = await fastKeyDBHelper
                          .getFastKeyByServerTabId(_fastKeyTabId);
                      if (tabs.isEmpty) {
                        throw StateError(
                            'The selected Fast Key could not be found.');
                      }
                      final fastKeyServerId =
                      tabs.first[AppDBConst.fastKeyServerId];

                      final fetchResultFuture = _fastKeyProductBloc
                          .getProductsStream
                          .firstWhere((result) =>
                      result.status == Status.COMPLETED ||
                          result.status == Status.ERROR);
                      await _fastKeyProductBloc.fetchProductsByFastKeyId(
                        _fastKeyTabId,
                        fastKeyServerId,
                      );
                      final fetchResult = await fetchResultFuture;
                      if (fetchResult.status == Status.ERROR) {
                        throw Exception(fetchResult.message ??
                            'Could not load the current Fast Key products.');
                      }

                      final productsById = <int, int>{};
                      final currentItems = await fastKeyDBHelper
                          .getFastKeyItems(_fastKeyTabId);
                      for (final item in currentItems) {
                        final productId = int.tryParse(
                          item[AppDBConst.fastKeyProductId]?.toString() ??
                              '',
                        );
                        if (productId == null) {
                          throw FormatException(
                            'Fast Key contains an invalid product ID.',
                          );
                        }
                        productsById.putIfAbsent(
                            productId, () => productsById.length + 1);
                      }
                      for (final product in selectedProducts) {
                        final productId = _resolveProductId(product);
                        if (productId != null) {
                          productsById.putIfAbsent(
                              productId, () => productsById.length + 1);
                        }
                      }

                      final requestProducts = productsById.entries
                          .map((entry) => FastKeyProductItem(
                        productId: entry.key,
                        slNumber: entry.value,
                      ))
                          .toList();
                      final updateResultFuture = _fastKeyProductBloc
                          .addProductsStream
                          .firstWhere((result) =>
                      result.status == Status.COMPLETED ||
                          result.status == Status.ERROR);
                      await _fastKeyProductBloc.updateFastKeyProducts(
                        fastKeyId: fastKeyServerId,
                        products: requestProducts,
                      );
                      final updateResult = await updateResultFuture;
                      if (updateResult.status == Status.ERROR) {
                        throw Exception(updateResult.message ??
                            'Failed to update Fast Key products.');
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      _clearFastKeyCache(tabId: _fastKeyTabId);
                      await _loadFastKeyTabItems();
                      await _resolveFastKeyMeta();
                      if (mounted) setState(() {});
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Failed to update Fast Key products: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      isBulkAdding = false;
                      if (dialogContext.mounted) {
                        setStateDialog(() => isSubmittingBulk = false);
                      }
                    }
                  },
                  child: isSubmittingBulk
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text('Add Selected (${selectedProducts.length})'),
                ),
>>>>>>> origin/Grocery_pch_api_integration
              ],
            );
          },
        );
      },
<<<<<<< HEAD
    );
  }

  Future<String> _showSelectImageDialog(
      {required BuildContext context, int? index}) async {
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
    for (var image in mediaImages) {
      images.add(GestureDetector(
        onTap: () async {
          imagePath = image.url;
          if (kDebugMode) {
            print("1 image path selected is : $imagePath");
          }
          Navigator.pop(context);
          await Future.delayed(Duration(milliseconds: 500));
          setState(() {});
        },
        child: Container(
          padding: EdgeInsets.all(10),
          child: _buildImageWidget(image.url),
        ),
      ));
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
=======
    ).whenComplete(() {
      _debounce?.cancel();
      isBulkAdding = false;
    });
  }

  void _showCategoryDialog({required BuildContext context, int? index}) {
    bool isEditing = index != null;
    TextEditingController nameController = TextEditingController(
        text: isEditing ? fastKeyTabs[index!].fastkeyTitle : '');
    String imagePath;

    if (isEditing) {
      final existingImage = fastKeyTabs[index!].fastkeyImage;
      imagePath = (existingImage is String && existingImage.isNotEmpty)
          ? existingImage
          : 'assets/default.png';
    } else {
      imagePath = 'assets/default.png';
    }
    bool showError = false;
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
>>>>>>> origin/Grocery_pch_api_integration
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              contentPadding:
<<<<<<< HEAD
                  EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 0),
              // titlePadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
              actionsPadding: EdgeInsets.only(right: 24, top: 10),
              // insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
=======
              EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 0),
              actionsPadding: EdgeInsets.only(right: 24, top: 10),
>>>>>>> origin/Grocery_pch_api_integration
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
<<<<<<< HEAD
                    TextConstants.selectImageText,
=======
                    isEditing
                        ? TextConstants.editFastKeyNameText
                        : TextConstants.addFastKeyNameText,
>>>>>>> origin/Grocery_pch_api_integration
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: themeHelper.themeMode == ThemeMode.dark
                          ? ThemeNotifier.textDark
                          : Colors.black87,
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
<<<<<<< HEAD
              content: Container(
                width: size.width * 0.6,
                height: size.height * 0.6,
                child: CustomScrollView(
                  primary: false,
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.all(3.0),
                      sliver: SliverGrid.count(
                        mainAxisSpacing: 1, //horizontal space
                        crossAxisSpacing: 1, //vertical space
                        crossAxisCount: 7, //number of images for a row
                        children: images,
=======
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
                                          color: themeHelper.themeMode ==
                                              ThemeMode.dark
                                              ? ThemeNotifier
                                              .orderPanelTabBackground
                                              : Color(0xFFFFF7F7),
                                          blurRadius: 3,
                                          spreadRadius: 3,
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                    child:
                                    _buildImageWidget(context, imagePath)),
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
                                        setStateDialog(() => isLoading = true);
                                        var image =
                                        await _showSelectImageDialog(
                                            context: context);
                                        if (kDebugMode) {
                                          print(
                                              "2 image path selected is : $image");
                                        }
                                        setStateDialog(() {
                                          if (image != null &&
                                              image.isNotEmpty) {
                                            imagePath = image;
                                          }
                                          isLoading = false;
                                        });
                                      },
                                      child: isLoading
                                          ? SizedBox(
                                        height: 25,
                                        width: 25,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.red,
                                        ),
                                      )
                                          : Icon(
                                        Icons.edit,
                                        size: 25,
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
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        TextConstants.nameText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.paymentEntryContainerColor
                              : Colors.white,
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
                            hintStyle: TextStyle(
                                color: themeHelper.themeMode == ThemeMode.dark
                                    ? ThemeNotifier.textDark
                                    : Colors.grey[400],
                                fontWeight: FontWeight.bold),
                            errorText: (showError &&
                                nameController.text.trim().isEmpty)
                                ? TextConstants.categoryNameReqText
                                : null,
                            errorStyle: const TextStyle(
                                color: Colors.red, fontSize: 12),
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
                  padding: EdgeInsets.only(
                    bottom: 16,
                    right: isEditing ? 0 : 36,
                    left: isEditing ? 24 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 50,
                        width: 120,
                        child: TextButton(
                          onPressed: () {
                            nameController.clear();
                          },
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
                                fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        height: 50,
                        width: 120,
                        child: TextButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              setStateDialog(() => showError = true);
                              return;
                            }
                            setStateDialog(() => isLoading = true);
                            if (isEditing) {
                              if (kDebugMode) {
                                print(
                                    "##### isEditing : $isEditing, $index, serverId: ${fastKeyTabs[index].fastkeyServerId}, Title : ${nameController.text}");
                              }
                              _fastKeyBloc.updateFastKey(
                                  title: nameController.text.trim(),
                                  index: index + 1,
                                  imageUrl: imagePath,
                                  fastKeyServerId:
                                  fastKeyTabs[index].fastkeyServerId,
                                  userId: userId ?? 0);

                              final response = await _fastKeyBloc
                                  .updateFastKeyStream
                                  .firstWhere(
                                    (response) =>
                                response.status == Status.COMPLETED ||
                                    response.status == Status.ERROR,
                              );

                              if (response.status == Status.COMPLETED &&
                                  response.data != null) {
                                if (kDebugMode) {
                                  print(
                                      "### FastKeyScreen: API updateFastKey success, server ID: ${response.data!.fastkeyId}");
                                }
                                setState(() {
                                  isLoading = false;
                                  _editingCategoryIndex = null;
                                  _loadFastKeysTabs();
                                });
                                if (Misc.showDebugSnackBar) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response.data?.message ??
                                          "Fast Key updated successfully"),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else if (response.status == Status.ERROR) {
                                setStateDialog(() => isLoading = false);
                                if (response.message!
                                    .contains('Unauthorised')) {
                                  if (kDebugMode) {
                                    print(
                                        "Fast key 9 ---- Unauthorised : ${response.message!}");
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
                                            "message 9 --- ${response.message}");
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
                                } else {
                                  if (kDebugMode) {
                                    print(
                                        "### FastKeyScreen: API updateFastKey failed: ${response.message}");
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response.message ??
                                            TextConstants.failedToUpdateFastKey,
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            } else {
                              await _addFastKeyTab(
                                  nameController.text, imagePath);
                            }
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ))
                              : Text(
                            isEditing
                                ? TextConstants.saveText
                                : TextConstants.addText,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      /// DELETE (only in edit)
                      if (isEditing)
                        SizedBox(
                          height: 50,
                          width: 110,
                          child: TextButton(
                            onPressed: () =>
                                _showDeleteConfirmationDialog(tabIndex: index),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.red, width: 1.5),
                              ),
                            ),
                            child: const Text(
                              TextConstants.deleteText,
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _showSelectImageDialog({
    required BuildContext context,
    int? index,
  }) async {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    bool isDark = themeHelper.themeMode == ThemeMode.dark;

    String imagePath = "";
    var size = MediaQuery.of(context).size;
    final fastKeyImages = await OrderRepository().getFastKeyImages();
    final types = fastKeyImages.keys.toList();

    int selectedTab = 0;

    List<FastKeyImageModel> getCurrentList() {
      if (types.isEmpty) return [];
      return fastKeyImages[types[selectedTab]] ?? [];
    }

    var selectedImage = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor:
              isDark ? ThemeNotifier.secondaryBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.only(left: 24, right: 24, top: 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Image",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? ThemeNotifier.textDark : Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[400],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
              content: SizedBox(
                width: size.width * 0.65,
                height: size.height * 0.65,
                child: Column(
                  children: [
                    if (types.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          for (int i = 0; i < types.length; i++) ...[
                            _buildTabButton(
                              label: types[i],
                              index: i,
                              selectedIndex: selectedTab,
                              isDark: isDark,
                              onTap: () =>
                                  setStateDialog(() => selectedTab = i),
                            ),
                            SizedBox(width: 10),
                          ],
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    /// IMAGE GRID
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Color(0xFF34384A) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: getCurrentList().isEmpty
                            ? Center(
                          child: Text(
                            'No Fast Key images are available.',
                            style: TextStyle(
                              color:
                              isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        )
                            : GridView.builder(
                          itemCount: getCurrentList().length,
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (_, i) {
                            final img = getCurrentList()[i];
                            return GestureDetector(
                              onTap: () =>
                                  Navigator.pop(context, img.url),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child:
                                _buildImageWidget(context, img.url),
                              ),
                            );
                          },
                        ),
>>>>>>> origin/Grocery_pch_api_integration
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
<<<<<<< HEAD
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
    if (imagePath.isEmpty)
      return _safeSvgPicture('assets/svg/password_placeholder.svg');
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return _safeSvgPicture(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child:
              Image.asset(imagePath, height: 80, width: 80, fit: BoxFit.cover));
=======
    );

    return selectedImage ?? imagePath;
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required int selectedIndex,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = index == selectedIndex;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF8A80),
                  Color(0xFFFF6E6E),
                  Color(0xFFFE6464),
                ],
              )
                  : null,
              color: isSelected
                  ? null
                  : (isDark ? Color(0xFF4D505F) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context, String imagePath) {
    if (kDebugMode) {
      print("_buildImageWidget for imagePath: $imagePath");
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    print("isDark: $isDark");

    final String defaultImage =
    isDark ? 'assets/default_dark.png' : 'assets/default.png';

    final String defaultSvg = isDark
        ? 'assets/svg/password_placeholder.svg'
        : 'assets/svg/password_placeholder.svg';

    if (imagePath.isEmpty) {
      return _safeSvgPicture(defaultSvg, defaultImage);
    }

    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return _safeSvgPicture(imagePath, defaultImage);
    } else if (imagePath.startsWith('assets/')) {
      final String finalPath =
      imagePath == 'assets/default.png' ? defaultImage : imagePath;

      return ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.asset(
          finalPath,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            defaultImage,
            height: 80,
            width: 80,
          ),
        ),
      );
>>>>>>> origin/Grocery_pch_api_integration
    } else if (imagePath.startsWith("http")) {
      return Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
<<<<<<< HEAD
            borderRadius: BorderRadius.circular(16), color: Colors.white38),
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
=======
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Image.network(
            imagePath,
            width: 75,
            height: 75,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                defaultImage,
                width: 75,
                height: 75,
              );
            },
          ),
        ),
>>>>>>> origin/Grocery_pch_api_integration
      );
    } else {
      return Platform.isWindows
          ? Image.asset(
<<<<<<< HEAD
              'assets/default.png',
              height: 75,
              width: 75,
            )
          : Image.file(
              File(imagePath),
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _safeSvgPicture('assets/svg/password_placeholder.svg'),
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
          child: Image.asset('assets/default.png', height: 80, width: 80));
    }
  }



=======
        defaultImage,
        height: 75,
        width: 75,
      )
          : Image.file(
        File(imagePath),
        height: 80,
        width: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _safeSvgPicture(defaultSvg, defaultImage),
      );
    }
  }

  Widget _safeSvgPicture(String assetPath, String fallbackImage) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: SvgPicture.asset(
          assetPath,
          height: 80,
          width: 80,
          placeholderBuilder: (context) => const Icon(Icons.image, size: 40),
        ),
      );
    } catch (e) {
      debugPrint("FastKeyScreen: SVG Parsing Error: $e");
      return ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.asset(
          fallbackImage,
          height: 80,
          width: 80,
        ),
      );
    }
  }

>>>>>>> origin/Grocery_pch_api_integration
  // Build #1.0.104: updated delete dialog with this new implementation
  void _showDeleteConfirmationDialog({
    int? tabIndex,
    int? itemIndex,
  }) async {
    bool? result = await CustomDialog.showAreYouSure(
      context,
      confirm: () async {
<<<<<<< HEAD
        // This callback only runs if user confirms (clicks Yes)
=======
>>>>>>> origin/Grocery_pch_api_integration
        try {
          setState(() => _isDeleting = true);

          if (tabIndex != null) {
            final tab = fastKeyTabs[tabIndex];
            await _deleteFastKeyTab(fastKeyTabServerId: tab.fastkeyServerId);
          } else if (itemIndex != null) {
<<<<<<< HEAD
            final fastKeyTabItemServerId =
                fastKeyProductItems[itemIndex][AppDBConst.fastKeyProductId];
            await _deleteFastKeyTabItem(int.parse(fastKeyTabItemServerId));
            setState(() {
              enableIcons = false; // Build #1.0.204: Hide icons after deletion
              selectedItemIndex = null; // Clear selection
=======
            final rawProductId =
            fastKeyProductItems[itemIndex][AppDBConst.fastKeyProductId];
            final productId = rawProductId is num
                ? rawProductId.toInt()
                : int.tryParse(rawProductId?.toString() ?? '');
            if (productId == null || productId <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot delete this item: invalid product ID.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            await _deleteFastKeyTabItem(productId);
            setState(() {
              enableIcons = false;
              selectedItemIndex = null;
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
    // Only close the category dialog if deleting a tab AND user confirmed
=======
>>>>>>> origin/Grocery_pch_api_integration
    if (result == true && tabIndex != null && mounted) {
      Navigator.pop(context);
    }
  }

<<<<<<< HEAD
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
=======
  Future<void> _resolveFastKeyMeta() async {
    debugPrint("🧠 START _resolveFastKeyMeta");

    await _ingestProductMetaFromMerged();

    for (int i = 0; i < fastKeyProductItems.length; i++) {
      final item = Map<String, dynamic>.from(fastKeyProductItems[i]);
      fastKeyProductItems[i] = item;

      final productId =
      int.tryParse(item["fast_key_product_id"]?.toString() ?? "");

      if (productId == null) {
        debugPrint("⛔ Skipping item without productId");
        continue;
      }

      debugPrint("🔍 Resolving meta for productId=$productId");

      await _enrichFastKeyItemFromSkuHive(item);

      // ✅ PRESERVE FastKey's own loyalty points (don't override from cache)
      int fastKeyLoyaltyPoints = 0;

      // Check if item already has loyalty_points from FastKey API
      if (item["loyalty_points"] != null) {
        fastKeyLoyaltyPoints =
            int.tryParse(item["loyalty_points"].toString()) ?? 0;
      }

      // Check meta_data from FastKey
      if (fastKeyLoyaltyPoints == 0 && item["meta_data"] is List) {
        final loyaltyEntry = (item["meta_data"] as List).firstWhere(
              (m) => m['key'] == '_product_loyalty_points',
          orElse: () => <String, dynamic>{},
        );
        if (loyaltyEntry.isNotEmpty) {
          fastKeyLoyaltyPoints =
              int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
        }
      }

      // Get cached product data for other attributes (EBT, variants)
      final cached = await _getCachedProductFromIsar(productId);

      if (cached != null) {
        // ✅ ONLY update meta_data if FastKey doesn't have its own loyalty points
        if (fastKeyLoyaltyPoints == 0 && cached['meta_data'] != null) {
          item['meta_data'] = cached['meta_data'];

          // Extract loyalty from cache as fallback
          final loyaltyEntry = (cached['meta_data'] as List).firstWhere(
                (m) => m['key'] == '_product_loyalty_points',
            orElse: () => <String, dynamic>{},
          );
          if (loyaltyEntry.isNotEmpty) {
            item['loyalty_points'] =
                int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
          }
        } else if (fastKeyLoyaltyPoints > 0) {
          // ✅ Keep FastKey's own loyalty points
          item['loyalty_points'] = fastKeyLoyaltyPoints;

          // Ensure meta_data has the loyalty points
          if (item['meta_data'] is! List) {
            item['meta_data'] = [
              {
                "key": "_product_loyalty_points",
                "value": fastKeyLoyaltyPoints.toString()
              }
            ];
          } else {
            // Check if meta_data already has loyalty entry
            final hasLoyalty = (item['meta_data'] as List)
                .any((m) => m['key'] == '_product_loyalty_points');
            if (!hasLoyalty) {
              (item['meta_data'] as List).add({
                "key": "_product_loyalty_points",
                "value": fastKeyLoyaltyPoints.toString()
              });
            }
          }
        }

        // Update EBT status from fresh data (but preserve loyalty)
        final isEbt = _isProductEbtEligible({
          "is_ebt_eligible":
          item['is_ebt_eligible'] ?? cached['is_ebt_eligible'],
          "meta_data": item['meta_data'] ?? cached['meta_data'],
          "fast_key_item_tags": item['fast_key_item_tags'] ?? cached['tags'],
          "tags": cached['tags'],
        });
        item['is_ebt_eligible'] = isEbt;
      }

      // Update variants
      final hasVariants = await _fastKeyHasVariants(item);
      item['has_variants'] = hasVariants;

      debugPrint(
        "🧩 VARIANT → productId=$productId | hasVariants=$hasVariants",
      );

      debugPrint(
        "🥗 EBT → productId=$productId | isEbt=${item['is_ebt_eligible']}",
      );

      debugPrint(
        "⭐ LOYALTY → productId=$productId | points=${item['loyalty_points'] ?? 0} (from FastKey API)",
      );
    }

    debugPrint("✅ END _resolveFastKeyMeta");

    if (mounted) setState(() {});
  }

  bool _isProductEbtEligible(Map<String, dynamic> item) {
    if (_truthyEbtValue(item["is_ebt_eligible"])) return true;
    if (_ebtEligibleFromMetaData(item["meta_data"])) return true;

    final dynamic tagsRaw = item["fast_key_item_tags"] ?? item["tags"];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        if (t is Map) {
          final name = (t["name"] ?? "").toString().toLowerCase();
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          if (name.contains("ebt") || slug.contains("ebt")) return true;
        }
      }
    }

    return false;
  }

  @override
  void dispose() {
    // ✅ Remove listener
    TopBar.mergedProductCacheRevision
        .removeListener(_onMergedProductCacheRevision);
    // ✅ Clear callback to prevent calling disposed state
    TopBar.onRefreshCompleted = null;

    WidgetsBinding.instance.removeObserver(this);
    _fastKeyBloc.dispose();
    orderBloc.dispose();
>>>>>>> origin/Grocery_pch_api_integration
    _fastKeyProductBloc.dispose();
    _productSearchController.dispose();
    fastKeyTabIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final screenWidth = MediaQuery.of(context).size.width;
    String formattedDate = DateFormat("EEE, MMM d' ${now.year}'").format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

=======
>>>>>>> origin/Grocery_pch_api_integration
    final categories = fastKeyTabs.map((tab) {
      return {
        'title': tab.fastkeyTitle,
        'image': tab.fastkeyImage,
        'itemCount': tab.itemCount,
      };
    }).toList();

<<<<<<< HEAD
    // Define showAddButton here to match the value passed to NestedGridWidget
    const bool showAddButton = true;

=======
    const bool showAddButton = true;

    if (widget.embedInShell) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          CategoryList(
            scrollController: _scrollController,
            isHorizontal: true,
            isLoading: isTabsLoading,
            isAddButtonEnabled: true,
            categories: categories,
            selectedIndex: _selectedCategoryIndex,
            editingIndex: _editingCategoryIndex,
            onAddButtonPressed: () => _showCategoryDialog(context: context),
            onCategoryTapped: (index) async {
              if (_selectedCategoryIndex == index) return;
              if (_editingCategoryIndex != index) {
                setState(() {
                  _selectedCategoryIndex = index;
                  _editingCategoryIndex = null;
                  _fastKeyTabId = fastKeyTabs[index].fastkeyServerId;
                  fastKeyTabIdNotifier.value = _fastKeyTabId;
                });
                await fastKeyDBHelper
                    .saveActiveFastKeyTab(fastKeyTabs[index].fastkeyServerId);
              } else {
                setState(() => _editingCategoryIndex = null);
              }
            },
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                final item = fastKeyTabs.removeAt(oldIndex);
                fastKeyTabs.insert(newIndex, item);
                if (_selectedCategoryIndex == oldIndex) {
                  _selectedCategoryIndex = newIndex;
                } else if (oldIndex < _selectedCategoryIndex! &&
                    newIndex >= _selectedCategoryIndex!) {
                  _selectedCategoryIndex = _selectedCategoryIndex! - 1;
                } else if (oldIndex > _selectedCategoryIndex! &&
                    newIndex <= _selectedCategoryIndex!) {
                  _selectedCategoryIndex = _selectedCategoryIndex! + 1;
                }
                if (_editingCategoryIndex == oldIndex)
                  _editingCategoryIndex = newIndex;
                _fastKeyBloc.updateFastKey(
                    title: item.fastkeyTitle,
                    index: newIndex + 1,
                    imageUrl: item.fastkeyImage,
                    fastKeyServerId: item.fastkeyServerId,
                    userId: item.userId);
              });
              for (int i = 0; i < fastKeyTabs.length; i++) {
                await fastKeyDBHelper.updateFastKeyTab(
                    fastKeyTabs[i].fastkeyServerId,
                    {AppDBConst.fastKeyTabIndex: i.toString()});
              }
            },
            onReorderStarted: (index) =>
                setState(() => _editingCategoryIndex = index),
            onEditButtonPressed: (index) {
              setState(() => _editingCategoryIndex = index);
              _showCategoryDialog(context: context, index: index);
            },
            onDismissEditMode: () =>
                setState(() => _editingCategoryIndex = null),
          ),
          Expanded(
            child: ValueListenableBuilder<dynamic>(
              valueListenable: fastKeyTabIdNotifier,
              builder: (context, fastKeyTabId, child) {
                return fastKeyTabId != null
                    ? NestedGridWidget(
                  productBloc: productBloc,
                  orderHelper: orderHelper,
                  isPaginating: _isPaginating,
                  isHorizontal: true,
                  isLoading: isTabsLoading || isItemsLoading,
                  showAddButton: showAddButton,
                  items: fastKeyProductItems,
                  selectedItemIndex: selectedItemIndex,
                  reorderedIndices: reorderedIndices,
                  onAddButtonPressed: () => _showAddItemDialog(),
                  onItemTapped: (index, {bool? variantAdded}) =>
                      _onItemSelected(
                          index, showAddButton, variantAdded ?? false),
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex == 0 || newIndex == 0) return;
                    final adjustedOldIndex = oldIndex - 1;
                    final adjustedNewIndex = newIndex - 1;
                    if (adjustedOldIndex < 0 ||
                        adjustedNewIndex < 0 ||
                        adjustedOldIndex >= fastKeyProductItems.length ||
                        adjustedNewIndex >= fastKeyProductItems.length)
                      return;
                    setState(() {
                      fastKeyProductItems =
                      List<Map<String, dynamic>>.from(
                          fastKeyProductItems);
                      final item =
                      fastKeyProductItems.removeAt(adjustedOldIndex);
                      fastKeyProductItems.insert(adjustedNewIndex, item);
                      reorderedIndices =
                          List.filled(fastKeyProductItems.length, null);
                      reorderedIndices[adjustedNewIndex] =
                          adjustedNewIndex;
                      selectedItemIndex = adjustedNewIndex;
                    });
                    fastKeyDBHelper.updateFastKeyItemOrder(
                        _fastKeyTabId!, fastKeyProductItems);
                  },
                  onDeleteItem: (index) =>
                      _showDeleteConfirmationDialog(itemIndex: index),
                  onCancelReorder: _onCancelReorder,
                  showBackButton: false,
                  enableIcons: enableIcons,
                  onLongPress: _onLongPress,
                )
                    : Container();
              },
            ),
          ),
        ],
      );
    }

>>>>>>> origin/Grocery_pch_api_integration
    return Scaffold(
      body: Column(
        children: [
          TopBar(
            screen: Screen.FASTKEY,
            onModeChanged: () async {
<<<<<<< HEAD
              /// Build #1.0.192: Fixed -> Exception -> setState() callback argument returned a Future. (onModeChanged in all screens)
=======
>>>>>>> origin/Grocery_pch_api_integration
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
<<<<<<< HEAD
                newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
              }

              // Update the notifier which will trigger _onLayoutChanged
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              // No need to call saveLayoutSelection here as it's handled in the notifier
              //   _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
              // update UI
=======
                newLayout = orderPanelPosition == OrderPanelPosition.left
                    ? SharedPreferenceTextConstants.navBottomOrderRight
                    : SharedPreferenceTextConstants.navLeftOrderRight;
              }

              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
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
                await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId ??
                    fastKeyTabs[_selectedCategoryIndex ?? 0].fastkeyServerId);
              } catch (e, s) {
                if (kDebugMode)
                  print("Exception in onProductSelected: $e, Stack: $s");
                //  setState(() => isAddingItemLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(TextConstants.errorAddingItem), // Build #1.0.144
=======
              try {
                if (kDebugMode) print("#### FastKey serverOrderId");
                _refreshOrderList();
                if (fastKeyTabs.isNotEmpty)
                  await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId ??
                      fastKeyTabs[_selectedCategoryIndex ?? 0].fastkeyServerId);
              } catch (e, s) {
                if (kDebugMode)
                  print("Exception in onProductSelected: $e, Stack: $s");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(TextConstants.errorAddingItem),
>>>>>>> origin/Grocery_pch_api_integration
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
                    (sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
<<<<<<< HEAD
                    formattedDate: formattedDate,
                    formattedTime: formattedTime,
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey:
                        _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
=======
                    key: const ValueKey('order_panel'),
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey: _refreshCounter,
>>>>>>> origin/Grocery_pch_api_integration
                  ),
                Expanded(
                  child: Column(
                    children: [
                      CategoryList(
<<<<<<< HEAD
=======
                        scrollController: _scrollController,
>>>>>>> origin/Grocery_pch_api_integration
                        isHorizontal: true,
                        isLoading: isTabsLoading,
                        isAddButtonEnabled: true,
                        categories: categories,
                        selectedIndex: _selectedCategoryIndex,
                        editingIndex: _editingCategoryIndex,
                        onAddButtonPressed: () =>
                            _showCategoryDialog(context: context),
                        onCategoryTapped: (index) async {
<<<<<<< HEAD
=======
                          if (_selectedCategoryIndex == index) {
                            if (kDebugMode) {
                              print(
                                  "### FastKeyScreen: Same category tapped, ignoring: $index");
                            }
                            return;
                          }
>>>>>>> origin/Grocery_pch_api_integration
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onCategoryTapped called for index: $index, ID: ${fastKeyTabs[index].fastkeyServerId}");
                          }
<<<<<<< HEAD
                          //Build #1.0.68: updated
=======
>>>>>>> origin/Grocery_pch_api_integration
                          if (_editingCategoryIndex != index) {
                            setState(() {
                              _selectedCategoryIndex = index;
                              _editingCategoryIndex = null;
                              _fastKeyTabId =
                                  fastKeyTabs[index].fastkeyServerId;
                              fastKeyTabIdNotifier.value = _fastKeyTabId;
                            });
                            await fastKeyDBHelper.saveActiveFastKeyTab(
                                fastKeyTabs[index].fastkeyServerId);
                            if (kDebugMode) {
<<<<<<< HEAD
                              //Build #1.0.84
=======
>>>>>>> origin/Grocery_pch_api_integration
                              print(
                                  "### FastKeyScreen: Saved active tab ID: ${fastKeyTabs[index].fastkeyServerId}");
                            }
                          } else {
                            setState(() {
                              _editingCategoryIndex = null;
                            });
                          }
                        },
                        onReorder: (oldIndex, newIndex) async {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onReorder called from $oldIndex to $newIndex");
                          }
                          setState(() {
                            final item = fastKeyTabs.removeAt(oldIndex);
                            fastKeyTabs.insert(newIndex, item);
                            if (_selectedCategoryIndex == oldIndex) {
                              _selectedCategoryIndex = newIndex;
                            } else if (oldIndex < _selectedCategoryIndex! &&
                                newIndex >= _selectedCategoryIndex!) {
                              _selectedCategoryIndex =
                                  _selectedCategoryIndex! - 1;
                            } else if (oldIndex > _selectedCategoryIndex! &&
                                newIndex <= _selectedCategoryIndex!) {
                              _selectedCategoryIndex =
                                  _selectedCategoryIndex! + 1;
                            }
<<<<<<< HEAD
                            //Build 1.1.36: Update editingIndex to the new position
                            if (_editingCategoryIndex == oldIndex) {
                              _editingCategoryIndex = newIndex;
                            }

                            ///update the index in backend as well
=======
                            if (_editingCategoryIndex == oldIndex) {
                              _editingCategoryIndex = newIndex;
                            }
>>>>>>> origin/Grocery_pch_api_integration
                            _fastKeyBloc.updateFastKey(
                                title: item.fastkeyTitle,
                                index: newIndex + 1,
                                imageUrl: item.fastkeyImage,
                                fastKeyServerId: item.fastkeyServerId,
                                userId: item.userId);
                          });
<<<<<<< HEAD
                          // Update indices in the database
=======
>>>>>>> origin/Grocery_pch_api_integration
                          for (int i = 0; i < fastKeyTabs.length; i++) {
                            await fastKeyDBHelper.updateFastKeyTab(
                                fastKeyTabs[i].fastkeyServerId, {
                              AppDBConst.fastKeyTabIndex: i.toString(),
                            });
                          }
                        },
                        onReorderStarted: (index) {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onReorderStarted called for index: $index");
                          }
                          setState(() {
<<<<<<< HEAD
                            _editingCategoryIndex =
                                index; // Set editing index for the item being reordered
=======
                            _editingCategoryIndex = index;
>>>>>>> origin/Grocery_pch_api_integration
                          });
                        },
                        onEditButtonPressed: (index) {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onEditButtonPressed called for index: $index");
                          }
                          setState(() {
<<<<<<< HEAD
                            _editingCategoryIndex =
                                index; // Set editing index for the item
=======
                            _editingCategoryIndex = index;
>>>>>>> origin/Grocery_pch_api_integration
                          });
                          _showCategoryDialog(context: context, index: index);
                        },
                        onDismissEditMode: () {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onDismissEditMode called");
                          }
                          setState(() {
<<<<<<< HEAD
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
                                  onAddButtonPressed: () =>
                                      _showAddItemDialog(),
                                  onItemTapped: (index, {bool? variantAdded}) =>
                                      _onItemSelected(
                                          index, showAddButton, variantAdded!),
                                  onReorder: (oldIndex, newIndex) {
                                    if (oldIndex == 0 || newIndex == 0) return;
                                    final adjustedOldIndex = oldIndex - 1;
                                    final adjustedNewIndex = newIndex - 1;
                                    if (adjustedOldIndex < 0 ||
                                        adjustedNewIndex < 0 ||
                                        adjustedOldIndex >=
                                            fastKeyProductItems.length ||
                                        adjustedNewIndex >=
                                            fastKeyProductItems.length) {
                                      return;
                                    }
                                    setState(() {
                                      fastKeyProductItems =
                                          List<Map<String, dynamic>>.from(
                                              fastKeyProductItems);
                                      final item = fastKeyProductItems
                                          .removeAt(adjustedOldIndex);
                                      fastKeyProductItems.insert(
                                          adjustedNewIndex, item);
                                      reorderedIndices = List.filled(
                                          fastKeyProductItems.length, null);
                                      reorderedIndices[adjustedNewIndex] =
                                          adjustedNewIndex;
                                      selectedItemIndex = adjustedNewIndex;
                                    });
                                    // Update database with new order
                                    fastKeyDBHelper.updateFastKeyItemOrder(
                                        _fastKeyTabId!, fastKeyProductItems);
                                  },
                                  onDeleteItem: (index) {
                                    // final itemId = fastKeyProductItems[index][AppDBConst.fastKeyProductId]; //Build #1.0.89
                                    // if (kDebugMode) {
                                    //   print('FastkeyScreen - Delete Fastkey item at index: $index, itemId: $itemId');
                                    // }
                                    // _deleteFastKeyTabItem(int.parse(itemId));
                                    _showDeleteConfirmationDialog(
                                        itemIndex:
                                            index); // Build #1.0.104: updated delete dialog
                                  },
                                  // onCancelReorder: () {
                                  //   setState(() {
                                  //     reorderedIndices = List.filled(fastKeyProductItems.length, null);
                                  //   });
                                  // },
                                  onCancelReorder:
                                      _onCancelReorder, // Build #1.0.204: Updated method
                                  showBackButton: false,
                                  enableIcons:
                                      enableIcons, // Build #1.0.204: Passing enableIcons
                                  onLongPress:
                                      _onLongPress, // Passing onLongPress callback
                                )
                              : Container();
                          // : const Center(child: Text("Please select a category"));
=======
                            _editingCategoryIndex = null;
                          });
                        },
                      ),
                      ValueListenableBuilder<dynamic>(
                        valueListenable: fastKeyTabIdNotifier,
                        builder: (context, fastKeyTabId, child) {
                          return fastKeyTabId != null
                              ? NestedGridWidget(
                            productBloc: productBloc,
                            orderHelper: orderHelper,
                            isPaginating: _isPaginating,
                            isHorizontal: true,
                            isLoading: isTabsLoading || isItemsLoading,
                            showAddButton: showAddButton,
                            items: fastKeyProductItems,
                            selectedItemIndex: selectedItemIndex,
                            reorderedIndices: reorderedIndices,
                            onAddButtonPressed: () =>
                                _showAddItemDialog(),
                            onItemTapped: (index, {bool? variantAdded}) {
                              _onItemSelected(index, showAddButton,
                                  variantAdded ?? false);
                            },
                            onReorder: (oldIndex, newIndex) {
                              if (oldIndex == 0 || newIndex == 0) return;
                              final adjustedOldIndex = oldIndex - 1;
                              final adjustedNewIndex = newIndex - 1;
                              if (adjustedOldIndex < 0 ||
                                  adjustedNewIndex < 0 ||
                                  adjustedOldIndex >=
                                      fastKeyProductItems.length ||
                                  adjustedNewIndex >=
                                      fastKeyProductItems.length) {
                                return;
                              }
                              setState(() {
                                fastKeyProductItems =
                                List<Map<String, dynamic>>.from(
                                    fastKeyProductItems);
                                final item = fastKeyProductItems
                                    .removeAt(adjustedOldIndex);
                                fastKeyProductItems.insert(
                                    adjustedNewIndex, item);
                                reorderedIndices = List.filled(
                                    fastKeyProductItems.length, null);
                                reorderedIndices[adjustedNewIndex] =
                                    adjustedNewIndex;
                                selectedItemIndex = adjustedNewIndex;
                              });
                              fastKeyDBHelper.updateFastKeyItemOrder(
                                  _fastKeyTabId!, fastKeyProductItems);
                            },
                            onDeleteItem: (index) {
                              _showDeleteConfirmationDialog(
                                  itemIndex: index);
                            },
                            onCancelReorder: _onCancelReorder,
                            showBackButton: false,
                            enableIcons: enableIcons,
                            onLongPress: _onLongPress,
                          )
                              : Container();
>>>>>>> origin/Grocery_pch_api_integration
                        },
                      )
                    ],
                  ),
                ),
                if (sidebarPosition != SidebarPosition.right &&
                    !(sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
<<<<<<< HEAD
                    formattedDate: formattedDate,
                    formattedTime: formattedTime,
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey:
                        _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
=======
                    key: const ValueKey('order_panel'),
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey: _refreshCounter,
>>>>>>> origin/Grocery_pch_api_integration
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
                if (mounted) {
<<<<<<< HEAD
                  //Build #1.0.54
=======
>>>>>>> origin/Grocery_pch_api_integration
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
