

import 'inventory_attribute_items_entity.dart';
import 'inventory_attribute_items_remote_data_source.dart';
import 'inventory_attribute_items_repository.dart';

class InventoryAttributeItemsRepositoryImpl implements InventoryAttributeItemsRepository {
  final InventoryAttributeItemsRemoteDataSource remoteDataSource;

  InventoryAttributeItemsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<InventoryAttributeItemsEntity>> getInventoryAttributeItems({required int attributeId}) async {
    final items = await remoteDataSource.getInventoryAttributeItems(attributeId: attributeId);
    return items;
  }
}
