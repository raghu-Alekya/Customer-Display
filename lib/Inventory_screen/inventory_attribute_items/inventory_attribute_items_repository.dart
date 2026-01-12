import 'inventory_attribute_items_entity.dart';

abstract class InventoryAttributeItemsRepository {
  Future<List<InventoryAttributeItemsEntity>> getInventoryAttributeItems({required int attributeId});
}
