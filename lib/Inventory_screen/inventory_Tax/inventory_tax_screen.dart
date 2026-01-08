// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
// import 'inventory_tax_bloc/inventory_tax_bloc.dart';
// import 'inventory_tax_bloc/inventory_tax_event.dart';
// import 'inventory_tax_bloc/inventory_tax_state.dart';
//
//
//
//
// class Inventory_Tax_Screen extends StatefulWidget {
//   const Inventory_Tax_Screen({super.key});
//
//   @override
//   State<Inventory_Tax_Screen> createState() => _Inventory_Tax_ScreenState();
// }
//
// class _Inventory_Tax_ScreenState extends State<Inventory_Tax_Screen> {
//   @override
//   void initState() {
//     super.initState();
//     context.read<Inventory_Tax_Bloc>().add(Inventory_Tax_Fetch_Event());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Inventory Taxes')),
//       body: BlocBuilder<Inventory_Tax_Bloc, Inventory_Tax_State>(
//         builder: (context, state) {
//           if (state is Inventory_Tax_Loading) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (state is Inventory_Tax_Error) {
//             return Center(child: Text(state.message));
//           }
//           if (state is Inventory_Tax_Loaded) {
//             return ListView.separated(
//               padding: const EdgeInsets.all(12),
//               itemCount: state.taxes.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 12),
//               itemBuilder: (context, index) {
//                 final tax = state.taxes[index];
//                 return Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('ID: ${tax.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
//                         Text('Name: ${tax.name}'),
//                         Text('Rate: ${tax.rate}%'),
//                         Text('Class: ${tax.taxClass}'),
//                         Text('Country: ${tax.country.isEmpty ? "All" : tax.country}'),
//                         Text('State: ${tax.state.isEmpty ? "All" : tax.state}'),
//                         Text('City: ${tax.city.isEmpty ? "All" : tax.city}'),
//                         Text('Postcode: ${tax.postcode.isEmpty ? "All" : tax.postcode}'),
//                         Text('Priority: ${tax.priority}'),
//                         Text('Compound: ${tax.compound}'),
//                         Text('Shipping: ${tax.shipping}'),
//                         Text('Order: ${tax.order}'),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             );
//           }
//           return const SizedBox();
//         },
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'inventory_tax_bloc/inventory_tax_bloc.dart';
import 'inventory_tax_bloc/inventory_tax_event.dart';
import 'inventory_tax_bloc/inventory_tax_state.dart';

class InventoryTaxDropdownWidget extends StatefulWidget {
  const InventoryTaxDropdownWidget({super.key});

  @override
  State<InventoryTaxDropdownWidget> createState() => _InventoryTaxDropdownWidgetState();
}

class _InventoryTaxDropdownWidgetState extends State<InventoryTaxDropdownWidget> {
  dynamic _selectedTax;

  @override
  void initState() {
    super.initState();
    context.read<Inventory_Tax_Bloc>().add(Inventory_Tax_Fetch_Event());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Inventory_Tax_Bloc, Inventory_Tax_State>(
      builder: (context, state) {
        if (state is Inventory_Tax_Loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is Inventory_Tax_Error) {
          return Text(state.message, style: const TextStyle(color: Colors.red));
        }

        if (state is Inventory_Tax_Loaded) {
          final taxes = state.taxes;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Tax:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              // Dropdown
              DropdownButtonFormField<dynamic>(
                value: _selectedTax,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 12),
                ),
                hint: const Text('Choose a tax'),
                items: taxes.map((tax) {
                  return DropdownMenuItem(
                    value: tax,
                    child: Text(tax.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTax = value;
                  });
                  if (value != null) {
                    print('Selected Tax -> ID: ${value.id}, Name: ${value.name}');
                  }
                },
                style: const TextStyle(color: Colors.black, fontSize: 16),
                dropdownColor: Colors.white,
              ),

            ],
          );
        }

        return const SizedBox();
      },
    );
  }
}
