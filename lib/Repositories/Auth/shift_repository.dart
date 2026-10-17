import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Models/Auth/shift_summary_model.dart';
import '../../Screens/Auth/store_id_screen.dart';
import 'AuthIdsStore.dart';

class ShiftRepository {
  // PCH shift APIs (same as grocery)
  static const String _shiftsBaseUrl =
      'https://pch.alektasolutions.com/api/v1/pos/shifts/';
  static const String _openShiftUrl = '${_shiftsBaseUrl}open';
  static const String _closeShiftUrl = '${_shiftsBaseUrl}close';
  static const String _employeeShiftsUrl = '${_shiftsBaseUrl}employee/';

  final APIHelper _helper = APIHelper();

  Future<ShiftsByUserResponse> getShiftsByUser(int userId) async {
    // Prefer employee UUID endpoint when available
    final employeeId = await AuthIdsStore.getEmployeeId();
    if (employeeId.isNotEmpty) {
      try {
        return await getShiftsByEmployee(employeeId, userId);
      } catch (e) {
        if (kDebugMode) {
          print('ShiftRepository - employee shifts failed, legacy path: $e');
        }
      }
    }

    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByUserIdEndUrl}$userId";
    if (kDebugMode) print("ShiftRepository - GET shifts by user: $url");
    final response = await _helper.get(url, true);
    return _parseShiftsByUser(response);
  }

  Future<ShiftsByUserResponse> getShiftsByEmployee(
      String employeeId,
      int userId,
      ) async {
    final url = "$_employeeShiftsUrl$employeeId";
    if (kDebugMode) print("ShiftRepository - GET shifts by employee: $url");
    final response = await _helper.get(url, true);
    return _parseShiftsByUser(response);
  }

  ShiftsByUserResponse _parseShiftsByUser(dynamic response) {
    if (response is String) {
      final responseData = json.decode(response);
      return ShiftsByUserResponse.fromJson(responseData);
    }
    if (response is List) {
      return ShiftsByUserResponse.fromJson(response);
    }
    if (response is Map<String, dynamic>) {
      return ShiftsByUserResponse.fromJson(response as List<dynamic>);
    }
    throw Exception("Unexpected response type in get shifts by user");
  }

  Future<ShiftByIdResponse> getShiftById(int shiftId) async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByShiftIdEndUrl}$shiftId";
    if (kDebugMode) print("ShiftRepository - GET shift by id: $url");
    final response = await _helper.get(url, true);
    if (response is String) {
      return ShiftByIdResponse.fromJson(json.decode(response));
    }
    if (response is Map<String, dynamic>) {
      return ShiftByIdResponse.fromJson(response);
    }
    throw Exception("Unexpected response type in get shift by id");
  }

  /// Open / close shift via PCH APIs.
  Future<ShiftResponse> manageShift(ShiftRequest request) async {
    final status = (request.status ?? '').toLowerCase();
    final isOpening = status == 'open';
    final isClosing = status == 'close' || status == 'closed';

    final isOnline = await OfflineHelper.isNetworkAvailable();
    if (!isOnline) {
      throw Exception('No Internet connection. Cannot update shift.');
    }

    if (isOpening) {
      return _openShiftOnline(request);
    }
    if (isClosing) {
      return _closeShiftOnline(request);
    }

    // Fallback legacy create-shift path
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}";
    if (kDebugMode) {
      print("ShiftRepository - POST legacy manageShift: $url");
      print("ShiftRepository - Body: ${request.toJson()}");
    }
    final response = await _helper.post(url, request.toJson(), true);
    return _parseShiftResponse(response, request.totalAmount, 'open');
  }

  Future<ShiftResponse> _openShiftOnline(ShiftRequest request) async {
    final userData = await UserDbHelper().getUserData();
    final token = userData?[AppDBConst.userToken]?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw Exception('Cannot open shift without an authenticated user token.');
    }

    final merchantId = (await AuthIdsStore.getMerchantId()).trim();
    final storeId = (await AuthIdsStore.getStoreId()).trim();
    if (merchantId.isEmpty || storeId.isEmpty) {
      throw Exception(
          'Cannot open shift without stored merchant and store IDs.');
    }

    String deviceId =
        userData?[AppDBConst.posDeviceId]?.toString().trim() ?? '';
    if (deviceId.isEmpty) {
      try {
        deviceId = (await DeviceHelper.getDeviceId()).trim();
      } catch (_) {}
    }
    if (deviceId.isEmpty) deviceId = 'unknown_device';

    final cashierName =
    userData?[AppDBConst.userDisplayName]?.toString().trim();
    final effectiveCashierName =
    (cashierName == null || cashierName.isEmpty) ? 'Cashier' : cashierName;

    final employeeId = (await AuthIdsStore.getEmployeeId()).trim();

    // API: denomination must be positive number; denom_count non-negative int
    final drawerDenoms = request.drawerDenominations
        .where((e) => e.denomination > 0 && e.denomCount >= 0)
        .map((e) => e.toJson())
        .toList();

    final payload = <String, dynamic>{
      'merchant_id': merchantId,
      'store_id': storeId,
      'device_id': deviceId,
      'cashier_name': effectiveCashierName,
      'opening_cash': request.totalAmount,
      if (employeeId.isNotEmpty) 'opened_by_employee_id': employeeId,
      if (drawerDenoms.isNotEmpty) 'drawer_denominations': drawerDenoms,
    };

    if (kDebugMode) {
      print("ShiftRepository - OPEN URL: $_openShiftUrl");
      print("ShiftRepository - OPEN Body: $payload");
    }

    // Absolute URL → validateMarchentUrl true so base is not double-prepended
    final response = await _helper.post(
      _openShiftUrl,
      payload,
      true,
      validateMarchentUrl: true,
    );

    final shiftResponse = _parseOpenedShiftResponse(
      response,
      cashierName: effectiveCashierName,
      openingCash: request.totalAmount,
    );

    // Persist local shift id for order tagging
    final localId = shiftResponse.shiftId > 0
        ? shiftResponse.shiftId
        : DateTime.now().millisecondsSinceEpoch % 1000000000;
    await UserDbHelper().updateUserShiftId(localId);

    return ShiftResponse(
      shiftId: localId,
      externalShiftId: shiftResponse.externalShiftId,
      userName: shiftResponse.userName,
      totalAmount: shiftResponse.totalAmount,
      overShort: shiftResponse.overShort,
      status: shiftResponse.status,
    );
  }

  Future<ShiftResponse> _closeShiftOnline(ShiftRequest request) async {
    final userData = await UserDbHelper().getUserData();
    final cashierName =
        userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier';
    final employeeId = (await AuthIdsStore.getEmployeeId()).trim();
    final merchantId = (await AuthIdsStore.getMerchantId()).trim();
    final storeId = (await AuthIdsStore.getStoreId()).trim();

    String deviceId =
        userData?[AppDBConst.posDeviceId]?.toString().trim() ?? '';
    if (deviceId.isEmpty) {
      try {
        deviceId = (await DeviceHelper.getDeviceId()).trim();
      } catch (_) {}
    }
    if (deviceId.isEmpty) deviceId = 'unknown_device';

    final drawerDenoms = request.drawerDenominations
        .where((e) => e.denomination > 0 && e.denomCount >= 0)
        .map((e) => e.toJson())
        .toList();

    final payload = <String, dynamic>{
      'merchant_id': merchantId,
      'store_id': storeId,
      'device_id': deviceId,
      'cashier_name': cashierName,
      'closing_cash_actual': request.totalAmount,
      'closing_cash': request.totalAmount,
      if (employeeId.isNotEmpty) 'closed_by_employee_id': employeeId,
      if (request.shiftId != null) 'local_shift_id': request.shiftId,
      if (drawerDenoms.isNotEmpty) 'drawer_denominations': drawerDenoms,
    };

    if (kDebugMode) {
      print("ShiftRepository - CLOSE URL: $_closeShiftUrl");
      print("ShiftRepository - CLOSE Body: $payload");
    }

    final response = await _helper.post(
      _closeShiftUrl,
      payload,
      true,
      validateMarchentUrl: true,
    );

    await UserDbHelper().updateUserShiftId(null);

    return _parseShiftResponse(response, request.totalAmount, 'closed');
  }

  ShiftResponse _parseOpenedShiftResponse(
      dynamic response, {
        required String cashierName,
        required num openingCash,
      }) {
    Map<String, dynamic> responseData = {};
    if (response is String) {
      try {
        responseData = Map<String, dynamic>.from(json.decode(response));
      } catch (_) {}
    } else if (response is Map) {
      responseData = Map<String, dynamic>.from(response);
    }

    final shiftData = responseData['data'] is Map
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : responseData['shift'] is Map
        ? Map<String, dynamic>.from(responseData['shift'] as Map)
        : responseData;

    final externalId = (shiftData['shift_id'] ??
        shiftData['id'] ??
        shiftData['shiftId'] ??
        responseData['shift_id'] ??
        responseData['id'])
        ?.toString();

    int? numericShiftId;
    if (externalId != null && int.tryParse(externalId) != null) {
      numericShiftId = int.parse(externalId);
    } else if (externalId != null && externalId.isNotEmpty) {
      numericShiftId = externalId.hashCode.abs() % 1000000000;
    }

    final rawTotal = shiftData['total_amount'] ??
        shiftData['opening_cash'] ??
        responseData['total_amount'] ??
        responseData['opening_cash'] ??
        openingCash;
    final totalAmount = rawTotal is num
        ? rawTotal
        : num.tryParse(rawTotal?.toString() ?? '') ?? openingCash;

    final rawOverShort = shiftData['over_short'] ?? responseData['over_short'];
    final overShort = rawOverShort is num
        ? rawOverShort
        : num.tryParse(rawOverShort?.toString() ?? '') ?? 0;

    return ShiftResponse(
      shiftId: numericShiftId ?? 0,
      externalShiftId:
      (externalId != null && externalId.startsWith('SHIFT-'))
          ? externalId
          : externalId,
      userName: (shiftData['cashier_name'] ??
          shiftData['user'] ??
          responseData['cashier_name'])
          ?.toString() ??
          cashierName,
      totalAmount: totalAmount,
      overShort: overShort,
      status:
      (shiftData['status'] ?? responseData['status'])?.toString() ?? 'open',
    );
  }

  ShiftResponse _parseShiftResponse(
      dynamic response,
      num fallbackTotal,
      String fallbackStatus,
      ) {
    Map<String, dynamic> map = {};
    if (response is String) {
      try {
        map = Map<String, dynamic>.from(json.decode(response));
      } catch (_) {}
    } else if (response is Map) {
      map = Map<String, dynamic>.from(response);
    }
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final idRaw = data['shift_id'] ?? data['id'] ?? map['shift_id'];
    int shiftId = 0;
    if (idRaw is int) {
      shiftId = idRaw;
    } else if (idRaw != null) {
      shiftId = int.tryParse(idRaw.toString()) ??
          idRaw.toString().hashCode.abs() % 1000000000;
    }

    return ShiftResponse(
      shiftId: shiftId,
      externalShiftId: idRaw?.toString(),
      userName: (data['user'] ?? data['cashier_name'] ?? 'Cashier').toString(),
      totalAmount: num.tryParse(
        (data['total_amount'] ?? fallbackTotal).toString(),
      ) ??
          fallbackTotal,
      overShort: num.tryParse((data['over_short'] ?? 0).toString()) ?? 0,
      status: (data['status'] ?? fallbackStatus).toString(),
    );
  }

}
