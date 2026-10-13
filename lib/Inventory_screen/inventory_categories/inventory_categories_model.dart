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
    // Safe image parsing
    String imageUrl = '';
    if (json['image'] is Map) {
      final src = json['image']['src'];
      if (src is String) {
        imageUrl = src;
      }
    }

    // Safe count parsing
    int count = 0;
    if (json['count'] is int) {
      count = json['count'];
    }

    // Safe string parsing
    String name = json['name'] is String ? json['name'] : '';
    String slug = json['slug'] is String ? json['slug'] : '';
    int id = json['id'] is int ? json['id'] : 0;

    return InventoryCategoriesModel(
      id: id,
      name: name,
      slug: slug,
      imageUrl: imageUrl,
      count: count,
    );
  }
}