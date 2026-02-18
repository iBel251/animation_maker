import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Operations for editing nodes on shapes.
class NodeOperations {
  NodeOperations._();

  /// Moves nodes at the given indices by a delta in world coordinates.
  /// Returns a new shape with updated points.
  /// [contourIndex] specifies which contour to edit (default 0 for first/only contour).
  /// 
  /// If the shape has bezierPoints, both the points list AND bezierPoints are updated
  /// to keep them in sync.
  static Shape moveNodes(
    Shape shape,
    Set<int> indices,
    Offset worldDelta, {
    int contourIndex = 0,
  }) {
    if (indices.isEmpty) return shape;

    final points = _getEditablePointsForContour(shape, contourIndex);
    if (points.isEmpty) return shape;

    // Convert world delta to local delta
    final localDelta = _worldDeltaToLocal(shape, worldDelta);

    // Create new points list with moved nodes
    final newPoints = List<Offset>.from(points);
    for (final index in indices) {
      if (index >= 0 && index < newPoints.length) {
        newPoints[index] = newPoints[index] + localDelta;
      }
    }

    // Preserve pressure data (point count doesn't change in move)
    final pressures = contourIndex == 0 ? shape.pointPressures?.toList() : null;

    // If shape has bezierPoints, update them as well to keep in sync
    // (only for contour 0 since bezierPoints are not per-contour)
    if (contourIndex == 0 && shape.bezierPoints != null && shape.bezierPoints!.isNotEmpty) {
      final newBezierPoints = shape.bezierPoints!.toList();
      for (final index in indices) {
        if (index >= 0 && index < newBezierPoints.length) {
          final bp = newBezierPoints[index];
          // Move anchor position; control handles are relative so they move with it
          newBezierPoints[index] = bp.copyWith(
            position: bp.position + localDelta,
          );
        }
      }

      // Also update contours if shape has multiple contours
      // This ensures the rendered shape stays in sync even if bezierPoints is later cleared
      List<List<Offset>>? newContours;
      if (shape.contours.isNotEmpty) {
        newContours = <List<Offset>>[];
        for (var i = 0; i < shape.contours.length; i++) {
          if (i == contourIndex) {
            newContours.add(newPoints);
          } else {
            newContours.add(shape.contours[i].toList());
          }
        }
      }

      final updated = shape.copyWith(
        points: newPoints,
        contours: newContours,
        bezierPoints: newBezierPoints,
        pointPressures: pressures,
      );
      return _compensateForOriginShift(shape, updated);
    }

    return _applyNewPointsToContour(shape, newPoints, contourIndex, newPressures: pressures);
  }

  /// Moves a single node by a delta in world coordinates.
  static Shape moveNode(
    Shape shape,
    int index,
    Offset worldDelta, {
    int contourIndex = 0,
  }) {
    return moveNodes(shape, {index}, worldDelta, contourIndex: contourIndex);
  }


  /// Sets a node's position in local coordinates.
  static Shape setNodePosition(
    Shape shape,
    int index,
    Offset localPosition, {
    int contourIndex = 0,
  }) {
    final points = _getEditablePointsForContour(shape, contourIndex);
    if (index < 0 || index >= points.length) return shape;

    final newPoints = List<Offset>.from(points);
    newPoints[index] = localPosition;

    return _applyNewPointsToContour(shape, newPoints, contourIndex);
  }

  /// Gets the number of editable nodes in a shape (for a specific contour).
  static int getNodeCount(Shape shape, {int contourIndex = 0}) {
    return _getEditablePointsForContour(shape, contourIndex).length;
  }

  /// Gets the total number of contours in a shape.
  static int getContourCount(Shape shape) {
    if (shape.contours.isNotEmpty) {
      return shape.contours.length;
    }
    return shape.points.isEmpty ? 0 : 1;
  }

