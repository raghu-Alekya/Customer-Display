import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class WeightProvider extends ChangeNotifier {
  double _weightKg        = 0.0;
  String _weightText      = '0.00 lb';
  String _nativeUnit      = 'lb';   // UI always shows pounds (chip / labels)
  bool   _isStable        = false;  // ← mirrors USB manager's 'stable' flag
  bool   _isConnected     = false;
  bool   _suppressUpdates = false;
  bool   _paused          = false;

  double get weightKg        => _weightKg;
  String get weightText      => _weightText;
  String get nativeUnit      => _nativeUnit;
  bool   get isStable        => _isStable;
  bool   get isConnected     => _isConnected;
  bool   get isPaused        => _paused;
  bool   get suppressUpdates => _suppressUpdates;

  // ── Called by TopBar's USB EventChannel stream ──────────────────────────
  // Pass the raw values exactly as UsbSerialManager emits them:
  //   weight  → the numeric value (in nativeUnit)
  //   unit    → 'kg' | 'lb' | 'g' | 'oz'
  //   stable  → from parseWeight()
  void updateFromUsb({
    required double weight,
    required String unit,
    required bool   stable,
    String?         displayText,
  }) {
    if (_suppressUpdates) return;
    _nativeUnit = 'lb';
    _isStable   = stable;
    _weightKg   = _toKg(weight, unit);          // normalise → kg for storage
    _weightText = displayText ?? _buildDisplayText(_weightKg);
    notifyListeners();
  }

  /// Legacy helper kept for compatibility — assumes lb display.
  void updateWeight(double kg, {String? displayText}) {
    if (_suppressUpdates) return;
    _weightKg   = kg;
    _nativeUnit = 'lb';
    _isStable   = true;
    _weightText = displayText ?? _buildDisplayText(kg);
    notifyListeners();
  }

  void resumeFromScale(double kg, {String? displayText}) {
    if (_suppressUpdates) return;
    _paused     = false;
    _weightKg   = kg;
    _nativeUnit = 'lb';
    _weightText = displayText ?? _buildDisplayText(kg);
    notifyListeners();
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    if (!connected) {
      _weightKg        = 0.0;
      _weightText      = '0.00 lb';
      _nativeUnit      = 'lb';
      _isStable        = false;
      _paused          = false;
      _suppressUpdates = false;
    }
    notifyListeners();
  }

  void clearWeight() {
    _suppressUpdates = true;
    _weightKg        = 0.0;
    _weightText      = '0.00 lb';
    _isStable        = false;
    notifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      _suppressUpdates = false;
    });
  }

  void pause()  { _paused = true; }
  void resume() { _paused = false; notifyListeners(); }

  // ── Internal helpers ────────────────────────────────────────────────────
  static double _toKg(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'lb': return value / 2.20462;
      case 'g':  return value / 1000.0;
      case 'oz': return value / 35.274;
      case 'kg':
      default:   return value;
    }
  }

  static String _buildDisplayText(double kg) =>
      '${(kg * 2.20462).toStringAsFixed(2)} lb';
}

// ─────────────────────────────────────────────────────────────────────────────
// AutoWeightPriceDialog
// ─────────────────────────────────────────────────────────────────────────────
class AutoWeightPriceDialog extends StatefulWidget {
  final String productName;
  final double unitPrice;

