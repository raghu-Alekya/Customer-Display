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


// import 'package:flutter/material.dart';

class VariablePriceCheckboxWidget extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  // ✅ NEW
  final String name;
  final String slug;

  const VariablePriceCheckboxWidget({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.name,
    required this.slug,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (val) {
              if (val != null) {
                // ✅ Debug prints similar to InventoryTagMultiSelectWidget
                debugPrint('Tag Selected -> name: $name, slug: $slug');

                // ✅ Print in the [name, slug] style like your tag widget
                debugPrint('$name Tag -> [name: $name, slug: $slug]');

                onChanged(val); // callback
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: isDark ? Colors.white38 : const Color(0xFFBDBDBD),
              width: 2,
            ),
            checkColor: Colors.white,
            fillColor: MaterialStateProperty.all(
              const Color(0xFF2196F3),
            ),
          ),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            text: 'If the product has ',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            children: const [
              TextSpan(
                text: 'Variable Price',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}