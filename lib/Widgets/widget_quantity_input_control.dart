import 'package:flutter/material.dart';

class QuantityControl extends StatelessWidget {
  final TextEditingController controller;
  final int quantity;
  final Function(int) onDecrement;
  final Function(int) onIncrement;

  const QuantityControl({
    Key? key,
    required this.controller,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFFE6464),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Minus button
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () {
                if (quantity > 0) onDecrement(quantity - 1);
              },
              child: Container(
                alignment: Alignment.center,
                child: const Text(
                  "−",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Text(
                controller.text.isEmpty ? "0" : controller.text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Plus button
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () {
                onIncrement(quantity + 1);
              },
              child: Container(
                alignment: Alignment.center,
                child: const Text(
                  "+",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}