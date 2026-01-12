// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
// import 'inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
// import 'inventory_attribute_items_bloc/inventory_attribute_items_event.dart';
// import 'inventory_attribute_items_bloc/inventory_attribute_items_state.dart';
// import 'inventory_attribute_items_entity.dart';
//
//
// class InventoryAttributeItemsDropdown extends StatefulWidget {
//   const InventoryAttributeItemsDropdown({super.key});
//
//   @override
//   State<InventoryAttributeItemsDropdown> createState() =>
//       _InventoryAttributeItemsDropdownState();
// }
//
// class _InventoryAttributeItemsDropdownState
//     extends State<InventoryAttributeItemsDropdown> {
//   InventoryAttributeItemsEntity? selectedItem;
//
//   @override
//   void initState() {
//     super.initState();
//     // Load items on init
//     context
//         .read<InventoryAttributeItemsBloc>()
//         .add(InventoryAttributeItemsLoadEvent());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<InventoryAttributeItemsBloc,
//         InventoryAttributeItemsState>(
//       builder: (context, state) {
//         if (state is InventoryAttributeItemsLoading) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (state is InventoryAttributeItemsLoaded) {
//           final items = state.items;
//
//           return DropdownButton<InventoryAttributeItemsEntity>(
//             hint: const Text('Select Item'),
//             value: selectedItem,
//             items: items.map((item) {
//               return DropdownMenuItem<InventoryAttributeItemsEntity>(
//                 value: item,
//                 child: Text(item.name),
//               );
//             }).toList(),
//             onChanged: (value) {
//               setState(() {
//                 selectedItem = value;
//               });
//               if (value != null) {
//                 print('Selected Item: ${value.name}, ID: ${value.id}');
//               }
//             },
//           );
//         } else if (state is InventoryAttributeItemsError) {
//           return Center(child: Text(state.message));
//         }
//         return const Center(child: Text('Loading items...'));
//       },
//     );
//   }
// }



////

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import 'inventory_attribute_items_bloc/inventory_attribute_items_event.dart';
import 'inventory_attribute_items_bloc/inventory_attribute_items_state.dart';
import 'inventory_attribute_items_entity.dart';

class InventoryAttributeItemsDropdown extends StatefulWidget {
  final int attributeId;
  final void Function(InventoryAttributeItemsEntity) onItemSelected;

  const InventoryAttributeItemsDropdown({
    super.key,
    required this.attributeId,
    required this.onItemSelected,
  });

  @override
  State<InventoryAttributeItemsDropdown> createState() =>
      _InventoryAttributeItemsDropdownState();
}

class _InventoryAttributeItemsDropdownState
    extends State<InventoryAttributeItemsDropdown> {
  InventoryAttributeItemsEntity? selectedItem;
  List<InventoryAttributeItemsEntity> items = [];

  @override
  void initState() {
    super.initState();
    context
        .read<InventoryAttributeItemsBloc>()
        .add(FetchInventoryAttributeItemsEvent(attributeId: widget.attributeId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryAttributeItemsBloc, InventoryAttributeItemsState>(
      listener: (context, state) {
        if (state is InventoryAttributeItemsLoaded) {
          setState(() {
            items = state.items;
            if (selectedItem != null && !items.contains(selectedItem)) {
              selectedItem = null;
            }
          });
        } else if (state is InventoryAttributeItemsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: DropdownButtonFormField<InventoryAttributeItemsEntity>(
        isExpanded: true,
        value: selectedItem,
        decoration: const InputDecoration(
          hintText: 'Select Item',
          border: OutlineInputBorder(),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item.name),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => selectedItem = value);
          widget.onItemSelected(value);
        },
      ),
    );
  }
}



