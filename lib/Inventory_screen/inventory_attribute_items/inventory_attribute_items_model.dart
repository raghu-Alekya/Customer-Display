import 'inventory_attribute_items_entity.dart';

class InventoryAttributeItemsModel extends InventoryAttributeItemsEntity {
  InventoryAttributeItemsModel({
    required int id,
    required String name,
    required String slug,
  }) : super(id: id, name: name, slug: slug);

  factory InventoryAttributeItemsModel.fromJson(Map<String, dynamic> json) {
    return InventoryAttributeItemsModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
  };
}
