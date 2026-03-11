import 'inventory_get_product_types_entity.dart';
import 'inventory_get_product_types_repository.dart';

class InventoryGetProductTypesGetUseCase {
  final InventoryGetProductTypesRepository repository;

  InventoryGetProductTypesGetUseCase({required this.repository});

  Future<InventoryGetProductTypesEntity> call() async {
    return await repository.getProductTypes();
  }
}
