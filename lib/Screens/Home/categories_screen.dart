import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:pinaka_pos/Database/isar_cache_entry.dart';
import '../../Blocs/Orders/order_bloc.dart';
import '../../Blocs/Search/product_search_bloc.dart';
import '../../Constants/misc_features.dart';
import '../../Database/db_helper.dart';
import '../../Database/storage/storage_provider.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/url_helper.dart';
import '../../Providers/Age/age_verification_provider.dart';
import '../../Utilities/global_utility.dart';
import '../../Models/Orders/orders_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/Search/product_search_repository.dart';
import '../../Utilities/responsive_layout.dart';
import '../../Utilities/shimmer_effect.dart';
import '../../Utilities/svg_images_utility.dart';
import '../../Widgets/ManualPriceDialog.dart';
import '../../Widgets/weighing_scale_widget.dart';
import '../../Widgets/widget_logs_toast.dart';
import '../../Widgets/widget_category_list.dart';
// ── NEW imports ──
import '../../Widgets/widget_nested_grid_layout.dart';
import '../../Widgets/widget_order_panel.dart';
import '../../Widgets/widget_sub_category.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import '../../Blocs/Category/category_bloc.dart';
import '../../Repositories/Category/category_repository.dart';
import '../../Database/isar_service.dart';
import '../../Helper/api_response.dart';
import '../../Models/Category/category_model.dart';
import '../../Models/Category/category_product_model.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Constants/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Widgets/widget_variants_dialog.dart';
import '../Auth/login_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pinaka_pos/Helper/Extentions/theme_notifier.dart';
import 'package:provider/provider.dart';

// ✅ FIX: Minimum age of a cached Indigo entry before a background refresh is
// allowed.  Prevents a refresh from firing on every single cache hit.
const _indigoBgRefreshThreshold = Duration(minutes: 30);

class CategoryBarWithAllButton extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> categoryListItems;
  final List<CategoryModel> visibleCategories;
  final List<CategoryModel> allCategories;
  final int? selectedCategoryIndex;
  final int? editingCategoryIndex;
  final ScrollController scrollController;

  /// true  = grid visible (Screen 1)
  /// false = subcategory cards visible (Screen 2/3)
  final bool showCategoryGrid;

  /// Most-recently visited categories, most-recent first (max 5).
  /// Shown always beside All.
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? ThemeNotifier.primaryBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                isDark ? const Color(0x25CCC8C8) : const Color(0x50BDB9B9),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding:
          const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── "All" button ──────────────────────────────────────────────
              _AllChip(
                isDark: isDark,
                isActive: showCategoryGrid,
                onTap: onAllTapped,
              ),

              // ── Recent chips — shown ALWAYS when list has items ───────────
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
                        final uiIndex =
                        visibleCategories.indexWhere((v) => v.id == cat.id);
                        // Highlighted only when drilling in AND this is active
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

              // No recents yet → push All to left
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

  /// e.g. "Vegetables" — shown as "Vegetables >" before the cards
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
        // ── Breadcrumb: "Vegetables  >" ────────────────────────────────────
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

        // ── Scrollable image cards ─────────────────────────────────────────
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildImage(imgPath, 42),
                        ),
                        const SizedBox(width: 10),
                        // Name
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
          .map((t) => IndigoTag.fromJson(Map<String, dynamic>.from(t as Map)))
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

// ─────────────────────────────────────────────────────────────────────────────
// INDIGO REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class IndigoCategoryRepository {
  Future<List<IndigoCategoryModel>> indigoFetchCategories(
      int parentCategoryId) async {
    final token = await _getTokenFromDb();
    final url = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}${UrlMethodConstants.categories}'
            '?page=1&per_page=100&hide_empty=true&parent=$parentCategoryId');

    if (kDebugMode) print(" Indigo categoriess URL: $url");

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
      return data.map((e) => IndigoCategoryBasedProducts.fromJson(e)).toList();
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

// ─────────────────────────────────────────────────────────────────────────────
// ISAR CACHE KEY HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _indigoSubCatKey(int parentId) => "indigo_subcategories_$parentId";
String _indigoProductKey(int categoryId) => "indigo_products_$categoryId";

