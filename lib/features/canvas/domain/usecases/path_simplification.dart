import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Path simplification algorithms for reducing complexity of freehand drawings.
class PathSimplification {
  PathSimplification._();

  /// Simplifies a list of points using the Ramer-Douglas-Peucker algorithm.
  /// 
  /// [points] - The original points to simplify.
  /// [tolerance] - Maximum perpendicular distance for point removal.
  ///   Higher values = fewer points (more simplification).
  ///   Typical values: 1.0 (light), 3.0 (medium), 5.0 (heavy).
  static List<Offset> rdpSimplify(List<Offset> points, double tolerance) {
    if (points.length < 3) return points.toList();
    
    return _rdpRecursive(points, 0, points.length - 1, tolerance);
  }

  static List<Offset> _rdpRecursive(
    List<Offset> points,
    int start,
    int end,
    double tolerance,
  ) {
    if (end - start < 2) {
      return [points[start], points[end]];
    }

    // Find the point with maximum distance from the line segment
    double maxDist = 0;
    int maxIndex = start;

    final lineStart = points[start];
    final lineEnd = points[end];

    for (var i = start + 1; i < end; i++) {
      final dist = _perpendicularDistance(points[i], lineStart, lineEnd);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDist > tolerance) {
      final left = _rdpRecursive(points, start, maxIndex, tolerance);
      final right = _rdpRecursive(points, maxIndex, end, tolerance);
      
      // Combine results (exclude duplicate middle point)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // All points between start and end are close to the line
      return [points[start], points[end]];
    }
  }

  /// Calculates perpendicular distance from a point to a line segment.
  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    
    final lengthSquared = dx * dx + dy * dy;
    
    if (lengthSquared == 0) {
      // Line segment is a point
      return (point - lineStart).distance;
    }
    
