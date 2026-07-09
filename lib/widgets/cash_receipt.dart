import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiosk/cart_manger.dart';
import 'package:kiosk/Homescreen.dart';

import '../bloc/product_bloc.dart';

class PrintReceiptScreen extends StatefulWidget {
  final double total;
  final int? orderId;
  final bool isCardPayment;
  final Future<void> Function(BuildContext context)? onPrintReceipt;

  const PrintReceiptScreen({
    super.key,
    required this.total,
    required this.orderId,
    this.isCardPayment = false,
    this.onPrintReceipt,
  });

  @override
  State<PrintReceiptScreen> createState() => _PrintReceiptScreenState();
}
class _PrintReceiptScreenState extends State<PrintReceiptScreen> {
  bool _isPrinting = false;
  @override
  void initState() {
    super.initState();
    debugPrint("PrintReceiptScreen orderId = ${widget.orderId}");
  }

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  void _startNewOrder(BuildContext context) {
    CartManager.cartItems.clear();
    context.read<ProductBloc>().add(const ResetProducts());

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Receipt Printed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 35 / 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF303236),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD8F3E4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 112,
                                height: 112,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Order ID: ',
                              style: TextStyle(
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: '#${widget.orderId}',
                              style: const TextStyle(
                                color: Color(0xFFFF6900), // #FF6900
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
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
                              text: _formatAmount(widget.total),
                              style: const TextStyle(color: Color(0xFFFF6C00)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!widget.isCardPayment)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
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
                      const Center(
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: Color(0xFF5B5B5B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Please collect your receipt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF5C5C5C),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isCardPayment)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          CartManager.cartItems.clear();

                          context.read<ProductBloc>().add(const ResetProducts());

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                                (route) => false,
                          );
                        },
                        child: const Text(
                          "Start New Order",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF9900),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (widget.isCardPayment && _isPrinting)
                          ? null
                          : () async {
                        if (widget.isCardPayment) {
                          setState(() => _isPrinting = true);

                          try {
                            if (widget.onPrintReceipt != null) {
                              await widget.onPrintReceipt!(context);
                            }
                            // Keep button disabled after successful print
                          } catch (e) {
                            setState(() => _isPrinting = false);
                          }
                        } else {
                          _startNewOrder(context);
                        }
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
                      child: _isPrinting
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        widget.isCardPayment
                            ? "Print Receipt"
                            : "Start New Order",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}