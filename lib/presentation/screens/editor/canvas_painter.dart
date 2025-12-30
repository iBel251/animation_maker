import 'dart:ui' as ui;

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.shapes,
    required this.selectedShapeId,
    required this.rasterLayer,
    required this.inProgressStroke,
    required this.brushThickness,
    required this.brushOpacity,
    required this.brushSmoothness,
    required this.brushColor,
    this.brushRenderer = const PerfectFreehandRenderer(),
    this.brushType,
  });

  final List<Shape> shapes;
  final String? selectedShapeId;
  final ui.Image? rasterLayer;
  final List<PointVector> inProgressStroke;
  final double brushThickness;
  final double brushOpacity;
  final double brushSmoothness;
  final Color brushColor;
  final BrushRenderer brushRenderer;
  final BrushType? brushType;

  @override
  void paint(Canvas canvas, Size size) {
    if (rasterLayer != null) {
      canvas.drawImage(rasterLayer!, Offset.zero, Paint());
    }

    // Live brush stroke preview (raster-only brush data).
    if (inProgressStroke.isNotEmpty) {
      final renderer = _rendererFor(brushType);
      final path = _buildFreehandPathFromPoints(
        inProgressStroke,
        brushThickness,
        brushSmoothness,
        renderer,
      );
      if (path != null) {
        final baseAlpha = brushColor.alpha / 255.0;
        final paint = Paint()
          ..color = brushColor
              .withValues(alpha: (baseAlpha * brushOpacity).clamp(0, 1))
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      }
    }

    // Shapes are painted in list order; later shapes render on top.
    for (final shape in shapes) {
      final renderer = _rendererFor(shape.brushType);
      final baseAlpha = shape.strokeColor.alpha / 255.0;
      final paint = Paint()
        ..color = shape.strokeColor
            .withValues(alpha: (baseAlpha * shape.opacity).clamp(0, 1))
        ..strokeWidth = shape.strokeWidth;

      switch (shape.kind) {
        case ShapeKind.freehand:
          final path = _buildFreehandPath(shape, renderer);
          if (path != null) {
            paint.style = PaintingStyle.fill;
            canvas.drawPath(path, paint);
            _highlightIfSelected(canvas, path.getBounds(), shape.id);
          }
          break;
        case ShapeKind.polygon:
        case ShapeKind.line:
          final path = _buildPolyline(
            shape.points,
            closePath: shape.kind == ShapeKind.polygon,
          );
          if (path != null) {
            paint.style = PaintingStyle.stroke;
            canvas.drawPath(path, paint);
            _highlightIfSelected(canvas, path.getBounds(), shape.id);
          }
          break;
        case ShapeKind.rectangle:
          paint.style = PaintingStyle.stroke;
          final rect = shape.bounds;
          if (rect != null) {
            canvas.drawRect(rect, paint);
            _highlightIfSelected(canvas, rect, shape.id);
          }
          break;
        case ShapeKind.ellipse:
          paint.style = PaintingStyle.stroke;
          final rect = shape.bounds;
          if (rect != null) {
            canvas.drawOval(rect, paint);
            _highlightIfSelected(canvas, rect, shape.id);
          }
          break;
      }
    }
  }

  Path? _buildFreehandPath(Shape shape, BrushRenderer renderer) {
    if (shape.points.isEmpty) return null;
    final smooth = _strokeSmoothing(brushSmoothness);
    final streamline = _strokeStreamline(brushSmoothness);
    return renderer.buildPathFromOffsets(
      shape.points,
      BrushStrokeOptions(
        size: shape.strokeWidth,
        thinning: 0.5,
        smoothing: smooth,
        streamline: streamline,
        simulatePressure: true,
        isComplete: true,
      ),
    );
  }

  Path? _buildFreehandPathFromPoints(
    List<PointVector> points,
    double thickness,
    double smoothness,
    BrushRenderer renderer,
  ) {
    final smooth = _strokeSmoothing(smoothness);
    final streamline = _strokeStreamline(smoothness);
    return renderer.buildPath(
      points,
      BrushStrokeOptions(
        size: thickness,
        thinning: 0.5,
        smoothing: smooth,
        streamline: streamline,
        simulatePressure: true,
        isComplete: false,
      ),
    );
  }

  Path? _buildPolyline(List<Offset> points, {bool closePath = false}) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      final single = points.first;
      final path = Path()
        ..addOval(Rect.fromCircle(center: single, radius: 0.5));
      return path;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (closePath && points.length > 2) {
      path.close();
    }
    return path;
  }

  void _highlightIfSelected(Canvas canvas, Rect bounds, String shapeId) {
    if (selectedShapeId != shapeId) return;
    final highlightStroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final highlightFill = Paint()
      ..color = const Color(0x331E88E5)
      ..style = PaintingStyle.fill;
    final inflated = bounds.inflate(4);
    canvas.drawRect(inflated, highlightFill);
    canvas.drawRect(inflated, highlightStroke);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.shapes != shapes ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.rasterLayer != rasterLayer ||
        oldDelegate.inProgressStroke != inProgressStroke ||
        oldDelegate.brushThickness != brushThickness ||
        oldDelegate.brushOpacity != brushOpacity ||
        oldDelegate.brushSmoothness != brushSmoothness ||
        oldDelegate.brushColor != brushColor;
  }

  double _strokeSmoothing(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.75;
  double _strokeStreamline(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.55;

  BrushRenderer _rendererFor(BrushType? type) {
    switch (type) {
      case BrushType.pencil:
        return const PencilBrushRenderer(jitter: 0.4);
      case BrushType.marker:
        return const MarkerBrushRenderer();
      default:
        return brushRenderer;
    }
  }
}

