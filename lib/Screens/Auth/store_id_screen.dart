import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Screens/Auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../../Blocs/Auth/login_bloc.dart';
import '../../Blocs/Auth/store_validation_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/store_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/login_model.dart';
import '../../Models/Auth/store_validation_model.dart';
import '../../Repositories/Auth/login_repository.dart';
import '../../Repositories/Auth/store_validation_repository.dart';
import '../../Widgets/widget_custom_num_pad.dart';
import '../../Widgets/widget_loading.dart';
import '../../services/customer_services.dart';
import '../Home/pos_home_screen.dart';
import '../../Widgets/widget_error.dart';

class StoreIdScreen extends StatefulWidget { // Build #1.0.16
  const StoreIdScreen({super.key});

  @override
  _StoreIdScreenState createState() => _StoreIdScreenState();
}

class _StoreIdScreenState extends State<StoreIdScreen> {
  late StoreValidationBloc _bloc;
  final UserDbHelper _userDbHelper = UserDbHelper();
  final TextEditingController _storeIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _lastErrorMessage;
  bool _isPasswordVisible = false; // Added for password visibility toggle


  @override
  void initState() {
    super.initState();
    _bloc = StoreValidationBloc(StoreValidationRepository());
    //  _checkExistingUser(); // Un comment this line if auto login needed
  }

  @override
  void dispose() {
    _bloc.dispose();
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
      );
    }
  }

  Future<void> _checkExistingUser() async {
    bool isLoggedIn = await _userDbHelper.isUserLoggedIn();
    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const POSHomeScreen()),
      );
    }
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

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

    return Scaffold(
      body: Row(
        children: [
          // Left Side - Logo Section (unchanged)
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
                        final store = response.data!; // StoreValidationResponse

                        // Run async side‑effects after this frame
                        Future.microtask(() async {
                          // 1) send store info to customer display
                          await CustomerService.publishStoreInfo(
                            storeId: int.tryParse(store.storeId ?? '0') ?? 0,
                            storeName: store.storeName ?? 'Merchant',
                            logoUrl: store.storeLogo,                // <-- use correct field here
                          );


                          // 2) Save validation data and navigate
                          await StoreDbHelper.instance.saveStoreValidationData(store);
                          if (!mounted) return;
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
                            );
                          }
                        });
                      }
                    }
                    else if (response.status == Status.ERROR) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _isLoading = false; // Stop loader
                        });
                        if (_lastErrorMessage != response.message) {
                          _lastErrorMessage = response.message;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response.message ?? 'Validation failed', style: TextStyle(color: Colors.red),)),
                          );
                        }
                      });
                    }
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Inside the Form widget's Column children in StoreIdScreen
                        const Text(
                          'Enter Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              }
                              return null;
                            },
                          ),
                        ),
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
                                  }
                                  return null;
                                },
                              ),
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
                              ),
                            ],
                          ),
                        ),
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
                              }
                              return null;
                            },
                          ),
                        ),
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
