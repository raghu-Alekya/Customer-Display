
import 'inventory_attributes_entity.dart';

abstract class InventoryAttributesRepository {
  Future<List<InventoryAttributesEntity>> getInventoryAttributes();
}
