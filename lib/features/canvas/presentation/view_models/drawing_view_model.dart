import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_drawing_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_grouping_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/stroke_drawing_service.dart';

/// View model for managing drawing operations (strokes and shapes)
class DrawingViewModel {
  DrawingViewModel({
    required ShapeDrawingService shapeDrawingService,
    required ShapeGroupingService shapeGroupingService,
  }) : _shapeDrawingService = shapeDrawingService,
       _shapeGroupingService = shapeGroupingService,
       _strokeDrawingService = StrokeDrawingService();

  final ShapeDrawingService _shapeDrawingService;
  final ShapeGroupingService _shapeGroupingService;
  late final StrokeDrawingService _strokeDrawingService;

  String? _currentDrawingId;
  Offset? _shapeStartPoint;
  Offset? _lastLineEnd;
  int _shapeCounter = 0;

  String _nextShapeId() {
    _shapeCounter += 1;
    return 'shape-$_shapeCounter';
  }

  bool get isDrawing => _strokeDrawingService.isDrawing;

  DrawingStartResult startDrawing(
    EditorState state,
    Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    final result = _strokeDrawingService.start(
      state,
      point,
      timeStamp: timeStamp,
      pressure: pressure,
    );
    if (!result.started) {
      return DrawingStartResult(state: state);
    }
    return DrawingStartResult(
      state: state.copyWith(
        selectedShapeId: null,
        clearSelection: result.clearSelection,
        inProgressStroke: result.inProgress,
      ),
    );
  }

  DrawingUpdateResult continueDrawing(
    EditorState state,
    Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    final result = _strokeDrawingService.update(
      state,
      point,
      timeStamp: timeStamp,
      pressure: pressure,
    );
    if (!result.updated) {
      return DrawingUpdateResult(state: state);
    }
    return DrawingUpdateResult(
      state: state.copyWith(inProgressStroke: result.inProgress),
    );
  }

  Future<DrawingFinishResult> endDrawing(
    EditorState state,
    String Function() nextShapeId,
    QuadTree? quadTree,
  ) async {
    final result = await _strokeDrawingService.finish(
      state,
      nextShapeId: nextShapeId,
      nextGroupId: _shapeGroupingService.nextGroupId,
      brushSmoothness: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.smoothness
          : state.brushSettings[state.currentBrush]!.smoothness,
      shapes: state.shapes,
      quadTree: quadTree,
    );
    if (result.newShapes.isNotEmpty || result.idsToDelete.isNotEmpty) {
      return DrawingFinishResult(
        newShapes: result.newShapes,
        selectShapeId: result.selectShapeId,
        clearSelection: result.clearSelection,
        newCurrentGroupId: result.newCurrentGroupId,
        idsToDelete: result.idsToDelete,
        state: state.copyWith(inProgressStroke: const []),
      );
    }
    return DrawingFinishResult(
      state: state.copyWith(inProgressStroke: result.inProgress),
    );
  }

  DrawingCancelResult cancelDrawing(EditorState state) {
    final result = _strokeDrawingService.cancel();
    if (!result.cancelled) {
      return DrawingCancelResult(state: null);
    }
    return DrawingCancelResult(
      state: state.copyWith(inProgressStroke: result.inProgress),
    );
  }

  ShapeDrawingStartResult startShapeDrawing(
    EditorState state,
    Offset point,
    String Function() nextShapeId,
  ) {
    if (state.activeTool != EditorTool.shape) {
      return ShapeDrawingStartResult(state: state, success: false);
    }
    if (_currentDrawingId != null) {
      return ShapeDrawingStartResult(state: state, success: false);
    }
    final kind = state.shapeDrawKind;
    final start = _shapeDrawingService.maybeSnapLineStart(
      point,
      kind,
      _lastLineEnd,
    );
    final newShape = _shapeDrawingService.createShapeForKind(
      kind: kind,
      start: start,
      id: nextShapeId(),
      strokeColor: state.currentColor,
      strokeWidth: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.thickness
          : state.brushSettings[state.currentBrush]!.thickness,
      opacity: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.opacity
          : state.brushSettings[state.currentBrush]!.opacity,
      fillColor: state.shapeFillColor,
    );
    _currentDrawingId = newShape.id;
    _shapeStartPoint = start;
    final updatedShapes = [...state.shapes, newShape];
    return ShapeDrawingStartResult(
      state: state.copyWith(shapes: updatedShapes),
      success: true,
      selectedShapeId: newShape.id,
    );
  }

