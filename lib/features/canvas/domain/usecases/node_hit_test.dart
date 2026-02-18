import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_handle_metrics.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_hit_result.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

// Re-export BezierHandleType for convenience
export 'package:animation_maker/features/canvas/presentation/models/node_hit_result.dart' show BezierHandleType;

/// Hit tests nodes and segments of a shape for node editing.
/// Returns the node or segment hit, or null if nothing was hit.
///
/// [shape] The shape to test against.
/// [worldPoint] The point in world/canvas coordinates.
/// [viewportScale] Current zoom level for viewport-aware hit testing.
/// [contourIndex] Optional: Specific contour to test. If null, tests the first contour only.
/// [selectedNodeIndices] Optional: Set of currently selected node indices.
///   When provided, Bezier control handles of selected nodes will be hit-testable.
NodeHitResult? hitTestNodes(
  Shape shape,
  Offset worldPoint,
  double viewportScale, {
  int? contourIndex,
  Set<int>? selectedNodeIndices,
}) {
  final points = _getEditablePointsForContour(shape, contourIndex ?? 0);
  if (points.isEmpty) return null;

  final matrix = shape.transformMatrix;
  final nodeHitRadius = nodeHandleHitRadius(viewportScale);
  final controlHandleHitRadius = bezierControlHandleHitRadius(viewportScale);
  final segmentTolerance = segmentHitTolerance(viewportScale);

  // Priority 0: Check Bezier control handles of selected nodes (highest priority)
  // Control handles are only interactable when their anchor is selected
  // Skip for merged shapes that should use weighted editing instead
  const nodeEditService = NodeEditService();
  final shouldSkipBezierHandles = nodeEditService.shouldHideBezierHandles(shape);

  if (shape.hasBezierCurves &&
      shape.bezierPoints != null &&
      selectedNodeIndices != null &&
      selectedNodeIndices.isNotEmpty &&
      !shouldSkipBezierHandles) {
    final handleResult = _hitTestBezierControlHandles(
      shape.bezierPoints!,
      matrix,
      worldPoint,
      controlHandleHitRadius,
      selectedNodeIndices,
    );
    if (handleResult != null) {
      return handleResult;
    }
  }

  // Priority 1: Check anchor points (nodes)
  for (var i = 0; i < points.length; i++) {
    final localPoint = points[i];
    final worldNodePos = _transformOffset(matrix, localPoint);
    final distance = (worldPoint - worldNodePos).distance;

    if (distance <= nodeHitRadius) {
      return NodeHitResult(
        nodeIndex: i,
        worldPosition: worldNodePos,
        contourIndex: contourIndex,
      );
    }
  }

  // Priority 2: Check path segments (for adding nodes)
  final segmentResult = _hitTestSegments(
    points,
    matrix,
    worldPoint,
    segmentTolerance,
    shape.isClosed,
    contourIndex: contourIndex,
  );

  return segmentResult;
}

/// Hit tests nodes and segments across ALL contours of a multi-contour shape.
/// Returns the node or segment hit along with the contour index, or null if nothing was hit.
/// Prioritizes nodes over segments, and tests contours in order (0, 1, 2, ...).
///
/// [shape] The shape to test against.
/// [worldPoint] The point in world/canvas coordinates.
/// [viewportScale] Current zoom level for viewport-aware hit testing.
NodeHitResult? hitTestNodesAllContours(
  Shape shape,
  Offset worldPoint,
  double viewportScale,
) {
  final contourCount = _getContourCount(shape);
  final matrix = shape.transformMatrix;
  final nodeHitRadius = nodeHandleHitRadius(viewportScale);
  final segmentTolerance = segmentHitTolerance(viewportScale);

  // First pass: Check all nodes across all contours (nodes have priority)
  for (var contourIdx = 0; contourIdx < contourCount; contourIdx++) {
    final points = _getEditablePointsForContour(shape, contourIdx);
    if (points.isEmpty) continue;

    for (var i = 0; i < points.length; i++) {
      final localPoint = points[i];
      final worldNodePos = _transformOffset(matrix, localPoint);
      final distance = (worldPoint - worldNodePos).distance;

      if (distance <= nodeHitRadius) {
        return NodeHitResult(
          nodeIndex: i,
          worldPosition: worldNodePos,
          contourIndex: contourIdx,
        );
      }
    }
  }

  // Second pass: Check all segments across all contours
  for (var contourIdx = 0; contourIdx < contourCount; contourIdx++) {
    final points = _getEditablePointsForContour(shape, contourIdx);
    if (points.isEmpty) continue;

    final segmentResult = _hitTestSegments(
      points,
      matrix,
      worldPoint,
      segmentTolerance,
      shape.isClosed,
      contourIndex: contourIdx,
    );

    if (segmentResult != null) {
      return segmentResult;
    }
  }

  return null;
}

