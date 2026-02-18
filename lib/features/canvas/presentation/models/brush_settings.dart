class BrushSettings {
  final double thickness;
  final double opacity;
  final double smoothness;

  const BrushSettings({
    this.thickness = 4.0,
    this.opacity = 1.0,
    this.smoothness = 0.35,
  });

  BrushSettings copyWith({
    double? thickness,
    double? opacity,
    double? smoothness,
  }) {
    return BrushSettings(
      thickness: thickness ?? this.thickness,
      opacity: opacity ?? this.opacity,
      smoothness: smoothness ?? this.smoothness,
    );
  }
}
