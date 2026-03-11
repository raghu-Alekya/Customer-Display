import 'inventory_categories_entity.dart';
import 'inventory_categories_repository.dart';

class InventoryCategoriesGetUseCase {
  final InventoryCategoriesRepository repository;

  InventoryCategoriesGetUseCase({required this.repository});

  Future<List<InventoryCategoriesEntity>> call() async {
    return await repository.getCategories();
  }
}
