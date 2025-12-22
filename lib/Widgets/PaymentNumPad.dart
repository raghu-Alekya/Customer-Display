import 'package:flutter/material.dart';

/// ---------------- ENUM ----------------
enum CustomTypeNumPad { payment }

/// ---------------- MAIN WIDGET ----------------
class PaymentNumPad extends StatelessWidget {
  final CustomTypeNumPad numPadType;
  final bool isDarkTheme;

  final String Function() getPaidAmount;
  final double balanceAmount;

  final Function(String) onDigitPressed;
  final VoidCallback onClearPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onPayPressed;

  /// ✅ NEW (IMPORTANT)
  final Function(double) onQuickAmountSelected;

  final bool showAddInsteadOfPay;
  final bool isLoading;

  const PaymentNumPad({
    super.key,
    required this.numPadType,
    required this.isDarkTheme,
    required this.getPaidAmount,
    required this.balanceAmount,
    required this.onDigitPressed,
    required this.onClearPressed,
    required this.onDeletePressed,
    required this.onPayPressed,
    required this.onQuickAmountSelected,
    this.showAddInsteadOfPay = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.425,
      child: Row(
        children: [
          /// 🔢 NUMBER PAD
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonHeight = (constraints.maxHeight - 24) / 4;
                final buttonWidth = (constraints.maxWidth / 3) - 8;
                final aspectRatio =
                    buttonWidth / (buttonHeight == 0 ? 1 : buttonHeight);

                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                  children: [
                    ...['7', '8', '9', '4', '5', '6', '1', '2', '3', '00', '0']
                        .map(
                          (e) => _NumKey(
                        text: e,
                        onTap: () => onDigitPressed(e),
                      ),
                    ),
                    _ClearKey(onTap: onClearPressed),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          /// 💰 QUICK AMOUNT + BACKSPACE
          Expanded(
            child: Column(
              children: [
                /// QUICK AMOUNTS
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _generate3QuickAmounts(balanceAmount)
                        .map(
                          (amount) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          child: _QuickAmountKey(
                            text: ' ${amount.toStringAsFixed(2)}',
                            onTap: () =>
                                onQuickAmountSelected(amount), // ✅ FIX
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),

                const SizedBox(height: 5),

                /// BACKSPACE
                Expanded(
                  flex: 1,
                  child: _BackspaceKey(onTap: onDeletePressed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- QUICK AMOUNT LOGIC ----------------
List<double> _generate3QuickAmounts(double balance) {
  final Set<double> values = {};

  values.add(balance);
  values.add(balance.ceilToDouble());
  values.add(((balance / 10).ceil() * 10).toDouble());

  return values.toList()..sort();
}

/// ---------------- NUMBER KEY ----------------
class _NumKey extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _NumKey({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 0.5,
            color: const Color(0xFFFE6464),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4C5F7D),
          ),
        ),
      ),
    );
  }
}

/// ---------------- QUICK AMOUNT KEY ----------------
class _QuickAmountKey extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _QuickAmountKey({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0xFFE1F8DC),
          shape: RoundedRectangleBorder(
            side: const BorderSide(
              width: 0.5,
              color: Color(0xFF518C3A),
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 3,
              offset: Offset(1, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF518C3A),
          ),
        ),
      ),
    );
  }
}

/// ---------------- CLEAR KEY ----------------
class _ClearKey extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 0.5,
            color: const Color(0xFFFF4D20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'C',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFF4D20),
          ),
        ),
      ),
    );
  }
}

/// ---------------- BACKSPACE KEY ----------------
class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 0.5,
            color: const Color(0xFF7B4597),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 4,
              offset: Offset(4, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_outlined,
          size: 30,
          color: Color(0xFF7B4597),
        ),
      ),
    );
  }
}

/// ---------------- PAY BUTTON ----------------
class _PayButton extends StatelessWidget {
  final bool isDarkTheme;
  final bool isLoading;
  final VoidCallback onTap;

  const _PayButton({
    required this.isDarkTheme,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white, // 👈 PAY text color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: const Size(200, 50),
      ),
      child: isLoading
          ? const CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      )
          : const Text(
        'PAY',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// ---------------- ADD BUTTON ----------------
class _AddButton extends StatelessWidget {
  final bool isDarkTheme;

  const _AddButton({required this.isDarkTheme});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text(
        'ADD',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}