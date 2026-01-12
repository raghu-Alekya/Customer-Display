import 'inventory_attributes_entity.dart';
import 'inventory_attributes_model.dart';
import 'inventory_attributes_remote_data_source.dart';
import 'inventory_attributes_repository.dart';

class InventoryAttributesRepositoryImpl implements InventoryAttributesRepository {
  final InventoryAttributesRemoteDataSource remoteDataSource;

  InventoryAttributesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<InventoryAttributesEntity>> getInventoryAttributes() async {
    final List<InventoryAttributesModel> models = await remoteDataSource.getInventoryAttributes();
    return models.map((model) => InventoryAttributesEntity(
      id: model.id,
      name: model.name,
      slug: model.slug,
      type: model.type,
    )).toList();
  }
}
