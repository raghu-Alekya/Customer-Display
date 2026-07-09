import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/capability_profile.dart'
    as esc;
import 'package:thermal_printer/esc_pos_utils_platform/src/generator.dart'
    as esc;
import 'package:thermal_printer/esc_pos_utils_platform/src/enums.dart' as esc;
import 'package:thermal_printer/esc_pos_utils_platform/src/pos_column.dart'
    as esc;
import 'package:thermal_printer/esc_pos_utils_platform/src/pos_styles.dart'
    as esc;
import 'package:thermal_printer/thermal_printer.dart';

import '../cart_manger.dart';
import '../repository/store_details_repository.dart';
import '../widgets/printer_settings_screen.dart';

Future<List<int>> buildCashReceiptBytes({
  required String orderType,
  required double subtotal,
  required double tax,
  required double total,
  required int? orderId,
  required String token,
}) async {
  // ✅ 1. Fetch everything FIRST
  final store = await StoreDetailsRepository().getStoreDetails(token: token);

  final prefs = await SharedPreferences.getInstance();

  // ✅ 2. THEN build bytes
  final profile = await esc.CapabilityProfile.load();
  final generator = esc.Generator(esc.PaperSize.mm80, profile);

  final bytes = <int>[];

  bytes.addAll([27, 64]); // reset
  // ================================
  // 🖼 LOGO
  // ================================
  // ================================
  // 🖼 LOGO (CACHE + FALLBACK)
  // ================================
  //     final prefs = await SharedPreferences.getInstance();
  //     final logoBase64 = prefs.getString('store_logo');
  //
  //     img.Image? image;
  //
  // // ✅ 1. Try cached logo
  //     if (logoBase64 != null) {
  //       try {
  //         final bytesImage = base64Decode(logoBase64);
  //         image = img.decodeImage(bytesImage);
  //       } catch (_) {}
  //     }
  //
  // // ✅ 2. Fallback → download if not cached
  //     if (image == null && store.logo.isNotEmpty) {
  //       try {
  //         final response = await http.get(Uri.parse(store.logo));
  //
  //         if (response.statusCode == 200) {
  //           final bytesImage = response.bodyBytes;
  //           image = img.decodeImage(bytesImage);
  //
  //           // 💾 Save to cache for next time
  //           await prefs.setString(
  //             'store_logo',
  //             base64Encode(bytesImage),
  //           );
  //         }
  //       } catch (_) {}
  //     }
  //
  // // ✅ 3. Print logo
  //     if (image != null) {
  //       image = img.grayscale(image);
  //       final resized = img.copyResize(image, width: 200);
  //       // final resized = img.copyResize(image, width: 200);
  //
  //       bytes.addAll(generator.imageRaster(
  //         resized,
  //         align: esc.PosAlign.center,
  //       ));
  //
  //       bytes.addAll(generator.feed(2));
  //     }

  // ✅ TOP HEADER
  bytes.addAll(
    generator.text(
      "  ****CUST_INVOICE****",
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        // bold: true,
        height: esc.PosTextSize.size1,
        width: esc.PosTextSize.size1,
      ),
    ),
  );

  bytes.addAll(generator.feed(1));

  // ================================
  // 🏪 STORE INFO
  // ================================
  bytes.addAll(
    generator.text(
      store.name,
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
        height: esc.PosTextSize.size2,
      ),
    ),
  );
  bytes.addAll(generator.feed(1)); // 1 line space

  bytes.addAll(
    generator.text(
      store.address,
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ),
  );

  bytes.addAll(
    generator.text(
      store.cityLine,
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ),
  );

  bytes.addAll(
    generator.text(
      "Phone: ${store.phoneNumber}",
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ),
  );

  bytes.addAll(generator.hr());

  // ================================
  // 📅 DATE & TIME
  // ================================
  final now = DateTime.now();
  final date = "${now.day}/${now.month}/${now.year}";
  final time = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";

  // ✅ Row 1 → Date & Time
  // Row 1
  // Row 1 → Date + Time
  // Row 1 → Date & Time
  bytes.addAll(
    generator.row([
      esc.PosColumn(text: "Date: $date", width: 8),
      esc.PosColumn(
        text: "Time: $time",
        width: 4,
        // ❌ remove align: right
      ),
    ]),
  );

  // Row 2 → OrderID & Type
  bytes.addAll(
    generator.row([
      esc.PosColumn(text: "OrderID: ${orderId ?? '--'}", width: 8),
      esc.PosColumn(
        text: "Type: ${orderType.toUpperCase()}",
        width: 4,
        // ❌ remove align: right
      ),
    ]),
  );

  bytes.addAll(generator.hr());
  // bytes.addAll(generator.hr());

  // ================================
  // 🧾 ITEM HEADER (80mm)
  // ================================
  bytes.addAll(
    generator.row([
      esc.PosColumn(text: "#", width: 1, styles: esc.PosStyles(bold: true)),
      esc.PosColumn(text: "Item", width: 5, styles: esc.PosStyles(bold: true)),
      esc.PosColumn(
        text: "Qty",
        width: 2,
        styles: esc.PosStyles(align: esc.PosAlign.center, bold: true),
      ),
      esc.PosColumn(
        text: "Rate",
        width: 2,
        styles: esc.PosStyles(align: esc.PosAlign.right, bold: true),
      ),
      esc.PosColumn(
        text: "Amt",
        width: 2,
        styles: esc.PosStyles(align: esc.PosAlign.right, bold: true),
      ),
    ]),
  );

  bytes.addAll(generator.feed(1));

  // ================================
  // 🛒 ITEMS
  // ================================
  int index = 1;

  for (final item in CartManager.cartItems) {
    final product = item['product'];
    final qty = (item['qty'] as num).toInt();

    final addons = (item['addons'] as List);

    final modifiers = item['modifiers'] as List? ?? [];

    final price = double.tryParse(product.price.replaceAll('₹', '')) ?? 0.0;

    final modifierTotal = modifiers.fold<double>(
      0,
      (sum, m) => sum + ((m.price as num).toDouble()),
    );

    final addonTotal = addons.fold<double>(
      0,
      (sum, a) => sum + ((a.price as num).toDouble()),
    );

    final rate = price + modifierTotal + addonTotal;
    final amount = rate * qty;

    // Item Row
    bytes.addAll(
      generator.row([
        esc.PosColumn(text: "${index++}", width: 1),

        esc.PosColumn(text: product.name, width: 5),

        esc.PosColumn(
          text: "$qty",
          width: 2,
          styles: const esc.PosStyles(align: esc.PosAlign.center),
        ),

        esc.PosColumn(
          text: "\$${rate.toStringAsFixed(2).padLeft(5)}",
          width: 2,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),

        esc.PosColumn(
          text: "\$${amount.toStringAsFixed(2).padLeft(5)}",
          width: 2,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),
      ]),
    );

    // Modifier Rows
    for (final m in modifiers) {
      bytes.addAll(generator.row([
        esc.PosColumn(text: " ", width: 1),
        esc.PosColumn(text: "  + ${m.name}", width: 7),
        esc.PosColumn(
          text: "\$${(m.price as num).toStringAsFixed(2).padLeft(5)}",
          width: 2,
          styles: const esc.PosStyles(
            align: esc.PosAlign.right,
          ),
        ),
        esc.PosColumn(text: " ", width: 2),
      ]));
    }

    // Addon Rows
    for (final a in addons) {
      bytes.addAll(generator.row([
        esc.PosColumn(text: " ", width: 1),
        esc.PosColumn(text: "  + ${a.name}", width: 7),
        esc.PosColumn(
          text: "\$${(a.price as num).toStringAsFixed(2).padLeft(5)}",
          width: 2,
          styles: const esc.PosStyles(
            align: esc.PosAlign.right,
          ),
        ),
        esc.PosColumn(text: " ", width: 2),
      ]));
    }

    bytes.addAll(generator.feed(1));
  }

  bytes.addAll(generator.hr());

  // ================================
  // 💰 TOTALS
  // ================================
  bytes.addAll(
    generator.row([
      esc.PosColumn(text: "Sub Total", width: 8),
      esc.PosColumn(
        text: "\$${subtotal.toStringAsFixed(2).padLeft(5)}",
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]),
  );

  bytes.addAll(
    generator.row([
      esc.PosColumn(text: "Tax", width: 8),
      esc.PosColumn(
        text: "\$${tax.toStringAsFixed(2).padLeft(5)}",
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]),
  );

  bytes.addAll(
    generator.row([
      esc.PosColumn(
        text: "NET PAYABLE",
        width: 8,
        styles: const esc.PosStyles(
          bold: true,
          height: esc.PosTextSize.size1, // ✅ smaller
          width: esc.PosTextSize.size1, // ✅ normal width
        ),
      ),
      esc.PosColumn(
        text: "\$${total.toStringAsFixed(2).padLeft(5)}",
        width: 4,
        styles: const esc.PosStyles(
          align: esc.PosAlign.right,
          bold: true,
          height: esc.PosTextSize.size1, // 🔥 keep amount big
          width: esc.PosTextSize.size1,
        ),
      ),
    ]),
  );

  bytes.addAll(generator.hr(ch: '=', linesAfter: 1));

  // ================================
  // 🙏 FOOTER
  // ================================
  bytes.addAll(
    generator.text(
      "Thank you!",
      styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
    ),
  );

  bytes.addAll(generator.feed(5));
  bytes.addAll(generator.cut());

  return bytes;
}

final PrinterManager _printerManager = PrinterManager.instance;

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> printReceiptForSelectedType(
  List<int> bytes,
  BuildContext context,
) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(PrinterPrefsKeys.type) ?? 'bluetooth';
  final appType = AppPrinterTypeExt.fromKey(stored);
  final printerType =
      appType == AppPrinterType.bluetooth
          ? PrinterType.bluetooth
          : PrinterType.usb;
  try {
    final printers = await _discoverDevices(printerType);
    debugPrint('Found ${printers.length} printers:');
    for (final p in printers) {
      final name = p.name.toString();
      final addr = (p.address ?? '').toString();
      debugPrint('- $name ${addr.isNotEmpty ? "[$addr]" : ""}');
    }

    var filtered =
        printers.where((p) {
          switch (appType) {
            case AppPrinterType.bluetooth:
              // Allow all Bluetooth devices with a non-empty address,
              // including Sunmi's InnerPrinter.
              return (p.address ?? '').toString().trim().isNotEmpty;
            case AppPrinterType.usb:
              return true;
          }
        }).toList();

    if (filtered.isEmpty) {
      debugPrint('No ${appType.label} printers found');
      if (!context.mounted) return false;
      _snack(
        context,
        'No ${appType.label} printer found. Open Printer Settings, run Test Print, then try again.',
      );
      return false;
    }

    PrinterDevice device;
    if (appType == AppPrinterType.bluetooth) {
      final savedAddr =
          prefs.getString(PrinterPrefsKeys.btAddress)?.trim() ?? '';
      final savedName = prefs.getString(PrinterPrefsKeys.btName)?.trim() ?? '';

      PrinterDevice? byAddress;
      if (savedAddr.isNotEmpty) {
        for (final p in filtered) {
          if ((p.address ?? '').toString() == savedAddr) {
            byAddress = p;
            break;
          }
        }
      }

      if (byAddress != null) {
        device = byAddress;
      } else if (savedName.isNotEmpty) {
        PrinterDevice? byName;
        for (final p in filtered) {
          if (p.name.toString() == savedName) {
            byName = p;
            break;
          }
        }
        device =
            byName ??
            filtered.firstWhere(
              (p) => p.name.toLowerCase().contains('printer'),
              orElse: () => filtered.first,
            );
      } else {
        // No saved BT printer yet – prefer obvious printer names like "printer".
        device = filtered.firstWhere(
          (p) => p.name.toLowerCase().contains('printer'),
          orElse: () => filtered.first,
        );
      }
    } else {
      final sv = prefs.getString(PrinterPrefsKeys.usbVendor)?.trim() ?? '';
      final sp = prefs.getString(PrinterPrefsKeys.usbProduct)?.trim() ?? '';
      if (sv.isNotEmpty && sp.isNotEmpty) {
        PrinterDevice? match;
        for (final p in filtered) {
          if ('${p.vendorId}' == sv && '${p.productId}' == sp) {
            match = p;
            break;
          }
        }
        device = match ?? filtered.first;
      } else {
        // No saved USB printer yet – prefer obvious printer names like "printer-80".
        device = filtered.firstWhere(
          (p) => p.name.toLowerCase().contains('printer'),
          orElse: () => filtered.first,
        );
      }
    }

    final deviceName = device.name.toString();
    debugPrint('Connecting to: $deviceName [$printerType]');

    final connected =
        printerType == PrinterType.bluetooth
            ? await _printerManager.connect(
              type: PrinterType.bluetooth,
              model: BluetoothPrinterInput(
                name: deviceName,
                address: (device.address ?? '').toString(),
                isBle: false,
                autoConnect: true,
              ),
            )
            : await _printerManager.connect(
              type: PrinterType.usb,
              model: UsbPrinterInput(
                name: deviceName,
                productId: (device.productId ?? '').toString(),
                vendorId: (device.vendorId ?? '').toString(),
              ),
            );
    if (!connected) {
      if (!context.mounted) return false;
      _snack(
        context,
        'Could not connect to printer. Check cable/Bluetooth and settings.',
      );
      return false;
    }

    final sent = await _printerManager.send(type: printerType, bytes: bytes);
    if (!sent) {
      if (!context.mounted) return false;
      _snack(context, 'Printer did not accept the receipt (send failed).');
      return false;
    }
    debugPrint('Print sent');
    return true;
  } catch (e, st) {
    debugPrint('Print error: $e\n$st');
    if (context.mounted) {
      _snack(context, 'Print failed: $e');
    }
    return false;
  } finally {
    try {
      final prefs2 = await SharedPreferences.getInstance();
      final t = AppPrinterTypeExt.fromKey(
        prefs2.getString(PrinterPrefsKeys.type) ?? 'bluetooth',
      );
      final pt =
          t == AppPrinterType.bluetooth
              ? PrinterType.bluetooth
              : PrinterType.usb;
      await Future<void>.delayed(const Duration(seconds: 2));
      await _printerManager.disconnect(
        type: pt,
        delayMs: pt == PrinterType.usb ? 150 : null,
      );
    } catch (_) {}
  }
}

Future<List<PrinterDevice>> _discoverDevices(PrinterType type) async {
  final map = <String, PrinterDevice>{};
  final completer = Completer<List<PrinterDevice>>();
  late final StreamSubscription<PrinterDevice> sub;
  sub = _printerManager.discovery(type: type, isBle: false).listen((device) {
    final key =
        '${device.name}_${device.address ?? ''}_${device.vendorId ?? ''}_${device.productId ?? ''}';
    map[key] = device;
  });
  Timer(const Duration(seconds: 4), () async {
    await sub.cancel();
    if (!completer.isCompleted) {
      completer.complete(map.values.toList(growable: false));
    }
  });
  return completer.future;
}
