import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_udid/flutter_udid.dart';
import '../../Constants/text.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/login_model.dart';

class LoginRepository {
  final APIHelper _helper = APIHelper();

  Future<String> fetchLoginToken(LoginRequest request) async {
    String url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}"; // Build #1.0.13 : updated url

    if (kDebugMode) {
      print("LoginRepository - URL: $url");
      print("LoginRepository - Request: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), false);
    return response;
  }
}
