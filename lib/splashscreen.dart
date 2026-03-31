import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bloc/promotion_bloc.dart';
import 'Homescreen.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<String> images = const [
    'assets/offer.png',
    'assets/img.png',
    'assets/img2.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadFullScreenPromotions();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

  Future<void> _loadFullScreenPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (!mounted || token == null || token.trim().isEmpty) return;
    context.read<PromotionBloc>().add(FetchFullScreenPromotionImages(token));
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
      listener: (context, state) {
        if (!mounted) return;
        if (state is PromotionLoaded &&
            state.type == PromotionType.fullScreen &&
            state.images.isNotEmpty)  {
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
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final src = images[index];
                  final isNetwork =
                      src.startsWith('http://') || src.startsWith('https://');

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
                          width: width,
                          height: height,
                          gaplessPlayback: true,
                        );
                },
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
