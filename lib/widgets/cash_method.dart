import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:keyos_app/Homescreen.dart';
import 'package:keyos_app/cart_manger.dart';
import 'package:keyos_app/widgets/kiosk_header_widgets.dart';
import 'package:keyos_app/widgets/printer_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repository/store_details_repository.dart';
import 'cash_receipt.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' as esc;
import 'package:thermal_printer/thermal_printer.dart';
import 'package:image/image.dart' as img;

class CashMethodScreen extends StatefulWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;
  final int? orderId;

  const CashMethodScreen({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.orderId,
  });

  @override
  State<CashMethodScreen> createState() => _CashMethodScreenState();
}

class _CashMethodScreenState extends State<CashMethodScreen> {
  bool _isPrinting = false;

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  int get _itemCount {
    return CartManager.cartItems.fold<int>(0, (sum, item) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      return sum + qty;
    });
  }
  // Future<List<int>> buildCashReceiptBytes({
  //   required String orderType,
  //   required double subtotal,
  //   required double tax,
  //   required double total,
  //   required int? orderId,
  // }) async {
  //   final profile = await esc.CapabilityProfile.load();
  //   final generator = esc.Generator(esc.PaperSize.mm80, profile);
  //   final bytes = <int>[];
  //   // Header
  //   bytes.addAll(generator.text(
  //     'Kiosk',
  //     styles: const esc.PosStyles(
  //       align: esc.PosAlign.center,
  //       bold: true,
  //       height: esc.PosTextSize.size2,
  //       width: esc.PosTextSize.size2,
  //     ),
  //   ));
  //   bytes.addAll(generator.text(
  //     'Order: ${orderId ?? '--'}',
  //     styles: const esc.PosStyles(align: esc.PosAlign.center),
  //   ));
  //   bytes.addAll(generator.text(
  //     orderType,
  //     styles: const esc.PosStyles(align: esc.PosAlign.center),
  //   ));
  //   bytes.addAll(generator.hr());
  //   // Items
  //   for (final item in CartManager.cartItems) {
  //     final product = item['product'];
  //     final qty = (item['qty'] as num).toInt();
  //     final addons = (item['addons'] as List);
  //     final price =
  //         double.tryParse(product.price.replaceAll('₹', '')) ?? 0.0;
  //     final addonTotal =
  //     addons.fold<double>(0, (sum, a) => sum + (a.price as double));
  //     final lineTotal = (price + addonTotal) * qty;
  //     bytes.addAll(generator.row([
  //       esc.PosColumn(
  //         text: '${product.name}  x  $qty',
  //         width: 8,
  //       ),
  //       esc.PosColumn(
  //         text: lineTotal.toStringAsFixed(2),
  //         width: 4,
  //         styles: const esc.PosStyles(align: esc.PosAlign.right),
  //       ),
  //     ]));
  //     for (final a in addons) {
  //       bytes.addAll(generator.text(
  //         '  + ${a.name}',
  //         styles: const esc.PosStyles(align: esc.PosAlign.left),
  //       ));
  //     }
  //   }
  //   bytes.addAll(generator.hr());
  //   // Totals
  //   bytes.addAll(generator.row([
  //     esc.PosColumn(text: 'Sub Total', width: 8),
  //     esc.PosColumn(
  //       text: subtotal.toStringAsFixed(2),
  //       width: 4,
  //       styles: const esc.PosStyles(align: esc.PosAlign.right),
  //     ),
  //   ]));
  //   bytes.addAll(generator.row([
  //     esc.PosColumn(text: 'Tax', width: 8),
  //     esc.PosColumn(
  //       text: tax.toStringAsFixed(2),
  //       width: 4,
  //       styles: const esc.PosStyles(align: esc.PosAlign.right),
  //     ),
  //   ]));
  //   bytes.addAll(generator.row([
  //     esc.PosColumn(text: 'Net Payable', width: 8),
  //     esc.PosColumn(
  //       text: total.toStringAsFixed(2),
  //       width: 4,
  //       styles: const esc.PosStyles(
  //         align: esc.PosAlign.right,
  //         bold: true,
  //       ),
  //     ),
  //   ]));
  //   bytes.addAll(generator.hr(ch: '=', linesAfter: 1));
  //   bytes.addAll(generator.text(
  //     'Thank you!',
  //     styles: const esc.PosStyles(
  //       align: esc.PosAlign.center,
  //       bold: true,
  //     ),
  //   ));
  //   bytes.addAll(generator.feed(3));
  //   bytes.addAll(generator.cut());
  //   return bytes;
  // }
  Future<void> cacheLogo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'store_logo',
          base64Encode(response.bodyBytes),
        );
      }
    } catch (_) {}
  }

  Future<List<int>> buildCashReceiptBytes({
    required String orderType,
    required double subtotal,
    required double tax,
    required double total,
    required int? orderId,
    required String token,
  }) async {
    // ✅ 1. Fetch everything FIRST
    final store = await StoreDetailsRepository()
        .getStoreDetails(token: token);

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
    bytes.addAll(generator.text(
      "  ****CUST_INVOICE****",
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        // bold: true,
        height: esc.PosTextSize.size1,
        width: esc.PosTextSize.size1,
      ),
    ));

    bytes.addAll(generator.feed(1));

    // ================================
    // 🏪 STORE INFO
    // ================================
    bytes.addAll(generator.text(
      store.name,
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
        height: esc.PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.feed(1)); // 1 line space

    bytes.addAll(generator.text(
      store.address,
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ));

    bytes.addAll(generator.text(
      store.cityLine,
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ));

    bytes.addAll(generator.text(
      "Phone: ${store.phoneNumber}",
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ));

    bytes.addAll(generator.hr());

    // ================================
    // 📅 DATE & TIME
    // ================================
    final now = DateTime.now();
    final date = "${now.day}/${now.month}/${now.year}";
    final time =
        "${now.hour}:${now.minute.toString().padLeft(2, '0')}";

// ✅ Row 1 → Date & Time
    // Row 1
    // Row 1 → Date + Time
    // Row 1 → Date & Time
    bytes.addAll(generator.row([
      esc.PosColumn(
        text: "Date: $date",
        width: 8,
      ),
      esc.PosColumn(
        text: "Time: $time",
        width: 4,
        // ❌ remove align: right
      ),
    ]));

// Row 2 → OrderID & Type
    bytes.addAll(generator.row([
      esc.PosColumn(
        text: "OrderID: ${orderId ?? '--'}",
        width: 8,
      ),
      esc.PosColumn(
        text: "Type: ${orderType.toUpperCase()}",
        width: 4,
        // ❌ remove align: right
      ),
    ]));

    bytes.addAll(generator.hr());
    // bytes.addAll(generator.hr());

    // ================================
    // 🧾 ITEM HEADER (80mm)
    // ================================
    bytes.addAll(generator.row([
      esc.PosColumn(text: "#", width: 1, styles: esc.PosStyles(bold: true)),
      esc.PosColumn(text: "Item", width: 5, styles: esc.PosStyles(bold: true)),
      esc.PosColumn(
          text: "Qty",
          width: 2,
          styles: esc.PosStyles(align: esc.PosAlign.center, bold: true)),
      esc.PosColumn(
          text: "Rate",
          width: 2,
          styles: esc.PosStyles(align: esc.PosAlign.right, bold: true)),
      esc.PosColumn(
          text: "Amt",
          width: 2,
          styles: esc.PosStyles(align: esc.PosAlign.right, bold: true)),
    ]));

    bytes.addAll(generator.feed(1));

    // ================================
    // 🛒 ITEMS
    // ================================
    int index = 1;

    for (final item in CartManager.cartItems) {
      final product = item['product'];
      final qty = (item['qty'] as num).toInt();
      final addons = (item['addons'] as List);

      final price =
          double.tryParse(product.price.replaceAll('₹', '')) ?? 0.0;

      final addonTotal =
      addons.fold<double>(0, (sum, a) => sum + (a.price as double));

      final rate = price + addonTotal;
      final amount = rate * qty;

      bytes.addAll(generator.row([
        esc.PosColumn(text: "${index++}", width: 1),
        esc.PosColumn(text: product.name, width: 5),
        esc.PosColumn(
            text: "$qty",
            width: 2,
            styles: const esc.PosStyles(align: esc.PosAlign.center)),
        esc.PosColumn(
            text: rate.toStringAsFixed(2),
            width: 2,
            styles: const esc.PosStyles(align: esc.PosAlign.right)),
        esc.PosColumn(
            text: amount.toStringAsFixed(2),
            width: 2,
            styles: const esc.PosStyles(align: esc.PosAlign.right)),
      ]));

      // Addons
      for (final a in addons) {
        bytes.addAll(generator.row([
          esc.PosColumn(text: "  + ${a.name}", width: 10),
          esc.PosColumn(
            text: (a.price as double).toStringAsFixed(2),
            width: 2,
            styles: const esc.PosStyles(align: esc.PosAlign.right),
          ),
        ]));
      }

      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.hr());

    // ================================
    // 💰 TOTALS
    // ================================
    bytes.addAll(generator.row([
      esc.PosColumn(text: "Sub Total", width: 8),
      esc.PosColumn(
        text: subtotal.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.row([
      esc.PosColumn(text: "Tax", width: 8),
      esc.PosColumn(
        text: tax.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.row([
      esc.PosColumn(
        text: "NET PAYABLE",
        width: 8,
        styles: const esc.PosStyles(
          bold: true,
          height: esc.PosTextSize.size1, // ✅ smaller
          width: esc.PosTextSize.size1,  // ✅ normal width
        ),
      ),
      esc.PosColumn(
        text: total.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(
          align: esc.PosAlign.right,
          bold: true,
          height: esc.PosTextSize.size1, // 🔥 keep amount big
          width: esc.PosTextSize.size1,
        ),
      ),
    ]));

    bytes.addAll(generator.hr(ch: '=', linesAfter: 1));

    // ================================
    // 🙏 FOOTER
    // ================================
    bytes.addAll(generator.text(
      "Thank you!",
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
      ),
    ));

    bytes.addAll(generator.feed(5));
    bytes.addAll(generator.cut());

    return bytes;
  }

  final PrinterManager _printerManager = PrinterManager.instance;

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> printReceiptForSelectedType(List<int> bytes, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrinterPrefsKeys.type) ?? 'bluetooth';
    final appType = AppPrinterTypeExt.fromKey(stored);
    final printerType =
        appType == AppPrinterType.bluetooth ? PrinterType.bluetooth : PrinterType.usb;
    try {
      final printers = await _discoverDevices(printerType);
      debugPrint('Found ${printers.length} printers:');
      for (final p in printers) {
        final name = p.name.toString();
        final addr = (p.address ?? '').toString();
        debugPrint('- $name ${addr.isNotEmpty ? "[$addr]" : ""}');
      }

      var filtered = printers.where((p) {
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
        final savedAddr = prefs.getString(PrinterPrefsKeys.btAddress)?.trim() ?? '';
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
          device = byName ??
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

      final connected = printerType == PrinterType.bluetooth
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
        _snack(context, 'Could not connect to printer. Check cable/Bluetooth and settings.');
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
        final pt = t == AppPrinterType.bluetooth ? PrinterType.bluetooth : PrinterType.usb;
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
      final key = '${device.name}_${device.address ?? ''}_${device.vendorId ?? ''}_${device.productId ?? ''}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  KioskMenuBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  KioskOrderTypeChip(orderType: widget.orderType),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Pay Cash at Counter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29 / 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22262C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Take the printed receipt and pay at the\ncounter',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16 / 1.2,
                          color: Color(0xFF7D8188),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: Image.asset(
                          'assets/printreceipt.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC7D3E3)),
                        ),
                        child: Column(
                          children: [
                            _CashRow(
                              title: 'Items   -',
                              value: _itemCount.toString().padLeft(2, '0'),
                              valueBold: false,
                              header: true,
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Sub Total',
                              value: _formatAmount(widget.subtotal),
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Tax (CGST + SGST)',
                              value: _formatAmount(widget.tax),
                            ),
                            const SizedBox(height: 8),
                            const _Dash(),
                            const SizedBox(height: 8),
                            _CashRow(
                              title: 'Net Payable',
                              value: _formatAmount(widget.total),
                              valueBold: true,
                              emphasizeTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          CartManager.cartItems.clear();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Start New Order',
                          style: TextStyle(
                            color: Color(0xFFFFA640),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFA640),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPrinting
                      ? null // disables button
                      : () async {
                    setState(() => _isPrinting = true);

                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token') ?? '';

                      final bytes = await buildCashReceiptBytes(
                        orderType: widget.orderType,
                        subtotal: widget.subtotal,
                        tax: widget.tax,
                        total: widget.total,
                        orderId: widget.orderId,
                        token: token, // ✅ now defined
                      );

                      if (!context.mounted) return;

                      final ok = await printReceiptForSelectedType(bytes, context);

                      if (!context.mounted || !ok) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrintReceiptScreen(
                            total: widget.total,
                            orderId: widget.orderId,
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isPrinting = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isPrinting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Print Receipt',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18 / 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final String title;
  final String value;
  final bool valueBold;
  final bool header;
  /// Larger type for the final total line (e.g. Net Payable).
  final bool emphasizeTotal;

  const _CashRow({
    required this.title,
    required this.value,
    this.valueBold = false,
    this.header = false,
    this.emphasizeTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final bodySize = emphasizeTotal ? 15.0 : 11.0;
    final titleStyle = TextStyle(
      fontSize: header ? 12 : bodySize,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: header
          ? FontWeight.w500
          : (emphasizeTotal ? FontWeight.w600 : FontWeight.w500),
    );

    final valueStyle = TextStyle(
      fontSize: header ? 12 : bodySize,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
    );

    if (header) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E568D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: titleStyle),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: titleStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFFBFD0E4),
    );
  }
}