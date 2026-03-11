// Model classes for parsing the complete product variations API response
class ProductVariation { //Build 1.1.36: added for variations api
  final int id;
  final String type;
  final String dateCreated;
  final String dateCreatedGmt;
  final String dateModified;
  final String dateModifiedGmt;
  final String description;
  final String permalink;
  final String sku;
  final String globalUniqueId;
  final String price;
  final String regularPrice;
  final String salePrice;
  final String? dateOnSaleFrom;
  final String? dateOnSaleFromGmt;
  final String? dateOnSaleTo;
  final String? dateOnSaleToGmt;
  final bool onSale;
  final String status;
  final bool purchasable;
  final bool virtual;
  final bool downloadable;
  final List<Download> downloads;
  final int downloadLimit;
  final int downloadExpiry;
  final String taxStatus;
  final String taxClass;
  final bool manageStock; //Build #1.0.78: Changed from String to bool to match API response
  final int? stockQuantity;
  final String stockStatus;
  final String backorders;
  final bool backordersAllowed;
  final bool backordered;
  final int? lowStockAmount;
  final String weight;
  final Dimensions dimensions;
  final String shippingClass;
  final int shippingClassId;
  final VariationImage image;
  final List<Attribute> attributes;
  final int menuOrder;
  final List<MetaData> metaData;
  final String name;
  final int parentId;
  final Links links;

  ProductVariation({
    required this.id,
    required this.type,
    required this.dateCreated,
    required this.dateCreatedGmt,
    required this.dateModified,
    required this.dateModifiedGmt,
    required this.description,
    required this.permalink,
    required this.sku,
    required this.globalUniqueId,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    this.dateOnSaleFrom,
    this.dateOnSaleFromGmt,
    this.dateOnSaleTo,
    this.dateOnSaleToGmt,
    required this.onSale,
    required this.status,
    required this.purchasable,
    required this.virtual,
    required this.downloadable,
    required this.downloads,
    required this.downloadLimit,
    required this.downloadExpiry,
    required this.taxStatus,
    required this.taxClass,
    required this.manageStock,
    this.stockQuantity,
    required this.stockStatus,
    required this.backorders,
    required this.backordersAllowed,
    required this.backordered,
    this.lowStockAmount,
    required this.weight,
    required this.dimensions,
    required this.shippingClass,
    required this.shippingClassId,
    required this.image,
    required this.attributes,
    required this.menuOrder,
    required this.metaData,
    required this.name,
    required this.parentId,
    required this.links,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id'] as int,
      type: json['type'] as String,
      dateCreated: json['date_created'] as String,
      dateCreatedGmt: json['date_created_gmt'] as String,
      dateModified: json['date_modified'] as String,
      dateModifiedGmt: json['date_modified_gmt'] as String,
      description: json['description'] as String,
      permalink: json['permalink'] as String,
      sku: json['sku'] as String,
      globalUniqueId: json['global_unique_id'] as String,
      price: json['price'] as String,
      regularPrice: json['regular_price'] as String,
      salePrice: json['sale_price'] as String,
      dateOnSaleFrom: json['date_on_sale_from'] as String?,
      dateOnSaleFromGmt: json['date_on_sale_from_gmt'] as String?,
      dateOnSaleTo: json['date_on_sale_to'] as String?,
      dateOnSaleToGmt: json['date_on_sale_to_gmt'] as String?,
      onSale: _parseBool(json['on_sale']),
      status: json['status'] as String,
      purchasable: _parseBool(json['purchasable']),
      virtual: _parseBool(json['virtual']),
      downloadable: _parseBool(json['downloadable']),
      downloads: (json['downloads'] as List)
          .map((download) => Download.fromJson(download))
          .toList(),
      downloadLimit: json['download_limit'] as int,
      downloadExpiry: json['download_expiry'] as int,
      taxStatus: json['tax_status'] as String,
      taxClass: json['tax_class'] as String,
      manageStock: _parseBool(json['manage_stock']), //Build #1.0.78: Updated to use _parseBool
      stockQuantity: json['stock_quantity'] as int?,
      stockStatus: json['stock_status'] as String,
      backorders: json['backorders'] as String,
      backordersAllowed: _parseBool(json['backorders_allowed']),
      backordered: _parseBool(json['backordered']),
      lowStockAmount: json['low_stock_amount'] as int?,
      weight: json['weight'] as String,
      dimensions: Dimensions.fromJson(json['dimensions']),
      shippingClass: json['shipping_class'] as String,
      shippingClassId: json['shipping_class_id'] as int,
      image: VariationImage.fromJson(json['image']),
      attributes: (json['attributes'] as List)
          .map((attr) => Attribute.fromJson(attr))
          .toList(),
      menuOrder: json['menu_order'] as int,
      metaData: (json['meta_data'] as List)
          .map((meta) => MetaData.fromJson(meta))
          .toList(),
      name: json['name'] as String,
      parentId: json['parent_id'] as int,
      links: Links.fromJson(json['_links']),
    );
  }

