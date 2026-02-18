import 'dart:ui' as ui;

import 'package:perfect_freehand/perfect_freehand.dart';

/// Parameters that describe how a brush stroke should be rendered.
class BrushStrokeOptions {
  const BrushStrokeOptions({
    required this.size,
    required this.thinning,
    required this.smoothing,
    required this.streamline,
    required this.simulatePressure,
    required this.isComplete,
  });

  final double size;
  final double thinning;
  final double smoothing;
  final double streamline;
  final bool simulatePressure;
  final bool isComplete;
}

abstract class BrushRenderer {
  const BrushRenderer();

  /// Build a path for a stroke from PointVector input (pressure-aware).
  ui.Path? buildPath(List<PointVector> points, BrushStrokeOptions options);

  /// Convenience helper for Offset-only input.
  ui.Path? buildPathFromOffsets(
    List<ui.Offset> points,
    BrushStrokeOptions options,
  );

  ui.Paint decoratePaint(ui.Paint paint) => paint;
}

class PerfectFreehandRenderer extends BrushRenderer {
  const PerfectFreehandRenderer();

  @override
  ui.Path? buildPath(List<PointVector> points, BrushStrokeOptions options) {
    if (points.isEmpty || options.size <= 0) return null;
    final outline = getStroke(
      points,
      options: StrokeOptions(
        size: options.size,
        thinning: options.thinning,
        smoothing: options.smoothing,
        streamline: options.streamline,
        simulatePressure: options.simulatePressure,
        isComplete: options.isComplete,
      ),
    );
    return _outlineToPath(outline);
  }

  @override
  ui.Path? buildPathFromOffsets(
    List<ui.Offset> points,
    BrushStrokeOptions options,
  ) {
    final vectors = points
        .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
        .toList(growable: false);
    return buildPath(vectors, options);
  }

  ui.Path? _outlineToPath(List<ui.Offset> outline) {
    return _smoothOutlineToPath(outline);
  }

  @override
  ui.Paint decoratePaint(ui.Paint paint) => paint;
}

/// Converts outline points to a smooth path using quadratic Bezier curves.
/// This is the official recommended rendering approach from perfect_freehand.
/// See: https://pub.dev/packages/perfect_freehand/example
ui.Path? _smoothOutlineToPath(List<ui.Offset> outline) {
  if (outline.isEmpty) return null;
  if (outline.length == 1) {
    final p = outline.first;
    return ui.Path()..addOval(ui.Rect.fromCircle(center: p, radius: 1));
  }
  if (outline.length == 2) {
    return ui.Path()
      ..moveTo(outline.first.dx, outline.first.dy)
      ..lineTo(outline.last.dx, outline.last.dy)
      ..close();
  }

  final path = ui.Path();
  path.moveTo(outline[0].dx, outline[0].dy);

  for (int i = 1; i < outline.length - 1; i++) {
    final p0 = outline[i];
    final p1 = outline[i + 1];
    // Control point is current point, end point is midpoint to next
    path.quadraticBezierTo(
      p0.dx,
      p0.dy,
      (p0.dx + p1.dx) / 2,
      (p0.dy + p1.dy) / 2,
    );
  }

  // Final point
  final last = outline.last;
  path.lineTo(last.dx, last.dy);
  path.close();

  return path;
}

/// A simple “pencil” renderer that introduces slight jitter and lighter strokes.
class PencilBrushRenderer extends BrushRenderer {
  const PencilBrushRenderer({this.jitter = 0.35});

  /// Max random offset applied per point, scaled by pressure.
  final double jitter;

  @override
  ui.Path? buildPath(List<PointVector> points, BrushStrokeOptions options) {
    if (points.isEmpty || options.size <= 0) return null;
    final jittered = <PointVector>[];
    for (final p in points) {
      final jx = _randOffset(p) * jitter;
      final jy = _randOffset(p) * jitter;
      jittered.add(
        PointVector(p.x + jx, p.y + jy, p.pressure),
      );
    }

    final outline = getStroke(
      jittered,
      options: StrokeOptions(
        size: options.size * 0.9,
        thinning: 0.75,
        smoothing: options.smoothing * 0.6,
        streamline: options.streamline * 0.6,
        simulatePressure: options.simulatePressure,
        isComplete: options.isComplete,
      ),
    );
    return _smoothOutlineToPath(outline);
  }

  @override
  ui.Path? buildPathFromOffsets(List<ui.Offset> points, BrushStrokeOptions options) {
    final vectors = points
        .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
        .toList(growable: false);
    return buildPath(vectors, options);
  }

  double _randOffset(PointVector p) {
    // Cheap deterministic jitter based on coordinates using ints.
    final sx = (p.x * 1000).round();
    final sy = (p.y * 1000).round();
    int seed = (sx * 73856093) ^ (sy * 19349663);
    seed &= 0x7fffffff; // keep positive
    final v = (seed % 1000) / 1000.0; // 0..1
    final double pressure = p.pressure ?? 1.0;
    return (v - 0.5) * pressure;
  }

  @override
  ui.Paint decoratePaint(ui.Paint paint) {
    return paint
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.8)
      ..color = paint.color.withOpacity((paint.color.opacity * 0.85).clamp(0, 1));
  }
}

/// A "marker" brush with uniform width (minimal pressure variance) and smoother edges.
class MarkerBrushRenderer extends BrushRenderer {
  const MarkerBrushRenderer();

  @override
  ui.Path? buildPath(List<PointVector> points, BrushStrokeOptions options) {
    if (points.isEmpty || options.size <= 0) return null;
    final outline = getStroke(
      points,
      options: StrokeOptions(
        size: options.size * 1.05,
        thinning: 0.0, // uniform width
        smoothing: (options.smoothing * 1.2).clamp(0.0, 1.0),
        streamline: (options.streamline * 1.1).clamp(0.0, 1.0),
        simulatePressure: false,
        isComplete: options.isComplete,
      ),
    );
    return _smoothOutlineToPath(outline);
  }

  @override
  ui.Path? buildPathFromOffsets(
    List<ui.Offset> points,
    BrushStrokeOptions options,
  ) {
    final vectors = points
        .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
        .toList(growable: false);
    return buildPath(vectors, options);
  }

  @override
  ui.Paint decoratePaint(ui.Paint paint) {
    return paint
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.6)
      ..isAntiAlias = true;
  }
}


