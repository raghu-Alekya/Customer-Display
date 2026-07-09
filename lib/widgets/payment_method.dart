import 'package:flutter/material.dart';
import 'package:kiosk/cart_manger.dart';
import 'package:kiosk/repository/order_repository.dart';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import 'package:kiosk/widgets/upi_method.dart';

import 'card_method.dart';
import 'cash_method.dart';

/// PNGs in `assets/` — rename these constants to match your filenames.
const String _paymentTileAssetCard = 'assets/card_payment.png';
const String _paymentTileAssetQr = 'assets/QRcode.png';
const String _paymentTileAssetCash = 'assets/cash.png';

class PaymentMethods extends StatefulWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;

  const PaymentMethods({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  @override
  State<PaymentMethods> createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethods> {
  String? _selectedMethod;
  final OrderRepository _orderRepository = OrderRepository();
  bool _isCreatingOrder = false;

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  bool get _isDineInOrder =>
      widget.orderType.toLowerCase().replaceAll('-', ' ').contains('dine in');

  bool get _isTakeAwayOrder {
    final normalized = widget.orderType
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.contains('take out') ||
        normalized.contains('takeaway') ||
        normalized.contains('take away');
  }

  int? _extractOrderId(Map<String, dynamic> orderResponse) {
    final topId = orderResponse['id'];
    if (topId is num && topId.toInt() > 0) return topId.toInt();

    final topOrderId = orderResponse['order_id'];
    if (topOrderId is num && topOrderId.toInt() > 0) return topOrderId.toInt();

    final data = orderResponse['data'];
    if (data is Map<String, dynamic>) {
      final dataId = data['id'];
      if (dataId is num && dataId.toInt() > 0) return dataId.toInt();

      final dataOrderId = data['order_id'];
      if (dataOrderId is num && dataOrderId.toInt() > 0) {
        return dataOrderId.toInt();
      }
    }
    return null;
  }

  Future<void> _goToSelectedMethod() async {
    if (_selectedMethod == null || _isCreatingOrder) return;

    setState(() => _isCreatingOrder = true);

    try {
      Map<String, dynamic>? orderResponse;
      if (_isDineInOrder) {
        orderResponse = await _orderRepository.createDineInOrder(
          cartItems: CartManager.cartItems,
        );
      } else if (_isTakeAwayOrder) {
        orderResponse = await _orderRepository.createTakeAwayOrder(
          cartItems: CartManager.cartItems,
        );
      }
      final createdOrderId =
      orderResponse == null ? null : _extractOrderId(orderResponse);

      if (_selectedMethod == 'cash') {
        if (createdOrderId == null) {
          throw Exception('Unable to read order id for cash payment.');
        }
        await _orderRepository.createCashPayment(
          orderId: createdOrderId,
          amount: widget.total,
        );
      } else if (_selectedMethod == 'card') {
        if (createdOrderId == null) {
          throw Exception('Unable to read order id for card payment.');
        }
        await _orderRepository.createCardPayment(
          orderId: createdOrderId,
          amount: widget.total,
        );
      }

      Widget target;
      switch (_selectedMethod) {
        case 'card':
          target = CardMethodScreen(
            orderType: widget.orderType,
            subtotal: widget.subtotal,
            tax: widget.tax,
            total: widget.total,
            orderId: createdOrderId!,
            token: '',

          );
          break;
        case 'upi':
          target = UpiMethodScreen(
            orderType: widget.orderType,
            subtotal: widget.subtotal,
            tax: widget.tax,
            total: widget.total,
          );
          break;
        case 'cash':
        default:
          target = CashMethodScreen(
            orderType: widget.orderType,
            subtotal: widget.subtotal,
            tax: widget.tax,
            total: widget.total,
            orderId: createdOrderId,
          );
          break;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create order: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
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
                  KioskMenuBackButton(
                    onPressed: () => Navigator.pop(context),
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
                  KioskOrderTypeChip(orderType: widget.orderType),
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
                        imageAsset: _paymentTileAssetCard,
                        fallbackIcon: Icons.account_balance_wallet_outlined,
                        title: 'Card',
                        subtitle: 'Tap / insert / swipe',
                        selected: _selectedMethod == 'card',
                        onTap: () => setState(() => _selectedMethod = 'card'),
                      ),
                      const SizedBox(height: 10),
                      _methodTile(
                        imageAsset: _paymentTileAssetQr,
                        fallbackIcon: Icons.qr_code_2_outlined,
                        title: 'Scan QR',
                        subtitle: 'Scan with your phone',
                        selected: _selectedMethod == 'upi',
                        onTap: () => setState(() => _selectedMethod = 'upi'),
                      ),
                      const SizedBox(height: 10),
                      _methodTile(
                        imageAsset: _paymentTileAssetCash,
                        fallbackIcon: Icons.payments_outlined,
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
                          children: [
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
                              value: _formatAmount(widget.subtotal),
                            ),
                            SizedBox(height: 6),
                            _SummaryRow(
                              label: 'Tax ',
                              value: _formatAmount(widget.tax),
                            ),
                            SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: Color(0xFFB9C9DF),
                            ),
                            SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Net Payable',
                              value: _formatAmount(widget.total),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                          _selectedMethod == null || _isCreatingOrder
                              ? null
                              : _goToSelectedMethod,
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
                          child: _isCreatingOrder
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
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
    required String imageAsset,
    required IconData fallbackIcon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final iconColor =
        selected ? const Color(0xFFEA7B00) : const Color(0xFF515A68);
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
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    fallbackIcon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
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