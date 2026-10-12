import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/shift_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/shift_model.dart';
import '../../Models/Auth/shift_summary_model.dart';
import 'AuthIdsStore.dart';
import '../../Screens/Auth/store_id_screen.dart';

class ShiftRepository {
  static const String _openShiftUrl =
      'https://pch.alektasolutions.com/api/v1/pos/shifts/open';
  static const String _closeShiftUrl =
      'https://pch.alektasolutions.com/api/v1/pos/shifts/close';

  final APIHelper _helper = APIHelper();
  final ShiftDbHelper _shiftDbHelper =
  ShiftDbHelper(); // ADD THIS — was missing entirely

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
        } else if (response is List || response is Map) {
          return ShiftsByUserResponse.fromJson(response);
        }
      } catch (e) {
        if (kDebugMode)
          print("ShiftRepository - getShiftsByUser online failed: $e");
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
            totalSaleAmount:
            (s[AppDBConst.shiftTotalSalesAmount] as num?)?.toDouble() ??
                0.0,
            safeDropTotal:
            (s[AppDBConst.shiftSafeDropTotal] as num?)?.toDouble() ?? 0.0,
            safeDrops: const [],
            vendorPayouts: const [],
            totalVendorPayments:
            (s[AppDBConst.shiftVendorPayoutTotal] as num?)?.toDouble() ??
                0.0,
            openingBalance:
            (s[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0,
            closingBalance:
            (s[AppDBConst.shiftClosingBalance] as num?)?.toDouble() ?? 0.0,
            notes: '',
            shiftClosingNotes: '',
            shiftStatus: s[AppDBConst.shiftStatus]?.toString() ?? 'OPEN',
            overShort:
            (s[AppDBConst.shiftOverShort] as num?)?.toDouble() ?? 0.0,
            tillAmount:
            (s[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0,
          );
        }).toList(),
      );
    } catch (e) {
      if (kDebugMode)
        print("ShiftRepository - offline getShiftsByUser error: $e");
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
        if (kDebugMode)
          print("ShiftRepository - getShiftById online error: $e");
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
    final isClosing = request.status?.toLowerCase() == 'close' ||
        request.status?.toLowerCase() == 'closed';
    final localShift = request.shiftId != null
        ? await _shiftDbHelper.getShiftById(request.shiftId!)
        : null;
    final rawServerShiftId = localShift?[AppDBConst.shiftServerId];
    final externalServerShiftId =
    rawServerShiftId?.toString().startsWith('SHIFT-') == true
        ? rawServerShiftId.toString()
        : null;
    final isExternalClosePreview = externalServerShiftId != null &&
        request.status?.toLowerCase() == 'update';

    if (isOnline && !isOfflineSession) {
      final isOpening = request.status?.toLowerCase() == 'open';
      final url = isOpening
          ? _openShiftUrl
          : isClosing && externalServerShiftId != null
          ? _closeShiftUrl
          : "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}";

      if (kDebugMode) {
        print("ShiftRepository - POST URL: $url");
        if (!isOpening) {
          print("ShiftRepository - POST Request Body: ${request.toJson()}");
        }
      }

      try {
        ShiftResponse shiftResponse;
        if (isOpening) {
          final userData = await UserDbHelper().getUserData();
          final token =
              userData?[AppDBConst.userToken]?.toString().trim() ?? '';
          if (token.isEmpty) {
            throw Exception(
                'Cannot open shift without an authenticated user token.');
          }

          final merchantId = (await AuthIdsStore.getMerchantId()).trim();
          final storeId = (await AuthIdsStore.getStoreId()).trim();
          if (merchantId.isEmpty || storeId.isEmpty) {
            throw Exception(
                'Cannot open shift without stored merchant and store IDs.');
          }
          String deviceId =
              userData?[AppDBConst.posDeviceId]?.toString().trim() ?? '';
          // Fallback: same DeviceHelper used at login (Windows/Android/iOS)
          if (deviceId.isEmpty) {
            try {
              deviceId = (await DeviceHelper.getDeviceId()).trim();
            } catch (_) {}
          }
          if (deviceId.isEmpty || deviceId.toLowerCase() == 'unknown') {
            throw Exception(
              'Cannot open shift without a device ID. Please log out and log in again.',
            );
          }
          // Persist so next open does not need fallback
          try {
            final uid = userData?[AppDBConst.userId];
            if (uid != null) {
              final db = await DBHelper.instance.database;
              await db.update(
                AppDBConst.userTable,
                {AppDBConst.posDeviceId: deviceId},
                where: '${AppDBConst.userId} = ?',
                whereArgs: [uid],
              );
            }
          } catch (_) {}
          if (kDebugMode) {
            print('ShiftRepository - open shift device_id: $deviceId');
          }

          final cashierName =
          userData?[AppDBConst.userDisplayName]?.toString().trim();
          final effectiveCashierName =
          cashierName == null || cashierName.isEmpty
              ? 'Cashier'
              : cashierName;
          final payload = <String, dynamic>{
            'merchant_id': merchantId,
            'store_id': storeId,
            'device_id': deviceId,
            'cashier_name': effectiveCashierName,
            'opening_cash': request.totalAmount,
          };
          final response = await _helper.post(
            url,
            payload,
            true,
            validateMarchentUrl: true,
          );
          shiftResponse = _parseOpenedShiftResponse(
            response,
            cashierName: effectiveCashierName,
            openingCash: request.totalAmount,
          );
          if (shiftResponse.externalShiftId != null) {
            final userId = userData?[AppDBConst.userId] as int? ?? 0;
            final localShiftId = await _shiftDbHelper.cacheOnlineShift(
              userId: userId,
              serverShiftId: shiftResponse.externalShiftId!,
              openingBalance: request.totalAmount.toDouble(),
              requestPayload: request.toJson(),
            );
            shiftResponse = ShiftResponse(
              shiftId: localShiftId,
              externalShiftId: shiftResponse.externalShiftId,
              userName: shiftResponse.userName,
              totalAmount: shiftResponse.totalAmount,
              overShort: shiftResponse.overShort,
              status: shiftResponse.status,
            );
            await UserDbHelper().updateUserShiftId(localShiftId);
          }
        } else if (isClosing && externalServerShiftId != null) {
          final userData = await UserDbHelper().getUserData();
          final cashierName =
              userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier';
          shiftResponse = await _closeExternalShift(
            serverShiftId: externalServerShiftId,
            localShiftId: request.shiftId!,
            closingCash: request.totalAmount,
            cashierName: cashierName,
          );
          await _shiftDbHelper.closeShiftOffline(
            localShiftId: request.shiftId!,
            closingBalance: request.totalAmount.toDouble(),
            closePayload: request.toJson(),
          );
          await _shiftDbHelper.markShiftClosureSynced(request.shiftId!);
        } else if (isExternalClosePreview) {
          final openingCash =
              (localShift?[AppDBConst.shiftOpeningBalance] as num?)
                  ?.toDouble() ??
                  0;
          final totalSales =
              (localShift?[AppDBConst.shiftTotalSalesAmount] as num?)
                  ?.toDouble() ??
                  0;
          final safeDrops = (localShift?[AppDBConst.shiftSafeDropTotal] as num?)
              ?.toDouble() ??
              0;
          final payouts =
              (localShift?[AppDBConst.shiftVendorPayoutTotal] as num?)
                  ?.toDouble() ??
                  0;
          final expectedCash = openingCash + totalSales - safeDrops - payouts;
          final userData = await UserDbHelper().getUserData();
          shiftResponse = ShiftResponse(
            shiftId: request.shiftId!,
            externalShiftId: externalServerShiftId,
            userName:
            userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier',
            totalAmount: request.totalAmount,
            overShort: request.totalAmount - expectedCash,
            status: 'OPEN',
          );
        } else {
          final response = await _helper.post(url, request.toJson(), true);
          if (response is String) {
            final responseData = json.decode(response);
            shiftResponse = ShiftResponse.fromJson(responseData);
          } else if (response is Map<String, dynamic>) {
            shiftResponse = ShiftResponse.fromJson(response);
          } else {
            throw Exception("Unexpected response type in shift management");
          }
        }

        if (kDebugMode) {
          print("ShiftRepository - Shift operation completed");
        }

        // Update local shift ID in User table
        if (request.status?.toLowerCase() == "open") {
          if (shiftResponse.externalShiftId == null) {
            final userData = await UserDbHelper().getUserData();
            final userId = userData?[AppDBConst.userId] as int? ?? 0;
            await ShiftDbHelper().createOnlineShiftMirror(
              userId: userId,
              serverShiftId: shiftResponse.shiftId,
              openingBalance: request.drawerTotalAmount.toDouble(),
              requestPayload: request.toJson(),
            );
            await UserDbHelper().updateUserShiftId(shiftResponse.shiftId);
          }
        } else if (request.status?.toLowerCase() == "close" ||
            request.status?.toLowerCase() == "closed") {
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
        if (request.status?.toLowerCase() == 'open') {
          rethrow;
        }
        // Otherwise fall through to offline local shift creation
      }
    }

    // ── OFFLINE SHIFT MANAGEMENT (SQLite) ──────────────────────────────────
    final userData = await UserDbHelper().getUserData();
    final userId = userData?[AppDBConst.userId] as int? ?? 0;
    final userName =
        userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier';

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
      final shiftIdToClose =
          request.shiftId ?? (await UserDbHelper().getUserShiftId()) ?? 0;
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

  Future<ShiftResponse> _closeExternalShift({
    required String serverShiftId,
    required int localShiftId,
    required num closingCash,
    required String cashierName,
  }) async {
    final payload = <String, dynamic>{
      'shift_id': serverShiftId,
      'closing_cash_actual': closingCash,
    };
    final response = await _helper.post(
      _closeShiftUrl,
      payload,
      true,
      validateMarchentUrl: true,
    );

    final dynamic decoded =
    response is String ? json.decode(response) : response;
    if (decoded is! Map) {
      throw const FormatException(
        'Unexpected response format when closing shift.',
      );
    }
    final responseData = Map<String, dynamic>.from(decoded);
    if (responseData['success'] == false) {
      throw Exception(
        responseData['message']?.toString() ?? 'Shift close was rejected.',
      );
    }

    final shiftData = responseData['shift'] is Map
        ? Map<String, dynamic>.from(responseData['shift'] as Map)
        : responseData;
    final rawOverShort =
        shiftData['cashDifference'] ?? shiftData['overShort'] ?? 0;
    final overShort = rawOverShort is num
        ? rawOverShort
        : num.tryParse(rawOverShort.toString()) ?? 0;
    return ShiftResponse(
      shiftId: localShiftId,
      externalShiftId: serverShiftId,
      userName:
      (shiftData['cashierName'] ?? shiftData['cashier_name'])?.toString() ??
          cashierName,
      totalAmount: closingCash,
      overShort: overShort,
      status: (shiftData['status'] ?? responseData['status'])?.toString() ??
          'CLOSED',
    );
  }

  ShiftResponse _parseOpenedShiftResponse(
      dynamic response, {
        required String cashierName,
        required num openingCash,
      }) {
    final dynamic decoded;
    if (response is String) {
      decoded = json.decode(response);
    } else {
      decoded = response;
    }
    if (decoded is! Map) {
      throw const FormatException(
          'Unexpected response format when opening shift.');
    }
    final responseData = Map<String, dynamic>.from(decoded);
    final data = responseData['data'] ?? responseData['shift'];
    final nestedShift = data is Map ? data['shift'] : null;
    final shiftData = nestedShift is Map
        ? Map<String, dynamic>.from(nestedShift)
        : data is Map
        ? Map<String, dynamic>.from(data)
        : responseData;

    final rawShiftId = responseData['shiftId'] ??
        shiftData['shift_id'] ??
        shiftData['shiftId'] ??
        shiftData['id'] ??
        responseData['shift_id'] ??
        responseData['id'];
    final externalId = rawShiftId?.toString().trim();
    if (externalId == null || externalId.isEmpty) {
      throw const FormatException(
        'Shift-open response did not contain a shift ID.',
      );
    }
    final numericShiftId = int.tryParse(externalId);

    final rawTotal = shiftData['total_amount'] ??
        shiftData['opening_cash'] ??
        responseData['total_amount'] ??
        responseData['opening_cash'];
    final totalAmount = rawTotal is num
        ? rawTotal
        : num.tryParse(rawTotal?.toString() ?? '') ?? openingCash;
    final rawOverShort = shiftData['over_short'] ?? responseData['over_short'];
    final overShort = rawOverShort is num
        ? rawOverShort
        : num.tryParse(rawOverShort?.toString() ?? '') ?? 0;

    return ShiftResponse(
      shiftId: numericShiftId ?? 0,
      externalShiftId: numericShiftId == null ? externalId : null,
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

  /// Replays closes made while disconnected before a new authentication is
  /// requested. This releases the server-side open shift/session that would
  /// otherwise produce `session_active_elsewhere` on the next login.
  Future<void> syncPendingRemoteClosures() async {
    if (!await OfflineHelper.isNetworkAvailable()) return;

    final pending = await ShiftDbHelper().getPendingShifts();
    var syncedClosure = false;
    for (final shift in pending) {
      if (shift[AppDBConst.shiftStatus]?.toString() != 'CLOSED') continue;
      final serverId = shift[AppDBConst.shiftServerId]?.toString();
      if (serverId == null || serverId.isEmpty)
        continue; // Locally opened shifts need a server create first.

      final rawPayload = shift['close_payload']?.toString();
      if (rawPayload == null || rawPayload.isEmpty) continue;
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      if (serverId.startsWith('SHIFT-')) {
        final closingCash = num.tryParse(
          (payload['total_amount'] ?? payload['closing_cash_actual'])
              ?.toString() ??
              '',
        ) ??
            0;
        final userData = await UserDbHelper().getUserData();
        await _closeExternalShift(
          serverShiftId: serverId,
          localShiftId: shift[AppDBConst.shiftLocalId] as int,
          closingCash: closingCash,
          cashierName:
          userData?[AppDBConst.userDisplayName]?.toString() ?? 'Cashier',
        );
      } else {
        final numericServerId = int.tryParse(serverId);
        if (numericServerId == null) continue;
        payload['shift_id'] = numericServerId;
        payload['status'] = 'closed';
        final url =
            '${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}';
        await _helper.post(url, payload, true);
      }
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

  Future<ShiftResponse> _manageShiftPayload(
      Map<String, dynamic> payload) async {
    final url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.shifts}${EndUrlConstants.createShiftEndUrl}";

    if (kDebugMode) {
      print("ShiftRepository - SYNC POST URL: $url");
      print("ShiftRepository - SYNC POST Payload: $payload");
    }

    final response = await _helper.post(url, payload, true);

    if (response is String) {
      final responseData = json.decode(response);
      return ShiftResponse.fromJson(responseData);
    } else if (response is Map<String, dynamic>) {
      return ShiftResponse.fromJson(response);
    }
    throw Exception("Unexpected response type in shift sync");
  }

  Future<void> syncPendingShifts() async {
    final String? token = await UserDbHelper().getUserToken();

    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        print(
          '⚠️ [ShiftSync] No auth token available. '
              'Shifts will sync after user logs in online.',
        );
      }
      return;
    }

    final pendingShifts = await _shiftDbHelper.getPendingShifts();

    if (pendingShifts.isEmpty) {
      if (kDebugMode) {
        print('ℹ️ [ShiftSync] No pending offline shifts to sync.');
      }
      return;
    }

    if (kDebugMode) {
      print(
        '🔄 [ShiftSync] Found '
            '${pendingShifts.length} pending shifts to sync.',
      );
    }

    for (final shift in pendingShifts) {
      final int localShiftId =
      int.parse(shift[AppDBConst.shiftLocalId].toString());

      final String shiftStatus =
          shift[AppDBConst.shiftStatus]?.toString() ?? '';

      final String? requestPayloadStr = shift['request_payload'] as String?;

      final String? closePayloadStr = shift['close_payload'] as String?;

      final rawServerShiftId = shift[AppDBConst.shiftServerId];
      Object? serverShiftId =
      rawServerShiftId?.toString().trim().isNotEmpty == true
          ? rawServerShiftId
          : null;

      try {
        // ============================================================
        // CASE 1:
        // OFFLINE SHIFT WAS CREATED WITHOUT SERVER ID
        // OR
        // ONLINE/OFFLINE SHIFT NEEDS SERVER ID
        // ============================================================

        if (serverShiftId == null) {
          if (requestPayloadStr == null || requestPayloadStr.isEmpty) {
            throw Exception(
              'No request payload available for local shift '
                  '$localShiftId',
            );
          }

          final Map<String, dynamic> openPayload = Map<String, dynamic>.from(
            jsonDecode(requestPayloadStr),
          );

          // Never send the local SQLite ID as server shift_id
          openPayload.remove('shift_id');

          openPayload['status'] = TextConstants.open;

          if (kDebugMode) {
            print(
              '📤 [ShiftSync] Creating server shift '
                  'for local shift $localShiftId',
            );
            print(
              '📤 [ShiftSync] OPEN PAYLOAD: $openPayload',
            );
          }

          final ShiftResponse openResponse =
          await _manageShiftPayload(openPayload);

          serverShiftId = openResponse.shiftId;

          if (kDebugMode) {
            print(
              '🎉 [ShiftSync] Server shift created. '
                  'Local=$localShiftId → Server=$serverShiftId',
            );
          }

          // Save server ID locally and cascade it to orders
          await _shiftDbHelper.updateShiftServerIdAndCascade(
            localShiftId: localShiftId,
            serverShiftId: int.parse(serverShiftId.toString()),
          );

          // Keep LOCAL shift ID in UserDB / SharedPreferences
          if (shiftStatus == TextConstants.open) {
            await UserDbHelper().updateUserShiftId(localShiftId);

            final prefs = await SharedPreferences.getInstance();

            await prefs.setInt(
              'active_local_shift_id',
              localShiftId,
            );
          }
        }

        // ============================================================
        // CASE 2:
        // SHIFT WAS CLOSED OFFLINE
        // SERVER SHIFT ALREADY EXISTS
        //
        // Example:
        // Local = 10
        // Server = 125
        // Status = CLOSED
        //
        // We ONLY CLOSE server shift 125.
        // ============================================================

        if (shiftStatus == TextConstants.closed) {
          if (serverShiftId == null) {
            throw Exception(
              'Cannot close local shift $localShiftId because '
                  'serverShiftId is still null.',
            );
          }

          if (closePayloadStr == null || closePayloadStr.isEmpty) {
            throw Exception(
              'No close payload available for '
                  'local shift $localShiftId',
            );
          }

          final Map<String, dynamic> closePayload = Map<String, dynamic>.from(
            jsonDecode(closePayloadStr),
          );

          if (kDebugMode) {
            print(
              '📤 [ShiftSync] Closing server shift '
                  '$serverShiftId '
                  '(Local=$localShiftId)',
            );

            print(
              '📤 [ShiftSync] CLOSE PAYLOAD: $closePayload',
            );
          }

          final ShiftResponse closeResponse;
          final externalServerShiftId = serverShiftId.toString();
          if (externalServerShiftId.startsWith('SHIFT-')) {
            final closingCash = num.tryParse(
              (closePayload['total_amount'] ??
                  closePayload['closing_cash_actual'])
                  ?.toString() ??
                  '',
            ) ??
                0;
            final userData = await UserDbHelper().getUserData();
            closeResponse = await _closeExternalShift(
              serverShiftId: externalServerShiftId,
              localShiftId: localShiftId,
              closingCash: closingCash,
              cashierName: userData?[AppDBConst.userDisplayName]?.toString() ??
                  'Cashier',
            );
          } else {
            closePayload['shift_id'] = serverShiftId;
            closePayload['status'] = TextConstants.closed;
            closeResponse = await _manageShiftPayload(closePayload);
          }

          if (kDebugMode) {
            print(
              '✅ [ShiftSync] CLOSE RESPONSE: '
                  'shiftId=${closeResponse.shiftId}, '
                  'status=${closeResponse.status}, '
                  'overShort=${closeResponse.overShort}',
            );
          }

          // Only mark synced AFTER server close succeeds.
          await _shiftDbHelper.markShiftFullySynced(
            localShiftId,
          );

          if (kDebugMode) {
            print(
              '✅ [ShiftSync] Local shift $localShiftId '
                  'marked SYNCED after successful close.',
            );
          }
        }

        // ============================================================
        // CASE 3:
        // OFFLINE SHIFT WAS OPEN AND HAS NOW BEEN CREATED SERVER-SIDE
        // ============================================================

        else if (shiftStatus == TextConstants.open && serverShiftId != null) {
          await _shiftDbHelper.markShiftFullySynced(
            localShiftId,
          );

          if (kDebugMode) {
            print(
              '✅ [ShiftSync] Local OPEN shift '
                  '$localShiftId marked SYNCED.',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            '❌ [ShiftSync] Failed to sync '
                'local shift $localShiftId: $e',
          );
        }

        if (e.toString().contains('Unauthorised') ||
            e.toString().contains('401') ||
            e.toString().contains('403')) {
          if (kDebugMode) {
            print(
              '⚠️ [ShiftSync] Session expired or unauthorized. '
                  'Stopping shift sync.',
            );
          }
        }

        // Keep PENDING so it can retry later.
        break;
      }
    }
  }
}
