import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

class SelectionService {
  const SelectionService();

  SelectionChange setSelectionMode(SelectionContext context, SelectionMode mode) {
    var ids = List<String>.from(context.selectedShapeIds);
    var primary = context.selectedShapeId;
    switch (mode) {
      case SelectionMode.single:
        if (primary != null) {
          ids = [primary];
        } else if (ids.isNotEmpty) {
          primary = ids.last;
          ids = [primary];
        } else {
          ids = const [];
          primary = null;
        }
        break;
      case SelectionMode.multi:
        if (ids.isEmpty && primary != null) {
          ids = [primary];
        }
        primary = null;
        break;
      case SelectionMode.lasso:
        ids = const [];
        primary = null;
        break;
      case SelectionMode.all:
        ids = context.shapes.map((s) => s.id).toList(growable: false);
        primary = ids.isNotEmpty ? ids.last : null;
        break;
    }
    return SelectionChange(
      selectedShapeId: primary,
      selectedShapeIds: ids,
      clearSelection: primary == null && ids.isEmpty,
    );
  }

  SelectionChange setSelection(List<String> ids) {
    final primary = ids.length == 1 ? ids.first : null;
    return SelectionChange(
      selectedShapeId: primary,
      selectedShapeIds: ids,
      clearSelection: ids.isEmpty,
    );
  }

  SelectionChange selectAtPoint(
    SelectionContext context,
    Offset point,
    QuadTree quadTree, {
    required double viewportScale,
  }) {
    final topHit = topShapeAtPoint(
      context.shapes,
      point,
      quadTree,
      viewportScale: viewportScale,
    );
    switch (context.selectionMode) {
      case SelectionMode.single:
      case SelectionMode.lasso:
        return SelectionChange(
          selectedShapeId: topHit?.id,
          selectedShapeIds: topHit != null ? [topHit.id] : const [],
          clearSelection: topHit == null,
        );
      case SelectionMode.multi:
        final hit =
            _nearestShapeAtPoint(context.shapes, point) ?? topHit;
        if (hit == null) {
          return const SelectionChange(
            selectedShapeId: null,
            selectedShapeIds: <String>[],
            clearSelection: true,
          );
        }
        final ids = List<String>.from(context.selectedShapeIds);
        if (ids.contains(hit.id)) {
          ids.remove(hit.id);
        } else {
          ids.add(hit.id);
        }
        const primary = null;
        return SelectionChange(
          selectedShapeId: primary,
          selectedShapeIds: ids,
          clearSelection: ids.isEmpty,
        );
      case SelectionMode.all:
        final ids = context.shapes.map((s) => s.id).toList(growable: false);
        return SelectionChange(
          selectedShapeId: ids.isNotEmpty ? ids.last : null,
          selectedShapeIds: ids,
          clearSelection: ids.isEmpty,
        );
    }
  }

  Shape? topShapeAtPoint(
    List<Shape> shapes,
    Offset point,
    QuadTree quadTree, {
    required double viewportScale,
    Set<String>? excludeIds,
  }) {
    // Pass 1: Exact hit testing with tight tolerance (maintains precision)
    final exactHit = _topShapeAtPointExact(
      shapes,
      point,
      quadTree,
      viewportScale,
      excludeIds,
    );
    return exactHit;
  }

  /// Pass 1: Exact hit testing with tight tolerance for precision.
  /// Returns the topmost shape that passes the exact hit test, or null.
  Shape? _topShapeAtPointExact(
    List<Shape> shapes,
    Offset point,
    QuadTree quadTree,
    double viewportScale,
    Set<String>? excludeIds,
  ) {
    final candidates = quadTree.queryPoint(point);
    final shapesToCheck = candidates.isNotEmpty
        ? shapes.where((s) => candidates.contains(s)).toList()
        : shapes;
    
    // Check from top to bottom (z-order priority)
    for (var i = shapes.length - 1; i >= 0; i--) {
      final shape = shapes[i];
      if (excludeIds != null && excludeIds.contains(shape.id)) {
        continue;
      }
      if (!shapesToCheck.contains(shape)) continue;
      
      // Scale tolerance with viewport - when zoomed out (small scale), 
      // we need larger tolerance in canvas space to maintain screen-space hit area
      // Base tolerance of 3 screen pixels, converted to canvas space
      final screenSpaceTolerance = 3.0;
      final viewportAdjustedTolerance = screenSpaceTolerance / math.max(viewportScale, 0.1);
      
      // Combine with stroke-based tolerance for better hit detection on thick strokes
      final strokeTolerance = shape.strokeWidth * 0.5;
      
      // Use the larger of the two tolerances, with a minimum of 0.5
      final tolerance = math.max(viewportAdjustedTolerance, math.max(0.5, strokeTolerance));
      
      if (_hitDistance(shape, point, toleranceOverride: tolerance) != null) {
        return shape;
      }
    }
    return null;
  }

