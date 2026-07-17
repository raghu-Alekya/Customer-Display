
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/store_details_model.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/appconstant.dart';

class StoreDetailsRepository {
  final http.Client _client;

  StoreDetailsRepository({http.Client? client})
      : _client = client ?? http.Client();

  Uri get _uri => Uri.parse(
    AppConstants.storeDetailsEndpoint,
  );

  static const String _cacheKey = 'store_details_cache';

  // 🔹 PUBLIC METHOD (USE THIS EVERYWHERE)
  Future<StoreDetails> getStoreDetails({required String token}) async {
    final cached = await _getCachedStoreDetails();

    if (cached != null) {
      // 🔁 refresh in background (non-blocking)
      _refreshStoreDetails(token);
      return cached;
    }

    // 🌐 first time → API
    final fresh = await _fetchFromApi(token);
    await _cacheStoreDetails(fresh);
    return fresh;
  }

  // 🔹 ORIGINAL API CALL (renamed)
  Future<StoreDetails> _fetchFromApi(String token) async {
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
          ? (decoded['message']?.toString() ??
          'Failed to load store details')
          : 'Failed to load store details';
      throw Exception(msg);
    }

    final details = decoded['store_details'];

    if (details is! Map<String, dynamic>) {
      throw Exception('Invalid store_details in response');
    }

    return StoreDetails.fromJson(details);
  }

  // 🔹 CACHE SAVE
  Future<void> _cacheStoreDetails(StoreDetails store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(store.toJson()));
  }

  // 🔹 CACHE LOAD
  Future<StoreDetails?> _getCachedStoreDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_cacheKey);

    if (data == null) return null;

    try {
      final jsonMap = jsonDecode(data);
      return StoreDetails.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  // 🔹 BACKGROUND REFRESH
  Future<void> _refreshStoreDetails(String token) async {
    try {
      final fresh = await _fetchFromApi(token);
      await _cacheStoreDetails(fresh);
    } catch (_) {
      // silently fail
    }
  }
}
