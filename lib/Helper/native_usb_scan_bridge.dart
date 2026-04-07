import 'package:flutter/foundation.dart';

/// Forwards USB-serial scanner lines from [TopBar]'s EventChannel (`type: scan`)
/// into the same barcode handler used by [BarcodeKeyboardListener] on the order panel.
///
/// [UsbSerialManager.kt] sends `raw` as `"$deviceName: $scannedLine"`.
class NativeUsbScanBridge {
  NativeUsbScanBridge._();

  static void Function(String barcode)? _handler;

  static void registerHandler(void Function(String barcode) handler) {
    _handler = handler;
  }

  static void unregisterHandler(void Function(String barcode) handler) {
    if (identical(_handler, handler)) _handler = null;
  }

  /// Strips the `"device: "` prefix from native [raw] and invokes the registered handler.
  static void dispatchFromRaw(String raw) {
    final payload = _payloadFromRaw(raw);
    if (payload.length < 6) return;
    try {
      _handler?.call(payload);
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('NativeUsbScanBridge: $e\n$s');
      }
    }
  }

  static String _payloadFromRaw(String raw) {
    final t = raw.trim();
    const sep = ': ';
    final i = t.indexOf(sep);
    if (i >= 0 && i + sep.length < t.length) {
      return t.substring(i + sep.length).trim();
    }
    return t;
  }
}