  bool hitTest(Shape shape, Offset point, {double viewportScale = 1.0}) {
    // Use viewport-adjusted tolerance similar to _topShapeAtPointExact
    final screenSpaceTolerance = 3.0;
    final viewportAdjustedTolerance = screenSpaceTolerance / math.max(viewportScale, 0.1);
    final strokeTolerance = shape.strokeWidth * 0.5;
    final tolerance = math.max(viewportAdjustedTolerance, math.max(0.5, strokeTolerance));
    
    return _hitDistance(
          shape,
          point,
          toleranceOverride: tolerance,
        ) !=
        null;
  }

  double? _hitDistance(Shape shape, Offset point, {double? toleranceOverride}) {
    final baseBounds = shape.localBounds;
    if (baseBounds == null) return null;
    
    double tolerance;
    if (toleranceOverride != null) {
      tolerance = toleranceOverride;
    } else {
      tolerance = math.max(0.5, shape.strokeWidth * 0.5);
    }
    
    final matrix = shape.matrixForRect(baseBounds);

    switch (shape.kind) {
      case ShapeKind.rectangle:
        final corners = _transformCorners(baseBounds, matrix);
        if (_pointInPolygon(point, corners)) return 0.0;
        final distance =
            _distanceToPolyline(point, corners, closed: true);
        return distance <= tolerance ? distance : null;
      case ShapeKind.ellipse:
        final inv = Matrix4.inverted(matrix);
        final local = _transformPoint(point, inv);
        final rx = baseBounds.width / 2;
        final ry = baseBounds.height / 2;
        if (rx <= 0 || ry <= 0) return null;
        final dx = (local.dx - baseBounds.center.dx) / rx;
        final dy = (local.dy - baseBounds.center.dy) / ry;
        final value = (dx * dx) + (dy * dy);
        if (value <= 1.0) return 0.0;
        final distance = (math.sqrt(value) - 1.0) * math.min(rx, ry);
        return distance <= tolerance ? distance : null;
      case ShapeKind.line:
        // Early bounds check
        final expandedBounds = baseBounds.inflate(tolerance);
        if (!expandedBounds.contains(point)) return null;
        final world = _transformOffsets(shape.points, matrix);
        final distance = _distanceToPolyline(
          point,
          world,
          closed: false,
          earlyExitThreshold: tolerance,
        );
        return distance <= tolerance ? distance : null;
      case ShapeKind.polygon:
        final contours = _shapeContours(shape);
        final worldContours = _transformContours(contours, matrix);
        if (_pointInContours(point, worldContours)) return 0.0;
        final distance =
            _distanceToPolylines(point, worldContours, closed: true);
        return distance <= tolerance ? distance : null;
      case ShapeKind.pointPath:
        final world = _transformOffsets(shape.points, matrix);
        if (shape.isClosed && _pointInPolygon(point, world)) return 0.0;
        final distancePP = _distanceToPolyline(point, world, closed: shape.isClosed);
        return distancePP <= tolerance ? distancePP : null;
      case ShapeKind.freehand:
        // Early bounds check before expensive transformation
        final expandedBounds = baseBounds.inflate(tolerance);
        if (!expandedBounds.contains(point)) return null;
        final world = _transformOffsets(shape.points, matrix);
        if (_isClosedFreehand(shape, world) && _pointInPolygon(point, world)) {
          return 0.0;
        }
        // Use early exit for performance on long freehand strokes
        final distance = _distanceToPolyline(
          point,
          world,
          closed: false,
          earlyExitThreshold: tolerance,
        );
        return distance <= tolerance ? distance : null;
      case ShapeKind.image:
        final corners = _transformCorners(baseBounds, matrix);
        if (_pointInPolygon(point, corners)) return 0.0;
        final imgDist = _distanceToPolyline(point, corners, closed: true);
        return imgDist <= tolerance ? imgDist : null;
    }
  }

