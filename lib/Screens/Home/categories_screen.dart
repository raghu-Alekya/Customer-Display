<<<<<<< HEAD
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
=======
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Database/db_helper.dart';
<<<<<<< HEAD
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
=======
import '../../Database/storage/storage_provider.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/url_helper.dart';
import '../../Providers/Age/age_verification_provider.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Utilities/global_utility.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
<<<<<<< HEAD
=======
import '../../Utilities/responsive_layout.dart';
import '../../Utilities/shimmer_effect.dart';
import '../../Utilities/svg_images_utility.dart';
import '../../Widgets/ManualPriceDialog.dart';
import '../../Widgets/weighing_scale_widget.dart';
import '../../Widgets/widget_logs_toast.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Widgets/widget_category_list.dart';
import '../../Widgets/widget_nested_grid_layout.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_sub_category.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Blocs/Category/category_bloc.dart';
import '../../Repositories/Category/category_repository.dart';
<<<<<<< HEAD
=======
import '../../Database/isar_service.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Helper/api_response.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Constants/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

<<<<<<< HEAD
import '../Auth/login_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final int? lastSelectedIndex;

  const CategoriesScreen({super.key, this.lastSelectedIndex});
=======
import '../../Widgets/widget_variants_dialog.dart';
import '../Auth/login_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pinaka_pos/Helper/Extentions/theme_notifier.dart';
import 'package:provider/provider.dart';

import 'isar_payments/local_payments_db_helper.dart';

const _indigoBgRefreshThreshold = Duration(minutes: 30);

class CategoryBarWithAllButton extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> categoryListItems;
  final List<CategoryModel> visibleCategories;
  final List<CategoryModel> allCategories;
  final int? selectedCategoryIndex;
  final int? editingCategoryIndex;
  final ScrollController scrollController;
  final bool showCategoryGrid;
  final List<CategoryModel> recentCategories;
  final bool isAddButtonEnabled;
  final VoidCallback onAllTapped;
  final Function(int uiIndex) onCategoryTapped;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(int)? onEditButtonPressed;
  final Function()? onDismissEditMode;

  const CategoryBarWithAllButton({
    super.key,
    required this.isLoading,
    required this.categoryListItems,
    required this.visibleCategories,
    required this.allCategories,
    required this.selectedCategoryIndex,
    this.editingCategoryIndex,
    required this.scrollController,
    required this.showCategoryGrid,
    required this.recentCategories,
    this.isAddButtonEnabled = false,
    required this.onAllTapped,
    required this.onCategoryTapped,
    this.onReorder,
    this.onEditButtonPressed,
    this.onDismissEditMode,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: ShimmerEffect.rectangular(height: 60),
      );
    }

    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: onDismissEditMode,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? ThemeNotifier.primaryBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x25CCC8C8)
                    : const Color(0x50BDB9B9),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AllChip(
                isDark: isDark,
                isActive: showCategoryGrid,
                onTap: onAllTapped,
              ),

              if (recentCategories.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? Colors.white12 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: recentCategories.map((cat) {
                        final uiIndex = visibleCategories
                            .indexWhere((v) => v.id == cat.id);
                        final bool isSelected = !showCategoryGrid &&
                            selectedCategoryIndex != null &&
                            selectedCategoryIndex! < allCategories.length &&
                            allCategories[selectedCategoryIndex!].id == cat.id;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _RecentCategoryChip(
                            category: cat,
                            isDark: isDark,
                            isSelected: isSelected,
                            onTap: uiIndex >= 0
                                ? () => onCategoryTapped(uiIndex)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              if (recentCategories.isEmpty) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}


class CategoryGridOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> categoryListItems;
  final Function(int) onCategoryTapped;

  const CategoryGridOverlay({
    super.key,
    required this.categoryListItems,
    required this.onCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              "Categories",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          LayoutBuilder(builder: (context, constraints) {
            const int cols = 5;
            const double gap = 8.0;
            final double cardW =
                (constraints.maxWidth - gap * (cols - 1)) / cols;
            const double cardH = 100.0;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(categoryListItems.length, (index) {
                final cat = categoryListItems[index];
                return SizedBox(
                  width: cardW,
                  height: cardH,
                  child: _CategoryGridCard(
                    title: cat['title'],
                    image: cat['image'],
                    isDark: isDark,
                    onTap: () => onCategoryTapped(index),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

class SubCategoryCardRow extends StatelessWidget {
  final List<Map<String, dynamic>> subCategoryListItems;
  final int? selectedIndex;
  final Function(int) onCardTapped;
  final bool isLoading;
  final String? breadcrumbLabel;

  const SubCategoryCardRow({
    super.key,
    required this.subCategoryListItems,
    this.selectedIndex,
    required this.onCardTapped,
    this.isLoading = false,
    this.breadcrumbLabel,
  });

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ShimmerEffect.rectangular(height: 64),
      );
    }

    if (subCategoryListItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (breadcrumbLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  breadcrumbLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFB0B0D0)
                        : const Color(0xFF4C5F7D),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark
                      ? const Color(0xFFB0B0D0)
                      : const Color(0xFF4C5F7D),
                ),
              ],
            ),
          ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: List.generate(subCategoryListItems.length, (index) {
              final sub = subCategoryListItems[index];
              final bool isSelected = selectedIndex == index;
              final String imgPath =
                  sub['image'] ?? sub['imageUrl'] ?? 'assets/default.png';

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => onCardTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFE5E5)
                          : isDark
                          ? const Color(0xFF26253A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFE6464)
                            : isDark
                            ? Colors.white12
                            : const Color(0xFFE0E0E0),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFFFE6464).withOpacity(0.12)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: isSelected ? 6 : 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildImage(imgPath, 42),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: Text(
                            sub['name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFFFE6464)
                                  : isDark
                                  ? Colors.white
                                  : const Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String imagePath, double size) {
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return SvgPicture.asset(imagePath,
          height: size,
          width: size,
          placeholderBuilder: (_) => Icon(Icons.image, size: size));
    } else if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.image, size: size));
    } else if (imagePath.startsWith('http')) {
      return Image.network(imagePath,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.image, size: size));
    } else {
      return Platform.isWindows
          ? Image.asset('assets/default.png', width: size, height: size)
          : Image.file(
        File(imagePath),
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image, size: size),
      );
    }
  }
}

class SubCategoryPillBar extends StatelessWidget {
  final List<Map<String, dynamic>> subCategoryListItems;
  final int? selectedIndex;
  final Function(int) onPillTapped;
  final bool isLoading;
  final String? breadcrumbLabel;

  const SubCategoryPillBar({
    super.key,
    required this.subCategoryListItems,
    this.selectedIndex,
    required this.onPillTapped,
    this.isLoading = false,
    this.breadcrumbLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SubCategoryCardRow(
      subCategoryListItems: subCategoryListItems,
      selectedIndex: selectedIndex,
      onCardTapped: onPillTapped,
      isLoading: isLoading,
      breadcrumbLabel: breadcrumbLabel,
    );
  }
}


class _AllChip extends StatelessWidget {
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;

  const _AllChip({
    required this.isDark,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFE6464)
              : isDark
              ? ThemeNotifier.secondaryBackground
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 14,
              color: isActive
                  ? Colors.white
                  : isDark
                  ? Colors.white54
                  : Colors.black54,
            ),
            const SizedBox(width: 5),
            Text(
              "All",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RecentCategoryChip extends StatelessWidget {
  final CategoryModel category;
  final bool isDark;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RecentCategoryChip({
    required this.category,
    required this.isDark,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String imagePath = category.image ?? 'assets/default.png';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFE5E5)
              : isDark
              ? ThemeNotifier.secondaryBackground
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFE6464)
                : isDark
                ? Colors.white12
                : Colors.black12,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildImage(imagePath, 24),
            ),
            const SizedBox(width: 7),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFFFE6464)
                    : isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildImage(String imagePath, double size) {
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return SvgPicture.asset(imagePath,
          height: size,
          width: size,
          placeholderBuilder: (_) => Icon(Icons.image, size: size));
    } else if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.image, size: size));
    } else if (imagePath.startsWith('http')) {
      return Image.network(imagePath,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.image, size: size));
    } else {
      return Platform.isWindows
          ? Image.asset('assets/default.png', width: size, height: size)
          : Image.file(
        File(imagePath),
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image, size: size),
      );
    }
  }
}



class _CategoryGridCard extends StatelessWidget {
  final String title;
  final String image;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryGridCard({
    required this.title,
    required this.image,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF26253A) : const Color(0xFFF3F4F8);
    final borderColor =
    isDark ? const Color(0xFF3A3A52) : const Color(0xFFE8EAF0);
    final textColor = isDark ? Colors.white : const Color(0xFF2C3E50);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 68,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: _buildImage(image),
              ),
            ),
            Expanded(
              flex: 32,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return SvgPicture.asset(imagePath,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const Icon(Icons.image, size: 28));
    } else if (imagePath.startsWith('assets/')) {
      return Image.asset(imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 28));
    } else if (imagePath.startsWith('http')) {
      return Image.network(imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 28));
    } else {
      return Platform.isWindows
          ? Image.asset('assets/default.png', fit: BoxFit.contain)
          : Image.file(File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 28));
    }
  }
}


class IndigoCategoryModel {
  final int id;
  final String name;
  final String slug;
  final int parent;
  final String description;
  final int count;
  final String image;

  IndigoCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
    required this.description,
    required this.count,
    required this.image,
  });

  factory IndigoCategoryModel.fromJson(Map<String, dynamic> json) {
    return IndigoCategoryModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      parent: json['parent'],
      description: json['description'] ?? '',
      count: json['count'],
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "slug": slug,
    "parent": parent,
    "description": description,
    "count": count,
    "image": image,
  };
}

class IndigoCategoryBasedProducts {
  final int id;
  final String name;
  final String sku;
  final String price;
  final String regularPrice;
  final String salePrice;
  final List<IndigoCategory> categories;
  final List<IndigoTag> tags;
  final List<String> images;
  final List<IndigoTaxRate> taxRates;
  final String type;
  // NEW: Meta data support (loyalty points etc.)
  final List<Map<String, dynamic>> metaData;

  IndigoCategoryBasedProducts({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.categories,
    required this.tags,
    required this.images,
    required this.taxRates,
    required this.type,
    this.metaData = const [], // default empty
  });