  /// Gets the local position of a node in a specific contour.
  static Offset? getNodeLocalPosition(Shape shape, int index, {int contourIndex = 0}) {
    final points = _getEditablePointsForContour(shape, contourIndex);
    if (index < 0 || index >= points.length) return null;
    return points[index];
  }

  /// Gets the world position of a node in a specific contour.
  static Offset? getNodeWorldPosition(Shape shape, int index, {int contourIndex = 0}) {
    final localPos = getNodeLocalPosition(shape, index, contourIndex: contourIndex);
    if (localPos == null) return null;
    // Use matrixForRect for consistency with renderer
    final baseBounds = shape.localBounds;
    final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
    return _transformOffset(matrix, localPos);
  }

  /// Gets all node positions in world coordinates for a specific contour.
  static List<Offset> getNodeWorldPositions(Shape shape, {int contourIndex = 0}) {
    final points = _getEditablePointsForContour(shape, contourIndex);
    // Use matrixForRect for consistency with renderer
    final baseBounds = shape.localBounds;
    final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
    return points.map((p) => _transformOffset(matrix, p)).toList();
  }

  /// Gets all node positions in world coordinates for ALL contours.
  /// Returns a list of lists, one per contour.
  ///
  /// For contour 0, uses bezierPoints positions if available (to match what the
  /// renderer draws). This ensures the node overlay and rendered shape stay in sync.
  ///
  /// Uses [matrixForRect] with localBounds to match the renderer's transformation,
  /// ensuring consistent coordinate transformation between overlay and rendered shape.
  static List<List<Offset>> getAllContourWorldPositions(Shape shape) {
    final contourCount = getContourCount(shape);
    // Use the same matrix calculation as the renderer for consistency
    final baseBounds = shape.localBounds;
    final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
    final result = <List<Offset>>[];

    for (var i = 0; i < contourCount; i++) {
      List<Offset> points;
      // For contour 0, prefer bezierPoints positions to stay in sync with rendered shape
      if (i == 0 && shape.hasBezierCurves && shape.bezierPoints != null) {
        points = shape.bezierPoints!.map((bp) => bp.position).toList();
      } else {
        points = _getEditablePointsForContour(shape, i);
      }
      result.add(points.map((p) => _transformOffset(matrix, p)).toList());
    }

    return result;
  }

  // ==================== Bezier Operations ====================

  /// Moves a Bezier anchor point (and its control handles) by a world delta.
  /// Both control handles move with the anchor to preserve the curve shape.
  static Shape moveBezierAnchor(
    Shape shape,
    int index,
    Offset worldDelta,
  ) {
    if (shape.bezierPoints == null || shape.bezierPoints!.isEmpty) return shape;
    if (index < 0 || index >= shape.bezierPoints!.length) return shape;

    final localDelta = _worldDeltaToLocal(shape, worldDelta);
    final newBezierPoints = shape.bezierPoints!.toList();
    final bp = newBezierPoints[index];

    // Move anchor position (control handles are relative, so they move with it)
    newBezierPoints[index] = bp.copyWith(
      position: bp.position + localDelta,
    );

    // Also update the points list for backward compatibility
    final newPoints = shape.points.toList();
    if (index < newPoints.length) {
      newPoints[index] = newBezierPoints[index].position;
    }

    // Also update contours if shape has multiple contours
    List<List<Offset>>? newContours;
    if (shape.contours.isNotEmpty && index < shape.contours.first.length) {
      newContours = <List<Offset>>[];
      for (var i = 0; i < shape.contours.length; i++) {
        if (i == 0) {
          // Update first contour (bezierPoints only covers first contour)
          final contour = shape.contours[i].toList();
          if (index < contour.length) {
            contour[index] = newBezierPoints[index].position;
          }
          newContours.add(contour);
        } else {
          newContours.add(shape.contours[i].toList());
        }
      }
    }

    final updated = shape.copyWith(
      bezierPoints: newBezierPoints,
      points: newPoints,
      contours: newContours,
    );
    return _compensateForOriginShift(shape, updated);
  }

