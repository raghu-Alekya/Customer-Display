import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../Database/db_helper.dart';
import '../Database/refund_db_helper.dart';
import '../Helper/offline_helper.dart';
import '../Helper/url_helper.dart';
import '../Repositories/Orders/Full_order_RefundOrderRepository.dart';
import '../Repositories/Orders/partial_order_reund_repository.dart';

class RefundSyncService {
  final RefundDbHelper _refundDbHelper = RefundDbHelper();

  Future<void> syncPendingRefunds() async {
    try {
      final isOnline =
      await OfflineHelper.isNetworkAvailable();

      if (!isOnline) {
        if (kDebugMode) {
          debugPrint(
            '📴 Refund sync skipped - device is offline',
          );
        }
        return;
      }

      final pendingRefunds =
      await _refundDbHelper.getPendingRefunds();

      if (pendingRefunds.isEmpty) {
        if (kDebugMode) {
          debugPrint('✅ No pending refunds to sync');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '🔄 Found ${pendingRefunds.length} pending refunds',
        );
      }

      final fullRepo = RefundOrderRepository(
        baseUrl: UrlHelper.pinakaBaseUrl,
      );

      final partialRepo = PartialRefundRepository(
        baseUrl: UrlHelper.pinakaBaseUrl,
      );

      for (final refund in pendingRefunds) {
        await _syncSingleRefund(
          refund: refund,
          fullRepo: fullRepo,
          partialRepo: partialRepo,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ Refund sync error: $e',
        );
      }
    }
  }

  Future<void> _syncSingleRefund({
    required Map<String, dynamic> refund,
    required RefundOrderRepository fullRepo,
    required PartialRefundRepository partialRepo,
  }) async {
    final localRefundId =
    refund[AppDBConst.refundLocalId]?.toString();

    if (localRefundId == null ||
        localRefundId.isEmpty) {
      return;
    }

    try {
      final orderId = refund[
      AppDBConst.refundOrderId] as int;

      final refundType =
          refund[AppDBConst.refundType]?.toString() ?? '';

      final amount =
          (refund[AppDBConst.refundAmount] as num?)
              ?.toDouble() ??
              0.0;

      final reason =
          refund[AppDBConst.refundReason]?.toString() ??
              'refund';

      final itemsReusable =
          refund[AppDBConst.refundItemsReusable]
              ?.toString() ??
              'yes';

      final itemsJson =
          refund[AppDBConst.refundItems]?.toString() ??
              '[]';

      final List<dynamic> decodedItems =
      jsonDecode(itemsJson);

      final List<Map<String, dynamic>> items =
      decodedItems
          .map(
            (item) =>
        Map<String, dynamic>.from(item),
      )
          .toList();

      // --------------------------------------------------
      // Mark as SYNCING
      // --------------------------------------------------

      await _refundDbHelper.updateRefundStatus(
        localRefundId: localRefundId,
        status: 'SYNCING',
      );

      bool success = false;

      // --------------------------------------------------
      // FULL REFUND
      // --------------------------------------------------

      if (refundType.toLowerCase() == 'full') {
        success = await fullRepo.fullOrderRefund(
          orderId: orderId,
          amount: amount,
          reason: reason,
          itemsReusable: itemsReusable,
        );
      }

      // --------------------------------------------------
      // PARTIAL REFUND
      // --------------------------------------------------

      else if (refundType.toLowerCase() == 'partial') {
        success = await partialRepo.partialOrderRefund(
          orderId: orderId,
          reason: reason,
          itemsReusable: itemsReusable,
          items: items,
        );
      }

      else {
        throw Exception(
          'Unknown refund type: $refundType',
        );
      }

      // --------------------------------------------------
      // SUCCESS
      // --------------------------------------------------

      if (success) {
        // API confirmed refund successfully.
        // Now remove the offline refund from local DB.
        await _refundDbHelper.deleteRefund(
          localRefundId: localRefundId,
        );

        if (kDebugMode) {
          debugPrint(
            '✅ Refund synced successfully '
                'and removed from local DB: $localRefundId',
          );
        }
      }

      // --------------------------------------------------
      // API returned false
      // --------------------------------------------------

      else {
        await _refundDbHelper.updateRefundStatus(
          localRefundId: localRefundId,
          status: 'PENDING_SYNC',
          errorMessage: 'Refund API returned failure',
        );

        if (kDebugMode) {
          debugPrint(
            '⚠️ Refund API failed. Keeping pending: $localRefundId',
          );
        }
      }
    } catch (e) {
      await _refundDbHelper.updateRefundStatus(
        localRefundId: localRefundId,
        status: 'PENDING_SYNC',
        errorMessage: e.toString(),
      );

      if (kDebugMode) {
        debugPrint(
          '🔁 Refund kept pending for retry '
              '$localRefundId: $e',
        );
      }
    }
  }
}