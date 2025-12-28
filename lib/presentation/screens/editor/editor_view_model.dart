import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/domain/services/quadtree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  factory EditorState.initial() => const EditorState(
        shapes: <Shape>[],
        activeTool: EditorTool.brush,
        selectedShapeId: null,
        currentFrame: 0,
        isPropertiesOpen: true,
        shapeDrawKind: ShapeKind.rectangle,
      );

  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
  final int currentFrame;
  final bool isPropertiesOpen;
  final ShapeKind shapeDrawKind;

  EditorState copyWith({
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
    int? currentFrame,
    bool? isPropertiesOpen,
    bool clearSelection = false,
    ShapeKind? shapeDrawKind,
  }) {
    return EditorState(
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId:
          clearSelection ? null : (selectedShapeId ?? this.selectedShapeId),
      currentFrame: currentFrame ?? this.currentFrame,
      isPropertiesOpen: isPropertiesOpen ?? this.isPropertiesOpen,
      shapeDrawKind: shapeDrawKind ?? this.shapeDrawKind,
    );
  }
}

class EditorViewModel extends Notifier<EditorState> {
  final Rect _quadBoundary = const Rect.fromLTWH(0, 0, 5000, 5000);
  late QuadTree _quadTree;
  @override
  EditorState build() {
    _quadTree = QuadTree(boundary: _quadBoundary);
    return EditorState.initial();
  }

  int _shapeCounter = 0;
  String? _currentDrawingId;
  Offset? _shapeStartPoint;
  Offset? _lastLineEnd;

  void setActiveTool(EditorTool tool) {
    state = state.copyWith(activeTool: tool);
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
  }

  void setCurrentFrame(int frame) {
    state = state.copyWith(currentFrame: frame);
  }

  void togglePropertiesPanel() {
    state = state.copyWith(isPropertiesOpen: !state.isPropertiesOpen);
  }

  void setShapeDrawKind(ShapeKind kind) {
    state = state.copyWith(shapeDrawKind: kind);
  }

  String _nextShapeId() {
    _shapeCounter += 1;
    return 'shape-$_shapeCounter';
  }

  void startDrawing(Offset point) {
    if (state.activeTool != EditorTool.brush) return;
    final newShape = Shape(
      id: _nextShapeId(),
      kind: ShapeKind.freehand,
      points: [point],
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2.0,
    );
    final updatedShapes = [...state.shapes, newShape];
    _setShapesAndRebuild(
      updatedShapes,
      selectedShapeId: newShape.id,
    );
    _currentDrawingId = newShape.id;
  }

  void continueDrawing(Offset point) {
    if (_currentDrawingId == null || state.activeTool != EditorTool.brush) {
      return;
    }
    final index =
        state.shapes.indexWhere((shape) => shape.id == _currentDrawingId);
    if (index == -1) return;

    final target = state.shapes[index];
    final updatedPoints = [...target.points, point];
    final updatedShape = target.copyWith(points: updatedPoints);

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updatedShape;

    _setShapesAndRebuild(updatedShapes, rebuildQuadTree: false);
  }

  void endDrawing() {
    _rebuildQuadTree(state.shapes);
    _currentDrawingId = null;
  }

  void startShapeDrawing(Offset point) {
    if (state.activeTool != EditorTool.shape) return;
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
        updatedShape =
            target.copyWith(points: [_shapeStartPoint!, point]);
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
    final bounds = shape.bounds ?? _shapeBounds(shape);
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
    if (shape.bounds != null) return shape.bounds;
    if (shape.points.isEmpty) return null;
    if (shape.points.length == 1) {
      final p = shape.points.first;
      return Rect.fromLTWH(p.dx, p.dy, 0, 0);
    }
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
          strokeColor: const Color(0xFF000000),
          strokeWidth: 2.0,
        );
      case ShapeKind.line:
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.line,
          points: [start, start],
          strokeColor: const Color(0xFF000000),
          strokeWidth: 2.0,
        );
      case ShapeKind.polygon:
        final pts = _trianglePoints(start, start);
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.polygon,
          points: pts,
          strokeColor: const Color(0xFF000000),
          strokeWidth: 2.0,
        );
      case ShapeKind.freehand:
        return Shape(
          id: _nextShapeId(),
          kind: ShapeKind.freehand,
          points: [start],
          strokeColor: const Color(0xFF000000),
          strokeWidth: 2.0,
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
}

final editorViewModelProvider =
    NotifierProvider<EditorViewModel, EditorState>(EditorViewModel.new);

