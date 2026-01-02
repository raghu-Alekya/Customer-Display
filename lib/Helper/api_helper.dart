import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pinaka_pos/Helper/url_helper.dart';
import '../Database/db_helper.dart';
import '../Database/user_db_helper.dart';
import 'file_helper.dart';
import 'package:pinaka_pos/Helper/Extentions/exceptions.dart';

class APIHelper { // Build #1.0.8, Naveen added
  //Build #1.0.54: added insure UrlHelper base URL is initialized
  Future<void> _initializeBaseUrl() async {
    if (kDebugMode) {
      print("#### APIHelper: Initializing UrlHelper base URL");
    }
    await UrlHelper.initializeBaseUrl();
    if (kDebugMode) {
      print("#### APIHelper: UrlHelper base URL initialized: ${UrlHelper.baseUrl}");
    }
  }
  Future<dynamic> postForm(
      String url,
      Map<String, String> params,
      bool useToken, {
        bool validateMarchentUrl = false,
      }) async {
    String finalUrl = "";
    String token = ""; // ✅ non-nullable

    try {
      await _initializeBaseUrl();

      finalUrl =
      validateMarchentUrl ? url : UrlHelper.baseUrl + url;

      final userData = await UserDbHelper().getUserData();
      token = userData?[AppDBConst.userToken] ?? "";

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(finalUrl),
      );

      if (useToken && token.isNotEmpty) {
        request.headers[HttpHeaders.authorizationHeader] =
        "Bearer $token";
      }

      request.fields.addAll(params);

      final streamedResponse = await request.send();
      final response =
      await http.Response.fromStream(streamedResponse);

      return _returnResponse(response);
    } catch (e, s) {
      _logError("POST FORM", finalUrl, token, e, s);
      throw Exception("Exception: $e; Stack: $s");
    }
  }

  // Base method for handling GET requests
  Future<dynamic> get(String url, bool useToken) async {
    var responseJson;
    String finalUrl = "";
    String? token = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = UrlHelper.baseUrl + url;
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? ""; // Build #1.0.13: token get from the user table from db

      if (kDebugMode) {
        print("URL: $finalUrl");
        print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
        print("Bearer Token: $token");
      }

      // Add Bearer token if required
      // final headers =
      //   useToken && token != null && token.isNotEmpty
      //       ? {HttpHeaders.authorizationHeader: "Bearer $token"}
      //       : null;
      final headers = {
        'Content-Type': 'application/json',
        if (useToken && token != null && token.isNotEmpty)
          HttpHeaders.authorizationHeader: "Bearer $token",
      };

      final response = await http.get(Uri.parse(finalUrl), headers: headers);
      responseJson = _returnResponse(response);
    } on SocketException {
      throw FetchDataException('No Internet connection');
    } catch (e, s) {
      _logError("GET", finalUrl, token, e, s);
      throw Exception("Exception: $e; Stack: $s");
    }

    return responseJson;
  }

  // Method for downloading files
  Future<http.StreamedResponse> downloadFile(String url) async {
    var httpClient = http.Client();
    String finalUrl = "";
    String? token = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = UrlHelper.baseUrl + url;
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? "";

      if (kDebugMode) {
        print("URL: $finalUrl");
        print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
        print("Bearer Token: $token");
      }

      var request = http.Request('GET', Uri.parse(finalUrl));
      request.headers[HttpHeaders.authorizationHeader] = "Bearer $token";
      var response = await httpClient.send(request);
      return response;
    } on SocketException {
      throw FetchDataException('No Internet connection');
    } catch (e, s) {
      _logError("DOWNLOAD", finalUrl, token, e, s);
      throw Exception("Exception: $e; Stack: $s");
    } finally {
      httpClient.close();
    }
  }

  // Base method for handling POST requests
  Future<dynamic> post(String url, Map<String, dynamic> params, bool useToken, {bool? validateMarchentUrl}) async {
    var responseJson;
    String finalUrl = "";
    String? token = "";
    var body = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = (validateMarchentUrl ?? false) ? url : UrlHelper.baseUrl + url;  //Build #1.0.42: Updated url condition
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? "";
      body = json.encode(params);

      // Add Bearer token if required
      final headers = {
        'Content-Type': 'application/json',
        if (useToken && token != null && token.isNotEmpty)
          HttpHeaders.authorizationHeader: "Bearer $token",
      };

      if (kDebugMode) {
        print("URL: $finalUrl");
        print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
        print("Body: $body");
        if (useToken && token != null && token.isNotEmpty) {
          print("Bearer Token: $token");
        }
        print("Headers: $headers");
      }

      final response = await http.post(Uri.parse(finalUrl), body: body, headers: headers);
      responseJson = _returnResponse(response);
    }
    on SocketException { //Build #1.0.34: if turn off internet need this exception here
      throw FetchDataException('No Internet connection');
    }
    catch (e, s) {
      _logError("POST", finalUrl, token, e, s, body: body);
      if(e is SocketException){
        //treat SocketException
        if (kDebugMode) {
          print("Socket exception: ${e.toString()}");
        }
      }
      else if(e is TimeoutException){
        //treat TimeoutException
        if (kDebugMode) {
          print("Timeout exception: ${e.toString()}");
        }
      }
      else if (kDebugMode) {
        print("Unhandled exception: ${e.toString()}");
      }
      throw Exception("Exception: $e; Stack: $s");
    }

    return responseJson;
  }

  // Method for handling POST requests with file uploads
  Future<dynamic> postWithFile(String url, bool useToken, FileHelper fileHelper) async {
    var responseJson;
    String finalUrl = "";
    String? token = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = UrlHelper.baseUrl + url;
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? "";
      File formDataFile = await fileHelper.getFile();

      if (kDebugMode) {
        print("MultiPartForm file data exists: ${fileHelper.exists()}");
        print("URL: $finalUrl");
        print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
        print("Bearer Token: $token");
      }

      if (useToken && token != null && token.isNotEmpty && formDataFile != null) {
        var request = http.MultipartRequest('POST', Uri.parse(finalUrl));
        request.headers['Authorization'] = 'Bearer $token';

        // Attach file to the request
        String fieldName = 'file'; // Customize field name as needed
        var file = await http.MultipartFile.fromPath(fieldName, formDataFile.path);
        request.files.add(file);

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        responseJson = _returnResponse(response);
      }
    } catch (e, s) {
      _logError("POST WITH FILE", finalUrl, token, e, s);
      throw Exception("Exception: $e; Stack: $s");
    }

    return responseJson;
  }

  // Base method for handling DELETE requests
  Future<dynamic> delete(String url) async {
    var responseJson;
    String finalUrl = "";
    String? token = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = UrlHelper.baseUrl + url;
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? "";

      final response = await http.delete(Uri.parse(finalUrl), headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
      });
      responseJson = _returnResponse(response);
    } on SocketException {
      throw FetchDataException('No Internet connection');
    } catch (e, s) {
      _logError("DELETE", finalUrl, token, e, s);
      throw Exception("Exception: $e; Stack: $s");
    }

    return responseJson;
  }

  // Base method for handling PUT requests
  Future<dynamic> put(String url, Map<String, dynamic> params, bool useToken) async {
    var responseJson;
    String finalUrl = "";
    String? token = "";
    var body = "";

    try {
      await _initializeBaseUrl(); // Ensure base URL is initialized
      finalUrl = UrlHelper.baseUrl + url;
      final userData = await UserDbHelper().getUserData();
      token =  userData?[AppDBConst.userToken] ?? "";
      body = json.encode(params);

      if (kDebugMode) {
        print("URL: $finalUrl");
        print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
        print("Bearer Token: $token");
        print("Body: $body");
      }

      // Add Bearer token if required
      final headers = {
        'Content-Type': 'application/json',
        if (useToken && token != null && token.isNotEmpty)
          HttpHeaders.authorizationHeader: "Bearer $token",
      };

      final response = await http.put(Uri.parse(finalUrl), body: body, headers: headers);
      responseJson = _returnResponse(response);
    } on SocketException {
      throw FetchDataException('No Internet connection');
    } catch (e, s) {
      _logError("PUT", finalUrl, token, e, s, body: body);
      throw Exception("Exception: $e; Stack: $s");
    }

    return responseJson;
  }

  // Helper method to log errors consistently
  void _logError(String method, String url, String? token, dynamic error, StackTrace stackTrace, {String body = ""}) {
    if (kDebugMode) {
      print("Exception in $method REQUEST: $error");
      print("Final URL: $url");
      print("Environment: ${UrlHelper.environment[UrlHelper.baseUrl]}");
      print("Token: $token");
      if (body.isNotEmpty) print("Body: $body");
      print("Stack Trace: $stackTrace");
    }
  }

  // Helper method to handle API responses
  dynamic _returnResponse(http.Response response) {
    if (kDebugMode) {
      print("API Response:");
      print("Status Code: ${response.statusCode}");
      print("Headers: ${response.headers}");
      print("Body: ${response.body}");
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return response.body.trim();
      case 400:
        throw BadRequestException(response.body);
      case 401:
      case 403:
        throw UnauthorisedException(response.body);
      case 404:
        throw NotFoundException(response.body);
      case 409: // Build #1.0.189: Added 409 for conflict errors
        throw Exception(response.body);
      case 500:
        throw InternalServerErrorException(response.body);
      default:
        throw FetchDataException(
            'Error occurred while communicating with the server. Status Code: ${response.statusCode}');
    }
  }
}