import 'dart:math' as math;
import 'dart:ui';

/// Represents the scene/output camera for animation rendering.
///
/// The scene camera defines what portion of the world space will be visible
/// in the final animation output. It is distinct from the workspace [Camera]
/// which controls the editor viewport.
///
/// The camera's [position] is the center point in world coordinates.
/// The [size] defines the output resolution and aspect ratio.
/// The [zoom] controls how much of the world is visible:
///   - zoom = 1.0: the camera shows a world area equal to [size]
///   - zoom > 1.0: zoomed in (smaller world area visible)
///   - zoom < 1.0: zoomed out (larger world area visible)
class SceneCamera {
  const SceneCamera({
    this.position = const Offset(0, 0),
    this.size = const Size(1920, 1080),
    this.zoom = 1.0,
    this.rotation = 0.0,
  }) : assert(zoom > 0, 'Zoom must be positive');

  /// Center position in world coordinates.
  final Offset position;

  /// Output frame dimensions (defines aspect ratio and base viewport size).
  final Size size;

  /// Zoom level where 1.0 = frame matches [size] in world units.
  /// Values > 1.0 zoom in (less world area visible).
  /// Values < 1.0 zoom out (more world area visible).
  final double zoom;

  /// Rotation of the camera view in radians. Positive = clockwise.
  final double rotation;

  /// Creates a scene camera matching a document's artboard size,
  /// centered on the artboard.
  factory SceneCamera.fromDocument(Size docSize) {
    return SceneCamera(
      position: Offset(docSize.width / 2, docSize.height / 2),
      size: docSize,
      zoom: 1.0,
      rotation: 0.0,
    );
  }

  /// Creates a copy with the given fields replaced.
  SceneCamera copyWith({
    Offset? position,
    Size? size,
    double? zoom,
    double? rotation,
  }) {
    return SceneCamera(
      position: position ?? this.position,
      size: size ?? this.size,
      zoom: zoom ?? this.zoom,
      rotation: rotation ?? this.rotation,
    );
  }

  /// The world-space width visible through this camera.
  double get viewWidth => size.width / zoom;

  /// The world-space height visible through this camera.
  double get viewHeight => size.height / zoom;

  /// The axis-aligned bounding rectangle in world space that this camera sees.
  /// When rotation is non-zero, this is the AABB of the rotated view.
  Rect get viewRect {
    if (rotation == 0.0) {
      return Rect.fromCenter(
        center: position,
        width: viewWidth,
        height: viewHeight,
      );
    }
    // With rotation, compute AABB of the rotated corners
    final corners = viewCorners;
    final minX = corners.map((c) => c.dx).reduce(math.min);
    final maxX = corners.map((c) => c.dx).reduce(math.max);
    final minY = corners.map((c) => c.dy).reduce(math.min);
    final maxY = corners.map((c) => c.dy).reduce(math.max);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// The 4 corner points of the camera view in world space,
  /// accounting for rotation. Order: top-left, top-right, bottom-right, bottom-left.
  List<Offset> get viewCorners {
    final hw = viewWidth / 2;
    final hh = viewHeight / 2;

    // Unrotated corners relative to center
    final corners = [
      Offset(-hw, -hh), // top-left
      Offset(hw, -hh), // top-right
      Offset(hw, hh), // bottom-right
      Offset(-hw, hh), // bottom-left
    ];

    if (rotation == 0.0) {
      return corners.map((c) => c + position).toList(growable: false);
    }

    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    return corners.map((c) {
      final rotated = Offset(
        c.dx * cos - c.dy * sin,
        c.dx * sin + c.dy * cos,
      );
      return rotated + position;
    }).toList(growable: false);
  }

  /// Linearly interpolates between two scene cameras.
  /// Useful for animated camera transitions.
  static SceneCamera lerp(SceneCamera a, SceneCamera b, double t) {
    t = t.clamp(0.0, 1.0);
    return SceneCamera(
      position: Offset.lerp(a.position, b.position, t)!,
      size: Size.lerp(a.size, b.size, t)!,
      zoom: a.zoom + (b.zoom - a.zoom) * t,
      rotation: a.rotation + (b.rotation - a.rotation) * t,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneCamera &&
        other.position == position &&
        other.size == size &&
        other.zoom == zoom &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(position, size, zoom, rotation);

  @override
  String toString() {
    return 'SceneCamera(position: $position, size: $size, '
        'zoom: ${zoom.toStringAsFixed(2)}, '
        'rotation: ${(rotation * 180 / math.pi).toStringAsFixed(1)}°)';
  }
}
