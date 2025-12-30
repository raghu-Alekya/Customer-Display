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

BoxDecoration neumorphicKeyDecoration(bool isDarkMode,
    {Color? lightColor, Color? darkColor}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDarkMode
          ? [
        darkColor ?? const Color(0xFF2B2C30),
        const Color(0xFF3A3B40),
      ]
          : [
        darkColor ?? const Color(0xFFD9E4F5), // edge
        lightColor ?? const Color(0xFFF6FAFF), // center
      ],
    ),
    boxShadow: isDarkMode
        ? [
      BoxShadow(
        color: Colors.black.withOpacity(0.6),
        blurRadius: 6,
        offset: const Offset(3, 3),
      ),
      BoxShadow(
        color: Colors.grey.shade800,
        blurRadius: 6,
        offset: const Offset(-2, -2),
      ),
    ]
        : const [
      BoxShadow(
        color: Color(0xFFCAD6EE),
        blurRadius: 6,
        offset: Offset(3, 3),
      ),
      BoxShadow(
        color: Colors.white,
        blurRadius: 6,
        offset: Offset(-2, -2),
      ),
    ],
  );
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),

          // 🎯 THIS creates dark edges + light center
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
              const Color(0xFF2B2C30),
              const Color(0xFF3A3B40),
            ]
                : [
              const Color(0xFFD9E4F5), // edge
              const Color(0xFFF6FAFF), // center
            ],
          ),

          boxShadow: isDarkMode
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 6,
              offset: const Offset(3, 3),
            ),
            BoxShadow(
              color: Colors.grey.shade800,
              blurRadius: 6,
              offset: const Offset(-2, -2),
            ),
          ]
              : [
            // outer depth
            const BoxShadow(
              color: Color(0xFFCAD6EE),
              blurRadius: 6,
              offset: Offset(3, 3),
            ),
            // highlight
            const BoxShadow(
              color: Colors.white,
              blurRadius: 6,
              offset: Offset(-2, -2),
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
        margin: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),

          // 🌿 Neumorphic gradient (dark edge → light center)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? const [
              Color(0xFF2F4A2F),
              Color(0xFF3F6B3F),
            ]
                : const [
              Color(0xFFDFF1DF), // edge
              Color(0xFFF4FFF1), // center
            ],
          ),

          // 🌫 Same depth as number keys
          boxShadow: isDarkMode
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 6,
              offset: const Offset(3, 3),
            ),
            BoxShadow(
              color: Colors.grey.shade800,
              blurRadius: 6,
              offset: const Offset(-2, -2),
            ),
          ]
              : const [
            BoxShadow(
              color: Color(0xFFBFD8BF),
              blurRadius: 6,
              offset: Offset(3, 3),
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 6,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? Colors.white
                : const Color(0xFF3F7F3F),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: neumorphicKeyDecoration(
          isDarkMode,
          lightColor: const Color(0xFFFFF1F1),
          darkColor: const Color(0xFFF2C6C6),
        ),
        alignment: Alignment.center,
        child: Text(
          'C',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFFD93025),
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
        margin: const EdgeInsets.all(6),
        decoration: neumorphicKeyDecoration(
          isDarkMode,
          lightColor: const Color(0xFFF6FAFF),
          darkColor: const Color(0xFFD9E4F5),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.backspace_outlined,
          size: 28,
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