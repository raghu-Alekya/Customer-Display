import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:usb_serial/usb_serial.dart';

class WeightProvider extends ChangeNotifier {
  double _weightKg = 0.0;
  String _weightText = '0.000 lb';
  bool _isConnected = false;
  DateTime _lastUpdate = DateTime.now();


  bool _paused = false;

  double get weightKg => _weightKg;
  String get weightText => _weightText;
  bool get isConnected => _isConnected;
  DateTime get lastUpdate => _lastUpdate;
  bool get isPaused => _paused;

  void updateWeight(double kg, {String? displayText}) {

    if (_paused) return;

    _weightKg = kg;
    _lastUpdate = DateTime.now();

    if (displayText != null) {
      _weightText = displayText;
    } else {
      final lb = kg * 2.20462;
      _weightText = '${lb.toStringAsFixed(3)} lb';
    }

    notifyListeners();
  }


  void resumeFromScale(double kg, {String? displayText}) {
    _paused = false; // un-pause first
    _weightKg = kg;
    _lastUpdate = DateTime.now();

    if (displayText != null) {
      _weightText = displayText;
    } else {
      final lb = kg * 2.20462;
      _weightText = '${lb.toStringAsFixed(3)} lb';
    }

    notifyListeners(); // single repaint — no flicker
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    if (!connected) {
      _weightKg = 0.0;
      _weightText = '0.000 lb';
      _paused = false;
    }
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }


  void clearWeight() {
    _weightKg = 0.0;
    _weightText = '0.000 lb';
    _paused = true; // ← suppress UI update until scale resumes
  }
}


///////

class AutoWeightPriceDialog extends StatefulWidget {
  final String productName;
  final double unitPrice;

  /// The unit to display: 'lb', 'kg', etc.
  final String unit;

  /// Called when user taps "Confirm & Add"
  /// Receives (weight, calculatedPrice)
  final void Function(double weight, double calculatedPrice)? onConfirm;

  const AutoWeightPriceDialog({
    super.key,
    required this.productName,
    required this.unitPrice,
    this.unit = 'lb',
    this.onConfirm,
  });

  @override
  State<AutoWeightPriceDialog> createState() => _AutoWeightPriceDialogState();
}

class _AutoWeightPriceDialogState extends State<AutoWeightPriceDialog> {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _buffer = <int>[];

  double _weight = 0.0;
  bool _connected = false;

  // ── NEW: text controller for manual weight entry ──
  final TextEditingController _weightController = TextEditingController();
  bool _isManualEntry = false; // true when user is typing manually

  @override
  void initState() {
    super.initState();
    _connectScale();

    // Listen to manual text changes
    _weightController.addListener(_onManualWeightChanged);
  }

