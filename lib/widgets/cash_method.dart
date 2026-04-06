import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keyos_app/Homescreen.dart';
import 'package:keyos_app/cart_manger.dart';
import 'package:keyos_app/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cash_receipt.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' as esc;
import 'package:thermal_printer/thermal_printer.dart';

class CashMethodScreen extends StatelessWidget {
  final String orderType;
  final double subtotal;
  final double tax;
  final double total;
  final int? orderId;

   CashMethodScreen({
    super.key,
    required this.orderType,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.orderId,
  });

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';

  int get _itemCount {
    return CartManager.cartItems.fold<int>(0, (sum, item) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      return sum + qty;
    });
  }
  Future<List<int>> buildCashReceiptBytes({
    required String orderType,
    required double subtotal,
    required double tax,
    required double total,
    required int? orderId,
  }) async {
    final profile = await esc.CapabilityProfile.load();
    final generator = esc.Generator(esc.PaperSize.mm80, profile);
    final bytes = <int>[];
    // Header
    bytes.addAll(generator.text(
      'My Kiosk',
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
        height: esc.PosTextSize.size2,
        width: esc.PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.text(
      'Order: ${orderId ?? '--'}',
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ));
    bytes.addAll(generator.text(
      orderType,
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    ));
    bytes.addAll(generator.hr());
    // Items
    for (final item in CartManager.cartItems) {
      final product = item['product'];
      final qty = (item['qty'] as num).toInt();
      final addons = (item['addons'] as List);
      final price =
          double.tryParse(product.price.replaceAll('₹', '')) ?? 0.0;
      final addonTotal =
      addons.fold<double>(0, (sum, a) => sum + (a.price as double));
      final lineTotal = (price + addonTotal) * qty;
      bytes.addAll(generator.row([
        esc.PosColumn(
          text: '${product.name}  x  $qty',
          width: 8,
        ),
        esc.PosColumn(
          text: lineTotal.toStringAsFixed(2),
          width: 4,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),
      ]));
      for (final a in addons) {
        bytes.addAll(generator.text(
          '  + ${a.name}',
          styles: const esc.PosStyles(align: esc.PosAlign.left),
        ));
      }
    }
    bytes.addAll(generator.hr());
    // Totals
    bytes.addAll(generator.row([
      esc.PosColumn(text: 'Sub Total', width: 8),
      esc.PosColumn(
        text: subtotal.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      esc.PosColumn(text: 'Tax', width: 8),
      esc.PosColumn(
        text: tax.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      esc.PosColumn(text: 'Net Payable', width: 8),
      esc.PosColumn(
        text: total.toStringAsFixed(2),
        width: 4,
        styles: const esc.PosStyles(
          align: esc.PosAlign.right,
          bold: true,
        ),
      ),
    ]));
    bytes.addAll(generator.hr(ch: '=', linesAfter: 1));
    bytes.addAll(generator.text(
      'Thank you!',
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
      ),
    ));
    bytes.addAll(generator.feed(3));
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
        await Future<void>.delayed(const Duration(milliseconds: 200));
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
      backgroundColor: const Color(0xFFE5E7EB),
      body: Center(
        child: Container(
          width: 500,
          // margin: const EdgeInsets.symmetric(vertical: 16),
          // padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 12),
          ),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 12,
                      color: Color(0xFFFF9900),
                    ),
                    label: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFFFF9900),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD08A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD3DDEB)),
                    ),
                    child: Text(
                      orderType,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5D78A5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const Text(
                'Pay Cash at Counter',
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

              // illustration placeholder / image
              SizedBox(
                height: 120,
                child: Image.asset(
                  'assets/printreceipt.png', // replace with your asset
                  fit: BoxFit.contain,
                  // errorBuilder: (_, __, ___) => const Icon(
                  //   Icons.point_of_sale_rounded,
                  //   size: 90,
                  //   color: Color(0xFF7C8DA6),
                  // ),
                ),
              ),

              const SizedBox(height: 22),

              // Bill card
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
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(
                      title: 'Sub Total',
                      value: _formatAmount(subtotal),
                    ),
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(
                      title: 'Tax (CGST + SGST)',
                      value: _formatAmount(tax),
                    ),
                    SizedBox(height: 8),
                    _Dash(),
                    SizedBox(height: 8),
                    _CashRow(
                      title: 'Net Payable',
                      value: _formatAmount(total),
                      valueBold: true,
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
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                  );
                },
                child: const Text(
                  'Start New Order',
                  style: TextStyle(
                    color: Color(0xFFFFA640),
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(),

    Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    child: SizedBox(
    width: double.infinity,
    child: ElevatedButton(
    onPressed: () async {
    final bytes = await buildCashReceiptBytes(
    orderType: orderType,
    subtotal: subtotal,
    tax: tax,
    total: total,
    orderId: orderId,
    );
    if (!context.mounted) return;

    final ok = await printReceiptForSelectedType(bytes, context);
    if (!context.mounted || !ok) return;

    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => PrintReceiptScreen(
    total: total,
    orderId: orderId,
    ),
    ),
    );
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
    child: const Text(
    'Print Receipt',
    style: TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 18 / 1.2,
    ),
    ),
    ),
    ),
    ),
              const SizedBox(height: 20),
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

  const _CashRow({
    required this.title,
    required this.value,
    this.valueBold = false,
    this.header = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: header ? 12 : 11,
      color: header ? Colors.white : const Color(0xFF5F738F),
      fontWeight: header ? FontWeight.w500 : FontWeight.w500,
    );

    final valueStyle = TextStyle(
      fontSize: header ? 12 : 11,
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