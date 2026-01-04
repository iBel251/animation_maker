import 'dart:ui';
import 'dart:math' as math;

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/domain/services/quadtree.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/presentation/painting/raster_controller.dart';
import 'package:animation_maker/presentation/screens/editor/history_manager.dart';
import 'package:animation_maker/presentation/screens/editor/shape_transformer.dart';
import 'package:animation_maker/presentation/screens/editor/clipboard_service.dart';
import 'package:animation_maker/presentation/screens/editor/tool_state_toggles.dart';
import 'package:animation_maker/presentation/screens/editor/selection_service.dart';
import 'package:animation_maker/presentation/screens/editor/selection_types.dart';
import 'package:animation_maker/presentation/screens/editor/shape_drawing_service.dart';
import 'package:animation_maker/presentation/screens/editor/document_service.dart';
import 'package:animation_maker/presentation/screens/editor/stroke_drawing_service.dart';
import 'package:animation_maker/presentation/screens/editor/transform_service.dart';
import 'package:animation_maker/presentation/screens/editor/selection_utils.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

enum EditorTool { brush, shape, select }

class EditorState {
  const EditorState({
    required this.shapes,
    required this.activeTool,
    required this.selectedShapeId,
    required this.selectedShapeIds,
    required this.currentFrame,
    required this.isPropertiesOpen,
    required this.shapeDrawKind,
    required this.currentColor,
    required this.isPanMode,
    required this.currentBrush,
    required this.rasterLayer,
    required this.brushThickness,
    required this.brushOpacity,
    required this.brushSmoothness,
    required this.isToolPanelOpen,
    required this.inProgressStroke,
    required this.palmRejectionEnabled,
    required this.brushVectorMode,
    required this.groupingEnabled,
    required this.currentGroupId,
    required this.transformGroupAsOne,
    required this.selectionMode,
    required this.pivotSnapEnabled,
    required this.pivotSnapStrength,
    required this.pivotFlipWithObject,
    this.shapeFillColor,
  });

  factory EditorState.initial() => const EditorState(
    shapes: <Shape>[],
    activeTool: EditorTool.brush,
    selectedShapeId: null,
    selectedShapeIds: <String>[],
    currentFrame: 0,
    isPropertiesOpen: false,
    shapeDrawKind: ShapeKind.rectangle,
    currentColor: Color(0xFF000000),
    isPanMode: false,
    currentBrush: BrushType.standard,
    rasterLayer: null,
    brushThickness: 4.0,
    brushOpacity: 1.0,
    brushSmoothness: 0.35,
    isToolPanelOpen: false,
    inProgressStroke: const <PointVector>[],
    palmRejectionEnabled: false,
    brushVectorMode: false,
    groupingEnabled: false,
    currentGroupId: null,
    transformGroupAsOne: false,
    selectionMode: SelectionMode.single,
    pivotSnapEnabled: true,
    pivotSnapStrength: 0.5,
    pivotFlipWithObject: true,
    shapeFillColor: null,
  );

  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final int currentFrame;
  final bool isPropertiesOpen;
  final ShapeKind shapeDrawKind;
  final Color currentColor;
  final bool isPanMode;
  final BrushType currentBrush;
  final Image? rasterLayer;
  final double brushThickness;
  final double brushOpacity;
  final double brushSmoothness;
  final bool isToolPanelOpen;
  final List<PointVector> inProgressStroke;
  final bool palmRejectionEnabled;
  final bool brushVectorMode;
  final bool groupingEnabled;
  final String? currentGroupId;
  final bool transformGroupAsOne;
  final SelectionMode selectionMode;
  final Color? shapeFillColor;
  final bool pivotSnapEnabled;
  final double pivotSnapStrength;
  final bool pivotFlipWithObject;

