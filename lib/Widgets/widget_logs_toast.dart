// New file: Widgets/process_toast.dart
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Helper/Extentions/theme_notifier.dart';
import 'package:provider/provider.dart';

// Toast widget to show process timings with close button
class LogsToast extends StatelessWidget { // Build #1.0.256: Added this widget for testing Logs for API & DB & UI
  final List<ProcessStep> steps;
  final VoidCallback onClose;

  const LogsToast({
    super.key,
    required this.steps,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);

    return AlertDialog(
      backgroundColor: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.secondaryBackground
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        TextConstants.processingItem,
        style: TextStyle(
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark
              : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 300, // Increased width (adjust as needed)
        // height: 100, // Increased height (adjust as needed)
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.map((step) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      step.name,
                      style: TextStyle(
                        color: themeHelper.themeMode == ThemeMode.dark
                            ? ThemeNotifier.textDark
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${step.timeTaken.toStringAsFixed(2)}s',
                        style: TextStyle(
                          color: themeHelper.themeMode == ThemeMode.dark
                              ? ThemeNotifier.textDark
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: Text(
            TextConstants.closeText,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}

// Class to hold process step data
class ProcessStep {
  final String name;
  final double timeTaken;

  ProcessStep({
    required this.name,
    required this.timeTaken,
  });
}

// Global list for process steps (add this at the top of your main file or create a dedicated globals file)
List<ProcessStep> globalProcessSteps = [];