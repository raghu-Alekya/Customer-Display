import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' as esc;
import 'package:thermal_printer/thermal_printer.dart';

/// Keys for [SharedPreferences]; also used when printing receipts from [CashMethodScreen].
class PrinterPrefsKeys {
  PrinterPrefsKeys._();

  static const type = 'printer_type';
  static const btAddress = 'printer_bt_address';
  static const btName = 'printer_bt_name';
  static const usbVendor = 'printer_usb_vendor_id';
  static const usbProduct = 'printer_usb_product_id';
}

/// ---------- Printer type enum & helpers ----------

enum AppPrinterType { bluetooth, usb }

extension AppPrinterTypeExt on AppPrinterType {
  String get label {
    switch (this) {
      case AppPrinterType.bluetooth:
        return 'Bluetooth';
      case AppPrinterType.usb:
        return 'USB';
    }
  }

  String get key {
    switch (this) {
      case AppPrinterType.bluetooth:
        return 'bluetooth';
      case AppPrinterType.usb:
        return 'usb';
    }
  }

  static AppPrinterType fromKey(String key) {
    switch (key) {
      case 'usb':
        return AppPrinterType.usb;
      case 'bluetooth':
      default:
        return AppPrinterType.bluetooth;
    }
  }
}

/// ---------- Settings + Print Screen ----------

class PrinterSettingsAndTestScreen extends StatefulWidget {
  const PrinterSettingsAndTestScreen({super.key});

  @override
  State<PrinterSettingsAndTestScreen> createState() =>
      _PrinterSettingsAndTestScreenState();
}

class _PrinterSettingsAndTestScreenState
    extends State<PrinterSettingsAndTestScreen> {
  AppPrinterType _selected = AppPrinterType.bluetooth;
  bool _loading = true;
  bool _printing = false;
  final PrinterManager _printerManager = PrinterManager.instance;

  @override
  void initState() {
    super.initState();
    _loadPrinterType();
  }

  Future<void> _loadPrinterType() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrinterPrefsKeys.type);
    final type =
    stored == null ? AppPrinterType.bluetooth : AppPrinterTypeExt.fromKey(stored);
    if (!mounted) return;
    setState(() {
      _selected = type;
      _loading = false;
    });
  }

  Future<void> _savePrinterType(AppPrinterType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrinterPrefsKeys.type, type.key);
  }

  Future<void> _saveLastPrinterDevice(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    if (_selected == AppPrinterType.bluetooth) {
      await prefs.setString(
        PrinterPrefsKeys.btAddress,
        (device.address ?? '').toString(),
      );
      await prefs.setString(
        PrinterPrefsKeys.btName,
        device.name.toString(),
      );
    } else {
      await prefs.setString(
        PrinterPrefsKeys.usbVendor,
        (device.vendorId ?? '').toString(),
      );
      await prefs.setString(
        PrinterPrefsKeys.usbProduct,
        (device.productId ?? '').toString(),
      );
    }
  }

  Future<void> _onTypeChanged(AppPrinterType? value) async {
    if (value == null) return;
    setState(() => _selected = value);
    await _savePrinterType(value);
  }

  /// Build a very simple test ticket.
  Future<List<int>> _buildTestBytes() async {
    final profile = await esc.CapabilityProfile.load();
    final generator = esc.Generator(esc.PaperSize.mm80, profile);

    final bytes = <int>[];
    bytes.addAll(generator.text(
      'Test Receipt',
      styles: const esc.PosStyles(
        align: esc.PosAlign.center,
        bold: true,
        height: esc.PosTextSize.size2,
        width: esc.PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.hr());
    // ...
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<PrinterDevice?> _pickPrinterForSelectedType() async {
    final type =
        _selected == AppPrinterType.bluetooth ? PrinterType.bluetooth : PrinterType.usb;
    final printers = await _discoverDevices(type);
    debugPrint('Found ${printers.length} printers total');
    for (final p in printers) {
      final name = p.name.toString();
      final addr = (p.address ?? '').toString();
      debugPrint('- $name ${addr.isNotEmpty ? "[$addr]" : ""}');
    }

    var filtered = printers.where((p) {
      if (_selected == AppPrinterType.bluetooth) {
        // For Bluetooth, allow all discovered devices (including InnerPrinter).
        // We still require that there is at least some address string.
        return (p.address ?? '').toString().trim().isNotEmpty;
      }
      // USB: keep all candidates for now, we will prefer real printers below.
      return true;
    }).toList();

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No ${_selected.label} printers found.'),
          ),
        );
      }
      return null;
    }

    // Let the user pick which printer to use for Test Print.
    return showDialog<PrinterDevice>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Select ${_selected.label} printer'),
          content: SizedBox(
            width: 400,
            height: 320,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final p = filtered[index];
                final name = p.name.toString();
                final addr = (p.address ?? '').toString();
                final vid = (p.vendorId ?? '').toString();
                final pid = (p.productId ?? '').toString();
                final details = [
                  if (addr.isNotEmpty) 'Addr: $addr',
                  if (vid.isNotEmpty && pid.isNotEmpty) 'VID: $vid  PID: $pid',
                ].join(' • ');
                return ListTile(
                  title: Text(name.isEmpty ? '(Unnamed device)' : name),
                  subtitle: details.isEmpty ? null : Text(details),
                  onTap: () => Navigator.of(ctx).pop(p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
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

  Future<void> _testPrint() async {
    setState(() => _printing = true);
    try {
      final bytes = await _buildTestBytes();

      // Use the helper that respects Bluetooth/USB selection
      final device = await _pickPrinterForSelectedType();
      if (device == null) {
        // _pickPrinterForSelectedType already showed a SnackBar
        return;
      }

      final type =
          _selected == AppPrinterType.bluetooth ? PrinterType.bluetooth : PrinterType.usb;
      final deviceName = device.name.toString();
      debugPrint('Connecting to printer: $deviceName ($type)');

      final connected = type == PrinterType.bluetooth
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
        throw Exception('Could not connect to printer');
      }
      final sent = await _printerManager.send(type: type, bytes: bytes);
      if (!sent) {
        throw Exception('Printer did not accept data (send failed)');
      }
      await _saveLastPrinterDevice(device);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print sent')),
        );
      }
    } catch (e, st) {
      debugPrint('Print error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    } finally {
      try {
        final type =
            _selected == AppPrinterType.bluetooth ? PrinterType.bluetooth : PrinterType.usb;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await _printerManager.disconnect(
          type: type,
          delayMs: type == PrinterType.usb ? 150 : null,
        );
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings & Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select printer type:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<AppPrinterType>(
              title: const Text('Bluetooth printer'),
              value: AppPrinterType.bluetooth,
              groupValue: _selected,
              onChanged: _printing ? null : _onTypeChanged,
            ),
            RadioListTile<AppPrinterType>(
              title: const Text('USB printer'),
              value: AppPrinterType.usb,
              groupValue: _selected,
              onChanged: _printing ? null : _onTypeChanged,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _printing ? null : _testPrint,
                icon: _printing
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.print),
                label: Text(_printing ? 'Printing...' : 'Test Print'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}