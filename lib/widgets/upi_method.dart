import 'package:flutter/material.dart';
import 'package:keyos_app/widgets/kiosk_header_widgets.dart';

class UpiMethodScreen extends StatelessWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;

  const UpiMethodScreen({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';


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
              /// HEADER
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
                      'Pay with UPI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22262C),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Scan QR code with any UPI app\nto complete payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF7D8188),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// QR AREA
                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: Image.asset(
                        'assets/QR_code.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// BILL
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
                          _UpiRow(
                            label: 'Sub Total',
                            value: _formatAmount(subtotal),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFBFD0E4)),
                          const SizedBox(height: 10),
                          _UpiRow(
                            label: 'Tax (CGST + SGST)',
                            value: _formatAmount(tax),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFFBFD0E4)),
                          const SizedBox(height: 10),
                          _UpiRow(
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

              /// BUTTON
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
                    'Check Payment Status',
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

class _UpiRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _UpiRow({
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