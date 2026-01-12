import 'inventory_get_product_types_entity.dart';
import 'inventory_get_product_types_remote_data_source.dart';
import 'inventory_get_product_types_repository.dart';

class InventoryGetProductTypesRepositoryImpl
    implements InventoryGetProductTypesRepository {
  final InventoryGetProductTypesRemoteDataSource remoteDataSource;

  InventoryGetProductTypesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<InventoryGetProductTypesEntity> getProductTypes() async {
    return await remoteDataSource.getProductTypes();
  }
}
