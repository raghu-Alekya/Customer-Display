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
      backgroundColor: const Color(0xFFE5E7EB),
      body: Center(
        child: Container(
          width: 500,
          // margin: const EdgeInsets.symmetric(vertical: 16),
          // padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 12),
          ),
          child: Column(
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
              const SizedBox(height: 26),
              const Text(
                'Pay with UPI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22262C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan QR code with any UPI app\nto complete payment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7D8188),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8DDE6)),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 120,
                  color: Color(0xFF4F6B9A),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EEF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D3E3)),
                ),
                child: Column(
                  children: [
                    _UpiRow(label: 'Sub Total', value: _formatAmount(subtotal)),
                    SizedBox(height: 8),
                    _UpiRow(
                      label: 'Tax (CGST + SGST)',
                      value: _formatAmount(tax),
                    ),
                    SizedBox(height: 8),
                    Divider(height: 1, color: Color(0xFFBFD0E4)),
                    SizedBox(height: 8),
                    _UpiRow(
                      label: 'Net Payable',
                      value: _formatAmount(total),
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Check Payment Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
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