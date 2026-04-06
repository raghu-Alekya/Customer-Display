import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Orange wave dots — used instead of a plain [CircularProgressIndicator] for promos & product thumbs.
class KioskWaveDots extends StatefulWidget {
  const KioskWaveDots({
    super.key,
    this.dotSize = 8,
    this.spacing = 5,
    this.color = const Color(0xFFFF9900),
    this.duration = const Duration(milliseconds: 1200),
  });

  final double dotSize;
  final double spacing;
  final Color color;
  final Duration duration;

  @override
  State<KioskWaveDots> createState() => _KioskWaveDotsState();
}

class _KioskWaveDotsState extends State<KioskWaveDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (i * 0.22) % 1.0;
            final t = (_controller.value + phase) % 1.0;
            final scale = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.45),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Full-area promo placeholder (dark background + centered wave dots).
class KioskPromoImageLoading extends StatelessWidget {
  const KioskPromoImageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: KioskWaveDots(
          dotSize: 10,
          spacing: 6,
          color: Color(0xFFFFB04D),
        ),
      ),
    );
  }
}

/// Compact loader for product grid thumbnails.
class KioskProductThumbLoading extends StatelessWidget {
  const KioskProductThumbLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F4F7),
      alignment: Alignment.center,
      child: const KioskWaveDots(
        dotSize: 6,
        spacing: 4,
        color: Color(0xFFFF9900),
      ),
    );
  }
}

/// Full-screen / block loading (e.g. product list fetching).
class KioskBlockLoading extends StatelessWidget {
  const KioskBlockLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KioskWaveDots(dotSize: 9, spacing: 5),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
