import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/login_model.dart';
import '../utils/appconstant.dart';

class LoginRepository {
  Future<LoginResponse> login({
    required String username,
    required String password,
    required String storeId,
  }) async {
    final url = Uri.parse(
      AppConstants.merchantLoginEndpoint,
    );

    print("🔵 Login API URL: $url");
    print("👉 Username: $username");
    print("👉 Password: $password");
    print("👉 Store ID: $storeId");

    var request = http.MultipartRequest('POST', url);

    request.fields['username'] = username;
    request.fields['password'] = password;
    request.fields['store_id'] = storeId;

    print("📤 Request Fields: ${request.fields}");

    var response = await request.send();

    print("👉 Status Code: ${response.statusCode}");

    final respStr = await response.stream.bytesToString();

    print("👉 Raw Response: $respStr");

    final data = jsonDecode(respStr);

    print("👉 Decoded Response: $data");

    try {
      final loginResponse = LoginResponse.fromJson(data);

      print("✅ Login Parsed Successfully: $loginResponse");

      return loginResponse;
    } catch (e) {
      print("❌ Parsing Error: $e");
      throw Exception("Login parsing failed");
    }
  }
}