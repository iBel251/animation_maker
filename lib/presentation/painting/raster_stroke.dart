import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';

/// Minimal stroke data stored for raster history/replay.
class RasterStroke {
  const RasterStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    this.thinning = 0.6,
    this.smoothing = 0.5,
    this.streamline = 0.5,
    this.simulatePressure = true,
  });

  final List<PointVector> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final double thinning;
  final double smoothing;
  final double streamline;
  final bool simulatePressure;
}
