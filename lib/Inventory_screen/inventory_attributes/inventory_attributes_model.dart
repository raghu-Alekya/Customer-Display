class InventoryAttributesModel {
  final int id;
  final String name;
  final String slug;
  final String type;

  InventoryAttributesModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
  });

  factory InventoryAttributesModel.fromJson(Map<String, dynamic> json) {
    return InventoryAttributesModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      type: json['type'],
    );
  }
}
