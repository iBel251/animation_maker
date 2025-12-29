import 'dart:ui' as ui;

import 'package:animation_maker/domain/models/shape.dart';
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
  });

  final List<Shape> shapes;
  final String? selectedShapeId;
  final ui.Image? rasterLayer;
  final List<PointVector> inProgressStroke;
  final double brushThickness;
  final double brushOpacity;
  final double brushSmoothness;
  final Color brushColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (rasterLayer != null) {
      canvas.drawImage(rasterLayer!, Offset.zero, Paint());
    }

    // Live brush stroke preview (raster-only brush data).
    if (inProgressStroke.isNotEmpty) {
      final path = _buildFreehandPathFromPoints(
        inProgressStroke,
        brushThickness,
        brushSmoothness,
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
      final baseAlpha = shape.strokeColor.alpha / 255.0;
      final paint = Paint()
        ..color = shape.strokeColor
            .withValues(alpha: (baseAlpha * shape.opacity).clamp(0, 1))
        ..strokeWidth = shape.strokeWidth;

      switch (shape.kind) {
        case ShapeKind.freehand:
          final path = _buildFreehandPath(shape);
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

  Path? _buildFreehandPath(Shape shape) {
    if (shape.points.isEmpty) return null;
    final outline = getStroke(
      shape.points
          .map((p) => PointVector.fromOffset(offset: p))
          .toList(growable: false),
      options: StrokeOptions(
        size: shape.strokeWidth,
        smoothing: brushSmoothness,
        streamline: brushSmoothness,
        thinning: 0.6,
        simulatePressure: true,
        isComplete: true,
      ),
    );
    return _outlineToPath(outline);
  }

  Path? _buildFreehandPathFromPoints(
    List<PointVector> points,
    double thickness,
    double smoothness,
  ) {
    final outline = getStroke(
      points,
      options: StrokeOptions(
        size: thickness,
        smoothing: smoothness,
        streamline: smoothness,
        thinning: 0.6,
        simulatePressure: true,
        isComplete: false,
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
}

