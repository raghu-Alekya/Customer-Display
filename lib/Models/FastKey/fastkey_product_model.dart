<<<<<<< HEAD
/// FAST KEY PRODUCT MANAGEMENT MODELS
/// API: POST /fastkeys/add-products
/// Request for adding products to a FastKey
class FastKeyProductRequest {  // Build #1.0.15
  final int fastKeyId;
=======
class FastKeyProductRequest {
  final dynamic fastKeyId;
>>>>>>> origin/Grocery_pch_api_integration
  final List<FastKeyProductItem> products;

  FastKeyProductRequest({
    required this.fastKeyId,
    required this.products,
  });

  Map<String, dynamic> toJson() => {
<<<<<<< HEAD
    'fastkey_id': fastKeyId,
    'products': products.map((item) => item.toJson()).toList(),
  };
=======
        'fastkey_id': fastKeyId,
        'products': products.map((item) => item.toJson()).toList(),
      };
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
    return FastKeyProductResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      fastkeyId: json['fastkey_id'] ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item))
=======
    var rawId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    return FastKeyProductResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      fastkeyId: rawId ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item as Map<String, dynamic>))
>>>>>>> origin/Grocery_pch_api_integration
          .toList(),
      failedProducts: json['failed_products'] as List<dynamic>?,
    );
  }
}

/// API RESPONSE: GET /fastkeys/get-by-fastkey-id/{id}
<<<<<<< HEAD
/// Response for getting products in a specific FastKey
=======
>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Grocery_pch_api_integration
    );
  }
}

<<<<<<< HEAD
/// Shared model for FastKey Product representation
/// Used in both product addition and listing responses
=======
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
>>>>>>> origin/Grocery_pch_api_integration
class FastKeyProduct {
  final int productId;
  final String name;
  final String price;
<<<<<<< HEAD
  final String image; // Still a String, as it should be a URL or empty
  final List<String> category;
  final int slNumber;
  List<Tags>? tags;
=======
  final String image;
  final List<String> category;
  final int slNumber;
  final List<Tags>? tags;
>>>>>>> origin/Grocery_pch_api_integration
  final String? sku;
  final bool? isVariant;
  final bool? hasVariant;

<<<<<<< HEAD
=======
  // ✅ NEW: Meta Data Support
  final List<ProductMetaData>? metaData;

>>>>>>> origin/Grocery_pch_api_integration
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
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/Grocery_pch_api_integration
          : null,
      sku: json['sku'] ?? '',
      isVariant: json['is_variant'] ?? false,
      hasVariant: json['has_variants'] ?? false,
<<<<<<< HEAD
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
=======

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
>>>>>>> origin/Grocery_pch_api_integration
