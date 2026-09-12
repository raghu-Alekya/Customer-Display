// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:sqflite/sqflite.dart';
//
// import '../Constants/text.dart';
// import '../Database/db_helper.dart';
//
// class ShiftDbHelper {
//   static final ShiftDbHelper _instance = ShiftDbHelper._internal();
//
//   factory ShiftDbHelper() => _instance;
//
//   ShiftDbHelper._internal();
//
//   bool _tableChecked = false;
//
//   /// Ensures shift_table exists in SQLite before running any query
//   Future<Database> _getDb() async {
//     final db = await DBHelper.instance.database;
//     if (!_tableChecked) {
//       await _ensureTableExists(db);
//       _tableChecked = true;
//     }
//     return db;
//   }
//
//   Future<void> _ensureTableExists(Database db) async {
//     try {
//       await db.execute('''
//         CREATE TABLE IF NOT EXISTS ${AppDBConst.shiftTable} (
//           ${AppDBConst.shiftLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
//           ${AppDBConst.userId} INTEGER,
//           ${AppDBConst.shiftStartTime} TEXT,
//           ${AppDBConst.shiftEndTime} TEXT,
//           ${AppDBConst.shiftOpeningBalance} REAL,
//           ${AppDBConst.shiftClosingBalance} REAL,
//           ${AppDBConst.shiftTotalSalesAmount} REAL,
//           ${AppDBConst.shiftSafeDropTotal} REAL,
//           ${AppDBConst.shiftVendorPayoutTotal} REAL,
//           ${AppDBConst.shiftOverShort} REAL,
//           ${AppDBConst.shiftStatus} TEXT,
//           ${AppDBConst.shiftSyncStatus} TEXT,
//           ${AppDBConst.shiftServerId} INTEGER,
//           request_payload TEXT,
//           close_payload TEXT,
//           ${AppDBConst.shiftCreatedAt} TEXT,
//           ${AppDBConst.updatedAt} TEXT
//         )
//       ''');
//
//       // Safely add columns in case the table already existed in an earlier run
//       try {
//         await db.execute('ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN request_payload TEXT');
//       } catch (_) {}
//       try {
//         await db.execute('ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN close_payload TEXT');
//       } catch (_) {}
//       // ✅ NEW: human-readable shift identifier (GE-000123 style)
//       try {
//         await db.execute('ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN shift_number TEXT');
//       } catch (_) {}
//
//       if (kDebugMode) {
//         print('✅ [ShiftDbHelper] Table ${AppDBConst.shiftTable} verified/created successfully');
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ [ShiftDbHelper] Error creating shift_table: $e');
//       }
//     }
//   }
//
//   /// ✅ NEW: Generates a stable, unique shift number from the local id.
//   /// Works fully offline since it never depends on server round-trips.
//   String _generateShiftNumber(int localId) =>
//       'GE-${localId.toString().padLeft(6, '0')}';
//
//   /// CREATE / OPEN SHIFT LOCALLY (Offline-First)
//   Future<int> createShiftOffline({
//     required int userId,
//     required double openingBalance,
//     required Map<String, dynamic> requestPayload,
//   }) async {
//     final db = await _getDb(); // ✅ Auto-creates table if missing
//     final now = DateTime.now().toUtc().toIso8601String();
//
//     final shiftData = {
//       AppDBConst.userId: userId,
//       AppDBConst.shiftStartTime: now,
//       AppDBConst.shiftOpeningBalance: openingBalance,
//       AppDBConst.shiftClosingBalance: 0.0,
//       AppDBConst.shiftTotalSalesAmount: 0.0,
//       AppDBConst.shiftSafeDropTotal: 0.0,
//       AppDBConst.shiftVendorPayoutTotal: 0.0,
//       AppDBConst.shiftOverShort: 0.0,
//       AppDBConst.shiftStatus: 'OPEN',
//       AppDBConst.shiftSyncStatus: 'PENDING',
//       'request_payload': jsonEncode(requestPayload),
//       AppDBConst.shiftCreatedAt: now,
//       AppDBConst.updatedAt: now,
//     };
//
//     final localShiftId = await db.insert(
//       AppDBConst.shiftTable,
//       shiftData,
//     );
//
//     // ✅ NEW: assign + persist the GE- shift number now that we have the id
//     final shiftNumber = _generateShiftNumber(localShiftId);
//     await db.update(
//       AppDBConst.shiftTable,
//       {'shift_number': shiftNumber},
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//     );
//
//     if (kDebugMode) {
//       print('✅ [ShiftDbHelper] Shift created locally with ID: $localShiftId');
//       // ---- Added: shift id + amounts snapshot ----
//       print('🧾 [ShiftDbHelper] Shift #$localShiftId | userId=$userId | '
//           'openingBalance=$openingBalance | startTime=$now');
//       // ---------------------------------------------
//       // ✅ NEW
//       print('🔖 [ShiftDbHelper] Shift #$localShiftId → number: $shiftNumber');
//     }
//
//     return localShiftId;
//   }
//
//   /// Keeps an online-created shift in the local ledger too.  The active user
//   /// continues to store the server id (so online operations are unchanged),
//   /// while an offline close can still find the matching local record.
//   Future<int> createOnlineShiftMirror({
//     required int userId,
//     required int serverShiftId,
//     required double openingBalance,
//     required Map<String, dynamic> requestPayload,
//   }) async {
//     final db = await _getDb();
//     final now = DateTime.now().toUtc().toIso8601String();
//
//     final existing = await db.query(
//       AppDBConst.shiftTable,
//       columns: [AppDBConst.shiftLocalId],
//       where: '${AppDBConst.shiftServerId} = ?',
//       whereArgs: [serverShiftId],
//       limit: 1,
//     );
//     if (existing.isNotEmpty) {
//       final existingId = existing.first[AppDBConst.shiftLocalId] as int;
//       if (kDebugMode) {
//         print('🧾 [ShiftDbHelper] Online shift mirror already exists: '
//             'localId=$existingId serverId=$serverShiftId');
//       }
//       return existingId;
//     }
//
//     final localShiftId = await db.insert(AppDBConst.shiftTable, {
//       AppDBConst.userId: userId,
//       AppDBConst.shiftServerId: serverShiftId,
//       AppDBConst.shiftStartTime: now,
//       AppDBConst.shiftOpeningBalance: openingBalance,
//       AppDBConst.shiftClosingBalance: 0.0,
//       AppDBConst.shiftTotalSalesAmount: 0.0,
//       AppDBConst.shiftSafeDropTotal: 0.0,
//       AppDBConst.shiftVendorPayoutTotal: 0.0,
//       AppDBConst.shiftOverShort: 0.0,
//       AppDBConst.shiftStatus: 'OPEN',
//       AppDBConst.shiftSyncStatus: 'SYNCED',
//       'request_payload': jsonEncode(requestPayload),
//       AppDBConst.shiftCreatedAt: now,
//       AppDBConst.updatedAt: now,
//     });
//
//     // ✅ NEW: assign + persist the GE- shift number for the mirrored shift too
//     final shiftNumber = _generateShiftNumber(localShiftId);
//     await db.update(
//       AppDBConst.shiftTable,
//       {'shift_number': shiftNumber},
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//     );
//
//     if (kDebugMode) {
//       // ---- Added: shift id + amounts snapshot ----
//       print('🧾 [ShiftDbHelper] Online shift mirrored | localId=$localShiftId '
//           'serverId=$serverShiftId | openingBalance=$openingBalance');
//       // ---------------------------------------------
//       // ✅ NEW
//       print('🔖 [ShiftDbHelper] Shift #$localShiftId → number: $shiftNumber');
//     }
//
//     return localShiftId;
//   }
//
//   /// CLOSE SHIFT LOCALLY (Offline-First)
//   Future<Map<String, dynamic>> closeShiftOffline({
//     required int localShiftId,
//     required double closingBalance,
//     required Map<String, dynamic> closePayload,
//   }) async {
//     final db = await _getDb(); // ✅ Auto-creates table if missing
//
//     final shift = await db.query(
//       AppDBConst.shiftTable,
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//       limit: 1,
//     );
//
//     if (shift.isEmpty) {
//       throw Exception('Shift not found in local database: $localShiftId');
//     }
//
//     final openingBalance =
//         (shift.first[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0;
//     final totalSales =
//         (shift.first[AppDBConst.shiftTotalSalesAmount] as num?)?.toDouble() ?? 0.0;
//     final safeDrops =
//         (shift.first[AppDBConst.shiftSafeDropTotal] as num?)?.toDouble() ?? 0.0;
//     final payouts =
//         (shift.first[AppDBConst.shiftVendorPayoutTotal] as num?)?.toDouble() ?? 0.0;
//
//     // Expected cash: Opening + Sales - SafeDrops - Payouts
//     final expectedCash = openingBalance + totalSales - safeDrops - payouts;
//     final overShort = closingBalance - expectedCash;
//     final now = DateTime.now().toUtc().toIso8601String();
//
//     await db.update(
//       AppDBConst.shiftTable,
//       {
//         AppDBConst.shiftEndTime: now,
//         AppDBConst.shiftClosingBalance: closingBalance,
//         AppDBConst.shiftOverShort: overShort,
//         AppDBConst.shiftStatus: 'CLOSED',
//         AppDBConst.shiftSyncStatus: 'PENDING',
//         'close_payload': jsonEncode(closePayload),
//         AppDBConst.updatedAt: now,
//       },
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//     );
//
//     if (kDebugMode) {
//       // ---- Added: shift id + order/amount snapshot ----
//       print('🧾 [ShiftDbHelper] Shift #$localShiftId CLOSED | '
//           'openingBalance=$openingBalance | totalSalesAmount=$totalSales | '
//           'safeDropTotal=$safeDrops | vendorPayoutTotal=$payouts | '
//           'closingBalance=$closingBalance | expectedCash=$expectedCash | '
//           'overShort=$overShort | endTime=$now');
//       // ---------------------------------------------------
//       // ✅ NEW: dump every order that fell inside this shift, with amounts
//       await printShiftOrdersSummary(localShiftId);
//     }
//
//     return {
//       'localShiftId': localShiftId,
//       'expectedCash': expectedCash,
//       'overShort': overShort,
//       'status': 'CLOSED',
//     };
//   }
//
//   /// `shiftId` may be either the local id (offline-created shift) or the
//   /// server id (online-created shift). Prefer the server-id match so ids from
//   /// the two systems can never be confused.
//   Future<Map<String, dynamic>> closeShiftByLocalOrServerId({
//     required int shiftId,
//     required int userId,
//     required double closingBalance,
//     required Map<String, dynamic> closePayload,
//   }) async {
//     final db = await _getDb();
//     final serverMatch = await db.query(
//       AppDBConst.shiftTable,
//       columns: [AppDBConst.shiftLocalId],
//       where: '${AppDBConst.shiftServerId} = ? AND ${AppDBConst.shiftStatus} = ?',
//       whereArgs: [shiftId, 'OPEN'],
//       limit: 1,
//     );
//     var localShiftId = serverMatch.isNotEmpty
//         ? serverMatch.first[AppDBConst.shiftLocalId] as int
//         : shiftId;
//
//     // Supports shifts that were opened online before the local mirror was
//     // introduced.  Preserve the close request rather than dropping it just
//     // because the device has no cached opening record.
//     final localMatch = await db.query(
//       AppDBConst.shiftTable,
//       columns: [AppDBConst.shiftLocalId],
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//       limit: 1,
//     );
//     if (serverMatch.isEmpty && localMatch.isEmpty) {
//       localShiftId = await createOnlineShiftMirror(
//         userId: userId,
//         serverShiftId: shiftId,
//         openingBalance: 0.0,
//         requestPayload: const {},
//       );
//     }
//
//     if (kDebugMode) {
//       // ---- Added: which id we resolved to ----
//       print('🧾 [ShiftDbHelper] closeShiftByLocalOrServerId | inputShiftId=$shiftId '
//           '| resolvedLocalShiftId=$localShiftId | closingBalance=$closingBalance');
//       // -----------------------------------------
//     }
//
//     return closeShiftOffline(
//       localShiftId: localShiftId,
//       closingBalance: closingBalance,
//       closePayload: closePayload,
//     );
//   }
//
//   /// GET ACTIVE SHIFT
//   Future<Map<String, dynamic>?> getActiveShift(int userId) async {
//     final db = await _getDb();
//
//     final result = await db.query(
//       AppDBConst.shiftTable,
//       where: '''
//         ${AppDBConst.userId} = ?
//         AND ${AppDBConst.shiftStatus} = ?
//       ''',
//       whereArgs: [userId, 'OPEN'],
//       orderBy: '${AppDBConst.shiftLocalId} DESC',
//       limit: 1,
//     );
//
//     if (result.isNotEmpty) {
//       if (kDebugMode) {
//         // ---- Added: shift id + amounts snapshot ----
//         final row = result.first;
//         print('🧾 [ShiftDbHelper] Active shift for user $userId -> '
//             'id=${row[AppDBConst.shiftLocalId]} | '
//             'shiftNumber=${row['shift_number']} | ' // ✅ NEW
//             'openingBalance=${row[AppDBConst.shiftOpeningBalance]} | '
//             'totalSalesAmount=${row[AppDBConst.shiftTotalSalesAmount]} | '
//             'safeDropTotal=${row[AppDBConst.shiftSafeDropTotal]} | '
//             'vendorPayoutTotal=${row[AppDBConst.shiftVendorPayoutTotal]} | '
//             'startTime=${row[AppDBConst.shiftStartTime]}');
//         // ---------------------------------------------
//       }
//       return result.first;
//     }
//     return null;
//   }
//
//   /// GET SHIFT HISTORY
//   Future<List<Map<String, dynamic>>> getShiftHistory(int userId) async {
//     final db = await _getDb();
//
//     final rows = await db.query(
//       AppDBConst.shiftTable,
//       where: '${AppDBConst.userId} = ?',
//       whereArgs: [userId],
//       orderBy: '${AppDBConst.shiftLocalId} DESC',
//     );
//
//     if (kDebugMode) {
//       // ---- Added: list every shift id + its amounts ----
//       for (final row in rows) {
//         print('🧾 [ShiftDbHelper] History | id=${row[AppDBConst.shiftLocalId]} '
//             '| number=${row['shift_number']} ' // ✅ NEW
//             '| status=${row[AppDBConst.shiftStatus]} '
//             '| totalSalesAmount=${row[AppDBConst.shiftTotalSalesAmount]} '
//             '| closingBalance=${row[AppDBConst.shiftClosingBalance]} '
//             '| overShort=${row[AppDBConst.shiftOverShort]}');
//       }
//       // ----------------------------------------------------
//     }
//
//     return rows;
//   }
//
//   /// GET SINGLE SHIFT
//   Future<Map<String, dynamic>?> getShiftById(int localShiftId) async {
//     final db = await _getDb();
//
//     final result = await db.query(
//       AppDBConst.shiftTable,
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//       limit: 1,
//     );
//
//     if (result.isNotEmpty) {
//       if (kDebugMode) {
//         final row = result.first;
//         print('🧾 [ShiftDbHelper] getShiftById($localShiftId) -> '
//             'number=${row['shift_number']} ' // ✅ NEW
//             '| totalSalesAmount=${row[AppDBConst.shiftTotalSalesAmount]} '
//             '| openingBalance=${row[AppDBConst.shiftOpeningBalance]} '
//             '| closingBalance=${row[AppDBConst.shiftClosingBalance]}');
//       }
//       return result.first;
//     }
//     return null;
//   }
//
//   /// GET PENDING SHIFTS FOR FUTURE PCH SYNC
//   Future<List<Map<String, dynamic>>> getPendingShifts() async {
//     final db = await _getDb();
//
//     return await db.query(
//       AppDBConst.shiftTable,
//       where: '${AppDBConst.shiftSyncStatus} = ?',
//       whereArgs: ['PENDING'],
//     );
//   }
//
//   /// MARK SHIFT AS SYNCED
//   Future<void> markShiftAsSynced(int localShiftId, int pchShiftId) async {
//     final db = await _getDb();
//
//     await db.update(
//       AppDBConst.shiftTable,
//       {
//         AppDBConst.shiftServerId: pchShiftId,
//         AppDBConst.shiftSyncStatus: 'SYNCED',
//         // 🔧 FIX: was DateTime.now().toString() — local time, non-ISO format,
//         // inconsistent with every other timestamp in this table (which use
//         // UTC ISO-8601). That mismatch was the source of the "wrong offline
//         // time" behavior. Now matches the format used everywhere else.
//         AppDBConst.updatedAt: DateTime.now().toUtc().toIso8601String(),
//       },
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//     );
//
//     if (kDebugMode) {
//       print('Shift synced successfully: $localShiftId');
//     }
//   }
//
//   Future<void> markShiftClosureSynced(int localShiftId) async {
//     final db = await _getDb();
//     await db.update(
//       AppDBConst.shiftTable,
//       {
//         AppDBConst.shiftSyncStatus: 'SYNCED',
//         AppDBConst.updatedAt: DateTime.now().toUtc().toIso8601String(),
//       },
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//     );
//   }
//
//   /// ✅ NEW: Look up a shift's GE- number by its local id.
//   Future<String?> getShiftNumber(int localShiftId) async {
//     final db = await _getDb();
//     final row = await db.query(
//       AppDBConst.shiftTable,
//       columns: ['shift_number'],
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//       limit: 1,
//     );
//     if (row.isEmpty) return null;
//     return row.first['shift_number'] as String?;
//   }
//
//   /// ✅ NEW: Prints every order that falls inside this shift's start/end
//   /// window for the shift's user, with per-order amounts, and reconciles
//   /// the sum against the shift's own stored totalSalesAmount.
//   ///
//   /// Note: orders aren't linked to a shift by a foreign key anywhere in the
//   /// schema, so this correlates by userId + time window (start_time/end_time,
//   /// both UTC ISO-8601 — reliable now that markShiftAsSynced's timestamp bug
//   /// is fixed). For an exact link, orders_table would need a shift_id column
//   /// stamped at order-creation time.
//   Future<void> printShiftOrdersSummary(int localShiftId) async {
//     final db = await _getDb();
//
//     final shiftRows = await db.query(
//       AppDBConst.shiftTable,
//       where: '${AppDBConst.shiftLocalId} = ?',
//       whereArgs: [localShiftId],
//       limit: 1,
//     );
//     if (shiftRows.isEmpty) {
//       if (kDebugMode) {
//         print('⚠ [ShiftDbHelper] printShiftOrdersSummary: shift $localShiftId not found');
//       }
//       return;
//     }
//     final shift = shiftRows.first;
//
//     final shiftNumber =
//         shift['shift_number']?.toString() ?? _generateShiftNumber(localShiftId);
//     final userId = shift[AppDBConst.userId] as int?;
//     final startTime = shift[AppDBConst.shiftStartTime]?.toString() ?? '';
//     final endTime = shift[AppDBConst.shiftEndTime]?.toString(); // null while OPEN
//     final shiftTotalSales =
//         (shift[AppDBConst.shiftTotalSalesAmount] as num?)?.toDouble() ?? 0.0;
//
//     List<Map<String, dynamic>> orderRows = [];
//     try {
//       orderRows = await db.query(
//         AppDBConst.orderTable,
//         where: endTime != null
//             ? '${AppDBConst.userId} = ? AND ${AppDBConst.orderDate} >= ? AND ${AppDBConst.orderDate} <= ?'
//             : '${AppDBConst.userId} = ? AND ${AppDBConst.orderDate} >= ?',
//         whereArgs:
//         endTime != null ? [userId, startTime, endTime] : [userId, startTime],
//       );
//     } catch (e) {
//       if (kDebugMode) {
//         print('⚠ [ShiftDbHelper] printShiftOrdersSummary: order query failed: $e');
//       }
//       return;
//     }
//
//     double sumFromOrders = 0.0;
//     if (kDebugMode) {
//       print('🧾🧾 [ShiftDbHelper] ===== Shift $shiftNumber (local #$localShiftId) orders =====');
//       print('   window: $startTime → ${endTime ?? "OPEN"} | userId=$userId');
//     }
//     for (final o in orderRows) {
//       final orderId = o[AppDBConst.orderServerId] ?? o[AppDBConst.orderId];
//       final total = (o[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0;
//       final status = o[AppDBConst.orderStatus];
//       sumFromOrders += total;
//       if (kDebugMode) {
//         print('   ▶ order=$orderId | status=$status | total=$total');
//       }
//     }
//
//     if (kDebugMode) {
//       print('   orders found: ${orderRows.length} | sum=$sumFromOrders | shift.totalSalesAmount=$shiftTotalSales');
//       if ((sumFromOrders - shiftTotalSales).abs() > 0.01) {
//         print('   ⚠ MISMATCH: order sum vs shift total differs by ${(sumFromOrders - shiftTotalSales).abs()}');
//       } else {
//         print('   ✅ order sum matches shift total');
//       }
//       print('🧾🧾 [ShiftDbHelper] ===== end summary =====');
//     }
//   }
//
//   /// CREATE / OPEN SHIFT (Legacy method kept for backwards compatibility)
//   Future<int> createShift({
//     required int userId,
//     required double openingBalance,
//   }) async {
//     return createShiftOffline(
//       userId: userId,
//       openingBalance: openingBalance,
//       requestPayload: {},
//     );
//   }
//
//   /// Closes a shift using either its local SQLite id or its server id.
/// This compatibility method keeps existing repository callers working.
// Future<Map<String, dynamic>> closeShiftByLocalOrServerId({
//   required int shiftId,
//   required int userId,
//   required double closingBalance,
//   required Map<String, dynamic> closePayload,
// }) async {
//   final db = await _getDb();
//   final rows = await db.query(
//     AppDBConst.shiftTable,
//     where: '${AppDBConst.userId} = ? AND (${AppDBConst.shiftLocalId} = ? OR ${AppDBConst.shiftServerId} = ?)',
//     whereArgs: [userId, shiftId, shiftId],
//     limit: 1,
//   );
//   if (rows.isEmpty) {
//     throw Exception('Shift not found locally: $shiftId');
//   }
//   final localId = (rows.first[AppDBConst.shiftLocalId] as num).toInt();
//   return closeShiftOffline(
//     localShiftId: localId,
//     closingBalance: closingBalance,
//     closePayload: closePayload,
//   );
// }

