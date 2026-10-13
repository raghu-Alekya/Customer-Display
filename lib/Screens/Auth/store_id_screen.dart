<<<<<<< HEAD
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../../Blocs/Auth/login_bloc.dart';
import '../../Blocs/Auth/store_validation_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
=======
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../Repositories/Auth/AuthIdsStore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:provider/provider.dart';

import '../../Blocs/Auth/store_validation_bloc.dart';
>>>>>>> origin/Grocery_pch_api_integration
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
<<<<<<< HEAD
import '../../Models/Auth/login_model.dart';
import '../../Models/Auth/store_validation_model.dart';
import '../../Repositories/Auth/login_repository.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_loading.dart';
import '../Home/fast_key_screen.dart';
import '../../Widgets/widget_error.dart';

class StoreIdScreen extends StatefulWidget { // Build #1.0.16
  const StoreIdScreen({super.key});

  @override
  _StoreIdScreenState createState() => _StoreIdScreenState();
=======
import '../../Models/Auth/store_validation_model.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../Home/pos_home_screen.dart';

class DeviceHelper {
  /// Returns a non-empty device id for Android / iOS / Windows / macOS / Linux / Web.
  /// Also prints platform + device type to console.
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      // ---------- WEB ----------
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        final id =
        '${webInfo.vendor ?? 'web'}_${webInfo.userAgent ?? 'browser'}_${webInfo.platform ?? 'unknown'}'
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '');
        final shortId = id.length > 80 ? id.substring(0, 80) : id;

        if (kDebugMode) {
          print('🌐 Platform: Web');
          print('🌐 Browser: ${webInfo.browserName}');
          print('🌐 Device ID: $shortId');
        }
        return shortId.isNotEmpty ? shortId : 'web_device';
      }

      // ---------- ANDROID ----------
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final id = androidInfo.id.isNotEmpty
            ? androidInfo.id
            : (androidInfo.fingerprint.isNotEmpty
            ? androidInfo.fingerprint
            : 'android_${androidInfo.model}');

        if (kDebugMode) {
          print('🤖 Platform: Android');
          print('🤖 Model: ${androidInfo.model}');
          print('🤖 Manufacturer: ${androidInfo.manufacturer}');
          print('🤖 Device ID: $id');
        }
        return id;
      }

      // ---------- iOS ----------
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final id = iosInfo.identifierForVendor ??
            'ios_${iosInfo.name}_${iosInfo.model}';

        if (kDebugMode) {
          print('🍎 Platform: iOS');
          print('🍎 Name: ${iosInfo.name}');
          print('🍎 Model: ${iosInfo.model}');
          print('🍎 Device ID: $id');
        }
        return id.isNotEmpty ? id : 'ios_device';
      }

      // ---------- WINDOWS ----------
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        final computerName = windowsInfo.computerName;
        final deviceId = windowsInfo.deviceId;
        final productId = windowsInfo.productId;
        final id = [
          if (deviceId.isNotEmpty) deviceId,
          if (computerName.isNotEmpty) computerName,
          if (productId.isNotEmpty) productId,
        ].join('_');

        final finalId = id.isNotEmpty
            ? id
            : 'windows_${windowsInfo.numberOfCores}_${windowsInfo.systemMemoryInMegabytes}';

        if (kDebugMode) {
          print('🪟 Platform: Windows');
          print('🪟 Computer Name: $computerName');
          print('🪟 Device ID (raw): $deviceId');
          print('🪟 Product ID: $productId');
          print('🪟 Device ID (sent): $finalId');
        }
        return finalId;
      }

      // ---------- macOS ----------
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        final id = macInfo.systemGUID ??
            '${macInfo.computerName}_${macInfo.model}';

        if (kDebugMode) {
          print('💻 Platform: macOS');
          print('💻 Computer Name: ${macInfo.computerName}');
          print('💻 Model: ${macInfo.model}');
          print('💻 System GUID: ${macInfo.systemGUID}');
          print('💻 Device ID: $id');
        }
        return id.isNotEmpty ? id : 'macos_device';
      }

      // ---------- LINUX ----------
      if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        final id = linuxInfo.machineId ??
            '${linuxInfo.name}_${linuxInfo.version ?? 'linux'}';

        if (kDebugMode) {
          print('🐧 Platform: Linux');
          print('🐧 Name: ${linuxInfo.name}');
          print('🐧 Version: ${linuxInfo.version}');
          print('🐧 Machine ID: ${linuxInfo.machineId}');
          print('🐧 Device ID: $id');
        }
        return id.isNotEmpty ? id : 'linux_device';
      }

      // ---------- FALLBACK ----------
      final fallback =
          'device_${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        print('❓ Platform: Unknown → Fallback Device ID: $fallback');
      }
      return fallback;
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ DeviceHelper.getDeviceId error: $e');
        print(stack);
      }
      final fallback =
          'device_${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        print('❓ Error Fallback Device ID: $fallback');
      }
      return fallback;
    }
  }

  static String getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}

