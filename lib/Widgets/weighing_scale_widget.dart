// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
//
//
// class WeightProvider extends ChangeNotifier {
//   double _weightKg        = 0.0;
//   String _weightText      = '0.000 lb';
//   bool   _isConnected     = false;
//   bool   _suppressUpdates = false;
//   bool   _paused          = false;
//
//   double get weightKg        => _weightKg;
//   String get weightText      => _weightText;
//   bool   get isConnected     => _isConnected;
//   bool   get isPaused        => _paused;
//   bool   get suppressUpdates => _suppressUpdates;
//
//   /// Called by TopBar's USB stream. Stores raw kg; builds lb display string.
//   void updateWeight(double kg, {String? displayText}) {
//     if (_suppressUpdates) return;
//     _weightKg   = kg;
//     _weightText = displayText ?? '${(kg * 2.20462).toStringAsFixed(3)} lb';
//     notifyListeners();
//   }
//
//   void resumeFromScale(double kg, {String? displayText}) {
//     if (_suppressUpdates) return;
//     _paused     = false;
//     _weightKg   = kg;
//     _weightText = displayText ?? '${(kg * 2.20462).toStringAsFixed(3)} lb';
//     notifyListeners();
//   }
//
//   void setConnected(bool connected) {
//     _isConnected = connected;
//     if (!connected) {
//       _weightKg        = 0.0;
//       _weightText      = '0.000 lb';
//       _paused          = false;
//       _suppressUpdates = false;
//     }
//     notifyListeners();
//   }
//
//
//   void clearWeight() {
//     _suppressUpdates = true;
//     _weightKg        = 0.0;
//     _weightText      = '0.000 lb';
//     notifyListeners(); // TopBar Consumer rebuilds immediately to show 0.000
//
//     Future.delayed(const Duration(seconds: 1), () {
//       _suppressUpdates = false;
//       // No notifyListeners — next real scale reading will update naturally
//     });
//   }
//
//   void pause()  { _paused = true; }
//   void resume() { _paused = false; notifyListeners(); }
// }
//
//
//
// class AutoWeightPriceDialog extends StatefulWidget {
//   final String productName;
//   final double unitPrice;
//
//   /// Display unit shown in the dialog — defaults to 'lb'.
//   final String unit;
//
//   final void Function(double weight, double calculatedPrice)? onConfirm;
//
//   const AutoWeightPriceDialog({
//     super.key,
//     required this.productName,
//     required this.unitPrice,
//     this.unit = 'lb',
//     this.onConfirm,
//   });
//
//   @override
//   State<AutoWeightPriceDialog> createState() => _AutoWeightPriceDialogState();
// }
//
// class _AutoWeightPriceDialogState extends State<AutoWeightPriceDialog> {
//   final TextEditingController _weightController = TextEditingController();
//   bool   _isManualEntry = false;
//   double _manualWeight  = 0.0;
//
//   // ── Lifecycle ─────────────────────────────────────────────────────────────
//
//   @override
//   void initState() {
//     super.initState();
//     _weightController.addListener(_onManualWeightChanged);
//
//     // Pre-fill text field with current scale reading converted to display unit
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       final kg = context.read<WeightProvider>().weightKg;
//       if (kg > 0) {
//         final displayVal = _kgToDisplayUnit(kg); // ← convert before pre-fill
//         _weightController.removeListener(_onManualWeightChanged);
//         _weightController.text = _formatWeight(displayVal);
//         _weightController.addListener(_onManualWeightChanged);
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _weightController.removeListener(_onManualWeightChanged);
//     _weightController.dispose();
//     super.dispose();
//   }
//
//   // ── Unit conversion ───────────────────────────────────────────────────────
//
//   /// Convert raw kg (always stored in provider) → dialog's display unit.
//   /// Scale sends kg → provider stores kg → dialog converts to lb for display.
//   double _kgToDisplayUnit(double kg) {
//     switch (widget.unit.toLowerCase()) {
//       case 'lb': return kg * 2.20462;  // 0.065 kg → 0.143 lb ✓
//       case 'g':  return kg * 1000;
//       case 'oz': return kg * 35.274;
//       case 'kg':
//       default:   return kg;
//     }
//   }
//
//   // ── Helpers ───────────────────────────────────────────────────────────────
//
//   /// Effective weight in display unit.
//   /// Manual entry takes priority over live scale reading.
//   double _effectiveWeight(WeightProvider provider) {
//     if (_isManualEntry) return _manualWeight;
//     final kg = provider.weightKg;
//     if (kg <= 0) return 0.0;
//     return _kgToDisplayUnit(kg); // e.g. 0.065 kg → 0.143 lb
//   }
//
//   /// Price = weight × unitPrice, truncated to 2 decimals (no rounding).
//   double _calculatedPrice(double weight) {
//     final raw = weight * widget.unitPrice;
//     return (raw * 100).truncateToDouble() / 100;
//   }
//
//   /// Truncate to 3 decimal places without rounding.
//   String _formatWeight(double value) {
//     final raw      = value.toStringAsFixed(10);
//     final dotIndex = raw.indexOf('.');
//     if (dotIndex == -1) return raw;
//     final dec      = raw.substring(dotIndex + 1);
//     final truncDec = dec.length > 3 ? dec.substring(0, 3) : dec;
//     return '${raw.substring(0, dotIndex)}.$truncDec';
//   }
//
//   /// Truncate to 2 decimal places without rounding.
//   String _formatPrice(double value) {
//     final raw      = value.toStringAsFixed(10);
//     final dotIndex = raw.indexOf('.');
//     if (dotIndex == -1) return raw;
//     final dec      = raw.substring(dotIndex + 1);
//     final truncDec = dec.length > 2 ? dec.substring(0, 2) : dec;
//     return '${raw.substring(0, dotIndex)}.$truncDec';
//   }
//
//   void _onManualWeightChanged() {
//     final text   = _weightController.text.trim();
//     final parsed = double.tryParse(text);
//     setState(() {
//       if (parsed != null && parsed > 0) {
//         _manualWeight  = parsed;
//         _isManualEntry = true;
//       } else {
//         _manualWeight  = 0.0;
//         _isManualEntry = text.isNotEmpty;
//       }
//     });
//   }
//
//   // ── Build ─────────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<WeightProvider>(
//       builder: (context, weightProvider, _) {
//         // Always in display unit (lb by default)
//         final weight = _effectiveWeight(weightProvider);
//         final price  = _calculatedPrice(weight);
//
//         // ── Sync text field with live scale when user has not typed manually ──
//         if (!_isManualEntry) {
//           final kg         = weightProvider.weightKg;
//           final displayVal = kg > 0 ? _kgToDisplayUnit(kg) : 0.0; // kg → lb
//           final liveText   = displayVal > 0 ? _formatWeight(displayVal) : '';
//
//           if (_weightController.text != liveText) {
//             _weightController.removeListener(_onManualWeightChanged);
//             _weightController.text = liveText;
//             if (liveText.isNotEmpty) {
//               _weightController.selection = TextSelection.fromPosition(
//                 TextPosition(offset: liveText.length),
//               );
//             }
//             _weightController.addListener(_onManualWeightChanged);
//           }
//         }
//
//         return Dialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           insetPadding: const EdgeInsets.symmetric(
//               horizontal: 24, vertical: 40),
//           child: SizedBox(
//             width: 480,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//
//                   // ── Title ──────────────────────────────────────────────
//                   Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       const Text(
//                         'Auto Weight & Price',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize:   22,
//                           fontWeight: FontWeight.w700,
//                           color:      Color(0xFF1A1A1A),
//                         ),
//                       ),
//                       Positioned(
//                         right: 0,
//                         child: GestureDetector(
//                           onTap: () => Navigator.of(context).pop(),
//                           child: Container(
//                             width: 32, height: 32,
//                             decoration: const BoxDecoration(
//                               color: Color(0xFFFF5C5C),
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Icon(Icons.close,
//                                 color: Colors.white, size: 18),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 28),
//
//                   // ── Row 1: Product name + Unit price ──────────────────
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _InfoLabel(
//                           label: 'Product Name :',
//                           value: widget.productName,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: _InfoLabel(
//                           label: 'Unit Price(${widget.unit}) :',
//                           value: '\$${widget.unitPrice.toStringAsFixed(2)}',
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   // ── Row 2: Weight field + Calculated price ─────────────
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _EditableWeightBox(
//                           label:      'Weight (${widget.unit}s) :',
//                           controller: _weightController,
//                           hintText:   '0.000',
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: _FieldBox(
//                           label:    'Calculated Price (\$) :',
//                           value:    weight == 0.0 ? '' : _formatPrice(price),
//                           hintText: '0.00',
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 28),
//
//                   // ── Confirm button ─────────────────────────────────────
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: SizedBox(
//                       width: 180, height: 48,
//                       child: ElevatedButton(
//                         onPressed: weight > 0
//                             ? () {
//                           final capturedWeight = weight;
//                           final capturedPrice  = price;
//
//                           // Reset TopBar display to 0.000 immediately
//                           // and suppress scale stream for 3 s
//                           weightProvider.clearWeight();
//
//                           // Return results to caller
//                           Navigator.of(context).pop({
//                             'weight':     capturedWeight,
//                             'finalPrice': capturedPrice,
//                           });
//
//                           widget.onConfirm
//                               ?.call(capturedWeight, capturedPrice);
//                         }
//                             : null,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFFFF6B6B),
//                           disabledBackgroundColor:
//                           const Color(0xFFFF6B6B).withOpacity(0.5),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           elevation: 0,
//                         ),
//                         child: const Text(
//                           'Confirm & Add',
//                           style: TextStyle(
//                             fontSize:   16,
//                             fontWeight: FontWeight.w600,
//                             color:      Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
//
// class _InfoLabel extends StatelessWidget {
//   final String label;
//   final String value;
//   const _InfoLabel({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return RichText(
//       text: TextSpan(
//         children: [
//           TextSpan(
//             text: label,
//             style: const TextStyle(
//               fontSize:   15,
//               fontWeight: FontWeight.w700,
//               color:      Color(0xFF1A1A1A),
//             ),
//           ),
//           const TextSpan(text: ' '),
//           TextSpan(
//             text: value,
//             style: const TextStyle(
//               fontSize:   15,
//               fontWeight: FontWeight.w500,
//               color:      Color(0xFFAAAAAA),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /// Read-only grey box — used for the calculated price.
// class _FieldBox extends StatelessWidget {
//   final String label;
//   final String value;
//   final String hintText;
//   const _FieldBox({
//     required this.label,
//     required this.value,
//     required this.hintText,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize:   15,
//             fontWeight: FontWeight.w700,
//             color:      Color(0xFF1A1A1A),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           height: 48,
//           decoration: BoxDecoration(
//             color:        const Color(0xFFF5F5F5),
//             borderRadius: BorderRadius.circular(10),
//             border:       Border.all(color: const Color(0xFFE0E0E0)),
//           ),
//           alignment: Alignment.centerLeft,
//           padding: const EdgeInsets.symmetric(horizontal: 14),
//           child: Text(
//             value.isEmpty ? hintText : value,
//             style: TextStyle(
//               fontSize:   16,
//               fontWeight: FontWeight.w500,
//               color: value.isEmpty
//                   ? const Color(0xFFCCCCCC)
//                   : const Color(0xFF555555),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// /// Editable text field — accepts both live scale data and manual keyboard input.
// class _EditableWeightBox extends StatelessWidget {
//   final String label;
//   final TextEditingController controller;
//   final String hintText;
//   const _EditableWeightBox({
//     required this.label,
//     required this.controller,
//     required this.hintText,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize:   15,
//             fontWeight: FontWeight.w700,
//             color:      Color(0xFF1A1A1A),
//           ),
//         ),
//         const SizedBox(height: 8),
//         SizedBox(
//           height: 48,
//           child: TextField(
//             controller:   controller,
//             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             style: const TextStyle(
//               fontSize:   16,
//               fontWeight: FontWeight.w500,
//               color:      Color(0xFF555555),
//             ),
//             decoration: InputDecoration(
//               hintText:  hintText,
//               hintStyle: const TextStyle(
//                 fontSize:   16,
//                 fontWeight: FontWeight.w500,
//                 color:      Color(0xFFCCCCCC),
//               ),
//               filled:    true,
//               fillColor: const Color(0xFFF5F5F5),
//               contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 14, vertical: 0),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide:   const BorderSide(color: Color(0xFFE0E0E0)),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide:   const BorderSide(
//                     color: Color(0xFFFF6B6B), width: 1.5),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }