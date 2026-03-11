import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../Helper/Extentions/theme_notifier.dart';

class ShimmerEffect extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerEffect.rectangular({super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder();

  const ShimmerEffect.circular({super.key,
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Shimmer.fromColors(
      baseColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground : Colors.grey[300]!, // Build #1.0.7: updated code
      highlightColor: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.tabsBackground : Colors.grey[300],
          shape: shapeBorder,
        ),
      ),
    );
  }
}
