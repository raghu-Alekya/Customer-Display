import 'package:flutter/material.dart';

import 'cash_receipt.dart';
// import 'package:keyos_app/cash_receipt_screen.dart';

class CashMethodScreen extends StatelessWidget {
  final String orderType;

  const CashMethodScreen({super.key, required this.orderType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: Center(
        child: Container(
          width: 500,
          // margin: const EdgeInsets.symmetric(vertical: 16),
          // padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 12),
          ),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 12,
                      color: Color(0xFFFF9900),
                    ),
                    label: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFFFF9900),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD08A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD3DDEB)),
                    ),
                    child: Text(
                      orderType,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5D78A5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const Text(
                'Pay Cash at Counter',
                style: TextStyle(
                  fontSize: 29 / 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22262C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take the printed receipt and pay at the\ncounter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16 / 1.2,
                  color: Color(0xFF7D8188),
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 24),

              // illustration placeholder / image
              SizedBox(
                height: 120,
                child: Image.asset(
                  'assets/printreceipt.png', // replace with your asset
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.point_of_sale_rounded,
                    size: 90,
                    color: Color(0xFF7C8DA6),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Bill card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EEF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D3E3)),
                ),
                child: Column(
                  children: const [
                    _CashRow(
                      title: 'Items   -',
                      value: '04',
                      valueBold: false,
                      header: true,
                    ),
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(title: 'Sub Total', value: '\$210.00'),
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(title: 'Tax', value: '\$10.52'),
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(
                      title: 'Net Payable',
                      value: '\$220.52',
                      valueBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {},
                child: const Text(
                  'Start New Order',
                  style: TextStyle(
                    color: Color(0xFFFFA640),
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrintReceiptScreen(),
                        ),
                      );
                    },
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
                      'Print Receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18 / 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final String title;
  final String value;
  final bool valueBold;
  final bool header;

  const _CashRow({
    required this.title,
    required this.value,
    this.valueBold = false,
    this.header = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: header ? 12 : 11,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: header ? FontWeight.w500 : FontWeight.w500,
    );

    final valueStyle = TextStyle(
      fontSize: header ? 12 : 11,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
    );

    if (header) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E568D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: titleStyle),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: titleStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFFBFD0E4),
    );
  }
}