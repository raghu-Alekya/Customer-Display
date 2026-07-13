import 'package:flutter/material.dart';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';

import '../helper.dart';

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
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final horizontalPadding = isDesktop ? 28.0 : isTablet ? 22.0 : 16.0;
    final verticalPadding = isDesktop ? 16.0 : isTablet ? 14.0 : 10.0;

    final titleFont = isDesktop ? 32.0 : isTablet ? 28.0 : 22.0;
    final subtitleFont = isDesktop ? 18.0 : isTablet ? 16.0 : 14.0;

    final qrSize = isDesktop ? 280.0 : isTablet ? 340.0 : 280.0;

    final cardPadding = isDesktop ? 20.0 : isTablet ? 16.0 : 14.0;
    final cardRadius = isDesktop ? 16.0 : isTablet ? 14.0 : 12.0;

    final buttonHeight = isDesktop ? 60.0 : isTablet ? 56.0 : 50.0;

    final spacingXS = isDesktop ? 8.0 : isTablet ? 6.0 : 4.0;
    final spacingS = isDesktop ? 16.0 : isTablet ? 54.0 : 40.0;
    final spacingM = isDesktop ? 24.0 : isTablet ? 120.0 : 160.0;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
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
                    Text(
                      'Pay with UPI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF22262C),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Scan QR code with any UPI app\nto complete payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleFont,
                        color: const Color(0xFF7D8188),
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: spacingM),

                    /// QR AREA
                    Center(
                      child: SizedBox(
                        width: qrSize,
                        height: qrSize,
                        child: Image.asset(
                          'assets/QR_code.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    SizedBox(height: spacingM),

                    /// BILL
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF5),
                        borderRadius: BorderRadius.circular(cardRadius),
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

                          SizedBox(height: spacingXS),

                          // const Divider(color: Color(0xFFBFD0E4)),

                          // SizedBox(height: spacingS),

                          _UpiRow(
                            label: 'Tax (CGST + SGST)',
                            value: _formatAmount(tax),
                          ),

                          // SizedBox(height: spacingXS),

                          const Divider(color: Color(0xFFBFD0E4)),

                          SizedBox(height: spacingXS),

                          _UpiRow(
                            label: 'Net Payable',
                            value: _formatAmount(total),
                            highlight: true,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: spacingXS),
                  ],
                ),
              ),

              /// BUTTON
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                  ),
                  child: Text(
                    'Check Payment Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop
                          ? 20
                          : isTablet
                          ? 18
                          : 16,
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
    final fontSize = Responsive.isDesktop(context)
        ? (highlight ? 20.0 : 16.0)
        : Responsive.isTablet(context)
        ? (highlight ? 28.0 : 20.0)
        : (highlight ? 18.0 : 18.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: highlight
                ? const Color(0xFF1E3E72)
                : const Color(0xFF5F738F),
            fontWeight:
            highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: highlight
                ? const Color(0xFF1E3E72)
                : const Color(0xFF5F738F),
            fontWeight:
            highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}