// ─────────────────────────────────────────────────────────────────────────────
// _IndigoCategoryRepositoryWithCache
// ─────────────────────────────────────────────────────────────────────────────

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
      } else {
        if (kDebugMode)
          print(
              "⏱️ [Indigo] Sub-cat cache is fresh, skipping BG refresh (parent: $parentCategoryId)");
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
          if (kDebugMode)
            print("🔥 [Indigo] Pre-warmed sub-categories (parent: $id)");
        } else if (_isStale(existing.timestamp)) {
          _scheduleRefresh(
              _indigoSubCatKey(id), () => _fetchAndWriteToIsar(id));
        } else {
          if (kDebugMode)
            print("⏱️ [Indigo] Pre-warm skipped (cache fresh) for parent: $id");
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
      if (kDebugMode) print(" [Indigo] Isar read error ($key): $e");
      return null;
    }
  }

  Future<String?> _readFromIsar(String key) async {
    return (await _readEntryFromIsar(key))?.json;
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
      if (kDebugMode) print(" [Indigo] Isar write error ($key): $e");
    }
  }

  List<IndigoCategoryModel> _decodeCategories(String jsonStr) {
    try {
      final List<dynamic> raw = json.decode(jsonStr);
      return raw
          .map(
              (e) => IndigoCategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      if (kDebugMode) print(" [Indigo] Decode error (categories): $e");
      return [];
    }
  }

  void _scheduleRefresh(String key, Future<void> Function() work) {
    if (_inFlightRefreshes.containsKey(key)) {
      if (kDebugMode)
        print("⏳ [Indigo] BG refresh already in-flight for [$key], skipping");
      return;
    }
    final task = work().whenComplete(() => _inFlightRefreshes.remove(key));
    _inFlightRefreshes[key] = task;
  }

  bool _isStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _indigoBgRefreshThreshold;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IndigoProductRepositoryWithCache
// ─────────────────────────────────────────────────────────────────────────────

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
      } else {
        if (kDebugMode)
          print(
              "⏱️ [Indigo] Product cache is fresh, skipping BG refresh (category: $categoryId)");
      }
      return _decodeProducts(entry.json);
    }
    try {
      return await _fetchAndWriteToIsar(categoryId);
    } catch (e) {
      if (kDebugMode)
        print(
            " [Indigo] API failed & no cache for products (category: $categoryId): $e");
      return [];
    }
  }

  Future<List<IndigoCategoryBasedProducts>> _fetchAndWriteToIsar(
      int categoryId) async {
    if (kDebugMode)
      print(" [Indigo] Fetching products from API (category: $categoryId)");
    final products = await _remote.fetchProducts(categoryId);
    final jsonStr = json.encode(products.map((p) => p.toJson()).toList());
    await _writeToIsar(_indigoProductKey(categoryId), jsonStr);
    TopBar.notifyMergedProductCacheMayHaveChanged();
    if (kDebugMode)
      print(
          " [Indigo] Cached ${products.length} products (category: $categoryId)");
    return products;
  }

  Future<void> preWarmAll(List<int> categoryIds) async {
    for (final id in categoryIds) {
      try {
        final existing = await _readEntryFromIsar(_indigoProductKey(id));
        if (existing == null) {
          await _fetchAndWriteToIsar(id);
          if (kDebugMode)
            print(" [Indigo] Pre-warmed products (category: $id)");
        } else if (_isStale(existing.timestamp)) {
          _scheduleRefresh(
              _indigoProductKey(id), () => _fetchAndWriteToIsar(id));
        } else {
          if (kDebugMode)
            print(
                "⏱️ [Indigo] Pre-warm skipped (cache fresh) for category: $id");
        }
      } catch (e) {
        if (kDebugMode)
          print(" [Indigo] Pre-warm products failed (category: $id): $e");
      }
    }
  }

  Future<IsarCacheEntry?> _readEntryFromIsar(String key) async {
    try {
      final isar = await IsarService.instance;
      return await isar.isarCacheEntrys.where().keyEqualTo(key).findFirst();
    } catch (e) {
      if (kDebugMode) print(" [Indigo] Isar read error ($key): $e");
      return null;
    }
  }

  Future<String?> _readFromIsar(String key) async {
    return (await _readEntryFromIsar(key))?.json;
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
      if (kDebugMode) print(" [Indigo] Isar write error ($key): $e");
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
      if (kDebugMode) print(" [Indigo] Decode error (products): $e");
      return [];
    }
  }

  void _scheduleRefresh(String key, Future<void> Function() work) {
    if (_inFlightRefreshes.containsKey(key)) {
      if (kDebugMode)
        print("⏳ [Indigo] BG refresh already in-flight for [$key], skipping");
      return;
    }
    final task = work().whenComplete(() => _inFlightRefreshes.remove(key));
    _inFlightRefreshes[key] = task;
  }

  bool _isStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _indigoBgRefreshThreshold;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CategoriesScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  final bool embedInShell;

  const CategoriesScreen(
      {super.key, this.lastSelectedIndex, this.embedInShell = false});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

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

  late CategoryBloc _categoryBloc;
  List<CategoryModel> categories = [];
  List<CategoryModel> subCategories = [];
  int? _selectedCategoryIndex;
  int? _editingCategoryIndex;
  int? _selectedSubCategoryIndex;
  final ScrollController _categoryScrollController = ScrollController();
  bool _hasAutoTappedOnce = false;

  // ── controls whether the full category grid is visible ───────────────────
  bool _showCategoryGrid = true;

  // ── recently visited categories, most-recent FIRST, max 5 shown ──────────
  final List<CategoryModel> _recentCategories = [];
  static const int _maxRecentCategories = 5;

  static const int _pageSize = 20;
  final List<Map<String, dynamic>> _allCategoryProducts = [];
  int _visibleProductCount = _pageSize;
  bool _autoLoadCompleted = false;
  bool _isPaginating = false;
  bool _hasMoreProductsToShow = false;

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
  int _refreshCounter = 0;
  bool _isAutoLoading = false;
  int? _inFlightSubCategoryParentId;
  int? _inFlightProductCategoryId;
  int? _inFlightIndigoSubParentId;
  int? _inFlightIndigoProductCategoryId;
  int? _lastLoadedSubCategoryParentId;
  int? _lastLoadedProductCategoryId;
  int? _lastLoadedIndigoSubParentId;
  int? _lastLoadedIndigoProductCategoryId;
  final Set<int> _loadedProductCategoryIds = {};
  final Set<int> _loadedSubCategoryParentIds = {};
  final Set<int> _loadedIndigoSubParentIds = {};
  final Set<int> _loadedIndigoProductCategoryIds = {};

  // ✅ Guards _preWarmAllIndigoData() from running more than once per session.
  bool _indigoPreWarmDone = false;

  // ── Indigo state ──────────────────────────────────────────────────────────
  final _IndigoCategoryRepositoryWithCache _indigoCategoryRepo =
  _IndigoCategoryRepositoryWithCache(IndigoCategoryRepository());
  final _IndigoProductRepositoryWithCache _indigoProductRepo =
  _IndigoProductRepositoryWithCache(
      IndigoCategoryBasedProductsRepository());

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

  /// Prevents stacked add-to-order work when the user taps products very quickly.
  bool _productAddTapInFlight = false;

  // ─────────────────────────────────────────────────────────────────────────
  // ── NEW: Default category product helpers ─────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────

  /// Isar key under which "default" category products are stored.
  static const String _defaultCatIsarKey = 'indigo_default_category_products';

  /// In-memory cache so repeat calls within the same session are instant.
  final Map<String, Map<String, dynamic>> _dynamicProductMemCache = {};

  /// Called once after top-level categories load.
  /// Finds any category with slug == "default" or name == "Default",
  /// fetches its products via the Indigo product repo, and stores them
  /// in Isar under [_defaultCatIsarKey].
  Future<void> _preLoadDefaultCategoryProducts(
      List<CategoryModel> cats) async {
    try {
      // Find the "default" / "Default" category in the loaded list
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

      // Already cached → nothing to do (stale check reuses _indigoProductRepo
      // internal logic, so we just bail if the Isar key already exists)
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

      if (kDebugMode)
        print(
            '🌍 [Default] Fetching products for "default" category id: ${defaultCat.id}');

      // Reuse the existing Indigo product repo (already has auth + Isar caching)
      final products = await _indigoProductRepo.fetchProducts(defaultCat.id);

      // Persist a flat list of toJson() maps under our dedicated key
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
            '💾 [Default] Cached ${products.length} products from "default" category (id: ${defaultCat.id})');
    } catch (e) {
      if (kDebugMode)
        print('⚠️ [Default] Failed to pre-load default products: $e');
    }
  }

  /// Searches [_defaultCatIsarKey] in Isar for a product whose
  /// name / sku / slug matches any of [tokens] (case-insensitive).
  /// Returns a normalised product map compatible with the order flow,
  /// or null when nothing matches.
  // Future<Map<String, dynamic>?> _findDynamicProductByTokens(
  //     List<String> tokens) async {
  //   try {
  //     // 1️⃣ Check in-memory cache first
  //     for (final token in tokens) {
  //       final t = token.toLowerCase();
  //       for (final entry in _dynamicProductMemCache.entries) {
  //         if (entry.key.contains(t)) return entry.value;
  //       }
  //     }
  //
  //     // 2️⃣ Read from Isar
  //     final isar = await IsarService.instance;
  //     final entry = await isar.isarCacheEntrys
  //         .where()
  //         .keyEqualTo(_defaultCatIsarKey)
  //         .findFirst();
  //     if (entry == null) {
  //       if (kDebugMode)
  //         print(
  //             '⚠️ [Default] $_defaultCatIsarKey not found in Isar — no real data yet');
  //       return null;
  //     }
  //
  //     final List<dynamic> raw = json.decode(entry.json);
  //
  //     for (final item in raw) {
  //       if (item is! Map) continue;
  //       final map = Map<String, dynamic>.from(item);
  //
  //       final name = (map['name'] ?? '').toString().toLowerCase();
  //       final sku = (map['sku'] ?? '').toString().toLowerCase();
  //       // "slug" may not be present in IndigoCategoryBasedProducts.toJson()
  //       // so also check categories list slugs as a fallback
  //       final slug = (map['slug'] ?? '').toString().toLowerCase();
  //
  //       for (final token in tokens) {
  //         final t = token.toLowerCase();
  //         if (name.contains(t) || sku.contains(t) || slug.contains(t)) {
  //           if (kDebugMode)
  //             print(
  //                 '✅ [Default] Matched "$token" → ${map['name']} (id: ${map['id']})');
  //
  //           // Build a normalised map that the order-flow already understands
  //           final normalised = <String, dynamic>{
  //             'fast_key_product_id': map['id'],
  //             'fast_key_item_name': map['name'],
  //             'fast_key_item_image':
  //             (map['images'] is List && (map['images'] as List).isNotEmpty)
  //                 ? (map['images'] as List).first
  //                 : '',
  //             'fast_key_item_price': map['price'] ?? '0',
  //             'fast_key_item_sku': map['sku'] ?? '',
  //             'fast_key_item_min_age': 0,
  //             'has_age_restriction': false,
  //             'fast_key_item_tags': <Map<String, dynamic>>[],
  //             'variations': <dynamic>[],
  //             'type': map['type'] ?? 'simple',
  //             'is_ebt_eligible': false,
  //           };
  //
  //           // Store in memory so next call is instant
  //           _cacheDynamicProduct(normalised);
  //           return normalised;
  //         }
  //       }
  //     }
  //
  //     if (kDebugMode)
  //       print(
  //           '🔍 [Default] No product matched tokens $tokens in default category cache');
  //     return null;
  //   } catch (e) {
  //     if (kDebugMode)
  //       print('⚠️ [Default] _findDynamicProductByTokens error: $e');
  //     return null;
  //   }
  // }

  Future<Map<String, dynamic>?> _findDynamicProductByTokens(
      List<String> tokens,
      ) async {
    // 1️⃣ In‑memory cache check
    for (final token in tokens) {
      final t = token.toLowerCase();
      for (final entry in _dynamicProductMemCache.entries) {
        if (entry.key.contains(t)) return entry.value;
      }
    }

    // 2️⃣ Read from Isar
    final isar = await IsarService.instance;
    final entry = await isar.isarCacheEntrys
        .where()
        .keyEqualTo(_defaultCatIsarKey)
        .findFirst();

    List<dynamic> raw = [];
    if (entry != null) {
      raw = json.decode(entry.json);
    } else {
      // ⚠️ Cache missing – try to fetch the Default category on the spot
      if (kDebugMode) print('⚠️ [Default] Cache empty, fetching now...');
      final defaultCat = categories.firstWhere(
            (c) => c.slug?.toLowerCase() == 'default' || c.name.toLowerCase() == 'default',
        orElse: () => throw Exception('Default category not found'),
      );
      final freshProducts = await _indigoProductRepo.fetchProducts(defaultCat.id);
      final jsonStr = json.encode(freshProducts.map((p) => p.toJson()).toList());
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

    // 3️⃣ Search raw list for matching token
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

  Map<String, dynamic> _buildNormalisedProductMap(Map<String, dynamic> rawMap) {
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

  /// Stores a resolved product in the in-memory cache keyed by lower-case name.
  void _cacheDynamicProduct(Map<String, dynamic> product) {
    final name =
    (product['fast_key_item_name'] ?? '').toString().toLowerCase();
    if (name.isNotEmpty) _dynamicProductMemCache[name] = product;
  }

  /// Builds a minimal fallback map when the real product is not found in cache.
  /// Used only as last resort — real data is always preferred.
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

  /// Returns the real Cashback product from the "default" category cache.
  /// Falls back to a dummy only when the category has not been fetched yet.
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
    if (kDebugMode) {
      print("⚠️ Cashback product missing in cache → using fallback map");
    }
    return fallback;
  }

  Future<void> _addMerchantDiscount(double discountAmount) async {
    if (discountAmount <= 0) return;

    final discountProduct = await _getDiscountProductFromIsar();
    if (discountProduct == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount product not found. Please sync categories.')),
        );
      }
      return;
    }

    final orderId = await orderHelper.ensureOrderExists();
    if (orderId == null) return;

    // Add as a line item with negative total
    await orderHelper.addItemToOrder(
      null,
      discountProduct['fast_key_item_name'],
      discountProduct['fast_key_item_image'],
      -discountAmount,   //  negative amount
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

  /// Returns the real Merchant Discount product from the "default" category cache.
  /// Falls back to a dummy only when the category has not been fetched yet.
  Future<Map<String, dynamic>?> _getDiscountProductFromIsar() async {
    final resolved = await _findDynamicProductByTokens([
      "discount",
      "merchant discount",
      "merchant-discount",
      "merchant_discount",
      "md",
    ]);
    if (resolved != null) return resolved;

    final fallback = _buildFallbackDynamicProduct(
      id: 899988,
      name: "Merchant Discount",
      sku: "MERCHANT-DISCOUNT-DYNAMIC",
    );
    _cacheDynamicProduct(fallback);
    if (kDebugMode) {
      print("Discount product missing in cache → using fallback map");
    }
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
    "default"
  };

  List<CategoryModel> get visibleCategories {
    return categories.where((c) {
      final name = c.name.toLowerCase().trim();
      return !_hiddenCategoryNames.contains(name);
    }).toList();
  }

  void _hideAutoLoadingDialog() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    orderBloc = OrderBloc(OrderRepository());
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 1;
    _categoryBloc = CategoryBloc(CategoryRepository());
    reorderedIndices = List.filled(categoryProducts.length, null);
    _loadTopLevelCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Indigo full pre-warm
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _preWarmAllIndigoData() async {
    if (_indigoPreWarmDone) {
      if (kDebugMode)
        print("⏱️ [Indigo] Pre-warm already done this session, skipping");
      return;
    }
    _indigoPreWarmDone = true;

    if (kDebugMode) {
      print(
          "⏱️ [Indigo] Full-tree pre-warm disabled — on-demand loads only (saves server)");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Indigo UI loaders
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadIndigoSubCategories(int parentCategoryId) async {
    if (!mounted) return;
    if (_inFlightIndigoSubParentId == parentCategoryId) return;
    if (_lastLoadedIndigoSubParentId == parentCategoryId &&
        _loadedIndigoSubParentIds.contains(parentCategoryId)) {
      return;
    }
    _inFlightIndigoSubParentId = parentCategoryId;
    try {
      if (_indigoSubCategories.isEmpty) {
        setState(() {
          _isLoadingIndigoSubCategories = true;
          _indigoError = null;
        });
      }
      setState(() {
        _indigoProducts = [];
        _selectedIndigoSubCategoryIndex = null;
      });

      final cats =
      await _indigoCategoryRepo.indigoFetchCategories(parentCategoryId);
      if (!mounted) return;

      setState(() {
        _indigoSubCategories = cats;
        _isLoadingIndigoSubCategories = false;
        _indigoError = null;
        if (cats.isNotEmpty && !_isAutoLoading) {
          _selectedIndigoSubCategoryIndex = 0;
        }
      });

      _loadedIndigoSubParentIds.add(parentCategoryId);
      _lastLoadedIndigoSubParentId = parentCategoryId;

      if (kDebugMode)
        print(
            " [UI] Loaded ${cats.length} Indigo sub-categories for parent $parentCategoryId");

      if (!_isAutoLoading) {
        if (cats.isNotEmpty) {
          _loadIndigoProductsBySubCategory(cats[0].id);
        } else {
          _loadIndigoProductsBySubCategory(parentCategoryId);
        }
      }
    } finally {
      if (_inFlightIndigoSubParentId == parentCategoryId) {
        _inFlightIndigoSubParentId = null;
      }
    }
  }

  Future<void> _loadIndigoProductsBySubCategory(int categoryId) async {
    if (!mounted) return;
    if (_inFlightIndigoProductCategoryId == categoryId) return;
    if (_lastLoadedIndigoProductCategoryId == categoryId &&
        _loadedIndigoProductCategoryIds.contains(categoryId)) {
      return;
    }
    _inFlightIndigoProductCategoryId = categoryId;
    try {
      setState(() {
        _isLoadingIndigoProducts = true;
        _visibleIndigoProductCount = _indigoPageSize;
        _isIndigoPaginating = false;
      });
      final products = await _indigoProductRepo.fetchProducts(categoryId);
      if (!mounted) return;
      setState(() {
        _indigoProducts = products;
        _isLoadingIndigoProducts = false;
      });
      _loadedIndigoProductCategoryIds.add(categoryId);
      _lastLoadedIndigoProductCategoryId = categoryId;
      if (kDebugMode)
        print(
            " [UI] Loaded ${products.length} Indigo products for sub-category $categoryId");
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
        final orderId = await orderHelper.ensureOrderExists();
        if (orderId == null) {
          final msg = OrderHelper.lastEnsureOrderError ??
              "Failed to create or restore order. Please try again.";
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          return;
        }

        if (kDebugMode) print(" TAP [Indigo]: ${product.name}");

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
        };

        final int productId =
            int.tryParse(item["fast_key_product_id"].toString()) ?? -1;
        final cachedProduct =
        productId > 0 ? await _getCachedProductFromIsar(productId) : null;

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

        if (kDebugMode && tags.isNotEmpty) {
          print(
              "Tags for ${product.name}: ${tags.map((t) => "${t['name']} (${t['slug']})").join(", ")}");
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
        if (kDebugMode && hasAgeRestriction)
          print("→ Age restriction DETECTED: $minAge+  → ${product.name}");

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
        int activeOrderId =
            orderHelper.activeOrderId ?? (await box.get('lastOrderId')) ?? 1000;
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
            final isVerified = await prov.verifyAge(context, minAge: minAge);
            if (!isVerified) return;
            hiveOrder["age_verified"] = true;
            await box.put(orderKey, hiveOrder);
          }
        }

        final bool hasProduceTag = tags.any((t) {
          final slug = (t["slug"] ?? "").toString().toLowerCase();
          final name = (t["name"] ?? "").toString().toLowerCase();
          return slug.contains("produce") || name.contains("produce");
        });

        if (hasProduceTag) {
          final result = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AutoWeightPriceDialog(
                  productName: productName, unitPrice: productPrice));
          if (result == null) return;
          await orderHelper.addItemToOrder(null, productName, productImage,
              result["finalPrice"], 1, productSku, activeOrderId,
              type: 'weighted',
              weightQty: (result["weight"] as num?)?.toDouble(),
              productId: productId,
              variationId: -1,
              salesPrice: result["finalPrice"],
              regularPrice: productPrice,
              unitPrice: productPrice,
              isEbtEligible: isEbtEligible,
              onItemAdded: () async => _refreshOrderList());
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
                regularPrice: finalPrice,
                unitPrice: finalPrice,
                isEbtEligible: isEbtEligible,
                onItemAdded: () async {});
            _refreshOrderList();
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
                (map["name"] is Map && map["name"]["rendered"] != null)
                    ? map["name"]["rendered"]
                    : (map["name"] is String
                    ? map["name"]
                    : "Unnamed Variant");
                map["price"] = map["price"]?.toString() ?? "0";
                return map;
              }
              return <String, dynamic>{};
            })
                .where((v) => v.isNotEmpty)
                .toList();

            if (offlineVariations.isEmpty && productId > 0) {
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
                final variantPrice =
                    double.tryParse(selectedVariant["price"].toString()) ??
                        productPrice;
                final variantSku = selectedVariant["sku"] ?? productSku;
                final variantImage = selectedVariant["image"] ?? productImage;
                await orderHelper.addItemToOrder(0, variantName, variantImage,
                    variantPrice, qty, variantSku, activeOrderId,
                    type: 'variant',
                    productId: productId,
                    variationId: variantId,
                    variationName: variantName,
                    salesPrice: variantPrice,
                    regularPrice: variantPrice,
                    unitPrice: variantPrice,
                    isEbtEligible: isEbtEligible,
                    onItemAdded: () async => _refreshOrderList());
              },
            ),
          );
        } else {
          await orderHelper.addItemToOrder(null, productName, productImage,
              finalPrice, 1, productSku, activeOrderId,
              type: 'product',
              productId: productId,
              variationId: -1,
              salesPrice: finalPrice,
              regularPrice: productPrice,
              unitPrice: productPrice,
              isEbtEligible: isEbtEligible,
              onItemAdded: () async => _refreshOrderList());
        }
        if (kDebugMode)
          print("🎉 [Indigo] Product flow completed → $productName");
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

  Future<Map<String, dynamic>?> _getCachedProductFromIsar(int productId) async {
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
          final dynamic idRaw = map['fast_key_product_id'] ?? map['id'];
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
        final map = v.map((key, value) => MapEntry(key.toString(), value));
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
              : (fallbackName.isNotEmpty
              ? fallbackName
              : "Unnamed Variant"),
          "price": (map["price"] ?? map["regular_price"] ?? "0").toString(),
          "sku": map["sku"] ?? "",
          "image": (map["image"] is Map && map["image"]["src"] != null)
              ? map["image"]["src"]
              : (map["image"] is String ? map["image"] : ""),
        };
      })
          .where((v) => v["id"] != null)
          .toList();
    } catch (_) {
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
    if (isLoadingNestedContent && kDebugMode) {
      print("⚠️ Nested loading timed out after ${timeout.inSeconds}s");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Original category methods
  // ─────────────────────────────────────────────────────────────────────────

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
    if (kDebugMode) {
      print("🚀 Auto warm (single category) → ${categories[tapIndex].name}");
    }
    _onCategoryTapped(tapIndex);
    await _waitForNestedLoadingOrTimeout();
    await Future.delayed(const Duration(milliseconds: 300));
    _preWarmAllIndigoData();
    _hideAutoLoadingDialog();
    if (!mounted) return;
    setState(() {
      _isAutoLoading = false;
      _autoLoadCompleted = true;
    });
    if (_selectedCategoryIndex != null &&
        _selectedCategoryIndex! >= 0 &&
        _selectedCategoryIndex! < categories.length) {
      final int parentCategoryId = categories[_selectedCategoryIndex!].id;
      final int targetCategoryId = _indigoSubCategories.isNotEmpty
          ? _indigoSubCategories.first.id
          : parentCategoryId;
      _loadIndigoProductsBySubCategory(targetCategoryId);
    }
    if (kDebugMode) print("✅ Auto load completed; pagination enabled");
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
    double offset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    offset = offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    _categoryScrollController.animateTo(offset,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _saveLastSelectedCategory(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSelectedCategoryIndex', index);
  }

  void _addToRecent(CategoryModel category) {
    _recentCategories.removeWhere((c) => c.id == category.id);
    _recentCategories.insert(0, category);
    if (_recentCategories.length > _maxRecentCategories) {
      _recentCategories.removeRange(
          _maxRecentCategories, _recentCategories.length);
    }
  }

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

          // ── NEW: Pre-load products from the "Default" category into Isar ──
          // This feeds _getCashbackProductFromIsar and _getDiscountProductFromIsar
          // with real API data instead of fallback dummy maps.
          _preLoadDefaultCategoryProducts(categories);
          // ─────────────────────────────────────────────────────────────────

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
            await _loadLastSelectedCategory();
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
      if (kDebugMode) print("⚠️ _loadTopLevelCategories timed out");
    }
  }

  Future<void> _loadSubCategories(int parentId) async {
    if (_inFlightSubCategoryParentId == parentId) return;
    if (_lastLoadedSubCategoryParentId == parentId &&
        _loadedSubCategoryParentIds.contains(parentId)) {
      return;
    }
    _inFlightSubCategoryParentId = parentId;
    _categoryBloc.fetchCategories(parentId);
    try {
      await for (final response in _categoryBloc.categoriesStream
          .timeout(const Duration(seconds: 25))) {
        if (!mounted) break;
        if (response.status == Status.COMPLETED && response.data != null) {
          setState(() {
            subCategories = response.data!.categories;
            isShowingSubCategories = true;
            _resetPaginationState();
            _allCategoryProducts.clear();
            categoryProducts.clear();
            _selectedSubCategoryIndex = null;
            isLoadingNestedContent = false;
          });

          // Auto-select first subcategory pill
          if (subCategories.isNotEmpty && !_isAutoLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onSubCategoryTapped(0);
            });
          }

          if (Misc.enableCategoryProductWithSubCategoryList ||
              subCategories.isEmpty) {
            _loadProductsByCategory(parentId);
          }
          _loadedSubCategoryParentIds.add(parentId);
          _lastLoadedSubCategoryParentId = parentId;
          break;
        }
        if (response.status == Status.ERROR) {
          setState(() => isLoadingNestedContent = false);
          break;
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => isLoadingNestedContent = false);
      if (kDebugMode) print("⚠️ _loadSubCategories timed out for $parentId");
    } finally {
      if (_inFlightSubCategoryParentId == parentId) {
        _inFlightSubCategoryParentId = null;
      }
    }
  }

  Future<void> _loadProductsByCategory(int categoryId) async {
    if (_inFlightProductCategoryId == categoryId) return;
    if (_lastLoadedProductCategoryId == categoryId &&
        _loadedProductCategoryIds.contains(categoryId)) {
      return;
    }
    _inFlightProductCategoryId = categoryId;
    setState(() {
      isLoadingNestedContent = true;
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
            int minAge = int.tryParse(ageTag["slug"]?.toString() ?? "0") ?? 0;
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
          _loadedProductCategoryIds.add(categoryId);
          _lastLoadedProductCategoryId = categoryId;
          break;
        }
        if (response.status == Status.ERROR) {
          setState(() => isLoadingNestedContent = false);
          break;
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => isLoadingNestedContent = false);
      if (kDebugMode)
        print("⚠️ _loadProductsByCategory timed out for $categoryId");
    } finally {
      if (_inFlightProductCategoryId == categoryId) {
        _inFlightProductCategoryId = null;
      }
    }
  }

  void _onCategoryTapped(int index) {
    if (index < 0 || index >= categories.length) return;
    if (_selectedCategoryIndex == index && !_showCategoryGrid) return;

    _addToRecent(categories[index]);

    setState(() {
      _selectedCategoryIndex = index;
      _showCategoryGrid = false;
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
      if (kDebugMode) print("_isProductCacheEmpty error: $e");
      return true;
    }
  }

  void _onSubCategoryTapped(int index) {
    if (index < 0 || index >= subCategories.length) return;
    final selectedSubCategory = subCategories[index];
    setState(() {
      _selectedSubCategoryIndex = index;
      if (currentCategoryLevel < categoryHierarchy.length) {
        navigationPath = navigationPath.sublist(0, currentCategoryLevel);
        categoryHierarchy =
            categoryHierarchy.sublist(0, currentCategoryLevel + 1);
      }
      navigationPath.add(selectedSubCategory.name);
      categoryHierarchy.add(selectedSubCategory.id);
      currentCategoryLevel++;
      isShowingSubCategories = true;
      _resetPaginationState();
      _allCategoryProducts.clear();
      categoryProducts.clear();
      isLoadingNestedContent = true;
    });
    _loadSubCategories(selectedSubCategory.id);
  }

  void _onBackToCategories() {
    if (currentCategoryLevel > 0) {
      setState(() {
        currentCategoryLevel--;
        navigationPath.removeLast();
        categoryHierarchy.removeLast();
        isShowingSubCategories = true;
        _resetPaginationState();
        _allCategoryProducts.clear();
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

  Stopwatch? refreshUIStopwatch;

  void _onItemSelected(int index, bool variantAdded) async {
    if (index == 0 && showBackButton) {
      _onBackToCategories();
      return;
    }
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
      Stopwatch? addProductStopwatch;
      if (Misc.enableUILogMessages) addProductStopwatch = Stopwatch()..start();
      subscription = orderBloc.updateOrderStream.listen((response) async {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (response.status == Status.LOADING) {
          const Center(child: CircularProgressIndicator());
        } else if (response.status == Status.COMPLETED) {
          if (kDebugMode) print("Item added to order $dbOrderId via API");
          if (Misc.showDebugSnackBar) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    "Item '${selectedProduct[AppDBConst.fastKeyItemName]}' added to order"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2)));
          }
          if (Misc.enableUILogMessages && addProductStopwatch != null) {
            addProductStopwatch.stop();
            globalProcessSteps.add(ProcessStep(
                name: TextConstants.addProductToOrder,
                timeTaken: addProductStopwatch.elapsedMilliseconds / 1000.0));
          }
          if (Misc.enableUILogMessages)
            refreshUIStopwatch = Stopwatch()..start();
          _refreshOrderList();
          subscription?.cancel();
        } else if (response.status == Status.ERROR) {
          if (Misc.enableUILogMessages && addProductStopwatch != null) {
            addProductStopwatch.stop();
            globalProcessSteps.clear();
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
    setState(() => _refreshCounter++);
    if (Misc.enableUILogMessages && refreshUIStopwatch != null) {
      refreshUIStopwatch?.stop();
      globalProcessSteps.add(ProcessStep(
          name: TextConstants.refreshDBUITime,
          timeTaken: refreshUIStopwatch!.elapsedMilliseconds / 1000.0));
    }
    if (Misc.enableUILogMessages && globalProcessSteps.isNotEmpty) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => LogsToast(
              steps: globalProcessSteps,
              onClose: () {
                globalProcessSteps.clear();
                Navigator.of(dialogContext).pop();
              }));
    }
  }

  bool get showBackButton => currentCategoryLevel >= 2;

  @override
  void dispose() {
    _categoryBloc.dispose();
    orderBloc.dispose();
    fastKeyTabIdNotifier.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INDIGO SECTION UI
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
                            strokeWidth: 2, color: Color(0xFFE74C3C)),
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
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() =>
                                _selectedIndigoSubCategoryIndex =
                                    index);
                                _loadIndigoProductsBySubCategory(
                                    _indigoSubCategories[index].id);
                              },
                              child: AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 180),
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
                                        : const Color(0xFFDDDDDD),
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
                                          errorBuilder:
                                              (_, __, ___) =>
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
      if (_showCategoryGrid) {
        return Expanded(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.only(
                  left: 10, right: 10, top: 0, bottom: 12),
              decoration: innerBoxDecoration(),
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

    return Scaffold(
      body: Column(
        children: [
          TopBar(
            screen: Screen.CATEGORY,
            onModeChanged: () async {
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
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              await UserDbHelper().saveUserSettings(
                  {AppDBConst.layoutSelection: newLayout},
                  modeChange: true);
              setState(() {});
            },
            onProductSelected: (product) async {
              try {
                if (kDebugMode)
                  print("###### serverOrderId: ${orderHelper.activeOrderId}");
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
          Expanded(
            child: Row(
              children: [
                if (sidebarPosition == SidebarPosition.left)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
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
                      refreshKey: _refreshCounter),
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) =>
                        setState(() => _selectedSidebarIndex = index),
                    isVertical: true,
                  ),
              ],
            ),
          ),
          if (sidebarPosition == SidebarPosition.bottom)
            custom_widgets.NavigationBar(
              selectedSidebarIndex: _selectedSidebarIndex,
              onSidebarItemSelected: (index) =>
                  setState(() => _selectedSidebarIndex = index),
              isVertical: false,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IndigoSubCategoryCard extends StatelessWidget {
  final IndigoCategoryModel category;
  final bool isDark;
  final VoidCallback onTap;

  const _IndigoSubCategoryCard(
      {required this.category, required this.isDark, required this.onTap});

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
                            height: 1.25)))),
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
    final cardBg = isDark ? const Color(0xFF26253A) : Colors.white;
    final borderColor =
    isDark ? const Color(0xFF3A3A52) : const Color(0xFFE3F2FD);
    final nameColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final priceColor = isDark ? Colors.grey.shade500 : const Color(0xFF1A1A1A);

    final bool isEbt = product.tags.any((t) {
      final name = t.name.toLowerCase();
      final slug = t.slug.toLowerCase();
      return name.contains('ebt') || slug.contains('ebt');
    });

    final bool hasVariants = product.type == 'variable';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: nameColor,
                  fontFamily: 'poppins',
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "\$${product.price}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: priceColor,
                  fontFamily: 'poppins',
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
}