  /// Moves a Bezier control-in handle by a world delta.
  /// The handle position is relative to the anchor.
  static Shape moveBezierControlIn(
    Shape shape,
    int index,
    Offset worldDelta, {
    bool mirrorOpposite = false,
  }) {
    if (shape.bezierPoints == null || shape.bezierPoints!.isEmpty) return shape;
    if (index < 0 || index >= shape.bezierPoints!.length) return shape;

    final localDelta = _worldDeltaToLocal(shape, worldDelta);
    final newBezierPoints = shape.bezierPoints!.toList();
    final bp = newBezierPoints[index];

    if (bp.controlIn == null) return shape;

    final newControlIn = bp.controlIn! + localDelta;
    
    // Optionally mirror to control-out for smooth curves
    Offset? newControlOut = bp.controlOut;
    if (mirrorOpposite && bp.controlOut != null) {
      // Mirror: control-out is opposite direction, same distance
      final distance = newControlIn.distance;
      if (distance > 0.001) {
        final direction = -newControlIn / distance;
        final oldOutDistance = bp.controlOut!.distance;
        newControlOut = direction * oldOutDistance;
      }
    }

    newBezierPoints[index] = bp.copyWith(
      controlIn: newControlIn,
      controlOut: newControlOut,
    );

    return shape.copyWith(bezierPoints: newBezierPoints);
  }

  /// Moves a Bezier control-out handle by a world delta.
  /// The handle position is relative to the anchor.
  static Shape moveBezierControlOut(
    Shape shape,
    int index,
    Offset worldDelta, {
    bool mirrorOpposite = false,
  }) {
    if (shape.bezierPoints == null || shape.bezierPoints!.isEmpty) return shape;
    if (index < 0 || index >= shape.bezierPoints!.length) return shape;

    final localDelta = _worldDeltaToLocal(shape, worldDelta);
    final newBezierPoints = shape.bezierPoints!.toList();
    final bp = newBezierPoints[index];

    if (bp.controlOut == null) return shape;

    final newControlOut = bp.controlOut! + localDelta;
    
    // Optionally mirror to control-in for smooth curves
    Offset? newControlIn = bp.controlIn;
    if (mirrorOpposite && bp.controlIn != null) {
      // Mirror: control-in is opposite direction, same distance
      final distance = newControlOut.distance;
      if (distance > 0.001) {
        final direction = -newControlOut / distance;
        final oldInDistance = bp.controlIn!.distance;
        newControlIn = direction * oldInDistance;
      }
    }

    newBezierPoints[index] = bp.copyWith(
      controlIn: newControlIn,
      controlOut: newControlOut,
    );

    return shape.copyWith(bezierPoints: newBezierPoints);
  }

  /// Gets all Bezier anchor positions in world coordinates.
  static List<Offset> getBezierAnchorWorldPositions(Shape shape) {
    if (shape.bezierPoints == null || shape.bezierPoints!.isEmpty) {
      return const [];
    }
    // Use matrixForRect for consistency with renderer
    final baseBounds = shape.localBounds;
    final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
    return shape.bezierPoints!.map((bp) => _transformOffset(matrix, bp.position)).toList();
  }

  /// Gets all Bezier control handle positions in world coordinates.
  /// Returns a list of (controlIn, controlOut) tuples for each point.
  static List<(Offset?, Offset?)> getBezierControlWorldPositions(Shape shape) {
    if (shape.bezierPoints == null || shape.bezierPoints!.isEmpty) {
      return const [];
    }
    // Use matrixForRect for consistency with renderer
    final baseBounds = shape.localBounds;
    final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
    return shape.bezierPoints!.map((bp) {
      final controlIn = bp.controlIn != null
          ? _transformOffset(matrix, bp.controlInAbsolute)
          : null;
      final controlOut = bp.controlOut != null
          ? _transformOffset(matrix, bp.controlOutAbsolute)
          : null;
      return (controlIn, controlOut);
    }).toList();
  }

