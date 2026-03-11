// Models for API request and response
// class Tag {
//   String name;
//
//   Tag({required this.name});
//
//   Map<String, dynamic> toJson() => {
//     'name': name,
//   };
// }

class AddCustomItemRequest { //Build #1.0.68
  final String name;
  final String type;
  final String regularPrice;
  final String sku;
  final String? taxStatus;
  final String? taxClass;
  final List<Tag> tags;

  AddCustomItemRequest({
    required this.name,
    this.type = "simple",
    required this.regularPrice,
    required this.sku,
    this.taxStatus,
    this.taxClass,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'regular_price': regularPrice,
      'sku': sku,
      'tax_status': taxStatus,
      'tax_class': taxClass,
      'tags': tags.map((tag) => tag.toJson()).toList(),
    };
  }
}

class Tax {
  int id;
  String name;

  Tax({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class AddCustomItemModel {
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
  String? dateCreatedGmt;
  String? dateModified;
  String? dateModifiedGmt;
  String? status;
  bool? featured;
  String? catalogVisibility;
  bool? onSale;
  bool? purchasable;
  int? totalSales;
  bool? virtual;
  bool? downloadable;
  List<Download>? downloads;
  int? downloadLimit;
  int? downloadExpiry;
  String? externalUrl;
  String? buttonText;
  String? taxStatus;
  String? taxClass;
  bool? manageStock;
  int? stockQuantity;
  String? stockStatus;
  String? backorders;
  bool? backordersAllowed;
  bool? backordered;
  String? lowStockAmount;
  bool? soldIndividually;
  String? weight;
  Dimensions? dimensions;
  bool? shippingRequired;
  bool? shippingTaxable;
  String? shippingClass;
  int? shippingClassId;
  bool? reviewsAllowed;
  String? averageRating;
  int? ratingCount;
  List<int>? upsellIds;
  List<int>? crossSellIds;
  int? parentId;
  String? purchaseNote;
  List<Category>? categories;
  List<Tag>? tags;
  List<Image>? images;
  List<Attribute>? attributes;
  List<DefaultAttribute>? defaultAttributes;
  List<int>? variations;
  List<int>? groupedProducts;
  int? menuOrder;
  String? priceHtml;
  List<int>? relatedIds;
  List<MetaData>? metaData;
  String? permalink;
  String? dateOnSaleFrom;
  String? dateOnSaleFromGmt;
  String? dateOnSaleTo;
  String? dateOnSaleToGmt;
  bool? hasOptions;
  String? postPassword;
  String? globalUniqueId;
  String? permalinkTemplate;
  String? generatedSlug;
  List<dynamic>? brands;
  Links? links;

  AddCustomItemModel({
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
    this.dateCreatedGmt,
    this.dateModified,
    this.dateModifiedGmt,
    this.status,
    this.featured,
    this.catalogVisibility,
    this.onSale,
    this.purchasable,
    this.totalSales,
    this.virtual,
    this.downloadable,
    this.downloads,
    this.downloadLimit,
    this.downloadExpiry,
    this.externalUrl,
    this.buttonText,
    this.taxStatus,
    this.taxClass,
    this.manageStock,
    this.stockQuantity,
    this.stockStatus,
    this.backorders,
    this.backordersAllowed,
    this.backordered,
    this.lowStockAmount,
    this.soldIndividually,
    this.weight,
    this.dimensions,
    this.shippingRequired,
    this.shippingTaxable,
    this.shippingClass,
    this.shippingClassId,
    this.reviewsAllowed,
    this.averageRating,
    this.ratingCount,
    this.upsellIds,
    this.crossSellIds,
    this.parentId,
    this.purchaseNote,
    this.categories,
    this.tags,
    this.images,
    this.attributes,
    this.defaultAttributes,
    this.variations,
    this.groupedProducts,
    this.menuOrder,
    this.priceHtml,
    this.relatedIds,
    this.metaData,
    this.permalink,
    this.dateOnSaleFrom,
    this.dateOnSaleFromGmt,
    this.dateOnSaleTo,
    this.dateOnSaleToGmt,
    this.hasOptions,
    this.postPassword,
    this.globalUniqueId,
    this.permalinkTemplate,
    this.generatedSlug,
    this.brands,
    this.links,
  });

  factory AddCustomItemModel.fromJson(Map<String, dynamic> json) {
    return AddCustomItemModel(
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
      dateCreatedGmt: json['date_created_gmt'] as String?,
      dateModified: json['date_modified'] as String?,
      dateModifiedGmt: json['date_modified_gmt'] as String?,
      status: json['status'] as String?,
      featured: json['featured'] as bool?,
      catalogVisibility: json['catalog_visibility'] as String?,
      onSale: json['on_sale'] as bool?,
      purchasable: json['purchasable'] as bool?,
      totalSales: json['total_sales'] as int?,
      virtual: json['virtual'] as bool?,
      downloadable: json['downloadable'] as bool?,
      downloads: json['downloads'] != null
          ? (json['downloads'] as List<dynamic>).map((d) => Download.fromJson(d as Map<String, dynamic>)).toList()
          : null,
      downloadLimit: json['download_limit'] as int?,
      downloadExpiry: json['download_expiry'] as int?,
      externalUrl: json['external_url'] as String?,
      buttonText: json['button_text'] as String?,
      taxStatus: json['tax_status'] as String?,
      taxClass: json['tax_class'] as String?,
      manageStock: json['manage_stock'] as bool?,
      stockQuantity: json['stock_quantity'] as int?,
      stockStatus: json['stock_status'] as String?,
      backorders: json['backorders'] as String?,
      backordersAllowed: json['backorders_allowed'] as bool?,
      backordered: json['backordered'] as bool?,
      lowStockAmount: json['low_stock_amount'] as String?,
      soldIndividually: json['sold_individually'] as bool?,
      weight: json['weight'] as String?,
      dimensions: json['dimensions'] != null
          ? Dimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : null,
      shippingRequired: json['shipping_required'] as bool?,
      shippingTaxable: json['shipping_taxable'] as bool?,
      shippingClass: json['shipping_class'] as String?,
      shippingClassId: json['shipping_class_id'] as int?,
      reviewsAllowed: json['reviews_allowed'] as bool?,
      averageRating: json['average_rating'] as String?,
      ratingCount: json['rating_count'] as int?,
      upsellIds: json['upsell_ids'] != null
          ? List<int>.from(json['upsell_ids'] as List<dynamic>)
          : null,
      crossSellIds: json['cross_sell_ids'] != null
          ? List<int>.from(json['cross_sell_ids'] as List<dynamic>)
          : null,
      parentId: json['parent_id'] as int?,
      purchaseNote: json['purchase_note'] as String?,
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>).map((c) => Category.fromJson(c as Map<String, dynamic>)).toList()
          : null,
      tags: json['tags'] != null
          ? (json['tags'] as List<dynamic>).map((t) => Tag.fromJson(t as Map<String, dynamic>)).toList()
          : null,
      images: json['images'] != null
          ? (json['images'] as List<dynamic>).map((i) => Image.fromJson(i as Map<String, dynamic>)).toList()
          : null,
      attributes: json['attributes'] != null
          ? (json['attributes'] as List<dynamic>).map((a) => Attribute.fromJson(a as Map<String, dynamic>)).toList()
          : null,
      defaultAttributes: json['default_attributes'] != null
          ? (json['default_attributes'] as List<dynamic>).map((a) => DefaultAttribute.fromJson(a as Map<String, dynamic>)).toList()
          : null,
      variations: json['variations'] != null
          ? List<int>.from(json['variations'] as List<dynamic>)
          : null,
      groupedProducts: json['grouped_products'] != null
          ? List<int>.from(json['grouped_products'] as List<dynamic>)
          : null,
      menuOrder: json['menu_order'] as int?,
      priceHtml: json['price_html'] as String?,
      relatedIds: json['related_ids'] != null
          ? List<int>.from(json['related_ids'] as List<dynamic>)
          : null,
      metaData: json['meta_data'] != null
          ? (json['meta_data'] as List<dynamic>).map((m) => MetaData.fromJson(m as Map<String, dynamic>)).toList()
          : null,
      permalink: json['permalink'] as String?,
      dateOnSaleFrom: json['date_on_sale_from'] as String?,
      dateOnSaleFromGmt: json['date_on_sale_from_gmt'] as String?,
      dateOnSaleTo: json['date_on_sale_to'] as String?,
      dateOnSaleToGmt: json['date_on_sale_to_gmt'] as String?,
      hasOptions: json['has_options'] as bool?,
      postPassword: json['post_password'] as String?,
      globalUniqueId: json['global_unique_id'] as String?,
      permalinkTemplate: json['permalink_template'] as String?,
      generatedSlug: json['generated_slug'] as String?,
      brands: json['brands'] != null ? List<dynamic>.from(json['brands'] as List<dynamic>) : null,
      links: json['_links'] != null ? Links.fromJson(json['_links'] as Map<String, dynamic>) : null,
    );
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
      'date_created_gmt': dateCreatedGmt,
      'date_modified': dateModified,
      'date_modified_gmt': dateModifiedGmt,
      'status': status,
      'featured': featured,
      'catalog_visibility': catalogVisibility,
      'on_sale': onSale,
      'purchasable': purchasable,
      'total_sales': totalSales,
      'virtual': virtual,
      'downloadable': downloadable,
      'downloads': downloads?.map((d) => d.toJson()).toList(),
      'download_limit': downloadLimit,
      'download_expiry': downloadExpiry,
      'external_url': externalUrl,
      'button_text': buttonText,
      'tax_status': taxStatus,
      'tax_class': taxClass,
      'manage_stock': manageStock,
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus,
      'backorders': backorders,
      'backorders_allowed': backordersAllowed,
      'backordered': backordered,
      'low_stock_amount': lowStockAmount,
      'sold_individually': soldIndividually,
      'weight': weight,
      'dimensions': dimensions?.toJson(),
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
      'categories': categories?.map((c) => c.toJson()).toList(),
      'tags': tags?.map((t) => t.toJson()).toList(),
      'images': images?.map((i) => i.toJson()).toList(),
      'attributes': attributes?.map((a) => a.toJson()).toList(),
      'default_attributes': defaultAttributes?.map((a) => a.toJson()).toList(),
      'variations': variations,
      'grouped_products': groupedProducts,
      'menu_order': menuOrder,
      'price_html': priceHtml,
      'related_ids': relatedIds,
      'meta_data': metaData?.map((m) => m.toJson()).toList(),
      'permalink': permalink,
      'date_on_sale_from': dateOnSaleFrom,
      'date_on_sale_from_gmt': dateOnSaleFromGmt,
      'date_on_sale_to': dateOnSaleTo,
      'date_on_sale_to_gmt': dateOnSaleToGmt,
      'has_options': hasOptions,
      'post_password': postPassword,
      'global_unique_id': globalUniqueId,
      'permalink_template': permalinkTemplate,
      'generated_slug': generatedSlug,
      'brands': brands,
      '_links': links?.toJson(),
    };
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

class Download {
  String? id;
  String? name;
  String? file;

  Download({this.id, this.name, this.file});

  factory Download.fromJson(Map<String, dynamic> json) {
    return Download(
      id: json['id'] as String?,
      name: json['name'] as String?,
      file: json['file'] as String?,
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

class Category {
  int? id;
  String? name;
  String? slug;

  Category({this.id, this.name, this.slug});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
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

class Tag {
  int? id;
  String? name;
  String? slug;

  Tag({this.id, this.name, this.slug});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as int?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
    );
  }

  // Convert to JSON - handles both cases (with or without id/slug)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (slug != null) 'slug': slug,
    };
  }
}

class Image {
  int? id;
  String? dateCreated;
  String? dateCreatedGmt;
  String? dateModified;
  String? dateModifiedGmt;
  String? src;
  String? name;
  String? alt;

  Image({
    this.id,
    this.dateCreated,
    this.dateCreatedGmt,
    this.dateModified,
    this.dateModifiedGmt,
    this.src,
    this.name,
    this.alt,
  });

  factory Image.fromJson(Map<String, dynamic> json) {
    return Image(
      id: json['id'] as int?,
      dateCreated: json['date_created'] as String?,
      dateCreatedGmt: json['date_created_gmt'] as String?,
      dateModified: json['date_modified'] as String?,
      dateModifiedGmt: json['date_modified_gmt'] as String?,
      src: json['src'] as String?,
      name: json['name'] as String?,
      alt: json['alt'] as String?,
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

class DefaultAttribute {
  int? id;
  String? name;
  String? option;

  DefaultAttribute({this.id, this.name, this.option});

  factory DefaultAttribute.fromJson(Map<String, dynamic> json) {
    return DefaultAttribute(
      id: json['id'] as int?,
      name: json['name'] as String?,
      option: json['option'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'option': option,
    };
  }
}

class Links {
  List<Link>? self;
  List<Link>? collection;

  Links({this.self, this.collection});

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      self: json['self'] != null
          ? (json['self'] as List<dynamic>).map((l) => Link.fromJson(l as Map<String, dynamic>)).toList()
          : null,
      collection: json['collection'] != null
          ? (json['collection'] as List<dynamic>).map((l) => Link.fromJson(l as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'self': self?.map((l) => l.toJson()).toList(),
      'collection': collection?.map((l) => l.toJson()).toList(),
    };
  }
}

class Link {
  String? href;
  TargetHints? targetHints;

  Link({this.href, this.targetHints});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      href: json['href'] as String?,
      targetHints: json['targetHints'] != null
          ? TargetHints.fromJson(json['targetHints'] as Map<String, dynamic>)
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
  List<String>? allow;

  TargetHints({this.allow});

  factory TargetHints.fromJson(Map<String, dynamic> json) {
    return TargetHints(
      allow: json['allow'] != null
          ? List<String>.from(json['allow'].map((x) => x.toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow': allow,
    };
  }
}

class ProductRequest {
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