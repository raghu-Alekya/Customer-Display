import 'inventory_categories_entity.dart';

abstract class InventoryCategoriesRepository {
  Future<List<InventoryCategoriesEntity>> getCategories();
}
