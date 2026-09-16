import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../Constants/text.dart';
import '../Database/db_helper.dart';
import '../Database/order_panel_db_helper.dart';
import '../Database/storage/storage_provider.dart';
import '../Models/Orders/get_orders_model.dart';
import '../Models/Orders/refund_orderlist_model.dart' as refund_model;
import 'url_helper.dart';


class OfflineHelper {
  // ─────────────────────────────────────────────────────────────────────────────
  // Connectivity
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns true only when a network interface exists AND the configured
  /// store API host can be resolved. This prevents pages from attempting
  /// remote calls when Windows reports Wi-Fi/Ethernet as connected but the
  /// store host is unreachable (for example: Failed host lookup).
  // Keep the connectivity/DNS result briefly. Several widgets can ask for
  // connectivity at the same time when a screen opens. Without this cache,
  // every widget performs its own DNS lookup and offline mode feels slow.
  static bool? _networkCache;
  static DateTime? _networkCacheTime;
  static Future<bool>? _networkCheckInFlight;
  static const Duration _networkCacheDuration = Duration(seconds: 15);
  // Keep this deliberately short. Offline screens should never wait on DNS.
  static const Duration _networkLookupTimeout = Duration(milliseconds: 350);

  // Last known store currency.  This is loaded from the local asset table so
  // offline mode never falls back to the UI default currency (which may be
  // different from the store's configured currency).
  static String? _cachedCurrencyCode;
  static String? _cachedCurrencySymbol;
  static Future<void>? _currencyLoadInFlight;

