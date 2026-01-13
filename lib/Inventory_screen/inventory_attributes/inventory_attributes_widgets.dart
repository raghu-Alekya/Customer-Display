// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
// import 'inventory_attributes_bloc/inventory_attributes_bloc.dart';
// import 'inventory_attributes_bloc/inventory_attributes_event.dart';
// import 'inventory_attributes_bloc/inventory_attributes_state.dart';
//
//
// class InventoryAttributesScreen extends StatelessWidget {
//   const InventoryAttributesScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Inventory Attributes')),
//       body: BlocBuilder<InventoryAttributesBloc, InventoryAttributesState>(
//         builder: (context, state) {
//           if (state is InventoryAttributesLoading) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (state is InventoryAttributesLoaded) {
//             return ListView.builder(
//               itemCount: state.attributes.length,
//               itemBuilder: (context, index) {
//                 final attr = state.attributes[index];
//                 return ListTile(
//                   title: Text(attr.name),
//                   subtitle: Text(attr.slug),
//                 );
//               },
//             );
//           } else if (state is InventoryAttributesError) {
//             return Center(child: Text(state.message));
//           }
//           return const Center(child: Text('Press button to fetch attributes'));
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         child: const Icon(Icons.refresh),
//         onPressed: () {
//           context.read<InventoryAttributesBloc>().add(FetchInventoryAttributesEvent());
//         },
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    this.onItemSelected,
  });

  // New optional callbacks
  final void Function(InventoryAttributesEntity attribute)? onAttributeSelected;
  final void Function(InventoryAttributesEntity attribute, int itemId)? onItemSelected;

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
          // Using Builder so context.read works correctly
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: Attribute Dropdown
              Expanded(
                flex: 2,
                child: InventoryAttributesDropdown(
                  onAttributeSelected: (attribute) {
                    // Update local state
                    setState(() {
                      selectedAttribute = attribute;
                    });

                    // Print attribute details to console
                    debugPrint('Selected Attribute Details:');
                    debugPrint('ID   : ${attribute.id}');
                    debugPrint('Name : ${attribute.name}');
                    debugPrint('Slug : ${attribute.slug}');
                    debugPrint('Type : ${attribute.type}');

                    // Trigger API in Bloc
                    context
                        .read<InventoryAttributeItemsBloc>()
                        .add(FetchInventoryAttributeItems(attribute.id));

                    // Call parent callback if provided
                    if (widget.onAttributeSelected != null) {
                      widget.onAttributeSelected!(attribute);
                    }
                  },
                ),
              ),

              const SizedBox(width: 2),

              // RIGHT: Items widget or placeholder
              Expanded(
                flex: 2,
                child: selectedAttribute == null
                    ? Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.06,
                    width: MediaQuery.of(context).size.width * 0.6,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.blueGrey.shade200, width: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonFormField<InventoryAttributesEntity>(
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 0, horizontal: 8),
                      ),
                      hint: Center(
                        child: Text(
                          'Select an attribute',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      items: const [],
                      onChanged: null, // disabled
                      icon: const Icon(Icons.arrow_drop_down, size: 24),
                    ),
                  ),
                )
                    : Container(
                  height: MediaQuery.of(context).size.height * 0.06,
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: InventoryAttributeItemsWidget(
                    attributeId: selectedAttribute!.id,

                    // Callback for item selection
                    onItemSelected: (itemId) {
                      // Print inside the widget
                      debugPrint(
                          'Selected Attribute -> ID: ${selectedAttribute!.id}, Name: ${selectedAttribute!.name}, Slug: ${selectedAttribute!.slug}');
                      debugPrint('Selected Item ID: $itemId');

                      // Call parent callback if provided
                      if (widget.onItemSelected != null &&
                          selectedAttribute != null) {
                        widget.onItemSelected!(selectedAttribute!, itemId);
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

