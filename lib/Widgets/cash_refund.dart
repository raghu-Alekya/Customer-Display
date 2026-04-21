import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Widgets/verify_item_status.dart';

import '../Models/Orders/refund_orderlist_model.dart';
import '../Repositories/Orders/Refund_orderlist_repository.dart';

class CashRefundDialog extends StatefulWidget {
  final RefundRequestModel refundRequest;
  final double refundAmount;
  final VoidCallback? onContinue;
  const CashRefundDialog({super.key, required this.refundRequest,
    required this.refundAmount, this.onContinue, });


  @override
  State<CashRefundDialog> createState() => _CashRefundDialogState();
}

class _CashRefundDialogState extends State<CashRefundDialog> {
  late CompletedOrdersRepository repository;
  String amount = "0.00";
  double totalRefund = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize repository with your base URL
    repository = CompletedOrdersRepository(baseUrl: "https://merchantretail.alektasolutions.com");

    // Set initial value from passed refundAmount
    amount = widget.refundAmount.toStringAsFixed(2);

    // Fetch refund total from API
    fetchRefundTotal();
  }

  Future<void> fetchRefundTotal() async {
    try {
      List<Map<String, dynamic>>? itemsMap;
      if (widget.refundRequest.items != null) {
        itemsMap = widget.refundRequest.items!
            .map((e) => {
          "order_item_id": e.orderItemId,
          "order_item_amount": e.orderItemAmount,
        })
            .toList();
      }

      final response = await repository.refundOrder(
        orderId: widget.refundRequest.orderId,
        refundType: widget.refundRequest.refundType,
        items: itemsMap,
      );

      if (response['success'] == true && response.containsKey('total')) {
        if (!mounted) return;
        setState(() {
          totalRefund = response['total']; // store total
          amount = response['total'].toStringAsFixed(2); // pre-fill numpad
        });
      }
    } catch (e) {
      if (kDebugMode) print("Refund fetch error: $e");
    }
  }
  void addDigit(String value) {
    setState(() {
      amount += value;
    });
  }

  void clearAmount() {
    setState(() {
      amount = "";
    });
  }
  Widget _keyButton(String text,
      {Color? bgColor, Color? textColor, VoidCallback? onTap}) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 70,
        margin: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor ??
              (isDark
                  ? const Color(0xFF242837) // ✅ dark button bg
                  : const Color(0xFFE5E5E5)), // ✅ light button bg
          borderRadius: BorderRadius.circular(6),
          // border: Border.all(
          //   color: isDark
          //       ? const Color(0xFF3A3A3A) // subtle border in dark
          //       : const Color(0xFFD0D0D0),
          // ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor ??
                (isDark
                    ? const Color(0xFFEAEAEA) // ✅ readable in dark
                    : const Color(0xFF4A4A4A)), // ✅ normal light
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        height: 530,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F1D2B)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          // border: Border.all(color: const Color(0xFF2E86DE), width: 2),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                /// TITLE
                Text(
                  "Cash Refund Amount",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF4A4A4A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "Please enter the cash amount to be refunded",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFD9D9D9)
                      : Colors.grey,),
                ),

                const SizedBox(height: 20),

                /// ENTER PRICE
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // ✅ VERY IMPORTANT
                    children: [
                      const Text(
                        "Enter Price :",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 10),

                      SizedBox(
                        width: 220, // match keypad width
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF353845)
                                : Colors.white,
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF3A3A3A)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Text(
                            '${(double.tryParse(amount) ?? 0.0) < 0 ? '-' : ''}\$${(double.tryParse(amount) ?? 0.0).abs().toStringAsFixed(2)}',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF3D4F7C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// NUMPAD
                Column(
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
                        _keyButton(
                          "Clear",
                          bgColor: isDark
                              ? const Color(0xFF483C3C) // dark red subtle
                              : const Color(0xFFFFE5E5), // light red background
                          textColor: isDark
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFFD32F2F),
                          onTap: clearAmount,
                        ),
                        _keyButton("0", onTap: () => addDigit("0")),
                        _keyButton(
                          "Add",
                          bgColor: isDark
                              ? const Color(0xFF4E5673) // slightly brighter for dark
                              : const Color(0xFF3D4F7C),
                          textColor: Colors.white,
                          onTap: () async {
                            final enteredAmount = double.tryParse(amount) ?? 0.0;
                            Navigator.pop(context, enteredAmount);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            /// CLOSE BUTTON
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // 👈 better tap area
                // Treat close as cancel: do not return a value
                onTap: () => Navigator.pop(context),
                child: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
class PaymentSuccessDialog extends StatelessWidget {
  final double? amount;
  final VoidCallback? onContinue;

  const PaymentSuccessDialog({
    super.key,
    this.amount,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final double value = amount ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1D2B) : Colors.white, // ✅ BG
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// ✅ SUCCESS ICON
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle, // ✅ THIS MAKES IT CIRCLE
                gradient: isDark
                    ? const RadialGradient(
                  colors: [
                    Color(0xFF283331), // center
                    Color(0xFF283331), // outer
                  ],
                )
                    : const RadialGradient(
                  colors: [
                    Color(0xFFEAF7EA),
                    Color(0xFFD4F1D4),
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: Color(0xFF5DBB63),
              ),
            ),

            const SizedBox(height: 30),

            /// TITLE
            Text(
              "Payment Confirmation",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF2E2E2E),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            /// MESSAGE
            Text(
              "Cash refund for ${value < 0 ? '-' : ''}\$${value.abs().toStringAsFixed(2)} has been\nsuccessfully completed.",
              style: TextStyle(
                fontSize: 18,
                color: isDark
                    ? const Color(0xFF7CFC9A) // brighter green for dark
                    : const Color(0xFF1E7F2D),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 36),

            /// CONTINUE BUTTON
            SizedBox(
              width: 280,
              height: 56,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, amount);
                  if (onContinue != null) onContinue!();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFF6B6B) // nicer dark button
                        : const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}