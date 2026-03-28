class ProductModel {
  final int id;
  final String name;
  final String price;
  final String? imageUrl;
  final bool? isVeg;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.isVeg,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = _extractImageUrl(json);
    final inferredVegFlag = _extractIsVeg(
      json['is_veg'] ?? json['is_ve'] ?? json['isVeg'],
    ) ??
        _inferIsVegFromText(json);

    return ProductModel(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? _asString(json['title']) ?? 'Unknown',
      price: _extractPrice(json),
      imageUrl: imageUrl,
      isVeg: inferredVegFlag,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String _extractPrice(Map<String, dynamic> json) {
    final dynamic candidate =
        json['price'] ?? json['sale_price'] ?? json['regular_price'] ?? json['amount'];
    final raw = _asString(candidate) ?? '0';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '₹0';
    return trimmed.contains('₹') ? trimmed : '₹$trimmed';
  }

  static String? _extractImageUrl(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is String && image.isNotEmpty) return image;
    if (image is Map<String, dynamic>) {
      final src = _asString(image['src']) ?? _asString(image['url']);
      if (src != null && src.isNotEmpty) return src;
    }

    final images = json['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.isNotEmpty) return first;
      if (first is Map<String, dynamic>) {
        final src = _asString(first['src']) ?? _asString(first['url']);
        if (src != null && src.isNotEmpty) return src;
      }
    }

    final thumbnail = _asString(json['thumbnail']);
    if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;

    final featured = _asString(json['featured_image']);
    if (featured != null && featured.isNotEmpty) return featured;

    final acf = json['acf'];
    if (acf is Map<String, dynamic>) {
      final acfImage = acf['image'];
      if (acfImage is String && acfImage.isNotEmpty) return acfImage;
      if (acfImage is Map<String, dynamic>) {
        final src = _asString(acfImage['url']) ?? _asString(acfImage['src']);
        if (src != null && src.isNotEmpty) return src;
      }
    }

    return null;
  }

  static bool? _extractIsVeg(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'null') return null;
      if (normalized == 'true' ||
          normalized == 'yes' ||
          normalized == '1' ||
          normalized == 'veg') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'no' ||
          normalized == '0' ||
          normalized == 'non veg' ||
          normalized == 'non-veg') {
        return false;
      }
    }
    return null;
  }

  static bool? _inferIsVegFromText(Map<String, dynamic> json) {
    final tokens = <String>[];

    void addValue(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final text = value.trim().toLowerCase();
        if (text.isNotEmpty) tokens.add(text);
        return;
      }
      if (value is List) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }
      if (value is Map<String, dynamic>) {
        for (final v in value.values) {
          addValue(v);
        }
      }
    }

    addValue(json['categories']);
    addValue(json['tags']);
    addValue(json['attributes']);
    addValue(json['name']);
    addValue(json['slug']);

    final joined = tokens.join(' ');
    if (joined.contains('non veg') ||
        joined.contains('non-veg') ||
        joined.contains('nonveg')) {
      return false;
    }
    if (joined.contains('veg')) {
      return true;
    }
    return null;
  }
}