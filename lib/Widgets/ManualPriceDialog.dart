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
        productImage: "assets/Bubbas_logo.png",
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
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 550,
        ),
        child: Stack(
          children: [
            // MAIN CONTENT
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  // ------------------ FIXED TOP CONTENT ------------------
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // PRODUCT ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: widget.productImage.startsWith("http")
                                ? Image.network(
                              widget.productImage,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                                : Image.asset(
                              widget.productImage,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Product Text
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  widget.productName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "(${widget.quantity} Pieces)",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // LABEL
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          "Enter Price",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),


                      const SizedBox(height: 20),

                      // TEXT FIELD
                      SizedBox(
                        height: 40,
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(text: enteredPrice),
                          decoration: InputDecoration(
                            hintText: "This product requires a custom price.",
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD3E1),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),

                  // ------------------ KEYPAD ------------------
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return _buildKey(
                            "Clear",
                            onTap: _clear,
                            textColor: const Color(0xFFE74C3C),
                            bgColor: const Color(0xFFFFEDED),
                          );
                        } else if (index == 10) {
                          return _buildKey("0", onTap: () => _onKeyTap("0"));
                        } else if (index == 11) {
                          return _buildKey(
                            "Add",
                            onTap: _submit,
                            bgColor: const Color(0xFF2C3E78),
                            textColor: Colors.white,
                          );
                        } else {
                          return _buildKey(
                            "${index + 1}",
                            onTap: () => _onKeyTap("${index + 1}"),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ------------------ CLOSE BUTTON (ABSOLUTE POSITION) ------------------
            Positioned(
              top: 15,
              right: 15,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE74C3C),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
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