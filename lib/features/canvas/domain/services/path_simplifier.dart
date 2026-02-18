import 'dart:math' as math;
import 'dart:ui';

/// Simplification result containing both points and optional pressure data.
class SimplificationResult {
  const SimplificationResult({
    required this.points,
    this.pressures,
  });

  final List<Offset> points;
  final List<double>? pressures;
}

/// Path simplification service using the Ramer-Douglas-Peucker algorithm.
///
/// The RDP algorithm reduces the number of points in a curve while preserving
/// its overall shape. It's the industry-standard algorithm for polyline
/// simplification with O(n log n) average performance.
class PathSimplifier {
  const PathSimplifier();

  /// Simplifies a list of points using the Ramer-Douglas-Peucker algorithm.
  ///
  /// [points] - The original list of points to simplify.
  /// [epsilon] - The maximum perpendicular distance threshold. Points within
  ///   this distance from the line between endpoints are removed.
  ///   Larger values produce more aggressive simplification.
  ///
  /// Returns a simplified list of points that preserves the overall shape.
  List<Offset> simplify(List<Offset> points, double epsilon) {
    if (points.length < 3) return List.from(points);
    if (epsilon <= 0) return List.from(points);

    // Use iterative approach to avoid stack overflow on very large paths
    return _simplifyIterative(points, epsilon);
  }

  /// Simplifies points while preserving corresponding pressure data.
  ///
  /// [points] - The original list of points to simplify.
  /// [pressures] - Optional pressure values corresponding to each point.
  /// [epsilon] - The maximum perpendicular distance threshold.
  ///
  /// Returns a [SimplificationResult] with simplified points and interpolated
  /// pressure values for the retained points.
  SimplificationResult simplifyWithPressure(
    List<Offset> points,
    List<double>? pressures,
    double epsilon,
  ) {
    if (points.length < 3) {
      return SimplificationResult(
        points: List.from(points),
        pressures: pressures != null ? List.from(pressures) : null,
      );
    }
    if (epsilon <= 0) {
      return SimplificationResult(
        points: List.from(points),
        pressures: pressures != null ? List.from(pressures) : null,
      );
    }

    // Get the indices of points to keep
    final keepIndices = _getKeptIndices(points, epsilon);

    // Extract points at kept indices
    final simplifiedPoints = <Offset>[];
    List<double>? simplifiedPressures;

    if (pressures != null && pressures.length == points.length) {
      simplifiedPressures = <double>[];
      for (final index in keepIndices) {
        simplifiedPoints.add(points[index]);
        simplifiedPressures.add(pressures[index]);
      }
    } else {
      for (final index in keepIndices) {
        simplifiedPoints.add(points[index]);
      }
    }

    return SimplificationResult(
      points: simplifiedPoints,
      pressures: simplifiedPressures,
    );
  }

  /// Suggests an appropriate epsilon value based on the path bounds and
  /// target point count.
  ///
  /// [points] - The original points.
  /// [targetCount] - Desired approximate number of points after simplification.
  ///
  /// Returns a suggested epsilon value.
  double suggestEpsilon(List<Offset> points, int targetCount) {
    if (points.length <= targetCount) return 0.0;
    if (points.isEmpty) return 0.0;

    // Calculate bounding box diagonal
    double minX = points[0].dx;
    double maxX = points[0].dx;
    double minY = points[0].dy;
    double maxY = points[0].dy;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final diagonal = math.sqrt(
      (maxX - minX) * (maxX - minX) + (maxY - minY) * (maxY - minY),
    );

    // Start with a percentage of the diagonal based on reduction ratio
    final reductionRatio = points.length / targetCount;
    return diagonal * 0.01 * math.sqrt(reductionRatio);
  }

  /// Preset epsilon values for common simplification levels.
  static const double epsilonLow = 1.0;
  static const double epsilonMedium = 3.0;
  static const double epsilonHigh = 6.0;
  static const double epsilonAggressive = 12.0;

  /// Gets an epsilon value scaled by viewport to maintain consistent
  /// visual simplification at different zoom levels.
  double epsilonForViewport(double baseEpsilon, double viewportScale) {
    // At zoom 1.0, use base epsilon
    // At zoom 2.0 (zoomed in), use smaller epsilon for finer control
    // At zoom 0.5 (zoomed out), use larger epsilon
    return baseEpsilon / viewportScale;
  }

  /// Iterative implementation of RDP to avoid stack overflow.
  List<Offset> _simplifyIterative(List<Offset> points, double epsilon) {
    final keepIndices = _getKeptIndices(points, epsilon);
    return keepIndices.map((i) => points[i]).toList();
  }

  /// Returns the indices of points to keep after simplification.
  List<int> _getKeptIndices(List<Offset> points, double epsilon) {
    final n = points.length;
    if (n < 3) return List.generate(n, (i) => i);

    // Bit array to mark which points to keep
    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;

    // Stack for iterative processing: stores (startIndex, endIndex) pairs
    final stack = <(int, int)>[];
    stack.add((0, n - 1));

    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();

      if (end - start < 2) continue;

      // Find the point with maximum distance from the line
      double maxDist = 0;
      int maxIndex = start;

      final startPoint = points[start];
      final endPoint = points[end];

      for (int i = start + 1; i < end; i++) {
        final dist = _perpendicularDistance(points[i], startPoint, endPoint);
        if (dist > maxDist) {
          maxDist = dist;
          maxIndex = i;
        }
      }

      // If max distance > epsilon, keep the point and recurse on both halves
      if (maxDist > epsilon) {
        keep[maxIndex] = true;
        // Process right half first (stack is LIFO, so left will be processed first)
        if (end - maxIndex > 1) {
          stack.add((maxIndex, end));
        }
        if (maxIndex - start > 1) {
          stack.add((start, maxIndex));
        }
      }
    }

    // Collect kept indices in order
    final result = <int>[];
    for (int i = 0; i < n; i++) {
      if (keep[i]) result.add(i);
    }
    return result;
  }

  /// Calculates the perpendicular distance from a point to a line segment.
  double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;

    // If line segment has zero length, return distance to start point
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 0.0001) {
      return (point - lineStart).distance;
    }

    // Calculate perpendicular distance using cross product formula:
    // distance = |cross product| / |line length|
    final cross = (point.dx - lineStart.dx) * dy - (point.dy - lineStart.dy) * dx;
    return cross.abs() / math.sqrt(lengthSquared);
  }
}
