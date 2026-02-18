import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Spatial hash grid for efficient segment intersection detection.
///
/// Reduces self-intersection checking from O(n²) to O(n) for typical cases
/// by partitioning segments into grid cells and only checking segments
/// that share cells.
class _SpatialHash {
  _SpatialHash({required this.cellSize}) : _grid = {};

  final double cellSize;
  final Map<int, List<_SegmentEntry>> _grid;

  /// Inserts a line segment into the spatial hash.
  void insertSegment(int index, Offset p1, Offset p2) {
    final cells = _getCellsForSegment(p1, p2);
    final entry = _SegmentEntry(index, p1, p2);
    for (final cellKey in cells) {
      _grid.putIfAbsent(cellKey, () => []).add(entry);
    }
  }

  /// Checks if any segments in the hash intersect with non-adjacent segments.
  bool hasIntersections() {
    final checked = <int, Set<int>>{};

    for (final segments in _grid.values) {
      // Only check segments within the same cell
      for (int i = 0; i < segments.length; i++) {
        for (int j = i + 1; j < segments.length; j++) {
          final seg1 = segments[i];
          final seg2 = segments[j];

          // Skip adjacent segments (they share a point)
          if ((seg1.index - seg2.index).abs() <= 1) continue;

          // Skip if already checked this pair
          final minIdx = seg1.index < seg2.index ? seg1.index : seg2.index;
          final maxIdx = seg1.index > seg2.index ? seg1.index : seg2.index;

          final checkedSet = checked.putIfAbsent(minIdx, () => {});
          if (checkedSet.contains(maxIdx)) continue;
          checkedSet.add(maxIdx);

          // Check intersection
          if (_segmentsIntersect(seg1.p1, seg1.p2, seg2.p1, seg2.p2)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Gets all grid cells that a segment passes through.
  Set<int> _getCellsForSegment(Offset p1, Offset p2) {
    final cells = <int>{};

    // Get cell coordinates for endpoints
    final startCellX = (p1.dx / cellSize).floor();
    final startCellY = (p1.dy / cellSize).floor();
    final endCellX = (p2.dx / cellSize).floor();
    final endCellY = (p2.dy / cellSize).floor();

    // Add start and end cells
    cells.add(_getCellKeyFromCoords(startCellX, startCellY));
    cells.add(_getCellKeyFromCoords(endCellX, endCellY));

    // If segment crosses cell boundaries, use DDA-like traversal
    final dx = (p2.dx - p1.dx).abs();
    final dy = (p2.dy - p1.dy).abs();

    if (dx > 0 || dy > 0) {
      // Number of samples proportional to distance traveled in cell space
      final cellsTraversed = ((endCellX - startCellX).abs() + (endCellY - startCellY).abs());
      final samples = (cellsTraversed * 2).clamp(2, 100); // At least 2 samples

      for (int i = 1; i < samples; i++) {
        final t = i / samples;
        final x = p1.dx + (p2.dx - p1.dx) * t;
        final y = p1.dy + (p2.dy - p1.dy) * t;
        final cellX = (x / cellSize).floor();
        final cellY = (y / cellSize).floor();
        cells.add(_getCellKeyFromCoords(cellX, cellY));
      }
    }

    return cells;
  }

  /// Computes a cell key from integer cell coordinates.
  int _getCellKeyFromCoords(int cellX, int cellY) {
    // Szudzik's pairing function for 2D → 1D mapping
    return cellX >= cellY
        ? cellX * cellX + cellX + cellY
        : cellY * cellY + cellX;
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

/// Entry for a line segment in the spatial hash.
class _SegmentEntry {
  const _SegmentEntry(this.index, this.p1, this.p2);

  final int index;
  final Offset p1;
  final Offset p2;
}

class FillUtils {
  static bool canFill(Shape shape) {
    switch (shape.kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.polygon:
        return true;
      case ShapeKind.freehand:
        return isFreehandClosed(shape);
      case ShapeKind.pointPath:
        return shape.isClosed;
      case ShapeKind.line:
      case ShapeKind.image:
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
        if (shape.contours.isNotEmpty) {
          final path = Path();
          for (final contour in shape.contours) {
            if (contour.length < 3) continue;
            path.addPolygon(contour, true);
          }
          if (shape.contours.length > 1) {
            path.fillType = PathFillType.evenOdd;
          }
          return path;
        }
        if (shape.points.length < 3) return null;
        return Path()..addPolygon(shape.points, true);
      case ShapeKind.pointPath:
        if (shape.points.length < 3) return null;
        if (!shape.isClosed) return null;
        return Path()..addPolygon(shape.points, true);
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.line:
      case ShapeKind.image:
        return null; // handled elsewhere for rect/ellipse; images don't fill
    }
  }

  static bool _hasSelfIntersection(List<Offset> points) {
    if (points.length < 4) return false; // Need at least 2 non-adjacent segments

    // Use spatial hashing for O(n) typical case instead of O(n²) brute force
    // Cell size is chosen based on typical stroke density
    final avgDistance = _calculateAveragePointDistance(points);
    final cellSize = avgDistance * 3.0; // 3x average ensures good distribution

    final hash = _SpatialHash(cellSize: cellSize.clamp(10.0, 100.0));

    // Insert all segments into spatial hash
    for (int i = 0; i < points.length - 1; i++) {
      hash.insertSegment(i, points[i], points[i + 1]);
    }

    return hash.hasIntersections();
  }

  /// Calculates average distance between consecutive points for cell size tuning.
  static double _calculateAveragePointDistance(List<Offset> points) {
    if (points.length < 2) return 20.0; // Default fallback

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += (points[i + 1] - points[i]).distance;
    }
    return totalDistance / (points.length - 1);
  }
}