  /// Restores the last currency configured by the store from SQLite.
  /// This method never performs a network request and is safe to call from
  /// every offline flow.  The value is cached in memory after the first read.
  static Future<void> restoreStoredCurrency({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCurrencySymbol != null &&
        _cachedCurrencySymbol!.trim().isNotEmpty) {
      TextConstants.currencySymbol = _cachedCurrencySymbol!;
      return;
    }

    if (!forceRefresh && _currencyLoadInFlight != null) {
      await _currencyLoadInFlight;
      return;
    }

    final future = _loadStoredCurrency();
    _currencyLoadInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_currencyLoadInFlight, future)) {
        _currencyLoadInFlight = null;
      }
    }
  }

  static Future<void> _loadStoredCurrency() async {
    try {
      final db = await DBHelper.instance.database;
      final rows = await db.query(
        AppDBConst.assetTable,
        columns: [AppDBConst.currency, AppDBConst.currencySymbol],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final code = rows.first[AppDBConst.currency]?.toString().trim();
      final symbol = rows.first[AppDBConst.currencySymbol]?.toString().trim();

      if (code != null && code.isNotEmpty) {
        _cachedCurrencyCode = code;
      }
      if (symbol != null && symbol.isNotEmpty) {
        _cachedCurrencySymbol = symbol;
        TextConstants.currencySymbol = symbol;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineHelper] Could not restore stored currency: $e');
      }
    }
  }

  /// Returns the store's last known currency code while offline.
  static Future<String> getStoredCurrencyCode() async {
    await restoreStoredCurrency();
    return _cachedCurrencyCode ?? 'USD';
  }

  /// Returns the store's last known currency symbol while offline.
  static Future<String> getStoredCurrencySymbol() async {
    await restoreStoredCurrency();
    final symbol = _cachedCurrencySymbol?.trim();
    if (symbol != null && symbol.isNotEmpty) return symbol;
    return TextConstants.currencySymbol;
  }

  /// Clears the in-memory currency cache. Call after a successful asset sync.
  static void invalidateCurrencyCache() {
    _cachedCurrencyCode = null;
    _cachedCurrencySymbol = null;
  }

  /// Updates the in-memory currency after a successful online asset sync.
  static void setStoredCurrency({String? code, String? symbol}) {
    final cleanCode = code?.trim();
    final cleanSymbol = symbol?.trim();
    _cachedCurrencyCode = (cleanCode != null && cleanCode.isNotEmpty) ? cleanCode : null;
    _cachedCurrencySymbol = (cleanSymbol != null && cleanSymbol.isNotEmpty) ? cleanSymbol : null;
    if (_cachedCurrencySymbol != null) {
      TextConstants.currencySymbol = _cachedCurrencySymbol!;
    }
  }

  static Future<bool> isNetworkAvailable({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _networkCache != null &&
        _networkCacheTime != null &&
        now.difference(_networkCacheTime!) < _networkCacheDuration) {
      return _networkCache!;
    }

    // Deduplicate simultaneous connectivity checks.
    if (!forceRefresh && _networkCheckInFlight != null) {
      return _networkCheckInFlight!;
    }

    final future = _checkNetworkAndDns();
    _networkCheckInFlight = future;

    try {
      final result = await future;
      _networkCache = result;
      _networkCacheTime = DateTime.now();
      return result;
    } finally {
      if (identical(_networkCheckInFlight, future)) {
        _networkCheckInFlight = null;
      }
    }
  }

  static Future<bool> _checkNetworkAndDns() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return false;

      final configuredUrl = UrlHelper.wooBaseUrl;
      final host = Uri.tryParse(configuredUrl)?.host;
      if (host == null || host.isEmpty) return false;

      final addresses = await InternetAddress.lookup(host)
          .timeout(_networkLookupTimeout);
      return addresses.isNotEmpty &&
          addresses.any((a) => a.rawAddress.isNotEmpty);
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[OfflineHelper] store host lookup failed: $e');
      return false;
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[OfflineHelper] store host lookup timeout: $e');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineHelper] connectivity check error: $e');
      return false;
    }
  }

  /// Call after login/store URL changes or when the app detects a network
  /// transition. The next request performs one fresh check only.
  static void invalidateNetworkCache() {
    _networkCache = null;
    _networkCacheTime = null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Session / Auth error detection
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns true if [error] is a 401 / expired-token / unauthorized error.
  static bool isSessionError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('jwt') ||
        msg.contains('token expired') ||
        msg.contains('invalid token') ||
        msg.contains('session expired') ||
        msg.contains('rest_forbidden') ||
        msg.contains('rest_not_logged_in');
  }

  /// Returns true if [error] signals the user is NOT in an active shift.
  static bool isShiftError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('shift') ||
        msg.contains('no active shift') ||
        msg.contains('shift not found');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // User-friendly messages (for SnackBar / banner / dialog)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns a friendly offline/error message string for the given [error].
  static String friendlyMessage(dynamic error, {bool isOnline = true}) {
    if (!isOnline) {
      return '📶 You\'re offline. Showing locally saved data.';
    }
    if (isSessionError(error)) {
      return '🔒 Session expired. Please log in again to continue.';
    }
    if (isShiftError(error)) {
      return '⏱ No active shift found. Please open a shift to proceed.';
    }
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return '🌐 Cannot reach server. Working in offline mode.';
    }
    if (msg.contains('TimeoutException')) {
      return '⏳ Server is taking too long. Showing cached data.';
    }
    return '⚠️ Something went wrong. Showing locally saved data.';
  }

  /// Show a non-blocking SnackBar with an offline/error message.
  static void showOfflineSnackBar(
      BuildContext context, {
        required String message,
        Color backgroundColor = const Color(0xFF323232),
        Duration duration = const Duration(seconds: 3),
      }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  /// Show a session-expired dialog with a "Log In Again" button.
  static Future<void> showSessionExpiredDialog(
      BuildContext context, {
        required VoidCallback onRelogin,
      }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Session Expired'),
          ],
        ),
        content: const Text(
          'Your session has expired or you are not authorized.\n\n'
              'Please log in again to continue working.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRelogin();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Log In Again',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Offline data builders: Orders List
  // ─────────────────────────────────────────────────────────────────────────────

  /// Reads orders from SQLite `orders_table` + `purchased_items_table` and
  /// returns an [OrdersListModel] for use when the network is unavailable.
  ///
  /// Filtering mirrors what the server does: [userId], [status], [pageNumber], [pageLimit].
  static Future<OrdersListModel> buildOfflineOrdersListFromDb({
    String userId = '',
    String status = '',
    int pageNumber = 1,
    int pageLimit = 30,
  }) async {
    try {
      // Restore the last store currency before mapping any offline order.
      // This keeps offline order models consistent with the store currency.
      await restoreStoredCurrency();

      final db = await DBHelper.instance.database;

      // Build WHERE clause
      final List<String> whereClauses = [];
      final List<dynamic> whereArgs = [];

      if (userId.isNotEmpty && userId != '0') {
        whereClauses.add('${AppDBConst.userId} = ?');
        whereArgs.add(int.tryParse(userId) ?? 0);
      }
      if (status.isNotEmpty) {
        // Support comma-separated multi-status (e.g. "processing,pending_offline")
        final statuses = status.split(',').map((s) => s.trim()).toList();
        final placeholders = List.filled(statuses.length, '?').join(',');
        whereClauses.add('${AppDBConst.orderStatus} IN ($placeholders)');
        whereArgs.addAll(statuses);
      }

      final String? whereStr =
      whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final offset = (pageNumber - 1) * pageLimit;
      final rows = await db.query(
        AppDBConst.orderTable,
        where: whereStr,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: '${AppDBConst.orderId} DESC',
        limit: pageLimit,
        offset: offset,
      );

      if (kDebugMode) {
        print('[OfflineHelper] buildOfflineOrdersListFromDb: ${rows.length} rows');
      }

      final List<OrderModel> orders = [];
      final Set<int> addedOrderIds = {};

      for (final row in rows) {
        final rawServerId = row[AppDBConst.orderServerId] ?? row['order_id'] ?? row['server_id'];
        final int serverId = rawServerId is num
            ? rawServerId.toInt()
            : int.tryParse(rawServerId?.toString() ?? '') ?? 0;
        final int localId = row[AppDBConst.orderId] as int? ?? 0;
        final int orderId = serverId > 0 ? serverId : localId;

        // Fetch line items for this order matching both localId and serverId
        List<Map<String, dynamic>> itemRows = await db.query(
          AppDBConst.purchasedItemsTable,
          where: '${AppDBConst.orderIdForeignKey} = ? OR ${AppDBConst.orderIdForeignKey} = ? OR ${AppDBConst.itemServerId} = ? OR ${AppDBConst.itemServerId} = ?',
          whereArgs: [localId, orderId, localId, orderId],
        );

        // Fallback to offlineOrders box if SQLite line items are empty
        if (itemRows.isEmpty) {
          try {
            final box = StorageProvider.offlineOrders;
            final dynamic raw = await box.get(orderId.toString()) ??
                (localId > 0 ? await box.get(localId.toString()) : null);
            if (raw is Map) {
              final orderMap = Map<String, dynamic>.from(raw);
              final List products = (orderMap['products'] as List?) ??
                  (orderMap['order_items'] as List?) ?? [];
              for (final p in products) {
                if (p is Map) {
                  final pMap = Map<String, dynamic>.from(p);
                  itemRows.add({
                    AppDBConst.itemServerId: pMap['id'] ?? pMap['server_id'] ?? 0,
                    AppDBConst.itemName: pMap['name'] ?? pMap['item_name'] ?? '',
                    AppDBConst.itemProductId: pMap['product_id'] ?? 0,
                    AppDBConst.itemVariationId: pMap['variation_id'] ?? 0,
                    AppDBConst.itemCount: pMap['quantity'] ?? pMap['items_count'] ?? 1,
                    AppDBConst.itemPrice: pMap['price'] ?? pMap['item_price'] ?? 0.0,
                    AppDBConst.itemSumPrice: pMap['item_sum_price'] ??
                        ((pMap['price'] as num? ?? 0) * (pMap['quantity'] as num? ?? 1)),
                    AppDBConst.itemImage: pMap['image'] ?? pMap['product_image'] ?? '',
                  });
                }
              }
            }
          } catch (_) {}
        }

        // Check if Hive has an updated status for this order (e.g. recently completed)
        var rowCopy = Map<String, dynamic>.from(row);
        try {
          final box = StorageProvider.offlineOrders;
          final dynamic raw = await box.get(orderId.toString()) ??
              (localId > 0 ? await box.get(localId.toString()) : null);
          if (raw is Map && raw['order_status'] != null) {
            final hiveStatus = raw['order_status'].toString();
            if (hiveStatus.isNotEmpty) {
              rowCopy[AppDBConst.orderStatus] = hiveStatus;
            }
          }
        } catch (_) {}

        orders.add(_orderModelFromSqliteRow(rowCopy, itemRows));
        addedOrderIds.add(orderId);
        if (localId > 0) addedOrderIds.add(localId);
      }

      // Supplement with any offline orders in StorageProvider that are not yet in SQLite
      try {
        final box = StorageProvider.offlineOrders;
        final allEntries = await box.toMap();
        for (final raw in allEntries.values) {
          if (raw is Map) {
            final orderMap = Map<String, dynamic>.from(raw);
            final rawId = orderMap['order_id'] ?? orderMap['id'] ?? orderMap[AppDBConst.orderServerId];
            final int offId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '') ?? 0;
            if (offId > 0 && !addedOrderIds.contains(offId)) {
              final List<Map<String, dynamic>> itemRows = [];
              final List products = (orderMap['products'] as List?) ??
                  (orderMap['order_items'] as List?) ?? [];
              for (final p in products) {
                if (p is Map) {
                  final pMap = Map<String, dynamic>.from(p);
                  itemRows.add({
                    AppDBConst.itemServerId: pMap['id'] ?? pMap['server_id'] ?? 0,
                    AppDBConst.itemName: pMap['name'] ?? pMap['item_name'] ?? '',
                    AppDBConst.itemProductId: pMap['product_id'] ?? 0,
                    AppDBConst.itemVariationId: pMap['variation_id'] ?? 0,
                    AppDBConst.itemCount: pMap['quantity'] ?? pMap['items_count'] ?? 1,
                    AppDBConst.itemPrice: pMap['price'] ?? pMap['item_price'] ?? 0.0,
                    AppDBConst.itemSumPrice: pMap['item_sum_price'] ??
                        ((pMap['price'] as num? ?? 0) * (pMap['quantity'] as num? ?? 1)),
                    AppDBConst.itemImage: pMap['image'] ?? pMap['product_image'] ?? '',
                  });
                }
              }

              final row = {
                AppDBConst.orderId: offId,
                AppDBConst.orderServerId: offId,
                AppDBConst.orderStatus: orderMap['order_status']?.toString() ?? 'processing',
                AppDBConst.orderTotal: (orderMap['gross_total'] ?? orderMap['total'] ?? 0.0) as num,
                AppDBConst.orderDate: orderMap['created_at']?.toString() ?? DateTime.now().toString(),
                AppDBConst.orderTime: orderMap['created_at']?.toString() ?? DateTime.now().toString(),
                AppDBConst.orderPaymentMethod: orderMap['payment_method']?.toString() ?? '',
                AppDBConst.userId: orderMap['user_id'] ?? 0,
                AppDBConst.orderDiscount: (orderMap['order_discount'] ?? 0.0) as num,
                AppDBConst.merchantDiscount: (orderMap['merchant_discount'] ?? 0.0) as num,
                AppDBConst.orderTax: (orderMap['order_tax'] ?? orderMap['tax'] ?? 0.0) as num,
              };
              orders.insert(0, _orderModelFromSqliteRow(row, itemRows));
              addedOrderIds.add(offId);
            }
          }
        }
      } catch (_) {}

      return OrdersListModel(orders: orders);
    } catch (e, s) {
      if (kDebugMode) {
        print('[OfflineHelper] buildOfflineOrdersListFromDb error: $e\n$s');
      }
      return OrdersListModel(orders: []);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Offline data builder: Completed / Refundable Orders
  // ─────────────────────────────────────────────────────────────────────────────

  /// Reads completed / pending_offline orders from SQLite for the Refund screen.
  static Future<List<refund_model.CompletedOrder>> buildOfflineCompletedOrdersFromDb({
    int page = 1,
    int perPage = 20,
    int? authorId,
    String? from,
    String? to,
  }) async {
    try {
      // Restore the store currency from local SQLite before mapping offline
      // orders. Never use a hard-coded INR/EUR symbol for offline data.
      await restoreStoredCurrency();

      final db = await DBHelper.instance.database;

      final List<String> whereClauses = [
        'LOWER(${AppDBConst.orderStatus}) IN (?,?,?,?,?,?,?,?,?,?)',
      ];
      final List<dynamic> whereArgs = [
        'completed',
        'wc-completed',
        'processing',
        'wc-processing',
        'pending_offline',
        'wc-pending_offline',
        'pending',
        'wc-pending',
        'refunded',
        'wc-refunded',
      ];

      if (authorId != null && authorId > 0) {
        whereClauses.add('${AppDBConst.userId} = ?');
        whereArgs.add(authorId);
      }
      if (from != null && from.isNotEmpty) {
        whereClauses.add('${AppDBConst.orderDate} >= ?');
        whereArgs.add(from);
      }
      if (to != null && to.isNotEmpty) {
        whereClauses.add('${AppDBConst.orderDate} <= ?');
        whereArgs.add(to);
      }

      final offset = (page - 1) * perPage;
      final rows = await db.query(
        AppDBConst.orderTable,
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        orderBy: '${AppDBConst.orderId} DESC',
        limit: perPage,
        offset: offset,
      );

      if (kDebugMode) {
        print('[OfflineHelper] buildOfflineCompletedOrdersFromDb: ${rows.length} rows');
      }

      final List<refund_model.CompletedOrder> result = [];
      for (final row in rows) {
        final rawServerId = row[AppDBConst.orderServerId] ?? row['order_id'] ?? row['server_id'];
        final int serverId = rawServerId is num
            ? rawServerId.toInt()
            : int.tryParse(rawServerId?.toString() ?? '') ?? 0;
        final int localId = row[AppDBConst.orderId] as int? ?? 0;
        final int orderId = serverId > 0 ? serverId : localId;

        List<Map<String, dynamic>> itemRows = await db.query(
          AppDBConst.purchasedItemsTable,
          where: '${AppDBConst.orderIdForeignKey} = ? OR ${AppDBConst.orderIdForeignKey} = ? OR ${AppDBConst.itemServerId} = ? OR ${AppDBConst.itemServerId} = ?',
          whereArgs: [localId, orderId, localId, orderId],
        );

        if (itemRows.isEmpty) {
          try {
            final box = StorageProvider.offlineOrders;
            final dynamic raw = await box.get(orderId.toString()) ??
                (localId > 0 ? await box.get(localId.toString()) : null);
            if (raw is Map) {
              final orderMap = Map<String, dynamic>.from(raw);
              final List products = (orderMap['products'] as List?) ??
                  (orderMap['order_items'] as List?) ?? [];
              for (final p in products) {
                if (p is Map) {
                  final pMap = Map<String, dynamic>.from(p);
                  itemRows.add({
                    AppDBConst.itemServerId: pMap['id'] ?? pMap['server_id'] ?? 0,
                    AppDBConst.itemName: pMap['name'] ?? pMap['item_name'] ?? '',
                    AppDBConst.itemProductId: pMap['product_id'] ?? 0,
                    AppDBConst.itemVariationId: pMap['variation_id'] ?? 0,
                    AppDBConst.itemCount: pMap['quantity'] ?? pMap['items_count'] ?? 1,
                    AppDBConst.itemPrice: pMap['price'] ?? pMap['item_price'] ?? 0.0,
                    AppDBConst.itemSumPrice: pMap['item_sum_price'] ??
                        ((pMap['price'] as num? ?? 0) * (pMap['quantity'] as num? ?? 1)),
                    AppDBConst.itemImage: pMap['image'] ?? pMap['product_image'] ?? '',
                  });
                }
              }
            }
          } catch (_) {}
        }

        var rowCopy = Map<String, dynamic>.from(row);
        try {
          final box = StorageProvider.offlineOrders;
          final dynamic raw = await box.get(orderId.toString()) ??
              (localId > 0 ? await box.get(localId.toString()) : null);
          if (raw is Map && raw['order_status'] != null) {
            final hiveStatus = raw['order_status'].toString();
            if (hiveStatus.isNotEmpty) {
              rowCopy[AppDBConst.orderStatus] = hiveStatus;
            }
          }
        } catch (_) {}

        result.add(_completedOrderFromSqliteRow(rowCopy, itemRows));
      }

      return result;
    } catch (e, s) {
      if (kDebugMode) {
        print('[OfflineHelper] buildOfflineCompletedOrdersFromDb error: $e\n$s');
      }
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Instant Order Status Update in SQLite & Hive
  // ─────────────────────────────────────────────────────────────────────────────

  /// Instantly updates the order status in both SQLite orders_table and Hive offlineOrders box,
  /// and refreshes OrderPanelDBHelper so the UI reflects the new status immediately.
  static Future<void> updateOfflineOrderStatus(
      int targetOrderId,
      String newStatus, {
        String? paymentMethod,
      }) async {
    try {
      final db = await DBHelper.instance.database;
      final Map<String, dynamic> updateValues = {
        AppDBConst.orderStatus: newStatus,
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        updateValues[AppDBConst.orderPaymentMethod] = paymentMethod;
      }

      // Update SQLite by serverId or local id
      await db.update(
        AppDBConst.orderTable,
        updateValues,
        where: '${AppDBConst.orderServerId} = ? OR ${AppDBConst.orderId} = ?',
        whereArgs: [targetOrderId, targetOrderId],
      );

      // Also update Hive offlineOrders box under all possible keys
      final box = StorageProvider.offlineOrders;
      final String key = targetOrderId.toString();
      final dynamic raw = await box.get(key);
      if (raw is Map) {
        final order = Map<String, dynamic>.from(raw);
        order['order_status'] = newStatus;
        if (paymentMethod != null) order['payment_method'] = paymentMethod;
        order['updated_at'] = DateTime.now().toIso8601String();
        await box.put(key, order);
      }

      // Search all entries in box to update any matching order
      try {
        final allEntries = await box.toMap();
        for (final entry in allEntries.entries) {
          final dynamic v = entry.value;
          if (v is Map) {
            final vid = v['order_id'] ?? v['id'] ?? v[AppDBConst.orderServerId];
            if (vid != null && vid.toString() == targetOrderId.toString()) {
              final order = Map<String, dynamic>.from(v);
              order['order_status'] = newStatus;
              if (paymentMethod != null) order['payment_method'] = paymentMethod;
              order['updated_at'] = DateTime.now().toIso8601String();
              await box.put(entry.key, order);
            }
          }
        }
      } catch (_) {}

      // Refresh OrderHelper in memory
      try {
        await OrderHelper().loadData();
      } catch (_) {}

      if (kDebugMode) {
        print('✅ [OfflineHelper] Order #$targetOrderId updated to $newStatus in SQLite & Hive');
      }
    } catch (e) {
      if (kDebugMode) print('❌ [OfflineHelper] updateOfflineOrderStatus error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Internal mappers: SQLite row → model
  // ─────────────────────────────────────────────────────────────────────────────

  static OrderModel _orderModelFromSqliteRow(
      Map<String, dynamic> row,
      List<Map<String, dynamic>> itemRows,
      ) {
    final rawServerId = row[AppDBConst.orderServerId] ?? row['order_id'] ?? row['server_id'];
    final int serverId = rawServerId is num
        ? rawServerId.toInt()
        : int.tryParse(rawServerId?.toString() ?? '') ?? 0;
    final int localId = row[AppDBConst.orderId] as int? ?? 0;
    final int orderId = serverId > 0 ? serverId : localId;

    final status = row[AppDBConst.orderStatus]?.toString() ?? 'pending_offline';
    final total = (row[AppDBConst.orderTotal] as num?)?.toStringAsFixed(2) ?? '0.00';
    final dateCreated = row[AppDBConst.orderDate]?.toString() ?? '';
    final discount = (row[AppDBConst.orderDiscount] as num?)?.toStringAsFixed(2) ?? '0.00';
    final tax = (row[AppDBConst.orderTax] as num?)?.toStringAsFixed(2) ??
        (row['tax'] as num?)?.toStringAsFixed(2) ?? '0.00';

    final lineItems = itemRows.map((item) => _lineItemFromSqliteRow(item)).toList();

    return OrderModel(
      id: orderId,
      parentId: 0,
      status: status,
      currency: _cachedCurrencyCode ?? 'USD',
      version: '',
      pricesIncludeTax: false,
      dateCreated: dateCreated,
      dateModified: dateCreated,
      discountTotal: discount,
      discountTax: '0.00',
      shippingTotal: '0.00',
      shippingTax: '0.00',
      cartTax: tax,
      total: total,
      totalTax: tax,
      customerId: row[AppDBConst.userId] as int? ?? 0,
      orderKey: '',
      lineItems: lineItems,
      feeLines: [],
      couponLines: [],
      metaData: [],
      datePaid: null,
      dateCompleted: null,
      paymentMethod: row[AppDBConst.orderPaymentMethod]?.toString() ?? '',
      createdVia: 'offline_pos',
      orderType: row[AppDBConst.orderType]?.toString(),
      number: orderId.toString(),
      currencySymbol: _cachedCurrencySymbol ?? TextConstants.currencySymbol,
      multipackDiscountTotal: null,
      autoDiscountTotal: null,
      getTime: row[AppDBConst.orderTime]?.toString(),
      autoDiscountMeta: null,
      orderLevelAutoDiscountAmount:
      (row[AppDBConst.merchantDiscount] as num?)?.toDouble() ?? 0.0,
      refundTotal: 0.0,
      refundOrderTotal: 0.0,
      netPayment: (row[AppDBConst.orderTotal] as num?)?.toDouble() ?? 0.0,
    );
  }

  static LineItem _lineItemFromSqliteRow(Map<String, dynamic> item) {
    final imageSrc = item[AppDBConst.itemImage]?.toString() ?? '';
    final itemPrice = (item[AppDBConst.itemPrice] as num?)?.toDouble() ?? 0.0;
    final itemRegularPrice = (item[AppDBConst.itemRegularPrice] as num?)?.toString() ?? itemPrice.toStringAsFixed(2);
    final itemSalesPrice = (item[AppDBConst.itemSalesPrice] as num?)?.toString() ?? itemPrice.toStringAsFixed(2);

    return LineItem(
      id: item[AppDBConst.itemServerId] as int? ?? 0,
      name: item[AppDBConst.itemName]?.toString() ?? '',
      productId: item[AppDBConst.itemProductId] as int? ?? 0,
      variationId: item[AppDBConst.itemVariationId] as int? ?? 0,
      quantity: item[AppDBConst.itemCount] as int? ?? 1,
      taxClass: '',
      subtotal: (item[AppDBConst.itemPrice] as num?)?.toStringAsFixed(2) ?? '0.00',
      subtotalTax: '0.00',
      total: (item[AppDBConst.itemSumPrice] as num?)?.toStringAsFixed(2) ?? '0.00',
      totalTax: '0.00',
      metaData: [],
      sku: item[AppDBConst.itemSKU]?.toString() ?? '',
      price: itemPrice,
      image: ImageData(id: '0', src: imageSrc),
      productData: ProductData(
        id: item[AppDBConst.itemProductId] as int? ?? 0,
        name: item[AppDBConst.itemName]?.toString() ?? '',
        tags: <Tag>[],
        regularPrice: itemRegularPrice,
        salePrice: itemSalesPrice,
        price: itemPrice.toStringAsFixed(2),
      ),
      isRefundItem: (item['is_refund_item'] as int? ?? 0) == 1,
      multipackDiscountAmount:
      (item[AppDBConst.multipack_discount_total] as num?)?.toDouble() ?? 0.0,
      multipackApplied: ((item[AppDBConst.multipack_discount_total] as num?)?.toDouble() ?? 0.0) > 0,
      autoDiscountAmount:
      (item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0,
      autoDiscountApplied: ((item[AppDBConst.autoDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0,
      comboDiscountAmount:
      (item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0,
      comboDiscountApplied: ((item[AppDBConst.comboDiscountTotal] as num?)?.toDouble() ?? 0.0) > 0,
      displayAutoDiscountAmount:
      (item[AppDBConst.displayAutoDiscount] as num?)?.toDouble() ?? 0.0,
      unitPrice: (item[AppDBConst.itemUnitPrice] as num?)?.toDouble() ?? itemPrice,
    );
  }

  static refund_model.CompletedOrder _completedOrderFromSqliteRow(
      Map<String, dynamic> row,
      List<Map<String, dynamic>> itemRows,
      ) {
    final rawServerId = row[AppDBConst.orderServerId] ?? row['order_id'] ?? row['server_id'];
    final int serverId = rawServerId is num
        ? rawServerId.toInt()
        : int.tryParse(rawServerId?.toString() ?? '') ?? 0;
    final int localId = row[AppDBConst.orderId] as int? ?? 0;
    final int orderId = serverId > 0 ? serverId : localId;

    final total = (row[AppDBConst.orderTotal] as num?)?.toDouble() ??
        (row['total'] as num?)?.toDouble() ??
        (row['gross_total'] as num?)?.toDouble() ?? 0.0;
    final discount = (row[AppDBConst.orderDiscount] as num?)?.toDouble() ??
        (row['discount'] as num?)?.toDouble() ?? 0.0;
    final tax = (row[AppDBConst.orderTax] as num?)?.toDouble() ??
        (row['tax'] as num?)?.toDouble() ?? 0.0;
    final dateStr = row[AppDBConst.orderDate]?.toString() ?? row['created_at']?.toString() ?? '';
    final completedAt = DateTime.tryParse(dateStr) ?? DateTime.now();

    final items = itemRows
        .map((item) {
      final double itemPrice = (item[AppDBConst.itemPrice] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          (item['item_price'] as num?)?.toDouble() ?? 0.0;
      final int qty = (item[AppDBConst.itemCount] as num?)?.toInt() ??
          (item['quantity'] as num?)?.toInt() ??
          (item['items_count'] as num?)?.toInt() ?? 1;
      final double sumPrice = (item[AppDBConst.itemSumPrice] as num?)?.toDouble() ??
          (item['item_sum_price'] as num?)?.toDouble() ??
          (item['total'] as num?)?.toDouble() ?? (itemPrice * (qty > 0 ? qty : 1));
      final int lineItemId = (item[AppDBConst.itemServerId] as num?)?.toInt() ??
          (item[AppDBConst.itemId] as num?)?.toInt() ??
          (item['id'] as num?)?.toInt() ?? 0;
      final String rawName = item[AppDBConst.itemName]?.toString() ??
          item['name']?.toString() ?? item['item_name']?.toString() ?? 'Item';

      return refund_model.LineItem(
        id: lineItemId,
        name: rawName.isNotEmpty ? rawName : 'Item',
        productId: (item[AppDBConst.itemProductId] as num?)?.toInt() ??
            (item['product_id'] as num?)?.toInt() ?? 0,
        quantity: qty > 0 ? qty : 1,
        total: sumPrice > 0 ? sumPrice : (itemPrice * (qty > 0 ? qty : 1)),
        image: item[AppDBConst.itemImage]?.toString() ?? item['image']?.toString() ?? '',
        totalTax: (item['total_tax'] as num?)?.toDouble() ?? 0.0,
        isItemsHasDiscount: 'No',
        itemDiscountType: '',
      );
    })
        .toList();

    return refund_model.CompletedOrder(
      orderId: orderId,
      status: row[AppDBConst.orderStatus]?.toString() ?? 'pending_offline',
      completedAt: completedAt,
      paymentMethod: row[AppDBConst.orderPaymentMethod]?.toString() ?? '',
      orderType: row[AppDBConst.orderType]?.toString() ?? '',
      transactionId: '',
      amount: total,
      discount: discount,
      tax: tax,
      total: total,
      author: (row[AppDBConst.userId] as num?)?.toInt(),
      items: items,
      coupons: [],
      payments: [],
    );
  }
}