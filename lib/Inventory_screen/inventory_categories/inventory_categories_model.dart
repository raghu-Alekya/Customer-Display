
import 'inventory_categories_entity.dart';

class InventoryCategoriesModel extends InventoryCategoriesEntity {
  final int id;
  final String name;
  final String slug;
  final String imageUrl;
  final int count;

  InventoryCategoriesModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    required this.count,
  }) : super(id: id, name: name, slug: slug, imageUrl: imageUrl, count: count);

  factory InventoryCategoriesModel.fromJson(Map<String, dynamic> json) {
    return InventoryCategoriesModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      imageUrl: json['image'] != null ? json['image']['src'] : '',
      count: json['count'],
    );
  }
}
