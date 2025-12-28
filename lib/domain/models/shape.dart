import 'dart:collection';
import 'dart:ui';

enum ShapeKind {
  freehand,
  rectangle,
  ellipse,
  line,
  polygon,
}

class Shape {
  Shape({
    required this.id,
    required this.kind,
    List<Offset> points = const [],
    this.bounds,
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 2.0,
    this.fillColor,
    this.opacity = 1.0,
    this.translation = Offset.zero,
    this.rotation = 0.0,
    this.scale = 1.0,
  }) : points = UnmodifiableListView(points);

  final String id;
  final ShapeKind kind;

  /// For freehand/polygon shapes.
  final UnmodifiableListView<Offset> points;

  /// Bounding rect for rectangle/ellipse/line definitions.
  final Rect? bounds;

  final Color strokeColor;
  final double strokeWidth;
  final Color? fillColor;
  final double opacity;

  /// Transform information.
  final Offset translation;
  final double rotation;
  final double scale;

  Shape copyWith({
    String? id,
    ShapeKind? kind,
    List<Offset>? points,
    Rect? bounds,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    double? opacity,
    Offset? translation,
    double? rotation,
    double? scale,
  }) {
    return Shape(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      points: points ?? this.points.toList(),
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
      translation: translation ?? this.translation,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }
}