  /// Display unit shown in the dialog — defaults to 'lb'.
  final String unit;

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
  final TextEditingController _weightController = TextEditingController();
  bool   _isManualEntry = false;
  double _manualWeight  = 0.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_onManualWeightChanged);

    // Pre-fill with current scale reading converted to dialog's display unit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<WeightProvider>();
      final kg = provider.weightKg;
      if (kg > 0) {
        _setControllerSilently(_formatWeight(_weightLbFromKg(kg)));
      }
    });
  }

  @override
  void dispose() {
    _weightController.removeListener(_onManualWeightChanged);
    _weightController.dispose();
    super.dispose();
  }

  // ── Unit conversion ───────────────────────────────────────────────────────

  /// Provider stores kg internally; UI always shows pounds.
  double _weightLbFromKg(double kg) => kg * 2.20462;

  /// Pounds → product pricing unit (for unitPrice × weight).
  double _lbToPricingUnit(double lb) {
    switch (widget.unit.toLowerCase()) {
      case 'lb':
      case 'lbs':
        return lb;
      case 'kg':
        return lb / 2.20462;
      case 'g':
        return lb / 2.20462 * 1000.0;
      case 'oz':
        return lb / 2.20462 * 35.274;
      default:
        return lb / 2.20462;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Live or manual weight in **pounds** (what the user sees/edits).
  double _effectiveWeightLb(WeightProvider provider) {
    if (_isManualEntry) return _manualWeight;
    final kg = provider.weightKg;
    if (kg <= 0) return 0.0;
    return _weightLbFromKg(kg);
  }

  /// Price = weight × unitPrice, truncated to 2 decimals (no rounding).
  double _calculatedPrice(double weight) {
    final raw = weight * widget.unitPrice;
    return (raw * 100).truncateToDouble() / 100;
  }

  String _formatWeight(double value) => value.toStringAsFixed(2);

  /// Truncate to 2 decimal places without rounding.
  String _formatPrice(double value) {
    final raw      = value.toStringAsFixed(10);
    final dotIndex = raw.indexOf('.');
    if (dotIndex == -1) return raw;
    final dec      = raw.substring(dotIndex + 1);
    final truncDec = dec.length > 2 ? dec.substring(0, 2) : dec;
    return '${raw.substring(0, dotIndex)}.$truncDec';
  }

  void _setControllerSilently(String text) {
    _weightController.removeListener(_onManualWeightChanged);
    _weightController.text = text;
    if (text.isNotEmpty) {
      _weightController.selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
    }
    _weightController.addListener(_onManualWeightChanged);
  }

  void _onManualWeightChanged() {
    final text   = _weightController.text.trim();
    final parsed = double.tryParse(text);
    setState(() {
      if (parsed != null && parsed > 0) {
        _manualWeight  = parsed; // pounds
        _isManualEntry = true;
      } else {
        _manualWeight  = 0.0;
        _isManualEntry = text.isNotEmpty;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, _) {
        final weightLb = _effectiveWeightLb(weightProvider);
        final weight   = _lbToPricingUnit(weightLb);
        final price    = _calculatedPrice(weight);

        // Stability indicator — reflects USB manager's 'stable' flag directly
        final bool isLive   = !_isManualEntry;
        final bool isStable = weightProvider.isStable;

        // ── Sync text field with live scale when not in manual mode ──────
        if (!_isManualEntry) {
          final kg       = weightProvider.weightKg;
          final displayVal = kg > 0 ? _weightLbFromKg(kg) : 0.0;
          final liveText =
              displayVal > 0 ? _formatWeight(displayVal) : '';

          if (_weightController.text != liveText) {
            _setControllerSilently(liveText);
          }
        }

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                
                    // ── Title ────────────────────────────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'Auto Weight & Price',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:   22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32, height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5C5C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 16),
                
                    // ── Scale status chip ─────────────────────────────────────
                    _ScaleStatusChip(
                      isConnected: weightProvider.isConnected,
                      isLive:      isLive,
                      isStable:    isStable,
                    ),
                
                    const SizedBox(height: 20),
                
                    // ── Row 1: Product name + Unit price ──────────────────────
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
                            label: 'Unit Price :',
                            value: '\$${widget.unitPrice.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 20),
                
                    // ── Row 2: Weight field + Calculated price ─────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _EditableWeightBox(
                            label:      'Weight (lbs) :',
                            controller: _weightController,
                            hintText:   '0.00',
                            isLive:     isLive,
                            isStable:   isStable,
                            onClear: () {
                              setState(() {
                                _isManualEntry = false;
                                _manualWeight  = 0.0;
                              });
                              _setControllerSilently('');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FieldBox(
                            label:    'Calculated Price (\$) :',
                            value:    weight == 0.0 ? '' : _formatPrice(price),
                            hintText: '0.00',
                          ),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 28),
                
                    // ── Confirm button ─────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 180, height: 48,
                        child: ElevatedButton(
                          onPressed: weightLb > 0
                              ? () {
                            final capturedWeight = weight;
                            final capturedPrice  = price;
                
                            weightProvider.clearWeight();
                
                            Navigator.of(context).pop({
                              'weight':     capturedWeight,
                              'finalPrice': capturedPrice,
                            });
                
                            widget.onConfirm
                                ?.call(capturedWeight, capturedPrice);
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
                              fontSize:   16,
                              fontWeight: FontWeight.w600,
                              color:      Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScaleStatusChip
// Shows live connection + stability status from USB manager.
// ─────────────────────────────────────────────────────────────────────────────
class _ScaleStatusChip extends StatelessWidget {
  final bool   isConnected;
  final bool   isLive;
  final bool   isStable;

  const _ScaleStatusChip({
    required this.isConnected,
    required this.isLive,
    required this.isStable,
  });

  @override
  Widget build(BuildContext context) {
    final Color  bgColor;
    final Color  dotColor;
    final String label;

    if (!isConnected) {
      bgColor  = const Color(0xFFF5F5F5);
      dotColor = const Color(0xFFAAAAAA);
      label    = 'Scale disconnected';
    } else if (!isLive) {
      bgColor  = const Color(0xFFFFF3E0);
      dotColor = const Color(0xFFFF9800);
      label    = 'Manual entry mode';
    } else if (isStable) {
      bgColor  = const Color(0xFFE8F5E9);
      dotColor = const Color(0xFF4CAF50);
      label    = 'Scale stable · reading in lb';
    } else {
      bgColor  = const Color(0xFFFFF8E1);
      dotColor = const Color(0xFFFFC107);
      label    = 'Scale unstable · stabilising…';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w500,
              color:      dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoLabel  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
              fontSize:   15,
              fontWeight: FontWeight.w700,
              color:      Color(0xFF1A1A1A),
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w500,
              color:      Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FieldBox — read-only calculated price box  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
            fontSize:   15,
            fontWeight: FontWeight.w700,
            color:      Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color:        const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: const Color(0xFFE0E0E0)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            value.isEmpty ? hintText : value,
            style: TextStyle(
              fontSize:   16,
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

// ─────────────────────────────────────────────────────────────────────────────
// _EditableWeightBox
// Updated: shows live/manual state via border colour; has a clear button
// to return from manual mode back to live scale reading.
// ─────────────────────────────────────────────────────────────────────────────
class _EditableWeightBox extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final String                hintText;
  final bool                  isLive;
  final bool                  isStable;
  final VoidCallback          onClear;   // restores live mode

  const _EditableWeightBox({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isLive,
    required this.isStable,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Border colour reflects source:
    //   green  = live & stable
    //   amber  = live & unstable
    //   orange = manual entry
    final Color activeBorder = isLive
        ? (isStable ? const Color(0xFF4CAF50) : const Color(0xFFFFC107))
        : const Color(0xFFFF9800);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w700,
            color:      Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller:   controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w500,
              color:      Color(0xFF555555),
            ),
            decoration: InputDecoration(
              hintText:  hintText,
              hintStyle: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w500,
                color:      Color(0xFFCCCCCC),
              ),
              filled:    true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 0),
              // "↺" button — only shown when user has typed manually
              suffixIcon: !isLive
                  ? Tooltip(
                message: 'Return to live scale reading',
                child: IconButton(
                  icon: const Icon(Icons.refresh,
                      color: Color(0xFFFF9800), size: 20),
                  onPressed: onClear,
                ),
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide(color: activeBorder, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:   BorderSide(color: activeBorder, width: 2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}