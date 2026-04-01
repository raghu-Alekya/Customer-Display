import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/promotion_image_model.dart';

class PromotionRepository {
  final http.Client _client;

  PromotionRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<PromotionImagesResponse> getPortraitPromotionImages({
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/orders/get-portrait-promotion-images',
    );

    print("🔵 Portrait API: $uri");
    print("🔐 Token: $token");

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    print("👉 Decoded Response: $decoded");

    if (response.statusCode == 200) {
      final result = PromotionImagesResponse.fromJson(decoded);
      print("✅ Portrait Images Parsed Successfully");
      return result;
    }

    print("❌ Portrait API Error: ${decoded['message']}");
    throw Exception(
      decoded['message']?.toString() ??
          'Failed to load portrait promotion images',
    );
  }

  Future<PromotionImagesResponse> getFullScreenPromotionImages({
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/orders/get-full-screen-promotion-images',
    );

    print("🔵 Full Screen API: $uri");
    print("🔐 Token: $token");

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    print("👉 Decoded Response: $decoded");

    if (response.statusCode == 200) {
      final result = PromotionImagesResponse.fromJson(decoded);
      print("✅ Full Screen Images Parsed Successfully");
      return result;
    }

    print("❌ Full Screen API Error: ${decoded['message']}");
    throw Exception(
      decoded['message']?.toString() ??
          'Failed to load full screen promotion images',
    );
  }

  Future<PromotionImagesResponse> getBannerPromotionImages({
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/orders/get-banner-promotion-images',
    );

    print("🔵 Banner API: $uri");
    print("🔐 Token: $token");

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    print("👉 Decoded Response: $decoded");

    if (response.statusCode == 200) {
      final result = PromotionImagesResponse.fromJson(decoded);
      print("✅ Banner Images Parsed Successfully");
      return result;
    }

    print("❌ Banner API Error: ${decoded['message']}");
    throw Exception(
      decoded['message']?.toString() ??
          'Failed to load banner promotion images',
    );
  }
}