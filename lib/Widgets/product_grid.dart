// import 'package:flutter/cupertino.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:pinaka_pos/Widgets/widget_nested_grid_layout.dart';
//
// import '../Blocs/Search/product_search_bloc.dart';
// import '../Database/order_panel_db_helper.dart';
//
// class ProductGridContainer extends StatefulWidget {
//   final List<Map<String, dynamic>> items;
//   final bool isLoading;
//   final bool isPaginating;
//
//   final ProductBloc productBloc;
//   final OrderHelper orderHelper;
//   final bool showBackButton;
//   final Function(int, {bool? variantAdded}) onItemTapped;
//   final VoidCallback onBackPressed;
//
//   const ProductGridContainer({
//     super.key,
//     required this.items,
//     required this.isLoading,
//     required this.isPaginating,
//     required this.productBloc,
//     required this.orderHelper,
//     required this.showBackButton,
//     required this.onItemTapped,
//     required this.onBackPressed,
//   });
//
//   @override
//   State<ProductGridContainer> createState() => _ProductGridContainerState();
// }
//
// class _ProductGridContainerState extends State<ProductGridContainer>
//     with AutomaticKeepAliveClientMixin {
//
//   late List<Map<String, dynamic>> _cachedItems;
//
//   /// Cached widget tree — returned as-is when only layout changes (mode switch).
//   /// Invalidated only when grid-relevant data changes.
//   Widget? _cachedBuild;
//
//   @override
//   void initState() {
//     super.initState();
//     _cachedItems = widget.items;
//   }
//
//   /// 🔥 Only invalidate cached build when data actually changes
//   @override
//   void didUpdateWidget(covariant ProductGridContainer oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//     final bool dataChanged = !listEquals(oldWidget.items, widget.items) ||
//         oldWidget.isLoading != widget.isLoading ||
//         oldWidget.isPaginating != widget.isPaginating ||
//         oldWidget.showBackButton != widget.showBackButton;
//
//     if (dataChanged) {
//       _cachedItems = widget.items;
//       _cachedBuild = null; // force rebuild on next build()
//     }
//   }
//
//   @override
//   bool get wantKeepAlive => true;
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//
//     // Return cached widget when only layout changed (mode switch) — no flicker
//     if (_cachedBuild != null) return _cachedBuild!;
//
//     _cachedBuild = RepaintBoundary(
//       child: Stack(
//         children: [
//
//           /// 🔥 GRID (STABLE)
//           NestedGridWidget(
//             key: const PageStorageKey("product_grid"),
//             items: _cachedItems, // 🔥 use cached
//             isLoading: false, // ❌ avoid passing loading here
//             isPaginating: widget.isPaginating,
//             showAddButton: false,
//             showBackButton: widget.showBackButton,
//             selectedItemIndex: null,
//             reorderedIndices: const [],
//             onAddButtonPressed: null,
//             onBackButtonPressed: widget.onBackPressed,
//             onItemTapped: widget.onItemTapped,
//             onReorder: (_, __) {},
//             onDeleteItem: (_) {},
//             onCancelReorder: () {},
//             showDeleteButton: false,
//             productBloc: widget.productBloc,
//             orderHelper: widget.orderHelper,
//             isHorizontal: true,
//           ),
//
//           /// 🔥 LIGHT LOADER (NO FULL REPAINT)
//           if (widget.isLoading)
//             Positioned(
//               right: 20,
//               bottom: 20,
//               child: Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.6),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const SizedBox(
//                   height: 18,
//                   width: 18,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//
//     return _cachedBuild!;
//   }
// }
// class StableCenterContent extends StatefulWidget {
//   final Widget child;
//
//   const StableCenterContent({super.key, required this.child});
//
//   @override
//   State<StableCenterContent> createState() => _StableCenterContentState();
// }
//
// class _StableCenterContentState extends State<StableCenterContent>
//     with AutomaticKeepAliveClientMixin {
//
//   @override
//   bool get wantKeepAlive => true;
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//
//     return RepaintBoundary(child: widget.child);
//   }
// }