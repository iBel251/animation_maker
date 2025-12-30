import 'dart:ui' as ui;

import 'package:animation_maker/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:flutter/material.dart';

/// Minimal raster engine to paint strokes into a bitmap.
class RasterEngine {
  RasterEngine({BrushRenderer renderer = const PerfectFreehandRenderer()})
      : _renderer = renderer;

  // Default to 1080p (16:9) before the canvas reports its actual size.
  ui.Size _size = const ui.Size(1920, 1080);
  ui.Image? _image;
  final BrushRenderer _renderer;

  ui.Image? get image => _image;

  void clear() {
    _image = null;
  }

  void updateSize(ui.Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (size == _size) return;
    _size = size;
    _image = null;
  }

  Future<ui.Image?> renderStrokes(List<RasterStroke> strokes) async {
    final int width = _size.width.ceil().clamp(1, 8000).toInt();
    final int height = _size.height.ceil().clamp(1, 8000).toInt();
    if (width == 0 || height == 0) return _image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Offset.zero & ui.Size(width.toDouble(), height.toDouble()),
    );

    for (final stroke in strokes) {
      final baseAlpha = stroke.color.alpha / 255.0;
      final paint = Paint()
        ..color = stroke.color
            .withValues(alpha: (baseAlpha * stroke.opacity).clamp(0, 1))
        ..style = PaintingStyle.fill;

      _drawStroke(canvas, stroke, paint);
    }

    try {
      final picture = recorder.endRecording();
      _image = await picture.toImage(width, height);
      return _image;
    } catch (_) {
      return _image;
    }
  }

  Future<ui.Image?> renderStrokeIncremental(RasterStroke stroke) async {
    final int width = _size.width.ceil().clamp(1, 8000).toInt();
    final int height = _size.height.ceil().clamp(1, 8000).toInt();
    if (width == 0 || height == 0) return _image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Offset.zero & ui.Size(width.toDouble(), height.toDouble()),
    );

    // Draw the existing raster first (if any), then the new stroke.
    final paint = Paint()
      ..color = stroke.color
          .withValues(alpha: (stroke.color.alpha / 255.0 * stroke.opacity).clamp(0, 1))
      ..style = PaintingStyle.fill;

    if (_image != null) {
      canvas.drawImage(_image!, Offset.zero, Paint());
    }

    _drawStroke(canvas, stroke, paint);

    try {
      final picture = recorder.endRecording();
      _image = await picture.toImage(width, height);
      return _image;
    } catch (_) {
      return _image;
    }
  }

  void _drawStroke(Canvas canvas, RasterStroke stroke, Paint paint) {
    final path = _buildPathForStroke(stroke);
    if (path == null || path.computeMetrics().isEmpty) return;
    canvas.drawPath(path, paint);
  }

  Path? _buildPathForStroke(RasterStroke stroke) {
    if (stroke.points.isEmpty || stroke.strokeWidth <= 0) return null;
    final renderer = switch (stroke.brushType) {
      BrushType.pencil => const PencilBrushRenderer(),
      BrushType.marker => const MarkerBrushRenderer(),
      _ => _renderer,
    };

    return renderer.buildPath(
      stroke.points,
      BrushStrokeOptions(
        size: stroke.strokeWidth,
        thinning: stroke.thinning,
        smoothing: stroke.smoothing,
        streamline: stroke.streamline,
        simulatePressure: stroke.simulatePressure,
        isComplete: true,
      ),
    );
  }
}
