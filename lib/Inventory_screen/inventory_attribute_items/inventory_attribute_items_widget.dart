import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import 'inventory_attribute_items_bloc/inventory_attribute_items_state.dart';

class InventoryAttributeItemsWidget extends StatefulWidget {
  final int attributeId;

  // Add a callback for item selection
  final void Function(int itemId)? onItemSelected;

  const InventoryAttributeItemsWidget({
    super.key,
    required this.attributeId,
    this.onItemSelected, // optional callback
  });

  @override
  State<InventoryAttributeItemsWidget> createState() =>
      _InventoryAttributeItemsWidgetState();
}

class _InventoryAttributeItemsWidgetState
    extends State<InventoryAttributeItemsWidget> {
  int? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor =
    isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor =
    isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor =
    isDark ? Colors.grey.shade900 : Colors.white;

    return BlocBuilder<InventoryAttributeItemsBloc,
        InventoryAttributeItemsState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.06,
          width: MediaQuery.of(context).size.width * 0.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildDropdown(
            state,
            textColor,
            hintColor,
            bgColor,
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
      InventoryAttributeItemsState state,
      Color textColor,
      Color hintColor,
      Color bgColor,
      ) {
    List<DropdownMenuItem<int>> dropdownItems = [];

    String hintText = 'No items found';
    bool isEnabled = false;

    if (state is InventoryAttributeItemsLoaded && state.items.isNotEmpty) {
      // Reset selection if not in new list
      if (_selectedItemId != null &&
          !state.items.any((item) => item.id == _selectedItemId)) {
        _selectedItemId = null;
      }

      dropdownItems = state.items
          .map(
            (item) => DropdownMenuItem<int>(
          value: item.id,
          child: Center(
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ),
        ),
      )
          .toList();

      hintText = 'Select an item';
      isEnabled = true;
    } else if (state is InventoryAttributeItemsLoading) {
      hintText = 'Loading items...';
      dropdownItems = [];
      isEnabled = false;
    }

    return DropdownButtonFormField<int>(
      value: _selectedItemId,
      isExpanded: true,
      isDense: true,
      dropdownColor: bgColor, // 👈 dark mode dropdown menu
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding:
        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      hint: Center(
        child: Text(
          hintText,
          style: TextStyle(color: hintColor, fontSize: 14),
        ),
      ),
      items: dropdownItems,
      onChanged: isEnabled
          ? (value) {
        setState(() {
          _selectedItemId = value;
        });

        if (value != null && widget.onItemSelected != null) {
          widget.onItemSelected!(value);
          debugPrint('Selected Item IDddddddd: $value');
        }
      }
          : null,
      icon: Icon(Icons.arrow_drop_down,
          size: 24, color: textColor),
      style: TextStyle(fontSize: 14, color: textColor),
    );
  }
}
