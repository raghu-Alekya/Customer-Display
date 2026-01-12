import 'inventory_attributes_entity.dart';
import 'inventory_attributes_repository.dart';

class InventoryAttributesGetUseCase {
  final InventoryAttributesRepository repository;

  InventoryAttributesGetUseCase({required this.repository});

  Future<List<InventoryAttributesEntity>> call() async {
    return await repository.getInventoryAttributes();
  }
}