  /// Gets the number of Bezier points in a shape.
  static int getBezierPointCount(Shape shape) {
    return shape.bezierPoints?.length ?? 0;
  }

  /// Checks if a shape uses Bezier curves.
  static bool hasBezierCurves(Shape shape) {
    return shape.hasBezierCurves;
  }

  // ==================== Weighted Node Operations ====================

  /// Moves nodes with distance-based weighted falloff from an active node.
  /// 
  /// The active node receives the full [worldDelta]. Nearby nodes receive
  /// a scaled delta based on their arc-length distance from the active node,
  /// using a Gaussian falloff function for smooth morphing.
  /// 
  /// [activeNodeIndex] - The node being directly dragged (receives full delta).
  /// [worldDelta] - The drag delta in world coordinates.
  /// [arcLengths] - Pre-computed cumulative arc-lengths for each node.
  /// [influenceRadius] - Maximum arc-length distance for influence (sigma for Gaussian).
  /// [cornerIndices] - Corner nodes that receive reduced weight (protected).
  /// [contourIndex] - Which contour to edit (default 0).
  static Shape moveNodesWeighted(
    Shape shape,
    int activeNodeIndex,
    Offset worldDelta, {
    required List<double> arcLengths,
    required double influenceRadius,
    Set<int> cornerIndices = const {},
    int contourIndex = 0,
  }) {
    final points = _getEditablePointsForContour(shape, contourIndex);
    if (points.isEmpty) return shape;
    if (activeNodeIndex < 0 || activeNodeIndex >= points.length) return shape;
    if (arcLengths.length != points.length) return shape;

    // Convert world delta to local delta
    final localDelta = _worldDeltaToLocal(shape, worldDelta);
    if (localDelta == Offset.zero) return shape;

    // Compute weights for each node based on arc-length distance
    final weights = _computeWeights(
      activeNodeIndex,
      arcLengths,
      influenceRadius,
      cornerIndices,
      shape.isClosed,
    );

    // Apply weighted delta to all affected nodes
    final newPoints = List<Offset>.from(points);
    for (var i = 0; i < newPoints.length; i++) {
      final weight = weights[i];
      if (weight > 0.001) {
        newPoints[i] = newPoints[i] + localDelta * weight;
      }
    }

    // Preserve pressure data (point count doesn't change in weighted move)
    final pressures = contourIndex == 0 ? shape.pointPressures?.toList() : null;

    // If shape has bezierPoints, update them as well to keep in sync
    // (only for contour 0 since bezierPoints are not per-contour)
    if (contourIndex == 0 && shape.bezierPoints != null && shape.bezierPoints!.isNotEmpty) {
      final newBezierPoints = shape.bezierPoints!.toList();
      final limit = math.min(newBezierPoints.length, weights.length);
      for (var i = 0; i < limit; i++) {
        final weight = weights[i];
        if (weight > 0.001) {
          final bp = newBezierPoints[i];
          newBezierPoints[i] = bp.copyWith(
            position: bp.position + localDelta * weight,
          );
        }
      }

      // Also update contours if shape has multiple contours
      // This ensures the rendered shape stays in sync even if bezierPoints is later cleared
      List<List<Offset>>? newContours;
      if (shape.contours.isNotEmpty) {
        newContours = <List<Offset>>[];
        for (var i = 0; i < shape.contours.length; i++) {
          if (i == contourIndex) {
            newContours.add(newPoints);
          } else {
            newContours.add(shape.contours[i].toList());
          }
        }
      }

      final updated = shape.copyWith(
        points: newPoints,
        contours: newContours,
        bezierPoints: newBezierPoints,
        pointPressures: pressures,
      );
      return _compensateForOriginShift(shape, updated);
    }

    return _applyNewPointsToContour(shape, newPoints, contourIndex, newPressures: pressures);
  }

