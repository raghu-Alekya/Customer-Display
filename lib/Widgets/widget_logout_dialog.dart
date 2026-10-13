import 'package:flutter/material.dart';
import 'package:quickalert/models/quickalert_options.dart';
import 'package:quickalert/quickalert.dart';
import 'package:quickalert/models/quickalert_animtype.dart';

class Logout extends StatelessWidget {
  // final BuildContext parentContext;
  final Function funClosShift;
  final Function funLogout;
  final Function funCancel;

  const Logout({Key? key, required this.funLogout, required this.funCancel, required this.funClosShift}) : super(key: key);

  // Show the logout dialog with close shift button
  showLogoutDialog(BuildContext context) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Logout',
      width: 350,
      text: 'Do you want to?',
      confirmBtnText: 'Logout',
      cancelBtnText: 'Cancel',
      headerBackgroundColor: const Color(0xFF2CD9C5),
      confirmBtnColor: Colors.blue,
      confirmBtnTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
      cancelBtnTextStyle: const TextStyle(color: Colors.grey, fontSize: 16),
      customAsset: null,
      animType: QuickAlertAnimType.scale,
      barrierDismissible: false,

      // Widget for the Close Shift button
      widget: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: ElevatedButton(
          onPressed: () {
            funClosShift();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: const Text(
            'Close Shift',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
      onConfirmBtnTap: () {
        // Handle logout logic
        funLogout();
        // handleLogout(parentContext);
      },
      onCancelBtnTap: () {
        // Navigator.of(parentContext).pop(); // Just close the dialog
        funCancel();
      },
    );
  }

  // Method to handle the logout functionality
  void handleLogout(BuildContext context) {
    // Close the dialog
    Navigator.of(context).pop();

    // Add your logout logic here
    debugPrint('User selected Logout');

    // Example: Navigate to login screen
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (context) => const LoginScreen()),
    //   (route) => false,
    // );
  }

  // Method to handle the close shift functionality
  void handleCloseShift(BuildContext context) {
    // Add your close shift logic here
    debugPrint('User selected Close Shift');

    // Example: Close shift then logout
    // closeShift().then((_) => _handleLogout(context));
  }

  @override
  Widget build(BuildContext context) {
    print("logout called");
    return showLogoutDialog(context);
  }
}