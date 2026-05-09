import 'package:flutter/material.dart';
import 'package:keyos_app/widgets/kiosk_header_widgets.dart';

class CardMethodScreen extends StatelessWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;

  const CardMethodScreen({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  String _formatAmount(double amount) => '\$ ${amount.toStringAsFixed(2)}';



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
              Row(
                children: [
                  KioskMenuBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  KioskOrderTypeChip(orderType: orderType),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pay by Card',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22262C),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Tap, insert, or swipe your card\nto complete payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF7D8188),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: Image.asset(
                        'assets/card.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFC7D3E3),
                        ),
                      ),
                      child: Column(
                        children: [
                          _MethodRow(
                            label: 'Sub Total',
                            value: _formatAmount(subtotal),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFBFD0E4)),
                          const SizedBox(height: 10),
                          _MethodRow(
                            label: 'Tax (CGST + SGST)',
                            value: _formatAmount(tax),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFBFD0E4)),
                          const SizedBox(height: 10),
                          _MethodRow(
                            label: 'Net Payable',
                            value: _formatAmount(total),
                            highlight: true,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pay Now',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
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

class _MethodRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MethodRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? const Color(0xFF1E3E72) : const Color(0xFF5F738F),
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF1E3E72) : const Color(0xFF5F738F),
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}