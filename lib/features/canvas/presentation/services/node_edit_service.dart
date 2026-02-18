import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/usecases/node_hit_test.dart';
import 'package:animation_maker/features/canvas/domain/usecases/node_operations.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_hit_result.dart';

/// Service for node editing operations.
/// Provides a clean interface for manipulating shape nodes.
class NodeEditService {
  const NodeEditService();

  /// Checks if a shape supports node editing.
  /// Freehand strokes now support weighted node editing for smooth morphing.
  bool isNodeEditable(Shape shape) {
    return shape.kind == ShapeKind.line ||
        shape.kind == ShapeKind.polygon ||
        shape.kind == ShapeKind.freehand ||
        shape.kind == ShapeKind.pointPath;
  }

  /// Checks if a shape should use weighted edit mode (hidden nodes + soft drag).
  /// 
  /// Weighted edit is appropriate for:
  /// - Shapes with many points (dense freehand strokes, merged curves)
  /// - Non-circle, non-straight-line polygons
  /// 
  /// Weighted edit is NOT appropriate for:
  /// - Point paths (always use standard clickable/draggable nodes + Bezier handles)
  /// - Circles/ellipses (use standard Bezier editing)
  /// - Simple straight-line polygons (rectangles, triangles, etc.)
  /// - Shapes with very few points
  bool isWeightedEditEligible(Shape shape, {int contourIndex = 0}) {
    // Must be an editable shape type
    if (!isNodeEditable(shape)) return false;

    // Point paths always use standard editing: clickable nodes, draggable nodes,
    // and editable Bezier control handles (never weighted drag)
    if (shape.kind == ShapeKind.pointPath) return false;

    final points = _getContourPoints(shape, contourIndex);
    
    // Too few points - use standard editing
    if (points.length < 8) return false;

    // Check if it's a converted circle/ellipse (4 points with Bezier)
    if (shape.hasBezierCurves && shape.bezierPoints != null) {
      // Bezier shapes with few anchors (like circles) use standard Bezier editing
      if (shape.bezierPoints!.length <= 6) return false;
    }

    // Check if it's a simple straight-line polygon (like rectangle/triangle)
    if (_isStraightLinePolygon(points)) return false;

    // Dense curves benefit from weighted editing
    return true;
  }

  /// Checks if a shape should use adaptive subdivision during weighted editing.
  ///
  /// Currently disabled - adaptive subdivision was causing wrinkles.
  /// TODO: Revisit if needed for extreme stretching cases.
  bool needsAdaptiveSubdivision(Shape shape, {int contourIndex = 0}) {
    // Disabled - causes wrinkles during drag
    return false;
  }

  /// Checks if bezier control handles should be hidden for this shape.
  ///
  /// Merged shapes use weighted editing instead of individual bezier handle
  /// manipulation. Circles and simple polygons should still show handles.
  bool shouldHideBezierHandles(Shape shape, {int contourIndex = 0}) {
    return isWeightedEditEligible(shape, contourIndex: contourIndex);
  }

  /// Checks if a polygon is composed of mostly straight line segments.
  /// Returns true for rectangles, triangles, and similar simple shapes.
  bool _isStraightLinePolygon(List<Offset> points) {
    if (points.length < 3) return true;
    if (points.length > 12) return false; // Too many points to be "simple"

    // Detect corners using angle threshold
    const cornerThreshold = math.pi / 6; // ~30 degrees tolerance
    int cornerCount = 0;

    for (var i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final curr = points[i];
      final next = points[(i + 1) % points.length];

      final v1 = prev - curr;
      final v2 = next - curr;

      final angle = _angleBetweenVectors(v1, v2);
      
      // Sharp angle = corner
      if (angle < math.pi - cornerThreshold) {
        cornerCount++;
      }
    }

    // If most points are corners, it's a straight-line polygon
    // (rectangle = 4 corners out of 4 points, triangle = 3 out of 3, etc.)
    return cornerCount >= points.length * 0.7;
  }

  /// Helper to get contour points.
  List<Offset> _getContourPoints(Shape shape, int contourIndex) {
    if (shape.contours.isNotEmpty) {
      if (contourIndex >= 0 && contourIndex < shape.contours.length) {
        return shape.contours[contourIndex].toList();
      }
      return const [];
    }
    if (contourIndex == 0) {
      return shape.points.toList();
    }
    return const [];
  }

