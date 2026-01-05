import 'package:flutter/material.dart';

/// A simple labeled slider with optional snapping and unit label.
class CustomSlider extends StatelessWidget {
  const CustomSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.unit = '',
    this.snapInterval,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;
  final double? snapInterval;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        Slider(
          value: _snapValue(value.clamp(min, max)),
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          label: unit.isEmpty
              ? _formatValue(value, step)
              : '${_formatValue(value, step)} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _formatValue(double v, double step) {
    if (step >= 1) return v.toStringAsFixed(0);
    if (step >= 0.1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  double _snapValue(double v) {
    if (snapInterval == null || snapInterval! <= 0) return v;
    final snap = snapInterval!;
    final snapped = (v / snap).round() * snap;
    return snapped.clamp(min, max);
  }
}


