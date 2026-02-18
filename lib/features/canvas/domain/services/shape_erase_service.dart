import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// Non-destructive erase service.
///
/// Instead of modifying shape geometry (which destroys curves, pressures, and
/// thickness), this stores erase-mask contours on the shape in local space.
/// The renderer uses `canvas.saveLayer` + `BlendMode.clear` to visually punch
/// out the erased regions at draw time, keeping the original geometry intact.
class ShapeEraseService {
  const ShapeEraseService();

  // Safety limits to prevent mask growth from causing frame drops/OOM when
  // many fast erases are applied to the same shape.
  static const int _maxContoursPerShape = 256;
  static const int _maxPointsPerContour = 320;
  static const int _maxTotalMaskPointsPerShape = 24000;

  /// Async version – the mask approach is fast, so this just delegates.
  Future<EraseResult> eraseAsync({
    required Shape shape,
    required Path eraserPath,
    required String Function() createId,
    bool strokeScaleWithShape = false,
    double brushSmoothness = 0.35,
    double sampleDistance = 1.5,
  }) async {
    return erase(
      shape: shape,
      eraserPath: eraserPath,
      createId: createId,
      sampleDistance: sampleDistance,
    );
  }

  EraseResult erase({
    required Shape shape,
    required Path eraserPath,
    required String Function() createId,
    bool strokeScaleWithShape = false,
    double brushSmoothness = 0.35,
    double sampleDistance = 1.5,
  }) {
    // 1. Get shape's local-space bounds and transform matrix.
    final base = shape.localBounds ?? shape.bounds;
    if (base == null) return const EraseResult.noop();
    final matrix = shape.matrixForRect(base);
    final inverse = Matrix4.copy(matrix);
    final det = inverse.invert();
    if (det == 0 || det.isNaN || det.isInfinite) {
      return const EraseResult.noop();
    }

    // 2. Transform eraser path from world space to local space.
    final localEraserPath = eraserPath.transform(inverse.storage);

    // 3. Sample contours from the local-space eraser path.
    final newContours = _sampleContoursFromPath(
      localEraserPath,
      sampleDistance: sampleDistance,
    );
    if (newContours.isEmpty) return const EraseResult.noop();

    // 4. Merge with existing erase contours.
    final existing =
        shape.eraseContours?.map((c) => c.toList()).toList() ??
        <List<Offset>>[];
    final merged = _enforceMaskBudget([...existing, ...newContours]);

    // 5. Return shape with updated erase mask (geometry untouched).
    final replacement = shape.copyWith(eraseContours: merged);
    return EraseResult(
      didErase: true,
      replacements: [replacement],
      preserveId: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Samples contours from a [Path] at regular intervals.
  List<List<Offset>> _sampleContoursFromPath(
    Path path, {
    required double sampleDistance,
  }) {
    final contours = <List<Offset>>[];
    final step = sampleDistance <= 0 ? 2.0 : sampleDistance;
    for (final metric in path.computeMetrics()) {
      if (metric.length <= 0) continue;
      final points = <Offset>[];
      var d = 0.0;
      while (d < metric.length) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) points.add(tangent.position);
        d += step;
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null) points.add(end.position);
      final cleaned = _dedupePoints(points, epsilon: step * 0.3);
      final limited = _limitContourPoints(
        cleaned,
        maxPoints: _maxPointsPerContour,
      );
      if (limited.length >= 3) {
        contours.add(limited);
      }
    }
    return contours;
  }

  List<Offset> _dedupePoints(List<Offset> points, {required double epsilon}) {
    if (points.length < 2) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - result.last).distance >= epsilon) {
        result.add(points[i]);
      }
    }
    if (result.length > 2 && (result.first - result.last).distance < epsilon) {
      result.removeLast();
    }
    return result;
  }

  List<List<Offset>> _enforceMaskBudget(List<List<Offset>> contours) {
    if (contours.isEmpty) return contours;

    var normalized = contours
        .map((c) => _limitContourPoints(c, maxPoints: _maxPointsPerContour))
        .where((c) => c.length >= 3)
        .toList(growable: false);

    if (normalized.length > _maxContoursPerShape) {
      normalized = normalized
          .sublist(normalized.length - _maxContoursPerShape)
          .toList(growable: false);
    }

    var totalPoints = normalized.fold<int>(
      0,
      (sum, contour) => sum + contour.length,
    );

    if (totalPoints <= _maxTotalMaskPointsPerShape) {
      return normalized;
    }

    final trimmed = normalized.toList(growable: true);

    // Prefer dropping oldest erase fragments first.
    while (trimmed.length > 1 && totalPoints > _maxTotalMaskPointsPerShape) {
      totalPoints -= trimmed.first.length;
      trimmed.removeAt(0);
    }

    // If one contour is still too dense, decimate it to the remaining budget.
    if (trimmed.isNotEmpty && totalPoints > _maxTotalMaskPointsPerShape) {
      final budget = _maxTotalMaskPointsPerShape
          .clamp(3, trimmed.first.length)
          .toInt();
      trimmed[0] = _limitContourPoints(trimmed.first, maxPoints: budget);
    }

    return trimmed;
  }

  List<Offset> _limitContourPoints(
    List<Offset> contour, {
    required int maxPoints,
  }) {
    if (contour.length <= maxPoints || maxPoints < 3) return contour;
    final stride = (contour.length / maxPoints).ceil();
    final reduced = <Offset>[];
    for (var i = 0; i < contour.length; i += stride) {
      reduced.add(contour[i]);
    }
    if (reduced.last != contour.last) {
      reduced.add(contour.last);
    }
    return reduced.length >= 3
        ? reduced
        : contour.take(3).toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

class EraseResult {
  const EraseResult({
    required this.didErase,
    required this.replacements,
    this.preserveId = false,
  });

  const EraseResult.noop()
    : didErase = false,
      replacements = const [],
      preserveId = false;

  const EraseResult.erased()
    : didErase = true,
      replacements = const [],
      preserveId = false;

  final bool didErase;
  final List<Shape> replacements;

  /// If true, replacements have the same ID as the original shape
  /// and should replace it in place rather than creating new shapes.
  final bool preserveId;
}