    // Calculate perpendicular distance using cross product
    final cross = (point.dx - lineStart.dx) * dy - (point.dy - lineStart.dy) * dx;
    return cross.abs() / math.sqrt(lengthSquared);
  }

  /// Fits Bezier curves to a list of points using a simplified algorithm.
  /// Returns BezierPoints that approximate the original path with smooth curves.
  /// 
  /// [points] - The points to fit curves to.
  /// [tolerance] - Error tolerance for curve fitting.
  /// [cornerAngleThreshold] - Angle in radians above which a point is considered a corner.
  static List<BezierPoint> fitBezierCurves(
    List<Offset> points, {
    double tolerance = 2.0,
    double cornerAngleThreshold = math.pi / 4, // 45 degrees
  }) {
    if (points.isEmpty) return [];
    if (points.length == 1) {
      return [BezierPoint.corner(points.first)];
    }
    if (points.length == 2) {
      return [
        BezierPoint.corner(points.first),
        BezierPoint.corner(points.last),
      ];
    }

    // Skip simplification if tolerance <= 0 (preserves all points for node editing sync)
    final simplified = tolerance > 0 ? rdpSimplify(points, tolerance) : points;

    // Detect corners (sharp angle changes)
    final corners = _detectCorners(simplified, cornerAngleThreshold);

    // Generate Bezier points with control handles
    return _generateBezierPoints(simplified, corners);
  }

  /// Detects corner indices based on angle changes.
  static Set<int> _detectCorners(List<Offset> points, double threshold) {
    final corners = <int>{0, points.length - 1}; // First and last are always corners
    
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      final v1 = prev - curr;
      final v2 = next - curr;
      
      final angle = _angleBetweenVectors(v1, v2);
      
      // If angle is sharp (less than 180 - threshold degrees), it's a corner
      if (angle < math.pi - threshold) {
        corners.add(i);
      }
    }
    
    return corners;
  }

  /// Calculates angle between two vectors.
  static double _angleBetweenVectors(Offset v1, Offset v2) {
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = v1.distance;
    final mag2 = v2.distance;
    
    if (mag1 < 0.001 || mag2 < 0.001) return math.pi;
    
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosAngle);
  }

  /// Generates BezierPoints with smooth control handles using improved curvature estimation.
  static List<BezierPoint> _generateBezierPoints(List<Offset> points, Set<int> corners) {
    if (points.isEmpty) return [];

    final result = <BezierPoint>[];
    final n = points.length;

    for (var i = 0; i < n; i++) {
      final point = points[i];
      final isCorner = corners.contains(i);

      if (isCorner) {
        // Corner point - no control handles
        result.add(BezierPoint.corner(point));
      } else {
        // Smooth point - use Catmull-Rom style tangent calculation
        // This considers multiple neighbors for smoother curves
        final tangent = _computeSmoothTangent(points, i, corners);
        final tangentLength = tangent.distance;

        if (tangentLength < 0.001) {
          result.add(BezierPoint.corner(point));
          continue;
        }

        final tangentNormalized = tangent / tangentLength;

        // Calculate handle lengths based on distances and local curvature
        final prev = i > 0 ? points[i - 1] : point;
        final next = i < n - 1 ? points[i + 1] : point;
        final distToPrev = (point - prev).distance;
        final distToNext = (next - point).distance;

        // Adaptive handle length: use 1/3 for curves, adjusted by local curvature
        // This creates smoother transitions for curved sections
        final curvature = _estimateLocalCurvature(points, i);
        final handleFactor = 0.33 * (1.0 - curvature * 0.3).clamp(0.2, 0.4);

        final handleLengthIn = distToPrev * handleFactor;
        final handleLengthOut = distToNext * handleFactor;

        result.add(BezierPoint(
          position: point,
          controlIn: Offset(
            -tangentNormalized.dx * handleLengthIn,
            -tangentNormalized.dy * handleLengthIn,
          ),
          controlOut: Offset(
            tangentNormalized.dx * handleLengthOut,
            tangentNormalized.dy * handleLengthOut,
          ),
        ));
      }
    }

    return result;
  }

  /// Computes a smooth tangent at point i using Catmull-Rom style interpolation.
  /// This looks at multiple neighbors for smoother curves.
  static Offset _computeSmoothTangent(List<Offset> points, int i, Set<int> corners) {
    final n = points.length;
    if (n < 2) return Offset.zero;

    // Find non-corner neighbors
    int prevIdx = i - 1;
    int nextIdx = i + 1;

    // Clamp to valid range
    prevIdx = prevIdx.clamp(0, n - 1);
    nextIdx = nextIdx.clamp(0, n - 1);

    final prev = points[prevIdx];
    final next = points[nextIdx];

    // Basic tangent from prev to next
    var tangent = next - prev;

    // If we have enough points, use weighted average for smoother result
    if (n >= 4) {
      final prev2Idx = (i - 2).clamp(0, n - 1);
      final next2Idx = (i + 2).clamp(0, n - 1);

      // Only consider extended neighbors if they're not corners
      if (!corners.contains(prev2Idx) && !corners.contains(next2Idx)) {
        final prev2 = points[prev2Idx];
        final next2 = points[next2Idx];

        // Weight closer neighbors more heavily (3:1 ratio)
        final extendedTangent = next2 - prev2;
        tangent = tangent * 0.75 + extendedTangent * 0.25;
      }
    }

    return tangent;
  }

  /// Estimates local curvature at point i (0 = straight, 1 = sharp curve).
  static double _estimateLocalCurvature(List<Offset> points, int i) {
    final n = points.length;
    if (n < 3 || i <= 0 || i >= n - 1) return 0.0;

    final prev = points[i - 1];
    final curr = points[i];
    final next = points[i + 1];

    final v1 = prev - curr;
    final v2 = next - curr;

    final mag1 = v1.distance;
    final mag2 = v2.distance;

    if (mag1 < 0.001 || mag2 < 0.001) return 0.0;

    // Calculate angle between vectors
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    final angle = math.acos(cosAngle);

    // Convert to curvature (0 at 180°, 1 at 0°)
    return 1.0 - (angle / math.pi);
  }

  /// Simplifies a shape's path and converts it to Bezier curves.
  /// Returns a new shape with reduced points and bezierPoints data.
  /// 
  /// [shape] - The shape to simplify.
  /// [tolerance] - Simplification tolerance (higher = fewer points).
  /// [convertToBezier] - Whether to convert to smooth Bezier curves.
  static Shape simplifyShape(
    Shape shape, {
    double tolerance = 2.0,
    bool convertToBezier = true,
  }) {
    if (shape.points.length < 3) return shape;

    // Simplify the points
    final simplified = rdpSimplify(shape.points.toList(), tolerance);
    
    if (convertToBezier) {
      // Convert to Bezier curves
      final bezierPoints = fitBezierCurves(simplified, tolerance: tolerance * 0.5);
      
      return shape.copyWith(
        kind: ShapeKind.polygon,
        points: simplified,
        bezierPoints: bezierPoints,
      );
    } else {
      // Just simplify without Bezier conversion
      return shape.copyWith(
        kind: ShapeKind.polygon,
        points: simplified,
        clearBezierPoints: true,
      );
    }
  }

  /// Calculates the reduction ratio (for UI feedback).
  /// Returns a value between 0 and 1 where 1 means no reduction.
  static double calculateReductionRatio(int originalCount, int simplifiedCount) {
    if (originalCount == 0) return 1.0;
    return simplifiedCount / originalCount;
  }
}
