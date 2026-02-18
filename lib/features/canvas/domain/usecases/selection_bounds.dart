import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

Rect? selectionBoundsForShape(
  Shape shape, {
  required double brushSmoothness,
  required bool strokeScaleWithShape,
}) {
  final baseBounds = shape.localBounds;
  final localStrokeWidth = _selectionLocalStrokeWidth(
    shape,
    strokeScaleWithShape,
  );
  // Prefer the per-shape smoothness when available so that selection bounds
  // match the exact rendering of the stroke.
  final effectiveSmoothness = shape.brushSmoothness ?? brushSmoothness;
  switch (shape.kind) {
    case ShapeKind.freehand:
      return _freehandSelectionBounds(
            shape,
            brushSmoothness: effectiveSmoothness,
            localStrokeWidth: localStrokeWidth,
          ) ??
          baseBounds;
    case ShapeKind.line:
      return _strokeBoundsFromPoints(
            shape.points,
            strokeWidth: localStrokeWidth,
          ) ??
          baseBounds;
    case ShapeKind.polygon:
    case ShapeKind.pointPath:
      return _strokeBoundsFromContours(
            shape.contours,
            shape.points,
            strokeWidth: localStrokeWidth,
          ) ??
          baseBounds;
    case ShapeKind.rectangle:
    case ShapeKind.ellipse:
      if (shape.bounds == null) return baseBounds;
      return _inflateRect(shape.bounds!, localStrokeWidth * 0.5);
    case ShapeKind.image:
      return shape.bounds ?? baseBounds;
  }
}

Rect? selectionBoundsForShapesWorld(
  List<Shape> shapes, {
  required double brushSmoothness,
  required bool strokeScaleWithShape,
}) {
  Rect? combined;
  for (final shape in shapes) {
    final baseBounds = shape.localBounds;
    if (baseBounds == null) continue;
    final localSelection =
        selectionBoundsForShape(
          shape,
          brushSmoothness: brushSmoothness,
          strokeScaleWithShape: strokeScaleWithShape,
        ) ??
        baseBounds;
    final matrix = shape.matrixForRect(baseBounds);
    final corners = _transformCorners(localSelection, matrix);
    final worldBounds = _boundsFromPoints(corners);
    if (worldBounds == null) continue;
    combined = combined == null
        ? worldBounds
        : combined.expandToInclude(worldBounds);
  }
  return combined;
}

