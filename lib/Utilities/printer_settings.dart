import 'dart:async';
import 'dart:io';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Database/db_helper.dart';
import 'package:pinaka_pos/Database/printer_db_helper.dart';
import 'package:pinaka_pos/Preferences/pinaka_preferences.dart';
import 'package:pinaka_pos/Utilities/result_utility.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import 'package:thermal_printer/thermal_printer.dart';

class PrinterSettings {
  PrinterSettings() {
    setSelectedPrinterFromDB();
  }

  var _reconnect = false;
  BTStatus _currentStatus = BTStatus.none;

  BluetoothPrinter? selectedPrinter;
  var printerManager = PrinterManager.instance;
  List<int>? pendingTask;
  final PrinterDBHelper _printerDBHelper = PrinterDBHelper();

  static Future<void> openDrawer({BuildContext? context}) async {
    // 1. Try Sunmi internal printer drawer (Broad compatibility for Sunmi devices)
    try {
      await SunmiPrinterPlusPlatform.instance.openDrawer();
    } catch (e) {
      if (kDebugMode) print("Sunmi openDrawer failed: $e");
    }

    // 2. Try Generic ESC/POS command for external printers (USB, Bluetooth, etc.)
    try {
      final printerSettings = PrinterSettings();
      await printerSettings.loadPrinter();
      if (printerSettings.selectedPrinter != null) {
        final profile = await CapabilityProfile.load(name: 'default');
        final generator = Generator(PaperSize.mm80, profile);

        // Send both Pin 2 and Pin 5 commands to cover most cash drawers
        List<int> bytes = generator.drawer(pin: PosDrawer.pin2);
        bytes += generator.drawer(pin: PosDrawer.pin5);

        bool connected = await printerSettings.connectDevice();
        if (connected) {
          printerSettings.printerManager.send(
            type: printerSettings.selectedPrinter!.typePrinter,
            bytes: bytes,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print("Generic openDrawer error: $e");
    }

    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TextConstants.cashDrawerIsOpening),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> loadPrinter() async {
    await setSelectedPrinterFromDB();
  }

  Future<Generator> getTicket() async {
    // Using 'default' instead of 'XP-N160I' for broader compatibility (including Star TSP100 series)
    final profile = await CapabilityProfile.load(name: 'default');
    return Generator(PaperSize.mm80, profile);
  }

  Future<void> saveSelectedPrinterToDB() async {
    if (selectedPrinter != null) {
      await _printerDBHelper.addPrinterToDB(selectedPrinter!);
    }
  }

  Future<void> setSelectedPrinterFromDB() async {
    var printerDB = await _printerDBHelper.getPrinterFromDB();
    if (printerDB.isEmpty) return;

    BluetoothPrinter printer = BluetoothPrinter();
    printer.deviceName = printerDB.first[AppDBConst.printerDeviceName];
    printer.productId = printerDB.first[AppDBConst.printerProductId];
    printer.vendorId = printerDB.first[AppDBConst.printerVendorId];
    printer.address = printerDB.first[AppDBConst.printerProductId] ?? "";
    printer.typePrinter = EnumToString.fromString(
          PrinterType.values,
          printerDB.first[AppDBConst.printerType],
        ) ??
        PrinterType.usb;
    printer.isBle = false;
    _currentStatus =
        (printer.typePrinter == PrinterType.bluetooth && printer.address != "")
            ? BTStatus.connected
            : BTStatus.none;
    selectedPrinter = printer;
  }

  Future<void> selectDevice(BluetoothPrinter device) async {
    if (selectedPrinter != null) {
      if ((device.address != selectedPrinter!.address) ||
          (device.typePrinter == PrinterType.usb &&
              selectedPrinter!.vendorId != device.vendorId)) {
        await PrinterManager.instance.disconnect(
          type: selectedPrinter!.typePrinter,
        );
      }
    }

    selectedPrinter = device;
  }

  Future<bool> connectDevice() async {
    if (selectedPrinter == null) return false;
    switch (selectedPrinter!.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: UsbPrinterInput(
            name: selectedPrinter!.deviceName,
            productId: selectedPrinter!.productId,
            vendorId: selectedPrinter!.vendorId,
          ),
        );
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: BluetoothPrinterInput(
            name: selectedPrinter!.deviceName,
            address: selectedPrinter!.address!,
            isBle: selectedPrinter!.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        break;
      case PrinterType.network:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: TcpPrinterInput(ipAddress: selectedPrinter!.address!),
        );
        break;
    }
    return true;
  }

  Future<Result<BluetoothPrinter>> printTicket(
    List<int> bytes,
    Generator generator,
  ) async {
    if (selectedPrinter == null)
      return Result.error(Exception(TextConstants.noPrinter));

    var bluetoothPrinter = selectedPrinter!;

    switch (bluetoothPrinter.typePrinter) {
      case PrinterType.usb:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: UsbPrinterInput(
            name: bluetoothPrinter.deviceName,
            productId: bluetoothPrinter.productId,
            vendorId: bluetoothPrinter.vendorId,
          ),
        );
        break;
      case PrinterType.bluetooth:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: BluetoothPrinterInput(
            name: bluetoothPrinter.deviceName,
            address: bluetoothPrinter.address!,
            isBle: bluetoothPrinter.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        break;
      case PrinterType.network:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!),
        );
        break;
    }

    // Append Drawer Open commands at the end (Pin 2 and Pin 5)
    // Moving this to the end often fixes issues with Star printers where leading commands
    // might interrupt the print data stream.
    bytes += generator.drawer(pin: PosDrawer.pin2);
    bytes += generator.drawer(pin: PosDrawer.pin5);

    printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);

    // Call Sunmi openDrawer just in case it's a Sunmi device using the platform driver
    try {
      SunmiPrinterPlusPlatform.instance.openDrawer();
    } catch (_) {}

    return Result.ok(bluetoothPrinter);
  }
}

class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;
  String? receiptIconPath;
  String? receiptHeaderText;
  String? receiptFooterText;
  PrinterType typePrinter;
  bool? state;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.state,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.usb,
    this.isBle = false,
    this.receiptIconPath,
    this.receiptHeaderText,
    this.receiptFooterText,
  });
}
