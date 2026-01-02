import 'dart:collection';
import 'dart:ui';

import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

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
    Offset translation = Offset.zero,
    double rotation = 0.0,
    double scale = 1.0,
    double? scaleX,
    double? scaleY,
    Offset pivot = Offset.zero,
    Transform2D? transform,
    this.brushType,
    this.isClosed = false,
    this.groupId,
    this.isFlippedH = false,
    this.isFlippedV = false,
  })  : points = UnmodifiableListView(points),
        transform = transform ??
            Transform2D(
              position: translation,
              rotation: rotation,
              scaleX: scaleX ?? scale,
              scaleY: scaleY ?? scale,
              pivot: pivot,
            );

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
  final BrushType? brushType;
  final bool isClosed;
  final String? groupId;
  final bool isFlippedH;
  final bool isFlippedV;

  /// Transform information.
  final Transform2D transform;

  /// Backward-compatible uniform scale (average of scaleX/scaleY).
  double get scale => (scaleX + scaleY) * 0.5;
  double get scaleX => transform.scaleX;
  double get scaleY => transform.scaleY;
  double get rotation => transform.rotation;
  Offset get translation => transform.position;

  /// Local (untransformed) bounds. Use [worldBounds] for hit tests.
  Rect? get localBounds => bounds;

  /// Combined transform matrix (translation * rotation * scale).
  Matrix4 get transformMatrix => transform.matrixWithOrigin(localOrigin);

  Matrix4 matrixForRect(Rect base) => transform.matrixWithOrigin(base.center);

  /// World-space bounds after applying transform to local bounds or points.
  Rect? get worldBounds {
    final base = bounds ?? _boundsFromPoints(points);
    if (base == null) return null;
    final corners = <Offset>[
      base.topLeft,
      base.topRight,
      base.bottomRight,
      base.bottomLeft,
    ].map((p) => _transformOffset(transformMatrix, p)).toList(growable: false);
    return _boundsFromPoints(corners);
  }

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
    double? scaleX,
    double? scaleY,
    Offset? pivot,
    Transform2D? transform,
    BrushType? brushType,
    bool? isClosed,
    String? groupId,
    bool? isFlippedH,
    bool? isFlippedV,
  }) {
    final nextTransform = transform ??
        this.transform.copyWith(
              position: translation,
              rotation: rotation,
              scaleX: scaleX ?? scale,
              scaleY: scaleY ?? scale,
              pivot: pivot,
            );
    return Shape(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      points: points ?? this.points.toList(),
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
      transform: nextTransform,
      brushType: brushType ?? this.brushType,
      isClosed: isClosed ?? this.isClosed,
      groupId: groupId ?? this.groupId,
      isFlippedH: isFlippedH ?? this.isFlippedH,
      isFlippedV: isFlippedV ?? this.isFlippedV,
    );
  }

  Offset _transformOffset(Matrix4 m, Offset o) {
    final v = m.transform3(Vector3(o.dx, o.dy, 0));
    return Offset(v.x, v.y);
  }

  Rect? _boundsFromPoints(List<Offset> pts) {
    if (pts.isEmpty) return null;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset get localOrigin {
    final base = bounds ?? _boundsFromPoints(points);
    return base?.center ?? Offset.zero;
  }
}

class Transform2D {
  const Transform2D({
    this.position = Offset.zero,
    this.rotation = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.pivot = Offset.zero,
    Matrix4? matrix,
  }) : _matrix = matrix;

  final Offset position;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final Offset pivot;
  final Matrix4? _matrix;

  Transform2D copyWith({
    Offset? position,
    double? rotation,
    double? scaleX,
    double? scaleY,
    Offset? pivot,
  }) {
    return Transform2D(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      pivot: pivot ?? this.pivot,
    );
  }

  Matrix4 matrixWithOrigin(Offset origin) {
    final pivotWorld = origin + pivot;
    final m = Matrix4.identity()
      ..translate(position.dx, position.dy)
      ..translate(pivotWorld.dx, pivotWorld.dy)
      ..rotateZ(rotation)
      ..scale(scaleX, scaleY, 1.0)
      ..translate(-pivotWorld.dx, -pivotWorld.dy);
    return m;
  }
}
