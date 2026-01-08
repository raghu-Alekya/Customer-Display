// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'inventory_tag_bloc/inventory_tag_bloc.dart';
// import 'inventory_tag_bloc/inventory_tag_event.dart';
// import 'inventory_tag_bloc/inventory_tag_state.dart';
//
// class InventoryTagMultiSelectWidget extends StatefulWidget {
//   const InventoryTagMultiSelectWidget({super.key});
//
//   @override
//   State<InventoryTagMultiSelectWidget> createState() =>
//       _InventoryTagMultiSelectWidgetState();
// }
//
// class _InventoryTagMultiSelectWidgetState
//     extends State<InventoryTagMultiSelectWidget> {
//   final List<dynamic> _selectedTags = [];
//
//   @override
//   void initState() {
//     super.initState();
//     // 🔹 Fetch tags only once when the widget is initialized
//     context.read<Inventory_Tag_Bloc>().add(Inventory_Tag_Fetch_Event());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<Inventory_Tag_Bloc, Inventory_Tag_State>(
//       builder: (context, state) {
//         if (state is Inventory_Tag_Loading) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         if (state is Inventory_Tag_Error) {
//           return Text(
//             state.message,
//             style: const TextStyle(color: Colors.red),
//           );
//         }
//
//         if (state is Inventory_Tag_Loaded) {
//           final tags = state.tags;
//
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Select Tags:',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               const SizedBox(height: 8),
//
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   mainAxisSpacing: 8,
//                   crossAxisSpacing: 8,
//                   childAspectRatio: 3,
//                 ),
//                 itemCount: tags.length,
//                 itemBuilder: (context, index) {
//                   final tag = tags[index];
//                   final isSelected = _selectedTags.contains(tag);
//
//                   return GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         if (isSelected) {
//                           _selectedTags.remove(tag);
//                         } else {
//                           _selectedTags.add(tag);
//                         }
//                       });
//                     },
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8),
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: isSelected ? Colors.blue : Colors.grey.shade400,
//                           width: 1.5,
//                         ),
//                         borderRadius: BorderRadius.circular(8),
//                         color: Colors.white,
//                       ),
//                       child: Row(
//                         children: [
//                           // Checkbox(
//                           //   value: isSelected,
//                           //   onChanged: (checked) {
//                           //     setState(() {
//                           //       if (checked == true) {
//                           //         _selectedTags.add(tag);
//                           //       } else {
//                           //         _selectedTags.remove(tag);
//                           //       }
//                           //     });
//                           //   },
//                           // ),
//
//                           Checkbox(
//                             value: isSelected,
//                             onChanged: (checked) {
//                               setState(() {
//                                 if (checked == true) {
//                                   _selectedTags.add(tag);
//                                 } else {
//                                   _selectedTags.remove(tag);
//                                 }
//                               });
//                             },
//                             checkColor: Colors.blue, // color of the check mark
//                             fillColor: MaterialStateProperty.resolveWith<Color>(
//                                   (Set<MaterialState> states) {
//                                 // Always white background
//                                 return Colors.white;
//                               },
//                             ),
//                             side: BorderSide(
//                               color: isSelected ? Colors.blue : Colors.grey.shade400, // border color
//                               width: 1.5,
//                             ),
//                           ),
//
//                           Flexible(
//                             child: Text(
//                               tag.name,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//
//             ],
//           );
//         }
//
//         return const SizedBox();
//       },
//     );
//   }
// }






///
///
///

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'inventory_tag_bloc/inventory_tag_bloc.dart';
import 'inventory_tag_bloc/inventory_tag_event.dart';
import 'inventory_tag_bloc/inventory_tag_state.dart';

class InventoryTagMultiSelectWidget extends StatefulWidget {
  const InventoryTagMultiSelectWidget({super.key});

  @override
  State<InventoryTagMultiSelectWidget> createState() =>
      _InventoryTagMultiSelectWidgetState();
}

class _InventoryTagMultiSelectWidgetState
    extends State<InventoryTagMultiSelectWidget> {
  final List<dynamic> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    // 🔹 Fetch tags only once when the widget is initialized
    context.read<Inventory_Tag_Bloc>().add(Inventory_Tag_Fetch_Event());
  }

  Widget _buildTagCard(dynamic tag, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              tag.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                if (checked) {
                  _selectedTags.add(tag);
                } else {
                  _selectedTags.remove(tag);
                }
              });
            },
            activeColor: Colors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Inventory_Tag_Bloc, Inventory_Tag_State>(
      builder: (context, state) {
        if (state is Inventory_Tag_Loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is Inventory_Tag_Error) {
          return Text(
            state.message,
            style: const TextStyle(color: Colors.red),
          );
        }

        if (state is Inventory_Tag_Loaded) {
          final tags = state.tags;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Tags:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  final isSelected = _selectedTags.contains(tag);
                  return _buildTagCard(tag, isSelected);
                },
              ),
            ],
          );
        }

        return const SizedBox();
      },
    );
  }
}
