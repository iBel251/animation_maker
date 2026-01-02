import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';

import 'editor_view_model.dart';
import 'package:animation_maker/domain/models/shape.dart';
import '../../widgets/adaptive_color_picker.dart';
import 'fill_utils.dart';

class PropertiesPanel extends ConsumerStatefulWidget {
  const PropertiesPanel({super.key, this.shapeCount});

  /// Optional override for shape count (primarily for hot reload compatibility).
  final int? shapeCount;

  @override
  ConsumerState<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends ConsumerState<PropertiesPanel> {
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _strokeCtrl = TextEditingController();

  String? _trackedSignature;

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _strokeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(
      editorViewModelProvider.select((state) => state.selectedShapeId),
    );
    final shapes =
        widget.shapeCount ??
        ref.watch(
          editorViewModelProvider.select((state) => state.shapes.length),
        );
    final currentColor = ref.watch(
      editorViewModelProvider.select((state) => state.currentColor),
    );
    final selectedShape = ref.watch(
      editorViewModelProvider.select((state) {
        final id = state.selectedShapeId;
        if (id == null) return null;
        for (final s in state.shapes) {
          if (s.id == id) return s;
        }
        return null;
      }),
    );

    _syncControllers(selectedShape);

    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: selectedId == null || selectedShape == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No object selected',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Shapes: $shapes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shape: $selectedId',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'Position'),
                    _stepperGrid(
                      context,
                      items: [
                        _StepperItem(
                          label: 'X',
                          value: _xCtrl.text,
                          onStep: (delta) => _nudgePosition(xDelta: delta),
                          fullWidth: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _stepperGrid(
                      context,
                      items: [
                        _StepperItem(
                          label: 'Y',
                          value: _yCtrl.text,
                          onStep: (delta) => _nudgePosition(yDelta: delta),
                          fullWidth: true,
                        ),
                      ],
                    ),
                    if (_hasBounds(selectedShape)) ...[
                      const SizedBox(height: 12),
                      _sectionTitle(context, 'Size'),
                      _stepperGrid(
                        context,
                        items: [
                          _StepperItem(
                            label: 'W',
                            value: _wCtrl.text,
                            onStep: (delta) => _nudgeSize(widthDelta: delta),
                          ),
                          _StepperItem(
                            label: 'H',
                            value: _hCtrl.text,
                            onStep: (delta) => _nudgeSize(heightDelta: delta),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'Appearance'),
                    _strokeControls(
                      context,
                      strokeWidth: selectedShape.strokeWidth,
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'Color'),
                    _swatchRow(
                      context,
                      label: 'Stroke',
                      color: selectedShape.strokeColor,
                      onPick: () async {
                        final picked = await showAdaptiveColorPicker(
                          context: context,
                          initialColor: selectedShape.strokeColor,
                        );
                        if (picked != null) {
                          ref
                              .read(editorViewModelProvider.notifier)
                              .updateSelectedStroke(strokeColor: picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _fillControls(context, selectedShape),
                    const SizedBox(height: 12),
                    Text(
                      'Shapes: $shapes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _syncControllers(Shape? shape) {
    if (shape == null) {
      _trackedSignature = null;
      return;
    }
    final bounds = shape.bounds ?? _computeBounds(shape);
    final signature = _shapeSignature(shape, bounds);
    if (_trackedSignature == signature) return;
    _trackedSignature = signature;
    _xCtrl.text = bounds?.left.toStringAsFixed(1) ?? '';
    _yCtrl.text = bounds?.top.toStringAsFixed(1) ?? '';
    _wCtrl.text = bounds?.width.toStringAsFixed(1) ?? '';
    _hCtrl.text = bounds?.height.toStringAsFixed(1) ?? '';
    _strokeCtrl.text = shape.strokeWidth.toStringAsFixed(1);
  }

  bool _hasBounds(Shape shape) => shape.bounds != null;

  Rect? _computeBounds(Shape shape) {
    if (shape.points.isEmpty) return null;
    double minX = shape.points.first.dx;
    double maxX = shape.points.first.dx;
    double minY = shape.points.first.dy;
    double maxY = shape.points.first.dy;
    for (final p in shape.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  String _shapeSignature(Shape shape, Rect? bounds) {
    final b = bounds;
    final boundsSig = b == null
        ? 'n/a'
        : '${b.left.toStringAsFixed(2)},${b.top.toStringAsFixed(2)},${b.width.toStringAsFixed(2)},${b.height.toStringAsFixed(2)}';
    final pointsSig = shape.points.isEmpty
        ? 'p0'
        : 'p${shape.points.length}:${shape.points.first.dx.toStringAsFixed(1)},${shape.points.first.dy.toStringAsFixed(1)}:${shape.points.last.dx.toStringAsFixed(1)},${shape.points.last.dy.toStringAsFixed(1)}';
    return '${shape.id}|$boundsSig|$pointsSig|${shape.strokeWidth.toStringAsFixed(2)}|${shape.strokeColor.value}';
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _stepperGrid(
    BuildContext context, {
    required List<_StepperItem> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _miniButton(
                        context,
                        icon: Icons.remove,
                        onTap: () => item.onStep(-item.step),
                        onHold: () => item.onStep(-item.step),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.value,
                            style: theme.textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _miniButton(
                        context,
                        icon: Icons.add,
                        onTap: () => item.onStep(item.step),
                        onHold: () => item.onStep(item.step),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _miniButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onHold,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onHold?.call(),
      child: SizedBox(
        width: 22,
        height: 22,
        child: Material(
          color: theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _numberRow(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required void Function(double?) onSubmit,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => onSubmit(double.tryParse(v)),
            onEditingComplete: () => onSubmit(double.tryParse(controller.text)),
          ),
        ),
      ],
    );
  }

  Widget _strokeControls(BuildContext context, {required double strokeWidth}) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stroke width',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${strokeWidth.toStringAsFixed(1)} px',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: strokeWidth.clamp(0.5, 40),
              min: 0.5,
              max: 40,
              divisions: 79,
              onChanged: (v) {
                _strokeCtrl.text = v.toStringAsFixed(1);
                _updateStrokeWidth(v, addToHistory: false);
              },
              onChangeEnd: (v) => _updateStrokeWidth(v, addToHistory: true),
              activeColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(
    BuildContext context, {
    required Color selectedColor,
    required ValueChanged<Color> onSelect,
    required Future<Color?> Function() onPickAdvanced,
  }) {
    final palette = <Color>[
      Colors.black,
      Colors.white,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: palette
              .map(
                (c) => GestureDetector(
                  onTap: () => onSelect(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == selectedColor
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                        width: c == selectedColor ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final picked = await onPickAdvanced();
            if (picked != null) {
              onSelect(picked);
            }
          },
          icon: const Icon(Icons.palette_outlined),
          label: const Text('Advanced picker'),
        ),
      ],
    );
  }

  void _updatePosition({double? x, double? y}) {
    ref.read(editorViewModelProvider.notifier).updateSelectedBounds(x: x, y: y);
  }

  void _updateSize({double? width, double? height}) {
    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedBounds(width: width, height: height);
  }

  void _updateStrokeWidth(double? width, {bool addToHistory = true}) {
    if (width == null) return;
    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedStroke(strokeWidth: width, addToHistory: addToHistory);
  }

  void _nudgePosition({double? xDelta, double? yDelta}) {
    final xVal = double.tryParse(_xCtrl.text);
    final yVal = double.tryParse(_yCtrl.text);
    _updatePosition(
      x: xDelta != null && xVal != null ? xVal + xDelta : null,
      y: yDelta != null && yVal != null ? yVal + yDelta : null,
    );
  }

  void _nudgeSize({double? widthDelta, double? heightDelta}) {
    final wVal = double.tryParse(_wCtrl.text);
    final hVal = double.tryParse(_hCtrl.text);
    _updateSize(
      width: widthDelta != null && wVal != null
          ? (wVal + widthDelta).clamp(0, double.infinity)
          : null,
      height: heightDelta != null && hVal != null
          ? (hVal + heightDelta).clamp(0, double.infinity)
          : null,
    );
  }

  // Color parsing helpers retained for potential future use.
  Color? _parseHexColor(String input) {
    var value = input.replaceAll('#', '');
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return null;
    final intColor = int.tryParse(value, radix: 16);
    if (intColor == null) return null;
    return Color(intColor);
  }

  String _colorToHex(Color color, {bool includeAlpha = true}) {
    final value = includeAlpha
        ? color.value
        : (0xFF << 24) | (color.red << 16) | (color.green << 8) | color.blue;
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Widget _swatchRow(
    BuildContext context, {
    required String label,
    required Color color,
    required Future<void> Function() onPick,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          tooltip: 'Pick $label color',
          onPressed: onPick,
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fillControls(BuildContext context, Shape shape) {
    final canFill = FillUtils.canFill(shape);
    final theme = Theme.of(context);
    final vm = ref.read(editorViewModelProvider.notifier);

    return Opacity(
      opacity: canFill ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fill',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: canFill
                    ? 'Pick fill color'
                    : 'Fill requires a closed shape',
                onPressed: canFill
                    ? () async {
                        final picked = await showAdaptiveColorPicker(
                          context: context,
                          initialColor: shape.fillColor ?? shape.strokeColor,
                        );
                        if (picked != null) {
                          vm.updateSelectedFill(picked);
                        }
                      }
                    : null,
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: shape.fillColor ?? Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.25),
                    ),
                  ),
                  child: shape.fillColor == null
                      ? Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (!canFill)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Fill works for closed shapes only',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepperItem {
  const _StepperItem({
    required this.label,
    required this.value,
    required this.onStep,
    this.step = 1,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final double step;
  final void Function(double delta) onStep;
  final bool fullWidth;
}
