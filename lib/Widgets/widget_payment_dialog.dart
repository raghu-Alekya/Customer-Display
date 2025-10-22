import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For displaying SVG images
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Helper/Extentions/text_extensions.dart';
import 'package:provider/provider.dart';

import '../Helper/Extentions/theme_notifier.dart';
import '../Utilities/printer_settings.dart'; // Contains text constants for UI

// Enum for different payment completion states
enum PaymentStatus { successful, partial, receipt, exitConfirmation, voidConfirmation }

// Enum for payment method types
enum PaymentMode { cash, card, wallet, ebt }

class PaymentDialog extends StatefulWidget {
  final PaymentStatus status; // Current payment status
  final PaymentMode? mode; // Payment method used
  final double? amount; // Payment amount
  final double? changeAmount; //Build #1.0.34: New parameter for change amount
  final VoidCallback? onVoid; // Callback for cancelling payment
  final VoidCallback? onPrint; // Callback for printing receipt
  final VoidCallback? onNextPayment; // Callback for proceeding to next payment
  final Function(String, {String? email})? onDone; // Callback for completing the payment flow
  final VoidCallback? onNoReceipt; // Callback when user doesn't want receipt
  final VoidCallback? onExitCancel; // Callback for canceling exit
  final VoidCallback? onExitConfirm; // Callback for confirming exit
  final Function(String)? onEmail; // Callback for sending receipt via email
  final Function(String)? onSMS; // Callback for sending receipt via SMS

  const PaymentDialog({
    Key? key,
    required this.status,
    this.mode,
    this.amount,
    this.changeAmount,
    this.onVoid,
    this.onPrint,
    this.onNextPayment,
    this.onDone,
    this.onNoReceipt,
    this.onExitCancel,
    this.onExitConfirm,
    this.onEmail,
    this.onSMS,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();

  factory PaymentDialog.voidConfirmation({  // Build #1.0.49
    VoidCallback? onVoidCancel,
    VoidCallback? onVoidConfirm,
  }) {
    return PaymentDialog(
      status: PaymentStatus.voidConfirmation,
      onExitCancel: onVoidCancel,
      onExitConfirm: onVoidConfirm,
    );
  }
// factory PaymentDialog.exitConfirmation({
//   VoidCallback? onExitCancel,
//   VoidCallback? onExitConfirm
// }) {
//   return PaymentDialog(
//     status: PaymentStatus.exitConfirmation,
//     onExitCancel: onExitCancel,
//     onExitConfirm: onExitConfirm,
//   );
// }
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedOption = 'Print'; // Default selected receipt option
  final TextEditingController _contactController = TextEditingController(); // For email/phone input
  String? _validationError; // To hold validation error messages
  String capitalize(String s) => s[0].toUpperCase() + s.substring(1); //Build #1.0.34: added for "Cash" in success popup dialog
  bool _isVoidCancelLoading = false; // Build #1.0.49: Track loading for void cancel
  bool _isVoidConfirmLoading = false; // Track loading for void confirm
  bool _isDoneLoading = false; // Track loading for done action
  bool _isNoReceiptLoading = false; // Track loading for no receipt action
  bool _isContinueLoading = false; // Track loading for no receipt action

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Rounded corners for dialog
      ),
      backgroundColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.popUpsBackground : null,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(30), // Padding inside dialog
          width: 750, // Fixed width for dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Keep dialog as small as possible
            crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
            children: [
              _buildStatusIcon(), // Display appropriate status icon
              const SizedBox(height: 24), // Vertical spacing
              _buildTitle(), // Display appropriate title based on status
              const SizedBox(height: 32),
              if (widget.status == PaymentStatus.voidConfirmation)  // Build #1.0.49: added void confirm dialog code
                Text(
                  TextConstants.voidConfirmText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey[800],
                    height: 1.5,
                  ),
                )// Vertical spacing
              else if (widget.status == PaymentStatus.exitConfirmation)
                Text(
                  TextConstants.exitConfirmText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey[800],
                    height: 1.5, // Line height
                  ),
                )
              else
                _buildPaymentInfo(), // Show payment details or receipt options
              const SizedBox(height: 20), // Vertical spacing
              if (widget.status == PaymentStatus.partial) //Build #1.0.34: Show only for partial payment - code updated as per new UI
                Text(
                  TextConstants.partialPaymentText,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 32), // Vertical spacing
              _buildActionButtons(), // Display appropriate action buttons
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    //Color iconColor; // Commented out unused variable
    Color backgroundColor = Colors.white; // Background color for icon
    // IconData icon; // Commented out unused variable
    String svgPath; // Path to SVG asset
    bool isPng = false; // Flag to determine if using PNG instead of SVG

