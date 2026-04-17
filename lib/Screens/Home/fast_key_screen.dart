import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Database/assets_db_helper.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Database/isar_service.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/auto_search.dart';
import '../../Helper/customerdisplayhelper.dart';
import '../../Providers/Age/age_verification_provider.dart';
import '../../Utilities/global_utility.dart';
import '../../Models/FastKey/fastkey_product_model.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Models/Search/product_by_sku_model.dart' as SKU;
import '../../Models/Search/product_search_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
import '../../Utilities/svg_images_utility.dart';
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
import '../../Utilities/svg_images_utility.dart';
import '../../Database/db_helper.dart';
import '../../Widgets/widget_variants_dialog.dart';
import '../Auth/login_screen.dart';

class FastKeyScreen extends StatefulWidget {
  final int? lastSelectedIndex;

  /// When true, only the center content is shown (no TopBar, NavBar, RightOrderPanel).
  /// Used by POSHomeScreen to embed in IndexedStack.
  final bool embedInShell;

  const FastKeyScreen(
      {super.key, this.lastSelectedIndex, this.embedInShell = false});

  @override
  State<FastKeyScreen> createState() => _FastKeyScreenState();
}

class _FastKeyScreenState extends State<FastKeyScreen>
    with WidgetsBindingObserver, LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 0;
  List<int> quantities = [1, 1, 1, 1];
  // SidebarPosition sidebarPosition = SidebarPosition.left;
  // OrderPanelPosition orderPanelPosition = OrderPanelPosition.right;
  bool isLoading = true;
  bool isBulkAdding = false;
  bool isimageLoading = false;

  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null);
  final FastKeyDBHelper fastKeyDBHelper = FastKeyDBHelper();
  late FastKeyBloc _fastKeyBloc;
  List<FastKey> fastKeyTabs = [];
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
  bool _isPaginating = false;
  int? userId;
  static final Map<int, Map<String, dynamic>> _productMetaCache = {};

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
  int? _fastKeyTabId;
  List<int?> reorderedIndices = [];
  int? selectedItemIndex;
  bool?
  enableIcons; // Build #1.0.204: Added this to track grid item delete/cancel icon visibility
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
  bool _isDeleting =
  false; // Build #1.0.104 : Track delete button loading state
  bool isAddingItemLoading = false; // Loader for adding items to order
  final ScrollController _scrollController = ScrollController();
  int _refreshCounter =
  0; //Build #1.0.170: Added: Counter to trigger RightOrderPanel refresh only when needed

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
    TopBar.mergedProductCacheRevision
        .addListener(_onMergedProductCacheRevision);
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
      enableIcons = true; // Show icons
      selectedItemIndex = itemIndex; // Track the long-pressed item
    });
  }

  void _onCancelReorder() {
    // Build #1.0.204
    setState(() {
      reorderedIndices = List.filled(fastKeyProductItems.length, null);
      enableIcons = false; // Hide icons
      selectedItemIndex = null; // Clear selection
    });
  }

  void _listenProductItemSearch() {
    final t = _productSearchController.text.trim();
    if (t.isEmpty || t.length < 3) {
      _searchTextGridKey.currentState?.resetList();
    }
    _autoSuggest.listentextchange(_productSearchController.text ?? "");
  }

  Future<void> _onTabChanged() async {
    if (kDebugMode) {
      print(
          "### FastKeyScreen: _onTabChanged: New Tab ID: ${fastKeyTabIdNotifier.value}");
    }
    setState(() {
      _fastKeyTabId = fastKeyTabIdNotifier.value;
      fastKeyProductItems.clear();
      isItemsLoading =
      true; //Build #1.0.92: Fixed Issue: Loader is not working at fast key grid for selected tab
    });
    if (_fastKeyTabId != null) {
      //Build #1.0.84
      await fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId!);
      if (kDebugMode) {
        print(
            "### FastKeyScreen: Saved active tab ID in _onTabChanged: $_fastKeyTabId");
      }
      await _loadFastKeyTabItems();
      await _resolveFastKeyMeta();
    }
  }

  /// Align Fast Keys with TopBar’s merged Isar/Hive read so EBT resolves on first paint.
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
      if (!mounted || _fastKeyTabId == null || fastKeyProductItems.isEmpty) {
        return;
      }
      await _ingestProductMetaFromMerged();
      if (!mounted) return;
      await _resolveFastKeyMeta();
    });
  }

  Future<void> getUserIdFromDB() async {
    try {
      final userData = await UserDbHelper().getUserData();
      if (userData != null && userData[AppDBConst.userId] != null) {
        userId = userData[AppDBConst.userId] as int;

        ///stop loading fast key every time
        if (kDebugMode) {
          print(
              "FastKeyScreen.getUserIdFromDB -> FastKeyDBHelper.isFastkeyLoaded = ${FastKeyDBHelper.isFastkeyLoaded}");
        }
        if (FastKeyDBHelper.isFastkeyLoaded) {
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
            } else {
              _fastKeyBloc.getFastKeysSink
                  .add(APIResponse.error(TextConstants.retryText));
            }
          } else if (onData.status == Status.COMPLETED) {
            if (onData.data != null) {
              final fastKeysResponse = onData.data!;
              if (fastKeysResponse.status != "success") {
                _fastKeyBloc.getFastKeysSink
                    .add(APIResponse.error(TextConstants.retryText));
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
  Future<void> loadTabs() async {
    // Build  #1.0.177: add await to loadTabs to fix delay in loading
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
    final fastKeyTabsData =
    await fastKeyDBHelper.getFastKeyTabsByUserId(userId ?? 1);
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
            product[AppDBConst.fastKeyTabIndex]?.toString() ?? '0',
            itemCount: int.tryParse(
                product[AppDBConst.fastKeyTabItemCount]?.toString() ??
                    '0') ??
                0,
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
      print(
          "### FastKeyScreen: _addFastKeyTab started with title: $title, image: $imageToSend");
    }
    // Call API to create FastKey on server via BLoC
    _fastKeyBloc.createFastKey(
        title: title,
        index: fastKeyTabs.length + 1,
        imageUrl: imageToSend,
        userId: userId ?? 1);

    // Listen for API response
    final response = await _fastKeyBloc.createFastKeyStream.firstWhere(
            (response) =>
        response.status == Status.COMPLETED ||
            response.status == Status.ERROR);
    if (response.status == Status.COMPLETED && response.data != null) {
      if (kDebugMode) {
        print(
            "### FastKeyScreen: API createFastKey success, server ID: ${response.data!.fastkeyId}");
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
          print(
              "### FastKeyScreen: Updated UI, selected tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      });
    } else if (response.status == Status.ERROR) {
      // Build #1.0.189: Only Show when it comes response as error
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
                Text("Unauthorised. Session is expired on this device."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
        // Handle API error
        if (kDebugMode) {
          print(
              "### FastKeyScreen: API createFastKey failed: ${response.message}");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(response.message ?? TextConstants.failedToCreateFastKey),
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
      print(
          "### FastKeyScreen: _deleteFastKeyTab started with server ID: $fastKeyTabServerId");
    }
    _fastKeyBloc.deleteFastKey(fastKeyTabServerId, userId ?? 1);

    int? nextActiveTabId;
    setState(() {
      final int deletedIndex = fastKeyTabs.indexWhere(
              (tab) => tab.fastkeyServerId == fastKeyTabServerId);
      final int? prevSelectedIndex = _selectedCategoryIndex;

      if (deletedIndex != -1) {
        fastKeyTabs.removeAt(deletedIndex);
      }

      if (fastKeyTabs.isEmpty) {
        _selectedCategoryIndex = null;
        _fastKeyTabId = null;
        fastKeyProductItems.clear();
      } else if (prevSelectedIndex != null && prevSelectedIndex == deletedIndex) {
        // Deleted currently selected tab: keep focus at same index (which is now next tab).
        final int newIndex = deletedIndex.clamp(0, fastKeyTabs.length - 1);
        _selectedCategoryIndex = newIndex;
        _fastKeyTabId = fastKeyTabs[newIndex].fastkeyServerId;
        nextActiveTabId = _fastKeyTabId;
        fastKeyProductItems.clear();
        isItemsLoading = true;
      } else {
        // Deleted a different tab: keep current tab content and fix shifted index.
        if (prevSelectedIndex != null && deletedIndex != -1 && deletedIndex < prevSelectedIndex) {
          _selectedCategoryIndex = prevSelectedIndex - 1;
        }
        if (_selectedCategoryIndex != null &&
            _selectedCategoryIndex! >= 0 &&
            _selectedCategoryIndex! < fastKeyTabs.length) {
          _fastKeyTabId = fastKeyTabs[_selectedCategoryIndex!].fastkeyServerId;
        }
      }

      _editingCategoryIndex = null; //Build 1.1.36: Clear edit mode
      if (kDebugMode) {
        print(
            "### FastKeyScreen: Updated UI after tab deletion, new tab count: ${fastKeyTabs.length}");
      }
    });

    if (nextActiveTabId != null) {
      fastKeyTabIdNotifier.value = nextActiveTabId;
      await fastKeyDBHelper.saveActiveFastKeyTab(nextActiveTabId);
    }

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
          fastKeyTabs.any((tab) => tab.fastkeyServerId == lastSelectedTabId)) {
        _selectedCategoryIndex = fastKeyTabs
            .indexWhere((tab) => tab.fastkeyServerId == lastSelectedTabId);
        _fastKeyTabId = lastSelectedTabId;
        if (kDebugMode) {
          print(
              "### FastKeyScreen: Restored tab ID: $_fastKeyTabId, index: $_selectedCategoryIndex");
        }
      } else if (fastKeyTabs.isNotEmpty) {
        _selectedCategoryIndex = 0;
        _fastKeyTabId = fastKeyTabs[0].fastkeyServerId;
        fastKeyDBHelper.saveActiveFastKeyTab(_fastKeyTabId); // Save default tab
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
      await _resolveFastKeyMeta();
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
    await _awaitMergedProductCacheReadyForFastKeys();
    if (FastKeyDBHelper.isFastkeyLoaded) {
      ///stops loading every time
      final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId!);
      final preparedItems = await _prepareFastKeyItemsForInitialUi(items);
      if (kDebugMode) {
        print(
            "FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = preparedItems;
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      }
      return;
    }

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
      final preparedItems = await _prepareFastKeyItemsForInitialUi(items);
      if (kDebugMode) {
        print(
            "FastKey Screen _loadFastKeyTabItems loading items: ${items.length}");
      }
      if (mounted) {
        setState(() {
          fastKeyProductItems = preparedItems;
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _prepareFastKeyItemsForInitialUi(
      List<Map<String, dynamic>> items) async {
    await _ingestProductMetaFromMerged();
    final List<Map<String, dynamic>> prepared = [];

    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw);
      final tagsCol = item[AppDBConst.fastKeyItemTags];
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

      final cached =
      productId != null ? await _getCachedProductFromIsar(productId) : null;

      // Same resolution as _resolveFastKeyMeta so grid badges match tap behavior.
      item["has_variants"] = await _fastKeyHasVariants(item);

      final isEbt = _isProductEbtEligible({
        "is_ebt_eligible": item["is_ebt_eligible"] ?? cached?["is_ebt_eligible"],
        "meta_data": item["meta_data"] ?? cached?["meta_data"],
        "fast_key_item_tags": item["fast_key_item_tags"] ?? cached?["tags"],
        "tags": cached?["tags"],
      });
      item["is_ebt_eligible"] = isEbt;
      if (item["meta_data"] == null &&
          cached != null &&
          cached["meta_data"] != null) {
        item["meta_data"] = cached["meta_data"];
      }

      prepared.add(item);
    }

    return prepared;
  }

  /// Fills `type`, `variations`, `fast_key_item_tags`, `is_ebt_eligible` from
  /// Hive `sku_*` cache when the fast-key SQLite row has no tags/type (API
  /// does not persist tags on fast_key_items). Needed so badges show on first paint.
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

    // 0️⃣ Persisted when Fast Key syncs from API (see fastkey_product_bloc)
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

    // 3️⃣ 🔥 CHECK VARIATION CACHE (THIS WAS MISSING)
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
      final tabs =
      await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
      if (tabs.isNotEmpty) {
        final fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
        if (kDebugMode) {
          print(
              "FastKey Screen _loadFastKeyTabItems selected tab server id: $fastKeyServerId");
        }
        final items = await fastKeyDBHelper.getFastKeyItems(_fastKeyTabId ?? 1);
        final preparedItems = await _prepareFastKeyItemsForInitialUi(items);
        if (kDebugMode) {
          print(
              "#### Retrieved ${items.length} FastKey Items for Tab ID: $_fastKeyTabId");
        }
        setState(() {
          fastKeyProductItems = preparedItems;
          reorderedIndices = List.filled(fastKeyProductItems.length, null);
          isItemsLoading = false;
        });
      } else {
        setState(() {
          fastKeyProductItems = [];
          isItemsLoading = false;
        });
      }
      await _resolveFastKeyMeta();
    } catch (e) {
      if (kDebugMode) {
        print("Error loading FastKey tab items: $e");
      }
      setState(() => isItemsLoading = false);
    }
  }

  // Build #1.0.87: code updated
  Future<void> _addFastKeyTabItem(
      String name, String image, String price) async {
    if (_fastKeyTabId == null) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, no tab selected");
      }
      return;
    }
    var tabs =
    await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) {
      if (kDebugMode) {
        print("### FastKeyScreen: _addFastKeyTabItem aborted, tab not found");
      }
      return;
    }
    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];
    var countProductInFastKey =
        fastKeyProductItems.length; // Use current UI state
    FastKeyProductItem item = FastKeyProductItem(
        productId: selectedProduct!['id'], slNumber: countProductInFastKey + 1);

    StreamSubscription? subscription;
    subscription =
        _fastKeyProductBloc.addProductsStream.listen((response) async {
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
            if (!isBulkAdding) {
              _refreshFastKeyTabItems();
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
    await _fastKeyProductBloc
        .addProducts(fastKeyId: fastKeyServerId, products: [item]);
  }

  Future<void> _deleteFastKeyTabItem(int fastKeyTabItemServerId) async {
    // Build #1.0.104
    if (_fastKeyTabId == null) return;

    // Build #1.0.89: delete FastKey product API integrated
    var tabs =
    await fastKeyDBHelper.getFastKeyByServerTabId(_fastKeyTabId ?? 1);
    if (tabs.isEmpty) return;

    var fastKeyServerId = tabs.first[AppDBConst.fastKeyServerId];

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
            if (Misc.showDebugSnackBar) {
              // Build #1.0.254
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
  }

  Future<void> _pickImage() async {
    final XFile? imageFile =
    await _picker.pickImage(source: ImageSource.gallery);
    if (imageFile != null) {
      setState(() {
        _pickedImage = File(imageFile.path);
      });
    }
  }

  Stopwatch? refreshUIStopwatch; // Build #1.0.256
  Future<void> _onItemSelected(
      int index, bool showAddButton, bool variantAdded) async {
    try {
      if (variantAdded) {
        if (!Misc.enableUILogMessages) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        _refreshOrderList();
        return;
      }

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

      final hasVariants = (item["type"] == "variable" ||
          (item["variations"] != null && item["variations"].isNotEmpty));
      final minAge =
          int.tryParse(item["fast_key_item_min_age"]?.toString() ?? "0") ?? 0;
      final hasAgeRestriction = minAge > 0;

      // Determine EBT eligibility using same rules as grid/meta resolver
      bool isEbtEligible = item["is_ebt_eligible"] == true;
      if (!isEbtEligible) {
        isEbtEligible = _isProductEbtEligible(item);
      }

      print(
          "🧾 Selected → id:$productId | name:$productName | price:$productPrice | variant:$hasVariants | age:$minAge");

      // 🧠 Determine order type
      final box = StorageProvider.offlineOrders;
      final isOfflineOrder =
      box.containsKey(orderHelper.activeOrderId.toString());
      final activeOrderId =
          orderHelper.activeOrderId ?? (await box.get('lastOrderId')) ?? 1000;

      if (orderHelper.activeOrderId == null) {
        orderHelper.activeOrderId = activeOrderId;
        await box.put('lastOrderId', activeOrderId);
      }

      // // 🔞 Age restriction
      // if (hasAgeRestriction && minAge > 0) {
      //   final verifiedKey = 'age_verified_order_$activeOrderId';
      //   final alreadyVerified = box.get(verifiedKey, defaultValue: false);
      //   if (!alreadyVerified) {
      //     final ageVerificationProvider = AgeVerificationProvider();
      //     final isVerified = await ageVerificationProvider.verifyAge(context, minAge: minAge);
      //     if (!isVerified) {
      //       print("❌ Age verification failed → Product blocked");
      //       return;
      //     }
      //     box.put(verifiedKey, true);
      //   }
      // }

      // 🧩 If product has variants
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

          // fallback from item["variations"]
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
              rawVariations.add({
                "id": id,
                "name": name,
                "price": price,
                "sku": variantData?["sku"] ?? "",
                "image": image,
              });
            }
          }

          offlineVariations = rawVariations.map<Map<String, dynamic>>((v) {
            if (v is String) v = jsonDecode(v);
            final map = Map<String, dynamic>.from(v);
            map["price"] = map["price"]?.toString() ?? "0";
            return map;
          }).toList();
        } catch (e) {
          print("⚠️ Error loading variants: $e");
        }

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

              await orderHelper.addItemToOrder(
                0,
                "$productName - $variantName",
                variantImage,
                variantPrice,
                qty,
                productSku,
                activeOrderId,
                type: 'variant',
                productId: productId,
                variationId: variantId,
                variationName: variantName,
                salesPrice: variantPrice,
                regularPrice: variantPrice,
                unitPrice: variantPrice,
                isEbtEligible: isEbtEligible,
                onItemAdded: () async {
                  print("✅ Variant added locally");
                  await CustomerDisplayHelper.updateCustomerDisplay(
                      activeOrderId);
                },
              );
              await Future.delayed(const Duration(milliseconds: 100));
              _refreshOrderList();
            },
          ),
        );
      } else {
        // 🟩 Simple product
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
          onItemAdded: () async {
            print("✅ Product added locally");
            await CustomerDisplayHelper.updateCustomerDisplay(activeOrderId);
          },
        );
        await Future.delayed(const Duration(milliseconds: 100));
        _refreshOrderList();
      }

      print("🎉 Product flow completed for → $productName");
    } catch (e, s) {
      print("❌ ERROR in _onItemSelected: $e");
      print(s);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to add product"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
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

  Future<void> _refreshOrderList() async {
    setState(() {
      // Build #1.0.128
      if (kDebugMode) {
        print(
            "##### _refreshOrderList: Incrementing _refreshCounter to $_refreshCounter to trigger RightOrderPanel refresh");
      }
      _refreshCounter++; //Build #1.0.170: Increment to signal refresh, causing didUpdateWidget to load with loader
    });
    await orderHelper.loadData();

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
        print(
            "Add Product to Order completed in ${globalProcessSteps.last.timeTaken}s");
      }
    }

    /// Show Toast
    if (Misc.enableUILogMessages && globalProcessSteps.isNotEmpty) {
      if (Navigator.canPop(context)) {
        // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
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
              // Clear global steps when toast is closed
              globalProcessSteps.clear();
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    }
  }

// ══════════════════════════════════════════════════════════════════════════════
// PATCH: Replace ONLY _showAddItemDialog() in _FastKeyScreenState.
//
// WHAT IS CHANGED (only 2 things):
//   1. Data source: ProductBloc API  →  TopBar.mergedCachedProductsForSearch()
//   2. Search filtering: StreamBuilder  →  in-memory filter on _filteredList
//
// WHAT IS NOT CHANGED (zero UI or logic differences):
//   • AlertDialog layout, title, backgroundColor
//   • Left TextField widget (same decoration, same controller)
//   • Right side Container + Scrollbar + ListView
//   • ListTile: image, title, subtitle, selectedTileColor — all identical
//   • Multi-select: selectedProducts list, isSelected check, onTap logic
//   • Cancel button
//   • "Add Selected" button: label, disabled state, entire onPressed block
//     (isBulkAdding, existingIds duplicate guard, _addFastKeyTabItem,
//      _refreshFastKeyTabItems, _getCachedProductFromIsar, _resolveFastKeyMeta)
// ══════════════════════════════════════════════════════════════════════════════

  Future<void> _showAddItemDialog() async {
    var size = MediaQuery.of(context).size;
    searchController.clear();
    bool errorShown = false;
    isBulkAdding = true;

    searchResults.clear();
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);

    /// ⭐ NEW: Store multiple selections (unchanged from original)
    List<Map<String, dynamic>> selectedProducts = [];

    // Same merged caches as TopBar search (not CategoryRepository.products_* only).
    List<dynamic> _allCached = [];
    try {
      _allCached = await TopBar.mergedCachedProductsForSearch();
    } catch (e) {
      debugPrint('FastKey _showAddItemDialog: cache load error → $e');
    }

    Timer? _dialogSearchDebounce;
    bool _dialogSearchPending = false;
    final ScrollController _dialogScrollController = ScrollController();

    // ── NEW: the filtered subset shown in the right-side ListView ───────────
    List<dynamic> _filteredList = [];

    // ── NEW: resolve image URL from a cached product map (mirrors TopBar) ───
    String _resolveImage(dynamic p) {
      try {
        final raw = p['images'];
        if (raw is String && raw.isNotEmpty) return raw;
        if (raw is List && raw.isNotEmpty) {
          final f = raw.first;
          if (f is String) return f;
          if (f is Map && f['src'] != null) return f['src'].toString();
        }
      } catch (_) {}
      return p['fast_key_item_image']?.toString() ?? '';
    }

    int? _resolveProductId(dynamic p) {
      final dynamic raw =
          p['fast_key_product_id'] ?? p['product_id'] ?? p['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }

    String _resolveName(dynamic p) {
      final dynamic rawName = p['fast_key_item_name'] ?? p['name'];
      if (rawName is Map && rawName['rendered'] != null) {
        return rawName['rendered'].toString();
      }
      return (rawName ?? 'Unknown').toString();
    }

    String _resolvePrice(dynamic p) {
      final dynamic raw = p['fast_key_item_price'] ??
          p['price'] ??
          p['regular_price'] ??
          '0.00';
      return raw.toString();
    }

    String _resolveSku(dynamic p) {
      return (p['sku'] ?? p['fast_key_item_sku'] ?? '').toString();
    }

    String _normalize(String input) {
      return input
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    bool _matchesCachedProduct(String q, dynamic p) {
      final normalizedQuery = _normalize(q);
      if (normalizedQuery.isEmpty) return true;

      final normalizedName = _normalize(_resolveName(p));
      final normalizedSku = _normalize(_resolveSku(p));

      if (normalizedName.contains(normalizedQuery) ||
          normalizedSku.contains(normalizedQuery)) {
        return true;
      }

      final parts = q
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((e) => _normalize(e))
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return false;
      return parts.every((part) =>
          normalizedName.contains(part) || normalizedSku.contains(part));
    }

    // ── NEW: build sorted + deduplicated filtered list (mirrors TopBar) ─────
    List<dynamic> _buildFiltered(String query) {
      final searchQuery = query.toLowerCase().trim();
      debugPrint('Processed search query: "$searchQuery"');

      if (searchQuery.isEmpty) return [];

      final Map<int, dynamic> unique = {};

      for (final p in _allCached) {
        final int? pid = _resolveProductId(p);
        if (pid == null) continue;
        if (!_matchesCachedProduct(searchQuery, p)) continue;

        unique[pid] = p;
      }

      final result = unique.values.toList()
        ..sort((a, b) {
          final na = _resolveName(a).toLowerCase();
          final nb = _resolveName(b).toLowerCase();

          final sa = na.startsWith(searchQuery);
          final sb = nb.startsWith(searchQuery);

          if (sa && !sb) return -1;
          if (!sa && sb) return 1;
          return na.compareTo(nb);
        });

      debugPrint('Filtered products count: ${result.length}');

      return result;
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              // ── UNCHANGED ─────────────────────────────────────────────────
              backgroundColor: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : null,
              title: Text(
                TextConstants.searchAddItemText,
                style: TextStyle(
                  fontSize: 18,
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.textDark
                      : Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 700,
                  child: Row(
                    children: [
                      ///  SEARCH FIELD

                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: TextConstants.searchItemText,
                            hintText: TextConstants.typeSearchText,
                          ),
                          onChanged: (value) {
                            _dialogSearchDebounce?.cancel();
                            final q = value.trim();
                            if (q.isEmpty || q.length < 3) {
                              setStateDialog(() {
                                _dialogSearchPending = false;
                                _filteredList = [];
                              });
                              return;
                            }
                            setStateDialog(() => _dialogSearchPending = true);
                            _dialogSearchDebounce =
                                Timer(const Duration(seconds: 2), () async {
                                  try {
                                    _allCached =
                                    await TopBar.mergedCachedProductsForSearch();
                                  } catch (e) {
                                    debugPrint(
                                        'FastKey _showAddItemDialog: cache refresh error → $e');
                                  }
                                  if (!dialogContext.mounted) return;
                                  setStateDialog(() {
                                    _dialogSearchPending = false;
                                    _filteredList =
                                        _buildFiltered(searchController.text);
                                  });
                                });
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// 📦 PRODUCT LIST

                      Expanded(
                        child: Builder(builder: (_) {
                          final searchText = searchController.text.trim();
                          if (searchText.isEmpty) {
                            return SizedBox(
                              height: size.height * 0.5,
                              child: const Center(
                                child: Text('No products found'),
                              ),
                            );
                          }
                          if (searchText.length < 3) {
                            return SizedBox(
                              height: size.height * 0.5,
                              child: Center(
                                child: Text(TextConstants.searchMinCharactersHint),
                              ),
                            );
                          }
                          if (_dialogSearchPending) {
                            return SizedBox(
                              height: size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 12),
                                    Text(TextConstants.searchPausedSearchingHint),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (_filteredList.isEmpty) {
                            return SizedBox(
                              height: size.height * 0.5,
                              child: const Center(
                                child: Text('No products found'),
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.primaryBackground
                                  : ThemeNotifier.lightBackground,
                            ),
                            height: size.height * 0.5,
                            child: Scrollbar(
                              controller: _dialogScrollController,
                              thumbVisibility: true,
                              radius: const Radius.circular(8),
                              child: ListView.builder(
                                controller: _dialogScrollController,
                                itemCount: _filteredList.length,
                                itemBuilder: (context, index) {
                                  final p = _filteredList[index];

                                  final String name = _resolveName(p).isNotEmpty
                                      ? _resolveName(p)
                                      : 'No Name';
                                  final String price = _resolvePrice(p);
                                  final String pid =
                                  (_resolveProductId(p) ?? '').toString();
                                  final String imageUrl = _resolveImage(p);

                                  // Detect EBT + variants using same rules as grid/order flow
                                  final List<dynamic> rawTags =
                                      (p['tags'] as List?) ?? const [];
                                  final bool isEbtEligible = rawTags.any((t) {
                                    if (t is! Map) return false;
                                    final name = (t['name'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final slug = (t['slug'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    return name.contains('ebt') ||
                                        slug.contains('ebt') ||
                                        slug == 'ebt-eligible';
                                  });

                                  final String type = (p['type'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final List<dynamic> variations =
                                      (p['variations'] as List?) ?? const [];
                                  final bool hasVariants = type == 'variable' ||
                                      variations.isNotEmpty;

                                  final bool isSelected = selectedProducts
                                      .any((s) => s['id'].toString() == pid);

                                  return ListTile(
                                    // ── UNCHANGED ──────────────────────────
                                    selected: isSelected,
                                    selectedTileColor:
                                    Colors.grey.withOpacity(0.3),

                                    leading: imageUrl.isNotEmpty
                                        ? Image.network(
                                      imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image),
                                    )
                                        : const Icon(Icons.image),

                                    title: Text(name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${TextConstants.currencySymbol}'
                                              '${double.tryParse(price)?.toStringAsFixed(2) ?? "0.00"}',
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (hasVariants)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 6),
                                                child: SvgPicture.asset(
                                                  SvgUtils.variationIcon,
                                                  height: 10,
                                                  width: 10,
                                                ),
                                              ),
                                            if (isEbtEligible)
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade600,
                                                  borderRadius:
                                                  BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'EBT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    /// ⭐ UNCHANGED: multi-select logic
                                    onTap: () {
                                      setStateDialog(() {
                                        if (isSelected) {
                                          selectedProducts.removeWhere(
                                                (s) => s['id'].toString() == pid,
                                          );
                                        } else {
                                          selectedProducts.add({
                                            'title': name,
                                            'image': imageUrl,
                                            'price': price,
                                            'id': int.tryParse(pid) ?? 0,
                                            'sku':
                                            p['sku']?.toString() ?? 'N/A',
                                          });
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              /// ── UNCHANGED: action buttons ──────────────────────────────────
              actions: [
                ///  CANCEL — unchanged
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(TextConstants.cancelText),
                ),

                /// ADD SELECTED — entire onPressed block unchanged
                TextButton(
                  onPressed: selectedProducts.isNotEmpty
                      ? () {
                    final List<Map<String, dynamic>> selectedCopy =
                    List<Map<String, dynamic>>.from(selectedProducts);

                    Navigator.of(dialogContext).pop();

                    Future.delayed(const Duration(milliseconds: 100),
                            () async {
                          isBulkAdding = true;

                          final existingItems = await fastKeyDBHelper
                              .getFastKeyItems(_fastKeyTabId!);
                          final existingIds = existingItems
                              .map((e) =>
                              e[AppDBConst.fastKeyProductId].toString())
                              .toSet();

                          for (var p in selectedCopy) {
                            final pid = p['id'].toString();
                            if (existingIds.contains(pid)) continue;
                            selectedProduct = p;
                            await _addFastKeyTabItem(
                              p['title'],
                              p['image'],
                              p['price'],
                            );
                          }

                          isBulkAdding = false;
                          await _refreshFastKeyTabItems();

                          // 🔥 Ensure Isar cache for newly added items
                          for (final item in fastKeyProductItems) {
                            final pid = int.tryParse(
                                item[AppDBConst.fastKeyProductId]
                                    ?.toString() ??
                                    '');
                            if (pid != null) {
                              await _getCachedProductFromIsar(pid);
                            }
                          }

                          await _resolveFastKeyMeta();
                          if (mounted) setState(() {});
                        });
                  }
                      : null,
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _dialogSearchDebounce?.cancel();
      _dialogScrollController.dispose();
    });
  }

  void _showCategoryDialog({required BuildContext context, int? index}) {
    bool isEditing = index != null;
    TextEditingController nameController = TextEditingController(
        text: isEditing ? fastKeyTabs[index!].fastkeyTitle : '');
    String imagePath =
    isEditing ? fastKeyTabs[index!].fastkeyImage : 'assets/default.png';
    bool showError = false;
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : null,
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
                                        setStateDialog(() => isLoading = true);

                                        var image =
                                        await _showSelectImageDialog(
                                            context: context);

                                        if (kDebugMode) {
                                          print(
                                              "2 image path selected is : $image");
                                        }

                                        setStateDialog(() {
                                          imagePath = image;
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
                                if (Misc.showDebugSnackBar) {
                                  // Build #1.0.254
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
      return fastKeyImages[types[selectedTab]] ?? [];
    }

    var selectedImage = await showDialog<String>(
      context: context,
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

                  /// CLOSE BUTTON
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
                    /// 🔥 DYNAMIC TABS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        for (int i = 0; i < types.length; i++) ...[
                          _buildTabButton(
                            label: types[i],
                            index: i,
                            selectedIndex: selectedTab,
                            isDark: isDark,
                            onTap: () => setStateDialog(() => selectedTab = i),
                          ),
                          SizedBox(width: 10),
                        ],
                      ],
                    ),

                    SizedBox(height: 20),

                    /// 🔥 IMAGE GRID
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Color(0xFF34384A) // dark gray background
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GridView.builder(
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
                              onTap: () => Navigator.pop(context, img.url),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: _buildImageWidget(img.url),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return selectedImage ?? imagePath;
  }

  /// ------------------------------------------------------------
  ///  🔥 TAB BUTTON WITH DARK/LIGHT MODE COLORS
  /// ------------------------------------------------------------
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

          /// Underline
          // AnimatedContainer(
          //   duration: Duration(milliseconds: 200),
          //   height: 3,
          //   width: isSelected ? 95 : 0,
          //   margin: EdgeInsets.only(top: 4),
          //   decoration: BoxDecoration(
          //     color: isSelected ? Colors.red : Colors.transparent,
          //     borderRadius: BorderRadius.circular(2),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imagePath) {
    if (kDebugMode) {
      print("_buildImageWidget for imagePath: $imagePath");
    }

    if (imagePath.isEmpty) {
      return _safeSvgPicture('assets/svg/password_placeholder.svg');
    }

    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return _safeSvgPicture(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.asset(
          imagePath,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (imagePath.startsWith("http")) {
      return Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent, // <-- FIXED (no grey background)
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
                color: Colors.transparent, // also transparent on error
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      );
    } else {
      return Platform.isWindows
          ? Image.asset(
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
            final fastKeyTabItemServerId =
            fastKeyProductItems[itemIndex][AppDBConst.fastKeyProductId];
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
  Future<void> _resolveFastKeyMeta() async {
    debugPrint("🧠 START _resolveFastKeyMeta");

    await _ingestProductMetaFromMerged();

    for (int i = 0; i < fastKeyProductItems.length; i++) {
      // 🔑 Convert QueryRow → mutable Map
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

      final cached = await _getCachedProductFromIsar(productId);

      // -------- VARIANTS --------
      final hasVariants = await _fastKeyHasVariants(item);
      item['has_variants'] = hasVariants;

      debugPrint(
        "🧩 VARIANT → productId=$productId | hasVariants=$hasVariants",
      );

      // -------- EBT --------
      final isEbt = _isProductEbtEligible({
        "is_ebt_eligible": item['is_ebt_eligible'] ?? cached?['is_ebt_eligible'],
        "meta_data": item['meta_data'] ?? cached?['meta_data'],
        "fast_key_item_tags": item['fast_key_item_tags'] ?? cached?['tags'],
        "tags": cached?['tags'],
      });

      item['is_ebt_eligible'] = isEbt;
      if (item['meta_data'] == null &&
          cached != null &&
          cached['meta_data'] != null) {
        item['meta_data'] = cached['meta_data'];
      }

      debugPrint(
        "🥗 EBT → productId=$productId | isEbt=$isEbt",
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
    TopBar.mergedProductCacheRevision
        .removeListener(_onMergedProductCacheRevision);
    WidgetsBinding.instance.removeObserver(this);
    _fastKeyBloc.dispose();
    orderBloc.dispose(); // Build 1.0.171
    _fastKeyProductBloc.dispose();
    _autoSuggest.dispose();
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
            child: ValueListenableBuilder<int?>(
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

    return Scaffold(
      body: Column(
        children: [
          TopBar(
            screen: Screen.FASTKEY,
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
              //   _preferences.saveLayoutSelection(newLayout);
              //Build #1.0.122: update layout mode change selection to DB
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
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
                if (fastKeyTabs.isNotEmpty)
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
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          // the gap between fast key and top bar
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
                    key: const ValueKey('order_panel'),
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey:
                    _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
                  ),
                Expanded(
                  child: Column(
                    children: [
                      CategoryList(
                        scrollController: _scrollController,
                        isHorizontal: true,
                        isLoading: isTabsLoading,
                        isAddButtonEnabled: true,
                        categories: categories,
                        selectedIndex: _selectedCategoryIndex,
                        editingIndex: _editingCategoryIndex,
                        onAddButtonPressed: () =>
                            _showCategoryDialog(context: context),
                        onCategoryTapped: (index) async {
                          // Prevent tapping the same category again
                          if (_selectedCategoryIndex == index) {
                            // Build #1.0.254: Fixed - Disable double click on category tabs & fast key tabs
                            if (kDebugMode) {
                              print(
                                  "### FastKeyScreen: Same category tapped, ignoring: $index");
                            }
                            return;
                          }
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onCategoryTapped called for index: $index, ID: ${fastKeyTabs[index].fastkeyServerId}");
                          }
                          //Build #1.0.68: updated
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
                              //Build #1.0.84
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
                            //Build 1.1.36: Update editingIndex to the new position
                            if (_editingCategoryIndex == oldIndex) {
                              _editingCategoryIndex = newIndex;
                            }

                            ///update the index in backend as well
                            _fastKeyBloc.updateFastKey(
                                title: item.fastkeyTitle,
                                index: newIndex + 1,
                                imageUrl: item.fastkeyImage,
                                fastKeyServerId: item.fastkeyServerId,
                                userId: item.userId);
                          });
                          // Update indices in the database
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
                            _editingCategoryIndex =
                                index; // Set editing index for the item being reordered
                          });
                        },
                        onEditButtonPressed: (index) {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onEditButtonPressed called for index: $index");
                          }
                          setState(() {
                            _editingCategoryIndex =
                                index; // Set editing index for the item
                          });
                          _showCategoryDialog(context: context, index: index);
                        },
                        onDismissEditMode: () {
                          if (kDebugMode) {
                            print(
                                "### FastKeyScreen: onDismissEditMode called");
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
                        },
                      )
                    ],
                  ),
                ),
                if (sidebarPosition != SidebarPosition.right &&
                    !(sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                    key: const ValueKey('order_panel'),
                    quantities: quantities,
                    refreshOrderList: _refreshOrderList,
                    refreshKey:
                    _refreshCounter, //Build #1.0.170: Pass counter as refreshKey
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
                  //Build #1.0.54
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
