import 'dart:math' as math;

/// Stateless snapping helpers for transforms.
class SnapService {
  /// Snap an angle (radians) to the nearest increment when within [threshold].
  /// Returns null if no snap should be applied.
  static double? snapAngle(
    double angle, {
    double increment = math.pi / 4, // 45 degrees
    double threshold = 0.06, // ~3.5 degrees
  }) {
    final snapped = (angle / increment).round() * increment;
    if ((angle - snapped).abs() <= threshold) {
      return snapped;
    }
    return null;
  }
}