  factory IndigoCategoryBasedProducts.fromJson(Map<String, dynamic> json) {
    List<String> imageList = [];
    if (json['images'] != null && json['images'] is List) {
      imageList = List<String>.from(json['images']);
    }

    List<IndigoCategory> categoryList = [];
    if (json['categories'] != null && json['categories'] is List) {
      categoryList = (json['categories'] as List)
          .map((c) =>
          IndigoCategory.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
    }

    List<IndigoTag> tagList = [];
    if (json['tags'] != null && json['tags'] is List) {
      tagList = (json['tags'] as List)
          .map((t) =>
          IndigoTag.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
    }

    List<IndigoTaxRate> taxRateList = [];
    if (json['tax'] != null &&
        json['tax']['tax_rates'] != null &&
        json['tax']['tax_rates'] is List) {
      taxRateList = (json['tax']['tax_rates'] as List)
          .map((tr) =>
          IndigoTaxRate.fromJson(Map<String, dynamic>.from(tr as Map)))
          .toList();
    }
// NEW: Parse meta_data
    List<Map<String, dynamic>> metaList = [];
    if (json['meta_data'] != null && json['meta_data'] is List) {
      metaList = (json['meta_data'] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

      // Console print for debugging (as requested)
      for (var m in metaList) {
        if (m['key'] == '_product_loyalty_points') {
          print('🔹 [Indigo] Loyalty Points for ${json['name']}: ${m['value']}');
        }
      }
    }

    return IndigoCategoryBasedProducts(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      regularPrice: json['regular_price']?.toString() ?? '0',
      salePrice: json['sale_price']?.toString() ?? '',
      categories: categoryList,
      tags: tagList,
      images: imageList,
      taxRates: taxRateList,
      type: json['type']?.toString() ?? 'simple',
      metaData: metaList,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "sku": sku,
    "price": price,
    "regular_price": regularPrice,
    "sale_price": salePrice,
    "categories": categories.map((c) => c.toJson()).toList(),
    "tags": tags.map((t) => t.toJson()).toList(),
    "images": images,
    "tax_rates": taxRates.map((tr) => tr.toJson()).toList(),
    "type": type,
    "meta_data": metaData, // NEW
  };
}

class IndigoCategory {
  final int id;
  final String name;
  final String slug;

  IndigoCategory({required this.id, required this.name, required this.slug});

  factory IndigoCategory.fromJson(Map<String, dynamic> json) => IndigoCategory(
    id: json['id'] ?? 0,
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {"id": id, "name": name, "slug": slug};
}

class IndigoTag {
  final int id;
  final String name;
  final String slug;

  IndigoTag({required this.id, required this.name, required this.slug});

  factory IndigoTag.fromJson(Map<String, dynamic> json) => IndigoTag(
    id: json['id'] ?? 0,
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {"id": id, "name": name, "slug": slug};
}

class IndigoTaxRate {
  final String label;
  final double rate;
  final bool compound;
  final bool shipping;

  IndigoTaxRate({
    required this.label,
    required this.rate,
    required this.compound,
    required this.shipping,
  });

  factory IndigoTaxRate.fromJson(Map<String, dynamic> json) => IndigoTaxRate(
    label: json['label']?.toString() ?? '',
    rate: (json['rate'] != null)
        ? double.tryParse(json['rate'].toString()) ?? 0.0
        : 0.0,
    compound: json['compound'] ?? false,
    shipping: json['shipping'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    "label": label,
    "rate": rate,
    "compound": compound,
    "shipping": shipping,
  };
}


class IndigoCategoryRepository {
  Future<List<IndigoCategoryModel>> indigoFetchCategories(
      int parentCategoryId) async {
    final token = await _getTokenFromDb();
    final url = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.categories}'
            '?page=1&per_page=100&hide_empty=true&parent=$parentCategoryId');

    if (kDebugMode) print("Indigo categories URL: $url");

    final response =
    await http.get(url, headers: {"Authorization": "Bearer $token"});

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((json) => IndigoCategoryModel.fromJson(json)).toList();
    } else {
      throw Exception(
          "Failed to load indigo categories (status ${response.statusCode})");
    }
  }

  Future<String> _getTokenFromDb() async {
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
    if (kDebugMode) print('Using JWT token: ${token.substring(0, 20)}...');
    return token;
  }
}

class IndigoCategoryBasedProductsRepository {
  Future<List<IndigoCategoryBasedProducts>> fetchProducts(
      int categoryId) async {
    final token = await _getTokenFromDb();
    final url = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.productByCategories}/$categoryId');

    final response =
    await http.get(url, headers: {"Authorization": "Bearer $token"});

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data
          .map((e) => IndigoCategoryBasedProducts.fromJson(e))
          .toList();
    } else {
      throw Exception("Failed to load products");
    }
  }

  Future<String> _getTokenFromDb() async {
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
    if (kDebugMode) print('Using JWT token: ${token.substring(0, 20)}...');
    return token;
  }
}


String _indigoSubCatKey(int parentId) => "indigo_subcategories_$parentId";
String _indigoProductKey(int categoryId) => "indigo_products_$categoryId";


class _IndigoCategoryRepositoryWithCache {
  final IndigoCategoryRepository _remote;
  _IndigoCategoryRepositoryWithCache(this._remote);

  static final Map<String, Future<void>> _inFlightRefreshes = {};

  Future<List<IndigoCategoryModel>> indigoFetchCategories(
      int parentCategoryId) async {
    final cacheKey = _indigoSubCatKey(parentCategoryId);
    final entry = await _readEntryFromIsar(cacheKey);
    if (entry != null) {
      if (kDebugMode) {
        print(
            "📦 [Indigo] Isar hit: sub-categories (parent: $parentCategoryId)");
      }
      if (_isStale(entry.timestamp)) {
        _scheduleRefresh(
            cacheKey, () => _fetchAndWriteToIsar(parentCategoryId));
      }
      return _decodeCategories(entry.json);
    }
    try {
      return await _fetchAndWriteToIsar(parentCategoryId);
    } catch (e) {
      if (kDebugMode) {
        print(
            "⚠️ [Indigo] API failed & no cache for sub-categories (parent: $parentCategoryId): $e");
      }
      return [];
    }
  }

  Future<List<IndigoCategoryModel>> _fetchAndWriteToIsar(
      int parentCategoryId) async {
    if (kDebugMode)
      print(
          "🌍 [Indigo] Fetching sub-categories from API (parent: $parentCategoryId)");
    final cats = await _remote.indigoFetchCategories(parentCategoryId);
    final jsonStr = json.encode(cats.map((c) => c.toJson()).toList());
    await _writeToIsar(_indigoSubCatKey(parentCategoryId), jsonStr);
    if (kDebugMode)
      print(
          "💾 [Indigo] Cached ${cats.length} sub-categories (parent: $parentCategoryId)");
    return cats;
  }

  Future<void> preWarmAll(List<int> parentIds) async {
    for (final id in parentIds) {
      try {
        final existing = await _readEntryFromIsar(_indigoSubCatKey(id));
        if (existing == null) {
          await _fetchAndWriteToIsar(id);
        } else if (_isStale(existing.timestamp)) {
          _scheduleRefresh(
              _indigoSubCatKey(id), () => _fetchAndWriteToIsar(id));
        }
      } catch (e) {
        if (kDebugMode) print("⚠️ [Indigo] Pre-warm failed (parent: $id): $e");
      }
    }
  }

  Future<IsarCacheEntry?> _readEntryFromIsar(String key) async {
    try {
      final isar = await IsarService.instance;
      return await isar.isarCacheEntrys.where().keyEqualTo(key).findFirst();
    } catch (e) {
      if (kDebugMode) print("[Indigo] Isar read error ($key): $e");
      return null;
    }
  }

  Future<void> _writeToIsar(String key, String jsonStr) async {
    try {
      final isar = await IsarService.instance;
      await isar.writeTxn(() async {
        await isar.isarCacheEntrys.put(
          IsarCacheEntry()
            ..key = key
            ..json = jsonStr
            ..timestamp = DateTime.now(),
        );
      });
    } catch (e) {
      if (kDebugMode) print("[Indigo] Isar write error ($key): $e");
    }
  }

  List<IndigoCategoryModel> _decodeCategories(String jsonStr) {
    try {
      final List<dynamic> raw = json.decode(jsonStr);
      return raw
          .map((e) =>
          IndigoCategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      if (kDebugMode) print("[Indigo] Decode error (categories): $e");
      return [];
    }
  }

  void _scheduleRefresh(String key, Future<void> Function() work) {
    if (_inFlightRefreshes.containsKey(key)) return;
    final task = work().whenComplete(() => _inFlightRefreshes.remove(key));
    _inFlightRefreshes[key] = task;
  }

  bool _isStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _indigoBgRefreshThreshold;
  }
}

class _IndigoProductRepositoryWithCache {
  final IndigoCategoryBasedProductsRepository _remote;
  _IndigoProductRepositoryWithCache(this._remote);

  static final Map<String, Future<void>> _inFlightRefreshes = {};

  Future<List<IndigoCategoryBasedProducts>> fetchProducts(
      int categoryId) async {
    final cacheKey = _indigoProductKey(categoryId);
    final entry = await _readEntryFromIsar(cacheKey);
    if (entry != null) {
      if (kDebugMode)
        print("📦 [Indigo] Isar hit: products (category: $categoryId)");
      if (_isStale(entry.timestamp)) {
        _scheduleRefresh(cacheKey, () => _fetchAndWriteToIsar(categoryId));
      }
      return _decodeProducts(entry.json);
    }
    try {
      return await _fetchAndWriteToIsar(categoryId);
    } catch (e) {
      if (kDebugMode)
        print(
            "[Indigo] API failed & no cache for products (category: $categoryId): $e");
      return [];
    }
  }

  Future<List<IndigoCategoryBasedProducts>> _fetchAndWriteToIsar(
      int categoryId) async {
    if (kDebugMode)
      print("[Indigo] Fetching products from API (category: $categoryId)");
    final products = await _remote.fetchProducts(categoryId);
    final jsonStr = json.encode(products.map((p) => p.toJson()).toList());
    await _writeToIsar(_indigoProductKey(categoryId), jsonStr);
    TopBar.notifyMergedProductCacheMayHaveChanged();
    if (kDebugMode)
      print(
          "[Indigo] Cached ${products.length} products (category: $categoryId)");
    return products;
  }

  Future<void> preWarmAll(List<int> categoryIds) async {
    for (final id in categoryIds) {
      try {
        final existing = await _readEntryFromIsar(_indigoProductKey(id));
        if (existing == null) {
          await _fetchAndWriteToIsar(id);
        } else if (_isStale(existing.timestamp)) {
          _scheduleRefresh(
              _indigoProductKey(id), () => _fetchAndWriteToIsar(id));
        }
      } catch (e) {
        if (kDebugMode)
          print("[Indigo] Pre-warm products failed (category: $id): $e");
      }
    }
  }

  Future<IsarCacheEntry?> _readEntryFromIsar(String key) async {
    try {
      final isar = await IsarService.instance;
      return await isar.isarCacheEntrys.where().keyEqualTo(key).findFirst();
    } catch (e) {
      if (kDebugMode) print("[Indigo] Isar read error ($key): $e");
      return null;
    }
  }

  Future<void> _writeToIsar(String key, String jsonStr) async {
    try {
      final isar = await IsarService.instance;
      await isar.writeTxn(() async {
        await isar.isarCacheEntrys.put(
          IsarCacheEntry()
            ..key = key
            ..json = jsonStr
            ..timestamp = DateTime.now(),
        );
      });
    } catch (e) {
      if (kDebugMode) print("[Indigo] Isar write error ($key): $e");
    }
  }

  List<IndigoCategoryBasedProducts> _decodeProducts(String jsonStr) {
    try {
      final List<dynamic> raw = json.decode(jsonStr);
      return raw
          .map((e) => IndigoCategoryBasedProducts.fromJson(
          Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      if (kDebugMode) print("[Indigo] Decode error (products): $e");
      return [];
    }
  }

  void _scheduleRefresh(String key, Future<void> Function() work) {
    if (_inFlightRefreshes.containsKey(key)) return;
    final task = work().whenComplete(() => _inFlightRefreshes.remove(key));
    _inFlightRefreshes[key] = task;
  }

  bool _isStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _indigoBgRefreshThreshold;
  }
}



class CategoriesScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  final bool embedInShell;

  const CategoriesScreen(
      {super.key, this.lastSelectedIndex, this.embedInShell = false});
>>>>>>> origin/Grocery_pch_api_integration

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

<<<<<<< HEAD
class _CategoriesScreenState extends State<CategoriesScreen> with WidgetsBindingObserver, LayoutSelectionMixin{
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 1;
  DateTime now = DateTime.now();
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
=======
class _CategoriesScreenState extends State<CategoriesScreen>
    with LayoutSelectionMixin {
  final List<String> items = List.generate(18, (index) => 'Bud Light');
  int _selectedSidebarIndex = 1;
  List<int> quantities = [1, 1, 1, 1];

  bool isLoading = true;
  bool isAddingItemLoading = false;
  bool isLoadingNestedContent = false;

  final ValueNotifier<int?> fastKeyTabIdNotifier = ValueNotifier<int?>(null);
  final OrderHelper orderHelper = OrderHelper();
  final productBloc = ProductBloc(ProductRepository());
  final PinakaPreferences _preferences = PinakaPreferences();

  int? _cachedActiveOrderId;
  late CategoryBloc _categoryBloc;
  List<CategoryModel> categories = [];
  List<CategoryModel> subCategories = [];
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
  int? _selectedSubCategoryIndex;
  final ScrollController _categoryScrollController = ScrollController();
  bool _hasAutoTappedOnce = false;

  bool _showCategoryGrid = true;

  final List<CategoryModel> _recentCategories = [];
  static const int _maxRecentCategories = 5;

  static const int _pageSize = 20;
  final List<Map<String, dynamic>> _allCategoryProducts = [];
  int _visibleProductCount = _pageSize;
  bool _autoLoadCompleted = false;
  bool _isPaginating = false;
  bool _hasMoreProductsToShow = false;

  List<Map<String, dynamic>> categoryProducts = [];
  String? _categoryContentError;
>>>>>>> origin/Grocery_pch_api_integration
  int? selectedItemIndex;
  List<int?> reorderedIndices = [];
  List<String> navigationPath = [];
  List<int> categoryHierarchy = [0];
  int currentCategoryLevel = 0;
  String? lastSelectedProduct;
  bool isShowingSubCategories = false;
  StreamSubscription? _updateOrderSubscription;
  late OrderBloc orderBloc;
<<<<<<< HEAD
  int _refreshCounter = 0; //Build #1.0.170: Added: Counter to trigger RightOrderPanel refresh only when needed
=======
  int _refreshCounter = 0;
  bool _isAutoLoading = false;

  // ── In-flight guards — only block CONCURRENT calls for the same id ─────────
  // These are cleared by _forceReloadCurrentView() after a product refresh.
  int? _inFlightSubCategoryParentId;
  int? _inFlightProductCategoryId;
  int? _inFlightIndigoSubParentId;
  int? _inFlightIndigoProductCategoryId;

  // ── "last loaded" tracking — REMOVED the persistent set guards ────────────
  // Previously _loadedProductCategoryIds / _loadedIndigoProductCategoryIds
  // prevented any reload after the first load. They are intentionally gone so
  // that _forceReloadCurrentView() can trigger a fresh Isar read after refresh.

  bool _indigoPreWarmDone = false;

  final _IndigoCategoryRepositoryWithCache _indigoCategoryRepo =
  _IndigoCategoryRepositoryWithCache(IndigoCategoryRepository());
  final _IndigoProductRepositoryWithCache _indigoProductRepo =
  _IndigoProductRepositoryWithCache(
      IndigoCategoryBasedProductsRepository());
  final CategoryRepository _connectorCategoryRepo = CategoryRepository();

  List<IndigoCategoryModel> _indigoSubCategories = [];
  List<IndigoCategoryBasedProducts> _indigoProducts = [];
  int? _selectedIndigoSubCategoryIndex;
  bool _isLoadingIndigoSubCategories = false;
  bool _isLoadingIndigoProducts = false;
  String? _indigoError;
  static const int _indigoPageSize = 30;

  int _visibleIndigoProductCount = _indigoPageSize;
  bool _isIndigoPaginating = false;
  final Map<int, Map<String, dynamic>> _productMetaCache = {};
  bool _isProductMetaCacheLoaded = false;

  bool _productAddTapInFlight = false;
  List<Map<String, dynamic>> tabs = [];
  List<Map<String, dynamic>> orderItems = [];

  static const String _defaultCatIsarKey = 'indigo_default_category_products';
  final Map<String, Map<String, dynamic>> _dynamicProductMemCache = {};

  // ─────────────────────────────────────────────────────────────────────────
  // FIX: Force-reload the currently visible product grid after a refresh.
  // Called by TopBar.onRefreshCompleted.
  // ─────────────────────────────────────────────────────────────────────────

  // Add this helper method to _CategoriesScreenState
  // ─────────────────────────────────────────────────────────────────────────
// Deletes Isar indigo_products_ entries for the currently visible category
// so _IndigoProductRepositoryWithCache sees a cache miss and fetches fresh.
// ─────────────────────────────────────────────────────────────────────────
  Future<void> _bustIndigoProductCacheForCurrentCategory() async {
    if (_selectedCategoryIndex == null ||
        _selectedCategoryIndex! >= categories.length) return;

    try {
      final isar = await IsarService.instance;
      final int parentId = categories[_selectedCategoryIndex!].id;

      // Collect parent + all loaded sub-category ids
      final Set<int> categoryIds = {parentId};
      for (final sub in _indigoSubCategories) {
        categoryIds.add(sub.id);
      }
      // Also include the currently selected sub-category explicitly
      if (_selectedIndigoSubCategoryIndex != null &&
          _indigoSubCategories.isNotEmpty &&
          _selectedIndigoSubCategoryIndex! < _indigoSubCategories.length) {
        categoryIds
            .add(_indigoSubCategories[_selectedIndigoSubCategoryIndex!].id);
      }

      await isar.writeTxn(() async {
        for (final id in categoryIds) {
          final count = await isar.isarCacheEntrys
              .filter()
              .keyEqualTo('indigo_products_$id')
              .deleteAll();
          if (kDebugMode) {
            print(
                '🗑️ [Categories] Busted indigo_products_$id (deleted: $count)');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print(
            '⚠️ [Categories] _bustIndigoProductCacheForCurrentCategory error: $e');
      }
    }
  }

// ─────────────────────────────────────────────────────────────────────────
// Force-reload the currently visible product grid after a TopBar refresh.
// Called via TopBar.onRefreshCompleted.
// ─────────────────────────────────────────────────────────────────────────
  Future<void> _forceReloadCurrentView() async {
    if (!mounted) return;
    if (kDebugMode) print("🔄 [Categories] _forceReloadCurrentView triggered");

    // Step 1: Delete the indigo_products_ Isar cache for the visible category.
    // This makes _IndigoProductRepositoryWithCache.fetchProducts see a cache
    // miss and call the real API, returning the FULL product list — not just
    // the delta that refreshProducts wrote.
    await _bustIndigoProductCacheForCurrentCategory();

    // Step 2: Clear ALL in-flight guards so load methods don't bail early.
    _inFlightIndigoSubParentId = null;
    _inFlightIndigoProductCategoryId = null;
    _inFlightSubCategoryParentId = null;
    _inFlightProductCategoryId = null;

    // Step 3: Re-trigger loads for the currently visible category/sub-category.
    if (!_showCategoryGrid &&
        _selectedCategoryIndex != null &&
        _selectedCategoryIndex! < categories.length) {
      final int parentId = categories[_selectedCategoryIndex!].id;

      // Reload sub-categories so pill bar reflects any new additions.
      await _loadIndigoSubCategories(parentId);

      // Determine which sub-category's products to reload.
      final int targetId = (_selectedIndigoSubCategoryIndex != null &&
          _indigoSubCategories.isNotEmpty &&
          _selectedIndigoSubCategoryIndex! < _indigoSubCategories.length)
          ? _indigoSubCategories[_selectedIndigoSubCategoryIndex!].id
          : parentId;

      // This now hits the API because we deleted the Isar cache in Step 1.
      await _loadIndigoProductsBySubCategory(targetId);

      // Also reload the standard (non-Indigo) product list if applicable.
      if (_selectedSubCategoryIndex != null &&
          subCategories.isNotEmpty &&
          _selectedSubCategoryIndex! < subCategories.length) {
        _loadProductsByCategory(subCategories[_selectedSubCategoryIndex!].id);
      }
    }

    if (kDebugMode) print("✅ [Categories] _forceReloadCurrentView done");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Order helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _preserveSelectedOrder() async {
    if (!mounted) return;

    final int? currentlyActive = orderHelper.activeOrderId;
    if (currentlyActive == null) return;

    await orderHelper.loadData();

    final List<int> visibleOrderIds = [];
    for (final order in orderHelper.orders) {
      final int? orderId = _normalizeOrderId(
        order[AppDBConst.orderServerId] ?? order['order_id'] ?? order['id'],
      );
      if (orderId == null || orderId <= 0) continue;

      final payments = await LocalPaymentDBHelper.instance
          .getPaymentsByOrderId(orderId, userId: orderHelper.activeUserId);

      if (payments.isEmpty) {
        visibleOrderIds.add(orderId);
      }
    }

    if (visibleOrderIds.contains(currentlyActive)) {
      OrderHelper.notifyOrderPanelToRefresh();
      return;
    }

    if (visibleOrderIds.isNotEmpty) {
      final fallbackId = visibleOrderIds.last;
      await orderHelper.setActiveOrder(fallbackId);
      await orderHelper.saveLastActiveOrderId(fallbackId);
    } else {
      await orderHelper.setActiveOrder(null);
      if (mounted) setState(() => orderItems.clear());
    }

    OrderHelper.notifyOrderPanelToRefresh();
  }

  int? _normalizeOrderId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<int> _getVisibleOrderIds() {
    final List<int> visibleOrderIds = [];
    for (final t in tabs) {
      final id = _normalizeOrderId(t['orderId']);
      if (id != null && id > 0) {
        visibleOrderIds.add(id);
      }
    }
    return visibleOrderIds;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Default category product helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _preLoadDefaultCategoryProducts(
      List<CategoryModel> cats) async {
    try {
      CategoryModel? defaultCat;
      for (final c in cats) {
        final slug = (c.slug ?? '').toLowerCase().trim();
        final name = c.name.toLowerCase().trim();
        if (slug == 'default' || name == 'default') {
          defaultCat = c;
          break;
        }
      }

      if (defaultCat == null) {
        if (kDebugMode)
          print('ℹ️ [Default] No "default" category found in top-level list');
        return;
      }

      final isar = await IsarService.instance;
      final existing = await isar.isarCacheEntrys
          .where()
          .keyEqualTo(_defaultCatIsarKey)
          .findFirst();
      if (existing != null) {
        if (kDebugMode)
          print(
              '📦 [Default] Products already cached (cat id: ${defaultCat.id})');
        return;
      }

      final products = await _indigoProductRepo.fetchProducts(defaultCat.id);
      final jsonStr = json.encode(products.map((p) => p.toJson()).toList());
      await isar.writeTxn(() async {
        await isar.isarCacheEntrys.put(
          IsarCacheEntry()
            ..key = _defaultCatIsarKey
            ..json = jsonStr
            ..timestamp = DateTime.now(),
        );
      });

      if (kDebugMode)
        print(
            '💾 [Default] Cached ${products.length} products from "default" category');
    } catch (e) {
      if (kDebugMode)
        print('⚠️ [Default] Failed to pre-load default products: $e');
    }
  }

  Future<Map<String, dynamic>?> _findDynamicProductByTokens(
      List<String> tokens,
      ) async {
    for (final token in tokens) {
      final t = token.toLowerCase();
      for (final entry in _dynamicProductMemCache.entries) {
        if (entry.key.contains(t)) return entry.value;
      }
    }

    final isar = await IsarService.instance;
    final entry = await isar.isarCacheEntrys
        .where()
        .keyEqualTo(_defaultCatIsarKey)
        .findFirst();

    List<dynamic> raw = [];
    if (entry != null) {
      raw = json.decode(entry.json);
    } else {
      if (kDebugMode) print('⚠️ [Default] Cache empty, fetching now...');
      final defaultCat = categories.firstWhere(
            (c) =>
        c.slug?.toLowerCase() == 'default' ||
            c.name.toLowerCase() == 'default',
        orElse: () => throw Exception('Default category not found'),
      );
      final freshProducts =
      await _indigoProductRepo.fetchProducts(defaultCat.id);
      final jsonStr =
      json.encode(freshProducts.map((p) => p.toJson()).toList());
      await isar.writeTxn(() async {
        await isar.isarCacheEntrys.put(
          IsarCacheEntry()
            ..key = _defaultCatIsarKey
            ..json = jsonStr
            ..timestamp = DateTime.now(),
        );
      });
      raw = json.decode(jsonStr);
    }

    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] ?? '').toString().toLowerCase();
      final sku = (map['sku'] ?? '').toString().toLowerCase();

      for (final token in tokens) {
        final t = token.toLowerCase();
        if (name.contains(t) || sku.contains(t)) {
          final normalised = _buildNormalisedProductMap(map);
          _cacheDynamicProduct(normalised);
          return normalised;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _buildNormalisedProductMap(
      Map<String, dynamic> rawMap) {
    return {
      'fast_key_product_id': rawMap['id'],
      'fast_key_item_name': rawMap['name'],
      'fast_key_item_image':
      (rawMap['images'] is List && (rawMap['images'] as List).isNotEmpty)
          ? (rawMap['images'] as List).first
          : '',
      'fast_key_item_price': rawMap['price'] ?? '0',
      'fast_key_item_sku': rawMap['sku'] ?? '',
      'fast_key_item_min_age': 0,
      'has_age_restriction': false,
      'fast_key_item_tags': <Map<String, dynamic>>[],
      'variations': <dynamic>[],
      'type': rawMap['type'] ?? 'simple',
      'is_ebt_eligible': false,
    };
  }

  void _cacheDynamicProduct(Map<String, dynamic> product) {
    final name =
    (product['fast_key_item_name'] ?? '').toString().toLowerCase();
    if (name.isNotEmpty) _dynamicProductMemCache[name] = product;
  }

  Map<String, dynamic> _buildFallbackDynamicProduct({
    required int id,
    required String name,
    required String sku,
  }) =>
      {
        'fast_key_product_id': id,
        'fast_key_item_name': name,
        'fast_key_item_image': '',
        'fast_key_item_price': '0',
        'fast_key_item_sku': sku,
        'fast_key_item_min_age': 0,
        'has_age_restriction': false,
        'fast_key_item_tags': <Map<String, dynamic>>[],
        'variations': <dynamic>[],
        'type': 'simple',
        'is_ebt_eligible': false,
      };

  Future<Map<String, dynamic>?> _getCashbackProductFromIsar() async {
    final resolved = await _findDynamicProductByTokens([
      "cashback",
      "cash back",
      "cash-back",
      "cash_back",
      "cb",
    ]);
    if (resolved != null) return resolved;

    final fallback = _buildFallbackDynamicProduct(
      id: 3311101,
      name: "Cashback",
      sku: "CASHBACK-DYNAMIC",
    );
    _cacheDynamicProduct(fallback);
    return fallback;
  }

  Future<void> _addMerchantDiscount(double discountAmount) async {
    if (discountAmount <= 0) return;

    final discountProduct = await _getDiscountProductFromIsar();
    if (discountProduct == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Discount product not found. Please sync categories.')),
        );
      }
      return;
    }

    final orderId = await orderHelper.ensureOrderExists();
    if (orderId == null) return;

    await orderHelper.addItemToOrder(
      null,
      discountProduct['fast_key_item_name'],
      discountProduct['fast_key_item_image'],
      -discountAmount,
      1,
      discountProduct['fast_key_item_sku'],
      orderId,
      type: 'discount',
      productId: discountProduct['fast_key_product_id'],
      variationId: -1,
      salesPrice: -discountAmount,
      regularPrice: 0,
      unitPrice: 0,
      onItemAdded: () => _refreshOrderList(),
    );
  }

  Future<Map<String, dynamic>?> _getDiscountProductFromIsar() async {
    final resolved = await _findDynamicProductByTokens([
      "discount",
      "merchant discount",
      "merchant-discount",
      "merchant_discount",
    ]);
    if (resolved != null) return resolved;

    final fallback = _buildFallbackDynamicProduct(
      id: 899988,
      name: "Merchant Discount",
      sku: "MERCHANT-DISCOUNT-DYNAMIC",
    );
    _cacheDynamicProduct(fallback);
    return fallback;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pagination helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _shouldEnableLazyLoad() {
    if (!_autoLoadCompleted) return false;
    if (isShowingSubCategories) return false;
    if (isLoadingNestedContent) return false;
    return true;
  }

  void _resetPaginationState() {
    _visibleProductCount = _pageSize;
    _isPaginating = false;
    _hasMoreProductsToShow = false;
  }

  void _applyVisibleProducts({required bool reset}) {
    if (reset) _visibleProductCount = _pageSize;
    if (!_autoLoadCompleted) {
      categoryProducts = List<Map<String, dynamic>>.from(_allCategoryProducts);
      _hasMoreProductsToShow = false;
      reorderedIndices = List.filled(categoryProducts.length, null);
      return;
    }
    final int total = _allCategoryProducts.length;
    final int take = _visibleProductCount.clamp(0, total);
    categoryProducts = _allCategoryProducts.take(take).toList();
    _hasMoreProductsToShow = take < total;
    reorderedIndices = List.filled(categoryProducts.length, null);
  }

  Future<void> _loadMoreVisibleProducts() async {
    if (!_shouldEnableLazyLoad()) return;
    if (_isPaginating) return;
    if (!_hasMoreProductsToShow) return;
    setState(() => _isPaginating = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _visibleProductCount += _pageSize;
      _applyVisibleProducts(reset: false);
      _isPaginating = false;
    });
  }

  bool _onProductsScrollNotification(ScrollNotification notification) {
    if (!_shouldEnableLazyLoad()) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final remaining =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (remaining < 300) _loadMoreVisibleProducts();
    return false;
  }

  void _showAutoLoadingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1A1C2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white70 : Colors.grey;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: dialogBg,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF3B1F1F)
                        : const Color(0xFFFFEDED),
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      size: 34, color: Color(0xFFE74C3C)),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                    height: 34,
                    width: 34,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Color(0xFFE74C3C))),
                const SizedBox(height: 18),
                Text("Loading Categories",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                const SizedBox(height: 8),
                Text(
                  "Please wait while we securely sync your latest data.\nThis may not take much time. Do not close the app.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, height: 1.5, color: textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeOnlyDialog() {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  final Set<String> _hiddenCategoryNames = {
    "promotions",
    "uncategorized",
    "default",
    "custom product",
  };

  void _hideAutoLoadingDialog() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  // @override
  // void initState() {
  //   super.initState();
  //   orderBloc = OrderBloc(OrderRepository());
  //   _selectedSidebarIndex = widget.lastSelectedIndex ?? 1;
  //   _categoryBloc = CategoryBloc(CategoryRepository());
  //   reorderedIndices = List.filled(categoryProducts.length, null);
  //   _loadTopLevelCategories();
  //
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     await Future.delayed(const Duration(milliseconds: 1200));
  //     if (mounted) await _preserveSelectedOrder();
  //   });
  //
  //   // ── FIX: Register the refresh callback so TopBar can trigger a UI reload.
  //   // This MUST be in CategoriesScreen.initState, not in TopBar.initState,
  //   // because _forceReloadCurrentView() is a method of _CategoriesScreenState.
  //   TopBar.onRefreshCompleted = () async {
  //     if (!mounted) return;
  //     await _forceReloadCurrentView();
  //   };
  // }

  //// above code was old code
>>>>>>> origin/Grocery_pch_api_integration

  @override
  void initState() {
    super.initState();
    orderBloc = OrderBloc(OrderRepository());
<<<<<<< HEAD
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
=======
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 1;
    _categoryBloc = CategoryBloc(CategoryRepository());
    reorderedIndices = List.filled(categoryProducts.length, null);
    _loadTopLevelCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) await _preserveSelectedOrder();
    });

    // ── FIX: Register the refresh callback so TopBar can trigger a UI reload.
    TopBar.onRefreshCompleted = () async {
      if (!mounted) return;
      await _forceReloadCurrentView();
    };
>>>>>>> origin/Grocery_pch_api_integration
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
<<<<<<< HEAD
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

=======
  }

  @override
  void dispose() {
    // ── FIX: Clear the callback so TopBar doesn't call into a disposed state.
    TopBar.onRefreshCompleted = null;

    _categoryBloc.dispose();
    orderBloc.dispose();
    fastKeyTabIdNotifier.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Indigo pre-warm
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _preWarmAllIndigoData() async {
    if (_indigoPreWarmDone) return;
    _indigoPreWarmDone = true;
    if (kDebugMode) {
      print("⏱️ [Indigo] Full-tree pre-warm disabled — on-demand loads only");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Indigo UI loaders
  // FIX: Only skip if a fetch is ACTIVELY IN FLIGHT for this exact id.
  //      The old "already loaded" set guards are removed so _forceReloadCurrentView
  //      can always re-read fresh data from Isar after a product refresh.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadIndigoSubCategories(int parentCategoryId) async {
    if (!mounted) return;

    // Only skip concurrent duplicate calls — not previous loads.
    if (_inFlightIndigoSubParentId == parentCategoryId) return;

    _inFlightIndigoSubParentId = parentCategoryId;
    setState(() {
      _isLoadingIndigoSubCategories = true;
      _isLoadingIndigoProducts = false;
      _indigoError = null;
      _indigoProducts = [];
      _indigoSubCategories = [];
      _selectedIndigoSubCategoryIndex = null;
    });
    try {
      final response =
      await _connectorCategoryRepo.getCategories(parent: parentCategoryId);
      if (!mounted) return;

      final cats = response.categories.map((category) {
        return IndigoCategoryModel(
          id: category.id,
          name: category.name,
          slug: category.slug,
          parent: category.parent,
          description: category.description,
          count: category.count,
          image: category.image ?? '',
        );
      }).where((c) {
        final name = c.name.toLowerCase().trim();
        final slug = c.slug.toLowerCase().trim();
        return !_hiddenCategoryNames.contains(name) && slug != 'custom-product';
      }).toList();

      setState(() {
        _indigoSubCategories = cats;
        _isLoadingIndigoSubCategories = false;
        _indigoError = null;
        if (cats.isNotEmpty && !_isAutoLoading) {
          _selectedIndigoSubCategoryIndex = 0;
        }
      });

      if (kDebugMode)
        print(
            "[UI] Loaded ${cats.length} Indigo sub-categories for parent $parentCategoryId");

      if (!_isAutoLoading) {
        if (cats.isNotEmpty) {
          _loadIndigoProductsBySubCategory(cats[0].id);
        } else {
          _loadIndigoProductsBySubCategory(parentCategoryId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingIndigoSubCategories = false;
        _isLoadingIndigoProducts = false;
        _indigoError = 'Failed to load categories: $e';
      });
    } finally {
      if (_inFlightIndigoSubParentId == parentCategoryId) {
        _inFlightIndigoSubParentId = null;
      }
    }
  }

  Future<void> _loadIndigoProductsBySubCategory(int categoryId) async {
    if (!mounted) return;

    // Only skip concurrent duplicate calls — not previous loads.
    if (_inFlightIndigoProductCategoryId == categoryId) return;

    _inFlightIndigoProductCategoryId = categoryId;
    setState(() {
      _isLoadingIndigoProducts = true;
      _indigoError = null;
      _indigoProducts = [];
      _visibleIndigoProductCount = _indigoPageSize;
      _isIndigoPaginating = false;
    });
    try {
      final response =
      await _connectorCategoryRepo.getProductsByCategory(categoryId);
      final products = response.products.map((product) {
        return IndigoCategoryBasedProducts(
          id: product.id,
          name: product.name,
          sku: product.sku,
          price: product.price.toString(),
          regularPrice: product.regularPrice,
          salePrice: product.salePrice,
          categories: product.categories
              .map((category) => IndigoCategory(
            id: category.id,
            name: category.name,
            slug: category.slug,
          ))
              .toList(),
          tags: product.tags
              .map((tag) => IndigoTag(
            id: tag.id ?? 0,
            name: tag.name ?? '',
            slug: tag.slug ?? '',
          ))
              .toList(),
          images: product.images,
          taxRates: product.tax?.taxRates
              .map((rate) => IndigoTaxRate(
            label: rate.label,
            rate: rate.rate,
            compound: false,
            shipping: false,
          ))
              .toList() ??
              const [],
          type: product.type,
          metaData: product.metaData,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _indigoProducts = products;
        _isLoadingIndigoProducts = false;
      });
      if (kDebugMode)
        print(
            "[UI] Loaded ${products.length} Indigo products for sub-category $categoryId");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingIndigoProducts = false;
        _indigoError = 'Failed to load products: $e';
      });
    } finally {
      if (_inFlightIndigoProductCategoryId == categoryId) {
        _inFlightIndigoProductCategoryId = null;
      }
    }
  }

  Future<void> _loadMoreIndigoProducts() async {
    if (_isIndigoPaginating) return;
    if (_isLoadingIndigoProducts) return;
    if (_visibleIndigoProductCount >= _indigoProducts.length) return;

    setState(() => _isIndigoPaginating = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      _visibleIndigoProductCount += _indigoPageSize;
      _isIndigoPaginating = false;
    });
  }

  bool _onIndigoProductsScrollNotification(ScrollNotification notification) {
    if (_showCategoryGrid) return false;
    if (_indigoProducts.isEmpty) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final remaining =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (remaining < 260) _loadMoreIndigoProducts();
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Full order flow for Indigo products
  // ─────────────────────────────────────────────────────────────────────────

  void _onIndigoProductTapped(IndigoCategoryBasedProducts product) async {
    if (_productAddTapInFlight) return;
    _productAddTapInFlight = true;

    try {
      try {
        // REPLACE WITH:
        if (orderHelper.activeOrderId == null) {
          _cachedActiveOrderId = null;
        } else if (_cachedActiveOrderId != orderHelper.activeOrderId) {
          _cachedActiveOrderId = orderHelper.activeOrderId;
        }

        final ensureSw = Stopwatch()..start();
        _cachedActiveOrderId ??= await orderHelper.ensureOrderExists();
        print('[Cart] categories ensureOrderExists ${ensureSw.elapsedMilliseconds}ms → $_cachedActiveOrderId');

        if (_cachedActiveOrderId == null) {
          final msg = OrderHelper.lastEnsureOrderError ??
              "Failed to create or restore order. Please try again.";
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          return;
        }
        final int orderId = _cachedActiveOrderId!;

        if (kDebugMode) print("TAP [Indigo]: ${product.name}");

        final Map<String, dynamic> item = {
          'fast_key_product_id': product.id,
          'fast_key_item_name': product.name,
          'fast_key_item_image':
          product.images.isNotEmpty ? product.images.first : '',
          'fast_key_item_price': product.price,
          'fast_key_item_sku': product.sku,
          'fast_key_item_min_age': 0,
          'has_age_restriction': false,
          'fast_key_item_tags': <Map<String, dynamic>>[],
          'variations': <dynamic>[],
          'type': product.type,
          // NEW: Store meta_data (loyalty points etc.) - no breaking changes to old code
          'meta_data': product.metaData,
          'loyalty_points': product.metaData.any((m) => m['key'] == '_product_loyalty_points')
              ? int.tryParse(product.metaData.firstWhere((m) => m['key'] == '_product_loyalty_points')['value'].toString()) ?? 0
              : 0,
        };

        // Debug print - Loyalty Points (as you requested)
        final loyaltyMeta = product.metaData.firstWhere(
              (m) => m['key'] == '_product_loyalty_points',
          orElse: () => <String, dynamic>{},
        );
        if (loyaltyMeta.isNotEmpty) {
          print('🛒 Added product with loyalty points: ${product.name} → ${loyaltyMeta['value']}');
        }

        final int productId =
            int.tryParse(item["fast_key_product_id"].toString()) ?? -1;
// Skip slow Isar scan — tags are already on the product object
        final Map<String, dynamic>? cachedProduct = null;

        List<Map<String, dynamic>> tags = product.tags.map((t) {
          return {
            "id": t.id,
            "name": (t.name ?? "").trim(),
            "slug": (t.slug ?? "").trim().toLowerCase()
          };
        }).toList();

        if (tags.isEmpty &&
            cachedProduct != null &&
            cachedProduct["tags"] is List) {
          for (final t in (cachedProduct["tags"] as List)) {
            if (t is Map) tags.add(Map<String, dynamic>.from(t));
          }
        }

        int minAge = 0;
        for (final t in tags) {
          final slug = (t["slug"] ?? "").toString().trim();
          if (RegExp(r'^\d{1,2}$').hasMatch(slug)) {
            final age = int.tryParse(slug);
            if (age != null && age >= 18 && age <= 99) {
              minAge = age;
              break;
            }
          }
        }
        if (minAge == 0) {
          for (final t in tags) {
            final nameLower = (t["name"] ?? "").toString().toLowerCase().trim();
            if (nameLower.contains("age restricted") ||
                nameLower.contains("restricted") ||
                nameLower.contains("age verification") ||
                nameLower.contains("21+") ||
                nameLower.contains("18+")) {
              final combined = nameLower + " " + (t["slug"] ?? "");
              final match = RegExp(r'(\d{1,2})').firstMatch(combined);
              minAge = int.tryParse(match?.group(1) ?? "21") ?? 21;
              break;
            }
          }
        }

        final bool hasAgeRestriction = minAge >= 18;

        final String productName = product.name;
        bool isEbtEligible = item["is_ebt_eligible"] == true ||
            cachedProduct?["is_ebt_eligible"] == true;
        if (!isEbtEligible && tags.isNotEmpty) {
          isEbtEligible = tags.any((t) {
            final name = (t["name"] ?? "").toString().toLowerCase();
            final slug = (t["slug"] ?? "").toString().toLowerCase();
            return name.contains("ebt") || slug.contains("ebt");
          });
        }

        final dynamic priceSource = item["fast_key_item_price"] ??
            cachedProduct?["fast_key_item_price"] ??
            cachedProduct?["price"];
        var productPrice =
            double.tryParse(priceSource?.toString() ?? "0") ?? 0.0;
        final String productSku = cachedProduct?["sku"] ??
            item["fast_key_item_sku"] ??
            "SKU-$productId";
        final dynamic rawImage = cachedProduct?["fast_key_item_image"] ??
            cachedProduct?["image"] ??
            item["fast_key_item_image"];
        final String productImage = rawImage is String
            ? rawImage
            : (rawImage is Map ? rawImage["src"] ?? "" : "");
        final String resolvedType =
        (cachedProduct?["type"] ?? item["type"] ?? "")
            .toString()
            .toLowerCase();
        final bool hasVariants = (cachedProduct?["has_variants"] == true) ||
            (resolvedType == "variable" ||
                (item["variations"] != null &&
                    (item["variations"] as List).isNotEmpty));
        final dynamic minAgeSource =
            cachedProduct?["min_age"] ?? item["fast_key_item_min_age"];
        if (minAge == 0)
          minAge = int.tryParse(minAgeSource?.toString() ?? "0") ?? 0;

        final box = StorageProvider.offlineOrders;
        int activeOrderId = orderHelper.activeOrderId ??
            (await box.get('lastOrderId')) ??
            1000;
        if (orderHelper.activeOrderId == null) {
          orderHelper.activeOrderId = activeOrderId;
          await box.put('lastOrderId', activeOrderId);
        }

        if (hasAgeRestriction && minAge > 0) {
          final orderKey = activeOrderId.toString();
          final rawOrder = await box.get(orderKey);
          final hiveOrder =
          Map<String, dynamic>.from(rawOrder is Map ? rawOrder : {});
          final alreadyVerified = hiveOrder["age_verified"] == true ||
              hiveOrder["age_verified"] == 1 ||
              hiveOrder["age_verified"]?.toString().toLowerCase() == "true";
          if (!alreadyVerified) {
            final prov = AgeVerificationProvider();
            final isVerified =
            await prov.verifyAge(context, minAge: minAge);
            if (!isVerified) return;
            hiveOrder["age_verified"] = true;
            await box.put(orderKey, hiveOrder);
          }
        }

        // final bool hasProduceTag = tags.any((t) {
        //   final slug = (t["slug"] ?? "").toString().toLowerCase();
        //   final name = (t["name"] ?? "").toString().toLowerCase();
        //   return slug.contains("produce") || name.contains("produce");
        // });
        //
        // if (hasProduceTag) {
        //   final result = await showDialog(
        //       context: context,
        //       barrierDismissible: false,
        //       builder: (_) => AutoWeightPriceDialog(
        //           productName: productName, unitPrice: productPrice));
        //   if (result == null) return;
        //   await orderHelper.addItemToOrder(null, productName, productImage,
        //       result["finalPrice"], 1, productSku, activeOrderId,
        //       type: 'weighted',
        //       weightQty: (result["weight"] as num?)?.toDouble(),
        //       productId: productId,
        //       variationId: -1,
        //       salesPrice: result["finalPrice"],
        //       regularPrice: productPrice,
        //       unitPrice: productPrice,
        //       isEbtEligible: isEbtEligible,
        //       onItemAdded: () async => _refreshOrderList());
        //   return;
        // }

        // bala


// ─────────────────────────────────────────────────────────────────────────────
// PRODUCE / WEIGHTED ITEM — Use LIVE scale weight + Clear after add
// ─────────────────────────────────────────────────────────────────────────────
        final bool hasProduceTag = tags.any((t) {
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          final name = (t["name"] ?? "").toString().toLowerCase();
          return slug.contains("produce") || name.contains("produce");
        });

        if (hasProduceTag) {
          final weightProvider = Provider.of<WeightProvider>(context, listen: false);

          // Parse current weight from display text (weight is in lbs from scale)
          double liveWeightLbs = 0.0;
          try {
            final parts = weightProvider.weightText.trim().split(' ');
            if (parts.isNotEmpty) {
              liveWeightLbs = double.tryParse(parts[0]) ?? 0.0;
            }
          } catch (_) {}

          print('Live Weight (lbs): $liveWeightLbs');

          // finalPrice = unitPrice(per lb) * weight(lbs)
          final double finalPrice = liveWeightLbs > 0 ? productPrice * liveWeightLbs : 0.0;

          print('Unit Price: $productPrice | Weight: $liveWeightLbs lbs | Final Price: $finalPrice');

          // Store the weight value before adding
          final double weightToAdd = liveWeightLbs;

          // Add the item — send productPrice as the main price, finalPrice as salesPrice
          await orderHelper.addItemToOrder(
            null,
            productName,
            productImage,
            finalPrice,  // ← Unit price (per lb)
            1,
            productSku,
            activeOrderId,
            type: 'weighted',
            weightQty: weightToAdd,   // store weight in lbs
            productId: productId,
            variationId: -1,
            salesPrice: finalPrice,   // ← Total price (unit price × weight)
            regularPrice: productPrice,  // unit price per lb
            unitPrice: productPrice,     // unit price per lb
            isEbtEligible: isEbtEligible,
            onItemAdded: () async {
              _refreshOrderList();
              // Only clear after a short delay to ensure the item is saved
              Future.delayed(const Duration(milliseconds: 200), () {
                weightProvider.updateWeight(0.0);
              });
            },
          );
          return;
        }




        double finalPrice = productPrice;
        final bool hasVariablePriceTag = tags.any((t) {
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          final name = (t["name"] ?? "").toString().toLowerCase();
          return slug.contains("variable") || name.contains("variable");
        });

        if (hasVariablePriceTag && !hasVariants) {
          final orderKey = activeOrderId.toString();
          final rawOrder = await box.get(orderKey);
          final hiveOrder =
          Map<String, dynamic>.from(rawOrder is Map ? rawOrder : {});
          final variableKey = "variable_price_added_$productId";
          final savedPriceKey = "selected_price_$productId";
          final savedPrice = hiveOrder[savedPriceKey];
          if (savedPrice != null)
            productPrice =
                double.tryParse(savedPrice.toString()) ?? productPrice;
          final alreadyAddedBefore = hiveOrder[variableKey] == true ||
              hiveOrder[variableKey] == 1 ||
              hiveOrder[variableKey]?.toString().toLowerCase() == "true";
          if (alreadyAddedBefore) {
            finalPrice = savedPrice ?? productPrice;
            await orderHelper.addItemToOrder(null, productName, productImage,
                finalPrice, 1, productSku, activeOrderId,
                type: 'product',
                productId: productId,
                variationId: -1,
                salesPrice: finalPrice,
                regularPrice: productPrice,
                unitPrice: productPrice,
                isEbtEligible: isEbtEligible,
                // ✅ ADD THESE:
                metaData: product.metaData.map((m) => Map<String, dynamic>.from(m)).toList(),
                loyaltyPoints: product.metaData.any((m) => m['key'] == '_product_loyalty_points')
                    ? int.tryParse(product.metaData.firstWhere(
                        (m) => m['key'] == '_product_loyalty_points')['value'].toString()) ?? 0
                    : 0,
                onItemAdded: () async => _refreshOrderList());
            return;
          }
          final enteredPrice = await ManualPriceDialog.show(context,
              productName: productName,
              productImage: productImage,
              minPrice: productPrice);
          if (enteredPrice == null) return;
          finalPrice = enteredPrice;
          hiveOrder[variableKey] = true;
          hiveOrder[savedPriceKey] = finalPrice;
          await box.put(orderKey, hiveOrder);
        }

        if (hasVariants) {
          bool loadingDialogShown = false;
          if (mounted) {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                    canPop: false,
                    child: Center(child: CircularProgressIndicator())));
            loadingDialogShown = true;
          }
          List<Map<String, dynamic>> offlineVariations = [];
          try {
            final productBox = StorageProvider.productCache;
            final cacheKey = "product_${productId}_variations";
            final cachedData = await productBox.get(cacheKey);
            List rawVariations = [];
            if (cachedData != null) {
              if (cachedData is Map && cachedData["variations"] is List)
                rawVariations = cachedData["variations"];
              else if (cachedData is List)
                rawVariations = cachedData;
              else if (cachedData is String) {
                try {
                  final decoded = jsonDecode(cachedData);
                  rawVariations =
                  decoded is Map ? decoded["variations"] ?? [] : decoded;
                } catch (_) {}
              }
            }
            offlineVariations = rawVariations
                .map<Map<String, dynamic>>((v) {
              if (v is String) {
                try {
                  v = jsonDecode(v);
                } catch (_) {}
              }
              if (v is Map) {
                final map =
                v.map((key, value) => MapEntry(key.toString(), value));
                map["image"] =
                (map["image"] is Map && map["image"]["src"] != null)
                    ? map["image"]["src"]
                    : (map["image"] is String ? map["image"] : "");
                map["name"] =
                (map["name"] is Map &&
                    map["name"]["rendered"] != null)
                    ? map["name"]["rendered"]
                    : (map["name"] is String
                    ? map["name"]
                    : "Unnamed Variant");
                map["price"] = map["price"]?.toString() ?? "0";

                // ✅ FIX: Preserve meta_data from cache
                if (map["meta_data"] is List) {
                  map["meta_data"] = (map["meta_data"] as List)
                      .whereType<Map>()
                      .map((m) => Map<String, dynamic>.from(m))
                      .toList();
                } else {
                  // ⚠️ If meta_data is missing, try to fetch it from the raw variation
                  // This happens when the cache was created before meta_data was supported
                  map["meta_data"] = <Map<String, dynamic>>[];
                }

                // ✅ Extract loyalty points from meta_data
                final metaData = map["meta_data"] as List<Map<String, dynamic>>;
                final loyaltyMeta = metaData.firstWhere(
                      (m) => m['key'] == '_product_loyalty_points',
                  orElse: () => <String, dynamic>{},
                );
                map["loyalty_points"] = loyaltyMeta.isNotEmpty
                    ? int.tryParse(loyaltyMeta['value']?.toString() ?? '0') ?? 0
                    : 0;

                // 🔍 DEBUG: Log variant data
                print('📦 [Variant Cache] Variant ID: ${map["id"]}, Name: ${map["name"]}, Loyalty: ${map["loyalty_points"]}, MetaCount: ${(map["meta_data"] as List).length}');

                return map;
              }
              return <String, dynamic>{};
            })
                .where((v) => v.isNotEmpty)
                .toList();

            if (offlineVariations.isEmpty && productId > 0) {
              await _clearVariantCacheForProduct(productId);

              final fetched = await _fetchVariationsFromApi(productId);
              if (fetched.isNotEmpty) {
                offlineVariations = fetched;
                await productBox.put(cacheKey, {
                  "variations": fetched,
                  "timestamp": DateTime.now().toIso8601String(),
                });
              }
            }
          } catch (e, st) {
            if (kDebugMode) {
              print("⚠️ [Indigo] Error loading variations: $e");
              print(st);
            }
          }

          if (offlineVariations.isEmpty) {
            if (mounted && loadingDialogShown)
              Navigator.of(context, rootNavigator: true).pop();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                Text("No variants available for this product right now."),
                duration: Duration(seconds: 2),
              ));
            }
            return;
          }

          if (mounted && loadingDialogShown)
            Navigator.of(context, rootNavigator: true).pop();
          await showDialog(
            context: context,
            builder: (ctx) => VariantsDialog(
              title: productName,
              variations: offlineVariations,
              onAddVariant: (selectedVariant, qty) async {
                final variantId =
                    int.tryParse(selectedVariant["id"].toString()) ?? -1;
                final variantName = selectedVariant["name"] ?? "Variant";

                // ✅ Use variant price
                final variantPrice =
                    double.tryParse(selectedVariant["price"].toString()) ??
                        productPrice;

                final variantSku = selectedVariant["sku"] ?? productSku;
                final variantImage = selectedVariant["image"] ?? productImage;

                // ✅ Extract meta_data from selected variant
                final List<Map<String, dynamic>> variantMetaData =
                selectedVariant["meta_data"] is List
                    ? List<Map<String, dynamic>>.from(selectedVariant["meta_data"])
                    : <Map<String, dynamic>>[];

                // ✅ Extract loyalty points - try multiple sources
                int variantLoyaltyPoints = 0;

                // Source 1: From meta_data
                final loyaltyMeta = variantMetaData.firstWhere(
                      (m) => m['key'] == '_product_loyalty_points',
                  orElse: () => <String, dynamic>{},
                );
                if (loyaltyMeta.isNotEmpty) {
                  variantLoyaltyPoints = int.tryParse(loyaltyMeta['value']?.toString() ?? '0') ?? 0;
                }

                // Source 2: Direct loyalty_points field
                if (variantLoyaltyPoints == 0) {
                  variantLoyaltyPoints = int.tryParse(
                      selectedVariant["loyalty_points"]?.toString() ?? '0') ?? 0;
                }

                // Source 3: If still 0 and there's a parent product meta_data, use that
                if (variantLoyaltyPoints == 0 && product.metaData.isNotEmpty) {
                  final parentLoyalty = product.metaData.firstWhere(
                        (m) => m['key'] == '_product_loyalty_points',
                    orElse: () => <String, dynamic>{},
                  );
                  if (parentLoyalty.isNotEmpty) {
                    variantLoyaltyPoints = int.tryParse(parentLoyalty['value']?.toString() ?? '0') ?? 0;
                    print('🔄 [Variant] Using parent loyalty points: $variantLoyaltyPoints');
                  }
                }

                final int finalLoyaltyPoints = variantLoyaltyPoints;

                // 🔍 DEBUG: Print loyalty points for the selected variant
                print('🛒 [Categories] Added variant: $variantName');
                print('  → Variant ID: $variantId');
                print('  → Variant Price: $variantPrice');
                print('  → Variant SKU: $variantSku');
                print('  → MetaData count: ${variantMetaData.length}');
                print('  → Loyalty Points (final): $finalLoyaltyPoints');

                await orderHelper.addItemToOrder(
                    0,
                    variantName,
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
                    metaData: variantMetaData,
                    loyaltyPoints: finalLoyaltyPoints,
                    onItemAdded: () async => _refreshOrderList()
                );
              },
            ),
          );
        } else {
          // await orderHelper.addItemToOrder(null, productName, productImage,
          //     finalPrice, 1, productSku, activeOrderId,
          //     type: 'product',
          //     productId: productId,
          //     variationId: -1,
          //     salesPrice: finalPrice,
          //     regularPrice: productPrice,
          //     unitPrice: productPrice,
          //     isEbtEligible: isEbtEligible,
          //     onItemAdded: () async => _refreshOrderList());

          await orderHelper.addItemToOrder(null, productName, productImage,
              finalPrice, 1, productSku, activeOrderId,
              type: 'product',
              productId: productId,
              variationId: -1,
              salesPrice: finalPrice,
              regularPrice: productPrice,
              unitPrice: productPrice,
              isEbtEligible: isEbtEligible,
              // ✅ ADD THESE:
              metaData: product.metaData.map((m) => Map<String, dynamic>.from(m)).toList(),
              loyaltyPoints: product.metaData.any((m) => m['key'] == '_product_loyalty_points')
                  ? int.tryParse(product.metaData.firstWhere(
                      (m) => m['key'] == '_product_loyalty_points')['value'].toString()) ?? 0
                  : 0,
              onItemAdded: () async => _refreshOrderList());
        }
      } catch (e, s) {
        if (kDebugMode) {
          print("❌ [Indigo] ERROR: $e");
          print(s);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(TextConstants.errorAddingItem),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)));
        }
      }
    } finally {
      _productAddTapInFlight = false;
    }
  }

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(
      int productId) async {
    try {
      if (_productMetaCache.isNotEmpty) {
        return _productMetaCache[productId];
      }
      if (_isProductMetaCacheLoaded) {
        return null;
      }

      final isar = await IsarService.instance;
      final allEntries = await isar.isarCacheEntrys
          .where()
          .filter()
          .keyStartsWith('products_')
          .findAll();
      for (final entry in allEntries) {
        final List<dynamic> products = json.decode(entry.json);
        for (final product in products) {
          if (product is! Map) continue;
          final map = Map<String, dynamic>.from(product);
          final dynamic idRaw =
              map['fast_key_product_id'] ?? map['id'];
          final int? id = int.tryParse(idRaw?.toString() ?? '');
          if (id != null) {
            _productMetaCache[id] = map;
          }
        }
      }
      _isProductMetaCacheLoaded = true;
      return _productMetaCache[productId];
    } catch (e) {
      if (kDebugMode) print("_getCachedProductFromIsar error: $e");
      return null;
    }
  }

  // Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(
  //     int productId) async {
  //   try {
  //     final token = await _getAuthTokenFromDb();
  //     final url = Uri.parse(
  //         "${UrlHelper.baseUrl}${UrlHelper.wooCommerceV3}products/$productId/variations");
  //     final response =
  //     await http.get(url, headers: {"Authorization": "Bearer $token"});
  //     if (response.statusCode != 200) return <Map<String, dynamic>>[];
  //     final decoded = jsonDecode(response.body);
  //     if (decoded is! List) return <Map<String, dynamic>>[];
  //
  //     return decoded
  //         .whereType<Map>()
  //         .map<Map<String, dynamic>>((v) {
  //       final map =
  //       v.map((key, value) => MapEntry(key.toString(), value));
  //       final attrs = map["attributes"];
  //       final String fallbackName = attrs is List
  //           ? attrs
  //           .whereType<Map>()
  //           .map((a) => (a["option"] ?? "").toString())
  //           .where((x) => x.isNotEmpty)
  //           .join(" - ")
  //           : "";
  //       return {
  //         "id": map["id"],
  //         "name": (map["name"] ?? "").toString().isNotEmpty
  //             ? map["name"]
  //             : (fallbackName.isNotEmpty
  //             ? fallbackName
  //             : "Unnamed Variant"),
  //         "price":
  //         (map["price"] ?? map["regular_price"] ?? "0").toString(),
  //         "sku": map["sku"] ?? "",
  //         "image":
  //         (map["image"] is Map && map["image"]["src"] != null)
  //             ? map["image"]["src"]
  //             : (map["image"] is String ? map["image"] : ""),
  //       };
  //     })
  //         .where((v) => v["id"] != null)
  //         .toList();
  //   } catch (_) {
  //     return <Map<String, dynamic>>[];
  //   }
  // }

  Future<List<Map<String, dynamic>>> _fetchVariationsFromApi(
      int productId) async {
    try {
      final token = await _getAuthTokenFromDb();
      // Connector: GET /store/{storeId}/products/{productId}/variations
      final urlString =
      await ProductRepository.buildVariationsUrl(productId);
      final url = Uri.parse(urlString);
      final response =
      await http.get(url, headers: {"Authorization": "Bearer $token"});

      if (kDebugMode) {
        print("🌍 [Variations API] GET $url");
        print("🌍 [Variations API] status: ${response.statusCode}");
      }

      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return <Map<String, dynamic>>[];

      final result = decoded.whereType<Map>().map<Map<String, dynamic>>((v) {
        final map = v.map((key, value) => MapEntry(key.toString(), value));
        final attrs = map["attributes"];
        final String fallbackName = attrs is List
            ? attrs
            .whereType<Map>()
            .map((a) => (a["option"] ?? "").toString())
            .where((x) => x.isNotEmpty)
            .join(" - ")
            : "";

        // ✅ CRITICAL FIX: Extract meta_data properly
        List<Map<String, dynamic>> metaData = [];
        if (map["meta_data"] is List) {
          metaData = (map["meta_data"] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }

        // ✅ Extract loyalty points from meta_data
        final loyaltyEntry = metaData.firstWhere(
              (m) => m['key']?.toString() == '_product_loyalty_points',
          orElse: () => <String, dynamic>{},
        );
        final int loyaltyPoints = loyaltyEntry.isNotEmpty
            ? int.tryParse(loyaltyEntry['value']?.toString() ?? '') ?? 0
            : 0;

        if (kDebugMode) {
          print("  📦 [Variations API] Variant ID=${map['id']}, Name=${fallbackName.isNotEmpty ? fallbackName : map['name']}, Loyalty=$loyaltyPoints, MetaCount=${metaData.length}");
        }

        return {
          "id": map["id"],
          "name": (map["name"] ?? "").toString().isNotEmpty
              ? map["name"]
              : (fallbackName.isNotEmpty ? fallbackName : "Unnamed Variant"),
          "price": (map["price"] ?? map["regular_price"] ?? "0").toString(),
          "sku": map["sku"] ?? "",
          "image": (map["image"] is Map && map["image"]["src"] != null)
              ? map["image"]["src"]
              : (map["image"] is String ? map["image"] : ""),
          "meta_data": metaData,  // ✅ CRITICAL: Store meta_data in cached variant
          "loyalty_points": loyaltyPoints,  // ✅ Also store directly for quick access
        };
      }).where((v) => v["id"] != null).toList();

      return result;
    } catch (e, s) {
      if (kDebugMode) {
        print("❌ [Variations API] error: $e");
        print(s);
      }
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

  Future<void> _waitForNestedLoadingOrTimeout() async {
    final stopwatch = Stopwatch()..start();
    const timeout = Duration(seconds: 15);
    while (mounted && isLoadingNestedContent && stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Original category methods
  // ─────────────────────────────────────────────────────────────────────────

  // Future<void> _autoTapAllCategories() async {
  //   if (categories.isEmpty || _hasAutoTappedOnce) return;
  //   _hasAutoTappedOnce = true;
  //   setState(() {
  //     _isAutoLoading = true;
  //     _autoLoadCompleted = false;
  //   });
  //   _showAutoLoadingDialog();
  //   final prefs = await SharedPreferences.getInstance();
  //   final int? saved = prefs.getInt('lastSelectedCategoryIndex');
  //   final int tapIndex =
  //   (saved != null && saved >= 0 && saved < categories.length) ? saved : 0;
  //   if (!mounted) return;
  //   _scrollToCategory(tapIndex);
  //   await Future.delayed(const Duration(milliseconds: 250));
  //   _onCategoryTapped(tapIndex);
  //   await _waitForNestedLoadingOrTimeout();
  //   await Future.delayed(const Duration(milliseconds: 300));
  //   _preWarmAllIndigoData();
  //   _hideAutoLoadingDialog();
  //   if (!mounted) return;
  //   setState(() {
  //     _isAutoLoading = false;
  //     _autoLoadCompleted = true;
  //   });
  //   if (_selectedCategoryIndex != null &&
  //       _selectedCategoryIndex! >= 0 &&
  //       _selectedCategoryIndex! < categories.length) {
  //     final int parentCategoryId = categories[_selectedCategoryIndex!].id;
  //     final int targetCategoryId = _indigoSubCategories.isNotEmpty
  //         ? _indigoSubCategories.first.id
  //         : parentCategoryId;
  //     _loadIndigoProductsBySubCategory(targetCategoryId);
  //   }
  // }
  // Future<void> _autoTapAllCategories() async {
  //   if (categories.isEmpty || _hasAutoTappedOnce) return;
  //   _hasAutoTappedOnce = true;
  //   setState(() {
  //     _isAutoLoading = true;
  //     _autoLoadCompleted = false;
  //   });
  //   _showAutoLoadingDialog();
  //   final prefs = await SharedPreferences.getInstance();
  //   final int? saved = prefs.getInt('lastSelectedCategoryIndex');
  //   final int tapIndex =
  //   (saved != null && saved >= 0 && saved < categories.length) ? saved : 0;
  //   if (!mounted) return;
  //   _scrollToCategory(tapIndex);
  //   await Future.delayed(const Duration(milliseconds: 250));
  //   _onCategoryTapped(tapIndex);
  //   await _waitForNestedLoadingOrTimeout();
  //   await Future.delayed(const Duration(milliseconds: 300));
  //   _preWarmAllIndigoData();
  //   _hideAutoLoadingDialog();
  //   if (!mounted) return;
  //   setState(() {
  //     _isAutoLoading = false;
  //     _autoLoadCompleted = true;
  //     // FIX: Always land back on the "All" tab after the background
  //     // pre-warm/auto-tap finishes, instead of staying on whichever
  //     // category _onCategoryTapped(tapIndex) opened internally above.
  //     // The pre-warm itself (sub-categories + products fetch/cache) is
  //     // untouched — this only affects what's shown once it's done.
  //     _showCategoryGrid = true;
  //   });
  //   if (_selectedCategoryIndex != null &&
  //       _selectedCategoryIndex! >= 0 &&
  //       _selectedCategoryIndex! < categories.length) {
  //     final int parentCategoryId = categories[_selectedCategoryIndex!].id;
  //     final int targetCategoryId = _indigoSubCategories.isNotEmpty
  //         ? _indigoSubCategories.first.id
  //         : parentCategoryId;
  //     _loadIndigoProductsBySubCategory(targetCategoryId);
  //   }
  // }

  /////// above code old code


  Future<void> _autoTapAllCategories() async {
    if (categories.isEmpty || _hasAutoTappedOnce) return;
    _hasAutoTappedOnce = true;
    setState(() {
      _isAutoLoading = true;
      _autoLoadCompleted = false;
    });
    _showAutoLoadingDialog();
    final prefs = await SharedPreferences.getInstance();
    final int? saved = prefs.getInt('lastSelectedCategoryIndex');
    final int tapIndex =
    (saved != null && saved >= 0 && saved < categories.length) ? saved : 0;
    if (!mounted) return;
    _scrollToCategory(tapIndex);
    await Future.delayed(const Duration(milliseconds: 250));
    _onCategoryTapped(tapIndex);
    await _waitForNestedLoadingOrTimeout();
    await Future.delayed(const Duration(milliseconds: 300));
    _preWarmAllIndigoData();
    _hideAutoLoadingDialog();
    if (!mounted) return;
    setState(() {
      _isAutoLoading = false;
      _autoLoadCompleted = true;
      // FIX: Always land back on the "All" tab after the background
      // pre-warm/auto-tap finishes, instead of staying on whichever
      // category _onCategoryTapped(tapIndex) opened internally above.
      _showCategoryGrid = true;
      // Also clear the selected category index to show All
      _selectedCategoryIndex = null;
      _selectedSubCategoryIndex = null;
      _indigoSubCategories = [];
      _indigoProducts = [];
      _selectedIndigoSubCategoryIndex = null;
    });
    // No need to load products for a specific category when showing "All"
    // Just clear the recent categories or keep them as is
  }



  Future<void> _loadLastSelectedCategory() async {
    if (categories.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt('lastSelectedCategoryIndex');
    final int safeIndex =
    (index != null && index >= 0 && index < categories.length) ? index : 0;
    if (!mounted) return;
    if (safeIndex < categories.length) {
      _addToRecent(categories[safeIndex]);
    }
    setState(() {
      _selectedCategoryIndex = safeIndex;
      _showCategoryGrid = false;
      navigationPath = [categories[safeIndex].name];
      categoryHierarchy = [0, categories[safeIndex].id];
      currentCategoryLevel = 1;
      isShowingSubCategories = true;
      isLoadingNestedContent = true;
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
    });
    await _loadSubCategories(categories[safeIndex].id);
    _loadIndigoSubCategories(categories[safeIndex].id);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToCategory(safeIndex));
    await prefs.setInt('lastSelectedCategoryIndex', safeIndex);
  }

  void _scrollToCategory(int index) {
    if (!_categoryScrollController.hasClients) return;
    final position = _categoryScrollController.position;
    final double itemWidth = ResponsiveLayout.getHeight(80) + 10;
    final double screenWidth = MediaQuery.of(context).size.width;
    double offset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    offset = offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    _categoryScrollController.animateTo(offset,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

>>>>>>> origin/Grocery_pch_api_integration
  Future<void> _saveLastSelectedCategory(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSelectedCategoryIndex', index);
  }

<<<<<<< HEAD
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
=======
  bool _shouldHideCategory(CategoryModel category) {
    final String name = category.name.toLowerCase().trim();
    final String slug = (category.slug ?? '').toLowerCase().trim();
    if (_hiddenCategoryNames.contains(name)) return true;
    if (slug == 'custom-product') return true;
    return false;
  }

  List<CategoryModel> get visibleCategories {
    return categories.where((c) => !_shouldHideCategory(c)).toList();
  }

  void _addToRecent(CategoryModel category) {
    if (_shouldHideCategory(category)) return;
    _recentCategories.removeWhere((c) => c.id == category.id);
    _recentCategories.insert(0, category);
    if (_recentCategories.length > _maxRecentCategories) {
      _recentCategories.removeRange(
          _maxRecentCategories, _recentCategories.length);
    }
  }

  // Future<void> _loadTopLevelCategories() async {
  //   if (categories.isEmpty) {
  //     setState(() {
  //       isLoading = true;
  //       isLoadingNestedContent = true;
  //     });
  //   } else {
  //     setState(() {
  //       isLoadingNestedContent = true;
  //     });
  //   }
  //   _categoryBloc.fetchCategories(0);
  //   try {
  //     await for (final response in _categoryBloc.categoriesStream
  //         .timeout(const Duration(seconds: 25))) {
  //       if (!mounted) break;
  //       if (response.status == Status.COMPLETED && response.data != null) {
  //         categories = response.data!.categories;
  //
  //         _preLoadDefaultCategoryProducts(categories);
  //
  //         setState(() {
  //           isLoading = false;
  //           isLoadingNestedContent = false;
  //         });
  //         final bool isProductCacheEmpty = await _isProductCacheEmpty();
  //         if (isProductCacheEmpty) {
  //           WidgetsBinding.instance
  //               .addPostFrameCallback((_) => _autoTapAllCategories());
  //         } else {
  //           setState(() => _autoLoadCompleted = true);
  //           _preWarmAllIndigoData();
  //           await _loadLastSelectedCategory();
  //         }
  //         // final bool isProductCacheEmpty = await _isProductCacheEmpty();
  //         // if (isProductCacheEmpty) {
  //         //   WidgetsBinding.instance
  //         //       .addPostFrameCallback((_) => _autoTapAllCategories());
  //         // } else {
  //         //   setState(() => _autoLoadCompleted = true);
  //         //   _preWarmAllIndigoData();
  //         //   // REMOVED: await _loadLastSelectedCategory();
  //         //   // We no longer auto-jump into the last selected category on startup.
  //         //   // The screen now always opens on the "All" categories grid
  //         //   // (_showCategoryGrid defaults to true). Recent categories still get
  //         //   // populated normally the moment the user taps any category, via
  //         //   // _addToRecent() inside _onCategoryTapped().
  //         // }
  //         break;
  //       }
  //       if (response.status == Status.ERROR) {
  //         setState(() {
  //           isLoading = false;
  //           isLoadingNestedContent = false;
  //         });
  //         if (response.message?.contains("Unauthorised") ?? false) {
  //           Navigator.pushReplacement(
  //               context, MaterialPageRoute(builder: (_) => LoginScreen()));
  //         }
  //         break;
  //       }
  //     }
  //   } on TimeoutException {
  //     if (!mounted) return;
  //     setState(() {
  //       isLoading = false;
  //       isLoadingNestedContent = false;
  //     });
  //   }
  // }

  //// above code was to old code

  Future<void> _loadTopLevelCategories() async {
    if (categories.isEmpty) {
      setState(() {
        isLoading = true;
        isLoadingNestedContent = true;
      });
    } else {
      setState(() {
        isLoadingNestedContent = true;
      });
    }
    _categoryBloc.fetchCategories(0);
    try {
      await for (final response in _categoryBloc.categoriesStream
          .timeout(const Duration(seconds: 25))) {
        if (!mounted) break;
        if (response.status == Status.COMPLETED && response.data != null) {
          categories = response.data!.categories;

          _preLoadDefaultCategoryProducts(categories);

          setState(() {
            isLoading = false;
            isLoadingNestedContent = false;
          });
          final bool isProductCacheEmpty = await _isProductCacheEmpty();
          if (isProductCacheEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _autoTapAllCategories());
          } else {
            setState(() => _autoLoadCompleted = true);
            _preWarmAllIndigoData();
            // REMOVED: await _loadLastSelectedCategory();
            // We always want to show "All" by default
            // Ensure the "All" tab is selected
            setState(() {
              _showCategoryGrid = true;
              _selectedCategoryIndex = null;
              _selectedSubCategoryIndex = null;
              _indigoSubCategories = [];
              _indigoProducts = [];
              _selectedIndigoSubCategoryIndex = null;
            });
          }
          break;
        }
        if (response.status == Status.ERROR) {
          setState(() {
            isLoading = false;
            isLoadingNestedContent = false;
          });
          if (response.message?.contains("Unauthorised") ?? false) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LoginScreen()));
          }
          break;
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isLoadingNestedContent = false;
      });
    }
  }

  Future<void> _loadSubCategories(int parentId) async {
    if (_inFlightSubCategoryParentId == parentId) return;
    _inFlightSubCategoryParentId = parentId;
    setState(() {
      isLoadingNestedContent = true;
      _categoryContentError = null;
    });
    _categoryBloc.fetchCategories(parentId);
    try {
      await for (final response in _categoryBloc.categoriesStream
          .timeout(const Duration(seconds: 25))) {
        if (!mounted) break;
        if (response.status == Status.COMPLETED && response.data != null) {
          setState(() {
            subCategories = response.data!.categories;
            _categoryContentError = null;
            isShowingSubCategories = true;
            _resetPaginationState();
            _allCategoryProducts.clear();
            categoryProducts.clear();
            _selectedSubCategoryIndex = null;
            isLoadingNestedContent = false;
          });

          if (subCategories.isNotEmpty && !_isAutoLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onSubCategoryTapped(0);
            });
          }

          if (Misc.enableCategoryProductWithSubCategoryList ||
              subCategories.isEmpty) {
            _loadProductsByCategory(parentId);
          }
          break;
        }
        if (response.status == Status.ERROR) {
          setState(() {
            _categoryContentError =
                response.message ?? 'Failed to load categories.';
            isLoadingNestedContent = false;
          });
          break;
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _categoryContentError = 'Loading categories timed out.';
        isLoadingNestedContent = false;
      });
    } finally {
      if (_inFlightSubCategoryParentId == parentId) {
        _inFlightSubCategoryParentId = null;
      }
>>>>>>> origin/Grocery_pch_api_integration
    }
  }

  Future<void> _loadProductsByCategory(int categoryId) async {
<<<<<<< HEAD
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
=======
    if (_inFlightProductCategoryId == categoryId) return;
    _inFlightProductCategoryId = categoryId;
    setState(() {
      isLoadingNestedContent = true;
      _categoryContentError = null;
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
    });
    _categoryBloc.fetchProductsByCategory(categoryId);
    try {
      await for (final response in _categoryBloc.productsStream
          .timeout(const Duration(seconds: 30))) {
        if (!mounted) break;
        if (response.status == Status.COMPLETED && response.data != null) {
          final Map<int, Map<String, dynamic>> uniqueProducts = {};
          for (final product in response.data!.products) {
            final tags = (product.tags ?? [])
                .map((t) => {
              "id": t.id,
              "name": (t.name ?? "").toString().toLowerCase(),
              "slug": (t.slug ?? "").toString().toLowerCase(),
            })
                .toList();
            final ageRestrictedLower =
            TextConstants.age_restricted.toLowerCase();
            final ageTag = tags.firstWhere(
                  (t) =>
              (t["name"]?.toString() ?? "").toLowerCase() ==
                  ageRestrictedLower ||
                  (t["slug"]?.toString() ?? "").toLowerCase() ==
                      ageRestrictedLower,
              orElse: () => <String, dynamic>{},
            );
            int minAge =
                int.tryParse(ageTag["slug"]?.toString() ?? "0") ?? 0;
            if (minAge == 0 && ageTag.isNotEmpty) minAge = 18;

            final bool isEbtEligible = tags.any((t) {
              final name = (t["name"] ?? "").toString().toLowerCase();
              final slug = (t["slug"] ?? "").toString().toLowerCase();
              return name.contains("ebt") || slug.contains("ebt");
            });

            final bool hasVariantsFlag =
                (product.type?.toLowerCase() == "variable") ||
                    ((product.variations?.isNotEmpty) ?? false);
            uniqueProducts[product.id] = {
              'fast_key_product_id': product.id,
              'fast_key_item_name': product.name,
              'fast_key_item_image':
              product.images.isNotEmpty ? product.images.first : '',
              'fast_key_item_price': product.price,
              'fast_key_item_sku': product.sku ?? '',
              'fast_key_item_min_age': minAge,
              'has_age_restriction': minAge > 0,
              'fast_key_item_tags': tags,
              'variations': product.variations,
              'type': product.type,
              'is_ebt_eligible': isEbtEligible,
              'has_variants': hasVariantsFlag,
            };
          }
          setState(() {
            _allCategoryProducts
              ..clear()
              ..addAll(uniqueProducts.values);
            _applyVisibleProducts(reset: true);
            isShowingSubCategories = false;
            isLoadingNestedContent = false;
          });
          break;
        }
        if (response.status == Status.ERROR) {
          setState(() {
            _categoryContentError =
                response.message ?? 'Failed to load products.';
            isLoadingNestedContent = false;
          });
          break;
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _categoryContentError = 'Loading products timed out.';
        isLoadingNestedContent = false;
      });
    } finally {
      if (_inFlightProductCategoryId == categoryId) {
        _inFlightProductCategoryId = null;
>>>>>>> origin/Grocery_pch_api_integration
      }
    }
  }

  void _onCategoryTapped(int index) {
<<<<<<< HEAD
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
=======
    if (index < 0 || index >= categories.length) return;
    if (_selectedCategoryIndex == index && !_showCategoryGrid) return;

    _addToRecent(categories[index]);

    setState(() {
      _selectedCategoryIndex = index;
      _showCategoryGrid = false;
      _categoryContentError = null;
      navigationPath = [categories[index].name];
      subCategories.clear();
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
      isShowingSubCategories = true;
      categoryHierarchy = [0, categories[index].id];
      currentCategoryLevel = 1;
      _selectedSubCategoryIndex = null;
      isLoadingNestedContent = true;
    });
    _saveLastSelectedCategory(index);
    _loadSubCategories(categories[index].id);
    _loadIndigoSubCategories(categories[index].id);
  }

  Future<bool> _isProductCacheEmpty() async {
    try {
      final isar = await IsarService.instance;
      final any = await isar.isarCacheEntrys
          .where()
          .filter()
          .keyStartsWith('products_')
          .findFirst();
      return any == null;
    } catch (e) {
      return true;
    }
  }

  void _onSubCategoryTapped(int index) {
    if (index < 0 || index >= subCategories.length) return;
    final selectedSubCategory = subCategories[index];
    setState(() {
      _selectedSubCategoryIndex = index;
      _categoryContentError = null;
      if (currentCategoryLevel < categoryHierarchy.length) {
        navigationPath = navigationPath.sublist(0, currentCategoryLevel);
        categoryHierarchy =
            categoryHierarchy.sublist(0, currentCategoryLevel + 1);
>>>>>>> origin/Grocery_pch_api_integration
      }
      navigationPath.add(selectedSubCategory.name);
      categoryHierarchy.add(selectedSubCategory.id);
      currentCategoryLevel++;
      isShowingSubCategories = true;
<<<<<<< HEAD
      categoryProducts.clear();
      isLoadingNestedContent = true; // Add this line to show shimmer
    });

    if (kDebugMode) print("_onSubCategoryTapped: currentCategoryLevel -> $currentCategoryLevel");
    if (kDebugMode) print("_onSubCategoryTapped: selectedSubCategory ID -> ${selectedSubCategory.id}"); // DEBUG
    if (kDebugMode) print("_onSubCategoryTapped: subCategories length -> ${subCategories.length}");
    _loadSubCategories(selectedSubCategory.id);
  }

=======
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
      isLoadingNestedContent = true;
    });
    _loadSubCategories(selectedSubCategory.id);
  }
  Future<void> _clearVariantCacheForProduct(int productId) async {
    try {
      final productBox = StorageProvider.productCache;
      final cacheKey = "product_${productId}_variations";
      await productBox.delete(cacheKey);
      if (kDebugMode) {
        print('🗑️ [Cache] Cleared variant cache for product $productId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [Cache] Failed to clear variant cache: $e');
      }
    }
  }
