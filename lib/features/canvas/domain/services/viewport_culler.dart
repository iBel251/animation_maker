import 'dart:ui';

import '../entities/camera.dart';
import '../entities/shape.dart';
import 'quadtree.dart';

/// Service for culling shapes outside the visible viewport.
///
/// Uses the QuadTree for efficient spatial queries to find only
/// shapes that need to be rendered based on the current camera view.
class ViewportCuller {
  const ViewportCuller();

  /// Returns shapes that are at least partially visible in the current viewport.
  ///
  /// Uses QuadTree for efficient spatial queries.
  /// [marginPercent] adds extra margin around the viewport to include shapes
  /// that are just outside (helps with smooth scrolling).
  List<Shape> cullShapes({
    required List<Shape> shapes,
    required QuadTree quadTree,
    required Camera camera,
    required Size viewportSize,
    double marginPercent = 0.1,
  }) {
    if (shapes.isEmpty) return const [];

    // Calculate visible world rect with margin
    final visibleRect = camera.visibleWorldRect(viewportSize);
    final margin = visibleRect.shortestSide * marginPercent;
    final queryRect = visibleRect.inflate(margin);

    // Use QuadTree for efficient query
    final candidates = quadTree.queryRect(queryRect);

    // The QuadTree already filters by bounds intersection,
    // but we do a final filter to ensure accuracy
    return candidates.where((shape) {
      final bounds = shape.worldBounds;
      return bounds != null && queryRect.overlaps(bounds);
    }).toList();
  }

  /// Returns shapes visible in viewport, preserving the original order.
  ///
  /// This is slower than [cullShapes] but maintains render order.
  /// Use when order matters (e.g., for correct z-ordering).
  List<Shape> cullShapesPreserveOrder({
    required List<Shape> shapes,
    required Camera camera,
    required Size viewportSize,
    double marginPercent = 0.1,
  }) {
    if (shapes.isEmpty) return const [];

    final visibleRect = camera.visibleWorldRect(viewportSize);
    final margin = visibleRect.shortestSide * marginPercent;
    final queryRect = visibleRect.inflate(margin);

    return shapes.where((shape) {
      final bounds = shape.worldBounds;
      return bounds != null && queryRect.overlaps(bounds);
    }).toList();
  }

  /// Returns whether a shape is visible in the current viewport.
  bool isShapeVisible({
    required Shape shape,
    required Camera camera,
    required Size viewportSize,
    double marginPercent = 0.1,
  }) {
    final bounds = shape.worldBounds;
    if (bounds == null) return false;

    final visibleRect = camera.visibleWorldRect(viewportSize);
    final margin = visibleRect.shortestSide * marginPercent;
    final queryRect = visibleRect.inflate(margin);

    return queryRect.overlaps(bounds);
  }

  /// Returns a level-of-detail hint for a shape based on zoom level.
  ///
  /// Returns 0 for full detail, higher values for reduced detail.
  /// This helps optimize rendering of complex shapes at low zoom levels.
  int lodLevel({
    required Shape shape,
    required double zoom,
  }) {
    // Only apply LOD to freehand strokes with many points
    if (shape.kind != ShapeKind.freehand) return 0;
    if (shape.points.length < 50) return 0;

    // Determine LOD based on zoom level
    if (zoom >= 0.5) return 0; // Full detail
    if (zoom >= 0.25) return 1; // Every 2nd point
    if (zoom >= 0.1) return 2; // Every 4th point
    return 3; // Every 8th point
  }

  /// Determines if a freehand stroke should use simplified rendering.
  bool shouldSimplifyStroke({
    required Shape stroke,
    required double zoom,
    int minPointsForSimplification = 50,
    double zoomThreshold = 0.5,
  }) {
    if (stroke.kind != ShapeKind.freehand) return false;
    if (stroke.points.length < minPointsForSimplification) return false;
    return zoom < zoomThreshold;
  }

  /// Returns simplified points for a stroke based on LOD level.
  ///
  /// [lodLevel] determines how many points to skip:
  /// - 0: All points (no simplification)
  /// - 1: Every 2nd point
  /// - 2: Every 4th point
  /// - 3: Every 8th point
  List<Offset> simplifyPoints(List<Offset> points, int lodLevel) {
    if (lodLevel <= 0 || points.length < 4) return points;

    final step = 1 << lodLevel; // 2, 4, or 8
    final simplified = <Offset>[];

    for (var i = 0; i < points.length; i += step) {
      simplified.add(points[i]);
    }

    // Always include the last point for continuity
    if (simplified.isNotEmpty && simplified.last != points.last) {
      simplified.add(points.last);
    }

    return simplified;
  }

  /// Returns simplified point pressures to match simplified points.
  List<double>? simplifyPressures(List<double>? pressures, int lodLevel) {
    if (pressures == null || lodLevel <= 0 || pressures.length < 4) {
      return pressures;
    }

    final step = 1 << lodLevel;
    final simplified = <double>[];

    for (var i = 0; i < pressures.length; i += step) {
      simplified.add(pressures[i]);
    }

    // Always include the last pressure
    if (simplified.isNotEmpty && simplified.last != pressures.last) {
      simplified.add(pressures.last);
    }

    return simplified;
  }

  /// Calculates the approximate screen size of a shape.
  ///
  /// This is useful for deciding whether to render details like
  /// stroke caps, joins, or other fine details.
  double screenSizeOfShape({
    required Shape shape,
    required Camera camera,
    required Size viewportSize,
  }) {
    final bounds = shape.worldBounds;
    if (bounds == null) return 0;

    // Convert world size to screen size
    final worldDiagonal = Offset(bounds.width, bounds.height).distance;
    return camera.worldToScreenDistance(worldDiagonal);
  }

  /// Returns true if the shape is too small on screen to show details.
  ///
  /// [minScreenSize] is the minimum size in screen pixels below which
  /// details should be hidden.
  bool isTooSmallForDetails({
    required Shape shape,
    required Camera camera,
    required Size viewportSize,
    double minScreenSize = 5.0,
  }) {
    return screenSizeOfShape(
          shape: shape,
          camera: camera,
          viewportSize: viewportSize,
        ) <
        minScreenSize;
  }
}
