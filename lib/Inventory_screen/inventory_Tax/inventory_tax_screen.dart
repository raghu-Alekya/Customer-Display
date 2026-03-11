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
  final ValueChanged<dynamic>? onTaxSelected;

  const InventoryTaxDropdownWidget({super.key, this.onTaxSelected});

  @override
  State<InventoryTaxDropdownWidget> createState() =>
      _InventoryTaxDropdownWidgetState();
}

class _InventoryTaxDropdownWidgetState
    extends State<InventoryTaxDropdownWidget> {
  dynamic _selectedTax;

  @override
  void initState() {
    super.initState();
    context.read<Inventory_Tax_Bloc>().add(Inventory_Tax_Fetch_Event());
  }

  @override
  Widget build(BuildContext context) {
    // Detect dark mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF252837) : Colors.white70;
    final borderColor = isDark ? const Color(0xFF3B4259) : Colors.grey;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final dropdownBackgroundColor = isDark ? const Color(0xFF2C2C3A) : Colors.white;

    return BlocBuilder<Inventory_Tax_Bloc, Inventory_Tax_State>(
      buildWhen: (previous, current) {
        return current is Inventory_Tax_Loaded || current is Inventory_Tax_Error;
      },
      builder: (context, state) {
        List taxes = [];
        bool isLoading = false;
        String hintText = 'Choose a tax';

        if (state is Inventory_Tax_Loading) {
          isLoading = true;
          hintText = 'Loading taxes...';
        } else if (state is Inventory_Tax_Loaded) {
          taxes = state.taxes;
        } else if (state is Inventory_Tax_Error) {
          return Text(
            state.message,
            style: const TextStyle(color: Colors.red),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<dynamic>(
              value: _selectedTax,
              isDense: true, // ADD

              hint: Text(
                hintText,
                style: TextStyle(color: textColor),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: backgroundColor,
                isDense: true, // 👈 ADD

                contentPadding:
                const EdgeInsets.symmetric(vertical:6, horizontal: 12),
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
              items: taxes.map<DropdownMenuItem<dynamic>>((tax) {
                return DropdownMenuItem(
                  value: tax,
                  child: Text(
                    tax.name,
                    style: TextStyle(color: textColor),
                  ),
                );
              }).toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                setState(() {
                  _selectedTax = value;
                });

                if (value != null) {
                  debugPrint(
                    'Selected Tax -> ID: ${value.id}, Name: ${value.name}, taxClass: ${value.taxClass}',
                  );
                }

                if (widget.onTaxSelected != null) {
                  widget.onTaxSelected!(value);
                }
              },
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
              dropdownColor: dropdownBackgroundColor,
              iconEnabledColor: Colors.grey,
            ),
          ],
        );
      },
    );
  }
}