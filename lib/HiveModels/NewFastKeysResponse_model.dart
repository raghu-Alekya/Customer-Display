class NewFastKeysResponse {
  final int userId;
  final String message;
  final String status;
  final List<NewFastKey> fastkeys;

  NewFastKeysResponse({
    required this.userId,
    required this.message,
    required this.status,
    required this.fastkeys,
  });

  factory NewFastKeysResponse.fromJson(Map<String, dynamic> json) {
    return NewFastKeysResponse(
      userId: json['user_id'] ?? 0,
      message: json['message'] ?? '',
      status: json['status'] ?? '',
      fastkeys: (json['fastkeys'] as List? ?? [])
          .map((e) => NewFastKey.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "message": message,
      "status": status,
      "fastkeys": fastkeys.map((e) => e.toJson()).toList(),
    };
  }
}

class NewFastKey {
  final int fastkeyId;
  final String fastkeyTitle;
  final String fastkeyImage;
  final int itemCount;
  final int userId;
  final int fastkeyIndex;
  final List<Product> products;

  NewFastKey({
    required this.fastkeyId,
    required this.fastkeyTitle,
    required this.fastkeyImage,
    required this.itemCount,
    required this.userId,
    required this.fastkeyIndex,
    required this.products,
  });

  factory NewFastKey.fromJson(Map<String, dynamic> json) {
    return NewFastKey(
      fastkeyId: json['fastkey_id'] ?? 0,
      fastkeyTitle: json['fastkey_title'] ?? '',
      fastkeyImage: json['fastkey_image'] ?? '',
      itemCount: json['itemCount'] ?? 0,
      userId: json['user_id'] ?? 0,
      fastkeyIndex: json['fastkey_index'] ?? 0,
      products: (json['products'] as List? ?? [])
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "fastkey_id": fastkeyId,
      "fastkey_title": fastkeyTitle,
      "fastkey_image": fastkeyImage,
      "itemCount": itemCount,
      "user_id": userId,
      "fastkey_index": fastkeyIndex,
      "products": products.map((e) => e.toJson()).toList(),
    };
  }
}

class Product {
  final int productId;
  final String name;
  final String price;
  final String image;
  final List<String> category;
  final int slNumber;
  final String sku;
  final bool isVariant;
  final bool hasVariants;
  final List<Tag> tags;

  Product({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.category,
    required this.slNumber,
    required this.sku,
    required this.isVariant,
    required this.hasVariants,
    required this.tags,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      price: json['price'] ?? '0',
      image: json['image'] ?? '',
      category: (json['category'] as List? ?? []).map((e) => e.toString()).toList(),
      slNumber: json['sl_number'] ?? 0,
      sku: json['sku'] ?? '',
      isVariant: json['is_variant'] ?? false,
      hasVariants: json['has_variants'] ?? false,
      tags: (json['tags'] as List? ?? [])
          .map((e) => Tag.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "product_id": productId,
      "name": name,
      "price": price,
      "image": image,
      "category": category,
      "sl_number": slNumber,
      "sku": sku,
      "is_variant": isVariant,
      "has_variants": hasVariants,
      "tags": tags.map((e) => e.toJson()).toList(),
    };
  }
}

class Tag {
  final String name;
  final String slug;
  final int id;

  Tag({
    required this.name,
    required this.slug,
    required this.id,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      id: json['id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "slug": slug,
      "id": id,
    };
  }
}