  EditorState? updateShapeDrawing(EditorState state, Offset point) {
    if (_currentDrawingId == null ||
        _shapeStartPoint == null ||
        state.activeTool != EditorTool.shape) {
      return null;
    }
    final index = state.shapes.indexWhere(
      (shape) => shape.id == _currentDrawingId,
    );
    if (index == -1) return null;

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
    return state.copyWith(shapes: updatedShapes);
  }

  ShapeDrawingFinishResult finishShapeDrawing(EditorState state) {
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
        _lastLineEnd = endPoint ?? _shapeStartPoint!;
        _currentDrawingId = null;
        _shapeStartPoint = null;
        return ShapeDrawingFinishResult(
          state: state.copyWith(shapes: updated),
          needsQuadTreeRebuild: true,
        );
      }
    } else {
      _lastLineEnd = null;
    }
    _currentDrawingId = null;
    _shapeStartPoint = null;
    return ShapeDrawingFinishResult(state: state, needsQuadTreeRebuild: true);
  }

  ShapeDrawingCancelResult cancelShapeDrawing(EditorState state) {
    if (_currentDrawingId == null) {
      return ShapeDrawingCancelResult(state: state, success: false);
    }
    final idx = state.shapes.indexWhere((s) => s.id == _currentDrawingId);
    if (idx == -1) {
      _currentDrawingId = null;
      _shapeStartPoint = null;
      return ShapeDrawingCancelResult(state: state, success: false);
    }
    final updated = List<Shape>.from(state.shapes)..removeAt(idx);
    _currentDrawingId = null;
    _shapeStartPoint = null;
    _lastLineEnd = null;
    return ShapeDrawingCancelResult(
      state: state.copyWith(shapes: updated),
      success: true,
      needsQuadTreeRebuild: true,
    );
  }

  void syncShapeCounter(int maxShape) {
    _shapeCounter = maxShape;
  }
}

class DrawingStartResult {
  final EditorState state;

  DrawingStartResult({required this.state});
}

class DrawingUpdateResult {
  final EditorState state;

  DrawingUpdateResult({required this.state});
}

class DrawingFinishResult {
  final EditorState state;
  final List<Shape> newShapes;
  final String? selectShapeId;
  final bool clearSelection;
  final String? newCurrentGroupId;
  final List<String> idsToDelete;

  DrawingFinishResult({
    required this.state,
    this.newShapes = const [],
    this.selectShapeId,
    this.clearSelection = false,
    this.newCurrentGroupId,
    this.idsToDelete = const [],
  });
}

class DrawingCancelResult {
  final EditorState? state;

  DrawingCancelResult({this.state});
}

class ShapeDrawingStartResult {
  final EditorState state;
  final bool success;
  final String? selectedShapeId;

  ShapeDrawingStartResult({
    required this.state,
    required this.success,
    this.selectedShapeId,
  });
}

class ShapeDrawingCancelResult {
  final EditorState state;
  final bool success;
  final bool needsQuadTreeRebuild;

  ShapeDrawingCancelResult({
    required this.state,
    required this.success,
    this.needsQuadTreeRebuild = false,
  });
}

class ShapeDrawingFinishResult {
  final EditorState state;
  final bool needsQuadTreeRebuild;

  ShapeDrawingFinishResult({
    required this.state,
    this.needsQuadTreeRebuild = false,
  });
}
