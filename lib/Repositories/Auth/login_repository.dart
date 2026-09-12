import 'package:flutter/foundation.dart';
import '../../Constants/text.dart';
import '../../Database/assets_db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/api_helper.dart';
import '../../Helper/offline_helper.dart';
import '../../Helper/url_helper.dart';
import '../../Models/Auth/login_model.dart';

class LoginRepository {
  final APIHelper _helper = APIHelper();

  // ─────────────────────────────────────────────────────────────────────────
  // Main login: online path + offline fallback
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> fetchLoginToken(LoginRequest request) async {
    final String url =
        "${UrlHelper.componentVersionUrl}${UrlMethodConstants.token}";

    if (kDebugMode) {
      print("LoginRepository - URL: $url");
      print("LoginRepository - Request: ${request.toJson()}");
    }

    // ── Check connectivity ──────────────────────────────────────────────────
    final isOnline = await OfflineHelper.isNetworkAvailable();

    // Restore the configured store symbol before the login UI continues. This
    // also keeps offline order totals from reverting to the default currency.
    try {
      final currency = await AssetDBHelper.instance.getCurrency();
      final symbol = currency != null && currency.length > 1 ? currency[1] : null;
      if (symbol != null && symbol.trim().isNotEmpty) {
        TextConstants.currencySymbol = symbol;
      }
    } catch (_) {
      // Cached currency is optional and must never block sign-in.
    }

    if (isOnline) {
      // ── ONLINE PATH ────────────────────────────────────────────────────
      try {
        final response = await _helper.post(url, request.toJson(), false);
        // On successful online login, save the PIN hash for future offline use
        await _cacheEmployeePinIfPresent(request);
        return response;
      } catch (e) {
        if (kDebugMode) print("LoginRepository - Online login exception: $e");

        final errStr = e.toString().toLowerCase();
        final isAuthFailure = OfflineHelper.isSessionError(e) ||
            errStr.contains('invalid') ||
            errStr.contains('incorrect') ||
            errStr.contains('unauthorised') ||
            errStr.contains('wrong') ||
            errStr.contains('403') ||
            errStr.contains('401');

        // If the server explicitly rejected the credentials, do not create a fake offline token
        if (isAuthFailure) {
          rethrow;
        }
        // Fall through only for actual network transport failure
      }
    }

    // ── OFFLINE PATH ────────────────────────────────────────────────────────
    if (kDebugMode) print("LoginRepository - Attempting offline PIN validation");

    final pin = request.toJson()['emp_login_pin']?.toString() ?? '';
    final employee = await UserDbHelper().validateOfflinePin(pin);

    if (employee == null) {
      throw Exception(
        isOnline
            ? "Login failed. Please check your PIN and network connection."
            : "Offline login failed: PIN not recognized. Please log in online first to cache your credentials.",
      );
    }

    // Found matching employee: create synthetic offline session
    final userId = int.tryParse(employee['employees_id']?.toString() ?? '0') ?? 0;
    final displayName = employee['employees_display_name']?.toString() ?? 'Cashier';
    final email = employee['employee_email']?.toString() ?? '';

    await UserDbHelper().saveOfflineUserSession(
      userId: userId,
      displayName: displayName,
      email: email,
    );

    if (kDebugMode) {
      print("LoginRepository - Offline session created for: $displayName (id: $userId)");
    }

    // Return a synthetic JSON response matching what the online API would return
    final offlineToken = 'OFFLINE_TOKEN_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    return '{"success":true,"data":{"id":$userId,"displayName":"$displayName","email":"$email","token":"$offlineToken","role":"cashier"}}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // After a successful ONLINE login, save the PIN hash for offline reuse.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _cacheEmployeePinIfPresent(LoginRequest request) async {
    try {
      final pin = request.toJson()['emp_login_pin']?.toString() ?? '';
      if (pin.isEmpty) return;
      final userData = await UserDbHelper().getUserData();
      if (userData == null) return;
      await UserDbHelper().saveEmployeePin(
        employeeId: userData['user_id']?.toString() ?? '',
        displayName: userData['display_name']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        pin: pin,
      );
    } catch (e) {
      if (kDebugMode) print("LoginRepository - Could not cache PIN: $e");
    }
  }
}
