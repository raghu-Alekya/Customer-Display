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

    print("👉 API URL: $url");
    print("👉 Product ID: $productId");
    print("👉 Token: $token");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    print("👉 Status Code: ${response.statusCode}");
    print("👉 Raw Response: ${response.body}");

    final decoded = json.decode(response.body);

    print("👉 Decoded Response: $decoded");

    if (response.statusCode == 200 && decoded['status'] == "success") {
      final List data = decoded['data'];

      print("👉 Addons Count: ${data.length}");
      print("👉 Addons Data: $data");

      return data.map((e) {
        print("👉 Mapping Addon: $e");
        return AddonModel.fromJson(e);
      }).toList();
    } else {
      print("❌ Error Response: $decoded");
      throw Exception("Failed to load addons");
    }
  }
}