
import 'inventory_tag_entity.dart';

class Inventory_Tag_Model extends Inventory_Tag_Entity {
  const Inventory_Tag_Model({
    required int id,
    required String name,
    required String slug,
    required String description,
    required int count,
  }) : super(
    id: id,
    name: name,
    slug: slug,
    description: description,
    count: count,
  );

  factory Inventory_Tag_Model.fromJson(Map<String, dynamic> json) {
    return Inventory_Tag_Model(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'] ?? '',
      count: json['count'],
    );
  }
}
