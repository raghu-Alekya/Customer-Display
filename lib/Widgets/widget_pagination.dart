import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final Function(int) onPageChanged;
  final Function(int) onRowsPerPageChanged;
  final bool showFirstLastButtons;
  final bool showPageNumbers;
  final String? emptyMessage;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final Color? buttonColor;
  final Color? disabledButtonColor;

  const PaginationWidget({
    Key? key,
    required this.currentPage,
    required this.totalItems,
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    this.showFirstLastButtons = true,
    this.showPageNumbers = true,
    this.emptyMessage,
    this.padding,
    this.backgroundColor,
    this.textStyle,
    this.buttonColor,
    this.disabledButtonColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int totalPages = (totalItems / rowsPerPage).ceil();

    // Don't show pagination if there's only one page or less
    if (totalItems <= rowsPerPage) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - Rows per page selector
          _buildRowsPerPageSelector(context),

          // Middle - Record count info
          _buildRecordInfo(context, totalPages),

          // Right side - Navigation buttons
          _buildNavigationButtons(context, totalPages),
        ],
      ),
    );
  }

  Widget _buildRowsPerPageSelector(BuildContext context) {
    return Row(
      children: [
        Text(
          "Rows per page:",
          style: textStyle ?? const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade400),
            color: Colors.white,
          ),
          child: DropdownButton<int>(
            value: rowsPerPage,
            underline: const SizedBox.shrink(),
            items: rowsPerPageOptions.map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text(
                  value.toString(),
                  style: textStyle,
                ),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                onRowsPerPageChanged(newValue);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordInfo(BuildContext context, int totalPages) {
    final int startRecord = (currentPage - 1) * rowsPerPage + 1;
    final int endRecord = (currentPage * rowsPerPage) > totalItems
        ? totalItems
        : (currentPage * rowsPerPage);

    if (totalItems == 0) {
      return Text(
        emptyMessage ?? "No records found",
        style: textStyle ?? const TextStyle(fontSize: 14, color: Colors.black87),
      );
    }

    return Text(
      '$startRecord-$endRecord of $totalItems',
      style: textStyle ?? const TextStyle(fontSize: 14, color: Colors.black87),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, int totalPages) {
    return Row(
      children: [
        // First page button
        if (showFirstLastButtons)
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: currentPage == 1
                ? null
                : () => onPageChanged(1),
            tooltip: 'First page',
            color: buttonColor,
            disabledColor: disabledButtonColor,
          ),

        // Previous page button
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage == 1
              ? null
              : () => onPageChanged(currentPage - 1),
          tooltip: 'Previous page',
          color: buttonColor,
          disabledColor: disabledButtonColor,
        ),

        // Page number indicator
        if (showPageNumbers)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '$currentPage of $totalPages',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ),

        // Next page button
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage >= totalPages
              ? null
              : () => onPageChanged(currentPage + 1),
          tooltip: 'Next page',
          color: buttonColor,
          disabledColor: disabledButtonColor,
        ),

        // Last page button
        if (showFirstLastButtons)
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: currentPage >= totalPages
                ? null
                : () => onPageChanged(totalPages),
            tooltip: 'Last page',
            color: buttonColor,
            disabledColor: disabledButtonColor,
          ),
      ],
    );
  }
}

// // Compact version for smaller screens
// class CompactPaginationWidget extends StatelessWidget {
//   final int currentPage;
//   final int totalItems;
//   final int rowsPerPage;
//   final Function(int) onPageChanged;
//   final EdgeInsetsGeometry? padding;
//   final Color? backgroundColor;
//   final TextStyle? textStyle;
//
//   const CompactPaginationWidget({
//     Key? key,
//     required this.currentPage,
//     required this.totalItems,
//     required this.rowsPerPage,
//     required this.onPageChanged,
//     this.padding,
//     this.backgroundColor,
//     this.textStyle,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final int totalPages = (totalItems / rowsPerPage).ceil();
//
//     if (totalItems <= rowsPerPage) {
//       return const SizedBox.shrink();
//     }
//
//     return Container(
//       padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       decoration: BoxDecoration(
//         color: backgroundColor ?? Colors.grey[50],
//         border: Border(
//           top: BorderSide(color: Colors.grey.shade300),
//         ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Record info
//           Text(
//             'Page $currentPage of $totalPages',
//             style: textStyle ?? const TextStyle(fontSize: 14, color: Colors.black87),
//           ),
//
//           // Navigation buttons
//           Row(
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.chevron_left),
//                 onPressed: currentPage == 1
//                     ? null
//                     : () => onPageChanged(currentPage - 1),
//                 tooltip: 'Previous page',
//               ),
//               IconButton(
//                 icon: const Icon(Icons.chevron_right),
//                 onPressed: currentPage >= totalPages
//                     ? null
//                     : () => onPageChanged(currentPage + 1),
//                 tooltip: 'Next page',
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Usage Example Helper Class
// class PaginationHelper {
//   static Widget buildPagination({
//     required int currentPage,
//     required int totalItems,
//     required int rowsPerPage,
//     required List<int> rowsPerPageOptions,
//     required Function(int) onPageChanged,
//     required Function(int) onRowsPerPageChanged,
//     bool compact = false,
//     bool showFirstLastButtons = true,
//     bool showPageNumbers = true,
//     String? emptyMessage,
//     EdgeInsetsGeometry? padding,
//     Color? backgroundColor,
//     TextStyle? textStyle,
//     Color? buttonColor,
//     Color? disabledButtonColor,
//   }) {
//     // if (compact) {
//     //   return CompactPaginationWidget(
//     //     currentPage: currentPage,
//     //     totalItems: totalItems,
//     //     rowsPerPage: rowsPerPage,
//     //     onPageChanged: onPageChanged,
//     //     padding: padding,
//     //     backgroundColor: backgroundColor,
//     //     textStyle: textStyle,
//     //   );
//     // }
//
//     return PaginationWidget(
//       currentPage: currentPage,
//       totalItems: totalItems,
//       rowsPerPage: rowsPerPage,
//       rowsPerPageOptions: rowsPerPageOptions,
//       onPageChanged: onPageChanged,
//       onRowsPerPageChanged: onRowsPerPageChanged,
//       showFirstLastButtons: showFirstLastButtons,
//       showPageNumbers: showPageNumbers,
//       emptyMessage: emptyMessage,
//       padding: padding,
//       backgroundColor: backgroundColor,
//       textStyle: textStyle,
//       buttonColor: buttonColor,
//       disabledButtonColor: disabledButtonColor,
//     );
//   }
// }