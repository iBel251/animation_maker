import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

/// Placeholder tool settings panel for future brush/tool configuration.
class ToolSettingsPanel extends ConsumerWidget {
  const ToolSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorViewModelProvider);
    final vm = ref.read(editorViewModelProvider.notifier);
    final isBrush = state.activeTool == EditorTool.brush;

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: isBrush
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brush Settings',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _SliderRow(
                  label: 'Thickness',
                  value: state.brushThickness,
                  min: 0.5,
                  max: 300,
                  unit: 'px',
                  onChanged: vm.setBrushThickness,
                ),
                const SizedBox(height: 12),
                _SliderRow(
                  label: 'Opacity',
                  value: state.brushOpacity,
                  min: 0.05,
                  max: 1.0,
                  unit: '',
                  onChanged: vm.setBrushOpacity,
                ),
                const SizedBox(height: 12),
                _SliderRow(
                  label: 'Smoothness',
                  value: state.brushSmoothness,
                  min: 0.0,
                  max: 1.0,
                  unit: '',
                  onChanged: vm.setBrushSmoothness,
                ),
              ],
            )
          : Center(
              child: Text(
                'Select a brush to see settings',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: 40,
          label: unit.isEmpty
              ? value.toStringAsFixed(2)
              : '${value.toStringAsFixed(1)} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
