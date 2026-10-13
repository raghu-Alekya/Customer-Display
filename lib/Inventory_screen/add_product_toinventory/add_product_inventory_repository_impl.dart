import 'add_product_inventory_entity.dart';
import 'add_product_inventory_remote_data_source.dart';
import 'add_product_inventory_repository.dart';

class AddProductInventoryTaxRepositoryImpl implements AddProductInventoryTaxRepository {
  final AddProductInventoryTaxRemoteDataSource remoteDataSource;

  AddProductInventoryTaxRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AddProductInventoryTaxEntity> addProduct(AddProductInventoryTaxEntity product) async {
    final result = await remoteDataSource.addProduct(product.toJson());
    return AddProductInventoryTaxEntity.fromJson(result);
  }
}