class StoreIdScreen extends StatefulWidget {
  const StoreIdScreen({super.key});

  @override
  State<StoreIdScreen> createState() => _StoreIdScreenState();
>>>>>>> origin/Grocery_pch_api_integration
}

class _StoreIdScreenState extends State<StoreIdScreen> {
  late StoreValidationBloc _bloc;
<<<<<<< HEAD
  final UserDbHelper _userDbHelper = UserDbHelper();
  final TextEditingController _storeIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _lastErrorMessage;
  bool _isPasswordVisible = false; // Added for password visibility toggle

=======

  final UserDbHelper _userDbHelper = UserDbHelper();

  final TextEditingController _storeIdController =
  TextEditingController();

  final TextEditingController _usernameController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isNavigating = false;

  String? _lastErrorMessage;
>>>>>>> origin/Grocery_pch_api_integration

  @override
  void initState() {
    super.initState();
    _bloc = StoreValidationBloc(StoreValidationRepository());
<<<<<<< HEAD
    //  _checkExistingUser(); // Un comment this line if auto login needed
=======

    // _checkExistingUser();
>>>>>>> origin/Grocery_pch_api_integration
  }

  @override
  void dispose() {
    _bloc.dispose();
<<<<<<< HEAD
    _storeIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleValidation() {  //Build #1.0.42: Updated code
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _lastErrorMessage = null; // Reset last error message
      });
      _bloc.validateStore(
        username: _usernameController.text,
        password: _passwordController.text,
        storeId: _storeIdController.text,
=======

    _storeIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // Future<void> _handleValidation() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //       _lastErrorMessage = null;
  //     });
  //
  //     final deviceId = await DeviceHelper.getDeviceId();
  //
  //     _bloc.validateStore(
  //       username: _usernameController.text.trim(),
  //       password: _passwordController.text.trim(),
  //       storeId: _storeIdController.text.trim(),
  //       deviceId: deviceId,
  //     );
  //   }
  // }

  Future<void> _handleValidation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _lastErrorMessage = null;
      });

      final deviceId = await DeviceHelper.getDeviceId();

      // Never send empty device_id
      final safeDeviceId = (deviceId.trim().isEmpty)
          ? 'device_${DateTime.now().millisecondsSinceEpoch}'
          : deviceId.trim();

      if (kDebugMode) {
        print('📤 Platform: ${DeviceHelper.getPlatformName()}');
        print('📤 device_id: $safeDeviceId');
      }

      _bloc.validateStore(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        storeId: _storeIdController.text.trim(),
        deviceId: safeDeviceId,
>>>>>>> origin/Grocery_pch_api_integration
      );
    }
  }

  Future<void> _checkExistingUser() async {
    bool isLoggedIn = await _userDbHelper.isUserLoggedIn();
<<<<<<< HEAD
    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FastKeyScreen()),
=======

    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const POSHomeScreen(),
        ),
>>>>>>> origin/Grocery_pch_api_integration
      );
    }
  }

<<<<<<< HEAD
  // Toggle password visibility
=======
>>>>>>> origin/Grocery_pch_api_integration
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

