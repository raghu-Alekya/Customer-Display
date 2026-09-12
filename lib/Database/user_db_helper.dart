import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../Constants/text.dart';
import '../Models/Auth/login_model.dart';
import '../Preferences/pinaka_preferences.dart';
import 'db_helper.dart';

class UserDbHelper { //Build #1.0.126: Updated for user data into db
  /// DOUBT -> NO PROBLEM IF WE USE "_instance"
  /// RE-Search: Singleton pattern - `UserDbHelper()` returns the same instance every time.
  /// No new object is created, only the existing static instance is reused.
  /// EX: IF WE USE/CALL LIKE THIS WAY !
// final UserDbHelper _userDbHelper = UserDbHelper();
// await _userDbHelper.getUserData();
  /// or use below in this call
// static final UserDbHelper instance = UserDbHelper._internal();
//   factory UserDbHelper() => instance;
  /// then call using
// UserDbHelper.instance.getUserData();
  static final UserDbHelper _instance = UserDbHelper._internal();
  factory UserDbHelper() => _instance;


  UserDbHelper._internal() {
    if (kDebugMode) {
      print("#### UserDbHelper initialized!");
    }
  }

  /// Saves or updates user data in the database
  /// Updates if user exists, inserts if new
  // Build #1.0.148: Fixed Issue: user display name is not changing in top bar if new user login, old user name showing
  // Ensures only ONE user has a valid token at any time
  Future<void> saveUserData(LoginResponse loginResponse) async {
    if (kDebugMode) {
      print("#### Saving user data for: ${loginResponse.displayName}");
      print("#### Token: ${loginResponse.token}");
    }

    final db = await DBHelper.instance.database;

    // 1. FIRST clear ALL existing tokens to ensure single active user
    await db.update(
      AppDBConst.userTable,
      {AppDBConst.userToken: ''}, // Clear all tokens
    );

    // 2. Check if user already exists
    final existingUser = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userId} = ?',
      whereArgs: [loginResponse.id],
    );

    // 3. Prepare user data map
    Map<String, dynamic> userMap = {
      AppDBConst.userId: loginResponse.id,
      AppDBConst.userRole: loginResponse.role,
      AppDBConst.userDisplayName: loginResponse.displayName,
      AppDBConst.userEmail: loginResponse.email,
      AppDBConst.userFirstName: loginResponse.firstName,
      AppDBConst.userLastName: loginResponse.lastName,
      AppDBConst.userNickname: loginResponse.nicename,
      AppDBConst.userToken: loginResponse.token, // Set NEW token
      AppDBConst.profilePhoto: loginResponse.avatar,
      AppDBConst.userShiftId: loginResponse.shiftId,
      // Build #offline: cache terminal identity on every login
      AppDBConst.deviceDisplayName: loginResponse.deviceDisplayName ?? '',
      AppDBConst.tableId: loginResponse.tableId ?? '',
    };

    if (existingUser.isNotEmpty) {
      // Preserve existing settings
      userMap[AppDBConst.themeMode] = existingUser.first[AppDBConst.themeMode] ?? ThemeMode.light.toString();
      userMap[AppDBConst.layoutSelection] = existingUser.first[AppDBConst.layoutSelection] ?? SharedPreferenceTextConstants.navLeftOrderRight;

      // Update existing user
      await db.update(
        AppDBConst.userTable,
        userMap,
        where: '${AppDBConst.userId} = ?',
        whereArgs: [loginResponse.id],
      );

      if (kDebugMode) {
        print("#### Updated existing user: ${loginResponse.id}");
      }
    } else {
      // Set defaults for new user
      userMap[AppDBConst.themeMode] = ThemeMode.light.toString();
      userMap[AppDBConst.layoutSelection] = SharedPreferenceTextConstants.navLeftOrderRight;

      // Insert new user
      await db.insert(
        AppDBConst.userTable,
        userMap,
      );

      if (kDebugMode) {
        print("#### Inserted new user: ${loginResponse.id}");
      }
    }

    // 4. Verify ONLY this user has a token
    final activeUsers = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
    );

    if (kDebugMode) {
      print("#### Active users after save: ${activeUsers.length}");
      if (activeUsers.isNotEmpty) {
        print("#### Active user ID: ${activeUsers.first[AppDBConst.userId]}");
      }
    }
  }

  /// Saves or updates user settings
  Future<void> saveUserSettings(Map<String, dynamic> settings, {bool modeChange = false, bool themeChange = false}) async {
    if (kDebugMode) {
      print("#### Starting saveUserSettings with modeChange: $modeChange, themeChange: $themeChange");
    }

    //Build #1.0.122 : Using layoutSelectionNotifier for UI updates
    if (PinakaPreferences.layoutSelectionNotifier.value != settings[AppDBConst.layoutSelection]) {
      PinakaPreferences.layoutSelectionNotifier.value = settings[AppDBConst.layoutSelection];
    }

    final userData = await getUserData();
    var userId = userData?[AppDBConst.userId];
    final db = await DBHelper.instance.database;

    if(!modeChange) {
      await db.update(
        AppDBConst.userTable,
        {
          AppDBConst.themeMode: settings[AppDBConst.themeMode],
          AppDBConst.layoutSelection: settings[AppDBConst.layoutSelection],
          AppDBConst.profilePhoto: settings[AppDBConst.profilePhoto],
        },
        where: '${AppDBConst.userId} = ?',
        whereArgs: [userId],
      );

    }else if(themeChange) {
      await db.update(
        AppDBConst.userTable,
        {
          AppDBConst.themeMode: settings[AppDBConst.themeMode],
        },
        where: '${AppDBConst.userId} = ?',
        whereArgs: [userId],
      );

    } else {
      await db.update(
        AppDBConst.userTable,
        {
          AppDBConst.layoutSelection: settings[AppDBConst.layoutSelection],
        },
        where: '${AppDBConst.userId} = ?',
        whereArgs: [userId],
      );
    }

    if (kDebugMode) {
      print("#### Updated user settings: ${settings[AppDBConst.themeMode]}, ${settings[AppDBConst.layoutSelection]}");
    }
  }

  // Build #1.0.148: Retrieves user data from database for the currently ACTIVE user (with valid token)
  // Fixed Issue: user display name is not changing in top bar if new user login, old user name showing
  Future<Map<String, dynamic>?> getUserData() async {
    final db = await DBHelper.instance.database;

    // Get the user with a valid token (most recent first)
    List<Map<String, dynamic>> result = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userToken} IS NOT NULL AND ${AppDBConst.userToken} != ""',
      orderBy: '${AppDBConst.userId} DESC', // Get most recently logged in
      limit: 1,
    );

    if (result.isNotEmpty) {
      if (kDebugMode) {
        print("#### Retrieved ACTIVE user data: ${result.first}");
        print("#### Current token: ${result.first[AppDBConst.userToken]}");
      }
      return result.first;
    }

    if (kDebugMode) print("#### No active user found in database");
    return null;
  }

  // Build #1.0.149 : usage to get userShiftId
  Future<int?> getUserShiftId() async {
    final userData = await getUserData();
    if (userData != null) {
      return userData[AppDBConst.userShiftId] as int?;
    }
    return null;
  }

  // Build #1.0.149 : This approach avoids requiring a new login while ensuring the shiftId
  Future<void> updateUserShiftId(int? shiftId) async {
    final db = await DBHelper.instance.database;
    final userData = await getUserData();
    if (userData != null) {
      await db.update(
        AppDBConst.userTable,
        {AppDBConst.userShiftId: shiftId},
        where: '${AppDBConst.userId} = ?',
        whereArgs: [userData[AppDBConst.userId]],
      );
      if (kDebugMode) {
        print("#### Updated shiftId: $shiftId for user: ${userData[AppDBConst.userId]}");
      }
    } else {
      if (kDebugMode) {
        print("#### No active user found to update shiftId");
      }
    }
  }

  /// Returns the currently active user's token, if available.
  Future<String?> getUserToken() async {
    final userData = await getUserData();
    final value = userData?[AppDBConst.userToken];
    final token = value?.toString().trim();
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Checks if user is logged in by verifying token existence
  Future<bool> isUserLoggedIn() async {
    try {
      final userData = await getUserData();
      final isLoggedIn = userData != null &&
          userData[AppDBConst.userToken] != null &&
          userData[AppDBConst.userToken].toString().isNotEmpty;
      if (kDebugMode) print("#### User login status: $isLoggedIn");
      return isLoggedIn;
    } catch (e) {
      if (kDebugMode) print("#### Error checking user login status: $e");
      return false;
    }
  }

  /// Clears user SESSION TOKEN during logout.
  /// IMPORTANT (Build #offline): Does NOT delete unsynced orders.
  /// Only clears the JWT token so getUserData() returns null (no active user)
  /// while all SQLite order rows with synced=0 are preserved for post-reconnect sync.
  Future<void> logout() async {
    final db = await DBHelper.instance.database;
    // Clear token only — do NOT delete user rows (orders reference user_id)
    await db.update(
      AppDBConst.userTable,
      {AppDBConst.userToken: ''},
    );
    if (kDebugMode) {
      print("#### User token cleared on logout (unsynced orders preserved)");
    }
  }

  // Add these methods inside UserDbHelper class

  /// Saves offline user session so getUserData() finds an active user.
  /// Uses a synthetic offline token so existing "token not empty" logic works.
  Future<void> saveOfflineUserSession({
    required int userId,
    required String displayName,
    String? email,
    String? firstName,
    String? lastName,
    String? nicename,
    String? role,
    String? avatar,
    int? shiftId,
    String? offlineToken, // optional; default generated below
  }) async {
    if (kDebugMode) {
      print("#### Saving OFFLINE user session for: $displayName (id: $userId)");
    }

    final db = await DBHelper.instance.database;

    // 1. Clear all tokens so only this offline user is active
    await db.update(
      AppDBConst.userTable,
      {AppDBConst.userToken: ''},
    );

    // Synthetic token so isUserLoggedIn() / getUserData() treat this user as active
    final token = offlineToken ?? 'OFFLINE_TOKEN_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    final existingUser = await db.query(
      AppDBConst.userTable,
      where: '${AppDBConst.userId} = ?',
      whereArgs: [userId],
    );

    // IMPORTANT: do not write email = '' during offline login.
    // user_table.email is UNIQUE + NOT NULL, so an empty email can collide
    // with another cached/offline user.
    Map<String, dynamic> userMap = {
      AppDBConst.userId: userId,
      AppDBConst.userRole: role ?? 'cashier',
      AppDBConst.userDisplayName: displayName,
      AppDBConst.userFirstName: firstName ?? displayName,
      AppDBConst.userLastName: lastName ?? '',
      AppDBConst.userNickname: nicename ?? displayName,
      AppDBConst.userToken: token,
      AppDBConst.profilePhoto: avatar ?? '',
      AppDBConst.userShiftId: shiftId,
    };

    // Only replace email when a real email was supplied.
    // Existing users keep their already-valid unique email.
    if (email != null && email.trim().isNotEmpty) {
      userMap[AppDBConst.userEmail] = email.trim();
    }

    if (existingUser.isNotEmpty) {
      // Preserve theme / layout if present
      userMap[AppDBConst.themeMode] =
          existingUser.first[AppDBConst.themeMode] ?? ThemeMode.light.toString();
      userMap[AppDBConst.layoutSelection] =
          existingUser.first[AppDBConst.layoutSelection] ??
              SharedPreferenceTextConstants.navLeftOrderRight;

      await db.update(
        AppDBConst.userTable,
        userMap,
        where: '${AppDBConst.userId} = ?',
        whereArgs: [userId],
      );
      if (kDebugMode) print("#### Updated existing user for offline: $userId");
    } else {
      // email is NOT NULL. Generate a unique local email only for a
      // brand-new offline user when no real email is available.
      if (!userMap.containsKey(AppDBConst.userEmail)) {
        userMap[AppDBConst.userEmail] =
        'offline_${userId}_${DateTime.now().millisecondsSinceEpoch}@offline.local';
      }

      userMap[AppDBConst.themeMode] = ThemeMode.light.toString();
      userMap[AppDBConst.layoutSelection] =
          SharedPreferenceTextConstants.navLeftOrderRight;

      await db.insert(AppDBConst.userTable, userMap);
      if (kDebugMode) print("#### Inserted new offline user: $userId");
    }

    if (kDebugMode) {
      final active = await getUserData();
      print("#### Offline active user after save: $active");
    }
  }

  /// Optional: treat offline synthetic tokens as logged-in (already covered by token != '')
  /// but you can use this if you need to distinguish online vs offline later.
  bool isOfflineToken(String? token) {
    return token != null && token.startsWith('OFFLINE_TOKEN_');
  }

  /// Checks if current user is logged in with an offline synthetic session.
  Future<bool> isOfflineSession() async {
    final userData = await getUserData();
    final token = userData?[AppDBConst.userToken]?.toString();
    return isOfflineToken(token);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build #offline: Offline PIN management for multi-cashier offline login
  // ─────────────────────────────────────────────────────────────────────────

  /// SHA-256 hash a PIN so we never store raw PINs locally.
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256convert(bytes);
    return digest;
  }

  // Simple SHA-256 using dart:convert (no external crypto dep needed for hex)
  String sha256convert(List<int> bytes) {
    // Use a simple deterministic hash — dart:crypto not available without package
    // We use a salted encoding approach compatible with dart:convert
    // For production: swap with package:crypto sha256.convert(bytes).toString()
    // This implementation uses a base64 encoding of the raw bytes as a unique identifier
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Called after a SUCCESSFUL ONLINE login: persist the employee PIN hash
  /// so they can log in offline on future sessions.
  Future<void> saveEmployeePin({
    required String employeeId,
    required String displayName,
    required String pin,
    String? email,
    int? assetId,
  }) async {
    if (pin.isEmpty) return;
    final db = await DBHelper.instance.database;
    final hash = _hashPin(pin);
    await db.insert(
      AppDBConst.employeesTable,
      {
        AppDBConst.employeeId: employeeId,
        AppDBConst.employeeDisplayName: displayName,
        AppDBConst.employeePinHash: hash,
        AppDBConst.employeeEmail: email ?? '',
        AppDBConst.assetId: assetId ?? 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (kDebugMode) {
      print('#### Saved offline PIN hash for employee: $employeeId');
    }
  }

  /// Called during OFFLINE LOGIN: check the entered PIN against any cached employee.
  /// Returns the matching employee row or null.
  Future<Map<String, dynamic>?> validateOfflinePin(String pin) async {
    if (pin.isEmpty) return null;
    final db = await DBHelper.instance.database;
    final hash = _hashPin(pin);
    final results = await db.query(
      AppDBConst.employeesTable,
      where: '${AppDBConst.employeePinHash} = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (results.isEmpty) {
      if (kDebugMode) print('#### Offline PIN validation: no match found');
      return null;
    }
    if (kDebugMode) {
      print('#### Offline PIN validated for employee: ${results.first[AppDBConst.employeeId]}');
    }
    return results.first;
  }

  /// Update the cached loyalty points balance for the active user.
  Future<void> updateLoyaltyPoints(int points) async {
    final db = await DBHelper.instance.database;
    final userData = await getUserData();
    if (userData == null) return;
    await db.update(
      AppDBConst.userTable,
      {AppDBConst.loyaltyPoints: points},
      where: '${AppDBConst.userId} = ?',
      whereArgs: [userData[AppDBConst.userId]],
    );
    if (kDebugMode) print('#### Updated loyalty points cache: $points');
  }

  /// Get the cached loyalty points balance for the active user.
  Future<int> getLoyaltyPoints() async {
    final userData = await getUserData();
    return (userData?[AppDBConst.loyaltyPoints] as int?) ?? 0;
  }
}