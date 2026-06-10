import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiosk/widgets/printer_settings_screen.dart';
import 'package:kiosk/widgets/setting_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/promotion_bloc.dart';
import 'bloc/store_details_bloc.dart';
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

    return MultiBlocListener(
      listeners: [
        BlocListener<PromotionBloc, PromotionState>(
          listener: (context, state) {
            if (state is PromotionLoaded &&
                state.type == PromotionType.portrait &&
                state.images.isNotEmpty) {
              setState(() {
                images = state.images;
                _currentPage = 0;
              });
              _controller.jumpToPage(promoVirtualBasePage(images.length));
              for (final src in state.images) {
                if (src.startsWith('http://') || src.startsWith('https://')) {
                  precacheImage(NetworkImage(src), context);
                }
              }
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
          width: width * 0.9,
          height: height * 0.95,
          decoration: BoxDecoration(
            color: const Color(0xFF4A1D4F),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [

              /// 🔹 TOP HEADER
              Flexible(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4B544),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: BlocBuilder<StoreDetailsBloc, StoreDetailsState>(
                          buildWhen: (prev, next) =>
                              next is StoreDetailsInitial ||
                              next is StoreDetailsLoading ||
                              next is StoreDetailsLoaded ||
                              next is StoreDetailsError,
                          builder: (context, state) {
                            if (state is StoreDetailsInitial ||
                                state is StoreDetailsLoading) {
                              return const SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: KioskWaveDots(
                                    dotSize: 7,
                                    spacing: 4,
                                    color: Color(0xFFFF9900),
                                  ),
                                ),
                              );
                            }
                            if (state is StoreDetailsError) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 40,
                                    color: Color(0xFF222222),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Store',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF222222),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            final details = (state as StoreDetailsLoaded).details;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (details.logo.isNotEmpty &&
                                    (details.logo.startsWith('http://') ||
                                        details.logo.startsWith('https://')))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: details.logo,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.black12,
                                          alignment: Alignment.center,
                                          child: const KioskWaveDots(
                                            dotSize: 5,
                                            spacing: 3,
                                            color: Color(0xFFFF9900),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                // Expanded(
                                //   child: Text(
                                //     details.name,
                                //     style: const TextStyle(
                                //       fontSize: 18,
                                //       fontWeight: FontWeight.w700,
                                //       color: Color(0xFF222222),
                                //     ),
                                //   ),
                                // ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_storeDetails?.address.isNotEmpty == true)
                              Text(
                                _storeDetails!.address,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            if (_storeDetails != null &&
                                _storeDetails!.cityLine.isNotEmpty)
                              Text(
                                _storeDetails!.cityLine,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            if (_storeDetails?.country.isNotEmpty == true)
                              Text(
                                _storeDetails!.country,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            const Text(
                              'Open Everyday',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF333333),
                              ),
                            ),
                            if (_storeDetails?.phoneNumber.isNotEmpty == true)
                              Text(
                                _storeDetails!.phoneNumber,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
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
                flex: 4, // 👈 control height here
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: Colors.black)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: PageView.builder(
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        reverse: false,
                        itemCount:
                            images.isEmpty ? 1 : kPromoVirtualPageCount,
                        onPageChanged: (i) {
                          if (images.isEmpty) return;
                          setState(
                            () => _currentPage = i % images.length,
                          );
                        },
                        itemBuilder: (context, index) {
                        if (images.isEmpty) {
                          return const ColoredBox(color: Colors.black);
                        }
                        final src = images[index % images.length];
                        final isNetwork = src.startsWith('http://') ||
                            src.startsWith('https://');

                        return isNetwork
                            ? CachedNetworkImage(
                          imageUrl: src,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) => const KioskPromoImageLoading(),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: Icon(Icons.broken_image, color: Colors.white70),
                            ),
                          ),
                        )
                            // : Image.asset(...);
                            : Image.asset(
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

              /// 🔹 BOTTOM BUTTONS
              Flexible(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5E2A84), Color(0xFF3B1A5A)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),

                  // ✅ IMPORTANT: USE STACK
                  child: Stack(
                    children: [

                      /// 🔽 MAIN CONTENT
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Select your Preference",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [

                              /// 🔹 Dine In
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 35, vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const FoodUiScreen(orderType: "Dine-In"),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Image.asset("assets/dinner.png",
                                        width: 20, height: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Dine in",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),

                              /// 🔹 Take Away
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pinkAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const FoodUiScreen(orderType: "Take Away"),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Image.asset("assets/take-away.png",
                                        width: 20, height: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Take Away",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      /// 🔥 SETTINGS BUTTON (BOTTOM RIGHT)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  // const PrinterSettingsAndTestScreen(),
                                  const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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