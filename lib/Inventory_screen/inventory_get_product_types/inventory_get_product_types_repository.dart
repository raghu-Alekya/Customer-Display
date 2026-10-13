import 'inventory_get_product_types_entity.dart';

abstract class InventoryGetProductTypesRepository {
  Future<InventoryGetProductTypesEntity> getProductTypes();
}
