import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class ShapeDrawingService {
  const ShapeDrawingService();

  Shape createShapeForKind({
    required ShapeKind kind,
    required Offset start,
    required String id,
    required Color strokeColor,
    required double strokeWidth,
    required double opacity,
    Color? fillColor,
  }) {
    switch (kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
        return Shape(
          id: id,
          kind: kind,
          bounds: Rect.fromLTWH(start.dx, start.dy, 0, 0),
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
          opacity: opacity,
          fillColor: fillColor,
        );
      case ShapeKind.line:
        return Shape(
          id: id,
          kind: ShapeKind.line,
          points: [start, start],
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
          opacity: opacity,
        );
      case ShapeKind.polygon:
        final pts = trianglePoints(start, start);
        return Shape(
          id: id,
          kind: ShapeKind.polygon,
          points: pts,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
          opacity: opacity,
          fillColor: fillColor,
        );
      case ShapeKind.freehand:
        return Shape(
          id: id,
          kind: ShapeKind.freehand,
          points: [start],
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
          opacity: opacity,
        );
    }
  }

  Shape updateShapeDuringDraw({
    required Shape target,
    required ShapeKind kind,
    required Offset startPoint,
    required Offset currentPoint,
    double minPointDistance = 0.0,
  }) {
    switch (kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
        final rect = Rect.fromPoints(startPoint, currentPoint);
        return target.copyWith(bounds: rect);
      case ShapeKind.line:
        final lastPoint = target.points.isNotEmpty ? target.points.last : null;
        if (lastPoint != null &&
            (lastPoint - currentPoint).distance < minPointDistance) {
          return target;
        }
        return target.copyWith(points: [startPoint, currentPoint]);
      case ShapeKind.polygon:
        final triPoints = trianglePoints(startPoint, currentPoint);
        return target.copyWith(points: triPoints);
      case ShapeKind.freehand:
        return target;
    }
  }

  Shape finalizeLineShape({
    required Shape target,
    required Offset startPoint,
  }) {
    if (target.points.length >= 2) {
      return target.copyWith(points: [startPoint, target.points.last]);
    }
    return target.copyWith(points: [startPoint, startPoint]);
  }

  Offset maybeSnapLineStart(
    Offset point,
    ShapeKind kind,
    Offset? lastLineEnd,
  ) {
    if (kind != ShapeKind.line || lastLineEnd == null) return point;
    const snapDistance = 8.0;
    final delta = point - lastLineEnd;
    if (delta.distance <= snapDistance) {
      return lastLineEnd;
    }
    return point;
  }

  List<Offset> trianglePoints(Offset start, Offset end) {
    final minX = start.dx < end.dx ? start.dx : end.dx;
    final maxX = start.dx > end.dx ? start.dx : end.dx;
    final minY = start.dy < end.dy ? start.dy : end.dy;
    final maxY = start.dy > end.dy ? start.dy : end.dy;
    final top = Offset((minX + maxX) / 2, minY);
    final left = Offset(minX, maxY);
    final right = Offset(maxX, maxY);
    return [top, right, left];
  }
}



