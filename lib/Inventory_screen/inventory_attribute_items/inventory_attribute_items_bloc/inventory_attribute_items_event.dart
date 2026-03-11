abstract class InventoryAttributeItemsEvent {}

class FetchInventoryAttributeItems
    extends InventoryAttributeItemsEvent {
  final int attributeId;

  FetchInventoryAttributeItems(this.attributeId);
}
