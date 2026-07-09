import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiosk/splashscreen.dart';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxHeight > constraints.maxWidth;

            final headerHeight = isPortrait
                ? constraints.maxHeight * 0.42
                : constraints.maxHeight * 0.75;

            final cardWidth = isPortrait
                ? constraints.maxWidth * 0.70
                : constraints.maxWidth * 0.42;

            return Stack(
              children: [
                /// Curved Header
                ClipPath(
                  clipper: TopCurveClipper(),
                  child: Container(
                    height: headerHeight,
                    width: double.infinity,
                    color: AppColors.primaryBlue,
                  ),
                ),

                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: SizedBox(
                        width: cardWidth,
                        child: Column(
                          children: [
                            SizedBox(height: isPortrait ? 20 : 10),

                            Text(
                              "Welcome Back !",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isPortrait ? 30 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              "Admin",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isPortrait ? 20 : 18,
                              ),
                            ),

                            SizedBox(height: isPortrait ? 35 : 20),

                            /// Login Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "User Login",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  const Text(
                                    "Please input your PIN to validate yourself",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  /// PIN Boxes
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    children: List.generate(
                                      6,
                                          (index) => buildPinBox(index),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  /// Keypad
                                  Column(
                                    children: [
                                      for (int row = 0; row < 4; row++)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              if (row == 0) ...[
                                                buildKey("1",
                                                    onTap: () => addDigit("1")),
                                                buildKey("2",
                                                    onTap: () => addDigit("2")),
                                                buildKey("3",
                                                    onTap: () => addDigit("3")),
                                              ],
                                              if (row == 1) ...[
                                                buildKey("4",
                                                    onTap: () => addDigit("4")),
                                                buildKey("5",
                                                    onTap: () => addDigit("5")),
                                                buildKey("6",
                                                    onTap: () => addDigit("6")),
                                              ],
                                              if (row == 2) ...[
                                                buildKey("7",
                                                    onTap: () => addDigit("7")),
                                                buildKey("8",
                                                    onTap: () => addDigit("8")),
                                                buildKey("9",
                                                    onTap: () => addDigit("9")),
                                              ],
                                              if (row == 3) ...[
                                                buildKey("C", onTap: clearPin),
                                                buildKey("0",
                                                    onTap: () => addDigit("0")),
                                                buildKey("⌫",
                                                    onTap: removeDigit),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
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
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                              Text("Enter 6 digit PIN"),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        "Login",
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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