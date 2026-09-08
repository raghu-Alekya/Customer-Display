import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:pinaka_pos/Screens/Auth/store_id_screen.dart';

import '../../Widgets/widget_custom_num_pad.dart';
import '../../core/api/auth_bloc.dart';
import '../../core/api/models/auth_state.dart';
import '../../core/api/pch_service_locator.dart';

class DeviceAuthorizationScreen extends StatefulWidget {
  const DeviceAuthorizationScreen({super.key});

  @override
  State<DeviceAuthorizationScreen> createState() =>
      _DeviceAuthorizationScreenState();
}

class _DeviceAuthorizationScreenState extends State<DeviceAuthorizationScreen> {
  final List<String> _pin = List.filled(6, "");
  final TextEditingController _pinController = TextEditingController();

  AuthBloc? _authBloc;
  String _deviceFingerprint = '';
  String _appVersion = '2.5.0';
  String _platform = 'UNKNOWN';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _authBloc = PchServiceLocator.createAuthBloc();
    _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    _deviceFingerprint = await DeviceHelper.getDeviceId();
    _platform = DeviceHelper.getPlatformName().toUpperCase();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      _appVersion = '2.5.0';
    }

    if (!mounted) return;
    setState(() {});

    _authBloc!.stateStream.listen((state) {
      if (state is DeviceActivated) {
        _goToLogin();
      }
    });
  }

  void _goToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StoreIdScreen()),
      );
    });
  }

  void _updatePin(String value) {
    for (int i = 0; i < _pin.length; i++) {
      if (_pin[i].isEmpty) {
        setState(() => _pin[i] = value);
        break;
      }
    }
  }

  void _deletePin() {
    for (int i = _pin.length - 1; i >= 0; i--) {
      if (_pin[i].isNotEmpty) {
        setState(() => _pin[i] = "");
        break;
      }
    }
  }

  void _clearPin() {
    setState(() {
      for (int i = 0; i < _pin.length; i++) {
        _pin[i] = "";
      }
      _pinController.clear();
    });
  }

  bool _validatePin() {
    if (_pin.any((digit) => digit.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter 6-digit Activation Code',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_validatePin()) return;
    if (_deviceFingerprint.isEmpty) {
      _deviceFingerprint = await DeviceHelper.getDeviceId();
    }

    final activationCode = _pin.join();

    if (kDebugMode) {
      print('📱 Device Authorization Payload:');
      print({
        'activationCode': activationCode,
        'deviceFingerprint': _deviceFingerprint,
        'appVersion': _appVersion,
        'platform': _platform,
      });
    }

    await _authBloc!.activateDevice(
      activationCode: activationCode,
      deviceFingerprint: _deviceFingerprint,
      appVersion: _appVersion,
      platform: _platform,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      body: _authBloc == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<AuthState>(
        stream: _authBloc!.stateStream,
        initialData: _authBloc!.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final isLoading = state is Authenticating;
          final errorText =
              state is AuthenticationFailed ? state.message : null;

          return Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: const Color(0xFF1E2745),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/svg/app_logo.svg',
                      height: 150,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  color: const Color(0xFFE0E0E0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Device Authorization',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2745),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter 6-digit Activation Code',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (_deviceFingerprint.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Device ID: $_deviceFingerprint',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 28),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              enabled: !isLoading,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 12,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  letterSpacing: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1E2745),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final digits =
                                    value.padRight(6, '').split('');
                                setState(() {
                                  for (int i = 0; i < 6; i++) {
                                    _pin[i] =
                                        i < digits.length ? digits[i] : '';
                                  }
                                });
                              },
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                errorText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          CustomNumPad(
                            numPadType: NumPadType.login,
                            onDigitPressed: (digit) {
                              if (isLoading) return;
                              if (_pinController.text.length < 6) {
                                _pinController.text += digit;
                                _updatePin(digit);
                              }
                            },
                            onClearPressed: isLoading ? () {} : _clearPin,
                            onDeletePressed: () {
                              if (isLoading) return;
                              if (_pinController.text.isNotEmpty) {
                                _pinController.text = _pinController.text
                                    .substring(
                                        0, _pinController.text.length - 1);
                                _deletePin();
                              }
                            },
                            actionButtonType: ActionButtonType.delete,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: MediaQuery.of(context).size.width /
                                (isPortrait ? 7.3 : 7.2),
                            height: MediaQuery.of(context).size.height /
                                (isPortrait ? 20.0 : 10.0),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2745),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Authorize Device',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            child: const Text(
                              '← Back to Login',
                              style: TextStyle(
                                color: Color(0xFF1E2745),
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _authBloc?.dispose();
    super.dispose();
  }
}
