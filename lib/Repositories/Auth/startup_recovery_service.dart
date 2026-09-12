import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../Database/db_helper.dart';
import '../../Database/order_panel_db_helper.dart';
import '../../Helper/url_helper.dart';
import '../../core/api/token_storage.dart';

/// Best-effort startup recovery.
/// It never deletes local orders and never blocks app startup on network errors.
class StartupRecoveryService {
  static Future<void> recover() async {
    try {
      final db = await DBHelper.instance.database;

      final users = await db.query(
        AppDBConst.userTable,
        where:
            '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
        orderBy: '${AppDBConst.userId} DESC',
        limit: 1,
      );

      if (users.isNotEmpty) {
        final user = users.first;
        final token = user[AppDBConst.userToken]?.toString() ?? '';

        if (token.startsWith('OFFLINE_TOKEN_')) {
          if (kDebugMode) print('[StartupRecovery] Offline session preserved.');
        } else if (token.isNotEmpty) {
          await _validateOrRefreshToken(token, user);
        }
      }

      final pending = await db.query(
        AppDBConst.orderTable,
        where:
            '${AppDBConst.orderStatus} = ? OR ${AppDBConst.synced} = 0',
        whereArgs: ['pending_offline'],
        orderBy: '${AppDBConst.orderId} DESC',
        limit: 1,
      );

      if (pending.isNotEmpty) {
        final rawId = pending.first[AppDBConst.orderId];
        final activeId = rawId is num
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '');

        if (activeId != null) {
          OrderHelper().activeOrderId = activeId;
          if (kDebugMode) {
            print('[StartupRecovery] Restored active order: $activeId');
          }
        }
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('[StartupRecovery] Non-fatal recovery error: $e');
        print(s);
      }
    }
  }

  static Future<void> _validateOrRefreshToken(
    String token,
    Map<String, dynamic> user,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) return;

      final validateUri = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}token/validate-token-pin',
      );

      final response = await http.post(
        validateUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'emp_login_pin': ''}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) return;

      if (response.statusCode != 401 && response.statusCode != 403) return;

      final refreshUri = Uri.parse(
        '${UrlHelper.baseUrl}${UrlHelper.pinakaPosV1}auth/refresh_token',
      );

      final refreshResponse = await http.post(
        refreshUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': token}),
      );

      if (refreshResponse.statusCode < 200 ||
          refreshResponse.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(refreshResponse.body);
      String? newToken;

      if (decoded is Map<String, dynamic>) {
        newToken = decoded['token']?.toString() ??
            (decoded['data'] is Map
                ? decoded['data']['token']?.toString()
                : null);
      }

      if (newToken == null || newToken.isEmpty) return;

      final db = await DBHelper.instance.database;
      await db.update(
        AppDBConst.userTable,
        {AppDBConst.userToken: newToken},
        where: '${AppDBConst.userId} = ?',
        whereArgs: [user[AppDBConst.userId]],
      );

      final refreshToken = await TokenStorage().getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await TokenStorage().saveTokens(
          accessToken: newToken,
          refreshToken: refreshToken,
        );
      }

      if (kDebugMode) print('[StartupRecovery] Token refreshed and saved.');
    } catch (e) {
      if (kDebugMode) print('[StartupRecovery] Token recovery skipped: $e');
    }
  }
}
