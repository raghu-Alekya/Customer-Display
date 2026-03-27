import 'package:flutter/material.dart';
import 'package:keyos_app/widgets/upi_method.dart';

import 'card_method.dart';
import 'cash_method.dart';
// import 'package:keyos_app/card_method_screen.dart';
// import 'package:keyos_app/cash_method_screen.dart';
// import 'package:keyos_app/upi_method_screen.dart';

class PaymentMethods extends StatefulWidget {
  final String orderType;

  const PaymentMethods({super.key, required this.orderType});

  @override
  State<PaymentMethods> createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethods> {
  String? _selectedMethod;

  void _goToSelectedMethod() {
    if (_selectedMethod == null) return;

    Widget target;
    switch (_selectedMethod) {
      case 'card':
        target = CardMethodScreen(orderType: widget.orderType);
        break;
      case 'upi':
        target = UpiMethodScreen(orderType: widget.orderType);
        break;
      case 'cash':
      default:
        target = CashMethodScreen(orderType: widget.orderType);
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => target),
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
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 12,
                      color: Color(0xFFFF8E00),
                    ),
                    label: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF8E00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD39C)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 24 / 1.2,
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD6E0EE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: Color(0xFF5C76A3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.orderType,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4E668E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  // padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  // decoration: BoxDecoration(
                  //   color: const Color(0xFFF5F6F8),
                  //   borderRadius: BorderRadius.circular(14),
                  // ),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'Choose Payment Method',
                        style: TextStyle(
                          fontSize: 33 / 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF30353D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Select how you'd like to pay.",
                        style: TextStyle(
                          fontSize: 12 / 1.2,
                          color: Color(0xFF8B929E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _methodTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Card',
                        subtitle: 'Tap / insert / swipe',
                        selected: _selectedMethod == 'card',
                        onTap: () => setState(() => _selectedMethod = 'card'),
                      ),
                      const SizedBox(height: 10),
                      _methodTile(
                        icon: Icons.qr_code_2_outlined,
                        title: 'Scan QR',
                        subtitle: 'Scan with your phone',
                        selected: _selectedMethod == 'upi',
                        onTap: () => setState(() => _selectedMethod = 'upi'),
                      ),
                      const SizedBox(height: 10),
                      _methodTile(
                        icon: Icons.payments_outlined,
                        title: 'Cash',
                        subtitle: 'Pay at counter',
                        selected: _selectedMethod == 'cash',
                        onTap: () => setState(() => _selectedMethod = 'cash'),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7EDF7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFD0E6)),
                        ),
                        child: Column(
                          children: const [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Payment Summary',
                                  style: TextStyle(
                                    color: Color(0xFF254A84),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox.shrink(),
                              ],
                            ),
                            SizedBox(height: 10),
                            _SummaryRow(
                              label: 'Sub Total',
                              value: '\$210.00',
                            ),
                            SizedBox(height: 6),
                            _SummaryRow(
                              label: 'Tax',
                              value: '\$10.52',
                            ),
                            SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: Color(0xFFB9C9DF),
                            ),
                            SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Net Payable',
                              value: '\$220.52',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedMethod == null ? null : _goToSelectedMethod,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9900),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFC9C9C9),
                            disabledForegroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18 / 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF2E3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFFF9900) : const Color(0xFFE4E4E4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                selected ? const Color(0xFFFFE2BF) : const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? const Color(0xFFEA7B00) : const Color(0xFF515A68),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24 / 1.2,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFFEA7B00)
                          : const Color(0xFF262A31),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11 / 1.2,
                      color: Color(0xFF7D8793),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBold ? const Color(0xFF1E3E72) : const Color(0xFF4F6B9A);
    final fontWeight = isBold ? FontWeight.w700 : FontWeight.w500;
    final fontSize = isBold ? 26 / 1.2 : 15 / 1.2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}