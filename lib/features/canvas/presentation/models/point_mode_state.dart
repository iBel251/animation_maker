import 'dart:ui';

/// Types of connections between points in point mode drawing.
enum PointConnectionType {
  /// Connect points with straight lines.
  straight,

  /// Connect points with smooth Bezier curves.
  curved,
}

/// State for point-mode drawing session.
///
/// Point mode allows users to place points by tapping on the canvas,
/// then connect them with straight lines or curves to create a shape.
class PointModeState {
  const PointModeState({
    this.isActive = false,
    this.connectionType = PointConnectionType.straight,
    this.placedPoints = const [],
    this.isClosed = false,
    this.previewShapeId,
  });

  /// Initial/default state.
  static const initial = PointModeState();

  /// Whether point mode is currently active.
  final bool isActive;

  /// The type of connection between points.
  final PointConnectionType connectionType;

  /// The points that have been placed on the canvas.
  final List<Offset> placedPoints;

  /// Whether the shape should be closed (connect last point to first).
  final bool isClosed;

  /// The ID of the preview shape being displayed while drawing.
  final String? previewShapeId;

  /// Whether any points have been placed.
  bool get hasPoints => placedPoints.isNotEmpty;

  /// Whether enough points exist to create a connection (2+).
  bool get canConnect => placedPoints.length >= 2;

  /// Whether enough points exist to close the shape (3+).
  bool get canClose => placedPoints.length >= 3;

  /// Number of placed points.
  int get pointCount => placedPoints.length;

  PointModeState copyWith({
    bool? isActive,
    PointConnectionType? connectionType,
    List<Offset>? placedPoints,
    bool? isClosed,
    String? previewShapeId,
    bool clearPreviewShapeId = false,
  }) {
    return PointModeState(
      isActive: isActive ?? this.isActive,
      connectionType: connectionType ?? this.connectionType,
      placedPoints: placedPoints ?? this.placedPoints,
      isClosed: isClosed ?? this.isClosed,
      previewShapeId: clearPreviewShapeId
          ? null
          : (previewShapeId ?? this.previewShapeId),
    );
  }

  /// Creates a new state with an additional point.
  PointModeState addPoint(Offset point) {
    return copyWith(
      placedPoints: [...placedPoints, point],
    );
  }

  /// Creates a new state with the last point removed.
  PointModeState removeLastPoint() {
    if (placedPoints.isEmpty) return this;
    return copyWith(
      placedPoints: placedPoints.sublist(0, placedPoints.length - 1),
    );
  }

  /// Creates a reset state (keeps active but clears points).
  PointModeState reset() {
    return const PointModeState(isActive: true);
  }
}
