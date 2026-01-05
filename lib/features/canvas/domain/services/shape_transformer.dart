import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class ShapeTransformer {
  static Shape applyTransform({
    required Shape shape,
    double? rotation,
    double? scale,
    double? scaleX,
    double? scaleY,
    Offset? translation,
  }) {
    final newRotation = rotation ?? shape.rotation;
    final nextScaleX = (scaleX ?? scale ?? shape.scaleX).clamp(0.05, 100.0);
    final nextScaleY = (scaleY ?? scale ?? shape.scaleY).clamp(0.05, 100.0);
    return shape.copyWith(
      rotation: newRotation,
      scaleX: nextScaleX,
      scaleY: nextScaleY,
      translation: translation ?? shape.translation,
    );
  }

  static Rect? bounds(Shape shape) {
    return shape.worldBounds ?? _baseBounds(shape);
  }

  static Rect? _baseBounds(Shape shape) {
    if (shape.bounds != null) return shape.bounds;
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

  static Rect _transformedAabb(Rect rect, double rotation, double scale) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final corners = <Offset>[
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
    final rot = rotation;
    final cosA = math.cos(rot);
    final sinA = math.sin(rot);
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final c in corners) {
      final dx = (c.dx - cx) * scale;
      final dy = (c.dy - cy) * scale;
      final rx = dx * cosA - dy * sinA + cx;
      final ry = dx * sinA + dy * cosA + cy;
      if (rx < minX) minX = rx;
      if (rx > maxX) maxX = rx;
      if (ry < minY) minY = ry;
      if (ry > maxY) maxY = ry;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Flip a shape horizontally and/or vertically around its center.
  static Shape flip({
    required Shape shape,
    bool horizontal = false,
    bool vertical = false,
    bool flipPivotWithObject = true,
  }) {
    if (!horizontal && !vertical) return shape;
    final base = _baseBounds(shape);
    if (base == null) return shape;
    final center = base.center;
    final newScaleX = horizontal ? -shape.scaleX : shape.scaleX;
    final newScaleY = vertical ? -shape.scaleY : shape.scaleY;

    // When keeping the pivot fixed, leave translation unchanged so the pivot's world
    // position stays in place while the shape flips around it. Otherwise, adjust
    // translation to keep the shape's center fixed (current behavior).
    Offset nextTranslation = shape.translation;
    if (flipPivotWithObject) {
      final worldCenterBefore = _transformPoint(shape, center);
      final tempShape = shape.copyWith(scaleX: newScaleX, scaleY: newScaleY);
      final worldCenterAfter = _transformPoint(tempShape, center);
      final positionCorrection = worldCenterBefore - worldCenterAfter;
      nextTranslation = shape.translation + positionCorrection;
    }

    return shape.copyWith(
      scaleX: newScaleX,
      scaleY: newScaleY,
      translation: nextTranslation,
    );
  }

  static Offset _transformPoint(Shape shape, Offset localPoint) {
    final matrix = shape.matrixForRect(Rect.fromLTWH(localPoint.dx, localPoint.dy, 0, 0));
    final transformed = matrix.transform3(Vector3(localPoint.dx, localPoint.dy, 0));
    return Offset(transformed.x, transformed.y);
  }
}


