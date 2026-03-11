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
      AppDBConst.userShiftId: loginResponse.shiftId, // Build #1.0.149 : Added shift_id
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

  /// Clears user data during logout
  Future<void> logout() async {
    final db = await DBHelper.instance.database;
    await db.delete(AppDBConst.userTable);
    if (kDebugMode) {
      print("#### User data cleared during logout");
    }
  }
}