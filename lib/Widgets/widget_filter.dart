import 'package:flutter/material.dart';

import '../Constants/text.dart';

class FilterDropdown extends StatefulWidget {
  final List<String> items;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const FilterDropdown({
    Key? key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _FilterDropdownState createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  late String _selectedValue;
  bool _isDropdownOpen = false; // Controls visibility of dropdown

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            TextConstants.filtersText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey[800]),
          ),
          // Filter Icon Button
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {
              setState(() {
                _isDropdownOpen = !_isDropdownOpen; // Toggle dropdown visibility
              });
            },
          ),
          // Dropdown Button (hidden unless icon is pressed)
          if (_isDropdownOpen)
            DropdownButton<String>(
              value: _selectedValue,
              items: widget.items
                  .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedValue = value;
                    _isDropdownOpen = false; // Close dropdown after selection
                  });
                  widget.onChanged(value);
                }
              },
              underline: SizedBox(), // Remove default underline
            ),
        ],
      ),
    );
  }
}