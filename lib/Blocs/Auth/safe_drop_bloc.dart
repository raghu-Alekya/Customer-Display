import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/safe_drop_model.dart';
import '../../Repositories/Auth/safe_drop_repository.dart';

class SafeDropBloc { // Build #1.0.70 - Added by Naveen
  final SafeDropRepository _safeDropRepository;
  final StreamController<APIResponse<SafeDropResponse>> _safeDropController =
  StreamController<APIResponse<SafeDropResponse>>.broadcast();

  StreamSink<APIResponse<SafeDropResponse>> get safeDropSink => _safeDropController.sink;
  Stream<APIResponse<SafeDropResponse>> get safeDropStream => _safeDropController.stream;

  SafeDropBloc(this._safeDropRepository) {
    if (kDebugMode) {
      print("************** SafeDropBloc Initialized");
    }
  }

  Future<void> createSafeDrop(SafeDropRequest request) async {
    if (_safeDropController.isClosed) return;

    safeDropSink.add(APIResponse.loading(TextConstants.loading));
    try {
      SafeDropResponse response = await _safeDropRepository.createSafeDrop(request);
      safeDropSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        safeDropSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        safeDropSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        safeDropSink.add(APIResponse.error("Failed to create safe drop: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in createSafeDrop: $e");
    }
  }

  void dispose() {
    if (!_safeDropController.isClosed) {
      _safeDropController.close();
      if (kDebugMode) print("SafeDropBloc disposed");
    }
  }
}