

import 'inventory_tag_entity.dart';
import 'inventory_tag_remote_data_source.dart';
import 'inventory_tag_repository.dart';

class Inventory_Tag_Repository_Impl
    implements Inventory_Tag_Repository {
  final Inventory_Tag_Remote_Data_Source remoteDataSource;

  Inventory_Tag_Repository_Impl(this.remoteDataSource);

  @override
  Future<List<Inventory_Tag_Entity>> getInventoryTags() {
    return remoteDataSource.fetchInventoryTags();
  }
}
