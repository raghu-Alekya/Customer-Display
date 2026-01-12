// // import 'package:flutter/material.dart';
// // import 'package:flutter_bloc/flutter_bloc.dart';
// // import 'inventory_tag_bloc/inventory_tag_bloc.dart';
// // import 'inventory_tag_bloc/inventory_tag_event.dart';
// // import 'inventory_tag_bloc/inventory_tag_state.dart';
// //
// // class InventoryTagMultiSelectWidget extends StatefulWidget {
// //   const InventoryTagMultiSelectWidget({super.key});
// //
// //   @override
// //   State<InventoryTagMultiSelectWidget> createState() =>
// //       _InventoryTagMultiSelectWidgetState();
// // }
// //
// // class _InventoryTagMultiSelectWidgetState
// //     extends State<InventoryTagMultiSelectWidget> {
// //   final List<dynamic> _selectedTags = [];
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // 🔹 Fetch tags only once when the widget is initialized
// //     context.read<Inventory_Tag_Bloc>().add(Inventory_Tag_Fetch_Event());
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return BlocBuilder<Inventory_Tag_Bloc, Inventory_Tag_State>(
// //       builder: (context, state) {
// //         if (state is Inventory_Tag_Loading) {
// //           return const Center(child: CircularProgressIndicator());
// //         }
// //
// //         if (state is Inventory_Tag_Error) {
// //           return Text(
// //             state.message,
// //             style: const TextStyle(color: Colors.red),
// //           );
// //         }
// //
// //         if (state is Inventory_Tag_Loaded) {
// //           final tags = state.tags;
// //
// //           return Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               const Text(
// //                 'Select Tags:',
// //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
// //               ),
// //               const SizedBox(height: 8),
// //
// //               GridView.builder(
// //                 shrinkWrap: true,
// //                 physics: const NeverScrollableScrollPhysics(),
// //                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
// //                   crossAxisCount: 2,
// //                   mainAxisSpacing: 8,
// //                   crossAxisSpacing: 8,
// //                   childAspectRatio: 3,
// //                 ),
// //                 itemCount: tags.length,
// //                 itemBuilder: (context, index) {
// //                   final tag = tags[index];
// //                   final isSelected = _selectedTags.contains(tag);
// //
// //                   return GestureDetector(
// //                     onTap: () {
// //                       setState(() {
// //                         if (isSelected) {
// //                           _selectedTags.remove(tag);
// //                         } else {
// //                           _selectedTags.add(tag);
// //                         }
// //                       });
// //                     },
// //                     child: Container(
// //                       padding: const EdgeInsets.symmetric(horizontal: 8),
// //                       decoration: BoxDecoration(
// //                         border: Border.all(
// //                           color: isSelected ? Colors.blue : Colors.grey.shade400,
// //                           width: 1.5,
// //                         ),
// //                         borderRadius: BorderRadius.circular(8),
// //                         color: Colors.white,
// //                       ),
// //                       child: Row(
// //                         children: [
// //                           // Checkbox(
// //                           //   value: isSelected,
// //                           //   onChanged: (checked) {
// //                           //     setState(() {
// //                           //       if (checked == true) {
// //                           //         _selectedTags.add(tag);
// //                           //       } else {
// //                           //         _selectedTags.remove(tag);
// //                           //       }
// //                           //     });
// //                           //   },
// //                           // ),
// //
// //                           Checkbox(
// //                             value: isSelected,
// //                             onChanged: (checked) {
// //                               setState(() {
// //                                 if (checked == true) {
// //                                   _selectedTags.add(tag);
// //                                 } else {
// //                                   _selectedTags.remove(tag);
// //                                 }
// //                               });
// //                             },
// //                             checkColor: Colors.blue, // color of the check mark
// //                             fillColor: MaterialStateProperty.resolveWith<Color>(
// //                                   (Set<MaterialState> states) {
// //                                 // Always white background
// //                                 return Colors.white;
// //                               },
// //                             ),
// //                             side: BorderSide(
// //                               color: isSelected ? Colors.blue : Colors.grey.shade400, // border color
// //                               width: 1.5,
// //                             ),
// //                           ),
// //
// //                           Flexible(
// //                             child: Text(
// //                               tag.name,
// //                               overflow: TextOverflow.ellipsis,
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   );
// //                 },
// //               ),
// //
// //             ],
// //           );
// //         }
// //
// //         return const SizedBox();
// //       },
// //     );
// //   }
// // }
//
//
//
//
//
//
// ///
// ///
// ///
//
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
//
//     /// ✅ Avoid repeated API calls
//     final bloc = context.read<Inventory_Tag_Bloc>();
//     if (bloc.state is! Inventory_Tag_Loaded) {
//       bloc.add(Inventory_Tag_Fetch_Event());
//     }
//   }
//
//   Widget _buildTagCard(dynamic tag, bool isSelected) {
//     Color backgroundColor;
//     Color borderColor;
//
//     if (tag.name == 'Age Restricted') {
//       backgroundColor = const Color.fromRGBO(245, 230, 215, 1); // light brown
//       borderColor = const Color.fromRGBO(191, 145, 104, 1);
//     } else if (tag.name == 'Ebt Eligible') {
//       backgroundColor = const Color.fromRGBO(225, 245, 225, 1); // light green
//       borderColor = const Color.fromRGBO(102, 187, 106, 1);
//     } else {
//       backgroundColor = const Color.fromRGBO(245, 247, 250, 1); // default
//       borderColor = const Color.fromRGBO(189, 189, 189, 1);
//     }
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: backgroundColor,
//         borderRadius: BorderRadius.circular(6),
//         // border: Border.all(
//         //   color: isSelected
//         //       ? const Color.fromRGBO(33, 150, 243, 1)
//         //       : borderColor,
//         //   width: 1.5,
//         // ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Expanded(
//             child: Text(
//               tag.name,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Color.fromRGBO(33, 33, 33, 1),
//               ),
//             ),
//           ),
//           Switch(
//             value: isSelected,
//             onChanged: (checked) {
//               setState(() {
//                 if (checked) {
//                   _selectedTags.add(tag);
//                 } else {
//                   _selectedTags.remove(tag);
//                 }
//               });
//             },
//             activeColor: const Color.fromRGBO(33, 150, 243, 1),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<Inventory_Tag_Bloc, Inventory_Tag_State>(
//       builder: (context, state) {
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
//           /// ✅ Filter tags
//           final primaryTags = tags.where((tag) =>
//           tag.name == 'Age Restricted' ||
//               tag.name == 'Ebt Eligible').toList();
//
//           final variableProductTags = tags
//               .where((tag) => tag.name == 'Variable Product')
//               .toList();
//
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               /// 🔹 FIRST SECTION
//               // const Text(
//               //   'Select Tags:',
//               //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               // ),
//               // const SizedBox(height: 8),
//               ListView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: primaryTags.length,
//                 itemBuilder: (context, index) {
//                   final tag = primaryTags[index];
//                   final isSelected = _selectedTags.contains(tag);
//                   return _buildTagCard(tag, isSelected);
//                 },
//               ),
//
//               // const SizedBox(height: 16),
//               //
//               // /// 🔹 SECOND SECTION
//               // const Text(
//               //   'Variable Product:',
//               //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               // ),
//               // const SizedBox(height: 8),
//               // ListView.builder(
//               //   shrinkWrap: true,
//               //   physics: const NeverScrollableScrollPhysics(),
//               //   itemCount: variableProductTags.length,
//               //   itemBuilder: (context, index) {
//               //     final tag = variableProductTags[index];
//               //     final isSelected = _selectedTags.contains(tag);
//               //     return _buildTagCard(tag, isSelected);
//               //   },
//               // ),
//             ],
//           );
//         }
//
//         /// ✅ Default empty UI
//         return const SizedBox();
//       },
//     );
//   }
// }
//


