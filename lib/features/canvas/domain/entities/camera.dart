import 'dart:ui';
import 'dart:math' as math;

/// Represents the camera/viewport state for the canvas.
///
/// The camera defines what portion of the infinite world space is visible.
/// It uses a position (center point in world coordinates), zoom level, and
/// optional rotation to transform between world and screen coordinates.
///
/// Coordinate Spaces:
/// - World Space: Infinite 2D plane where shapes exist (origin at artboard top-left)
/// - Screen Space: Device viewport coordinates (origin at widget top-left)
///
/// Transform Pipeline: World Space → Camera Transform → Screen Space
class Camera {
  const Camera({
    this.position = const Offset(0, 0),
    this.zoom = 1.0,
    this.rotation = 0.0,
  }) : assert(zoom > 0, 'Zoom must be positive');

  /// Camera center position in world coordinates.
  ///
  /// Moving the camera right (positive x) makes world content move left on screen.
  /// Default is (0, 0) which centers the camera at the artboard's top-left.
  final Offset position;

  /// Zoom level where 1.0 = 100%.
  ///
  /// Values > 1.0 zoom in (content appears larger).
  /// Values < 1.0 zoom out (content appears smaller).
  /// Must be positive.
  final double zoom;

  /// Canvas rotation in radians.
  ///
  /// Positive values rotate clockwise.
  /// Default is 0.0 (no rotation).
  final double rotation;

  /// Creates a camera that fits the given world rect in the viewport with padding.
  factory Camera.fitRect({
    required Rect worldRect,
    required Size viewportSize,
    double paddingPercent = 0.05,
  }) {
    if (worldRect.isEmpty || viewportSize.isEmpty) {
      return const Camera();
    }

    // Calculate the zoom needed to fit the rect
    final padding = math.min(viewportSize.width, viewportSize.height) * paddingPercent;
    final availableWidth = viewportSize.width - (padding * 2);
    final availableHeight = viewportSize.height - (padding * 2);

    final zoomX = availableWidth / worldRect.width;
    final zoomY = availableHeight / worldRect.height;
    final zoom = math.min(zoomX, zoomY);

    // Center the camera on the rect's center
    final position = worldRect.center;

    return Camera(position: position, zoom: zoom);
  }

  /// Creates a camera centered on a point at a specific zoom level.
  factory Camera.centered({
    required Offset worldPoint,
    required double zoom,
    double rotation = 0.0,
  }) {
    return Camera(
      position: worldPoint,
      zoom: zoom,
      rotation: rotation,
    );
  }

  /// Creates a copy of this camera with the given fields replaced.
  Camera copyWith({
    Offset? position,
    double? zoom,
    double? rotation,
  }) {
    return Camera(
      position: position ?? this.position,
      zoom: zoom ?? this.zoom,
      rotation: rotation ?? this.rotation,
    );
  }

  /// Converts a world coordinate to screen coordinate.
  ///
  /// The viewport center is used as the screen-space anchor point.
  /// The camera position determines what world point appears at screen center.
  Offset worldToScreen(Offset worldPoint, Size viewportSize) {
    // Translate relative to camera position
    var point = worldPoint - position;

    // Apply rotation around camera center (if any)
    if (rotation != 0) {
      final cos = math.cos(rotation);
      final sin = math.sin(rotation);
      point = Offset(
        point.dx * cos - point.dy * sin,
        point.dx * sin + point.dy * cos,
      );
    }

    // Apply zoom
    point = point * zoom;

    // Translate to screen center
    return point + Offset(viewportSize.width / 2, viewportSize.height / 2);
  }

  /// Converts a screen coordinate to world coordinate.
  ///
  /// This is the inverse of [worldToScreen].
  Offset screenToWorld(Offset screenPoint, Size viewportSize) {
    // Translate from screen center
    var point = screenPoint - Offset(viewportSize.width / 2, viewportSize.height / 2);

    // Remove zoom
    point = point / zoom;

    // Remove rotation (apply inverse rotation)
    if (rotation != 0) {
      final cos = math.cos(-rotation);
      final sin = math.sin(-rotation);
      point = Offset(
        point.dx * cos - point.dy * sin,
        point.dx * sin + point.dy * cos,
      );
    }

    // Translate back to world space
    return point + position;
  }

  /// Returns the world-space rect visible in the viewport.
  ///
  /// This is useful for viewport culling - only shapes intersecting
  /// this rect need to be rendered.
  Rect visibleWorldRect(Size viewportSize) {
    // Get the four corners of the screen in world space
    final topLeft = screenToWorld(Offset.zero, viewportSize);
    final topRight = screenToWorld(Offset(viewportSize.width, 0), viewportSize);
    final bottomLeft = screenToWorld(Offset(0, viewportSize.height), viewportSize);
    final bottomRight = screenToWorld(
      Offset(viewportSize.width, viewportSize.height),
      viewportSize,
    );

    // Find the bounding box of these corners
    // (handles rotation where corners may not be axis-aligned)
    final minX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx]
        .reduce(math.min);
    final maxX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx]
        .reduce(math.max);
    final minY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy]
        .reduce(math.min);
    final maxY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy]
        .reduce(math.max);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns true if the given world rect is at least partially visible.
  ///
  /// Uses [visibleWorldRect] to check for intersection.
  bool isRectVisible(Rect worldRect, Size viewportSize) {
    return visibleWorldRect(viewportSize).overlaps(worldRect);
  }

  /// Returns true if the given world point is visible in the viewport.
  bool isPointVisible(Offset worldPoint, Size viewportSize) {
    return visibleWorldRect(viewportSize).contains(worldPoint);
  }

  /// Linearly interpolates between two camera states.
  ///
  /// Useful for animated camera transitions.
  /// [t] is clamped to [0.0, 1.0].
  static Camera lerp(Camera a, Camera b, double t) {
    t = t.clamp(0.0, 1.0);
    return Camera(
      position: Offset.lerp(a.position, b.position, t)!,
      zoom: a.zoom + (b.zoom - a.zoom) * t,
      rotation: a.rotation + (b.rotation - a.rotation) * t,
    );
  }

  /// Returns the world-space distance corresponding to a screen-space distance.
  ///
  /// Useful for calculating tolerances that should remain constant on screen.
  double screenToWorldDistance(double screenDistance) {
    return screenDistance / zoom;
  }

  /// Returns the screen-space distance corresponding to a world-space distance.
  ///
  /// Useful for scaling UI elements that should maintain world-space size.
  double worldToScreenDistance(double worldDistance) {
    return worldDistance * zoom;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Camera &&
        other.position == position &&
        other.zoom == zoom &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(position, zoom, rotation);

  @override
  String toString() {
    return 'Camera(position: $position, zoom: ${zoom.toStringAsFixed(2)}, '
        'rotation: ${(rotation * 180 / math.pi).toStringAsFixed(1)}°)';
  }
}
