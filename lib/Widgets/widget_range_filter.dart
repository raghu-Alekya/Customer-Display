import 'package:flutter/material.dart';

class RangeFilter extends StatefulWidget { // Build #1.0.8, Surya added
  final String label;
  final double minValue;
  final double maxValue;
  final RangeValues initialRange;
  final Function(RangeValues) onRangeChanged;

  RangeFilter({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.initialRange,
    required this.onRangeChanged,
  });

  @override
  _RangeFilterState createState() => _RangeFilterState();
}

class _RangeFilterState extends State<RangeFilter> {
  late RangeValues _currentRange;
  late TextEditingController minController;
  late TextEditingController maxController;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
    minController = TextEditingController(text: _currentRange.start.round().toString());
    maxController = TextEditingController(text: _currentRange.end.round().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label),
            SizedBox(height: 10),
            RangeSlider(
              values: _currentRange,
              min: widget.minValue,
              max: widget.maxValue,
              divisions: 10,
              labels: RangeLabels(
                _currentRange.start.round().toString(),
                _currentRange.end.round().toString(),
              ),
              onChanged: (values) {
                setState(() {
                  _currentRange = values;
                  minController.text = values.start.round().toString();
                  maxController.text = values.end.round().toString();
                });
                widget.onRangeChanged(values);
              },
            ),
            Row(
              children: [
                _buildRangeInput("Min", minController, true),
                SizedBox(width: 12),
                _buildRangeInput("Max", maxController, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeInput(String label, TextEditingController controller, bool isMin) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onSubmitted: (_) => _updateRangeFromInputs(),
      ),
    );
  }

  void _updateRangeFromInputs() {
    double? min = double.tryParse(minController.text);
    double? max = double.tryParse(maxController.text);

    if (min != null && max != null && min < max) {
      setState(() {
        _currentRange = RangeValues(min, max);
      });
      widget.onRangeChanged(_currentRange);
    }
  }
}
