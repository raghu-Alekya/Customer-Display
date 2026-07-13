import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiosk/cart_manger.dart';
import 'package:kiosk/Homescreen.dart';

import '../bloc/product_bloc.dart';
import '../helper.dart';

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
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final horizontalPadding = isDesktop ? 30.0 : isTablet ? 24.0 : 16.0;
    final verticalPadding = isDesktop ? 16.0 : isTablet ? 44.0 : 30.0;

    final titleFont = isDesktop ? 34.0 : isTablet ? 30.0 : 24.0;
    final orderFont = isDesktop ? 30.0 : isTablet ? 30.0 : 28.0;
    final amountFont = isDesktop ? 34.0 : isTablet ? 34.0 : 28.0;
    final normalFont = isDesktop ? 18.0 : isTablet ? 20.0 : 18.0;
    final smallFont = isDesktop ? 16.0 : isTablet ? 14.0 : 12.0;

    final circleOuter = isDesktop ? 600.0 : isTablet ? 300.0 : 320.0;
    final circleInner = isDesktop ? 530.0 : isTablet ? 315.0 : 410.0;
    final checkIcon = isDesktop ? 72.0 : isTablet ? 90.0 : 78.0;

    final buttonHeight = isDesktop ? 58.0 : isTablet ? 54.0 : 50.0;

    final radius = isDesktop ? 24.0 : isTablet ? 20.0 : 16.0;

    final spacingXS = isDesktop ? 10.0 : isTablet ? 8.0 : 6.0;
    final spacingS = isDesktop ? 18.0 : isTablet ? 14.0 : 10.0;
    final spacingM = isDesktop ? 30.0 : isTablet ? 104.0 : 58.0;
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
              Text(
                'Receipt Printed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFont,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF303236),
                ),
              ),
          SizedBox(height: spacingM),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: circleOuter,
                          height: circleOuter,
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
                                width: circleInner,
                                height: circleInner,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.check_rounded,
                                  size: checkIcon,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                SizedBox(height: spacingM),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: orderFont,
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
                SizedBox(height: spacingS),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: amountFont,
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
                  SizedBox(height: spacingM),
                      if (!widget.isCardPayment)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 20 : isTablet ? 16 : 12,
                            vertical: isDesktop ? 16 : isTablet ? 14 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0F8),
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: const Color(0xFFBAC7DB)),
                          ),
                          child: Text(
                            'Please proceed to the cash counter to\ncomplete your payment & Collect your Food.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: normalFont,
                              color: const Color(0xFF36507D),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
        SizedBox(height: spacingM),
                      Center(
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: isDesktop ? 54 : isTablet ? 46 : 38,
                          color: const Color(0xFF5B5B5B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: Please collect your receipt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF5C5C5C),
                          fontSize: smallFont,
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
                        child: Text(
                          "Start New Order",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: normalFont,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF9900),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: spacingS),

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
                        minimumSize: Size(double.infinity, buttonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: normalFont,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          SizedBox(height: spacingM),
            ],
          ),
        ),
      ),
    );
  }
}