import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

enum ShapeKind {
  freehand,
  rectangle,
  ellipse,
  line,
  polygon,
  pointPath,
  image,
}

/// A point on a Bezier curve with optional control handles.
/// 
/// For cubic Bezier curves, each point has:
/// - [position]: The anchor point position
/// - [controlIn]: The incoming control handle (affects curve approaching this point)
/// - [controlOut]: The outgoing control handle (affects curve leaving this point)
/// 
/// Control handles are relative to the anchor position.
/// If both handles are null, this is a corner point (sharp).
/// If handles are colinear and equidistant, this is a smooth point.
class BezierPoint {
  const BezierPoint({
    required this.position,
    this.controlIn,
    this.controlOut,
  });

  /// The anchor point position in local coordinates.
  final Offset position;

  /// Incoming control handle (relative to position).
  /// If null, the incoming segment is a straight line.
  final Offset? controlIn;

  /// Outgoing control handle (relative to position).
  /// If null, the outgoing segment is a straight line.
  final Offset? controlOut;

  /// Whether this is a corner point (no smooth curve).
  bool get isCorner => controlIn == null && controlOut == null;

  /// Whether this point has smooth tangent handles (colinear).
  bool get isSmooth {
    if (controlIn == null || controlOut == null) return false;
    // Check if handles are approximately colinear
    final inAngle = math.atan2(controlIn!.dy, controlIn!.dx);
    final outAngle = math.atan2(controlOut!.dy, controlOut!.dx);
    final diff = (inAngle - outAngle + math.pi).abs();
    return (diff - math.pi).abs() < 0.01; // ~0.5 degree tolerance
  }

  /// Gets the absolute position of the incoming control point.
  Offset get controlInAbsolute => position + (controlIn ?? Offset.zero);

  /// Gets the absolute position of the outgoing control point.
  Offset get controlOutAbsolute => position + (controlOut ?? Offset.zero);

  BezierPoint copyWith({
    Offset? position,
    Offset? controlIn,
    Offset? controlOut,
    bool clearControlIn = false,
    bool clearControlOut = false,
  }) {
    return BezierPoint(
      position: position ?? this.position,
      controlIn: clearControlIn ? null : (controlIn ?? this.controlIn),
      controlOut: clearControlOut ? null : (controlOut ?? this.controlOut),
    );
  }

  /// Creates a corner point (no handles).
  factory BezierPoint.corner(Offset position) {
    return BezierPoint(position: position);
  }

  /// Creates a smooth point with symmetric handles.
  factory BezierPoint.smooth(Offset position, Offset tangent, double handleLength) {
    final normalized = tangent / tangent.distance;
    return BezierPoint(
      position: position,
      controlIn: -normalized * handleLength,
      controlOut: normalized * handleLength,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BezierPoint &&
        other.position == position &&
        other.controlIn == controlIn &&
        other.controlOut == controlOut;
  }

  @override
  int get hashCode => Object.hash(position, controlIn, controlOut);
}

class Shape {
  Shape({
    required this.id,
    required this.kind,
    this.name,
    Map<String, dynamic>? metadata,
    List<Offset> points = const [],
    List<double>? pointPressures,
    List<List<Offset>>? contours,
    List<BezierPoint>? bezierPoints,
    this.bounds,
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 2.0,
    this.fillColor,
    this.opacity = 1.0,
    this.isVisible = true,
    this.isLocked = false,
    Offset translation = Offset.zero,
    double rotation = 0.0,
    double scale = 1.0,
    double? scaleX,
    double? scaleY,
    Offset pivot = Offset.zero,
    Transform2D? transform,
    this.brushType,
    this.brushSmoothness,
    this.isClosed = false,
    this.groupId,
    this.parentId,
    this.spatialObjectId,
    this.isFlippedH = false,
    this.isFlippedV = false,
    this.imagePath,
    this.imageOriginalSize,
    List<List<Offset>>? eraseContours,
  })  : points = UnmodifiableListView(points),
        pointPressures = _resolvePointPressures(points, pointPressures),
        contours = UnmodifiableListView(
          (contours ?? const <List<Offset>>[])
              .map((c) => UnmodifiableListView(c))
              .toList(growable: false),
        ),
        bezierPoints = bezierPoints == null
            ? null
            : UnmodifiableListView(bezierPoints),
        eraseContours = eraseContours == null || eraseContours.isEmpty
            ? null
            : UnmodifiableListView(
                eraseContours
                    .map((c) => UnmodifiableListView(c))
                    .toList(growable: false),
              ),
        metadata = metadata == null
            ? null
            : Map<String, dynamic>.unmodifiable(metadata),
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
  final String? name;
  final Map<String, dynamic>? metadata;

