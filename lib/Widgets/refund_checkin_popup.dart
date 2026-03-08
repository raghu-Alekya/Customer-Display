import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Blocs/Orders/refund_validation_bloc.dart';
import '../Models/Orders/refund_orderlist_model.dart';
import '../Screens/Home/refund_product_list.dart';
import 'cash_refund.dart';

class PinCheckInDialog extends StatefulWidget {
  final CompletedOrder order; // ✅ ADD THIS

  const PinCheckInDialog({
    super.key,
    required this.order, // ✅ REQUIRE THIS
  });

  @override
  State<PinCheckInDialog> createState() => _PinCheckInDialogState();
}

class _PinCheckInDialogState extends State<PinCheckInDialog> {
  final List<String> pin = [];
  int? refundOption;
  String? errorMessage;// null = no default selected

  void addDigit(String value) {
    if (pin.length < 6) {
      setState(() => pin.add(value));
    }
  }

  void removeDigit() {
    if (pin.isNotEmpty) {
      setState(() => pin.removeLast());
    }
  }

  void clearPin() {
    setState(() => pin.clear());
  }

  Widget _pinBox(int index) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 55,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF353845) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF363348) : const Color(0xFFD8D7D7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        index < pin.length ? "*" : "",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
  Widget _keyButton(String text, {VoidCallback? onTap, Color? bgColor}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isClear = text == "Clear";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 55,
        margin: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isClear
              ? (isDark ? const Color(0xFF453C48) : Colors.white)
              : (bgColor ??
              (isDark ? const Color(0xFF353845) : const Color(0xFFDFE8FF))),
          borderRadius: BorderRadius.circular(8),
          border: isClear
              ? Border.all(
            color: const Color(0xFFD18A8A),
            width: 1,
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isClear
                ?(isDark ? Color(0xFFD18A8A): Colors.red)
                : (isDark ? Colors.white : const Color(0xFF4C5F7D)),
          ),
        ),
      ),
    );
  }
  @override
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocConsumer<RefundValidationBloc, RefundValidationState>(
        listener: (context, state) {
          if (state is RefundValidationSuccess) {
            // ✅ Close PIN dialog
            Navigator.pop(context);

            // ✅ Open Refund screen
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => RefundScreen(order: widget.order),
            );
          }

          if (state is RefundValidationFailure) {
            setState(() {
              errorMessage = "Invalid PIN or unauthorized user";
              pin.clear();
            });
          }
        },
        builder: (context, state) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1F1D2B) : Colors.white,
            child: IntrinsicHeight(
              child: Stack(
                children: [

                  /// MAIN CONTENT
                  Container(
                    width: 850,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),

                    child: Column(
                      children: [

                        /// 🔷 HEADER CENTERED FOR BOTH PANELS
                        const Center(
                          child: Text(
                            "Check-In",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Center(
                          child: Text(
                            "PIN verification required to proceed with refund",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF4C5F7D),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// 🔷 PANELS
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            /// LEFT PANEL
                            SizedBox(
                              width: 420,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 14), // adjust value if needed
                                    child: const Text(
                                      "Pin :",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: List.generate(6, (index) => _pinBox(index)),
                                  ),

                                  const SizedBox(height: 6),

                                  /// ERROR MESSAGE
                                  if (errorMessage != null)
                                    Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),

                                  const SizedBox(height: 30),

                                  Padding(
                                    padding: const EdgeInsets.only(left: 14), // adjust value if needed
                                    child: const Text(
                                      "Continue Refund",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  /// RADIO OPTIONS
                                  Row(
                                    children: [

                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            refundOption = 1;
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Radio<int>(
                                              value: 1,
                                              groupValue: refundOption,
                                              onChanged: (value) {
                                                setState(() {
                                                  refundOption = value;
                                                });
                                              },
                                              fillColor:
                                              MaterialStateProperty.resolveWith<Color>(
                                                    (states) {
                                                  if (states.contains(MaterialState.selected)) {
                                                    return const Color(0xFFFE6464);
                                                  }
                                                  return Colors.grey.shade400;
                                                },
                                              ),
                                            ),
                                            Text(
                                              "Without order reference",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: refundOption == 1
                                                    ? const Color(0xFFFE6464) // ✅ selected color
                                                    : const Color(0xFF8D94AE), // default color
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            refundOption = 2;
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Radio<int>(
                                              value: 2,
                                              groupValue: refundOption,
                                              onChanged: (value) {
                                                setState(() {
                                                  refundOption = value;
                                                });
                                              },
                                              fillColor: MaterialStateProperty.resolveWith<Color>(
                                                    (states) {
                                                  if (states.contains(MaterialState.selected)) {
                                                    return const Color(0xFFFE6464);
                                                  }
                                                  return Colors.grey.shade400;
                                                },
                                              ),
                                            ),
                                            Text(
                                              "Without order reference",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: refundOption == 2
                                                    ? const Color(0xFFFE6464) // ✅ selected color
                                                    : const Color(0xFF8D94AE), // default color
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 35),

                                  /// SAVE BUTTON
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF5C5C),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: state is RefundValidationLoading
                                          ? null
                                          : () {

                                        if (pin.length != 6) {
                                          setState(() {
                                            errorMessage = "Please enter 6 digit PIN";
                                          });
                                          return;
                                        }

                                        if (refundOption == null) {
                                          setState(() {
                                            errorMessage = "Please select refund option";
                                          });
                                          return;
                                        }

                                        context.read<RefundValidationBloc>().add(
                                          ValidateEmployeePinEvent(
                                            pin.join(),
                                          ),
                                        );
                                      },
                                      child: state is RefundValidationLoading
                                          ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : const Text(
                                        "Save & Continue",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 40),

                            /// RIGHT PANEL (KEYPAD)
                            SizedBox(
                              width: 350,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _keyButton("1", onTap: () => addDigit("1")),
                                        _keyButton("2", onTap: () => addDigit("2")),
                                        _keyButton("3", onTap: () => addDigit("3")),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _keyButton("4", onTap: () => addDigit("4")),
                                        _keyButton("5", onTap: () => addDigit("5")),
                                        _keyButton("6", onTap: () => addDigit("6")),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _keyButton("7", onTap: () => addDigit("7")),
                                        _keyButton("8", onTap: () => addDigit("8")),
                                        _keyButton("9", onTap: () => addDigit("9")),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _keyButton("Clear", onTap: clearPin),
                                        _keyButton("0", onTap: () => addDigit("0")),
                                        GestureDetector(
                                          onTap: removeDigit,
                                          child: Container(
                                            width: 90,
                                            height: 55,
                                            margin: const EdgeInsets.all(8),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF32374A) : Colors.white, // inside white
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isDark ? Color(0xFF617CA6) : const Color(0xFF4C5F7D), // border color
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.backspace_outlined,
                                              size: 22,
                                              color: Color(0xFF4C5F7D), // icon color
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  /// CLOSE BUTTON
                  Positioned(
                    top: 25,
                    right: 25,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5C5C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}