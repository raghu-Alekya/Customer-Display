import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pinaka_pos/Widgets/widget_quantity_input_control.dart';
import 'package:provider/provider.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Widgets/widget_custom_num_pad.dart';
class EditProduct extends StatefulWidget {
  final Map<String, dynamic> orderItem;
  final Function(int) onQuantityUpdated;
  final bool isDialog;

  const EditProduct({
    Key? key,
    required this.orderItem,
    required this.onQuantityUpdated,
    this.isDialog = false,
  }) : super(key: key);

  @override
  _EditProductState createState() => _EditProductState();
}

class _EditProductState extends State<EditProduct> {
  late TextEditingController controller;
  late int quantity;
  late double _regularPrice;

  @override
  void initState() {
    super.initState();

    quantity = widget.orderItem[AppDBConst.itemCount] ?? 1;

    var item = widget.orderItem;

    _regularPrice =
    (item[AppDBConst.itemRegularPrice] == null ||
        (item[AppDBConst.itemRegularPrice]?.toDouble() ?? 0.0) == 0.0)
        ? item[AppDBConst.itemUnitPrice]?.toDouble() ?? 0.0
        : item[AppDBConst.itemRegularPrice]!.toDouble();

    controller = TextEditingController(text: quantity.toString());
  }

  // ✅ FIXED update quantity logic
  void updateQuantity(int newQuantity) {
    if (newQuantity < 0) newQuantity = 0;
    if (newQuantity > 99) newQuantity = 99;

    setState(() {
      quantity = newQuantity;
      controller.text = quantity.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;

    final width = widget.isDialog
        ? MediaQuery.of(context).size.width * 0.28
        : MediaQuery.of(context).size.width * 0.65;

    final height = widget.isDialog
        ? MediaQuery.of(context).size.height * 0.68
        : MediaQuery.of(context).size.height * 0.9;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.fromLTRB(20, 23, 20, 0),
          decoration: BoxDecoration(
            color: isDark ? ThemeNotifier.primaryBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(150)
                    : Colors.black.withAlpha(38),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? ThemeNotifier.secondaryBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? ThemeNotifier.borderColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProductImage(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.orderItem[AppDBConst.itemName],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${TextConstants.currencySymbol}${_regularPrice.toStringAsFixed(2)} ($quantity Item)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Total : ${TextConstants.currencySymbol}${(quantity * _regularPrice).toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 29,
                      height: 29,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              QuantityControl(
                controller: controller,
                quantity: quantity,
                onDecrement: (q) => updateQuantity(q),
                onIncrement: (q) => updateQuantity(q),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: CustomNumPad(
                  isDarkTheme: isDark,

                  // ✅ FIXED NUMPAD LOGIC
                  onDigitPressed: (digit) {
                    String current = controller.text;

                    // If current = 0 → replace value
                    if (current == "0") {
                      updateQuantity(int.parse(digit));
                      return;
                    }

                    // Append digit but limit to 2 digits (0–99)
                    String newValue = current + digit;

                    int newQty = int.tryParse(newValue) ?? quantity;

                    updateQuantity(newQty);
                  },

                  onClearPressed: () => updateQuantity(0),

                  onAddPressed: quantity > 0
                      ? () {
                    widget.onQuantityUpdated(quantity);
                    Navigator.pop(context);
                  }
                      : null,

                  actionButtonType: ActionButtonType.add,
                  gridPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    final img = widget.orderItem[AppDBConst.itemImage]?.toString() ?? "";

    if (img.isEmpty) {
      return Image.asset(
        'assets/custom.png',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
      );
    }

    // HTTP IMAGE
    if (img.startsWith('http')) {
      return Image.network(
        img,
        width: 65,
        height: 65,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset('assets/custom.png', width: 65, height: 65);
        },
      );
    }

    // ASSETS IMAGE: PNG / JPG / SVG
    if (img.startsWith('assets/')) {
      if (img.endsWith('.svg')) {
        return SvgPicture.asset(img, width: 65, height: 65, fit: BoxFit.cover);
      } else {
        return Image.asset(img, width: 65, height: 65, fit: BoxFit.cover);
      }
    }

    // LOCAL FILE PATH
    if (File(img).existsSync()) {
      return Image.file(File(img), width: 65, height: 65, fit: BoxFit.cover);
    }

    // FALLBACK
    return Image.asset('assets/custom.png', width: 65, height: 65);
  }

}