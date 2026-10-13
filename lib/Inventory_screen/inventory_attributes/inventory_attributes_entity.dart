class InventoryAttributesEntity {
  final int id;
  final String name;
  final String slug;
  final String type;

  InventoryAttributesEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
  });

  // ✅ Override equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is InventoryAttributesEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name; // Optional, helps in debug
}
