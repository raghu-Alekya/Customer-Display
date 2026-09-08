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
        await db.execute('ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN request_payload TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${AppDBConst.shiftTable} ADD COLUMN close_payload TEXT');
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

  /// CREATE / OPEN SHIFT LOCALLY (Offline-First)
  Future<int> createShiftOffline({
    required int userId,
    required double openingBalance,
    required Map<String, dynamic> requestPayload,
  }) async {
    final db = await _getDb(); // ✅ Auto-creates table if missing
    final now = DateTime.now().toUtc().toIso8601String();

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

    final localShiftId = await db.insert(
      AppDBConst.shiftTable,
      shiftData,
    );

    if (kDebugMode) {
      print('✅ [ShiftDbHelper] Shift created locally with ID: $localShiftId');
    }

    return localShiftId;
  }

  /// CLOSE SHIFT LOCALLY (Offline-First)
  Future<Map<String, dynamic>> closeShiftOffline({
    required int localShiftId,
    required double closingBalance,
    required Map<String, dynamic> closePayload,
  }) async {
    final db = await _getDb(); // ✅ Auto-creates table if missing

    final shift = await db.query(
      AppDBConst.shiftTable,
      where: '${AppDBConst.shiftLocalId} = ?',
      whereArgs: [localShiftId],
      limit: 1,
    );

    if (shift.isEmpty) {
      throw Exception('Shift not found in local database: $localShiftId');
    }

    final openingBalance =
        (shift.first[AppDBConst.shiftOpeningBalance] as num?)?.toDouble() ?? 0.0;
    final totalSales =
        (shift.first[AppDBConst.shiftTotalSalesAmount] as num?)?.toDouble() ?? 0.0;
    final safeDrops =
        (shift.first[AppDBConst.shiftSafeDropTotal] as num?)?.toDouble() ?? 0.0;
    final payouts =
        (shift.first[AppDBConst.shiftVendorPayoutTotal] as num?)?.toDouble() ?? 0.0;

    // Expected cash: Opening + Sales - SafeDrops - Payouts
    final expectedCash = openingBalance + totalSales - safeDrops - payouts;
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
    );
  }

  /// MARK SHIFT AS SYNCED
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
}