  /// For freehand/polygon shapes.
  final UnmodifiableListView<Offset> points;

  /// Optional pressure per point (freehand strokes).
  final UnmodifiableListView<double>? pointPressures;

  /// Optional multi-contour data for compound polygons (each contour is local).
  final UnmodifiableListView<UnmodifiableListView<Offset>> contours;

  /// Optional Bezier curve points with control handles.
  /// When non-null, this takes precedence over [points] for rendering.
  /// Used for smooth curves like converted ellipses.
  final UnmodifiableListView<BezierPoint>? bezierPoints;

  /// Whether this shape uses Bezier curves (has bezierPoints data).
  bool get hasBezierCurves => bezierPoints != null && bezierPoints!.isNotEmpty;

  /// Bounding rect for rectangle/ellipse/line definitions.
  final Rect? bounds;

  final Color strokeColor;
  final double strokeWidth;
  final Color? fillColor;
  final double opacity;
  final bool isVisible;
  final bool isLocked;
  final BrushType? brushType;

  /// The smoothness value [0.0, 1.0] used when this freehand shape was drawn.
  /// Null for non-freehand shapes or shapes created before this field existed.
  final double? brushSmoothness;

  final bool isClosed;
  final String? groupId;
  final String? parentId;
  final String? spatialObjectId;
  final bool isFlippedH;
  final bool isFlippedV;

  /// Relative path to the image file within app documents (for image shapes).
  final String? imagePath;

  /// Original pixel dimensions of the image (for aspect ratio preservation).
  final Size? imageOriginalSize;

  /// Erase-mask contours in local (untransformed) space.
  /// Each contour is a closed polygon that visually masks a portion of the
  /// shape at render time. The original geometry is preserved.
  final UnmodifiableListView<UnmodifiableListView<Offset>>? eraseContours;

  /// Whether this shape has an erase mask applied.
  bool get hasEraseMask => eraseContours != null && eraseContours!.isNotEmpty;

  /// Transform information.
  final Transform2D transform;

  /// Backward-compatible uniform scale (average of scaleX/scaleY).
  double get scale => (scaleX + scaleY) * 0.5;
  double get scaleX => transform.scaleX;
  double get scaleY => transform.scaleY;
  double get rotation => transform.rotation;
  Offset get translation => transform.position;

  /// Local (untransformed) bounds. Use [worldBounds] for hit tests.
  ///
  /// Path-driven kinds must prefer geometry bounds to avoid stale `bounds`
  /// values after node edits (for example after rectangle/ellipse -> path).
  Rect? get localBounds {
    final geometryBounds = _boundsFromContours(_geometryContours);
    final bezierBounds = _boundsFromBezierPath();
    switch (kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.image:
        return bounds ?? geometryBounds;
      case ShapeKind.line:
      case ShapeKind.freehand:
        return geometryBounds ?? bounds;
      case ShapeKind.polygon:
      case ShapeKind.pointPath:
        return bezierBounds ?? geometryBounds ?? bounds;
    }
  }

  /// Combined transform matrix (translation * rotation * scale).
  Matrix4 get transformMatrix => transform.matrixWithOrigin(localOrigin);

  Matrix4 matrixForRect(Rect base) => transform.matrixWithOrigin(base.center);

