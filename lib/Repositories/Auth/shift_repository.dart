import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Models/Auth/shift_summary_model.dart';

class ShiftRepository { // Build #1.0.70 - Added by Naveen
  final APIHelper _helper = APIHelper();

  //Build #1.0.74: Fetch shifts by user ID
  Future<ShiftsByUserResponse> getShiftsByUser(int userId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByUserIdEndUrl}$userId";

    if (kDebugMode) {
      print("ShiftRepository - GET URL for Shifts by User: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("ShiftRepository - GET Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return ShiftsByUserResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing shifts by user response: $e");
        throw Exception("Failed to parse shifts by user response");
      }
    } else if (response is List<dynamic>) {
      return ShiftsByUserResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in get shifts by user");
    }
  }

  //Build #1.0.74: Fetch shift by shift ID
  Future<ShiftByIdResponse> getShiftById(int shiftId) async {
    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByShiftIdEndUrl}$shiftId";

    if (kDebugMode) {
      print("ShiftRepository - GET URL for Shift by ID: $url");
    }

    final response = await _helper.get(url, true);

    if (kDebugMode) {
      print("ShiftRepository - GET Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return ShiftByIdResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing shift by id response: $e");
        throw Exception("Failed to parse shift by id response");
      }
    } else if (response is Map<String, dynamic>) {
      return ShiftByIdResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in get shift by id");
    }
  }

  // manageShift method
  Future<ShiftResponse> manageShift(ShiftRequest request) async {

    final url = "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}";

    if (kDebugMode) {
      print("ShiftRepository - POST URL: $url");
      print("ShiftRepository - POST Request Body: ${request.toJson()}");
    }

    final response = await _helper.post(url, request.toJson(), true);

    if (kDebugMode) {
      print("ShiftRepository - POST Raw Response: $response");
    }

    if (response is String) {
      try {
        final responseData = json.decode(response);
        return ShiftResponse.fromJson(responseData);
      } catch (e) {
        if (kDebugMode) print("Error parsing shift response: $e");
        throw Exception("Failed to parse shift response");
      }
    } else if (response is Map<String, dynamic>) {
      return ShiftResponse.fromJson(response);
    } else {
      throw Exception("Unexpected response type in shift management");
    }
  }
}