  /// Calculates angle between two vectors.
  double _angleBetweenVectors(Offset v1, Offset v2) {
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = v1.distance;
    final mag2 = v2.distance;

    if (mag1 < 0.001 || mag2 < 0.001) return math.pi;

    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosAngle);
  }

  /// Detects corner indices in a contour for weighted edit protection.
  /// Corners are points with sharp angle changes that should be protected.
  Set<int> detectCorners(
    Shape shape, {
    int contourIndex = 0,
    double threshold = math.pi / 4, // 45 degrees
  }) {
    final points = _getContourPoints(shape, contourIndex);
    if (points.length < 3) return const {};

    final corners = <int>{};

    // First and last points are corners for open paths
    if (!shape.isClosed) {
      corners.add(0);
      corners.add(points.length - 1);
    }

    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final v1 = prev - curr;
      final v2 = next - curr;

      final angle = _angleBetweenVectors(v1, v2);

      // Sharp angle = corner
      if (angle < math.pi - threshold) {
        corners.add(i);
      }
    }

    // For closed paths, also check the wrap-around angles
    if (shape.isClosed && points.length >= 3) {
      // Check first point
      final prevFirst = points[points.length - 1];
      final currFirst = points[0];
      final nextFirst = points[1];
      final angleFirst = _angleBetweenVectors(prevFirst - currFirst, nextFirst - currFirst);
      if (angleFirst < math.pi - threshold) {
        corners.add(0);
      }

      // Check last point
      final prevLast = points[points.length - 2];
      final currLast = points[points.length - 1];
      final nextLast = points[0];
      final angleLast = _angleBetweenVectors(prevLast - currLast, nextLast - currLast);
      if (angleLast < math.pi - threshold) {
        corners.add(points.length - 1);
      }
    }

    return corners;
  }

  /// Computes cumulative arc-lengths for each node in a contour.
  /// Returns a list where arcLengths[i] is the distance from node 0 to node i.
  List<double> computeArcLengths(Shape shape, {int contourIndex = 0}) {
    final points = _getContourPoints(shape, contourIndex);
    if (points.isEmpty) return const [];

    final arcLengths = <double>[0.0];
    double cumulative = 0.0;

    for (var i = 1; i < points.length; i++) {
      cumulative += (points[i] - points[i - 1]).distance;
      arcLengths.add(cumulative);
    }

    return arcLengths;
  }

  /// Performs a weighted move on multiple nodes with distance-based falloff.
  /// The active node receives full delta, nearby nodes receive scaled delta.
  /// 
  /// [activeNodeIndex] - The node being directly dragged.
  /// [worldDelta] - The drag delta in world coordinates.
  /// [arcLengths] - Pre-computed arc-lengths for the contour.
  /// [influenceRadius] - Maximum arc-length distance for influence.
  /// [cornerIndices] - Corners that should receive reduced weight.
  Shape moveNodesWeighted(
    Shape shape,
    int activeNodeIndex,
    Offset worldDelta, {
    required List<double> arcLengths,
    required double influenceRadius,
    Set<int> cornerIndices = const {},
    int contourIndex = 0,
  }) {
    return NodeOperations.moveNodesWeighted(
      shape,
      activeNodeIndex,
      worldDelta,
      arcLengths: arcLengths,
      influenceRadius: influenceRadius,
      cornerIndices: cornerIndices,
      contourIndex: contourIndex,
    );
  }

  /// Checks if a shape has multiple contours (e.g., from a merge of disjoint shapes).
  bool hasMultipleContours(Shape shape) {
    return shape.contours.length > 1;
  }

  /// Gets the number of contours in a shape.
  int getContourCount(Shape shape) {
    return NodeOperations.getContourCount(shape);
  }

  /// Explodes a multi-contour shape into separate shapes, one per contour.
  /// Returns null if the shape has 0 or 1 contours.
  /// Each resulting shape inherits styling from the original.
  List<Shape>? explodeContours(Shape shape, String Function() createId) {
    final contourCount = getContourCount(shape);
    if (contourCount <= 1) return null;

    final contours = shape.contours.isNotEmpty
        ? shape.contours
        : [shape.points];

    final results = <Shape>[];
    for (var i = 0; i < contours.length; i++) {
      final contourPoints = contours[i].toList();
      if (contourPoints.length < 2) continue;

      results.add(Shape(
        id: createId(),
        kind: ShapeKind.polygon,
        name: shape.name != null ? '${shape.name} (part ${i + 1})' : null,
        points: contourPoints,
        contours: null, // Single contour, so no multi-contour list needed
        strokeColor: shape.strokeColor,
        strokeWidth: shape.strokeWidth,
        fillColor: shape.fillColor,
        opacity: shape.opacity,
        isVisible: shape.isVisible,
        isLocked: shape.isLocked,
        brushType: shape.brushType,
        isClosed: shape.isClosed,
        // Note: groupId is intentionally NOT inherited - exploded shapes are independent
      ));
    }

    return results.isEmpty ? null : results;
  }

  /// Checks if a shape can be converted to an editable path.
  bool canConvertToPath(Shape shape) {
    return shape.kind == ShapeKind.rectangle ||
        shape.kind == ShapeKind.ellipse;
  }

  /// Converts a rectangle or ellipse shape to an editable polygon.
  /// Returns null if the shape cannot be converted.
  Shape? convertToPath(Shape shape) {
    if (shape.kind == ShapeKind.rectangle) {
      return _convertRectangleToPath(shape);
    } else if (shape.kind == ShapeKind.ellipse) {
      return _convertEllipseToPath(shape);
    }
    return null;
  }

  /// Converts a rectangle shape to a polygon with 4 corner points.
  Shape _convertRectangleToPath(Shape shape) {
    final bounds = shape.bounds;
    if (bounds == null) {
      // Fallback to a unit square
      return shape.copyWith(
        kind: ShapeKind.polygon,
        points: const [
          Offset(0, 0),
          Offset(100, 0),
          Offset(100, 100),
          Offset(0, 100),
        ],
        isClosed: true,
      );
    }

    // Create 4 corner points in local coordinates
    final points = <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
    ];

    return shape.copyWith(
      kind: ShapeKind.polygon,
      points: points,
      isClosed: true,
    );
  }

  /// Converts an ellipse shape to a Bezier curve representation.
  /// Uses 4 anchor points with control handles for a smooth ellipse.
  /// 
  /// This uses the standard circle approximation with cubic Bezier curves:
  /// - 4 anchor points at cardinal directions (right, bottom, left, top)
  /// - Control handles calculated using the magic number k = 4*(sqrt(2)-1)/3 ≈ 0.5523
  Shape _convertEllipseToPath(Shape shape, {bool useBezier = true}) {
    final bounds = shape.bounds;
    if (bounds == null) {
      // Fallback to a unit ellipse
      return _generateEllipseBezier(
        shape,
        const Rect.fromLTWH(0, 0, 100, 100),
      );
    }

    return _generateEllipseBezier(shape, bounds);
  }

  /// Generates a 4-point Bezier approximation of an ellipse.
  /// 
  /// The standard way to approximate an ellipse with Bezier curves uses
  /// 4 points at the cardinal directions with control handles at distance
  /// k * radius, where k = 4*(sqrt(2)-1)/3 ≈ 0.5522847498.
  Shape _generateEllipseBezier(Shape shape, Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2;
    final radiusY = bounds.height / 2;

    // Magic number for Bezier circle approximation
    // k = 4 * (sqrt(2) - 1) / 3 ≈ 0.5522847498
    const k = 0.5522847498;
    final kx = k * radiusX;
    final ky = k * radiusY;

    // 4 anchor points at cardinal directions (right, bottom, left, top)
    // with control handles for smooth curves
    final bezierPoints = <BezierPoint>[
      // Right (3 o'clock)
      BezierPoint(
        position: Offset(centerX + radiusX, centerY),
        controlIn: Offset(0, -ky),  // From top-right curve
        controlOut: Offset(0, ky),   // To bottom-right curve
      ),
      // Bottom (6 o'clock)
      BezierPoint(
        position: Offset(centerX, centerY + radiusY),
        controlIn: Offset(kx, 0),   // From right-bottom curve
        controlOut: Offset(-kx, 0), // To left-bottom curve
      ),
      // Left (9 o'clock)
      BezierPoint(
        position: Offset(centerX - radiusX, centerY),
        controlIn: Offset(0, ky),   // From bottom-left curve
        controlOut: Offset(0, -ky), // To top-left curve
      ),
      // Top (12 o'clock)
      BezierPoint(
        position: Offset(centerX, centerY - radiusY),
        controlIn: Offset(-kx, 0),  // From left-top curve
        controlOut: Offset(kx, 0),  // To right-top curve
      ),
    ];

    // Also create points list for backward compatibility
    final points = bezierPoints.map((bp) => bp.position).toList();

    return shape.copyWith(
      kind: ShapeKind.polygon,
      points: points,
      bezierPoints: bezierPoints,
      isClosed: true,
    );
  }

  /// Legacy method for polygon-based ellipse conversion.
  /// Use _generateEllipseBezier instead for smooth curves.
  Shape _generateEllipsePointsLegacy(Shape shape, Rect bounds, int segments) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2;
    final radiusY = bounds.height / 2;

    final points = <Offset>[];
    for (var i = 0; i < segments; i++) {
      final angle = (2 * math.pi * i) / segments;
      final x = centerX + radiusX * math.cos(angle);
      final y = centerY + radiusY * math.sin(angle);
      points.add(Offset(x, y));
    }

    return shape.copyWith(
      kind: ShapeKind.polygon,
      points: points,
      isClosed: true,
    );
  }

  /// Gets the number of editable nodes in a shape (for a specific contour).
  int getNodeCount(Shape shape, {int contourIndex = 0}) {
    return NodeOperations.getNodeCount(shape, contourIndex: contourIndex);
  }

  /// Hit tests nodes and segments at the given world point (for a specific contour).
  NodeHitResult? hitTest(
    Shape shape,
    Offset worldPoint,
    double viewportScale, {
    int? contourIndex,
  }) {
    return hitTestNodes(shape, worldPoint, viewportScale, contourIndex: contourIndex);
  }

  /// Hit tests nodes and segments across ALL contours of a multi-contour shape.
  /// Returns the hit result with the contour index, or null if nothing was hit.
  NodeHitResult? hitTestAllContours(
    Shape shape,
    Offset worldPoint,
    double viewportScale,
  ) {
    return hitTestNodesAllContours(shape, worldPoint, viewportScale);
  }

  /// Hit tests only nodes (not segments) for a specific contour.
  NodeHitResult? hitTestNodesOnlyForContour(
    Shape shape,
    Offset worldPoint,
    double viewportScale, {
    int? contourIndex,
  }) {
    return hitTestNodesOnly(shape, worldPoint, viewportScale, contourIndex: contourIndex);
  }

  /// Hit tests only nodes across ALL contours.
  /// Useful for selecting a contour by clicking on any of its nodes.
  NodeHitResult? hitTestNodesOnlyAllContours(
    Shape shape,
    Offset worldPoint,
    double viewportScale,
  ) {
    return hitTestNodesOnlyAllContours(shape, worldPoint, viewportScale);
  }

  /// Moves selected nodes by a world-space delta.
  Shape moveNodes(
    Shape shape,
    Set<int> nodeIndices,
    Offset worldDelta, {
    int contourIndex = 0,
  }) {
    return NodeOperations.moveNodes(shape, nodeIndices, worldDelta, contourIndex: contourIndex);
  }

  /// Gets all node positions in world coordinates for a specific contour.
  List<Offset> getNodeWorldPositions(Shape shape, {int contourIndex = 0}) {
    return NodeOperations.getNodeWorldPositions(shape, contourIndex: contourIndex);
  }

  /// Gets all node positions in world coordinates for ALL contours.
  List<List<Offset>> getAllContourWorldPositions(Shape shape) {
    return NodeOperations.getAllContourWorldPositions(shape);
  }

  /// Gets a node's position in world coordinates.
  Offset? getNodeWorldPosition(Shape shape, int index, {int contourIndex = 0}) {
    return NodeOperations.getNodeWorldPosition(shape, index, contourIndex: contourIndex);
  }

  /// Captures drag start positions for undo support.
  Map<int, Offset> captureNodePositions(Shape shape, Set<int> nodeIndices, {int contourIndex = 0}) {
    final positions = <int, Offset>{};
    for (final index in nodeIndices) {
      final pos = NodeOperations.getNodeLocalPosition(shape, index, contourIndex: contourIndex);
      if (pos != null) {
        positions[index] = pos;
      }
    }
    return positions;
  }


  /// Updates the node edit state for a hover event.
  NodeEditState updateHover(
    NodeEditState state,
    NodeHitResult? hitResult,
  ) {
    if (hitResult == null) {
      return state.copyWith(
        clearHoveredNodeIndex: true,
        clearHoveredSegmentIndex: true,
      );
    }

    if (hitResult.hitNode) {
      return state.copyWith(
        hoveredNodeIndex: hitResult.nodeIndex,
        clearHoveredSegmentIndex: true,
      );
    }

    if (hitResult.hitSegment) {
      return state.copyWith(
        clearHoveredNodeIndex: true,
        hoveredSegmentIndex: hitResult.segmentIndex,
      );
    }

    return state.copyWith(
      clearHoveredNodeIndex: true,
      clearHoveredSegmentIndex: true,
    );
  }

}
