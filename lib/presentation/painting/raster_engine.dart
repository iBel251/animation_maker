import 'dart:ui' as ui;

import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// Minimal raster engine to paint strokes into a bitmap.
class RasterEngine {
  // Default to 1080p (16:9) before the canvas reports its actual size.
  ui.Size _size = const ui.Size(1920, 1080);
  ui.Image? _image;

  ui.Image? get image => _image;

  void clear() {
    _image = null;
  }

  void updateSize(ui.Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (size == _size) return;
    _size = size;
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

      final path = _buildPathForStroke(stroke);
      if (path == null || path.computeMetrics().isEmpty) continue;
      canvas.drawPath(path, paint);
    }

    try {
      final picture = recorder.endRecording();
      _image = await picture.toImage(width, height);
      return _image;
    } catch (_) {
      return _image;
    }
  }

  Path? _buildPathForStroke(RasterStroke stroke) {
    if (stroke.points.isEmpty || stroke.strokeWidth <= 0) return null;

    final outline = getStroke(
      stroke.points,
      options: StrokeOptions(
        size: stroke.strokeWidth,
        thinning: stroke.thinning,
        smoothing: stroke.smoothing,
        streamline: stroke.streamline,
        simulatePressure: stroke.simulatePressure,
        isComplete: true,
      ),
    );
    return _outlineToPath(outline);
  }

  Path? _outlineToPath(List<Offset> outline) {
    if (outline.isEmpty) return null;
    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      final pt = outline[i];
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }
}
