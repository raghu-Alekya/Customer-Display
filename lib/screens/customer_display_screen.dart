// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../models/display_state.dart';
// import '../providers/display_provider.dart';
// import 'package:http/http.dart' as http;
//
//
//
// class _C {
//   static const bodyBg = Color(0xFFE9EEF6);
//   static const headerBlue = Color(0xFF1F3A68);
//   static const accentBlue = Color(0xFF003A82);
//   static const textDark = Color(0xFF212121);
//   static const textMid = Color(0xFF353535);
//   static const textGray = Color(0xFF808080);
//   static const green = Color(0xFF036A07);
//   static const blue2 = Color(0xFF007BFF);
//   static const purple = Color(0xFF9C27B0);
//   static const teal = Color(0xFF55CBCD);
//   static const totalsBar = Color(0xFFFFA9A9);
//   static const red = Color(0xFFE20000);
//   static const slate = Color(0xFF3D506E);
//   static const cardBorder = Color(0xFFDDE3EC);
// }
//
// // ============================================================================
// // CUSTOMER DISPLAY SCREEN
// // ============================================================================
//
// class CustomerDisplayScreen extends StatefulWidget {
//   const CustomerDisplayScreen({super.key});
//
//   @override
//   State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
// }
//
// class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
//   /// After MQTT IDLE/WELCOME, stay on Welcome until a real new CART arrives.
//   bool _forceWelcome = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<DisplayProvider>(
//       builder: (context, provider, _) {
//         final state = provider.state;
//         final screen = state.screen.toUpperCase().trim();
//
//         // Real order = has a proper orderId (even if items is empty)
//         final hasRealOrder = state.orderId.trim().isNotEmpty &&
//             state.orderId.trim() != '0';
//
//         // Determine whether to force the Welcome layout
//         if (screen == 'IDLE' || screen == 'WELCOME') {
//           _forceWelcome = true;
//         } else if (screen == 'CART' || screen == 'PAYMENT') {
//           // Show CART layout only if there is a real order; otherwise force Welcome
//           _forceWelcome = !hasRealOrder;
//         } else if (screen == 'THANK_YOU' ||
//             screen == 'SUCCESS' ||
//             screen == 'REFUND') {
//           _forceWelcome = false;
//         } else {
//           // Fallback: treat unknown screens as Welcome
//           _forceWelcome = true;
//         }
//
//         debugPrint(
//           'CUSTOMER DISPLAY -> screen=${state.screen}, '
//               'items=${state.items.length}, orderId=${state.orderId}, '
//               'forceWelcome=$_forceWelcome, store=${state.storeName}',
//         );
//
//         return Scaffold(
//           backgroundColor: _C.slate,
//           body: SafeArea(
//             child: _buildScreen(provider, state, screen),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildScreen(
//       DisplayProvider provider,
//       DisplayState state,
//       String screen,
//       ) {
//     // Completed order → Welcome (store name), never old cart
//     if (_forceWelcome &&
//         screen != 'THANK_YOU' &&
//         screen != 'SUCCESS' &&
//         screen != 'REFUND') {
//       return _WelcomeLayout(
//         key: const ValueKey('WELCOME_FORCED'),
//         state: state,
//       );
//     }
//
//     switch (screen) {
//       case 'WELCOME':
//         return _WelcomeLayout(
//           key: const ValueKey('WELCOME'),
//           state: state,
//         );
//
//       case 'CART':
//       case 'PAYMENT':
//         return _CustomerDisplayLayout(
//           key: const ValueKey('CART'),
//           state: state,
//         );
//
//       case 'THANK_YOU':
//         return _ThankYouLayout(
//           key: const ValueKey('THANK_YOU'),
//           state: state,
//         );
//
//       case 'SUCCESS':
//       case 'REFUND':
//         return _MessageView(
//           key: ValueKey(state.screen),
//           screen: state.screen,
//           total: state.total,
//           message: state.message,
//         );
//
//       case 'IDLE':
//       default:
//         return _WelcomeLayout(
//           key: const ValueKey('IDLE'),
//           state: state,
//         );
//     }
//   }
// }
//
// // ============================================================================
// // HELPERS – hide discount lines from items list (summary only)
// // ============================================================================
//
// bool _isDiscountLineItem(DisplayItem item) {
//   final name = item.name.toLowerCase().trim();
//   final type = item.itemType.toLowerCase();
//
//   if (type.contains('discount') || type.contains('merchant')) {
//     return true;
//   }
//   if (name.contains('merchant discount') ||
//       name == 'discount' ||
//       name.contains('order discount')) {
//     return true;
//   }
//   // Coupon as a cart line belongs only in summary
//   if (name == 'coupon' || type.contains('coupon')) {
//     return true;
//   }
//   return false;
// }
//
// List<DisplayItem> _visibleCartItems(List<DisplayItem> items) {
//   return items.where((item) => !_isDiscountLineItem(item)).toList();
// }
//
// // ============================================================================
// // SLIDESHOW
// // ============================================================================
//
// class _Slideshow extends StatefulWidget {
//   final List<String> urls;
//
//   const _Slideshow({
//     required this.urls,
//   });
//
//   @override
//   State<_Slideshow> createState() => _SlideshowState();
// }
//
// class _SlideshowState extends State<_Slideshow> {
//   int _index = 0;
//   Timer? _timer;
//
//   List<String> get _urls {
//     return widget.urls.where((u) => u.trim().isNotEmpty).toList();
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _restart();
//   }
//
//   @override
//   void didUpdateWidget(covariant _Slideshow oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     if (!_listEquals(oldWidget.urls, widget.urls)) {
//       _index = 0;
//       _restart();
//     }
//   }
//
//   bool _listEquals(List<String> a, List<String> b) {
//     if (a.length != b.length) return false;
//     for (var i = 0; i < a.length; i++) {
//       if (a[i] != b[i]) return false;
//     }
//     return true;
//   }
//
//   void _restart() {
//     _timer?.cancel();
//     final urls = _urls;
//     if (urls.length <= 1) return;
//
//     _timer = Timer.periodic(const Duration(seconds: 3), (_) {
//       if (!mounted) return;
//       setState(() {
//         _index = (_index + 1) % urls.length;
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final urls = _urls;
//
//     if (urls.isEmpty) {
//       return Container(
//         color: _C.slate,
//         alignment: Alignment.center,
//         child: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.image_outlined, color: Colors.white54, size: 64),
//             SizedBox(height: 12),
//             Text(
//               'No banners',
//               style: TextStyle(color: Colors.white70, fontSize: 16),
//             ),
//           ],
//         ),
//       );
//     }
//
//     final safeIndex = _index.clamp(0, urls.length - 1);
//
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         AnimatedSwitcher(
//           duration: const Duration(milliseconds: 400),
//           child: Image.network(
//             urls[safeIndex],
//             key: ValueKey('${urls[safeIndex]}#$safeIndex'),
//             fit: BoxFit.cover,
//             width: double.infinity,
//             height: double.infinity,
//             loadingBuilder: (context, child, progress) {
//               if (progress == null) return child;
//               return Container(
//                 color: _C.slate,
//                 alignment: Alignment.center,
//                 child: const CircularProgressIndicator(color: Colors.white54),
//               );
//             },
//             errorBuilder: (context, error, stackTrace) {
//               debugPrint(
//                 'Slideshow image failed: ${urls[safeIndex]} -> $error',
//               );
//               return Container(
//                 color: _C.slate,
//                 alignment: Alignment.center,
//                 child: const Icon(
//                   Icons.broken_image_outlined,
//                   color: Colors.white54,
//                   size: 64,
//                 ),
//               );
//             },
//           ),
//         ),
//         if (urls.length > 1)
//           Positioned(
//             left: 0,
//             right: 0,
//             bottom: 12,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(urls.length, (i) {
//                 final active = i == safeIndex;
//                 return Container(
//                   width: active ? 10 : 7,
//                   height: active ? 10 : 7,
//                   margin: const EdgeInsets.symmetric(horizontal: 3),
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: active ? Colors.white : Colors.white38,
//                   ),
//                 );
//               }),
//             ),
//           ),
//       ],
//     );
//   }
// }
//
//
// // class _WelcomeLayout extends StatefulWidget {
// //   final DisplayState state;
// //
// //   const _WelcomeLayout({
// //     super.key,
// //     required this.state,
// //   });
// //
// //   @override
// //   State<_WelcomeLayout> createState() => _WelcomeLayoutState();
// // }
// //
// // class _WelcomeLayoutState extends State<_WelcomeLayout> {
// //   List<String> _promotionImages = [];
// //   bool _loadingPromotions = true;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadPromotionImages();
// //   }
// //
// //   @override
// //   void didUpdateWidget(covariant _WelcomeLayout oldWidget) {
// //     super.didUpdateWidget(oldWidget);
// //
// //     // Reload if store/base URL changes.
// //     if (oldWidget.state.storeBaseUrl != widget.state.storeBaseUrl) {
// //       _loadPromotionImages();
// //     }
// //   }
// //
// //   // ==========================================================================
// //   // LOAD PROMOTION IMAGES
// //   // ==========================================================================
// //
// //   Future<void> _loadPromotionImages() async {
// //     final baseUrl = widget.state.storeBaseUrl?.trim();
// //
// //     if (baseUrl == null || baseUrl.isEmpty) {
// //       debugPrint(
// //         'WELCOME -> storeBaseUrl is empty. '
// //             'Using existing slideshowUrls.',
// //       );
// //
// //       if (!mounted) return;
// //
// //       setState(() {
// //         _promotionImages = widget.state.slideshowUrls;
// //         _loadingPromotions = false;
// //       });
// //
// //       return;
// //     }
// //
// //     try {
// //       final cleanBaseUrl = baseUrl.endsWith('/')
// //           ? baseUrl.substring(0, baseUrl.length - 1)
// //           : baseUrl;
// //
// //       final apiUrl =
// //           '$cleanBaseUrl/wp-content/plugins/pinaka-pos-wp/promotion_images.php';
// //
// //       debugPrint(
// //         'WELCOME -> Loading promotion images from:',
// //       );
// //       debugPrint(
// //         'WELCOME -> $apiUrl',
// //       );
// //
// //       final response = await http
// //           .get(
// //         Uri.parse(apiUrl),
// //         headers: const {
// //           'Accept': 'application/json',
// //         },
// //       )
// //           .timeout(const Duration(seconds: 10));
// //
// //       debugPrint(
// //         'WELCOME -> promotion_images status: ${response.statusCode}',
// //       );
// //
// //       debugPrint(
// //         'WELCOME -> promotion_images body: ${response.body}',
// //       );
// //
// //       if (response.statusCode != 200) {
// //         throw Exception(
// //           'promotion_images.php returned ${response.statusCode}',
// //         );
// //       }
// //
// //       final decoded = jsonDecode(response.body);
// //
// //       final images = _extractPromotionImages(decoded);
// //
// //       // Resolve relative URLs.
// //       final resolvedImages = <String>[];
// //       final seen = <String>{};
// //
// //       for (final image in images) {
// //         final resolved = _resolvePromotionUrl(
// //           image,
// //           cleanBaseUrl,
// //         );
// //
// //         if (resolved.isNotEmpty && seen.add(resolved)) {
// //           resolvedImages.add(resolved);
// //         }
// //       }
// //
// //       debugPrint(
// //         'WELCOME -> Promotion image count: '
// //             '${resolvedImages.length}',
// //       );
// //
// //       for (var i = 0; i < resolvedImages.length; i++) {
// //         debugPrint(
// //           'WELCOME -> promotion[$i] = ${resolvedImages[i]}',
// //         );
// //       }
// //
// //       if (!mounted) return;
// //
// //       setState(() {
// //         // If API has images, use them.
// //         //
// //         // If API returns nothing, fall back to the old slideshow URLs.
// //         _promotionImages = resolvedImages.isNotEmpty
// //             ? resolvedImages
// //             : widget.state.slideshowUrls;
// //
// //         _loadingPromotions = false;
// //       });
// //     } catch (e, stackTrace) {
// //       debugPrint(
// //         'WELCOME -> Failed to load promotion images: $e',
// //       );
// //
// //       debugPrintStack(
// //         stackTrace: stackTrace,
// //       );
// //
// //       if (!mounted) return;
// //
// //       // Keep the old banners as fallback.
// //       setState(() {
// //         _promotionImages = widget.state.slideshowUrls;
// //         _loadingPromotions = false;
// //       });
// //     }
// //   }
// //
// //   // ==========================================================================
// //   // EXTRACT IMAGE URLS FROM API RESPONSE
// //   // ==========================================================================
// //
// //   List<String> _extractPromotionImages(dynamic data) {
// //     final result = <String>[];
// //
// //     void absorb(dynamic value) {
// //       if (value == null) return;
// //
// //       // ------------------------------------------------------------------------
// //       // List
// //       // ------------------------------------------------------------------------
// //       if (value is List) {
// //         for (final item in value) {
// //           if (item is String) {
// //             final url = item.trim();
// //
// //             if (url.isNotEmpty) {
// //               result.add(url);
// //             }
// //           } else if (item is Map) {
// //             final url = item['url'] ??
// //                 item['src'] ??
// //                 item['image'] ??
// //                 item['image_url'] ??
// //                 item['imageUrl'] ??
// //                 item['promotion_image'] ??
// //                 item['promotionImage'] ??
// //                 item['promotion_image_url'] ??
// //                 item['promotionImageUrl'] ??
// //                 item['banner_url'] ??
// //                 item['bannerUrl'] ??
// //                 item['path'];
// //
// //             if (url != null) {
// //               final urlString = url.toString().trim();
// //
// //               if (urlString.isNotEmpty) {
// //                 result.add(urlString);
// //               }
// //             }
// //           }
// //         }
// //
// //         return;
// //       }
// //
// //       // ------------------------------------------------------------------------
// //       // String
// //       // ------------------------------------------------------------------------
// //       if (value is String) {
// //         final text = value.trim();
// //
// //         if (text.isEmpty) return;
// //
// //         // JSON string containing array/object.
// //         if (text.startsWith('[') || text.startsWith('{')) {
// //           try {
// //             final decoded = jsonDecode(text);
// //             absorb(decoded);
// //             return;
// //           } catch (_) {
// //             // Continue as normal string.
// //           }
// //         }
// //
// //         // Comma-separated URLs.
// //         if (text.contains(',')) {
// //           for (final part in text.split(',')) {
// //             final url = part.trim();
// //
// //             if (url.isNotEmpty) {
// //               result.add(url);
// //             }
// //           }
// //         } else {
// //           result.add(text);
// //         }
// //
// //         return;
// //       }
// //
// //       // ------------------------------------------------------------------------
// //       // Map
// //       // ------------------------------------------------------------------------
// //       if (value is Map) {
// //         // Exact promotion_images key first.
// //         const promotionKeys = [
// //           'promotion_images',
// //           'promotionImages',
// //           'promotion_image',
// //           'promotionImage',
// //           'promotion_image_urls',
// //           'promotionImageUrls',
// //           'images',
// //           'image_urls',
// //           'imageUrls',
// //           'data',
// //           'results',
// //           'items',
// //         ];
// //
// //         for (final key in promotionKeys) {
// //           if (value.containsKey(key)) {
// //             absorb(value[key]);
// //           }
// //         }
// //
// //         return;
// //       }
// //     }
// //
// //     absorb(data);
// //
// //     return result;
// //   }
// //
// //   // ==========================================================================
// //   // RESOLVE RELATIVE IMAGE URL
// //   // ==========================================================================
// //
// //   String _resolvePromotionUrl(
// //       String url,
// //       String baseUrl,
// //       ) {
// //     final value = url.trim();
// //
// //     if (value.isEmpty) {
// //       return '';
// //     }
// //
// //     if (value.startsWith('http://') ||
// //         value.startsWith('https://') ||
// //         value.startsWith('file://') ||
// //         value.startsWith('data:')) {
// //       return value;
// //     }
// //
// //     final base = baseUrl.endsWith('/')
// //         ? baseUrl.substring(0, baseUrl.length - 1)
// //         : baseUrl;
// //
// //     if (value.startsWith('/')) {
// //       return '$base$value';
// //     }
// //
// //     return '$base/$value';
// //   }
// //
// //   // ==========================================================================
// //   // UI
// //   // ==========================================================================
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final state = widget.state;
// //     final hasStore = state.storeName.isNotEmpty;
// //
// //     return Container(
// //       color: _C.slate,
// //       child: Stack(
// //         children: [
// //           Row(
// //             children: [
// //               // =================================================================
// //               // LEFT SIDE
// //               // =================================================================
// //
// //               Expanded(
// //                 child: Padding(
// //                   padding: const EdgeInsets.all(16),
// //                   child: Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       _StoreLogo(
// //                         url: state.storeLogoUrl,
// //                         width: 150,
// //                       ),
// //                       const SizedBox(height: 24),
// //                       Text(
// //                         hasStore
// //                             ? 'Welcome to ${state.storeName}'
// //                             : 'Welcome to',
// //                         textAlign: TextAlign.center,
// //                         maxLines: 2,
// //                         overflow: TextOverflow.ellipsis,
// //                         style: const TextStyle(
// //                           color: Colors.white,
// //                           fontSize: 42,
// //                           fontWeight: FontWeight.bold,
// //                           fontFamily: 'serif',
// //                           height: 1.15,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //
// //               // =================================================================
// //               // RIGHT SIDE - PROMOTION IMAGES
// //               // =================================================================
// //
// //               Expanded(
// //                 child: Padding(
// //                   padding: const EdgeInsets.all(16),
// //                   child: _loadingPromotions
// //                       ? Container(
// //                     color: _C.slate,
// //                     alignment: Alignment.center,
// //                     child: const CircularProgressIndicator(
// //                       color: Colors.white54,
// //                     ),
// //                   )
// //                       : _Slideshow(
// //                     urls: _promotionImages,
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //
// //           // ====================================================================
// //           // POWERED BY
// //           // ====================================================================
// //
// //           if (hasStore)
// //             Positioned(
// //               left: 0,
// //               right: 0,
// //               bottom: 0,
// //               child: Container(
// //                 width: double.infinity,
// //                 padding: const EdgeInsets.all(12),
// //                 alignment: Alignment.center,
// //                 child: const Text(
// //                   'Powered by Pinaka',
// //                   textAlign: TextAlign.center,
// //                   style: TextStyle(
// //                     color: Colors.white,
// //                     fontSize: 20,
// //                   ),
// //                 ),
// //               ),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
// // ============================================================================
// // WELCOME
// // ============================================================================
//
// class _WelcomeLayout extends StatefulWidget {
//   final DisplayState state;
//
//   const _WelcomeLayout({
//     super.key,
//     required this.state,
//   });
//
//   @override
//   State<_WelcomeLayout> createState() => _WelcomeLayoutState();
// }
//
// class _WelcomeLayoutState extends State<_WelcomeLayout> {
//   List<String> _promotionImages = [];
//
//   String _storeName = '';
//   String? _storeLogoUrl;
//   String? _storeBaseUrl;
//
//   bool _loading = true;
//   bool _loadingStarted = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadWelcomeData();
//   }
//
//   @override
//   void didUpdateWidget(covariant _WelcomeLayout oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     final oldState = oldWidget.state;
//     final newState = widget.state;
//
//     final brandingChanged =
//         oldState.storeName != newState.storeName ||
//             oldState.storeLogoUrl != newState.storeLogoUrl ||
//             oldState.storeBaseUrl != newState.storeBaseUrl;
//
//     final bannersChanged = !_sameList(
//       oldState.slideshowUrls,
//       newState.slideshowUrls,
//     );
//
//     if (brandingChanged || bannersChanged) {
//       debugPrint(
//         'WELCOME -> DisplayState changed. Reloading welcome data.',
//       );
//
//       _loadWelcomeData();
//     }
//   }
//
//   // ==========================================================================
//   // LOAD WELCOME DATA
//   // ==========================================================================
//
//   Future<void> _loadWelcomeData() async {
//     if (!mounted) return;
//
//     if (_loadingStarted) {
//       return;
//     }
//
//     _loadingStarted = true;
//
//     try {
//       debugPrint('WELCOME -> =======================================');
//       debugPrint('WELCOME -> Loading welcome data from DisplayState');
//
//       final state = widget.state;
//
//       debugPrint(
//         'WELCOME -> storeName = ${state.storeName}',
//       );
//
//       debugPrint(
//         'WELCOME -> storeLogoUrl = ${state.storeLogoUrl}',
//       );
//
//       debugPrint(
//         'WELCOME -> storeBaseUrl = ${state.storeBaseUrl}',
//       );
//
//       debugPrint(
//         'WELCOME -> slideshowUrls = ${state.slideshowUrls}',
//       );
//
//       // ----------------------------------------------------------------------
//       // Store information comes directly from DisplayState.
//       //
//       // DisplayState should be populated by your MQTT message handler.
//       // ----------------------------------------------------------------------
//
//       final storeName = state.storeName.trim();
//
//       final storeLogoUrl = state.storeLogoUrl?.trim().isNotEmpty == true
//           ? state.storeLogoUrl!.trim()
//           : null;
//
//       final storeBaseUrl = state.storeBaseUrl?.trim().isNotEmpty == true
//           ? state.storeBaseUrl!.trim()
//           : null;
//
//       // ----------------------------------------------------------------------
//       // First use slideshow URLs received through MQTT.
//       // ----------------------------------------------------------------------
//
//       final mqttImages = _uniqueUrls(
//         state.slideshowUrls,
//         storeBaseUrl,
//       );
//
//       // ----------------------------------------------------------------------
//       // Optionally load promotion_images.php.
//       //
//       // If the API returns images, those are used.
//       // Otherwise MQTT slideshowUrls are used.
//       // ----------------------------------------------------------------------
//
//       List<String> promotionImages = [];
//
//       if (storeBaseUrl != null && storeBaseUrl.isNotEmpty) {
//         promotionImages = await _loadPromotionImages(
//           storeBaseUrl,
//         );
//       } else {
//         debugPrint(
//           'WELCOME -> storeBaseUrl is empty. '
//               'Skipping promotion API.',
//         );
//       }
//
//       // ----------------------------------------------------------------------
//       // Priority:
//       //
//       // 1. promotion_images.php
//       // 2. MQTT slideshowUrls
//       // ----------------------------------------------------------------------
//
//       final finalImages = promotionImages.isNotEmpty
//           ? promotionImages
//           : mqttImages;
//
//       debugPrint('WELCOME -> FINAL DATA');
//       debugPrint('WELCOME -> storeName = $storeName');
//       debugPrint('WELCOME -> storeLogoUrl = $storeLogoUrl');
//       debugPrint('WELCOME -> storeBaseUrl = $storeBaseUrl');
//       debugPrint(
//         'WELCOME -> banner count = ${finalImages.length}',
//       );
//
//       for (var i = 0; i < finalImages.length; i++) {
//         debugPrint(
//           'WELCOME -> banner[$i] = ${finalImages[i]}',
//         );
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         _storeName = storeName;
//         _storeLogoUrl = storeLogoUrl;
//         _storeBaseUrl = storeBaseUrl;
//         _promotionImages = finalImages;
//         _loading = false;
//       });
//     } catch (e, stackTrace) {
//       debugPrint(
//         'WELCOME -> Failed loading welcome data: $e',
//       );
//
//       debugPrintStack(
//         stackTrace: stackTrace,
//       );
//
//       if (!mounted) return;
//
//       // ----------------------------------------------------------------------
//       // Always fall back to DisplayState.
//       // ----------------------------------------------------------------------
//
//       final state = widget.state;
//
//       final fallbackName = state.storeName.trim();
//
//       final fallbackLogo = state.storeLogoUrl?.trim().isNotEmpty == true
//           ? state.storeLogoUrl!.trim()
//           : null;
//
//       final fallbackBase = state.storeBaseUrl?.trim().isNotEmpty == true
//           ? state.storeBaseUrl!.trim()
//           : null;
//
//       final fallbackImages = _uniqueUrls(
//         state.slideshowUrls,
//         fallbackBase,
//       );
//
//       setState(() {
//         _storeName = fallbackName;
//         _storeLogoUrl = fallbackLogo;
//         _storeBaseUrl = fallbackBase;
//         _promotionImages = fallbackImages;
//         _loading = false;
//       });
//     } finally {
//       _loadingStarted = false;
//     }
//   }
//
//   // ==========================================================================
//   // PROMOTION API
//   // ==========================================================================
//
//   Future<List<String>> _loadPromotionImages(
//       String storeBaseUrl,
//       ) async {
//     final cleanBaseUrl = _cleanBaseUrl(storeBaseUrl);
//
//     final apiUrl =
//         '$cleanBaseUrl/wp-content/plugins/pinaka-pos-wp/promotion_images.php';
//
//     debugPrint(
//       'WELCOME -> Calling promotion API:',
//     );
//
//     debugPrint(
//       'WELCOME -> $apiUrl',
//     );
//
//     try {
//       final response = await http
//           .get(
//         Uri.parse(apiUrl),
//         headers: const {
//           'Accept': 'application/json',
//           'Cache-Control': 'no-cache',
//         },
//       )
//           .timeout(
//         const Duration(seconds: 10),
//       );
//
//       debugPrint(
//         'WELCOME -> promotion_images status=${response.statusCode}',
//       );
//
//       debugPrint(
//         'WELCOME -> promotion_images response=${response.body}',
//       );
//
//       if (response.statusCode < 200 ||
//           response.statusCode >= 300) {
//         debugPrint(
//           'WELCOME -> Promotion API failed: '
//               '${response.statusCode}',
//         );
//
//         return [];
//       }
//
//       if (response.body.trim().isEmpty) {
//         debugPrint(
//           'WELCOME -> Promotion API returned empty body',
//         );
//
//         return [];
//       }
//
//       final decoded = jsonDecode(response.body);
//
//       final images = _extractPromotionImages(decoded);
//
//       final resolved = _uniqueUrls(
//         images,
//         cleanBaseUrl,
//       );
//
//       debugPrint(
//         'WELCOME -> Promotion API images=${resolved.length}',
//       );
//
//       return resolved;
//     } catch (e, stackTrace) {
//       debugPrint(
//         'WELCOME -> Promotion API error: $e',
//       );
//
//       debugPrintStack(
//         stackTrace: stackTrace,
//       );
//
//       return [];
//     }
//   }
//
//   // ==========================================================================
//   // EXTRACT PROMOTION IMAGES
//   // ==========================================================================
//
//   List<String> _extractPromotionImages(
//       dynamic data,
//       ) {
//     final result = <String>[];
//
//     void absorb(dynamic value) {
//       if (value == null) return;
//
//       // ----------------------------------------------------------------------
//       // LIST
//       // ----------------------------------------------------------------------
//
//       if (value is List) {
//         for (final item in value) {
//           if (item is String) {
//             final text = item.trim();
//
//             if (text.isNotEmpty) {
//               result.add(text);
//             }
//           } else if (item is Map) {
//             final url =
//                 item['url'] ??
//                     item['src'] ??
//                     item['image'] ??
//                     item['image_url'] ??
//                     item['imageUrl'] ??
//                     item['promotion_image'] ??
//                     item['promotionImage'] ??
//                     item['promotion_image_url'] ??
//                     item['promotionImageUrl'] ??
//                     item['banner_url'] ??
//                     item['bannerUrl'] ??
//                     item['path'];
//
//             if (url != null) {
//               final text = url.toString().trim();
//
//               if (text.isNotEmpty) {
//                 result.add(text);
//               }
//             }
//           }
//         }
//
//         return;
//       }
//
//       // ----------------------------------------------------------------------
//       // STRING
//       // ----------------------------------------------------------------------
//
//       if (value is String) {
//         final text = value.trim();
//
//         if (text.isEmpty) return;
//
//         if (text.startsWith('[') || text.startsWith('{')) {
//           try {
//             final decoded = jsonDecode(text);
//
//             absorb(decoded);
//
//             return;
//           } catch (_) {
//             // Continue below.
//           }
//         }
//
//         if (text.contains(',')) {
//           for (final part in text.split(',')) {
//             final item = part.trim();
//
//             if (item.isNotEmpty) {
//               result.add(item);
//             }
//           }
//         } else {
//           result.add(text);
//         }
//
//         return;
//       }
//
//       // ----------------------------------------------------------------------
//       // MAP
//       // ----------------------------------------------------------------------
//
//       if (value is Map) {
//         const keys = [
//           'promotion_images',
//           'promotionImages',
//           'promotion_image',
//           'promotionImage',
//           'promotion_image_urls',
//           'promotionImageUrls',
//           'images',
//           'image_urls',
//           'imageUrls',
//           'banners',
//           'banner_urls',
//           'bannerUrls',
//           'slides',
//           'data',
//           'results',
//           'items',
//         ];
//
//         for (final key in keys) {
//           if (value.containsKey(key)) {
//             absorb(value[key]);
//           }
//         }
//
//         return;
//       }
//     }
//
//     absorb(data);
//
//     return result;
//   }
//
//   // ==========================================================================
//   // URL HELPERS
//   // ==========================================================================
//
//   String _cleanBaseUrl(
//       String value,
//       ) {
//     var result = value.trim();
//
//     while (result.endsWith('/')) {
//       result = result.substring(0, result.length - 1);
//     }
//
//     return result;
//   }
//
//   String _resolveUrl(
//       String url,
//       String? baseUrl,
//       ) {
//     final value = url.trim();
//
//     if (value.isEmpty) {
//       return '';
//     }
//
//     if (value.startsWith('http://') ||
//         value.startsWith('https://') ||
//         value.startsWith('file://') ||
//         value.startsWith('data:')) {
//       return value;
//     }
//
//     if (baseUrl == null || baseUrl.trim().isEmpty) {
//       return value;
//     }
//
//     final base = _cleanBaseUrl(baseUrl);
//
//     if (value.startsWith('/')) {
//       return '$base$value';
//     }
//
//     return '$base/$value';
//   }
//
//   List<String> _uniqueUrls(
//       List<String> urls,
//       String? baseUrl,
//       ) {
//     final result = <String>[];
//     final seen = <String>{};
//
//     for (final url in urls) {
//       final resolved = _resolveUrl(
//         url,
//         baseUrl,
//       );
//
//       if (resolved.isEmpty) {
//         continue;
//       }
//
//       if (seen.add(resolved)) {
//         result.add(resolved);
//       }
//     }
//
//     return result;
//   }
//
//   bool _sameList(
//       List<String> a,
//       List<String> b,
//       ) {
//     if (a.length != b.length) {
//       return false;
//     }
//
//     for (var i = 0; i < a.length; i++) {
//       if (a[i] != b[i]) {
//         return false;
//       }
//     }
//
//     return true;
//   }
//
//   // ==========================================================================
//   // UI
//   // ==========================================================================
//
//   @override
//   Widget build(
//       BuildContext context,
//       ) {
//     final hasStore = _storeName.isNotEmpty;
//
//     // ------------------------------------------------------------------------
//     // Initial loading
//     // ------------------------------------------------------------------------
//
//     if (_loading && !hasStore && _storeLogoUrl == null) {
//       return Container(
//         color: _C.slate,
//         child: Row(
//           children: [
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.storefront_rounded,
//                       color: Colors.white54,
//                       size: 90,
//                     ),
//                     const SizedBox(height: 20),
//                     const Text(
//                       'Welcome',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 40,
//                         fontWeight: FontWeight.bold,
//                         fontFamily: 'serif',
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const SizedBox(
//                       width: 28,
//                       height: 28,
//                       child: CircularProgressIndicator(
//                         color: Colors.white54,
//                         strokeWidth: 2,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: _promotionImages.isEmpty
//                   ? Container(
//                 color: _C.slate,
//                 alignment: Alignment.center,
//                 child: const CircularProgressIndicator(
//                   color: Colors.white54,
//                 ),
//               )
//                   : _Slideshow(
//                 urls: _promotionImages,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return Container(
//       color: _C.slate,
//       child: Stack(
//         children: [
//           Row(
//             children: [
//               // =================================================================
//               // LEFT
//               // =================================================================
//
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _StoreLogo(
//                         url: _storeLogoUrl,
//                         width: 150,
//                       ),
//
//                       const SizedBox(height: 24),
//
//                       Text(
//                         hasStore
//                             ? 'Welcome to $_storeName'
//                             : 'Welcome to',
//                         textAlign: TextAlign.center,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 42,
//                           fontWeight: FontWeight.bold,
//                           fontFamily: 'serif',
//                           height: 1.15,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // =================================================================
//               // RIGHT - PROMOTIONS
//               // =================================================================
//
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: _promotionImages.isEmpty
//                       ? Container(
//                     color: _C.slate,
//                     alignment: Alignment.center,
//                     child: const Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           Icons.image_outlined,
//                           color: Colors.white54,
//                           size: 64,
//                         ),
//                         SizedBox(height: 12),
//                         Text(
//                           'No banners',
//                           style: TextStyle(
//                             color: Colors.white70,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                       : _Slideshow(
//                     urls: _promotionImages,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           // ====================================================================
//           // POWERED BY
//           // ====================================================================
//
//           if (hasStore)
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(12),
//                 alignment: Alignment.center,
//                 child: const Text(
//                   'Powered by Pinaka',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
//
// // ============================================================================
// // STORE LOGO
// // ============================================================================
//
// class _StoreLogo extends StatelessWidget {
//   final String? url;
//   final double width;
//
//   const _StoreLogo({
//     required this.url,
//     required this.width,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (url == null || url!.trim().isEmpty) {
//       return Icon(
//         Icons.storefront_rounded,
//         color: Colors.white,
//         size: width * 0.6,
//       );
//     }
//
//     return Image.network(
//       url!,
//       width: width,
//       fit: BoxFit.contain,
//       errorBuilder: (context, error, stackTrace) {
//         return Icon(
//           Icons.storefront_rounded,
//           color: Colors.white,
//           size: width * 0.6,
//         );
//       },
//     );
//   }
// }
//
// // ============================================================================
// // THANK YOU
// // ============================================================================
//
// class _ThankYouLayout extends StatelessWidget {
//   final DisplayState state;
//
//   const _ThankYouLayout({
//     super.key,
//     required this.state,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: _C.slate,
//       child: Row(
//         children: [
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(32),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text(
//                     '😊',
//                     style: TextStyle(
//                       fontSize: 84,
//                       fontFamily: 'serif',
//                       shadows: [
//                         Shadow(
//                           color: Colors.black,
//                           offset: Offset(2, 2),
//                           blurRadius: 4,
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   const Text(
//                     'Thank You!',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 40,
//                       fontFamily: 'serif',
//                       height: 1.3,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Please Visit Again',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 30,
//                       fontFamily: 'serif',
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Expanded(
//             child: _Slideshow(urls: state.slideshowUrls),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // CART LAYOUT
// // ============================================================================
//
// class _CustomerDisplayLayout extends StatefulWidget {
//   final DisplayState state;
//
//   const _CustomerDisplayLayout({
//     super.key,
//     required this.state,
//   });
//
//   @override
//   State<_CustomerDisplayLayout> createState() =>
//       _CustomerDisplayLayoutState();
// }
//
// class _CustomerDisplayLayoutState extends State<_CustomerDisplayLayout> {
//   late final TextEditingController _controller;
//
//   bool _keypadOpen = false;
//   bool _popupOpen = false;
//
//   // Sticky summary: once summaryEnabled=true for an order, keep panel
//   // until order changes or cart is empty.
//   bool _summaryLocked = false;
//   String? _lastSummaryOrderId;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = TextEditingController(text: widget.state.loyaltyContact);
//   }
//
//   @override
//   void didUpdateWidget(covariant _CustomerDisplayLayout oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     if (oldWidget.state.loyaltyContact != widget.state.loyaltyContact) {
//       _controller.text = widget.state.loyaltyContact;
//       _controller.selection = TextSelection.fromPosition(
//         TextPosition(offset: _controller.text.length),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   void _appendChar(String value) {
//     setState(() {
//       _controller.text += value;
//       _controller.selection = TextSelection.fromPosition(
//         TextPosition(offset: _controller.text.length),
//       );
//     });
//   }
//
//   void _backspace() {
//     if (_controller.text.isEmpty) return;
//     setState(() {
//       _controller.text =
//           _controller.text.substring(0, _controller.text.length - 1);
//       _controller.selection = TextSelection.fromPosition(
//         TextPosition(offset: _controller.text.length),
//       );
//     });
//   }
//
//   void _submit(DisplayProvider provider) {
//     final value = _controller.text.trim();
//     if (value.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Enter customer number'),
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//     setState(() => _popupOpen = true);
//     provider.submitLoyaltyContact(value);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<DisplayProvider>();
//     final state = provider.state;
//
//     // List shows products / payout / cashback only — NOT merchant discount
//     final listItems = _visibleCartItems(state.items);
//     final hasListItems = listItems.isNotEmpty;
//
//     // Sticky summary bookkeeping (uses full state.items for emptiness)
//     if (state.orderId != _lastSummaryOrderId) {
//       _summaryLocked = false;
//       _lastSummaryOrderId = state.orderId;
//     }
//     if (state.items.isEmpty) {
//       _summaryLocked = false;
//     }
//     if (state.summaryEnabled) {
//       _summaryLocked = true;
//     }
//     final bool showSummary =
//         (state.summaryEnabled || _summaryLocked) && state.items.isNotEmpty;
//
//     return Container(
//       color: _C.bodyBg,
//       padding: const EdgeInsets.all(8),
//       child: Stack(
//         children: [
//           Column(
//             children: [
//               _HeaderBar(state: state),
//               const SizedBox(height: 10),
//               Expanded(
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // ── LEFT ──────────────────────────────────────────
//                     Expanded(
//                       flex: 2,
//                       child: Padding(
//                         padding: const EdgeInsets.only(right: 10),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             _CustomerInfoCard(
//                               state: state,
//                               controller: _controller,
//                               unlocked: state.phoneInputUnlocked,
//                               onFieldTap: () {
//                                 if (!state.phoneInputUnlocked) return;
//                                 setState(() => _keypadOpen = true);
//                               },
//                               onAdd: () => _submit(provider),
//                             ),
//
//                             if (hasListItems) const _ItemsHeaderRow(),
//
//                             Expanded(
//                               child: !hasListItems
//                                   ? const _EmptyStateBox()
//                                   : ListView.builder(
//                                 padding: EdgeInsets.zero,
//                                 itemCount: listItems.length,
//                                 itemBuilder: (context, index) {
//                                   final item = listItems[index];
//                                   return _ItemRow(
//                                     key: ValueKey(
//                                       '${item.productId}_$index',
//                                     ),
//                                     item: item,
//                                     isLast:
//                                     index == listItems.length - 1,
//                                   );
//                                 },
//                               ),
//                             ),
//
//                             // Summary: merchant discount + coupon only here
//                             if (showSummary) _SummaryPanel(state: state),
//
//                             if (_keypadOpen)
//                               _CustomKeypad(
//                                 onChar: _appendChar,
//                                 onBackspace: _backspace,
//                                 onDone: () {
//                                   setState(() => _keypadOpen = false);
//                                 },
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     // ── RIGHT – slideshow ─────────────────────────────
//                     Expanded(
//                       flex: 2,
//                       child: Container(
//                         color: _C.slate,
//                         child: _Slideshow(urls: state.slideshowUrls),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//
//           if (_popupOpen)
//             _RedeemPopup(
//               fetching: provider.isFetchingPoints,
//               points: state.availablePoints,
//               onOk: () {
//                 provider.closeRedeemPopup();
//                 if (!mounted) return;
//                 setState(() => _popupOpen = false);
//               },
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // HEADER
// // ============================================================================
//
// class _HeaderBar extends StatelessWidget {
//   final DisplayState state;
//
//   const _HeaderBar({required this.state});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 60,
//       color: _C.headerBlue,
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 100,
//             height: 56,
//             child: _StoreLogo(url: state.storeLogoUrl, width: 100),
//           ),
//           Expanded(
//             child: state.storeName.isNotEmpty
//                 ? Text(
//               state.storeName,
//               textAlign: TextAlign.center,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             )
//                 : const SizedBox.shrink(),
//           ),
//           if (state.orderDate.isNotEmpty)
//             Text(
//               state.orderDate,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           if (state.orderDate.isNotEmpty && state.orderTime.isNotEmpty)
//             Container(
//               width: 2,
//               height: 18,
//               margin: const EdgeInsets.symmetric(horizontal: 10),
//               color: Colors.white,
//             ),
//           if (state.orderTime.isNotEmpty)
//             Text(
//               state.orderTime,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // CUSTOMER INFO CARD
// // ============================================================================
//
// class _CustomerInfoCard extends StatelessWidget {
//   final DisplayState state;
//   final TextEditingController controller;
//   final bool unlocked;
//   final VoidCallback onFieldTap;
//   final VoidCallback onAdd;
//
//   const _CustomerInfoCard({
//     required this.state,
//     required this.controller,
//     required this.unlocked,
//     required this.onFieldTap,
//     required this.onAdd,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 3,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Text(
//                 'Customer:',
//                 style: TextStyle(
//                   color: _C.accentBlue,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               SizedBox(
//                 width: 180,
//                 height: 40,
//                 child: TextField(
//                   controller: controller,
//                   enabled: unlocked,
//                   readOnly: true,
//                   onTap: onFieldTap,
//                   style: const TextStyle(
//                     color: Color(0xFF353535),
//                     fontSize: 18,
//                   ),
//                   decoration: InputDecoration(
//                     hintText: 'Enter phone or email',
//                     hintStyle: const TextStyle(
//                       color: Colors.grey,
//                       fontSize: 14,
//                     ),
//                     contentPadding:
//                     const EdgeInsets.symmetric(horizontal: 12),
//                     filled: true,
//                     fillColor:
//                     unlocked ? Colors.white : const Color(0xFFF2F2F2),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(6),
//                       borderSide: const BorderSide(color: _C.cardBorder),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               SizedBox(
//                 height: 48,
//                 child: ElevatedButton(
//                   onPressed: unlocked ? onAdd : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _C.accentBlue,
//                     disabledBackgroundColor:
//                     _C.accentBlue.withOpacity(0.4),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                   ),
//                   child: const Text(
//                     'Add',
//                     style: TextStyle(color: Colors.white, fontSize: 16),
//                   ),
//                 ),
//               ),
//               const Spacer(),
//               const Text(
//                 'Points:',
//                 style: TextStyle(
//                   color: _C.red,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 '${state.availablePoints}',
//                 style: const TextStyle(
//                   color: Color(0xFF353535),
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               const Text(
//                 'Order ID:',
//                 style: TextStyle(
//                   color: _C.accentBlue,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 state.orderId.isNotEmpty ? state.orderId : '—',
//                 style: const TextStyle(
//                   color: Color(0xFF353535),
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // ITEMS HEADER
// // ============================================================================
//
// class _ItemsHeaderRow extends StatelessWidget {
//   const _ItemsHeaderRow();
//
//   @override
//   Widget build(BuildContext context) {
//     const style = TextStyle(
//       color: Colors.white,
//       fontWeight: FontWeight.bold,
//       fontSize: 16,
//     );
//
//     return Container(
//       height: 48,
//       color: _C.headerBlue,
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: const Row(
//         children: [
//           Expanded(flex: 15, child: Text('Item Name', style: style)),
//           Expanded(
//             flex: 10,
//             child: Text(
//               'Qty × Price',
//               textAlign: TextAlign.center,
//               style: style,
//             ),
//           ),
//           Expanded(
//             flex: 8,
//             child: Text(
//               'Total',
//               textAlign: TextAlign.right,
//               style: style,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // ITEM ROW
// // ============================================================================
//
// class _ItemRow extends StatelessWidget {
//   final DisplayItem item;
//   final bool isLast;
//
//   const _ItemRow({
//     super.key,
//     required this.item,
//     required this.isLast,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final nameLower = item.name.toLowerCase();
//
//     final isSpecial =
//         nameLower == 'payout' || nameLower == 'cashback' || nameLower == 'coupon';
//
//     final isWeighted =
//         item.itemType.toLowerCase().contains('weighted') && item.weightQty > 0;
//
//     final String qtyPriceText;
//     if (isSpecial) {
//       qtyPriceText = '';
//     } else if (isWeighted) {
//       qtyPriceText =
//       '${item.weightQty.toStringAsFixed(3)} lb × ${_currency(item.unitPrice)}';
//     } else {
//       qtyPriceText = '${item.qty} × ${_currency(item.unitPrice)}';
//     }
//
//     return Column(
//       children: [
//         Container(
//           color: Colors.white,
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           child: Row(
//             children: [
//               Expanded(
//                 flex: 15,
//                 child: Text(
//                   item.name.length > 26
//                       ? '${item.name.substring(0, 26)}…'
//                       : item.name,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 flex: 10,
//                 child: Text(
//                   qtyPriceText,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(color: Colors.black54, fontSize: 18),
//                 ),
//               ),
//               Expanded(
//                 flex: 8,
//                 child: Text(
//                   _currency(item.total),
//                   textAlign: TextAlign.right,
//                   style: TextStyle(
//                     color: nameLower == 'payout' ? Colors.red : Colors.black,
//                     fontSize: 17,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         if (!isLast) const Divider(color: Colors.grey, height: 1),
//       ],
//     );
//   }
//
//   String _currency(double value) => '\$${value.toStringAsFixed(2)}';
// }
//
// // ============================================================================
// // EMPTY STATE
// // ============================================================================
//
// class _EmptyStateBox extends StatelessWidget {
//   const _EmptyStateBox();
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Container(
//         width: 320,
//         height: 240,
//         alignment: Alignment.center,
//         padding: const EdgeInsets.all(24),
//         child: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.shopping_cart_outlined, size: 140, color: Colors.black26),
//             SizedBox(height: 16),
//             Text(
//               'No items in the Order panel',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.black, fontSize: 22),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // DASHED DIVIDER
// // ============================================================================
//
// class _DashedDivider extends StatelessWidget {
//   final Color color;
//   final double dashWidth;
//   final double dashGap;
//   final double thickness;
//
//   const _DashedDivider({
//     this.color = const Color(0xFFCCCCCC),
//     this.dashWidth = 5,
//     this.dashGap = 4,
//     this.thickness = 1,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: thickness + 2,
//       width: double.infinity,
//       child: CustomPaint(
//         painter: _DashedLinePainter(
//           color: color,
//           dashWidth: dashWidth,
//           dashGap: dashGap,
//           thickness: thickness,
//         ),
//       ),
//     );
//   }
// }
//
// class _DashedLinePainter extends CustomPainter {
//   final Color color;
//   final double dashWidth;
//   final double dashGap;
//   final double thickness;
//
//   _DashedLinePainter({
//     required this.color,
//     required this.dashWidth,
//     required this.dashGap,
//     required this.thickness,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..strokeWidth = thickness;
//
//     double startX = 0;
//     final y = size.height / 2;
//
//     while (startX < size.width) {
//       canvas.drawLine(
//         Offset(startX, y),
//         Offset(startX + dashWidth, y),
//         paint,
//       );
//       startX += dashWidth + dashGap;
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
//     return oldDelegate.color != color ||
//         oldDelegate.dashWidth != dashWidth ||
//         oldDelegate.dashGap != dashGap ||
//         oldDelegate.thickness != thickness;
//   }
// }
//
// // ============================================================================
// // SUMMARY PANEL (merchant discount + coupon only here)
// // ============================================================================
//
// class _SummaryPanel extends StatefulWidget {
//   final DisplayState state;
//
//   const _SummaryPanel({required this.state});
//
//   @override
//   State<_SummaryPanel> createState() => _SummaryPanelState();
// }
//
// class _SummaryPanelState extends State<_SummaryPanel> {
//   bool _expanded = true;
//
//   @override
//   Widget build(BuildContext context) {
//     final state = widget.state;
//
//     final double coupon = state.discount > 0 ? state.discount : 0.0;
//     final double net = state.netTotal > 0
//         ? state.netTotal
//         : (state.subtotal - coupon - state.merchantDiscount);
//     final double netPayable = state.total;
//
//     // Total items excludes merchant-discount / coupon lines
//     final int totalItems = state.items.fold<int>(0, (sum, item) {
//       if (_isDiscountLineItem(item)) return sum;
//       return sum + item.qty;
//     });
//
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(top: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: _C.cardBorder),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           AnimatedSize(
//             duration: const Duration(milliseconds: 250),
//             curve: Curves.easeInOut,
//             child: _expanded
//                 ? Padding(
//               padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   _row(
//                     'Gross Total',
//                     _currency(state.subtotal),
//                     _C.textDark,
//                     20,
//                     FontWeight.bold,
//                   ),
//                   if (state.merchantDiscount > 0)
//                     _row(
//                       'Merchant Discount',
//                       '-${_currency(state.merchantDiscount)}',
//                       _C.blue2,
//                       16,
//                       FontWeight.w600,
//                     ),
//                   if (coupon > 0)
//                     _row(
//                       'Coupon',
//                       '-${_currency(coupon)}',
//                       _C.green,
//                       16,
//                       FontWeight.w600,
//                     ),
//                   const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 6),
//                     child: _DashedDivider(),
//                   ),
//                   _row(
//                     'Net Total',
//                     _currency(net),
//                     _C.textMid,
//                     18,
//                     FontWeight.bold,
//                   ),
//                   _row(
//                     'Tax',
//                     _currency(state.tax),
//                     _C.textGray,
//                     16,
//                     FontWeight.normal,
//                   ),
//                   if (state.redeemedAmount > 0)
//                     _row(
//                       'Redeemed Amount',
//                       '-${_currency(state.redeemedAmount)}',
//                       _C.purple,
//                       16,
//                       FontWeight.normal,
//                     ),
//                   if (state.cashbackFee > 0)
//                     _row(
//                       'Cashback Fee',
//                       _currency(state.cashbackFee),
//                       _C.teal,
//                       16,
//                       FontWeight.normal,
//                     ),
//                   const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 6),
//                     child: _DashedDivider(),
//                   ),
//                   _row(
//                     'Net Payable',
//                     _currency(netPayable),
//                     _C.textDark,
//                     22,
//                     FontWeight.w800,
//                   ),
//                 ],
//               ),
//             )
//                 : const SizedBox.shrink(),
//           ),
//           GestureDetector(
//             behavior: HitTestBehavior.opaque,
//             onTap: () => setState(() => _expanded = !_expanded),
//             child: Container(
//               color: _C.totalsBar,
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Total Items : $totalItems',
//                       style: const TextStyle(
//                         color: _C.textDark,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   Text(
//                     'Net Payable : ${_currency(netPayable)}',
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Icon(
//                     _expanded
//                         ? Icons.keyboard_arrow_down
//                         : Icons.keyboard_arrow_up,
//                     color: Colors.black87,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _row(
//       String label,
//       String value,
//       Color color,
//       double size,
//       FontWeight weight,
//       ) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
//       child: Row(
//         children: [
//           Expanded(
//             child: Text(
//               label,
//               style: TextStyle(
//                 color: color,
//                 fontSize: size,
//                 fontWeight: weight,
//               ),
//             ),
//           ),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: size,
//               fontWeight: weight,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _currency(double value) => '\$${value.toStringAsFixed(2)}';
// }
//
// // ============================================================================
// // KEYPAD
// // ============================================================================
//
// class _CustomKeypad extends StatelessWidget {
//   final void Function(String) onChar;
//   final VoidCallback onBackspace;
//   final VoidCallback onDone;
//
//   const _CustomKeypad({
//     required this.onChar,
//     required this.onBackspace,
//     required this.onDone,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final keys = [
//       '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
//       '@', '.', 'Space', '⌫', 'Done',
//     ];
//
//     return Container(
//       margin: const EdgeInsets.only(top: 8),
//       color: Colors.white,
//       padding: const EdgeInsets.all(4),
//       child: GridView.count(
//         crossAxisCount: 6,
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         mainAxisSpacing: 4,
//         crossAxisSpacing: 4,
//         childAspectRatio: 1.6,
//         children: keys.map((key) {
//           final isSpace = key == 'Space';
//           final isBackspace = key == '⌫';
//           final isDone = key == 'Done';
//
//           return Material(
//             color: isDone ? _C.accentBlue : Colors.grey.shade200,
//             child: InkWell(
//               onTap: () {
//                 if (isBackspace) {
//                   onBackspace();
//                 } else if (isDone) {
//                   onDone();
//                 } else if (isSpace) {
//                   onChar(' ');
//                 } else {
//                   onChar(key);
//                 }
//               },
//               child: Center(
//                 child: isBackspace
//                     ? const Icon(Icons.backspace_outlined, size: 18)
//                     : Text(
//                   key,
//                   style: TextStyle(
//                     color: isDone ? Colors.white : Colors.black87,
//                     fontSize: isSpace ? 14 : 18,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }
//
// // ============================================================================
// // REDEEM POPUP
// // ============================================================================
//
// class _RedeemPopup extends StatelessWidget {
//   final bool fetching;
//   final int points;
//   final VoidCallback onOk;
//
//   const _RedeemPopup({
//     required this.fetching,
//     required this.points,
//     required this.onOk,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Positioned.fill(
//       child: Container(
//         color: const Color(0x80000000),
//         alignment: Alignment.center,
//         child: Container(
//           width: 400,
//           padding: const EdgeInsets.all(24),
//           color: Colors.white,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text(
//                 'Redeem Points',
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 fetching
//                     ? 'Fetching points...'
//                     : 'Available Points: $points',
//                 style: const TextStyle(
//                   color: Color(0xFF333333),
//                   fontSize: 18,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: 120,
//                 child: ElevatedButton(
//                   onPressed: fetching ? null : onOk,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _C.accentBlue,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                   ),
//                   child: const Text(
//                     'OK',
//                     style: TextStyle(color: Colors.white),
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
//
// // ============================================================================
// // MESSAGE VIEW
// // ============================================================================
//
// class _MessageView extends StatelessWidget {
//   final String screen;
//   final double? total;
//   final String? message;
//
//   const _MessageView({
//     super.key,
//     required this.screen,
//     this.total,
//     this.message,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final config = switch (screen) {
//       'SUCCESS' => (
//       title: 'Thank you!',
//       icon: Icons.check_circle_rounded,
//       color: _C.green,
//       ),
//       'REFUND' => (
//       title: 'Refund',
//       icon: Icons.currency_exchange_rounded,
//       color: _C.blue2,
//       ),
//       _ => (
//       title: 'Total Due',
//       icon: Icons.receipt_long_rounded,
//       color: _C.accentBlue,
//       ),
//     };
//
//     return Container(
//       color: _C.bodyBg,
//       alignment: Alignment.center,
//       child: Padding(
//         padding: const EdgeInsets.all(40),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 105,
//               height: 105,
//               decoration: BoxDecoration(
//                 color: config.color.withOpacity(0.12),
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: config.color.withOpacity(0.4),
//                   width: 2,
//                 ),
//               ),
//               child: Icon(config.icon, color: config.color, size: 56),
//             ),
//             const SizedBox(height: 24),
//             Text(
//               config.title,
//               style: TextStyle(
//                 color: config.color,
//                 fontSize: 36,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             if (total != null) ...[
//               const SizedBox(height: 18),
//               Text(
//                 '\$${total!.toStringAsFixed(2)}',
//                 style: TextStyle(
//                   color: config.color,
//                   fontSize: 56,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//             ],
//             if (message != null && message!.trim().isNotEmpty) ...[
//               const SizedBox(height: 18),
//               Text(
//                 message!,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(color: _C.textMid, fontSize: 17),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }


//////==========


import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pinaka_pos_customer_display/screens/qr_connect_widgets.dart';
import 'package:provider/provider.dart';

import '../models/display_state.dart';
import '../providers/display_provider.dart';
import 'package:http/http.dart' as http;



class _C {
  static const bodyBg = Color(0xFFE9EEF6);
  static const headerBlue = Color(0xFF1F3A68);
  static const accentBlue = Color(0xFF003A82);
  static const textDark = Color(0xFF212121);
  static const textMid = Color(0xFF353535);
  static const textGray = Color(0xFF808080);
  static const green = Color(0xFF036A07);
  static const blue2 = Color(0xFF007BFF);
  static const purple = Color(0xFF9C27B0);
  static const teal = Color(0xFF55CBCD);
  static const totalsBar = Color(0xFFFFA9A9);
  static const red = Color(0xFFE20000);
  static const slate = Color(0xFF3D506E);
  static const cardBorder = Color(0xFFDDE3EC);
}

// ============================================================================
// CUSTOMER DISPLAY SCREEN
// ============================================================================

class CustomerDisplayScreen extends StatefulWidget {
  const CustomerDisplayScreen({super.key});

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  /// After MQTT IDLE/WELCOME, stay on Welcome until a real new CART arrives.
  bool _forceWelcome = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<DisplayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final screen = state.screen.toUpperCase().trim();

        // Real order = has a proper orderId (even if items is empty)
        final hasRealOrder = state.orderId.trim().isNotEmpty &&
            state.orderId.trim() != '0';

        // Determine whether to force the Welcome layout
        if (screen == 'IDLE' || screen == 'WELCOME') {
          _forceWelcome = true;
        } else if (screen == 'CART' || screen == 'PAYMENT') {
          // Show CART layout only if there is a real order; otherwise force Welcome
          _forceWelcome = !hasRealOrder;
        } else if (screen == 'THANK_YOU' ||
            screen == 'SUCCESS' ||
            screen == 'REFUND') {
          _forceWelcome = false;
        } else {
          // Fallback: treat unknown screens as Welcome
          _forceWelcome = true;
        }

        debugPrint(
          'CUSTOMER DISPLAY -> screen=${state.screen}, '
              'items=${state.items.length}, orderId=${state.orderId}, '
              'forceWelcome=$_forceWelcome, store=${state.storeName}',
        );

        return Scaffold(
          backgroundColor: _C.slate,
          body: SafeArea(
            child: _buildScreen(provider, state, screen),
          ),
        );
      },
    );
  }

  Widget _buildScreen(
      DisplayProvider provider,
      DisplayState state,
      String screen,
      ) {
    // Completed order → Welcome (store name), never old cart
    if (_forceWelcome &&
        screen != 'THANK_YOU' &&
        screen != 'SUCCESS' &&
        screen != 'REFUND') {
      return _WelcomeLayout(
        key: const ValueKey('WELCOME_FORCED'),
        state: state,
      );
    }

    switch (screen) {
      case 'WELCOME':
        return _WelcomeLayout(
          key: const ValueKey('WELCOME'),
          state: state,
        );

      case 'CART':
      case 'PAYMENT':
        return _CustomerDisplayLayout(
          key: const ValueKey('CART'),
          state: state,
        );

      case 'THANK_YOU':
        return _ThankYouLayout(
          key: const ValueKey('THANK_YOU'),
          state: state,
        );

      case 'SUCCESS':
      case 'REFUND':
        return _MessageView(
          key: ValueKey(state.screen),
          screen: state.screen,
          total: state.total,
          message: state.message,
        );

      case 'IDLE':
      default:
        return _WelcomeLayout(
          key: const ValueKey('IDLE'),
          state: state,
        );
    }
  }
}

// ============================================================================
// HELPERS – hide discount lines from items list (summary only)
// ============================================================================

bool _isDiscountLineItem(DisplayItem item) {
  final name = item.name.toLowerCase().trim();
  final type = item.itemType.toLowerCase();

  if (type.contains('discount') || type.contains('merchant')) {
    return true;
  }
  if (name.contains('merchant discount') ||
      name == 'discount' ||
      name.contains('order discount')) {
    return true;
  }
  // Coupon as a cart line belongs only in summary
  if (name == 'coupon' || type.contains('coupon')) {
    return true;
  }
  return false;
}

List<DisplayItem> _visibleCartItems(List<DisplayItem> items) {
  return items.where((item) => !_isDiscountLineItem(item)).toList();
}

// ============================================================================
// PROMOTION IMAGE HELPERS (shared by Welcome / Cart / ThankYou)
// ============================================================================

String _cleanBaseUrl(String value) {
  var result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String _resolveUrl(String url, String? baseUrl) {
  final value = url.trim();
  if (value.isEmpty) return '';

  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('file://') ||
      value.startsWith('data:')) {
    return value;
  }

  if (baseUrl == null || baseUrl.trim().isEmpty) {
    return value;
  }

  final base = _cleanBaseUrl(baseUrl);
  if (value.startsWith('/')) {
    return '$base$value';
  }
  return '$base/$value';
}

List<String> _resolveUrls(List<String> urls, String? baseUrl) {
  final result = <String>[];
  final seen = <String>{};
  for (final url in urls) {
    final resolved = _resolveUrl(url, baseUrl);
    if (resolved.isEmpty) continue;
    if (seen.add(resolved)) {
      result.add(resolved);
    }
  }
  return result;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _extractPromotionImages(dynamic data) {
  final result = <String>[];

  void absorb(dynamic value) {
    if (value == null) return;

    if (value is List) {
      for (final item in value) {
        if (item is String) {
          final text = item.trim();
          if (text.isNotEmpty) result.add(text);
        } else if (item is Map) {
          final url = item['url'] ??
              item['src'] ??
              item['image'] ??
              item['image_url'] ??
              item['imageUrl'] ??
              item['promotion_image'] ??
              item['promotionImage'] ??
              item['promotion_image_url'] ??
              item['promotionImageUrl'] ??
              item['banner_url'] ??
              item['bannerUrl'] ??
              item['path'];
          if (url != null) {
            final text = url.toString().trim();
            if (text.isNotEmpty) result.add(text);
          }
        }
      }
      return;
    }

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return;

      if (text.startsWith('[') || text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          absorb(decoded);
          return;
        } catch (_) {}
      }

      if (text.contains(',')) {
        for (final part in text.split(',')) {
          final item = part.trim();
          if (item.isNotEmpty) result.add(item);
        }
      } else {
        result.add(text);
      }
      return;
    }

    if (value is Map) {
      const keys = [
        'promotion_images',
        'promotionImages',
        'promotion_image',
        'promotionImage',
        'promotion_image_urls',
        'promotionImageUrls',
        'images',
        'image_urls',
        'imageUrls',
        'banners',
        'banner_urls',
        'bannerUrls',
        'slides',
        'data',
        'results',
        'items',
      ];
      for (final key in keys) {
        if (value.containsKey(key)) {
          absorb(value[key]);
        }
      }
      return;
    }
  }

  absorb(data);
  return result;
}

/// Shared promo cache across Welcome / Cart / ThankYou.
/// Caches successes AND failures so MQTT rebuilds do not re-hit the network.
class _PromoImageCache {
  static String? _baseUrl;
  static List<String> _images = const [];
  static DateTime? _fetchedAt;
  static bool _failed = false;
  static Future<List<String>>? _inFlight;

  /// Success stays fresh longer; failure is short so DNS can recover.
  static const _successTtl = Duration(minutes: 10);
  static const _failureTtl = Duration(seconds: 45);

  static bool _isFresh(String cleanBase) {
    if (_baseUrl != cleanBase || _fetchedAt == null) return false;
    final age = DateTime.now().difference(_fetchedAt!);
    return age <= (_failed ? _failureTtl : _successTtl);
  }

  /// Returns cached list (may be empty on remembered failure) if still fresh.
  static List<String>? getIfFresh(String baseUrl) {
    final clean = _cleanBaseUrl(baseUrl);
    if (!_isFresh(clean)) return null;
    return List<String>.from(_images);
  }

  static void putSuccess(String baseUrl, List<String> images) {
    _baseUrl = _cleanBaseUrl(baseUrl);
    _images = List<String>.from(images);
    _fetchedAt = DateTime.now();
    _failed = false;
  }

  static void putFailure(String baseUrl) {
    _baseUrl = _cleanBaseUrl(baseUrl);
    // Keep previous good images if any; only mark failure time
    _fetchedAt = DateTime.now();
    _failed = true;
  }

  static void clear() {
    _baseUrl = null;
    _images = const [];
    _fetchedAt = null;
    _failed = false;
    _inFlight = null;
  }
}

Future<List<String>> _loadPromotionImagesFromApi(String storeBaseUrl) async {
  final cleanBaseUrl = _cleanBaseUrl(storeBaseUrl);

  final cached = _PromoImageCache.getIfFresh(cleanBaseUrl);
  if (cached != null) {
    debugPrint(
      'PROMO -> cache hit (${cached.length} images, failed=${_PromoImageCache._failed})',
    );
    return cached;
  }

  // Coalesce concurrent callers (Welcome + another layout mounting together)
  if (_PromoImageCache._inFlight != null) {
    debugPrint('PROMO -> awaiting in-flight request');
    return _PromoImageCache._inFlight!;
  }

  final future = () async {
    final apiUrl =
        '$cleanBaseUrl/wp-content/plugins/pinaka-pos-wp/promotion_images.php';

    debugPrint('PROMO -> Calling promotion API: $apiUrl');

    try {
      final response = await http
          .get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      )
          .timeout(const Duration(seconds: 8));

      debugPrint('PROMO -> status=${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _PromoImageCache.putFailure(cleanBaseUrl);
        return <String>[];
      }

      if (response.body.trim().isEmpty) {
        _PromoImageCache.putFailure(cleanBaseUrl);
        return <String>[];
      }

      final decoded = jsonDecode(response.body);
      final images = _extractPromotionImages(decoded);
      final resolved = _resolveUrls(images, cleanBaseUrl);

      debugPrint('PROMO -> images=${resolved.length}');
      if (resolved.isNotEmpty) {
        _PromoImageCache.putSuccess(cleanBaseUrl, resolved);
      } else {
        _PromoImageCache.putFailure(cleanBaseUrl);
      }
      return resolved;
    } catch (e, stackTrace) {
      debugPrint('PROMO -> API error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _PromoImageCache.putFailure(cleanBaseUrl);
      return <String>[];
    } finally {
      _PromoImageCache._inFlight = null;
    }
  }();

  _PromoImageCache._inFlight = future;
  return future;
}

/// Shared widget: loads promotion banners once, keeps last good set,
/// falls back to MQTT slideshowUrls. Does NOT re-fetch on every MQTT tick.
class _PromotionSlideshow extends StatefulWidget {
  final DisplayState state;

  const _PromotionSlideshow({
    super.key,
    required this.state,
  });

  @override
  State<_PromotionSlideshow> createState() => _PromotionSlideshowState();
}

class _PromotionSlideshowState extends State<_PromotionSlideshow> {
  List<String> _images = [];
  bool _loading = true;
  bool _fetchStarted = false;
  String? _lastBaseUrl;
  List<String> _lastMqttUrls = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant _PromotionSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState = oldWidget.state;
    final newState = widget.state;

    final baseChanged =
        (oldState.storeBaseUrl ?? '') != (newState.storeBaseUrl ?? '');
    final bannersChanged =
    !_sameStringList(oldState.slideshowUrls, newState.slideshowUrls);

    if (baseChanged) {
      _PromoImageCache.clear();
      _fetchStarted = false;
      _lastBaseUrl = null;
      _bootstrap();
      return;
    }

    // MQTT often republishes empty slideshowUrls on IDLE — do not wipe
    // banners we already have. Only adopt MQTT list if it has content
    // and differs from what we show.
    if (bannersChanged) {
      final storeBaseUrl = newState.storeBaseUrl?.trim().isNotEmpty == true
          ? newState.storeBaseUrl!.trim()
          : null;
      final mqttImages = _resolveUrls(newState.slideshowUrls, storeBaseUrl);

      if (mqttImages.isNotEmpty && !_sameStringList(mqttImages, _images)) {
        // Prefer API cache if we already have it; otherwise take MQTT
        final cached = storeBaseUrl != null
            ? _PromoImageCache.getIfFresh(storeBaseUrl)
            : null;
        final next = (cached != null && cached.isNotEmpty)
            ? cached
            : mqttImages;
        if (!_sameStringList(next, _images)) {
          setState(() {
            _images = next;
            _loading = false;
            _lastMqttUrls = mqttImages;
            _lastBaseUrl = storeBaseUrl;
          });
        } else {
          _lastMqttUrls = mqttImages;
        }
      } else {
        // Empty MQTT update — keep current banners, just remember mqtt list
        _lastMqttUrls = mqttImages;
      }
    }
  }

  void _bootstrap() {
    final state = widget.state;
    final storeBaseUrl = state.storeBaseUrl?.trim().isNotEmpty == true
        ? state.storeBaseUrl!.trim()
        : null;
    final mqttImages = _resolveUrls(state.slideshowUrls, storeBaseUrl);

    // 1) Instant cache / previous success
    if (storeBaseUrl != null) {
      final cached = _PromoImageCache.getIfFresh(storeBaseUrl);
      if (cached != null && cached.isNotEmpty) {
        _images = cached;
        _loading = false;
        _lastBaseUrl = storeBaseUrl;
        _lastMqttUrls = mqttImages;
        // Still schedule a silent refresh only if cache was a failure
        // and TTL expired — getIfFresh already handles TTL.
        return;
      }
    }

    // 2) MQTT fallback immediately (no spinner if we have URLs)
    if (mqttImages.isNotEmpty) {
      _images = mqttImages;
      _loading = false;
      _lastBaseUrl = storeBaseUrl;
      _lastMqttUrls = mqttImages;
    } else {
      _loading = _images.isEmpty;
      _lastBaseUrl = storeBaseUrl;
      _lastMqttUrls = mqttImages;
    }

    // 3) One network attempt (coalesced + cached on failure)
    if (storeBaseUrl != null && storeBaseUrl.isNotEmpty && !_fetchStarted) {
      _fetchStarted = true;
      _fetchApiInBackground(storeBaseUrl, mqttImages);
    }
  }

  Future<void> _fetchApiInBackground(
      String storeBaseUrl,
      List<String> mqttImages,
      ) async {
    final promotionImages = await _loadPromotionImagesFromApi(storeBaseUrl);
    if (!mounted) return;

    final finalImages =
    promotionImages.isNotEmpty ? promotionImages : mqttImages;

    // Never replace a non-empty slideshow with empty unless we truly have nothing
    if (finalImages.isEmpty && _images.isNotEmpty) {
      setState(() {
        _loading = false;
        _lastBaseUrl = storeBaseUrl;
        _lastMqttUrls = mqttImages;
      });
      return;
    }

    if (_sameStringList(finalImages, _images) && !_loading) {
      _lastBaseUrl = storeBaseUrl;
      _lastMqttUrls = mqttImages;
      return;
    }

    setState(() {
      if (finalImages.isNotEmpty) {
        _images = finalImages;
      }
      _loading = false;
      _lastBaseUrl = storeBaseUrl;
      _lastMqttUrls = mqttImages;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show spinner the first time with zero images
    if (_loading && _images.isEmpty) {
      return Container(
        color: _C.slate,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white54),
      );
    }

    return _Slideshow(urls: _images);
  }
}

// ============================================================================
// SLIDESHOW
// ============================================================================

class _Slideshow extends StatefulWidget {
  final List<String> urls;

  const _Slideshow({
    required this.urls,
  });

  @override
  State<_Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<_Slideshow> {
  int _index = 0;
  Timer? _timer;

  List<String> get _urls {
    return widget.urls.where((u) => u.trim().isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _Slideshow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_listEquals(oldWidget.urls, widget.urls)) {
      _index = 0;
      _restart();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _restart() {
    _timer?.cancel();
    final urls = _urls;
    if (urls.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % urls.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;

    if (urls.isEmpty) {
      return Container(
        color: _C.slate,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text(
              'No banners',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final safeIndex = _index.clamp(0, urls.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Image.network(
            urls[safeIndex],
            key: ValueKey('${urls[safeIndex]}#$safeIndex'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: _C.slate,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white54),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                'Slideshow image failed: ${urls[safeIndex]} -> $error',
              );
              return Container(
                color: _C.slate,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              );
            },
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == safeIndex;
                return Container(
                  width: active ? 10 : 7,
                  height: active ? 10 : 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.white38,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// WELCOME
// ============================================================================

class _WelcomeLayout extends StatefulWidget {
  final DisplayState state;

  const _WelcomeLayout({
    super.key,
    required this.state,
  });

  @override
  State<_WelcomeLayout> createState() => _WelcomeLayoutState();
}

class _WelcomeLayoutState extends State<_WelcomeLayout> {
  String _storeName = '';
  String? _storeLogoUrl;

  bool _loading = true;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _loadWelcomeData();
  }

  @override
  void didUpdateWidget(covariant _WelcomeLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState = oldWidget.state;
    final newState = widget.state;

    final brandingChanged =
        oldState.storeName != newState.storeName ||
            oldState.storeLogoUrl != newState.storeLogoUrl ||
            oldState.storeBaseUrl != newState.storeBaseUrl;

    if (brandingChanged) {
      debugPrint('WELCOME -> DisplayState branding changed. Reloading.');
      _loadWelcomeData();
    }
  }

  Future<void> _loadWelcomeData() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final state = widget.state;

      final storeName = state.storeName.trim();
      final storeLogoUrl = state.storeLogoUrl?.trim().isNotEmpty == true
          ? state.storeLogoUrl!.trim()
          : null;

      if (!mounted) return;

      setState(() {
        _storeName = storeName;
        _storeLogoUrl = storeLogoUrl;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('WELCOME -> Failed loading welcome data: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final state = widget.state;
      setState(() {
        _storeName = state.storeName.trim();
        _storeLogoUrl = state.storeLogoUrl?.trim().isNotEmpty == true
            ? state.storeLogoUrl!.trim()
            : null;
        _loading = false;
      });
    }
  }

  Future<void> _handleReconnect() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    try {
      await Provider.of<DisplayProvider>(context, listen: false).reconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconnected to POS')),
      );
    } catch (e) {
      debugPrint('WELCOME -> Reconnect failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconnect failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _handleScanQr() async {
    final result = await Navigator.of(context).push<CfdConnectionPayload>(
      MaterialPageRoute(builder: (_) => const QrConnectScannerPage()),
    );
    if (result == null || !mounted) return;

    try {
      await Provider.of<DisplayProvider>(context, listen: false)
          .connectWithScannedConfig(
        brokerIp: result.brokerIp,
        brokerPort: result.brokerPort,
        merchantId: result.merchantId,
        storeId: result.storeId,
        terminalId: result.terminalId,
        brokerUsername: result.brokerUsername,
        brokerToken: result.brokerToken,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to POS successfully')),
      );
    } catch (e) {
      debugPrint('WELCOME -> Connect from QR failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect using scanned QR code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStore = _storeName.isNotEmpty;

    if (_loading && !hasStore && _storeLogoUrl == null) {
      return Container(
        color: _C.slate,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white54,
                      size: 90,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _PromotionSlideshow(state: widget.state),
            ),
          ],
        ),
      );
    }

    return Container(
      color: _C.slate,
      child: Stack(
        children: [
          Row(
            children: [
              // Left side: branding + connection icons
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StoreLogo(
                        url: _storeLogoUrl,
                        width: 150,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        hasStore
                            ? 'Welcome to $_storeName'
                            : 'Welcome to Pinaka',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      WelcomeConnectionIcons(
                        onReconnect: _handleReconnect,
                        onScanQr: _handleScanQr,
                        isReconnecting: _reconnecting,
                      ),
                    ],
                  ),
                ),
              ),

              // Right side: promotion slideshow (API + MQTT fallback)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _PromotionSlideshow(state: widget.state),
                ),
              ),
            ],
          ),

          // Powered by
          if (hasStore)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                child: const Text(
                  'Powered by Pinaka',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ============================================================================
// STORE LOGO
// ============================================================================

class _StoreLogo extends StatelessWidget {
  final String? url;
  final double width;

  const _StoreLogo({
    required this.url,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: width * 0.6,
      );
    }

    return Image.network(
      url!,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: width * 0.6,
        );
      },
    );
  }
}

// ============================================================================
// THANK YOU
// ============================================================================

class _ThankYouLayout extends StatelessWidget {
  final DisplayState state;

  const _ThankYouLayout({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.slate,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '😊',
                    style: TextStyle(
                      fontSize: 84,
                      fontFamily: 'serif',
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Thank You!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontFamily: 'serif',
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please Visit Again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Promotion banners (same as Welcome)
          Expanded(
            child: _PromotionSlideshow(state: state),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CART LAYOUT
// ============================================================================

class _CustomerDisplayLayout extends StatefulWidget {
  final DisplayState state;

  const _CustomerDisplayLayout({
    super.key,
    required this.state,
  });

  @override
  State<_CustomerDisplayLayout> createState() =>
      _CustomerDisplayLayoutState();
}

class _CustomerDisplayLayoutState extends State<_CustomerDisplayLayout> {
  late final TextEditingController _controller;

  bool _keypadOpen = false;
  bool _popupOpen = false;

  // Sticky summary: once summaryEnabled=true for an order, keep panel
  // until order changes or cart is empty.
  bool _summaryLocked = false;
  String? _lastSummaryOrderId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.loyaltyContact);
  }

  @override
  void didUpdateWidget(covariant _CustomerDisplayLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.loyaltyContact != widget.state.loyaltyContact) {
      _controller.text = widget.state.loyaltyContact;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _appendChar(String value) {
    setState(() {
      _controller.text += value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _backspace() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _controller.text =
          _controller.text.substring(0, _controller.text.length - 1);
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _submit(DisplayProvider provider) {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter customer number'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _popupOpen = true);
    provider.submitLoyaltyContact(value);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisplayProvider>();
    final state = provider.state;

    // List shows products / payout / cashback only — NOT merchant discount
    final listItems = _visibleCartItems(state.items);
    final hasListItems = listItems.isNotEmpty;

    // Sticky summary bookkeeping (uses full state.items for emptiness)
    if (state.orderId != _lastSummaryOrderId) {
      _summaryLocked = false;
      _lastSummaryOrderId = state.orderId;
    }
    if (state.items.isEmpty) {
      _summaryLocked = false;
    }
    if (state.summaryEnabled) {
      _summaryLocked = true;
    }
    final bool showSummary =
        (state.summaryEnabled || _summaryLocked) && state.items.isNotEmpty;

    return Container(
      color: _C.bodyBg,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            children: [
              _HeaderBar(state: state),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── LEFT ──────────────────────────────────────────
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CustomerInfoCard(
                              state: state,
                              controller: _controller,
                              unlocked: state.phoneInputUnlocked,
                              onFieldTap: () {
                                if (!state.phoneInputUnlocked) return;
                                setState(() => _keypadOpen = true);
                              },
                              onAdd: () => _submit(provider),
                            ),

                            if (hasListItems) const _ItemsHeaderRow(),

                            Expanded(
                              child: !hasListItems
                                  ? const _EmptyStateBox()
                                  : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: listItems.length,
                                itemBuilder: (context, index) {
                                  final item = listItems[index];
                                  return _ItemRow(
                                    key: ValueKey(
                                      '${item.productId}_$index',
                                    ),
                                    item: item,
                                    isLast:
                                    index == listItems.length - 1,
                                  );
                                },
                              ),
                            ),

                            // Summary: merchant discount + coupon only here
                            if (showSummary) _SummaryPanel(state: state),

                            if (_keypadOpen)
                              _CustomKeypad(
                                onChar: _appendChar,
                                onBackspace: _backspace,
                                onDone: () {
                                  setState(() => _keypadOpen = false);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── RIGHT – promotion slideshow (API + MQTT fallback) ─
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: _C.slate,
                        child: _PromotionSlideshow(state: state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_popupOpen)
            _RedeemPopup(
              fetching: provider.isFetchingPoints,
              points: state.availablePoints,
              onOk: () {
                provider.closeRedeemPopup();
                if (!mounted) return;
                setState(() => _popupOpen = false);
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _HeaderBar extends StatelessWidget {
  final DisplayState state;

  const _HeaderBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: _C.headerBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 56,
            child: _StoreLogo(url: state.storeLogoUrl, width: 100),
          ),
          Expanded(
            child: state.storeName.isNotEmpty
                ? Text(
              state.storeName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
                : const SizedBox.shrink(),
          ),
          if (state.orderDate.isNotEmpty)
            Text(
              state.orderDate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (state.orderDate.isNotEmpty && state.orderTime.isNotEmpty)
            Container(
              width: 2,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white,
            ),
          if (state.orderTime.isNotEmpty)
            Text(
              state.orderTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMER INFO CARD
// ============================================================================

class _CustomerInfoCard extends StatelessWidget {
  final DisplayState state;
  final TextEditingController controller;
  final bool unlocked;
  final VoidCallback onFieldTap;
  final VoidCallback onAdd;

  const _CustomerInfoCard({
    required this.state,
    required this.controller,
    required this.unlocked,
    required this.onFieldTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Customer:',
                style: TextStyle(
                  color: _C.accentBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                height: 40,
                child: TextField(
                  controller: controller,
                  enabled: unlocked,
                  readOnly: true,
                  onTap: onFieldTap,
                  style: const TextStyle(
                    color: Color(0xFF353535),
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter phone or email',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor:
                    unlocked ? Colors.white : const Color(0xFFF2F2F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: _C.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: unlocked ? onAdd : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accentBlue,
                    disabledBackgroundColor:
                    _C.accentBlue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Points:',
                style: TextStyle(
                  color: _C.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${state.availablePoints}',
                style: const TextStyle(
                  color: Color(0xFF353535),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Order ID:',
                style: TextStyle(
                  color: _C.accentBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.orderId.isNotEmpty ? state.orderId : '—',
                style: const TextStyle(
                  color: Color(0xFF353535),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ITEMS HEADER
// ============================================================================

class _ItemsHeaderRow extends StatelessWidget {
  const _ItemsHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    return Container(
      height: 48,
      color: _C.headerBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Row(
        children: [
          Expanded(flex: 15, child: Text('Item Name', style: style)),
          Expanded(
            flex: 10,
            child: Text(
              'Qty × Price',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              'Total',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ITEM ROW
// ============================================================================

class _ItemRow extends StatelessWidget {
  final DisplayItem item;
  final bool isLast;

  const _ItemRow({
    super.key,
    required this.item,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final nameLower = item.name.toLowerCase();

    final isSpecial =
        nameLower == 'payout' || nameLower == 'cashback' || nameLower == 'coupon';

    final isWeighted =
        item.itemType.toLowerCase().contains('weighted') && item.weightQty > 0;

    final String qtyPriceText;
    if (isSpecial) {
      qtyPriceText = '';
    } else if (isWeighted) {
      qtyPriceText =
      '${item.weightQty.toStringAsFixed(3)} lb × ${_currency(item.unitPrice)}';
    } else {
      qtyPriceText = '${item.qty} × ${_currency(item.unitPrice)}';
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 15,
                child: Text(
                  item.name.length > 26
                      ? '${item.name.substring(0, 26)}…'
                      : item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  qtyPriceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 18),
                ),
              ),
              Expanded(
                flex: 8,
                child: Text(
                  _currency(item.total),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: nameLower == 'payout' ? Colors.red : Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: Colors.grey, height: 1),
      ],
    );
  }

  String _currency(double value) => '\$${value.toStringAsFixed(2)}';
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyStateBox extends StatelessWidget {
  const _EmptyStateBox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 240,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 140, color: Colors.black26),
            SizedBox(height: 16),
            Text(
              'No items',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DASHED DIVIDER
// ============================================================================

class _DashedDivider extends StatelessWidget {
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  const _DashedDivider({
    this.color = const Color(0xFFCCCCCC),
    this.dashWidth = 5,
    this.dashGap = 4,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness + 2,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: dashWidth,
          dashGap: dashGap,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashGap,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;

    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.thickness != thickness;
  }
}

// ============================================================================
// SUMMARY PANEL (merchant discount + coupon only here)
// ============================================================================

class _SummaryPanel extends StatefulWidget {
  final DisplayState state;

  const _SummaryPanel({required this.state});

  @override
  State<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<_SummaryPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    final double coupon = state.discount > 0 ? state.discount : 0.0;
    final double net = state.netTotal > 0
        ? state.netTotal
        : (state.subtotal - coupon - state.merchantDiscount);
    final double netPayable = state.total;

    // Total items excludes merchant-discount / coupon lines
    final int totalItems = state.items.fold<int>(0, (sum, item) {
      if (_isDiscountLineItem(item)) return sum;
      return sum + item.qty;
    });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(
                    'Gross Total',
                    _currency(state.subtotal),
                    _C.textDark,
                    20,
                    FontWeight.bold,
                  ),
                  if (state.merchantDiscount > 0)
                    _row(
                      'Merchant Discount',
                      '-${_currency(state.merchantDiscount)}',
                      _C.blue2,
                      16,
                      FontWeight.w600,
                    ),
                  if (coupon > 0)
                    _row(
                      'Coupon',
                      '-${_currency(coupon)}',
                      _C.green,
                      16,
                      FontWeight.w600,
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: _DashedDivider(),
                  ),
                  _row(
                    'Net Total',
                    _currency(net),
                    _C.textMid,
                    18,
                    FontWeight.bold,
                  ),
                  _row(
                    'Tax',
                    _currency(state.tax),
                    _C.textGray,
                    16,
                    FontWeight.normal,
                  ),
                  if (state.redeemedAmount > 0)
                    _row(
                      'Redeemed Amount',
                      '-${_currency(state.redeemedAmount)}',
                      _C.purple,
                      16,
                      FontWeight.normal,
                    ),
                  if (state.cashbackFee > 0)
                    _row(
                      'Cashback Fee',
                      _currency(state.cashbackFee),
                      _C.teal,
                      16,
                      FontWeight.normal,
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: _DashedDivider(),
                  ),
                  _row(
                    'Net Payable',
                    _currency(netPayable),
                    _C.textDark,
                    22,
                    FontWeight.w800,
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: _C.totalsBar,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Items : $totalItems',
                      style: const TextStyle(
                        color: _C.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Net Payable : ${_currency(netPayable)}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
      String label,
      String value,
      Color color,
      double size,
      FontWeight weight,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: size,
                fontWeight: weight,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
            ),
          ),
        ],
      ),
    );
  }

  String _currency(double value) => '\$${value.toStringAsFixed(2)}';
}

// ============================================================================
// KEYPAD
// ============================================================================

class _CustomKeypad extends StatelessWidget {
  final void Function(String) onChar;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const _CustomKeypad({
    required this.onChar,
    required this.onBackspace,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
      '@', '.', 'Space', '⌫', 'Done',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(4),
      child: GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.6,
        children: keys.map((key) {
          final isSpace = key == 'Space';
          final isBackspace = key == '⌫';
          final isDone = key == 'Done';

          return Material(
            color: isDone ? _C.accentBlue : Colors.grey.shade200,
            child: InkWell(
              onTap: () {
                if (isBackspace) {
                  onBackspace();
                } else if (isDone) {
                  onDone();
                } else if (isSpace) {
                  onChar(' ');
                } else {
                  onChar(key);
                }
              },
              child: Center(
                child: isBackspace
                    ? const Icon(Icons.backspace_outlined, size: 18)
                    : Text(
                  key,
                  style: TextStyle(
                    color: isDone ? Colors.white : Colors.black87,
                    fontSize: isSpace ? 14 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// REDEEM POPUP
// ============================================================================

class _RedeemPopup extends StatelessWidget {
  final bool fetching;
  final int points;
  final VoidCallback onOk;

  const _RedeemPopup({
    required this.fetching,
    required this.points,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0x80000000),
        alignment: Alignment.center,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Redeem Points',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                fetching
                    ? 'Fetching points...'
                    : 'Available Points: $points',
                style: const TextStyle(
                  color: const Color(0xFF333333),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: fetching ? null : onOk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE VIEW
// ============================================================================

class _MessageView extends StatelessWidget {
  final String screen;
  final double? total;
  final String? message;

  const _MessageView({
    super.key,
    required this.screen,
    this.total,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final config = switch (screen) {
      'SUCCESS' => (
      title: 'Thank you!',
      icon: Icons.check_circle_rounded,
      color: _C.green,
      ),
      'REFUND' => (
      title: 'Refund',
      icon: Icons.currency_exchange_rounded,
      color: _C.blue2,
      ),
      _ => (
      title: 'Total Due',
      icon: Icons.receipt_long_rounded,
      color: _C.accentBlue,
      ),
    };

    return Container(
      color: _C.bodyBg,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 105,
              height: 105,
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: config.color.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Icon(config.icon, color: config.color, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              config.title,
              style: TextStyle(
                color: config.color,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (total != null) ...[
              const SizedBox(height: 18),
              Text(
                '\$${total!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: config.color,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textMid, fontSize: 17),
              ),
            ],
          ],
        ),
      ),
    );
  }
}