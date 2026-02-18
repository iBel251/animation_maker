const String kShapeRasterPaintPathKey = 'shapeRasterPaintPath';

/// Fraction by which the raster image extends beyond the shape bounds.
/// e.g. 0.5 means 50% of max(width, height) added on each side.
/// When absent, the image is assumed to cover exactly the shape bounds.
const String kShapeRasterPaintMarginKey = 'shapeRasterPaintMargin';
