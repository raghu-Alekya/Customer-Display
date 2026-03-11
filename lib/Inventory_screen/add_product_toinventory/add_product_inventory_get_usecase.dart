

import 'add_product_inventory_entity.dart';
import 'add_product_inventory_repository.dart';

class AddProductInventoryTaxGetUseCase {
  final AddProductInventoryTaxRepository repository;

  AddProductInventoryTaxGetUseCase({required this.repository});

  Future<AddProductInventoryTaxEntity> call(AddProductInventoryTaxEntity product) async {
    return await repository.addProduct(product);
  }
}
