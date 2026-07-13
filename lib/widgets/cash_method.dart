import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kiosk/Homescreen.dart';
import 'package:kiosk/cart_manger.dart';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import 'package:kiosk/widgets/printer_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper.dart';
import '../repository/store_details_repository.dart';
import '../utils/printer_helper.dart';
import 'cash_receipt.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' as esc;
import 'package:thermal_printer/thermal_printer.dart';
import 'package:image/image.dart' as img;

class CashMethodScreen extends StatefulWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;
  final int? orderId;

  const CashMethodScreen({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.orderId,
  });

  @override
  State<CashMethodScreen> createState() => _CashMethodScreenState();
}

class _CashMethodScreenState extends State<CashMethodScreen> {
  bool _isPrinting = false;

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  int get _itemCount {
    return CartManager.cartItems.fold<int>(0, (sum, item) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      return sum + qty;
    });
  }

  Future<void> cacheLogo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'store_logo',
          base64Encode(response.bodyBytes),
        );
      }
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final screenWidth = Responsive.w(context);

    final horizontalPadding = isDesktop ? 28.0 : isTablet ? 22.0 : 16.0;
    final verticalPadding = isDesktop ? 16.0 : isTablet ? 14.0 : 10.0;

    final titleFont = isDesktop ? 30.0 : isTablet ? 26.0 : 22.0;
    final subTitleFont = isDesktop ? 18.0 : isTablet ? 16.0 : 14.0;

    final summaryTitleFont = isDesktop ? 18.0 : isTablet ? 16.0 : 15.0;
    final summaryFont = isDesktop ? 16.0 : isTablet ? 15.0 : 13.0;

    final imageHeight = isDesktop ? 330.0 : isTablet ? 450.0 : 260.0;

    final buttonHeight = isDesktop ? 60.0 : isTablet ? 56.0 : 50.0;

    final radius = isDesktop ? 14.0 : isTablet ? 12.0 : 10.0;

    final spacingXS = isDesktop ? 8.0 : isTablet ? 6.0 : 4.0;
    final spacingS = isDesktop ? 16.0 : isTablet ? 14.0 : 10.0;
    final spacingM = isDesktop ? 24.0 : isTablet ? 20.0 : 16.0;
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
              Row(
                children: [
                  KioskMenuBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  KioskOrderTypeChip(orderType: widget.orderType),
                ],
              ),
              SizedBox(height: spacingM),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pay Cash at Counter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleFont,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF22262C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take the printed receipt and pay at the\ncounter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subTitleFont,
                          color: const Color(0xFF7D8188),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: imageHeight,
                        child: Image.asset(
                          'assets/printreceipt.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 72),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                          isDesktop ? 18 : isTablet ? 26 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(color: const Color(0xFFC7D3E3)),
                        ),
                        child: Column(
                          children: [
                            _CashRow(
                              title: 'Items   -',
                              value: _itemCount.toString().padLeft(2, '0'),
                              valueBold: false,
                              header: true,
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Sub Total',
                              value: _formatAmount(widget.subtotal),
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Tax ',
                              value: _formatAmount(widget.tax),
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Net Payable',
                              value: _formatAmount(widget.total),
                              valueBold: true,
                              emphasizeTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              contentPadding: const EdgeInsets.all(20),
                              content: SizedBox(
                                width: 300,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Cancel Payment",
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    const Text(
                                      "This will stop your current payment you may need to restart your order.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    Image.asset(
                                      "assets/cancel_payment.png",
                                      height: 140,
                                    ),

                                    const SizedBox(height: 28),

                                    SizedBox(
                                      width: double.infinity,
                                      height: buttonHeight,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF9800),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                        },
                                        child: const Text(
                                          "No, Continue Payment",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFFFF9800),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          CartManager.cartItems.clear();

                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const HomeScreen(),
                                            ),
                                                (route) => false,
                                          );
                                        },
                                        child: const Text(
                                          "Yes, Cancel Order",
                                          style: TextStyle(
                                            color: Color(0xFFFF9800),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Start New Order',
                          style: TextStyle(
                            color: Color(0xFFFFA640),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFA640),
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPrinting
                      ? null // disables button
                      : () async {
                    setState(() => _isPrinting = true);

                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token') ?? '';

                      final bytes = await buildCashReceiptBytes(
                        orderType: widget.orderType,
                        subtotal: widget.subtotal,
                        tax: widget.tax,
                        total: widget.total,
                        orderId: widget.orderId,
                        token: token, // ✅ now defined
                      );

                      if (!context.mounted) return;

                      final ok = await printReceiptForSelectedType(bytes, context);

                      if (!context.mounted || !ok) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrintReceiptScreen(
                            total: widget.total,
                            orderId: widget.orderId,
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isPrinting = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 18 : isTablet ? 16 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isPrinting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    'Print Receipt',
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

class _CashRow extends StatelessWidget {
  final String title;
  final String value;
  final bool valueBold;
  final bool header;
  /// Larger type for the final total line (e.g. Net Payable).
  final bool emphasizeTotal;

  const _CashRow({
    required this.title,
    required this.value,
    this.valueBold = false,
    this.header = false,
    this.emphasizeTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final bodySize = Responsive.isDesktop(context)
        ? (emphasizeTotal ? 22.0 : 16.0)
        : Responsive.isTablet(context)
        ? (emphasizeTotal ? 20.0 : 15.0)
        : (emphasizeTotal ? 18.0 : 14.0);
    final titleStyle = TextStyle(
      fontSize: header
          ? (Responsive.isDesktop(context) ? 16 : 14)
          : bodySize,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: header
          ? FontWeight.w500
          : (emphasizeTotal ? FontWeight.w600 : FontWeight.w500),
    );

    final valueStyle = TextStyle(
      fontSize: header
          ? (Responsive.isDesktop(context) ? 16 : 14)
          : bodySize,
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