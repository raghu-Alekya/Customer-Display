import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart';

import '../inventory_attribute_items/inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import '../inventory_attribute_items/inventory_attribute_items_bloc/inventory_attribute_items_event.dart';
import '../inventory_attribute_items/inventory_attribute_items_remote_data_source.dart';
import '../inventory_attribute_items/inventory_attribute_items_widget.dart';
import 'inventory_attributes_bloc/inventory_attributes_bloc.dart';
import 'inventory_attributes_bloc/inventory_attributes_event.dart';
import 'inventory_attributes_bloc/inventory_attributes_state.dart';
import 'inventory_attributes_entity.dart';


class InventoryAttributesDropdown extends StatefulWidget {
  const InventoryAttributesDropdown({
    super.key,
    required this.onAttributeSelected,
  });

  final void Function(InventoryAttributesEntity attribute)
  onAttributeSelected;

  @override
  State<InventoryAttributesDropdown> createState() =>
      _InventoryAttributesDropdownState();
}

class _InventoryAttributesDropdownState
    extends State<InventoryAttributesDropdown> {
  InventoryAttributesEntity? selectedAttribute;
  List<InventoryAttributesEntity> attributes = [];

  @override
  void initState() {
    super.initState();
    context
        .read<InventoryAttributesBloc>()
        .add(FetchInventoryAttributesEvent());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor =
    isDark ? Colors.grey.shade700 : Colors.blueGrey.shade200;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor =
    isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor =
    isDark ? Colors.grey.shade900 : Colors.white;

    return BlocListener<InventoryAttributesBloc, InventoryAttributesState>(
      listener: (context, state) {
        if (state is InventoryAttributesLoaded) {
          setState(() {
            attributes = state.attributes;
            if (selectedAttribute != null &&
                !attributes.contains(selectedAttribute)) {
              selectedAttribute = null;
            }
          });
        }

        if (state is InventoryAttributesError) {
          debugPrint('InventoryAttributesError: ${state.message}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.06,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonFormField<InventoryAttributesEntity>(
                  value: selectedAttribute,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: bgColor, // 👈 Dark mode dropdown
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8),
                  ),
                  hint: Center(
                    child: Text(
                      'Select',
                      style:
                      TextStyle(color: hintColor, fontSize: 14),
                    ),
                  ),
                  items: attributes.map((attr) {
                    return DropdownMenuItem<
                        InventoryAttributesEntity>(
                      value: attr,
                      child: Center(
                        child: Text(
                          attr.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: textColor),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedAttribute = value;
                    });

                    widget.onAttributeSelected(value);

                    debugPrint('ID   : ${value.id}');
                    debugPrint('Name : ${value.name}');
                    debugPrint('Slug : ${value.slug}');
                    debugPrint('Type : ${value.type}');
                  },
                  icon: Icon(Icons.arrow_drop_down,
                      size: 24, color: textColor),
                  style:
                  TextStyle(fontSize: 14, color: textColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 🔹 Parent Widget: Side-by-side layout with Dropdown + Items
///




class InventoryAttributesWithItemsWidget extends StatefulWidget {
  const InventoryAttributesWithItemsWidget({
    super.key,
    this.onAttributeSelected,
    this.onItemSelected,       // kept for backward compatibility
    this.onItemSlugSelected,   // new recommended callback for slug
  });

  // Callbacks
  final void Function(InventoryAttributesEntity attribute)? onAttributeSelected;
  final void Function(InventoryAttributesEntity attribute, int itemId)? onItemSelected;
  final void Function(InventoryAttributesEntity attribute, String slug)? onItemSlugSelected;

  @override
  State<InventoryAttributesWithItemsWidget> createState() =>
      _InventoryAttributesWithItemsWidgetState();
}

class _InventoryAttributesWithItemsWidgetState
    extends State<InventoryAttributesWithItemsWidget> {
  InventoryAttributesEntity? selectedAttribute;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InventoryAttributeItemsBloc(
        InventoryAttributeItemsApi(),
      ),
      child: Builder(
        builder: (context) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Attribute Dropdown
              Container(
                // height: 48,
                child: Expanded(
                  flex: 2,
                  child: InventoryAttributesDropdown(
                    onAttributeSelected: (attribute) {
                      setState(() {
                        selectedAttribute = attribute;
                      });

                      debugPrint('Selected Attribute:');
                      debugPrint('  • ID   : ${attribute.id}');
                      debugPrint('  • Name : ${attribute.name}');
                      debugPrint('  • Slug : ${attribute.slug}');
                      debugPrint('  • Type : ${attribute.type}');

                      // Load items for selected attribute
                      context
                          .read<InventoryAttributeItemsBloc>()
                          .add(FetchInventoryAttributeItems(attribute.id));

                      widget.onAttributeSelected?.call(attribute);
                    },
                  ),
                ),
              ),

              const SizedBox(width:4), // slightly better spacing

              // RIGHT: Items selector or placeholder
              Expanded(
                flex: 2,
                child: selectedAttribute == null
                    ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey.shade200, width: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Select an attribute first',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
                    : Container(
                  height: 48,
                  child: InventoryAttributeItemsWidget(
                    attributeId: selectedAttribute!.id,
                    onItemSelected: (itemSlug) {
                      if (selectedAttribute == null || itemSlug == null || itemSlug.trim().isEmpty) {
                        debugPrint('Invalid selection: no attribute or empty slug');
                        return;
                      }

                      debugPrint('Item selected:');
                      debugPrint('  • Attribute ID   : ${selectedAttribute!.id}');
                      debugPrint('  • Attribute Name : ${selectedAttribute!.name}');
                      debugPrint('  • Attribute Slug : ${selectedAttribute!.slug}');
                      debugPrint('  • Selected Slug  : $itemSlug');

                      // Pass slug to parent (preferred)
                      widget.onItemSlugSelected?.call(selectedAttribute!, itemSlug);

                      // Optional: if some old code still uses itemId, you can try to parse
                      // (only if slug contains numeric ID — otherwise skip)
                      final possibleId = int.tryParse(itemSlug);
                      if (possibleId != null && widget.onItemSelected != null) {
                        widget.onItemSelected!(selectedAttribute!, possibleId);
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}