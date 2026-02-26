import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../Constants/text.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_response.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/logout_model.dart';
import '../../Repositories/Auth/logout_repository.dart';

// Build #1.0.163: Added Logout BLoC
class LogoutBloc {
  final LogoutRepository _logoutRepository;
  final UserDbHelper _userDbHelper = UserDbHelper();
  final StreamController<APIResponse<LogoutResponse>> _logoutController =
  StreamController<APIResponse<LogoutResponse>>.broadcast();

  StreamSink<APIResponse<LogoutResponse>> get logoutSink => _logoutController.sink;
  Stream<APIResponse<LogoutResponse>> get logoutStream => _logoutController.stream;

  LogoutBloc(this._logoutRepository) {
    if (kDebugMode) {
      print("LogoutBloc - Initialized");
    }
  }

  // Build #1.0.163: Logout API call
  Future<void> performLogout() async {
    if (_logoutController.isClosed) {
      if (kDebugMode) {
        print("LogoutBloc - StreamController is closed, aborting logout");
      }
      return;
    }

    // Notify UI of loading state
    logoutSink.add(APIResponse.loading(TextConstants.loading));

    try {
      // Call repository to perform logout
      String response = await _logoutRepository.logout();
      LogoutResponse logoutResponse = LogoutResponse.fromJson(json.decode(response));
      await UserDbHelper().logout();
      if (kDebugMode) {
        print("LogoutBloc - Logout response: ${logoutResponse.message}");
      }

      if (logoutResponse.success) {
         // If i clear user data from database and shared preferences / shiftId and another values will delete just for logout
        // we don't need to clear!
        //  await _userDbHelper.logout();
       //   final prefs = await SharedPreferences.getInstance();
       //   await prefs.clear();

        // Notify UI of successful logout
        logoutSink.add(APIResponse.completed(logoutResponse));
      } else {
        // Handle unsuccessful logout
        logoutSink.add(APIResponse.error(logoutResponse.message.isNotEmpty ? logoutResponse.message : TextConstants.logoutFailed));
      }
    } catch (e) {
      // Handle various types of exceptions
      String errorMessage = TextConstants.failedToLogout;

      if (e.toString().contains('Unauthorised')) {
        logoutSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e is http.ClientException) {
        errorMessage = TextConstants.networkError;
      } else {
        try {
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
          if (jsonMatch != null) {
            final errorJson = json.decode(jsonMatch.group(0)!);
            errorMessage = errorJson['message']?.toString() ?? errorMessage;
          }
        } catch (_) {
          errorMessage = e.toString();
        }
      }

      if (kDebugMode) {
        print("LogoutBloc - Error during logout: $errorMessage");
      }
      if (!e.toString().contains('Unauthorised')) {
        logoutSink.add(APIResponse.error(errorMessage));
      }
    }
  }

  // Build #1.0.166: Added Logout By Employ Pin API call
  Future<void> performLogoutByEmpPin(int? empLoginPin) async { // PIN required for API body
    if (_logoutController.isClosed) {
      if (kDebugMode) {
        print("LogoutBloc - StreamController is closed, aborting logout");
      }
      return;
    }

    // Notify UI of loading state
    logoutSink.add(APIResponse.loading(TextConstants.loading));

    try {
      // Call repository to perform logout
      String response = await _logoutRepository.performLogoutByEmpPin(LogoutRequest(empLoginPin!));
      LogoutResponse logoutResponse = LogoutResponse.fromJson(json.decode(response));

      if (kDebugMode) {
        print("LogoutBloc , performLogoutByEmpPin - Logout response message: ${logoutResponse.message}");
      }

      if (logoutResponse.success) {
        // Notify UI of successful logout
        logoutSink.add(APIResponse.completed(logoutResponse));
      } else {
        // Handle unsuccessful logout
        logoutSink.add(APIResponse.error(logoutResponse.message.isNotEmpty ? logoutResponse.message : TextConstants.logoutFailed));
      }
    } catch (e) {
      // Handle various types of exceptions
      String errorMessage = TextConstants.failedToLogout;

      if (e.toString().contains('UnauthorisedException')) {
        logoutSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e is http.ClientException) {
        errorMessage = TextConstants.networkError;
      } else {
        try {
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
          if (jsonMatch != null) {
            final errorJson = json.decode(jsonMatch.group(0)!);
            errorMessage = errorJson['message']?.toString() ?? errorMessage;
          }
        } catch (_) {
          errorMessage = e.toString();
        }
      }

      if (kDebugMode) {
        print("LogoutBloc, performLogoutByEmpPin - Error during logout: $errorMessage");
      }
      if (!e.toString().contains('UnauthorisedException')) {
        logoutSink.add(APIResponse.error(errorMessage));
      }
    }
  }

  void dispose() {
    if (!_logoutController.isClosed) {
      _logoutController.close();
      if (kDebugMode) {
        print("LogoutBloc - Disposed");
      }
    }
  }
}