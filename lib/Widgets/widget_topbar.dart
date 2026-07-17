// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:http/http.dart' as http;
// import 'package:pinaka_pos/Database/storage/storage_provider.dart';
// import 'package:isar/isar.dart';
// import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
// import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
// import 'package:provider/provider.dart';
//
// import '../Blocs/Auth/logout_bloc.dart';
// import '../Blocs/Orders/order_bloc.dart';
// import '../Blocs/Search/product_search_bloc.dart';
// import '../Constants/text.dart';
// import '../Database/db_helper.dart';
// import '../Database/isar_cache_entry.dart';
// import '../Database/isar_service.dart';
// import '../Database/order_panel_db_helper.dart';
// import '../Database/user_db_helper.dart';
// import '../Helper/Extentions/theme_notifier.dart';
// import '../Helper/url_helper.dart';
// import '../Helper/api_response.dart';
// import '../Models/Search/product_search_model.dart';
// import '../Preferences/pinaka_preferences.dart';
// import '../Providers/Age/age_verification_provider.dart';
// import '../Repositories/Auth/logout_repository.dart';
// import '../Repositories/Orders/order_repository.dart';
// import '../Repositories/Search/product_search_repository.dart';
// import '../Screens/Auth/login_screen.dart' show LoginScreen;
// import '../Utilities/printer_settings.dart';
// import '../Utilities/svg_images_utility.dart';
// import 'ManualPriceDialog.dart';
//
// import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;
//
// // ══════════════════════════════════════════════════════════════════════════════
// // NATIVE SCALE CHANNELS
// // ══════════════════════════════════════════════════════════════════════════════
//
// const _scaleMethodChannel = MethodChannel('magellan_scale');
// const _scaleEventChannel = EventChannel('magellan_scale/events');
//
// // ══════════════════════════════════════════════════════════════════════════════
// // 7-SEGMENT LCD DISPLAY
// // ══════════════════════════════════════════════════════════════════════════════
//
// class _SegmentPainter extends CustomPainter {
//   final String char;
//   final Color onColor;
//   final Color offColor;
//   final double strokeW;
//
//   _SegmentPainter({
//     required this.char,
//     required this.onColor,
//     required this.offColor,
//     this.strokeW = 3.0,
//   });
//
//   static const Map<String, List<bool>> _segments = {
//     '0': [true, true, true, true, true, true, false],
//     '1': [false, true, true, false, false, false, false],
//     '2': [true, true, false, true, true, false, true],
//     '3': [true, true, true, true, false, false, true],
//     '4': [false, true, true, false, false, true, true],
//     '5': [true, false, true, true, false, true, true],
//     '6': [true, false, true, true, true, true, true],
//     '7': [true, true, true, false, false, false, false],
//     '8': [true, true, true, true, true, true, true],
//     '9': [true, true, true, true, false, true, true],
//     '.': [false, false, false, false, false, false, false],
//     '-': [false, false, false, false, false, false, true],
//     ' ': [false, false, false, false, false, false, false],
//   };
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (char == '.') {
//       final dotR = strokeW * 1.1;
//       canvas.drawCircle(
//         Offset(size.width / 2, size.height - dotR),
//         dotR,
//         Paint()..color = onColor,
//       );
//       return;
//     }
//
//     final segs = _segments[char] ?? _segments[' ']!;
//     final w = size.width;
//     final h = size.height;
//     final s = strokeW;
//     final gap = s * 0.55;
//
//     void seg(bool on, Offset p1, Offset p2) {
//       canvas.drawLine(
//         p1,
//         p2,
//         Paint()
//           ..color = on ? onColor : offColor
//           ..strokeWidth = s
//           ..strokeCap = StrokeCap.round
//           ..style = PaintingStyle.stroke,
//       );
//     }
//
//     final mid = h / 2;
//     seg(segs[0], Offset(gap + s * 0.5, s * 0.5),
//         Offset(w - gap - s * 0.5, s * 0.5));
//     seg(segs[1], Offset(w - s * 0.5, gap + s * 0.5),
//         Offset(w - s * 0.5, mid - gap));
//     seg(segs[2], Offset(w - s * 0.5, mid + gap),
//         Offset(w - s * 0.5, h - gap - s * 0.5));
//     seg(segs[3], Offset(gap + s * 0.5, h - s * 0.5),
//         Offset(w - gap - s * 0.5, h - s * 0.5));
//     seg(segs[4], Offset(s * 0.5, mid + gap),
//         Offset(s * 0.5, h - gap - s * 0.5));
//     seg(segs[5], Offset(s * 0.5, gap + s * 0.5), Offset(s * 0.5, mid - gap));
//     seg(segs[6], Offset(gap + s * 0.5, mid), Offset(w - gap - s * 0.5, mid));
//   }
//
//   @override
//   bool shouldRepaint(_SegmentPainter old) =>
//       old.char != char || old.onColor != onColor;
// }
//
// class SevenSegmentDisplay extends StatelessWidget {
//   final String text;
//   final double digitHeight;
//   final Color onColor;
//   final Color offColor;
//   final double spacing;
//
//   const SevenSegmentDisplay({
//     super.key,
//     required this.text,
//     this.digitHeight = 34,
//     this.onColor = const Color(0xFF1A1A1A),
//     this.offColor = const Color(0xFFD8D8D8),
//     this.spacing = 3,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: text.split('').map((ch) {
//         final isDot = ch == '.';
//         final w = isDot ? digitHeight * 0.22 : digitHeight * 0.60;
//         return Padding(
//           padding: EdgeInsets.only(right: isDot ? 1 : spacing),
//           child: SizedBox(
//             width: w,
//             height: digitHeight,
//             child: CustomPaint(
//               painter: _SegmentPainter(
//                 char: ch,
//                 onColor: onColor,
//                 offColor: offColor,
//                 strokeW: digitHeight * 0.088,
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }
//
// // ══════════════════════════════════════════════════════════════════════════════
//
// enum Screen { FASTKEY, CATEGORY, ADD, ORDERS, APPS, SHIFT, SAFE, EDIT }
//
// class _PinBoxField extends StatefulWidget {
//   final TextEditingController controller;
//   final bool hasError;
//
//   const _PinBoxField({required this.controller, required this.hasError});
//
//   @override
//   State<_PinBoxField> createState() => _PinBoxFieldState();
// }
//
//
// class _ScaleDisplayWidget extends StatefulWidget {
//   final VoidCallback onLongPress;
//   final VoidCallback onReconnect;
//   final ValueNotifier<bool> isConnectingNotifier;
//
//   const _ScaleDisplayWidget({
//     required this.onLongPress,
//     required this.onReconnect,
//     required this.isConnectingNotifier,
//   });
//
//   @override
//   State<_ScaleDisplayWidget> createState() => _ScaleDisplayWidgetState();
// }
//
// class _ScaleDisplayWidgetState extends State<_ScaleDisplayWidget> {
//   @override
//   void initState() {
//     super.initState();
//     widget.isConnectingNotifier.addListener(_onConnectingChanged);
//   }
//
//   void _onConnectingChanged() {
//     if (mounted) setState(() {});
//   }
//
//   @override
//   void dispose() {
//     widget.isConnectingNotifier.removeListener(_onConnectingChanged);
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
//     final isDark = themeHelper.themeMode == ThemeMode.dark;
//     final bool isConnecting = widget.isConnectingNotifier.value;
//
//     return Consumer<WeightProvider>(
//       builder: (context, weightProvider, _) {
//         final bool connected = weightProvider.isConnected;
//         final parts = weightProvider.weightText.trim().split(' ');
//         final numPart = parts.isNotEmpty ? parts[0] : '0.00';
//         final unitPart = parts.length > 1 ? parts[1] : 'lb';
//
//         return GestureDetector(
//           onLongPress: widget.onLongPress,
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (connected) ...[
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//                   decoration: BoxDecoration(
//                     color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEAEAEA),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: SevenSegmentDisplay(
//                     text: numPart,
//                     digitHeight: 28,
//                     onColor: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A),
//                     offColor: isDark ? const Color(0xFF444444) : const Color(0xFFD0D0D0),
//                     spacing: 3,
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
//                   decoration: BoxDecoration(
//                     color: isDark ? const Color(0xFF444444) : const Color(0xFF3A3A3A),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     unitPart,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                       letterSpacing: 0.5,
//                       height: 1.0,
//                     ),
//                   ),
//                 ),
//               ] else ...[
//                 GestureDetector(
//                   onTap: isConnecting ? null : widget.onReconnect,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: isDark
//                           ? ThemeNotifier.secondaryBackground
//                           : Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         if (isConnecting)
//                           SizedBox(
//                             width: 14,
//                             height: 14,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 1.5,
//                               color: Colors.grey.shade400,
//                             ),
//                           )
//                         else
//                           Icon(Icons.scale, size: 16, color: Colors.grey.shade400),
//                         const SizedBox(width: 6),
//                         Text(
//                           isConnecting ? 'Connecting...' : 'Scale disconnected',
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey.shade500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _PinBoxFieldState extends State<_PinBoxField> {
//   bool _obscure = true;
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//
//     return SizedBox(
//       height: 48,
//       child: TextField(
//         controller: widget.controller,
//         maxLength: 6,
//         autofocus: true,
//         keyboardType: TextInputType.number,
//         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//         obscureText: _obscure,
//         enableSuggestions: false,
//         autocorrect: false,
//         textAlign: TextAlign.center,
//         style: TextStyle(
//           letterSpacing: 14,
//           fontSize: 15,
//           fontWeight: FontWeight.w600,
//           color: isDark ? Colors.white : Colors.black,
//         ),
//         decoration: InputDecoration(
//           counterText: "",
//           filled: true,
//           fillColor: isDark ? const Color(0xFF40424F) : const Color(0xFFF2F4F8),
//           suffixIcon: IconButton(
//             splashRadius: 13,
//             icon: Icon(
//               _obscure ? Icons.visibility_off : Icons.visibility,
//               size: 20,
//               color: isDark ? Colors.white54 : Colors.grey,
//             ),
//             onPressed: () => setState(() => _obscure = !_obscure),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(
//               color: widget.hasError ? Colors.red : Colors.transparent,
//               width: 1.2,
//             ),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//             borderSide: BorderSide(
//               color: widget.hasError ? Colors.red : Colors.redAccent,
//               width: 1.5,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class TopBar extends StatefulWidget {
//   final Function() onModeChanged;
//   final Function(ProductResponse)? onProductSelected;
//   final Screen screen;
//
//   const TopBar({
//     required this.screen,
//     required this.onModeChanged,
//     this.onProductSelected,
//     super.key,
//   });
//
//   // ── Static helpers ──────────────────────────────────────────────────────────
//
//   static void clearUserCache() {
//     _TopBarState.clearUserDataCache();
//   }
//
//   /// Bumped when merged product data (Isar/Hive) may have changed.
//   static final ValueNotifier<int> mergedProductCacheRevision =
//   ValueNotifier<int>(0);
//
//
//   static Completer<void>? _firstMergedReloadCompleter;
//   static bool _mergedReloadCompletedOnce = false;
//
//   static Future<void> waitForFirstMergedProductCacheReload() async {
//     if (_mergedReloadCompletedOnce) return;
//     _firstMergedReloadCompleter ??= Completer<void>();
//     return _firstMergedReloadCompleter!.future;
//   }
//
//   static void resetMergedProductCacheSignals() {
//     _mergedReloadCompletedOnce = false;
//     _firstMergedReloadCompleter = null;
//   }
//
//   static void _onTopBarMergedReloadCycleFinished() {
//     _mergedReloadCompletedOnce = true;
//     _firstMergedReloadCompleter ??= Completer<void>();
//     if (!_firstMergedReloadCompleter!.isCompleted) {
//       _firstMergedReloadCompleter!.complete();
//     }
//     mergedProductCacheRevision.value++;
//   }
//
//   static void notifyMergedProductCacheMayHaveChanged() {
//     mergedProductCacheRevision.value++;
//   }
//
//   static Future<List<dynamic>> mergedCachedProductsForSearch() async {
//     final unique = await _TopBarState._uniqueProductsFromAllCaches();
//     return unique.values.toList();
//   }
//
//   // ── FIX: Static callback registered by CategoriesScreen. ───────────────────
//   // TopBar calls this after a successful product refresh so CategoriesScreen
//   // can bust its Indigo UI-state guards and reload the visible product grid.
//   // CategoriesScreen sets this in its initState and clears it in dispose().
//   static VoidCallback? onRefreshCompleted;
//   static final ValueNotifier<int> modeChangedNotifier = ValueNotifier<int>(0);
//
//   @override
//   State<TopBar> createState() => _TopBarState();
// }
//
// class _TopBarState extends State<TopBar> with WidgetsBindingObserver {
//   final _searchController = TextEditingController();
//   final _searchFocusNode = FocusNode();
//   Timer? _debounce;
//   OverlayEntry? _overlayEntry;
//   final _searchFieldKey = GlobalKey();
//
//   final orderHelper = OrderHelper();
//   late OrderBloc _orderBloc;
//
//   bool isAddingItemLoading = false;
//   int? userId;
//   String? userRole;
//   String? userDisplayName;
//   bool isLoading = false;
//   double _lastBottomInset = 0;
//   bool _isSearchEnabled = true;
//
//   void _clearSearchUiState() {
//     _searchController.clear();
//     _removeOverlay();
//   }
//
//   var _printerSettings = PrinterSettings();
//
//   List<dynamic> _cachedProducts = [];
//   bool _cacheLoaded = false;
//   final ProductBloc productBloc = ProductBloc(ProductRepository());
//
//   bool _dialogOpen = false;
//
//   static final Map<String, List<Map<String, dynamic>>> _apiSearchCache = {};
//   bool _isApiSearchLoading = false;
//
//   StreamSubscription<dynamic>? _scaleSubscription;
//   bool _isConnecting = false;
//   String _scaleStatus = 'Disconnected';
//
//   WeightProvider? _weightProvider;
//
//   // ── Cached user data (static so it survives hot-reloads) ───────────────────
//   static Map<String, dynamic>? _cachedUserData;
//   static bool _isUserDataLoaded = false;
//   static Future<Map<String, dynamic>?>? _initialUserFuture;
//   static bool isNavigationInProgress = false;
//
//   final ValueNotifier<bool> _isConnectingNotifier = ValueNotifier<bool>(false);
//
//   static void clearUserDataCache() {
//     _cachedUserData = null;
//     _isUserDataLoaded = false;
//     _initialUserFuture = null;
//     TopBar.resetMergedProductCacheSignals();
//     if (kDebugMode) print("🧹 TopBar user data cache cleared");
//   }
//
//   static void clearUserCache() {
//     _cachedUserData = null;
//     _isUserDataLoaded = false;
//     _initialUserFuture = null;
//     if (kDebugMode) print("🧹 TopBar user data cache cleared");
//   }
//
//   // ── LIFECYCLE ───────────────────────────────────────────────────────────────
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _orderBloc = OrderBloc(OrderRepository());
//     _searchController.addListener(_onSearchChanged);
//     _searchFocusNode.addListener(_onFocusChanged);
//     _isSearchEnabled =
//         widget.screen != Screen.ORDERS && widget.screen != Screen.APPS;
//
//     _loadCachedProducts();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       _weightProvider = Provider.of<WeightProvider>(context, listen: false);
//       _listenToScale();
//     });
//
//     if (!_isUserDataLoaded) {
//       _initialUserFuture = UserDbHelper().getUserData();
//       _initialUserFuture!.then((userData) {
//         _cachedUserData = userData;
//         _isUserDataLoaded = true;
//         if (userData != null) {
//           userId = userData[AppDBConst.userId] as int?;
//           userDisplayName = userData[AppDBConst.userDisplayName] as String?;
//           userRole = userData[AppDBConst.userRole] as String?;
//         }
//         if (mounted) setState(() {});
//       });
//     } else {
//       if (_cachedUserData != null) {
//         userId = _cachedUserData![AppDBConst.userId] as int?;
//         userDisplayName = _cachedUserData![AppDBConst.userDisplayName] as String?;
//         userRole = _cachedUserData![AppDBConst.userRole] as String?;
//       }
//     }
//
//     // ✅ REMOVED: modeChangedNotifier debug listener — was never disposed,
//     //    leaked across screens, and caused mode changes on tab navigation.
//   }
//
//   void setModeChangePending(bool value) {
//   }
//
//   // Add this method inside class _TopBarState { ... }
//   void preventModeChangeDuringNavigation() {
//     isNavigationInProgress = true;
//     Future.delayed(const Duration(milliseconds: 1000), () {
//       if (mounted) isNavigationInProgress = false;
//     });
//   }
//
//   @override
//   void didUpdateWidget(covariant TopBar oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.screen != widget.screen) {
//       _clearSearchUiState();
//     }
//     _forceClearOldOrderFlicker();
//   }
//
//   void _forceClearOldOrderFlicker() {
//     _dialogOpen = false;
//     isAddingItemLoading = false;
//     _removeOverlay();
//
//     // Force immediate UI clean
//     if (mounted) {
//       setState(() {});
//     }
//
//     // Extra aggressive clear after frame to kill any remaining flash
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (!mounted) return;
//
//       // Clear search completely again
//       _searchController.clear();
//       _removeOverlay();
//
//       // This is the key - force rebuild again
//       if (mounted) {
//         setState(() {});
//       }
//
//       if (kDebugMode) {
//         print('🔄 Flicker cleared for screen: ${widget.screen}');
//       }
//     });
//   }
//
//   @override
//   void didChangeMetrics() {
//     final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
//     if (_lastBottomInset > 0 && bottomInset == 0) {
//       if (_searchFocusNode.hasFocus) {
//         _searchFocusNode.unfocus();
//       }
//     }
//     _lastBottomInset = bottomInset;
//   }
//
//   @override
//   void dispose() {
//     _debounce?.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     _searchFocusNode.removeListener(_onFocusChanged);
//     _searchFocusNode.dispose();
//     _orderBloc.dispose();
//     _removeOverlay();
//     _stopScale();
//     _apiSearchCache.clear();
//     super.dispose();
//     TopBar.clearUserCache();
//     _isConnectingNotifier.dispose();
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // SCALE
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   void _listenToScale() {
//     if (_scaleSubscription != null) return;
//     _scaleLog('🔌 Subscribing to native magellan_scale/events...');
//
//     _scaleSubscription = _scaleEventChannel.receiveBroadcastStream().listen(
//           (event) {
//         try {
//           final Map<String, dynamic> data = jsonDecode(event as String);
//           final String type = data['type'] as String? ?? '';
//           _scaleLog('📡 Native event: $event');
//
//           switch (type) {
//             case 'status':
//               final status = data['status'] as String? ?? '';
//               final message = data['message'] as String? ?? '';
//               _scaleLog('📊 Status: $status — $message');
//               if (mounted) {
//                 setState(() => _scaleStatus = message);
//                 _isConnectingNotifier.value = (status == 'connecting');
//               }
//               _weightProvider?.setConnected(status == 'connected');
//               if (status == 'disconnected' || status == 'error') {
//                 _weightProvider?.updateWeight(0.0);
//               }
//               break;
//
//             case 'weight':
//               final double w = (data['weight'] as num?)?.toDouble() ?? 0.0;
//               final String unit = data['unit'] as String? ?? 'lb';
//               _scaleLog(' Weight: $w $unit');
//               double kg = w;
//               if (unit == 'lb')
//                 kg = w * 0.453592;
//               else if (unit == 'g')
//                 kg = w / 1000;
//               else if (unit == 'oz')
//                 kg = w * 0.0283495;
//               final double lb = kg * 2.20462;
//               final displayText = '${lb.toStringAsFixed(2)} lb';
//               _weightProvider?.updateWeight(kg, displayText: displayText);
//               break;
//
//             case 'scan':
//               final raw = data['raw'] as String? ?? '';
//               _scaleLog('📷 Scan: $raw');
//               break;
//
//             case 'raw':
//               _scaleLog('📦 Raw: ${data['raw']}');
//               break;
//
//             default:
//               _scaleLog('❓ Unknown event type: $type');
//           }
//         } catch (e) {
//           _scaleLog('❌ Event parse error: $e');
//         }
//       },
//       onError: (e) {
//         _scaleLog('❌ EventChannel error: $e');
//         _weightProvider?.setConnected(false);
//         if (mounted) {
//           setState(() => _scaleStatus = 'Channel error');
//           _isConnectingNotifier.value = false;
//         }
//       },
//       onDone: () {
//         _scaleLog('⚠️ EventChannel closed.');
//         _weightProvider?.setConnected(false);
//         if (mounted) {
//           setState(() => _scaleStatus = 'Disconnected');
//           _isConnectingNotifier.value = false;
//         }
//       },
//       cancelOnError: false,
//     );
//   }
//
//   void _scaleLog(String msg) {
//     if (kDebugMode) debugPrint('[Scale] $msg');
//   }
//
//   void _stopScale() {
//     _scaleSubscription?.cancel();
//     _scaleSubscription = null;
//     try {
//       _scaleMethodChannel.invokeMethod('stop');
//     } catch (_) {}
//     _weightProvider?.setConnected(false);
//     _weightProvider?.updateWeight(0.0);
//   }
//
//   Future<void> _reconnectScale() async {
//     _scaleLog('🔄 Reconnecting...');
//     if (mounted) {
//       setState(() => _scaleStatus = 'Reconnecting...');
//       _isConnectingNotifier.value = true;
//     }
//     try {
//       await _scaleMethodChannel.invokeMethod('reconnect');
//     } catch (e) {
//       _scaleLog('❌ Reconnect error: $e');
//     }
//     if (_scaleSubscription == null) {
//       _listenToScale();
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // PRODUCT REFRESH
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   Future<void> refreshProducts() async {
//     try {
//       setState(() => isLoading = true);
//
//       final isar = await IsarService.instance;
//
//       // ── 1. Auth token ──────────────────────────────────────────────────────
//       final db = await DBHelper.instance.database;
//       final result = await db.query(
//         AppDBConst.userTable,
//         where:
//         '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
//         orderBy: '${AppDBConst.userId} DESC',
//         limit: 1,
//       );
//       if (result.isEmpty) throw Exception('No active user token found');
//       final token = result.first[AppDBConst.userToken] as String;
//
//       // ── 2. Call data-sync API ──────────────────────────────────────────────
//       final url = Uri.parse(
//         '${UrlHelper.baseUrl}'
//             '${UrlHelper.componentVersionUrl}'
//             'data-sync/get-data-changes?device_id=POS-003',
//       );
//
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );
//
//       if (response.statusCode != 200) {
//         if (kDebugMode) {
//           print('API Error: ${response.statusCode} — ${response.body}');
//         }
//         throw Exception('API returned ${response.statusCode}');
//       }
//
//       final decoded = jsonDecode(response.body) as Map<String, dynamic>;
//       if (kDebugMode) print('API Response: ${response.body}');
//
//       final List<dynamic> changes = decoded['changes'] ?? [];
//       if (changes.isEmpty) {
//         if (kDebugMode) print('No changes from API');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Products are already up to date'),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//         TopBar.notifyMergedProductCacheMayHaveChanged();
//         await _reloadAllProductsFromIsar();
//         TopBar.onRefreshCompleted?.call();
//         return;
//       }
//
//       // ── 2-B. Extract last event_version ───────────────────────────────────
//       int? lastEventVersion;
//       for (final change in changes) {
//         final dynamic rawVersion = change['event_version'];
//         if (rawVersion == null) continue;
//         final int? version = rawVersion is int
//             ? rawVersion
//             : int.tryParse(rawVersion.toString());
//         if (version != null &&
//             (lastEventVersion == null || version > lastEventVersion)) {
//           lastEventVersion = version;
//         }
//       }
//       if (kDebugMode) {
//         print('Last event_version from changes: $lastEventVersion');
//       }
//
//       // ── 3. Split by event_type ─────────────────────────────────────────────
//       final List<Map<String, dynamic>> toUpsert = [];
//       final List<int> toDelete = [];
//
//       for (final change in changes) {
//         if (change['post_type'] != 'product') continue;
//         final String eventType =
//         (change['event_type'] as String? ?? '').toLowerCase();
//
//         if (eventType == 'deleted') {
//           final dynamic rawId = change['data']?['id'] ?? change['post_id'];
//           final int? id = rawId is int
//               ? rawId
//               : int.tryParse(rawId?.toString() ?? '');
//           if (id != null) {
//             toDelete.add(id);
//             if (kDebugMode) print('Queued DELETE for product id=$id');
//           }
//         } else if (eventType == 'created' ||
//             eventType == 'updated' ||
//             eventType == 'restored') {
//           if (change['data'] is Map) {
//             toUpsert.add(Map<String, dynamic>.from(change['data'] as Map));
//             if (kDebugMode) {
//               print('Queued ${eventType.toUpperCase()} for product '
//                   'id=${change['data']['id']} name="${change['data']['name']}"');
//             }
//           }
//         }
//       }
//
//       if (kDebugMode) {
//         print(
//             'Changes → upsert: ${toUpsert.length}, delete: ${toDelete.length}');
//       }
//
//       // ── 4. Helpers ─────────────────────────────────────────────────────────
//
//       bool isEbtEligibleFromTags(List<dynamic> tags) {
//         return tags.any((t) {
//           final name = (t['name'] ?? '').toString().toLowerCase();
//           final slug = (t['slug'] ?? '').toString().toLowerCase();
//           return name == 'ebt' ||
//               name == 'ebt eligible' ||
//               slug == 'ebt' ||
//               slug == 'ebt-eligible';
//         });
//       }
//
//       int minAgeFromTags(List<dynamic> tags) {
//         for (final t in tags) {
//           final name = (t['name'] ?? '').toString().toLowerCase().trim();
//           if (name == TextConstants.age_restricted.toLowerCase().trim()) {
//             final int parsed =
//                 int.tryParse((t['slug'] ?? '').toString().trim()) ?? 0;
//             return parsed > 0 ? parsed : 18;
//           }
//         }
//         return 0;
//       }
//
//       Map<String, dynamic> normaliseProduct(Map<String, dynamic> p) {
//         final List<dynamic> rawTags = (p['tags'] as List?) ?? [];
//
//         final List<Map<String, dynamic>> originalTags = rawTags
//             .whereType<Map>()
//             .map((t) => {
//           'id': t['id'],
//           'name': (t['name'] ?? '').toString(),
//           'slug': (t['slug'] ?? '').toString(),
//         })
//             .toList();
//
//         final List<Map<String, dynamic>> lowercasedTags = rawTags
//             .whereType<Map>()
//             .map((t) => {
//           'id': t['id'],
//           'name': (t['name'] ?? '').toString().toLowerCase(),
//           'slug': (t['slug'] ?? '').toString().toLowerCase(),
//         })
//             .toList();
//
//         final int minAge = minAgeFromTags(rawTags);
//
//         if (kDebugMode && minAge > 0) {
//           print('🔞 Product id=${p['id']} "${p['name']}" → '
//               'age restricted, minAge=$minAge');
//         }
//
//         final List<dynamic> images = (p['images'] as List?) ?? [];
//         final String imageUrl = images.isNotEmpty
//             ? ((images.first is Map)
//             ? (images.first['src'] ?? '').toString()
//             : images.first.toString())
//             : '';
//
//         return {
//           'fast_key_product_id': p['id'],
//           'fast_key_item_name': p['name'] ?? '',
//           'fast_key_item_image': imageUrl,
//           'fast_key_item_price': p['price'] ?? p['regular_price'] ?? '0',
//           'fast_key_item_sku': p['sku'] ?? '',
//           'fast_key_item_tags': lowercasedTags,
//           'fast_key_item_min_age': minAge,
//           'has_age_restriction': minAge > 0,
//           'variations': p['variations'] ?? [],
//           'type': p['type'] ?? 'simple',
//           'id': p['id'],
//           'name': p['name'] ?? '',
//           'price': p['price'] ?? p['regular_price'] ?? '0',
//           'regular_price': p['regular_price'] ?? '',
//           'sku': p['sku'] ?? '',
//           'images': images,
//           'tags': originalTags,
//           'is_ebt_eligible': isEbtEligibleFromTags(rawTags),
//           'tax': p['tax'],
//         };
//       }
//
//       Future<IsarCacheEntry?> removeProductFromEntry(
//           String key, int productId) async {
//         final IsarCacheEntry? entry = await isar.isarCacheEntrys
//             .where()
//             .filter()
//             .keyEqualTo(key)
//             .findFirst();
//         if (entry == null) return null;
//
//         List<Map<String, dynamic>> list = [];
//         try {
//           list = (jsonDecode(entry.json) as List)
//               .whereType<Map>()
//               .map((m) => Map<String, dynamic>.from(m))
//               .toList();
//         } catch (_) {
//           return null;
//         }
//
//         final int before = list.length;
//         list.removeWhere(
//               (p) =>
//           (p['fast_key_product_id'] ?? p['product_id'] ?? p['id'])
//               ?.toString() ==
//               productId.toString(),
//         );
//         if (list.length == before) return null;
//
//         return entry
//           ..json = jsonEncode(list)
//           ..timestamp = DateTime.now();
//       }
//
//       // ── 5. Single Isar write transaction ───────────────────────────────────
//       // Collect which category ids are being touched by upserts so we can
//       // delete their indigo_products_ cache BEFORE writing the delta.
//       // This forces _IndigoProductRepositoryWithCache to do a full API fetch
//       // on next load instead of serving a partial delta-only cache.
//       final Set<int> affectedCategoryIds = {};
//       for (final productData in toUpsert) {
//         final List<dynamic> apiCategories =
//             (productData['categories'] as List?) ?? [];
//         for (final cat in apiCategories) {
//           final int? catId = cat['id'] is int
//               ? cat['id'] as int
//               : int.tryParse(cat['id']?.toString() ?? '');
//           if (catId != null) affectedCategoryIds.add(catId);
//         }
//       }
//
//       await isar.writeTxn(() async {
//         // ── 5-A  DELETED ────────────────────────────────────────────────────
//         for (final productId in toDelete) {
//           if (kDebugMode) print('Processing DELETE for product $productId…');
//
//           final List<IsarCacheEntry> productEntries = await isar.isarCacheEntrys
//               .where()
//               .filter()
//               .keyStartsWith('products_')
//               .findAll();
//
//           for (final entry in productEntries) {
//             final IsarCacheEntry? updated =
//             await removeProductFromEntry(entry.key, productId);
//             if (updated != null) {
//               await isar.isarCacheEntrys.put(updated);
//               if (kDebugMode) print('Removed $productId from ${entry.key}');
//             }
//           }
//
//           final List<IsarCacheEntry> indigoEntries = await isar.isarCacheEntrys
//               .where()
//               .filter()
//               .keyStartsWith('indigo_products_')
//               .findAll();
//
//           for (final entry in indigoEntries) {
//             final IsarCacheEntry? updated =
//             await removeProductFromEntry(entry.key, productId);
//             if (updated != null) {
//               await isar.isarCacheEntrys.put(updated);
//               if (kDebugMode)
//                 print('  ✂️  Removed $productId from ${entry.key}');
//             }
//           }
//
//           await isar.isarCacheEntrys
//               .filter()
//               .keyEqualTo('sku_$productId')
//               .deleteAll();
//
//           await isar.isarCacheEntrys
//               .filter()
//               .keyEqualTo('product_${productId}_variations')
//               .deleteAll();
//
//           if (kDebugMode)
//             print('  ✅ Product $productId fully deleted from Isar');
//         }
//
//         // ── 5-B  DELETE all indigo_products_ entries for affected categories
//         // BEFORE writing anything. This ensures the next UI load does a full
//         // API fetch and returns ALL products, not just the delta items.
//         for (final catId in affectedCategoryIds) {
//           final String indigoKey = 'indigo_products_$catId';
//           final deleted = await isar.isarCacheEntrys
//               .filter()
//               .keyEqualTo(indigoKey)
//               .deleteAll();
//           if (kDebugMode) {
//             print(
//                 '🗑️ Pre-deleted $indigoKey (count: $deleted) before upsert so next load fetches full list from API');
//           }
//         }
//
//         // ── 5-C  CREATED / UPDATED — write only to products_<catId> ──────────
//         // We intentionally do NOT recreate indigo_products_ here.
//         // The deleted entries above mean _IndigoProductRepositoryWithCache
//         // will see a cache miss and call the real API which returns every
//         // product in the category, not just the changed ones.
//         final Map<int, List<Map<String, dynamic>>> categoryProductMap = {};
//
//         for (final productData in toUpsert) {
//           final List<dynamic> apiCategories =
//               (productData['categories'] as List?) ?? [];
//
//           if (apiCategories.isEmpty) {
//             final int? id = productData['id'] is int
//                 ? productData['id'] as int
//                 : int.tryParse(productData['id']?.toString() ?? '');
//             if (id != null) {
//               await isar.isarCacheEntrys
//                   .filter()
//                   .keyEqualTo('sku_$id')
//                   .deleteAll();
//             }
//             if (kDebugMode) {
//               print('⚠️ Product id=${productData['id']} has no categories — '
//                   'skipping category cache update');
//             }
//             continue;
//           }
//
//           final Map<String, dynamic> normalised = normaliseProduct(productData);
//
//           for (final cat in apiCategories) {
//             final int? catId = cat['id'] is int
//                 ? cat['id'] as int
//                 : int.tryParse(cat['id']?.toString() ?? '');
//             if (catId == null) continue;
//             categoryProductMap.putIfAbsent(catId, () => []).add(normalised);
//           }
//         }
//
//         for (final mapEntry in categoryProductMap.entries) {
//           final int catId = mapEntry.key;
//           final List<Map<String, dynamic>> updatedProducts = mapEntry.value;
//
//           // products_<catId> — always merge delta into this cache
//           final String categoryKey = 'products_$catId';
//           final IsarCacheEntry? existing = await isar.isarCacheEntrys
//               .where()
//               .filter()
//               .keyEqualTo(categoryKey)
//               .findFirst();
//
//           List<Map<String, dynamic>> cachedList = [];
//           if (existing != null) {
//             try {
//               cachedList = (jsonDecode(existing.json) as List)
//                   .whereType<Map>()
//                   .map((m) => Map<String, dynamic>.from(m))
//                   .toList();
//             } catch (_) {}
//           }
//
//           for (final updated in updatedProducts) {
//             final int productId = updated['fast_key_product_id'] as int? ?? 0;
//             final int idx = cachedList.indexWhere(
//                   (p) =>
//               (p['fast_key_product_id'] ?? p['id'])?.toString() ==
//                   productId.toString(),
//             );
//             if (idx >= 0) {
//               cachedList[idx] = {...cachedList[idx], ...updated};
//               if (kDebugMode) {
//                 print('♻️  Upserted $productId → $categoryKey');
//               }
//             } else {
//               cachedList.add(updated);
//               if (kDebugMode) {
//                 print('➕ Inserted $productId → $categoryKey');
//               }
//             }
//           }
//
//           await isar.isarCacheEntrys.put(
//             (existing ?? IsarCacheEntry())
//               ..key = categoryKey
//               ..json = jsonEncode(cachedList)
//               ..timestamp = DateTime.now(),
//           );
//
//           // NOTE: indigo_products_<catId> is intentionally NOT written here.
//           // It was deleted in step 5-B above. The Indigo repo will fetch
//           // fresh from the API on next load, getting the full product list.
//
//           // Clean up sku_* for each upserted product
//           for (final updated in updatedProducts) {
//             final int productId = updated['fast_key_product_id'] as int? ?? 0;
//             if (productId != 0) {
//               await isar.isarCacheEntrys
//                   .filter()
//                   .keyEqualTo('sku_$productId')
//                   .deleteAll();
//             }
//           }
//         }
//       }); // end writeTxn
//
//       if (kDebugMode) {
//         print('Isar sync complete — '
//             'upserted: ${toUpsert.length}, deleted: ${toDelete.length}');
//       }
//
//       // ── 5-D. Acknowledge sync version to server ────────────────────────────
//       if (lastEventVersion != null) {
//         try {
//           final updateUrl = Uri.parse(
//             '${UrlHelper.baseUrl}'
//                 '${UrlHelper.componentVersionUrl}'
//                 'data-sync/update-data-count',
//           );
//
//           final updateResponse = await http.post(
//             updateUrl,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//             body: jsonEncode({
//               'device_id': 'POS-003',
//               'last_sync_version': lastEventVersion,
//             }),
//           );
//
//           if (kDebugMode) {
//             if (updateResponse.statusCode == 200) {
//               print('✅ Sync version acknowledged: '
//                   'last_sync_version=$lastEventVersion — '
//                   '${updateResponse.body}');
//             } else {
//               print('⚠️ update-data-count failed: '
//                   '${updateResponse.statusCode} — ${updateResponse.body}');
//             }
//           }
//         } catch (e) {
//           if (kDebugMode) print('⚠️ update-data-count error (non-fatal): $e');
//         }
//       }
//
//       // ── 6. Invalidate in-memory caches & notify CategoriesScreen ──────────
//       TopBar.notifyMergedProductCacheMayHaveChanged();
//       await _reloadAllProductsFromIsar();
//
//       TopBar.onRefreshCompleted?.call();
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Products refreshed successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e, st) {
//       if (kDebugMode) print('❌ refreshProducts error: $e\n$st');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Refresh failed: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }
//   // ══════════════════════════════════════════════════════════════════════════════
//   // SEARCH
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   _loadCachedProducts() async {
//     try {
//       await _reloadAllProductsFromIsar();
//     } catch (e) {
//       if (kDebugMode) print("_loadCachedProducts error: $e");
//       if (mounted) setState(() => _cacheLoaded = true);
//       TopBar._onTopBarMergedReloadCycleFinished();
//     }
//   }
//
//   static int? _productIdFromCacheMap(dynamic product) {
//     if (product is! Map) return null;
//     final dynamic raw = product["fast_key_product_id"] ??
//         product["product_id"] ??
//         product["id"];
//     if (raw is int) return raw;
//     return int.tryParse(raw?.toString() ?? "");
//   }
//
//   static Future<Map<int, dynamic>> _uniqueProductsFromAllCaches() async {
//     final isar = await IsarService.instance;
//     final Map<int, dynamic> uniqueProducts = {};
//
//     Iterable<dynamic> _expandCandidates(dynamic product) sync* {
//       if (product == null) return;
//       if (product is List) {
//         for (final item in product) {
//           yield* _expandCandidates(item);
//         }
//         return;
//       }
//       if (product is Map) {
//         final map = Map<String, dynamic>.from(product);
//         if (map["products"] is List) {
//           for (final nested in (map["products"] as List)) {
//             yield* _expandCandidates(nested);
//           }
//         } else if (map["product"] is Map || map["product"] is List) {
//           yield* _expandCandidates(map["product"]);
//         } else {
//           yield map;
//         }
//       }
//     }
//
//     void mergeProductList(List<dynamic> products) {
//       for (final product in products) {
//         try {
//           for (final candidate in _expandCandidates(product)) {
//             final int? productId = _productIdFromCacheMap(candidate);
//             if (productId == null) continue;
//             uniqueProducts[productId] = candidate;
//           }
//         } catch (_) {}
//       }
//     }
//
//     final indigoEntries = await isar.isarCacheEntrys
//         .where()
//         .filter()
//         .keyStartsWith("indigo_products_")
//         .findAll();
//     for (final entry in indigoEntries) {
//       try {
//         mergeProductList(json.decode(entry.json) as List<dynamic>);
//       } catch (_) {}
//     }
//
//     try {
//       final allList =
//       await StorageProvider.productCache.get("all_products_list");
//       if (allList is List) {
//         for (final item in allList) {
//           if (item is! Map) continue;
//           final m = Map<String, dynamic>.from(item);
//           if (m["products"] is List && (m["products"] as List).isNotEmpty) {
//             final first = (m["products"] as List).first;
//             if (first is Map) mergeProductList([first]);
//           } else {
//             mergeProductList([m]);
//           }
//         }
//       }
//     } catch (_) {}
//
//     final cachedEntries = await isar.isarCacheEntrys
//         .where()
//         .filter()
//         .keyStartsWith("products_")
//         .findAll();
//     for (final entry in cachedEntries) {
//       try {
//         mergeProductList(json.decode(entry.json) as List<dynamic>);
//       } catch (_) {}
//     }
//
//     return uniqueProducts;
//   }
//
//   Future<void> _reloadAllProductsFromIsar() async {
//     try {
//       final uniqueProducts = await _uniqueProductsFromAllCaches();
//       if (mounted) {
//         setState(() {
//           _cachedProducts = uniqueProducts.values.toList();
//           _cacheLoaded = true;
//         });
//         if (kDebugMode) {
//           print(
//               "✅ _cachedProducts refreshed: ${_cachedProducts.length} total products");
//         }
//       }
//       TopBar._onTopBarMergedReloadCycleFinished();
//     } catch (e) {
//       if (kDebugMode) print("❌ _reloadAllProductsFromIsar error: $e");
//       TopBar._onTopBarMergedReloadCycleFinished();
//     }
//   }
//
//   String _getProductImage(dynamic product) {
//     try {
//       if (product.images != null && product.images!.isNotEmpty) {
//         final img = product.images!.first;
//         if (img is String && img.isNotEmpty) return img;
//         if (img is Map && img["src"] != null) return img["src"].toString();
//       }
//     } catch (_) {}
//     return "";
//   }
//
//   getAllCachedProducts() async {
//     final uniqueProducts = await _uniqueProductsFromAllCaches();
//     return uniqueProducts.values.toList();
//   }
//
//   void _onFocusChanged() {
//     final q = _searchController.text.trim();
//     if (_searchFocusNode.hasFocus && q.length >= 3 && _overlayEntry == null) {
//       _showSearchResultsOverlay();
//     } else if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
//       _removeOverlay();
//     }
//   }
//
//   void _onSearchChanged() {
//     if (_debounce?.isActive ?? false) _debounce?.cancel();
//     final query = _searchController.text.toLowerCase().trim();
//     if (query.isEmpty || query.length < 3) {
//       _removeOverlay();
//       setState(() {});
//       return;
//     }
//
//     _debounce = Timer(const Duration(milliseconds: 500), () async {
//       final q = _searchController.text.toLowerCase().trim();
//       if (q.isEmpty || q.length < 3) {
//         _removeOverlay();
//         if (mounted) setState(() {});
//         return;
//       }
//
//       if (_overlayEntry == null) {
//         _showSearchResultsOverlay();
//       } else {
//         _overlayEntry?.markNeedsBuild();
//       }
//       if (mounted) setState(() {});
//
//       await _searchProductsFromApi(q);
//
//       if (!mounted) return;
//       _overlayEntry?.markNeedsBuild();
//       setState(() {});
//     });
//   }
//
//   Future<void> _searchProductsFromApi(String query) async {
//     if (_apiSearchCache.containsKey(query)) {
//       if (kDebugMode) print('⚡ API search cache hit for "$query"');
//       _mergeApiResults(_apiSearchCache[query]!);
//       return;
//     }
//
//     if (mounted) setState(() => _isApiSearchLoading = true);
//
//     try {
//       final token = await _getAuthTokenFromDb();
//       final encodedQuery = Uri.encodeQueryComponent(query);
//       final url = Uri.parse(
//         '${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}'
//             'products?search=$encodedQuery&page=1&per_page=20',
//       );
//
//       if (kDebugMode) print('🔍 API Search → $url');
//
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );
//
//       if (response.statusCode != 200) {
//         if (kDebugMode) {
//           print('⚠️ API search ${response.statusCode}: ${response.body}');
//         }
//         return;
//       }
//
//       final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
//
//       final List<Map<String, dynamic>> apiProducts = decoded
//           .whereType<Map>()
//           .map<Map<String, dynamic>>((p) {
//         final List<dynamic> images = (p['images'] as List?) ?? [];
//         final String imageUrl = images.isNotEmpty && images.first is Map
//             ? (images.first['src'] ?? '').toString()
//             : '';
//
//         final List<dynamic> rawTags = (p['tags'] as List?) ?? [];
//         final List<Map<String, dynamic>> tags = rawTags
//             .whereType<Map>()
//             .map((t) => {
//           'id': t['id'],
//           'name': (t['name'] ?? '').toString(),
//           'slug': (t['slug'] ?? '').toString(),
//         })
//             .toList();
//
//         final List<dynamic> rawCategories = (p['categories'] as List?) ?? [];
//
//         return {
//           'fast_key_product_id': p['id'],
//           'fast_key_item_name': p['name'] ?? '',
//           'fast_key_item_image': imageUrl,
//           'fast_key_item_price': p['price'] ?? p['regular_price'] ?? '0',
//           'fast_key_item_sku': p['sku'] ?? '',
//           'fast_key_item_tags': tags,
//           'id': p['id'],
//           'name': p['name'] ?? '',
//           'price': p['price'] ?? p['regular_price'] ?? '0',
//           'regular_price': p['regular_price'] ?? '',
//           'sku': p['sku'] ?? '',
//           'images': images,
//           'tags': tags,
//           'variations': p['variations'] ?? [],
//           'type': p['type'] ?? 'simple',
//           'categories': rawCategories,
//           'is_ebt_eligible': tags.any((t) {
//             final name = (t['name'] ?? '').toString().toLowerCase();
//             final slug = (t['slug'] ?? '').toString().toLowerCase();
//             return name == 'ebt' ||
//                 name == 'ebt eligible' ||
//                 slug == 'ebt' ||
//                 slug == 'ebt-eligible';
//           }),
//         };
//       }).toList();
//
//       _apiSearchCache[query] = apiProducts;
//
//       if (kDebugMode) {
//         print('✅ API returned ${apiProducts.length} products for "$query"');
//       }
//
//       _mergeApiResults(apiProducts);
//     } catch (e) {
//       if (kDebugMode) print('❌ _searchProductsFromApi error: $e');
//     } finally {
//       if (mounted) setState(() => _isApiSearchLoading = false);
//     }
//   }
//
//   void _mergeApiResults(List<Map<String, dynamic>> apiProducts) {
//     if (apiProducts.isEmpty) return;
//
//     final Map<int, dynamic> existing = {};
//     for (final p in _cachedProducts) {
//       final int? pid = _productIdFromCacheMap(p);
//       if (pid != null) existing[pid] = p;
//     }
//
//     bool changed = false;
//     for (final ap in apiProducts) {
//       final int? pid = _productIdFromCacheMap(ap);
//       if (pid == null) continue;
//       if (!existing.containsKey(pid)) {
//         existing[pid] = ap;
//         changed = true;
//       }
//     }
//
//     if (changed && mounted) {
//       setState(() {
//         _cachedProducts = existing.values.toList();
//       });
//     }
//   }
//
//   void _clearSearch() {
//     _searchController.clear();
//     _removeOverlay();
//     _searchFocusNode.unfocus();
//     setState(() {});
//   }
//
//   void _showSearchResultsOverlay() {
//     if (_overlayEntry != null || _dialogOpen) return;
//     final box =
//     _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
//     if (box == null) return;
//     final offset = box.localToGlobal(Offset.zero);
//     final size = box.size;
//
//     _overlayEntry = OverlayEntry(
//       builder: (context) {
//         final theme = Provider.of<ThemeNotifier>(context);
//         return Stack(
//           children: [
//             Positioned.fill(
//               child: GestureDetector(
//                 behavior: HitTestBehavior.translucent,
//                 onTap: () {
//                   _removeOverlay();
//                   _searchFocusNode.unfocus();
//                 },
//               ),
//             ),
//             Positioned(
//               width: size.width,
//               left: offset.dx,
//               top: offset.dy + size.height,
//               child: Material(
//                 elevation: 6,
//                 child: Container(
//                   constraints: const BoxConstraints(maxHeight: 360),
//                   decoration: BoxDecoration(
//                     color: theme.themeMode == ThemeMode.dark
//                         ? ThemeNotifier.secondaryBackground
//                         : Colors.white,
//                     borderRadius: const BorderRadius.only(
//                       bottomLeft: Radius.circular(8),
//                       bottomRight: Radius.circular(8),
//                     ),
//                   ),
//                   child: _buildLocalResultsList(),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//     Overlay.of(context).insert(_overlayEntry!);
//   }
//
//   Widget _buildLocalResultsList() {
//     final query = _searchController.text.toLowerCase().trim();
//     if (!_cacheLoaded) return const Center(child: CircularProgressIndicator());
//     if (_cachedProducts.isEmpty)
//       return const Center(child: Text("No products in cache"));
//     if (query.isNotEmpty && query.length < 3) {
//       return Center(child: Text(TextConstants.searchMinCharactersHint));
//     }
//
//     int? _resolveProductId(dynamic p) {
//       final dynamic raw =
//           p["fast_key_product_id"] ?? p["product_id"] ?? p["id"];
//       if (raw is int) return raw;
//       return int.tryParse(raw?.toString() ?? "");
//     }
//
//     String _resolveName(dynamic p) {
//       final dynamic rawName = p["fast_key_item_name"] ?? p["name"];
//       if (rawName is Map && rawName["rendered"] != null) {
//         return rawName["rendered"].toString();
//       }
//       return (rawName ?? "Unknown").toString();
//     }
//
//     String _resolvePrice(dynamic p) {
//       final dynamic raw = p["fast_key_item_price"] ??
//           p["price"] ??
//           p["regular_price"] ??
//           "0.00";
//       return raw.toString();
//     }
//
//     String _resolveSku(dynamic p) {
//       return (p["sku"] ?? p["fast_key_item_sku"] ?? "").toString();
//     }
//
//     List<int> _resolveVariationIds(dynamic p) {
//       final raw = p["variations"];
//       if (raw is! List || raw.isEmpty) return <int>[];
//       return raw
//           .map((v) => v is int ? v : int.tryParse(v?.toString() ?? ""))
//           .whereType<int>()
//           .toList();
//     }
//
//     String _normalize(String input) {
//       return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
//     }
//
//     bool _matchesCachedProduct(String q, dynamic p) {
//       final normalizedQuery = _normalize(q);
//       if (normalizedQuery.isEmpty) return true;
//
//       final normalizedName = _normalize(_resolveName(p));
//       final normalizedSku = _normalize(_resolveSku(p));
//
//       if (normalizedName.contains(normalizedQuery) ||
//           normalizedSku.contains(normalizedQuery)) {
//         return true;
//       }
//
//       final parts = q
//           .toLowerCase()
//           .split(RegExp(r'\s+'))
//           .map((e) => _normalize(e))
//           .where((e) => e.isNotEmpty)
//           .toList();
//       if (parts.isEmpty) return false;
//       return parts.every((part) =>
//       normalizedName.contains(part) || normalizedSku.contains(part));
//     }
//
//     final Map<int, dynamic> uniqueById = {};
//     for (final p in _cachedProducts) {
//       final int? pid = _resolveProductId(p);
//       if (pid == null) continue;
//       if (_matchesCachedProduct(query, p)) {
//         uniqueById[pid] = p;
//       }
//     }
//
//     final list = uniqueById.values.toList()
//       ..sort((a, b) {
//         final na = _resolveName(a).toLowerCase();
//         final nb = _resolveName(b).toLowerCase();
//         final sa = na.startsWith(query);
//         final sb = nb.startsWith(query);
//         if (sa && !sb) return -1;
//         if (!sa && sb) return 1;
//         return na.compareTo(nb);
//       });
//
//     if (list.isEmpty && _isApiSearchLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (list.isEmpty) return const Center(child: Text("No products found"));
//
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         if (_isApiSearchLoading) const LinearProgressIndicator(minHeight: 2),
//         Flexible(
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: list.length,
//             itemBuilder: (context, i) {
//               final p = list[i];
//               final name = _resolveName(p);
//               final price = _resolvePrice(p);
//               final sku = _resolveSku(p);
//
//               String? imageUrl;
//               final imagesRaw = p["images"];
//               if (imagesRaw != null) {
//                 if (imagesRaw is String && imagesRaw.isNotEmpty) {
//                   imageUrl = imagesRaw;
//                 } else if (imagesRaw is List && imagesRaw.isNotEmpty) {
//                   final first = imagesRaw.first;
//                   if (first is String && first.isNotEmpty) {
//                     imageUrl = first;
//                   } else if (first is Map && first["src"] != null) {
//                     imageUrl = first["src"].toString();
//                   }
//                 }
//               }
//               imageUrl ??= p["fast_key_item_image"]?.toString();
//               if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
//
//               return ListTile(
//                 leading: SizedBox(
//                   width: 50,
//                   height: 50,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: imageUrl != null
//                         ? Image.network(
//                       imageUrl,
//                       fit: BoxFit.cover,
//                       loadingBuilder: (ctx, child, progress) =>
//                       progress == null
//                           ? child
//                           : const Center(
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2)),
//                       errorBuilder: (_, __, ___) =>
//                       const Icon(Icons.broken_image, size: 40),
//                     )
//                         : const Icon(Icons.image, size: 40),
//                   ),
//                 ),
//                 title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
//                 subtitle: Row(
//                   children: [
//                     Text(
//                       "\$$price",
//                       style: const TextStyle(fontWeight: FontWeight.w500),
//                     ),
//                     const SizedBox(width: 6),
//
//                     // ── EBT badge ──────────────────────────────────────
//                     Builder(builder: (_) {
//                       final rawTags = p["tags"] ?? p["fast_key_item_tags"];
//                       final bool isEbt = rawTags is List &&
//                           rawTags.any((t) {
//                             final name = (t["name"] ?? "").toString().toLowerCase();
//                             final slug = (t["slug"] ?? "").toString().toLowerCase();
//                             return name.contains("ebt") || slug.contains("ebt");
//                           });
//                       if (!isEbt) return const SizedBox.shrink();
//                       return Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade600,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: const Text(
//                           'EBT',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.3,
//                           ),
//                         ),
//                       );
//                     }),
//
//                     const SizedBox(width: 4),
//
//                     // ── Variants badge ─────────────────────────────────
//                     Builder(builder: (_) {
//                       final rawVariations = p["variations"];
//                       final bool hasVariants = (rawVariations is List &&
//                           rawVariations.isNotEmpty) ||
//                           (p["type"]?.toString().toLowerCase() == "variable");
//                       if (!hasVariants) return const SizedBox.shrink();
//                       return Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
//                         // decoration: BoxDecoration(
//                         //   color: Theme.of(context).brightness == Brightness.dark
//                         //       ? const Color(0xFF2F3241)
//                         //       : const Color(0xFFF0F0F5),
//                         //   borderRadius: BorderRadius.circular(4),
//                         //   border: Border.all(
//                         //     color: Theme.of(context).brightness == Brightness.dark
//                         //         ? Colors.white24
//                         //         : Colors.black12,
//                         //     width: 0.5,
//                         //   ),
//                         // ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // CustomPaint(
//                             //   size: const Size(10, 10),
//                             //   // painter: _VariantIconPainter(
//                             //   //   color: Theme.of(context).brightness == Brightness.dark
//                             //   //       ? Colors.white54
//                             //   //       : Colors.black45,
//                             //   // ),
//                             // ),
//                             const SizedBox(width: 4),
//                             SvgPicture.asset(
//                               "assets/svg/variation.svg",
//                               height: 10,
//                               width: 10,
//                             ),
//                             // const SizedBox(width: 3),
//                             // Text(
//                             //   'Variants',
//                             //   style: TextStyle(
//                             //     fontSize: 9,
//                             //     fontWeight: FontWeight.w600,
//                             //     color: Theme.of(context).brightness == Brightness.dark
//                             //         ? Colors.white54
//                             //         : Colors.black54,
//                             //   ),
//                             // ),
//                           ],
//                         ),
//                       );
//                     }),
//                   ],
//                 ),
//                 onTap: () async {
//                   final int productId = _resolveProductId(p) ?? 0;
//                   ProductResponse fullProduct = ProductResponse(
//                     id: productId,
//                     name: name,
//                     price: price,
//                     sku: sku.isNotEmpty ? sku : null,
//                     images: imageUrl != null ? [imageUrl!] : [],
//                     variations: _resolveVariationIds(p),
//                   );
//
//                   try {
//                     final rawTags = p["tags"];
//                     if (rawTags is List && rawTags.isNotEmpty) {
//                       fullProduct.tags = rawTags.map((t) {
//                         if (t is Map) {
//                           return SKU.Tags(
//                             id: t["id"],
//                             name: t["name"]?.toString(),
//                             slug: t["slug"]?.toString(),
//                           );
//                         }
//                         return SKU.Tags();
//                       }).toList();
//                     } else {
//                       final isar = await IsarService.instance;
//                       final entries = await isar.isarCacheEntrys
//                           .where()
//                           .filter()
//                           .keyStartsWith("products_")
//                           .findAll();
//
//                       for (final entry in entries) {
//                         final List<dynamic> cached = jsonDecode(entry.json);
//                         final match = cached.firstWhere(
//                               (item) =>
//                           ((item["fast_key_product_id"] ??
//                               item["product_id"] ??
//                               item["id"])
//                               ?.toString() ==
//                               productId.toString()),
//                           orElse: () => null,
//                         );
//                         if (match != null) {
//                           final fallbackTags = match["tags"];
//                           if (fallbackTags is List &&
//                               fallbackTags.isNotEmpty) {
//                             fullProduct.tags = fallbackTags.map((t) {
//                               if (t is Map) {
//                                 return SKU.Tags(
//                                   id: t["id"],
//                                   name: t["name"]?.toString(),
//                                   slug: t["slug"]?.toString(),
//                                 );
//                               }
//                               return SKU.Tags();
//                             }).toList();
//                           }
//                           break;
//                         }
//                       }
//                     }
//                   } catch (e) {
//                     debugPrint(
//                         "❌ Tag enrichment failed for product $productId: $e");
//                   }
//
//                   _handleProductTap(fullProduct);
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // VARIANT HELPERS
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   Future<List<Map<String, dynamic>>> _getVariantsFromCache(
//       int productId) async {
//     try {
//       final productBox = StorageProvider.productCache;
//
//       List<Map<String, dynamic>> _normalizeVariants(dynamic raw) {
//         if (raw is! List || raw.isEmpty) return <Map<String, dynamic>>[];
//         return raw
//             .whereType<Map>()
//             .map<Map<String, dynamic>>((v) {
//           final map =
//           v.map((key, value) => MapEntry(key.toString(), value));
//           final attrs = map["attributes"];
//           final String fallbackName = attrs is List
//               ? attrs
//               .whereType<Map>()
//               .map((a) => (a["option"] ?? "").toString())
//               .where((x) => x.isNotEmpty)
//               .join(" - ")
//               : "";
//           return {
//             "id": map["id"],
//             "name": (map["name"] ?? "").toString().isNotEmpty
//                 ? map["name"]
//                 : (fallbackName.isNotEmpty ? fallbackName : "Variant"),
//             "price": map["regular_price"] ?? map["price"] ?? "0",
//             "image":
//             (map["image"] is Map && map["image"]["src"] != null)
//                 ? map["image"]["src"]
//                 : (map["image"] is String ? map["image"] : ""),
//             "sku": map["sku"] ?? "",
//           };
//         })
//             .where((v) => v["id"] != null)
//             .toList();
//       }
//
//       final isar = await IsarService.instance;
//       final entries = await isar.isarCacheEntrys
//           .where()
//           .filter()
//           .keyStartsWith("products_")
//           .findAll();
//
//       for (final entry in entries) {
//         final List<dynamic> products = jsonDecode(entry.json);
//         final match = products.firstWhere(
//               (p) =>
//           p["fast_key_product_id"]?.toString() == productId.toString(),
//           orElse: () => null,
//         );
//         if (match == null) continue;
//
//         final rawVariations = match["variations"] ??
//             (await productBox
//                 .get("product_${productId}_variations"))?["variations"];
//         final variants = _normalizeVariants(rawVariations);
//         if (variants.isNotEmpty) return variants;
//       }
//
//       final cached =
//       await productBox.get("product_${productId}_variations");
//       final fallbackVariants =
//       _normalizeVariants(cached is Map ? cached["variations"] : null);
//       if (fallbackVariants.isNotEmpty) return fallbackVariants;
//     } catch (e) {
//       debugPrint("_getVariantsFromCache error: $e");
//     }
//     return [];
//   }
//
//   Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(
//       int productId) async {
//     try {
//       final token = await _getAuthTokenFromDb();
//       final url = Uri.parse(
//           "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations");
//       final response =
//       await http.get(url, headers: {"Authorization": "Bearer $token"});
//       if (response.statusCode != 200) return <Map<String, dynamic>>[];
//
//       final decoded = jsonDecode(response.body);
//       if (decoded is! List) return <Map<String, dynamic>>[];
//
//       return decoded
//           .whereType<Map>()
//           .map<Map<String, dynamic>>((v) {
//         final map =
//         v.map((key, value) => MapEntry(key.toString(), value));
//         final attrs = map["attributes"];
//         final String fallbackName = attrs is List
//             ? attrs
//             .whereType<Map>()
//             .map((a) => (a["option"] ?? "").toString())
//             .where((x) => x.isNotEmpty)
//             .join(" - ")
//             : "";
//         return {
//           "id": map["id"],
//           "name": (map["name"] ?? "").toString().isNotEmpty
//               ? map["name"]
//               : (fallbackName.isNotEmpty ? fallbackName : "Variant"),
//           "price":
//           (map["price"] ?? map["regular_price"] ?? "0").toString(),
//           "image":
//           (map["image"] is Map && map["image"]["src"] != null)
//               ? map["image"]["src"]
//               : (map["image"] is String ? map["image"] : ""),
//           "sku": map["sku"] ?? "",
//         };
//       })
//           .where((v) => v["id"] != null)
//           .toList();
//     } catch (e) {
//       debugPrint("_fetchVariationsFromApi error: $e");
//       return <Map<String, dynamic>>[];
//     }
//   }
//
//   Future<String> _getAuthTokenFromDb() async {
//     final db = await DBHelper.instance.database;
//     final result = await db.query(
//       AppDBConst.userTable,
//       where:
//       '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
//       orderBy: '${AppDBConst.userId} DESC',
//       limit: 1,
//     );
//     if (result.isEmpty) throw Exception('No active user token found');
//     return result.first[AppDBConst.userToken] as String;
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // PRODUCT TAP HANDLER
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   Future<void> _handleProductTap(ProductResponse product) async {
//     final screen = widget.screen;
//     if (screen != Screen.FASTKEY &&
//         screen != Screen.CATEGORY &&
//         screen != Screen.ADD) {
//       if (kDebugMode) print("TopBar: product tap ignored on screen $screen");
//       return;
//     }
//
//     if (_dialogOpen) {
//       if (kDebugMode) print("TopBar: dialog already open, ignoring tap");
//       return;
//     }
//
//     _searchFocusNode.unfocus();
//     _removeOverlay();
//     await WidgetsBinding.instance.endOfFrame;
//     if (!mounted) return;
//
//     try {
//       final ensuredOrderId = await orderHelper.ensureOrderExists();
//       if (ensuredOrderId == null) {
//         if (kDebugMode) print("❌ Failed to create or restore order");
//         return;
//       }
//       if (!mounted) return;
//
//       final offlineBox = StorageProvider.offlineOrders;
//       final activeOrderId = ensuredOrderId.toString();
//       final raw = await offlineBox.get(activeOrderId);
//       final Map<String, dynamic> rawOrder =
//       Map<String, dynamic>.from(raw is Map ? raw : {});
//
//       final List<SKU.Tags> tags = product.tags ?? [];
//
//       // Age verification
//       final bool hasAgeRestriction =
//       tags.any((t) => t.name == TextConstants.age_restricted);
//
//       if (hasAgeRestriction) {
//         final dynamic hiveAge = rawOrder["age_verified"];
//         final bool alreadyVerified = hiveAge == true ||
//             hiveAge == 1 ||
//             hiveAge?.toString().toLowerCase() == "true";
//
//         if (!alreadyVerified) {
//           final SKU.Tags ageTag =
//           tags.firstWhere((t) => t.name == TextConstants.age_restricted);
//           final int minAge =
//               int.tryParse(ageTag.slug?.toString() ?? "0") ?? 0;
//
//           _dialogOpen = true;
//           final prov = AgeVerificationProvider();
//           final ok = await prov.verifyAge(context, minAge: minAge);
//           _dialogOpen = false;
//
//           if (!mounted) return;
//           if (!ok) return;
//
//           rawOrder["age_verified"] = true;
//           await offlineBox.put(activeOrderId, rawOrder);
//         }
//       }
//
//       if (!mounted) return;
//
//       // EBT eligibility
//       bool isEbtEligible = false;
//       try {
//         final isar = await IsarService.instance;
//         final cachedEntries = await isar.isarCacheEntrys
//             .where()
//             .filter()
//             .keyStartsWith("products_")
//             .findAll();
//
//         for (final entry in cachedEntries) {
//           final List<dynamic> products = jsonDecode(entry.json);
//           final match = products.firstWhere(
//                 (p) =>
//             p["fast_key_product_id"]?.toString() ==
//                 product.id.toString(),
//             orElse: () => null,
//           );
//           if (match != null) {
//             final dynamic rawEbt = match["is_ebt_eligible"];
//             isEbtEligible = rawEbt == true ||
//                 rawEbt == 1 ||
//                 rawEbt?.toString() == "1" ||
//                 rawEbt?.toString().toLowerCase() == "true";
//             break;
//           }
//         }
//       } catch (e) {
//         if (kDebugMode) print("⚠️ EBT resolve error: $e");
//       }
//
//       if (!isEbtEligible) {
//         isEbtEligible = tags.any((t) {
//           final name = t.name?.toLowerCase() ?? "";
//           final slug = t.slug?.toLowerCase() ?? "";
//           return name == "ebt" ||
//               name == "ebt eligible" ||
//               slug == "ebt" ||
//               slug == "ebt-eligible";
//         });
//       }
//
//       if (!mounted) return;
//
//       final double unitPrice = (product.price is num)
//           ? (product.price as num).toDouble()
//           : double.tryParse(product.price?.toString() ?? "0") ?? 0.0;
//
//       // Produce
//       final bool hasProduceTag = tags.any((t) =>
//       t.slug?.toLowerCase() == "produce" ||
//           t.name?.toLowerCase() == "produce");
//
//       // if (hasProduceTag) {
//       //   await WidgetsBinding.instance.endOfFrame;
//       //   if (!mounted) return;
//       //
//       //   _dialogOpen = true;
//       //   Map<String, dynamic>? result;
//       //   try {
//       //     result = await showDialog<Map<String, dynamic>>(
//       //       context: context,
//       //       barrierDismissible: false,
//       //       useRootNavigator: true,
//       //       builder: (dialogCtx) => ChangeNotifierProvider.value(
//       //         value: Provider.of<WeightProvider>(context, listen: false),
//       //         child: AutoWeightPriceDialog(
//       //           productName: product.name ?? "Product",
//       //           unitPrice: unitPrice,
//       //         ),
//       //       ),
//       //     );
//       //   } finally {
//       //     _dialogOpen = false;
//       //   }
//       //
//       //   if (!mounted) return;
//       //   if (result == null) return;
//       //
//       //   final double finalPrice = (result["finalPrice"] as num).toDouble();
//       //   final double weightValue = (result["weight"] as num).toDouble();
//       //
//       //   setState(() => isAddingItemLoading = true);
//       //
//       //   await orderHelper.addItemToOrder(
//       //     product.id!,
//       //     product.name ?? 'Unknown',
//       //     product.images?.isNotEmpty == true ? product.images!.first : '',
//       //     finalPrice,
//       //     1,
//       //     product.sku ?? '',
//       //     int.parse(activeOrderId),
//       //     type: "weighted",
//       //     weightQty: weightValue,
//       //     productId: product.id,
//       //     variationId: -1,
//       //     unitPrice: unitPrice,
//       //     salesPrice: finalPrice,
//       //     regularPrice: unitPrice,
//       //     combo: null,
//       //     isEbtEligible: isEbtEligible,
//       //     onItemAdded: () {
//       //       _removeOverlay();
//       //       _clearSearch();
//       //       if (mounted) setState(() => isAddingItemLoading = false);
//       //       widget.onProductSelected?.call(product);
//       //     },
//       //   );
//       //   return;
//       // }
//
//
//       if (hasProduceTag) {
//         final weightProvider =
//         Provider.of<WeightProvider>(context, listen: false);
//
//         // Parse current weight from scale display
//         double liveWeight = 0.0;
//         try {
//           final parts = weightProvider.weightText.trim().split(' ');
//           if (parts.isNotEmpty) {
//             liveWeight = double.tryParse(parts[0]) ?? 0.0;
//           }
//         } catch (_) {}
//
//         // Convert lb → kg
//         final double weightKg =
//         liveWeight > 0 ? liveWeight * 0.453592 : 0.0;
//
//         // Fallback weight
//         final double weightToUse =
//         weightKg > 0.00001 ? weightKg : 0.0001;
//
//         final double finalPrice = unitPrice * weightToUse;
//
//         if (weightKg <= 0.0001 && mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Scale not detected — using 100g default'),
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }
//
//         setState(() => isAddingItemLoading = true);
//
//         await orderHelper.addItemToOrder(
//           product.id!,
//           product.name ?? 'Unknown',
//           product.images?.isNotEmpty == true
//               ? product.images!.first
//               : '',
//           finalPrice,
//           1,
//           product.sku ?? '',
//           int.parse(activeOrderId),
//           type: 'weighted',
//           weightQty: weightToUse,
//           productId: product.id,
//           variationId: -1,
//           unitPrice: unitPrice,
//           salesPrice: finalPrice,
//           regularPrice: unitPrice,
//           combo: null,
//           isEbtEligible: isEbtEligible,
//           // onItemAdded: () {
//           //
//           //
//           //   // Reset scale
//           //   weightProvider.updateWeight(0.0);
//           //
//           //   _removeOverlay();
//           //   _clearSearch();
//           //
//           //   if (mounted) {
//           //     setState(() => isAddingItemLoading = false);
//           //   }
//           //
//           //   widget.onProductSelected?.call(product);
//           // },
//             onItemAdded: () {
//                     _removeOverlay();
//                     _clearSearch();
//                     if (mounted) setState(() => isAddingItemLoading = false);
//                     widget.onProductSelected?.call(product);
//                   },
//         );
//
//         return;
//       }
//
//       // Variants
//       List<Map<String, dynamic>> variants =
//       await _getVariantsFromCache(product.id!);
//       if (variants.isEmpty) {
//         variants = await _fetchVariationsFromApi(product.id!);
//         if (variants.isNotEmpty) {
//           await StorageProvider.productCache.put(
//             "product_${product.id}_variations",
//             {
//               "variations": variants,
//               "timestamp": DateTime.now().toIso8601String(),
//             },
//           );
//         }
//       }
//       final bool hasVariants = variants.isNotEmpty;
//
//       if (!mounted) return;
//
//       if (hasVariants) {
//         await WidgetsBinding.instance.endOfFrame;
//         if (!mounted) return;
//
//         _dialogOpen = true;
//         try {
//           await showDialog(
//             context: context,
//             barrierDismissible: false,
//             useRootNavigator: true,
//             builder: (dialogCtx) => VariantsDialog(
//               title: product.name ?? "Select Variant",
//               variations: variants,
//               onAddVariant: (selected, qty) async {
//                 final varPrice =
//                     double.tryParse(selected["price"].toString()) ?? 0.0;
//
//                 await orderHelper.addItemToOrder(
//                   selected["id"],
//                   selected["name"] ?? product.name ?? 'Unknown',
//                   selected["image"] ?? '',
//                   varPrice,
//                   qty,
//                   selected["sku"] ?? product.sku ?? '',
//                   int.parse(activeOrderId),
//                   type: 'variant',
//                   productId: product.id,
//                   variationId: selected["id"],
//                   unitPrice: varPrice,
//                   salesPrice: varPrice,
//                   regularPrice: varPrice,
//                   isEbtEligible: isEbtEligible,
//                   onItemAdded: () {
//                     _removeOverlay();
//                     _clearSearch();
//                     if (mounted) setState(() => isAddingItemLoading = false);
//                     widget.onProductSelected?.call(product);
//                   },
//                 );
//               },
//             ),
//           );
//         } finally {
//           _dialogOpen = false;
//         }
//
//         _removeOverlay();
//         _clearSearch();
//         if (mounted) setState(() => isAddingItemLoading = false);
//         return;
//       }
//
//       // Variable price
//       final bool hasVariablePriceTag = tags.any((t) =>
//       t.slug?.toLowerCase() == "variable-product" ||
//           t.slug?.toLowerCase() == "variable" ||
//           t.name?.toLowerCase() == "variable product" ||
//           t.name?.toLowerCase() == "variable");
//
//       final String variableKey = "variable_price_added_${product.id}";
//       final String savedPriceKey = "selected_price_${product.id}";
//       final bool popupAlreadyShown = rawOrder[variableKey] == true;
//
//       double finalPrice = unitPrice;
//
//       if (hasVariablePriceTag) {
//         if (popupAlreadyShown) {
//           final savedPrice = rawOrder[savedPriceKey];
//           finalPrice =
//               double.tryParse(savedPrice?.toString() ?? "") ?? unitPrice;
//         } else {
//           await WidgetsBinding.instance.endOfFrame;
//           if (!mounted) return;
//
//           _dialogOpen = true;
//           double? enteredPrice;
//           try {
//             enteredPrice = await ManualPriceDialog.show(
//               context,
//               productName: product.name ?? "Product",
//               productImage: _getProductImage(product),
//               minPrice: unitPrice,
//             );
//           } finally {
//             _dialogOpen = false;
//           }
//
//           if (!mounted) return;
//           if (enteredPrice == null) return;
//
//           finalPrice = enteredPrice;
//           rawOrder[variableKey] = true;
//           rawOrder[savedPriceKey] = finalPrice;
//           await offlineBox.put(activeOrderId, rawOrder);
//         }
//       }
//
//       if (!mounted) return;
//
//       // Simple product
//       setState(() => isAddingItemLoading = true);
//
//       await orderHelper.addItemToOrder(
//         product.id!,
//         product.name ?? 'Unknown',
//         product.images?.isNotEmpty == true ? product.images!.first : '',
//         finalPrice,
//         1,
//         product.sku ?? '',
//         int.tryParse(activeOrderId) ?? 0,
//         type: "simple",
//         productId: product.id!,
//         variationId: -1,
//         variationName: null,
//         variationCount: 0,
//         combo: null,
//         salesPrice: finalPrice,
//         regularPrice: finalPrice,
//         unitPrice: finalPrice,
//         isEbtEligible: isEbtEligible,
//         onItemAdded: () {
//           _removeOverlay();
//           _clearSearch();
//           if (mounted) setState(() => isAddingItemLoading = false);
//           widget.onProductSelected?.call(product);
//         },
//       );
//     } catch (e, st) {
//       if (kDebugMode) print("❌ _handleProductTap Exception: $e\n$st");
//       _dialogOpen = false;
//       _removeOverlay();
//       if (mounted) setState(() => isAddingItemLoading = false);
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // MISC HELPERS
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   void _removeOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }
//
//   Future<void> _fetchUserId() async {
//     if (_isUserDataLoaded && _cachedUserData != null) {
//       final userData = _cachedUserData;
//       if (userData != null && userData[AppDBConst.userId] != null) {
//         setState(() {
//           userId = userData[AppDBConst.userId] as int;
//           userDisplayName = userData[AppDBConst.userDisplayName];
//           userRole = userData[AppDBConst.userRole];
//         });
//       }
//       return;
//     }
//     final userData = await UserDbHelper().getUserData();
//     if (userData != null && userData[AppDBConst.userId] != null) {
//       setState(() {
//         userId = userData[AppDBConst.userId] as int;
//         userDisplayName = userData[AppDBConst.userDisplayName];
//         userRole = userData[AppDBConst.userRole];
//       });
//     }
//   }
//
//   Future<bool> _showCashDrawerPinPopup(BuildContext context) async {
//     final TextEditingController pinController = TextEditingController();
//     bool isError = false;
//
//     return await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             final isDark =
//                 Theme.of(context).brightness == Brightness.dark;
//
//             return Dialog(
//               insetPadding:
//               const EdgeInsets.symmetric(horizontal: 40),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               backgroundColor:
//               isDark ? const Color(0xFF2F3241) : Colors.white,
//               child: SizedBox(
//                 width: 320,
//                 child: Padding(
//                   padding: const EdgeInsets.all(20),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.red.withOpacity(0.15),
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(
//                           Icons.lock_outline,
//                           color: Colors.redAccent,
//                           size: 30,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Text(
//                         "Authentication Required",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           fontFamily: 'Inter',
//                           color: isDark ? Colors.white : Colors.black,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       Text(
//                         "Enter PIN to open cash drawer",
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontFamily: 'Inter',
//                           color: isDark
//                               ? Colors.white60
//                               : Colors.grey[600],
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 18),
//                       _PinBoxField(
//                         controller: pinController,
//                         hasError: isError,
//                       ),
//                       if (isError) ...[
//                         const SizedBox(height: 8),
//                         const Text(
//                           "You are not authorized to access this feature.",
//                           style:
//                           TextStyle(fontSize: 11, color: Colors.red),
//                         ),
//                       ],
//                       const SizedBox(height: 20),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: isDark
//                                     ? const Color(0xFF50535F)
//                                     : const Color(0xFFE0E0E0),
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 10),
//                                 shape: RoundedRectangleBorder(
//                                     borderRadius:
//                                     BorderRadius.circular(8)),
//                               ),
//                               onPressed: () =>
//                                   Navigator.pop(ctx, false),
//                               child: Text(
//                                 "Cancel",
//                                 style: TextStyle(
//                                   color: isDark
//                                       ? Colors.white70
//                                       : Colors.black87,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.redAccent,
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 10),
//                                 shape: RoundedRectangleBorder(
//                                     borderRadius:
//                                     BorderRadius.circular(8)),
//                               ),
//                               onPressed: () async {
//                                 final pin =
//                                 pinController.text.trim();
//                                 if (pin.length != 6) {
//                                   setState(() => isError = true);
//                                   return;
//                                 }
//                                 setState(() => isError = false);
//                                 try {
//                                   final response =
//                                   await OrderRepository()
//                                       .validateLoginPin(pin);
//                                   final decoded =
//                                   json.decode(response);
//                                   if (decoded["success"] == true) {
//                                     Navigator.pop(ctx, true);
//                                   } else {
//                                     setState(() => isError = true);
//                                     pinController.clear();
//                                   }
//                                 } catch (e) {
//                                   setState(() => isError = true);
//                                   pinController.clear();
//                                 }
//                               },
//                               child: const Text(
//                                 "Confirm",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
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
//             );
//           },
//         );
//       },
//     ) ??
//         false;
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════════
//   // BUILD
//   // ══════════════════════════════════════════════════════════════════════════════
//
//   @override
//   Widget build(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//
//     return Container(
//       color: themeHelper.themeMode == ThemeMode.dark
//           ? ThemeNotifier.primaryBackground
//           : Colors.white,
//       height: 70,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Row(
//         children: [
//           SvgPicture.asset(
//             themeHelper.themeMode == ThemeMode.dark
//                 ? 'assets/svg/app_logo.svg'
//                 : 'assets/svg/app_icon.svg',
//             height: 40,
//             width: 40,
//           ),
//           const SizedBox(width: 80),
//
//           // Search bar
//           Expanded(
//             child: Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: themeHelper.themeMode == ThemeMode.dark
//                       ? const Color(0xFF3B3939)
//                       : const Color(0xFFEDEBEB),
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: themeHelper.themeMode == ThemeMode.dark
//                         ? const Color(0xFF605F5F)
//                         : Colors.grey.withOpacity(0.1),
//                     blurRadius: 2,
//                     spreadRadius:
//                     themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
//                     offset: const Offset(0, 0),
//                   ),
//                 ],
//               ),
//               height: 46,
//               key: _searchFieldKey,
//               child: TextField(
//                 enabled: _isSearchEnabled,
//                 controller: _searchController,
//                 focusNode: _searchFocusNode,
//                 decoration: InputDecoration(
//                   hintText: TextConstants.searchHint,
//                   prefixIcon: Icon(Icons.search,
//                       color: Theme.of(context).iconTheme.color),
//                   suffixIcon: _searchController.text.isNotEmpty
//                       ? IconButton(
//                     icon: Icon(Icons.clear,
//                         color: Theme.of(context).iconTheme.color),
//                     onPressed: _clearSearch,
//                   )
//                       : null,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(20),
//                     borderSide: BorderSide.none,
//                   ),
//                   filled: true,
//                   fillColor: themeHelper.themeMode == ThemeMode.dark
//                       ? ThemeNotifier.searchBarBackground
//                       : Colors.white,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 50),
//
//           // Scale weight display — isolated widget, no TopBar rebuild on weight events
//           _ScaleDisplayWidget(
//             onLongPress: _reconnectScale,
//             onReconnect: _reconnectScale,
//             isConnectingNotifier: _isConnectingNotifier,
//           ),
//
//           if (widget.screen == Screen.SHIFT) ...[
//             const SizedBox(width: 10),
//             GestureDetector(
//               onTap: () async {
//                 showDialog(
//                   context: context,
//                   barrierDismissible: false,
//                   builder: (_) =>
//                   const Center(child: CircularProgressIndicator()),
//                 );
//
//                 await LogoutBloc(LogoutRepository()).performLogout();
//                 await UserDbHelper().logout();
//                 await PinakaPreferences.clearUserPreferences();
//                 TopBar.clearUserCache();
//
//                 Navigator.of(context).pop();
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (_) => LoginScreen()),
//                 );
//               },
//               child: Container(
//                 padding: const EdgeInsets.all(13),
//                 decoration: BoxDecoration(
//                   color: themeHelper.themeMode == ThemeMode.dark
//                       ? ThemeNotifier.secondaryBackground
//                       : Colors.white,
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: themeHelper.themeMode == ThemeMode.dark
//                         ? const Color(0xFF3B3939)
//                         : const Color(0xFFF1F1F3),
//                   ),
//                 ),
//                 child: const Icon(Icons.logout, size: 24, color: Colors.grey),
//               ),
//             ),
//           ],
//
//           const SizedBox(width: 16),
//
//           // Cash drawer
//           GestureDetector(
//             onTap: () async {
//               final isAuthorized =
//               await _showCashDrawerPinPopup(context);
//               if (!isAuthorized) return;
//               await PrinterSettings.openDrawer(context: context);
//               List<int> bytes = [];
//               final ticket = await _printerSettings.getTicket();
//               bytes += ticket.feed(1);
//               await _printerSettings.printTicket(bytes, ticket);
//             },
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: themeHelper.themeMode == ThemeMode.dark
//                     ? ThemeNotifier.secondaryBackground
//                     : Colors.white,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: themeHelper.themeMode == ThemeMode.dark
//                       ? const Color(0xFF3B3939)
//                       : const Color(0xFFF1F1F3),
//                 ),
//               ),
//               child: SvgPicture.asset(
//                 SvgUtils.cashDrawerIcon,
//                 width: 26,
//                 height: 26,
//                 colorFilter: ColorFilter.mode(
//                   themeHelper.themeMode == ThemeMode.dark
//                       ? Colors.white70
//                       : Colors.grey,
//                   BlendMode.srcIn,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//
//
// // Mode toggle - FIXED (Prevents accidental trigger during navigation)
//           GestureDetector(
//             onTap: () {
//               print("🔄 [MODE BUTTON] Tapped — calling onModeChanged");
//               // ✅ No modeChangedNotifier.value++ — removing this was the key fix.
//               // That static notifier leaked to ALL screens that ever built a TopBar,
//               // including TotalOrdersScreen and CompletedOrdersScreen (Refund).
//               widget.onModeChanged();
//             },
//             child: Container(
//               padding: const EdgeInsets.all(13),
//               decoration: BoxDecoration(
//                 color: themeHelper.themeMode == ThemeMode.dark
//                     ? ThemeNotifier.secondaryBackground
//                     : Colors.white,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: themeHelper.themeMode == ThemeMode.dark
//                       ? const Color(0xFF3B3939)
//                       : const Color(0xFFF1F1F3),
//                 ),
//               ),
//               child: SvgPicture.asset(
//                 SvgUtils.changeModeIcon,
//                 width: 26,
//                 height: 26,
//                 colorFilter: ColorFilter.mode(
//                   themeHelper.themeMode == ThemeMode.dark
//                       ? Colors.white70
//                       : Colors.grey,
//                   BlendMode.srcIn,
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 16),
//
//           // Theme toggle
//           GestureDetector(
//             onTap: () {
//               themeHelper.setThemeMode(
//                 themeHelper.themeMode == ThemeMode.dark
//                     ? ThemeMode.light
//                     : ThemeMode.dark,
//               );
//             },
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: themeHelper.themeMode == ThemeMode.dark
//                     ? ThemeNotifier.secondaryBackground
//                     : Colors.white,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: themeHelper.themeMode == ThemeMode.dark
//                       ? const Color(0xFF605F5F)
//                       : const Color(0xFFF1F1F3),
//                 ),
//               ),
//               child: SvgPicture.asset(
//                 SvgUtils.themeIcon,
//                 width: 26,
//                 height: 26,
//                 colorFilter: ColorFilter.mode(
//                   themeHelper.themeMode == ThemeMode.dark
//                       ? Colors.white70
//                       : Colors.grey,
//                   BlendMode.srcIn,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//
//           // Notifications
//           Container(
//             decoration: BoxDecoration(
//               color: themeHelper.themeMode == ThemeMode.dark
//                   ? ThemeNotifier.secondaryBackground
//                   : Colors.white,
//               shape: BoxShape.circle,
//               border: Border.all(
//                 color: themeHelper.themeMode == ThemeMode.dark
//                     ? const Color(0xFF3B3939)
//                     : const Color(0xFFF1F1F3),
//               ),
//             ),
//             padding: const EdgeInsets.all(10),
//             child: Icon(
//               Icons.notifications,
//               size: 24,
//               color: themeHelper.themeMode == ThemeMode.dark
//                   ? Colors.white
//                   : Colors.black54,
//             ),
//           ),
//           const SizedBox(width: 16),
//
//           // Refresh
//           IconButton(
//             icon: isLoading
//                 ? const SizedBox(
//               height: 20,
//               width: 20,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//                 : const Icon(Icons.refresh),
//             onPressed: isLoading ? null : refreshProducts,
//           ),
//
//           // User chip
//           Container(
//             height: 45,
//             padding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
//             decoration: BoxDecoration(
//               color: themeHelper.themeMode == ThemeMode.dark
//                   ? ThemeNotifier.secondaryBackground
//                   : Colors.white,
//               borderRadius: BorderRadius.circular(15),
//               border: Border.all(
//                 color: themeHelper.themeMode == ThemeMode.dark
//                     ? const Color(0xFF3B3939)
//                     : const Color(0xFFF1F1F3),
//               ),
//             ),
//             child: Row(
//               children: [
//                 CircleAvatar(
//                   radius: 15,
//                   backgroundColor: Colors.deepPurple,
//                   child: Text(
//                     (userDisplayName ?? "Unknown")
//                         .substring(0, 1)
//                         .toUpperCase(),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 15),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       userDisplayName ?? "",
//                       style: TextStyle(
//                         fontWeight: FontWeight.w500,
//                         color: themeHelper.themeMode == ThemeMode.dark
//                             ? ThemeNotifier.textDark
//                             : ThemeNotifier.textLight,
//                         fontSize: 14,
//                       ),
//                     ),
//                     Text(
//                       userRole ?? "Unknown",
//                       style: const TextStyle(
//                           color: Color(0xFFE09696), fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Database/storage/storage_provider.dart';
import 'package:isar/isar.dart';
import 'package:pinaka_pos/Widgets/weighing_scale_widget.dart';
import 'package:pinaka_pos/Widgets/widget_variants_dialog.dart';
import 'package:provider/provider.dart';

