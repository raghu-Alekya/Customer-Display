
import 'inventory_tax_entity.dart';
import 'inventory_tax_repository.dart';

class Inventory_Tax_Get_UseCase {
  final Inventory_Tax_Repository repository;

  Inventory_Tax_Get_UseCase(this.repository);

  Future<List<Inventory_Tax_Entity>> call() {
    return repository.getInventoryTaxes();
  }
}