/////////////


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'inventory_tag_bloc/inventory_tag_bloc.dart';
import 'inventory_tag_bloc/inventory_tag_event.dart';
import 'inventory_tag_bloc/inventory_tag_state.dart';

class InventoryTagMultiSelectWidget extends StatefulWidget {
  final ValueChanged<dynamic>? onTypeSelected;

  const InventoryTagMultiSelectWidget({super.key,this.onTypeSelected});

  @override
  State<InventoryTagMultiSelectWidget> createState() =>
      _InventoryTagMultiSelectWidgetState();
}

class _InventoryTagMultiSelectWidgetState
    extends State<InventoryTagMultiSelectWidget> {
  /// ✅ Single selected tag (not multiple)
  dynamic _selectedTag;

  @override
  void initState() {
    super.initState();

    /// ✅ Avoid repeated API calls
    final bloc = context.read<Inventory_Tag_Bloc>();
    if (bloc.state is! Inventory_Tag_Loaded) {
      bloc.add(Inventory_Tag_Fetch_Event());
    }
  }

  Widget _buildTagCard(dynamic tag, bool isSelected) {
    Color backgroundColor;
    Color borderColor;

    if (tag.name == 'Age Restricted') {
      backgroundColor = const Color.fromRGBO(245, 230, 215, 1);
      borderColor = const Color.fromRGBO(191, 145, 104, 1);
    } else if (tag.name == 'Ebt Eligible') {
      backgroundColor = const Color.fromRGBO(225, 245, 225, 1);
      borderColor = const Color.fromRGBO(102, 187, 106, 1);
    } else {
      backgroundColor = const Color.fromRGBO(245, 247, 250, 1);
      borderColor = const Color.fromRGBO(189, 189, 189, 1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        // border: Border.all(
        //   color: isSelected
        //       ? const Color.fromRGBO(33, 150, 243, 1)
        //       : borderColor,
        //   width: 1.5,
        // ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              tag.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(33, 33, 33, 1),
              ),
            ),
          ),
          // Switch(
          //   value: isSelected,
          //   onChanged: (checked) {
          //     setState(() {
          //
          //       // if (widget.onTypeSelected != null) {
          //       //   widget.onTypeSelected!(value);
          //       // }
          //       /// ✅ Only one tag can be selected
          //       _selectedTag = checked ? tag : null;
          //       debugPrint('Selected Tag -> id: ${tag.id}, name: ${tag.name},slug: ${tag.slug}');
          //
          //     });
          //   },
          //
          //   activeColor: const Color.fromRGBO(33, 150, 243, 1),
          // ),

          Switch(
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                _selectedTag = checked ? tag : null;

                // Trigger parent callback
                if (widget.onTypeSelected != null) {
                  widget.onTypeSelected!(_selectedTag);
                }

                // Local debugPrint (optional)
                if (_selectedTag != null) {
                  debugPrint(
                      'Selected Tag -> id: ${_selectedTag.id}, name: ${_selectedTag.name}, slug: ${_selectedTag.slug}'
                  );
                }
              });
            },
            activeColor: const Color.fromRGBO(33, 150, 243, 1),
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Inventory_Tag_Bloc, Inventory_Tag_State>(
      builder: (context, state) {
        if (state is Inventory_Tag_Error) {
          return Text(
            state.message,
            style: const TextStyle(color: Colors.red),
          );
        }

        if (state is Inventory_Tag_Loaded) {
          final tags = state.tags;

          /// ✅ Filter required tags
          final primaryTags = tags.where((tag) =>
          tag.name == 'Age Restricted' ||
              tag.name == 'Ebt Eligible').toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: primaryTags.length,
                itemBuilder: (context, index) {
                  final tag = primaryTags[index];
                  final isSelected = _selectedTag == tag;
                  return _buildTagCard(tag, isSelected);
                },
              ),
            ],
          );
        }

        /// ✅ Default empty UI
        return const SizedBox();
      },
    );
  }
}
