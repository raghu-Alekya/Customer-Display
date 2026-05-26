import 'dart:async';
import 'package:flutter/material.dart';

class SessionEndedDialog {

  static bool _isShowing = false;

  static Future<void> show(
      BuildContext context, {
        VoidCallback? onTapHere,
      }) async {

    if (_isShowing) return;

    _isShowing = true;

    int seconds = 10;
    Timer? timer;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {

        return StatefulBuilder(
          builder: (context, setState) {

            timer ??= Timer.periodic(
              const Duration(seconds: 1),
                  (t) {

                if (seconds == 0) {

                  t.cancel();

                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }

                  _isShowing = false;

                  if (onTapHere != null) {
                    onTapHere();
                  }

                } else {

                  seconds--;

                  if (context.mounted) {
                    setState(() {});
                  }
                }
              },
            );

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                width: 620,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// IMAGE
                    Image.asset(
                      'assets/session_ended.png',
                      height: 150,
                    ),

                    const SizedBox(height: 18),

                    /// TITLE
                    const Text(
                      'Session Ended',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5C5C),
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// DESCRIPTION
                    const Text(
                      'Your account was accessed on another device.\n'
                          'Please sign in again to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF666666),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Divider(
                      thickness: 1,
                      color: Color(0xFFE5E5E5),
                    ),

                    const SizedBox(height: 18),

                    /// REDIRECT TEXT
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF444444),
                          height: 1.6,
                        ),
                        children: [

                          const TextSpan(
                            text: 'Redirecting to login ',
                          ),

                          TextSpan(
                            text: '$seconds',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const TextSpan(
                            text: ' seconds\n',
                          ),

                          const TextSpan(
                            text: 'if you are not redirected ',
                          ),

                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {

                                Navigator.pop(dialogContext);

                                _isShowing = false;

                                if (onTapHere != null) {
                                  onTapHere();
                                }
                              },
                              child: const Text(
                                'tap here',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration:
                                  TextDecoration.underline,
                                  fontSize: 15,
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
            );
          },
        );
      },
    );

    timer?.cancel();
    _isShowing = false;
  }
}