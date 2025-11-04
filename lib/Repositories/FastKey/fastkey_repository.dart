import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/FastKey/fastkey_model.dart';

class FastKeyRepository {  // Build #1.0.15
  final APIHelper _helper = APIHelper();

  // POST: Create FastKey
  Future<FastKeyResponse> createFastKey(FastKeyRequest request) async {
    final box = await Hive.openBox('fastKeysBox');

    if (kDebugMode) {
      print("📦 [FastKeyRepository] Creating new FastKey (Offline Mode)");
      print("📝 Request: ${request.toJson()}");
    }

    // ✅ Consistent key
    Map<String, dynamic> cachedData = {};
    if (box.containsKey('fastkeys')) {
      cachedData = Map<String, dynamic>.from(box.get('fastkeys'));
    }

    final List<dynamic> existingFastKeys = cachedData['fastkeys'] ?? [];

    final newFastKeyId = DateTime.now().millisecondsSinceEpoch;

    final newFastKey = {
      'fastkey_id': newFastKeyId,
      'user_id': request.userId ?? 0,
      'fastkey_title': request.fastkeyTitle,
      'fastkey_image': request.fastkeyImage,
      'fastkey_index': request.fastkeyIndex.toString(),
      'itemCount': 0,
      'products': [],
    };

    existingFastKeys.add(newFastKey);

    cachedData['fastkeys'] = existingFastKeys;
    cachedData['status'] = 'success';
    cachedData['message'] = 'FastKey added locally';
    cachedData['user_id'] = request.userId ?? 0;

    await box.put('fastkeys', cachedData); // ✅ consistent key

    if (kDebugMode) {
      print("✅ FastKey saved to Hive successfully!");
      print("📦 Total FastKeys after add: ${existingFastKeys.length}");
      print("🆕 Added FastKey Title: ${request.fastkeyTitle}");
    }

    return FastKeyResponse(
      status: 'success',
      message: 'FastKey created locally (offline)',
      fastkeyId: newFastKeyId,
      fastkeyTitle: request.fastkeyTitle,
      fastkeyIndex: request.fastkeyIndex.toString(),
      fastkeyImage: request.fastkeyImage,
      isOfflineData: true,
    );
  }

  // GET: Fetch FastKeys by User
  Future<FastKeyListResponse> getFastKeysByUser() async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.fastKeys}${EndUrlConstants.getFastKeyEndUrl}";

    final box = await Hive.openBox('fastKeysBox');

    if (kDebugMode) {
      print("🔹 FastKeyRepository - GET URL: $url");
    }

    try {
      // 🌍 Step 1: Fetch from API
      final response = await _helper.get(url, true);

      if (kDebugMode) {
        print("📥 FastKeyRepository - GET Raw Response: $response");
      }

      dynamic responseData;

      if (response is String) {
        responseData = json.decode(response);
      } else if (response is Map<String, dynamic>) {
        responseData = response;
      } else {
        throw Exception("Unexpected response type in GET");
      }

      // ✅ Step 2: Parse to model
      final fastKeyListResponse = FastKeyListResponse.fromJson(responseData);

      // ✅ Step 3: Store response data in Hive
      final jsonData = fastKeyListResponse.toJson();
      await box.put('cachedFastKeys', jsonData);

      if (kDebugMode) {
        print("✅ FastKeys cached successfully in Hive (box: fastKeysBox)");

        // 🔍 Step 3.1: Verify by reading back
        final cachedData = box.get('cachedFastKeys');
        if (cachedData != null) {
          print("🔸 Hive Data Keys: ${cachedData.keys}");
          print("🔹 First FastKey Title: ${(cachedData['fastkeys'] as List?)?.first?['fastkey_title'] ?? 'N/A'}");
        } else {
          print("❌ Hive Save Failed — No data found under key 'cachedFastKeys'");
        }
      }

      return fastKeyListResponse;
    } catch (e) {
      // 📴 Step 4: Offline fallback from Hive
      if (kDebugMode) {
        print("⚠ API failed, loading from Hive: $e");
      }

      final cachedData = box.get('cachedFastKeys');

      if (cachedData != null) {
        if (kDebugMode) {
          print("📦 Loaded FastKeys from Hive cache successfully (Offline Mode)");
          print("🔹 Cached First FastKey: ${(cachedData['fastkeys'] as List?)?.first?['fastkey_title'] ?? 'N/A'}");
        }

        final response =
        FastKeyListResponse.fromJson(Map<String, dynamic>.from(cachedData));
        response.isOfflineData = true; // ✅ mark offline
        return response;
      }

      throw Exception("❌ Failed to fetch or load cached FastKeys: $e");
    }

  }

  // 🧩 Debug helper: Print all cached FastKeys from Hive manually
  Future<void> printAllCachedFastKeys() async {
    final box = await Hive.openBox('fastKeysBox');

    if (!box.containsKey('cachedFastKeys')) {
      print("❌ No FastKeys cached in Hive yet (key: cachedFastKeys)");
      return;
    }

    final cachedData = box.get('cachedFastKeys');

    if (cachedData == null) {
      print("⚠ Cached data is null.");
      return;
    }

    // Convert to Map to access values easily
    final Map<String, dynamic> data = Map<String, dynamic>.from(cachedData);

    print("📦 ===== HIVE FASTKEY CACHE DUMP START =====");
    print("🔑 Cached Keys: ${data.keys}");

    final fastKeys = (data['fastkeys'] as List?) ?? [];
    print("📋 Total FastKeys Cached: ${fastKeys.length}");

    for (int i = 0; i < fastKeys.length; i++) {
      final key = fastKeys[i];
      print("--------------------------------------------------");
      print("🔸 FastKey #${i + 1}");
      print("   🆔 ID: ${key['fastkey_id']}");
      print("   🏷 Title: ${key['fastkey_title']}");
      print("   📸 Image: ${key['fastkey_image']}");
      print("   📦 Item Count: ${key['itemCount'] ?? 0}");
      print("   📊 Index: ${key['fastkey_index']}");

      final products = (key['products'] as List?) ?? [];
      print("   🛍 Products in FastKey: ${products.length}");

      for (int j = 0; j < products.length; j++) {
        final product = products[j];
        print("     • Product ${j + 1}: ${product['name']} (${product['price']})");
      }
    }

    print("📦 ===== HIVE FASTKEY CACHE DUMP END =====");
  }

  // // Build #1.0.19: POST: Delete FastKey
  Future<FastKeyResponse> deleteFastKey(int fastkeyServerId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.fastKeys}${EndUrlConstants.deleteFastKeyEndUrl}/$fastkeyServerId";

    if (kDebugMode) {
      print("FastKeyRepository - DELETE URL: $url");
    }

    final response = await _helper.get(url, true);///Build #1.0.85: updated to get URL

    if (kDebugMode) {
      print("FastKeyRepository - DELETE Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return FastKeyResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing DELETE response: $e");
        throw Exception("Failed to parse FastKey delete response");
      }
    } else if (response is Map<String, dynamic>) {
      return FastKeyResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in DELETE");
    }
  }

  // Build #1.0.89: Added this method for updateFastKey API
  Future<FastKeyResponse> updateFastKey(FastKeyRequest request) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.fastKeys}${EndUrlConstants.updateFastKeyEndUrl}";

    if (kDebugMode) {
      print("FastKeyRepository - UPDATE URL: $url");
      print("Request body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("FastKeyRepository - UPDATE Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return FastKeyResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing UPDATE response: $e");
        throw Exception("Failed to parse FastKey update response");
      }
    } else if (response is Map<String, dynamic>) {
      return FastKeyResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in UPDATE");
    }
  }
}