  EditorState copyWith({
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
    List<String>? selectedShapeIds,
    int? currentFrame,
    bool? isPropertiesOpen,
    bool clearSelection = false,
    ShapeKind? shapeDrawKind,
    Color? currentColor,
    bool? isPanMode,
    BrushType? currentBrush,
    Image? rasterLayer,
    double? brushThickness,
    double? brushOpacity,
    double? brushSmoothness,
    bool? isToolPanelOpen,
    List<PointVector>? inProgressStroke,
    bool? palmRejectionEnabled,
    bool? brushVectorMode,
    bool? groupingEnabled,
    String? currentGroupId,
    bool? transformGroupAsOne,
    SelectionMode? selectionMode,
    Color? shapeFillColor,
    bool? pivotSnapEnabled,
    double? pivotSnapStrength,
    bool? pivotFlipWithObject,
  }) {
    return EditorState(
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId: clearSelection
          ? null
          : (selectedShapeId ?? this.selectedShapeId),
      selectedShapeIds: clearSelection
          ? const []
          : (selectedShapeIds ?? this.selectedShapeIds),
      currentFrame: currentFrame ?? this.currentFrame,
      isPropertiesOpen: isPropertiesOpen ?? this.isPropertiesOpen,
      shapeDrawKind: shapeDrawKind ?? this.shapeDrawKind,
      currentColor: currentColor ?? this.currentColor,
      isPanMode: isPanMode ?? this.isPanMode,
      currentBrush: currentBrush ?? this.currentBrush,
      rasterLayer: rasterLayer ?? this.rasterLayer,
      brushThickness: brushThickness ?? this.brushThickness,
      brushOpacity: brushOpacity ?? this.brushOpacity,
      brushSmoothness: brushSmoothness ?? this.brushSmoothness,
      isToolPanelOpen: isToolPanelOpen ?? this.isToolPanelOpen,
      inProgressStroke: inProgressStroke != null
          ? List<PointVector>.unmodifiable(inProgressStroke)
          : this.inProgressStroke,
      palmRejectionEnabled: palmRejectionEnabled ?? this.palmRejectionEnabled,
      brushVectorMode: brushVectorMode ?? this.brushVectorMode,
      groupingEnabled: groupingEnabled ?? this.groupingEnabled,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      transformGroupAsOne: transformGroupAsOne ?? this.transformGroupAsOne,
      selectionMode: selectionMode ?? this.selectionMode,
      shapeFillColor: shapeFillColor ?? this.shapeFillColor,
      pivotSnapEnabled: pivotSnapEnabled ?? this.pivotSnapEnabled,
      pivotSnapStrength: pivotSnapStrength ?? this.pivotSnapStrength,
      pivotFlipWithObject: pivotFlipWithObject ?? this.pivotFlipWithObject,
    );
  }
}

class EditorViewModel extends Notifier<EditorState> {
  final DocumentService _document = DocumentService();
  final RasterController _rasterController = RasterController();
  final ToolStateToggles _toolToggles = ToolStateToggles();
  final SelectionService _selectionService = const SelectionService();
  final ShapeDrawingService _shapeDrawingService = const ShapeDrawingService();
  late final StrokeDrawingService _strokeDrawingService = StrokeDrawingService(
    _rasterController,
  );
  final TransformService _transformService = const TransformService();
  final SelectionUtils _selectionUtils = const SelectionUtils();
  int _groupCounter = 0;
  final EditorClipboard _clipboard = EditorClipboard();
  @override
  EditorState build() {
    final initial = EditorState.initial();
    _document.resetHistory(
      shapes: initial.shapes,
      strokes: const [],
      selectedId: initial.selectedShapeId,
    );
    _document.rebuildQuadTree(initial.shapes);
    return initial;
  }

  int _shapeCounter = 0;
  String? _currentDrawingId;
  Offset? _shapeStartPoint;
  Offset? _lastLineEnd;
  bool _applyingHistory = false;
  bool _pendingHistoryPush = false;

  void setActiveTool(EditorTool tool) {
    final clearSelection = tool != EditorTool.select;
    state = _toolToggles
        .deactivatePan(state)
        .copyWith(
          activeTool: tool,
          selectedShapeId: clearSelection ? null : state.selectedShapeId,
          clearSelection: clearSelection,
          groupingEnabled: tool == EditorTool.brush
              ? state.groupingEnabled
              : false,
          currentGroupId: tool == EditorTool.brush
              ? state.currentGroupId
              : null,
        );
    if (tool != EditorTool.brush && _strokeDrawingService.isDrawing) {
      final cancel = _strokeDrawingService.cancel();
      if (cancel.cancelled) {
        state = state.copyWith(inProgressStroke: cancel.inProgress);
      }
    }
    if (tool != EditorTool.shape) {
      _lastLineEnd = null;
    }
  }

