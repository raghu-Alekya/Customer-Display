import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/store_id_screen.dart';
import 'login_screen.dart';
import '../../Repositories/Auth/AuthIdsStore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkValidationAndNavigate();
  }

  Future<void> _checkValidationAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));

    // Same behavior as grocery PCH:
    // - Merchant login done in this install → employee PIN screen
    // - Otherwise → merchant/store login
    bool isValid = false;
    try {
      isValid = await AuthIdsStore.isMerchantLoginDone()
          .timeout(const Duration(seconds: 2));
      final storeId = (await AuthIdsStore.getStoreId()).trim();
      if (isValid) {
        debugPrint('[Splash] → Employee PIN (storeId=$storeId)');
      } else {
        debugPrint('[Splash] → Merchant login (no session for this build)');
      }
    } catch (e) {
      debugPrint('[Splash] Store login check failed: $e');
      isValid = false;
    }

    if (!mounted) return;

    if (isValid) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.2, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
                position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(seconds: 1),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const StoreIdScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.2, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
                position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2745),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: SvgPicture.asset(
                    'assets/svg/pinaka_logo.svg',
                    height: 120,
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
