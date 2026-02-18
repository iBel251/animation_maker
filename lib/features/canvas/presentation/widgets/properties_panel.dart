import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_notifier.dart';
import 'package:animation_maker/core/widgets/color_picker_widget.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/style_edit_scope.dart';
import '../services/fill_utils.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/style_edit_scope_toggle.dart';
import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/transform_stepper_field.dart';
import 'dart:math' as math;

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
  final _rCtrl = TextEditingController();
  final _strokeCtrl = TextEditingController();
  final _stepCtrl = TextEditingController(text: '5');
  final _xFocusNode = FocusNode();
  final _yFocusNode = FocusNode();
  final _wFocusNode = FocusNode();
  final _hFocusNode = FocusNode();
  final _rFocusNode = FocusNode();
  final _stepFocusNode = FocusNode();
  bool _transformExpanded = false;
  double _transformStep = 5;

  String? _trackedSignature;

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _rCtrl.dispose();
    _strokeCtrl.dispose();
    _stepCtrl.dispose();
    _xFocusNode.dispose();
    _yFocusNode.dispose();
    _wFocusNode.dispose();
    _hFocusNode.dispose();
    _rFocusNode.dispose();
    _stepFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(editorViewModelProvider.notifier);
    final panelState = ref.watch(
      editorViewModelProvider.select(_PropertiesPanelViewState.fromEditorState),
    );
    final selectedId = panelState.selectedId;
    final shapes = widget.shapeCount ?? panelState.shapeCount;
    final styleEditScope = panelState.styleEditScope;
    final selectedShape = panelState.selectedShape;
    final selectedWorldBounds = panelState.selectedWorldBounds;
    final selectedWorldAnchor = panelState.selectedWorldAnchor;

    _syncControllers(
      selectedShape,
      selectedWorldBounds: selectedWorldBounds,
      selectedWorldAnchor: selectedWorldAnchor,
    );

    return Container(
      color: AppColors.grey100,
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
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.interests_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedShape.name == null ||
                                    selectedShape.name!.trim().isEmpty
                                ? 'Shape: $selectedId'
                                : '${selectedShape.name} ($selectedId)',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _transformSection(context, selectedShape),
                    if (selectedShape.kind == ShapeKind.image) ...[
                      const SizedBox(height: 10),
                      _sectionCard(
                        context,
                        title: 'Image',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectedShape.imagePath != null)
                              Text(
                                selectedShape.imagePath!.split('/').last,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.grey700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (selectedShape.imageOriginalSize != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Original: ${selectedShape.imageOriginalSize!.width.toInt()} x ${selectedShape.imageOriginalSize!.height.toInt()}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.grey600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      StyleEditScopeToggle(
                        scope: styleEditScope,
                        onChanged: vm.setStyleEditScope,
                      ),
                      const SizedBox(height: 10),
                      _sectionCard(
                        context,
                        title: 'Appearance',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _strokeControls(
                              context,
                              strokeWidth: selectedShape.strokeWidth,
                            ),
                            const SizedBox(height: 10),
                            _swatchRow(
                              context,
                              label: 'Stroke',
                              color: selectedShape.strokeColor,
                              onPick: () async {
                                final initial = selectedShape.strokeColor;
                                final picked = await showAdaptiveColorPicker(
                                  context: context,
                                  initialColor: initial,
                                  recentColors: ref
                                      .read(editorViewModelProvider)
                                      .document
                                      .recentColors
                                      .map((value) => Color(value))
                                      .toList(growable: false),
                                  onColorChanged: (value) {
                                    ref
                                        .read(editorViewModelProvider.notifier)
                                        .updateSelectedStroke(
                                          strokeColor: value,
                                        );
                                  },
                                );
                                if (picked == null) {
                                  ref
                                      .read(editorViewModelProvider.notifier)
                                      .updateSelectedStroke(
                                        strokeColor: initial,
                                      );
                                  return;
                                }
                                ref
                                    .read(editorViewModelProvider.notifier)
                                    .updateSelectedStroke(strokeColor: picked);
                                ref
                                    .read(editorViewModelProvider.notifier)
                                    .recordProjectColor(picked);
                              },
                            ),
                            const SizedBox(height: 8),
                            _fillControls(context, selectedShape),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Shapes: $shapes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _transformSection(BuildContext context, Shape selectedShape) {
    final items = <_StepperItem>[
      _StepperItem(
        label: 'X',
        controller: _xCtrl,
        focusNode: _xFocusNode,
        onStep: (delta) => _nudgePosition(xDelta: delta),
        onCommit: _commitX,
      ),
      _StepperItem(
        label: 'Y',
        controller: _yCtrl,
        focusNode: _yFocusNode,
        onStep: (delta) => _nudgePosition(yDelta: delta),
        onCommit: _commitY,
      ),
    ];
    if (_hasBounds(selectedShape)) {
      items.addAll(<_StepperItem>[
        _StepperItem(
          label: 'W',
          controller: _wCtrl,
          focusNode: _wFocusNode,
          onStep: (delta) => _nudgeSize(widthDelta: delta),
          onCommit: _commitWidth,
        ),
        _StepperItem(
          label: 'H',
          controller: _hCtrl,
          focusNode: _hFocusNode,
          onStep: (delta) => _nudgeSize(heightDelta: delta),
          onCommit: _commitHeight,
        ),
      ]);
    }
    items.add(
      _StepperItem(
        label: 'R',
        controller: _rCtrl,
        focusNode: _rFocusNode,
        onStep: (delta) => _nudgeRotation(delta),
        onCommit: _commitRotation,
      ),
    );

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _transformExpanded,
        onExpansionChanged: (value) =>
            setState(() => _transformExpanded = value),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.primary,
        title: Text(
          'Transform',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Position and size',
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.grey600),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _transformStepControl(context),
              const SizedBox(height: 8),
              _stepperGrid(context, items: items),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  void _syncControllers(
    Shape? shape, {
    Rect? selectedWorldBounds,
    Offset? selectedWorldAnchor,
  }) {
    if (shape == null) {
      _trackedSignature = null;
      return;
    }
    final localBounds = shape.localBounds;
    final worldBounds = selectedWorldBounds ?? shape.worldBounds ?? localBounds;
    final worldAnchor =
        selectedWorldAnchor ?? worldBounds?.center ?? shape.translation;
    final signature = _shapeSignature(
      shape,
      localBounds: localBounds,
      worldBounds: worldBounds,
      worldAnchor: worldAnchor,
    );
    if (_trackedSignature == signature) return;
    _trackedSignature = signature;
    _syncController(
      controller: _xCtrl,
      focusNode: _xFocusNode,
      value: worldAnchor.dx.toStringAsFixed(1),
    );
    _syncController(
      controller: _yCtrl,
      focusNode: _yFocusNode,
      value: _toDisplayY(worldAnchor.dy).toStringAsFixed(1),
    );
    _syncController(
      controller: _wCtrl,
      focusNode: _wFocusNode,
      value: worldBounds?.width.toStringAsFixed(1) ?? '',
    );
    _syncController(
      controller: _hCtrl,
      focusNode: _hFocusNode,
      value: worldBounds?.height.toStringAsFixed(1) ?? '',
    );
    _syncController(
      controller: _rCtrl,
      focusNode: _rFocusNode,
      value: _toDegrees(shape.rotation).toStringAsFixed(1),
    );
    _strokeCtrl.text = shape.strokeWidth.toStringAsFixed(1);
  }

  void _syncController({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String value,
  }) {
    if (focusNode.hasFocus) return;
    if (controller.text == value) return;
    controller.text = value;
  }

  bool _hasBounds(Shape shape) => shape.bounds != null;

  String _shapeSignature(
    Shape shape, {
    Rect? localBounds,
    Rect? worldBounds,
    Offset? worldAnchor,
  }) {
    final lb = localBounds;
    final wb = worldBounds;
    final wa = worldAnchor;
    final localBoundsSig = lb == null
        ? 'n/a'
        : '${lb.left.toStringAsFixed(2)},${lb.top.toStringAsFixed(2)},${lb.width.toStringAsFixed(2)},${lb.height.toStringAsFixed(2)}';
    final worldBoundsSig = wb == null
        ? 'n/a'
        : '${wb.left.toStringAsFixed(2)},${wb.top.toStringAsFixed(2)},${wb.width.toStringAsFixed(2)},${wb.height.toStringAsFixed(2)}';
    final worldAnchorSig = wa == null
        ? 'n/a'
        : '${wa.dx.toStringAsFixed(2)},${wa.dy.toStringAsFixed(2)}';
    final allPoints = shape.contours.isNotEmpty
        ? shape.contours.expand((c) => c).toList(growable: false)
        : shape.points;
    final pointsSig = allPoints.isEmpty
        ? 'p0'
        : 'p${allPoints.length}:${allPoints.first.dx.toStringAsFixed(1)},${allPoints.first.dy.toStringAsFixed(1)}:${allPoints.last.dx.toStringAsFixed(1)},${allPoints.last.dy.toStringAsFixed(1)}';
    return '${shape.id}|$localBoundsSig|$worldBoundsSig|$worldAnchorSig|$pointsSig|${shape.translation.dx.toStringAsFixed(2)},${shape.translation.dy.toStringAsFixed(2)}|${shape.rotation.toStringAsFixed(4)}|${shape.scaleX.toStringAsFixed(3)},${shape.scaleY.toStringAsFixed(3)}|${shape.strokeWidth.toStringAsFixed(2)}|${shape.strokeColor.toARGB32()}';
  }

  Widget _stepperGrid(
    BuildContext context, {
    required List<_StepperItem> items,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.0;
        // Keep enough room for fixed controls (+/- buttons, label) and
        // value text at normal desktop scaling to avoid RenderFlex overflow.
        const minTileWidth = 124.0;
        final twoColumnWidth = (constraints.maxWidth - spacing) / 2;
        final columns = twoColumnWidth >= minTileWidth ? 2 : 1;
        final tileWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.12),
                      ),
                    ),
                    child: TransformStepperField(
                      label: item.label,
                      controller: item.controller,
                      focusNode: item.focusNode,
                      step: _currentTransformStep(),
                      onStep: item.onStep,
                      onCommit: item.onCommit,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _strokeControls(BuildContext context, {required double strokeWidth}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stroke width',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${strokeWidth.toStringAsFixed(1)} px',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
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
    );
  }

  void _updatePosition({double? x, double? y}) {
    final anchor = _selectedWorldAnchor();
    if (anchor == null) return;
    final nextX = x ?? anchor.dx;
    final currentDisplayY = _toDisplayY(anchor.dy);
    final nextDisplayY = y ?? currentDisplayY;
    final nextY = _fromDisplayY(nextDisplayY);
    final delta = Offset(nextX - anchor.dx, nextY - anchor.dy);
    if (delta == Offset.zero) return;
    ref.read(editorViewModelProvider.notifier).moveSelectedBy(delta);
  }

  void _updateSize({double? width, double? height}) {
    final selectedShape = ref.read(editorViewModelProvider).selectedShape;
    if (selectedShape == null) return;
    final localBounds = selectedShape.localBounds;
    final worldBounds = selectedShape.worldBounds ?? localBounds;
    if (localBounds == null || worldBounds == null) return;

    // W/H fields display world bounds; convert requested world size back to
    // local size before writing geometry bounds.
    final nextLocalWidth = width == null || worldBounds.width.abs() < 0.0001
        ? null
        : width * (localBounds.width / worldBounds.width);
    final nextLocalHeight = height == null || worldBounds.height.abs() < 0.0001
        ? null
        : height * (localBounds.height / worldBounds.height);

    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedBounds(width: nextLocalWidth, height: nextLocalHeight);
  }

  Offset? _selectedWorldAnchor() {
    final selectedShape = ref.read(editorViewModelProvider).selectedShape;
    if (selectedShape == null) return null;
    final bounds = selectedShape.worldBounds ?? selectedShape.localBounds;
    return bounds?.center ?? selectedShape.translation;
  }

  // Properties panel uses Cartesian-style Y for users:
  // positive Y goes upward, while engine world-space Y grows downward.
  double _toDisplayY(double worldY) => -worldY;
  double _fromDisplayY(double displayY) => -displayY;
  double _toDegrees(double radians) => radians * 180 / math.pi;
  double _toRadians(double degrees) => degrees * math.pi / 180;

  void _updateStrokeWidth(double? width, {bool addToHistory = true}) {
    if (width == null) return;
    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedStroke(strokeWidth: width, addToHistory: addToHistory);
  }

  void _updateRotationDegrees(double? degrees, {bool addToHistory = true}) {
    if (degrees == null) return;
    ref
        .read(editorViewModelProvider.notifier)
        .updateSelectedTransform(
          rotation: _toRadians(degrees),
          addToHistory: addToHistory,
        );
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

  void _nudgeRotation(double deltaDegrees) {
    final current = double.tryParse(_rCtrl.text);
    if (current == null) return;
    _updateRotationDegrees(current + deltaDegrees, addToHistory: true);
  }

  void _commitX() {
    final value = double.tryParse(_xCtrl.text);
    if (value == null) return;
    _updatePosition(x: value);
  }

  void _commitY() {
    final value = double.tryParse(_yCtrl.text);
    if (value == null) return;
    _updatePosition(y: value);
  }

  void _commitWidth() {
    final value = double.tryParse(_wCtrl.text);
    if (value == null) return;
    _updateSize(width: value.clamp(0, double.infinity).toDouble());
  }

  void _commitHeight() {
    final value = double.tryParse(_hCtrl.text);
    if (value == null) return;
    _updateSize(height: value.clamp(0, double.infinity).toDouble());
  }

  void _commitRotation() {
    final value = double.tryParse(_rCtrl.text);
    if (value == null) return;
    _updateRotationDegrees(value, addToHistory: true);
  }

  double _currentTransformStep() {
    final parsed = double.tryParse(_stepCtrl.text.trim());
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return _transformStep;
  }

  void _commitTransformStep() {
    final parsed = double.tryParse(_stepCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      _stepCtrl.text = _formatStep(_transformStep);
      return;
    }
    final normalized = parsed.clamp(0.1, 10000).toDouble();
    if (_transformStep == normalized) {
      _stepCtrl.text = _formatStep(normalized);
      return;
    }
    setState(() {
      _transformStep = normalized;
      _stepCtrl.text = _formatStep(normalized);
    });
  }

  String _formatStep(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

  Widget _transformStepControl(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Step',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.grey700,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: TextField(
            controller: _stepCtrl,
            focusNode: _stepFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
            onSubmitted: (_) => _commitTransformStep(),
            onTapOutside: (_) {
              _commitTransformStep();
              _stepFocusNode.unfocus();
            },
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
                        final initial = shape.fillColor ?? shape.strokeColor;
                        final picked = await showAdaptiveColorPicker(
                          context: context,
                          initialColor: initial,
                          recentColors: ref
                              .read(editorViewModelProvider)
                              .document
                              .recentColors
                              .map((value) => Color(value))
                              .toList(growable: false),
                          onColorChanged: (value) =>
                              vm.updateSelectedFill(value),
                        );
                        if (picked == null) {
                          vm.updateSelectedFill(shape.fillColor);
                          return;
                        }
                        vm.updateSelectedFill(picked);
                        vm.recordProjectColor(picked);
                      }
                    : null,
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: shape.fillColor ?? AppColors.transparent,
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
                  color: AppColors.grey600,
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
    required this.controller,
    required this.focusNode,
    required this.onStep,
    required this.onCommit,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(double delta) onStep;
  final VoidCallback onCommit;
}

class _PropertiesPanelViewState {
  const _PropertiesPanelViewState({
    required this.selectedId,
    required this.selectedShape,
    required this.selectedWorldBounds,
    required this.selectedWorldAnchor,
    required this.selectedShapeSignature,
    required this.shapeCount,
    required this.styleEditScope,
  });

  factory _PropertiesPanelViewState.fromEditorState(EditorState state) {
    final selectedId = state.selectedShapeId;
    Shape? selectedShape;
    if (selectedId != null) {
      for (final shape in state.shapes) {
        if (shape.id == selectedId) {
          selectedShape = shape;
          break;
        }
      }
    }
    return _PropertiesPanelViewState(
      selectedId: selectedId,
      selectedShape: selectedShape,
      selectedWorldBounds:
          selectedShape?.worldBounds ?? selectedShape?.localBounds,
      selectedWorldAnchor:
          (selectedShape?.worldBounds ?? selectedShape?.localBounds)?.center ??
          selectedShape?.translation,
      selectedShapeSignature: _selectedShapeSignature(selectedShape),
      shapeCount: state.shapes.length,
      styleEditScope: state.styleEditScope,
    );
  }

  final String? selectedId;
  final Shape? selectedShape;
  final Rect? selectedWorldBounds;
  final Offset? selectedWorldAnchor;
  final String selectedShapeSignature;
  final int shapeCount;
  final StyleEditScope styleEditScope;

  static String _selectedShapeSignature(Shape? shape) {
    if (shape == null) return '';
    final bounds = shape.localBounds;
    final fillColor = shape.fillColor?.toARGB32() ?? -1;
    final imageSize = shape.imageOriginalSize;
    return <Object>[
      shape.id,
      shape.kind.index,
      shape.name ?? '',
      shape.isVisible ? 1 : 0,
      shape.isLocked ? 1 : 0,
      bounds?.left.toStringAsFixed(2) ?? 'n/a',
      bounds?.top.toStringAsFixed(2) ?? 'n/a',
      bounds?.width.toStringAsFixed(2) ?? 'n/a',
      bounds?.height.toStringAsFixed(2) ?? 'n/a',
      shape.strokeWidth.toStringAsFixed(2),
      shape.strokeColor.toARGB32(),
      fillColor,
      shape.opacity.toStringAsFixed(3),
      shape.translation.dx.toStringAsFixed(2),
      shape.translation.dy.toStringAsFixed(2),
      shape.rotation.toStringAsFixed(4),
      shape.scaleX.toStringAsFixed(3),
      shape.scaleY.toStringAsFixed(3),
      shape.transform.pivot.dx.toStringAsFixed(2),
      shape.transform.pivot.dy.toStringAsFixed(2),
      shape.imagePath ?? '',
      imageSize?.width.toStringAsFixed(1) ?? 'n/a',
      imageSize?.height.toStringAsFixed(1) ?? 'n/a',
    ].join('|');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PropertiesPanelViewState &&
        other.selectedId == selectedId &&
        other.selectedShapeSignature == selectedShapeSignature &&
        other.selectedWorldBounds == selectedWorldBounds &&
        other.selectedWorldAnchor == selectedWorldAnchor &&
        other.shapeCount == shapeCount &&
        other.styleEditScope == styleEditScope;
  }

  @override
  int get hashCode => Object.hash(
    selectedId,
    selectedShapeSignature,
    selectedWorldBounds,
    selectedWorldAnchor,
    shapeCount,
    styleEditScope,
  );
}
