import 'package:flutter/material.dart';
import 'dart:async';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import '../repository/card_payment_repository.dart';
import 'cash_receipt.dart';

class CardMethodScreen extends StatefulWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;
  final int orderId;

  const CardMethodScreen({
    super.key,
    required this.orderId,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
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

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PrintReceiptScreen(
                total: widget.total,
                orderId: widget.orderId,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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

              const SizedBox(height: 16),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Payment Amount
                    Text(
                      _formatAmount(widget.total),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22262C),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Tap or Insert your Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7D8188),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Card Image
                    SizedBox(
                      width: 200,
                      height: 140,
                      child: Image.asset(
                        'assets/card.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Timer Section - Shows elapsed time
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Processing Time:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF5F738F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_elapsedSeconds}s',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: _elapsedSeconds >= 30 ? Colors.orange : const Color(0xFF1E3E72),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // If not working message - only show when not processing
                    if (!_isProcessing)
                      TextButton(
                        onPressed: () {
                          _showPaymentOptions();
                        },
                        child: const Text(
                          'If not working, try again or choose another payment method',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7D8188),
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