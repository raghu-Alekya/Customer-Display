// Reusable Status Widget - add this to your widget file or create a separate file
import 'package:flutter/material.dart';

class StatusWidget extends StatelessWidget {
  final String status;
  final double dotSize;
  final double fontSize;

  const StatusWidget({
    Key? key,
    required this.status,
    this.dotSize = 8.0,
    this.fontSize = 14.0,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade600;
      case 'on-hold':
        return Colors.orange.shade600;
      case 'pending':
        return Colors.yellow.shade600; // yellow for pending, on-Hold for yellow, refunded for red
      case 'cancelled':
        return Colors.red.shade600;
      case 'processing':
        return Colors.yellow.shade600;
      case 'refunded' :
        return Colors.red.shade600;
      case 'failed':
        return Colors.red.shade600;
      case 'partial-refund':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Get lighter shade for text
  Color _getTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'on-hold':
        return Colors.orange.shade700;
      case 'pending':
        return Colors.yellow.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'processing':
        return Colors.yellow.shade700;
      case 'refunded' :
        return Colors.red.shade700;
      case 'failed':
        return Colors.red.shade800;
      case 'partial-refund':
        return Colors.orange.shade600;

      default:
        return Colors.grey.shade700;
    }
  }

  // Get lightest shade for container background
  Color _getContainerColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade50;
      case 'on-hold':
        return Colors.orange.shade50;
      case 'pending':
        return Colors.yellow.shade50;
      case 'cancelled':
        return Colors.red.shade50;
      case 'processing':
        return Colors.yellow.shade50;
      case 'refunded' :
        return Colors.red.shade50;
      case 'failed':
        return Colors.red.shade50;
      case 'partial-refund':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: _getContainerColor(status), // Lightest shade
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: _getStatusColor(status), // Darkest shade
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Align(
            alignment: Alignment.center,
            child: Text(
              status,
              style: TextStyle(
                color: _getTextColor(status), // Medium shade
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}