import 'package:flutter/material.dart';

import '../Repositories/Orders/Full_order_RefundOrderRepository.dart';
import '../Screens/refund_screen.dart';

class VerifyItemStatusDialog extends StatefulWidget {
  final dynamic order;
  const VerifyItemStatusDialog({super.key,  required this.order,});

  @override
  State<VerifyItemStatusDialog> createState() =>
      _VerifyItemStatusDialogState();
}

class _VerifyItemStatusDialogState extends State<VerifyItemStatusDialog> {
  int? selectedOption;
  bool isLoading = false; // 👈 Add this in your State class
  Widget _optionTile({
    required int value,
    required String title,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedOption == value
                ? const Color(0xFF4A4A4A)
                : const Color(0xFFDADADA),
          ),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: selectedOption,
              activeColor: const Color(0xFF4A4A4A),
              onChanged: (val) {
                setState(() {
                  selectedOption = val;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4A4A4A),
                  ),
                  children: [
                    TextSpan(text: title),
                    if (subtitle != null)
                      TextSpan(
                        text: " $subtitle",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFEDEDED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// TITLE
            const Text(
              "Verify Item Status",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A3A3A),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            /// SUBTITLE
            const Text(
              "Choose the correct condition for the\nreturned item",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            /// OPTION 1
            _optionTile(
              value: 1,
              title: "Items are Resalable",
              subtitle: "(Added to inventory)",
            ),

            /// OPTION 2
            _optionTile(
              value: 2,
              title: "Items are Damaged",
            ),

            const SizedBox(height: 30),

            /// BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: selectedOption == null || isLoading
                          ? null
                          : () async {
                        setState(() => isLoading = true);

                        try {
                          final repo = RefundOrderRepository(
                            baseUrl: "https://merchantretail.alektasolutions.com",
                          );

                          final itemsReusableValue = selectedOption == 1 ? "yes" : "no";

                          bool success = await repo.fullOrderRefund(
                            orderId: widget.order.orderId,
                            amount: widget.order.total.toDouble(),
                            reason: selectedOption == 1 ? "items are resalable" : "items are damaged",
                            itemsReusable: itemsReusableValue,
                          );

                          if (!mounted) return;

                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Refund Successful"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Refund Failed"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
                      },
                      child: isLoading
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "Submit",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}