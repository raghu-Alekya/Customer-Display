import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:keyos_app/repository/addon_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Homescreen.dart';
import 'bloc/promotion_bloc.dart';
import 'bloc/store_details_bloc.dart';
import 'bloc/category_bloc.dart';
import 'bloc/product_bloc.dart';
import 'bloc/sub category_bloc.dart';
import 'cart_manger.dart';
import 'cart_screen.dart';
import 'customize_screen.dart';
import 'model/category_model.dart';
import 'model/product model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FoodUiScreen extends StatefulWidget {
  final String orderType;
  const FoodUiScreen({super.key,required this.orderType});

  @override
  State<FoodUiScreen> createState() => _FoodUiScreenState();
}

class _FoodUiScreenState extends State<FoodUiScreen> {
  static const int rootCategoryId = 28;
  int? selectedType;
  int selectedCategory = 0;
  int selectedSubcategory = 0;
  int? selectedSubcategoryId;
  int currentPromoIndex = 0;

  late final PageController promoPageController;
  late final TextEditingController searchController;
  Timer? searchDebounceTimer;
  Timer? promoTimer;

  final List<String> promoImages = const [
    'assets/promo-1.jpeg',
    'assets/promo-2.jpeg',
    'assets/promo-3.png',
  ];
  List<String> bannerImages = const [];

  final List<String> orderTypes = ['Non Veg', 'Veg'];

  bool _matchesSelectedType(ProductModel product) {
    if (selectedType == null) return true;
    // Null from API is treated as "all", so it is visible in both filters.
    if (product.isVeg == null) return true;
    if (selectedType == 0) return product.isVeg == false; // Non Veg
    return product.isVeg == true; // Veg
  }

