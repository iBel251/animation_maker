import 'package:animation_maker/domain/models/shape.dart';
import 'package:flutter/material.dart';

class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.shapes,
    required this.selectedShapeId,
  });

  final List<Shape> shapes;
  final String? selectedShapeId;

  @override
  void paint(Canvas canvas, Size size) {
    // Shapes are painted in list order; later shapes render on top.
    for (final shape in shapes) {
      final paint = Paint()
        ..color = shape.strokeColor.withOpacity(shape.opacity)
        ..strokeWidth = shape.strokeWidth
        ..style = PaintingStyle.stroke;

      switch (shape.kind) {
        case ShapeKind.freehand:
        case ShapeKind.polygon:
        case ShapeKind.line:
          final path = _buildPath(
            shape.points,
            closePath: shape.kind == ShapeKind.polygon,
          );
          if (path != null) {
            canvas.drawPath(path, paint);
            _highlightIfSelected(canvas, path.getBounds(), shape.id);
          }
          break;
        case ShapeKind.rectangle:
          final rect = shape.bounds;
          if (rect != null) {
            canvas.drawRect(rect, paint);
            _highlightIfSelected(canvas, rect, shape.id);
          }
          break;
        case ShapeKind.ellipse:
          final rect = shape.bounds;
          if (rect != null) {
            canvas.drawOval(rect, paint);
            _highlightIfSelected(canvas, rect, shape.id);
          }
          break;
      }
    }
  }

  Path? _buildPath(List<Offset> points, {bool closePath = false}) {
    if (points.length < 2) return null;
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
        oldDelegate.selectedShapeId != selectedShapeId;
  }
}

