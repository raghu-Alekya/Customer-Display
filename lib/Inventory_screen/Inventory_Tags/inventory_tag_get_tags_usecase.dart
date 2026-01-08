
import 'inventory_tag_entity.dart';
import 'inventory_tag_repository.dart';

class Inventory_Tag_Get_Tags_UseCase {
  final Inventory_Tag_Repository repository;

  Inventory_Tag_Get_Tags_UseCase(this.repository);

  Future<List<Inventory_Tag_Entity>> call() {
    return repository.getInventoryTags();
  }
}
