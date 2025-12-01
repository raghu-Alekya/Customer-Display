import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_response.dart';
import '../../Helper/cashbackhelper.dart';
import '../../Helper/file_helper.dart';
import '../../Models/Auth/login_model.dart';
import '../../Repositories/Auth/login_repository.dart';
import 'package:pinaka_pos/Helper/Extentions/exceptions.dart'; // Import custom exceptions

class LoginBloc { // Build #1.0.8
  final UserDbHelper _userDbHelper = UserDbHelper();
  final LoginRepository _loginRepository;
  final StreamController<APIResponse<LoginResponse>> _loginController = StreamController<APIResponse<LoginResponse>>.broadcast();

  StreamSink<APIResponse<LoginResponse>> get loginSink => _loginController.sink;
  Stream<APIResponse<LoginResponse>> get loginStream => _loginController.stream;

  LoginBloc(this._loginRepository) {
    if (kDebugMode) {
      print("************** LoginBloc Initialized");
    }
  }

  // In LoginBloc.dart
  Future<void> fetchLoginToken(LoginRequest request) async { // Build #1.0.13: Added Login request
    if (_loginController.isClosed) return;

    loginSink.add(APIResponse.loading(TextConstants.loading));
    try {
      String token = await _loginRepository.fetchLoginToken(request);
      LoginResponse loginResponse = LoginResponse.fromJson(json.decode(token));

      if (loginResponse.token != null && loginResponse.success == true) {
        // Build #1.0.148: Always save/update the new login data
        // ✅ 1) Existing logic: Save to SQLite (keep this if you still use it)
        await _userDbHelper.saveUserData(loginResponse);

        // ✅ 2) NEW: Save fresh token into Hive (this is what Cashback + APIs will use)
        final userBox = Hive.box('user');
        await userBox.put('token', loginResponse.token);

        // (Optional) Save extra user info if you want
        // if (loginResponse.user != null) {
        //   await userBox.put('userData', loginResponse.user!.toJson());
        // }

        if (kDebugMode) {
          print("🟩 [LoginBloc] Fresh token saved to Hive → ${loginResponse.token}");
        }

        // ✅ 3) OPTIONAL: Now that token exists, preload cashback config
        await CashbackHelper.loadCashbackOnStartup();

        // ✅ 4) Notify UI login success
        loginSink.add(APIResponse.completed(loginResponse));
      } else {
        // Show the exact error message from API
        loginSink.add(APIResponse.error(
            loginResponse.message ?? "Invalid PIN or user not found."));
      }
    } catch (e, s) {
      String errorMessage = "An error occurred. Please try again.";
      if (kDebugMode) {
        print("Exception type: ${e.runtimeType}");
        print("Exception content: $e");
        print("Stack trace: $s");
      }

      //Build #1.0.34: Handle custom exceptions with message property
      if (e is UnauthorisedException || e is BadRequestException || e is NotFoundException || e is InternalServerErrorException) {
        String? message;
        // Assume message is the JSON response body
        try {
          // If message is directly accessible (e.g., UnauthorisedException(response.body))
          final errorJson = json.decode(e.toString().replaceFirst(RegExp(r'^[a-zA-Z]+Exception: '), ''));
          message = errorJson['message']?.toString();
        } catch (_) {
          // Fallback to parsing toString() for JSON
          try {
            final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
            if (jsonMatch != null) {
              final errorJson = json.decode(jsonMatch.group(0)!);
              message = errorJson['message']?.toString();
            }
          } catch (_) {
            // Use toString() if JSON parsing fails
            message = e.toString();
          }
        }
        errorMessage = message ?? errorMessage;
      } else if (e is FetchDataException) {
        errorMessage = e.toString(); // Handle network errors
      } else if (e is SocketException) {
        errorMessage = "Network error. Please check your connection.";
      } else {
        //Build #1.0.34: Handle generic Exception (e.g., from APIHelper's catch block)
        try {
          // Extract JSON from toString()
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
          if (jsonMatch != null) {
            final errorJson = json.decode(jsonMatch.group(0)!);
            errorMessage = errorJson['message']?.toString() ?? errorMessage;
          } else {
            errorMessage = e.toString();
          }
        } catch (_) {
          errorMessage = e.toString();
        }
      }
      loginSink.add(APIResponse.error(errorMessage));
      if (kDebugMode) print("Exception in LoginBlock.fetchLoginToken: $e; Stack: $s");
    }
  }

  void dispose() {
    if (!_loginController.isClosed) {
      _loginController.close();
      if (kDebugMode) print("LoginBloc disposed");
    }
  }
}