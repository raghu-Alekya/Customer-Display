import 'package:flutter/material.dart';

class OrderPopupHelper {
  static Future<void> showNoOrderPopup(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),  // enough spacing around dialog
          child: Center(
            child: Container(
              width: 520,   // ⬅ Fixed width
              height: 320,  // ⬅ Fixed height
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 🔴 Gradient Circle
                  Align(
                    alignment: const Alignment(0.0, -1.0),
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment(0.50, 0.56),
                          radius: 1.2,
                          colors: [
                            Color(0xFFFBC2C2),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Image.asset(
                          "assets/warning.png",  // your custom ! warning image
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),


                  // 🔴 Red Small Circle
                  // Align(
                  //   alignment: const Alignment(1.0, -1.0), // exact top-right corner
                  //   child: GestureDetector(
                  //     onTap: () => Navigator.pop(context),  // <-- CLOSE POPUP
                  //     child: Container(
                  //       width: 26,
                  //       height: 26,
                  //       decoration: BoxDecoration(
                  //         color: const Color(0xFFF84337),
                  //         borderRadius: BorderRadius.circular(14),
                  //       ),
                  //       child: const Center(
                  //         child: Icon(
                  //           Icons.close,
                  //           color: Colors.white,
                  //           size: 16,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // ---------------- TEXT + BUTTON ----------------
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 90),

                      const Text(
                        "No Order ID Created",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF373535),
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: 15),

                      const SizedBox(
                        width: 450,
                        child: Text(
                          "To add products, you need to create a new order ID.\nPlease create one now?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFA19A9A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF84337),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 45,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "OK",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}