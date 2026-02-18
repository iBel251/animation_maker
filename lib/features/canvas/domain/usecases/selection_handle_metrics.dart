import 'dart:math' as math;

const double _screenHandleSize = 10.0;
const double _minCanvasHandleSize = 1.0;
const double _maxCanvasHandleSize = 50.0;

// Node editing handle sizes
const double _screenNodeHandleSize = 8.0;
const double _minNodeHandleSize = 0.8;
const double _maxNodeHandleSize = 40.0;
const double _nodeHitRadiusMultiplier = 1.5; // Larger hit area than visual

// Bezier control handle sizes (larger and more visible)
const double _screenBezierControlSize = 7.0;
const double _minBezierControlSize = 0.7;
const double _maxBezierControlSize = 35.0;
const double _bezierControlHitMultiplier = 2.0; // Even larger hit area for control handles

double selectionHandleCanvasSize(double viewportScale) {
  if (viewportScale <= 0) return _screenHandleSize;
  final rawSize = _screenHandleSize / viewportScale;
  return rawSize.clamp(_minCanvasHandleSize, _maxCanvasHandleSize);
}

double selectionHandleHalfSize(double viewportScale) {
  return selectionHandleCanvasSize(viewportScale) * 0.5;
}

double selectionHandleRotationOffset(double viewportScale) {
  const double baseOffset = 20.0;
  if (viewportScale <= 0) return baseOffset;
  return baseOffset / math.max(viewportScale, 0.0001);
}

/// Returns the canvas-space size for node handles (for rendering).
double nodeHandleCanvasSize(double viewportScale) {
  if (viewportScale <= 0) return _screenNodeHandleSize;
  final rawSize = _screenNodeHandleSize / viewportScale;
  return rawSize.clamp(_minNodeHandleSize, _maxNodeHandleSize);
}

/// Returns the canvas-space hit radius for node handles (larger than visual).
double nodeHandleHitRadius(double viewportScale) {
  return nodeHandleCanvasSize(viewportScale) * _nodeHitRadiusMultiplier;
}

/// Returns the canvas-space tolerance for segment hit testing.
double segmentHitTolerance(double viewportScale) {
  // Slightly larger than node hit radius for easier segment selection
  return nodeHandleHitRadius(viewportScale) * 0.8;
}

/// Returns the canvas-space size for Bezier control handles (for rendering).
double bezierControlHandleCanvasSize(double viewportScale) {
  if (viewportScale <= 0) return _screenBezierControlSize;
  final rawSize = _screenBezierControlSize / viewportScale;
  return rawSize.clamp(_minBezierControlSize, _maxBezierControlSize);
}

/// Returns the canvas-space hit radius for Bezier control handles.
/// Larger hit area makes it easier to grab the small handles.
double bezierControlHandleHitRadius(double viewportScale) {
  return bezierControlHandleCanvasSize(viewportScale) * _bezierControlHitMultiplier;
}
