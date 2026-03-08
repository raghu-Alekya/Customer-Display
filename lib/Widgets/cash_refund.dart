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
  String amount = " ";
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 70,
        margin: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor ?? const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor ?? const Color(0xFF4A4A4A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        height: 530,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E86DE), width: 2),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                /// TITLE
                const Text(
                  "Cash Refund Amount",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4A4A),
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "Please enter the cash amount to be refunded",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),

                const SizedBox(height: 20),

                /// ENTER PRICE
                Row(
                  children: [
                    const Text(
                      "Enter Price :",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 10),

                    SizedBox(   // 👈 reduce width here
                      width: 260,  // 🔹 change this value as needed
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          "\$ $amount",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3D4F7C),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          bgColor: const Color(0xFFE5E5E5),
                          textColor: Colors.red,
                          onTap: clearAmount,
                        ),
                        _keyButton("0", onTap: () => addDigit("0")),
                        _keyButton(
                          "Add",
                          bgColor: const Color(0xFF3D4F7C),
                          textColor: Colors.white,
                          onTap: () async {

                            final enteredAmount = double.tryParse(amount) ?? 0.0;

                            final result = await showDialog<double>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => PaymentSuccessDialog(
                                amount: enteredAmount,
                              ),
                            );

                            if (result != null) {
                              Navigator.pop(context, result); // return value to RefundScreen
                            }
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
                onTap: () =>  Navigator.pop(context, amount),
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close,
                      size: 12, color: Colors.white),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2E86DE), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// ✅ SUCCESS ICON
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: Color(0xFF5DBB63),
              ),
            ),

            const SizedBox(height: 30),

            /// TITLE
            const Text(
              "Payment Confirmation",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2E2E2E),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            /// MESSAGE
            Text(
              "Cash refund for \$$amount has been\nsuccessfully completed.",
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF1E7F2D),
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
                  Navigator.pop(context,amount); // close dialog
                  if (onContinue != null) onContinue!(); // ✅ trigger callback
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
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