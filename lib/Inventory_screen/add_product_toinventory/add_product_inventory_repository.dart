import 'add_product_inventory_entity.dart';

abstract class AddProductInventoryTaxRepository {
  Future<AddProductInventoryTaxEntity> addProduct(AddProductInventoryTaxEntity product);
}