  /// Computes smooth falloff weights for each node based on arc-length distance.
  ///
  /// Uses a raised-cosine blend between a Gaussian core and a global minimum
  /// floor, so **every** node moves at least a little. This eliminates hard
  /// cutoff boundaries that create sharp leftover spikes.
  ///
  /// weight = max(floor, gaussian) where floor scales with path fraction
  /// so shorter paths have a higher floor (more uniform movement).
  static List<double> _computeWeights(
    int activeIndex,
    List<double> arcLengths,
    double influenceRadius,
    Set<int> cornerIndices,
    bool isClosed,
  ) {
    final n = arcLengths.length;
    if (n == 0) return const [];

    final weights = List<double>.filled(n, 0.0);
    final activeArcLength = arcLengths[activeIndex];
    final totalLength = arcLengths.last;

    // Gaussian sigma — wider = smoother transitions
    final sigma = influenceRadius / 2.0;
    final twoSigmaSquared = 2.0 * sigma * sigma;

    // Global minimum floor weight so no node is ever completely stationary.
    // This prevents the hard boundary that causes sharp kinks.
    // Floor is higher for shorter strokes (more uniform) and lower for
    // very long strokes (so distant parts don't drift noticeably).
    final floor = (30.0 / n).clamp(0.02, 0.12);

    for (var i = 0; i < n; i++) {
      // Compute arc-length distance
      double distance;
      if (isClosed) {
        final directDist = (arcLengths[i] - activeArcLength).abs();
        final wrapDist = totalLength - directDist;
        distance = math.min(directDist, wrapDist);
      } else {
        distance = (arcLengths[i] - activeArcLength).abs();
      }

      // Gaussian falloff with minimum floor
      final gaussian = math.exp(-(distance * distance) / twoSigmaSquared);
      double weight = math.max(gaussian, floor);

      // Corners: slightly reduced but still participates
      if (i != activeIndex && cornerIndices.contains(i)) {
        weight *= 0.6;
      }

      weights[i] = weight;
    }

    // Ensure active node always has weight 1.0
    weights[activeIndex] = 1.0;

    return weights;
  }

  // ==================== Adaptive Subdivision ====================

  /// Subdivides segments that have been stretched beyond a threshold.
  ///
  /// Call this after [moveNodesWeighted] to maintain curve density and prevent
  /// sharp edge formation when dragging nodes on merged shapes.
  ///
  /// [stretchFactor] - Subdivide segments longer than (average * stretchFactor).
  /// [maxSubdivisionsPerCall] - Limit new points per call to prevent runaway.
  /// [contourIndex] - Which contour to process.
  ///
  /// Returns the shape with new points inserted, or original if no subdivision needed.
  static Shape adaptiveSubdivideIfNeeded(
    Shape shape, {
    double stretchFactor = 2.0,
    int maxSubdivisionsPerCall = 5,
    int contourIndex = 0,
  }) {
    final points = _getEditablePointsForContour(shape, contourIndex);
    if (points.length < 3) return shape;

    // Calculate average segment length
    final avgLength = _averageSegmentLength(points, shape.isClosed);
    if (avgLength <= 0) return shape;

    final threshold = avgLength * stretchFactor;

    // Find segments that need subdivision (longest first)
    final segmentsToSplit = <_SegmentInfo>[];
    final segmentCount = shape.isClosed ? points.length : points.length - 1;

    for (var i = 0; i < segmentCount; i++) {
      final nextIdx = (i + 1) % points.length;
      final length = (points[nextIdx] - points[i]).distance;
      if (length > threshold) {
        segmentsToSplit.add(_SegmentInfo(i, length));
      }
    }

    if (segmentsToSplit.isEmpty) return shape;

    // Sort by length descending, then limit
    segmentsToSplit.sort((a, b) => b.length.compareTo(a.length));
    final toProcess = segmentsToSplit.take(maxSubdivisionsPerCall).toList();

    // Sort by index descending so we can insert from end to start
    // (preserving earlier indices)
    toProcess.sort((a, b) => b.index.compareTo(a.index));

    // Build new points list with subdivisions
    final newPoints = points.toList();
    List<double>? newPressures;

    // Save original point count - critical for detecting last segment of closed paths
    final originalPointCount = points.length;

    // Prepare pressure data if present
    if (contourIndex == 0 && shape.pointPressures != null && shape.pointPressures!.isNotEmpty) {
      newPressures = shape.pointPressures!.toList();
    }

    // Process segments from high to low index
    // This ensures insertions at higher indices don't affect lower indices
    for (final seg in toProcess) {
      final i = seg.index;

      // For closed paths, check if this is the last segment (wraps to first point)
      final isLastSegmentOfClosed = shape.isClosed && (i == originalPointCount - 1);

      // Get the two points of this segment
      final p1 = newPoints[i];
      final p2 = isLastSegmentOfClosed ? newPoints[0] : newPoints[i + 1];
      final midpoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      // Insert midpoint after index i
      final insertIdx = i + 1;
      newPoints.insert(insertIdx, midpoint);

      // Handle pressure data - interpolate
      if (newPressures != null && i < newPressures.length) {
        final pressure1 = newPressures[i];
        final pressure2 = isLastSegmentOfClosed
            ? newPressures[0]
            : (i + 1 < newPressures.length ? newPressures[i + 1] : pressure1);
        final midPressure = (pressure1 + pressure2) / 2;

        newPressures.insert(insertIdx, midPressure);
      }
    }

    // Apply the new points
    // For merged shapes (polygons), clear bezierPoints to use simple node-based rendering
    // This avoids bezier/points sync issues and gives cleaner weighted editing
    return _applySubdividedPoints(
      shape,
      newPoints,
      contourIndex,
      newBezierPoints: null, // Clear bezier - use points directly
      newPressures: newPressures,
    );
  }