/// Hit tests only nodes (not segments).
/// Useful for delete and select operations.
NodeHitResult? hitTestNodesOnly(
  Shape shape,
  Offset worldPoint,
  double viewportScale, {
  int? contourIndex,
}) {
  final points = _getEditablePointsForContour(shape, contourIndex ?? 0);
  if (points.isEmpty) return null;

  final matrix = shape.transformMatrix;
  final nodeHitRadius = nodeHandleHitRadius(viewportScale);

  for (var i = 0; i < points.length; i++) {
    final localPoint = points[i];
    final worldNodePos = _transformOffset(matrix, localPoint);
    final distance = (worldPoint - worldNodePos).distance;

    if (distance <= nodeHitRadius) {
      return NodeHitResult(
        nodeIndex: i,
        worldPosition: worldNodePos,
        contourIndex: contourIndex,
      );
    }
  }

  return null;
}

/// Hit tests only nodes across ALL contours.
/// Useful for selecting a contour by clicking on any of its nodes.
NodeHitResult? hitTestNodesOnlyAllContours(
  Shape shape,
  Offset worldPoint,
  double viewportScale,
) {
  final contourCount = _getContourCount(shape);
  final matrix = shape.transformMatrix;
  final nodeHitRadius = nodeHandleHitRadius(viewportScale);

  for (var contourIdx = 0; contourIdx < contourCount; contourIdx++) {
    final points = _getEditablePointsForContour(shape, contourIdx);
    if (points.isEmpty) continue;

    for (var i = 0; i < points.length; i++) {
      final localPoint = points[i];
      final worldNodePos = _transformOffset(matrix, localPoint);
      final distance = (worldPoint - worldNodePos).distance;

      if (distance <= nodeHitRadius) {
        return NodeHitResult(
          nodeIndex: i,
          worldPosition: worldNodePos,
          contourIndex: contourIdx,
        );
      }
    }
  }

  return null;
}

/// Gets the number of contours in a shape.
int _getContourCount(Shape shape) {
  if (shape.contours.isNotEmpty) {
    return shape.contours.length;
  }
  return shape.points.isEmpty ? 0 : 1;
}

/// Gets the editable points for a specific contour index.
/// Returns empty list if the index is out of bounds.
List<Offset> _getEditablePointsForContour(Shape shape, int contourIndex) {
  if (shape.contours.isNotEmpty) {
    if (contourIndex >= 0 && contourIndex < shape.contours.length) {
      return shape.contours[contourIndex].toList();
    }
    return const [];
  }
  // Single contour in points
  if (contourIndex == 0) {
    return shape.points.toList();
  }
  return const [];
}

/// Gets the editable points from a shape (first contour only - legacy).
/// For multi-contour shapes, returns the first contour.
List<Offset> _getEditablePoints(Shape shape) {
  return _getEditablePointsForContour(shape, 0);
}

/// Transforms a local offset to world coordinates using the shape's matrix.
Offset _transformOffset(Matrix4 matrix, Offset local) {
  final v = matrix.transform3(Vector3(local.dx, local.dy, 0));
  return Offset(v.x, v.y);
}

