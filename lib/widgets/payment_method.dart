import 'package:flutter/material.dart';
import 'package:kiosk/cart_manger.dart';
import 'package:kiosk/repository/order_repository.dart';
import 'package:kiosk/widgets/kiosk_header_widgets.dart';
import 'package:kiosk/widgets/upi_method.dart';

import '../helper.dart';
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
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    final titleFont = isDesktop ? 30.0 : isTablet ? 26.0 : 22.0;
    final subTitleFont = isDesktop ? 16.0 : isTablet ? 14.0 : 12.0;
    final sectionTitleFont = isDesktop ? 16.0 : isTablet ? 15.0 : 14.0;
    final summaryFont = isDesktop ? 15.0 : isTablet ? 14.0 : 13.0;

    final spacingXS = isDesktop ? 8.0 : isTablet ? 6.0 : 4.0;
    final spacingS = isDesktop ? 14.0 : isTablet ? 12.0 : 10.0;
    final spacingM = isDesktop ? 20.0 : isTablet ? 16.0 : 12.0;

    final containerPadding = isDesktop ? 18.0 : isTablet ? 16.0 : 12.0;
    final buttonHeight = isDesktop ? 60.0 : isTablet ? 54.0 : 48.0;
    final radius = isDesktop ? 12.0 : isTablet ? 10.0 : 8.0;
    final summaryPadding = Responsive.isDesktop(context)
        ? 24.0
        : Responsive.isTablet(context)
        ? 20.0
        : 16.0;

    final summaryRadius = Responsive.isDesktop(context)
        ? 16.0
        : Responsive.isTablet(context)
        ? 14.0
        : 12.0;

    final summaryTitleFont = Responsive.isDesktop(context)
        ? 22.0
        : Responsive.isTablet(context)
        ? 18.0
        : 16.0;

    final summarySpacing = Responsive.isDesktop(context)
        ? 16.0
        : Responsive.isTablet(context)
        ? 12.0
        : 10.0;

    final dividerSpacing = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 16.0
        : 12.0;
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
                  padding: EdgeInsets.all(containerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: spacingXS),

                      Text(
                        'Choose Payment Method',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleFont,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF30353D),
                        ),
                      ),

                      SizedBox(height: spacingXS),

                      Text(
                        "Select how you'd like to pay.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subTitleFont,
                          color: const Color(0xFF8B929E),
                        ),
                      ),

                      SizedBox(height: spacingM),

                      /// PAYMENT METHODS
                      Expanded(
                        flex: 5,
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: Responsive.isDesktop(context)
                              ? 28
                              : Responsive.isTablet(context)
                              ? 22
                              : 16,
                          mainAxisSpacing: Responsive.isDesktop(context)
                              ? 28
                              : Responsive.isTablet(context)
                              ? 22
                              : 16,
                          childAspectRatio: Responsive.isDesktop(context)
                              ? 1.15
                              : Responsive.isTablet(context)
                              ? 1.2
                              : 1.05,
                          children: [

                            _methodTile(
                              imageAsset: _paymentTileAssetCard,
                              fallbackIcon: Icons.account_balance_wallet_outlined,
                              title: 'Card',
                              subtitle: 'Tap / Insert / Swipe',
                              selected: _selectedMethod == 'card',
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'card';
                                });
                              },
                            ),

                            _methodTile(
                              imageAsset: _paymentTileAssetQr,
                              fallbackIcon: Icons.qr_code_2_outlined,
                              title: 'Scan QR',
                              subtitle: 'Scan with your phone',
                              selected: _selectedMethod == 'upi',
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'upi';
                                });
                              },
                            ),

                            _methodTile(
                              imageAsset: _paymentTileAssetCash,
                              fallbackIcon: Icons.payments_outlined,
                              title: 'Cash',
                              subtitle: 'Pay at counter',
                              selected: _selectedMethod == 'cash',
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'cash';
                                });
                              },
                            ),

                            _methodTile(
                              imageAsset: "assets/wallet.png",
                              fallbackIcon: Icons.account_balance_wallet,
                              title: 'Wallet',
                              subtitle: 'Pay using Wallet',
                              selected: _selectedMethod == 'wallet',
                              onTap: () {
                                setState(() {
                                  _selectedMethod = 'wallet';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: spacingM),

                      /// PAYMENT SUMMARY
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(summaryPadding),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7EDF7),
                          borderRadius: BorderRadius.circular(summaryRadius),
                          border: Border.all(
                            color: const Color(0xFFBFD0E6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(
                              'Payment Summary',
                              style: TextStyle(
                                color: const Color(0xFF254A84),
                                fontWeight: FontWeight.bold,
                                fontSize: summaryTitleFont,
                              ),
                            ),

                            SizedBox(height: summarySpacing),

                            _SummaryRow(
                              context,
                              label: "Sub Total",
                              value: _formatAmount(widget.subtotal),
                            ),

                            SizedBox(height: summarySpacing),

                            _SummaryRow(
                              context,
                              label: "Tax",
                              value: _formatAmount(widget.tax),
                            ),

                            SizedBox(height: dividerSpacing),

                            const Divider(),

                            SizedBox(height: dividerSpacing),

                            _SummaryRow(
                              context,
                              label: "Net Payable",
                              value: _formatAmount(widget.total),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: spacingM),

                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton(
                          onPressed: _selectedMethod == null || _isCreatingOrder
                              ? null
                              : _goToSelectedMethod,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9900),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFC9C9C9),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                          child: _isCreatingOrder
                              ? SizedBox(
                            width: isDesktop ? 26 : 22,
                            height: isDesktop ? 26 : 22,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : Text(
                            "Confirm Payment",
                            style: TextStyle(
                              fontSize: isDesktop
                                  ? 20
                                  : isTablet
                                  ? 18
                                  : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
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
    final imageSize = Responsive.isDesktop(context)
        ? 100.0
        : Responsive.isTablet(context)
        ? 150.0
        : 120.0;

    final titleFont = Responsive.isDesktop(context)
        ? 20.0
        : Responsive.isTablet(context)
        ? 18.0
        : 16.0;

    final subtitleFont = Responsive.isDesktop(context)
        ? 15.0
        : Responsive.isTablet(context)
        ? 14.0
        : 12.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF5B1A)
                : const Color(0xFFF4E3D8),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [

            /// Check Icon
            if (selected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5B1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

            /// Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    /// Image FIRST
                    Image.asset(
                      imageAsset,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 18),

                    /// Title BELOW image
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// Subtitle BELOW title
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleFont,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _SummaryRow(
    BuildContext context, {
      required String label,
      required String value,
      bool isBold = false,
    }) {
  final fontSize = Responsive.isDesktop(context)
      ? (isBold ? 26.0 : 20.0)
      : Responsive.isTablet(context)
      ? (isBold ? 22.0 : 18.0)
      : (isBold ? 24.0 : 16.0);

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: isBold
              ? const Color(0xFF254A84)
              : Colors.black,
        ),
      ),
    ],
  );
}