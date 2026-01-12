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

import 'inventory_attributes_bloc/inventory_attributes_bloc.dart';
import 'inventory_attributes_bloc/inventory_attributes_event.dart';
import 'inventory_attributes_bloc/inventory_attributes_state.dart';
import 'inventory_attributes_entity.dart';

/// 🔹 Reusable Inventory Attributes Dropdown Widget
class InventoryAttributesDropdown extends StatefulWidget {
  const InventoryAttributesDropdown({
    super.key,
    required this.onAttributeSelected,
  });

  /// ✅ Callback to parent
  final void Function(InventoryAttributesEntity attribute) onAttributeSelected;

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
    // Fetch inventory attributes from Bloc
    context
        .read<InventoryAttributesBloc>()
        .add(FetchInventoryAttributesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryAttributesBloc, InventoryAttributesState>(
      listener: (context, state) {
        if (state is InventoryAttributesLoaded) {
          setState(() {
            attributes = state.attributes;

            // Reset selected if it's no longer in the list
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
            // ✅ Make dropdown responsive using Expanded
            Expanded(
              child: DropdownButtonFormField<InventoryAttributesEntity>(
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Select',
                  contentPadding: const EdgeInsets.symmetric(
                    vertical:2,
                    horizontal:2,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Colors.blueGrey,
                      width:0.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    // borderSide: const BorderSide(
                    //   color: Colors.blue,
                    //   width: 2,
                    // ),
                  ),
                ),
                value: selectedAttribute,
                items: attributes.map((attr) {
                  return DropdownMenuItem<InventoryAttributesEntity>(
                    value: attr,
                    child: Text(attr.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedAttribute = value;
                  });

                  // ✅ Callback to parent
                  widget.onAttributeSelected(value);

                  // ✅ Debug prints
                  debugPrint('ID   : ${value.id}');
                  debugPrint('Name : ${value.name}');
                  debugPrint('Slug : ${value.slug}');
                  debugPrint('Type : ${value.type}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}








