import 'package:flutter/material.dart';

class OrderPopupHelper {
  /// Shows a popup when no active order exists
  static Future<void> showNoOrderPopup(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("No Active Order"),
        content: const Text(
          "Please click on 'New' to create an order before adding items.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