  Shape? _nearestShapeAtPoint(
    List<Shape> shapes,
    Offset point,
  ) {
    Shape? best;
    var bestDistance = double.infinity;
    void considerShape(Shape shape) {
      final distance = _hitDistance(shape, point);
      if (distance == null) return;
      if (distance + 0.001 < bestDistance) {
        bestDistance = distance;
        best = shape;
      }
    }

    for (var i = shapes.length - 1; i >= 0; i--) {
      considerShape(shapes[i]);
    }
    return best;
  }

  List<Offset> _transformOffsets(List<Offset> points, Matrix4 matrix) {
    if (points.isEmpty) return const <Offset>[];
    return points
        .map((p) => _transformPoint(p, matrix))
        .toList(growable: false);
  }

  List<List<Offset>> _transformContours(
    List<List<Offset>> contours,
    Matrix4 matrix,
  ) {
    if (contours.isEmpty) return const <List<Offset>>[];
    return contours
        .map((c) => _transformOffsets(c, matrix))
        .toList(growable: false);
  }

  Offset _transformPoint(Offset point, Matrix4 matrix) {
    final v = matrix.transform3(Vector3(point.dx, point.dy, 0));
    return Offset(v.x, v.y);
  }

  List<Offset> _transformCorners(Rect rect, Matrix4 matrix) {
    final corners = <Offset>[
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
    return corners.map((c) => _transformPoint(c, matrix)).toList(growable: false);
  }

  List<List<Offset>> _shapeContours(Shape shape) {
    if (shape.contours.isNotEmpty) {
      return shape.contours
          .map((c) => c.toList(growable: false))
          .toList(growable: false);
    }
    if (shape.points.isNotEmpty) {
      return [shape.points.toList(growable: false)];
    }
    return const [];
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersect = ((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  bool _pointInContours(Offset point, List<List<Offset>> contours) {
    if (contours.isEmpty) return false;
    final path = Path();
    for (final contour in contours) {
      if (contour.length < 3) continue;
      path.addPolygon(contour, true);
    }
    path.fillType = PathFillType.evenOdd;
    return path.contains(point);
  }

  double _distanceToPolyline(
    Offset point,
    List<Offset> points, {
    required bool closed,
    double? earlyExitThreshold,
  }) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) return (point - points.first).distance;
    
    var minDistance = double.infinity;
    
    // For very long polylines (like freehand strokes), use simplified sampling
    // to improve performance while maintaining accuracy
    final useSimplified = earlyExitThreshold != null && points.length > 100;
    final step = useSimplified ? math.max(1, points.length ~/ 50) : 1;
    
    for (var i = 0; i < points.length - 1; i += step) {
      final nextIndex = math.min(i + 1, points.length - 1);
      final dist = _distanceToSegment(point, points[i], points[nextIndex]);
      if (dist < minDistance) {
        minDistance = dist;
        // Early exit if we're within threshold
        if (earlyExitThreshold != null && minDistance <= earlyExitThreshold) {
          return minDistance;
        }
      }
    }
    
    // Check remaining segments if we used simplified sampling
    if (useSimplified && step > 1) {
      for (var i = step - 1; i < points.length - 1; i += step) {
        final nextIndex = math.min(i + 1, points.length - 1);
        final dist = _distanceToSegment(point, points[i], points[nextIndex]);
        if (dist < minDistance) {
          minDistance = dist;
          if (earlyExitThreshold != null && minDistance <= earlyExitThreshold) {
            return minDistance;
          }
        }
      }
    }
    
    if (closed) {
      final dist = _distanceToSegment(point, points.last, points.first);
      if (dist < minDistance) minDistance = dist;
    }
    return minDistance;
  }

  double _distanceToPolylines(
    Offset point,
    List<List<Offset>> contours, {
    required bool closed,
  }) {
    var minDistance = double.infinity;
    for (final contour in contours) {
      final distance = _distanceToPolyline(point, contour, closed: closed);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = (ab.dx * ab.dx) + (ab.dy * ab.dy);
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - closest).distance;
  }

  bool _isClosedFreehand(Shape shape, List<Offset> points) {
    if (shape.isClosed) return true;
    if (points.length < 3) return false;
    const threshold = 6.0;
    return (points.first - points.last).distance <= threshold ||
        shape.fillColor != null;
  }

}

class SelectionContext {
  const SelectionContext({
    required this.shapes,
    required this.selectionMode,
    required this.selectedShapeId,
    required this.selectedShapeIds,
  });

  final List<Shape> shapes;
  final SelectionMode selectionMode;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
}

class SelectionChange {
  const SelectionChange({
    required this.selectedShapeId,
    required this.selectedShapeIds,
    required this.clearSelection,
  });

  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final bool clearSelection;
}




