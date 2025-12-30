import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/domain/services/quadtree.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/presentation/painting/brush_stroke_factory.dart';
import 'package:animation_maker/presentation/painting/raster_controller.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:animation_maker/presentation/screens/editor/history_manager.dart';
import 'package:animation_maker/presentation/screens/editor/shape_transformer.dart';
import 'package:animation_maker/presentation/screens/editor/tool_state_toggles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

enum EditorTool {
  brush,
  shape,
  select,
}

class EditorState {
  const EditorState({
    required this.shapes,
    required this.activeTool,
    required this.selectedShapeId,
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
    this.shapeFillColor,
  });

  factory EditorState.initial() => const EditorState(
        shapes: <Shape>[],
        activeTool: EditorTool.brush,
        selectedShapeId: null,
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
        shapeFillColor: null,
      );

  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
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
  final Color? shapeFillColor;

  EditorState copyWith({
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
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
    Color? shapeFillColor,
  }) {
    return EditorState(
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId:
          clearSelection ? null : (selectedShapeId ?? this.selectedShapeId),
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
      palmRejectionEnabled:
          palmRejectionEnabled ?? this.palmRejectionEnabled,
      brushVectorMode: brushVectorMode ?? this.brushVectorMode,
      shapeFillColor: shapeFillColor ?? this.shapeFillColor,
    );
  }
}

class EditorViewModel extends Notifier<EditorState> {
  final Rect _quadBoundary = const Rect.fromLTWH(0, 0, 5000, 5000);
  late QuadTree _quadTree;
  final RasterController _rasterController = RasterController();
  final HistoryManager _history = HistoryManager();
  final ToolStateToggles _toolToggles = ToolStateToggles();
  @override
  EditorState build() {
    _quadTree = QuadTree(boundary: _quadBoundary);
    final initial = EditorState.initial();
    _history.reset();
    _history.push(
      shapes: initial.shapes,
      strokes: const [],
      selectedId: initial.selectedShapeId,
    );
    return initial;
  }

  int _shapeCounter = 0;
  String? _currentDrawingId;
  Offset? _shapeStartPoint;
  Offset? _lastLineEnd;
  bool _applyingHistory = false;
  final List<PointVector> _currentStrokePoints = [];
  bool _isDrawingStroke = false;

