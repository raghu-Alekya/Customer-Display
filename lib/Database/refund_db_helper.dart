import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

class RefundDbHelper {

  Future<String> insertOfflineRefund({
    required int orderId,
    required String refundType,
    required double amount,
    required String paymentType,
    required String reason,
    required String itemsReusable,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await DBHelper.instance.database;

    final localRefundId =
        'REF-${DateTime.now().millisecondsSinceEpoch}';

    await db.insert(
      AppDBConst.refundTable,
      {
        AppDBConst.refundLocalId: localRefundId,
        AppDBConst.refundOrderId: orderId,
        AppDBConst.refundType: refundType,
        AppDBConst.refundAmount: amount,
        AppDBConst.refundPaymentType: paymentType,
        AppDBConst.refundReason: reason,
        AppDBConst.refundItemsReusable: itemsReusable,
        AppDBConst.refundItems: jsonEncode(items),
        AppDBConst.refundStatus: 'PENDING_SYNC',
        AppDBConst.refundRetryCount: 0,
        AppDBConst.refundErrorMessage: null,
        AppDBConst.refundCreatedAt:
        DateTime.now().toIso8601String(),
        AppDBConst.refundSyncedAt: null,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return localRefundId;
  }

  /// Get all refunds waiting to be synced.
  Future<List<Map<String, dynamic>>> getPendingRefunds() async {
    final db = await DBHelper.instance.database;

    return await db.query(
      AppDBConst.refundTable,
      where: '''
        ${AppDBConst.refundStatus} = ?
      ''',
      whereArgs: ['PENDING_SYNC'],
      orderBy: '${AppDBConst.refundId} ASC',
    );
  }

  /// Update refund status.
  Future<void> updateRefundStatus({
    required String localRefundId,
    required String status,
    String? errorMessage,
  }) async {
    final db = await DBHelper.instance.database;

    await db.update(
      AppDBConst.refundTable,
      {
        AppDBConst.refundStatus: status,
        AppDBConst.refundErrorMessage: errorMessage,
      },
      where: '''
        ${AppDBConst.refundLocalId} = ?
      ''',
      whereArgs: [localRefundId],
    );
  }

  Future<void> deleteRefund({
    required String localRefundId,
  }) async {
    final db = await DBHelper.instance.database;

    await db.delete(
      AppDBConst.refundTable,
      where: '${AppDBConst.refundLocalId} = ?',
      whereArgs: [localRefundId],
    );
  }

  /// Mark refund as successfully synced.
  Future<void> markRefundSynced({
    required String localRefundId,
  }) async {
    final db = await DBHelper.instance.database;

    await db.update(
      AppDBConst.refundTable,
      {
        AppDBConst.refundStatus: 'SYNCED',
        AppDBConst.refundErrorMessage: null,
        AppDBConst.refundSyncedAt:
        DateTime.now().toIso8601String(),
      },
      where: '''
        ${AppDBConst.refundLocalId} = ?
      ''',
      whereArgs: [localRefundId],
    );
  }



  /// Increase retry count and save error.
  Future<void> markRefundFailed({
    required String localRefundId,
    required String errorMessage,
  }) async {
    final db = await DBHelper.instance.database;

    await db.rawUpdate(
      '''
      UPDATE ${AppDBConst.refundTable}
      SET
        ${AppDBConst.refundStatus} = ?,
        ${AppDBConst.refundRetryCount} =
          ${AppDBConst.refundRetryCount} + 1,
        ${AppDBConst.refundErrorMessage} = ?
      WHERE ${AppDBConst.refundLocalId} = ?
      ''',
      [
        'FAILED',
        errorMessage,
        localRefundId,
      ],
    );
  }

}