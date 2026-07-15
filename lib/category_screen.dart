import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kiosk/repository/addon_repository.dart';
import 'package:kiosk/widgets/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Homescreen.dart';
import 'helper.dart';
import 'promo_carousel_utils.dart';
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
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import 'package:kiosk/widgets/kiosk_loading.dart';

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

  final List<String> orderTypes = [
    "All",
    "Veg",
    "Non Veg",
  ];
  // int selectedType = 0;

  bool _matchesSelectedType(ProductModel product) {
    switch (selectedType) {
      case 0: // All
        return true;

      case 1: // Veg
        return product.isVeg == true;

      case 2: // Non Veg
        return product.isVeg == false;

      default:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();

    selectedCategory = 0;
    selectedSubcategory = 0;
    selectedSubcategoryId = null;

    promoPageController = PageController(
      initialPage: promoVirtualBasePage(promoImages.length),
    );

    searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductBloc>().add(const ResetProducts());
      context.read<CategoryBloc>().add(const FetchCategories());
    });

    _startPromoAutoSlide();
    _loadBannerPromotions();
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => _loadStoreDetailsIfNeeded());
  }

  List<String> get _activePromoList =>
      bannerImages.isNotEmpty ? bannerImages : promoImages;

  void _advanceCategoryPromo() {
    final list = _activePromoList;
    if (!mounted || list.length < 2) return;
    if (!promoPageController.hasClients) return;
    final cur = promoPageController.page!.round();
    final next = cur + 1;
    if (next >= kPromoVirtualPageCount - 20) {
      promoPageController.jumpToPage(promoVirtualBasePage(list.length));
      return;
    }
    promoPageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
    if (_activePromoList.length < 2) return;
    promoTimer?.cancel();
    promoTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _advanceCategoryPromo(),
    );
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
                  promoPageController
                      .jumpToPage(promoVirtualBasePage(state.images.length));
                  for (final src in state.images) {
                    if (src.startsWith('http://') || src.startsWith('https://')) {
                      precacheImage(NetworkImage(src), context);
                    }
                  }
                  _startPromoAutoSlide();
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

                    const SizedBox(width: 12), // 🔥 SPACE BEFORE DIVIDER

                    Container(width: 1, color: Colors.black12),

                    const SizedBox(width: 12), // 🔥 SPACE AFTER DIVIDER

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
    final images = _activePromoList;

    final screenHeight = Responsive.h(context);
    final screenWidth = Responsive.w(context);

    final bannerHeight = Responsive.isDesktop(context)
        ? screenHeight * 0.20
        : Responsive.isTablet(context)
        ? screenHeight * 0.18
        : screenHeight * 0.16;

    return SizedBox(
      width: screenWidth,
      height: bannerHeight.clamp(120.0, 220.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PageView.builder(
            controller: promoPageController,
            reverse: false,
            itemCount: images.isEmpty ? 1 : kPromoVirtualPageCount,
            onPageChanged: (index) {
              if (images.isEmpty) return;
              setState(() {
                currentPromoIndex = index % images.length;
              });
            },
            itemBuilder: (_, index) {
              if (images.isEmpty) {
                return const ColoredBox(color: Colors.black);
              }

              final src = images[index % images.length];
              final isNetwork =
                  src.startsWith('http://') ||
                      src.startsWith('https://');

              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),

                  isNetwork
                      ? Image.network(
                    src,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const KioskPromoImageLoading();
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
      ),
    );
  }

  /// Logo + store name on the far left (like reference kiosk header).
  Widget _storeLogoBlock() {
    return BlocBuilder<StoreDetailsBloc, StoreDetailsState>(
      builder: (context, state) {
        if (state is! StoreDetailsLoaded) {
          return SizedBox(width: Responsive.w(context) * 0.01);
        }

        final d = state.details;
        final url = d.logo.trim();

        final hasUrl = url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'));

        if (!hasUrl && d.name.isEmpty) {
          return SizedBox(width: Responsive.w(context) * 0.01);
        }

        final screenWidth = Responsive.w(context);

        final maxWidth = Responsive.isDesktop(context)
            ? 130.0
            : Responsive.isTablet(context)
            ? 120.0
            : 100.0;

        final logoWidth = Responsive.isDesktop(context)
            ? 85.0
            : Responsive.isTablet(context)
            ? 72.0
            : 60.0;

        final logoHeight = Responsive.isDesktop(context)
            ? 60.0
            : Responsive.isTablet(context)
            ? 52.0
            : 46.0;

        final borderRadius = screenWidth * 0.008;

        return Padding(
          padding: EdgeInsets.only(
            right: screenWidth * 0.008,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasUrl)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: logoWidth,
                      height: logoHeight,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: logoWidth,
                        height: logoHeight,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const KioskWaveDots(
                          dotSize: 6,
                          spacing: 4,
                          color: Color(0xFFFF9900),
                        ),
                      ),
                      errorWidget: (_, __, ___) => SizedBox(
                        width: logoWidth,
                        height: logoHeight,
                        child: const Icon(
                          Icons.storefront,
                          size: 30,
                          color: Color(0xFF506796),
                        ),
                      ),
                    ),
                  ),

                // if (d.name.isNotEmpty) ...[
                //   SizedBox(height: Responsive.h(context) * 0.005),
                //   Text(
                //     d.name,
                //     maxLines: 2,
                //     overflow: TextOverflow.ellipsis,
                //     textAlign: TextAlign.center,
                //     style: TextStyle(
                //       fontSize: Responsive.isDesktop(context)
                //           ? 12
                //           : Responsive.isTablet(context)
                //           ? 11
                //           : 10,
                //       fontWeight: FontWeight.w700,
                //       color: const Color(0xFF2E5AAC),
                //       height: 1.15,
                //     ),
                //   ),
                // ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topFilters() {
    final screenWidth = Responsive.w(context);

    final searchWidth = Responsive.isDesktop(context)
        ? 420.0
        : Responsive.isTablet(context)
        ? 300.0
        : 250.0;

    final chipWidth = Responsive.isDesktop(context)
        ? 95.0
        : Responsive.isTablet(context)
        ? 85.0
        : 75.0;

    final filterHeight = Responsive.isDesktop(context)
        ? 56.0
        : Responsive.isTablet(context)
        ? 50.0
        : 46.0;

    final fontSize = Responsive.isDesktop(context)
        ? 12.0
        : Responsive.isTablet(context)
        ? 11.0
        : 10.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * .006),
      child: Row(
        children: [
          _storeLogoBlock(),

          SizedBox(width: screenWidth * .008),

          KioskOrderTypeChip(orderType: widget.orderType),

          SizedBox(width: screenWidth * .020),

          /// SEARCH
          SizedBox(
            width: searchWidth,
            child: Container(
              height: filterHeight,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * .004),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: TextField(
                      controller: searchController,
                      readOnly: true,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: TextStyle(
                          fontSize: fontSize + 2,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(query: ""),
                          ),
                        ).then((_) {
                          context.read<ProductBloc>().add(
                            FetchProductsForCategory(
                              selectedSubcategoryId ?? rootCategoryId,
                            ),
                          );
                        });
                      },
                    ),
                  ),

                  Positioned(
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(query: ""),
                          ),
                        );
                      },
                      child: Container(
                        height: filterHeight - 8,
                        width: filterHeight - 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.search,
                          color: Colors.white,
                          size: fontSize + 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          /// VEG / NON VEG
          Row(
            children: List.generate(orderTypes.length, (index) {
              final selected = selectedType == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedType = index;
                  });
                },
                child: SizedBox(
                  width: chipWidth,
                  child: _capsule(
                    margin: const EdgeInsets.only(left: 6),
                    height: filterHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    borderColor: selected
                        ? const Color(0xFFFFA620)
                        : Colors.black12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (index != 0) ...[
                          Icon(
                            Icons.circle,
                            size: fontSize,
                            color: index == 1 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            orderTypes[index],
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _subCategoryTabs() {
    final screenWidth = Responsive.w(context);

    final horizontalPadding = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 14.0
        : 10.0;

    final verticalPadding = Responsive.isDesktop(context)
        ? 10.0
        : Responsive.isTablet(context)
        ? 8.0
        : 6.0;

    final borderRadius = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 16.0
        : 14.0;

    final fontSize = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 13.0
        : 11.0;

    return BlocBuilder<SubcategoryBloc, SubcategoryState>(
      builder: (context, state) {
        if (state is! SubcategoryLoaded || state.subcategories.isEmpty) {
          return const SizedBox.shrink();
        }

        final subcategories = state.subcategories;

        final safeSelected =
        selectedSubcategory < subcategories.length
            ? selectedSubcategory
            : 0;

        return Padding(
          padding: EdgeInsets.only(
            left: screenWidth * .005,
            right: screenWidth * .008,
            bottom: screenWidth * .006,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
                        FetchProductsForCategory(
                          subcategories[index].id,
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(
                        right: screenWidth * .006,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFFE5CC)
                            : Colors.white,
                        borderRadius:
                        BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFB36B)
                              : Colors.black12,
                        ),
                      ),
                      child: Text(
                        subcategories[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
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
    final screenWidth = Responsive.w(context);

    final panelWidth = Responsive.isDesktop(context)
        ? 120.0
        : Responsive.isTablet(context)
        ? 120.0
        : 110.0;

    final itemPadding = Responsive.isDesktop(context)
        ? 8.0
        : Responsive.isTablet(context)
        ? 6.0
        : 5.0;

    final imageSpacing = Responsive.isDesktop(context)
        ? 12.0
        : 8.0;

    final fontSize = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 13.0
        : 12.0;

    final borderRadius = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 16.0
        : 14.0;

    return SizedBox(
      width: panelWidth,
      child: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, state) {
          if (state is CategoryLoading || state is CategoryInitial) {
            return const KioskBlockLoading();
          }

          if (state is CategoryError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * .01,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load categories',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: screenWidth * .005),

                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        color: Colors.black54,
                      ),
                    ),

                    SizedBox(height: screenWidth * .01),

                    TextButton(
                      onPressed: () {
                        context.read<CategoryBloc>().add(
                          const FetchCategories(),
                        );

                        context.read<SubcategoryBloc>().add(
                          const FetchSubcategories(rootCategoryId),
                        );

                        context.read<ProductBloc>().add(
                          const FetchProductsForCategory(rootCategoryId),
                        );
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is! CategoryLoaded || state.categories.isEmpty) {
            return Center(
              child: Text(
                "No categories",
                style: TextStyle(fontSize: fontSize),
              ),
            );
          }

          final categories = state.categories
              .where(
                (c) =>
            c.name.trim().toLowerCase() != "uncategorized",
          )
              .toList();

          if (categories.isEmpty) {
            return Center(
              child: Text(
                "No categories",
                style: TextStyle(fontSize: fontSize),
              ),
            );
          }

          final safeSelectedIndex =
          selectedCategory < categories.length
              ? selectedCategory
              : 0;

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: screenWidth * .004,
              right: screenWidth * .003,
              bottom: screenWidth * .01,
            ),
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(
              height: screenWidth * .008,
            ),
            itemBuilder: (_, index) {
              final c = categories[index];
              final selected = index == safeSelectedIndex;

              return InkWell(
                borderRadius:
                BorderRadius.circular(borderRadius),
                onTap: () {
                  setState(() {
                    selectedCategory = index;
                    selectedSubcategory = -1;
                    selectedSubcategoryId = null;
                  });

                  context.read<ProductBloc>().add(
                    ClearProducts(),
                  );

                  context.read<SubcategoryBloc>().add(
                    FetchSubcategories(c.id),
                  );
                },
                child: AnimatedContainer(
                  duration:
                  const Duration(milliseconds: 250),
                  padding: EdgeInsets.symmetric(
                    horizontal: itemPadding,
                    vertical: itemPadding,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF9B17)
                        : Colors.white,
                    borderRadius:
                    BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF9B17)
                          : Colors.black12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      _categoryLeading(c),

                      SizedBox(height: imageSpacing),

                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: selected
                              ? Colors.black
                              : Colors.black54,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
    final imageSize = Responsive.isDesktop(context)
        ? 80.0
        : Responsive.isTablet(context)
        ? 70.0
        : 70.0;

    final borderRadius = Responsive.isDesktop(context)
        ? 16.0
        : Responsive.isTablet(context)
        ? 14.0
        : 12.0;

    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          Icons.category,
          size: imageSize * 0.55,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        category.imageUrl!,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.category,
            size: imageSize * 0.55,
          ),
        ),
      ),
    );
  }

  Widget _foodGrid() {
    print("🔥 FoodGrid Rebuild");

    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductInitial) {
          return const SizedBox();
        }

        if (state is ProductLoading) {
          return const Center(
            child: KioskBlockLoading(
              message: "Loading products...",
            ),
          );
        }

        if (state is ProductError) {
          return Center(
            child: Text(
              "Failed to load items: ${state.message}",
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (state is! ProductLoaded || state.products.isEmpty) {
          return const Center(
            child: Text("No items found"),
          );
        }

        final products = state.products
            .where(_matchesSelectedType)
            .toList();

        if (products.isEmpty) {
          return const Center(
            child: Text("No items found for selected type"),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            int crossAxisCount;
            double childAspectRatio;
            double spacing;

            if (Responsive.isDesktop(context)) {
              crossAxisCount = (width / 210).floor().clamp(4, 7);
              childAspectRatio = 0.88;
              spacing = 12;
            } else if (Responsive.isTablet(context)) {
              crossAxisCount = (width / 190).floor().clamp(3, 5);
              childAspectRatio = 0.85;
              spacing = 10;
            } else {
              crossAxisCount = (width / 170).floor().clamp(2, 3);
              childAspectRatio = 0.82;
              spacing = 8;
            }

            return GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(
                Responsive.isDesktop(context)
                    ? 12
                    : Responsive.isTablet(context)
                    ? 10
                    : 8,
              ),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                return _productCard(products[index]);
              },
            );
          },
        );
      },
    );
  }
  // Widget _foodGrid() {
  //   print("🔥 FoodGrid Rebuild");
  //
  //   return BlocBuilder<ProductBloc, ProductState>(
  //     builder: (context, state) {
  //       if (state is ProductInitial) {
  //         return const SizedBox();
  //       }
  //
  //       if (state is ProductLoading) {
  //         return const Center(
  //           child: KioskBlockLoading(
  //             message: "Loading products...",
  //           ),
  //         );
  //       }
  //
  //       if (state is ProductError) {
  //         return Center(
  //           child: Text(
  //             "Failed to load items: ${state.message}",
  //             style: const TextStyle(
  //               color: Colors.grey,
  //             ),
  //             textAlign: TextAlign.center,
  //           ),
  //         );
  //       }
  //
  //       if (state is! ProductLoaded || state.products.isEmpty) {
  //         return const Center(
  //           child: Text("No items found"),
  //         );
  //       }
  //
  //       final products = state.products
  //           .where(_matchesSelectedType)
  //           .toList();
  //
  //       if (products.isEmpty) {
  //         return const Center(
  //           child: Text("No items found for selected type"),
  //         );
  //       }
  //
  //       return LayoutBuilder(
  //         builder: (context, constraints) {
  //           final width = constraints.maxWidth;
  //
  //           int crossAxisCount;
  //           double childAspectRatio;
  //           double spacing;
  //
  //           if (Responsive.isDesktop(context)) {
  //             crossAxisCount = (width / 210).floor().clamp(4, 7);
  //             childAspectRatio = 0.88;
  //             spacing = 12;
  //           } else if (Responsive.isTablet(context)) {
  //             crossAxisCount = (width / 190).floor().clamp(3, 5);
  //             childAspectRatio = 0.85;
  //             spacing = 10;
  //           } else {
  //             crossAxisCount = (width / 170).floor().clamp(2, 3);
  //             childAspectRatio = 0.82;
  //             spacing = 8;
  //           }
  //
  //           return GridView.builder(
  //             physics: const BouncingScrollPhysics(),
  //             padding: EdgeInsets.all(
  //               Responsive.isDesktop(context)
  //                   ? 12
  //                   : Responsive.isTablet(context)
  //                   ? 10
  //                   : 8,
  //             ),
  //             itemCount: products.length,
  //             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //               crossAxisCount: crossAxisCount,
  //               crossAxisSpacing: spacing,
  //               mainAxisSpacing: spacing,
  //               childAspectRatio: childAspectRatio,
  //             ),
  //             itemBuilder: (context, index) {
  //               return _productCard(products[index]);
  //             },
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _productCard(ProductModel item) {
    final Color typeColor = item.isVeg == true
        ? Colors.green
        : item.isVeg == false
        ? Colors.red
        : Colors.transparent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;

        final imageSize = Responsive.isDesktop(context)
            ? (cardWidth * 0.58).clamp(90.0, 120.0)
            : Responsive.isTablet(context)
            ? (cardWidth * 0.55).clamp(80.0, 110.0)
            : (cardWidth * 0.50).clamp(65.0, 90.0);

        final padding = Responsive.isDesktop(context)
            ? 14.0
            : Responsive.isTablet(context)
            ? 12.0
            : 10.0;

        final titleFont = Responsive.isDesktop(context)
            ? 15.0
            : Responsive.isTablet(context)
            ? 13.0
            : 11.0;

        final priceFont = Responsive.isDesktop(context)
            ? 16.0
            : Responsive.isTablet(context)
            ? 14.0
            : 12.0;

        final iconSize = Responsive.isDesktop(context)
            ? 20.0
            : Responsive.isTablet(context)
            ? 18.0
            : 16.0;

        final dotSize = Responsive.isDesktop(context)
            ? 9.0
            : Responsive.isTablet(context)
            ? 8.0
            : 7.0;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openCustomize(item),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// Product Image
                Expanded(
                  flex: 5,
                  child: Center(
                    child: _productImage(
                      item.imageUrl,
                      size: imageSize,
                    ),
                  ),
                ),

                SizedBox(height: padding * .5),

                /// Product Details
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.crop_square_rounded,
                              size: iconSize,
                              color: typeColor,
                            ),
                            Icon(
                              Icons.circle,
                              size: dotSize,
                              color: typeColor,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: padding * .4),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleFont,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),

                            SizedBox(width: padding * .1),

                            Text(
                              '\$${item.price.replaceAll("₹", "")}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: priceFont,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF129A50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _openCustomize(ProductModel item) async {
    final screenSize = MediaQuery.of(context).size;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          elevation: 8,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: Responsive.isDesktop(context)
                ? screenSize.width * 0.18
                : Responsive.isTablet(context)
                ? screenSize.width * 0.10
                : 20,
            vertical: Responsive.isDesktop(context)
                ? screenSize.height * 0.09
                : Responsive.isTablet(context)
                ? screenSize.height * 0.08
                : 20,
          ),
          child: SizedBox(
            width: Responsive.isDesktop(context)
                ? screenSize.width * 0.75
                : Responsive.isTablet(context)
                ? screenSize.width * 0.68
                : screenSize.width * 0.68,
            height: Responsive.isDesktop(context)
                ? screenSize.height * 0.40
                : Responsive.isTablet(context)
                ? screenSize.height * 0.55
                : screenSize.height * 0.60,
            child: CustomizeScreen(
              product: item,
              addons: const [],
              orderType: widget.orderType,
              openedFromSearch: false,
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    }
  }
  // static const double _productImageSize = 76;

  Widget _productImage(
      String? imageUrl, {
        required double size,
      }) {
    final borderRadius = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 12.0
        : 10.0;

    final iconSize = size * 0.35;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          Icons.fastfood_rounded,
          size: iconSize,
          color: Colors.black54,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => SizedBox(
          width: size,
          height: size,
          child: const KioskProductThumbLoading(),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.fastfood_rounded,
            size: iconSize,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  void _searchProducts(String query) {
    query = query.trim();

    if (query.isEmpty) {
      if (selectedSubcategoryId != null) {
        context.read<ProductBloc>()
            .add(FetchProductsForCategory(selectedSubcategoryId!));
        return;
      }

      final categoryState = context.read<CategoryBloc>().state;

      if (categoryState is CategoryLoaded &&
          categoryState.categories.isNotEmpty) {
        final safeIndex = selectedCategory < categoryState.categories.length
            ? selectedCategory
            : 0;

        context.read<ProductBloc>().add(
          FetchProductsForCategory(
            categoryState.categories[safeIndex].id,
          ),
        );
        return;
      }

      context.read<ProductBloc>().add(
        const FetchProductsForCategory(rootCategoryId),
      );
      return;
    }

    if (query.length >= 2) {
      context.read<ProductBloc>().add(SearchProducts(query));
    }
  }

  void _onSearchChanged(String value) {
    searchDebounceTimer?.cancel();

    final query = value.trim();

    // Immediately clear old search results
    if (query.isNotEmpty && query.length < 2) {
      context.read<ProductBloc>().add(ClearProducts());
      return;
    }

    searchDebounceTimer = Timer(
      const Duration(milliseconds: 450),
          () {
        if (!mounted) return;

        _searchProducts(query);
      },
    );
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
    final bottomHeight = Responsive.isDesktop(context)
        ? 92.0
        : Responsive.isTablet(context)
        ? 86.0
        : 78.0;
    final homeSize = Responsive.isDesktop(context)
        ? 64.0
        : Responsive.isTablet(context)
        ? 56.0
        : 50.0;

    final cartHeight = Responsive.isDesktop(context)
        ? 60.0
        : Responsive.isTablet(context)
        ? 54.0
        : 48.0;

    final totalFont = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 18.0
        : 16.0;

    final labelFont = Responsive.isDesktop(context)
        ? 12.0
        : Responsive.isTablet(context)
        ? 11.0
        : 10.0;

    final cartFont = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 18.0
        : 16.0;

    return Container(
      height: bottomHeight,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context) * .015,
        vertical: Responsive.h(context) * .01,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0x11000000)),
        ),
      ),
      child: Row(
        children: [
          /// HOME BUTTON
          GestureDetector(
            onTap: () {
              CartManager.cartItems.clear();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
                    (route) => false,
              );
            },
            child: Container(
              width: homeSize,
              height: homeSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(12),
              ),
              child:Icon(
                Icons.home_outlined,
                color: Colors.white,
                size: Responsive.isDesktop(context)
                    ? 34
                    : Responsive.isTablet(context)
                    ? 30
                    : 26,
              ),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: Responsive.isDesktop(context)
                ? 260
                : Responsive.isTablet(context)
                ? 220
                : 190,
            child: Row(
              children: [
                /// TOTAL PRICE
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Price",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: labelFont,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "\$${_getTotalPrice().toStringAsFixed(2)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: totalFont,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: Responsive.w(context) * .01),

                /// CART BUTTON
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(
                          orderType: widget.orderType,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: cartHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.isDesktop(context)
                          ? 28
                          : Responsive.isTablet(context)
                          ? 24
                          : 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.shopping_cart_checkout,
                              color: Colors.white,
                              size: Responsive.isDesktop(context)
                                  ? 34
                                  : Responsive.isTablet(context)
                                  ? 30
                                  : 26,
                            ),
                            if (CartManager.cartItems.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "${_totalCartQuantity()}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.isDesktop(context)
                                          ? 12
                                          : Responsive.isTablet(context)
                                          ? 11
                                          : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(width: Responsive.w(context) * .006),

                        Text(
                          "Cart",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: cartFont,
                            fontWeight: FontWeight.w700,
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
    final horizontalPadding = Responsive.isDesktop(context)
        ? 6.0
        : Responsive.isTablet(context)
        ? 6.0
        : 8.0;

    final verticalPadding = Responsive.isDesktop(context)
        ? 9.0
        : Responsive.isTablet(context)
        ? 6.0
        : 5.0;

    final borderRadius = Responsive.isDesktop(context)
        ? 12.0
        : Responsive.isTablet(context)
        ? 10.0
        : 8.0;

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: Alignment.center,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }

}