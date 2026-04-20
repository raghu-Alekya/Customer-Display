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

/// 🔹 ATTRIBUTE DROPDOWN (WITH INLINE SEARCH) — unchanged
class InventoryAttributesDropdown extends StatefulWidget {
  const InventoryAttributesDropdown({
    super.key,
    required this.onAttributeSelected,
  });

  final void Function(InventoryAttributesEntity attribute) onAttributeSelected;

  @override
  State<InventoryAttributesDropdown> createState() =>
      _InventoryAttributesDropdownState();
}

class _InventoryAttributesDropdownState
    extends State<InventoryAttributesDropdown> {
  InventoryAttributesEntity? selectedAttribute;
  List<InventoryAttributesEntity> attributes = [];

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    context
        .read<InventoryAttributesBloc>()
        .add(FetchInventoryAttributesEvent());
  }

  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    TextEditingController searchController = TextEditingController();
    List<InventoryAttributesEntity> filteredList = List.from(attributes);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 220,
          child: CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(0, 45),
            showWhenUnlinked: false,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 34,
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                filteredList = attributes
                                    .where((attr) => attr.name
                                    .toLowerCase()
                                    .contains(value.toLowerCase()))
                                    .toList();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final attr = filteredList[index];
                              return InkWell(
                                onTap: () {
                                  safeSetState(() {
                                    selectedAttribute = attr;
                                  });
                                  widget.onAttributeSelected(attr);
                                  _removeDropdown();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 6),
                                  child: Text(
                                    attr.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
    isDark ? Colors.grey.shade700 : Colors.blueGrey.shade200;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.white;

    return BlocListener<InventoryAttributesBloc, InventoryAttributesState>(
      listener: (context, state) {
        if (state is InventoryAttributesLoaded) {
          safeSetState(() {
            attributes = state.attributes;
            if (selectedAttribute != null &&
                !attributes.contains(selectedAttribute)) {
              selectedAttribute = null;
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: _toggleDropdown,
              child: Text(
                selectedAttribute?.name ?? 'Select',
                style: TextStyle(
                  fontSize: 13,
                  color: selectedAttribute == null ? hintColor : textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔹 PARENT WIDGET
class InventoryAttributesWithItemsWidget extends StatefulWidget {
  const InventoryAttributesWithItemsWidget({
    super.key,
    this.onAttributeSelected,
    this.onItemSelected,
    this.onItemSlugSelected,
    this.onAddItemTapped,
    // ✅ NEW: parent (InventoryScreen) calls this to get the refresher function
    this.onRegisterRefresher,
  });

  final void Function(InventoryAttributesEntity attribute)? onAttributeSelected;
  final void Function(InventoryAttributesEntity attribute, int itemId)?
  onItemSelected;
  final void Function(InventoryAttributesEntity attribute, String slug)?
  onItemSlugSelected;
  final VoidCallback? onAddItemTapped;

  // ✅ NEW callback: gives InventoryScreen a handle to call refreshAndSelect
  final void Function(void Function(String newSlug) refresher)?
  onRegisterRefresher;

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
            children: [
              /// LEFT — attribute picker
              Expanded(
                child: InventoryAttributesDropdown(
                  onAttributeSelected: (attribute) {
                    setState(() => selectedAttribute = attribute);
                    context.read<InventoryAttributeItemsBloc>().add(
                      FetchInventoryAttributeItems(attribute.id),
                    );
                    widget.onAttributeSelected?.call(attribute);
                  },
                ),
              ),

              const SizedBox(width: 6),

              /// RIGHT — item picker
              Expanded(
                child: selectedAttribute == null
                    ? Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
                    : InventoryAttributeItemsWidget(
                  attributeId: selectedAttribute!.id,
                  onAddItemTapped: () {
                    widget.onAddItemTapped?.call();
                  },
                  onItemSelected: (itemSlug) {
                    widget.onItemSlugSelected
                        ?.call(selectedAttribute!, itemSlug);
                  },
                  // ✅ NEW: pass the refresher registration up
                  onRegisterRefresher: (refreshFn) {
                    widget.onRegisterRefresher?.call(refreshFn);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}