import 'package:pinaka_pos/Models/Search/product_by_sku_model.dart';

class ProductResponse { // Build #1.0.13 : Added product search model
  int? id;
  String? name;
  String? slug;
  String? description;
  String? shortDescription;
  String? sku;
  String? price;
  String? regularPrice;
  String? salePrice;
  String? dateCreated;
  String? dateModified;
  String? status;
  bool? onSale;
  bool? purchasable;
  int? stockQuantity;
  String? stockStatus;
  String? backorders;
  bool? backordersAllowed;
  String? lowStockAmount;
  String? weight;
  Dimensions? dimensions;
  List<String>? categories;
  List<Tags>? tags;
  List<String>? images;
  List<Attribute>? attributes;
  List<MetaData>? metaData;
  String? permalink;
  String? dateOnSaleFrom;
  String? dateOnSaleTo;
  List<int>? variations;

  // ✅ NEW: Cached loyalty points for quick access
  int? _cachedLoyaltyPoints;

  ProductResponse({
    this.id,
    this.name,
    this.slug,
    this.description,
    this.shortDescription,
    this.sku,
    this.price,
    this.regularPrice,
    this.salePrice,
    this.dateCreated,
    this.dateModified,
    this.status,
    this.onSale,
    this.purchasable,
    this.stockQuantity,
    this.stockStatus,
    this.backorders,
    this.backordersAllowed,
    this.lowStockAmount,
    this.weight,
    this.dimensions,
    this.categories,
    this.tags,
    this.images,
    this.attributes,
    this.metaData,
    this.permalink,
    this.dateOnSaleFrom,
    this.dateOnSaleTo,
    this.variations,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      id: json['id'] as int?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      shortDescription: json['short_description'] as String?,
      sku: json['sku'] as String?,
      price: json['price'] as String?,
      regularPrice: json['regular_price'] as String?,
      salePrice: json['sale_price'] as String?,
      dateCreated: json['date_created'] as String?,
      dateModified: json['date_modified'] as String?,
      status: json['status'] as String?,
      onSale: json['on_sale'] as bool?,
      purchasable: json['purchasable'] as bool?,
      stockQuantity: json['stock_quantity'] as int?,
      stockStatus: json['stock_status'] as String?,
      backorders: json['backorders'] as String?,
      backordersAllowed: json['backorders_allowed'] as bool?,
      lowStockAmount: json['low_stock_amount'] as String?,
      weight: json['weight'] as String?,
      dimensions: json['dimensions'] != null
          ? Dimensions.fromJson(json['dimensions'])
          : null,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'].map((x) => x.toString()))
          : null,
      tags: json['tags'] != null
          ? List<Tags>.from(json['tags'].map((x) => Tags.fromJson(x)))
          : null,
      images: _parseImages(json['images']),
      attributes: json['attributes'] != null
          ? List<Attribute>.from(
          json['attributes'].map((x) => Attribute.fromJson(x)))
          : null,
      metaData: json['meta_data'] != null
          ? List<MetaData>.from(
          json['meta_data'].map((x) => MetaData.fromJson(x)))
          : null,
      permalink: json['permalink'] as String?,
      dateOnSaleFrom: json['date_on_sale_from'] as String?,
      dateOnSaleTo: json['date_on_sale_to'] as String?,
      variations: (json['variations'] as List?)?.map((item) => item as int).toList() ?? [],
    );
  }

