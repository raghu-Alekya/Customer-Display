class CategoryModel {
  final int id;
  final String name;
  final int parent;
  final String? imageUrl;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.parent,
    this.imageUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = _extractImageUrl(json);
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      parent: json['parent'] as int? ?? 0,
      imageUrl: imageUrl,
    );
  }

  static String? _extractImageUrl(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is String && image.isNotEmpty) return image;
    if (image is Map<String, dynamic>) {
      final src = image['src']?.toString() ?? image['url']?.toString();
      if (src != null && src.isNotEmpty) return src;
    }

    final thumbnail = json['thumbnail']?.toString();
    if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;

    final icon = json['icon']?.toString();
    if (icon != null && icon.isNotEmpty) return icon;

    final acf = json['acf'];
    if (acf is Map<String, dynamic>) {
      final acfImage = acf['image'];
      if (acfImage is String && acfImage.isNotEmpty) return acfImage;
      if (acfImage is Map<String, dynamic>) {
        final src = acfImage['url']?.toString() ?? acfImage['src']?.toString();
        if (src != null && src.isNotEmpty) return src;
      }
    }

    return null;
  }
}