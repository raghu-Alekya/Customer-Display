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

/// =============================================
/// 🔹 IMPROVED ATTRIBUTE DROPDOWN (with proper close on outside tap)
/// =============================================
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

class _InventoryAttributesDropdownState extends State<InventoryAttributesDropdown> {
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

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final searchController = TextEditingController();
    List<InventoryAttributesEntity> filteredList = List.from(attributes);

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown, // Close when tapping outside
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Background tap area
              Positioned.fill(
                child: GestureDetector(onTap: _removeDropdown),
              ),
              // Dropdown content
              CompositedTransformFollower(
                link: _layerLink,
                offset: const Offset(0, 48),
                showWhenUnlinked: false,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: StatefulBuilder(
                    builder: (context, setModalState) {
                      return Container(
                        width: 240,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search Field
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: searchController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Search attribute...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
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

                            // List of Attributes
                            Expanded(
                              child: filteredList.isEmpty
                                  ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No attributes found'),
                                ),
                              )
                                  : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final attr = filteredList[index];
                                  final isSelected =
                                      attr.id == selectedAttribute?.id;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedAttribute = attr;
                                      });
                                      widget.onAttributeSelected(attr);
                                      _removeDropdown();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 14,
                                      ),
                                      color: isSelected
                                          ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.12)
                                          : null,
                                      child: Text(
                                        attr.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : null,
                                        ),
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
            ],
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<InventoryAttributesBloc, InventoryAttributesState>(
      listener: (context, state) {
        if (state is InventoryAttributesLoaded) {
          setState(() {
            attributes = state.attributes;
            // Clear selection if selected attribute no longer exists
            if (selectedAttribute != null &&
                !attributes.any((a) => a.id == selectedAttribute!.id)) {
              selectedAttribute = null;
            }
          });
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.blueGrey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedAttribute?.name ?? 'Select Attribute',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedAttribute == null
                          ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                          : theme.textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================================
/// 🔹 PARENT WIDGET (Unchanged - Just cleaned up)
/// =============================================
class InventoryAttributesWithItemsWidget extends StatefulWidget {
  const InventoryAttributesWithItemsWidget({
    super.key,
    this.onAttributeSelected,
    this.onItemSelected,
    this.onItemSlugSelected,
    this.onAddItemTapped,
    this.onRegisterRefresher,
  });

  final void Function(InventoryAttributesEntity attribute)? onAttributeSelected;
  final void Function(InventoryAttributesEntity attribute, int itemId)? onItemSelected;
  final void Function(InventoryAttributesEntity attribute, String slug)? onItemSlugSelected;
  final VoidCallback? onAddItemTapped;
  final void Function(void Function(String newSlug) refresher)? onRegisterRefresher;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Attribute Dropdown
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

              const SizedBox(width: 8),

              // Right: Item Selector
              Expanded(
                child: selectedAttribute == null
                    ? Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Select Attribute First',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
                    : InventoryAttributeItemsWidget(
                  attributeId: selectedAttribute!.id,
                  onAddItemTapped: widget.onAddItemTapped,
                  onItemSelected: (itemSlug) {
                    widget.onItemSlugSelected?.call(
                      selectedAttribute!,
                      itemSlug,
                    );
                  },
                  onRegisterRefresher: widget.onRegisterRefresher,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}