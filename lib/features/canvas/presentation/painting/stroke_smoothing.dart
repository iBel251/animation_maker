import 'dart:ui';

import 'one_euro_filter.dart';

class StrokeSmoother {
  StrokeSmoother(this.smoothness)
      : _config = _filterConfigFromSmoothness(smoothness);

  final double smoothness;
  final _FilterConfig _config;
  OneEuroFilter? _xFilter;
  OneEuroFilter? _yFilter;
  Stopwatch? _watch;

  void start() {
    _xFilter = OneEuroFilter(
      minCutoff: _config.minCutoff,
      beta: _config.beta,
    );
    _yFilter = OneEuroFilter(
      minCutoff: _config.minCutoff,
      beta: _config.beta,
    );
    _watch = Stopwatch()..start();
  }

  void reset() {
    _xFilter = null;
    _yFilter = null;
    _watch = null;
  }

  Offset filterPoint(Offset point) {
    if (_xFilter == null || _yFilter == null || _watch == null) {
      return point;
    }
    final t = _watch!.elapsedMicroseconds / 1e6;
    final sx = _xFilter!.filter(point.dx, t);
    final sy = _yFilter!.filter(point.dy, t);
    return Offset(sx, sy);
  }

  double pointSpacing() {
    // Higher smoothness -> lower spacing so filters do most of the work.
    return (_minPointDistanceBase + (1 - smoothness) * 1.2)
        .clamp(0.15, 4.0);
  }

  static const double _minPointDistanceBase = 0.2;

  static _FilterConfig _filterConfigFromSmoothness(double s) {
    final t = s.clamp(0, 1);
    final inv = 1 - t;
    final minCutoff = _lerp(1.6, 0.15, inv.toDouble());
    final beta = _lerp(0.0, 0.04, inv.toDouble());
    return _FilterConfig(minCutoff: minCutoff, beta: beta);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _FilterConfig {
  const _FilterConfig({required this.minCutoff, required this.beta});
  final double minCutoff;
  final double beta;
}


