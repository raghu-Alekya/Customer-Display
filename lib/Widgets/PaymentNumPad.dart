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
                    _BackspaceKey(onTap: onDeletePressed),
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
                            text: '\$${amount.toStringAsFixed(2)}',
                            onTap: () => onQuickAmountSelected(amount),
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
                  child: _ClearKey(onTap: onClearPressed),
                  // child: _BackspaceKey(onTap: onDeletePressed),
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
  // Always start with the base balance
  final List<double> values = [];

  // First quick amount = exact balance
  values.add(balance);

  // Second quick amount = ceiling of balance (rounded up)
  values.add(balance.ceilToDouble());

  // Third quick amount = next nearest 10
  values.add(((balance / 10).ceil() * 10).toDouble());

  // In case there are duplicates, tweak slightly to ensure 3 unique values
  for (int i = 0; i < values.length; i++) {
    for (int j = i + 1; j < values.length; j++) {
      if (values[i] == values[j]) {
        values[j] += 1; // small adjustment to make it unique
      }
    }
  }

  values.sort();
  return values;
}


/// ---------------- NUMBER KEY ----------------
class _NumKey extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _NumKey({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: ShapeDecoration(
          color: isDarkMode
              ? const Color(0xFF303136)
              : const Color(0xFFEDF1F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadows: isDarkMode
              ? [
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFF34363F).withOpacity(0.5),
              offset: const Offset(4, 4),
              blurRadius: 3,
            ),
            // 🌘 Top-left highlight
            BoxShadow(
              color: Colors.white.withOpacity(0.05),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ]
              : const [
            // 🌤 Top-left highlight
            BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 6,
            ),
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFFD9E6FF),
              offset: Offset(4, 4),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withOpacity(0.9)
                : const Color(0xFF0C3952),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: isDarkMode ? const Color(0xFF354D2F) : const Color(0xFFE5FFDD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF518C3A),
          ),
        ),
      ),
    );
  }
}

/// ---------------- CLEAR KEY ----------------
class _ClearKey extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearKey({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: ShapeDecoration(
          color: isDarkMode
              ? const Color(0xFF872727)
              : const Color(0xFFFFDADA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          shadows: isDarkMode
              ? [
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFFD40D0D).withOpacity(0.4),
              offset: const Offset(4, 4),
              blurRadius: 3,
            ),
            // 🌘 Top-left highlight
            BoxShadow(
              color: Colors.white.withOpacity(0.08),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ]
              : const [
            // 🌤 Top-left highlight
            BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 4,
            ),
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFFFFCCCC),
              offset: Offset(4, 4),
              blurRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'C',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? Colors.white
                : const Color(0xFFFF4D20),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: ShapeDecoration(
          color: isDarkMode
              ? const Color(0xFF303136)
              : const Color(0xFFEDF1F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadows: isDarkMode
              ? [
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFF34363F).withOpacity(0.5),
              offset: const Offset(4, 4),
              blurRadius: 3,
            ),
            // 🌘 Top-left highlight
            BoxShadow(
              color: Colors.white.withOpacity(0.05),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ]
              : const [
            // 🌤 Top-left highlight
            BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 6,
            ),
            // 🌑 Bottom-right shadow
            BoxShadow(
              color: Color(0xFFD9E6FF),
              offset: Offset(4, 4),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.backspace_outlined,
          size: 30,
          color: isDarkMode ? Colors.white : const Color(0xFF0C3952),
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