  /// Calculates the average segment length for a contour.
  static double _averageSegmentLength(List<Offset> points, bool isClosed) {
    if (points.length < 2) return 0.0;

    var totalLength = 0.0;
    final segmentCount = isClosed ? points.length : points.length - 1;

    for (var i = 0; i < segmentCount; i++) {
      final nextIdx = (i + 1) % points.length;
      totalLength += (points[nextIdx] - points[i]).distance;
    }

    return segmentCount > 0 ? totalLength / segmentCount : 0.0;
  }

  /// Applies subdivided points to a shape, handling bezier and pressure data.
  static Shape _applySubdividedPoints(
    Shape shape,
    List<Offset> newPoints,
    int contourIndex, {
    List<BezierPoint>? newBezierPoints,
    List<double>? newPressures,
  }) {
    // Handle multi-contour shapes
    if (shape.contours.isNotEmpty) {
      if (contourIndex < 0 || contourIndex >= shape.contours.length) {
        return shape;
      }

      final newContours = <List<Offset>>[];
      for (var i = 0; i < shape.contours.length; i++) {
        if (i == contourIndex) {
          newContours.add(newPoints);
        } else {
          newContours.add(shape.contours[i].toList());
        }
      }

      final firstContourPoints = contourIndex == 0 ? newPoints : shape.contours.first.toList();

      final updated = shape.copyWith(
        contours: newContours,
        points: firstContourPoints,
        bezierPoints: newBezierPoints,
        pointPressures: newPressures,
      );
      return _compensateForOriginShift(shape, updated);
    }

    // Single contour shape
    if (contourIndex == 0) {
      final updated = shape.copyWith(
        points: newPoints,
        bezierPoints: newBezierPoints,
        pointPressures: newPressures,
      );
      return _compensateForOriginShift(shape, updated);
    }

    return shape;
  }
}

