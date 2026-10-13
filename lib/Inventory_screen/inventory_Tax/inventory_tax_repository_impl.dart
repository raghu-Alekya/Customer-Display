

import 'inventory_tax_entity.dart';
import 'inventory_tax_remote_data_source.dart';
import 'inventory_tax_repository.dart';

class Inventory_Tax_Repository_Impl implements Inventory_Tax_Repository {
  final Inventory_Tax_Remote_Data_Source remoteDataSource;

  Inventory_Tax_Repository_Impl(this.remoteDataSource);

  @override
  Future<List<Inventory_Tax_Entity>> getInventoryTaxes() {
    return remoteDataSource.fetchInventoryTaxes();
  }
}
