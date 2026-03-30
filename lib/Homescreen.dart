import 'dart:async';
import 'package:flutter/material.dart';

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

  /// 🔹 Replace with your API images
  final List<String> images = [
    "assets/home.png",
    "assets/home2.png",
    "assets/home3.png",
  ];

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;

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

    return Scaffold(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("New Delhi\nRestaurant"),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text("123, Street, City"),
                          Text("Open Everyday"),
                          Text("+01 231 546 8945"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),


              /// 🔹 BODY
              /// 🔹 BODY (ONLY AUTO SCROLLIMAGES)
              Flexible(
                flex: 4, // 👈 control height here
                child: PageView.builder(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Image.asset(
                      images[index], // ✅ correct
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  },
                ),
              ),

              /// 🔹 BOTTOM BUTTONS
          Flexible(
            flex: 1,
              child:
              Container(
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FoodUiScreen(orderType: "Dine-In"), // ✅
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Image.asset("assets/dinner.png", width: 20, height: 20),
                              const SizedBox(width: 8),
                              const Text("Dine in"),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const  FoodUiScreen(orderType: "Take out"), // ✅
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Image.asset("assets/take-away.png", width: 20, height: 20),
                              const SizedBox(width: 8),
                              const Text("Take out"),
                            ],
                          ),
                        )
                      ],
                    )
                  ],
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