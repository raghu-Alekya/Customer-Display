import 'package:flutter/material.dart';
import '../../Constants/text.dart';

class RedeemPointsDialog extends StatefulWidget {
  final String customerMobile;
  final int availablePoints;
  final double orderTotal;

  const RedeemPointsDialog({
    super.key,
    required this.customerMobile,
    required this.availablePoints,
    required this.orderTotal,
  });

  @override
  State<RedeemPointsDialog> createState() => _RedeemPointsDialogState();
}

class _RedeemPointsDialogState extends State<RedeemPointsDialog> {
  TextEditingController redeemController = TextEditingController();
  final FocusNode redeemFocusNode = FocusNode();

  int redeemPoints = 0;
  double valueRedeemed = 0.0;
  double newPayable = 0.0;
  double balanceAmount = 0.0;

  @override
  void initState() {
    super.initState();
    newPayable = widget.orderTotal;
    balanceAmount = widget.orderTotal;
  }

  // -------------------- THEME HELPERS --------------------
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bgPrimary => isDark ? const Color(0xFF252837) : Colors.white;
  Color get bgSecondary => isDark ? const Color(0xFF1F1D2B) : const Color(0xFFF9F9F9);
  Color get borderColor => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE4E4E4);

  Color get textPrimary => isDark ? Colors.white : Colors.black87;
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF666666);
  Color get textHint => isDark ? Colors.white38 : const Color(0xFFAAAAAA);

  Color get keypadButtonColor =>
      isDark ? const Color(0xFF393B4C) : Colors.white;

  // --------------------------------------------------------

  void updateValues() {
    redeemPoints = int.tryParse(redeemController.text) ?? 0;

    if (redeemPoints > widget.availablePoints) {
      redeemPoints = widget.availablePoints;
    }

    valueRedeemed = redeemPoints * 1.0;

    newPayable = widget.orderTotal - valueRedeemed;
    if (newPayable < 0) newPayable = 0;

    balanceAmount = newPayable;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgPrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
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

            // MOBILE ROW
            Row(
              children: [
                Text(
                  "    Cust. Mobile No:",
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.customerMobile,
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

            // MAIN WHITE BOX
            Container(
              width: 900,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- LEFT PANEL -------------------
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildLabelHelperBox(
                          title: "Available Points :",
                          helper: "Customer’s current reward balance.",
                          value: widget.availablePoints.toString(),
                        ),
                        const SizedBox(height: 24),

                        buildLabelHelperBox(
                          title: "Redeem Points:",
                          helper: "Enter points to redeem.",
                          controller: redeemController,
                          isEditable: true,
                        ),
                        const SizedBox(height: 24),

                        buildLabelHelperBox(
                          title: "Value Redeemed:",
                          helper: "Amount deducted from order.",
                          value:
                          "${TextConstants.currencySymbol}${valueRedeemed.toStringAsFixed(2)}",
                        ),
                        const SizedBox(height: 24),

                        buildLabelHelperBox(
                          title: "New Payable Amount:",
                          helper: "Updated order total.",
                          value:
                          "${TextConstants.currencySymbol}${balanceAmount.toStringAsFixed(2)}",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 30),

                  // ---------------- RIGHT KEYPAD -------------------
                  Column(
                    children: [
                      buildKeypadRow(["1", "2", "3"]),
                      const SizedBox(height: 12),
                      buildKeypadRow(["4", "5", "6"]),
                      const SizedBox(height: 12),
                      buildKeypadRow(["7", "8", "9"]),
                      const SizedBox(height: 12),
                      buildKeypadRow(["Clear", "0", "⌫"]),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // FOOTER BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  footerCancelButton(),
                  const Spacer(),
                  footerSecondaryButton("Remove Points", Colors.red),
                  const SizedBox(width: 10),
                  footerPrimaryButton("Redeem Points"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ---------------- HELPERS -----------------

  Widget sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
  );

  Widget helperText(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: textHint,
    ),
  );

  // KEYPAD ROW
  Widget buildKeypadRow(List<String> values) {
    return Row(
      children: values
          .map(
            (value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: keypadButton(value),
        ),
      )
          .toList(),
    );
  }

  // KEYPAD BUTTON
  Widget keypadButton(String value) {
    return InkWell(
      onTap: () {
        redeemFocusNode.requestFocus();

        if (value.trim() == "Clear") {
          redeemController.clear();
        } else if (value == "⌫") {
          if (redeemController.text.isNotEmpty) {
            redeemController.text =
                redeemController.text.substring(0, redeemController.text.length - 1);
          }
        } else {
          redeemController.text += value;
        }

        updateValues();
      },
      child: Container(
        width: 100,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: keypadButtonColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : const Color(0x3F000000),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF4C5F7D),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // CANCEL BUTTON
  Widget footerCancelButton() {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        width: 150,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFFD6464),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: bgPrimary,
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            )
          ],
        ),
        child: Center(
          child: Text(
            "Cancel",
            style: TextStyle(
              color: const Color(0xFFFD6464),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // REMOVE POINTS / SECONDARY BUTTON
  Widget footerSecondaryButton(String text, Color textColor) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, {
          "redeemedPoints": redeemPoints,
          "redeemedValue": valueRedeemed,
        });
      },
      child: Container(
        width: 150,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF393B4C) : const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // MAIN REDEEM BUTTON
  Widget footerPrimaryButton(String text) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, {
          "redeemedPoints": redeemPoints,
          "redeemedValue": valueRedeemed,
        });
      },
      child: Container(
        width: 150,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFD6464), // SAME IN DARK & LIGHT
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "Redeem Points",
            style: TextStyle(
              color: Color(0xFFF9F6F6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // CREATE BOX ITEM
  Widget buildLabelHelperBox({
    required String title,
    required String helper,
    String? value,
    TextEditingController? controller,
    bool isEditable = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle(title),
              helperText(helper),
            ],
          ),
        ),

        const SizedBox(width: 18),

        Expanded(
          flex: 1,
          child: Container(
            height: 51,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: bgPrimary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(width: 1, color: borderColor),
            ),
            child: isEditable
                ? TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(color: textHint),
              ),
            )
                : Text(
              value ?? "",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}