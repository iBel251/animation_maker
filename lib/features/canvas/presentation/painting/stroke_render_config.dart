/// Configuration for stroke rendering parameters.
///
/// This class centralizes all stroke rendering parameter mappings to ensure
/// consistency between preview strokes (CanvasPainter) and saved strokes
/// (ShapeEraseService, ShapeMergeService).
///
/// Previously, different parts of the codebase used different ranges:
/// - CanvasPainter: smoothing 0.05-0.9, streamline 0.05-0.8
/// - ShapeEraseService: smoothing 0.05-0.8, streamline 0.05-0.6
///
/// This caused preview strokes to look different from saved strokes.
class StrokeRenderConfig {
  StrokeRenderConfig._();

  // Smoothing parameter ranges
  /// Minimum smoothing value (less smoothing, more detail)
  static const double minSmoothing = 0.4;

  /// Maximum smoothing value (more smoothing, less detail)
  static const double maxSmoothing = 0.7;

  // Streamline parameter ranges
  /// Minimum streamline value (less streamlining, follows input closely)
  static const double minStreamline = 0.4;

  /// Maximum streamline value (more streamlining, smoother curves)
  static const double maxStreamline = 0.7;

  // Thinning parameter
  /// Default thinning value for pressure-sensitive strokes
  /// Higher values = more variation between thick and thin
  static const double defaultThinning = 0.5;

  /// Converts a normalized smoothness value [0.0, 1.0] to actual smoothing parameter.
  ///
  /// - 0.0 = minSmoothing (0.05) - preserves more detail
  /// - 1.0 = maxSmoothing (0.8) - maximum smoothing
  ///
  /// Example:
  /// ```dart
  /// final smoothing = StrokeRenderConfig.smoothingForValue(0.5);
  /// // Returns 0.425 (midpoint between 0.05 and 0.8)
  /// ```
  static double smoothingForValue(double normalizedValue) {
    assert(normalizedValue >= 0.0 && normalizedValue <= 1.0,
        'Smoothness must be between 0.0 and 1.0');
    return minSmoothing + (maxSmoothing - minSmoothing) * normalizedValue;
  }

  /// Converts a normalized smoothness value [0.0, 1.0] to actual streamline parameter.
  ///
  /// - 0.0 = minStreamline (0.05) - follows input closely
  /// - 1.0 = maxStreamline (0.6) - maximum streamlining
  ///
  /// Example:
  /// ```dart
  /// final streamline = StrokeRenderConfig.streamlineForValue(0.5);
  /// // Returns 0.325 (midpoint between 0.05 and 0.6)
  /// ```
  static double streamlineForValue(double normalizedValue) {
    assert(normalizedValue >= 0.0 && normalizedValue <= 1.0,
        'Smoothness must be between 0.0 and 1.0');
    return minStreamline + (maxStreamline - minStreamline) * normalizedValue;
  }

  /// Returns smoothing and streamline values for a given normalized smoothness.
  ///
  /// Convenience method that returns both parameters at once.
  ///
  /// Example:
  /// ```dart
  /// final params = StrokeRenderConfig.parametersForValue(0.7);
  /// print('Smoothing: ${params.smoothing}, Streamline: ${params.streamline}');
  /// ```
  static StrokeParameters parametersForValue(double normalizedValue) {
    return StrokeParameters(
      smoothing: smoothingForValue(normalizedValue),
      streamline: streamlineForValue(normalizedValue),
    );
  }
}

/// Container for stroke rendering parameters.
class StrokeParameters {
  const StrokeParameters({
    required this.smoothing,
    required this.streamline,
  });

  final double smoothing;
  final double streamline;

  @override
  String toString() =>
      'StrokeParameters(smoothing: $smoothing, streamline: $streamline)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrokeParameters &&
        other.smoothing == smoothing &&
        other.streamline == streamline;
  }

  @override
  int get hashCode => Object.hash(smoothing, streamline);
}
