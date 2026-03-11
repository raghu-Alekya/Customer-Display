import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Helper/Extentions/theme_notifier.dart';

class FilterChipWidget extends StatelessWidget { // Build #1.0.8, Surya added
  final String label;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const FilterChipWidget({
    Key? key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.primaryBackground : null,
      itemBuilder: (context) => options.map((option) {
        final isSelected = option == selectedValue;
        final textColor = themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.textDark
            : Colors.black;
        return PopupMenuItem<String>(
          value: option,
          child: Text(option,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.redAccent : textColor,
            ),
          ),
        );
      }).toList(),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        height: MediaQuery.of(context).size.height * 0.06,
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Chip(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selectedValue != "All" ? Colors.redAccent : themeHelper.themeMode == ThemeMode.dark ? Color(0xFF252837) :  Colors.grey.shade200,
          side: BorderSide(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.borderColor
                : Colors.grey.shade400, // Set your desired border color
            width: 1.0, // Set border width
          ),

          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                //'$label ',
                // ': $selectedValue',
                selectedValue == "All" ? label : selectedValue,
                style: TextStyle(
                    color: selectedValue != "All" ? Colors.white : themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.textDark : Colors.black),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: selectedValue != "All" ? Colors.white : themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark : Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
