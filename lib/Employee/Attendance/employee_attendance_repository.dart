import 'package:dio/dio.dart';

import '../../core/api/pch_client.dart';
import '../../core/api/pch_config.dart';
import '../../core/api/pch_service_locator.dart';
import '../../core/api/pos_context_provider.dart';
import '../../Repositories/Auth/AuthIdsStore.dart';
import 'employee_attendance_model.dart';

class EmployeeAttendanceRepository {
  factory EmployeeAttendanceRepository.forCurrentApp() {
    final contextProvider = PchServiceLocator.contextProvider;
    final client = PchClient(
      baseUrl: PchConfig.attendanceBaseUrl,
      tokenStorage: PchServiceLocator.tokenStorage,
      contextProvider: contextProvider,
    );
    return EmployeeAttendanceRepository(
      client: client,
      contextProvider: contextProvider,
    );
  }
  EmployeeAttendanceRepository({
    required PchClient client,
    required PosContextProvider contextProvider,
  })  : _dio = client.dio,
        _contextProvider = contextProvider;

  final Dio _dio;
  final PosContextProvider _contextProvider;

  /// Reads attendance history for the authenticated POS employee only.
  Future<EmployeeAttendanceRecord?> getMyAttendanceForDate({
    required String employeeCode,
    required String date,
  }) async {
    try {
      final response = await _dio.get(
        'attendance',
        queryParameters: {
          'employeeCode': employeeCode,
          'date': date,
          'page': 1,
          'limit': 100,
        },
      );
      final body = _asMap(response.data);
      final rawRecords = body['records'];
      if (rawRecords is! List) return null;

      final records = rawRecords
          .whereType<Map>()
          .map((item) => EmployeeAttendanceRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList()
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn));
      return records.isEmpty ? null : records.first;
    } on DioException catch (error) {
      throw EmployeeAttendanceException(_messageFromDio(error));
    }
  }

  /// Gets the active clock-in record for the authenticated POS employee.
  Future<EmployeeAttendanceRecord?> getMyOpenAttendance() async {
    try {
      final response = await _dio.get('attendance/me');
      final body = _asMap(response.data);
      final raw = body['currentAttendance'];
      if (raw is! Map) return null;
      return EmployeeAttendanceRecord.fromJson(Map<String, dynamic>.from(raw));
    } on DioException catch (error) {
      throw EmployeeAttendanceException(_messageFromDio(error));
    }
  }

  Future<EmployeeAttendanceRecord> clockIn({
    required String employeeCode,
    required String pin,
  }) =>
      _clock('clock-in', employeeCode: employeeCode, pin: pin);

  Future<EmployeeAttendanceRecord> clockOut({
    required String employeeCode,
    required String pin,
  }) =>
      _clock('clock-out', employeeCode: employeeCode, pin: pin);

  Future<EmployeeAttendanceRecord> _clock(
    String action, {
    required String employeeCode,
    required String pin,
  }) async {
    final context = await _contextProvider.getContext();
    final merchantId =
        context?.merchantId ?? await AuthIdsStore.getMerchantId();
    final storeId = context?.storeId ?? await AuthIdsStore.getStoreId();
    if (merchantId.trim().isEmpty || storeId.trim().isEmpty) {
      throw const EmployeeAttendanceException(
        'Merchant/store context is missing. Select a store and sign in again.',
      );
    }

    try {
      final response = await _dio.post(
        'attendance/$action',
        data: {
          'employeeCode': employeeCode,
          'pin': pin,
          'merchantId': merchantId,
          'storeId': storeId,
        },
      );
      final body = _asMap(response.data);
      final dynamic rawAttendance = body['attendance'];
      // Clock-out currently returns attendance as a one-element array.
      final dynamic rawRecord = rawAttendance is List
          ? (rawAttendance.isEmpty ? null : rawAttendance.first)
          : rawAttendance;
      if (rawRecord is! Map) {
        throw const EmployeeAttendanceException(
          'The attendance API returned no attendance record.',
        );
      }
      final recordJson = Map<String, dynamic>.from(rawRecord);
      final employee = body['employee'] is Map
          ? Map<String, dynamic>.from(body['employee'] as Map)
          : const <String, dynamic>{};
      recordJson.putIfAbsent('employeeCode', () => employeeCode);
      recordJson.putIfAbsent(
        'employeeName',
        () => employee['employeeName'] ?? '',
      );
      return EmployeeAttendanceRecord.fromJson(recordJson);
    } on DioException catch (error) {
      throw EmployeeAttendanceException(_messageFromDio(error));
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const EmployeeAttendanceException(
      'The attendance API returned an invalid response.',
    );
  }

  String _messageFromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is List) return message.join(', ');
      if (message != null) return message.toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not reach the attendance service. Check the connection and try again.';
    }
    return 'Attendance request failed (${error.response?.statusCode ?? 'network error'}).';
  }
}

class EmployeeAttendanceException implements Exception {
  const EmployeeAttendanceException(this.message);
  final String message;

  @override
  String toString() => message;
}
