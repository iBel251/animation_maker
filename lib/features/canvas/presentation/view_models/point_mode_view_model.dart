import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/point_mode_state.dart';
import 'package:flutter/material.dart';

/// View model for point mode drawing operations.
/// Handles entering/exiting point mode, placing points, and generating
/// preview shapes with straight or curved connections.
class PointModeViewModel {
  PointModeViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function(List<Shape> shapes, {String? selectedShapeId})
        setShapesAndRebuild,
    required void Function(List<Shape> shapes) rebuildQuadTree,
    required void Function() pushHistory,
    required String Function() nextShapeId,
  })  : _getState = getState,
        _setState = setState,
        _setShapesAndRebuild = setShapesAndRebuild,
        _rebuildQuadTree = rebuildQuadTree,
        _pushHistory = pushHistory,
        _nextShapeId = nextShapeId;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function(List<Shape> shapes, {String? selectedShapeId})
      _setShapesAndRebuild;
  final void Function(List<Shape> shapes) _rebuildQuadTree;
  final void Function() _pushHistory;
  final String Function() _nextShapeId;

  /// Enters point mode for placing points to create a path.
  void enterPointMode() {
    final state = _getState();
    if (state.pointModeState.isActive) return;
    _setState(state.copyWith(
      pointModeState: const PointModeState(isActive: true),
      clearSelection: true,
    ));
  }

  /// Exits point mode, removing any preview shape.
  void exitPointMode() {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive) return;

    // Remove preview shape if exists
    List<Shape> updatedShapes = state.shapes;
    if (pointState.previewShapeId != null) {
      updatedShapes = state.shapes
          .where((s) => s.id != pointState.previewShapeId)
          .toList();
    }

    _setState(state.copyWith(
      pointModeState: PointModeState.initial,
      shapes: updatedShapes,
    ));
    _rebuildQuadTree(updatedShapes);
  }

  /// Adds a point at the given position in point mode.
  void addPointModePoint(Offset point) {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive) return;

    final newPointState = pointState.addPoint(point);
    _setState(state.copyWith(pointModeState: newPointState));

    // Update or create preview shape
    _updatePointModePreview();
  }

  /// Removes the last placed point in point mode.
  void removeLastPointModePoint() {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive || !pointState.hasPoints) return;

    final newPointState = pointState.removeLastPoint();
    _setState(state.copyWith(pointModeState: newPointState));

    // Update preview shape
    _updatePointModePreview();
  }

  /// Sets the connection type for point mode (straight or curved).
  void setPointModeConnectionType(PointConnectionType type) {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive) return;

    _setState(state.copyWith(
      pointModeState: pointState.copyWith(connectionType: type),
    ));

    // Update preview to reflect new connection type
    _updatePointModePreview();
  }

  /// Toggles whether the point mode shape should be closed.
  void togglePointModeClosed() {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive) return;

    _setState(state.copyWith(
      pointModeState: pointState.copyWith(isClosed: !pointState.isClosed),
    ));

    // Update preview to reflect closed state
    _updatePointModePreview();
  }

  /// Finalizes the point mode shape and adds it to the canvas.
  void finalizePointMode() {
    final state = _getState();
    final pointState = state.pointModeState;
    if (!pointState.isActive || !pointState.canConnect) return;

    final previewId = pointState.previewShapeId;
    if (previewId == null) return;

    // The preview shape becomes the final shape - sync to document
    _setShapesAndRebuild(
      state.shapes,
      selectedShapeId: previewId,
    );

    // Clear point mode state
    _setState(_getState().copyWith(
      pointModeState: PointModeState.initial,
    ));

    _pushHistory();
  }

  /// Updates or creates the preview shape for point mode.
  void _updatePointModePreview() {
    final state = _getState();
    final pointState = state.pointModeState;
    final points = pointState.placedPoints;

    // Remove existing preview if no points
    if (points.isEmpty) {
      if (pointState.previewShapeId != null) {
        final updatedShapes = state.shapes
            .where((s) => s.id != pointState.previewShapeId)
            .toList();
        _setState(state.copyWith(
          shapes: updatedShapes,
          pointModeState: pointState.copyWith(clearPreviewShapeId: true),
        ));
      }
      return;
    }

    // Create or update preview shape
    final shapeId = pointState.previewShapeId ?? _nextShapeId();
    final brushSettings = state.brushSettings[state.currentBrush]!;

    Shape previewShape;
    if (pointState.connectionType == PointConnectionType.curved &&
        points.length >= 2) {
      // Generate Bezier points for smooth curve
      final bezierPoints =
          _generateSmoothBezierPoints(points, pointState.isClosed);
      previewShape = Shape(
        id: shapeId,
        kind: ShapeKind.pointPath,
        points: points,
        bezierPoints: bezierPoints,
        strokeColor: state.currentColor,
        strokeWidth: brushSettings.thickness,
        opacity: brushSettings.opacity,
        fillColor: state.shapeFillColor,
        isClosed: pointState.isClosed,
      );
    } else {
      // Straight line connections
      previewShape = Shape(
        id: shapeId,
        kind: ShapeKind.pointPath,
        points: points,
        strokeColor: state.currentColor,
        strokeWidth: brushSettings.thickness,
        opacity: brushSettings.opacity,
        fillColor: state.shapeFillColor,
        isClosed: pointState.isClosed,
      );
    }

    // Update shapes list
    List<Shape> updatedShapes;
    if (pointState.previewShapeId != null) {
      // Replace existing preview
      updatedShapes = state.shapes.map((s) {
        return s.id == pointState.previewShapeId ? previewShape : s;
      }).toList();
    } else {
      // Add new preview
      updatedShapes = [...state.shapes, previewShape];
    }

    _setState(state.copyWith(
      shapes: updatedShapes,
      pointModeState: pointState.copyWith(previewShapeId: shapeId),
    ));
  }

  /// Generates smooth Bezier points from a list of positions using Catmull-Rom.
  List<BezierPoint> _generateSmoothBezierPoints(
      List<Offset> points, bool isClosed) {
    if (points.length < 2) return [];

    final result = <BezierPoint>[];
    final n = points.length;

    for (var i = 0; i < n; i++) {
      final prev = isClosed
          ? points[(i - 1 + n) % n]
          : (i == 0 ? points[0] : points[i - 1]);
      final current = points[i];
      final next = isClosed
          ? points[(i + 1) % n]
          : (i == n - 1 ? points[n - 1] : points[i + 1]);

      // Calculate tangent direction
      final tangent = next - prev;
      final tangentLength = tangent.distance;

      if (tangentLength < 0.001) {
        // Degenerate case - create corner point
        result.add(BezierPoint.corner(current));
        continue;
      }

      // Control handle length is ~1/6 of distance between neighbors
      final handleLength = tangentLength / 6.0;
      final normalized = tangent / tangentLength;

      result.add(BezierPoint(
        position: current,
        controlIn: normalized * -handleLength,
        controlOut: normalized * handleLength,
      ));
    }

    return result;
  }
}
