import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/pch_client.dart';
import '../../core/api/pch_config.dart';
import '../../core/api/pch_service_locator.dart';
import '../../core/api/pos_context_provider.dart';
import '../../Repositories/Auth/AuthIdsStore.dart';
import 'employee_attendance_model.dart';

class EmployeeAttendanceRepository {
  // Static cache persists attendance status in memory across dialog opens/closes
  static final Map<String, EmployeeAttendanceRecord> _todayRecordsCache = {};

  static Map<String, EmployeeAttendanceRecord> get cachedRecords =>
      Map.unmodifiable(_todayRecordsCache);

  static void cacheRecord(EmployeeAttendanceRecord record) {
    _todayRecordsCache[record.employeeCode] = record;
  }

  factory EmployeeAttendanceRepository.forCurrentApp() {
    final contextProvider = PchServiceLocator.contextProvider;
    final baseUrl = PchConfig.attendanceBaseUrl;

    final client = PchClient(
      baseUrl: baseUrl,
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

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Attendance] $message');
    }
  }

  /// Fetches all active employees assigned to this store from the backend
  Future<List<AttendanceEmployee>> getStoreEmployees({
    required String merchantId,
    required String storeId,
  }) async {
    try {
      final response = await _dio.get(
        'merchants/$merchantId/stores/$storeId/employees',
      );

      final body = _asMap(response.data);
      final rawList = body['employees'];
      if (rawList is! List) return [];

      return rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final firstName = (map['firstName'] ?? '').toString().trim();
        final lastName = (map['lastName'] ?? '').toString().trim();
        final fullName = '$firstName $lastName'.trim();

        return AttendanceEmployee(
          employeeCode: map['employeeCode'] ?? '',
          name:
              fullName.isNotEmpty ? fullName : (map['username'] ?? 'Employee'),
          isRegistered: true,
          loginPin: map['loginPin']?.toString(),
          roleName: map['roleName']?.toString() ?? 'Staff',
        );
      }).toList();
    } on DioException catch (e) {
      _logDioError('GET store employees', e);
      return [];
    }
  }

  /// Reads attendance history for an employee and date.
  /// Reads attendance history for an employee.
  Future<EmployeeAttendanceRecord?> getMyAttendanceForDate({
    required String employeeCode,
    required String date,
  }) async {
    _log('========== GET ATTENDANCE HISTORY ==========');
    _log('Fetching for employeeCode: "$employeeCode"');

    try {
      final response = await _dio.get(
        'attendance',
        queryParameters: {
          'employeeCode': employeeCode.trim(),
          'page': 1,
          'limit': 100,
          // Note: We don't strictly filter by 'date' in query params to avoid
          // UTC vs Local timezone day-shift drops; we sort by clockIn DESC instead!
        },
      );

      final body = _asMap(response.data);
      final rawRecords = body['records'];

      if (rawRecords is! List || rawRecords.isEmpty) {
        _log('No records returned by server for $employeeCode');
        return _todayRecordsCache[employeeCode];
      }

      _log('Server returned ${rawRecords.length} records for $employeeCode');

      final records = <EmployeeAttendanceRecord>[];
      for (final item in rawRecords) {
        if (item is Map) {
          try {
            records.add(EmployeeAttendanceRecord.fromJson(
              Map<String, dynamic>.from(item),
            ));
          } catch (e) {
            _log('Record parse error for $employeeCode: $e | Raw: $item');
          }
        }
      }

      if (records.isEmpty) {
        return _todayRecordsCache[employeeCode];
      }

      // Sort by clockIn DESC (latest first)
      records.sort((a, b) => b.clockIn.compareTo(a.clockIn));

      final latest = records.first;
      _log('Latest record for $employeeCode: status=${latest.status}, isOpen=${latest.isOpen}, in=${latest.clockIn}, out=${latest.clockOut}');

      // If the latest record has no clockOut, it is an open PRESENT session!
      _todayRecordsCache[employeeCode] = latest;
      return latest;
    } on DioException catch (error) {
      _logDioError('GET attendance history', error);
      return _todayRecordsCache[employeeCode];
    } catch (error) {
      _log('Unexpected error fetching attendance for $employeeCode: $error');
      return _todayRecordsCache[employeeCode];
    }
  }
  /// Gets the active clock-in record.
  Future<EmployeeAttendanceRecord?> getMyOpenAttendance() async {
    try {
      final response = await _dio.get('attendance/me');
      final body = _asMap(response.data);
      final raw = body['currentAttendance'];

      if (raw is! Map) return null;

      final record = EmployeeAttendanceRecord.fromJson(
        Map<String, dynamic>.from(raw),
      );
      _todayRecordsCache[record.employeeCode] = record;
      return record;
    } on DioException catch (error) {
      _logDioError('GET attendance/me', error);
      return null;
    }
  }

  Future<EmployeeAttendanceRecord> clockIn({
    required String employeeCode,
    required String pin,
  }) {
    return _clock('clock-in', employeeCode: employeeCode, pin: pin);
  }

  Future<EmployeeAttendanceRecord> clockOut({
    required String employeeCode,
    required String pin,
  }) {
    return _clock('clock-out', employeeCode: employeeCode, pin: pin);
  }

  Future<EmployeeAttendanceRecord> _clock(
    String action, {
    required String employeeCode,
    required String pin,
  }) async {
    _log('========== ATTENDANCE $action ==========');
    _log('Employee code: $employeeCode');

    try {
      final context = await _contextProvider.getContext();
      String? merchantId = context?.merchantId;
      String? storeId = context?.storeId;

      if (merchantId == null || merchantId.trim().isEmpty) {
        merchantId = await AuthIdsStore.getMerchantId();
      }

      if (storeId == null || storeId.trim().isEmpty) {
        storeId = await AuthIdsStore.getStoreId();
      }

      if (merchantId == null ||
          merchantId.trim().isEmpty ||
          storeId == null ||
          storeId.trim().isEmpty) {
        throw const EmployeeAttendanceException(
          'Merchant/store context is missing. Select a store and sign in again.',
        );
      }

      final response = await _dio.post(
        'attendance/$action',
        data: {
          'employeeCode': employeeCode.trim(),
          'pin': pin.trim(),
          'merchantId': merchantId.trim(),
          'storeId': storeId.trim(),
        },
      );

      final body = _asMap(response.data);
      final dynamic rawAttendance = body['attendance'];
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
          : <String, dynamic>{};

      recordJson.putIfAbsent('employeeCode', () => employeeCode);
      recordJson.putIfAbsent(
        'employeeName',
        () => employee['employeeName'] ?? '',
      );

      final record = EmployeeAttendanceRecord.fromJson(recordJson);

      // Save into cache so status is retained across popup open/close
      _todayRecordsCache[employeeCode] = record;

      _log('$action completed successfully.');
      return record;
    } on DioException catch (error) {
      _logDioError('POST attendance/$action', error);
      throw EmployeeAttendanceException(_messageFromDio(error));
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const EmployeeAttendanceException('Invalid API response format.');
  }

  void _logDioError(String operation, DioException error) {
    _log(
        'Operation: $operation, Status: ${error.response?.statusCode}, Error: ${error.response?.data}');
  }

  String _messageFromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is List) return message.join(', ');
      if (message != null) return message.toString();
    }
    return error.message ?? 'Attendance request failed';
  }
}

class EmployeeAttendanceException implements Exception {
  const EmployeeAttendanceException(this.message);
  final String message;
  @override
  String toString() => message;
}
