
import 'inventory_tag_entity.dart';

abstract class Inventory_Tag_Repository {
  Future<List<Inventory_Tag_Entity>> getInventoryTags();
}
