import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';

class StrokeInputSettings {
  const StrokeInputSettings({
    required this.minSpacing,
    required this.maxSamplesPerSegment,
  });

  final double minSpacing;
  final int maxSamplesPerSegment;
}

/// Simple input processor - passes points directly to perfect_freehand.
/// The smoothing happens in perfect_freehand's getStroke() function.
class StrokeInputProcessor {
  StrokeInputProcessor(this._settings);

  final StrokeInputSettings _settings;
  Offset? _lastPoint;

  void reset() {
    _lastPoint = null;
  }

  List<PointVector> start(
    Offset point,
    Duration timeStamp,
    double pressure,
  ) {
    reset();
    _lastPoint = point;
    return [
      PointVector.fromOffset(
        offset: point,
        pressure: pressure.clamp(0.0, 1.0),
      ),
    ];
  }

  List<PointVector> add(
    Offset point,
    Duration timeStamp,
    double pressure,
  ) {
    // Skip points that are too close
    if (_lastPoint != null) {
      final dist = (point - _lastPoint!).distance;
      if (dist < _settings.minSpacing) {
        return const [];
      }
    }

    _lastPoint = point;
    return [
      PointVector.fromOffset(
        offset: point,
        pressure: pressure.clamp(0.0, 1.0),
      ),
    ];
  }

  List<PointVector> finish() {
    return const [];
  }
}
