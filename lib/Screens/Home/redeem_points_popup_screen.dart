import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Constants/text.dart';
import '../../Repositories/Orders/order_repository.dart';

class RedeemPointsDialog extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const RedeemPointsDialog({
    super.key,
    required this.apiData,
  });

  @override
  State<RedeemPointsDialog> createState() => _RedeemPointsDialogState();
}

class _RedeemPointsDialogState extends State<RedeemPointsDialog> {
  late String customerContact;
  late int availablePoints;
  late int redeemPoints;
  late double valueRedeemed;
  late double existingNetPayable;
  late double newPayableAmount;
  bool isRedeemLoading = false;

  @override
  void initState() {
    super.initState();
    customerContact = widget.apiData["contact"] ?? "";
    availablePoints = widget.apiData["available_points"] ?? 0;
    redeemPoints = widget.apiData["redeem_points"] ?? 0;

    valueRedeemed =
        double.tryParse(widget.apiData["value_redeemed"].toString()) ?? 0.0;

    existingNetPayable = double.tryParse(
        widget.apiData["existing_net_payable"].toString()) ??
        0.0;

    newPayableAmount =
        double.tryParse(widget.apiData["new_payable_amount"].toString()) ?? 0.0;
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bgPrimary => isDark ? const Color(0xFF252837) : Colors.white;
  Color get bgSecondary =>
      isDark ? const Color(0xFF1F1D2B) : const Color(0xFFF9F9F9);
  Color get borderColor =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE4E4E4);

  Color get textPrimary => isDark ? Colors.white : Colors.black87;
  Color get textSecondary =>
      isDark ? Colors.white70 : const Color(0xFF666666);
  Color get textHint => isDark ? Colors.white38 : const Color(0xFFAAAAAA);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgPrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Reward Points Redemption",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: SizedBox(
                width: 600,
                child: Text(
                  "This customer has reward points available. Enter the amount they want to redeem. The order total will update based on the points used.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TOP DETAILS
            Row(
              children: [
                const SizedBox(width: 20),
                Text(
                  "Cust. Mobile No or Email:",
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),

                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: bgSecondary,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    customerContact,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 30),

                Text(
                  "Net Payable:",
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),

                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: bgSecondary,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    "${TextConstants.currencySymbol}${existingNetPayable.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // MAIN BOX
            Container(
              width: 900,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow("Available Points :", availablePoints.toString(),
                      "Customer’s current reward balance."),
                  const SizedBox(height: 24),

                  infoRow("Redeem Points :", redeemPoints.toString(),
                      "Points redeemed for this order."),
                  const SizedBox(height: 24),

                  infoRow(
                      "Value Redeemed :",
                      "${TextConstants.currencySymbol}${valueRedeemed.toStringAsFixed(2)}",
                      "Amount discounted"),
                  const SizedBox(height: 24),

                  infoRow(
                      "New Payable Amount :",
                      "${TextConstants.currencySymbol}${newPayableAmount.toStringAsFixed(2)}",
                      "Updated order total after redemption"),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // FOOTER BUTTONS
            Row(
              children: [
                footerCancelButton(),
                const Spacer(),
                footerPrimaryButton("Redeem Points"),
                const SizedBox(width: 10),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget infoRow(String title, String value, String helper) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              Text(helper, style: TextStyle(color: textHint, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgPrimary,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
          ),
        ),
      ],
    );
  }

  Widget footerCancelButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 150,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFD6464)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text("Cancel",
            style: TextStyle(
                color: Color(0xFFFD6464),
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget footerSecondaryButton(String text, Color textColor) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, {"remove": true});
      },
      child: Container(
        width: 150,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF393B4C) : const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget footerPrimaryButton(String text) {
    return InkWell(
      onTap: isRedeemLoading
          ? null
          : () async {
        setState(() => isRedeemLoading = true);

        try {
          final response = await OrderRepository().redeemLoyaltyPoints(
            orderId: widget.apiData["order_id"],
            contact: widget.apiData["contact"],
            redeemAmount: valueRedeemed,
            redeemPoints: redeemPoints,
          );

          // POPUP RETURNS THE API DATA TO ORDER-SUMMARY PAGE
          if (mounted) {
            const MethodChannel customerDisplayChannel =
            MethodChannel(
              'com.alekta.pinakapos/sunmi_display',
            );

// UPDATE CUSTOMER DISPLAY
            await customerDisplayChannel.invokeMethod(
              "customerDisplayResult",
              {
                "success": true,
                "points": availablePoints,
                "redeemedAmount": valueRedeemed,
              },
            );

            Navigator.pop(context, {
              "redeemedPoints": redeemPoints,
              "redeemedValue": valueRedeemed,
              "apiResponse": response,
            });
          }
        } catch (e) {
          final errorMessage = e.toString().replaceAll("Exception: ", "");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        finally {
          if (mounted) setState(() => isRedeemLoading = false);
        }
      },
      child: Container(
        width: 150,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isRedeemLoading
              ? Colors.grey.shade400 // Disabled color
              : const Color(0xFFFD6464), // Active color
          borderRadius: BorderRadius.circular(10),
        ),
        child: isRedeemLoading
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          "Redeem Points",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
