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
    return Container(
      width: 45,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8D7D7)),
      ),
      child: Text(
        index < pin.length ? "*" : "",
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _keyButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 55,
        margin: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }


  @override
  @override
  Widget build(BuildContext context) {
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
          child: IntrinsicHeight(
            child: Stack(
              children: [
                /// MAIN CONTENT
                Container(
                  width: 850,
                  height: 400,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// LEFT PANEL
                      SizedBox(
                        width: 420,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                "Check-In",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                "PIN verification required to proceed with refund",
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 20),

                            const Text("PIN:", style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 10),

                            Row(
                              children: List.generate(6, (index) => _pinBox(index)),
                            ),

                            const SizedBox(height: 6),

                            /// 🔴 ERROR MESSAGE
                            if (errorMessage != null)
                              Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),

                            const SizedBox(height: 20),

                            const Text(
                              "Continue Refund",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                /// WITH ORDER REFERENCE
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
                                        fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (states) {
                                            if (states.contains(MaterialState.selected)) {
                                              return Colors.grey.shade700; // selected
                                            }
                                            return Colors.grey.shade400; // unselected
                                          },
                                        ),
                                      ),
                                      Text(
                                        "With order reference",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: refundOption == 1
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 30),

                                /// WITHOUT ORDER REFERENCE
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
                                              return Colors.grey.shade700;
                                            }
                                            return Colors.grey.shade400;
                                          },
                                        ),
                                      ),
                                      Text(
                                        "Without order reference",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: refundOption == 2
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),


                            const Spacer(),

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
                                      errorMessage =
                                      "Please enter 6 digit PIN";
                                    });
                                    return;
                                  }

                                  if (refundOption == null) {
                                    setState(() {
                                      errorMessage =
                                      "Please select refund option";
                                    });
                                    return;
                                  }

                                  context
                                      .read<RefundValidationBloc>()
                                      .add(
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
                                    : const Text("Save & Continue"),
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
                                      width: 95,
                                      height: 65,
                                      margin: const EdgeInsets.all(8),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9EDF5),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.backspace_outlined,
                                        size: 22,
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
                ),

                /// ❌ CLOSE BUTTON
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
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
      },
    );
  }
}