  /// World-space bounds after applying transform to local bounds or points.
  Rect? get worldBounds {
    final base = localBounds;
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
    String? name,
    bool clearName = false,
    Map<String, dynamic>? metadata,
    bool clearMetadata = false,
    List<Offset>? points,
    List<double>? pointPressures,
    List<List<Offset>>? contours,
    List<BezierPoint>? bezierPoints,
    bool clearBezierPoints = false,
    Rect? bounds,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    bool clearFillColor = false,
    double? opacity,
    bool? isVisible,
    bool? isLocked,
    Offset? translation,
    double? rotation,
    double? scale,
    double? scaleX,
    double? scaleY,
    Offset? pivot,
    Transform2D? transform,
    BrushType? brushType,
    double? brushSmoothness,
    bool? isClosed,
    String? groupId,
    bool clearGroupId = false,
    String? parentId,
    bool clearParentId = false,
    String? spatialObjectId,
    bool clearSpatialObjectId = false,
    bool? isFlippedH,
    bool? isFlippedV,
    bool clearPointPressures = false,
    String? imagePath,
    bool clearImagePath = false,
    Size? imageOriginalSize,
    List<List<Offset>>? eraseContours,
    bool clearEraseContours = false,
  }) {
    final nextTransform = transform ??
        this.transform.copyWith(
              position: translation,
              rotation: rotation,
              scaleX: scaleX ?? scale,
              scaleY: scaleY ?? scale,
              pivot: pivot,
            );
    final resolvedContours = contours ??
        this.contours.map((c) => c.toList(growable: false)).toList(
              growable: false,
            );
    final resolvedPoints = points ??
        ((contours != null && contours.isNotEmpty)
            ? contours.first
            : this.points.toList());
    final geometryUpdated = points != null || contours != null;
    final resolvedPointPressures = clearPointPressures
        ? null
        : (pointPressures ??
            (geometryUpdated ? null : this.pointPressures?.toList(growable: false)));
    final resolvedBezierPoints = clearBezierPoints
        ? null
        : (bezierPoints ?? this.bezierPoints?.toList());
    final resolvedEraseContours = clearEraseContours
        ? null
        : (eraseContours ??
            this.eraseContours
                ?.map((c) => c.toList(growable: false))
                .toList(growable: false));
    return Shape(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: clearName ? null : (name ?? this.name),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      points: resolvedPoints,
      pointPressures: resolvedPointPressures,
      contours: resolvedContours,
      bezierPoints: resolvedBezierPoints,
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: clearFillColor ? null : (fillColor ?? this.fillColor),
      opacity: opacity ?? this.opacity,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      transform: nextTransform,
      brushType: brushType ?? this.brushType,
      brushSmoothness: brushSmoothness ?? this.brushSmoothness,
      isClosed: isClosed ?? this.isClosed,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      spatialObjectId: clearSpatialObjectId
          ? null
          : (spatialObjectId ?? this.spatialObjectId),
      isFlippedH: isFlippedH ?? this.isFlippedH,
      isFlippedV: isFlippedV ?? this.isFlippedV,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageOriginalSize: imageOriginalSize ?? this.imageOriginalSize,
      eraseContours: resolvedEraseContours,
    );
  }

  Offset _transformOffset(Matrix4 m, Offset o) {
    final v = m.transform3(Vector3(o.dx, o.dy, 0));
    return Offset(v.x, v.y);
  }

  Iterable<List<Offset>> get geometryContours => _geometryContours;

  Iterable<List<Offset>> get _geometryContours {
    if (contours.isNotEmpty) return contours;
    if (points.isNotEmpty) return [points];
    return const [];
  }

  static UnmodifiableListView<double>? _resolvePointPressures(
    List<Offset> points,
    List<double>? pressures,
  ) {
    if (pressures == null) return null;
    if (pressures.length != points.length) return null;
    return UnmodifiableListView<double>(pressures);
  }

  Rect? _boundsFromContours(Iterable<List<Offset>> contours) {
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;
    for (final contour in contours) {
      for (final p in contour) {
        minX = minX == null ? p.dx : math.min(minX, p.dx);
        maxX = maxX == null ? p.dx : math.max(maxX, p.dx);
        minY = minY == null ? p.dy : math.min(minY, p.dy);
        maxY = maxY == null ? p.dy : math.max(maxY, p.dy);
      }
    }
    if (minX == null || maxX == null || minY == null || maxY == null) {
      return null;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
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

  Rect? _boundsFromBezierPath() {
    final points = bezierPoints;
    if (points == null || points.length < 2) return null;

    final closePath = isClosed;
    final path = Path()..moveTo(points.first.position.dx, points.first.position.dy);
    for (var i = 0; i < points.length; i++) {
      final nextIndex = (i + 1) % points.length;
      if (!closePath && nextIndex == 0) break;
      final current = points[i];
      final next = points[nextIndex];
      final p1 = current.controlOutAbsolute;
      final p2 = next.controlInAbsolute;
      final p3 = next.position;
      path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    }
    if (closePath) {
      path.close();
    }

    final bounds = path.getBounds();
    if (!bounds.width.isFinite || !bounds.height.isFinite) return null;
    return bounds;
  }

  Offset get localOrigin {
    final base = localBounds;
    return base?.center ?? Offset.zero;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Shape && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
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
