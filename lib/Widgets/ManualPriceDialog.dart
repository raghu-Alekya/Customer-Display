import 'package:flutter/material.dart';

class ManualPriceDialog extends StatefulWidget {
  final String productName;
  final double? minPrice;

  const ManualPriceDialog({
    super.key,
    required this.productName,
    this.minPrice,
  });

  /// Helper method to show the dialog and get the result
  static Future<double?> show(BuildContext context,
      {required String productName, double? minPrice}) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualPriceDialog(
        productName: productName,
        minPrice: minPrice,
      ),
    );
  }

  @override
  State<ManualPriceDialog> createState() => _ManualPriceDialogState();
}

class _ManualPriceDialogState extends State<ManualPriceDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(
        context,
        double.parse(_controller.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Enter Price"),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Price for ${widget.productName}",
            prefixText: "₹ ",
          ),
          validator: (value) {
            final price = double.tryParse(value ?? "");
            if (price == null || price <= 0) {
              return "Enter a valid price";
            }
            if (widget.minPrice != null && price < widget.minPrice!) {
              return "Minimum price is ₹${widget.minPrice}";
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context, null),
        ),
        ElevatedButton(
          child: const Text("Add"),
          onPressed: _submit,
        ),
      ],
    );
  }
}