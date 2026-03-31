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

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return PromotionImagesResponse.fromJson(decoded);
    }

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

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return PromotionImagesResponse.fromJson(decoded);
    }

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

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return PromotionImagesResponse.fromJson(decoded);
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Failed to load banner promotion images',
    );
  }
}

