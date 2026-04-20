import 'package:flutter/material.dart';

import '../Repositories/Orders/Full_order_RefundOrderRepository.dart';
import '../Repositories/Orders/partial_order_reund_repository.dart';
import '../Screens/Home/total_orders_screen.dart';

class VerifyItemStatusDialog extends StatefulWidget {
  final dynamic order;
  final List<dynamic> selectedItems;

  const VerifyItemStatusDialog({
    super.key,
    required this.order,
    required this.selectedItems,
  });

  @override
  State<VerifyItemStatusDialog> createState() =>
      _VerifyItemStatusDialogState();
}

class _VerifyItemStatusDialogState extends State<VerifyItemStatusDialog> {
  int? selectedOption;
  bool isLoading = false;

  Widget _optionTile({
    required int value,
    required String title,
    String? subtitle,
    required bool isDark,
  }) {
    final borderColor = selectedOption == value
        ? (isDark ? Colors.white70 : const Color(0xFF4A4A4A))
        : (isDark ? Colors.white24 : const Color(0xFFDADADA));

    final textColor = isDark ? Colors.white : const Color(0xFF4A4A4A);
    final subTextColor = isDark ? Colors.white60 : Colors.grey;

    return GestureDetector(
      onTap: () => setState(() => selectedOption = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: selectedOption,
              activeColor: isDark ? Colors.white : const Color(0xFF4A4A4A),
              onChanged: (val) => setState(() => selectedOption = val),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: textColor),
                  children: [
                    TextSpan(text: title),
                    if (subtitle != null)
                      TextSpan(
                        text: " $subtitle",
                        style: TextStyle(fontSize: 13, color: subTextColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
    isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEDEDED);

    final primaryText =
    isDark ? Colors.white : const Color(0xFF3A3A3A);

    final secondaryText =
    isDark ? Colors.white70 : Colors.grey;

    final cancelBg =
    isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 420,
        width: 500,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Verify Item Status",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              "Choose the correct condition for the\nreturned item",
              style: TextStyle(fontSize: 15, color: secondaryText),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            _optionTile(
              value: 1,
              title: "Items are Resalable",
              subtitle: "(Added to inventory)",
              isDark: isDark,
            ),

            _optionTile(
              value: 2,
              title: "Items are Damaged",
              isDark: isDark,
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: cancelBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryText,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: selectedOption == null || isLoading
                          ? null
                          : () async {
                        setState(() => isLoading = true);

                        try {
                          final fullRepo = RefundOrderRepository(
                            baseUrl:
                            "https://merchantretail.alektasolutions.com",
                          );

                          final partialRepo = PartialRefundRepository(
                            baseUrl:
                            "https://merchantretail.alektasolutions.com",
                          );

                          final isFullRefund =
                              widget.selectedItems.length ==
                                  widget.order.items.length;

                          final itemsReusableValue =
                          selectedOption == 1 ? "yes" : "no";

                          final reason = selectedOption == 1
                              ? "items are resalable"
                              : "items are damaged";

                          bool success = false;

                          if (isFullRefund) {
                            success =
                            await fullRepo.fullOrderRefund(
                              orderId: widget.order.orderId,
                              amount:
                              widget.order.total.toDouble(),
                              reason: reason,
                              itemsReusable: itemsReusableValue,
                            );
                          } else {
                            final itemsToRefund =
                            widget.selectedItems.map((item) {
                              final rawAmount =
                                  item['amount']?.toString() ?? "0";

                              final amount = double.tryParse(
                                rawAmount.replaceAll(
                                    RegExp(r'[^0-9.]'), ''),
                              ) ??
                                  0.0;

                              return {
                                "order_item_id":
                                item['order_item_id'],
                                "qty": item['qty'],
                                "refundable_amount": amount,
                              };
                            }).toList();

                            success =
                            await partialRepo.partialOrderRefund(
                              orderId: widget.order.orderId,
                              reason: reason,
                              itemsReusable: itemsReusableValue,
                              items: itemsToRefund,
                            );
                          }

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? "Refund Successful"
                                  : "Refund Failed"),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );

                          if (success) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const TotalOrdersScreen(),
                              ),
                                  (route) => false,
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
                          : const Text("Submit", style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),),
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