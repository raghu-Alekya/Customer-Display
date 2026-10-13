import '../inventory_attribute_items_model.dart';

abstract class InventoryAttributeItemsState {}

class InventoryAttributeItemsInitial
    extends InventoryAttributeItemsState {}

class InventoryAttributeItemsLoading
    extends InventoryAttributeItemsState {}

class InventoryAttributeItemsLoaded
    extends InventoryAttributeItemsState {
  final List<InventoryAttributeItemsModel> items;

  InventoryAttributeItemsLoaded(this.items);
}

class InventoryAttributeItemsError
    extends InventoryAttributeItemsState {
  final String message;

  InventoryAttributeItemsError(this.message);
}