    switch (widget.status) {
      case PaymentStatus.successful:
      //iconColor = Colors.green;
      //backgroundColor = Colors.green.withOpacity(0.1);
      //icon = Icons.check_circle_outline;
        svgPath = 'assets/svg/check_broken.svg'; // Success icon path
        break;
      case PaymentStatus.partial:
      //iconColor = Colors.orange;
      //backgroundColor = Colors.orange.withOpacity(0.1);
      //icon = Icons.check_circle_outline;
        svgPath = 'assets/svg/check_broken_partial.svg'; // Partial payment icon path
        break;
      case PaymentStatus.receipt:
      //iconColor = Colors.blue;
      //backgroundColor = Colors.blue.withOpacity(0.1);
      //icon = Icons.print;
        isPng = true; // Using PNG instead of SVG
        svgPath = 'assets/printer.png'; // Receipt printer icon path
        break;
    // If you don't have this image, replace with an Icon:
    // return Icon(icon, size: 90, color: iconColor);
      case PaymentStatus.exitConfirmation:
        svgPath = 'assets/svg/check_broken_exit.svg';

      case PaymentStatus.voidConfirmation:  // Build #1.0.49
        svgPath = 'assets/svg/check_broken_alert.svg';
        break;
    }

    return Container(
      width: 90, // Fixed size for icon container
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle, // Circular container
        color: backgroundColor,
      ),
      child: isPng
          ? Image.asset( // Use Image.asset for PNG
        svgPath,
        width: 50,
        height: 50,
      )
          : SvgPicture.asset( // Use SvgPicture for SVG
        svgPath,
        width: 50,
        height: 50,
      ),
    );
  }

  Widget _buildTitle() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    String title; // Title text based on payment status
    switch (widget.status) {
      case PaymentStatus.successful:
        title = TextConstants.successPaymentTitle; // Title for successful payment
        break;
      case PaymentStatus.partial:
        title = TextConstants.partialPaymentTitle; // Title for partial payment
        break;
      case PaymentStatus.receipt:
        title = TextConstants.receiptTitle; // Title for receipt options
        break;
      case PaymentStatus.exitConfirmation:
        title = TextConstants.exitConfirmTitle;

      case PaymentStatus.voidConfirmation:
        title = TextConstants.voidConfirmTitle;
        break;

    }

    return Text(
      title,
      textAlign: TextAlign.center,
      softWrap: true,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700, // Bold title
        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : widget.status == PaymentStatus.exitConfirmation ? Colors.black87 : Colors.blueGrey[800],
      ),
    ).poppins();
  }

  Widget _buildPaymentInfo() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    if (widget.status == PaymentStatus.receipt) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the receipt options
        children: [
          _buildReceiptOptionButton( // Print receipt option
            icon: Icons.print,
            label: TextConstants.print,
            isSelected: _selectedOption == TextConstants.print,
            onTap: () {
              setState(() {
                _selectedOption = TextConstants.print; // Update selected option
              });
            },
          ),
          const SizedBox(width: 12), // Horizontal spacing
          _buildReceiptOptionButton( // Email receipt option
            icon: Icons.email_outlined,
            label: TextConstants.email,
            isSelected: _selectedOption == TextConstants.email,
            onTap: () {
              setState(() {
                _selectedOption = TextConstants.email; // Update selected option
              });
            },
          ),
          const SizedBox(width: 12), // Horizontal spacing
          _buildReceiptOptionButton( // SMS receipt option
            icon: Icons.sms_outlined,
            label: TextConstants.sms,
            isSelected: _selectedOption == TextConstants.sms,
            onTap: () {
              setState(() {
                _selectedOption = TextConstants.sms; // Update selected option
              });
            },
          ),
        ],
      );
    }
    return Container( //Build #1.0.34: UI updated as per new figma ui
      width: MediaQuery.of(context).size.width * 0.25,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
      decoration: BoxDecoration(
        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.popUpsBackground : Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${capitalize(widget.mode!.name)} ${TextConstants.mode}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4C5F7D),
                  ),
                ).poppins(),
                Text(
                  '${TextConstants.currencySymbol}${widget.amount!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4C5F7D),
                  ),
                ).poppins(),
              ],
            ),
          ),
          if (widget.changeAmount != null && widget.changeAmount! > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDDF1E1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TextConstants.change, // Consistent label
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1BA672),
                    ),
                  ).poppins(),
                  Text(
                    '${TextConstants.currencySymbol}${widget.changeAmount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1BA672),
                    ),
                  ).poppins(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {// Build #1.0.49: Updated code with void confirm dialog code and loader adder
    final bool isVoidable = (widget.amount ?? 0.0) <= 0.0; // Build #1.0.175: added default value
    if (widget.status == PaymentStatus.voidConfirmation) {
      return Row(
        children: [
          Expanded(
            child: _buildButton(
              TextConstants.noKeepIt,
                  () {
                if (kDebugMode) {
                  print("DEBUG: Void cancel button pressed");
                }
                setState(() {
                  _isVoidCancelLoading = true; // Show loader on button
                });
                widget.onExitCancel?.call();
                Future.delayed(const Duration(milliseconds: 500), () {
                  if(mounted) { // Build #1.0.80: fixed setState Error
                    setState(() {
                      _isVoidCancelLoading = false; // Hide loader after action
                    });
                  }
                });
              },
              backgroundColor: Colors.grey[100]!,
              textColor: Colors.blueGrey[700]!,
              isLoading: _isVoidCancelLoading, // Pass loading state
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildButton(
              TextConstants.yesVoid,
                  () {
                if (kDebugMode) {
                  print("DEBUG: Void confirm button pressed");
                }
                setState(() {
                  _isVoidConfirmLoading = true; // Show loader on button
                });
                widget.onExitConfirm?.call();
                // Loader persists until _handleVoidPayment updates widget.isVoidLoading
              },
              backgroundColor: const Color(0xFFFE6464),
              isLoading: _isVoidConfirmLoading, // Combine states
            ),
          ),
        ],
      );
    }

    if (widget.status == PaymentStatus.exitConfirmation) {
      return Row(
        children: [
          // Cancel button
          Expanded(
            child: _buildButton(
              TextConstants.cancelText,
              widget.onExitCancel ?? () {},
              backgroundColor: Colors.grey[100]!,
              textColor: Colors.blueGrey[700]!,
            ),
          ),
          const SizedBox(width: 16), // Horizontal spacing

          // Continue button
          Expanded(
            child: _buildButton(
              TextConstants.continueText,
                  () { // Build #1.0.104: Fixed: Exit button loader issue
                if (kDebugMode) {
                  print("DEBUG: continue button pressed");
                }
                setState(() {
                  _isContinueLoading = true; // Show loader on button
                });
                widget.onExitConfirm?.call();
                // Loader persists until _handleVoidPayment updates widget.isVoidLoading
              },
              backgroundColor: const Color(0xFFFE6464),
              isLoading: _isContinueLoading, // Combine states
            ),
          ),
        ],
      );
    }
    if (widget.status == PaymentStatus.receipt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center children horizontally
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25, // Responsive width
              child: TextField(
                controller: _contactController, // Controller for input text
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _validationError != null ? Colors.red : Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _validationError != null ? Colors.red : Colors.grey[400]!),
                  ),
                  hintText: TextConstants.enterEmailOrPhone, // Placeholder text
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 18,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Padding inside text field
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500, // Medium weight
                  color: Colors.blueGrey[800],
                ),
                onChanged: (_) {
                  // Clear error when user starts typing
                  if (_validationError != null) {
                    setState(() {
                      _validationError = null;
                    });
                  }
                },
              ),
            ),
          ),
          // Display validation error if it exists
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _validationError!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          const SizedBox(height: 24), // Vertical spacing
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25, // Responsive width
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      TextConstants.noReceipt,
                          () async {
                        if (kDebugMode) {
                          print("DEBUG: No receipt button pressed");
                        }
                        setState(() {
                          _isNoReceiptLoading = true;
                        });
                        await PrinterSettings.openDrawer(context: context);

                        widget.onNoReceipt?.call();

                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            setState(() {
                              _isNoReceiptLoading = false;
                            });
                          }
                        });
                      },
                      backgroundColor: Colors.grey[200]!,
                      textColor: Colors.blueGrey[700]!,
                      isLoading: _isNoReceiptLoading, // Loader state
                    ),
                  ),
                  const SizedBox(width: 16), // Horizontal spacing
                  Expanded(
                    child: _buildButton(
                      TextConstants.done, // "Done" button
                          () {
                        final contactInfo = _contactController.text.trim();
                        bool isValid = true;
                        // Validate only if Email or SMS is selected
                        if (_selectedOption == TextConstants.email || _selectedOption == TextConstants.sms) {
                          if (contactInfo.isEmpty) {
                            setState(() {
                              _validationError = 'Please enter a valid ${_selectedOption.toLowerCase()}.';
                            });
                            isValid = false;
                          }
                        }
                        // If valid, proceed with the action
                        if (isValid) {
                          if (kDebugMode) {
                            print(
                                "DEBUG: Done button pressed, selectedOption: $_selectedOption");
                          }
                          setState(() {
                            _isDoneLoading = true; // Show loader on button
                          });
                          if (_selectedOption == TextConstants.print) {
                            widget.onDone?.call(_selectedOption); // Let onDone handle printing
                          }
                          else if (_selectedOption == TextConstants.email) {
                            widget.onEmail?.call(contactInfo); // Email receipt
                            widget.onDone?.call(_selectedOption, email: contactInfo); // Build #1.0.159: Pass email to onDone btn action
                          } else if (_selectedOption == TextConstants.sms) {
                            widget.onSMS?.call(contactInfo);// SMS receipt
                            widget.onDone?.call(_selectedOption);
                          }
                          // widget.onDone?.call(_selectedOption); // Call done callback
                        }
                      },
                      backgroundColor: const Color(0xFF1BA672),
                      isLoading: _isDoneLoading, // Pass loading state
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    // For successful and partial payment states
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.3,
        child: Row(
          children: [
            // Void button
            Expanded(
              child: _buildButton(
                TextConstants.vOid,
                isVoidable ? () {} : widget.onVoid ?? () {},
                backgroundColor: isVoidable ? Colors.grey : const Color(0xFFFE6464),
              ),
            ),

            // Only show "No Receipt" button if payment is successful
            if (widget.status == PaymentStatus.successful) ...[
              const SizedBox(width: 8), // spacing
              Expanded(
                child: _buildButton(
                  TextConstants.noReceipt,
                      () async {
                    if (kDebugMode) print("DEBUG: No receipt button pressed");

                    setState(() {
                      _isNoReceiptLoading = true;
                    });

                    await PrinterSettings.openDrawer(context: context);
                    widget.onNoReceipt?.call();

                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {
                          _isNoReceiptLoading = false;
                        });
                      }
                    });
                  },
                  backgroundColor: Colors.grey[200]!,
                  textColor: Colors.blueGrey[700]!,
                  isLoading: _isNoReceiptLoading,
                ),
              ),
            ],

            const SizedBox(width: 16), // spacing before Print/Next Payment button

            // Print / Next Payment button
            Expanded(
              child: _buildButton(
                // Dynamic label based on status
                widget.status == PaymentStatus.successful
                    ? TextConstants.print
                    : widget.status == PaymentStatus.partial
                    ? TextConstants.nextPayment
                    : TextConstants.print, // fallback

                // Dynamic callback based on status
                widget.status == PaymentStatus.successful
                    ? () {
                  final contactInfo = _contactController.text.trim();
                  bool isValid = true;

                  if (_selectedOption == TextConstants.email || _selectedOption == TextConstants.sms) {
                    if (contactInfo.isEmpty) {
                      setState(() {
                        _validationError = 'Please enter a valid ${_selectedOption.toLowerCase()}.';
                      });
                      isValid = false;
                    }
                  }

                  if (isValid) {
                    if (kDebugMode) print("DEBUG: Done button pressed, selectedOption: $_selectedOption");

                    setState(() {
                      _isDoneLoading = true;
                    });

                    if (_selectedOption == TextConstants.print) {
                      widget.onDone?.call(_selectedOption); // Let onDone handle printing
                    }
                    else if (_selectedOption == TextConstants.email) {
                      widget.onEmail?.call(contactInfo);
                      widget.onDone?.call(_selectedOption, email: contactInfo);
                    } else if (_selectedOption == TextConstants.sms) {
                      widget.onSMS?.call(contactInfo);
                      widget.onDone?.call(_selectedOption);
                    }
                  }
                }
                    : widget.status == PaymentStatus.partial
                    ? (widget.onNextPayment ?? () {}) // Next payment for partial
                    : () {},

                backgroundColor: const Color(0xFF1BA672),
                isLoading: _isDoneLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build #1.0.49: updated code
  Widget _buildButton(String text, VoidCallback onPressed,
      {Color backgroundColor = Colors.blue, Color textColor = Colors.white, bool isLoading = false}) {
    if (kDebugMode) {
      print("DEBUG: Building button '$text', isLoading: $isLoading");
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed, // Disable button when loading
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor, // Maintain original background color
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBackgroundColor: backgroundColor, // Keep same color when disabled
      ),
      child: isLoading
          ? const SizedBox(
        width: 28, // Increased loader size
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3, // Slightly thicker stroke for visibility
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ).poppins(),
    );
  }

  Widget _buildReceiptOptionButton({
    required IconData icon, // Icon to display
    required String label, // Text label
    required bool isSelected, // Whether this option is selected
    required VoidCallback onTap, // Click handler
  }) {
    return InkWell(
      onTap: onTap, // Handle taps
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Inner padding
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE1E1) : Colors.transparent, // Light red when selected
          borderRadius: BorderRadius.circular(20), // Rounded corners
          border: Border.all(
            color: isSelected ? const Color(0xFFFE6464) : Colors.grey[300]!, // Red border when selected
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Take minimum space
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected ? true : false, // Radio button state
              onChanged: (_) => onTap(), // Handle radio click
              activeColor: const Color(0xFFFE6464), // Red when active
            ),
            const SizedBox(width: 4), // Horizontal spacing
            Icon(
              icon, // Display icon (print, email, sms)
              size: 20,
              color: isSelected ? const Color(0xFFFE6464) : Colors.grey[600], // Red when selected
            ),
            const SizedBox(width: 8), // Horizontal spacing
            Text(
              label, // Option label text
              style: TextStyle(
                color: isSelected ? const Color(0xFFFE6464) : Colors.grey[700], // Red when selected
                fontWeight: FontWeight.w600, // Semi-bold
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}