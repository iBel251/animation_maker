import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_notifier.dart';
import 'package:animation_maker/core/widgets/color_picker_widget.dart';
import 'package:animation_maker/core/widgets/custom_slider.dart';
import 'package:animation_maker/core/constants/app_colors.dart';

/// Placeholder tool settings panel for future brush/tool configuration.
class ToolSettingsPanel extends ConsumerWidget {
  const ToolSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorViewModelProvider);
    final vm = ref.read(editorViewModelProvider.notifier);
    final isBrush = state.activeTool == EditorTool.brush;
    final isShape = state.activeTool == EditorTool.shape;
    final isSelect = state.activeTool == EditorTool.select;

    return Container(
      color: AppColors.grey50,
      padding: const EdgeInsets.all(12),
      child: isBrush
          ? _BrushSettings(state: state, vm: vm)
          : isShape
          ? _ShapeSettings(state: state, vm: vm)
          : isSelect
          ? _SelectSettings(state: state, vm: vm)
          : Center(
              child: Text(
                'Select a tool to see settings',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
              ),
            ),
    );
  }
}

class _ShapeSettings extends StatelessWidget {
  const _ShapeSettings({required this.state, required this.vm});

  final EditorState state;
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shape Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        CustomSlider(
          label: 'Stroke Width',
          value: state.brushThickness,
          min: 0.5,
          max: 300,
          unit: 'px',
          step: 1.0,
          snapInterval: 5.0,
          onChanged: vm.setBrushThickness,
        ),
        const SizedBox(height: 12),
        CustomSlider(
          label: 'Opacity',
          value: state.brushOpacity,
          min: 0.05,
          max: 1.0,
          unit: '',
          step: 0.1,
          onChanged: vm.setBrushOpacity,
        ),
        const SizedBox(height: 12),
        _FillColorPicker(
          current: state.shapeFillColor,
          onChanged: vm.setShapeFillColor,
        ),
      ],
    );
  }
}

class _SelectSettings extends StatelessWidget {
  const _SelectSettings({required this.state, required this.vm});

  final EditorState state;
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = state.pivotSnapEnabled;
    final strength = state.pivotSnapStrength;
    final flipPivot = state.pivotFlipWithObject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selection Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pivot snap',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) => vm.setPivotSnap(enabled: v),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Snap strength', style: theme.textTheme.labelSmall),
                  Text(
                    strength.toStringAsFixed(2),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.grey700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: strength.clamp(0, 1),
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: enabled ? (v) => vm.setPivotSnap(strength: v) : null,
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pivot flips with shape',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(value: flipPivot, onChanged: vm.setPivotFlipWithObject),
          ],
        ),
      ],
    );
  }
}

class _BrushSettings extends StatelessWidget {
  const _BrushSettings({required this.state, required this.vm});

  final EditorState state;
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brush Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        CustomSlider(
          label: 'Thickness',
          value: state.brushThickness,
          min: 0.5,
          max: 300,
          unit: 'px',
          step: 1.0,
          snapInterval: 5.0,
          onChanged: vm.setBrushThickness,
        ),
        const SizedBox(height: 12),
        CustomSlider(
          label: 'Opacity',
          value: state.brushOpacity,
          min: 0.05,
          max: 1.0,
          unit: '',
          step: 0.1,
          onChanged: vm.setBrushOpacity,
        ),
        const SizedBox(height: 12),
        CustomSlider(
          label: 'Smoothness',
          value: state.brushSmoothness,
          min: 0.0,
          max: 1.0,
          unit: '',
          step: 0.1,
          onChanged: vm.setBrushSmoothness,
        ),
      ],
    );
  }
}

class _FillColorPicker extends StatelessWidget {
  const _FillColorPicker({required this.current, required this.onChanged});

  final Color? current;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fill color',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showAdaptiveColorPicker(
                  context: context,
                  initialColor: color ?? AppColors.white,
                );
                if (picked != null) {
                  onChanged(picked);
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color ?? AppColors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => onChanged(null),
              child: const Text('No fill'),
            ),
          ],
        ),
      ],
    );
  }
}



