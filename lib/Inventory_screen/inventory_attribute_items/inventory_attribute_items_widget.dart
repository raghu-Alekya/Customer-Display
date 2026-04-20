import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import 'inventory_attribute_items_bloc/inventory_attribute_items_event.dart';
import 'inventory_attribute_items_bloc/inventory_attribute_items_state.dart';

class InventoryAttributeItemsWidget extends StatefulWidget {
  final int attributeId;
  final void Function(String itemSlug)? onItemSelected;
  final VoidCallback? onAddItemTapped;

  // ✅ NEW: called from parent after createTerm succeeds,
  // triggers a re-fetch and auto-selects the new slug
  final void Function(void Function(String newSlug) refreshAndSelect)?
  onRegisterRefresher;

  const InventoryAttributeItemsWidget({
    super.key,
    required this.attributeId,
    this.onItemSelected,
    this.onAddItemTapped,
    this.onRegisterRefresher,
  });

  @override
  State<InventoryAttributeItemsWidget> createState() =>
      _InventoryAttributeItemsWidgetState();
}

class _InventoryAttributeItemsWidgetState
    extends State<InventoryAttributeItemsWidget> {
  String? _selectedItemSlug;
  String? _pendingAutoSelectSlug; // ✅ slug to auto-select after reload

  @override
  void initState() {
    super.initState();
    // ✅ Register the refreshAndSelect callback with parent
    widget.onRegisterRefresher?.call(_refreshAndSelect);
  }

  /// Called by parent after a new term is created via API.
  /// Re-fetches items and auto-selects the new slug once loaded.
  void _refreshAndSelect(String newSlug) {
    if (!mounted) return;
    setState(() {
      _pendingAutoSelectSlug = newSlug;
    });
    // Re-trigger fetch so BLoC reloads from API
    context
        .read<InventoryAttributeItemsBloc>()
        .add(FetchInventoryAttributeItems(widget.attributeId));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.white;

    return BlocConsumer<InventoryAttributeItemsBloc,
        InventoryAttributeItemsState>(
      // ✅ listener handles auto-select after re-fetch
      listener: (context, state) {
        if (state is InventoryAttributeItemsLoaded &&
            _pendingAutoSelectSlug != null) {
          final slug = _pendingAutoSelectSlug!;
          final exists = state.items.any((item) => item.slug == slug);
          if (exists) {
            setState(() {
              _selectedItemSlug = slug;
              _pendingAutoSelectSlug = null;
            });
            // Notify parent of the auto-selected slug
            widget.onItemSelected?.call(slug);
          }
        }
      },
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
          child: _buildDropdown(state, textColor, hintColor, bgColor),
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
    List<DropdownMenuItem<String>> dropdownItems = [];
    String hintText = 'No items found';
    bool isEnabled = false;

    if (state is InventoryAttributeItemsLoaded) {
      if (_selectedItemSlug != null &&
          _selectedItemSlug != 'add_item' &&
          !state.items.any((item) => item.slug == _selectedItemSlug)) {
        _selectedItemSlug = null;
      }

      dropdownItems = state.items
          .map((item) => DropdownMenuItem<String>(
        value: item.slug,
        child: Center(
          child: Text(item.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor)),
        ),
      ))
          .toList();

      dropdownItems.insert(
        0,
        const DropdownMenuItem<String>(
          value: 'add_item',
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16, color: Color(0xFF2196F3)),
                SizedBox(width: 4),
                Text('Add Item',
                    style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

      hintText = 'Select an item';
      isEnabled = true;
    } else if (state is InventoryAttributeItemsLoading) {
      hintText = 'Loading items...';
      isEnabled = false;
    }

    return DropdownButtonFormField<String>(
      value: _selectedItemSlug,
      isExpanded: true,
      isDense: true,
      dropdownColor: bgColor,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      hint: Center(
          child:
          Text(hintText, style: TextStyle(color: hintColor, fontSize: 14))),
      items: dropdownItems,
      onChanged: isEnabled
          ? (value) {
        if (value == 'add_item') {
          setState(() => _selectedItemSlug = null);
          widget.onAddItemTapped?.call();
          return;
        }
        setState(() => _selectedItemSlug = value);
        if (value != null && widget.onItemSelected != null) {
          widget.onItemSelected!(value);
          debugPrint('Selected Item Slug: $value');
        }
      }
          : null,
      icon: Icon(Icons.arrow_drop_down, size: 24, color: textColor),
      style: TextStyle(fontSize: 14, color: textColor),
    );
  }
}