  // Helper method to parse boolean values that might be strings
  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    } else if (value is String) {
      return value.toLowerCase() == 'true';
    } else {
      return false;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'date_created': dateCreated,
      'date_created_gmt': dateCreatedGmt,
      'date_modified': dateModified,
      'date_modified_gmt': dateModifiedGmt,
      'description': description,
      'permalink': permalink,
      'sku': sku,
      'global_unique_id': globalUniqueId,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'date_on_sale_from': dateOnSaleFrom,
      'date_on_sale_from_gmt': dateOnSaleFromGmt,
      'date_on_sale_to': dateOnSaleTo,
      'date_on_sale_to_gmt': dateOnSaleToGmt,
      'on_sale': onSale,
      'status': status,
      'purchasable': purchasable,
      'virtual': virtual,
      'downloadable': downloadable,
      'downloads': downloads.map((d) => d.toJson()).toList(),
      'download_limit': downloadLimit,
      'download_expiry': downloadExpiry,
      'tax_status': taxStatus,
      'tax_class': taxClass,
      'manage_stock': manageStock, //Build #1.0.78: Now a bool
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus,
      'backorders': backorders,
      'backorders_allowed': backordersAllowed,
      'backordered': backordered,
      'low_stock_amount': lowStockAmount,
      'weight': weight,
      'dimensions': dimensions.toJson(),
      'shipping_class': shippingClass,
      'shipping_class_id': shippingClassId,
      'image': image.toJson(),
      'attributes': attributes.map((attr) => attr.toJson()).toList(),
      'menu_order': menuOrder,
      'meta_data': metaData.map((meta) => meta.toJson()).toList(),
      'name': name,
      'parent_id': parentId,
      '_links': links.toJson(),
    };
  }
}

class Download {
  final String id;
  final String name;
  final String file;

  Download({
    required this.id,
    required this.name,
    required this.file,
  });

  factory Download.fromJson(Map<String, dynamic> json) {
    return Download(
      id: json['id'] as String,
      name: json['name'] as String,
      file: json['file'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'file': file,
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
      length: json['length'] as String,
      width: json['width'] as String,
      height: json['height'] as String,
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

class VariationImage {
  final int id;
  final String dateCreated;
  final String dateCreatedGmt;
  final String dateModified;
  final String dateModifiedGmt;
  final String src;
  final String name;
  final String alt;

  VariationImage({
    required this.id,
    required this.dateCreated,
    required this.dateCreatedGmt,
    required this.dateModified,
    required this.dateModifiedGmt,
    required this.src,
    required this.name,
    required this.alt,
  });

  factory VariationImage.fromJson(Map<String, dynamic> json) {
    return VariationImage(
      id: json['id'] as int,
      dateCreated: json['date_created'] as String,
      dateCreatedGmt: json['date_created_gmt'] as String,
      dateModified: json['date_modified'] as String,
      dateModifiedGmt: json['date_modified_gmt'] as String,
      src: json['src'] as String,
      name: json['name'] as String,
      alt: json['alt'] as String,
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

class Attribute {
  final int id;
  final String name;
  final String slug;
  final String option;

  Attribute({
    required this.id,
    required this.name,
    required this.slug,
    required this.option,
  });

  factory Attribute.fromJson(Map<String, dynamic> json) {
    return Attribute(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      option: json['option'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'option': option,
    };
  }
}

class MetaData {
  final int id;
  final String key;
  final dynamic value; // Changed to dynamic to handle various types

  MetaData({
    required this.id,
    required this.key,
    required this.value,
  });

  factory MetaData.fromJson(Map<String, dynamic> json) {
    return MetaData(
      id: json['id'] as int,
      key: json['key'] as String,
      value: json['value'], // Keep as dynamic
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
  final List<Link> self;
  final List<Link> collection;
  final List<Link> up;

  Links({
    required this.self,
    required this.collection,
    required this.up,
  });

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      self: (json['self'] as List).map((link) => Link.fromJson(link)).toList(),
      collection: (json['collection'] as List)
          .map((link) => Link.fromJson(link))
          .toList(),
      up: (json['up'] as List).map((link) => Link.fromJson(link)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'self': self.map((link) => link.toJson()).toList(),
      'collection': collection.map((link) => link.toJson()).toList(),
      'up': up.map((link) => link.toJson()).toList(),
    };
  }
}

class Link {
  final String href;
  final TargetHints? targetHints;

  Link({
    required this.href,
    this.targetHints,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      href: json['href'] as String,
      targetHints: json['targetHints'] != null
          ? TargetHints.fromJson(json['targetHints'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'href': href,
      'targetHints': targetHints?.toJson(),
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
      allow: List<String>.from(json['allow']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow': allow,
    };
  }
}