import 'dart:math' as math;

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/transform_handle.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_hierarchy_service.dart';
import 'package:animation_maker/features/canvas/domain/usecases/transform_session.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/joystick_mode.dart';
import 'package:flutter/material.dart';

/// View model for joystick-based transform operations.
/// Manages joystick move, scale, and rotate operations with proper
/// parent-child hierarchy support.
class JoystickTransformViewModel {
  JoystickTransformViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required List<Shape> Function() getSelectedGroupShapes,
    required Rect? Function(List<Shape>) getSelectionBounds,
    required void Function(List<Shape>) applyTransformedShapes,
    required void Function(Offset) moveSelectedBy,
    required void Function(Set<String> shapeIds, Offset delta) moveShapesByIds,
    required void Function() finalizeSelectionEdit,
    ShapeHierarchyService? hierarchyService,
  }) : _getState = getState,
       _setState = setState,
       _getSelectedGroupShapes = getSelectedGroupShapes,
       _getSelectionBounds = getSelectionBounds,
       _applyTransformedShapes = applyTransformedShapes,
       _moveSelectedBy = moveSelectedBy,
       _moveShapesByIds = moveShapesByIds,
       _finalizeSelectionEdit = finalizeSelectionEdit,
       _hierarchyService = hierarchyService ?? const ShapeHierarchyService();

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final List<Shape> Function() _getSelectedGroupShapes;
  final Rect? Function(List<Shape>) _getSelectionBounds;
  final void Function(List<Shape>) _applyTransformedShapes;
  final void Function(Offset) _moveSelectedBy;
  final void Function(Set<String> shapeIds, Offset delta) _moveShapesByIds;
  final void Function() _finalizeSelectionEdit;
  final ShapeHierarchyService _hierarchyService;

  // Internal state for joystick operations
  List<Shape> _joystickBaseShapes = const [];
  Offset _joystickCenter = Offset.zero;
  Map<String, Offset> _baseChildPositions = const {};
  Map<String, double> _baseChildRotations = const {};
  Set<String> _joystickMoveShapeIds = const <String>{};

  /// Whether a joystick transform session is active.
  bool get isActive => _joystickBaseShapes.isNotEmpty;

  /// The center point used for joystick transforms.
  Offset get center => _joystickCenter;

  /// Toggles the joystick controller visibility.
  void toggleJoystickController() {
    final state = _getState();
    _setState(
      state.copyWith(
        joystickControllerEnabled: !state.joystickControllerEnabled,
      ),
    );
  }

  /// Sets the joystick transform mode.
  void setJoystickMode(JoystickMode mode) {
    final state = _getState();
    if (state.joystickMode == mode) return;
    _setState(state.copyWith(joystickMode: mode));
  }

  /// Starts a joystick transform session.
  /// Captures the base state of selected shapes for incremental transforms.
  void startJoystickTransform() {
    final state = _getState();
    _joystickBaseShapes = _getSelectedGroupShapes();
    final bounds = _getSelectionBounds(_joystickBaseShapes);

    // Use pivot world position for rotation center
    if (_joystickBaseShapes.isNotEmpty && bounds != null) {
      final primaryShape = state.selectedShapeId != null
          ? state.shapes.firstWhere(
              (s) => s.id == state.selectedShapeId,
              orElse: () => _joystickBaseShapes.first,
            )
          : _joystickBaseShapes.first;
      if (primaryShape.spatialObjectId != null) {
        _joystickCenter = bounds.center;
      } else {
        final origin = primaryShape.localBounds?.center ?? bounds.center;
        _joystickCenter = _pivotWorldForShape(primaryShape, origin);
      }
    } else {
      _joystickCenter = bounds?.center ?? Offset.zero;
    }

    // Capture base child positions for rotation propagation
    _captureBaseChildPositions();
    _captureMoveShapeIds();
  }

  /// Ends the joystick transform session and commits changes to history.
  void endJoystickTransform() {
    _joystickBaseShapes = const [];
    _joystickCenter = Offset.zero;
    _baseChildPositions = const {};
    _baseChildRotations = const {};
    _joystickMoveShapeIds = const <String>{};
    _finalizeSelectionEdit();
  }

  /// Applies a move delta from the joystick.
  void applyJoystickMove(Offset delta) {
    if (delta == Offset.zero) return;
    if (_joystickMoveShapeIds.isEmpty) {
      _moveSelectedBy(delta);
      return;
    }
    _moveShapesByIds(_joystickMoveShapeIds, delta);
  }

  /// Applies uniform scale from the joystick.
  void applyJoystickScale(double factor) {
    if (_joystickBaseShapes.isEmpty) return;
    _applyScaleFromSnapshot(
      baseShapes: _joystickBaseShapes,
      center: _joystickCenter,
      scaleX: factor,
      scaleY: factor,
    );
  }

  /// Applies directional scale from the joystick.
  void applyJoystickScaleDirectional(double scaleX, double scaleY) {
    if (_joystickBaseShapes.isEmpty) return;
    _applyScaleFromSnapshot(
      baseShapes: _joystickBaseShapes,
      center: _joystickCenter,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  /// Applies scale using a specific transform handle.
  void applyJoystickScaleWithHandle(
    TransformHandle handle,
    double factor,
    Offset? axis,
  ) {
    if (_joystickBaseShapes.isEmpty) return;
    final session = TransformSession(
      shapes: _joystickBaseShapes,
      center: _joystickCenter,
    );

    List<Shape> updated;
    switch (handle) {
      case TransformHandle.scaleUniform:
        updated = session.scaleUniform(factor);
        break;
      case TransformHandle.scaleX:
      case TransformHandle.scaleY:
        if (axis == null) return;
        updated = session.scaleAxis(handle, factor, axis: axis);
        break;
      default:
        return;
    }

    _applyTransformedShapes(updated);
  }

  /// Applies rotation from the joystick.
  void applyJoystickRotate(double deltaAngle) {
    if (_joystickBaseShapes.isEmpty) return;
    final state = _getState();

    if (state.selectedShape?.spatialObjectId != null) {
      final ids = _joystickBaseShapes.map((s) => s.id).toSet();
      final currentBases = state.shapes
          .where((shape) => ids.contains(shape.id))
          .toList(growable: false);
      _applyRotationFromSnapshot(
        baseShapes: currentBases,
        center: _joystickCenter,
        deltaAngle: deltaAngle,
      );
      return;
    }

    // Use TransformSession.rotate for rotation
    final session = TransformSession(
      shapes: _joystickBaseShapes,
      center: _joystickCenter,
    );
    final updated = session.rotate(deltaAngle);

    // Also rotate children around parent's pivot using BASE positions
    final allUpdated = <Shape>[...updated];
    for (final baseParent in _joystickBaseShapes) {
      final parentPivotWorld =
          baseParent.transform.position +
          baseParent.localOrigin +
          baseParent.transform.pivot;

      final descendants = _hierarchyService.getDescendants(
        baseParent,
        state.shapes,
      );
      for (final child in descendants) {
        final basePivotWorld = _baseChildPositions[child.id];
        if (basePivotWorld == null) continue;
        final baseRotation = _baseChildRotations[child.id] ?? child.rotation;

        // Rotate child's BASE pivot around parent's pivot by the TOTAL delta
        final relativePos = basePivotWorld - parentPivotWorld;
        final rotatedPos = _rotatePoint(relativePos, deltaAngle);
        final newPivotWorld = parentPivotWorld + rotatedPos;
        final childLocalPivot = child.localOrigin + child.transform.pivot;
        final newTranslation = newPivotWorld - childLocalPivot;

        allUpdated.add(
          child.copyWith(
            translation: newTranslation,
            rotation: baseRotation + deltaAngle,
          ),
        );
      }
    }

    _applyTransformedShapes(allUpdated);
  }

  /// Captures the base pivot positions of all children of selected shapes.
  void _captureBaseChildPositions() {
    final state = _getState();
    final basePositions = <String, Offset>{};
    final baseRotations = <String, double>{};

    for (final parent in _joystickBaseShapes) {
      final descendants = _hierarchyService.getDescendants(
        parent,
        state.shapes,
      );
      final expanded = _expandSpatialSiblings(descendants, state.shapes);

      for (final child in expanded) {
        final childOrigin = child.localOrigin;
        basePositions[child.id] = _pivotWorldForShape(child, childOrigin);
        baseRotations[child.id] = child.rotation;
      }
    }

    _baseChildPositions = basePositions;
    _baseChildRotations = baseRotations;
  }

  /// Captures shape ids that should move during a joystick move session.
  void _captureMoveShapeIds() {
    final state = _getState();
    final ids = <String>{};
    for (final base in _joystickBaseShapes) {
      ids.add(base.id);
      final descendants = _hierarchyService.getDescendants(base, state.shapes);
      for (final child in descendants) {
        ids.add(child.id);
      }
    }
    _joystickMoveShapeIds = ids;
  }

  /// Calculates the world position of a shape's pivot point.
  Offset _pivotWorldForShape(Shape shape, Offset origin) {
    return shape.translation + origin + shape.transform.pivot;
  }

  /// Rotates a point around the origin by the given angle.
  Offset _rotatePoint(Offset point, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      point.dx * cos - point.dy * sin,
      point.dx * sin + point.dy * cos,
    );
  }

  /// Expands a list of shapes to include all spatial siblings.
  List<Shape> _expandSpatialSiblings(
    Iterable<Shape> shapes,
    List<Shape> allShapes,
  ) {
    final spatialIds = <String>{};
    for (final shape in shapes) {
      final spatialId = shape.spatialObjectId;
      if (spatialId != null) {
        spatialIds.add(spatialId);
      }
    }
    if (spatialIds.isEmpty) {
      return shapes.toList(growable: false);
    }
    final expanded = <String, Shape>{};
    for (final shape in shapes) {
      expanded[shape.id] = shape;
    }
    for (final shape in allShapes) {
      final spatialId = shape.spatialObjectId;
      if (spatialId != null && spatialIds.contains(spatialId)) {
        expanded[shape.id] = shape;
      }
    }
    return expanded.values.toList(growable: false);
  }

  /// Applies rotation from a base snapshot.
  void _applyRotationFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double deltaAngle,
  }) {
    if (baseShapes.isEmpty || deltaAngle == 0.0) return;
    final state = _getState();
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();

    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _rotateShapeFromCenter(base, center, deltaAngle);
    }

    _setState(state.copyWith(shapes: updated));
  }

  /// Applies scale from a base snapshot.
  void _applyScaleFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double scaleX,
    required double scaleY,
  }) {
    if (baseShapes.isEmpty) return;
    final state = _getState();
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
      ).copyWith(scaleX: base.scaleX, scaleY: base.scaleY);
    }

    _setState(state.copyWith(shapes: updated));
  }

  /// Rotates a shape around a center point.
  Shape _rotateShapeFromCenter(Shape base, Offset center, double deltaAngle) {
    // Rotate position around center
    final currentPos = base.translation + base.localOrigin;
    final relativePos = currentPos - center;
    final rotatedPos = _rotatePoint(relativePos, deltaAngle);
    final newPos = center + rotatedPos - base.localOrigin;

    return base.copyWith(
      translation: newPos,
      rotation: base.rotation + deltaAngle,
    );
  }

  /// Scales a shape from a center point.
  Shape _scaleShapeFromCenter(
    Shape base,
    Offset center,
    double scaleX,
    double scaleY,
  ) {
    // Scale position relative to center
    final currentPos = base.translation + base.localOrigin;
    final relativePos = currentPos - center;
    final scaledPos = Offset(relativePos.dx * scaleX, relativePos.dy * scaleY);
    final newPos = center + scaledPos - base.localOrigin;

    // Scale the shape's bounds or points
    if (base.bounds != null) {
      final bounds = base.bounds!;
      final newWidth = bounds.width * scaleX;
      final newHeight = bounds.height * scaleY;
      return base.copyWith(
        translation: newPos,
        bounds: Rect.fromCenter(
          center: bounds.center,
          width: newWidth,
          height: newHeight,
        ),
      );
    } else if (base.points.isNotEmpty) {
      final shapeCenter = _computePointsCenter(base.points);
      final scaledPoints = base.points
          .map((p) {
            final rel = p - shapeCenter;
            return shapeCenter + Offset(rel.dx * scaleX, rel.dy * scaleY);
          })
          .toList(growable: false);

      if (base.contours.isNotEmpty) {
        final scaledContours = base.contours
            .map((contour) {
              return contour
                  .map((p) {
                    final rel = p - shapeCenter;
                    return shapeCenter +
                        Offset(rel.dx * scaleX, rel.dy * scaleY);
                  })
                  .toList(growable: false);
            })
            .toList(growable: false);

        return base.copyWith(
          translation: newPos,
          points: scaledPoints,
          contours: scaledContours,
        );
      }

      return base.copyWith(translation: newPos, points: scaledPoints);
    }

    return base.copyWith(translation: newPos);
  }

  /// Computes the center of a list of points.
  Offset _computePointsCenter(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }
}
