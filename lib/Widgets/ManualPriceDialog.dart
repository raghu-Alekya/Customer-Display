import 'package:flutter/material.dart';

class ManualPriceDialog extends StatefulWidget {
  final String productName;
  final String productImage;
  final int quantity;

  const ManualPriceDialog({
    super.key,
    required this.productName,
    required this.productImage,
    this.quantity = 1,
  });

  static Future<double?> show(
      BuildContext context, {
        required String productName,
        required String productImage,
        int quantity = 1,
        required double minPrice,
      }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualPriceDialog(
        productName: productName,
        productImage: productImage,
        quantity: quantity,
      ),
    );
  }


  @override
  State<ManualPriceDialog> createState() => _ManualPriceDialogState();
}

class _ManualPriceDialogState extends State<ManualPriceDialog> {
  String enteredPrice = "";

  void _onKeyTap(String value) {
    setState(() => enteredPrice += value);
  }

  void _clear() {
    setState(() => enteredPrice = "");
  }

  void _submit() {
    if (enteredPrice.isNotEmpty) {
      Navigator.pop(context, double.tryParse(enteredPrice));
    }
  }
  @override

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ------ COLORS FOR BOTH THEMES ------
    final dialogBg = isDark ? const Color(0xFF1A1C2A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF2B2D3C) : const Color(0xFFF2F4F7);

    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white70 : Colors.grey;

    final clearTextColor = const Color(0xFFE74C3C);
    final clearBg = isDark ? const Color(0xFF3B1F1F) : const Color(0xFFFFEDED);

    final addBg = const Color(0xFF2C3E78);
    final addText = Colors.white;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  // ---------------- PRODUCT ROW ----------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // PRODUCT IMAGE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.productImage.isNotEmpty &&
                            (widget.productImage.startsWith("http") ||
                                widget.productImage.startsWith("https"))
                            ? Image.network(
                          widget.productImage,
                          width: 75,
                          height: 75,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            "assets/Bubbas_logo.png",
                            width: 75,
                            height: 75,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Image.asset(
                          "assets/Bubbas_logo.png",
                          width: 75,
                          height: 75,
                          fit: BoxFit.cover,
                        ),
                      ),


                      const SizedBox(width: 16),

                      // PRODUCT NAME + QTY
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.productName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "(${widget.quantity} Pieces)",
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),


                  const SizedBox(height: 15),

                  // ---------------- Label ----------------
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Enter Price",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ---------------- TEXT FIELD ----------------
                  SizedBox(
                    height: 44,
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(text: enteredPrice),
                      style: TextStyle(color: textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "This product requires a custom price.",
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color:
                              isDark ? Colors.white12 : const Color(0xFFCBD3E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: addBg, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------------- KEYPAD ----------------
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.7,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return _buildKey(
                            "Clear",
                            onTap: _clear,
                            bgColor: clearBg,
                            textColor: clearTextColor,
                          );
                        } else if (index == 10) {
                          return _buildKey("0",
                              onTap: () => _onKeyTap("0"),
                              bgColor: cardBg,
                              textColor: textPrimary);
                        } else if (index == 11) {
                          return _buildKey("Add",
                              onTap: _submit,
                              bgColor: addBg,
                              textColor: addText);
                        } else {
                          return _buildKey(
                            "${index + 1}",
                            onTap: () => _onKeyTap("${index + 1}"),
                            bgColor: cardBg,
                            textColor: textPrimary,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // CLOSE BUTTON
            Positioned(
              top: 14,
              right: 14,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE74C3C),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ---------------- BUTTON WIDGET -------------------
  Widget _buildKey(
      String label, {
        required VoidCallback onTap,
        Color bgColor = const Color(0xFFF2F4F7),
        Color textColor = const Color(0xFF1A1A1A),
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}