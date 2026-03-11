import 'category_model.dart';
import 'category_model.dart';

class CategoryProduct {
  final int id;
  final String name;
  final String sku;
  final double price;
  final String regularPrice;
  final String salePrice;

  final List<CategoryModel> categories;
  final List<Tags> tags;
  final List<String> images;
  final List<Attribute> attributes;
  final List<Map<String, dynamic>> metaData;
  final List<int> variations;
  final String type;
  final ProductTax? tax;

  CategoryProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.categories,
    required this.tags,
    required this.images,
    required this.attributes,
    required this.metaData,
    required this.variations,
    required this.type,
    this.tax,
  });

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory CategoryProduct.fromJson(Map<String, dynamic> json) {
    return CategoryProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      price: _parsePrice(json['price']),
      regularPrice: json['regular_price'] ?? '',
      salePrice: json['sale_price'] ?? '',
      categories: (json['categories'] as List? ?? [])
          .map((e) => CategoryModel.fromJson(e))
          .toList(),
      tags: (json['tags'] as List? ?? [])
          .map((e) => Tags.fromJson(e))
          .toList(),
      attributes: (json['attributes'] as List? ?? [])
          .map((e) => Attribute.fromJson(e))
          .toList(),
      metaData: (json['meta_data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      images: (json['images'] as List? ?? [])
          .map((e) {
        if (e is Map<String, dynamic>) {
          return e['src']?.toString() ?? '';
        } else if (e is String) {
          return e;
        }
        return '';
      })
          .where((e) => e.isNotEmpty)
          .toList(),
      variations: (json['variations'] as List? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e != 0)
          .toList(),
      type: json['type'] ?? 'simple',
      tax: json['tax'] != null ? ProductTax.fromJson(json['tax']) : null,
    );
  }
}
class ProductTax {
  final bool taxable;
  final String taxClass;
  final String taxStatus;
  final List<TaxRate> taxRates;

  ProductTax({
    required this.taxable,
    required this.taxClass,
    required this.taxStatus,
    required this.taxRates,
  });

  factory ProductTax.fromJson(Map<String, dynamic> json) {
    return ProductTax(
      taxable: json['taxable'] ?? false,
      taxClass: json['tax_class'] ?? '',
      taxStatus: json['tax_status'] ?? '',
      taxRates: (json['tax_rates'] as List? ?? [])
          .map((e) => TaxRate.fromJson(e))
          .toList(),
    );
  }
}

class TaxRate {
  final double rate;
  final String label;

  TaxRate({
    required this.rate,
    required this.label,
  });

  factory TaxRate.fromJson(Map<String, dynamic> json) {
    return TaxRate(
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] ?? '',
    );
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
}

class Attribute {
  final String name;
  final List<String> values;
  final bool visible;
  final bool variation;

  Attribute({
    required this.name,
    required this.values,
    required this.visible,
    required this.variation,
  });

  factory Attribute.fromJson(Map<String, dynamic> json) {
    return Attribute(
      name: json['name'] ?? '',
      values: json['values'] != null
          ? List<String>.from(json['values'].map((x) => x.toString()))
          : [],
      visible: json['visible'] ?? false,
      variation: json['variation'] ?? false,
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

class CategoryProductListResponse {
  final List<CategoryProduct> products;

  CategoryProductListResponse({required this.products});

  factory CategoryProductListResponse.fromJson(List<dynamic> json) {
    return CategoryProductListResponse(
      products: json.map((item) => CategoryProduct.fromJson(item)).toList(),
    );
  }
}