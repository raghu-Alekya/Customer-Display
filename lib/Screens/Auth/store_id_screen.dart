import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:provider/provider.dart';

import '../../Blocs/Auth/store_validation_bloc.dart';
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/store_validation_model.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../Home/pos_home_screen.dart';

class DeviceHelper {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;

      if (kDebugMode) {
        print("Android Device ID: ${androidInfo.id}");
      }

      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;

      if (kDebugMode) {
        print("iOS Device ID: ${iosInfo.identifierForVendor}");
      }

      return iosInfo.identifierForVendor ?? "unknown_ios";
    }

    if (kDebugMode) {
      print("Unknown Device Platform");
    }

    return "unknown_device";
  }
}

class StoreIdScreen extends StatefulWidget {
  const StoreIdScreen({super.key});

  @override
  State<StoreIdScreen> createState() => _StoreIdScreenState();
}

class _StoreIdScreenState extends State<StoreIdScreen> {
  late StoreValidationBloc _bloc;

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

  @override
  void initState() {
    super.initState();
    _bloc = StoreValidationBloc(StoreValidationRepository());

    // _checkExistingUser();
  }

  @override
  void dispose() {
    _bloc.dispose();

    _storeIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _handleValidation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _lastErrorMessage = null;
      });

      final deviceId = await DeviceHelper.getDeviceId();

      _bloc.validateStore(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        storeId: _storeIdController.text.trim(),
        deviceId: deviceId,
      );
    }
  }

  Future<void> _checkExistingUser() async {
    bool isLoggedIn = await _userDbHelper.isUserLoggedIn();

    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const POSHomeScreen(),
        ),
      );
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation ==
            Orientation.portrait;

    final themeHelper =
    Provider.of<ThemeNotifier>(context);

    return Scaffold(
      body: Row(
        children: [

          /// LEFT SIDE
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
                            );
                          }
                        });
                      }
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
                          );
                        }
                      });
                    }
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      crossAxisAlignment:
                      CrossAxisAlignment.center,
                      children: [

                        const Text(
                          'Enter Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

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
                              }
                              return null;
                            },
                          ),
                        ),

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
                                  }
                                  return null;
                                },
                              ),

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
                              ),
                            ],
                          ),
                        ),

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
                              }
                              return null;
                            },
                          ),
                        ),

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