/// Helper class for tracking segment info during subdivision.
class _SegmentInfo {
  const _SegmentInfo(this.index, this.length);
  final int index;
  final double length;
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
List<Offset> _getEditablePoints(Shape shape) {
  return _getEditablePointsForContour(shape, 0);
}

/// Applies new points to a specific contour of a shape, creating a new shape instance.
Shape _applyNewPointsToContour(
  Shape shape,
  List<Offset> newPoints,
  int contourIndex, {
  List<double>? newPressures,
}) {
  // If shape has multiple contours, update the specific contour
  if (shape.contours.isNotEmpty) {
    if (contourIndex < 0 || contourIndex >= shape.contours.length) {
      return shape; // Invalid contour index
    }

    final newContours = <List<Offset>>[];
    for (var i = 0; i < shape.contours.length; i++) {
      if (i == contourIndex) {
        newContours.add(newPoints);
      } else {
        newContours.add(shape.contours[i].toList());
      }
    }

    // Update shape.points to match the first contour for compatibility
    final firstContourPoints = contourIndex == 0 ? newPoints : shape.contours.first.toList();

    final updated = shape.copyWith(
      contours: newContours,
      points: firstContourPoints,
      pointPressures: newPressures,
    );
    return _compensateForOriginShift(shape, updated);
  }

  // Single contour shape - just update points
  if (contourIndex == 0) {
    final updated = shape.copyWith(
      points: newPoints,
      pointPressures: newPressures,
    );
    return _compensateForOriginShift(shape, updated);
  }

  return shape; // Invalid contour index for single-contour shape
}

/// Applies new points to a shape, creating a new shape instance (legacy - first contour only).
Shape _applyNewPoints(
  Shape shape,
  List<Offset> newPoints, {
  List<double>? newPressures,
}) {
  return _applyNewPointsToContour(shape, newPoints, 0, newPressures: newPressures);
}

bool _transformDependsOnOrigin(Shape shape) {
  const epsilon = 1e-6;
  return shape.rotation.abs() > epsilon ||
      (shape.scaleX - 1.0).abs() > epsilon ||
      (shape.scaleY - 1.0).abs() > epsilon;
}

/// Compensates translation when local bounds shift so transformed shapes
/// don't drift during node edits.
Shape _compensateForOriginShift(Shape original, Shape updated) {
  if (!_transformDependsOnOrigin(updated)) return updated;
  final oldBounds = original.localBounds;
  final newBounds = updated.localBounds;
  if (oldBounds == null || newBounds == null) return updated;

  final delta = oldBounds.center - newBounds.center;
  if (delta == Offset.zero) return updated;

  final cosA = math.cos(updated.rotation);
  final sinA = math.sin(updated.rotation);
  final scaledDelta = Offset(
    delta.dx * updated.scaleX,
    delta.dy * updated.scaleY,
  );
  final transformedDelta = Offset(
    cosA * scaledDelta.dx - sinA * scaledDelta.dy,
    sinA * scaledDelta.dx + cosA * scaledDelta.dy,
  );
  final compensation = delta - transformedDelta;

  return updated.copyWith(translation: updated.translation + compensation);
}

Offset _worldDeltaToLocal(Shape shape, Offset worldDelta) {
  // Convert world delta to local delta by undoing rotation and scale
  // so node drags track cursor movement after transforms.
  final rotation = shape.rotation;
  var dx = worldDelta.dx;
  var dy = worldDelta.dy;

  if (rotation != 0) {
    // Apply inverse rotation (rotate by -rotation)
    final cosR = math.cos(-rotation);
    final sinR = math.sin(-rotation);
    final rotatedX = dx * cosR - dy * sinR;
    final rotatedY = dx * sinR + dy * cosR;
    dx = rotatedX;
    dy = rotatedY;
  }

  const minScale = 1e-6;
  final sx = shape.scaleX;
  final sy = shape.scaleY;
  final safeScaleX = sx.abs() < minScale ? 1.0 : sx;
  final safeScaleY = sy.abs() < minScale ? 1.0 : sy;

  return Offset(dx / safeScaleX, dy / safeScaleY);
}

/// Transforms a local offset to world coordinates.
Offset _transformOffset(Matrix4 matrix, Offset local) {
  final v = matrix.transform3(Vector3(local.dx, local.dy, 0));
  return Offset(v.x, v.y);
}
