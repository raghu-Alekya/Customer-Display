import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Helper/url_helper.dart';
import 'package:pinaka_pos/Repositories/Auth/AuthIdsStore.dart';
import 'package:pinaka_pos/Screens/Auth/store_id_screen.dart';

class DeviceActivationScreen extends StatefulWidget {
  const DeviceActivationScreen({super.key});

  @override
  State<DeviceActivationScreen> createState() => _DeviceActivationScreenState();
}

// Retain alias for backward compatibility with existing imports
typedef DeviceAuthorizationScreen = DeviceActivationScreen;

class _DeviceActivationScreenState extends State<DeviceActivationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _activationCodeController =
      TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingDetails();
  }

  Future<void> _loadExistingDetails() async {
    try {
      final savedCode = await AuthIdsStore.getDeviceActivationCode();
      final savedSerial = await AuthIdsStore.getDeviceSerialNumber();

      if (savedCode.isNotEmpty) {
        _activationCodeController.text = savedCode;
      }

      if (savedSerial.isNotEmpty) {
        _serialNumberController.text = savedSerial;
      } else {
        // Auto-suggest device id as default serial number
        final deviceId = await DeviceHelper.getDeviceId();
        if (deviceId.isNotEmpty && mounted) {
          _serialNumberController.text = deviceId;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('[DeviceActivation] Error loading existing details: $e');
      }
    }
  }

  Future<void> _handleSaveAndContinue() async {
    FocusScope.of(context).unfocus();

    final activationCode = _activationCodeController.text.trim();
    final serialNumber = _serialNumberController.text.trim();

    if (activationCode.isEmpty) {
      _showToast('Please enter the Activation Code', isError: true);
      return;
    }

    if (serialNumber.isEmpty) {
      _showToast('Please enter the Serial Number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // POST https://pch.alektasolutions.com/connector/api/v1/device-activation/activate
      final endpoint = '${UrlHelper.baseUrl}device-activation/activate';
      final payload = {
        'activationCode': activationCode,
        'serialNumber': serialNumber,
      };

      if (kDebugMode) {
        print('📱 [DeviceActivation] Calling API: $endpoint');
        print('📱 [DeviceActivation] Payload: $payload');
      }

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (kDebugMode) {
        print('📱 [DeviceActivation] Status: ${response.statusCode}');
        print('📱 [DeviceActivation] Response Body: ${response.body}');
      }

      Map<String, dynamic> responseData = {};
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final bool isSuccess = (response.statusCode >= 200 &&
              response.statusCode < 300) &&
          (responseData['success'] == true || responseData['data'] != null);

      final String message = (responseData['message'] ??
              (isSuccess
                  ? 'This device is already activated'
                  : 'Device activation failed'))
          .toString();

      if (isSuccess) {
        // Save activation information to preferences
        final data = responseData['data'] is Map<String, dynamic>
            ? responseData['data'] as Map<String, dynamic>
            : (responseData['data'] is Map
                ? Map<String, dynamic>.from(responseData['data'])
                : null);

        await AuthIdsStore.saveDeviceActivation(
          activationCode: activationCode,
          serialNumber: serialNumber,
          data: data,
        );

        if (!mounted) return;

        // Show snackbar message returned from server (e.g. "This device is already activated")
        _showToast(message, isError: false);

        // Navigate to Merchant Login (StoreIdScreen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StoreIdScreen()),
        );
      } else {
        final err = responseData['message'] ??
            responseData['error'] ??
            'Activation failed. Please verify activation code and serial number.';
        setState(() {
          _errorMessage = err.toString();
        });
        _showToast(err.toString(), isError: true);
      }
    } on SocketException catch (_) {
      const err = 'No internet connection. Please connect and try again.';
      setState(() => _errorMessage = err);
      _showToast(err, isError: true);
    } catch (e) {
      final err = 'Activation error: $e';
      setState(() => _errorMessage = err);
      _showToast(err, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF1E2745),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _goToMerchantLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StoreIdScreen()),
    );
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      body: Row(
        children: [
          // Left side branding (matches Employee PIN screen)
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF1E2745),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/svg/app_logo.svg',
                      height: 150,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Retail POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Device Activation & Authorization',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right side form (matches Employee PIN screen layout)
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFE0E0E0),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPortrait ? 24 : 48,
                  vertical: 24,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Device Activation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2745),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your activation code and device serial number',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Activation Code Field
                            const Text(
                              'Activation Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E2745),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _activationCodeController,
                              textCapitalization: TextCapitalization.characters,
                              enabled: !_isLoading,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E2745),
                                letterSpacing: 1.0,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. PK-643015',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                  letterSpacing: 0,
                                ),
                                prefixIcon: const Icon(
                                  Icons.vpn_key_outlined,
                                  color: Color(0xFF1E2745),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
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
                            ),

                            const SizedBox(height: 20),

                            // Serial Number Field
                            const Text(
                              'Serial Number',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E2745),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _serialNumberController,
                              enabled: !_isLoading,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E2745),
                                letterSpacing: 0.8,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. TEST00001234',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                  letterSpacing: 0,
                                ),
                                prefixIcon: const Icon(
                                  Icons.devices_outlined,
                                  color: Color(0xFF1E2745),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
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
                            ),

                            if (_errorMessage != null &&
                                _errorMessage!.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Save and Continue Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _handleSaveAndContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E2745),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Save and Continue',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Skip to Merchant Login
                            TextButton(
                              onPressed: _isLoading ? null : _goToMerchantLogin,
                              child: const Text(
                                'Skip to Merchant Login →',
                                style: TextStyle(
                                  color: Color(0xFF1E2745),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