  static List<String>? _parseImages(dynamic images) {
    if (images == null) return null;

    if (images is List) {
      return images.map((image) {
        if (image is String) {
          return image;
        } else if (image is Map && image['src'] != null) {
          return image['src'].toString();
        }
        return '';
      }).where((url) => url.isNotEmpty).toList();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'short_description': shortDescription,
      'sku': sku,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'date_created': dateCreated,
      'date_modified': dateModified,
      'status': status,
      'on_sale': onSale,
      'purchasable': purchasable,
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus,
      'backorders': backorders,
      'backorders_allowed': backordersAllowed,
      'low_stock_amount': lowStockAmount,
      'weight': weight,
      'dimensions': dimensions?.toJson(),
      'categories': categories,
      'tags': tags?.map((x) => x.toJson()).toList(),
      'images': images,
      'attributes': attributes?.map((x) => x?.toJson()).toList(),
      'meta_data': metaData?.map((x) => x.toJson()).toList(),
      'permalink': permalink,
      'date_on_sale_from': dateOnSaleFrom,
      'date_on_sale_to': dateOnSaleTo,
      'variations': variations,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ NEW: Helper methods for loyalty points (no breaking changes)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get loyalty points from meta_data
  /// Checks both '_product_loyalty_points' and '_csv_loyalty_points' keys
  int getLoyaltyPoints() {
    // Return cached value if available
    if (_cachedLoyaltyPoints != null) return _cachedLoyaltyPoints!;

    if (metaData == null || metaData!.isEmpty) return 0;

    // Check for both possible keys
    final loyaltyEntry = metaData!.firstWhere(
          (m) => m.key == '_product_loyalty_points' || m.key == '_csv_loyalty_points',
      orElse: () => MetaData(),
    );

    if (loyaltyEntry.value != null) {
      _cachedLoyaltyPoints = int.tryParse(loyaltyEntry.value.toString()) ?? 0;
      return _cachedLoyaltyPoints!;
    }

    return 0;
  }

  /// Get all meta data as List of Maps for easy consumption
  List<Map<String, dynamic>> getMetaDataAsMap() {
    if (metaData == null || metaData!.isEmpty) return [];

    return metaData!.map((m) => {
      'id': m.id,
      'key': m.key ?? '',
      'value': m.value,
    }).toList();
  }

  /// Get specific meta data value by key
  dynamic getMetaValue(String key) {
    if (metaData == null || metaData!.isEmpty) return null;

    final entry = metaData!.firstWhere(
          (m) => m.key == key,
      orElse: () => MetaData(),
    );

    return entry.value;
  }

  /// Check if product has loyalty points
  bool hasLoyaltyPoints() {
    return getLoyaltyPoints() > 0;
  }

  /// Get loyalty points as String (useful for display)
  String getLoyaltyPointsAsString() {
    final points = getLoyaltyPoints();
    return points > 0 ? points.toString() : '';
  }
}

class Dimensions {
  String? length;
  String? width;
  String? height;

  Dimensions({this.length, this.width, this.height});

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      length: json['length'] as String?,
      width: json['width'] as String?,
      height: json['height'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'length': length,
      'width': width,
      'height': height,
    };
  }
}

class Attribute {
  int? id;
  String? name;
  String? option;
  List<String>? options;

  Attribute({this.id, this.name, this.option, this.options});

  factory Attribute.fromJson(Map<String, dynamic> json) {
    return Attribute(
      id: json['id'] as int?,
      name: json['name'] as String?,
      option: json['option'] as String?,
      options: json['options'] != null
          ? List<String>.from(json['options'].map((x) => x.toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'option': option,
      'options': options,
    };
  }
}

class MetaData {
  int? id;
  String? key;
  dynamic value;

  MetaData({this.id, this.key, this.value});

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] as int?,
      key: json['key'] as String?,
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'value': value,
    };
  }
}

// Uncomment if Tags class is needed
// class Tags {
//   int? id;
//   String? name;
//   String? slug;
//
//   Tags({this.id, this.name, this.slug});
//
//   factory Tags.fromJson(Map<String, dynamic> json) {
//     return Tags(
//       id: json['id'] as int?,
//       name: json['name'] as String?,
//       slug: json['slug'] as String?,
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'slug': slug,
//     };
//   }
// }

class ProductRequest { // Build #1.0.13 : Added product search model
  int page;
  int limit;
  String? search;

  ProductRequest({
    required this.page,
    required this.limit,
    this.search,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['page'] = page;
    data['limit'] = limit;
    if (search != null) {
      data['search'] = search;
    }
    return data;
  }
}