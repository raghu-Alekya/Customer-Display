import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user_login.dart';

class AuthRepository {
  Future<UserLoginResponse> loginWithPin(String pin) async {
    final url = Uri.parse(
        'https://kioski.alekyatechsolutions.com/wp-json/pinaka-kiosk/v1/token');

    final request = http.MultipartRequest('POST', url)
      ..fields['emp_login_pin'] = pin;

    final response = await request.send();

    final resBody = await response.stream.bytesToString();
    final decoded = json.decode(resBody);

    print("LOGIN RESPONSE: $decoded");

    if (response.statusCode == 200 && decoded['success'] == true) {
      final result = UserLoginResponse.fromJson(decoded);

      /// ✅ STORE TOKEN
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", result.data.token);

      print("✅ TOKEN SAVED: ${result.data.token}");

      return result;
    } else {
      throw Exception(decoded['message'] ?? "Login Failed");
    }
  }
}