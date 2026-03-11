/// FAST KEY PRODUCT MANAGEMENT MODELS
/// API: POST /fastkeys/add-products
/// Request for adding products to a FastKey
class FastKeyProductRequest {  // Build #1.0.15
  final int fastKeyId;
  final List<FastKeyProductItem> products;

  FastKeyProductRequest({
    required this.fastKeyId,
    required this.products,
  });

  Map<String, dynamic> toJson() => {
    'fastkey_id': fastKeyId,
    'products': products.map((item) => item.toJson()).toList(),
  };
}

/// Individual product item for adding to FastKey
class FastKeyProductItem {
  final int productId;
  final int slNumber;

  FastKeyProductItem({
    required this.productId,
    required this.slNumber,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'sl_number': slNumber,
  };
}

/// API RESPONSE: POST /fastkeys/add-products
/// Response when adding products to FastKey
class FastKeyProductResponse {
  final String status;
  final String message;
  final int fastkeyId;
  final List<FastKeyProduct>? products;
  final List<dynamic>? failedProducts;

  FastKeyProductResponse({
    required this.status,
    required this.message,
    required this.fastkeyId,
    this.products,
    this.failedProducts,
  });

  factory FastKeyProductResponse.fromJson(Map<String, dynamic> json) {
    return FastKeyProductResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      fastkeyId: json['fastkey_id'] ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item))
          .toList(),
      failedProducts: json['failed_products'] as List<dynamic>?,
    );
  }
}

/// API RESPONSE: GET /fastkeys/get-by-fastkey-id/{id}
/// Response for getting products in a specific FastKey
class FastKeyProductsResponse {
  final String status;
  final String message;
  final String fastkeyId;
  final String fastkeyTitle;
  final dynamic fastkeyImage;
  final String fastkeyIndex;
  final List<FastKeyProduct> products;

  FastKeyProductsResponse({
    required this.status,
    required this.message,
    required this.fastkeyId,
    required this.fastkeyTitle,
    required this.fastkeyImage,
    required this.fastkeyIndex,
    required this.products,
  });

  factory FastKeyProductsResponse.fromJson(Map<String, dynamic> json) {
    return FastKeyProductsResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      fastkeyId: json['fastkey_id']?.toString() ?? '0',
      fastkeyTitle: json['fastkey_title'] ?? '',
      fastkeyImage: json['fastkey_image'],
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item))
          .toList() ?? [],
    );
  }
}

/// Shared model for FastKey Product representation
/// Used in both product addition and listing responses
class FastKeyProduct {
  final int productId;
  final String name;
  final String price;
  final String image; // Still a String, as it should be a URL or empty
  final List<String> category;
  final int slNumber;
  List<Tags>? tags;
  final String? sku;
  final bool? isVariant;
  final bool? hasVariant;

  FastKeyProduct({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.category,
    required this.slNumber,
    this.tags,
    this.sku,
    this.isVariant,
    this.hasVariant,
  });

  factory FastKeyProduct.fromJson(Map<String, dynamic> json) {
    return FastKeyProduct(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      price: json['price']?.toString() ?? '0',
      image: json['image'] ?? '',
      category: (json['category'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList() ?? [],
      slNumber: json['sl_number'] ?? 0,
      tags: json['tags'] != null
          ? List<Tags>.from(json['tags'].map((x) => Tags.fromJson(x)))
          : null,
      sku: json['sku'] ?? '',
      isVariant: json['is_variant'] ?? false,
      hasVariant: json['has_variants'] ?? false,
    );
  }
}

class Tags {
  int? id;
  String? name;
  String? slug;

  Tags({this.id, this.name, this.slug});

  factory Tags.fromJson(Map<String, dynamic> json) {
    return Tags(
      id: json['id'] as int?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
    };
  }
}