  @override
  void initState() {
    super.initState();
    promoPageController = PageController();
    searchController = TextEditingController();
    _startPromoAutoSlide();
    _loadBannerPromotions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStoreDetailsIfNeeded());
  }

  Future<void> _loadStoreDetailsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (!mounted || token == null || token.trim().isEmpty) return;
    final bloc = context.read<StoreDetailsBloc>();
    if (bloc.state is! StoreDetailsLoaded) {
      bloc.add(FetchStoreDetails(token));
    }
  }

  Future<void> _loadBannerPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (!mounted || token == null || token.trim().isEmpty) return;
    context.read<PromotionBloc>().add(FetchBannerPromotionImages(token));
  }

  void _startPromoAutoSlide() {
    if (promoImages.length < 2) return;
    promoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || promoImages.isEmpty) return;
      final nextPage = (currentPromoIndex + 1) % promoImages.length;
      promoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }
  double _getTotalPrice() {
    double total = 0;

    for (var item in CartManager.cartItems) {
      final product = item["product"];
      final qty = (item["qty"] as num?)?.toDouble() ?? 0;
      final addons = item["addons"] as List;

      // Product price may include a currency symbol like "₹"; strip it before parsing.
      final rawPrice = (product.price ?? '').toString().replaceAll('₹', '');
      final price = double.tryParse(rawPrice) ?? 0;

      final addonTotal = addons.fold<double>(
        0,
        (sum, a) => sum + (a.price as num).toDouble(),
      );

      total += (price + addonTotal) * qty;
    }

    return total;
  }

  @override
  void dispose() {
    promoTimer?.cancel();
    searchDebounceTimer?.cancel();
    promoPageController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<PromotionBloc, PromotionState>(
              listener: (context, state) {
                if (!mounted) return;
                if (state is PromotionLoaded &&
                    state.type == PromotionType.banner &&
                    state.images.isNotEmpty) {
                  setState(() {
                    bannerImages = state.images;
                    currentPromoIndex = 0;
                  });
                  promoPageController.jumpToPage(0);
                  for (final src in state.images) {
                    if (src.startsWith('http://') || src.startsWith('https://')) {
                      precacheImage(NetworkImage(src), context);
                    }
                  }
                }
              },
            ),
            BlocListener<CategoryBloc, CategoryState>(
              listener: (context, state) {
                if (state is CategoryLoaded) {
                  if (state.categories.isEmpty) {
                    context
                        .read<ProductBloc>()
                        .add(const FetchProductsForCategory(rootCategoryId));
                    return;
                  }

                  final safeIndex = selectedCategory < state.categories.length
                      ? selectedCategory
                      : 0;
                  final selectedCategoryId = state.categories[safeIndex].id;
                  context
                      .read<SubcategoryBloc>()
                      .add(FetchSubcategories(selectedCategoryId));
                } else if (state is CategoryError) {
                  context
                      .read<ProductBloc>()
                      .add(const FetchProductsForCategory(rootCategoryId));
                }
              },
            ),
            BlocListener<SubcategoryBloc, SubcategoryState>(
              listener: (context, state) {
                if (state is! SubcategoryLoaded) return;

                if (state.subcategories.isEmpty) {
                  selectedSubcategory = 0;
                  selectedSubcategoryId = null;
                  context
                      .read<ProductBloc>()
                      .add(FetchProductsForCategory(state.parentId));
                  return;
                }

                final existingIndex = state.subcategories.indexWhere(
                      (e) => e.id == selectedSubcategoryId,
                );
                final nextIndex = existingIndex >= 0 ? existingIndex : 0;
                selectedSubcategory = nextIndex;
                selectedSubcategoryId = state.subcategories[nextIndex].id;
                context
                    .read<ProductBloc>()
                    .add(FetchProductsForCategory(selectedSubcategoryId!));
              },
            ),
          ],
          child: Column(
            children: [
              _promoCard(),
              const SizedBox(height: 10),
              _topFilters(),
              SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _leftCategories(),
                    Container(width: 1, color: Colors.black12),
                    Expanded(
                      child: Column(
                        children: [
                          _subCategoryTabs(),
                          Expanded(child: _foodGrid()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _promoCard() {
    final images = bannerImages.isNotEmpty ? bannerImages : promoImages;
    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 96,
        child: PageView.builder(
          controller: promoPageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              currentPromoIndex = index;
            });
          },
          itemBuilder: (_, index) {
            final src = images[index];
            final isNetwork =
                src.startsWith('http://') || src.startsWith('https://');

            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                isNetwork
                    ? Image.network(
                        src,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : Image.asset(
                        src,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Logo + store name on the far left (like reference kiosk header).
  Widget _storeLogoBlock() {
    return BlocBuilder<StoreDetailsBloc, StoreDetailsState>(
      builder: (context, state) {
        if (state is! StoreDetailsLoaded) {
          return const SizedBox(width: 8);
        }
        final d = state.details;
        final url = d.logo.trim();
        final hasUrl = url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'));
        if (!hasUrl && d.name.isEmpty) {
          return const SizedBox(width: 8);
        }
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasUrl)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(Icons.storefront, size: 32, color: Color(0xFF506796)),
                      ),
                    ),
                  ),
                if (d.name.isNotEmpty) ...[
                  if (hasUrl) const SizedBox(height: 4),
                  Text(
                    d.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E5AAC),
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _storeLogoBlock(),
          const SizedBox(width: 4),
          _capsule(
            width: null,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF506796),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.orderType,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF506796),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Container(
              height: 30,
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _searchProducts(),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle:
                        TextStyle(fontSize: 11, color: Colors.black54),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _searchProducts,
                    child: Container(
                      height: 22,
                      width: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                      const Icon(Icons.search, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _capsule(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            borderColor: const Color(0xFFFFA620),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 14, color: Color(0xFFFF7A00)),
                SizedBox(width: 4),
                Text(
                  'Eng',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          ...List.generate(orderTypes.length, (index) {
            final selected = selectedType == index;
            return GestureDetector(
              onTap: () => setState(() {
                selectedType = selected ? null : index;
              }),
              child: _capsule(
                margin: const EdgeInsets.only(left: 4),
                height: 30,
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                borderColor:
                selected ? const Color(0xFFFFA620) : Colors.black12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: index == 0 ? Colors.red : Colors.green),
                    const SizedBox(width: 4),
                    Text(orderTypes[index], style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _subCategoryTabs() {
    return BlocBuilder<SubcategoryBloc, SubcategoryState>(
      builder: (context, state) {
        if (state is! SubcategoryLoaded || state.subcategories.isEmpty) {
          return const SizedBox.shrink();
        }

        final subcategories = state.subcategories;
        final safeSelected =
        selectedSubcategory < subcategories.length ? selectedSubcategory : 0;

        return Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(subcategories.length, (index) {
                  final selected = safeSelected == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedSubcategory = index;
                        selectedSubcategoryId = subcategories[index].id;
                      });
                      context.read<ProductBloc>().add(
                        FetchProductsForCategory(subcategories[index].id),
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index == subcategories.length - 1 ? 0 : 6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color:
                        selected ? const Color(0xFFFFE5CC) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFB36B)
                              : Colors.black12,
                        ),
                      ),
                      child: Text(
                        subcategories[index].name,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? const Color(0xFFFF7A00)
                              : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leftCategories() {
    return SizedBox(
      width: 98,
      child: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, state) {
          if (state is CategoryLoading || state is CategoryInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CategoryError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Failed to load categories',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.message,
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        context.read<CategoryBloc>().add(const FetchCategories());
                        context
                            .read<SubcategoryBloc>()
                            .add(const FetchSubcategories(rootCategoryId));
                        context
                            .read<ProductBloc>()
                            .add(const FetchProductsForCategory(rootCategoryId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is! CategoryLoaded || state.categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories',
                style: TextStyle(fontSize: 12),
              ),
            );
          }

          final categories = state.categories
              .where((c) => c.name.trim().toLowerCase() != 'uncategorized')
              .toList();
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories',
                style: TextStyle(fontSize: 12),
              ),
            );
          }
          final safeSelectedIndex = selectedCategory < categories.length
              ? selectedCategory
              : 0;

          return ListView.separated(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final c = categories[index];
              final selected = index == safeSelectedIndex;
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedCategory = index;
                    selectedSubcategory = 0;
                    selectedSubcategoryId = null;
                  });
                  context.read<SubcategoryBloc>().add(FetchSubcategories(c.id));
                  context
                      .read<ProductBloc>()
                      .add(FetchProductsForCategory(c.id));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF3E8) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? const Color(0xFFFF8A00) : Colors.black12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _categoryLeading(c),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? const Color(0xFFFF7A00) : Colors.black54,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryLeading(CategoryModel category) {
    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF6F6F6),
        ),
        child: const Icon(Icons.category, size: 20),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        category.imageUrl!,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF6F6F6),
            ),
            child: const Icon(Icons.category, size: 20),
          );
        },
      ),
    );
  }

  Widget _foodGrid() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductLoading || state is ProductInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProductError) {
          return Center(
            child: Text(
              'Failed to load items: ${state.message}',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (state is! ProductLoaded || state.products.isEmpty) {
          return const Center(child: Text('No items found'));
        }

        final products = state.products.where(_matchesSelectedType).toList();
        if (products.isEmpty) {
          return const Center(child: Text('No items found for selected type'));
        }

        return Center( // 🔥 centers the grid
          child: SizedBox(
            width: 450, // 🔥 control total grid width here
            child: GridView.builder(
              // shrinkWrap: true, // 🔥 important
              physics: const BouncingScrollPhysics(),
              // padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // ✅ keep 3
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (_, index) {
                final item = products[index];
                return _productCard(item);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _productCard(ProductModel item) {
    final Color typeColor = item.isVeg == true
        ? Colors.green
        : item.isVeg == false
        ? Colors.red
        : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openCustomize(item),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.crop_square_rounded, size: 13, color: typeColor),
                  Icon(Icons.circle, size: 6, color: typeColor),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Center(child: _productImage(item.imageUrl)),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '\$${item.price.replaceAll("₹", "")}',
                  style: const TextStyle(
                    color: Color(0xFF129A50),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _openCustomize(item),
                  child: Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD8B2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 13,
                      color: Color(0xFFFF8A00),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _openCustomize(ProductModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomizeScreen(
          product: item,
          addons: const [],
          orderType: widget.orderType,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Widget _productImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 38,
        width: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.fastfood_rounded, size: 20, color: Colors.black54),
      );
    }
    // 🔹 Debug: check if this URL is already cached
    () async {
      final fileInfo =
          await DefaultCacheManager().getFileFromCache(imageUrl);
      final fromCache = fileInfo != null;
      print('Product image [$imageUrl] cached before build? $fromCache');
    }();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl,       // <-- use imageUrl here
        height: 38,
        width: 38,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
          height: 38,
          width: 38,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 38,
          width: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.fastfood_rounded,
            size: 20,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  void _searchProducts() {
    final query = searchController.text.trim();
    if (query.isEmpty) {
      if (selectedSubcategoryId != null) {
        context
            .read<ProductBloc>()
            .add(FetchProductsForCategory(selectedSubcategoryId!));
        return;
      }

      final categoryState = context.read<CategoryBloc>().state;
      if (categoryState is CategoryLoaded && categoryState.categories.isNotEmpty) {
        final safeIndex = selectedCategory < categoryState.categories.length
            ? selectedCategory
            : 0;
        context.read<ProductBloc>().add(
          FetchProductsForCategory(categoryState.categories[safeIndex].id),
        );
        return;
      }

      context
          .read<ProductBloc>()
          .add(const FetchProductsForCategory(rootCategoryId));
      return;
    }

    context.read<ProductBloc>().add(SearchProducts(query));
  }

  void _onSearchChanged(String value) {
    searchDebounceTimer?.cancel();
    searchDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (value.trim().isEmpty || value.trim().length >= 2) {
        _searchProducts();
      }
    });
  }

  int _totalCartQuantity() {
    int total = 0;
    for (final item in CartManager.cartItems) {
      final qty = item['qty'] as int? ?? 0;
      total += qty;
    }
    return total;
  }


  Widget _bottomBar() {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_outlined, color: Colors.white, size: 21),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: 200, // 🔥 increased width (important)
            child: Row(
              children: [
                /// 🔹 TOTAL PRICE (OUTSIDE)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Price:',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "\$${_getTotalPrice().toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                /// 🔶 CART BUTTON
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(orderType: widget.orderType),
                      ),
                    );
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        /// 🔥 ICON + BADGE
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.shopping_cart_checkout,
                              size: 18,
                              color: Colors.white,
                            ),

                            if (CartManager.cartItems.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "${_totalCartQuantity()}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 6),

                        const Text(
                          'Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capsule({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    Color borderColor = const Color(0x22000000),
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

}