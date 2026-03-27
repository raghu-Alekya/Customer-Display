import 'package:flutter/material.dart';

/// Scales the whole app to a fixed kiosk design resolution.
/// This keeps UI proportions identical across kiosk display sizes.
class KioskFrame extends StatelessWidget {
  final Widget child;
  final double designWidth;
  final double designHeight;
  final Color backgroundColor;
  final bool kioskOnly;
  final double allowedSizeDifference;
  final BoxFit fit;

  const KioskFrame({
    super.key,
    required this.child,
    // Use Flutter logical reference size (not physical pixels).
    this.designWidth = 460,
    this.designHeight = 780,
    this.backgroundColor = Colors.black,
    this.kioskOnly = false,
    this.allowedSizeDifference = 24,
    this.fit = BoxFit.fitHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            return child;
          }

          // Keep one fixed design frame; do not auto-swap dimensions.
          // This avoids double letterboxing when orientation is already locked.
          final targetSize = Size(designWidth, designHeight);

          if (kioskOnly &&
              !_isWithinAllowedRange(
                current: Size(constraints.maxWidth, constraints.maxHeight),
                target: targetSize,
              )) {
            return _UnsupportedDisplay(
              current: Size(constraints.maxWidth, constraints.maxHeight),
              expected: targetSize,
            );
          }

          return Center(
            child: FittedBox(
              fit: fit,
              alignment: Alignment.center,
              child: SizedBox(
                width: targetSize.width,
                height: targetSize.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: targetSize,
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isWithinAllowedRange({
    required Size current,
    required Size target,
  }) {
    return (current.width - target.width).abs() <= allowedSizeDifference &&
        (current.height - target.height).abs() <= allowedSizeDifference;
  }
}

class _UnsupportedDisplay extends StatelessWidget {
  final Size current;
  final Size expected;

  const _UnsupportedDisplay({
    required this.current,
    required this.expected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unsupported display for kiosk mode',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Expected: ${expected.width.toInt()} x ${expected.height.toInt()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Current: ${current.width.toInt()} x ${current.height.toInt()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Run this app on the kiosk machine resolution to continue.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
