import 'package:flutter/foundation.dart';

class Misc{
  /// use this feature for testing only, not to be used for release builds
  static bool disablePrinter = kDebugMode ? false : false;
  static bool enableCategoryProductWithSubCategoryList = kDebugMode ? false : false;
  static bool enableEditProductScreen = kDebugMode ? false : false;
  static bool enableDBDelete = kDebugMode ? false : false; //'true' to delete the database during development/testing, in Release pass it as false
  //Build #1.0.189: If we want to disable the back button we should set it to false
  static bool enableHardwareBackButton = kDebugMode ? true : true;
  static bool enableReordering = false; // Build #1.0.204: Added this to control reordering in nested grid items
  static bool showDebugSnackBar = kDebugMode ? false : false; // Build #1.0.254: Disable Toast messages for api success call on every screen
  static bool enableUILogMessages = false; // Build #1.0.256: Enable/disable UI log messages for toast
  printFeatures(){
    if (kDebugMode) {
      print("enableCategoryProductWithSubCategoryList : $enableCategoryProductWithSubCategoryList");
      print("enableDBDelete                           : $enableDBDelete");
      print("enableHardwareBackButton                 : $enableHardwareBackButton");
    }
  }
}