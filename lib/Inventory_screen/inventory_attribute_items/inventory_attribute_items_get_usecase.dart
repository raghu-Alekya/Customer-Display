import 'inventory_attribute_items_entity.dart';
import 'inventory_attribute_items_repository.dart';

class GetInventoryAttributeItemsUseCase {
  final InventoryAttributeItemsRepository repository;

  GetInventoryAttributeItemsUseCase({required this.repository});

  Future<List<InventoryAttributeItemsEntity>> call({required int attributeId}) {
    return repository.getInventoryAttributeItems(attributeId: attributeId);
  }
}