import '../Blocs/Auth/logout_bloc.dart';
import '../Blocs/Orders/order_bloc.dart';
import '../Blocs/Search/product_search_bloc.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/fast_key_db_helper.dart';
import '../Database/isar_cache_entry.dart';
import '../Database/isar_service.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/user_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/url_helper.dart';
import '../Helper/native_usb_scan_bridge.dart';
import '../Helper/api_response.dart';
import '../Models/Search/product_search_model.dart';
import '../Preferences/pinaka_preferences.dart';
import '../Providers/Age/age_verification_provider.dart';
import '../Repositories/Auth/logout_repository.dart';
import '../Repositories/Orders/order_repository.dart';
import '../Repositories/Search/product_search_repository.dart';
import '../Screens/Auth/login_screen.dart' show LoginScreen;
import '../Screens/Home/categories_screen.dart';
import '../Screens/Home/fast_key_screen.dart';
import '../Utilities/printer_settings.dart';
import '../Utilities/svg_images_utility.dart';
import 'ManualPriceDialog.dart';

import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart' as SKU;



const _scaleMethodChannel = MethodChannel('magellan_scale');
const _scaleEventChannel = EventChannel('magellan_scale/events');

// ══════════════════════════════════════════════════════════════════════════════
// 7-SEGMENT LCD DISPLAY
// ══════════════════════════════════════════════════════════════════════════════

