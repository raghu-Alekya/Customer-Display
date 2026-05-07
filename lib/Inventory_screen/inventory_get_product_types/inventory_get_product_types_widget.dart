import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_get_product_types_bloc/inventory_get_product_types_bloc.dart';
import 'inventory_get_product_types_bloc/inventory_get_product_types_event.dart';
import 'inventory_get_product_types_bloc/inventory_get_product_types_state.dart';

class InventoryGetProductTypesWidget extends StatefulWidget {
  final ValueChanged<String?>? onTypeSelected; // callback

  const InventoryGetProductTypesWidget({super.key, this.onTypeSelected});

  @override
  State<InventoryGetProductTypesWidget> createState() =>
      _InventoryGetProductTypesWidgetState();
}

class _InventoryGetProductTypesWidgetState
    extends State<InventoryGetProductTypesWidget> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    context
        .read<InventoryGetProductTypesBloc>()
        .add(InventoryGetProductTypesLoadEvent());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = isDark ? const Color(0xFF252837) : Colors.white70;
    final borderColor = isDark ? const Color(0xFF3B4259) : Colors.grey.shade400;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final dropdownBackgroundColor =
    isDark ? const Color(0xFF2C2C3A) : Colors.white;
    final iconColor = isDark ? Colors.white54 : Colors.grey;

    return BlocBuilder<InventoryGetProductTypesBloc,
        InventoryGetProductTypesState>(
      builder: (context, state) {
        // 🔹 Loading state
        if (state is InventoryGetProductTypesLoading) {
          return DropdownButtonFormField<String>(
            items: [],
            onChanged: null,
            hint: Text(
              'Loading product types...',
              style: TextStyle(color: textColor),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
            ),
            style: TextStyle(color: textColor, fontSize: 16),
            dropdownColor: dropdownBackgroundColor,
            iconEnabledColor: iconColor,
          );
        }

        // 🔹 Error state
        if (state is InventoryGetProductTypesError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // 🔹 Loaded state (✅ UPDATED ONLY THIS BLOCK)
        if (state is InventoryGetProductTypesLoaded) {
          final types = state.productTypes.types;

          final filteredEntries = types.entries.where((entry) {
            return entry.key == 'simple' || entry.key == 'variable';
          }).map((entry) {
            String displayValue = entry.value;

            if (entry.key == 'variable') {
              displayValue = 'Variant product';
            }

            return MapEntry(entry.key, displayValue);
          }).toList();

          return DropdownButtonFormField<String>(
            isDense: true,
            value: _selectedType,
            hint: Text(
              'Choose a product type',
              style: TextStyle(color: textColor),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
            ),
            items: filteredEntries
                .map((entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(color: textColor),
              ),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
              });

              if (widget.onTypeSelected != null) {
                widget.onTypeSelected!(value);
              }

              if (value != null) {
                print('Selected Product Type: $value');
              }
            },
            style: TextStyle(color: textColor, fontSize: 16),
            dropdownColor: dropdownBackgroundColor,
            iconEnabledColor: iconColor,
          );
        }

        return const Center(child: Text('No data'));
      },
    );
  }
}