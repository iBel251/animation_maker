import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class FillUtils {
  static bool canFill(Shape shape) {
    switch (shape.kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.polygon:
        return true;
      case ShapeKind.freehand:
        return isFreehandClosed(shape);
      case ShapeKind.line:
        return false;
    }
  }

  /// Closure check for freehand: explicit flag, endpoint proximity, or any self-intersection.
  static bool isFreehandClosed(Shape shape, {double threshold = 6.0}) {
    if (shape.kind != ShapeKind.freehand) return false;
    if (shape.isClosed) return true;
    return isFreehandClosedPoints(shape.points, threshold: threshold);
  }

  static bool isFreehandClosedPoints(List<Offset> points,
      {double threshold = 6.0}) {
    if (points.length < 3) return false;
    final first = points.first;
    final last = points.last;
    if ((first - last).distance <= threshold) return true;
    return _hasSelfIntersection(points);
  }

  static Path? buildFillPath(Shape shape) {
    if (!canFill(shape) || shape.fillColor == null) return null;
    switch (shape.kind) {
      case ShapeKind.freehand:
        if (shape.points.length < 3) return null;
        final path = Path()
          ..moveTo(shape.points.first.dx, shape.points.first.dy);
        for (var i = 1; i < shape.points.length; i++) {
          final p = shape.points[i];
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        path.fillType = PathFillType.evenOdd;
        return path;
      case ShapeKind.polygon:
        if (shape.points.length < 3) return null;
        return Path()..addPolygon(shape.points, true);
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.line:
        return null; // handled elsewhere for rect/ellipse
    }
  }

  static bool _hasSelfIntersection(List<Offset> points) {
    // Brute-force segment intersection for non-adjacent segments.
    for (int i = 0; i < points.length - 3; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      for (int j = i + 2; j < points.length - 1; j++) {
        // Skip adjacent segments sharing a point.
        if (j == i) continue;
        final p3 = points[j];
        final p4 = points[j + 1];
        if (_segmentsIntersect(p1, p2, p3, p4)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
    double orient(Offset p, Offset q, Offset r) =>
        (q.dy - p.dy) * (r.dx - q.dx) - (q.dx - p.dx) * (r.dy - q.dy);

    bool onSegment(Offset p, Offset q, Offset r) {
      return q.dx <= (p.dx > r.dx ? p.dx : r.dx) + 0.0001 &&
          q.dx + 0.0001 >= (p.dx < r.dx ? p.dx : r.dx) &&
          q.dy <= (p.dy > r.dy ? p.dy : r.dy) + 0.0001 &&
          q.dy + 0.0001 >= (p.dy < r.dy ? p.dy : r.dy);
    }

    final o1 = orient(a1, a2, b1);
    final o2 = orient(a1, a2, b2);
    final o3 = orient(b1, b2, a1);
    final o4 = orient(b1, b2, a2);

    if (o1.sign != o2.sign && o3.sign != o4.sign) return true;

    if (o1.abs() < 0.0001 && onSegment(a1, b1, a2)) return true;
    if (o2.abs() < 0.0001 && onSegment(a1, b2, a2)) return true;
    if (o3.abs() < 0.0001 && onSegment(b1, a1, b2)) return true;
    if (o4.abs() < 0.0001 && onSegment(b1, a2, b2)) return true;
    return false;
  }
}



