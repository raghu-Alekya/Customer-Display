import 'add_product_inventory_entity.dart';

class AddProductInventoryTaxModel extends AddProductInventoryTaxEntity {
  AddProductInventoryTaxModel({
    required super.id,
    required super.name,
    required super.type,
    required super.sku,
    required super.regularPrice,
    required super.salePrice,
    required super.categories,
    required super.tags,
    required super.images,
    required super.metaData,
    required super.manageStock,
    required super.stockQuantity,
    required super.taxStatus,
    required super.taxClass,
  });

  factory AddProductInventoryTaxModel.fromJson(Map<String, dynamic> json) {
    return AddProductInventoryTaxModel(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? 'simple',
      sku: json['sku'],
      regularPrice: json['regular_price'],
      salePrice: json['sale_price'],
      categories: List<Map<String, dynamic>>.from(json['categories'] ?? []),
      tags: List<Map<String, dynamic>>.from(json['tags'] ?? []),
      images: List<Map<String, dynamic>>.from(json['images'] ?? []),
      metaData: List<Map<String, dynamic>>.from(json['meta_data'] ?? []),
      manageStock: json['manage_stock'] ?? false,
      stockQuantity: json['stock_quantity'] ?? 0,
      taxStatus: json['tax_status'] ?? 'taxable',
      taxClass: json['tax_class'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'sku': sku,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'categories': categories,
      'tags': tags,
      'images': images,
      'meta_data': metaData,
      'manage_stock': manageStock,
      'stock_quantity': stockQuantity,
      'tax_status': taxStatus,
      'tax_class': taxClass,
    };
  }
}
