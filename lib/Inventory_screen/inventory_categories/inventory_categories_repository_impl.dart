

import 'inventory_categories_entity.dart';
import 'inventory_categories_remote_data_source.dart';
import 'inventory_categories_repository.dart';

class InventoryCategoriesRepositoryImpl implements InventoryCategoriesRepository {
  final InventoryCategoriesRemoteDataSource remoteDataSource;

  InventoryCategoriesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<InventoryCategoriesEntity>> getCategories() async {
    return await remoteDataSource.getCategories();
  }
}
