class FastKeyProductRequest {
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

/// =============================================
/// RESPONSE MODELS
/// =============================================

/// API RESPONSE: POST /fastkeys/add-products
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
          .toList() ??
          [],
    );
  }
}

/// =============================================
/// SHARED MODELS
/// =============================================

/// Meta Data Model (New - for loyalty points etc.)
class ProductMetaData {
  final int? id;
  final String? key;
  final String? value;

  ProductMetaData({
    this.id,
    this.key,
    this.value,
  });

  factory ProductMetaData.fromJson(Map<String, dynamic> json) {
    return ProductMetaData(
      id: json['id'] as int?,
      key: json['key'] as String?,
      value: json['value']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'value': value,
  };
}

/// Tags Model
class Tags {
  final int? id;
  final String? name;
  final String? slug;

  Tags({
    this.id,
    this.name,
    this.slug,
  });

  factory Tags.fromJson(Map<String, dynamic> json) {
    return Tags(
      id: json['id'] as int?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
  };
}

/// Main Product Model (Updated with meta_data)
class FastKeyProduct {
  final int productId;
  final String name;
  final String price;
  final String image;
  final List<String> category;
  final int slNumber;
  final List<Tags>? tags;
  final String? sku;
  final bool? isVariant;
  final bool? hasVariant;

  // ✅ NEW: Meta Data Support
  final List<ProductMetaData>? metaData;

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
    this.metaData, // Optional - No breaking changes
  });

  factory FastKeyProduct.fromJson(Map<String, dynamic> json) {
    return FastKeyProduct(
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      price: json['price']?.toString() ?? '0',
      image: json['image'] ?? '',
      category: (json['category'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList() ??
          [],
      slNumber: json['sl_number'] ?? 0,
      tags: json['tags'] != null
          ? List<Tags>.from(json['tags'].map((x) => Tags.fromJson(x)))
          : null,
      sku: json['sku'] ?? '',
      isVariant: json['is_variant'] ?? false,
      hasVariant: json['has_variants'] ?? false,

      // Meta Data Parsing
      metaData: (json['meta_data'] as List<dynamic>?)
          ?.map((item) => ProductMetaData.fromJson(item))
          .toList(),
    );
  }

  // Helper method
  int? getLoyaltyPoints() {
    if (metaData == null || metaData!.isEmpty) return null;
    for (var meta in metaData!) {
      if (meta.key == '_product_loyalty_points') {
        return int.tryParse(meta.value ?? '0');
      }
    }
    return null;
  }
}