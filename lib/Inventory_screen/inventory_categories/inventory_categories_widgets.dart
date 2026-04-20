import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_categories_bloc/inventory_categories_bloc.dart';
import 'inventory_categories_bloc/inventory_categories_event.dart';
import 'inventory_categories_bloc/inventory_categories_state.dart';

class InventoryCategoriesDropdown extends StatefulWidget {
  final dynamic selectedCategory;                    // ← new: controlled value
  final ValueChanged<dynamic>? onCategorySelected; // parent callback

  const InventoryCategoriesDropdown({super.key, this.onCategorySelected,this.selectedCategory,});

  @override
  State<InventoryCategoriesDropdown> createState() =>
      _InventoryCategoriesDropdownState();
}

class _InventoryCategoriesDropdownState
    extends State<InventoryCategoriesDropdown> {
  dynamic selectedCategory;

  @override
  void initState() {
    super.initState();
    context.read<InventoryCategoriesBloc>().add(InventoryCategoriesFetchEvent());
  }

  @override
  Widget build(BuildContext context) {
    // Detect dark mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = isDark ? const Color(0xFF252837) : Colors.white70;
    final borderColor = isDark ? const Color(0xFF3B4259) : Colors.grey;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final dropdownBackgroundColor = isDark ? const Color(0xFF2C2C3A) : Colors.white;

    return BlocBuilder<InventoryCategoriesBloc, InventoryCategoriesState>(
      builder: (context, state) {
        List categories = [];
        bool isLoading = false;
        String hintText = 'Please select the category';

        if (state is InventoryCategoriesLoading) {
          isLoading = true;
          hintText = 'Loading categories...';
        } else if (state is InventoryCategoriesLoaded) {
          categories = state.categories;
        } else if (state is InventoryCategoriesError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return DropdownButtonFormField<dynamic>(
          value: selectedCategory,
          hint: Text(
            hintText,
            style: TextStyle(color: textColor),
          ),
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          items: categories.map<DropdownMenuItem<dynamic>>((category) {
            return DropdownMenuItem<dynamic>(
              value: category,
              child: Row(
                children: [
                  if (category.imageUrl.isNotEmpty)
                    Image.network(
                      category.imageUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  if (category.imageUrl.isNotEmpty) const SizedBox(width: 10),
                  Text(
                    '${category.name} (${category.count})',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: isLoading
              ? null
              : (value) {
            setState(() {
              selectedCategory = value;
            });

            if (value != null) {
              debugPrint(
                  'Selected Category -> ID: ${value.id}, Name: ${value.name}');
            }

            if (widget.onCategorySelected != null) {
              widget.onCategorySelected!(value);
            }
          },
          style: TextStyle(
            color: textColor,
            fontSize: 14,
          ),
          dropdownColor: dropdownBackgroundColor,
          iconEnabledColor: Colors.grey,
        );
      },
    );
  }
}