  void setActiveTool(EditorTool tool) {
    state = _toolToggles.deactivatePan(state).copyWith(activeTool: tool);
    if (tool != EditorTool.brush && _isDrawingStroke) {
      _resetStrokeState();
      state = state.copyWith(inProgressStroke: const []);
    }
    if (tool != EditorTool.shape) {
      _lastLineEnd = null;
    }
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

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  Future<void> undo() async {
    final snap = _history.undo();
    if (snap == null) return;
    await _applySnapshot(snap);
  }

  Future<void> redo() async {
    final snap = _history.redo();
    if (snap == null) return;
    await _applySnapshot(snap);
  }

  void setShapeDrawKind(ShapeKind kind) {
    state = state.copyWith(shapeDrawKind: kind);
  }

  void setCurrentColor(Color color) {
    state = state.copyWith(currentColor: color);
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

  void setShapeFillColor(Color? color) {
    state = state.copyWith(shapeFillColor: color);
  }

  void updateSelectedTransform({
    double? rotation,
    double? scale,
    bool addToHistory = false,
  }) {
    final targetId = state.selectedShapeId;
    if (targetId == null) return;
    final idx = state.shapes.indexWhere((s) => s.id == targetId);
    if (idx == -1) return;
    final target = state.shapes[idx];
    if (target.kind == ShapeKind.line && target.points.length < 2) return;
    final updated = ShapeTransformer.applyTransform(
      shape: target,
      rotation: rotation,
      scale: scale,
    );
    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[idx] = updated;
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
    final targetId = shapeId ?? state.selectedShapeId;
    if (targetId == null) return;
    final idx = state.shapes.indexWhere((s) => s.id == targetId);
    if (idx == -1) return;
    final target = state.shapes[idx];
    final clampedScaleX = scaleX.clamp(0.05, 100.0);
    final clampedScaleY = scaleY.clamp(0.05, 100.0);

    Shape updated = target;
    final usesBounds =
        target.kind == ShapeKind.rectangle || target.kind == ShapeKind.ellipse;
    final bounds = baseBounds ?? target.bounds;

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
      final points = basePoints ?? target.points.toList();
      if (points.isNotEmpty) {
        final boundsFromPoints = baseBounds ?? _shapeBounds(target);
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

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[idx] = updated;
    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
  }

  void updateSelectedStroke({
    double? strokeWidth,
    Color? strokeColor,
    bool addToHistory = true,
  }) {
    final targetId = state.selectedShapeId;
    if (targetId == null) return;
    final index = state.shapes.indexWhere((s) => s.id == targetId);
    if (index == -1) return;

    final target = state.shapes[index];
    final updated = target.copyWith(
      strokeWidth: strokeWidth ?? target.strokeWidth,
      strokeColor: strokeColor ?? target.strokeColor,
    );
    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updated;
    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
    if (addToHistory) {
      _pushHistory();
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

    final newWidth =
        (width ?? existingBounds.width).clamp(0, double.infinity).toDouble();
    final newHeight =
        (height ?? existingBounds.height).clamp(0, double.infinity).toDouble();
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
      final shiftedPoints =
          target.points.map((p) => p + delta).toList(growable: false);
      updated = target.copyWith(points: shiftedPoints);
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updated;
    _setShapesAndRebuild(updatedShapes);
    _pushHistory();
  }

  String _nextShapeId() {
    _shapeCounter += 1;
    return 'shape-$_shapeCounter';
  }

  void startDrawing(Offset point) {
    if (state.activeTool != EditorTool.brush) return;
    if (_isDrawingStroke) return;
    state = state.copyWith(selectedShapeId: null, clearSelection: true);
    _currentStrokePoints
      ..clear()
      ..add(PointVector.fromOffset(offset: point, pressure: 1.0));
    state = state.copyWith(
      inProgressStroke: List<PointVector>.from(_currentStrokePoints),
    );
    _isDrawingStroke = true;
  }

  void continueDrawing(Offset point) {
    if (!_isDrawingStroke || state.activeTool != EditorTool.brush) {
      return;
    }
    final filtered = point;
    final lastVector =
        _currentStrokePoints.isNotEmpty ? _currentStrokePoints.last : null;
    final lastPoint =
        lastVector != null ? Offset(lastVector.x, lastVector.y) : null;

    _currentStrokePoints
        .add(PointVector.fromOffset(offset: filtered, pressure: 1.0));
    state = state.copyWith(
      inProgressStroke: List<PointVector>.from(_currentStrokePoints),
    );
  }

  Future<void> endDrawing() async {
    if (!_isDrawingStroke) {
      return;
    }
    final rasterPoints = _currentStrokePoints.isNotEmpty
        ? List<PointVector>.from(_currentStrokePoints)
        : <PointVector>[];
    if (rasterPoints.isEmpty) {
      _resetStrokeState();
      state = state.copyWith(inProgressStroke: const []);
      return;
    }
    final strokeResult = BrushStrokeFactory.build(
      asVector: state.brushVectorMode,
      vectorId: _nextShapeId(),
      points: rasterPoints,
      color: state.currentColor,
      thickness: state.brushThickness,
      opacity: state.brushOpacity,
      thinning: _strokeThinning(),
      smoothing: _strokeSmoothing(state.brushSmoothness),
      streamline: _strokeStreamline(state.brushSmoothness),
      simulatePressure: true,
      brushType: state.currentBrush,
    );

    if (strokeResult.isVector && strokeResult.vectorShape != null) {
      final updatedShapes = [...state.shapes, strokeResult.vectorShape!];
      _setShapesAndRebuild(
        updatedShapes,
        selectedShapeId: strokeResult.vectorShape!.id,
      );
      state = state.copyWith(inProgressStroke: const []);
      _pushHistory();
      _resetStrokeState();
      return;
    }

    final newRaster = await _rasterController.addStroke(
      strokeResult.rasterStroke!,
    );

    state = state.copyWith(
      rasterLayer: newRaster,
      inProgressStroke: const [],
    );
    _pushHistory();

    _resetStrokeState();
  }

  /// Abort an in-progress stroke without committing it (e.g., multitouch).
  void cancelDrawing() {
    if (!_isDrawingStroke) return;
    _resetStrokeState();
    state = state.copyWith(inProgressStroke: const []);
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
    final start = _maybeSnapLineStart(point, kind);
    final newShape = _createShapeForKind(kind, start);
    final updatedShapes = [...state.shapes, newShape];
    _setShapesAndRebuild(
      updatedShapes,
      selectedShapeId: newShape.id,
    );
    _currentDrawingId = newShape.id;
    _shapeStartPoint = start;
  }

  void updateShapeDrawing(Offset point) {
    if (_currentDrawingId == null ||
        _shapeStartPoint == null ||
        state.activeTool != EditorTool.shape) {
      return;
    }
    final index =
        state.shapes.indexWhere((shape) => shape.id == _currentDrawingId);
    if (index == -1) return;

    final target = state.shapes[index];
    Shape updatedShape = target;
    switch (state.shapeDrawKind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
        final rect = Rect.fromPoints(_shapeStartPoint!, point);
        updatedShape = target.copyWith(bounds: rect);
        break;
      case ShapeKind.line:
        final filtered = point;
        final lastPoint = target.points.isNotEmpty ? target.points.last : null;
        if (lastPoint != null &&
            (lastPoint - filtered).distance < _minPointDistanceForBrush()) {
          break;
        }
        updatedShape =
            target.copyWith(points: [_shapeStartPoint!, filtered]);
        break;
      case ShapeKind.polygon:
        // Use triangle defined by start + current as bounding box.
        final triPoints = _trianglePoints(_shapeStartPoint!, point);
        updatedShape = target.copyWith(points: triPoints);
        break;
      case ShapeKind.freehand:
        break;
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updatedShape;

    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
  }

  void finishShapeDrawing() {
    if (state.shapeDrawKind == ShapeKind.line &&
        _currentDrawingId != null &&
        _shapeStartPoint != null) {
      final idx =
          state.shapes.indexWhere((shape) => shape.id == _currentDrawingId);
      if (idx != -1) {
        final target = state.shapes[idx];
        final endPoint =
            target.points.length >= 2 ? target.points.last : _shapeStartPoint!;
        final updatedShape =
            target.copyWith(points: [_shapeStartPoint!, endPoint]);
        final updated = List<Shape>.from(state.shapes);
        updated[idx] = updatedShape;
        _setShapesAndRebuild(updated, rebuildQuadTree: false);
        _lastLineEnd = endPoint;
      }
    } else {
      _lastLineEnd = null;
    }
    _rebuildQuadTree(state.shapes);
    _currentDrawingId = null;
    _shapeStartPoint = null;
    _pushHistory();
  }

  void moveSelectedBy(Offset delta) {
    final targetId = state.selectedShapeId;
    if (targetId == null) return;
    final index = state.shapes.indexWhere((s) => s.id == targetId);
    if (index == -1) return;

    final target = state.shapes[index];
    final moved = _translateShape(target, delta);
    final updated = List<Shape>.from(state.shapes);
    updated[index] = moved;
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
  }

  void selectAtPoint(Offset point) {
    // Use QuadTree for initial culling, then pick top-most by list order.
    final candidates = quadTree.queryPoint(point);
    String? hitId;

    if (candidates.isNotEmpty) {
      // Choose the last shape in state.shapes that is also a candidate.
      for (var i = state.shapes.length - 1; i >= 0; i--) {
        final shape = state.shapes[i];
        if (candidates.contains(shape) && _hitTest(shape, point)) {
          hitId = shape.id;
          break;
        }
      }
    } else {
      // Fallback linear search (reverse order) without QuadTree overlap.
      for (var i = state.shapes.length - 1; i >= 0; i--) {
        final shape = state.shapes[i];
        if (_hitTest(shape, point)) {
          hitId = shape.id;
          break;
        }
      }
    }

    state = state.copyWith(
      selectedShapeId: hitId,
      clearSelection: hitId == null,
    );
  }

  bool _hitTest(Shape shape, Offset point) {
    final bounds = ShapeTransformer.bounds(shape);
    if (bounds == null) return false;
    // Inflate a bit for stroke hit tolerance on strokes.
    const tolerance = 4.0;
    final expanded = bounds.inflate(tolerance);
    return expanded.contains(point);
  }

  Shape _translateShape(Shape shape, Offset delta) {
    final shiftedBounds = shape.bounds?.shift(delta);
    final shiftedPoints = shape.points.isNotEmpty
        ? shape.points.map((p) => p + delta).toList()
        : null;
    return shape.copyWith(
      bounds: shiftedBounds,
      points: shiftedPoints ?? shape.points.toList(),
      translation: shape.translation + delta,
    );
  }

  Rect? _shapeBounds(Shape shape) {
    return ShapeTransformer.bounds(shape);
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
      _rebuildQuadTree(immutableShapes);
    }
  }


  void _rebuildQuadTree(List<Shape> shapes) {
    _quadTree = QuadTree(boundary: _quadBoundary);
    for (final shape in shapes) {
      _quadTree.insert(shape);
    }
  }

  Future<void> _applySnapshot(HistorySnapshot snap) async {
    _resetStrokeState();
    _applyingHistory = true;
    _rasterController.replaceStrokes(snap.rasterStrokes);
    final newRaster = await _rasterController.renderAll();
    _setShapesAndRebuild(snap.shapes, selectedShapeId: snap.selectedShapeId);
    state = state.copyWith(
      rasterLayer: newRaster,
      inProgressStroke: const [],
    );
    _applyingHistory = false;
  }

  void _pushHistory() {
    if (_applyingHistory) return;
    _history.push(
      shapes: state.shapes,
      strokes: _rasterController.strokes,
      selectedId: state.selectedShapeId,
    );
  }

  QuadTree get quadTree => _quadTree;
  void rebuildQuadTree() => _rebuildQuadTree(state.shapes);

  Shape _createShapeForKind(ShapeKind kind, Offset start) {
    switch (kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
        return Shape(
          id: _nextShapeId(),
          kind: kind,
          bounds: Rect.fromLTWH(start.dx, start.dy, 0, 0),
          strokeColor: state.currentColor,
          strokeWidth: state.brushThickness,
          opacity: state.brushOpacity,
          fillColor: state.shapeFillColor,
        );
      case ShapeKind.line:
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.line,
          points: [start, start],
          strokeColor: state.currentColor,
          strokeWidth: state.brushThickness,
          opacity: state.brushOpacity,
        );
      case ShapeKind.polygon:
        final pts = _trianglePoints(start, start);
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.polygon,
          points: pts,
          strokeColor: state.currentColor,
          strokeWidth: state.brushThickness,
          opacity: state.brushOpacity,
          fillColor: state.shapeFillColor,
        );
      case ShapeKind.freehand:
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.freehand,
          points: [start],
          strokeColor: state.currentColor,
          strokeWidth: state.brushThickness,
          opacity: state.brushOpacity,
        );
    }
  }

  List<Offset> _trianglePoints(Offset start, Offset end) {
    final minX = start.dx < end.dx ? start.dx : end.dx;
    final maxX = start.dx > end.dx ? start.dx : end.dx;
    final minY = start.dy < end.dy ? start.dy : end.dy;
    final maxY = start.dy > end.dy ? start.dy : end.dy;
    final top = Offset((minX + maxX) / 2, minY);
    final left = Offset(minX, maxY);
    final right = Offset(maxX, maxY);
    return [top, right, left];
  }

  Offset _maybeSnapLineStart(Offset point, ShapeKind kind) {
    if (kind != ShapeKind.line || _lastLineEnd == null) return point;
    const snapDistance = 8.0;
    final delta = point - _lastLineEnd!;
    if (delta.distance <= snapDistance) {
      return _lastLineEnd!;
    }
    return point;
  }

  double _minPointDistanceForBrush() => 0.0;

  void finalizeSelectionEdit() {
    _pushHistory();
  }

  void _resetStrokeState() {
    _isDrawingStroke = false;
    _currentStrokePoints.clear();
  }

  double _strokeSmoothing(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.75;
  double _strokeStreamline(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.55;
  double _strokeThinning() => 0.5;
}

final editorViewModelProvider =
    NotifierProvider<EditorViewModel, EditorState>(EditorViewModel.new);

