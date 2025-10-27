import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Widgets/widget_payment_dialog.dart';
import 'package:provider/provider.dart';
import '../Helper/Extentions/nav_layout_manager.dart';

import '../Constants/text.dart';
import '../Helper/Extentions/theme_notifier.dart';

enum ActionButtonType { delete, ok, add, pay }
enum NumPadType { payment, login, age }

class CustomNumPad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onClearPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onConfirmPressed;
  final VoidCallback? onAddPressed;
  final VoidCallback? onPayPressed;
  final ActionButtonType actionButtonType;
  // final bool isPayment;
  // final bool isAgeVerification; // New parameter for age verification layout
  final String Function()? getPaidAmount; // Build #1.0.29: Change to a callback
  final double? balanceAmount; // Build #1.0.29 : Added to compare with paid amount
  final bool? isLoading; // Add isLoading
  final NumPadType numPadType;
  final bool isDarkTheme;
  final bool showAddInsteadOfPay;
  final EdgeInsetsGeometry? gridPadding;

  const CustomNumPad({
    super.key,
    required this.onDigitPressed,
    required this.onClearPressed,
    this.onDeletePressed,
    this.onConfirmPressed,
    this.onAddPressed,
    this.onPayPressed,
    this.actionButtonType = ActionButtonType.delete,
    // this.isPayment = false,
    // this.isAgeVerification = false, // Default to false
    this.getPaidAmount,
    this.balanceAmount,
    this.isLoading, // Require isLoading
    this.numPadType = NumPadType.login,
    this.isDarkTheme = false,
    this.showAddInsteadOfPay = false,
    this.gridPadding,
  });

  @override
  Widget build(BuildContext context) {
    bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    double paddingValue = isPortrait ? 16 : 30;

    switch (numPadType) {
      case NumPadType.age:
        return _buildAgeVerificationPad(context, paddingValue);
      case NumPadType.payment:
        return _buildPaymentPad(context, paddingValue);
      case NumPadType.login:
      default:
        return _buildLoginPad(context, paddingValue);
    }
  }

  Widget _buildPaymentPad(BuildContext context, double paddingValue) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
    return Container(
      //padding: EdgeInsets.symmetric(horizontal: paddingValue),
      height: MediaQuery.of(context).size.height * 0.4250,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: LayoutBuilder(
                builder: (context, constraints) {
                  double buttonHeight = (constraints.maxHeight - 24) / 4;
                  double buttonWidth = (constraints.maxWidth / 3) - 8;
                  double aspectRatio = buttonWidth / buttonHeight;
                  if (aspectRatio <= 0) aspectRatio = 1.0;

                  return SizedBox(
                    child: GridView.count(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 12,
                      childAspectRatio: aspectRatio,
                      children: [
                        _buildKey(isDarkTheme :darkTheme, "7"),
                        _buildKey(isDarkTheme :darkTheme, "8"),
                        _buildKey(isDarkTheme :darkTheme, "9"),
                        _buildKey(isDarkTheme :darkTheme, "4"),
                        _buildKey(isDarkTheme :darkTheme, "5"),
                        _buildKey(isDarkTheme :darkTheme, "6"),
                        _buildKey(isDarkTheme :darkTheme, "1"),
                        _buildKey(isDarkTheme :darkTheme, "2"),
                        _buildKey(isDarkTheme :darkTheme, "3"),
                        _buildKey(isDarkTheme :darkTheme, "00"),
                        _buildKey(isDarkTheme :darkTheme,"0"),
                        _buildClearKey(isDarkTheme: darkTheme)
                      ],
                    ),
                  );
                }
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildBackspaceKey(isDarkTheme : darkTheme)),
                SizedBox(height: 8),
                // Expanded(child: _buildClearKey(isDarkTheme : darkTheme)),
                //SizedBox(height: 8),
                Expanded(
                  flex: 3,
                  child: showAddInsteadOfPay
                      ? _buildAddButton(context)
                      :_buildPayButton(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Age Verification Layout
  Widget _buildAgeVerificationPad(BuildContext context, double paddingValue) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // ✅ Outside spacing
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ Inside spacing
      child: Column(
        children: [
          // Numbers 1-9 in 3x3 grid
          Expanded(
            flex: 3,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2,
              children: [
                _buildKey("1", isDarkTheme: darkTheme),
                _buildKey("2", isDarkTheme: darkTheme),
                _buildKey("3", isDarkTheme: darkTheme),
                _buildKey("4", isDarkTheme: darkTheme),
                _buildKey("5", isDarkTheme: darkTheme),
                _buildKey("6", isDarkTheme: darkTheme),
                _buildKey("7", isDarkTheme: darkTheme),
                _buildKey("8", isDarkTheme: darkTheme),
                _buildKey("9", isDarkTheme: darkTheme),
              ],
            ),
          ),
          // Bottom row with Clear and 0
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildClearKeyForAge(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // ✅ applies around the spacer
                  child: const SizedBox(width: 2),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildKey("0", isDarkTheme: darkTheme),
                ),
              ],
            ),
          ),
          // // Action buttons
          // Expanded(
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: _buildManualVerifyButton(),
          //       ),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: _buildVerifyAgeButton(),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  // Original numpad layout remains unchanged
  Widget _buildLoginPad(BuildContext context, double paddingValue){
    final themeHelper = Provider.of<ThemeNotifier>(context);
    var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      padding: gridPadding ?? EdgeInsets.symmetric(horizontal: paddingValue),
      children: [
        ...List.generate(9, (index) {
          return _buildKey((index + 1).toString(), isDarkTheme :darkTheme);
        }),
        _buildActionKey(
          text: TextConstants.clearText,
          onPressed: onClearPressed,
          color: darkTheme ? ThemeNotifier.tabsBackground : Colors.white,
          textColor: darkTheme ? ThemeNotifier.textDark: ThemeNotifier.textLight,
          isAddButton: false, // Build #1.0.53 : Explicitly mark as not Add button

        ),
        _buildKey("0", isDarkTheme: darkTheme),
        _buildActionKey(
          text: _getActionButtonText(),
          onPressed: _getActionButtonCallback(),
          color: _getActionButtonColor(context),
          textColor: _getActionButtonTextColor(context),
          isAddButton: true, // Build #1.0.53 : Mark as Add button
        ),
      ],
    );
  }



  // Remove _buildPayButton, _showPartialPaymentDialog, _showPaymentDialog, _showReceiptDialog
  // Build #1.0.34: Update _buildPayButton to only call onPayPressed
  Widget _buildPayButton(BuildContext context) {
    //final bool isEnabled = onPayPressed != null;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4444), //isEnabled ? : Colors.grey, # 1.0.174 removed the condition because to allow payment even the net payable/balance amount is <= 0
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPayPressed, //Build #1.0.34
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading! //Build 1.1.36: loader for PAY button
            ? const SizedBox(
          height: 40,
          width: 40,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          'PAY',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // New method for ADD button (similar styling to PAY button but different color and callback)
  Widget _buildAddButton(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (themeHelper.themeMode == ThemeMode.dark && isDarkTheme
            ? Colors.white70
            : const Color(0xFF1E2745)), // Same as login pad ADD button color
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onAddPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: (isLoading ?? false) // Show loader when loading
            ? const SizedBox(
          height: 40,
          width: 40,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          'ADD',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: themeHelper.themeMode == ThemeMode.dark && isDarkTheme
                ? ThemeNotifier.primaryBackground
                : Colors.white,
          ),
        ),
      ),
    );
  }

  // // New method for Manual Verify button
  // Widget _buildManualVerifyButton() {
  //   return Container(
  //     width: double.infinity,
  //     height: 50,
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF4A5568), // Dark blue-gray color
  //       borderRadius: BorderRadius.circular(8),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.1),
  //           blurRadius: 4,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: TextButton(
  //       onPressed: onManualVerifyPressed ?? () {},
  //       style: TextButton.styleFrom(
  //         padding: EdgeInsets.zero,
  //         backgroundColor: Colors.transparent,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //       ),
  //       child: const Text(
  //         'Manually Verified',
  //         style: TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w500,
  //           color: Colors.white,
  //         ),
  //       ),
  //     ),
  //   );
  // }
  //
  // // New method for Verify Age button
  // Widget _buildVerifyAgeButton() {
  //   return Container(
  //     width: double.infinity,
  //     height: 50,
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFE2E8F0), // Light gray color
  //       borderRadius: BorderRadius.circular(8),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.1),
  //           blurRadius: 4,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: TextButton(
  //       onPressed: onVerifyPressed ?? () {},
  //       style: TextButton.styleFrom(
  //         padding: EdgeInsets.zero,
  //         backgroundColor: Colors.transparent,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //       ),
  //       child: const Text(
  //         'Verify Age',
  //         style: TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w500,
  //           color: Color(0xFF4A5568),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // New method for Clear key in age verification (with orange border)
  Widget _buildClearKeyForAge(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // ✅ Outside spacing
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), // ✅ Inside spacing
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark
            ? const Color(0xFF393B4C) // Dark mode color
            : const Color(0xFFFBFDFE), // Light mode color
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF6B35), width: 2), // Orange border
        boxShadow: [
          BoxShadow(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.shadow_F7 : Colors.black.withOpacity(0.05),
            blurRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onClearPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: themeHelper.themeMode == ThemeMode.dark
              ? const Color(0xFF393B4C) // Dark mode
              : const Color(0xFFFBFDFE), // Light mode

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Clear',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFF6B35), // Orange text
          ),
        ),
      ),
    );
  }

  // Get Action Button Text
  String _getActionButtonText() {
    switch (actionButtonType) {
      case ActionButtonType.ok:
        return TextConstants.okText;
      case ActionButtonType.add:
        return TextConstants.addText;
      default:
        return TextConstants.deleteText;
    }
  }

  // Get Action Button Callback
  VoidCallback _getActionButtonCallback() {
    switch (actionButtonType) {
      case ActionButtonType.ok:
        return onConfirmPressed ?? () {};
      case ActionButtonType.add:
        return onAddPressed ?? () {};
      default:
        return onDeletePressed ?? () {};
    }
  }

  // Get Action Button Color
  Color _getActionButtonColor(context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return (actionButtonType == ActionButtonType.ok || actionButtonType == ActionButtonType.add)
        ? themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Color(0xFF1E2745) // OK & Add use same color
        : Colors.white;
  }

  // Get Action Button Text Color
  Color _getActionButtonTextColor(context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return (actionButtonType == ActionButtonType.ok || actionButtonType == ActionButtonType.add)
        ? themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white
        : Colors.black;
  }

  // Build Numeric Key
  Widget _buildKey(String value, {bool isDarkTheme = false}) {
    //final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // ✅ Outside spacing
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // ✅ Inside spacing
      width: double.infinity,
      decoration: BoxDecoration(
        color:  isDarkTheme
            ? ThemeNotifier.tabsBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color:isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextButton(
        onPressed: () => onDigitPressed(value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight,
          ),
        ),
      ),
    );
  }

  // Build Action Key (Clear, Delete/OK/Add)
  Widget _buildActionKey({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    required Color textColor,
    Widget? child,
    bool isAddButton = false, // Add flag to identify Add button
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: (isLoading ?? false) && isAddButton && actionButtonType == ActionButtonType.add
          ? const SizedBox( // Build #1.0.53 : updated condition
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : child ??
          Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
    );
  }

  // New method for backspace key
  Widget _buildBackspaceKey({bool isDarkTheme = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        //color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color:isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onDeletePressed ?? () {},
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(Icons.backspace_outlined, color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight, size: 20),
      ),
    );
  }

  // New method for clear key
  Widget _buildClearKey({bool isDarkTheme = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onClearPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'C',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight,
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:pinaka_pos/Widgets/widget_payment_dialog.dart';
// import 'package:provider/provider.dart';
// import '../Helper/Extentions/nav_layout_manager.dart';
//
// import '../Constants/text.dart';
// import '../Helper/Extentions/theme_notifier.dart';
//
// enum ActionButtonType { delete, ok, add, pay }
// enum NumPadType { payment, login, age }
//
// class CustomNumPad extends StatelessWidget {
//   final Function(String) onDigitPressed;
//   final VoidCallback onClearPressed;
//   final VoidCallback? onDeletePressed;
//   final VoidCallback? onConfirmPressed;
//   final VoidCallback? onAddPressed;
//   final VoidCallback? onPayPressed;
//   final ActionButtonType actionButtonType;
//   // final bool isPayment;
//   // final bool isAgeVerification; // New parameter for age verification layout
//   final String Function()? getPaidAmount; // Build #1.0.29: Change to a callback
//   final double? balanceAmount; // Build #1.0.29 : Added to compare with paid amount
//   final bool? isLoading; // Add isLoading
//   final NumPadType numPadType;
//   final bool isDarkTheme;
//   final bool showAddInsteadOfPay;
//   final EdgeInsetsGeometry? gridPadding;
//
//   const CustomNumPad({
//     super.key,
//     required this.onDigitPressed,
//     required this.onClearPressed,
//     this.onDeletePressed,
//     this.onConfirmPressed,
//     this.onAddPressed,
//     this.onPayPressed,
//     this.actionButtonType = ActionButtonType.delete,
//     // this.isPayment = false,
//     // this.isAgeVerification = false, // Default to false
//     this.getPaidAmount,
//     this.balanceAmount,
//     this.isLoading, // Require isLoading
//     this.numPadType = NumPadType.login,
//     this.isDarkTheme = false,
//     this.showAddInsteadOfPay = false,
//     this.gridPadding,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
//     double paddingValue = isPortrait ? 16 : 30;
//
//     switch (numPadType) {
//       case NumPadType.age:
//         return _buildAgeVerificationPad(context, paddingValue);
//       case NumPadType.payment:
//         return _buildPaymentPad(context, paddingValue);
//       case NumPadType.login:
//       default:
//         return _buildLoginPad(context, paddingValue);
//     }
//   }
//
//   Widget _buildPaymentPad(BuildContext context, double paddingValue) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
//     return Container(
//       //padding: EdgeInsets.symmetric(horizontal: paddingValue),
//       height: MediaQuery.of(context).size.height * 0.4250,
//       child: Row(
//         children: [
//           Expanded(
//             flex: 3,
//             child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   double buttonHeight = (constraints.maxHeight - 24) / 4;
//                   double buttonWidth = (constraints.maxWidth / 3) - 8;
//                   double aspectRatio = buttonWidth / buttonHeight;
//                   if (aspectRatio <= 0) aspectRatio = 1.0;
//
//                   return SizedBox(
//                     child: GridView.count(
//                       shrinkWrap: true,
//                       padding: EdgeInsets.zero,
//                       physics: const NeverScrollableScrollPhysics(),
//                       crossAxisCount: 3,
//                       mainAxisSpacing: 8,
//                       crossAxisSpacing: 12,
//                       childAspectRatio: aspectRatio,
//                       children: [
//                         _buildKey(isDarkTheme :darkTheme, "7"),
//                         _buildKey(isDarkTheme :darkTheme, "8"),
//                         _buildKey(isDarkTheme :darkTheme, "9"),
//                         _buildKey(isDarkTheme :darkTheme, "4"),
//                         _buildKey(isDarkTheme :darkTheme, "5"),
//                         _buildKey(isDarkTheme :darkTheme, "6"),
//                         _buildKey(isDarkTheme :darkTheme, "1"),
//                         _buildKey(isDarkTheme :darkTheme, "2"),
//                         _buildKey(isDarkTheme :darkTheme, "3"),
//                         _buildKey(isDarkTheme :darkTheme, "00"),
//                         _buildKey(isDarkTheme :darkTheme,"0"),
//                         _buildKey(isDarkTheme :darkTheme, "."),
//                       ],
//                     ),
//                   );
//                 }
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               children: [
//                 Expanded(child: _buildBackspaceKey(isDarkTheme : darkTheme)),
//                 SizedBox(height: 8),
//                 Expanded(child: _buildClearKey(isDarkTheme : darkTheme)),
//                 SizedBox(height: 8),
//                 Expanded(
//                   flex: 2,
//                   child: showAddInsteadOfPay
//                       ? _buildAddButton(context)
//                       :_buildPayButton(context),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
// // Age Verification Layout
//   Widget _buildAgeVerificationPad(BuildContext context, double paddingValue) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // ✅ Outside spacing
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ Inside spacing
//       child: Column(
//         children: [
//           // Numbers 1-9 in 3x3 grid
//           Expanded(
//             flex: 3,
//             child: GridView.count(
//               shrinkWrap: true,
//               crossAxisCount: 3,
//               mainAxisSpacing: 12,
//               crossAxisSpacing: 12,
//               childAspectRatio: 2,
//               children: [
//                 _buildKey("1", isDarkTheme: darkTheme),
//                 _buildKey("2", isDarkTheme: darkTheme),
//                 _buildKey("3", isDarkTheme: darkTheme),
//                 _buildKey("4", isDarkTheme: darkTheme),
//                 _buildKey("5", isDarkTheme: darkTheme),
//                 _buildKey("6", isDarkTheme: darkTheme),
//                 _buildKey("7", isDarkTheme: darkTheme),
//                 _buildKey("8", isDarkTheme: darkTheme),
//                 _buildKey("9", isDarkTheme: darkTheme),
//               ],
//             ),
//           ),
//           // Bottom row with Clear and 0
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: _buildClearKeyForAge(context),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // ✅ applies around the spacer
//                   child: const SizedBox(width: 2),
//                 ),
//                 const SizedBox(width: 4),
//                 Expanded(
//                   child: _buildKey("0", isDarkTheme: darkTheme),
//                 ),
//               ],
//             ),
//           ),
//           // // Action buttons
//           // Expanded(
//           //   child: Row(
//           //     children: [
//           //       Expanded(
//           //         child: _buildManualVerifyButton(),
//           //       ),
//           //       const SizedBox(width: 12),
//           //       Expanded(
//           //         child: _buildVerifyAgeButton(),
//           //       ),
//           //     ],
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
//
//   // Original numpad layout remains unchanged
//   Widget _buildLoginPad(BuildContext context, double paddingValue){
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     var darkTheme = themeHelper.themeMode == ThemeMode.dark && isDarkTheme;
//     return GridView.count(
//       shrinkWrap: true,
//       crossAxisCount: 3,
//       mainAxisSpacing: 12,
//       crossAxisSpacing: 12,
//       childAspectRatio: 2,
//       padding: gridPadding ?? EdgeInsets.symmetric(horizontal: paddingValue),
//       children: [
//         ...List.generate(9, (index) {
//           return _buildKey((index + 1).toString(), isDarkTheme :darkTheme);
//         }),
//         _buildActionKey(
//           text: TextConstants.clearText,
//           onPressed: onClearPressed,
//           color: darkTheme ? ThemeNotifier.tabsBackground : Colors.white,
//           textColor: darkTheme ? ThemeNotifier.textDark: ThemeNotifier.textLight,
//           isAddButton: false, // Build #1.0.53 : Explicitly mark as not Add button
//
//         ),
//         _buildKey("0", isDarkTheme: darkTheme),
//         _buildActionKey(
//           text: _getActionButtonText(),
//           onPressed: _getActionButtonCallback(),
//           color: _getActionButtonColor(context),
//           textColor: _getActionButtonTextColor(context),
//           isAddButton: true, // Build #1.0.53 : Mark as Add button
//         ),
//       ],
//     );
//   }
//
//
//
//   // Remove _buildPayButton, _showPartialPaymentDialog, _showPaymentDialog, _showReceiptDialog
//   // Build #1.0.34: Update _buildPayButton to only call onPayPressed
//   Widget _buildPayButton(BuildContext context) {
//     //final bool isEnabled = onPayPressed != null;
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: const Color(0xFFFF4444), //isEnabled ? : Colors.grey, # 1.0.174 removed the condition because to allow payment even the net payable/balance amount is <= 0
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: onPayPressed, //Build #1.0.34
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: Colors.transparent,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: isLoading! //Build 1.1.36: loader for PAY button
//             ? const SizedBox(
//           height: 40,
//           width: 40,
//           child: CircularProgressIndicator(
//             color: Colors.white,
//             strokeWidth: 2,
//           ),
//         )
//             : const Text(
//           'PAY',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // New method for ADD button (similar styling to PAY button but different color and callback)
//   Widget _buildAddButton(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: (themeHelper.themeMode == ThemeMode.dark && isDarkTheme
//             ? Colors.white70
//             : const Color(0xFF1E2745)), // Same as login pad ADD button color
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: onAddPressed,
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: Colors.transparent,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: (isLoading ?? false) // Show loader when loading
//             ? const SizedBox(
//           height: 40,
//           width: 40,
//           child: CircularProgressIndicator(
//             color: Colors.white,
//             strokeWidth: 2,
//           ),
//         )
//             : Text(
//           'ADD',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//             color: themeHelper.themeMode == ThemeMode.dark && isDarkTheme
//                 ? ThemeNotifier.primaryBackground
//                 : Colors.white,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // // New method for Manual Verify button
//   // Widget _buildManualVerifyButton() {
//   //   return Container(
//   //     width: double.infinity,
//   //     height: 50,
//   //     decoration: BoxDecoration(
//   //       color: const Color(0xFF4A5568), // Dark blue-gray color
//   //       borderRadius: BorderRadius.circular(8),
//   //       boxShadow: [
//   //         BoxShadow(
//   //           color: Colors.black.withOpacity(0.1),
//   //           blurRadius: 4,
//   //           offset: const Offset(0, 2),
//   //         ),
//   //       ],
//   //     ),
//   //     child: TextButton(
//   //       onPressed: onManualVerifyPressed ?? () {},
//   //       style: TextButton.styleFrom(
//   //         padding: EdgeInsets.zero,
//   //         backgroundColor: Colors.transparent,
//   //         shape: RoundedRectangleBorder(
//   //           borderRadius: BorderRadius.circular(8),
//   //         ),
//   //       ),
//   //       child: const Text(
//   //         'Manually Verified',
//   //         style: TextStyle(
//   //           fontSize: 16,
//   //           fontWeight: FontWeight.w500,
//   //           color: Colors.white,
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
//   //
//   // // New method for Verify Age button
//   // Widget _buildVerifyAgeButton() {
//   //   return Container(
//   //     width: double.infinity,
//   //     height: 50,
//   //     decoration: BoxDecoration(
//   //       color: const Color(0xFFE2E8F0), // Light gray color
//   //       borderRadius: BorderRadius.circular(8),
//   //       boxShadow: [
//   //         BoxShadow(
//   //           color: Colors.black.withOpacity(0.1),
//   //           blurRadius: 4,
//   //           offset: const Offset(0, 2),
//   //         ),
//   //       ],
//   //     ),
//   //     child: TextButton(
//   //       onPressed: onVerifyPressed ?? () {},
//   //       style: TextButton.styleFrom(
//   //         padding: EdgeInsets.zero,
//   //         backgroundColor: Colors.transparent,
//   //         shape: RoundedRectangleBorder(
//   //           borderRadius: BorderRadius.circular(8),
//   //         ),
//   //       ),
//   //       child: const Text(
//   //         'Verify Age',
//   //         style: TextStyle(
//   //           fontSize: 16,
//   //           fontWeight: FontWeight.w500,
//   //           color: Color(0xFF4A5568),
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
//
//   // New method for Clear key in age verification (with orange border)
//   Widget _buildClearKeyForAge(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // ✅ Outside spacing
//       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), // ✅ Inside spacing
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: themeHelper.themeMode == ThemeMode.dark
//             ? const Color(0xFF393B4C) // Dark mode color
//             : const Color(0xFFFBFDFE), // Light mode color
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: const Color(0xFFFF6B35), width: 2), // Orange border
//         boxShadow: [
//           BoxShadow(
//             color: themeHelper.themeMode == ThemeMode.dark
//                 ? ThemeNotifier.shadow_F7 : Colors.black.withOpacity(0.05),
//             blurRadius: 0,
//             offset: const Offset(0, 0),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: onClearPressed,
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: themeHelper.themeMode == ThemeMode.dark
//               ? const Color(0xFF393B4C) // Dark mode
//               : const Color(0xFFFBFDFE), // Light mode
//
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: const Text(
//           'Clear',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w500,
//             color: Color(0xFFFF6B35), // Orange text
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Get Action Button Text
//   String _getActionButtonText() {
//     switch (actionButtonType) {
//       case ActionButtonType.ok:
//         return TextConstants.okText;
//       case ActionButtonType.add:
//         return TextConstants.addText;
//       default:
//         return TextConstants.deleteText;
//     }
//   }
//
//   // Get Action Button Callback
//   VoidCallback _getActionButtonCallback() {
//     switch (actionButtonType) {
//       case ActionButtonType.ok:
//         return onConfirmPressed ?? () {};
//       case ActionButtonType.add:
//         return onAddPressed ?? () {};
//       default:
//         return onDeletePressed ?? () {};
//     }
//   }
//
//   // Get Action Button Color
//   Color _getActionButtonColor(context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return (actionButtonType == ActionButtonType.ok || actionButtonType == ActionButtonType.add)
//         ? themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Color(0xFF1E2745) // OK & Add use same color
//         : Colors.white;
//   }
//
//   // Get Action Button Text Color
//   Color _getActionButtonTextColor(context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     return (actionButtonType == ActionButtonType.ok || actionButtonType == ActionButtonType.add)
//         ? themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : Colors.white
//         : Colors.black;
//   }
//
//   // Build Numeric Key
//   Widget _buildKey(String value, {bool isDarkTheme = false}) {
//     //final themeHelper = Provider.of<ThemeNotifier>(context);
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // ✅ Outside spacing
//       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // ✅ Inside spacing
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color:  isDarkTheme
//             ? ThemeNotifier.tabsBackground : Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color:isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: () => onDigitPressed(value),
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: Text(
//           value,
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w400,
//             color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Build Action Key (Clear, Delete/OK/Add)
//   Widget _buildActionKey({
//     required String text,
//     required VoidCallback onPressed,
//     required Color color,
//     required Color textColor,
//     Widget? child,
//     bool isAddButton = false, // Add flag to identify Add button
//   }) {
//     return ElevatedButton(
//       onPressed: onPressed,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: textColor,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//       child: (isLoading ?? false) && isAddButton && actionButtonType == ActionButtonType.add
//           ? const SizedBox( // Build #1.0.53 : updated condition
//         height: 20,
//         width: 20,
//         child: CircularProgressIndicator(
//           color: Colors.white,
//           strokeWidth: 2,
//         ),
//       )
//           : child ??
//           Text(
//             text,
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
//           ),
//     );
//   }
//
//   // New method for backspace key
//   Widget _buildBackspaceKey({bool isDarkTheme = false}) {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         //color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color:isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 0),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: onDeletePressed ?? () {},
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: Icon(Icons.backspace_outlined, color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight, size: 20),
//       ),
//     );
//   }
//
//   // New method for clear key
//   Widget _buildClearKey({bool isDarkTheme = false}) {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         // color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: isDarkTheme ? ThemeNotifier.borderColor : Color(0xFFE8E8E8)), // Light grey border
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: TextButton(
//         onPressed: onClearPressed,
//         style: TextButton.styleFrom(
//           padding: EdgeInsets.zero,
//           backgroundColor: isDarkTheme ? ThemeNotifier.tabsBackground : Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         child: Text(
//           'C',
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.w400,
//             color: isDarkTheme ? ThemeNotifier.textDark : ThemeNotifier.textLight,
//           ),
//         ),
//       ),
//     );
//   }
// }