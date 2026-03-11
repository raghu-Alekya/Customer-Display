// blocs/store_validation_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/Extentions/exceptions.dart';
import '../../Helper/api_response.dart';
import '../../Helper/customerdisplayhelper.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Utilities/global_utility.dart';
import '../../Models/Auth/store_validation_model.dart';
import '../../Repositories/Auth/store_validation_repository.dart';

class StoreValidationBloc { //Build #1.0.42: Added by Naveen
  final StoreValidationRepository _repository;

  final StreamController<APIResponse<StoreValidationResponse>> _validationController =
  StreamController<APIResponse<StoreValidationResponse>>.broadcast();

  StreamSink<APIResponse<StoreValidationResponse>> get validationSink => _validationController.sink;
  Stream<APIResponse<StoreValidationResponse>> get validationStream => _validationController.stream;

  StoreValidationBloc(this._repository) {
    if (kDebugMode) {
      print("StoreValidationBloc Initialized");
    }
  }

  // In StoreValidationBloc.validateStore
  Future<void> validateStore({
    required String username,
    required String password,
    required String storeId,
  }) async {
    if (_validationController.isClosed) return;

    validationSink.add(APIResponse.loading(TextConstants.loading));
    try {
      final deviceDetails = await GlobalUtility.getDeviceDetails(); //Build #1.0.126: Updated code - using from global class
      final response = await _repository.validateStore(
        username: username,
        password: password,
        storeId: storeId,
        deviceId: deviceDetails['device_id'] ?? 'unknown',
      );

      if (kDebugMode) {
        print("StoreValidationBloc - Validation Response: ${response.toJson()}");
      }
      if (response.storeId != null && response.storeId!.isNotEmpty) {
        await PinakaPreferences.saveLoggedInStore(
          storeId: response.storeId!,
          storeName: response.storeName ?? "",
          storeLogoUrl: response.storeLogo,
          storeBaseUrl: response.storeBaseUrl,
        );

        await CustomerDisplayHelper.updateWelcomeWithStore(
          response.storeId!,
          response.storeName ?? "",
          storeLogoUrl: response.storeLogo,
          storeBaseUrl: response.storeBaseUrl,
        );
      }

      validationSink.add(APIResponse.completed(response));
    } catch (e, s) {
      String errorMessage = "Validation failed. Please try again.";
      if (kDebugMode) {
        print("Exception type: ${e.runtimeType}");
        print("Exception content: $e");
        print("Stack trace: $s");
      }

      if (e is UnauthorisedException || e is BadRequestException) {
        try {
          // Extract JSON from exception string
          final jsonMatch = RegExp(r'\{.*\}').firstMatch(e.toString());
          if (jsonMatch != null) {
            final errorJson = json.decode(jsonMatch.group(0)!);
            errorMessage = errorJson['message']?.toString() ?? "Invalid credentials.";
          } else {
            errorMessage = "Invalid credentials.";
          }
        } catch (_) {
          errorMessage = "Invalid credentials.";
        }
      } else if (e is SocketException) {
        errorMessage = "Network error. Please check your connection.";
      } else {
        // Handle generic exceptions
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

      validationSink.add(APIResponse.error(errorMessage));
      if (kDebugMode) print("Exception in validateStore: $e; Stack: $s");
    }
  }

  void dispose() {
    if (!_validationController.isClosed) {
      _validationController.close();
    }
    if (kDebugMode) print("StoreValidationBloc disposed");
  }
}