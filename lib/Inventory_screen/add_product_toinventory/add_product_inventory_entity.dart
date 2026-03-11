class AddProductInventoryTaxEntity {
  final int id;
  final String name;
  final String type;
  final String sku;
  final String regularPrice;
  final String salePrice;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> metaData;
  final List<Map<String, dynamic>> attributes; // ✅ NEW
  final bool manageStock;
  final int stockQuantity;
  final String taxStatus;
  final String taxClass;

  AddProductInventoryTaxEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.sku,
    required this.regularPrice,
    required this.salePrice,
    required this.categories,
    required this.tags,
    required this.images,
    required this.metaData,
    required this.attributes, // ✅ NEW
    required this.manageStock,
    required this.stockQuantity,
    required this.taxStatus,
    required this.taxClass,
  });

  factory AddProductInventoryTaxEntity.fromJson(Map<String, dynamic> json) {
    return AddProductInventoryTaxEntity(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? 'simple',
      sku: json['sku'],
      regularPrice: json['regular_price'] ?? '',
      salePrice: json['sale_price'] ?? '',
      categories: List<Map<String, dynamic>>.from(json['categories'] ?? []),
      tags: List<Map<String, dynamic>>.from(json['tags'] ?? []),
      images: List<Map<String, dynamic>>.from(json['images'] ?? []),
      metaData: List<Map<String, dynamic>>.from(json['meta_data'] ?? []),
      attributes: List<Map<String, dynamic>>.from(json['attributes'] ?? []), // ✅ NEW
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
      'attributes': attributes, // ✅ NEW
      'manage_stock': manageStock,
      'stock_quantity': stockQuantity,
      'tax_status': taxStatus,
      'tax_class': taxClass,
    };
  }
}