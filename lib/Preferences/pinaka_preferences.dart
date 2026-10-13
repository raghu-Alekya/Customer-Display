import 'dart:convert';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/thermal_printer.dart';
import '../Constants/text.dart';
import '../Utilities/printer_settings.dart';

<<<<<<< HEAD
class PinakaPreferences { // Build #1.0.7 , Naveen - added PinakaPreferences code
  static late SharedPreferences _prefs;
  static late ValueNotifier<String> layoutSelectionNotifier; //Build #1.0.54: added
=======
class PinakaPreferences {
  // Build #1.0.7 , Naveen - added PinakaPreferences code
  static late SharedPreferences _prefs;
  static late ValueNotifier<String>
  layoutSelectionNotifier; //Build #1.0.54: added
>>>>>>> origin/Grocery_pch_api_integration

  static SharedPreferences get prefs => _prefs;

  static Future<void> prepareSharedPref() async {
    _prefs = await SharedPreferences.getInstance();
<<<<<<< HEAD
    layoutSelectionNotifier =  ValueNotifier<String>('');
  }
=======
    layoutSelectionNotifier = ValueNotifier<String>('');
  }

  static Future<void> clearLoggedInStore() async {
    try {
      await _prefs.remove('storeId');
      await _prefs.remove('storeName');
      await _prefs.remove('storeLogoUrl');
      await _prefs.remove('storeBaseUrl');
    } catch (_) {}
  }

>>>>>>> origin/Grocery_pch_api_integration
  static Future<void> saveLoggedInStore({
    required String storeId,
    required String storeName,
    String? storeLogoUrl,
<<<<<<< HEAD
=======
    String? storeBaseUrl,
>>>>>>> origin/Grocery_pch_api_integration
  }) async {
    await _prefs.setString('storeId', storeId);
    await _prefs.setString('storeName', storeName);
    await _prefs.setString('storeLogoUrl', storeLogoUrl ?? '');
<<<<<<< HEAD
=======
    if (storeBaseUrl != null) {
      await _prefs.setString('storeBaseUrl', storeBaseUrl);
    }
>>>>>>> origin/Grocery_pch_api_integration
  }

  static Map<String, String?> getLoggedInStore() {
    final storeId = _prefs.getString('storeId');
    final storeName = _prefs.getString('storeName');
    final storeLogoUrl = _prefs.getString('storeLogoUrl');
<<<<<<< HEAD
=======
    final storeBaseUrl = _prefs.getString('storeBaseUrl');
>>>>>>> origin/Grocery_pch_api_integration
    if (storeId != null && storeName != null) {
      return {
        'storeId': storeId,
        'storeName': storeName,
        'storeLogoUrl': storeLogoUrl,
<<<<<<< HEAD
=======
        'storeBaseUrl': storeBaseUrl,
>>>>>>> origin/Grocery_pch_api_integration
      };
    }
    return {};
  }

<<<<<<< HEAD
=======
  static Future<void> clearUserPreferences() async {
    // Clear stored store info
    await _prefs.remove('storeId');
    await _prefs.remove('storeName');
    await _prefs.remove('storeLogoUrl');
    await _prefs.remove('storeBaseUrl');

    // Clear layout selection
    layoutSelectionNotifier.value = '';
    await _prefs.remove(SharedPreferenceTextConstants.layoutSelection);

    // Clear selected printer
    await _prefs.remove(SharedPreferenceTextConstants.selectedPrinter);

    // Build #1.0.285: Clear active order state to prevent session cross-talk
    await _prefs.remove('activeOrderId');
    await _prefs.remove('lastActiveOrderId');

    if (kDebugMode) print("#### PinakaPreferences: User preferences cleared");
  }

>>>>>>> origin/Grocery_pch_api_integration
  /// Build #1.0.122: No need , now we are using DB saving code
  // saveThemeMode
  // Future<void> saveAppThemeMode(ThemeMode mode) async {
  //   _prefs.setString(SharedPreferenceTextConstants.themeModeKey, mode.toString() ?? ThemeMode.light.toString() );
  // }
  //
  // // Get ThemeMode from SharedPreferences
  // Future<String?> getSavedAppThemeMode() async { // Build #1.0.9 : By default dark theme getting selected on launch even after changing from settings
  //   return _prefs.getString(SharedPreferenceTextConstants.themeModeKey);
  // }

