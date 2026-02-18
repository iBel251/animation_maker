import 'dart:ui' as ui;

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:flutter/material.dart';

/// Paints the scene camera viewport overlay on the canvas.
///
/// Renders a dimmed area outside the camera's viewport and a frame border
/// around the visible area. This is applied as a `foregroundPainter` on the
/// same CustomPaint that hosts CanvasPainter, ensuring correct coordinate
/// transforms without modifying CanvasPainter.
class CameraOverlayPainter extends CustomPainter {
  CameraOverlayPainter({
    required this.sceneCamera,
    required this.viewportScale,
    required this.worldOriginOffset,
    this.isActive = false,
  });

  final SceneCamera sceneCamera;
  final double viewportScale;
  final Offset worldOriginOffset;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Translate to world origin (same as CanvasPainter)
    canvas.translate(worldOriginOffset.dx, worldOriginOffset.dy);

    final corners = sceneCamera.viewCorners;

    // Build camera frame path
    final framePath = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    // Dimming overlay: full canvas minus camera frame
    // Use a very large rect to cover the entire virtual canvas
    final fullRect = Rect.fromLTWH(
      -worldOriginOffset.dx,
      -worldOriginOffset.dy,
      size.width,
      size.height,
    );
    final fullPath = Path()..addRect(fullRect);
    final dimPath = Path.combine(
      PathOperation.difference,
      fullPath,
      framePath,
    );

    final dimOpacity = isActive ? 0.45 : 0.25;
    canvas.drawPath(
      dimPath,
      Paint()..color = Color.fromRGBO(0, 0, 0, dimOpacity),
    );

    // Camera frame border
    final borderColor = isActive
        ? const Color(0xFFFFFFFF)
        : const Color(0xAAFFFFFF);
    final borderWidth = isActive ? 2.5 / viewportScale : 1.5 / viewportScale;

    canvas.drawPath(
      framePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // Corner markers when active
    if (isActive) {
      _drawCornerMarkers(canvas, corners);
    }

    // Resolution label
    _drawLabel(canvas, corners);

    canvas.restore();
  }

  void _drawCornerMarkers(Canvas canvas, List<Offset> corners) {
    final markerSize = 8.0 / viewportScale;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / viewportScale;

    for (final corner in corners) {
      final rect = Rect.fromCenter(
        center: corner,
        width: markerSize,
        height: markerSize,
      );
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawLabel(Canvas canvas, List<Offset> corners) {
    final w = sceneCamera.size.width.round();
    final h = sceneCamera.size.height.round();
    final zoomPercent = (sceneCamera.zoom * 100).round();
    final label = '${w}x$h  $zoomPercent%';

    final fontSize = 12.0 / viewportScale;
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: isActive ? const Color(0xFFFFFFFF) : const Color(0xAAFFFFFF),
        fontSize: fontSize,
      ))
      ..addText(label);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: 300 / viewportScale));

    // Position above the top-left corner
    final labelOffset = Offset(
      corners[0].dx,
      corners[0].dy - fontSize - 6 / viewportScale,
    );

    // Background for readability
    final bgRect = Rect.fromLTWH(
      labelOffset.dx - 4 / viewportScale,
      labelOffset.dy - 2 / viewportScale,
      paragraph.longestLine + 8 / viewportScale,
      paragraph.height + 4 / viewportScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(3 / viewportScale)),
      Paint()..color = const Color(0x88000000),
    );

    canvas.drawParagraph(paragraph, labelOffset);
  }

  @override
  bool shouldRepaint(CameraOverlayPainter oldDelegate) {
    return oldDelegate.sceneCamera != sceneCamera ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.worldOriginOffset != worldOriginOffset ||
        oldDelegate.isActive != isActive;
  }
}