  void setSelectionMode(SelectionMode mode) {
    final change = _selectionService.setSelectionMode(
      _selectionContext(),
      mode,
    );
    state = state.copyWith(
      selectionMode: mode,
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  void setSelection(List<String> ids) {
    final change = _selectionService.setSelection(ids);
    state = state.copyWith(
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  void setPivotSnap({bool? enabled, double? strength}) {
    state = state.copyWith(
      pivotSnapEnabled: enabled ?? state.pivotSnapEnabled,
      pivotSnapStrength: strength ?? state.pivotSnapStrength,
    );
  }

  void setPivotFlipWithObject(bool flip) {
    state = state.copyWith(pivotFlipWithObject: flip);
  }

  void selectShape(String? shapeId) {
    state = state.copyWith(
      selectedShapeId: shapeId,
      clearSelection: shapeId == null,
    );
  }

  void setShapes(List<Shape> shapes) {
    _setShapesAndRebuild(shapes);
    _pushHistory();
  }

  void setCurrentFrame(int frame) {
    state = state.copyWith(currentFrame: frame);
  }

  void updateCanvasSize(Size size) {
    _rasterController.updateSize(size);
  }

  void togglePropertiesPanel() {
    state = _toolToggles.toggleProperties(state);
  }

  void toggleToolPanel() {
    state = _toolToggles.toggleToolPanel(state);
  }

  bool get canUndo => _document.history.canUndo;
  bool get canRedo => _document.history.canRedo;
  bool get canPaste => _clipboard.hasContent;

  Future<void> undo() async {
    final snap = _document.undo();
    if (snap == null) return;
    await _applySnapshot(snap);
  }

  Future<void> redo() async {
    final snap = _document.redo();
    if (snap == null) return;
    await _applySnapshot(snap);
  }

  void setShapeDrawKind(ShapeKind kind) {
    state = state.copyWith(shapeDrawKind: kind);
  }

  void copySelection() {
    final id = state.selectedShapeId;
    if (id == null) return;
    final targets = _selectedGroupShapes();
    if (targets.isEmpty) return;
    _clipboard.copyShapes(targets);
    // Emit a state copy to refresh listeners (e.g., enabling Paste button).
    state = state.copyWith();
  }

  void pasteClipboard() {
    if (!_clipboard.hasContent) return;
    final clones = _clipboard.pasteClones(
      _nextShapeId,
      offset: const Offset(16, 16),
    );
    if (clones.isEmpty) return;
    final updated = [...state.shapes, ...clones];
    _setShapesAndRebuild(updated, selectedShapeId: clones.last.id);
    _pushHistory();
  }

  void flipSelectedHorizontal() {
    _flipSelected(horizontal: true);
  }

  void flipSelectedVertical() {
    _flipSelected(vertical: true);
  }

  void _flipSelected({bool horizontal = false, bool vertical = false}) {
    final id = state.selectedShapeId;
    if (id == null) return;
    final idx = state.shapes.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final target = state.shapes[idx];
    final flipped = ShapeTransformer.flip(
      shape: target,
      horizontal: horizontal,
      vertical: vertical,
      flipPivotWithObject: state.pivotFlipWithObject,
    );
    final updated = List<Shape>.from(state.shapes);
    updated[idx] = flipped;
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
    _pushHistory();
  }

  void duplicateSelected() {
    final targets = _selectedGroupShapes();
    if (targets.isEmpty) return;
    final newGroupId = targets.first.groupId != null ? _nextGroupId() : null;
    final clones = targets
        .map(
          (shape) => shape.copyWith(
            id: _nextShapeId(),
            groupId: newGroupId,
            bounds: shape.bounds?.shift(const Offset(16, 16)),
            points: shape.points.isNotEmpty
                ? shape.points.map((p) => p + const Offset(16, 16)).toList()
                : shape.points.toList(),
          ),
        )
        .toList(growable: false);
    final updated = [...state.shapes, ...clones];
    _setShapesAndRebuild(updated, selectedShapeId: clones.last.id);
    _pushHistory();
  }

  void deleteSelected() {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    final updated = List<Shape>.from(state.shapes);
    indices
      ..sort((a, b) => b.compareTo(a))
      ..forEach(updated.removeAt);
    _setShapesAndRebuild(updated, clearSelection: true, selectedShapeId: null);
    _pushHistory();
  }

  void setCurrentColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  /// Replace shapes by id with the provided transformed copies (no history push).
  void applyTransformedShapes(List<Shape> transformed) {
    if (transformed.isEmpty) return;
    final map = {for (final s in transformed) s.id: s};
    bool changed = false;
    final updated = <Shape>[];
    for (final s in state.shapes) {
      final replacement = map[s.id];
      if (replacement != null) {
        updated.add(replacement);
        changed = true;
      } else {
        updated.add(s);
      }
    }
    if (!changed) return;
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
  }

  void togglePanMode() {
    state = _toolToggles.togglePanMode(state);
  }

  void setPanMode(bool enabled) {
    if (state.isPanMode == enabled) return;
    state = state.copyWith(isPanMode: enabled);
  }

  void setBrushType(BrushType brush) {
    state = state.copyWith(currentBrush: brush);
  }

  void setBrushThickness(double value) {
    state = state.copyWith(brushThickness: value.clamp(0.5, 300));
  }

  void setBrushOpacity(double value) {
    state = state.copyWith(brushOpacity: value.clamp(0.05, 1.0));
  }

  void setBrushSmoothness(double value) {
    state = state.copyWith(brushSmoothness: value.clamp(0.0, 1.0));
  }

  void togglePalmRejection() {
    state = state.copyWith(palmRejectionEnabled: !state.palmRejectionEnabled);
  }

  void toggleBrushVectorMode() {
    state = state.copyWith(brushVectorMode: !state.brushVectorMode);
  }

  void toggleGrouping() {
    if (state.groupingEnabled) {
      state = state.copyWith(groupingEnabled: false, currentGroupId: null);
    } else {
      state = state.copyWith(
        groupingEnabled: true,
        currentGroupId: _nextGroupId(),
      );
    }
  }

  void toggleTransformGroupAsOne() {
    state = state.copyWith(transformGroupAsOne: !state.transformGroupAsOne);
  }

  void setShapeFillColor(Color? color) {
    state = state.copyWith(shapeFillColor: color);
  }

  void updateSelectedTransform({
    double? rotation,
    double? scale,
    bool addToHistory = false,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in indices) {
      final target = state.shapes[idx];
      if (target.kind == ShapeKind.line && target.points.length < 2) continue;
      updatedShapes[idx] = ShapeTransformer.applyTransform(
        shape: target,
        rotation: rotation,
        scale: scale,
      );
    }
    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
    if (addToHistory) {
      _pushHistory();
    }
  }

  void scaleSelectedGeometry({
    Rect? baseBounds,
    List<Offset>? basePoints,
    required double scaleX,
    required double scaleY,
    String? shapeId,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    final clampedScaleX = scaleX.clamp(0.05, 10.0);
    final clampedScaleY = scaleY.clamp(0.05, 10.0);

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in indices) {
      final target = state.shapes[idx];
      final usesBounds =
          target.kind == ShapeKind.rectangle ||
          target.kind == ShapeKind.ellipse;
      // Use provided base bounds/points only when scaling a single shape; otherwise use each shape's own geometry.
      final useShared = indices.length == 1;
      final bounds =
          (useShared ? baseBounds : null) ??
          target.bounds ??
          _shapeBounds(target);

      Shape updated = target;
      if (usesBounds && bounds != null) {
        final center = bounds.center;
        final halfW = bounds.width / 2 * clampedScaleX;
        final halfH = bounds.height / 2 * clampedScaleY;
        final newRect = Rect.fromLTRB(
          center.dx - halfW,
          center.dy - halfH,
          center.dx + halfW,
          center.dy + halfH,
        );
        updated = target.copyWith(bounds: newRect);
      } else {
        final points =
            (useShared ? basePoints : null) ?? target.points.toList();
        if (points.isNotEmpty) {
          final boundsFromPoints =
              (useShared ? baseBounds : null) ?? _shapeBounds(target);
          final center = boundsFromPoints?.center ?? points.first;
          final scaledPoints = points
              .map(
                (p) => Offset(
                  center.dx + (p.dx - center.dx) * clampedScaleX,
                  center.dy + (p.dy - center.dy) * clampedScaleY,
                ),
              )
              .toList(growable: false);
          updated = target.copyWith(points: scaledPoints, bounds: null);
        }
      }
      updatedShapes[idx] = updated;
    }

    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
  }

  /// Apply rotation around a common center using a snapshot of shapes.
  void applyRotationFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double deltaAngle,
  }) {
    if (baseShapes.isEmpty || deltaAngle == 0.0) return;
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();
    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _rotateShapeFromCenter(base, center, deltaAngle);
    }
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
  }

  /// Apply scaling to the current selection using a snapshot of base shapes and a common center.
  void applyScaleFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double scaleX,
    required double scaleY,
  }) {
    if (baseShapes.isEmpty) return;
    final sx = scaleX.clamp(0.05, 100.0);
    final sy = scaleY.clamp(0.05, 100.0);
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();
    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _scaleShapeFromCenter(
        base,
        center,
        sx,
        sy,
      ).copyWith(scale: base.scale);
    }
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
  }

  Shape _scaleShapeFromCenter(
    Shape base,
    Offset center,
    double scaleX,
    double scaleY,
  ) {
    return _transformService.scaleShapeFromCenter(base, center, scaleX, scaleY);
  }

  Shape _rotateShapeFromCenter(Shape base, Offset center, double deltaAngle) {
    return _transformService.rotateShapeFromCenter(base, center, deltaAngle);
  }

  void updateSelectedStroke({
    double? strokeWidth,
    Color? strokeColor,
    bool addToHistory = true,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final index in indices) {
      final target = state.shapes[index];
      updatedShapes[index] = target.copyWith(
        strokeWidth: strokeWidth ?? target.strokeWidth,
        strokeColor: strokeColor ?? target.strokeColor,
      );
    }
    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
    if (addToHistory) {
      _pushHistoryDeferred();
    }
  }

  void updateSelectedFill(Color? fillColor, {bool addToHistory = true}) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final index in indices) {
      final target = state.shapes[index];
      updatedShapes[index] = target.copyWith(fillColor: fillColor);
    }
    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
    if (addToHistory) {
      _pushHistoryDeferred();
    }
  }

  void updateSelectedBounds({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    final targetId = state.selectedShapeId;
    if (targetId == null) return;
    final index = state.shapes.indexWhere((s) => s.id == targetId);
    if (index == -1) return;

    final target = state.shapes[index];
    final existingBounds = target.bounds ?? _shapeBounds(target);
    if (existingBounds == null) return;

    final newWidth = (width ?? existingBounds.width)
        .clamp(0, double.infinity)
        .toDouble();
    final newHeight = (height ?? existingBounds.height)
        .clamp(0, double.infinity)
        .toDouble();
    final newRect = Rect.fromLTWH(
      x ?? existingBounds.left,
      y ?? existingBounds.top,
      newWidth,
      newHeight,
    );

    Shape updated;
    if (target.bounds != null) {
      updated = target.copyWith(bounds: newRect);
    } else {
      final delta = newRect.topLeft - existingBounds.topLeft;
      final shiftedPoints = target.points
          .map((p) => p + delta)
          .toList(growable: false);
      updated = target.copyWith(points: shiftedPoints);
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updated;
    _setShapesAndRebuild(updatedShapes);
    _pushHistoryDeferred();
  }

  String _nextShapeId() {
    _shapeCounter += 1;
    return 'shape-$_shapeCounter';
  }

  String _nextGroupId() {
    _groupCounter += 1;
    return 'group-$_groupCounter';
  }

  List<int> _selectedGroupIndices() {
    return _selectionUtils.selectedGroupIndices(
      state.shapes,
      state.selectedShapeId,
    );
  }

  List<Shape> _selectedGroupShapes() {
    return _selectionUtils.selectedGroupShapes(
      state.shapes,
      state.selectedShapeId,
    );
  }

  void startDrawing(Offset point) {
    final result = _strokeDrawingService.start(state, point);
    if (!result.started) return;
    state = state.copyWith(
      selectedShapeId: null,
      clearSelection: result.clearSelection,
      inProgressStroke: result.inProgress,
    );
  }

  void continueDrawing(Offset point) {
    final result = _strokeDrawingService.update(state, point);
    if (!result.updated) return;
    state = state.copyWith(inProgressStroke: result.inProgress);
  }

  Future<void> endDrawing() async {
    final result = await _strokeDrawingService.finish(
      state,
      nextShapeId: _nextShapeId,
      nextGroupId: _nextGroupId,
    );
    if (result.newCurrentGroupId != null &&
        result.newCurrentGroupId != state.currentGroupId) {
      state = state.copyWith(currentGroupId: result.newCurrentGroupId);
    }
    if (result.newShapes.isNotEmpty) {
      final updatedShapes = [...state.shapes, ...result.newShapes];
      _setShapesAndRebuild(
        updatedShapes,
        selectedShapeId: result.selectShapeId,
        clearSelection: result.clearSelection,
      );
      state = state.copyWith(inProgressStroke: const []);
      _pushHistory();
      return;
    }
    if (result.rasterImage != null) {
      state = state.copyWith(
        rasterLayer: result.rasterImage,
        inProgressStroke: const [],
      );
      _pushHistory();
      return;
    }
    state = state.copyWith(inProgressStroke: result.inProgress);
  }

  /// Abort an in-progress stroke without committing it (e.g., multitouch).
  void cancelDrawing() {
    final cancel = _strokeDrawingService.cancel();
    if (cancel.cancelled) {
      state = state.copyWith(inProgressStroke: cancel.inProgress);
    }
  }

  /// Abort an in-progress shape draw and discard the provisional shape.
  void cancelShapeDrawing() {
    if (_currentDrawingId == null) return;
    final idx = state.shapes.indexWhere((s) => s.id == _currentDrawingId);
    if (idx == -1) {
      _currentDrawingId = null;
      _shapeStartPoint = null;
      return;
    }
    final updated = List<Shape>.from(state.shapes)..removeAt(idx);
    _setShapesAndRebuild(updated, rebuildQuadTree: true);
    _currentDrawingId = null;
    _shapeStartPoint = null;
    _lastLineEnd = null;
  }

  void startShapeDrawing(Offset point) {
    if (state.activeTool != EditorTool.shape) return;
    if (_currentDrawingId != null) return;
    final kind = state.shapeDrawKind;
    final start = _shapeDrawingService.maybeSnapLineStart(
      point,
      kind,
      _lastLineEnd,
    );
    final newShape = _shapeDrawingService.createShapeForKind(
      kind: kind,
      start: start,
      id: _nextShapeId(),
      strokeColor: state.currentColor,
      strokeWidth: state.brushThickness,
      opacity: state.brushOpacity,
      fillColor: state.shapeFillColor,
    );
    final updatedShapes = [...state.shapes, newShape];
    _setShapesAndRebuild(updatedShapes, selectedShapeId: newShape.id);
    _currentDrawingId = newShape.id;
    _shapeStartPoint = start;
  }

  void updateShapeDrawing(Offset point) {
    if (_currentDrawingId == null ||
        _shapeStartPoint == null ||
        state.activeTool != EditorTool.shape) {
      return;
    }
    final index = state.shapes.indexWhere(
      (shape) => shape.id == _currentDrawingId,
    );
    if (index == -1) return;

    final target = state.shapes[index];
    final updatedShape = _shapeDrawingService.updateShapeDuringDraw(
      target: target,
      kind: state.shapeDrawKind,
      startPoint: _shapeStartPoint!,
      currentPoint: point,
      minPointDistance: 0.0,
    );

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updatedShape;

    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
  }

  void finishShapeDrawing() {
    if (state.shapeDrawKind == ShapeKind.line &&
        _currentDrawingId != null &&
        _shapeStartPoint != null) {
      final idx = state.shapes.indexWhere(
        (shape) => shape.id == _currentDrawingId,
      );
      if (idx != -1) {
        final target = state.shapes[idx];
        final updatedShape = _shapeDrawingService.finalizeLineShape(
          target: target,
          startPoint: _shapeStartPoint!,
        );
        final endPoint = updatedShape.points.length >= 2
            ? updatedShape.points.last
            : null;
        final updated = List<Shape>.from(state.shapes);
        updated[idx] = updatedShape;
        _setShapesAndRebuild(updated, rebuildQuadTree: false);
        _lastLineEnd = endPoint ?? _shapeStartPoint!;
      }
    } else {
      _lastLineEnd = null;
    }
    _document.rebuildQuadTree(state.shapes);
    _currentDrawingId = null;
    _shapeStartPoint = null;
    _pushHistory();
  }

  void moveSelectedBy(Offset delta) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final updated = List<Shape>.from(state.shapes);
    for (final index in indices) {
      final target = state.shapes[index];
      updated[index] = _translateShape(target, delta);
    }
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
  }

  void selectAtPoint(Offset point) {
    final change = _selectionService.selectAtPoint(
      _selectionContext(),
      point,
      _document.quadTree,
    );
    state = state.copyWith(
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  Shape? topShapeAtPoint(Offset point) {
    return _selectionService.topShapeAtPoint(
      state.shapes,
      point,
      _document.quadTree,
    );
  }

  SelectionContext _selectionContext() => SelectionContext(
    shapes: state.shapes,
    selectionMode: state.selectionMode,
    selectedShapeId: state.selectedShapeId,
    selectedShapeIds: state.selectedShapeIds,
  );

  Shape _translateShape(Shape shape, Offset delta) {
    return _transformService.translate(shape, delta);
  }

  Rect? _shapeBounds(Shape shape) {
    return _transformService.shapeBounds(shape);
  }

  void _setShapesAndRebuild(
    List<Shape> shapes, {
    String? selectedShapeId,
    bool clearSelection = false,
    bool rebuildQuadTree = true,
  }) {
    final immutableShapes = List<Shape>.unmodifiable(shapes);
    state = state.copyWith(
      shapes: immutableShapes,
      selectedShapeId: selectedShapeId,
      clearSelection: clearSelection,
      inProgressStroke: const [],
    );
    if (rebuildQuadTree) {
      _document.rebuildQuadTree(immutableShapes);
    }
  }

  Future<void> _applySnapshot(HistorySnapshot snap) async {
    _strokeDrawingService.cancel();
    _applyingHistory = true;
    _rasterController.replaceStrokes(snap.rasterStrokes);
    final newRaster = await _rasterController.renderAll();
    _setShapesAndRebuild(snap.shapes, selectedShapeId: snap.selectedShapeId);
    state = state.copyWith(rasterLayer: newRaster, inProgressStroke: const []);
    _applyingHistory = false;
  }

  void _pushHistory() {
    if (_applyingHistory) return;
    _document.pushHistory(
      shapes: state.shapes,
      strokes: _rasterController.strokes,
      selectedId: state.selectedShapeId,
    );
  }

  void _pushHistoryDeferred() {
    if (_applyingHistory || _pendingHistoryPush) return;
    _pendingHistoryPush = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingHistoryPush = false;
      if (_applyingHistory) return;
      _document.pushHistory(
        shapes: state.shapes,
        strokes: _rasterController.strokes,
        selectedId: state.selectedShapeId,
      );
    });
  }

  QuadTree get quadTree => _document.quadTree;
  void rebuildQuadTree() => _document.rebuildQuadTree(state.shapes);

  void finalizeSelectionEdit() {
    _pushHistory();
  }
}

final editorViewModelProvider = NotifierProvider<EditorViewModel, EditorState>(
  EditorViewModel.new,
);
