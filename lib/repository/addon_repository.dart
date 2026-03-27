import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/addon_model.dart';

class AddonRepository {
  Future<List<AddonModel>> getAddons({
    required int productId,
    required String token,
  }) async {
    final url = Uri.parse(
      'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/modifiers-addons/get-modifiers-by-product-id?product_id=$productId',
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    final decoded = json.decode(response.body);

    if (response.statusCode == 200 && decoded['status'] == "success") {
      final List data = decoded['data'];
      return data.map((e) => AddonModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load addons");
    }
  }
}