<<<<<<< HEAD
  // void _updatePassword(String value) {
  //   for (int i = 0; i < _password.length; i++) {
  //     if (_password[i].isEmpty) {
  //       setState(() {
  //         _password[i] = value;
  //       });
  //       if (kDebugMode) {
  //         print("Password updated: $_password");
  //       }
  //
  //       // Auto-submit when 6 digits are entered
  //       // if (i == 5) {
  //       //   _handleLogin();
  //       // }
  //       break;
  //     }
  //   }
  // }
  //
  // void _deletePassword() {
  //   for (int i = _password.length - 1; i >= 0; i--) {
  //     if (_password[i].isNotEmpty) {
  //       setState(() {
  //         _password[i] = "";
  //       });
  //       if (kDebugMode) {
  //         print("Password deleted: $_password");
  //       }
  //       break;
  //     }
  //   }
  // }
  //
  // // Clear all fields with animation by resetting them one by one
  // void _clearPassword() {
  //   setState(() {
  //     // Clear the fields one by one to trigger the animation on each field
  //     for (int i = 0; i < _password.length; i++) {
  //       _password[i] = ""; // Reset each field with animation
  //     }
  //   });
  //   if (kDebugMode) {
  //     print("Password cleared: $_password");
  //   }
  // }
  //
  // bool _validatePin() { // Build #1.0.13
  //   if (_password.any((digit) => digit.isEmpty)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please enter 6-digit PIN',
  //         style: TextStyle(color: Colors.red),
  //       ),),
  //     );
  //     return false;
  //   }
  //   return true;
  // }
  //
  // void _handleLogin() {
  //   if (!_validatePin()) return;
  //
  //   final pin = _password.join();
  //   _bloc.fetchLoginToken(LoginRequest(pin));
  // }

  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final themeHelper = Provider.of<ThemeNotifier>(context);
=======
  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation ==
            Orientation.portrait;

    final themeHelper =
    Provider.of<ThemeNotifier>(context);