>>>>>>> origin/Grocery_pch_api_integration
  void _onBackToCategories() {
    if (currentCategoryLevel > 0) {
      setState(() {
        currentCategoryLevel--;
        navigationPath.removeLast();
        categoryHierarchy.removeLast();
        isShowingSubCategories = true;
<<<<<<< HEAD
        categoryProducts.clear();
        _selectedSubCategoryIndex = null;
      });

=======
        _resetPaginationState();
        _allCategoryProducts.clear();
        categoryProducts.clear();
        _selectedSubCategoryIndex = null;
      });
>>>>>>> origin/Grocery_pch_api_integration
      if (currentCategoryLevel == 0) {
        _loadSubCategories(categories[_selectedCategoryIndex!].id);
      } else {
        _loadSubCategories(categoryHierarchy.last);
      }
    }
  }

<<<<<<< HEAD
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
=======
  Stopwatch? refreshUIStopwatch;

>>>>>>> origin/Grocery_pch_api_integration
  void _onItemSelected(int index, bool variantAdded) async {
    if (index == 0 && showBackButton) {
      _onBackToCategories();
      return;
    }
<<<<<<< HEAD

    // fix for parent product also adding along with variant product , we have to restrict that like categories screen
    if(variantAdded == true){
      // Build #1.0.148: we have to show loader until product adds into order panel, then hide
      // Navigator.pop(context); // Hide Loader / VariationPopup dialog
      if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
        Navigator.pop(context);
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

=======
    if (variantAdded == true) {
      if (!Misc.enableUILogMessages) {
        if (Navigator.canPop(context)) _closeOnlyDialog();
      }
      _refreshOrderList();
      return;
    }
    final adjustedIndex = index - (showBackButton ? 1 : 0);
    if (adjustedIndex < 0 || adjustedIndex >= categoryProducts.length) return;
    final selectedProduct = categoryProducts[adjustedIndex];
    final serverOrderId = orderHelper.activeOrderId;
    final dbOrderId = orderHelper.activeOrderId;
    try {
      _updateOrderSubscription?.cancel();
      StreamSubscription? subscription;
>>>>>>> origin/Grocery_pch_api_integration
      subscription = orderBloc.updateOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
<<<<<<< HEAD
        //  setState(() => isAddingItemLoading = false);
        if (response.status == Status.LOADING) { // Build #1.0.80
          const Center(child: CircularProgressIndicator());
        }else if (response.status == Status.COMPLETED) {
          // Build #1.0.148: we have to show loader until product adds into order panel, then hide
          // Navigator.pop(context); // Hide Loader / VariationPopup dialog
          if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
            Navigator.pop(context);
          }
          if (kDebugMode) print("Item added to order $dbOrderId via API");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Item '${selectedProduct[AppDBConst.fastKeyItemName]}' added to order"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (Navigator.canPop(context)) { // Build #1.0.197: Fixed [SCRUM - 345] -> Screen blackout when adding item to cart
            Navigator.pop(context);
          }
          if (kDebugMode) print("Failed to add item to order: ${response.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? TextConstants.failedToAddItemToOrder), // Build #1.0.144
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
=======
        if (response.status == Status.LOADING) {
          // loading
        } else if (response.status == Status.COMPLETED) {
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
>>>>>>> origin/Grocery_pch_api_integration
          _refreshOrderList();
          subscription?.cancel();
        }
      });
<<<<<<< HEAD

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
    final screenWidth = MediaQuery.of(context).size.width;
    String formattedDate = DateFormat("EEE, MMM d' ${now.year}'").format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

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
=======
      await orderBloc.updateOrderProducts(
          orderId: serverOrderId,
          dbOrderId: dbOrderId,
          lineItems: [
            OrderLineItem(
                productId: selectedProduct[AppDBConst.fastKeyProductId],
                quantity: 1)
          ]);
    } catch (e) {
      if (kDebugMode) print("Exception in _onItemSelected: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(TextConstants.errorAddingItem),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2)));
    } finally {
      _updateOrderSubscription?.cancel();
      _updateOrderSubscription = null;
    }
  }

  void _onNavigationPathTapped(int index) {
    if (index < 0 || index >= navigationPath.length) return;
    if (index == currentCategoryLevel - 1) return;
    setState(() {
      navigationPath = navigationPath.sublist(0, index + 1);
      _categoryContentError = null;
      categoryHierarchy = categoryHierarchy.sublist(0, index + 2);
      currentCategoryLevel = index + 1;
      isShowingSubCategories = true;
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
      _selectedSubCategoryIndex = null;
    });
    if (index == 0)
      _loadSubCategories(categories[_selectedCategoryIndex!].id);
    else
      _loadSubCategories(categoryHierarchy.last);
  }

  void _refreshOrderList() {
    if (!mounted) return;
    _cachedActiveOrderId = null; // clear so next tap re-validates
    setState(() => _refreshCounter++);
  }

  bool get showBackButton => currentCategoryLevel >= 2;

  // ─────────────────────────────────────────────────────────────────────────
  // Indigo section UI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildIndigoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
    isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F3);
    final breadcrumbColor =
    isDark ? const Color(0xFFB0B0D0) : const Color(0xFF4C5F7D);

    final indigoSubCatItems = _indigoSubCategories
        .map((cat) => {
      'name': cat.name,
      'image': cat.image ?? '',
      'count': cat.count,
    })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (navigationPath.isNotEmpty ||
            _isLoadingIndigoSubCategories ||
            indigoSubCatItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (navigationPath.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _onNavigationPathTapped(0),
                    child: Text(
                      navigationPath.first,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: breadcrumbColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 16, color: breadcrumbColor),
                  ),
                ],

                Expanded(
                  child: _isLoadingIndigoSubCategories
                      ? const SizedBox(
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE74C3C)),
                      ),
                    ),
                  )
                      : indigoSubCatItems.isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        indigoSubCatItems.length,
                            (index) {
                          final sub = indigoSubCatItems[index];
                          final bool isSelected =
                              _selectedIndigoSubCategoryIndex ==
                                  index;
                          final String imgPath =
                              (sub['image'] as String?) ??
                                  'assets/default.png';

                          return Padding(
                            padding:
                            const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() =>
                                _selectedIndigoSubCategoryIndex =
                                    index);
                                _loadIndigoProductsBySubCategory(
                                    _indigoSubCategories[index].id);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFE5E5)
                                      : isDark
                                      ? const Color(0xFF26253A)
                                      : Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFE6464)
                                        : isDark
                                        ? Colors.white12
                                        : const Color(
                                        0xFFDDDDDD),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      child: imgPath
                                          .startsWith('http')
                                          ? Image.network(imgPath,
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __,
                                              ___) =>
                                          const Icon(
                                              Icons.image,
                                              size: 28))
                                          : Image.asset(
                                          'assets/default.png',
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sub['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFFFE6464)
                                            : isDark
                                            ? Colors.white
                                            : const Color(
                                            0xFF2C3E50),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Divider(thickness: 1, color: dividerColor),
        ),

        if (_isLoadingIndigoProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Color(0xFFE74C3C)),
            ),
          )
        else if (_indigoError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _indigoError!,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (_selectedIndigoSubCategoryIndex != null &&
              _indigoProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No products in this category.",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else if (_indigoProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: LayoutBuilder(builder: (context, constraints) {
                  const int cols = 4;
                  const double gap = 8.0;
                  final double cardW =
                      (constraints.maxWidth - gap * (cols - 1)) / cols;
                  const double cardH = 72.0;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: _indigoProducts
                        .take(_visibleIndigoProductCount)
                        .map((product) {
                      return SizedBox(
                        width: cardW,
                        height: cardH,
                        child: _IndigoProductCard(
                          product: product,
                          isDark: isDark,
                          onTap: () => _onIndigoProductTapped(product),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
        if (_isIndigoPaginating &&
            _visibleIndigoProductCount < _indigoProducts.length)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFE74C3C)),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildInnerColumnChildren({
    required bool isDark,
    required List<Map<String, dynamic>> subCategoryListItems,
    required Widget Function(Widget) buildProductsWidget,
  }) {
    return [_buildIndigoSection()];
  }

  Widget _buildCategoryBar(
      BuildContext context,
      List<Map<String, dynamic>> categoryListItems,
      List<CategoryModel> visibleCats,
      ) {
    return CategoryBarWithAllButton(
      isLoading: isLoading,
      categoryListItems: categoryListItems,
      visibleCategories: visibleCats,
      allCategories: categories,
      selectedCategoryIndex: _selectedCategoryIndex,
      editingCategoryIndex: _editingCategoryIndex,
      scrollController: _categoryScrollController,
      showCategoryGrid: _showCategoryGrid,
      recentCategories: _recentCategories,
      isAddButtonEnabled: false,
      onAllTapped: () {
        setState(() {
          _showCategoryGrid = true;
        });
      },
      onCategoryTapped: (uiIndex) {
        final selectedCategory = visibleCats[uiIndex];
        final realIndex =
        categories.indexWhere((c) => c.id == selectedCategory.id);
        if (realIndex != -1) _onCategoryTapped(realIndex);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final List<CategoryModel> tempCategories = List.from(categories);
          final item = tempCategories.removeAt(oldIndex);
          tempCategories.insert(newIndex, item);
          categories = tempCategories;
          if (_selectedCategoryIndex != null) {
            if (_selectedCategoryIndex == oldIndex) {
              _selectedCategoryIndex = newIndex;
            } else if (oldIndex < _selectedCategoryIndex! &&
                newIndex >= _selectedCategoryIndex!) {
              _selectedCategoryIndex = _selectedCategoryIndex! - 1;
            } else if (oldIndex > _selectedCategoryIndex! &&
                newIndex <= _selectedCategoryIndex!) {
              _selectedCategoryIndex = _selectedCategoryIndex! + 1;
            }
          }
        });
      },
      onDismissEditMode: () => setState(() => _editingCategoryIndex = null),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleCats = categories.where((c) {
      final name = c.name.toLowerCase().trim();
      return !_hiddenCategoryNames.contains(name);
    }).toList();

    final categoryListItems = visibleCats
        .map((category) => {
      'title': category.name,
      'image': category.image ?? 'assets/default.png',
      'itemCount': category.count,
    })
        .toList();

    final subCategoryListItems = subCategories
        .map((subCategory) => {
      'name': subCategory.name,
      'image': subCategory.image ?? 'assets/default.png',
      'count': subCategory.count,
    })
        .toList();

    Widget buildProductsWidget(Widget child) {
      return NotificationListener<ScrollNotification>(
          onNotification: _onProductsScrollNotification, child: child);
    }

    BoxDecoration innerBoxDecoration() => BoxDecoration(
      color: isDark ? const Color(0xFF1D1C2C) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    );

    Widget buildContentArea() {
      // if (_showCategoryGrid) {
      //   return Expanded(
      //     child: SingleChildScrollView(
      //       child: Container(
      //         margin: const EdgeInsets.only(
      //             left: 10, right: 10, top: 0, bottom: 12),
      //         decoration: innerBoxDecoration(),
      //         child: CategoryGridOverlay(
      //           categoryListItems: categoryListItems,
      //           onCategoryTapped: (uiIndex) {
      //             final selectedCategory = visibleCats[uiIndex];
      //             final realIndex =
      //             categories.indexWhere((c) => c.id == selectedCategory.id);
      //             if (realIndex != -1) _onCategoryTapped(realIndex);
      //           },
      //         ),
      //       ),
      //     ),
      //   );
      // }

      if (_showCategoryGrid) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(
                left: 10, right: 10, top: 0, bottom: 12),
            decoration: innerBoxDecoration(),
            child: SingleChildScrollView(
              child: CategoryGridOverlay(
                categoryListItems: categoryListItems,
                onCategoryTapped: (uiIndex) {
                  final selectedCategory = visibleCats[uiIndex];
                  final realIndex =
                  categories.indexWhere((c) => c.id == selectedCategory.id);
                  if (realIndex != -1) _onCategoryTapped(realIndex);
                },
              ),
            ),
          ),
        );
      }

      // return Expanded(
      //   child: NotificationListener<ScrollNotification>(
      //     onNotification: _onIndigoProductsScrollNotification,
      //     child: SingleChildScrollView(
      //       child: Container(
      //         margin: const EdgeInsets.only(
      //             left: 10, right: 10, top: 0, bottom: 12),
      //         decoration: innerBoxDecoration(),
      //         child: Column(
      //           crossAxisAlignment: CrossAxisAlignment.start,
      //           children: _buildInnerColumnChildren(
      //             isDark: isDark,
      //             subCategoryListItems: subCategoryListItems,
      //             buildProductsWidget: buildProductsWidget,
      //           ),
      //         ),
      //       ),
      //     ),
      //   ),
      // );

      return Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onIndigoProductsScrollNotification,
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.only(
                  left: 10, right: 10, top: 0, bottom: 12),
              decoration: innerBoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildInnerColumnChildren(
                  isDark: isDark,
                  subCategoryListItems: subCategoryListItems,
                  buildProductsWidget: buildProductsWidget,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.embedInShell) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildCategoryBar(context, categoryListItems, visibleCats),
          buildContentArea(),
        ],
      );
    }
