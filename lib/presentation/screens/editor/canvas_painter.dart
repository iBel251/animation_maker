import 'dart:ui' as ui;
import 'dart:math' as math;

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
    this.showSelectionHandles = false,
    this.viewportScale = 1.0,
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
  final bool showSelectionHandles;
  final double viewportScale;

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
      final baseBounds = shape.bounds ?? _shapeBoundsFromPoints(shape.points);
      final paint = renderer.decoratePaint(
        Paint()
          ..color = shape.strokeColor
              .withValues(alpha: (baseAlpha * shape.opacity).clamp(0, 1))
          ..strokeWidth = shape.strokeWidth,
      );

      switch (shape.kind) {
        case ShapeKind.freehand:
          _withShapeTransform(canvas, shape, () {
            final path = _buildFreehandPath(shape, renderer);
            if (path != null) {
              // Freehand strokes are filled paths; stroke width is baked into the outline.
              final fill = renderer.decoratePaint(
                Paint()
                  ..color = shape.strokeColor
                      .withValues(alpha: (baseAlpha * shape.opacity).clamp(0, 1))
                  ..style = PaintingStyle.fill,
              );
              canvas.drawPath(path, fill);
              canvas.drawPath(path, paint);
            }
          });
          if (selectedShapeId == shape.id && baseBounds != null) {
            _drawSelection(canvas, _transformedCorners(baseBounds, shape.rotation, shape.scale));
          }
          break;
        case ShapeKind.polygon:
        case ShapeKind.line:
          _withShapeTransform(canvas, shape, () {
            final path = _buildPolyline(
              shape.points,
              closePath: shape.kind == ShapeKind.polygon,
            );
            if (path != null) {
              if (shape.fillColor != null && shape.kind == ShapeKind.polygon) {
                final fill = Paint()
                  ..color = shape.fillColor!
                      .withValues(alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(0, 1))
                  ..style = PaintingStyle.fill;
                canvas.drawPath(path, fill);
              }
              paint.style = PaintingStyle.stroke;
              canvas.drawPath(path, paint);
              if (selectedShapeId == shape.id) {
                _drawSelection(canvas, _transformedCorners(path.getBounds(), shape.rotation, shape.scale));
              }
            }
          });
          break;
        case ShapeKind.rectangle:
          _withShapeTransform(canvas, shape, () {
            final rect = shape.bounds;
            if (rect != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!
                      .withValues(alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(0, 1))
                  ..style = PaintingStyle.fill;
                canvas.drawRect(rect, fill);
              }
              paint.style = PaintingStyle.stroke;
              canvas.drawRect(rect, paint);
            }
          });
          if (selectedShapeId == shape.id && shape.bounds != null) {
            _drawSelection(canvas, _transformedCorners(shape.bounds!, shape.rotation, shape.scale));
          }
          break;
        case ShapeKind.ellipse:
          _withShapeTransform(canvas, shape, () {
            final rect = shape.bounds;
            if (rect != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!
                      .withValues(alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(0, 1))
                  ..style = PaintingStyle.fill;
                canvas.drawOval(rect, fill);
              }
              paint.style = PaintingStyle.stroke;
              canvas.drawOval(rect, paint);
            }
          });
          if (selectedShapeId == shape.id && shape.bounds != null) {
            _drawSelection(canvas, _transformedCorners(shape.bounds!, shape.rotation, shape.scale));
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

  void _drawSelection(Canvas canvas, List<Offset> corners) {
    if (corners.length != 4) return;
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (var i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();
    final highlightStroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final highlightFill = Paint()
      ..color = const Color(0x221E88E5)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, highlightFill);
    canvas.drawPath(path, highlightStroke);

    if (!showSelectionHandles) return;
    _drawHandles(canvas, corners);
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

  void _withShapeTransform(
    Canvas canvas,
    Shape shape,
    VoidCallback draw,
  ) {
    final bounds = shape.bounds ?? _shapeBoundsFromPoints(shape.points);
    if (bounds == null ||
        (shape.rotation == 0.0 && shape.scale == 1.0)) {
      draw();
      return;
    }
    final center = bounds.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(shape.rotation);
    canvas.scale(shape.scale);
    canvas.translate(-center.dx, -center.dy);
    draw();
    canvas.restore();
  }

  Rect? _shapeBoundsFromPoints(List<Offset> points) {
    if (points.isEmpty) return null;
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<Offset> _transformedCorners(Rect rect, double rotation, double scale) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final corners = <Offset>[
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
    if (rotation == 0.0 && scale == 1.0) return corners;
    final cosA = math.cos(rotation);
    final sinA = math.sin(rotation);
    return corners
        .map((c) {
          final dx = (c.dx - cx) * scale;
          final dy = (c.dy - cy) * scale;
          final rx = dx * cosA - dy * sinA + cx;
          final ry = dx * sinA + dy * cosA + cy;
          return Offset(rx, ry);
        })
        .toList(growable: false);
  }

  void _drawHandles(Canvas canvas, List<Offset> corners) {
    if (corners.length != 4) return;
    final size = 10 / viewportScale;
    final half = size / 2;
    final handlePaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.fill;
    for (final c in corners) {
      canvas.drawRect(
        Rect.fromLTWH(c.dx - half, c.dy - half, size, size),
        handlePaint,
      );
    }
    // Edge handles (middle of each edge).
    final topCenterEdge = Offset(
      (corners[0].dx + corners[1].dx) / 2,
      (corners[0].dy + corners[1].dy) / 2,
    );
    final rightCenterEdge = Offset(
      (corners[1].dx + corners[2].dx) / 2,
      (corners[1].dy + corners[2].dy) / 2,
    );
    final bottomCenterEdge = Offset(
      (corners[2].dx + corners[3].dx) / 2,
      (corners[2].dy + corners[3].dy) / 2,
    );
    final leftCenterEdge = Offset(
      (corners[3].dx + corners[0].dx) / 2,
      (corners[3].dy + corners[0].dy) / 2,
    );
    final edgeCenters = [
      topCenterEdge,
      rightCenterEdge,
      bottomCenterEdge,
      leftCenterEdge
    ];
    for (final c in edgeCenters) {
      canvas.drawCircle(c, size * 0.45, handlePaint);
    }
    final topCenter = Offset(
      (corners[0].dx + corners[1].dx) / 2,
      (corners[0].dy + corners[1].dy) / 2,
    );
    final center = Offset(
      (corners[0].dx + corners[2].dx) / 2,
      (corners[0].dy + corners[2].dy) / 2,
    );
    final dir = (topCenter - center);
    final len = dir.distance;
    if (len > 0) {
      final norm = dir / len;
      final handleCenter = center + norm * (len + 20 / viewportScale);
      canvas.drawCircle(handleCenter, size * 0.6, handlePaint);
      canvas.drawLine(topCenter, handleCenter, handlePaint..strokeWidth = 1);
    }
  }
}

