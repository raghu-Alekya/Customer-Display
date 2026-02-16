import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Screens/Home/pos_home_screen.dart';
import 'package:provider/provider.dart';

import '../Helper/Extentions/theme_notifier.dart';

class CustomDialog {
  // Reusable Button Styles
  static ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFFE6464),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    minimumSize: const Size(double.infinity, 48),
  );

  static ButtonStyle get _secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFF6F6F6),
    foregroundColor: Color(0xFF4C5F7D),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    minimumSize: const Size(double.infinity, 48),
  );

  // Reusable Text Styles
  static TextStyle _titleStyle(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: themeHelper.themeMode == ThemeMode.dark ? Color(0xFFE8E6E6): Color(0xFF4C5F7D),
    );
  }

    static TextStyle _descriptionStyle(BuildContext context) {
      final themeHelper = Provider.of<ThemeNotifier>(context);
      return TextStyle(
        fontSize: 14,
        color: themeHelper.themeMode == ThemeMode.dark ? Color(0xFFDADADA) : Colors.grey,
      );
    }

    static const TextStyle _lightDescriptionStyle = TextStyle(
      fontSize: 14,
      color: Color(0xFFD0CCCC),
    );

    static const TextStyle _mutedDescriptionStyle = TextStyle(
      fontSize: 14,
      color: Color(0xFF9CA3AF),
    );

    // Public Methods
    static Future<void> showInvalidCoupon(BuildContext context) {
      return _showSimpleDialog(
        context,
        title: TextConstants.invalidCoupon,
        description: TextConstants.invalidCouponDescription,
        buttonText: TextConstants.letsTryAgain,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: true,
      );
    }

    static Future<void> showDiscountNotApplied(
        BuildContext context, {
          String errorMessageTitle = TextConstants.discountNotApplied,
          String errorMessageDes = TextConstants.discountNotAppliedDescription,
          VoidCallback? onRetry,
        }) {
      return _showSimpleDialog(
        context,
        title: errorMessageTitle,
        description: errorMessageDes,
        buttonText: TextConstants.letsTryAgain,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: true,
        onButtonPressed: onRetry ?? () => Navigator.of(context).pop(),
      );
    }

  static Future<void> showCloseShiftWarning(
      BuildContext context, {
        VoidCallback? onOk,
      }) {
    return _showSimpleDialog(
      context,
      title: TextConstants.closeShiftWarning, // You'll need to add this to TextConstants
      description: TextConstants.closeShiftWarningDesc,
      buttonText: TextConstants.ok, // Make sure this exists in TextConstants
      iconPath: 'assets/svg/check_broken_info.svg', // Using same icon as other info dialogs
      showCloseIcon: false, // No close icon since user must acknowledge
      onButtonPressed: onOk ?? () {
        Navigator.of(context).pop();
        // Navigate to FastKeyScreen - adjust the route name as per your app
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => POSHomeScreen()),
            (route) => false,
        );
      },
    );
  }

    //Build #1.0.67: code updated for removing the payout/coupon/discount based on
    static Future<bool?> showRemoveSpecialOrderItemsConfirmation(BuildContext context, {String? type, Function? confirm}) {
      return _showConfirmDialog(
          context,
          title: type == 'payout'
              ? TextConstants.removePayout
              : type == 'coupon'
              ? TextConstants.removeCoupon
              : type == 'custom item'
              ? TextConstants.removeCustomItem
              : TextConstants.removeDiscount,

          description: TextConstants.removeSpecialOrderItemDescription,
          confirmText: TextConstants.remove,
          cancelText: TextConstants.close,
          iconPath: 'assets/svg/check_broken_alert.svg',
          confirmCallBack: confirm
        //confirmCallback: confirm,
      );
    }

  // Build #1.0.221 : Updated function for re-use purpose
  static Future<bool?> showAreYouSure(BuildContext context, {
    Function? confirm,
    bool isDeleting = false,
    String description = TextConstants.deleteTheRecordsDescription, // Default description
    String confirmText = TextConstants.yesDelete, // Default confirm text
    String cancelText = TextConstants.noKeepIt, // Default cancel text
  }) {
    return _showConfirmDialog(
      context,
      title: TextConstants.areYouSure,
      description: description, // Use provided or default description
      confirmText: confirmText,
      cancelText: cancelText,
      iconPath: 'assets/svg/check_broken_alert.svg',
      confirmCallBack: confirm,
      isDeleting: isDeleting,
    ); //Build #1.0.74: Pass to _showConfirmDialog
  }

    static Future<void> showCustomItemAlert( //Build #1.0.68: updated code
        BuildContext context, {
          String? title,
          String? description,
          String? buttonText,
          bool? showCloseIcon, // Build #1.0.240: updated code for reusing this popUp dialog
          VoidCallback? onButtonPressed,
        }) {
      return _showSimpleDialog(
        context,
        title: title ?? TextConstants.customItemAlert,
        description: description ?? TextConstants.customItemAlertDescription,
        buttonText: buttonText ?? TextConstants.addCustomItem,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: showCloseIcon ?? true,
        onButtonPressed: onButtonPressed ?? () => Navigator.of(context).pop(), // Default dismiss action
      );
    }

    static Future<void> showCouponNotApplied(
        BuildContext context, {
          String errorMessageTitle = TextConstants.couponNotApplied,
          String errorMessageDes = TextConstants.couponNotAppliedDescription,
          VoidCallback? onRetry,
        }) {
      return _showSimpleDialog(
        context,
        title: errorMessageTitle,
        description: errorMessageDes,
        buttonText: TextConstants.letsTryAgain,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: true,
        onButtonPressed: onRetry ?? () => Navigator.of(context).pop(),
      );
    }

    static Future<void> showInvalidDiscount(BuildContext context) {
      return _showSimpleDialog(
        context,
        title: TextConstants.invalidDiscount,
        description: TextConstants.invalidDiscountDescription,
        buttonText: TextConstants.letsTryAgain,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: true,
      );
    }

    static Future<void> showCustomItemNotAdded(
        BuildContext context, {
          String errorMessageTitle = TextConstants.customItemCouldNotBeAdded,
          String errorMessageDes = TextConstants.customItemCouldNotBeAddedDescription,
          VoidCallback? onRetry,
        }) {
      return _showSimpleDialog(
        context,
        title: errorMessageTitle,
        description: errorMessageDes,
        buttonText: TextConstants.letsTryAgain,
        iconPath: 'assets/svg/check_broken_info.svg',
        showCloseIcon: true,
        onButtonPressed: onRetry ?? () => Navigator.of(context).pop(),
      );
    }

    // Cash Drawer Verification Methods
    static Future<bool?> showStartShiftVerification(
        BuildContext context, {
          required double totalAmount,
          double? overShort,
          bool isLoading = false, // Build #1.0.247 : Added loader on button tap of start, update, close shift call
        }) {
      Completer<bool?> completer = Completer<bool?>();

      _showCashVerificationDialog(
        context,
        totalAmount: totalAmount,
        overShort: overShort,
        isShiftStarted: false,
        isLoading: isLoading,
        completer: completer,
      );

      return completer.future;
    }

    static Future<bool?> showCloseShiftVerification( // Build #1.0.247 : Added loader on button tap of start, update, close shift call
        BuildContext context, {
          required double totalAmount,
          double? overShort,
          bool isLoading = false, // Added this parameter
        }) {

      Completer<bool?> completer = Completer<bool?>();
      _showCashVerificationDialog(
        context,
        totalAmount: totalAmount,
        overShort: overShort,
        isShiftStarted: true,
        isLoading: isLoading,
        completer: completer, // Pass the completer
      );

      return completer.future;
    }

    static Future<bool?> showUpdateShiftVerification( // Build #1.0.247 : Added loader on button tap of start, update, close shift call
        BuildContext context, {
          required double totalAmount,
          double? overShort,
          bool isLoading = false,
        }) {

      Completer<bool?> completer = Completer<bool?>();

       _showCashVerificationDialog(
        context,
        totalAmount: totalAmount,
        overShort: overShort,
        isShiftStarted: true,
        actionButtonTextOverride: TextConstants.updateShift,
        descriptionTextOverride: TextConstants.updateShiftDescription,
        isLoading: isLoading,
        completer: completer,
      );
      return completer.future;
    }

    // Reusable Base Dialog Builder
    static Widget _buildBaseDialog(BuildContext context, Widget content) {
      final themeHelper = Provider.of<ThemeNotifier>(context);
      return Dialog(
        backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.popUpsBackground : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.35,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      );
    }

  // Reusable Icon Builder
  static Widget _buildIcon(String iconPath, {double height = 50, Color? color}) {
    return SvgPicture.asset(
      iconPath,
      height: height,
      color: color,
    );
  }

  // // Reusable Circular Icon with Background
  // static Widget _buildCircularIcon(String iconPath, {Color? iconColor, Color? backgroundColor}) {
  //   return Container(
  //     width: 60,
  //     height: 60,
  //     decoration: BoxDecoration(
  //       color: backgroundColor ?? Color(0xFFFEE2E2),
  //       borderRadius: BorderRadius.circular(30),
  //     ),
  //     child: Center(
  //       child: _buildIcon(iconPath, height: 30, color: iconColor),
  //     ),
  //   );
  // }

    // Reusable Text Builders
    static Widget _buildTitle(BuildContext context, String title) {
      return Text(
        title,
        style: _titleStyle(context),
        textAlign: TextAlign.center,
      );
    }

    static Widget _buildDescription(BuildContext context, String description, {TextStyle? style}) {
      return Text(
        description,
        style: style ?? _descriptionStyle(context),
        textAlign: TextAlign.center,
      );
    }

    // Reusable Button Builders
    static Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isDeleting = false}) {
      return ElevatedButton(
        style: _primaryButtonStyle,
        onPressed: onPressed,
        child: isDeleting
            ? SizedBox( //Build #1.0.74
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          text,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    static Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
      return ElevatedButton(
        style: _secondaryButtonStyle,
        onPressed: onPressed,
        child: Text(text, style: TextStyle(color: Color(0xFF4C5F7D), fontWeight: FontWeight.bold)),
      );
    }

    // Reusable Close Icon
    static Widget _buildCloseIcon(BuildContext context) {
      return Positioned(
        top: 0,
        right: 0,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: CircleAvatar(
            backgroundColor: Colors.redAccent,
            radius: 20,
            child: Icon(Icons.close, size: 20, color: Colors.white),
          ),
        ),
      );
    }

    // Reusable Amount Row Builder
    static Widget _buildAmountRow(String label, double amount, {Color? backgroundColor, Color? textColor}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor ?? Color(0xFF4C5F7D),
              ),
            ),
            Text(
              '${TextConstants.currencySymbol}${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor ?? Color(0xFF4C5F7D),
              ),
            ),
          ],
        ),
      );
    }

    // Internal Methods - Refactored
    static Future<void> _showSimpleDialog(
        BuildContext context, {
          required String title,
          required String description,
          required String buttonText,
          required String iconPath,
          bool showCloseIcon = false,
          VoidCallback? onButtonPressed,
        }) {
      return showDialog(
        context: context,
        builder: (_) => _buildBaseDialog(
          context,
          Stack(
            children: [
              if (showCloseIcon) _buildCloseIcon(context),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: showCloseIcon ? 32 : 0),
                  _buildIcon(iconPath),
                  const SizedBox(height: 16),
                  _buildTitle(context,title),
                  const SizedBox(height: 8),
                  _buildDescription(context, description),
                  const SizedBox(height: 24),
                  _buildPrimaryButton(
                    buttonText,
                    onButtonPressed ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    static Future<bool?> _showConfirmDialog(
        BuildContext context, {
          required String title,
          required String description,
          required String confirmText,
          required String cancelText,
          required String iconPath,
          Function? confirmCallBack,
          bool isDeleting = false, // Add parameter
        }) {
      return showDialog(
        context: context,
        builder: (BuildContext dialogContext) => _buildBaseDialog(
          dialogContext,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(iconPath, height: 48),
              const SizedBox(height: 16),
              _buildTitle(context, title),
              const SizedBox(height: 8),
              _buildDescription(context, description, style: _lightDescriptionStyle),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      cancelText,
                          () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPrimaryButton(
                        confirmText,
                            () async {
                          final result = confirmCallBack?.call();
                          if (result is Future) {
                            await result;
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        },
                        isDeleting:isDeleting
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    static Future<bool?> _showCashVerificationDialog(
        BuildContext context, {
          required double totalAmount,
          double? overShort,
          required bool isShiftStarted,
          String? actionButtonTextOverride,
          String? descriptionTextOverride,
          bool isLoading = false, // Build #1.0.247 : Added this parameter
          Completer<bool?>? completer, // Added completer parameter
        }) {
      String actionButtonText = actionButtonTextOverride ??
          (isShiftStarted ? TextConstants.closeShift : TextConstants.startShift);

      String descriptionText = descriptionTextOverride ??
          (isShiftStarted
              ? TextConstants.ShiftCloseDescription
              : TextConstants.ShiftStartDescription);

      //Build #1.0.74: Determine over/short label and styling
      String overShortLabel = overShort == 0 ? 'Over/Short' : overShort! > 0 ? 'Over' : 'Short';
      Color overShortBgColor = overShort == 0 ? Color(0xFFE8F5E8) : overShort! > 0 ? Color(0xFFE8F5E8) : Color(0xFFFEE2E2);
      Color overShortTextColor = overShort == 0 ? Color(0xFF22C55E) : overShort! > 0 ? Color(0xFF22C55E) : Color(0xFFFE6464);

      if (kDebugMode) {
        print('Showing cash verification dialog - Total: $totalAmount, Over/Short: $overShort, Label: $overShortLabel');
      }

      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildBaseDialog(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background
              _buildIcon(
                'assets/svg/check_broken_alert.svg',
              ),
              const SizedBox(height: 16),
              // Title
              _buildTitle(context, TextConstants.verifyDrawerAndSafeAmounts),
              const SizedBox(height: 24),
              // Total Amount
              _buildAmountRow(TextConstants.totalAmount, totalAmount),
              const SizedBox(height: 12),
              //Build #1.0.78: Show Over/Short only if not zero
              if (overShort != null && overShort != 0)
                _buildAmountRow(
                  overShortLabel,
                  overShort.abs(),
                  backgroundColor: overShortBgColor,
                  textColor: overShortTextColor,
                ),
              const SizedBox(height: 16),
              // Description
              _buildDescription(context, descriptionText, style: _mutedDescriptionStyle),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      TextConstants.back,
                          () {
                        Navigator.of(context).pop();
                        completer?.complete(false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isLoading
                        ? _buildPrimaryButtonWithLoader()
                        : _buildPrimaryButton(
                      actionButtonText,
                          () {
                        Navigator.of(context).pop();
                        completer?.complete(true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

  // Build #1.0.247 : Added this helper method for loader button
  static Widget _buildPrimaryButtonWithLoader() {
    return ElevatedButton(
      style: _primaryButtonStyle,
      onPressed: null, // Disable button when loading
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
// Reusable Components:
// 1. Button Styles (lines 7-19):
//
// _primaryButtonStyle - Red buttons
// _secondaryButtonStyle - Gray buttons
//
// 2. Text Styles (lines 21-41):
//
// _titleStyle - Dialog titles
// _descriptionStyle - Regular descriptions
// _lightDescriptionStyle - Light gray text
// _mutedDescriptionStyle - Muted gray text
//
// 3. Reusable Builders (lines 139-225):
//
// _buildBaseDialog() - Common dialog container
// _buildIcon() - SVG icon builder
// _buildCircularIcon() - Icon with circular background
// _buildTitle() - Title text
// _buildDescription() - Description text
// _buildPrimaryButton() - Red buttons
// _buildSecondaryButton() - Gray buttons
// _buildCloseIcon() - Close button
// _buildAmountRow() - Amount display rows
//
// Benefits of This Refactor:
// Eliminated Repetition:
//
// Before: Dialog container code repeated 3 times
// After: Single _buildBaseDialog() method
//
// Consistent Styling:
//
// All buttons use the same styles
// All text uses consistent styling
// Easy to change colors/fonts in one place
//
// Maintainable:
//
// Want to change button colors? Change _primaryButtonStyle
// Want to change text size? Change _titleStyle
// Need new dialog? Use existing builders
//
// Cleaner Methods:
//
// _showSimpleDialog() went from 50+ lines to ~25 lines
// _showConfirmDialog() is much cleaner
// _showCashVerificationDialog() focuses on layout, not styling
//
// Flexible:
//
// _buildAmountRow() handles different colors for short/over amounts
// _buildDescription() accepts custom styles
// _buildIcon() accepts custom colors and sizes
//