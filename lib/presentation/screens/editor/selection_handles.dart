import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

enum TransformHandle { scaleUniform, scaleX, scaleY, rotate, pivot }

class HandleHit {
  HandleHit({
    required this.type,
    required this.center,
    required this.startDistance,
    required this.startAngle,
    this.axis,
  });

  final TransformHandle type;
  final Offset center;
  final double startDistance;
  final double startAngle;
  final Offset? axis;
}

HandleHit? hitTestHandle(Shape shape, Offset posCanvas, double viewportScale) {
  final base = shape.bounds ?? boundsFromPoints(shape.points);
  if (base == null) return null;
  final matrix = shape.matrixForRect(base);
  final corners = transformedCorners(base, matrix);
  final center = Offset(
    (corners[0].dx + corners[2].dx) / 2,
    (corners[0].dy + corners[2].dy) / 2,
  );
  final handleSize = 12 / viewportScale;
  final half = handleSize / 2;
  final pivotRadius = handleSize * 0.8; // slightly larger hit for pivot

  // Pivot handle: give it priority so overlaps favor the pivot.
  final pivotWorld = _pivotWorld(base, shape);
  final pivotRect = Rect.fromCircle(center: pivotWorld, radius: pivotRadius);
  if (pivotRect.contains(posCanvas)) {
    return HandleHit(
      type: TransformHandle.pivot,
      center: pivotWorld,
      startDistance: 0,
      startAngle: 0,
    );
  }

  // Corner handles (uniform scale).
  for (final c in corners) {
    final rect = Rect.fromLTWH(
      c.dx - half,
      c.dy - half,
      handleSize,
      handleSize,
    );
    if (rect.contains(posCanvas)) {
      final dist = (c - center).distance;
      return HandleHit(
        type: TransformHandle.scaleUniform,
        center: center,
        startDistance: dist,
        startAngle: 0,
      );
    }
  }

  // Edge handles (axis scale).
  final topCenter = Offset(
    (corners[0].dx + corners[1].dx) / 2,
    (corners[0].dy + corners[1].dy) / 2,
  );
  final rightCenter = Offset(
    (corners[1].dx + corners[2].dx) / 2,
    (corners[1].dy + corners[2].dy) / 2,
  );
  final bottomCenter = Offset(
    (corners[2].dx + corners[3].dx) / 2,
    (corners[2].dy + corners[3].dy) / 2,
  );
  final leftCenter = Offset(
    (corners[3].dx + corners[0].dx) / 2,
    (corners[3].dy + corners[0].dy) / 2,
  );

  final edgeHandles = <Map<String, dynamic>>[
    {'pos': leftCenter, 'type': TransformHandle.scaleX},
    {'pos': rightCenter, 'type': TransformHandle.scaleX},
    {'pos': topCenter, 'type': TransformHandle.scaleY},
    {'pos': bottomCenter, 'type': TransformHandle.scaleY},
  ];

  for (final entry in edgeHandles) {
    final pos = entry['pos'] as Offset;
    final rect = Rect.fromLTWH(
      pos.dx - half,
      pos.dy - half,
      handleSize,
      handleSize,
    );
    if (rect.contains(posCanvas)) {
      final axisVector = (pos - center);
      final axis = axisVector.distance == 0
          ? Offset.zero
          : axisVector / axisVector.distance;
      final dist = axisVector.distance;
      return HandleHit(
        type: entry['type'] as TransformHandle,
        center: center,
        startDistance: dist,
        startAngle: 0,
        axis: axis,
      );
    }
  }

  // Rotate handle above top edge.
  final dir = (topCenter - center);
  final len = dir.distance;
  if (len > 0) {
    final norm = dir / len;
    final handleCenter = center + norm * (len + 20 / viewportScale);
    final rect = Rect.fromCircle(center: handleCenter, radius: half);
    if (rect.contains(posCanvas)) {
      final dist = (posCanvas - center).distance;
      final angle = math.atan2(
        posCanvas.dy - center.dy,
        posCanvas.dx - center.dx,
      );
      return HandleHit(
        type: TransformHandle.rotate,
        center: center,
        startDistance: dist,
        startAngle: angle,
      );
    }
  }

  return null;
}

Offset? hitAxisForHandle(TransformHandle handle, double rotation) {
  switch (handle) {
    case TransformHandle.scaleX:
      return Offset(math.cos(rotation), math.sin(rotation));
    case TransformHandle.scaleY:
      return Offset(-math.sin(rotation), math.cos(rotation));
    default:
      return null;
  }
}

List<Offset> transformedCorners(Rect rect, Matrix4 matrix) {
  final corners = <Offset>[
    Offset(rect.left, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right, rect.bottom),
    Offset(rect.left, rect.bottom),
  ];
  return corners
      .map((c) {
        final v = matrix.transform3(Vector3(c.dx, c.dy, 0));
        return Offset(v.x, v.y);
      })
      .toList(growable: false);
}

Rect? boundsFromPoints(List<Offset> points) {
  if (points.isEmpty) return null;
  double minX = points.first.dx;
  double maxX = points.first.dx;
  double minY = points.first.dy;
  double maxY = points.first.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Offset _pivotWorld(Rect base, Shape shape) {
  final origin = base.center;
  return shape.translation + origin + shape.transform.pivot;
}
