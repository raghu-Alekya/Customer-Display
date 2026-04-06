import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keyos_app/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/promotion_bloc.dart';
import 'bloc/store_details_bloc.dart';
import 'model/store_details_model.dart';
import 'category_screen.dart';
import 'customize_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final PageController _controller = PageController();
  int _currentPage = 0;
  late Timer _timer;
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
    _loadPromotions();
    _loadStoreDetails();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (images.isEmpty) return;

      if (_currentPage < images.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _controller.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
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
    _timer.cancel();
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
              _controller.jumpToPage(0);
              for (final src in state.images) {
                if (src.startsWith('http://') || src.startsWith('https://')) {
                  precacheImage(NetworkImage(src), context);
                }
              }
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
                              return SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Color(0xFF222222),
                                    ),
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
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    details.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                ),
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
                    PageView.builder(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final src = images[index];
                        final isNetwork = src.startsWith('http://') ||
                            src.startsWith('https://');

                        return isNetwork
                            ? CachedNetworkImage(
                          imageUrl: src,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) => const ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
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
                  child: Column(
                    children: [
                      const Text(
                        "Select your Preference",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

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
                                  horizontal: 20, vertical: 12),
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

                          /// 🔹 Settings
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const PrinterSettingsAndTestScreen(), // your settings screen
                                ),
                              );
                            },
                            tooltip: 'Printer Settings',
                          ),
                        ],
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