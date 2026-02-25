import 'package:flutter/material.dart';

import '../Repositories/Orders/Full_order_RefundOrderRepository.dart';
import '../Repositories/Orders/partial_order_reund_repository.dart';
import '../Screens/Home/total_orders_screen.dart';
import '../Screens/refund_screen.dart';

class VerifyItemStatusDialog extends StatefulWidget {
  final dynamic order;
  final List<dynamic> selectedItems;
  const VerifyItemStatusDialog({super.key,  required this.order, required this.selectedItems,});

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

                        print("========= SUBMIT CLICKED =========");
                        print("Selected Option: $selectedOption");
                        print("Selected Items Raw: ${widget.selectedItems}");

                        setState(() => isLoading = true);

                        try {
                          final fullRepo = RefundOrderRepository(
                            baseUrl: "https://merchantretail.alektasolutions.com",
                          );

                          final partialRepo = PartialRefundRepository(
                            baseUrl: "https://merchantretail.alektasolutions.com",
                          );

                          bool success = false;

                          /// 🔹 Determine if FULL or PARTIAL refund
                          final bool isFullRefund =
                              widget.selectedItems.length == widget.order.items.length;

                          print("Is Full Refund: $isFullRefund");

                          /// 🔹 Determine item condition
                          final String itemsReusableValue =
                          selectedOption == 1 ? "yes" : "no";

                          final String reason =
                          selectedOption == 1
                              ? "items are resalable"
                              : "items are damaged";

                          /// ================= FULL REFUND =================
                          if (isFullRefund) {

                            print("---- FULL REFUND FLOW ----");
                            print("Order ID: ${widget.order.orderId}");
                            print("Amount: ${widget.order.total}");

                            success = await fullRepo.fullOrderRefund(
                              orderId: widget.order.orderId,
                              amount: widget.order.total.toDouble(),
                              reason: reason,
                              itemsReusable: itemsReusableValue,
                            );
                          }

                          /// ================= PARTIAL REFUND =================
                          else {

                            print("---- PARTIAL REFUND FLOW ----");

                            if (widget.selectedItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No items selected for partial refund"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => isLoading = false);
                              return;
                            }

                            final List<Map<String, dynamic>> itemsToRefund =
                            widget.selectedItems.map((item) {

                              final rawAmount = item['amount']?.toString() ?? "0";

                              final double amount = double.tryParse(
                                rawAmount.replaceAll(RegExp(r'[^0-9.]'), ''),
                              ) ??
                                  0.0;

                              return {
                                "order_item_id": item['order_item_id'],
                                "qty": item['qty'],
                                "refundable_amount": amount, // ✅ USE PARSED VALUE
                              };

                            }).toList();

                            print("Partial Refund Payload: $itemsToRefund");

                            success = await partialRepo.partialOrderRefund(
                              orderId: widget.order.orderId,
                              reason: reason,
                              itemsReusable: itemsReusableValue,
                              items: itemsToRefund,
                            );
                          }

                          print("Refund API Success: $success");

                          if (!mounted) return;

                          if (success) {

                            // Show success message first
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Refund Successful"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );

                            // Wait for snackbar to finish, then navigate
                            // await Future.delayed(const Duration(seconds: 2));

                            if (!mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TotalOrdersScreen(),
                              ),
                                  (route) => false,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Refund Failed"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }

                        } catch (e, stackTrace) {

                          print("🔥 ERROR: $e");
                          print("StackTrace: $stackTrace");

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );

                        } finally {
                          if (mounted) {
                            setState(() => isLoading = false);
                          }
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
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}