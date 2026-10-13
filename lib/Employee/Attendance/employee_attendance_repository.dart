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
          name: fullName.isNotEmpty ? fullName : (map['username'] ?? 'Employee'),
          isRegistered: map['pinSet'] == true || (map['loginPin'] != null),
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
  Future<EmployeeAttendanceRecord?> getMyAttendanceForDate({
    required String employeeCode,
    required String date,
  }) async {
    _log('========== GET ATTENDANCE HISTORY ==========');
    _log('Employee code: $employeeCode');
    _log('Date: $date');

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

      if (rawRecords is! List) return _todayRecordsCache[employeeCode];

      final records = rawRecords
          .whereType<Map>()
          .map(
            (item) => EmployeeAttendanceRecord.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList()
        ..sort((a, b) => b.clockIn.compareTo(a.clockIn));

      if (records.isNotEmpty) {
        _todayRecordsCache[employeeCode] = records.first;
        return records.first;
      }
      return _todayRecordsCache[employeeCode];
    } on DioException catch (error) {
      _logDioError('GET attendance history', error);
      // Return cached in-memory record if available
      return _todayRecordsCache[employeeCode];
    } catch (error) {
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
    _log('Operation: $operation, Status: ${error.response?.statusCode}, Error: ${error.response?.data}');
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