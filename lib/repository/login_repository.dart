import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/login_model.dart';

class LoginRepository {
  Future<LoginResponse> login({
    required String username,
    required String password,
    required String storeId,
  }) async {
    final url = Uri.parse(
      'https://test.alekyatechsolutions.com/wp-json/custom/v1/validate-merchant',
    );

    var request = http.MultipartRequest('POST', url);

    request.fields['username'] = username;
    request.fields['password'] = password;
    request.fields['store_id'] = storeId;

    var response = await request.send();
    final respStr = await response.stream.bytesToString();

    final data = jsonDecode(respStr);

    return LoginResponse.fromJson(data);
  }
}