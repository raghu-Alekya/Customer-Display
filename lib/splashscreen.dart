import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/promotion_bloc.dart';
import 'Homescreen.dart';
import 'promo_carousel_utils.dart';
import 'widgets/kiosk_loading.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  late final PageController _controller;
  int _currentPage = 0;
  Timer? _timer;

  List<String> images = const [
    'assets/offer.png',
    'assets/img.png',
    'assets/img2.png',
  ];

  void _advanceSplashSlide() {
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

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: promoVirtualBasePage(images.length),
    );
    _loadFullScreenPromotions();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _advanceSplashSlide(),
    );
  }

  Future<void> _loadFullScreenPromotions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (!mounted || token == null || token.trim().isEmpty) {
        return;
      }

      context.read<PromotionBloc>().add(
        FetchFullScreenPromotionImages(token),
      );
    } catch (e) {
      debugPrint("Failed to fetch promotions: $e");
      // Keep displaying cached images
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return BlocListener<PromotionBloc, PromotionState>(
        listener: (context, state) async {
          if (!mounted) return;

          if (state is PromotionLoaded &&
              state.type == PromotionType.fullScreen &&
              state.images.isNotEmpty) {

            // Download all new images first
            await Future.wait(
              state.images
                  .where((e) => e.startsWith("http"))
                  .map((e) => DefaultCacheManager().downloadFile(e)),
            );

            if (!mounted) return;

            setState(() {
              images = List<String>.from(state.images);
              _currentPage = 0;
            });

            _controller.jumpToPage(
              promoVirtualBasePage(images.length),
            );
          }
        },
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),

              /// 🔹 Auto Sliding Images (asset or network)
              Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  controller: _controller,
                  reverse: false,
                  itemCount: images.isEmpty ? 1 : kPromoVirtualPageCount,
                  onPageChanged: (i) {
                    if (images.isEmpty) return;
                    setState(() => _currentPage = i % images.length);
                  },
                  itemBuilder: (context, index) {
                  if (images.isEmpty) {
                    return const ColoredBox(color: Colors.black);
                  }
                  final src = images[index % images.length];
                  final isNetwork =
                      src.startsWith('http://') || src.startsWith('https://');

                  return isNetwork
                      ?CachedNetworkImage(
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
                          width: width,
                          height: height,
                          gaplessPlayback: true,
                        );
                },
              ),
              ),

            /// 🔹 Bottom Text (Responsive)
            Positioned(
              bottom: height * 0.05,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.05,
                    vertical: height * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Touch to Order",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
