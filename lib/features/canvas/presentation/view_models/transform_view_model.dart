import 'dart:math' as math;

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_transformer.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/transform_service.dart';
import 'package:flutter/material.dart';

/// View model for managing shape transformation operations
class TransformViewModel {
  TransformViewModel({
    required TransformService transformService,
  }) : _transformService = transformService;

  final TransformService _transformService;

  EditorState updateSelectedTransform({
    required EditorState state,
    required List<int> selectedIndices,
    double? rotation,
    double? scale,
  }) {
    if (selectedIndices.isEmpty) return state;
    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in selectedIndices) {
      final target = state.shapes[idx];
      if (target.kind == ShapeKind.line && target.points.length < 2) continue;
      updatedShapes[idx] = ShapeTransformer.applyTransform(
        shape: target,
        rotation: rotation,
        scale: scale,
      );
    }
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState scaleSelectedGeometry({
    required EditorState state,
    required List<int> selectedIndices,
    Rect? baseBounds,
    List<Offset>? basePoints,
    required double scaleX,
    required double scaleY,
  }) {
    if (selectedIndices.isEmpty) return state;
    final clampedScaleX = scaleX.clamp(0.05, 10.0);
    final clampedScaleY = scaleY.clamp(0.05, 10.0);

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in selectedIndices) {
      final target = state.shapes[idx];
      final usesBounds =
          target.kind == ShapeKind.rectangle ||
          target.kind == ShapeKind.ellipse;
      final useShared = selectedIndices.length == 1;
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
      } else if (target.contours.isNotEmpty) {
        final boundsFromPoints =
            (useShared ? baseBounds : null) ?? _shapeBounds(target);
        final contourPoints = target.contours
            .map((c) => c.toList(growable: false))
            .toList(growable: false);
        if (contourPoints.isNotEmpty && contourPoints.first.isNotEmpty) {
          final center = boundsFromPoints?.center ?? contourPoints.first.first;
          final scaledContours = contourPoints
              .map(
                (c) => c
                    .map(
                      (p) => Offset(
                        center.dx + (p.dx - center.dx) * clampedScaleX,
                        center.dy + (p.dy - center.dy) * clampedScaleY,
                      ),
                    )
                    .toList(growable: false),
              )
              .toList(growable: false);
          updated = target.copyWith(
            points: scaledContours.first,
            contours: scaledContours,
            bounds: null,
            pointPressures: _preservePointPressures(target, scaledContours.first),
          );
        }
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
          updated = target.copyWith(
            points: scaledPoints,
            bounds: null,
            pointPressures: _preservePointPressures(target, scaledPoints),
          );
        }
      }
      updatedShapes[idx] = updated;
    }

    return state.copyWith(shapes: updatedShapes);
  }

  EditorState applyRotationFromSnapshot({
    required EditorState state,
    required List<Shape> baseShapes,
    required Offset center,
    required double deltaAngle,
  }) {
    if (baseShapes.isEmpty || deltaAngle == 0.0) return state;
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();
    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _rotateShapeFromCenter(base, center, deltaAngle);
    }
    return state.copyWith(shapes: updated);
  }

  EditorState applyScaleFromSnapshot({
    required EditorState state,
    required List<Shape> baseShapes,
    required Offset center,
    required double scaleX,
    required double scaleY,
  }) {
    if (baseShapes.isEmpty) return state;
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
    return state.copyWith(shapes: updated);
  }

  EditorState moveSelectedBy({
    required EditorState state,
    required List<int> selectedIndices,
    required Offset delta,
  }) {
    if (delta == Offset.zero || selectedIndices.isEmpty) return state;
    final updated = List<Shape>.from(state.shapes);
    for (final index in selectedIndices) {
      final target = state.shapes[index];
      updated[index] = _translateShape(target, delta);
    }
    return state.copyWith(shapes: updated);
  }

  EditorState flipSelected({
    required EditorState state,
    required int selectedIndex,
    bool horizontal = false,
    bool vertical = false,
    required bool flipPivotWithObject,
  }) {
    if (selectedIndex == -1) return state;
    final target = state.shapes[selectedIndex];
    final flipped = ShapeTransformer.flip(
      shape: target,
      horizontal: horizontal,
      vertical: vertical,
      flipPivotWithObject: flipPivotWithObject,
    );
    final updated = List<Shape>.from(state.shapes);
    updated[selectedIndex] = flipped;
    return state.copyWith(shapes: updated);
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

  Shape _translateShape(Shape shape, Offset delta) {
    return _transformService.translate(shape, delta);
  }

  Rect? _shapeBounds(Shape shape) {
    return _transformService.shapeBounds(shape);
  }

  List<double>? _preservePointPressures(Shape shape, List<Offset>? points) {
    final pressures = shape.pointPressures;
    if (pressures == null || points == null) return null;
    if (pressures.length != points.length) return null;
    return pressures.toList(growable: false);
  }
}
