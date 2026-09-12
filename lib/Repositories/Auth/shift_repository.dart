import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../Database/db_helper.dart';
import '../../Database/shift_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Models/Auth/shift_summary_model.dart';

class ShiftRepository {
  final APIHelper _helper = APIHelper();

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch shifts by user ID (Online first + Offline fallback)
  // ─────────────────────────────────────────────────────────────────────────
  Future<ShiftsByUserResponse> getShiftsByUser(int userId) async {
    final isOnline = await OfflineHelper.isNetworkAvailable();
    final isOfflineSession = await UserDbHelper().isOfflineSession();

    if (isOnline && !isOfflineSession) {
      final url =
          "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByUserIdEndUrl}$userId";

      if (kDebugMode) {
        print("ShiftRepository - GET URL for Shifts by User: $url");
      }

      try {
        final response = await _helper.get(url, true);

        if (kDebugMode) {
          print("ShiftRepository - GET Raw Response: $response");
        }

        if (response is String) {
          final responseData = json.decode(response);
          return ShiftsByUserResponse.fromJson(responseData);
        } else if (response is List<dynamic>) {
          return ShiftsByUserResponse.fromJson(response);
        }
      } catch (e) {
        if (kDebugMode) print("ShiftRepository - getShiftsByUser online failed: $e");
        if (OfflineHelper.isSessionError(e)) rethrow;
      }
    }

    // Offline fallback: query local shifts from SQLite
    try {
      final shifts = await ShiftDbHelper().getPendingShifts();
      return ShiftsByUserResponse(
        shifts: shifts.map((s) {
          return Shift(
            shiftId: s[AppDBConst.shiftLocalId] as int? ?? 0,
            title: 'Offline Shift #${s[AppDBConst.shiftLocalId]}',
            userId: s[AppDBConst.userId] as int? ?? userId,
            userName: 'Cashier',
            assignedStaff: 0,
            startTime: s[AppDBConst.shiftStartTime]?.toString() ?? '',
            endTime: s[AppDBConst.shiftEndTime]?.toString() ?? '',
            totalSales: 0,
            totalSaleAmount: (s[AppDBConst.shiftTotalSalesAmount] as num?)?.toDouble() ?? 0.0,
            safeDropTotal: (s[AppDBConst.shiftSafeDropTotal] as num?)?.toDouble() ?? 0.0,
            safeDrops: const [],
            vendorPayouts: const [],
            totalVendorPayments: (s[AppDBConst.shiftVendorPayoutTotal] as num?)?.toDouble() ?? 0.0,
            openingBalance: (s[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0,
            closingBalance: (s[AppDBConst.shiftClosingBalance] as num?)?.toDouble() ?? 0.0,
            notes: '',
            shiftClosingNotes: '',
            shiftStatus: s[AppDBConst.shiftStatus]?.toString() ?? 'OPEN',
            overShort: (s[AppDBConst.shiftOverShort] as num?)?.toDouble() ?? 0.0,
            tillAmount: (s[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0,
          );
        }).toList(),
      );
    } catch (e) {
      if (kDebugMode) print("ShiftRepository - offline getShiftsByUser error: $e");
      return const ShiftsByUserResponse(shifts: []);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch shift by shift ID
  // ─────────────────────────────────────────────────────────────────────────
  Future<ShiftByIdResponse> getShiftById(int shiftId) async {
    final isOnline = await OfflineHelper.isNetworkAvailable();
    final isOfflineSession = await UserDbHelper().isOfflineSession();

    if (isOnline && !isOfflineSession) {
      final url =
          "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.shiftByShiftIdEndUrl}$shiftId";

      if (kDebugMode) {
        print("ShiftRepository - GET URL for Shift by ID: $url");
      }

      try {
        final response = await _helper.get(url, true);

        if (kDebugMode) {
          print("ShiftRepository - GET Raw Response: $response");
        }

        if (response is String) {
          final responseData = json.decode(response);
          return ShiftByIdResponse.fromJson(responseData);
        } else if (response is Map<String, dynamic>) {
          return ShiftByIdResponse.fromJson(response);
        }
      } catch (e) {
        if (kDebugMode) print("ShiftRepository - getShiftById online error: $e");
        if (OfflineHelper.isSessionError(e)) rethrow;
      }
    }

    // Offline fallback: return synthetic shift
    return ShiftByIdResponse(
      shift: Shift(
        shiftId: shiftId,
        title: 'Shift #$shiftId',
        userId: 0,
        userName: 'Cashier',
        assignedStaff: 0,
        startTime: DateTime.now().toIso8601String(),
        endTime: '',
        totalSales: 0,
        totalSaleAmount: 0.0,
        safeDropTotal: 0.0,
        safeDrops: const [],
        vendorPayouts: const [],
        totalVendorPayments: 0.0,
        openingBalance: 0.0,
        closingBalance: 0.0,
        notes: '',
        shiftClosingNotes: '',
        shiftStatus: 'OPEN',
        overShort: 0.0,
        tillAmount: 0.0,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Manage shift: Open / Close shift
  // ─────────────────────────────────────────────────────────────────────────
  Future<ShiftResponse> manageShift(ShiftRequest request) async {
    final isOnline = await OfflineHelper.isNetworkAvailable();
    final isOfflineSession = await UserDbHelper().isOfflineSession();

    if (isOnline && !isOfflineSession) {
      final url =
          "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}";

      if (kDebugMode) {
        print("ShiftRepository - POST URL: $url");
        print("ShiftRepository - POST Request Body: ${request.toJson()}");
      }

      try {
        final response = await _helper.post(url, request.toJson(), true);

        if (kDebugMode) {
          print("ShiftRepository - POST Raw Response: $response");
        }

        ShiftResponse shiftResponse;
        if (response is String) {
          final responseData = json.decode(response);
          shiftResponse = ShiftResponse.fromJson(responseData);
        } else if (response is Map<String, dynamic>) {
          shiftResponse = ShiftResponse.fromJson(response);
        } else {
          throw Exception("Unexpected response type in shift management");
        }

        // Update local shift ID in User table
        if (request.status?.toLowerCase() == "open") {
          final userData = await UserDbHelper().getUserData();
          final userId = userData?[AppDBConst.userId] as int? ?? 0;
          await ShiftDbHelper().createOnlineShiftMirror(
            userId: userId,
            serverShiftId: shiftResponse.shiftId,
            openingBalance: request.drawerTotalAmount.toDouble(),
            requestPayload: request.toJson(),
          );
          await UserDbHelper().updateUserShiftId(shiftResponse.shiftId);
        } else if (request.status?.toLowerCase() == "close" || request.status?.toLowerCase() == "closed") {
          await UserDbHelper().updateUserShiftId(null);
        }

        return shiftResponse;
      } catch (e, s) {
        if (kDebugMode) {
          print("ShiftRepository - Online manageShift exception: $e\n$s");
        }
        // If the session token is genuinely expired on the online backend, rethrow so UI redirects to login
        if (OfflineHelper.isSessionError(e) && !isOfflineSession) {
          rethrow;
        }
        // Otherwise fall through to offline local shift creation
      }
    }

    // ── OFFLINE SHIFT MANAGEMENT (SQLite) ──────────────────────────────────
    final userData = await UserDbHelper().getUserData();
    final userId = userData?[AppDBConst.userId] as int? ?? 0;
    final userName = userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier';

    if (request.status?.toLowerCase() == "open") {
      final localShiftId = await ShiftDbHelper().createShiftOffline(
        userId: userId,
        openingBalance: request.drawerTotalAmount.toDouble(),
        requestPayload: request.toJson(),
      );

      await UserDbHelper().updateUserShiftId(localShiftId);

      if (kDebugMode) {
        print("ShiftRepository - Created offline shift with ID: $localShiftId");
      }

      return ShiftResponse(
        shiftId: localShiftId,
        userName: userName,
        totalAmount: request.totalAmount,
        overShort: 0,
        status: 'open',
      );
    } else {
      // Close shift offline
      final shiftIdToClose = request.shiftId ?? (await UserDbHelper().getUserShiftId()) ?? 0;
      try {
        await ShiftDbHelper().closeShiftByLocalOrServerId(
          shiftId: shiftIdToClose,
          userId: userId,
          closingBalance: request.drawerTotalAmount.toDouble(),
          closePayload: request.toJson(),
        );
      } catch (e) {
        if (kDebugMode) print("ShiftRepository - offline closeShift error: $e");
      }

      await UserDbHelper().updateUserShiftId(null);

      if (kDebugMode) {
        print("ShiftRepository - Closed offline shift: $shiftIdToClose");
      }

      return ShiftResponse(
        shiftId: shiftIdToClose,
        userName: userName,
        totalAmount: request.totalAmount,
        overShort: 0,
        status: 'closed',
      );
    }
  }

  /// Replays closes made while disconnected before a new authentication is
  /// requested. This releases the server-side open shift/session that would
  /// otherwise produce `session_active_elsewhere` on the next login.
  Future<void> syncPendingRemoteClosures() async {
    if (!await OfflineHelper.isNetworkAvailable()) return;

    final pending = await ShiftDbHelper().getPendingShifts();
    var syncedClosure = false;
    for (final shift in pending) {
      if (shift[AppDBConst.shiftStatus]?.toString() != 'CLOSED') continue;
      final serverId = shift[AppDBConst.shiftServerId] as int?;
      if (serverId == null) continue; // Locally opened shifts need a server create first.

      final rawPayload = shift['close_payload']?.toString();
      if (rawPayload == null || rawPayload.isEmpty) continue;
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      payload['shift_id'] = serverId;
      payload['status'] = 'closed';

      final url =
          '${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}';
      await _helper.post(url, payload, true);
      await ShiftDbHelper().markShiftClosureSynced(
        shift[AppDBConst.shiftLocalId] as int,
      );
      syncedClosure = true;
    }

    // The normal online close flow logs out immediately after closing. Do the
    // same after replaying an offline close so the following token request is
    // not rejected as an already-active console session.
    if (syncedClosure) {
      final logoutUrl =
          '${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}${EndUrlConstants.logout}';
      try {
        await _helper.post(logoutUrl, {}, true);
      } catch (e) {
        if (kDebugMode) {
          print('ShiftRepository - queued-close logout retry failed: $e');
        }
      }
    }
  }
}
