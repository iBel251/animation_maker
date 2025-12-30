import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';

class ShapeTransformer {
  static Shape applyTransform({
    required Shape shape,
    double? rotation,
    double? scale,
  }) {
    final newRotation = rotation ?? shape.rotation;
    final newScale = (scale ?? shape.scale).clamp(0.05, 100.0);
    return shape.copyWith(rotation: newRotation, scale: newScale);
  }

  static Rect? bounds(Shape shape) {
    final base = _baseBounds(shape);
    if (base == null) return null;
    if (shape.rotation == 0.0 && shape.scale == 1.0) return base;
    return _transformedAabb(base, shape.rotation, shape.scale);
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
}
