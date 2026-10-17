class FastKeyProductRequest {
  final dynamic fastKeyId;
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
  final dynamic fastkeyId;
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
    var rawId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    return FastKeyProductResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      fastkeyId: rawId ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item as Map<String, dynamic>))
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
    final responseData = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final rawProducts = responseData['products'];

    return FastKeyProductsResponse(
      status: responseData['status']?.toString() ?? '',
      message: responseData['message']?.toString() ?? '',
      fastkeyId: (responseData['fastkey_id'] ?? responseData['fastkeyId'])
              ?.toString() ??
          '0',
      fastkeyTitle: responseData['fastkey_title']?.toString() ?? '',
      fastkeyImage: responseData['fastkey_image'],
      fastkeyIndex: responseData['fastkey_index']?.toString() ?? '0',
      products: (rawProducts is List ? rawProducts : null)
              ?.whereType<Map>()
              .map((item) =>
                  FastKeyProduct.fromJson(Map<String, dynamic>.from(item)))
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
      id: int.tryParse(json['id']?.toString() ?? ''),
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
      id: int.tryParse(json['id']?.toString() ?? ''),
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
    var rawProductId = json['product_id'] ?? json['id'] ?? 0;
    final parsedProductId = rawProductId is int
        ? rawProductId
        : int.tryParse(rawProductId.toString());
    if (parsedProductId == null || parsedProductId <= 0) {
      throw FormatException('FastKey product has an invalid product_id');
    }

    var rawSlNumber = json['sl_number'] ?? json['slNumber'] ?? 0;
    int parsedSlNumber;
    if (rawSlNumber is int) {
      parsedSlNumber = rawSlNumber;
    } else if (rawSlNumber != null &&
        int.tryParse(rawSlNumber.toString()) != null) {
      parsedSlNumber = int.parse(rawSlNumber.toString());
    } else {
      parsedSlNumber = 0;
    }

    return FastKeyProduct(
      productId: parsedProductId,
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      image:
          json['image']?.toString() ?? json['fastkey_image']?.toString() ?? '',
      category: (json['category'] is List ? json['category'] as List : null)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      slNumber: parsedSlNumber,
      tags: json['tags'] is List
          ? (json['tags'] as List)
              .whereType<Map>()
              .map((tag) => Tags.fromJson(Map<String, dynamic>.from(tag)))
              .toList()
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
