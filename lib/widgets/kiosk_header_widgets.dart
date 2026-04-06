import 'package:flutter/material.dart';

/// Canonical colors/styles for kiosk top bars — keep in sync with [PaymentMethods].
class KioskHeaderTokens {
  KioskHeaderTokens._();

  static const Color menuOrange = Color(0xFFFF8E00);
  static const Color menuBorder = Color(0xFFFFD39C);
  static const double menuFontSize = 11;
  static const double menuIconSize = 12;

  static const Color orderTypeBg = Color(0xFFEAF0FA);
  static const Color orderTypeBorder = Color(0xFFD6E0EE);
  static const Color orderTypeDot = Color(0xFF5C76A3);
  static const Color orderTypeText = Color(0xFF4E668E);
  static const double orderTypeFontSize = 10;
}

class KioskMenuBackButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const KioskMenuBackButton({
    super.key,
    this.label = 'Back',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: const Icon(
        Icons.arrow_back_ios_new,
        size: KioskHeaderTokens.menuIconSize,
        color: KioskHeaderTokens.menuOrange,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: KioskHeaderTokens.menuFontSize,
          color: KioskHeaderTokens.menuOrange,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: KioskHeaderTokens.menuBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class KioskOrderTypeChip extends StatelessWidget {
  final String orderType;

  const KioskOrderTypeChip({super.key, required this.orderType});

  @override
  Widget build(BuildContext context) {
    final text = orderType.trim().isEmpty ? 'Dine-In' : orderType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KioskHeaderTokens.orderTypeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KioskHeaderTokens.orderTypeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.circle,
            size: 6,
            color: KioskHeaderTokens.orderTypeDot,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: KioskHeaderTokens.orderTypeFontSize,
              color: KioskHeaderTokens.orderTypeText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
