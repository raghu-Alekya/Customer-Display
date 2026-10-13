// new_category_models.dart
import 'dart:convert';

class Product {
  final int id;
  final String name;
  final String price;
  final dynamic image;
  final int count;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    required this.count,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    price: json['price']?.toString() ?? '0',
    image: json['image'],
    count: json['count'] ?? 0,
  );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'price': price, 'image': image, 'count': count};
}

class NewCategoryModel {
  final int id;
  final String name;
  final String slug;
  final int parent;
  final String description;
  final int count;
  final String? image;
  final List<Product> products;
  final List<NewCategoryModel> children;

  NewCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
    required this.description,
    required this.count,
    this.image,
    required this.products,
    required this.children,
  });

  factory NewCategoryModel.fromJson(Map<String, dynamic> json) => NewCategoryModel(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    parent: json['parent'] ?? 0,
    description: json['description'] ?? '',
    count: json['count'] ?? 0,
    image: json['image']?.toString(),
    products: (json['products'] as List? ?? [])
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    children: (json['children'] as List? ?? [])
        .map((e) => NewCategoryModel.fromJson(
        Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'parent': parent,
    'description': description,
    'count': count,
    'image': image,
    'products': products.map((e) => e.toJson()).toList(),
    'children': children.map((e) => e.toJson()).toList(),
  };
}

/// Wrapper that accepts Map/List/String and always gives you List<NewCategoryModel>.
class NewCategoryListResponse {
  final String? status; // optional (present when the root is a Map)
  final List<NewCategoryModel> categories;

  NewCategoryListResponse({this.status, required this.categories});

  /// Universal parser: String JSON, Map with "category", or raw List.
  factory NewCategoryListResponse.fromAny(dynamic data) {
    if (data == null) {
      return NewCategoryListResponse(categories: []);
    }

    // If a JSON string
    if (data is String) {
      final decoded = json.decode(data);
      return NewCategoryListResponse.fromAny(decoded);
    }

    // If it's a Map root like { "status": "...", "category": [ ... ] }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      final list = (map['category'] as List? ?? []);
      final cats = list
          .map((e) => NewCategoryModel.fromJson(
          Map<String, dynamic>.from(e as Map)))
          .toList();
      return NewCategoryListResponse(status: map['status']?.toString(), categories: cats);
    }

    // If it's already a List root like [ {id:..}, {id:..} ]
    if (data is List) {
      final cats = data
          .map((e) => NewCategoryModel.fromJson(
          Map<String, dynamic>.from(e as Map)))
          .toList();
      return NewCategoryListResponse(categories: cats);
    }

    // Fallback
    return NewCategoryListResponse(categories: []);
  }
}