  //Build #1.0.54: added in PinakaPreferences class
  // Future<void> saveLayoutSelection(String layout) async {
  //   await _prefs.setString(SharedPreferenceTextConstants.layoutSelection, layout);
  //   // Only update notifier if the value has changed
  //   if (layoutSelectionNotifier.value != layout) {
  //     layoutSelectionNotifier.value = layout;
  //   }
  //   if (kDebugMode) {
  //     print("#### PinakaPreferences: Saved layout: $layout");
  //   }
  // }
  //
  // Future<String?> getSavedLayoutSelection() async {
  //   return _prefs.getString(SharedPreferenceTextConstants.layoutSelection) ??
  //       SharedPreferenceTextConstants.navLeftOrderRight;
  // }

  // saveSelectedPrinter
  Future<void> saveSelectedPrinter(BluetoothPrinter selectedPrinter) async {
    Map<String, dynamic> printer = {
<<<<<<< HEAD
      'deviceName':selectedPrinter.deviceName,
      'productId':selectedPrinter.productId,
      'vendorId':selectedPrinter.vendorId,
      'typePrinter': EnumToString.convertToString(selectedPrinter.typePrinter)
    };

    await _prefs.setString(SharedPreferenceTextConstants.selectedPrinter, jsonEncode(printer));
=======
      'deviceName': selectedPrinter.deviceName,
      'productId': selectedPrinter.productId,
      'vendorId': selectedPrinter.vendorId,
      'typePrinter': EnumToString.convertToString(selectedPrinter.typePrinter)
    };

    await _prefs.setString(
        SharedPreferenceTextConstants.selectedPrinter, jsonEncode(printer));
>>>>>>> origin/Grocery_pch_api_integration
  }

  // Get SelectedPrinter from SharedPreferences
  Future<BluetoothPrinter> getSavedSelectedPrinter() async {
    BluetoothPrinter selectedPrinter = BluetoothPrinter();

<<<<<<< HEAD
    String? printerPref = _prefs.getString(SharedPreferenceTextConstants.selectedPrinter);
=======
    String? printerPref =
    _prefs.getString(SharedPreferenceTextConstants.selectedPrinter);
>>>>>>> origin/Grocery_pch_api_integration

    if (kDebugMode) {
      print(" >>>>> Preference getSavedSelectedPrinter $printerPref");
    }
<<<<<<< HEAD
    if(printerPref == null){
      return selectedPrinter;
    }

    Map<String,dynamic> printer = jsonDecode(printerPref) as Map<String, dynamic>;
=======
    if (printerPref == null) {
      return selectedPrinter;
    }

    Map<String, dynamic> printer =
    jsonDecode(printerPref) as Map<String, dynamic>;
>>>>>>> origin/Grocery_pch_api_integration

    selectedPrinter.deviceName = printer['deviceName'];
    selectedPrinter.productId = printer['productId'];
    selectedPrinter.vendorId = printer['vendorId'];
<<<<<<< HEAD
    selectedPrinter.typePrinter = EnumToString.fromString(PrinterType.values, printer['typePrinter']) ?? PrinterType.usb;

    if (kDebugMode) {
      print(" >>>>> Preference getSavedSelectedPrinter selectedPrinter : ${selectedPrinter.deviceName}, ${selectedPrinter.productId}, ${selectedPrinter.vendorId}, ${selectedPrinter.typePrinter}");
    }
    return selectedPrinter;//
  }
=======
    selectedPrinter.typePrinter =
        EnumToString.fromString(PrinterType.values, printer['typePrinter']) ??
            PrinterType.usb;

    if (kDebugMode) {
      print(
          " >>>>> Preference getSavedSelectedPrinter selectedPrinter : ${selectedPrinter.deviceName}, ${selectedPrinter.productId}, ${selectedPrinter.vendorId}, ${selectedPrinter.typePrinter}");
    }
    return selectedPrinter; //
  }


>>>>>>> origin/Grocery_pch_api_integration
}
