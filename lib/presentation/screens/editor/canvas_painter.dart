import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'selection_types.dart';
import 'selection_handles.dart';
import 'fill_utils.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.shapes,
    required this.selectedShapeId,
    this.selectedShapeIds = const <String>[],
    required this.selectionMode,
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
    this.rotationGuideCenter,
    this.rotationGuideAngle,
    this.pivotSnapGuide,
  });

  final List<Shape> shapes;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final SelectionMode selectionMode;
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
  final Offset? rotationGuideCenter;
  final double? rotationGuideAngle;
  final Offset? pivotSnapGuide;

  @override
  void paint(Canvas canvas, Size size) {
    if (rasterLayer != null) {
      canvas.drawImage(rasterLayer!, Offset.zero, Paint());
    }

    // Shapes are painted in list order; later shapes render on top.
    for (final shape in shapes) {
      final renderer = _rendererFor(shape.brushType);
      final baseAlpha = shape.strokeColor.alpha / 255.0;
      final baseBounds = shape.bounds ?? _shapeBoundsFromPoints(shape.points);
      final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
      final strokeScale = _strokeScaleFor(shape);
      final effectiveStrokeWidth =
          strokeScale <= 0.0001 ? shape.strokeWidth : shape.strokeWidth / strokeScale;
      final paint = renderer.decoratePaint(
        Paint()
          ..color = shape.strokeColor.withValues(
            alpha: (baseAlpha * shape.opacity).clamp(0, 1),
          )
          ..strokeWidth = effectiveStrokeWidth,
      );

      switch (shape.kind) {
        case ShapeKind.freehand:
          _withShapeTransform(canvas, matrix, () {
            final fillPath = FillUtils.buildFillPath(shape);
            if (fillPath != null && shape.fillColor != null) {
              final fillPaint = Paint()
                ..color = shape.fillColor!.withValues(
                  alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(
                    0,
                    1,
                  ),
                )
                ..style = PaintingStyle.fill;
              canvas.drawPath(fillPath, fillPaint);
            }
            final path = _buildFreehandPath(shape, renderer);
            if (path != null) {
              // Freehand strokes are filled paths; stroke width is baked into the outline.
              final fill = renderer.decoratePaint(
                Paint()
                  ..color = shape.strokeColor.withValues(
                    alpha: (baseAlpha * shape.opacity).clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill,
              );
              canvas.drawPath(path, fill);
              canvas.drawPath(path, paint);
            }
          });
          if (_isSelected(shape.id) && baseBounds != null) {
            _drawSelection(
              canvas,
              transformedCorners(baseBounds, shape.matrixForRect(baseBounds)),
              canvasBounds: Rect.fromLTWH(0, 0, size.width, size.height),
              pivotWorld: _pivotWorld(baseBounds, shape),
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.polygon:
        case ShapeKind.line:
          _withShapeTransform(canvas, matrix, () {
            final path = _buildPolyline(
              shape.points,
              closePath: shape.kind == ShapeKind.polygon,
            );
            if (path != null) {
              if (shape.fillColor != null && shape.kind == ShapeKind.polygon) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawPath(path, fill);
              }
              paint.style = PaintingStyle.stroke;
              paint.strokeWidth = effectiveStrokeWidth;
              canvas.drawPath(path, paint);
            }
          });
          if (_isSelected(shape.id) && baseBounds != null) {
            _drawSelection(
              canvas,
              transformedCorners(
                baseBounds,
                matrix,
              ),
              canvasBounds: Rect.fromLTWH(0, 0, size.width, size.height),
              pivotWorld: _pivotWorld(baseBounds, shape),
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.rectangle:
          _withShapeTransform(canvas, matrix, () {
            final rect = shape.bounds;
            if (rect != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawRect(rect, fill);
              }
              paint.style = PaintingStyle.stroke;
              paint.strokeWidth = effectiveStrokeWidth;
              canvas.drawRect(rect, paint);
            }
          });
          if (_isSelected(shape.id) && shape.bounds != null) {
            _drawSelection(
              canvas,
              transformedCorners(
                shape.bounds!,
                shape.matrixForRect(shape.bounds!),
              ),
              canvasBounds: Rect.fromLTWH(0, 0, size.width, size.height),
              pivotWorld: _pivotWorld(shape.bounds!, shape),
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.ellipse:
          _withShapeTransform(canvas, matrix, () {
            final rect = shape.bounds;
            if (rect != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawOval(rect, fill);
              }
              paint.style = PaintingStyle.stroke;
              paint.strokeWidth = effectiveStrokeWidth;
              canvas.drawOval(rect, paint);
            }
          });
          if (_isSelected(shape.id) && shape.bounds != null) {
            _drawSelection(
              canvas,
              transformedCorners(
                shape.bounds!,
                shape.matrixForRect(shape.bounds!),
              ),
              canvasBounds: Rect.fromLTWH(0, 0, size.width, size.height),
              pivotWorld: _pivotWorld(shape.bounds!, shape),
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
      }
    }

    // Live brush stroke preview should draw above shapes.
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
          ..color = brushColor.withValues(
            alpha: (baseAlpha * brushOpacity).clamp(0, 1),
          )
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      }
    }
  }

  Path? _buildFreehandPath(
    Shape shape,
    BrushRenderer renderer,
  ) {
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

  void _drawSelection(
    Canvas canvas,
    List<Offset> corners, {
    required Rect canvasBounds,
    Offset? pivotWorld,
    Offset? pivotSnapGuide,
  }) {
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
    _drawHandles(canvas, corners, canvasBounds);
    if (pivotWorld != null) {
      _drawPivot(canvas, pivotWorld);
      if (pivotSnapGuide != null) {
        _drawPivotGuide(canvas, pivotWorld, pivotSnapGuide);
      }
    }

    if (rotationGuideCenter != null && rotationGuideAngle != null) {
      _drawRotationGuide(
        canvas,
        rotationGuideCenter!,
        rotationGuideAngle!,
        corners,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.shapes != shapes ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.selectedShapeIds != selectedShapeIds ||
        oldDelegate.selectionMode != selectionMode ||
        oldDelegate.rasterLayer != rasterLayer ||
        oldDelegate.inProgressStroke != inProgressStroke ||
        oldDelegate.brushThickness != brushThickness ||
        oldDelegate.brushOpacity != brushOpacity ||
        oldDelegate.brushSmoothness != brushSmoothness ||
        oldDelegate.brushColor != brushColor ||
        oldDelegate.rotationGuideAngle != rotationGuideAngle ||
        oldDelegate.rotationGuideCenter != rotationGuideCenter ||
        oldDelegate.pivotSnapGuide != pivotSnapGuide;
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

  void _withShapeTransform(Canvas canvas, Matrix4 matrix, VoidCallback draw) {
    canvas.save();
    canvas.transform(matrix.storage);
    draw();
    canvas.restore();
  }

  double _strokeScaleFor(Shape shape) {
    final sx = shape.scaleX.abs();
    final sy = shape.scaleY.abs();
    final maxScale = sx > sy ? sx : sy;
    return maxScale <= 0.0001 ? 1.0 : maxScale;
  }

  void _drawHandles(
    Canvas canvas,
    List<Offset> corners,
    Rect canvasBounds,
  ) {
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
      leftCenterEdge,
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
    final placement = _rotationHandlePlacement(
      center: center,
      edgeCenters: edgeCenters,
      viewportScale: viewportScale,
      canvasBounds: canvasBounds.deflate(size * 0.6),
    );
    canvas.drawCircle(placement.handle, size * 0.6, handlePaint);
    canvas.drawLine(
      placement.anchor,
      placement.handle,
      handlePaint..strokeWidth = 1,
    );
  }

  void _drawPivot(Canvas canvas, Offset pivot) {
    final size = 12 / viewportScale;
    final half = size / 2;
    final paint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivot, half * 0.6, paint);
    final stroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(pivot + Offset(-half, 0), pivot + Offset(half, 0), stroke);
    canvas.drawLine(pivot + Offset(0, -half), pivot + Offset(0, half), stroke);
  }

  void _drawPivotGuide(Canvas canvas, Offset pivot, Offset target) {
    if ((pivot - target).distance < 0.5) return;
    final guidePaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, target, guidePaint);
  }

  Offset _pivotWorld(Rect base, Shape shape) {
    final origin = base.center;
    return shape.translation + origin + shape.transform.pivot;
  }

  _RotationHandlePlacement _rotationHandlePlacement({
    required Offset center,
    required List<Offset> edgeCenters,
    required double viewportScale,
    required Rect canvasBounds,
  }) {
    const double baseOffset = 20.0;
    Offset? fallbackHandle;
    Offset? fallbackAnchor;
    for (final anchor in edgeCenters) {
      final dir = anchor - center;
      final len = dir.distance;
      if (len <= 0) continue;
      final norm = dir / len;
      final candidate =
          center + norm * (len + baseOffset / viewportScale);
      fallbackHandle ??= candidate;
      fallbackAnchor ??= anchor;
      if (canvasBounds.contains(candidate)) {
        return _RotationHandlePlacement(handle: candidate, anchor: anchor);
      }
    }
    return _RotationHandlePlacement(
      handle: fallbackHandle ?? center,
      anchor: fallbackAnchor ?? center,
    );
  }

  void _drawRotationGuide(
    Canvas canvas,
    Offset center,
    double angle,
    List<Offset> corners,
  ) {
    final radius = _guideRadius(corners);
    final end =
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final guidePaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, end, guidePaint);
  }

  double _guideRadius(List<Offset> corners) {
    if (corners.length != 4) return 80;
    final width = (corners[0] - corners[1]).distance;
    final height = (corners[1] - corners[2]).distance;
    return (math.max(width, height) / 2) + 24;
  }

  bool _isSelected(String id) {
    if (selectedShapeId == id) return true;
    if (selectionMode == SelectionMode.multi ||
        selectionMode == SelectionMode.all ||
        selectionMode == SelectionMode.lasso) {
      return selectedShapeIds.contains(id);
    }
    return false;
  }
}

class _RotationHandlePlacement {
  const _RotationHandlePlacement({
    required this.handle,
    required this.anchor,
  });

  final Offset handle;
  final Offset anchor;
}