class _SegmentPainter extends CustomPainter {
  final String char;
  final Color onColor;
  final Color offColor;
  final double strokeW;

  _SegmentPainter({
    required this.char,
    required this.onColor,
    required this.offColor,
    this.strokeW = 3.0,
  });

  static const Map<String, List<bool>> _segments = {
    '0': [true, true, true, true, true, true, false],
    '1': [false, true, true, false, false, false, false],
    '2': [true, true, false, true, true, false, true],
    '3': [true, true, true, true, false, false, true],
    '4': [false, true, true, false, false, true, true],
    '5': [true, false, true, true, false, true, true],
    '6': [true, false, true, true, true, true, true],
    '7': [true, true, true, false, false, false, false],
    '8': [true, true, true, true, true, true, true],
    '9': [true, true, true, true, false, true, true],
    '.': [false, false, false, false, false, false, false],
    '-': [false, false, false, false, false, false, true],
    ' ': [false, false, false, false, false, false, false],
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (char == '.') {
      final dotR = strokeW * 1.1;
      canvas.drawCircle(
        Offset(size.width / 2, size.height - dotR),
        dotR,
        Paint()..color = onColor,
      );
      return;
    }

    final segs = _segments[char] ?? _segments[' ']!;
    final w = size.width;
    final h = size.height;
    final s = strokeW;
    final gap = s * 0.55;

    void seg(bool on, Offset p1, Offset p2) {
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = on ? onColor : offColor
          ..strokeWidth = s
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    final mid = h / 2;
    seg(segs[0], Offset(gap + s * 0.5, s * 0.5),
        Offset(w - gap - s * 0.5, s * 0.5));
    seg(segs[1], Offset(w - s * 0.5, gap + s * 0.5),
        Offset(w - s * 0.5, mid - gap));
    seg(segs[2], Offset(w - s * 0.5, mid + gap),
        Offset(w - s * 0.5, h - gap - s * 0.5));
    seg(segs[3], Offset(gap + s * 0.5, h - s * 0.5),
        Offset(w - gap - s * 0.5, h - s * 0.5));
    seg(segs[4], Offset(s * 0.5, mid + gap),
        Offset(s * 0.5, h - gap - s * 0.5));
    seg(segs[5], Offset(s * 0.5, gap + s * 0.5), Offset(s * 0.5, mid - gap));
    seg(segs[6], Offset(gap + s * 0.5, mid), Offset(w - gap - s * 0.5, mid));
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.char != char || old.onColor != onColor;
}

class SevenSegmentDisplay extends StatelessWidget {
  final String text;
  final double digitHeight;
  final Color onColor;
  final Color offColor;
  final double spacing;

  const SevenSegmentDisplay({
    super.key,
    required this.text,
    this.digitHeight = 34,
    this.onColor = const Color(0xFF1A1A1A),
    this.offColor = const Color(0xFFD8D8D8),
    this.spacing = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: text.split('').map((ch) {
        final isDot = ch == '.';
        final w = isDot ? digitHeight * 0.22 : digitHeight * 0.60;
        return Padding(
          padding: EdgeInsets.only(right: isDot ? 1 : spacing),
          child: SizedBox(
            width: w,
            height: digitHeight,
            child: CustomPaint(
              painter: _SegmentPainter(
                char: ch,
                onColor: onColor,
                offColor: offColor,
                strokeW: digitHeight * 0.088,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

enum Screen { FASTKEY, CATEGORY, ADD, ORDERS, APPS, SHIFT, SAFE, EDIT }

class _PinBoxField extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;

  const _PinBoxField({required this.controller, required this.hasError});

  @override
  State<_PinBoxField> createState() => _PinBoxFieldState();
}

// ══════════════════════════════════════════════════════════════════════════════
// SCALE DISPLAY WIDGET — isolated so weight updates never rebuild TopBar
// ══════════════════════════════════════════════════════════════════════════════

class _ScaleDisplayWidget extends StatefulWidget {
  final VoidCallback onLongPress;
  final VoidCallback onReconnect;
  final ValueNotifier<bool> isConnectingNotifier;

  const _ScaleDisplayWidget({
    required this.onLongPress,
    required this.onReconnect,
    required this.isConnectingNotifier,
  });

  @override
  State<_ScaleDisplayWidget> createState() => _ScaleDisplayWidgetState();
}

class _ScaleDisplayWidgetState extends State<_ScaleDisplayWidget> {
  @override
  void initState() {
    super.initState();
    widget.isConnectingNotifier.addListener(_onConnectingChanged);
  }

  void _onConnectingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.isConnectingNotifier.removeListener(_onConnectingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);
    final isDark = themeHelper.themeMode == ThemeMode.dark;
    final bool isConnecting = widget.isConnectingNotifier.value;

    return Consumer<WeightProvider>(
      builder: (context, weightProvider, _) {
        final bool connected = weightProvider.isConnected;
        final parts = weightProvider.weightText.trim().split(' ');
        final numPart = parts.isNotEmpty ? parts[0] : '0.00';
        final unitPart = parts.length > 1 ? parts[1] : 'lb';

        return GestureDetector(
          onLongPress: widget.onLongPress,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (connected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEAEAEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SevenSegmentDisplay(
                    text: numPart,
                    digitHeight: 28,
                    onColor: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A),
                    offColor: isDark ? const Color(0xFF444444) : const Color(0xFFD0D0D0),
                    spacing: 3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF444444) : const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unitPart,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: isConnecting ? null : widget.onReconnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? ThemeNotifier.secondaryBackground
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isConnecting)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey.shade400,
                            ),
                          )
                        else
                          Icon(Icons.scale, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          isConnecting ? 'Connecting...' : 'Scale disconnected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PinBoxFieldState extends State<_PinBoxField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: widget.controller,
        maxLength: 6,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          letterSpacing: 14,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: isDark ? const Color(0xFF40424F) : const Color(0xFFF2F4F8),
          suffixIcon: IconButton(
            splashRadius: 13,
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: widget.hasError ? Colors.red : Colors.transparent,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: widget.hasError ? Colors.red : Colors.redAccent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatefulWidget {
  final Function() onModeChanged;
  final Function(ProductResponse)? onProductSelected;
  final Screen screen;

  const TopBar({
    required this.screen,
    required this.onModeChanged,
    this.onProductSelected,
    super.key,
  });

  // ── Static helpers ──────────────────────────────────────────────────────────

  static void clearUserCache() {
    _TopBarState.clearUserDataCache();
  }

  static final ValueNotifier<int> mergedProductCacheRevision =
  ValueNotifier<int>(0);

  static Completer<void>? _firstMergedReloadCompleter;
  static bool _mergedReloadCompletedOnce = false;


  // Inside class TopBar { ... }  (not _TopBarState)

  /// Public helper to get product ID from any cached product map
  /// Used by FastKeyDBHelper after product sync
  static int? productIdFromCacheMap(dynamic product) {
    if (product is! Map) return null;
    final dynamic raw = product["fast_key_product_id"] ??
        product["product_id"] ??
        product["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  static Future<void> waitForFirstMergedProductCacheReload() async {
    if (_mergedReloadCompletedOnce) return;
    _firstMergedReloadCompleter ??= Completer<void>();
    return _firstMergedReloadCompleter!.future;
  }

  static void resetMergedProductCacheSignals() {
    _mergedReloadCompletedOnce = false;
    _firstMergedReloadCompleter = null;
  }

  static void _onTopBarMergedReloadCycleFinished() {
    _mergedReloadCompletedOnce = true;
    _firstMergedReloadCompleter ??= Completer<void>();
    if (!_firstMergedReloadCompleter!.isCompleted) {
      _firstMergedReloadCompleter!.complete();
    }
    mergedProductCacheRevision.value++;
  }

  static void notifyMergedProductCacheMayHaveChanged() {
    mergedProductCacheRevision.value++;
  }

  static Future<List<dynamic>> mergedCachedProductsForSearch() async {
    final unique = await _TopBarState._uniqueProductsFromAllCaches();
    return unique.values.toList();
  }

  static VoidCallback? onRefreshCompleted;
  static final ValueNotifier<int> modeChangedNotifier = ValueNotifier<int>(0);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  final _searchFieldKey = GlobalKey();

  final orderHelper = OrderHelper();
  late OrderBloc _orderBloc;

  bool isAddingItemLoading = false;
  int? userId;
  String? userRole;
  String? userDisplayName;
  bool isLoading = false;
  double _lastBottomInset = 0;
  bool _isSearchEnabled = true;

  void _clearSearchUiState() {
    _searchController.clear();
    _removeOverlay();
  }

  var _printerSettings = PrinterSettings();

  List<dynamic> _cachedProducts = [];
  bool _cacheLoaded = false;
  final ProductBloc productBloc = ProductBloc(ProductRepository());

  bool _dialogOpen = false;

  static final Map<String, List<Map<String, dynamic>>> _apiSearchCache = {};
  bool _isApiSearchLoading = false;

  StreamSubscription<dynamic>? _scaleSubscription;
  bool _isConnecting = false;
  String _scaleStatus = 'Disconnected';

  WeightProvider? _weightProvider;

  // ── Cached order ID — avoids hitting DB on every product tap ───────────────
  int? _cachedEnsuredOrderId;

  // ── Cached user data (static so it survives hot-reloads) ───────────────────
  static Map<String, dynamic>? _cachedUserData;
  static bool _isUserDataLoaded = false;
  static Future<Map<String, dynamic>?>? _initialUserFuture;
  static bool isNavigationInProgress = false;

  // ── ValueNotifier for connecting state — avoids TopBar setState on scale ───
  final ValueNotifier<bool> _isConnectingNotifier = ValueNotifier<bool>(false);

  static void clearUserDataCache() {
    _cachedUserData = null;
    _isUserDataLoaded = false;
    _initialUserFuture = null;
    TopBar.resetMergedProductCacheSignals();
    if (kDebugMode) print("🧹 TopBar user data cache cleared");
  }

  static void clearUserCache() {
    _cachedUserData = null;
    _isUserDataLoaded = false;
    _initialUserFuture = null;
    if (kDebugMode) print("🧹 TopBar user data cache cleared");
  }

  // ── LIFECYCLE ───────────────────────────────────────────────────────────────


   // Add this method to _TopBarState
  Future<void> _syncFastKeysFromApi() async {
    try {
      if (kDebugMode) print("🔄 Syncing FastKeys from API...");

      final db = await DBHelper.instance.database;
      final result = await db.query(
        AppDBConst.userTable,
        where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );

      if (result.isEmpty) {
        if (kDebugMode) print('⚠️ No user found for FastKey sync');
        return;
      }

      final token = result.first[AppDBConst.userToken] as String;
      final userId = result.first[AppDBConst.userId] as int;

      // Sync FastKeys from API
      final fastKeyDBHelper = FastKeyDBHelper();
      await fastKeyDBHelper.syncFastKeysFromApi(token, userId);

      // Clear FastKeyScreen cache
      // FastKeyScreen.clearFastKeyCache();

      if (kDebugMode) print("✅ FastKey sync completed");

    } catch (e) {
      if (kDebugMode) print('❌ FastKey sync error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orderBloc = OrderBloc(OrderRepository());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _isSearchEnabled =
        widget.screen != Screen.ORDERS && widget.screen != Screen.APPS;

    _loadCachedProducts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _weightProvider = Provider.of<WeightProvider>(context, listen: false);
      _listenToScale();
    });



    if (!_isUserDataLoaded) {
      _initialUserFuture = UserDbHelper().getUserData();
      _initialUserFuture!.then((userData) {
        _cachedUserData = userData;
        _isUserDataLoaded = true;
        if (userData != null) {
          userId = userData[AppDBConst.userId] as int?;
          userDisplayName = userData[AppDBConst.userDisplayName] as String?;
          userRole = userData[AppDBConst.userRole] as String?;
        }
        if (mounted) setState(() {});
      });
    } else {
      if (_cachedUserData != null) {
        userId = _cachedUserData![AppDBConst.userId] as int?;
        userDisplayName =
        _cachedUserData![AppDBConst.userDisplayName] as String?;
        userRole = _cachedUserData![AppDBConst.userRole] as String?;
      }
    }

  }

  void setModeChangePending(bool value) {}

  void preventModeChangeDuringNavigation() {
    isNavigationInProgress = true;
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) isNavigationInProgress = false;
    });
  }

  @override
  void didUpdateWidget(covariant TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screen != widget.screen) {
      _clearSearchUiState();
    }
    _forceClearOldOrderFlicker();
  }

  void _forceClearOldOrderFlicker() {
    _dialogOpen = false;
    isAddingItemLoading = false;
    _removeOverlay();

    if (mounted) {
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _searchController.clear();
      _removeOverlay();
      if (mounted) {
        setState(() {});
      }
      if (kDebugMode) {
        print('🔄 Flicker cleared for screen: ${widget.screen}');
      }
    });
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (_lastBottomInset > 0 && bottomInset == 0) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
    _lastBottomInset = bottomInset;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _orderBloc.dispose();
    _removeOverlay();
    _stopScale();
    _apiSearchCache.clear();
    _isConnectingNotifier.dispose();
    super.dispose();
    TopBar.clearUserCache();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SCALE — weight events go directly to WeightProvider, no TopBar setState
  // ══════════════════════════════════════════════════════════════════════════════

  void _listenToScale() {
    if (_scaleSubscription != null) return;
    _scaleLog('🔌 Subscribing to native magellan_scale/events...');

    _scaleSubscription = _scaleEventChannel.receiveBroadcastStream().listen(
          (event) {
        try {
          final Map<String, dynamic> data = jsonDecode(event as String);
          final String type = data['type'] as String? ?? '';

          switch (type) {
            case 'status':
              final status = data['status'] as String? ?? '';
              final message = data['message'] as String? ?? '';
              _scaleLog('📊 Status: $status — $message');
              // Only setState for _scaleStatus (rare event), not weight
              if (mounted) {
                setState(() => _scaleStatus = message);
                _isConnectingNotifier.value = (status == 'connecting');
              }
              _weightProvider?.setConnected(status == 'connected');
              if (status == 'disconnected' || status == 'error') {
                _weightProvider?.updateWeight(0.0);
              }
              break;

            case 'weight':
              _weightProvider?.updateFromUsb(
                weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
                unit: data['unit'] as String? ?? 'lb',
                stable: data['stable'] as bool? ?? true,
              );
              if (kDebugMode) {
                _scaleLog(
                  ' ${data['weight']} ${data['unit']} stable=${data['stable']}',
                );
              }
              break;

            case 'scan':
              final raw = data['raw'] as String? ?? '';
              _scaleLog('📷 Scan → order panel: $raw');
              NativeUsbScanBridge.dispatchFromRaw(raw);
              break;

            case 'raw':
              break;

            default:
              _scaleLog('❓ Unknown event type: $type');
          }
        } catch (e) {
          _scaleLog('❌ Event parse error: $e');
        }
      },
      onError: (e) {
        _scaleLog('❌ EventChannel error: $e');
        _weightProvider?.setConnected(false);
        if (mounted) {
          setState(() => _scaleStatus = 'Channel error');
          _isConnectingNotifier.value = false;
        }
      },
      onDone: () {
        _scaleLog('⚠️ EventChannel closed.');
        _weightProvider?.setConnected(false);
        if (mounted) {
          setState(() => _scaleStatus = 'Disconnected');
          _isConnectingNotifier.value = false;
        }
      },
      cancelOnError: false,
    );
  }

  void _scaleLog(String msg) {
    if (kDebugMode) debugPrint('[Scale] $msg');
  }

  void _stopScale() {
    _scaleSubscription?.cancel();
    _scaleSubscription = null;
    try {
      _scaleMethodChannel.invokeMethod('stop');
    } catch (_) {}
    _weightProvider?.setConnected(false);
    _weightProvider?.updateWeight(0.0);
  }

  Future<void> _reconnectScale() async {
    _scaleLog('🔄 Reconnecting...');
    if (mounted) {
      setState(() => _scaleStatus = 'Reconnecting...');
      _isConnectingNotifier.value = true;
    }
    try {
      await _scaleMethodChannel.invokeMethod('reconnect');
    } catch (e) {
      _scaleLog('❌ Reconnect error: $e');
    }
    if (_scaleSubscription == null) {
      _listenToScale();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PRODUCT REFRESH
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> refreshProducts() async {
    try {
      setState(() => isLoading = true);

      final isar = await IsarService.instance;

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

      final url = Uri.parse(
        '${UrlHelper.baseUrl}'
            '${UrlHelper.componentVersionUrl}'
            'data-sync/get-data-changes?device_id=POS-003',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('API Error: ${response.statusCode} — ${response.body}');
        }
        throw Exception('API returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (kDebugMode) print('API Response: ${response.body}');

      final List<dynamic> changes = decoded['changes'] ?? [];
      if (changes.isEmpty) {
        if (kDebugMode) print('No changes from API');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Products are already up to date'),
              backgroundColor: Colors.green,
            ),
          );
        }
        TopBar.notifyMergedProductCacheMayHaveChanged();
        await _reloadAllProductsFromIsar();
        await _syncFastKeysFromApi();

        TopBar.onRefreshCompleted?.call();
        return;
      }

      int? lastEventVersion;
      for (final change in changes) {
        final dynamic rawVersion = change['event_version'];
        if (rawVersion == null) continue;
        final int? version = rawVersion is int
            ? rawVersion
            : int.tryParse(rawVersion.toString());
        if (version != null &&
            (lastEventVersion == null || version > lastEventVersion)) {
          lastEventVersion = version;
        }
      }
      if (kDebugMode) {
        print('Last event_version from changes: $lastEventVersion');
      }

      final List<Map<String, dynamic>> toUpsert = [];
      final List<int> toDelete = [];

      for (final change in changes) {
        if (change['post_type'] != 'product') continue;
        final String eventType =
        (change['event_type'] as String? ?? '').toLowerCase();

        if (eventType == 'deleted') {
          final dynamic rawId = change['data']?['id'] ?? change['post_id'];
          final int? id = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
          if (id != null) {
            toDelete.add(id);
            if (kDebugMode) print('Queued DELETE for product id=$id');
          }
        } else if (eventType == 'created' ||
            eventType == 'updated' ||
            eventType == 'restored') {
          if (change['data'] is Map) {
            toUpsert.add(Map<String, dynamic>.from(change['data'] as Map));
            if (kDebugMode) {
              print('Queued ${eventType.toUpperCase()} for product '
                  'id=${change['data']['id']} name="${change['data']['name']}"');
            }
          }
        }
      }

      if (kDebugMode) {
        print(
            'Changes → upsert: ${toUpsert.length}, delete: ${toDelete.length}');
      }

      bool isEbtEligibleFromTags(List<dynamic> tags) {
        return tags.any((t) {
          final name = (t['name'] ?? '').toString().toLowerCase();
          final slug = (t['slug'] ?? '').toString().toLowerCase();
          return name == 'ebt' ||
              name == 'ebt eligible' ||
              slug == 'ebt' ||
              slug == 'ebt-eligible';
        });
      }

      int minAgeFromTags(List<dynamic> tags) {
        for (final t in tags) {
          final name = (t['name'] ?? '').toString().toLowerCase().trim();
          if (name == TextConstants.age_restricted.toLowerCase().trim()) {
            final int parsed =
                int.tryParse((t['slug'] ?? '').toString().trim()) ?? 0;
            return parsed > 0 ? parsed : 18;
          }
        }
        return 0;
      }

      Map<String, dynamic> normaliseProduct(Map<String, dynamic> p) {
        final List<dynamic> rawTags = (p['tags'] as List?) ?? [];

        final List<Map<String, dynamic>> originalTags = rawTags
            .whereType<Map>()
            .map((t) => {
          'id': t['id'],
          'name': (t['name'] ?? '').toString(),
          'slug': (t['slug'] ?? '').toString(),
        })
            .toList();

        final List<Map<String, dynamic>> lowercasedTags = rawTags
            .whereType<Map>()
            .map((t) => {
          'id': t['id'],
          'name': (t['name'] ?? '').toString().toLowerCase(),
          'slug': (t['slug'] ?? '').toString().toLowerCase(),
        })
            .toList();

        final int minAge = minAgeFromTags(rawTags);

        if (kDebugMode && minAge > 0) {
          print('🔞 Product id=${p['id']} "${p['name']}" → '
              'age restricted, minAge=$minAge');
        }

        final List<dynamic> images = (p['images'] as List?) ?? [];
        final String imageUrl = images.isNotEmpty
            ? ((images.first is Map)
            ? (images.first['src'] ?? '').toString()
            : images.first.toString())
            : '';

        return {
          'fast_key_product_id': p['id'],
          'fast_key_item_name': p['name'] ?? '',
          'fast_key_item_image': imageUrl,
          'fast_key_item_price': p['price'] ?? p['regular_price'] ?? '0',
          'fast_key_item_sku': p['sku'] ?? '',
          'fast_key_item_tags': lowercasedTags,
          'fast_key_item_min_age': minAge,
          'has_age_restriction': minAge > 0,
          'variations': p['variations'] ?? [],
          'type': p['type'] ?? 'simple',
          'id': p['id'],
          'name': p['name'] ?? '',
          'price': p['price'] ?? p['regular_price'] ?? '0',
          'regular_price': p['regular_price'] ?? '',
          'sku': p['sku'] ?? '',
          'images': images,
          'tags': originalTags,
          'is_ebt_eligible': isEbtEligibleFromTags(rawTags),
          'tax': p['tax'],
        };
      }

      Future<IsarCacheEntry?> removeProductFromEntry(
          String key, int productId) async {
        final IsarCacheEntry? entry = await isar.isarCacheEntrys
            .where()
            .filter()
            .keyEqualTo(key)
            .findFirst();
        if (entry == null) return null;

        List<Map<String, dynamic>> list = [];
        try {
          list = (jsonDecode(entry.json) as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } catch (_) {
          return null;
        }

        final int before = list.length;
        list.removeWhere(
              (p) =>
          (p['fast_key_product_id'] ?? p['product_id'] ?? p['id'])
              ?.toString() ==
              productId.toString(),
        );
        if (list.length == before) return null;

        return entry
          ..json = jsonEncode(list)
          ..timestamp = DateTime.now();
      }

      final Set<int> affectedCategoryIds = {};
      for (final productData in toUpsert) {
        final List<dynamic> apiCategories =
            (productData['categories'] as List?) ?? [];
        for (final cat in apiCategories) {
          final int? catId = cat['id'] is int
              ? cat['id'] as int
              : int.tryParse(cat['id']?.toString() ?? '');
          if (catId != null) affectedCategoryIds.add(catId);
        }
      }

      await isar.writeTxn(() async {
        for (final productId in toDelete) {
          if (kDebugMode) print('Processing DELETE for product $productId…');

          final List<IsarCacheEntry> productEntries = await isar.isarCacheEntrys
              .where()
              .filter()
              .keyStartsWith('products_')
              .findAll();

          for (final entry in productEntries) {
            final IsarCacheEntry? updated =
            await removeProductFromEntry(entry.key, productId);
            if (updated != null) {
              await isar.isarCacheEntrys.put(updated);
              if (kDebugMode) print('Removed $productId from ${entry.key}');
            }
          }

          final List<IsarCacheEntry> indigoEntries = await isar.isarCacheEntrys
              .where()
              .filter()
              .keyStartsWith('indigo_products_')
              .findAll();

          for (final entry in indigoEntries) {
            final IsarCacheEntry? updated =
            await removeProductFromEntry(entry.key, productId);
            if (updated != null) {
              await isar.isarCacheEntrys.put(updated);
              if (kDebugMode)
                print('  ✂️  Removed $productId from ${entry.key}');
            }
          }

          await isar.isarCacheEntrys
              .filter()
              .keyEqualTo('sku_$productId')
              .deleteAll();

          await isar.isarCacheEntrys
              .filter()
              .keyEqualTo('product_${productId}_variations')
              .deleteAll();

          if (kDebugMode)
            print('  ✅ Product $productId fully deleted from Isar');
        }

        for (final catId in affectedCategoryIds) {
          final String indigoKey = 'indigo_products_$catId';
          final deleted = await isar.isarCacheEntrys
              .filter()
              .keyEqualTo(indigoKey)
              .deleteAll();
          if (kDebugMode) {
            print(
                '🗑️ Pre-deleted $indigoKey (count: $deleted) before upsert so next load fetches full list from API');
          }
        }

        final Map<int, List<Map<String, dynamic>>> categoryProductMap = {};

        for (final productData in toUpsert) {
          final List<dynamic> apiCategories =
              (productData['categories'] as List?) ?? [];

          if (apiCategories.isEmpty) {
            final int? id = productData['id'] is int
                ? productData['id'] as int
                : int.tryParse(productData['id']?.toString() ?? '');
            if (id != null) {
              await isar.isarCacheEntrys
                  .filter()
                  .keyEqualTo('sku_$id')
                  .deleteAll();
            }
            if (kDebugMode) {
              print('⚠️ Product id=${productData['id']} has no categories — '
                  'skipping category cache update');
            }
            continue;
          }

          final Map<String, dynamic> normalised = normaliseProduct(productData);

          for (final cat in apiCategories) {
            final int? catId = cat['id'] is int
                ? cat['id'] as int
                : int.tryParse(cat['id']?.toString() ?? '');
            if (catId == null) continue;
            categoryProductMap.putIfAbsent(catId, () => []).add(normalised);
          }
        }

        for (final mapEntry in categoryProductMap.entries) {
          final int catId = mapEntry.key;
          final List<Map<String, dynamic>> updatedProducts = mapEntry.value;

          final String categoryKey = 'products_$catId';
          final IsarCacheEntry? existing = await isar.isarCacheEntrys
              .where()
              .filter()
              .keyEqualTo(categoryKey)
              .findFirst();

          List<Map<String, dynamic>> cachedList = [];
          if (existing != null) {
            try {
              cachedList = (jsonDecode(existing.json) as List)
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
            } catch (_) {}
          }

          for (final updated in updatedProducts) {
            final int productId = updated['fast_key_product_id'] as int? ?? 0;
            final int idx = cachedList.indexWhere(
                  (p) =>
              (p['fast_key_product_id'] ?? p['id'])?.toString() ==
                  productId.toString(),
            );
            if (idx >= 0) {
              cachedList[idx] = {...cachedList[idx], ...updated};
              if (kDebugMode) {
                print('♻️  Upserted $productId → $categoryKey');
              }
            } else {
              cachedList.add(updated);
              if (kDebugMode) {
                print('➕ Inserted $productId → $categoryKey');
              }
            }
          }

          await isar.isarCacheEntrys.put(
            (existing ?? IsarCacheEntry())
              ..key = categoryKey
              ..json = jsonEncode(cachedList)
              ..timestamp = DateTime.now(),
          );

          for (final updated in updatedProducts) {
            final int productId = updated['fast_key_product_id'] as int? ?? 0;
            if (productId != 0) {
              await isar.isarCacheEntrys
                  .filter()
                  .keyEqualTo('sku_$productId')
                  .deleteAll();
            }
          }
        }
      });

      if (kDebugMode) {
        print('Isar sync complete — '
            'upserted: ${toUpsert.length}, deleted: ${toDelete.length}');
      }

      if (lastEventVersion != null) {
        try {
          final updateUrl = Uri.parse(
            '${UrlHelper.baseUrl}'
                '${UrlHelper.componentVersionUrl}'
                'data-sync/update-data-count',
          );

          final updateResponse = await http.post(
            updateUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'device_id': 'POS-003',
              'last_sync_version': lastEventVersion,
            }),
          );

          if (kDebugMode) {
            if (updateResponse.statusCode == 200) {
              print('✅ Sync version acknowledged: '
                  'last_sync_version=$lastEventVersion — '
                  '${updateResponse.body}');
            } else {
              print('⚠️ update-data-count failed: '
                  '${updateResponse.statusCode} — ${updateResponse.body}');
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ update-data-count error (non-fatal): $e');
        }
      }

      // Also clear cached order ID so next tap re-validates
      _cachedEnsuredOrderId = null;

      TopBar.notifyMergedProductCacheMayHaveChanged();
      await _reloadAllProductsFromIsar();
      TopBar.onRefreshCompleted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Products refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      if (kDebugMode) print('❌ refreshProducts error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ══════════════════════════════════════════════════════════════════════════════

  _loadCachedProducts() async {
    try {
      await _reloadAllProductsFromIsar();
    } catch (e) {
      if (kDebugMode) print("_loadCachedProducts error: $e");
      if (mounted) setState(() => _cacheLoaded = true);
      TopBar._onTopBarMergedReloadCycleFinished();
    }
  }

  static int? _productIdFromCacheMap(dynamic product) {
    if (product is! Map) return null;
    final dynamic raw = product["fast_key_product_id"] ??
        product["product_id"] ??
        product["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "");
  }

  static Future<Map<int, dynamic>> _uniqueProductsFromAllCaches() async {
    final isar = await IsarService.instance;
    final Map<int, dynamic> uniqueProducts = {};

    Iterable<dynamic> _expandCandidates(dynamic product) sync* {
      if (product == null) return;
      if (product is List) {
        for (final item in product) {
          yield* _expandCandidates(item);
        }
        return;
      }
      if (product is Map) {
        final map = Map<String, dynamic>.from(product);
        if (map["products"] is List) {
          for (final nested in (map["products"] as List)) {
            yield* _expandCandidates(nested);
          }
        } else if (map["product"] is Map || map["product"] is List) {
          yield* _expandCandidates(map["product"]);
        } else {
          yield map;
        }
      }
    }

    void mergeProductList(List<dynamic> products) {
      for (final product in products) {
        try {
          for (final candidate in _expandCandidates(product)) {
            final int? productId = _productIdFromCacheMap(candidate);
            if (productId == null) continue;
            uniqueProducts[productId] = candidate;
          }
        } catch (_) {}
      }
    }

    final indigoEntries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith("indigo_products_")
        .findAll();
    for (final entry in indigoEntries) {
      try {
        mergeProductList(json.decode(entry.json) as List<dynamic>);
      } catch (_) {}
    }

    try {
      final allList =
      await StorageProvider.productCache.get("all_products_list");
      if (allList is List) {
        for (final item in allList) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          if (m["products"] is List && (m["products"] as List).isNotEmpty) {
            final first = (m["products"] as List).first;
            if (first is Map) mergeProductList([first]);
          } else {
            mergeProductList([m]);
          }
        }
      }
    } catch (_) {}

    final cachedEntries = await isar.isarCacheEntrys
        .where()
        .filter()
        .keyStartsWith("products_")
        .findAll();
    for (final entry in cachedEntries) {
      try {
        mergeProductList(json.decode(entry.json) as List<dynamic>);
      } catch (_) {}
    }

    return uniqueProducts;
  }

  Future<void> _reloadAllProductsFromIsar() async {
    try {
      final uniqueProducts = await _uniqueProductsFromAllCaches();
      if (mounted) {
        setState(() {
          _cachedProducts = uniqueProducts.values.toList();
          _cacheLoaded = true;
        });
        if (kDebugMode) {
          print(
              "✅ _cachedProducts refreshed: ${_cachedProducts.length} total products");
        }
      }
      TopBar._onTopBarMergedReloadCycleFinished();
    } catch (e) {
      if (kDebugMode) print("❌ _reloadAllProductsFromIsar error: $e");
      TopBar._onTopBarMergedReloadCycleFinished();
    }
  }

  String _getProductImage(dynamic product) {
    try {
      if (product.images != null && product.images!.isNotEmpty) {
        final img = product.images!.first;
        if (img is String && img.isNotEmpty) return img;
        if (img is Map && img["src"] != null) return img["src"].toString();
      }
    } catch (_) {}
    return "";
  }

  getAllCachedProducts() async {
    final uniqueProducts = await _uniqueProductsFromAllCaches();
    return uniqueProducts.values.toList();
  }

  void _onFocusChanged() {
    final q = _searchController.text.trim();
    if (_searchFocusNode.hasFocus && q.length >= 3 && _overlayEntry == null) {
      _showSearchResultsOverlay();
    } else if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      _removeOverlay();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty || query.length < 3) {
      _removeOverlay();
      setState(() {});
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final q = _searchController.text.toLowerCase().trim();
      if (q.isEmpty || q.length < 3) {
        _removeOverlay();
        if (mounted) setState(() {});
        return;
      }

      if (_overlayEntry == null) {
        _showSearchResultsOverlay();
      } else {
        _overlayEntry?.markNeedsBuild();
      }
      if (mounted) setState(() {});

      await _searchProductsFromApi(q);

      if (!mounted) return;
      _overlayEntry?.markNeedsBuild();
      setState(() {});
    });
  }

  // Future<void> _searchProductsFromApi(String query) async {
  //   if (_apiSearchCache.containsKey(query)) {
  //     if (kDebugMode) print('⚡ API search cache hit for "$query"');
  //     _mergeApiResults(_apiSearchCache[query]!);
  //     return;
  //   }
  //
  //   if (mounted) setState(() => _isApiSearchLoading = true);
  //
  //   try {
  //     final token = await _getAuthTokenFromDb();
  //     final encodedQuery = Uri.encodeQueryComponent(query);
  //     final url = Uri.parse(
  //       '${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}'
  //           'products?search=$encodedQuery&page=1&per_page=20',
  //     );
  //
  //     if (kDebugMode) print('🔍 API Search → $url');
  //
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //     );
  //
  //     if (response.statusCode != 200) {
  //       if (kDebugMode) {
  //         print('⚠️ API search ${response.statusCode}: ${response.body}');
  //       }
  //       return;
  //     }
  //
  //     final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
  //
  //     final List<Map<String, dynamic>> apiProducts = decoded
  //         .whereType<Map>()
  //         .map<Map<String, dynamic>>((p) {
  //       final List<dynamic> images = (p['images'] as List?) ?? [];
  //       final String imageUrl = images.isNotEmpty && images.first is Map
  //           ? (images.first['src'] ?? '').toString()
  //           : '';
  //
  //       final List<dynamic> rawTags = (p['tags'] as List?) ?? [];
  //       final List<Map<String, dynamic>> tags = rawTags
  //           .whereType<Map>()
  //           .map((t) => {
  //         'id': t['id'],
  //         'name': (t['name'] ?? '').toString(),
  //         'slug': (t['slug'] ?? '').toString(),
  //       })
  //           .toList();
  //
  //       final List<dynamic> rawCategories = (p['categories'] as List?) ?? [];
  //
  //       // ✅ Extract meta_data properly
  //       final List<Map<String, dynamic>> metaData = (p['meta_data'] as List?)
  //           ?.whereType<Map>()
  //           .map((m) => {
  //         'id': m['id'],
  //         'key': m['key']?.toString() ?? '',
  //         'value': m['value'],
  //       })
  //           .toList() ?? [];
  //
  //       // ✅ Extract loyalty points for logging
  //       int loyaltyPoints = 0;
  //       if (metaData.isNotEmpty) {
  //         final loyaltyEntry = metaData.firstWhere(
  //               (m) => m['key'] == '_product_loyalty_points' || m['key'] == '_csv_loyalty_points',
  //           orElse: () => {},
  //         );
  //         if (loyaltyEntry.isNotEmpty) {
  //           loyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
  //         }
  //       }
  //
  //       // ✅ Print loyalty points for this product
  //       if (kDebugMode && loyaltyPoints > 0) {
  //         print('⭐ Product "${p['name']}" (ID: ${p['id']}) has $loyaltyPoints loyalty points');
  //       }
  //
  //       return {
  //         'fast_key_product_id': p['id'],
  //         'fast_key_item_name': p['name'] ?? '',
  //         'fast_key_item_image': imageUrl,
  //         'fast_key_item_price': p['price'] ?? p['regular_price'] ?? '0',
  //         'fast_key_item_sku': p['sku'] ?? '',
  //         'fast_key_item_tags': tags,
  //         'id': p['id'],
  //         'name': p['name'] ?? '',
  //         'price': p['price'] ?? p['regular_price'] ?? '0',
  //         'regular_price': p['regular_price'] ?? '',
  //         'sku': p['sku'] ?? '',
  //         'images': images,
  //         'tags': tags,
  //         'variations': p['variations'] ?? [],
  //         'type': p['type'] ?? 'simple',
  //         'categories': rawCategories,
  //         'meta_data': metaData, // ✅ Include meta_data
  //         'loyalty_points': loyaltyPoints, // ✅ Store for quick access
  //         'is_ebt_eligible': tags.any((t) {
  //           final name = (t['name'] ?? '').toString().toLowerCase();
  //           final slug = (t['slug'] ?? '').toString().toLowerCase();
  //           return name == 'ebt' ||
  //               name == 'ebt eligible' ||
  //               slug == 'ebt' ||
  //               slug == 'ebt-eligible';
  //         }),
  //       };
  //     }).toList();
  //
  //     _apiSearchCache[query] = apiProducts;
  //
  //     // ✅ Log summary of loyalty points found
  //     if (kDebugMode) {
  //       final productsWithPoints = apiProducts.where((p) => (p['loyalty_points'] ?? 0) > 0);
  //       print('✅ API returned ${apiProducts.length} products for "$query"');
  //       print('⭐ ${productsWithPoints.length} products have loyalty points');
  //       if (productsWithPoints.isNotEmpty) {
  //         print('📊 Loyalty points details:');
  //         for (final p in productsWithPoints) {
  //           print('   • ${p['name']}: ${p['loyalty_points']} points');
  //         }
  //       }
  //     }
  //
  //     _mergeApiResults(apiProducts);
  //   } catch (e) {
  //     if (kDebugMode) print('❌ _searchProductsFromApi error: $e');
  //   } finally {
  //     if (mounted) setState(() => _isApiSearchLoading = false);
  //   }
  // }


  Future<void> _searchProductsFromApi(String query) async {
    final searchQuery = query.trim();

    if (_apiSearchCache.containsKey(searchQuery)) {
      if (kDebugMode) {
        print('⚡ API search cache hit for "$searchQuery"');
      }
      _mergeApiResults(_apiSearchCache[searchQuery]!);
      return;
    }

    if (mounted) {
      setState(() => _isApiSearchLoading = true);
    }

    try {
      final token = await _getAuthTokenFromDb();

      final encodedQuery = Uri.encodeQueryComponent(searchQuery);

      late final Uri url;

      // If query is only numbers -> SKU search
      if (RegExp(r'^\d+$').hasMatch(searchQuery)) {
        url = Uri.parse(
          '${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}'
              'products?sku=$encodedQuery&page=1&per_page=20',
        );

        if (kDebugMode) {
          print('🔢 SKU Search → $url');
        }
      } else {
        // Normal product name search
        url = Uri.parse(
          '${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}'
              'products?search=$encodedQuery&page=1&per_page=20',
        );

        if (kDebugMode) {
          print('🔍 Product Search → $url');
        }
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('⚠️ API search ${response.statusCode}: ${response.body}');
        }
        return;
      }

      final List<dynamic> decoded =
      jsonDecode(response.body) as List<dynamic>;

      final List<Map<String, dynamic>> apiProducts = decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>((p) {

        final List<dynamic> images =
            (p['images'] as List?) ?? [];

        final String imageUrl =
        images.isNotEmpty && images.first is Map
            ? (images.first['src'] ?? '').toString()
            : '';

        final List<dynamic> rawTags =
            (p['tags'] as List?) ?? [];

        final List<Map<String, dynamic>> tags =
        rawTags.whereType<Map>().map((t) {
          return {
            'id': t['id'],
            'name': (t['name'] ?? '').toString(),
            'slug': (t['slug'] ?? '').toString(),
          };
        }).toList();


        final List<dynamic> rawCategories =
            (p['categories'] as List?) ?? [];


        // Extract meta_data
        final List<Map<String, dynamic>> metaData =
            (p['meta_data'] as List?)
                ?.whereType<Map>()
                .map((m) {
              return {
                'id': m['id'],
                'key': m['key']?.toString() ?? '',
                'value': m['value'],
              };
            }).toList() ??
                [];


        // Extract loyalty points
        int loyaltyPoints = 0;

        final loyaltyEntry = metaData.firstWhere(
              (m) =>
          m['key'] == '_product_loyalty_points' ||
              m['key'] == '_csv_loyalty_points',
          orElse: () => {},
        );

        if (loyaltyEntry.isNotEmpty) {
          loyaltyPoints =
              int.tryParse(
                loyaltyEntry['value']?.toString() ?? '0',
              ) ??
                  0;
        }


        if (kDebugMode && loyaltyPoints > 0) {
          print(
            '⭐ Product "${p['name']}" '
                '(ID: ${p['id']}) has $loyaltyPoints loyalty points',
          );
        }


        return {
          'fast_key_product_id': p['id'],
          'fast_key_item_name': p['name'] ?? '',
          'fast_key_item_image': imageUrl,
          'fast_key_item_price':
          p['price'] ?? p['regular_price'] ?? '0',
          'fast_key_item_sku': p['sku'] ?? '',
          'fast_key_item_tags': tags,

          'id': p['id'],
          'name': p['name'] ?? '',
          'price':
          p['price'] ?? p['regular_price'] ?? '0',
          'regular_price': p['regular_price'] ?? '',
          'sku': p['sku'] ?? '',
          'images': images,
          'tags': tags,
          'variations': p['variations'] ?? [],
          'type': p['type'] ?? 'simple',
          'categories': rawCategories,

          'meta_data': metaData,
          'loyalty_points': loyaltyPoints,

          'is_ebt_eligible': tags.any((t) {
            final name =
            (t['name'] ?? '').toString().toLowerCase();

            final slug =
            (t['slug'] ?? '').toString().toLowerCase();

            return name == 'ebt' ||
                name == 'ebt eligible' ||
                slug == 'ebt' ||
                slug == 'ebt-eligible';
          }),
        };
      }).toList();


      _apiSearchCache[searchQuery] = apiProducts;


      if (kDebugMode) {
        final productsWithPoints = apiProducts.where(
              (p) => (p['loyalty_points'] ?? 0) > 0,
        );

        print(
          ' API returned ${apiProducts.length} products '
              'for "$searchQuery"',
        );

        print(
          '⭐ ${productsWithPoints.length} products have loyalty points',
        );

        if (productsWithPoints.isNotEmpty) {
          print(' Loyalty points details:');

          for (final p in productsWithPoints) {
            print(
              '   • ${p['name']}: ${p['loyalty_points']} points',
            );
          }
        }
      }


      _mergeApiResults(apiProducts);

    } catch (e) {
      if (kDebugMode) {
        print('_searchProductsFromApi error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isApiSearchLoading = false);
      }
    }
  }

  void _mergeApiResults(List<Map<String, dynamic>> apiProducts) {
    if (apiProducts.isEmpty) return;

    final Map<int, dynamic> existing = {};
    for (final p in _cachedProducts) {
      final int? pid = _productIdFromCacheMap(p);
      if (pid != null) existing[pid] = p;
    }

    bool changed = false;
    for (final ap in apiProducts) {
      final int? pid = _productIdFromCacheMap(ap);
      if (pid == null) continue;

      if (!existing.containsKey(pid)) {
        existing[pid] = ap;
        changed = true;
      } else {
        // ✅ FIX: product already cached (e.g. from Isar, which never
        // stores meta_data — see normaliseProduct()). Don't drop the
        // API result's meta_data/loyalty_points on the floor.
        final current = existing[pid];
        if (current is Map) {
          final bool currentHasMeta = current['meta_data'] is List &&
              (current['meta_data'] as List).isNotEmpty;
          final bool apiHasMeta = ap['meta_data'] is List &&
              (ap['meta_data'] as List).isNotEmpty;
          if (!currentHasMeta && apiHasMeta) {
            final merged = Map<String, dynamic>.from(current);
            merged['meta_data'] = ap['meta_data'];
            merged['loyalty_points'] = ap['loyalty_points'];
            existing[pid] = merged;
            changed = true;
          }
        }
      }
    }

    if (changed && mounted) {
      setState(() {
        _cachedProducts = existing.values.toList();
      });
    }
  }


  void _clearSearch() {
    _searchController.clear();
    _removeOverlay();
    _searchFocusNode.unfocus();
    // Reset cached order ID so next search tap re-validates
    _cachedEnsuredOrderId = null;
    setState(() {});
  }

  void _showSearchResultsOverlay() {
    if (_overlayEntry != null || _dialogOpen) return;
    final box =
    _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Provider.of<ThemeNotifier>(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _removeOverlay();
                  _searchFocusNode.unfocus();
                },
              ),
            ),
            Positioned(
              width: size.width,
              left: offset.dx,
              top: offset.dy + size.height,
              child: Material(
                elevation: 6,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: BoxDecoration(
                    color: theme.themeMode == ThemeMode.dark
                        ? ThemeNotifier.secondaryBackground
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildLocalResultsList(),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildLocalResultsList() {
    final query = _searchController.text.toLowerCase().trim();
    if (!_cacheLoaded) return const Center(child: CircularProgressIndicator());
    if (_cachedProducts.isEmpty)
      return const Center(child: Text("No products in cache"));
    if (query.isNotEmpty && query.length < 3) {
      return Center(child: Text(TextConstants.searchMinCharactersHint));
    }

    int? _resolveProductId(dynamic p) {
      final dynamic raw =
          p["fast_key_product_id"] ?? p["product_id"] ?? p["id"];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? "");
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

    String _resolveSku(dynamic p) {
      return (p["sku"] ?? p["fast_key_item_sku"] ?? "").toString();
    }

    List<int> _resolveVariationIds(dynamic p) {
      final raw = p["variations"];
      if (raw is! List || raw.isEmpty) return <int>[];
      return raw
          .map((v) => v is int ? v : int.tryParse(v?.toString() ?? ""))
          .whereType<int>()
          .toList();
    }

    String _normalize(String input) {
      return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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

    final Map<int, dynamic> uniqueById = {};
    for (final p in _cachedProducts) {
      final int? pid = _resolveProductId(p);
      if (pid == null) continue;
      if (_matchesCachedProduct(query, p)) {
        uniqueById[pid] = p;
      }
    }

    final list = uniqueById.values.toList()
      ..sort((a, b) {
        final na = _resolveName(a).toLowerCase();
        final nb = _resolveName(b).toLowerCase();
        final sa = na.startsWith(query);
        final sb = nb.startsWith(query);
        if (sa && !sb) return -1;
        if (!sa && sb) return 1;
        return na.compareTo(nb);
      });

    if (list.isEmpty && _isApiSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) return const Center(child: Text("No products found"));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isApiSearchLoading) const LinearProgressIndicator(minHeight: 2),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              final name = _resolveName(p);
              final price = _resolvePrice(p);
              final sku = _resolveSku(p);

              String? imageUrl;
              final imagesRaw = p["images"];
              if (imagesRaw != null) {
                if (imagesRaw is String && imagesRaw.isNotEmpty) {
                  imageUrl = imagesRaw;
                } else if (imagesRaw is List && imagesRaw.isNotEmpty) {
                  final first = imagesRaw.first;
                  if (first is String && first.isNotEmpty) {
                    imageUrl = first;
                  } else if (first is Map && first["src"] != null) {
                    imageUrl = first["src"].toString();
                  }
                }
              }
              imageUrl ??= p["fast_key_item_image"]?.toString();
              if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;

              return ListTile(
                leading: SizedBox(
                  width: 50,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) =>
                      progress == null
                          ? child
                          : const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2)),
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 40),
                    )
                        : const Icon(Icons.image, size: 40),
                  ),
                ),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Row(
                  children: [
                    Text(
                      "\$$price",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    Builder(builder: (_) {
                      final rawTags = p["tags"] ?? p["fast_key_item_tags"];
                      final bool isEbt = rawTags is List &&
                          rawTags.any((t) {
                            final name =
                            (t["name"] ?? "").toString().toLowerCase();
                            final slug =
                            (t["slug"] ?? "").toString().toLowerCase();
                            return name.contains("ebt") ||
                                slug.contains("ebt");
                          });
                      if (!isEbt) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EBT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    Builder(builder: (_) {
                      final rawVariations = p["variations"];
                      final bool hasVariants = (rawVariations is List &&
                          rawVariations.isNotEmpty) ||
                          (p["type"]?.toString().toLowerCase() == "variable");
                      if (!hasVariants) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            SvgPicture.asset(
                              "assets/svg/variation.svg",
                              height: 10,
                              width: 10,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                onTap: () async {
                  final int productId = _resolveProductId(p) ?? 0;
                  ProductResponse fullProduct = ProductResponse(
                    id: productId,
                    name: name,
                    price: price,
                    sku: sku.isNotEmpty ? sku : null,
                    images: imageUrl != null ? [imageUrl!] : [],
                    variations: _resolveVariationIds(p),
                  );

                  try {
                    final rawTags = p["tags"];
                    if (rawTags is List && rawTags.isNotEmpty) {
                      fullProduct.tags = rawTags.map((t) {
                        if (t is Map) {
                          return SKU.Tags(
                            id: t["id"],
                            name: t["name"]?.toString(),
                            slug: t["slug"]?.toString(),
                          );
                        }
                        return SKU.Tags();
                      }).toList();
                    } else {
                      final isar = await IsarService.instance;
                      final entries = await isar.isarCacheEntrys
                          .where()
                          .filter()
                          .keyStartsWith("products_")
                          .findAll();

                      for (final entry in entries) {
                        final List<dynamic> cached = jsonDecode(entry.json);
                        final match = cached.firstWhere(
                              (item) =>
                          ((item["fast_key_product_id"] ??
                              item["product_id"] ??
                              item["id"])
                              ?.toString() ==
                              productId.toString()),
                          orElse: () => null,
                        );
                        if (match != null) {
                          final fallbackTags = match["tags"];
                          if (fallbackTags is List &&
                              fallbackTags.isNotEmpty) {
                            fullProduct.tags = fallbackTags.map((t) {
                              if (t is Map) {
                                return SKU.Tags(
                                  id: t["id"],
                                  name: t["name"]?.toString(),
                                  slug: t["slug"]?.toString(),
                                );
                              }
                              return SKU.Tags();
                            }).toList();
                          }
                          break;
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint(
                        "❌ Tag enrichment failed for product $productId: $e");
                  }

                  _handleProductTap(fullProduct);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // VARIANT HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _getVariantsFromCache(
      int productId) async {
    try {
      final productBox = StorageProvider.productCache;

      // List<Map<String, dynamic>> _normalizeVariants(dynamic raw) {
      //   if (raw is! List || raw.isEmpty) return <Map<String, dynamic>>[];
      //   return raw
      //       .whereType<Map>()
      //       .map<Map<String, dynamic>>((v) {
      //     final map =
      //     v.map((key, value) => MapEntry(key.toString(), value));
      //     final attrs = map["attributes"];
      //     final String fallbackName = attrs is List
      //         ? attrs
      //         .whereType<Map>()
      //         .map((a) => (a["option"] ?? "").toString())
      //         .where((x) => x.isNotEmpty)
      //         .join(" - ")
      //         : "";
      //     return {
      //       "id": map["id"],
      //       "name": (map["name"] ?? "").toString().isNotEmpty
      //           ? map["name"]
      //           : (fallbackName.isNotEmpty ? fallbackName : "Variant"),
      //       "price": map["regular_price"] ?? map["price"] ?? "0",
      //       "image":
      //       (map["image"] is Map && map["image"]["src"] != null)
      //           ? map["image"]["src"]
      //           : (map["image"] is String ? map["image"] : ""),
      //       "sku": map["sku"] ?? "",
      //     };
      //   })
      //       .where((v) => v["id"] != null)
      //       .toList();
      // }

      List<Map<String, dynamic>> _normalizeVariants(dynamic raw) {
        if (raw is! List || raw.isEmpty) return <Map<String, dynamic>>[];
        return raw
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

          // ✅ NEW: preserve meta_data
          final List<Map<String, dynamic>> metaData = (map["meta_data"] is List)
              ? (map["meta_data"] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
              : <Map<String, dynamic>>[];

          return {
            "id": map["id"],
            "name": (map["name"] ?? "").toString().isNotEmpty
                ? map["name"]
                : (fallbackName.isNotEmpty ? fallbackName : "Variant"),
            "price": map["regular_price"] ?? map["price"] ?? "0",
            "image": (map["image"] is Map && map["image"]["src"] != null)
                ? map["image"]["src"]
                : (map["image"] is String ? map["image"] : ""),
            "sku": map["sku"] ?? "",
            "meta_data": metaData, // ✅ NEW
          };
        })
            .where((v) => v["id"] != null)
            .toList();
      }

      final isar = await IsarService.instance;
      final entries = await isar.isarCacheEntrys
          .where()
          .filter()
          .keyStartsWith("products_")
          .findAll();

    //   for (final entry in entries) {
    //     final List<dynamic> products = jsonDecode(entry.json);
    //     final match = products.firstWhere(
    //           (p) =>
    //       p["fast_key_product_id"]?.toString() == productId.toString(),
    //       orElse: () => null,
    //     );
    //     if (match == null) continue;
    //
    //     final rawVariations = match["variations"] ??
    //         (await productBox
    //             .get("product_${productId}_variations"))?["variations"];
    //     final variants = _normalizeVariants(rawVariations);
    //     if (variants.isNotEmpty) return variants;
    //   }
    //
    //   final cached =
    //   await productBox.get("product_${productId}_variations");
    //   final fallbackVariants =
    //   _normalizeVariants(cached is Map ? cached["variations"] : null);
    //   if (fallbackVariants.isNotEmpty) return fallbackVariants;
    // } catch (e) {
    //   debugPrint("_getVariantsFromCache error: $e");
    // }
    // return [];
           for (final entry in entries) {
        final List<dynamic> products = jsonDecode(entry.json);
        final match = products.firstWhere(
              (p) => p["fast_key_product_id"]?.toString() == productId.toString(),
          orElse: () => null,
        );
        if (match == null) continue;

        final rawVariations = match["variations"] ??
            (await productBox.get("product_${productId}_variations_v2"))?["variations"];
        final variants = _normalizeVariants(rawVariations);

        // ✅ NEW: treat missing meta_data as a cache miss
        final bool allHaveMetaData = variants.isNotEmpty &&
            variants.every((v) => v["meta_data"] is List);
        if (allHaveMetaData) return variants;
      }

      final cached = await productBox.get("product_${productId}_variations_v2");
      final fallbackVariants =
      _normalizeVariants(cached is Map ? cached["variations"] : null);
      final bool fallbackHasMeta = fallbackVariants.isNotEmpty &&
          fallbackVariants.every((v) => v["meta_data"] is List);
      if (fallbackHasMeta) return fallbackVariants;
    } catch (e) {
      debugPrint("_getVariantsFromCache error: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(
      int productId) async {
    try {
      final token = await _getAuthTokenFromDb();
      final url = Uri.parse(
          "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations");
      final response =
      await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode != 200) return <Map<String, dynamic>>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return <Map<String, dynamic>>[];

      return decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>((v) {
        final map =
        v.map((key, value) => MapEntry(key.toString(), value));
        final attrs = map["attributes"];
        final String fallbackName = attrs is List
            ? attrs
            .whereType<Map>()
            .map((a) => (a["option"] ?? "").toString())
            .where((x) => x.isNotEmpty)
            .join(" - ")
            : "";
        return {
          "id": map["id"],
          "name": (map["name"] ?? "").toString().isNotEmpty
              ? map["name"]
              : (fallbackName.isNotEmpty ? fallbackName : "Variant"),
          "price":
          (map["price"] ?? map["regular_price"] ?? "0").toString(),
          "image":
          (map["image"] is Map && map["image"]["src"] != null)
              ? map["image"]["src"]
              : (map["image"] is String ? map["image"] : ""),
          "sku": map["sku"] ?? "",
          // ✅ NEW
          "meta_data": (map["meta_data"] is List)
              ? (map["meta_data"] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
              : <Map<String, dynamic>>[],
        };
      })
          .where((v) => v["id"] != null)
          .toList();
    } catch (e) {
      debugPrint("_fetchVariationsFromApi error: $e");
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> _getAuthTokenFromDb() async {
    final db = await DBHelper.instance.database;
    final result = await db.query(
      AppDBConst.userTable,
      where:
      '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC',
      limit: 1,
    );
    if (result.isEmpty) throw Exception('No active user token found');
    return result.first[AppDBConst.userToken] as String;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PRODUCT TAP HANDLER — fast path, no Isar scans on every tap
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _handleProductTap(ProductResponse product) async {
    final screen = widget.screen;
    if (screen != Screen.FASTKEY &&
        screen != Screen.CATEGORY &&
        screen != Screen.ADD) {
      if (kDebugMode) print("TopBar: product tap ignored on screen $screen");
      return;
    }

    if (_dialogOpen) {
      if (kDebugMode) print("TopBar: dialog already open, ignoring tap");
      return;
    }

    _searchFocusNode.unfocus();
    _removeOverlay();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      // ── Step 1: Get order ID — create/reuse when none active ───────────────
      if (orderHelper.activeOrderId == null) {
        _cachedEnsuredOrderId = null;
      } else if (_cachedEnsuredOrderId != orderHelper.activeOrderId) {
        _cachedEnsuredOrderId = orderHelper.activeOrderId;
      }

      final ensureSw = Stopwatch()..start();
      _cachedEnsuredOrderId ??= await orderHelper.ensureOrderExists();
      print('[Cart] topbar ensureOrderExists ${ensureSw.elapsedMilliseconds}ms → $_cachedEnsuredOrderId');

      if (_cachedEnsuredOrderId == null) {
        final msg = OrderHelper.lastEnsureOrderError ??
            'Failed to create or restore order';
        print('[Cart] topbar add FAILED: $msg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
        return;
      }
      if (!mounted) return;

      final offlineBox = StorageProvider.offlineOrders;
      final activeOrderId = _cachedEnsuredOrderId.toString();

      // ── Step 2: Resolve tags FIRST — everything else depends on them ────────
      final List<SKU.Tags> tags = product.tags ?? [];

      // ── Step 3: Age check — fast in-memory tag scan, only hits Hive if needed
      final bool hasAgeRestriction =
      tags.any((t) => t.name == TextConstants.age_restricted);

      if (hasAgeRestriction) {
        final raw = await offlineBox.get(activeOrderId);
        final Map<String, dynamic> rawOrder =
        Map<String, dynamic>.from(raw is Map ? raw : {});
        final dynamic hiveAge = rawOrder["age_verified"];
        final bool alreadyVerified = hiveAge == true ||
            hiveAge == 1 ||
            hiveAge?.toString().toLowerCase() == "true";

        if (!alreadyVerified) {
          final SKU.Tags ageTag =
          tags.firstWhere((t) => t.name == TextConstants.age_restricted);
          final int minAge =
              int.tryParse(ageTag.slug?.toString() ?? "0") ?? 0;

          _dialogOpen = true;
          final prov = AgeVerificationProvider();
          final ok = await prov.verifyAge(context, minAge: minAge);
          _dialogOpen = false;

          if (!mounted) return;
          if (!ok) return;

          rawOrder["age_verified"] = true;
          await offlineBox.put(activeOrderId, rawOrder);
        }
      }

      if (!mounted) return;

      // ── Step 4: EBT — in-memory tag scan only, no Isar ─────────────────────
      final bool isEbtEligible = tags.any((t) {
        final name = t.name?.toLowerCase() ?? "";
        final slug = t.slug?.toLowerCase() ?? "";
        return name == "ebt" ||
            name == "ebt eligible" ||
            slug == "ebt" ||
            slug == "ebt-eligible";
      });

      // ── Step 5: Price ───────────────────────────────────────────────────────
      final double unitPrice = (product.price is num)
          ? (product.price as num).toDouble()
          : double.tryParse(product.price?.toString() ?? "0") ?? 0.0;

      // ── Step 6: Produce / weighted ──────────────────────────────────────────
      final bool hasProduceTag = tags.any((t) =>
      (t.slug?.toString().toLowerCase() == "produce") ||
          (t.name?.toString().toLowerCase() == "produce"));

      if (hasProduceTag) {
        final weightProvider = Provider.of<WeightProvider>(context, listen: false);

        double liveWeightLbs = 0.0;
        try {
          final parts = weightProvider.weightText.trim().split(' ');
          if (parts.isNotEmpty) {
            liveWeightLbs = double.tryParse(parts[0]) ?? 0.0;
          }
        } catch (_) {}

        print('🟢 Live Weight (lbs) from TopBar: $liveWeightLbs for produce item');

        final double finalPrice = (liveWeightLbs > 0)
            ? unitPrice * liveWeightLbs
            : unitPrice; // fallback

        final double weightToUse = liveWeightLbs > 0 ? liveWeightLbs : 0.0001;

        if (liveWeightLbs <= 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scale not detected — using default weight'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        setState(() => isAddingItemLoading = true);

        // ─────────────────────────────────────────────────────────────
        // Extract metaData + loyaltyPoints (works for both normal & Indigo products)
        // ─────────────────────────────────────────────────────────────
        List<Map<String, dynamic>> metaDataList = [];
        int loyaltyPoints = 0;

        // Try multiple sources
        dynamic rawMeta = null;
        if (product is IndigoCategoryBasedProducts) {
          rawMeta = product.metaData;
        } else {
          // Try from cached product map
          final cached = _cachedProducts.firstWhere(
                (p) => _productIdFromCacheMap(p) == product.id,
            orElse: () => null,
          );
          if (cached is Map) {
            rawMeta = cached['meta_data'] ?? cached['metaData'] ?? cached['metaData'];
          }
        }

        if (rawMeta is List) {
          metaDataList = rawMeta
              .whereType<Map>()
              .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
              .toList();

          // Extract loyalty points
          final loyaltyEntry = metaDataList.firstWhere(
                (m) => m['key'] == '_product_loyalty_points',
            orElse: () => {},
          );
          if (loyaltyEntry.isNotEmpty) {
            loyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
          }
        }

        await orderHelper.addItemToOrder(
          product.id!,
          product.name ?? 'Unknown',
          product.images?.isNotEmpty == true ? product.images!.first : '',
          finalPrice,
          1,
          product.sku ?? '',
          _cachedEnsuredOrderId!,
          type: 'weighted',
          weightQty: weightToUse,           // ← lbs (important)
          productId: product.id,
          variationId: -1,
          unitPrice: unitPrice,             // price per lb
          salesPrice: finalPrice,
          regularPrice: unitPrice,
          isEbtEligible: isEbtEligible,
          onItemAdded: () {
            _removeOverlay();
            _clearSearch();
            if (mounted) setState(() => isAddingItemLoading = false);
            widget.onProductSelected?.call(product);
          },
        );
        return;
      }

      // ── Step 7: Variants — only fetch if type/variations suggest it ─────────
      final bool mightHaveVariants =
          product.variations?.isNotEmpty == true ||

              (product.slug?.toString().toLowerCase() == 'variable');

      List<Map<String, dynamic>> variants = [];
      if (mightHaveVariants) {
        variants = await _getVariantsFromCache(product.id!);
        if (variants.isEmpty) {
          variants = await _fetchVariationsFromApi(product.id!);
          if (variants.isNotEmpty) {
            await StorageProvider.productCache.put(
              "product_${product.id}_variations",
              {
                "variations": variants,
                "timestamp": DateTime.now().toIso8601String(),
              },
            );
          }
        }
      }

      if (!mounted) return;

      if (variants.isNotEmpty) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;

        _dialogOpen = true;
        try {
          await showDialog(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder: (dialogCtx) => VariantsDialog(
              title: product.name ?? "Select Variant",
              variations: variants,
              onAddVariant: (selected, qty) async {
                final varPrice =
                    double.tryParse(selected["price"].toString()) ?? 0.0;
                final List<Map<String, dynamic>> variantMetaData =
                selected["meta_data"] is List
                    ? List<Map<String, dynamic>>.from(selected["meta_data"])
                    : <Map<String, dynamic>>[];

                final int variantLoyaltyPoints = variantMetaData.any(
                        (m) => m['key'] == '_product_loyalty_points')
                    ? int.tryParse(variantMetaData
                    .firstWhere((m) => m['key'] == '_product_loyalty_points')['value']
                    .toString()) ??
                    0
                    : 0;

                print(
                    '🛒 [TopBar] Added variant with loyalty points: ${selected["name"]} → $variantLoyaltyPoints');

                await orderHelper.addItemToOrder(
                  selected["id"],
                  selected["name"] ?? product.name ?? 'Unknown',
                  selected["image"] ?? '',
                  varPrice,
                  qty,
                  selected["sku"] ?? product.sku ?? '',
                  _cachedEnsuredOrderId!,
                  type: 'variant',
                  productId: product.id,
                  variationId: selected["id"],
                  unitPrice: varPrice,
                  salesPrice: varPrice,
                  regularPrice: varPrice,
                  isEbtEligible: isEbtEligible,
                  metaData: variantMetaData,           // ✅ NEW
                  loyaltyPoints: variantLoyaltyPoints, //
                  onItemAdded: () {
                    _removeOverlay();
                    _clearSearch();
                    if (mounted) setState(() => isAddingItemLoading = false);
                    widget.onProductSelected?.call(product);
                  },
                );
              },
            ),
          );
        } finally {
          _dialogOpen = false;
        }

        _removeOverlay();
        _clearSearch();
        if (mounted) setState(() => isAddingItemLoading = false);
        return;
      }

      // ── Step 8: Variable price tag ──────────────────────────────────────────
      final bool hasVariablePriceTag = tags.any((t) =>
      t.slug?.toLowerCase() == "variable-product" ||
          t.slug?.toLowerCase() == "variable" ||
          t.name?.toLowerCase() == "variable product" ||
          t.name?.toLowerCase() == "variable");

      double finalPrice = unitPrice;

      if (hasVariablePriceTag) {
        // Only read Hive for variable price products (rare case)
        final raw = await offlineBox.get(activeOrderId);
        final Map<String, dynamic> rawOrder =
        Map<String, dynamic>.from(raw is Map ? raw : {});
        final String variableKey = "variable_price_added_${product.id}";
        final String savedPriceKey = "selected_price_${product.id}";
        final bool popupAlreadyShown = rawOrder[variableKey] == true;

        if (popupAlreadyShown) {
          final savedPrice = rawOrder[savedPriceKey];
          finalPrice =
              double.tryParse(savedPrice?.toString() ?? "") ?? unitPrice;
        } else {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;

          _dialogOpen = true;
          double? enteredPrice;
          try {
            enteredPrice = await ManualPriceDialog.show(
              context,
              productName: product.name ?? "Product",
              productImage: _getProductImage(product),
              minPrice: unitPrice,
            );
          } finally {
            _dialogOpen = false;
          }

          if (!mounted) return;
          if (enteredPrice == null) return;

          finalPrice = enteredPrice;
          rawOrder[variableKey] = true;
          rawOrder[savedPriceKey] = finalPrice;
          await offlineBox.put(activeOrderId, rawOrder);
        }
      }

      if (!mounted) return;

      // ── Step 9: Simple product — add directly ───────────────────────────────
      setState(() => isAddingItemLoading = true);

      // ─────────────────────────────────────────────────────────────
      // Extract metaData + loyaltyPoints (works for both normal & Indigo products)
      // ─────────────────────────────────────────────────────────────
      List<Map<String, dynamic>> metaDataList = product.getMetaDataAsMap();
      int loyaltyPoints = product.getLoyaltyPoints();

      // Try multiple sources
      dynamic rawMeta;
      if (product is IndigoCategoryBasedProducts) {
        rawMeta = product.metaData;
      } else {
        final cached = _cachedProducts.firstWhere(
              (p) => _productIdFromCacheMap(p) == product.id,
          orElse: () => null,
        );
        if (cached is Map) {
          rawMeta = cached['meta_data'] ?? cached['metaData'];
        }
      }

      // ✅ FIX: fullProduct built from the search overlay never has metaData
      // set on it (only tags), so getMetaDataAsMap()/getLoyaltyPoints() come
      // back empty. Fall back to whatever meta_data we found in the caches.
      if (metaDataList.isEmpty && rawMeta is List) {
        metaDataList = rawMeta
            .whereType<Map>()
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      if (loyaltyPoints == 0 && metaDataList.isNotEmpty) {
        final loyaltyEntry = metaDataList.firstWhere(
              (m) =>
          m['key'] == '_product_loyalty_points' ||
              m['key'] == '_csv_loyalty_points',
          orElse: () => {},
        );
        if (loyaltyEntry.isNotEmpty) {
          loyaltyPoints =
              int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
        }
      }

      // ✅ Log loyalty points when adding to cart
      if (kDebugMode) {
        print('🛒 Adding product to cart:');
        print('   📦 Product: ${product.name} (ID: ${product.id})');
        print('   💰 Price: \$${finalPrice.toStringAsFixed(2)}');
        print('   ⭐ Loyalty Points: $loyaltyPoints');
        if (metaDataList.isNotEmpty) {
          print('   📋 Meta Data: ${metaDataList.length} items');
          final loyaltyMeta = metaDataList.where((m) =>
          m['key'] == '_product_loyalty_points' ||
              m['key'] == '_csv_loyalty_points');
          for (final m in loyaltyMeta) {
            print('      • ${m['key']}: ${m['value']}');
          }
        }
      }

      // Try multiple sources

      if (product is IndigoCategoryBasedProducts) {
        rawMeta = product.metaData;
      } else {
        // Try from cached product map
        final cached = _cachedProducts.firstWhere(
              (p) => _productIdFromCacheMap(p) == product.id,
          orElse: () => null,
        );
        if (cached is Map) {
          rawMeta = cached['meta_data'] ?? cached['metaData'] ?? cached['metaData'];
        }
      }

      // if (rawMeta is List) {
      //   metaDataList = rawMeta
      //       .whereType<Map>()
      //       .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
      //       .toList();
      //
      //   // Extract loyalty points
      //   final loyaltyEntry = metaDataList.firstWhere(
      //         (m) => m['key'] == '_product_loyalty_points',
      //     orElse: () => {},
      //   );
      //   if (loyaltyEntry.isNotEmpty) {
      //     loyaltyPoints = int.tryParse(loyaltyEntry['value']?.toString() ?? '0') ?? 0;
      //   }
      // }

      await orderHelper.addItemToOrder(
        product.id!,
        product.name ?? 'Unknown',
        product.images?.isNotEmpty == true ? product.images!.first : '',
        finalPrice,
        1,
        product.sku ?? '',
        _cachedEnsuredOrderId!,
        type: "simple",
        productId: product.id!,
        variationId: -1,
        variationName: null,
        variationCount: 0,
        combo: null,
        salesPrice: finalPrice,
        regularPrice: finalPrice,
        unitPrice: finalPrice,
        isEbtEligible: isEbtEligible,

        metaData: metaDataList,
        loyaltyPoints: loyaltyPoints,

        onItemAdded: () {
          _removeOverlay();
          _clearSearch();
          if (mounted) setState(() => isAddingItemLoading = false);
          widget.onProductSelected?.call(product);
        },
      );
    } catch (e, st) {
      if (kDebugMode) print("❌ _handleProductTap Exception: $e\n$st");
      _dialogOpen = false;
      _removeOverlay();
      if (mounted) setState(() => isAddingItemLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // MISC HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _fetchUserId() async {
    if (_isUserDataLoaded && _cachedUserData != null) {
      final userData = _cachedUserData;
      if (userData != null && userData[AppDBConst.userId] != null) {
        setState(() {
          userId = userData[AppDBConst.userId] as int;
          userDisplayName = userData[AppDBConst.userDisplayName];
          userRole = userData[AppDBConst.userRole];
        });
      }
      return;
    }
    final userData = await UserDbHelper().getUserData();
    if (userData != null && userData[AppDBConst.userId] != null) {
      setState(() {
        userId = userData[AppDBConst.userId] as int;
        userDisplayName = userData[AppDBConst.userDisplayName];
        userRole = userData[AppDBConst.userRole];
      });
    }
  }

  Future<bool> _showCashDrawerPinPopup(BuildContext context) async {
    final TextEditingController pinController = TextEditingController();
    bool isError = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark =
                Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor:
              isDark ? const Color(0xFF2F3241) : Colors.white,
              child: SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Authentication Required",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Enter PIN to open cash drawer",
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Inter',
                          color: isDark
                              ? Colors.white60
                              : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      _PinBoxField(
                        controller: pinController,
                        hasError: isError,
                      ),
                      if (isError) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "You are not authorized to access this feature.",
                          style: TextStyle(
                              fontSize: 11, color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF50535F)
                                    : const Color(0xFFE0E0E0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8)),
                              ),
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                final pin =
                                pinController.text.trim();
                                if (pin.length != 6) {
                                  setState(() => isError = true);
                                  return;
                                }
                                setState(() => isError = false);
                                try {
                                  final response =
                                  await OrderRepository()
                                      .validateLoginPin(pin);
                                  final decoded =
                                  json.decode(response);
                                  if (decoded["success"] == true) {
                                    Navigator.pop(ctx, true);
                                  } else {
                                    setState(() => isError = true);
                                    pinController.clear();
                                  }
                                } catch (e) {
                                  setState(() => isError = true);
                                  pinController.clear();
                                }
                              },
                              child: const Text(
                                "Confirm",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
            );
          },
        );
      },
    ) ??
        false;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return Container(
      color: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.primaryBackground
          : Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SvgPicture.asset(
            themeHelper.themeMode == ThemeMode.dark
                ? 'assets/svg/app_logo.svg'
                : 'assets/svg/app_icon.svg',
            height: 40,
            width: 40,
          ),
          const SizedBox(width: 80),

          // Search bar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFEDEBEB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF605F5F)
                        : Colors.grey.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius:
                    themeHelper.themeMode == ThemeMode.dark ? 2 : 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              height: 46,
              key: _searchFieldKey,
              child: TextField(
                enabled: _isSearchEnabled,
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: TextConstants.searchHint,
                  prefixIcon: Icon(Icons.search,
                      color: Theme.of(context).iconTheme.color),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Theme.of(context).iconTheme.color),
                    onPressed: _clearSearch,
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.searchBarBackground
                      : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 50),

          // Scale display — isolated widget, rebuilds only on weight/connect changes
          _ScaleDisplayWidget(
            onLongPress: _reconnectScale,
            onReconnect: _reconnectScale,
            isConnectingNotifier: _isConnectingNotifier,
          ),

          if (widget.screen == Screen.SHIFT) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                  const Center(child: CircularProgressIndicator()),
                );

                await LogoutBloc(LogoutRepository()).performLogout();
                await UserDbHelper().logout();
                await PinakaPreferences.clearUserPreferences();
                TopBar.clearUserCache();

                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? ThemeNotifier.secondaryBackground
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? const Color(0xFF3B3939)
                        : const Color(0xFFF1F1F3),
                  ),
                ),
                child:
                const Icon(Icons.logout, size: 24, color: Colors.grey),
              ),
            ),
          ],

          const SizedBox(width: 16),

          // Cash drawer
          GestureDetector(
            onTap: () async {
              final isAuthorized =
              await _showCashDrawerPinPopup(context);
              if (!isAuthorized) return;
              await PrinterSettings.openDrawer(context: context);
              List<int> bytes = [];
              final ticket = await _printerSettings.getTicket();
              bytes += ticket.feed(1);
              await _printerSettings.printTicket(bytes, ticket);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.cashDrawerIcon,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Mode toggle
          GestureDetector(
            onTap: () {
              print("🔄 [MODE BUTTON] Tapped — calling onModeChanged");
              widget.onModeChanged();
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF3B3939)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.changeModeIcon,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Theme toggle
          GestureDetector(
            onTap: () {
              themeHelper.setThemeMode(
                themeHelper.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.secondaryBackground
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeHelper.themeMode == ThemeMode.dark
                      ? const Color(0xFF605F5F)
                      : const Color(0xFFF1F1F3),
                ),
              ),
              child: SvgPicture.asset(
                SvgUtils.themeIcon,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  themeHelper.themeMode == ThemeMode.dark
                      ? Colors.white70
                      : Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Notifications
          Container(
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? const Color(0xFF3B3939)
                    : const Color(0xFFF1F1F3),
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.notifications,
              size: 24,
              color: themeHelper.themeMode == ThemeMode.dark
                  ? Colors.white
                  : Colors.black54,
            ),
          ),
          const SizedBox(width: 16),

          // Refresh
          IconButton(
            icon: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : refreshProducts,
          ),

          // User chip
          Container(
            height: 45,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: themeHelper.themeMode == ThemeMode.dark
                  ? ThemeNotifier.secondaryBackground
                  : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? const Color(0xFF3B3939)
                    : const Color(0xFFF1F1F3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    (userDisplayName ?? "Unknown")
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userDisplayName ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : ThemeNotifier.textLight,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      userRole ?? "Unknown",
                      style: const TextStyle(
                          color: Color(0xFFE09696), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}