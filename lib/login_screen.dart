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
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final isPortrait = constraints.maxHeight > constraints.maxWidth;

                      final backgroundHeight =
                      isPortrait ? constraints.maxHeight * 0.52 : constraints.maxHeight * 0.72;

                      final cardWidth = isPortrait
                          ? constraints.maxWidth * 0.7
                          : constraints.maxWidth * 0.45;

                      return Stack(
                        children: [
                          // 🔵 Background
                          Container(
                            height: backgroundHeight,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFF24467A),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(80),
                                bottomRight: Radius.circular(80),
                              ),
                            ),
                          ),

                          SafeArea(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: cardWidth,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(height: isPortrait ? 0 : 10),

                                      Text(
                                        "Welcome Back !",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isPortrait ? 30 : 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height:8),

                                      Text(
                                        "Admin",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isPortrait ? 20 : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      SizedBox(height: isPortrait ? 75 : 20),

                                      // Login Card
                                      Center(
                                      child: SizedBox(
                                      // width: 450,
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 10,
                                            ),
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
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),

                                            const SizedBox(height: 40),

                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4, bottom: 6),
                                                  child: Text(
                                                    "Username / Email :",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),

                                                FractionallySizedBox(
                                                  widthFactor: 0.8,
                                                  child: TextField(
                                                    controller: usernameController,
                                                    decoration: InputDecoration(
                                                      hintText: "Enter your Username / Email",
                                                      hintStyle: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.grey.shade100,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 15),

                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4, bottom: 6),
                                                  child: Text(
                                                    "Password :",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                FractionallySizedBox(
                                                  widthFactor: 0.8,
                                                  child: TextField(
                                                    controller: passwordController,
                                                    obscureText: !isPasswordVisible,
                                                    decoration: InputDecoration(
                                                      hintText: "Enter Password",
                                                      hintStyle: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.grey.shade100,
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
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 15),

                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4, bottom: 6),
                                                  child: Text(
                                                    "Store ID :",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                FractionallySizedBox(
                                                  widthFactor: 0.8,
                                                  child: TextField(
                                                    controller: storeIdController,
                                                    decoration: InputDecoration(
                                                      hintText: "Enter Store ID",
                                                      hintStyle: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.grey.shade100,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 75),

                                            FractionallySizedBox(
                                              widthFactor: 0.8,
                                              child: SizedBox(
                                                height: 50,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    FocusScope.of(context).unfocus();

                                                    if (isButtonEnabled) {
                                                      context.read<LoginBloc>().add(
                                                        LoginSubmitted(
                                                          username: usernameController.text.trim(),
                                                          password: passwordController.text.trim(),
                                                          storeId: storeIdController.text.trim(),
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            "Please enter Store ID, Username & Password",
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF24467A),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(6),
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
                                            ),

                                            const SizedBox(height: 12),

                                            const Text(
                                              "Secure login for authorized users only",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ))],
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
        )

    );
  }
}



