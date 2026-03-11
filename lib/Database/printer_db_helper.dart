import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:pinaka_pos/Utilities/printer_settings.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

class PrinterDBHelper {
  static final PrinterDBHelper _instance = PrinterDBHelper._internal();
  factory PrinterDBHelper() => _instance;

  PrinterDBHelper._internal() {
    if (kDebugMode) {
      print("#### FastKeyDBHelper initialized!");
    }
  }

  Future<int> addPrinterToDB(BluetoothPrinter printer) async {
    final db = await DBHelper.instance.database;

    //Build #1.0.279: Code Updated - Could not re add printer device to POS machine in setting-printer setting
    //Clear ALL old printers first
    await db.delete(AppDBConst.printerTable);

    // Then insert the new printer
    final device = await db.insert(AppDBConst.printerTable, {
      AppDBConst.printerDeviceName: printer.deviceName,
      AppDBConst.printerProductId: printer.productId ?? printer.address,
      AppDBConst.printerVendorId: printer.vendorId ?? 'bluetooth',
      AppDBConst.printerType: EnumToString.convertToString(printer.typePrinter),
    });

    if (kDebugMode) {
      print("#### Printer added in DB with deviceName: ${printer.deviceName}");
    }
    return device;
  }

  Future<int> updatePrinterToDB(BluetoothPrinter printer) async {
    final db = await DBHelper.instance.database;
    final int device;
    var printerDB = await getPrinterFromDB();

    if(printerDB.isEmpty) {
      device = await db.insert(AppDBConst.printerTable, {
        AppDBConst.printerDeviceName: printer.deviceName,
        AppDBConst.printerProductId: printer.productId,
        AppDBConst.printerVendorId: printer.vendorId,
        AppDBConst.printerType: EnumToString.convertToString(printer.typePrinter),
        AppDBConst.receiptIconPath: printer.receiptIconPath, //Build #1.0.122 : Added new column's
        AppDBConst.receiptHeaderText: printer.receiptHeaderText,
        AppDBConst.receiptFooterText: printer.receiptFooterText,
      });
    }
    else{
      device = await db.update(AppDBConst.printerTable, {
        AppDBConst.printerDeviceName: printer.deviceName,
        AppDBConst.printerProductId: printer.productId,
        AppDBConst.printerVendorId: printer.vendorId,
        AppDBConst.printerType: EnumToString.convertToString(printer.typePrinter),
        AppDBConst.receiptIconPath: printer.receiptIconPath, //Build #1.0.122 : Added new column's
        AppDBConst.receiptHeaderText: printer.receiptHeaderText,
        AppDBConst.receiptFooterText: printer.receiptFooterText,
      },
        where: '${AppDBConst.printerId} = ?',
        whereArgs: [1],
      );
    }
    if (kDebugMode) {
      print("#### Printer added in DB with deviceName: ${printer.deviceName}");
    }
    return device;
  }

  Future<List<Map<String, dynamic>>> getPrinterFromDB() async {
    final db = await DBHelper.instance.database;
    //Build #1.0.279: Code Updated - Could not re add printer device to POS machine in setting-printer setting
    final printerDevice = await db.query(AppDBConst.printerTable);

    if (kDebugMode) {
      print("#### PrinterDb Retrieved no. of printerDevices = '${printerDevice.length}' from DB");
    }
    if(printerDevice.isNotEmpty){
      if (kDebugMode) {
        print("#### PrinterDb Retrieved printerDevice name: '${printerDevice.first[AppDBConst.printerDeviceName]}' from DB");
      }
    }
    return printerDevice;
  }

/// Build #1.0.122 : Use , If required
// Add receipt settings methods
// Future<void> saveReceiptSettings(Map<String, dynamic> settings) async {
//   final db = await DBHelper.instance.database;
//   final existingPrinter = await getPrinterFromDB();
//   if (existingPrinter.isEmpty) {
//     await db.insert(
//       AppDBConst.printerTable,
//       {
//         AppDBConst.printerId: 1,
//         AppDBConst.printerDeviceName: settings[AppDBConst.printerDeviceName],
//         AppDBConst.receiptIconPath: settings[AppDBConst.receiptIconPath],
//         AppDBConst.receiptHeaderText: settings[AppDBConst.receiptHeaderText],
//         AppDBConst.receivedFooterText: settings[AppDBConst.receivedFooterText],
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   } else {
//     await db.update(
//       AppDBConst.printerTable,
//       {
//         AppDBConst.printerDeviceName: settings[AppDBConst.printerDeviceName],
//         AppDBConst.receiptIconPath: settings[AppDBConst.receiptIconPath],
//         AppDBConst.receiptHeaderText: settings[AppDBConst.receiptHeaderText],
//         AppDBConst.receivedFooterText: settings[AppDBConst.receivedFooterText],
//       },
//       where: '${AppDBConst.printerId} = ?',
//       whereArgs: [1],
//     );
//   }
//   if (kDebugMode) {
//     print("#### Saved receipt settings: $settings");
//   }
// }

// Future<Map<String, dynamic>?> getReceiptSettings() async {
//   final db = await DBHelper.instance.database;
//   List<Map<String, dynamic>> result = await db.query(
//     AppDBConst.printerTable,
//     columns: [
//       AppDBConst.receiptIconPath,
//       AppDBConst.receiptHeaderText,
//       AppDBConst.receivedFooterText
//     ],
//     where: '${AppDBConst.printerId} = ?',
//     whereArgs: [1],
//     limit: 1,
//   );
//   if (kDebugMode) {
//     print("#### Retrieved receipt settings: ${result.isNotEmpty ? result.first : null}");
//   }
//   return result.isNotEmpty ? result.first : null;
// }
}