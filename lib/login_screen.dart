import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiosk/repository/login_repository.dart';
import 'package:kiosk/user_login.dart';

import '../splashscreen.dart';
import 'bloc/login_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController storeIdController = TextEditingController();

  bool isButtonEnabled = false;
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    usernameController.addListener(checkInput);
    passwordController.addListener(checkInput);
    storeIdController.addListener(checkInput);
  }

  void checkInput() {
    final isValid =
        usernameController.text.trim().isNotEmpty &&
            passwordController.text.trim().isNotEmpty &&
            storeIdController.text.trim().isNotEmpty;

    if (isValid != isButtonEnabled) {
      setState(() {
        isButtonEnabled = isValid;
      });
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    storeIdController.dispose();
    super.dispose();
  }

  // @override
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(LoginRepository()),
        child: Builder(
            builder: (context) {
              return BlocListener<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state is LoginLoading) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  else if (state is LoginSuccess) {
                    // ✅ Close loader safely
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }

                    // ✅ Navigate
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserLogin(),
                      ),
                    );
                  }

                  else if (state is LoginFailure) {
                    // ✅ Close loader safely
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error)),
                    );
                  }
                },

                child: Scaffold(
                  body: Stack(
                    children: [
                      // 🔵 Background
                      Container(
                        height: 420,
                        decoration: const BoxDecoration(
                          color: Color(0xFF24467A),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(80),
                            bottomRight: Radius.circular(80),
                          ),
                        ),
                      ),

                      Center(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 60),

                              const Text(
                                "Welcome Back !",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const Text(
                                "Admin",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 20,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // 🔹 Login Card
                              Container(
                                width: 420,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12, blurRadius: 10),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    const Text(
                                      "Login into your Account",
                                      style: TextStyle(color: Colors.grey),
                                    ),

                                    const SizedBox(height: 20),

                                    // 🔹 Username
                                    TextField(
                                      controller: usernameController,
                                      decoration: InputDecoration(
                                        hintText: "Username / Email",
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              8),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 15),

                                    // 🔹 Password
                                    TextField(
                                      controller: passwordController,
                                      obscureText: !isPasswordVisible, // ✅ toggle
                                      decoration: InputDecoration(
                                        hintText: "Password",
                                        filled: true,
                                        fillColor: Colors.grey[100],

                                        // 👇 Clickable icon
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            isPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              isPasswordVisible = !isPasswordVisible;
                                            });
                                          },
                                        ),

                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 15),

                                    // 🔹 Store ID
                                    TextField(
                                      controller: storeIdController,
                                      decoration: InputDecoration(
                                        hintText: "Store ID",
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              8),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 30),

                                    // 🔹 Sign In Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (isButtonEnabled) {
                                            context.read<LoginBloc>().add(
                                              LoginSubmitted(
                                                username:
                                                usernameController.text.trim(),
                                                password:
                                                passwordController.text.trim(),
                                                storeId:
                                                storeIdController.text.trim(),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger
                                                .of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Please enter Store ID, Username & Password",
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                              0xFF24467A),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                6),
                                          ),
                                        ),
                                        child: const Text(
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
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
                    ],
                  ),
                ),
              );
            }
        )

    );
  }
}



