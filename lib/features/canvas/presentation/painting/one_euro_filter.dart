import 'dart:math';

/// One Euro filter implementation for smoothing pointer input.
class OneEuroFilter {
  OneEuroFilter({
    required double minCutoff,
    required double beta,
    this.dCutoff = 1.0,
  })  : _minCutoff = minCutoff,
        _beta = beta;

  final double _minCutoff;
  final double _beta;
  final double dCutoff;

  double _lastTimestamp = -1;
  double? _xPrev;
  double? _dxPrev;

  double filter(double x, double timestamp) {
    final double dt = _computeDt(timestamp);
    if (dt <= 0) return x;

    // Derivative of the signal.
    final double dx = _xPrev == null ? 0 : (x - _xPrev!) / dt;
    final double edx = _dxPrev == null
        ? dx
        : _lowPass(prev: _dxPrev!, value: dx, cutoff: dCutoff, dt: dt);
    _dxPrev = edx;

    // Dynamic cutoff.
    final double cutoff = _minCutoff + _beta * dx.abs();
    final double filteredX = _xPrev == null
        ? x
        : _lowPass(prev: _xPrev!, value: x, cutoff: cutoff, dt: dt);
    _xPrev = filteredX;
    return filteredX;
  }

  void reset() {
    _lastTimestamp = -1;
    _xPrev = null;
    _dxPrev = null;
  }

  double _computeDt(double timestamp) {
    if (_lastTimestamp < 0) {
      _lastTimestamp = timestamp;
      return 0;
    }
    final dt = timestamp - _lastTimestamp;
    _lastTimestamp = timestamp;
    return dt <= 0 ? 0 : dt;
  }

  double _lowPass({
    required double prev,
    required double value,
    required double cutoff,
    required double dt,
  }) {
    final double r = 2 * pi * cutoff * dt;
    final double alpha = r / (r + 1);
    return alpha * value + (1 - alpha) * prev;
  }
}