>>>>>>> origin/Grocery_pch_api_integration

    return Scaffold(
      body: Column(
        children: [
<<<<<<< HEAD
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
=======
          TopBar(
            screen: Screen.CATEGORY,
            onModeChanged: () async {
              String newLayout;
              if (sidebarPosition == SidebarPosition.left) {
                newLayout =
                    SharedPreferenceTextConstants.navRightOrderLeft;
              } else if (sidebarPosition == SidebarPosition.right) {
                newLayout =
                    SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
                newLayout = orderPanelPosition == OrderPanelPosition.left
                    ? SharedPreferenceTextConstants.navBottomOrderRight
                    : SharedPreferenceTextConstants.navLeftOrderRight;
              }
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
              setState(() {});
            },
            onProductSelected: (product) async {
              try {
                _refreshOrderList();
              } catch (e, s) {
                if (kDebugMode)
                  print("Exception in onProductSelected: $e, Stack: $s");
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(TextConstants.errorAddingItem),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2)));
              }
            },
          ),
          const Divider(color: Colors.grey, thickness: 0.4, height: 1),
>>>>>>> origin/Grocery_pch_api_integration
          Expanded(
            child: Row(
              children: [
                if (sidebarPosition == SidebarPosition.left)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
<<<<<<< HEAD
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
                    formattedDate: formattedDate,
                    formattedTime: formattedTime,
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
                            padding: const EdgeInsets.all(
                                8.0), // spacing around the frame
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? const Color(0xFF1C1C1E) // dark background
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
                                          16, 8, 10, 1),
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
                                      thickness: 4,
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
=======
                    onSidebarItemSelected: (index) =>
                        setState(() => _selectedSidebarIndex = index),
                    isVertical: true,
                  ),
                if (sidebarPosition == SidebarPosition.right ||
                    (sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList,
                      refreshKey: _refreshCounter),
                Expanded(
                  child: Column(
                    children: [
                      _buildCategoryBar(
                          context, categoryListItems, visibleCats),
                      buildContentArea(),
>>>>>>> origin/Grocery_pch_api_integration
                    ],
                  ),
                ),
                if (sidebarPosition != SidebarPosition.right &&
<<<<<<< HEAD
                    !(sidebarPosition == SidebarPosition.bottom && orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                    formattedDate: formattedDate,
                    formattedTime: formattedTime,
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
=======
                    !(sidebarPosition == SidebarPosition.bottom &&
                        orderPanelPosition == OrderPanelPosition.left))
                  RightOrderPanel(
                      key: const ValueKey('order_panel'),
                      quantities: quantities,
                      refreshOrderList: _refreshOrderList,
                      refreshKey: _refreshCounter),
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) =>
                        setState(() => _selectedSidebarIndex = index),
>>>>>>> origin/Grocery_pch_api_integration
                    isVertical: true,
                  ),
              ],
            ),
          ),
          if (sidebarPosition == SidebarPosition.bottom)
            custom_widgets.NavigationBar(
              selectedSidebarIndex: _selectedSidebarIndex,
<<<<<<< HEAD
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
=======
              onSidebarItemSelected: (index) =>
                  setState(() => _selectedSidebarIndex = index),
              isVertical: false,
            ),
        ],

      ),

    );
  }

  Widget _buildIndigoSubCategoryBar(bool isDark) {
    final dividerColor =
    isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F3);
    final breadcrumbColor =
    isDark ? const Color(0xFFB0B0D0) : const Color(0xFF4C5F7D);

    final indigoSubCatItems = _indigoSubCategories
        .map((cat) => {
      'name': cat.name,
      'image': cat.image ?? '',
      'count': cat.count,
    })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (navigationPath.isNotEmpty ||
            _isLoadingIndigoSubCategories ||
            indigoSubCatItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (navigationPath.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _onNavigationPathTapped(0),
                    child: Text(
                      navigationPath.first,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: breadcrumbColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 16, color: breadcrumbColor),
                  ),
                ],
                Expanded(
                  child: _isLoadingIndigoSubCategories
                      ? const SizedBox(
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE74C3C)),
                      ),
                    ),
                  )
                      : indigoSubCatItems.isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        indigoSubCatItems.length,
                            (index) {
                          final sub = indigoSubCatItems[index];
                          final bool isSelected =
                              _selectedIndigoSubCategoryIndex ==
                                  index;
                          final String imgPath =
                              (sub['image'] as String?) ??
                                  'assets/default.png';

                          return Padding(
                            padding:
                            const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() =>
                                _selectedIndigoSubCategoryIndex =
                                    index);
                                _loadIndigoProductsBySubCategory(
                                    _indigoSubCategories[index].id);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFE5E5)
                                      : isDark
                                      ? const Color(0xFF26253A)
                                      : Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFE6464)
                                        : isDark
                                        ? Colors.white12
                                        : const Color(
                                        0xFFDDDDDD),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      child: imgPath
                                          .startsWith('http')
                                          ? Image.network(imgPath,
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __,
                                              ___) =>
                                          const Icon(
                                              Icons.image,
                                              size: 28))
                                          : Image.asset(
                                          'assets/default.png',
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sub['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFFFE6464)
                                            : isDark
                                            ? Colors.white
                                            : const Color(
                                            0xFF2C3E50),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Divider(thickness: 1, color: dividerColor),
        ),
      ],
    );
  }

  Widget _buildIndigoProductsGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingIndigoProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Color(0xFFE74C3C)),
            ),
          )
        else if (_selectedIndigoSubCategoryIndex != null &&
            _indigoProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No products in this category.",
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else if (_indigoProducts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              child: LayoutBuilder(builder: (context, constraints) {
                const int cols = 4;
                const double gap = 8.0;
                final double cardW =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                const double cardH = 72.0;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _indigoProducts
                      .take(_visibleIndigoProductCount)
                      .map((product) {
                    return SizedBox(
                      width: cardW,
                      height: cardH,
                      child: _IndigoProductCard(
                        product: product,
                        isDark: isDark,
                        onTap: () => _onIndigoProductTapped(product),
                      ),
                    );
                  }).toList(),
                );
              }),
            ),
        if (_isIndigoPaginating &&
            _visibleIndigoProductCount < _indigoProducts.length)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFE74C3C)),
              ),
            ),
          ),
      ],
    );
  }
}

