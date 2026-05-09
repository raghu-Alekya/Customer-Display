import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keyos_app/splashscreen.dart';

import 'bloc/user_login_bloc.dart';

class AppColors {
  static const primaryBlue = Color(0xFF23467A);
  static const background = Color(0xFFF5F6F8);
  static const white = Colors.white;
  static const keypadBg = Color(0xFFF1F3F6);
  static const textDark = Color(0xFF333333);
  static const textLight = Color(0xFF8A8A8A);
}

class UserLogin extends StatefulWidget {
  const UserLogin({super.key});

  @override
  State<UserLogin> createState() => _UserLoginState();
}

class _UserLoginState extends State<UserLogin> {
  String pin = "";

  void addDigit(String digit) {
    if (pin.length < 6) {
      setState(() {
        pin += digit;
      });
    }
  }

  void removeDigit() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  void clearPin() {
    setState(() {
      pin = "";
    });
  }

  Widget buildPinBox(int index) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          index < pin.length ? "●" : "",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget buildKey(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 60,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.keypadBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );
          } else if (state is AuthSuccess) {
            Navigator.pop(context); // close loader

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const KioskScreen(),
              ),
            );
          } else if (state is AuthFailure) {
            Navigator.pop(context); // close loader

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: Stack(
          children: [
            /// 🔵 Curved Header
            ClipPath(
              clipper: TopCurveClipper(),
              child: Container(
                height: 420,
                color: AppColors.primaryBlue,
              ),
            ),

            /// Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  const Text(
                    "Welcome Back !",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Admin",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),

                  const SizedBox(height: 30),

                  /// Login Card
                  Container(
                    width: 350,
                    height: 500,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10)
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "User Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Please input your PIN to validate your self",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        /// PIN Boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                          List.generate(6, (index) => buildPinBox(index)),
                        ),

                        const SizedBox(height: 16),

                        /// Keypad
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buildKey("1", onTap: () => addDigit("1")),
                                buildKey("2", onTap: () => addDigit("2")),
                                buildKey("3", onTap: () => addDigit("3")),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buildKey("4", onTap: () => addDigit("4")),
                                buildKey("5", onTap: () => addDigit("5")),
                                buildKey("6", onTap: () => addDigit("6")),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buildKey("7", onTap: () => addDigit("7")),
                                buildKey("8", onTap: () => addDigit("8")),
                                buildKey("9", onTap: () => addDigit("9")),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buildKey("C", onTap: clearPin),
                                buildKey("0", onTap: () => addDigit("0")),
                                buildKey("⌫", onTap: removeDigit),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        /// 🔥 LOGIN BUTTON (UPDATED)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              if (pin.length == 6) {
                                context
                                    .read<AuthBloc>()
                                    .add(LoginWithPinEvent(pin));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Enter 6 digit PIN")),
                                );
                              }
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// 🔷 Custom Curve
class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.lineTo(0, size.height - 80);

    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 80,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}