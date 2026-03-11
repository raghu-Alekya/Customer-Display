class InventoryAttributeItemsModel {
  final int id;
  final String name;
  final String slug;

  InventoryAttributeItemsModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory InventoryAttributeItemsModel.fromJson(Map<String, dynamic> json) {
    return InventoryAttributeItemsModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
    );
  }
}