class _IndigoSubCategoryCard extends StatelessWidget {
  final IndigoCategoryModel category;
  final bool isDark;
  final VoidCallback onTap;

  const _IndigoSubCategoryCard(
      {required this.category, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardBg =
    isDark ? const Color(0xFF26253A) : const Color(0xFFF3F4F8);
    final borderColor =
    isDark ? const Color(0xFF3A3A52) : const Color(0xFFE8EAF0);
    final textColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                flex: 70,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: category.image.isNotEmpty
                        ? Image.network(category.image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _placeholder(),
                        loadingBuilder: (_, child, prog) =>
                        prog == null ? child : _placeholder())
                        : _placeholder())),
            Expanded(
                flex: 30,
                child: Container(
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                    child: Text(category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            fontFamily: 'poppins',
                            height: 1.25)))
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
        child: Icon(Icons.category_outlined,
            size: 28, color: isDark ? Colors.white24 : Colors.black26));
  }
}

class _IndigoProductCard extends StatelessWidget {
  final IndigoCategoryBasedProducts product;
  final bool isDark;
  final VoidCallback onTap;

  const _IndigoProductCard(
      {required this.product, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isEbt = product.tags.any((t) {
      final name = t.name.toLowerCase();
      final slug = t.slug.toLowerCase();
      return name.contains('ebt') || slug.contains('ebt');
    });

    final bool hasVariants = product.type == 'variable';
    final themeHelper = Provider.of<ThemeNotifier>(context, listen: false);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.secondaryBackground
            : Colors.white,
        elevation: 5,
        shadowColor: Colors.blueAccent,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: Colors.blueAccent,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Row(
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : ThemeNotifier.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '\$${double.tryParse(product.price)?.toStringAsFixed(2) ?? "0.00"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: themeHelper.themeMode == ThemeMode.dark
                                ? ThemeNotifier.textDark
                                : ThemeNotifier.textLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (hasVariants) ...[
                          SvgPicture.asset(
                            SvgUtils.variationIcon,
                            height: 10,
                            width: 10,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (isEbt)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(4),
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
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final _VariantIconPainter? leadingIcon;

  const _TagBadge({
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CustomPaint(painter: leadingIcon!),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFamily: 'poppins',
              letterSpacing: 0.2,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantIconPainter extends CustomPainter {
  final Color color;
  const _VariantIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const r = Radius.circular(1);
    final s = size.width * 0.42;
    final gap = size.width * 0.16;
    canvas.drawRRect(RRect.fromLTRBR(0, 0, s, s, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(s + gap, 0, size.width, s, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(0, s + gap, s, size.height, r), paint);
    paint.color = color.withOpacity(0.45);
    canvas.drawRRect(
        RRect.fromLTRBR(s + gap, s + gap, size.width, size.height, r), paint);
  }

  @override
  bool shouldRepaint(_VariantIconPainter old) => old.color != color;
>>>>>>> origin/Grocery_pch_api_integration
}