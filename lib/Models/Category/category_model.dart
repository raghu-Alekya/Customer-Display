// models/category_model.dart
class CategoryModel { // Build #1.0.21
  final int id;
  final String name;
  final String slug;
  final int parent;
  final String description;
  final int count;
  final String? image;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
    required this.description,
    required this.count,
    this.image,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      parent: json['parent'] ?? 0,
      description: json['description'] ?? '',
      count: json['count'] ?? 0,
      image: json['image'],
    );
  }  

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'parent': parent,
      'description': description,
      'count': count,
      'image': image,
    };
  }

  // Add this copyWith method
  CategoryModel copyWith({
    int? id,
    String? name,
    String? slug,
    int? parent,
    String? description,
    int? count,
    String? image,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      parent: parent ?? this.parent,
      description: description ?? this.description,
      count: count ?? this.count,
      image: image ?? this.image,
    );
  }
}

class CategoryListResponse {
  final List<CategoryModel> categories;

  CategoryListResponse({required this.categories});

  factory CategoryListResponse.fromJson(List<dynamic> json) {
    return CategoryListResponse(
      categories: json.map((item) => CategoryModel.fromJson(item)).toList(),
    );
  }
}