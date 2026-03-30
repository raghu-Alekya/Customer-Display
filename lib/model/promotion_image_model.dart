class PromotionImagesResponse {
  final bool success;
  final String message;
  final List<String> images;

  PromotionImagesResponse({
    required this.success,
    required this.message,
    required this.images,
  });

  factory PromotionImagesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    return PromotionImagesResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      images: data.map((e) => e.toString()).toList(),
    );
  }
}

