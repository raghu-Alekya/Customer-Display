import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_categories_bloc/inventory_categories_bloc.dart';
import 'inventory_categories_bloc/inventory_categories_event.dart';
import 'inventory_categories_bloc/inventory_categories_state.dart';

class InventoryCategoriesDropdown extends StatefulWidget {
  const InventoryCategoriesDropdown({super.key});

  @override
  State<InventoryCategoriesDropdown> createState() =>
      _InventoryCategoriesDropdownState();
}

class _InventoryCategoriesDropdownState
    extends State<InventoryCategoriesDropdown> {
  String? selectedCategory;

  @override
  void initState() {
    super.initState();

    /// 🔥 THIS IS THE FIX
    context
        .read<InventoryCategoriesBloc>()
        .add(InventoryCategoriesFetchEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCategoriesBloc, InventoryCategoriesState>(
      builder: (context, state) {
        if (state is InventoryCategoriesLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is InventoryCategoriesLoaded) {
          if (state.categories.isEmpty) {
            return const Center(child: Text('No categories found'));
          }

          return DropdownButtonFormField<String>(
            value: selectedCategory,
            // decoration: InputDecoration(
            //   labelText: 'Select Category',
            //   border: OutlineInputBorder(
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            //   filled: true,
            //   fillColor: Colors.grey[100],
            // ),

            decoration: InputDecoration(
              labelText: 'Select Category',
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 12),
            ),
            items: state.categories.map((category) {
              return DropdownMenuItem<String>(
                value: category.name,
                child: Row(
                  children: [
                    if (category.imageUrl.isNotEmpty)
                      Image.network(
                        category.imageUrl,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    const SizedBox(width: 10),
                    Text('${category.name} (${category.count})'),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value;
              });
            },
          );
        }

        if (state is InventoryCategoriesError) {
          return Center(child: Text(state.message));
        }

        /// Initial state
        return const SizedBox.shrink();
      },
    );
  }
}
