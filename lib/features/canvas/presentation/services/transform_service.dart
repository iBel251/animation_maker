import 'dart:ui';
import 'dart:math' as math;

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_transformer.dart';

class TransformService {
  const TransformService();

  Rect? shapeBounds(Shape shape) => ShapeTransformer.bounds(shape);

  Shape translate(Shape shape, Offset delta) {
    final shiftedBounds = shape.bounds?.shift(delta);
    final shiftedContours = shape.contours.isNotEmpty
        ? shape.contours
            .map(
              (c) => c.map((p) => p + delta).toList(growable: false),
            )
            .toList(growable: false)
        : null;
    final shiftedEraseContours = shape.eraseContours != null
        ? shape.eraseContours!
            .map(
              (c) => c.map((p) => p + delta).toList(growable: false),
            )
            .toList(growable: false)
        : null;
    final shiftedPoints = shape.points.isNotEmpty
        ? shape.points.map((p) => p + delta).toList()
        : null;
    final resolvedPressures = _preservePointPressures(
      shape,
      shiftedContours != null ? shiftedContours.first : shiftedPoints,
    );
    // Shift bezierPoints if present to keep them in sync with points
    final shiftedBezierPoints = shape.bezierPoints != null
        ? shape.bezierPoints!
            .map((bp) => bp.copyWith(position: bp.position + delta))
            .toList(growable: false)
        : null;
    return shape.copyWith(
      bounds: shiftedBounds,
      points: shiftedContours != null
          ? shiftedContours.first
          : (shiftedPoints ?? shape.points.toList()),
      contours: shiftedContours,
      bezierPoints: shiftedBezierPoints,
      pointPressures: resolvedPressures,
      eraseContours: shiftedEraseContours,
      translation: shape.translation,
    );
  }

  Shape scaleShapeFromCenter(
    Shape base,
    Offset center,
    double scaleX,
    double scaleY,
  ) {
    final bounds = base.bounds ?? shapeBounds(base);
    if (bounds != null &&
        (base.kind == ShapeKind.rectangle || base.kind == ShapeKind.ellipse)) {
      final corners = [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft,
      ];
      var minX = double.infinity,
          maxX = -double.infinity,
          minY = double.infinity,
          maxY = -double.infinity;
      for (final c in corners) {
        final dx = (c.dx - center.dx) * scaleX;
        final dy = (c.dy - center.dy) * scaleY;
        final sx = center.dx + dx;
        final sy = center.dy + dy;
        if (sx < minX) minX = sx;
        if (sx > maxX) maxX = sx;
        if (sy < minY) minY = sy;
        if (sy > maxY) maxY = sy;
      }
      final newRect = Rect.fromLTRB(minX, minY, maxX, maxY);
      return base.copyWith(bounds: newRect);
    }

    if (base.contours.isNotEmpty) {
      final scaledContours = base.contours
          .map(
            (c) => c
                .map(
                  (p) => Offset(
                    center.dx + (p.dx - center.dx) * scaleX,
                    center.dy + (p.dy - center.dy) * scaleY,
                  ),
                )
                .toList(growable: false),
          )
          .toList(growable: false);
      return base.copyWith(
        points: scaledContours.first,
        contours: scaledContours,
        bounds: null,
        pointPressures: _preservePointPressures(base, scaledContours.first),
      );
    }

    if (base.points.isNotEmpty) {
      final scaled = base.points
          .map(
            (p) => Offset(
              center.dx + (p.dx - center.dx) * scaleX,
              center.dy + (p.dy - center.dy) * scaleY,
            ),
          )
          .toList(growable: false);
      return base.copyWith(
        points: scaled,
        bounds: null,
        pointPressures: _preservePointPressures(base, scaled),
      );
    }

    return base;
  }

  Shape rotateShapeFromCenter(Shape base, Offset center, double deltaAngle) {
    final bounds = base.bounds ?? shapeBounds(base);
    final baseCenter = bounds?.center ?? center;
    final cosA = math.cos(deltaAngle);
    final sinA = math.sin(deltaAngle);

    Offset rotateOffset(Offset o) {
      final dx = o.dx - center.dx;
      final dy = o.dy - center.dy;
      return Offset(
        center.dx + dx * cosA - dy * sinA,
        center.dy + dx * sinA + dy * cosA,
      );
    }

    if (bounds != null &&
        (base.kind == ShapeKind.rectangle || base.kind == ShapeKind.ellipse)) {
      final newCenter = rotateOffset(bounds.center);
      final delta = newCenter - bounds.center;
      return base.copyWith(
        bounds: bounds.shift(delta),
        rotation: base.rotation + deltaAngle,
        scale: base.scale,
      );
    }

    if (base.contours.isNotEmpty) {
      final newCenter = rotateOffset(baseCenter);
      final delta = newCenter - baseCenter;
      final shiftedContours = base.contours
          .map(
            (c) => c.map((p) => p + delta).toList(growable: false),
          )
          .toList(growable: false);
      return base.copyWith(
        points: shiftedContours.first,
        contours: shiftedContours,
        rotation: base.rotation + deltaAngle,
        scale: base.scale,
        pointPressures: _preservePointPressures(base, shiftedContours.first),
      );
    }

    if (base.points.isNotEmpty) {
      final newCenter = rotateOffset(baseCenter);
      final delta = newCenter - baseCenter;
      final shifted = base.points.map((p) => p + delta).toList(growable: false);
      return base.copyWith(
        points: shifted,
        rotation: base.rotation + deltaAngle,
        scale: base.scale,
        pointPressures: _preservePointPressures(base, shifted),
      );
    }

    return base.copyWith(
      rotation: base.rotation + deltaAngle,
      scale: base.scale,
    );
  }

  List<double>? _preservePointPressures(Shape shape, List<Offset>? points) {
    final pressures = shape.pointPressures;
    if (pressures == null || points == null) return null;
    if (pressures.length != points.length) return null;
    return pressures.toList(growable: false);
  }
}


