import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';
import 'package:animation_maker/domain/models/shape.dart';

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
    final shapes = widget.shapeCount ??
        ref.watch(editorViewModelProvider.select((state) => state.shapes.length));
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
                    const SizedBox(height: 8),
                    Text(
                      'Shapes: $shapes',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shape: $selectedId',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'Position'),
                    _numberRow(
                      context,
                      label: 'X',
                      controller: _xCtrl,
                      onSubmit: (v) => _updatePosition(x: v),
                    ),
                    const SizedBox(height: 8),
                    _numberRow(
                      context,
                      label: 'Y',
                      controller: _yCtrl,
                      onSubmit: (v) => _updatePosition(y: v),
                    ),
                    if (_hasBounds(selectedShape)) ...[
                      const SizedBox(height: 12),
                      _sectionTitle(context, 'Size'),
                      _numberRow(
                        context,
                        label: 'W',
                        controller: _wCtrl,
                        onSubmit: (v) => _updateSize(width: v),
                      ),
                      const SizedBox(height: 8),
                      _numberRow(
                        context,
                        label: 'H',
                        controller: _hCtrl,
                        onSubmit: (v) => _updateSize(height: v),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'Appearance'),
                    _strokeControls(
                      context,
                      strokeWidth: selectedShape.strokeWidth,
                    ),
                    const SizedBox(height: 12),
                    _colorRow(
                      context,
                      selectedColor: selectedShape.strokeColor,
                      onSelect: (c) =>
                          ref.read(editorViewModelProvider.notifier).updateSelectedStroke(
                                strokeColor: c,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Shapes: $shapes',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.grey.shade700),
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
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(fontWeight: FontWeight.w600),
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _numberRow(
          context,
          label: 'Stroke',
          controller: _strokeCtrl,
          onSubmit: (v) => _updateStrokeWidth(v),
        ),
        Slider(
          value: strokeWidth.clamp(1, 20),
          min: 1,
          max: 20,
          divisions: 19,
          label: strokeWidth.toStringAsFixed(1),
          onChanged: (v) {
            _strokeCtrl.text = v.toStringAsFixed(1);
            _updateStrokeWidth(v);
          },
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _colorRow(
    BuildContext context, {
    required Color selectedColor,
    required ValueChanged<Color> onSelect,
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
    return Wrap(
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
    );
  }

  void _updatePosition({double? x, double? y}) {
    ref.read(editorViewModelProvider.notifier).updateSelectedBounds(
          x: x,
          y: y,
        );
  }

  void _updateSize({double? width, double? height}) {
    ref.read(editorViewModelProvider.notifier).updateSelectedBounds(
          width: width,
          height: height,
        );
  }

  void _updateStrokeWidth(double? width) {
    if (width == null) return;
    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedStroke(strokeWidth: width);
  }
}