/// Hit tests path segments and returns the closest hit within tolerance.
NodeHitResult? _hitTestSegments(
  List<Offset> points,
  Matrix4 matrix,
  Offset worldPoint,
  double tolerance,
  bool isClosed, {
  int? contourIndex,
}) {
  if (points.length < 2) return null;

  double bestDistance = tolerance;
  int? bestSegmentIndex;
  double? bestT;
  Offset? bestPosition;

  final segmentCount = isClosed ? points.length : points.length - 1;

  for (var i = 0; i < segmentCount; i++) {
    final a = _transformOffset(matrix, points[i]);
    final b = _transformOffset(matrix, points[(i + 1) % points.length]);

    final result = _nearestPointOnSegment(worldPoint, a, b);

    if (result.distance < bestDistance) {
      bestDistance = result.distance;
      bestSegmentIndex = i;
      bestT = result.t;
      bestPosition = result.point;
    }
  }

  if (bestSegmentIndex != null) {
    return NodeHitResult(
      segmentIndex: bestSegmentIndex,
      segmentT: bestT,
      worldPosition: bestPosition,
      contourIndex: contourIndex,
    );
  }

  return null;
}

/// Result of finding the nearest point on a line segment.
class _SegmentNearestResult {
  const _SegmentNearestResult({
    required this.point,
    required this.distance,
    required this.t,
  });

  final Offset point;
  final double distance;
  final double t; // Parameter [0, 1] along segment
}

/// Finds the nearest point on a line segment to a given point.
/// Returns the nearest point, distance, and parameter t along the segment.
_SegmentNearestResult _nearestPointOnSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;

  if (lengthSquared < 0.0001) {
    // Degenerate segment (a == b)
    final distance = (point - a).distance;
    return _SegmentNearestResult(point: a, distance: distance, t: 0);
  }

  final ap = point - a;
  final dotProduct = ap.dx * ab.dx + ap.dy * ab.dy;
  var t = dotProduct / lengthSquared;

  // Clamp t to [0, 1] to stay on segment
  t = t.clamp(0.0, 1.0);

  final nearest = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
  final distance = (point - nearest).distance;

  return _SegmentNearestResult(point: nearest, distance: distance, t: t);
}

/// Converts a world point to local coordinates using inverse transform.
Offset worldToLocal(Shape shape, Offset worldPoint) {
  final matrix = shape.transformMatrix;
  final inverse = Matrix4.tryInvert(matrix);
  if (inverse == null) return worldPoint;

  final v = inverse.transform3(Vector3(worldPoint.dx, worldPoint.dy, 0));
  return Offset(v.x, v.y);
}

/// Converts a local point to world coordinates.
Offset localToWorld(Shape shape, Offset localPoint) {
  return _transformOffset(shape.transformMatrix, localPoint);
}

/// Hit tests Bezier control handles for selected nodes.
/// Only tests control handles of nodes that are in [selectedNodeIndices].
NodeHitResult? _hitTestBezierControlHandles(
  List<BezierPoint> bezierPoints,
  Matrix4 matrix,
  Offset worldPoint,
  double hitRadius,
  Set<int> selectedNodeIndices,
) {
  // Check control handles of selected nodes
  for (final nodeIndex in selectedNodeIndices) {
    if (nodeIndex < 0 || nodeIndex >= bezierPoints.length) continue;

    final bp = bezierPoints[nodeIndex];

    // Check control-in handle
    if (bp.controlIn != null) {
      final controlInWorld = _transformOffset(matrix, bp.controlInAbsolute);
      final distance = (worldPoint - controlInWorld).distance;
      if (distance <= hitRadius) {
        return NodeHitResult(
          nodeIndex: nodeIndex,
          worldPosition: controlInWorld,
          bezierHandleType: BezierHandleType.controlIn,
        );
      }
    }

    // Check control-out handle
    if (bp.controlOut != null) {
      final controlOutWorld = _transformOffset(matrix, bp.controlOutAbsolute);
      final distance = (worldPoint - controlOutWorld).distance;
      if (distance <= hitRadius) {
        return NodeHitResult(
          nodeIndex: nodeIndex,
          worldPosition: controlOutWorld,
          bezierHandleType: BezierHandleType.controlOut,
        );
      }
    }
  }

  return null;
}
