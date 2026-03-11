import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Helper/api_response.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Models/Auth/shift_summary_model.dart';
import '../../Repositories/Auth/shift_repository.dart';

class ShiftBloc { //Build #1.0.74: Updated Code
  final ShiftRepository _shiftRepository;

  // Stream controller for shifts by user
  final StreamController<APIResponse<ShiftsByUserResponse>> _shiftsByUserController =
  StreamController<APIResponse<ShiftsByUserResponse>>.broadcast();
  StreamSink<APIResponse<ShiftsByUserResponse>> get shiftsByUserSink =>
      _shiftsByUserController.sink;
  Stream<APIResponse<ShiftsByUserResponse>> get shiftsByUserStream =>
      _shiftsByUserController.stream;

  // Stream controller for shift by ID
  final StreamController<APIResponse<ShiftByIdResponse>> _shiftByIdController =
  StreamController<APIResponse<ShiftByIdResponse>>.broadcast();
  StreamSink<APIResponse<ShiftByIdResponse>> get shiftByIdSink =>
      _shiftByIdController.sink;
  Stream<APIResponse<ShiftByIdResponse>> get shiftByIdStream =>
      _shiftByIdController.stream;

  // Existing stream controller for manage shift
  final StreamController<APIResponse<ShiftResponse>> _shiftController =
  StreamController<APIResponse<ShiftResponse>>.broadcast();
  StreamSink<APIResponse<ShiftResponse>> get shiftSink => _shiftController.sink;
  Stream<APIResponse<ShiftResponse>> get shiftStream => _shiftController.stream;

  ShiftBloc(this._shiftRepository) {
    if (kDebugMode) {
      print("************** ShiftBloc Initialized");
    }
  }

  //Build #1.0.74: Fetch shifts by user ID
  Future<void> getShiftsByUser(int userId) async {
    if (_shiftsByUserController.isClosed) return;

    shiftsByUserSink.add(APIResponse.loading(TextConstants.loading));
    try {
      ShiftsByUserResponse response = await _shiftRepository.getShiftsByUser(userId);
      if (kDebugMode) {
        print("ShiftBloc - Successfully fetched ${response.shifts.length} shifts for user $userId");
      }
      shiftsByUserSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        shiftsByUserSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        shiftsByUserSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        shiftsByUserSink.add(APIResponse.error("Failed to fetch shifts: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in getShiftsByUser: $e");
    }
  }

  //Build #1.0.74: Fetch shift by shift ID
  Future<void> getShiftById(int shiftId) async {
    if (_shiftByIdController.isClosed) return;

    shiftByIdSink.add(APIResponse.loading(TextConstants.loading));
    try {
      ShiftByIdResponse response = await _shiftRepository.getShiftById(shiftId);
      if (kDebugMode) {
        print("ShiftBloc - Successfully fetched shift with ID $shiftId");
      }
      shiftByIdSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        shiftByIdSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        shiftByIdSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        shiftByIdSink.add(APIResponse.error("Failed to fetch shift: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in getShiftById: $e");
    }
  }

  // Existing manageShift method
  Future<void> manageShift(ShiftRequest request) async {
    if (_shiftController.isClosed) return;

    shiftSink.add(APIResponse.loading(TextConstants.loading));
    try {
      ShiftResponse response = await _shiftRepository.manageShift(request);
      shiftSink.add(APIResponse.completed(response));
    } catch (e) {
      if (e.toString().contains('Unauthorised')) {
        shiftSink.add(APIResponse.error("Unauthorised. Session is expired."));
      }
      else if (e.toString().contains('SocketException')) {
        shiftSink.add(APIResponse.error("Network error. Please check your connection."));
      } else {
        shiftSink.add(APIResponse.error("Failed to manage shift: ${e.toString()}"));
      }
      if (kDebugMode) print("Exception in manageShift: $e");
    }
  }

  void dispose() {
    if (!_shiftsByUserController.isClosed) { //Build #1.0.74
      _shiftsByUserController.close();
    }
    if (!_shiftByIdController.isClosed) {
      _shiftByIdController.close();
    }
    if (!_shiftController.isClosed) {
      _shiftController.close();
    }
    if (kDebugMode) print("ShiftBloc disposed");
  }
}