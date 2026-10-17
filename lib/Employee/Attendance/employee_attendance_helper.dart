import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Repositories/Auth/AuthIdsStore.dart';
import '../../core/api/models/pos_context.dart';
import '../../core/api/pch_service_locator.dart';
import 'employee_attendance_model.dart';
import 'employee_attendance_popup.dart';
import 'employee_attendance_repository.dart';

/// Opens the employee attendance dialog (clock-in / clock-out).
/// Call after login or from an Apps menu action:
///   await EmployeeAttendanceHelper.show(context);
class EmployeeAttendanceHelper {
  /// Sync the active user JWT into [TokenStorage] so Dio can authenticate.
  static Future<void> syncTokenFromUserDb() async {
    try {
      final user = await UserDbHelper().getUserData();
      final token = user?[AppDBConst.userToken]?.toString().trim();
      if (token != null && token.isNotEmpty) {
        await PchServiceLocator.tokenStorage.saveAccessToken(token);
        if (kDebugMode) {
          print('[Attendance] Token synced from user DB');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Attendance] Token sync failed: $e');
    }
  }

  /// Ensure merchant/store/device are in PosContext for attendance headers.
  static Future<void> syncPosContext() async {
    try {
      final merchantId = (await AuthIdsStore.getMerchantId()).trim();
      final storeId = (await AuthIdsStore.getStoreId()).trim();
      if (merchantId.isEmpty || storeId.isEmpty) return;

      final existing = await PchServiceLocator.contextProvider.getContext();
      final deviceId = (existing?.deviceId ?? 'unknown_device').trim().isEmpty
          ? 'unknown_device'
          : (existing?.deviceId ?? 'unknown_device');

      await PchServiceLocator.contextProvider.saveContext(
        PosContext(
          merchantId: merchantId,
          storeId: storeId,
          deviceId: deviceId,
          userId: existing?.userId,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('[Attendance] PosContext sync failed: $e');
    }
  }

  /// Show the attendance popup. Loads store employees from the API.
  static Future<void> show(BuildContext context) async {
    await syncTokenFromUserDb();
    await syncPosContext();

    final repo = EmployeeAttendanceRepository.forCurrentApp();
    String merchantId = '';
    String storeId = '';
    try {
      merchantId = (await AuthIdsStore.getMerchantId()).trim();
      storeId = (await AuthIdsStore.getStoreId()).trim();
    } catch (_) {}

    List<AttendanceEmployee> employees = [];
    if (merchantId.isNotEmpty && storeId.isNotEmpty) {
      try {
        employees = await repo.getStoreEmployees(
          merchantId: merchantId,
          storeId: storeId,
        );
      } catch (e) {
        if (kDebugMode) print('[Attendance] getStoreEmployees failed: $e');
      }
    }

    String currentCode = '';
    try {
      final empId = (await AuthIdsStore.getEmployeeId()).trim();
      if (empId.isNotEmpty) {
        currentCode = empId;
      } else {
        final user = await UserDbHelper().getUserData();
        currentCode = user?[AppDBConst.userNickname]?.toString() ??
            user?[AppDBConst.userEmail]?.toString() ??
            '';
      }
    } catch (_) {}

    if (employees.isEmpty && currentCode.isNotEmpty) {
      String name = 'Current user';
      try {
        final user = await UserDbHelper().getUserData();
        name = user?[AppDBConst.userDisplayName]?.toString() ?? name;
      } catch (_) {}
      employees = [
        AttendanceEmployee(
          employeeCode: currentCode,
          name: name,
          isRegistered: true,
          roleName: 'Staff',
        ),
      ];
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EmployeeAttendanceApiPopup(
        employees: employees,
        currentEmployeeCode: currentCode.isNotEmpty
            ? currentCode
            : (employees.isNotEmpty ? employees.first.employeeCode : ''),
        repository: repo,
      ),
    );
  }
}
