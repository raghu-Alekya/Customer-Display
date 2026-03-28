import 'package:flutter/material.dart';
import 'package:keyos_app/cart_manger.dart';
import 'package:keyos_app/Homescreen.dart';

class PrintReceiptScreen extends StatelessWidget {
  final double total;
  final int? orderId;

  const PrintReceiptScreen({
    super.key,
    required this.total,
    required this.orderId,
  });

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E8EA),
      body: Center(
        child: Container(
          width: 500,
          // margin: const EdgeInsets.symmetric(vertical: 16),
          // padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black, width: 10),
          ),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Text(
                'Receipt Printed',
                style: TextStyle(
                  fontSize: 35 / 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF303236),
                ),
              ),
              const SizedBox(height: 30),

              // Success circle
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8F3E4),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    color: Color(0xFFAEE6C7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 33 / 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Order ID: ',
                      style: TextStyle(color: Color(0xFF303236)),
                    ),
                    TextSpan(
                      text: orderId == null ? '--' : '#$orderId',
                      style: const TextStyle(color: Color(0xFFFF6C00)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 35 / 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Total : ',
                      style: TextStyle(color: Color(0xFF303236)),
                    ),
                    TextSpan(
                      text: _formatAmount(total),
                      style: const TextStyle(color: Color(0xFFFF6C00)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFBAC7DB)),
                ),
                child: const Text(
                  'Please proceed to the cash counter to\ncomplete your payment & Collect your Food.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15 / 1.2,
                    color: Color(0xFF36507D),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF5B5B5B)),
              const SizedBox(height: 8),
              const Text(
                'Note: Please collect your receipt',
                style: TextStyle(
                  color: Color(0xFF5C5C5C),
                  fontSize: 14,
                ),
              ),

              const Spacer(),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      CartManager.cartItems.clear();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9900),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Start New Order',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18 / 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}