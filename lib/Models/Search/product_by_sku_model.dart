class ProductBySkuResponse { // Build #1.0.43: Added by naveen
  final int id;
  final String name;
  final String slug;
  final String permalink;
  final String dateCreated;
  final String dateCreatedGmt;
  final String dateModified;
  final String dateModifiedGmt;
  final String type;
  final String status;
  final bool featured;
  final String catalogVisibility;
  final String description;
  final String shortDescription;
  final String sku;
  final String price;
  final String regularPrice;
  final String salePrice;
  final dynamic dateOnSaleFrom;
  final dynamic dateOnSaleFromGmt;
  final dynamic dateOnSaleTo;
  final dynamic dateOnSaleToGmt;
  final bool onSale;
  final bool purchasable;
  final int totalSales;
  final bool virtual;
  final bool downloadable;
  final List<dynamic> downloads;
  final int downloadLimit;
  final int downloadExpiry;
  final String externalUrl;
  final String buttonText;
  final String taxStatus;
  final String taxClass;
  final bool manageStock;
  final dynamic stockQuantity;
  final String backorders;
  final bool backordersAllowed;
  final bool backordered;
  final dynamic lowStockAmount;
  final bool soldIndividually;
  final String weight;
  final Dimensions dimensions;
  final bool shippingRequired;
  final bool shippingTaxable;
  final String shippingClass;
  final int shippingClassId;
  final bool reviewsAllowed;
  final String averageRating;
  final int ratingCount;
  final List<dynamic> upsellIds;
  final List<dynamic> crossSellIds;
  final int parentId;
  final String purchaseNote;
  final List<Category> categories;
  final List<Tags>? tags;
  final List<Image> images;
  final List<dynamic> attributes;
  final List<dynamic> defaultAttributes;
  final List<dynamic> variations;
  final List<dynamic> groupedProducts;
  final int menuOrder;
  final String priceHtml;
  final List<int> relatedIds;
  final List<MetaData> metaData;
  final String stockStatus;
  final bool hasOptions;
  final String postPassword;
  final String globalUniqueId;
  final List<dynamic> brands;
  final Links links;

  ProductBySkuResponse({
    required this.id,
    required this.name,
    required this.slug,
    required this.permalink,
    required this.dateCreated,
    required this.dateCreatedGmt,
    required this.dateModified,
    required this.dateModifiedGmt,
    required this.type,
    required this.status,
    required this.featured,
    required this.catalogVisibility,
    required this.description,
    required this.shortDescription,
    required this.sku,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.dateOnSaleFrom,
    required this.dateOnSaleFromGmt,
    required this.dateOnSaleTo,
    required this.dateOnSaleToGmt,
    required this.onSale,
    required this.purchasable,
    required this.totalSales,
    required this.virtual,
    required this.downloadable,
    required this.downloads,
    required this.downloadLimit,
    required this.downloadExpiry,
    required this.externalUrl,
    required this.buttonText,
    required this.taxStatus,
    required this.taxClass,
    required this.manageStock,
    required this.stockQuantity,
    required this.backorders,
    required this.backordersAllowed,
    required this.backordered,
    required this.lowStockAmount,
    required this.soldIndividually,
    required this.weight,
    required this.dimensions,
    required this.shippingRequired,
    required this.shippingTaxable,
    required this.shippingClass,
    required this.shippingClassId,
    required this.reviewsAllowed,
    required this.averageRating,
    required this.ratingCount,
    required this.upsellIds,
    required this.crossSellIds,
    required this.parentId,
    required this.purchaseNote,
    required this.categories,
    required this.tags,
    required this.images,
    required this.attributes,
    required this.defaultAttributes,
    required this.variations,
    required this.groupedProducts,
    required this.menuOrder,
    required this.priceHtml,
    required this.relatedIds,
    required this.metaData,
    required this.stockStatus,
    required this.hasOptions,
    required this.postPassword,
    required this.globalUniqueId,
    required this.brands,
    required this.links,
  });

  // ✅ DETECT CUSTOM ITEM (MUST BE INSIDE CLASS)
  bool get isCustomItem {
    try {
      return type.toLowerCase() == "custom" ||
          metaData.any((m) =>
          m.key == "is_custom_item" &&
              (m.value == true || m.value == "true"));
    } catch (_) {
      return false;
    }
  }
// ✅ SAFE PRODUCT IMAGE GETTER
  String get productImage {
    try {
      if (images.isNotEmpty && images.first.src.isNotEmpty) {
        return images.first.src;
      }
    } catch (_) {}

    // fallback for custom items
    return "assets/custom.png";
  }

  factory ProductBySkuResponse.fromJson(Map<String, dynamic> json) {
    return ProductBySkuResponse(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      permalink: json['permalink'] ?? '',
      dateCreated: json['date_created'] ?? '',
      dateCreatedGmt: json['date_created_gmt'] ?? '',
      dateModified: json['date_modified'] ?? '',
      dateModifiedGmt: json['date_modified_gmt'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      featured: json['featured'] ?? false,
      catalogVisibility: json['catalog_visibility'] ?? '',
      description: json['description'] ?? '',
      shortDescription: json['short_description'] ?? '',
      sku: json['sku'] ?? '',
      price: json['price'] ?? '',
      regularPrice: json['regular_price'] ?? '',
      salePrice: json['sale_price'] ?? '',
      dateOnSaleFrom: json['date_on_sale_from'],
      dateOnSaleFromGmt: json['date_on_sale_from_gmt'],
      dateOnSaleTo: json['date_on_sale_to'],
      dateOnSaleToGmt: json['date_on_sale_to_gmt'],
      onSale: json['on_sale'] ?? false,
      purchasable: json['purchasable'] ?? false,
      totalSales: json['total_sales'] ?? 0,
      virtual: json['virtual'] ?? false,
      downloadable: json['downloadable'] ?? false,
      downloads: json['downloads'] ?? [],
      downloadLimit: json['download_limit'] ?? 0,
      downloadExpiry: json['download_expiry'] ?? 0,
      externalUrl: json['external_url'] ?? '',
      buttonText: json['button_text'] ?? '',
      taxStatus: json['tax_status'] ?? '',
      taxClass: json['tax_class'] ?? '',
      manageStock: json['manage_stock'] ?? false,
      stockQuantity: json['stock_quantity'],
      backorders: json['backorders'] ?? '',
      backordersAllowed: json['backorders_allowed'] ?? false,
      backordered: json['backordered'] ?? false,
      lowStockAmount: json['low_stock_amount'],
      soldIndividually: json['sold_individually'] ?? false,
      weight: json['weight'] ?? '',
      dimensions: Dimensions.fromJson(json['dimensions'] ?? {}),
      shippingRequired: json['shipping_required'] ?? false,
      shippingTaxable: json['shipping_taxable'] ?? false,
      shippingClass: json['shipping_class'] ?? '',
      shippingClassId: json['shipping_class_id'] ?? 0,
      reviewsAllowed: json['reviews_allowed'] ?? false,
      averageRating: json['average_rating'] ?? '',
      ratingCount: json['rating_count'] ?? 0,
      upsellIds: List<dynamic>.from(json['upsell_ids'] ?? []),
      crossSellIds: List<dynamic>.from(json['cross_sell_ids'] ?? []),
      parentId: json['parent_id'] ?? 0,
      purchaseNote: json['purchase_note'] ?? '',
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => Category.fromJson(e))
          .toList() ??
          [],
      tags: json['tags'] != null
          ? List<Tags>.from(json['tags'].map((x) => Tags.fromJson(x)))
          : null,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => Image.fromJson(e))
          .toList() ??
          [],
      attributes: List<dynamic>.from(json['attributes'] ?? []),
      defaultAttributes: List<dynamic>.from(json['default_attributes'] ?? []),
      variations: List<dynamic>.from(json['variations'] ?? []),
      groupedProducts: List<dynamic>.from(json['grouped_products'] ?? []),
      menuOrder: json['menu_order'] ?? 0,
      priceHtml: json['price_html'] ?? '',
      relatedIds: List<int>.from(json['related_ids'] ?? []),
      metaData: (json['meta_data'] as List<dynamic>?)
          ?.map((e) => MetaData.fromJson(e))
          .toList() ??
          [],
      stockStatus: json['stock_status'] ?? '',
      hasOptions: json['has_options'] ?? false,
      postPassword: json['post_password'] ?? '',
      globalUniqueId: json['global_unique_id'] ?? '',
      brands: List<dynamic>.from(json['brands'] ?? []),
      links: Links.fromJson(json['_links'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'permalink': permalink,
      'date_created': dateCreated,
      'date_created_gmt': dateCreatedGmt,
      'date_modified': dateModified,
      'date_modified_gmt': dateModifiedGmt,
      'type': type,
      'status': status,
      'featured': featured,
      'catalog_visibility': catalogVisibility,
      'description': description,
      'short_description': shortDescription,
      'sku': sku,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'date_on_sale_from': dateOnSaleFrom,
      'date_on_sale_from_gmt': dateOnSaleFromGmt,
      'date_on_sale_to': dateOnSaleTo,
      'date_on_sale_to_gmt': dateOnSaleToGmt,
      'on_sale': onSale,
      'purchasable': purchasable,
      'total_sales': totalSales,
      'virtual': virtual,
      'downloadable': downloadable,
      'downloads': downloads,
      'download_limit': downloadLimit,
      'download_expiry': downloadExpiry,
      'external_url': externalUrl,
      'button_text': buttonText,
      'tax_status': taxStatus,
      'tax_class': taxClass,
      'manage_stock': manageStock,
      'stock_quantity': stockQuantity,
      'backorders': backorders,
      'backorders_allowed': backordersAllowed,
      'backordered': backordered,
      'low_stock_amount': lowStockAmount,
      'sold_individually': soldIndividually,
      'weight': weight,
      'dimensions': dimensions.toJson(),
      'shipping_required': shippingRequired,
      'shipping_taxable': shippingTaxable,
      'shipping_class': shippingClass,
      'shipping_class_id': shippingClassId,
      'reviews_allowed': reviewsAllowed,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'upsell_ids': upsellIds,
      'cross_sell_ids': crossSellIds,
      'parent_id': parentId,
      'purchase_note': purchaseNote,
      'categories': categories.map((e) => e.toJson()).toList(),
      'tags': tags,
      'images': images.map((e) => e.toJson()).toList(),
      'attributes': attributes,
      'default_attributes': defaultAttributes,
      'variations': variations,
      'grouped_products': groupedProducts,
      'menu_order': menuOrder,
      'price_html': priceHtml,
      'related_ids': relatedIds,
      'meta_data': metaData.map((e) => e.toJson()).toList(),
      'stock_status': stockStatus,
      'has_options': hasOptions,
      'post_password': postPassword,
      'global_unique_id': globalUniqueId,
      'brands': brands,
      '_links': links.toJson(),
    };
  }
}

class Dimensions {
  final String length;
  final String width;
  final String height;

  Dimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      length: json['length'] ?? '',
      width: json['width'] ?? '',
      height: json['height'] ?? '',
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

class Category {
  final int id;
  final String name;
  final String slug;

  Category({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
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

class Image {
  final int id;
  final String dateCreated;
  final String dateCreatedGmt;
  final String dateModified;
  final String dateModifiedGmt;
  final String src;
  final String name;
  final String alt;

  Image({
    required this.id,
    required this.dateCreated,
    required this.dateCreatedGmt,
    required this.dateModified,
    required this.dateModifiedGmt,
    required this.src,
    required this.name,
    required this.alt,
  });

  factory Image.fromJson(Map<String, dynamic> json) {
    return Image(
      id: json['id'] ?? 0,
      dateCreated: json['date_created'] ?? '',
      dateCreatedGmt: json['date_created_gmt'] ?? '',
      dateModified: json['date_modified'] ?? '',
      dateModifiedGmt: json['date_modified_gmt'] ?? '',
      src: json['src'] ?? '',
      name: json['name'] ?? '',
      alt: json['alt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_created': dateCreated,
      'date_created_gmt': dateCreatedGmt,
      'date_modified': dateModified,
      'date_modified_gmt': dateModifiedGmt,
      'src': src,
      'name': name,
      'alt': alt,
    };
  }
}

class MetaData {
  final int id;
  final String key;
  final dynamic value;

  MetaData({
    required this.id,
    required this.key,
    required this.value,
  });

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
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

class Links {
  final List<Self> self;
  final List<Collection> collection;

  Links({
    required this.self,
    required this.collection,
  });

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      self: (json['self'] as List<dynamic>?)
          ?.map((e) => Self.fromJson(e))
          .toList() ??
          [],
      collection: (json['collection'] as List<dynamic>?)
          ?.map((e) => Collection.fromJson(e))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'self': self.map((e) => e.toJson()).toList(),
      'collection': collection.map((e) => e.toJson()).toList(),
    };
  }
}

class Self {
  final String href;
  final TargetHints targetHints;

  Self({
    required this.href,
    required this.targetHints,
  });

  factory Self.fromJson(Map<String, dynamic> json) {
    return Self(
      href: json['href'] ?? '',
      targetHints: TargetHints.fromJson(json['targetHints'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'href': href,
      'targetHints': targetHints.toJson(),
    };
  }
}

class TargetHints {
  final List<String> allow;

  TargetHints({
    required this.allow,
  });

  factory TargetHints.fromJson(Map<String, dynamic> json) {
    return TargetHints(
      allow: List<String>.from(json['allow'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow': allow,
    };
  }
}

class Collection {
  final String href;

  Collection({
    required this.href,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      href: json['href'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'href': href,
    };
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