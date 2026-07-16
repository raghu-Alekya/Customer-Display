import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kiosk/widgets/printer_settings_screen.dart';
import 'package:kiosk/widgets/setting_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/promotion_bloc.dart';
import 'bloc/store_details_bloc.dart';
import 'helper.dart';
import 'model/store_details_model.dart';
import 'category_screen.dart';
import 'customize_screen.dart';
import 'promo_carousel_utils.dart';
import 'widgets/kiosk_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late final PageController _controller;
  int _currentPage = 0;
  Timer? _slideTimer;
  String selectedType = "Dine-In"; // default

  StoreDetails? _storeDetails;

  /// 🔹 Replace with your API images
  List<String> images = [
    "assets/home.png",
    "assets/home2.png",
    "assets/home3.png",
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: promoVirtualBasePage(images.length),
    );
    _loadPromotions();
    _loadStoreDetails();

    _restartSlideTimer();
  }

  /// Always moves to the next page (forward). Content repeats via modulo so the
  /// carousel loops without animating backward from last → first.
  void _advancePromoOnePage() {
    if (!mounted || images.length < 2) return;
    if (!_controller.hasClients) return;
    final cur = _controller.page!.round();
    final next = cur + 1;
    if (next >= kPromoVirtualPageCount - 20) {
      _controller.jumpToPage(promoVirtualBasePage(images.length));
      return;
    }
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _restartSlideTimer() {
    _slideTimer?.cancel();
    if (images.length < 2) return;
    _slideTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _advancePromoOnePage(),
    );
  }

  Future<void> _loadPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (!mounted || token == null || token.trim().isEmpty) return;
    context.read<PromotionBloc>().add(FetchPortraitPromotionImages(token));
  }

  Future<void> _loadStoreDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (!mounted || token == null || token.trim().isEmpty) return;
    context.read<StoreDetailsBloc>().add(FetchStoreDetails(token));
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final buttonSpacing = Responsive.isDesktop(context)
        ? 40.0
        : Responsive.isTablet(context)
        ? 80.0
        : 50.0;

    final headerPadding = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 16.0
        : 12.0;

    final logoSize = Responsive.isDesktop(context)
        ? 90.0
        : Responsive.isTablet(context)
        ? 62.0
        : 52.0;

    final logoRadius = Responsive.isDesktop(context)
        ? 10.0
        : Responsive.isTablet(context)
        ? 8.0
        : 6.0;

    final titleFont = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 26.0
        : 14.0;

    final bodyFont = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 13.0
        : 11.0;
    final textFont = Responsive.isDesktop(context)
        ? 14.0
        : Responsive.isTablet(context)
        ? 13.0
        : 11.0;
    final headerHeight = Responsive.isDesktop(context)
        ? 130.0
        : Responsive.isTablet(context)
        ? 145.0
        : 80.0;

    final iconButtonSize = Responsive.isDesktop(context)
        ? 60.0
        : Responsive.isTablet(context)
        ? 52.0
        : 46.0;

    final iconSize = Responsive.isDesktop(context)
        ? 30.0
        : Responsive.isTablet(context)
        ? 26.0
        : 22.0;

    final buttonPadding = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 30.0
        : 10.0;


    final buttonHeight = Responsive.isDesktop(context)
        ? 60.0
        : Responsive.isTablet(context)
        ? 58.0
        : 58.0;

    final buttonFont = Responsive.isDesktop(context)
        ? 18.0
        : Responsive.isTablet(context)
        ? 20.0
        : 20.0;

    final imageSize = Responsive.isDesktop(context)
        ? 28.0
        : Responsive.isTablet(context)
        ? 30.0
        : 28.0;

    final horizontalPadding = Responsive.isDesktop(context)
        ? 32.0
        : Responsive.isTablet(context)
        ? 24.0
        : 18.0;

    final verticalPadding = Responsive.isDesktop(context)
        ? 16.0
        : Responsive.isTablet(context)
        ? 14.0
        : 12.0;

    final spacing = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 18.0
        : 22.0;
    final buttonWidth = MediaQuery.of(context).size.width * 0.42;

    return MultiBlocListener(
      listeners: [
        BlocListener<PromotionBloc, PromotionState>(
          listener: (context, state) async {
            if (!mounted) return;

            if (state is PromotionLoaded &&
                state.type == PromotionType.portrait &&
                state.images.isNotEmpty) {

              // Download all new images into cache first
              await Future.wait(
                state.images
                    .where((url) => url.startsWith("http"))
                    .map((url) => DefaultCacheManager().downloadFile(url)),
              );

              if (!mounted) return;

              setState(() {
                images = List<String>.from(state.images);
                _currentPage = 0;
              });

              _controller.jumpToPage(
                promoVirtualBasePage(images.length),
              );

              _restartSlideTimer();
            }
          },
        ),
        BlocListener<StoreDetailsBloc, StoreDetailsState>(
          listener: (context, state) {
            if (state is StoreDetailsLoaded) {
              setState(() => _storeDetails = state.details);
              final logo = state.details.logo;
              if (logo.isNotEmpty &&
                  (logo.startsWith('http://') || logo.startsWith('https://'))) {
                precacheImage(NetworkImage(logo), context);
              }
            }
          },
        ),
      ],
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: width * 0.99,
          height: height * 0.99,
          decoration: BoxDecoration(
            color: const Color(0xFF4A1D4F),
            // borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [

              /// 🔹 TOP HEADER
              SizedBox(
                height: headerHeight,
                child: Container(
                  padding: EdgeInsets.all(headerPadding),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4B544),
                    // borderRadius: BorderRadius.vertical(
                    //   top: Radius.circular(30),
                    // ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      BlocBuilder<StoreDetailsBloc, StoreDetailsState>(
                        builder: (context, state) {
                          if (state is! StoreDetailsLoaded) {
                            return SizedBox(
                              width: logoSize,
                              height: logoSize,
                            );
                          }

                          final details = state.details;

                          return details.logo.isEmpty
                              ? SizedBox(
                            width: logoSize,
                            height: logoSize,
                          )
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(logoRadius),
                            child: CachedNetworkImage(
                              imageUrl: details.logo,
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),

                      SizedBox(width: Responsive.w(context) * .02),

                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_storeDetails?.address.isNotEmpty == true)
                              Text(
                                _storeDetails!.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: textFont,
                                  color: const Color(0xFF333333),
                                ),
                              ),

                            if (_storeDetails?.cityLine.isNotEmpty == true)
                              Text(
                                _storeDetails!.cityLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: textFont,
                                  color: const Color(0xFF333333),
                                ),
                              ),

                            if (_storeDetails?.country.isNotEmpty == true)
                              Text(
                                _storeDetails!.country,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: textFont,
                                  color: const Color(0xFF333333),
                                ),
                              ),

                            Text(
                              "Open Everyday",
                              style: TextStyle(
                                fontSize: textFont,
                                color: const Color(0xFF333333),
                              ),
                            ),

                            if (_storeDetails?.phoneNumber.isNotEmpty == true)
                              Text(
                                _storeDetails!.phoneNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: textFont,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),


              /// 🔹 BODY
              /// 🔹 BODY (ONLY AUTO SCROLLIMAGES)
              Flexible(
                flex: Responsive.isDesktop(context)
                    ? 5
                    : Responsive.isTablet(context)
                    ? 4
                    : 3,
                child: Container(

                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.black),

                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: PageView.builder(
                          controller: _controller,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: images.isEmpty ? 1 : kPromoVirtualPageCount,
                          onPageChanged: (i) {
                            if (images.isEmpty) return;

                            setState(() {
                              _currentPage = i % images.length;
                            });
                          },
                          itemBuilder: (context, index) {
                            if (images.isEmpty) {
                              return const ColoredBox(color: Colors.black);
                            }

                            final src = images[index % images.length];
                            final isNetwork = src.startsWith('http://') ||
                                src.startsWith('https://');

                            if (isNetwork) {
                              return CachedNetworkImage(
                                imageUrl: src,
                                cacheManager: DefaultCacheManager(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (_, __) => const KioskPromoImageLoading(),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            }

                            return Image.asset(
                              src,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              gaplessPlayback: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// 🔹 BOTTOM BUTTONS
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: Container(
                  padding: EdgeInsets.all(
                    Responsive.isDesktop(context)
                        ? 12
                        : Responsive.isTablet(context)
                        ? 10
                        : 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF5E2A84),
                        Color(0xFF3B1A5A),
                      ],
                    ),
                    // borderRadius: BorderRadius.vertical(
                    //   bottom: Radius.circular(30),
                    // ),
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Select your Preference",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: titleFont,
                                ),
                              ),

                              SizedBox(height: spacing),

                            // final buttonWidth = MediaQuery.of(context).size.width * 0.30;

                    Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FoodUiScreen(
                                  orderType: "Dine-In",
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                "assets/dinner.png",
                                width: imageSize,
                                height: imageSize,
                              ),
                              SizedBox(width: spacing / 2),
                              Text(
                                "Dine In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: buttonFont,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FoodUiScreen(
                                  orderType: "Take Away",
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                "assets/take-away.png",
                                width: imageSize,
                                height: imageSize,
                              ),
                              SizedBox(width: spacing / 2),
                              Text(
                                "Take Away",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: buttonFont,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    )
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: buttonPadding,
                        bottom: 20,
                        child: Container(
                          width: iconButtonSize,
                          height: iconButtonSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.logout,
                              size: iconSize,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),

                      Positioned(
                        right: buttonPadding,
                        bottom: 20,
                        child: Container(
                          width: iconButtonSize,
                          height: iconButtonSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.settings,
                              size: iconSize,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// 🔥 CURVE SHAPE
class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.lineTo(size.width * 0.3, 0);
    path.quadraticBezierTo(
        0, size.height * 0.3, size.width * 0.3, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.6, size.height * 0.7, size.width * 0.3, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}