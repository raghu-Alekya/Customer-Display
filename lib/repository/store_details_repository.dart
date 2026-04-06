
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/store_details_model.dart';

class StoreDetailsRepository {
  final http.Client _client;

  StoreDetailsRepository({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _uri = Uri.parse(
    'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/assets/store-details',
  );

  Future<StoreDetails> fetchStoreDetails({required String token}) async {
    final response = await _client.get(
      _uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final decoded = json.decode(response.body);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      final msg = decoded is Map<String, dynamic>
          ? (decoded['message']?.toString() ?? 'Failed to load store details')
          : 'Failed to load store details';
      throw Exception(msg);
    }

    final details = decoded['store_details'];
    if (details is! Map<String, dynamic>) {
      throw Exception('Invalid store_details in response');
    }

    return StoreDetails.fromJson(details);
  }
}