/// CLOSE SHIFT (Legacy method kept for backwards compatibility)
//   Future<void> closeShift({
//     required int localShiftId,
//     required double closingBalance,
//     required double totalSalesAmount,
//     required double safeDropTotal,
//     required double vendorPayoutTotal,
//   }) async {
//     await closeShiftOffline(
//       localShiftId: localShiftId,
//       closingBalance: closingBalance,
//       closePayload: {
//         'totalSalesAmount': totalSalesAmount,
//         'safeDropTotal': safeDropTotal,
//         'vendorPayoutTotal': vendorPayoutTotal,
//       },
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../Constants/text.dart';
import '../Database/db_helper.dart';

class ShiftDbHelper {
  static final ShiftDbHelper _instance = ShiftDbHelper._internal();

  factory ShiftDbHelper() => _instance;

  ShiftDbHelper._internal();

  bool _tableChecked = false;

  /// Ensures shift_table exists in SQLite before running any query
  Future<Database> _getDb() async {
    final db = await DBHelper.instance.database;
    if (!_tableChecked) {
      await _ensureTableExists(db);
      _tableChecked = true;
    }
    return db;
  }

  Future<void> _ensureTableExists(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppDBConst.shiftTable} (
          ${AppDBConst.shiftLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${AppDBConst.userId} INTEGER,
          ${AppDBConst.shiftStartTime} TEXT,
          ${AppDBConst.shiftEndTime} TEXT,
          ${AppDBConst.shiftOpeningBalance} REAL,
          ${AppDBConst.shiftClosingBalance} REAL,
          ${AppDBConst.shiftTotalSalesAmount} REAL,
          ${AppDBConst.shiftSafeDropTotal} REAL,
          ${AppDBConst.shiftVendorPayoutTotal} REAL,
          ${AppDBConst.shiftOverShort} REAL,
          ${AppDBConst.shiftStatus} TEXT,
          ${AppDBConst.shiftSyncStatus} TEXT,
          ${AppDBConst.shiftServerId} INTEGER,
          request_payload TEXT,
          close_payload TEXT,
          ${AppDBConst.shiftCreatedAt} TEXT,
          ${AppDBConst.updatedAt} TEXT
        )
      ''');

      // Safely add columns in case the table already existed in an earlier run
      try {
        await db.execute(
          'ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN request_payload TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN close_payload TEXT',
        );
      } catch (_) {}

      if (kDebugMode) {
        print('✅ [ShiftDbHelper] Table ${AppDBConst.shiftTable} verified/created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [ShiftDbHelper] Error creating shift_table: $e');
      }
    }
  }
  /// CACHE AN ONLINE-CREATED SHIFT LOCALLY
  ///
  /// This is required so an online shift can later be closed while offline.
  Future<int> cacheOnlineShift({
    required int userId,
    required int serverShiftId,
    required double openingBalance,
    required Map<String, dynamic> requestPayload,
  }) async {
    final db = await _getDb();

    final now = DateTime.now().toUtc().toIso8601String();

    // Prevent duplicate local records for the same server shift.
    final existing = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftServerId} = ?',
      whereArgs: [serverShiftId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final localId =
      existing.first[AppDBConst.shiftLocalId] as int;

      if (kDebugMode) {
        print(
          'ℹ️ [ShiftDbHelper] Server shift $serverShiftId '
              'already cached locally as $localId',
        );
      }

      return localId;
    }

    final localShiftId = await db.insert(
      AppDBConst.shiftTable,
      {
        AppDBConst.userId: userId,
        AppDBConst.shiftStartTime: now,
        AppDBConst.shiftOpeningBalance: openingBalance,
        AppDBConst.shiftClosingBalance: 0.0,
        AppDBConst.shiftTotalSalesAmount: 0.0,
        AppDBConst.shiftSafeDropTotal: 0.0,
        AppDBConst.shiftVendorPayoutTotal: 0.0,
        AppDBConst.shiftOverShort: 0.0,

        AppDBConst.shiftStatus: 'OPEN',

        // Open operation already succeeded on the backend.
        AppDBConst.shiftSyncStatus: 'SYNCED',

        // Backend shift ID.
        AppDBConst.shiftServerId: serverShiftId,

        'request_payload': jsonEncode(requestPayload),

        AppDBConst.shiftCreatedAt: now,
        AppDBConst.updatedAt: now,
      },
    );

    if (kDebugMode) {
      print('==========================================');
      print('💾 [ShiftDbHelper] ONLINE SHIFT CACHED');
      print('🆔 Local Shift ID: $localShiftId');
      print('🌐 Server Shift ID: $serverShiftId');
      print('==========================================');
    }

    return localShiftId;
  }
  Future<Map<String, dynamic>?> getShiftByServerId(
      int serverShiftId,
      ) async {
    final db = await _getDb();

    final result = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftServerId} = ?',
      whereArgs: [serverShiftId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      if (kDebugMode) {
        print(
          '🔍 [ShiftDbHelper] Found shift by server ID '
              '$serverShiftId: ${result.first}',
        );
      }

      return result.first;
    }

    if (kDebugMode) {
      print(
        '⚠️ [ShiftDbHelper] No local shift found '
            'for server ID: $serverShiftId',
      );
    }

    return null;
  }

  /// Alias kept for callers (e.g. ShiftRepository.manageShift) that still
  /// reference the older method name. Mirrors an online-opened shift into
  /// the local ledger so it can later be closed while offline.
  Future<int> createOnlineShiftMirror({
    required int userId,
    required int serverShiftId,
    required double openingBalance,
    required Map<String, dynamic> requestPayload,
  }) {
    return cacheOnlineShift(
      userId: userId,
      serverShiftId: serverShiftId,
      openingBalance: openingBalance,
      requestPayload: requestPayload,
    );
  }
  /// CREATE / OPEN SHIFT LOCALLY (Offline-First)
  Future<int> createShiftOffline({
    required int userId,
    required double openingBalance,
    required Map<String, dynamic> requestPayload,
  }) async {
    final db = await _getDb();

    final now = DateTime.now().toUtc().toIso8601String();

    if (kDebugMode) {
      print('\n==========================================');
      print('🗄️ SQLITE CREATE OFFLINE SHIFT');
      print('==========================================');
      print('👤 User ID: $userId');
      print('💰 Opening Balance: $openingBalance');
      print('📅 Created At: $now');
      print('📤 Request Payload: $requestPayload');
    }

    final shiftData = {
      AppDBConst.userId: userId,
      AppDBConst.shiftStartTime: now,
      AppDBConst.shiftOpeningBalance: openingBalance,
      AppDBConst.shiftClosingBalance: 0.0,
      AppDBConst.shiftTotalSalesAmount: 0.0,
      AppDBConst.shiftSafeDropTotal: 0.0,
      AppDBConst.shiftVendorPayoutTotal: 0.0,
      AppDBConst.shiftOverShort: 0.0,
      AppDBConst.shiftStatus: 'OPEN',
      AppDBConst.shiftSyncStatus: 'PENDING',
      'request_payload': jsonEncode(requestPayload),
      AppDBConst.shiftCreatedAt: now,
      AppDBConst.updatedAt: now,
    };

    if (kDebugMode) {
      print('📥 Data being inserted into shift_table:');
      print(shiftData);
    }

    // SQLite INSERT
    final localShiftId = await db.insert(
      AppDBConst.shiftTable,
      shiftData,
    );

    if (kDebugMode) {
      print('==========================================');
      print('🎉 SQLITE INSERT SUCCESS');
      print('🆔 GENERATED LOCAL SHIFT ID: $localShiftId');
      print('==========================================');
    }

    // Verify inserted row
    final insertedRow = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('🔍 INSERTED ROW VERIFICATION:');
      print(insertedRow);

      if (insertedRow.isNotEmpty) {
        print(
          '🆔 Database Local ID: '
              '${insertedRow.first[AppDBConst.shiftLocalId]}',
        );

        print(
          '🌐 Database Server ID: '
              '${insertedRow.first[AppDBConst.shiftServerId]}',
        );

        print(
          '📊 Database Status: '
              '${insertedRow.first[AppDBConst.shiftStatus]}',
        );

        print(
          '🔄 Database Sync Status: '
              '${insertedRow.first[AppDBConst.shiftSyncStatus]}',
        );
      }

      print('==========================================\n');
    }

    return localShiftId;
  }
  Future<void> addRefundToShift({
    required int localShiftId,
    required double refundAmount,
    required String paymentMethod,
  }) async {
    final db = await _getDb();

    if (refundAmount <= 0) {
      return;
    }

    final shift = await getShiftById(localShiftId);

    if (shift == null) {
      throw Exception(
        'Shift not found: $localShiftId',
      );
    }

    final currentTotalRefund =
        (shift['shift_total_refund_amount'] as num?)?.toDouble() ?? 0.0;

    final currentCashRefund =
        (shift['shift_cash_refund_amount'] as num?)?.toDouble() ?? 0.0;

    final currentCardRefund =
        (shift['shift_card_refund_amount'] as num?)?.toDouble() ?? 0.0;

    final currentEbtRefund =
        (shift['shift_ebt_refund_amount'] as num?)?.toDouble() ?? 0.0;

    final currentOtherRefund =
        (shift['shift_other_refund_amount'] as num?)?.toDouble() ?? 0.0;

    double newCashRefund = currentCashRefund;
    double newCardRefund = currentCardRefund;
    double newEbtRefund = currentEbtRefund;
    double newOtherRefund = currentOtherRefund;

    switch (paymentMethod.trim().toLowerCase()) {
      case 'cash':
        newCashRefund += refundAmount;
        break;

      case 'card':
        newCardRefund += refundAmount;
        break;

      case 'ebt':
        newEbtRefund += refundAmount;
        break;

      default:
        newOtherRefund += refundAmount;
        break;
    }

    final newTotalRefund =
        currentTotalRefund + refundAmount;

    final grossSales =
        (shift['shift_gross_sales_amount'] as num?)
            ?.toDouble() ??
            0.0;

    final netSales =
        grossSales - newTotalRefund;

    await db.update(
      AppDBConst.shiftTable,
      {
        'shift_total_refund_amount': newTotalRefund,
        'shift_cash_refund_amount': newCashRefund,
        'shift_card_refund_amount': newCardRefund,
        'shift_ebt_refund_amount': newEbtRefund,
        'shift_other_refund_amount': newOtherRefund,
        'shift_net_sales_amount': netSales,
        AppDBConst.updatedAt:
        DateTime.now().toUtc().toIso8601String(),
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('════════ REFUND ADDED TO SHIFT ════════');
      print('Shift ID: $localShiftId');
      print('Refund Method: $paymentMethod');
      print('Refund Amount: ₹$refundAmount');
      print('Total Refunds: ₹$newTotalRefund');
      print('Net Sales: ₹$netSales');
      print('══════════════ THE END ═════════════════════════');
    }
  }
  Future<void> addSaleToShift({
    required int localShiftId,
    required double saleAmount,
  }) async {
    final db = await _getDb();

    if (saleAmount <= 0) return;

    final shift = await getShiftById(localShiftId);

    if (shift == null) {
      throw Exception(
        'Shift not found: $localShiftId',
      );
    }

    final currentGross =
        (shift['shift_gross_sales_amount'] as num?)
            ?.toDouble() ??
            0.0;

    final totalRefund =
        (shift['shift_total_refund_amount'] as num?)
            ?.toDouble() ??
            0.0;

    final newGross =
        currentGross + saleAmount;

    final newNetSales =
        newGross - totalRefund;

    await db.update(
      AppDBConst.shiftTable,
      {
        'shift_gross_sales_amount': newGross,
        'shift_net_sales_amount': newNetSales,

        // Existing field can represent net sales
        AppDBConst.shiftTotalSalesAmount:
        newNetSales,

        AppDBConst.updatedAt:
        DateTime.now().toUtc().toIso8601String(),
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('════════ SALE ADDED TO SHIFT ════════');
      print('Shift ID: $localShiftId');
      print('Sale: ₹$saleAmount');
      print('Gross Sales: ₹$newGross');
      print('Refunds: ₹$totalRefund');
      print('Net Sales: ₹$newNetSales');
      print('═════════════════════════════════════');
    }
  }
  /// CLOSE SHIFT LOCALLY (Offline-First)
  Future<Map<String, dynamic>> closeShiftOffline({
    required int localShiftId,
    required double closingBalance,
    required Map<String, dynamic> closePayload,
  }) async {
    final db = await _getDb(); // ✅ Auto-creates table if missing

    if (kDebugMode) {
      print('🔍 [OfflineShift] Looking for local shift ID: $localShiftId');
    }
    final shift = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
      limit: 1,
    );
    if (shift.isEmpty) {
      throw Exception(
        'Shift not found using local ID: $localShiftId',
      );
    }
    if (shift.isEmpty) {
      throw Exception('Shift not found in local database: $localShiftId');
    }

    final openingBalance =
        (shift.first[AppDBConst.shiftOpeningBalance] as num?)
            ?.toDouble() ??
            0.0;

    final totalSales =
        (shift.first[AppDBConst.shiftTotalSalesAmount] as num?)
            ?.toDouble() ??
            0.0;

    final safeDrops =
        (shift.first[AppDBConst.shiftSafeDropTotal] as num?)
            ?.toDouble() ??
            0.0;

    final payouts =
        (shift.first[AppDBConst.shiftVendorPayoutTotal] as num?)
            ?.toDouble() ??
            0.0;

// Expected Cash = Opening Balance + Sales - Safe Drops - Payouts
    final expectedCash =
        openingBalance +
            totalSales -
            safeDrops -
            payouts;

    final overShort = closingBalance - expectedCash;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      AppDBConst.shiftTable,
      {
        AppDBConst.shiftEndTime: now,
        AppDBConst.shiftClosingBalance: closingBalance,
        AppDBConst.shiftOverShort: overShort,
        AppDBConst.shiftStatus: 'CLOSED',
        AppDBConst.shiftSyncStatus: 'PENDING',
        'close_payload': jsonEncode(closePayload),
        AppDBConst.updatedAt: now,
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    return {
      'localShiftId': localShiftId,
      'expectedCash': expectedCash,
      'overShort': overShort,
      'status': 'CLOSED',
    };
  }

  /// GET ACTIVE SHIFT
  Future<Map<String, dynamic>?> getActiveShift(int userId) async {
    final db = await _getDb();

    // 1. Try matching with specific userId
    final result = await db.query(
      AppDBConst.shiftTable,
      where: '''
        ${AppDBConst.userId} = ?
        AND ${AppDBConst.shiftStatus} = ?
      ''',
      whereArgs: [userId, 'OPEN'],
      orderBy: '${AppDBConst.shiftLocalId} DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    // 2. Terminal fallback: find ANY currently OPEN shift
    final anyOpenShift = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftStatus} = ?',
      whereArgs: ['OPEN'],
      orderBy: '${AppDBConst.shiftLocalId} DESC',
      limit: 1,
    );

    if (anyOpenShift.isNotEmpty) {
      return anyOpenShift.first;
    }

    return null;
  }

  /// GET SHIFT HISTORY
  Future<List<Map<String, dynamic>>> getShiftHistory(int userId) async {
    final db = await _getDb();

    return await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.userId} = ?',
      whereArgs: [userId],
      orderBy: '${AppDBConst.shiftLocalId} DESC',
    );
  }

  /// GET SINGLE SHIFT
  Future<Map<String, dynamic>?> getShiftById(int localShiftId) async {
    final db = await _getDb();

    final result = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// GET PENDING SHIFTS FOR FUTURE PCH SYNC
  Future<List<Map<String, dynamic>>> getPendingShifts() async {
    final db = await _getDb();

    return await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftSyncStatus} = ?',
      whereArgs: ['PENDING'],
      orderBy: '${AppDBConst.shiftLocalId} ASC',
    );
  }

  /// ✅ 1. MAP LOCAL ID ➔ SERVER ID AND CASCADE UPDATE LOCAL ORDERS
  Future<void> updateShiftServerIdAndCascade({
    required int localShiftId,
    required int serverShiftId,
  }) async {
    final db = await _getDb();

    await db.transaction((txn) async {
      // Update shift table with the authoritative server ID
      await txn.update(
        AppDBConst.shiftTable,
        {
          AppDBConst.shiftServerId: serverShiftId,
          AppDBConst.updatedAt: DateTime.now().toUtc().toIso8601String(),
        },
        where: '${AppDBConst.shiftLocalId} = ?',
        whereArgs: [localShiftId],
      );

      // Cascade map to local orders created during this shift
      try {
        await txn.rawUpdate(
          'UPDATE order_table SET shift_id = ? WHERE shift_id = ?',
          [serverShiftId, localShiftId],
        );
        if (kDebugMode) {
          print('✅ [ID Mapping] Cascaded shiftId $localShiftId ➔ $serverShiftId in order_table');
        }
      } catch (e) {
        if (kDebugMode) {
          print('ℹ️ [ID Mapping] Note on order cascade: $e');
        }
      }
    });
  }

  /// ✅ 2. MARK SHIFT AS FULLY SYNCED
  Future<void> markShiftFullySynced(int localShiftId) async {
    final db = await _getDb();

    await db.update(
      AppDBConst.shiftTable,
      {
        AppDBConst.shiftSyncStatus: 'SYNCED',
        AppDBConst.updatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('🎉 [ShiftDbHelper] Shift $localShiftId marked SYNCED');
    }
  }

  /// MARK SHIFT AS SYNCED (Legacy compatibility)
  Future<void> markShiftAsSynced(int localShiftId, int pchShiftId) async {
    final db = await _getDb();

    await db.update(
      AppDBConst.shiftTable,
      {
        AppDBConst.shiftServerId: pchShiftId,
        AppDBConst.shiftSyncStatus: 'SYNCED',
        AppDBConst.updatedAt: DateTime.now().toString(),
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('Shift synced successfully: $localShiftId');
    }
  }

  /// CREATE / OPEN SHIFT (Legacy method kept for backwards compatibility)
  Future<int> createShift({
    required int userId,
    required double openingBalance,
  }) async {
    return createShiftOffline(
      userId: userId,
      openingBalance: openingBalance,
      requestPayload: {},
    );
  }

  /// CLOSE SHIFT (Legacy method kept for backwards compatibility)
  Future<void> closeShift({
    required int localShiftId,
    required double closingBalance,
    required double totalSalesAmount,
    required double safeDropTotal,
    required double vendorPayoutTotal,
  }) async {
    await closeShiftOffline(
      localShiftId: localShiftId,
      closingBalance: closingBalance,
      closePayload: {
        'totalSalesAmount': totalSalesAmount,
        'safeDropTotal': safeDropTotal,
        'vendorPayoutTotal': vendorPayoutTotal,
      },
    );
  }

  Future<Map<String, dynamic>> closeShiftByLocalOrServerId({
    required int shiftId,
    required int userId,
    required double closingBalance,
    required Map<String, dynamic> closePayload,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.userId} = ? AND (${AppDBConst.shiftLocalId} = ? OR ${AppDBConst.shiftServerId} = ?)',
      whereArgs: [userId, shiftId, shiftId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Shift not found locally: $shiftId');
    }
    final localId = (rows.first[AppDBConst.shiftLocalId] as num).toInt();
    return closeShiftOffline(
      localShiftId: localId,
      closingBalance: closingBalance,
      closePayload: closePayload,
    );
  }

  Future<void> markShiftClosureSynced(int localShiftId) async {
    final db = await _getDb();

    await db.update(
      AppDBConst.shiftTable,
      {
        AppDBConst.shiftSyncStatus: 'SYNCED',
        AppDBConst.updatedAt: DateTime.now().toUtc().toIso8601String(),
      },
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
    );

    if (kDebugMode) {
      print('🎉 [ShiftDbHelper] Shift closure synced: $localShiftId');
    }
  }
}