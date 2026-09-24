import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../Blocs/Assets/asset_bloc.dart';
import '../../Blocs/Auth/login_bloc.dart';
import '../../Blocs/Auth/logout_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/fast_key_db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/login_model.dart';
import '../../Repositories/Assets/asset_repository.dart';
import '../../Repositories/Auth/login_repository.dart';
import '../../Repositories/Auth/logout_repository.dart';
import '../../Repositories/Orders/order_repository.dart';
import '../../Repositories/session_valadition_repository.dart';
import '../../Widgets/SafeStorageHelper.dart';
import '../../Widgets/discount_engine_constants.dart';
import '../../screens/Home/shift_open_close_balance.dart';
import '../Home/pos_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<String> _password = List.filled(6, "");
  late LoginBloc _bloc;
  late AssetBloc _assetBloc;
  bool _hasErrorShown = false;
  bool _discountSyncDone = false;
  bool _isNavigating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bloc = LoginBloc(LoginRepository());
    _assetBloc = AssetBloc(AssetRepository());
  }

  void _updatePassword(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    for (int i = 0; i < _password.length; i++) {
      if (_password[i].isEmpty) {
        setState(() {
          _password[i] = value;
        });
        if (kDebugMode) {
          print("Password updated: $_password");
        }

        // Auto-submit when 6 digits are entered
        if (i == 5) {
          _handleLogin();
        }
        break;
      }
    }
  }

  void _deletePassword() {
    for (int i = _password.length - 1; i >= 0; i--) {
      if (_password[i].isNotEmpty) {
        setState(() {
          _password[i] = "";
          _errorMessage = null;
        });
        if (kDebugMode) {
          print("Password deleted: $_password");
        }
        break;
      }
    }
  }

  void _clearPassword() {
    setState(() {
      for (int i = 0; i < _password.length; i++) {
        _password[i] = "";
      }
      _errorMessage = null;
    });
    if (kDebugMode) {
      print("Password cleared: $_password");
    }
  }

  bool _validatePin() {
    if (_password.any((digit) => digit.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter 6-digit PIN',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _handleLogin() async {
    if (!_validatePin()) return;
    _hasErrorShown = false;
    setState(() {
      _errorMessage = null;
    });
    final pin = _password.join();
    _bloc.fetchLoginToken(LoginRequest(pin));
  }

  void resetLoadStatus() {
    FastKeyDBHelper.isFastkeyLoaded = false;
    OrderHelper.isOrderPanelLoaded = false;

    if (kDebugMode) {
      print(
          "resetLoadStatus: isFastkeyLoaded -> ${FastKeyDBHelper.isFastkeyLoaded}, isOrderPanelLoaded -> ${OrderHelper.isOrderPanelLoaded}");
    }
  }

  void _onLoginSuccess(LoginResponse loginResponse) async {
    if (_isNavigating) return;
    _isNavigating = true;

    final pin = _password.join();
    final token = loginResponse.token ?? "";

    TokenValidationService.startValidation(
      token: token,
      pin: pin,
    );

    await SafeStorageHelper.saveSafeEnableDrop(
      loginResponse.safeEnableDrop == "1",
    );

    if (!_discountSyncDone) {
      _discountSyncDone = true;
      try {
        final repo = OrderRepository();
        await syncDiscountRulesFromApi(AppDB.isar, repo);
        debugPrint("✅ Discount rules synced after login");
      } catch (e) {
        debugPrint("❌ Discount rule sync failed: $e");
      }
    }

    if (kDebugMode) {
      print("🔐 safe_enable = ${loginResponse.safeEnable}");
      print("💾 safe_enable stored = ${loginResponse.safeEnable == "1"}");
      print("🔽 safe_enable_drop = ${loginResponse.safeEnableDrop}");
    }

    unawaited(_assetBloc.fetchImageAssets());
    await _assetBloc.fetchAssets();
    resetLoadStatus();

    int? shiftId = await UserDbHelper().getUserShiftId();
    if (!mounted) return;

    if (shiftId != null && loginResponse.shiftId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const POSHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ShiftOpenCloseBalanceScreen(),
          settings: const RouteSettings(arguments: TextConstants.loginScreen),
        ),
      );
    }
  }

  void _onLoginError(String errorMsg) {
    _clearPassword();
    setState(() {
      _errorMessage = errorMsg;
    });

    var logoutBloc = LogoutBloc(LogoutRepository());
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) {
                        final dialogNavigator = Navigator.of(dialogContext);
                        logoutBloc.logoutStream.listen((response) {
                          if (response.status == Status.COMPLETED) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    response.message ?? TextConstants.successfullyLogout),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            dialogNavigator.pop();
                          } else if (response.status == Status.ERROR) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    response.message ?? TextConstants.failedToLogout),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            dialogNavigator.pop();
                          }
                        });

                        final pin = _password.join();
                        logoutBloc.performLogoutByEmpPin(int.tryParse(pin));

                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    );
                  },
                  child: const Text(
                    TextConstants.logoutText,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A122D),
      body: StreamBuilder<APIResponse<LoginResponse>>(
        stream: _bloc.loginStream,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.hasData && snapshot.data?.status == Status.LOADING;

          if (snapshot.hasData) {
            final response = snapshot.data!;
            if (response.status == Status.COMPLETED &&
                response.data?.token != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onLoginSuccess(response.data!);
              });
            } else if (response.status == Status.ERROR) {
              if (!_hasErrorShown) {
                _hasErrorShown = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onLoginError(
                      response.message ?? TextConstants.failedToLogin);
                });
              }
            }
          }

          return _buildMobileLoginView(context, isLoading);
        },
      ),
    );
  }

  Widget _buildMobileLoginView(BuildContext context, bool isLoading) {
    return Stack(
      children: [
        // Background Curved Red Accent Lines
        Positioned.fill(
          child: CustomPaint(
            painter: RedCurvesPainter(),
          ),
        ),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // App Logo
                    SvgPicture.asset(
                      'assets/svg/app_logo.svg',
                      height: 95,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      "POS  •  RETAIL  •  RESTAURANT",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // "Enter PIN" Label
                    const Text(
                      "Enter PIN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 6 PIN Dots (Circles)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = _password[index].isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? Colors.white : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? Colors.white : Colors.white54,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Error message banner or Loading Spinner
                    SizedBox(
                      height: 40,
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : (_errorMessage != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : null),
                    ),

                    const SizedBox(height: 8),

                    // 3x4 Keypad
                    _buildMobileNumPad(isLoading),

                    const SizedBox(height: 32),

                    // Version Footer
                    const Text(
                      "v1.0.0",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileNumPad(bool isLoading) {
    final keys = [
      ["1", "2", "3"],
      ["4", "5", "6"],
      ["7", "8", "9"],
      ["C", "0", "DEL"],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key == "C") {
                return Expanded(
                  child: _buildMobileKeyButton(
                    child: const Text(
                      "C",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: isLoading ? null : _clearPassword,
                  ),
                );
              } else if (key == "DEL") {
                return Expanded(
                  child: _buildMobileKeyButton(
                    child: const Icon(
                      Icons.backspace_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onTap: isLoading ? null : _deletePassword,
                  ),
                );
              } else {
                return Expanded(
                  child: _buildMobileKeyButton(
                    child: Text(
                      key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: isLoading ? null : () => _updatePassword(key),
                  ),
                );
              }
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileKeyButton({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Material(
        color: const Color(0xFF1E2A4A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class RedCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paint2 = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top Right Arc Swoosh
    final pathTop1 = Path();
    pathTop1.moveTo(size.width * 0.35, 0);
    pathTop1.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.04,
      size.width,
      size.height * 0.18,
    );
    canvas.drawPath(pathTop1, paint1);

    final pathTop2 = Path();
    pathTop2.moveTo(size.width * 0.55, 0);
    pathTop2.quadraticBezierTo(
      size.width * 0.95,
      size.height * 0.02,
      size.width,
      size.height * 0.1,
    );
    canvas.drawPath(pathTop2, paint2);

    // Bottom Left Arc Swoosh
    final pathBottom1 = Path();
    pathBottom1.moveTo(0, size.height * 0.84);
    pathBottom1.quadraticBezierTo(
      size.width * 0.12,
      size.height * 0.94,
      size.width * 0.55,
      size.height,
    );
    canvas.drawPath(pathBottom1, paint1);

    final pathBottom2 = Path();
    pathBottom2.moveTo(0, size.height * 0.9);
    pathBottom2.quadraticBezierTo(
      size.width * 0.06,
      size.height * 0.97,
      size.width * 0.38,
      size.height,
    );
    canvas.drawPath(pathBottom2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}