>>>>>>> origin/Grocery_pch_api_integration

    return Scaffold(
      body: Row(
        children: [
<<<<<<< HEAD
          // Left Side - Logo Section (unchanged)
=======

          /// LEFT SIDE
>>>>>>> origin/Grocery_pch_api_integration
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

<<<<<<< HEAD
          // Right Side - Validation Interface
          Expanded(
            flex: 1,
            child: Padding(  //Build #1.0.42: Updated UI
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: StreamBuilder<APIResponse<StoreValidationResponse>>(
                stream: _bloc.validationStream,
                builder: (context, snapshot) {
                  // In _StoreIdScreenState.build, inside StreamBuilder
                  if (snapshot.hasData) {
                    final response = snapshot.data!;
                    if (response.status == Status.COMPLETED) {
                      if (response.data!.success) {
                        // Save validation data and navigate
                        StoreDbHelper.instance.saveStoreValidationData(response.data!).then((_) {  //Build #1.0.126: updated to StoreDbHelper
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        });
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _isLoading = false; // Stop loader
                          });
                          if (_lastErrorMessage != response.data!.message) {
                            _lastErrorMessage = response.data!.message;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(response.data!.message ?? 'Validation failed',  style: TextStyle(color: Colors.red))),
=======
          /// RIGHT SIDE
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: StreamBuilder<
                  APIResponse<StoreValidationResponse>>(
                stream: _bloc.validationStream,
                builder: (context, snapshot) {

                  /// HANDLE RESPONSE
                  if (snapshot.hasData) {
                    final response = snapshot.data!;

                    /// SUCCESS
                    if (response.status ==
                        Status.COMPLETED) {

                      if (response.data?.success == true) {

                        final store = response.data!;

                        /// PREVENT MULTIPLE NAVIGATION
                        if (!_isNavigating) {
                          _isNavigating = true;

                          WidgetsBinding.instance
                              .addPostFrameCallback((_) async {

                            /// SAVE STORE DATA
                            await StoreDbHelper.instance
                                .saveStoreValidationData(
                                store);

                            // Always persist merchant/store IDs (SharedPreferences)
                            // so next app open skips merchant login → employee PIN.
                            // Fall back to form fields if API omits ids.
                            final mid = store.merchantId.trim().isNotEmpty
                                ? store.merchantId.trim()
                                : _usernameController.text.trim();
                            final sid = store.storeId.trim().isNotEmpty
                                ? store.storeId.trim()
                                : _storeIdController.text.trim();
                            if (mid.isNotEmpty && sid.isNotEmpty) {
                              await AuthIdsStore.save(
                                merchantId: mid,
                                storeId: sid,
                              );
                              debugPrint(
                                  '[StoreLogin] Saved AuthIdsStore merchant=$mid store=$sid');
                            } else {
                              debugPrint(
                                  '[StoreLogin] WARNING: could not save AuthIds (merchant or store empty)');
                            }

                            if (!mounted) return;

                            setState(() {
                              _isLoading = false;
                            });

                            /// NAVIGATE
                            Navigator.of(context)
                                .pushReplacement(
                              MaterialPageRoute(
                                builder: (context) =>
                                const LoginScreen(),
                              ),
                            );
                          });
                        }

                      } else {

                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {

                          if (!mounted) return;

                          setState(() {
                            _isLoading = false;
                          });

                          if (_lastErrorMessage !=
                              response.data?.message) {

                            _lastErrorMessage =
                                response.data?.message;

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  response.data?.message ??
                                      'Validation failed',
                                  style: const TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
>>>>>>> origin/Grocery_pch_api_integration
                            );
                          }
                        });
                      }
<<<<<<< HEAD
                    } else if (response.status == Status.ERROR) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _isLoading = false; // Stop loader
                        });
                        if (_lastErrorMessage != response.message) {
                          _lastErrorMessage = response.message;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response.message ?? 'Validation failed', style: TextStyle(color: Colors.red),)),
=======
                    }

                    /// ERROR
                    else if (response.status ==
                        Status.ERROR) {

                      WidgetsBinding.instance
                          .addPostFrameCallback((_) {

                        if (!mounted) return;

                        setState(() {
                          _isLoading = false;
                        });

                        if (_lastErrorMessage !=
                            response.message) {

                          _lastErrorMessage =
                              response.message;

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                response.message ??
                                    'Validation failed',
                                style: const TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ),
>>>>>>> origin/Grocery_pch_api_integration
                          );
                        }
                      });
                    }
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
<<<<<<< HEAD
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Inside the Form widget's Column children in StoreIdScreen
=======
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      crossAxisAlignment:
                      CrossAxisAlignment.center,
                      children: [

>>>>>>> origin/Grocery_pch_api_integration
                        const Text(
                          'Enter Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
<<<<<<< HEAD
                        const SizedBox(height: 10),
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context).size.width / 2.5
                              : MediaQuery.of(context).size.width / 3,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300),
                          ),
                          child: TextFormField(
                            keyboardType: TextInputType.emailAddress,
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Username',
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 1.0,
                                  style: BorderStyle.none,
                                ),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter a Username';
=======

                        const SizedBox(height: 10),

                        /// USERNAME
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context)
                              .size
                              .width / 2.5
                              : MediaQuery.of(context)
                              .size
                              .width / 3,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),

                          decoration: BoxDecoration(
                            color: themeHelper.themeMode ==
                                ThemeMode.dark
                                ? ThemeNotifier
                                .paymentEntryContainerColor
                                : Colors.white,

                            borderRadius:
                            BorderRadius.circular(12),

                            border: Border.all(
                              color: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? ThemeNotifier
                                  .borderColor
                                  : Colors.grey.shade300,
                            ),
                          ),

                          child: TextFormField(
                            controller:
                            _usernameController,

                            keyboardType:
                            TextInputType.emailAddress,

                            decoration:
                            const InputDecoration(
                              hintText: 'Username',
                              border: InputBorder.none,
                            ),

                            textAlign:
                            TextAlign.center,

                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Enter Username';
>>>>>>> origin/Grocery_pch_api_integration
                              }
                              return null;
                            },
                          ),
                        ),