List<Offset>? selectionCornersForShapesWorld(
  List<Shape> shapes, {
  required double brushSmoothness,
  required bool strokeScaleWithShape,
}) {
  final points = <Offset>[];
  for (final shape in shapes) {
    final baseBounds = shape.localBounds;
    if (baseBounds == null) continue;
    final localSelection =
        selectionBoundsForShape(
          shape,
          brushSmoothness: brushSmoothness,
          strokeScaleWithShape: strokeScaleWithShape,
        ) ??
        baseBounds;
    final matrix = shape.matrixForRect(baseBounds);
    points.addAll(_transformCorners(localSelection, matrix));
  }
  if (points.isEmpty) return null;
  if (points.length < 3) {
    final bounds = _boundsFromPoints(points);
    if (bounds == null) return null;
    return _transformCorners(bounds, Matrix4.identity());
  }

  final hull = _convexHull(points);
  if (hull.length < 3) {
    final bounds = _boundsFromPoints(points);
    if (bounds == null) return null;
    return _transformCorners(bounds, Matrix4.identity());
  }

  double bestArea = double.infinity;
  double bestAngle = 0.0;
  Rect? bestRect;

  for (var i = 0; i < hull.length; i++) {
    final p1 = hull[i];
    final p2 = hull[(i + 1) % hull.length];
    final edge = p2 - p1;
    final angle = math.atan2(edge.dy, edge.dx);
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final p in hull) {
      final x = p.dx * cosA + p.dy * sinA;
      final y = -p.dx * sinA + p.dy * cosA;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final area = (maxX - minX) * (maxY - minY);
    if (area < bestArea) {
      bestArea = area;
      bestAngle = angle;
      bestRect = Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }

  if (bestRect == null) return null;
  final cosA = math.cos(bestAngle);
  final sinA = math.sin(bestAngle);

  Offset rotateBack(Offset p) {
    final x = p.dx * cosA - p.dy * sinA;
    final y = p.dx * sinA + p.dy * cosA;
    return Offset(x, y);
  }

  return <Offset>[
    rotateBack(Offset(bestRect.left, bestRect.top)),
    rotateBack(Offset(bestRect.right, bestRect.top)),
    rotateBack(Offset(bestRect.right, bestRect.bottom)),
    rotateBack(Offset(bestRect.left, bestRect.bottom)),
  ];
}

Rect? _freehandSelectionBounds(
  Shape shape, {
  required double brushSmoothness,
  required double localStrokeWidth,
}) {
  if (shape.points.isEmpty) return null;
  final strokeWidth = localStrokeWidth;
  if (strokeWidth <= 0) {
    return _boundsFromPoints(shape.points);
  }
  final outline = _freehandOutline(
    shape.points,
    strokeWidth: strokeWidth,
    brushSmoothness: brushSmoothness,
    pressures: shape.pointPressures?.toList(growable: false),
  );
  if (outline == null || outline.isEmpty) {
    final bounds = _boundsFromPoints(shape.points);
    return bounds == null ? null : _inflateRect(bounds, strokeWidth * 0.5);
  }
  return _boundsFromPoints(outline);
}

List<Offset>? _freehandOutline(
  List<Offset> points, {
  required double strokeWidth,
  required double brushSmoothness,
  List<double>? pressures,
}) {
  if (points.isEmpty || strokeWidth <= 0) return null;
  final hasPressure = pressures != null && pressures.length == points.length;
  final vectors = hasPressure
      ? List<PointVector>.generate(
          points.length,
          (i) => PointVector.fromOffset(
            offset: points[i],
            pressure: pressures[i],
          ),
          growable: false,
        )
      : points
            .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
            .toList(growable: false);
  return getStroke(
    vectors,
    options: StrokeOptions(
      size: strokeWidth,
      thinning: 0.5,
      smoothing: _strokeSmoothing(brushSmoothness),
      streamline: _strokeStreamline(brushSmoothness),
      simulatePressure: true,
      isComplete: true,
    ),
  );
}

Rect? _strokeBoundsFromPoints(
  List<Offset> points, {
  required double strokeWidth,
}) {
  final bounds = _boundsFromPoints(points);
  if (bounds == null) return null;
  if (strokeWidth <= 0) return bounds;
  return _inflateRect(bounds, strokeWidth * 0.5);
}

Rect? _strokeBoundsFromContours(
  List<List<Offset>> contours,
  List<Offset> points, {
  required double strokeWidth,
}) {
  if (contours.isNotEmpty) {
    Rect? combined;
    for (final contour in contours) {
      final bounds = _boundsFromPoints(contour);
      if (bounds == null) continue;
      combined = combined == null ? bounds : combined.expandToInclude(bounds);
    }
    if (combined != null) {
      return strokeWidth <= 0
          ? combined
          : _inflateRect(combined, strokeWidth * 0.5);
    }
  }
  return _strokeBoundsFromPoints(points, strokeWidth: strokeWidth);
}

Rect? _boundsFromPoints(List<Offset> points) {
  if (points.isEmpty) return null;
  double minX = points.first.dx;
  double maxX = points.first.dx;
  double minY = points.first.dy;
  double maxY = points.first.dy;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

List<Offset> _transformCorners(Rect rect, Matrix4 matrix) {
  final corners = <Offset>[
    Offset(rect.left, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right, rect.bottom),
    Offset(rect.left, rect.bottom),
  ];
  return corners
      .map((c) {
        final v = matrix.transform3(Vector3(c.dx, c.dy, 0));
        return Offset(v.x, v.y);
      })
      .toList(growable: false);
}

List<Offset> _convexHull(List<Offset> points) {
  if (points.length <= 1) return List<Offset>.from(points);
  final sorted = List<Offset>.from(points)
    ..sort((a, b) {
      final cmpX = a.dx.compareTo(b.dx);
      return cmpX != 0 ? cmpX : a.dy.compareTo(b.dy);
    });

  double cross(Offset o, Offset a, Offset b) {
    return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  }

  final lower = <Offset>[];
  for (final p in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }

  final upper = <Offset>[];
  for (var i = sorted.length - 1; i >= 0; i--) {
    final p = sorted[i];
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }

  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

Rect _inflateRect(Rect rect, double amount) {
  if (amount == 0) return rect;
  return rect.inflate(amount);
}

double _effectiveStrokeWidth(Shape shape, bool strokeScaleWithShape) {
  final scale = _strokeScaleFor(shape);
  final scaleFactor = strokeScaleWithShape ? math.max(1.0, scale) : 1.0;
  return shape.strokeWidth / scaleFactor;
}

// Selection bounds are computed in local space and then transformed to world.
// Compensate local inflation by inverse transform scale so world-space
// selection stroke padding matches rendered stroke width.
double _selectionLocalStrokeWidth(Shape shape, bool strokeScaleWithShape) {
  final worldStrokeWidth = _effectiveStrokeWidth(shape, strokeScaleWithShape);
  final scale = _strokeScaleFor(shape);
  return worldStrokeWidth / scale;
}

double _strokeScaleFor(Shape shape) {
  final sx = shape.scaleX.abs();
  final sy = shape.scaleY.abs();
  final maxScale = sx > sy ? sx : sy;
  return maxScale <= 0.0001 ? 1.0 : maxScale;
}

double _strokeSmoothing(double slider) => 0.05 + slider.clamp(0.0, 1.0) * 0.85;

double _strokeStreamline(double slider) => 0.05 + slider.clamp(0.0, 1.0) * 0.75;