  // Called whenever user types in the weight field
  void _onManualWeightChanged() {
    final text = _weightController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _weight = 0.0;
        _isManualEntry = false;
      });
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed != null) {
      setState(() {
        _weight = parsed;
        _isManualEntry = true;
      });
    }
  }

  Future<void> _connectScale() async {
    try {
      final devices = await UsbSerial.listDevices();
      print("Devices found: ${devices.length}");
      for (var d in devices) {
        print("Device: ${d.productName}, VID:${d.vid}, PID:${d.pid}");
      }

      if (devices.isEmpty) {
        print("No USB devices found.");
        return;
      }

      // 🔹 Filter: try to find the USB serial scale
      UsbDevice? scaleDevice;

      // 1️⃣ First, check by name
      for (var d in devices) {
        final name = d.productName?.toLowerCase() ?? '';
        if (name.contains("usb serial") || name.contains("converter")) {
          scaleDevice = d;
          break;
        }
      }

      // 2️⃣ Fallback: check by known VID/PID
      if (scaleDevice == null) {
        for (var d in devices) {
          if (d.vid == 1027 && d.pid == 24577) {
            scaleDevice = d;
            break;
          }
        }
      }

      if (scaleDevice == null) {
        print("No USB scale found!");
        return;
      }

      // 🔹 Create port
      _port = await scaleDevice.create();
      if (_port == null) {
        print("Failed to create port for device.");
        return;
      }

      // 🔹 Open port
      final opened = await _port!.open();
      if (!opened) {
        print("Failed to open port for scale.");
        return;
      }

      // 🔹 Configure port
      await _port!.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await _port!.setDTR(true);
      await _port!.setRTS(true);

      _buffer.clear();

      // 🔹 Listen for incoming data
      _subscription = _port!.inputStream?.listen(
            (Uint8List data) {
          _buffer.addAll(data);
          while (_buffer.isNotEmpty) {
            final idx = _buffer.indexOf(0x0A); // newline
            if (idx == -1) break;

            final frame = _buffer.sublist(0, idx + 1);
            _buffer.removeRange(0, idx + 1);

            final line = String.fromCharCodes(frame).trim();
            if (line.isNotEmpty) {
              final parsed = _parseWeight(line);
              if (parsed != null && mounted) {
                // Only update from scale if user is NOT typing manually
                if (!_isManualEntry) {
                  setState(() {
                    _weight = parsed;
                    _connected = true;
                    // Sync controller text with scale reading (no rounding)
                    _weightController.removeListener(_onManualWeightChanged);
                    _weightController.text = _formatWeight(parsed);
                    _weightController.addListener(_onManualWeightChanged);
                  });
                }
              }
            }
          }
        },
        onError: (e) => print("Stream error: $e"),
        onDone: () => print("Stream closed"),
      );

      if (mounted) setState(() => _connected = true);
      print("✅ Connected to scale: ${scaleDevice.productName}");
    } catch (e) {
      print("Error connecting to scale: $e");
    }
  }

  double? _parseWeight(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'([+-]?\d*\.?\d+)\s*(kg|g|lb|oz)',
      caseSensitive: false,
    ).firstMatch(clean);

    if (match != null) {
      final value = double.tryParse(match.group(1) ?? '');
      final unit = match.group(2)?.toLowerCase() ?? '';

      if (value != null) {
        // Convert to the widget's preferred unit if needed
        if (unit == 'kg' && widget.unit == 'lb') return value * 2.20462;
        if (unit == 'lb' && widget.unit == 'kg') return value / 2.20462;
        if (unit == 'g' && widget.unit == 'kg') return value / 1000;
        if (unit == 'g' && widget.unit == 'lb') return (value / 1000) * 2.20462;
        return value;
      }
    }

    // Fallback: just extract a number
    final numMatch = RegExp(r'([+-]?\d*\.?\d+)').firstMatch(clean);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1) ?? '');
    }

    return null;
  }

  // ── NEW: Format weight WITHOUT rounding (truncate at 3 decimals) ──
  String _formatWeight(double value) {
    // Convert to string with enough decimal places, then truncate (not round)
    final raw = value.toStringAsFixed(10); // get plenty of decimals
    final dotIndex = raw.indexOf('.');
    if (dotIndex == -1) return raw;

    // Keep up to 3 decimal places, but truncate (not round)
    final decimals = raw.substring(dotIndex + 1);
    final truncatedDecimals = decimals.length > 3
        ? decimals.substring(0, 3)
        : decimals;

    return '${raw.substring(0, dotIndex)}.$truncatedDecimals';
  }

  // ── NEW: Calculated price WITHOUT rounding ──
  // e.g. 2.4999 * price → show exact truncated value, not rounded
  String _formatPrice(double value) {
    final raw = value.toStringAsFixed(10);
    final dotIndex = raw.indexOf('.');
    if (dotIndex == -1) return raw;

    final decimals = raw.substring(dotIndex + 1);
    final truncatedDecimals = decimals.length > 2
        ? decimals.substring(0, 2)
        : decimals;

    return '${raw.substring(0, dotIndex)}.$truncatedDecimals';
  }

  // ── UPDATED: calculated price uses truncation not rounding ──
  double get _calculatedPrice {
    final raw = _weight * widget.unitPrice;
    // Truncate to 2 decimal places without rounding
    return (raw * 100).truncateToDouble() / 100;
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    await _port?.close();
    _port = null;
  }

  @override
  void dispose() {
    _weightController.removeListener(_onManualWeightChanged);
    _weightController.dispose();
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title Row ──────────────────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Auto Weight & Price',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5C5C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Row 1: Product Name + Unit Price ───────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoLabel(
                      label: 'Product Name :',
                      value: widget.productName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoLabel(
                      label: 'Unit Price(${widget.unit}) :',
                      value: '\$${widget.unitPrice.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Row 2: Weight (editable) + Calculated Price ────────────
              Row(
                children: [
                  // ── UPDATED: Weight is now a TextField ──
                  Expanded(
                    child: _EditableWeightBox(
                      label: 'Weight (${widget.unit}s) :',
                      controller: _weightController,
                      hintText: '0.000',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Calculated price: truncated, not rounded ──
                  Expanded(
                    child: _FieldBox(
                      label: 'Calculated Price (\$) :',
                      value: _weight == 0.0
                          ? ''
                          : _formatPrice(_weight * widget.unitPrice),
                      hintText: '0.00',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Confirm Button ─────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 180,
                  height: 48,
                  child: ElevatedButton(
                    // ── UPDATED: enabled when _weight > 0 (scale OR manual) ──
                    onPressed: _weight > 0
                        ? () {
                      // Notify any callback
                      if (widget.onConfirm != null) {
                        widget.onConfirm!(_weight, _calculatedPrice);
                      }

                      // Clear WeightProvider
                      final weightProvider =
                      context.read<WeightProvider>();
                      weightProvider.clearWeight();

                      // Close the dialog
                      Navigator.of(context).pop({
                        "weight": _weight,
                        "finalPrice": _calculatedPrice,
                      });
                    }
                        : null,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      disabledBackgroundColor:
                      const Color(0xFFFF6B6B).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm & Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

/// Displays a bold label + colored value (e.g. "Product Name : Tomato")
class _InfoLabel extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a label above a read-only grey input box (for Calculated Price)
class _FieldBox extends StatelessWidget {
  final String label;
  final String value;
  final String hintText;

  const _FieldBox({
    required this.label,
    required this.value,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            value.isEmpty ? hintText : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: value.isEmpty
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF555555),
            ),
          ),
        ),
      ],
    );
  }
}

// ── NEW: Editable weight TextField box ────────────────────────────────────────

/// Displays a label above an EDITABLE input box for weight
/// Supports both auto-fill from USB scale and manual keyboard entry
class _EditableWeightBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;

  const _EditableWeightBox({
    required this.label,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF555555),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFCCCCCC),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}