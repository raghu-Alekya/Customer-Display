import 'package:flutter/material.dart';
import 'dart:async';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import '../helper.dart';
import '../repository/card_payment_repository.dart';
import '../utils/printer_helper.dart';
import 'cash_receipt.dart';

class CardMethodScreen extends StatefulWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;
  final int orderId;
  final String token;

  const CardMethodScreen({
    super.key,
    required this.orderId,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.token,
  });

  @override
  State<CardMethodScreen> createState() => _CardMethodScreenState();
}

class _CardMethodScreenState extends State<CardMethodScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isProcessing = false;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _processCardPayment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_paymentCompleted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  Future<void> _processCardPayment() async {
    if (_isProcessing || _paymentCompleted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final repo = CardPaymentRepository();
      final response = await repo.createCardPayment(
        orderId: widget.orderId,
        amount: widget.total,
      );

      if (mounted) {
        if (response['status'] == 'success') {
          setState(() {
            _paymentCompleted = true;
            _isProcessing = false;
          });

          _timer?.cancel();
          final int orderId =
              (response['order_id'] as num?)?.toInt() ?? widget.orderId;
          debugPrint("widget.orderId = ${widget.orderId}");
          debugPrint("response.order_id = ${response['order_id']}");

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PrintReceiptScreen(
                total: widget.total,
                orderId: orderId,
                isCardPayment: true,
                onPrintReceipt: (ctx) async {
                  final bytes = await buildCashReceiptBytes(
                    orderType: widget.orderType,
                    subtotal: widget.subtotal,
                    tax: widget.tax,
                    total: widget.total,
                    orderId: widget.orderId,
                    token: widget.token,
                  );

                  // ✅ Use the PrintReceiptScreen context, not CardMethodScreen context
                  await printReceiptForSelectedType(bytes, ctx);
                },
              ),
            ),
          );
        } else {
          _showPaymentError(response['message'] ?? 'Payment Failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showPaymentError(e.toString());
      }
    } finally {
      if (mounted && !_paymentCompleted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPaymentError(String message) {
    _timer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Payment Failed',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _elapsedSeconds = 0;
                  _paymentCompleted = false;
                  _isProcessing = false;
                });
                _startTimer();
                _processCardPayment();
              },
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final horizontalPadding = isDesktop ? 28.0 : isTablet ? 22.0 : 16.0;
    final verticalPadding = isDesktop ? 16.0 : isTablet ? 14.0 : 10.0;

    final amountFont = isDesktop ? 54.0 : isTablet ? 46.0 : 38.0;
    final titleFont = isDesktop ? 24.0 : isTablet ? 20.0 : 18.0;
    final bodyFont = isDesktop ? 18.0 : isTablet ? 16.0 : 14.0;

    final cardImageWidth = isDesktop ? 360.0 : isTablet ? 420.0 : 370.0;
    final cardImageHeight = isDesktop ? 180.0 : isTablet ? 560.0 : 420.0;

    final timerFont = isDesktop ? 42.0 : isTablet ? 36.0 : 30.0;

    final buttonRadius = isDesktop ? 14.0 : isTablet ? 12.0 : 10.0;

    final spacingXS = isDesktop ? 8.0 : isTablet ? 6.0 : 4.0;
    final spacingS = isDesktop ? 18.0 : isTablet ? 14.0 : 10.0;
    final spacingM = isDesktop ? 28.0 : isTablet ? 22.0 : 16.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            children: [
              // Header with back button and order type
              Row(
                children: [
                  KioskMenuBackButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  KioskOrderTypeChip(orderType: widget.orderType),
                ],
              ),

              SizedBox(height: spacingS),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Payment Amount
                    Text(
                      _formatAmount(widget.total),
                      style: TextStyle(
                        fontSize: amountFont,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF22262C),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tap or Insert your Card',
                      style: TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7D8188),
                      ),
                    ),

                    SizedBox(height: spacingM),

                    // Card Image
                    SizedBox(
                      width: cardImageWidth,
                      height: cardImageHeight,
                      child: Image.asset(
                        'assets/card.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    SizedBox(height: spacingM),

                    // Timer Section - Shows elapsed time
                    if (_isProcessing)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 30 : isTablet ? 24 : 18,
                          vertical: isDesktop ? 22 : isTablet ? 18 : 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Processing Time:',
                              style: TextStyle(
                                fontSize: bodyFont,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF5F738F),
                              ),
                            ),
                            SizedBox(height: spacingM),
                            Text(
                              '${_elapsedSeconds}s',
                              style: TextStyle(
                                fontSize: timerFont,
                                fontWeight: FontWeight.w700,
                                color: _elapsedSeconds >= 30 ? Colors.orange : const Color(0xFF1E3E72),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: spacingM),

                    // If not working message - only show when not processing
                    if (!_isProcessing)
                      TextButton(
                        onPressed: () {
                          _showPaymentOptions();
                        },
                        child: Text(
                          'If not working, try again or choose another payment method',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: bodyFont,
                            color: const Color(0xFF7D8188),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    if (_isProcessing && !_paymentCompleted)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFFFF9900),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Processing payment...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7D8188),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Payment Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Color(0xFFFF9900)),
                title: const Text('Try Card Payment Again'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _elapsedSeconds = 0;
                    _paymentCompleted = false;
                    _isProcessing = false;
                  });
                  _timer?.cancel();
                  _startTimer();
                  _processCardPayment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.money, color: Color(0xFFFF9900)),
                title: const Text('Pay with Cash'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  // Navigate to cash payment screen
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}