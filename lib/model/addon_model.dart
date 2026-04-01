class AddonModel {
  final int id;
  final String name;
  final double price;
  final String type;
  final String? imageUrl;
  bool isSelected;

  AddonModel({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    this.imageUrl,
    this.isSelected = false,
  });

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    return AddonModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num).toDouble(),
      type: json['type']?.toString() ?? '',
      imageUrl: _parseImageUrl(json),
    );
  }

  static String? _parseImageUrl(Map<String, dynamic> json) {
    final direct = json['image_url'] ?? json['imageUrl'] ?? json['thumbnail'];
    if (direct is String && direct.isNotEmpty) return direct;

    final img = json['image'];
    if (img is String && img.isNotEmpty) return img;
    if (img is Map) {
      final src = img['src'] ?? img['url'];
      if (src is String && src.isNotEmpty) return src;
    }
    return null;
  }
}