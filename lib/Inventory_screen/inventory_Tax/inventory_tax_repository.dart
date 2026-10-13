import 'inventory_tax_entity.dart';

abstract class Inventory_Tax_Repository {
  Future<List<Inventory_Tax_Entity>> getInventoryTaxes();
}
