import 'dart:ui';
import 'package:animation_maker/domain/models/shape.dart';
import 'selection_handles.dart';
import 'dart:math' as math;

/// Stateless helper that applies transform deltas to a snapshot of shapes.
/// It keeps shapes immutable and returns transformed copies.
class TransformSession {
  TransformSession({required List<Shape> shapes, required this.center})
    : _base = {for (final s in shapes) s.id: s},
      _origins = {
        for (final s in shapes)
          s.id:
              (s.bounds ?? _boundsFromPoints(s.points))?.center ?? Offset.zero,
      };

  final Map<String, Shape> _base;
  final Offset center;
  final Map<String, Offset> _origins;

  List<Shape> scaleUniform(double factor) {
    return _base.values
        .map(
          (shape) => shape.copyWith(
            transform: shape.transform.copyWith(
              scaleX: shape.scaleX * factor,
              scaleY: shape.scaleY * factor,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Shape> scaleAxis(
    TransformHandle handle,
    double factor, {
    required Offset axis,
  }) {
    return _base.values
        .map(
          (shape) => shape.copyWith(
            transform: shape.transform.copyWith(
              scaleX: handle == TransformHandle.scaleX
                  ? shape.scaleX * factor
                  : shape.scaleX,
              scaleY: handle == TransformHandle.scaleY
                  ? shape.scaleY * factor
                  : shape.scaleY,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Shape> rotate(double deltaAngle) {
    return _base.values
        .map(
          (shape) => shape.copyWith(
            transform: shape.transform.copyWith(
              rotation: shape.rotation + deltaAngle,
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Updates the pivot point while keeping the shape visually stationary.
  ///
  /// The pivot acts as the center for rotation and scale transforms. When the pivot
  /// changes, we must compensate the position to prevent the shape from moving.
  ///
  /// Takes either:
  /// - [pivotLocal]: direct local-space pivot offset (relative to origin)
  /// - [worldTarget]: world-space target (converted to local internally, deprecated - prefer passing pivotLocal)
  List<Shape> updatePivot(Offset pivotLocal, {Offset? worldTarget}) {
    final updated = <Shape>[];
    for (final shape in _base.values) {
      final origin = _origins[shape.id] ?? Offset.zero;

      // Convert world target to local space if provided (legacy path)
      Offset newPivotLocal;
      if (worldTarget != null) {
        final oldPivot = shape.transform.pivot;
        final pivotWorld = shape.translation + origin + oldPivot;
        final worldDelta = worldTarget - pivotWorld;

        // Map world delta into the shape's local space using the inverse of (rotation * scale).
        final cosA = math.cos(shape.rotation);
        final sinA = math.sin(shape.rotation);
        final sx = shape.scaleX;
        final sy = shape.scaleY;
        if (sx.abs() < 1e-6 || sy.abs() < 1e-6) {
          // Fallback to direct subtraction if scale is degenerate.
          newPivotLocal = worldTarget - shape.translation - origin;
        } else {
          final dxRot = cosA * worldDelta.dx + sinA * worldDelta.dy;
          final dyRot = -sinA * worldDelta.dx + cosA * worldDelta.dy;
          final localDelta = Offset(dxRot / sx, dyRot / sy);
          newPivotLocal = oldPivot + localDelta;
        }
      } else {
        newPivotLocal = pivotLocal;
      }

      // Calculate how much the pivot moved in local space
      final oldPivot = shape.transform.pivot;
      final p0 = origin + oldPivot;
      final p1 = origin + newPivotLocal;
      final delta = p1 - p0;

      // Safety check: if delta is huge, something went wrong
      if (delta.distance > 10000) {
        // Skip this update to prevent runaway
        updated.add(shape);
        continue;
      }

      // Apply the shape's current rotation and scale to the delta
      // When scale is negative (flipped), the delta direction needs to be reversed in local space
      final cosA = math.cos(shape.rotation);
      final sinA = math.sin(shape.rotation);

      // Apply flip sign to delta in local space BEFORE rotation/scale transform
      final flipSignX = shape.scaleX.sign;
      final flipSignY = shape.scaleY.sign;
      final flippedDelta = Offset(delta.dx * flipSignX, delta.dy * flipSignY);

      final absScaleX = shape.scaleX.abs();
      final absScaleY = shape.scaleY.abs();

      // Transform the flipped delta using absolute scale and rotation
      final lx = cosA * absScaleX * flippedDelta.dx - sinA * absScaleY * flippedDelta.dy;
      final ly = sinA * absScaleX * flippedDelta.dx + cosA * absScaleY * flippedDelta.dy;

      // Compensate position: the untransformed delta movement minus transformed movement
      final compensation = (p0 - p1) + Offset(lx, ly);

      updated.add(
        shape.copyWith(
          transform: shape.transform.copyWith(
            pivot: newPivotLocal,
            position: shape.translation + compensation,
          ),
        ),
      );
    }
    return updated;
  }

  static Rect? _boundsFromPoints(List<Offset> pts) {
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
}