<<<<<<< HEAD
                        const SizedBox(height: 10),
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context).size.width / 2.5
                              : MediaQuery.of(context).size.width / 3,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300),
                          ),
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextFormField(
                                controller: _passwordController,
                                keyboardType: TextInputType.text,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  hintText: 'Password',
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 1.0,
                                      style: BorderStyle.none,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 1.0,
                                      style: BorderStyle.none,
                                    ),
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                obscureText: !_isPasswordVisible,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter a Password';
=======

                        const SizedBox(height: 10),

                        /// PASSWORD
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context)
                              .size
                              .width / 2.5
                              : MediaQuery.of(context)
                              .size
                              .width / 3,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),

                          decoration: BoxDecoration(
                            color: themeHelper.themeMode ==
                                ThemeMode.dark
                                ? ThemeNotifier
                                .paymentEntryContainerColor
                                : Colors.white,

                            borderRadius:
                            BorderRadius.circular(12),

                            border: Border.all(
                              color: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? ThemeNotifier
                                  .borderColor
                                  : Colors.grey.shade300,
                            ),
                          ),

                          child: Stack(
                            alignment:
                            Alignment.centerRight,
                            children: [

                              TextFormField(
                                controller:
                                _passwordController,

                                obscureText:
                                !_isPasswordVisible,

                                decoration:
                                const InputDecoration(
                                  hintText: 'Password',
                                  border:
                                  InputBorder.none,
                                ),

                                textAlign:
                                TextAlign.center,

                                validator: (value) {
                                  if (value == null ||
                                      value.isEmpty) {
                                    return 'Enter Password';
>>>>>>> origin/Grocery_pch_api_integration
                                  }
                                  return null;
                                },
                              ),
<<<<<<< HEAD
                              // Position the icon separately using Stack
                              Positioned(
                                right: 8,
                                child: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
=======

                              IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons
                                      .visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed:
                                _togglePasswordVisibility,
>>>>>>> origin/Grocery_pch_api_integration
                              ),
                            ],
                          ),
                        ),
<<<<<<< HEAD
                        const SizedBox(height: 10),
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context).size.width / 2.5
                              : MediaQuery.of(context).size.width / 3,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.paymentEntryContainerColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.borderColor : Colors.grey.shade300),
                          ),
                          child: TextFormField(
                            keyboardType: TextInputType.text,
                            controller: _storeIdController,
                            decoration: const InputDecoration(
                              hintText: 'Store ID',
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 1.0,
                                  style: BorderStyle.none,
                                ),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter a Store ID';
=======

                        const SizedBox(height: 10),

                        /// STORE ID
                        Container(
                          width: isPortrait
                              ? MediaQuery.of(context)
                              .size
                              .width / 2.5
                              : MediaQuery.of(context)
                              .size
                              .width / 3,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),

                          decoration: BoxDecoration(
                            color: themeHelper.themeMode ==
                                ThemeMode.dark
                                ? ThemeNotifier
                                .paymentEntryContainerColor
                                : Colors.white,

                            borderRadius:
                            BorderRadius.circular(12),

                            border: Border.all(
                              color: themeHelper.themeMode ==
                                  ThemeMode.dark
                                  ? ThemeNotifier
                                  .borderColor
                                  : Colors.grey.shade300,
                            ),
                          ),

                          child: TextFormField(
                            controller:
                            _storeIdController,

                            decoration:
                            const InputDecoration(
                              hintText: 'Store ID',
                              border: InputBorder.none,
                            ),

                            textAlign:
                            TextAlign.center,

                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Enter Store ID';
>>>>>>> origin/Grocery_pch_api_integration
                              }
                              return null;
                            },
                          ),
                        ),
<<<<<<< HEAD
                        const SizedBox(height: 15),
                        // Update ElevatedButton
                        SizedBox(
                          width: isPortrait
                              ? MediaQuery.of(context).size.width / 4
                              : MediaQuery.of(context).size.width / 3,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleValidation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2745),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: const Color(0xFF1E2745), // Maintain color when disabled
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Submit'),
                          ),
                        )
=======

                        const SizedBox(height: 15),

                        /// BUTTON
                        SizedBox(
                          width: isPortrait
                              ? MediaQuery.of(context)
                              .size
                              .width / 4
                              : MediaQuery.of(context)
                              .size
                              .width / 3,

                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _handleValidation,

                            style:
                            ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF1E2745),

                              foregroundColor:
                              Colors.white,

                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 12,
                              ),

                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),

                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text('Submit'),
                          ),
                        ),
>>>>>>> origin/Grocery_pch_api_integration
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
<<<<<<< HEAD
=======

>>>>>>> origin/Grocery_pch_api_integration
