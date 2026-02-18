import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/usecases/node_operations.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_bounds.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_handle_metrics.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_hit_test.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brush_renderer_registry.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/features/canvas/presentation/painting/stroke_render_config.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import '../services/fill_utils.dart';
import '../services/shape_raster_paint_keys.dart';

class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.shapes,
    required this.selectedShapeId,
    this.selectedShapeIds = const <String>[],
    required this.selectionMode,
    required this.inProgressStroke,
    required this.brushThickness,
    required this.brushOpacity,
    required this.brushSmoothness,
    required this.brushColor,
    required this.strokeScaleWithShape,
    required this.selectionColor,
    this.brushRenderer = const PerfectFreehandRenderer(),
    this.brushType,
    this.showSelectionHandles = false,
    this.viewportScale = 1.0,
    this.rotationGuideCenter,
    this.rotationGuideAngle,
    this.pivotSnapGuide,
    required this.activeTool,
    this.nodeEditState,
    this.mergePreviewShape,
    // Unlimited canvas: artboard info for visual guide
    this.artboardSize,
    this.artboardBackground,
    this.worldOriginOffset = Offset.zero,
    this.imageCache = const {},
  });

  final List<Shape> shapes;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final SelectionMode selectionMode;
  final List<PointVector> inProgressStroke;
  final double brushThickness;
  final double brushOpacity;
  final double brushSmoothness;
  final Color brushColor;
  final bool strokeScaleWithShape;
  final Color selectionColor;
  final BrushRenderer brushRenderer;
  final BrushType? brushType;
  final bool showSelectionHandles;
  final double viewportScale;
  final Offset? rotationGuideCenter;
  final double? rotationGuideAngle;
  final Offset? pivotSnapGuide;
  final EditorTool activeTool;
  final NodeEditState? nodeEditState;
  final Shape? mergePreviewShape;

  /// Artboard size for unlimited canvas - draws artboard as visual guide
  final Size? artboardSize;

  /// Artboard background for unlimited canvas rendering
  final CanvasBackground? artboardBackground;

  /// World origin offset within the virtual canvas.
  /// This recenters the artboard so negative world space is visible.
  final Offset worldOriginOffset;

  /// Cache of loaded dart:ui.Image objects keyed by relative image path.
  final Map<String, ui.Image> imageCache;

  @override
  void paint(Canvas canvas, Size size) {
    final hasOriginOffset = worldOriginOffset != Offset.zero;
    if (hasOriginOffset) {
      canvas.save();
      canvas.translate(worldOriginOffset.dx, worldOriginOffset.dy);
    }
    _drawWorkspaceBackground(canvas, size);
    _drawWorldOriginMarker(canvas);
    // Draw artboard as visual guide for unlimited canvas
    if (artboardSize != null) {
      _drawArtboard(canvas, artboardSize!, artboardBackground);
    }

    Shape? selectedShape;
    if (selectedShapeId != null) {
      for (final shape in shapes) {
        if (shape.id == selectedShapeId) {
          selectedShape = shape;
          break;
        }
      }
    }
    final selectedSpatialId = selectedShape?.spatialObjectId;
    final hasSpatialSelection = selectedSpatialId != null;
    final spatialShapes = hasSpatialSelection
        ? shapes
              .where((shape) => shape.spatialObjectId == selectedSpatialId)
              .toList(growable: false)
        : const <Shape>[];
    final spatialSelectionBounds = hasSpatialSelection
        ? selectionBoundsForShapesWorld(
            spatialShapes,
            brushSmoothness: brushSmoothness,
            strokeScaleWithShape: strokeScaleWithShape,
          )
        : null;
    final spatialSelectionCorners = hasSpatialSelection
        ? selectionCornersForShapesWorld(
            spatialShapes,
            brushSmoothness: brushSmoothness,
            strokeScaleWithShape: strokeScaleWithShape,
          )
        : null;
    final canvasBounds = Rect.fromLTWH(
      -worldOriginOffset.dx,
      -worldOriginOffset.dy,
      size.width,
      size.height,
    );

    // Shapes are painted in list order; later shapes render on top.
    for (final shape in shapes) {
      // Skip hidden shapes
      if (!shape.isVisible) continue;

      final renderer = _rendererFor(shape.brushType);
      final baseAlpha = shape.strokeColor.alpha / 255.0;
      final baseBounds = shape.localBounds;
      final selectionBounds = selectionBoundsForShape(
        shape,
        brushSmoothness: brushSmoothness,
        strokeScaleWithShape: strokeScaleWithShape,
      );
      final selectionBase = selectionBounds ?? baseBounds;
      final skipSpatialSelection =
          hasSpatialSelection && shape.spatialObjectId == selectedSpatialId;
      final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);
      final rasterPaintPath = _shapeRasterPaintPath(shape);
      final rasterImage = rasterPaintPath == null
          ? null
          : imageCache[rasterPaintPath];
      final baseScale = _strokeScaleFor(shape);
      final scaleFactor = strokeScaleWithShape ? math.max(1.0, baseScale) : 1.0;
      final effectiveStrokeWidth = shape.strokeWidth / scaleFactor;
      final strokeColor = shape.strokeColor.withValues(
        alpha: (baseAlpha * shape.opacity).clamp(0, 1),
      );
      final strokePaint = renderer.decoratePaint(
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStrokeWidth,
      );
      final brushPaint = renderer.decoratePaint(
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.fill,
      );

      switch (shape.kind) {
        case ShapeKind.freehand:
          final wb = shape.worldBounds;
          final erasePaths = wb != null
              ? _beginEraseMask(canvas, shape, wb, matrix)
              : null;
          final worldPoints = _transformOffsets(shape.points, matrix);
          final hasPressure =
              shape.pointPressures != null &&
              shape.pointPressures!.length == shape.points.length;
          final vectorPoints = _pointsWithPressure(
            worldPoints,
            shape.pointPressures,
          );
          if (shape.fillColor != null && FillUtils.canFill(shape)) {
            final fillPath = _buildFreehandFillPath(worldPoints);
            if (fillPath != null) {
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
          }
          final path = _buildFreehandPathFromOffsets(
            vectorPoints,
            effectiveStrokeWidth,
            shape.brushSmoothness ?? brushSmoothness,
            renderer,
            hasPressureData: hasPressure,
          );
          if (path != null) {
            // Freehand strokes are filled paths; stroke width is baked into the outline.
            canvas.drawPath(path, brushPaint);
          }
          if (erasePaths != null) _endEraseMask(canvas, erasePaths);
          // Draw raster overlay AFTER erase mask so the vector eraser
          // does not affect raster paint visibility.
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          // Hide selection box during node edit mode (nodes are edited individually)
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.polygon:
          final wbPoly = shape.worldBounds;
          final erasePathsPoly = wbPoly != null
              ? _beginEraseMask(canvas, shape, wbPoly, matrix)
              : null;
          // Check if this polygon has Bezier curve data
          if (shape.hasBezierCurves && shape.bezierPoints != null) {
            // Render as Bezier curves
            final bezierPath = _buildBezierCurvePath(
              shape.bezierPoints!,
              matrix,
              shape.isClosed,
            );
            if (bezierPath != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawPath(bezierPath, fill);
              }
              canvas.drawPath(bezierPath, strokePaint);
            }
          } else {
            // Standard polygon rendering with straight lines
            final contours = shape.contours.isNotEmpty
                ? shape.contours
                : (shape.points.isNotEmpty
                      ? [shape.points]
                      : const <List<Offset>>[]);
            final worldContours = _transformContours(contours, matrix);
            final path = _buildContourPath(
              worldContours,
              closePath: true,
              evenOdd: contours.length > 1,
            );
            if (path != null) {
              if (shape.fillColor != null) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawPath(path, fill);
              }
              canvas.drawPath(path, strokePaint);
            }
          }
          if (erasePathsPoly != null) _endEraseMask(canvas, erasePathsPoly);
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          // Hide selection box during node edit mode (nodes are edited individually)
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.line:
          final wbLine = shape.worldBounds;
          final erasePathsLine = wbLine != null
              ? _beginEraseMask(canvas, shape, wbLine, matrix)
              : null;
          final worldPoints = _transformOffsets(shape.points, matrix);
          final path = _buildPolyline(worldPoints, closePath: false);
          if (path != null) {
            canvas.drawPath(path, strokePaint);
          }
          if (erasePathsLine != null) _endEraseMask(canvas, erasePathsLine);
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          // Hide selection box during node edit mode (nodes are edited individually)
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.rectangle:
          final wbRect = shape.worldBounds;
          final erasePathsRect = wbRect != null
              ? _beginEraseMask(canvas, shape, wbRect, matrix)
              : null;
          final rect = shape.bounds;
          if (rect != null) {
            var path = Path()..addRect(rect);
            path = path.transform(matrix.storage);
            if (shape.fillColor != null) {
              final fill = Paint()
                ..color = shape.fillColor!.withValues(
                  alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(
                    0,
                    1,
                  ),
                )
                ..style = PaintingStyle.fill;
              canvas.drawPath(path, fill);
            }
            canvas.drawPath(path, strokePaint);
          }
          if (erasePathsRect != null) _endEraseMask(canvas, erasePathsRect);
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          // Hide selection box during node edit mode (nodes are edited individually)
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.ellipse:
          final wbEllipse = shape.worldBounds;
          final erasePathsEllipse = wbEllipse != null
              ? _beginEraseMask(canvas, shape, wbEllipse, matrix)
              : null;
          final rect = shape.bounds;
          if (rect != null) {
            var path = Path()..addOval(rect);
            path = path.transform(matrix.storage);
            if (shape.fillColor != null) {
              final fill = Paint()
                ..color = shape.fillColor!.withValues(
                  alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity).clamp(
                    0,
                    1,
                  ),
                )
                ..style = PaintingStyle.fill;
              canvas.drawPath(path, fill);
            }
            canvas.drawPath(path, strokePaint);
          }
          if (erasePathsEllipse != null) {
            _endEraseMask(canvas, erasePathsEllipse);
          }
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          // Hide selection box during node edit mode (nodes are edited individually)
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.pointPath:
          final wbPP = shape.worldBounds;
          final erasePathsPP = wbPP != null
              ? _beginEraseMask(canvas, shape, wbPP, matrix)
              : null;
          // Point path rendering - similar to polygon but respects isClosed
          if (shape.hasBezierCurves && shape.bezierPoints != null) {
            // Render as Bezier curves
            final bezierPath = _buildBezierCurvePath(
              shape.bezierPoints!,
              matrix,
              shape.isClosed,
            );
            if (bezierPath != null) {
              if (shape.fillColor != null && shape.isClosed) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawPath(bezierPath, fill);
              }
              canvas.drawPath(bezierPath, strokePaint);
            }
          } else {
            // Straight line connections
            final worldPoints = _transformOffsets(shape.points, matrix);
            final path = _buildPolyline(worldPoints, closePath: shape.isClosed);
            if (path != null) {
              if (shape.fillColor != null && shape.isClosed) {
                final fill = Paint()
                  ..color = shape.fillColor!.withValues(
                    alpha: (shape.fillColor!.alpha / 255.0 * shape.opacity)
                        .clamp(0, 1),
                  )
                  ..style = PaintingStyle.fill;
                canvas.drawPath(path, fill);
              }
              canvas.drawPath(path, strokePaint);
            }
          }
          if (erasePathsPP != null) _endEraseMask(canvas, erasePathsPP);
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );

          // Draw point handles when shape tool is active (for visual feedback during drawing)
          if (activeTool == EditorTool.shape && shape.points.isNotEmpty) {
            final worldPoints = _transformOffsets(shape.points, matrix);
            _drawPointHandles(canvas, worldPoints);
          }

          // Selection box
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
        case ShapeKind.image:
          final wbImg = shape.worldBounds;
          final erasePathsImg = wbImg != null
              ? _beginEraseMask(canvas, shape, wbImg, matrix)
              : null;
          final rect = shape.bounds;
          if (rect != null && shape.imagePath != null) {
            final img = imageCache[shape.imagePath!];
            if (img != null) {
              canvas.save();
              canvas.transform(matrix.storage);
              final imgPaint = Paint()..filterQuality = FilterQuality.medium;
              if (shape.opacity < 1.0) {
                imgPaint.color = Color.fromARGB(
                  (255 * shape.opacity).round(),
                  255,
                  255,
                  255,
                );
              }
              final src = Rect.fromLTWH(
                0,
                0,
                img.width.toDouble(),
                img.height.toDouble(),
              );
              canvas.drawImageRect(img, src, rect, imgPaint);
              canvas.restore();
            } else {
              // Placeholder while image is loading
              canvas.save();
              canvas.transform(matrix.storage);
              final placeholderPaint = Paint()
                ..color = const Color(0xFFE0E0E0)
                ..style = PaintingStyle.fill;
              canvas.drawRect(rect, placeholderPaint);
              final borderPaint = Paint()
                ..color = const Color(0xFF9E9E9E)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0;
              canvas.drawRect(rect, borderPaint);
              // Draw image icon in center
              final iconSize = rect.shortestSide * 0.3;
              final iconRect = Rect.fromCenter(
                center: rect.center,
                width: iconSize,
                height: iconSize * 0.75,
              );
              canvas.drawRect(iconRect, borderPaint);
              canvas.restore();
            }
          }
          if (erasePathsImg != null) _endEraseMask(canvas, erasePathsImg);
          _drawShapeRasterOverlay(
            canvas,
            shape: shape,
            matrix: matrix,
            localBounds: baseBounds,
            rasterImage: rasterImage,
          );
          if (_isSelected(shape.id) &&
              selectionBase != null &&
              activeTool != EditorTool.nodeEdit &&
              !skipSpatialSelection) {
            final pivotBase = baseBounds ?? selectionBase;
            _drawSelection(
              canvas,
              transformedCorners(
                selectionBase,
                shape.matrixForRect(baseBounds ?? selectionBase),
              ),
              canvasBounds: canvasBounds,
              pivotWorld: pivotBase != null
                  ? _pivotWorld(pivotBase, shape)
                  : null,
              pivotSnapGuide: pivotSnapGuide,
            );
          }
          break;
      }
    }

    if (hasSpatialSelection &&
        (spatialSelectionCorners != null || spatialSelectionBounds != null) &&
        activeTool != EditorTool.nodeEdit) {
      _drawSelection(
        canvas,
        spatialSelectionCorners ??
            transformedCorners(spatialSelectionBounds!, Matrix4.identity()),
        canvasBounds: canvasBounds,
        pivotWorld: null,
      );
    }

    // Live brush stroke preview should draw above shapes.
    if (inProgressStroke.isNotEmpty) {
      final renderer = _rendererFor(brushType);
      final isEraser = activeTool == EditorTool.eraser;
      final paint = Paint()..style = PaintingStyle.fill;
      if (isEraser) {
        paint.color = const Color(0x6690A4AE);
      } else {
        final baseAlpha = brushColor.alpha / 255.0;
        paint.color = brushColor.withValues(
          alpha: (baseAlpha * brushOpacity).clamp(0, 1),
        );
      }
      final decorated = renderer.decoratePaint(paint);

      // Use a smooth vector preview while drawing.
      final hasPressure = inProgressStroke.any((p) => p.pressure != null);
      final path = _buildFreehandPathFromPoints(
        inProgressStroke,
        brushThickness,
        brushSmoothness,
        renderer,
        hasPressureData: hasPressure,
      );
      if (path != null) {
        canvas.drawPath(path, decorated);
      }
    }

    // Draw node editing overlay when in node edit mode
    if (activeTool == EditorTool.nodeEdit &&
        nodeEditState != null &&
        selectedShapeId != null &&
        shapes.isNotEmpty) {
      final shapeIndex = shapes.indexWhere((s) => s.id == selectedShapeId);
      if (shapeIndex != -1) {
        _drawNodeEditOverlay(canvas, shapes[shapeIndex], nodeEditState!);
      }
    }

    // Render merge preview overlay if active
    if (mergePreviewShape != null) {
      _paintMergePreview(canvas, mergePreviewShape!);
    }

    if (hasOriginOffset) {
      canvas.restore();
    }
  }

  /// Paints the merge preview shape with a semi-transparent overlay effect.
  void _paintMergePreview(Canvas canvas, Shape previewShape) {
    final renderer = _rendererFor(previewShape.brushType);
    final baseAlpha = previewShape.strokeColor.alpha / 255.0;
    final baseBounds = previewShape.localBounds;
    final matrix = previewShape.matrixForRect(baseBounds ?? Rect.zero);

    // Preview opacity - semi-transparent to show it's not final
    const previewOpacity = 0.6;
    final effectiveOpacity = previewShape.opacity * previewOpacity;

    // Calculate effective stroke width (same as main paint method)
    final baseScale = _strokeScaleFor(previewShape);
    final scaleFactor = strokeScaleWithShape ? math.max(1.0, baseScale) : 1.0;
    final effectiveStrokeWidth = previewShape.strokeWidth / scaleFactor;

    // Create paint for stroke
    final strokeColor = previewShape.strokeColor.withValues(
      alpha: (baseAlpha * effectiveOpacity).clamp(0, 1),
    );
    final strokePaint = renderer.decoratePaint(
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStrokeWidth,
    );
    final fillPaint = renderer.decoratePaint(
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill,
    );

    switch (previewShape.kind) {
      case ShapeKind.freehand:
        final worldPoints = _transformOffsets(previewShape.points, matrix);
        final hasPressure =
            previewShape.pointPressures != null &&
            previewShape.pointPressures!.length == previewShape.points.length;
        final vectorPoints = _pointsWithPressure(
          worldPoints,
          previewShape.pointPressures,
        );

        // Draw fill if present
        if (previewShape.fillColor != null && FillUtils.canFill(previewShape)) {
          final fillPath = _buildFreehandFillPath(worldPoints);
          if (fillPath != null) {
            final shapeFillPaint = Paint()
              ..color = previewShape.fillColor!.withValues(
                alpha:
                    (previewShape.fillColor!.alpha / 255.0 * effectiveOpacity)
                        .clamp(0, 1),
              )
              ..style = PaintingStyle.fill;
            canvas.drawPath(fillPath, shapeFillPaint);
          }
        }

        // Draw stroke
        final path = _buildFreehandPathFromOffsets(
          vectorPoints,
          effectiveStrokeWidth,
          previewShape.brushSmoothness ?? brushSmoothness,
          renderer,
          hasPressureData: hasPressure,
        );
        if (path != null) {
          canvas.drawPath(path, fillPaint);
        }
        break;

      case ShapeKind.polygon:
        final contours = previewShape.contours.isNotEmpty
            ? previewShape.contours
            : (previewShape.points.isNotEmpty
                  ? [previewShape.points]
                  : const <List<Offset>>[]);
        final worldContours = _transformContours(contours, matrix);
        final path = _buildContourPath(
          worldContours,
          closePath: true,
          evenOdd: contours.length > 1,
        );
        if (path != null) {
          // Draw fill if present
          if (previewShape.fillColor != null) {
            final shapeFillPaint = Paint()
              ..color = previewShape.fillColor!.withValues(
                alpha:
                    (previewShape.fillColor!.alpha / 255.0 * effectiveOpacity)
                        .clamp(0, 1),
              )
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, shapeFillPaint);
          }
          // Draw stroke
          canvas.drawPath(path, strokePaint);
        }
        break;

      case ShapeKind.rectangle:
        if (baseBounds != null) {
          _withShapeTransform(canvas, matrix, () {
            // Draw fill if present
            if (previewShape.fillColor != null) {
              final shapeFillPaint = Paint()
                ..color = previewShape.fillColor!.withValues(
                  alpha:
                      (previewShape.fillColor!.alpha / 255.0 * effectiveOpacity)
                          .clamp(0, 1),
                )
                ..style = PaintingStyle.fill;
              canvas.drawRect(baseBounds, shapeFillPaint);
            }
            // Draw stroke
            canvas.drawRect(baseBounds, strokePaint);
          });
        }
        break;

      case ShapeKind.ellipse:
        if (baseBounds != null) {
          _withShapeTransform(canvas, matrix, () {
            // Draw fill if present
            if (previewShape.fillColor != null) {
              final shapeFillPaint = Paint()
                ..color = previewShape.fillColor!.withValues(
                  alpha:
                      (previewShape.fillColor!.alpha / 255.0 * effectiveOpacity)
                          .clamp(0, 1),
                )
                ..style = PaintingStyle.fill;
              canvas.drawOval(baseBounds, shapeFillPaint);
            }
            // Draw stroke
            canvas.drawOval(baseBounds, strokePaint);
          });
        }
        break;

      case ShapeKind.line:
        if (previewShape.points.length >= 2) {
          final worldPoints = _transformOffsets(previewShape.points, matrix);
          canvas.drawLine(worldPoints[0], worldPoints[1], strokePaint);
        }
        break;

      case ShapeKind.pointPath:
        // Point path preview - similar to polygon
        if (previewShape.hasBezierCurves && previewShape.bezierPoints != null) {
          final bezierPath = _buildBezierCurvePath(
            previewShape.bezierPoints!,
            matrix,
            previewShape.isClosed,
          );
          if (bezierPath != null) {
            if (previewShape.fillColor != null && previewShape.isClosed) {
              final shapeFillPaint = Paint()
                ..color = previewShape.fillColor!.withValues(
                  alpha: (previewShape.fillColor!.a * effectiveOpacity).clamp(
                    0,
                    1,
                  ),
                )
                ..style = PaintingStyle.fill;
              canvas.drawPath(bezierPath, shapeFillPaint);
            }
            canvas.drawPath(bezierPath, strokePaint);
          }
        } else {
          final worldPoints = _transformOffsets(previewShape.points, matrix);
          final path = _buildPolyline(
            worldPoints,
            closePath: previewShape.isClosed,
          );
          if (path != null) {
            if (previewShape.fillColor != null && previewShape.isClosed) {
              final shapeFillPaint = Paint()
                ..color = previewShape.fillColor!.withValues(
                  alpha: (previewShape.fillColor!.a * effectiveOpacity).clamp(
                    0,
                    1,
                  ),
                )
                ..style = PaintingStyle.fill;
              canvas.drawPath(path, shapeFillPaint);
            }
            canvas.drawPath(path, strokePaint);
          }
        }
        break;

      case ShapeKind.image:
        break; // Images don't participate in merge preview
    }

    // Draw a highlighted border to indicate this is a preview
    final bounds = previewShape.worldBounds;
    if (bounds != null) {
      final borderPaint = Paint()
        ..color = Colors.blue.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / viewportScale;
      canvas.drawRect(bounds.inflate(4 / viewportScale), borderPaint);

      // Draw "Preview" label
      final textSpan = TextSpan(
        text: 'Preview',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 12 / viewportScale,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(bounds.left, bounds.top - 16 / viewportScale),
      );
    }
  }

  Path? _buildFreehandPathFromOffsets(
    List<PointVector> points,
    double thickness,
    double smoothness,
    BrushRenderer renderer, {
    bool hasPressureData = false,
  }) {
    if (points.isEmpty) return null;
    final smooth = _strokeSmoothing(smoothness);
    final streamline = _strokeStreamline(smoothness);
    // When we have real pressure data, don't simulate it - use the actual values.
    // This prevents width distortion when editing nodes since perfect_freehand
    // simulates pressure based on point spacing/velocity when simulatePressure is true.
    final shouldSimulatePressure = !hasPressureData;
    return renderer.buildPath(
      points,
      BrushStrokeOptions(
        size: thickness,
        thinning: 0.5,
        smoothing: smooth,
        streamline: streamline,
        simulatePressure: shouldSimulatePressure,
        isComplete: true,
      ),
    );
  }

  Path? _buildFreehandPathFromPoints(
    List<PointVector> points,
    double thickness,
    double smoothness,
    BrushRenderer renderer, {
    bool hasPressureData = false,
  }) {
    final smooth = _strokeSmoothing(smoothness);
    final streamline = _strokeStreamline(smoothness);
    final shouldSimulatePressure = !hasPressureData;
    // Use isComplete: true during drawing to prevent thin edges
    // This ensures consistent rendering that matches the final stroke
    return renderer.buildPath(
      points,
      BrushStrokeOptions(
        size: thickness,
        thinning: 0.5,
        smoothing: smooth,
        streamline: streamline,
        simulatePressure: shouldSimulatePressure,
        isComplete: true,
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

  /// Draws the node editing overlay showing editable nodes on a shape.
  /// For multi-contour shapes, draws all contours with visual distinction.
  /// In weighted edit mode, hides most nodes and only shows the active node.
  void _drawNodeEditOverlay(
    Canvas canvas,
    Shape shape,
    NodeEditState nodeState,
  ) {
    final activeContourIndex = nodeState.activeContourIndex;
    final nodeSize = nodeHandleCanvasSize(viewportScale);
    final halfSize = nodeSize / 2;

    // Get all contour positions
    final allContourPositions = NodeOperations.getAllContourWorldPositions(
      shape,
    );
    if (allContourPositions.isEmpty) return;

    // Colors for distinguishing contours
    const inactiveContourColors = [
      Color(0xFF9CA3AF), // Gray
      Color(0xFFF59E0B), // Amber
      Color(0xFF10B981), // Emerald
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEC4899), // Pink
      Color(0xFF06B6D4), // Cyan
    ];

    // First pass: Draw inactive contours (dimmed)
    for (
      var contourIdx = 0;
      contourIdx < allContourPositions.length;
      contourIdx++
    ) {
      if (contourIdx == activeContourIndex)
        continue; // Skip active contour for now

      final contourPositions = allContourPositions[contourIdx];
      if (contourPositions.isEmpty) continue;

      final contourColor =
          inactiveContourColors[contourIdx % inactiveContourColors.length];

      // Draw inactive contour path (dimmed)
      _drawNodeEditPathWithColor(
        canvas,
        contourPositions,
        shape.isClosed,
        contourColor.withValues(alpha: 0.4),
      );

      // In weighted edit mode, don't draw nodes on inactive contours
      if (!nodeState.useWeightedEdit) {
        // Draw inactive contour nodes (smaller, dimmed)
        final inactiveHalfSize = halfSize * 0.7;
        for (var i = 0; i < contourPositions.length; i++) {
          _drawInactiveNodeHandle(
            canvas,
            contourPositions[i],
            inactiveHalfSize,
            contourColor,
          );
        }
      }
    }

    // Second pass: Draw active contour (full visibility)
    if (activeContourIndex >= 0 &&
        activeContourIndex < allContourPositions.length) {
      final activePositions = allContourPositions[activeContourIndex];
      if (activePositions.isNotEmpty) {
        // Check if shape has Bezier curves (and not in weighted edit mode)
        // Also hide bezier handles for merged shapes that should use weighted editing
        const nodeEditService = NodeEditService();
        final shouldHideHandles =
            nodeState.useWeightedEdit ||
            nodeEditService.shouldHideBezierHandles(shape);
        final hasBezier = shape.hasBezierCurves && !shouldHideHandles;

        if (hasBezier && shape.bezierPoints != null) {
          // Use the same matrix calculation as the main renderer for consistency
          // This ensures the overlay path matches the rendered shape exactly
          final baseBounds = shape.localBounds;
          final matrix = shape.matrixForRect(baseBounds ?? Rect.zero);

          // Draw Bezier curve path
          _drawBezierPath(canvas, shape.bezierPoints!, shape.isClosed, matrix);

          // Draw Bezier control handles and anchor points
          _drawBezierHandles(
            canvas,
            shape.bezierPoints!,
            matrix,
            nodeState,
            halfSize,
          );
        } else if (nodeState.useWeightedEdit) {
          // Weighted edit mode: draw path and only the active node
          // For freehand, use the same stroke outline as rendering so overlay matches stroke
          _drawWeightedEditOverlay(
            canvas,
            activePositions,
            nodeState,
            halfSize,
            shape.isClosed,
            shape: shape,
          );
        } else {
          // Standard polygon path
          _drawNodeEditPath(canvas, activePositions, shape.isClosed);

          // Draw segment hover highlight (for path interaction)
          if (nodeState.hoveredSegmentIndex != null) {
            _drawHoveredSegment(
              canvas,
              activePositions,
              nodeState.hoveredSegmentIndex!,
              shape.isClosed,
            );
          }

          // Draw node handles for active contour
          for (var i = 0; i < activePositions.length; i++) {
            final pos = activePositions[i];
            final isSelected = nodeState.selectedNodeIndices.contains(i);
            final isHovered = nodeState.hoveredNodeIndex == i;

            _drawNodeHandle(
              canvas,
              pos,
              halfSize,
              isSelected: isSelected,
              isHovered: isHovered,
            );
          }
        }
      }
    }
  }

  /// Draws the overlay for weighted edit mode.
  /// Shows only the path and the active node, plus an influence indicator.
  /// For freehand shapes, draws the stroke outline to match the rendered stroke
  /// (avoids "nodes stay behind" where polyline extends past rounded caps).
  void _drawWeightedEditOverlay(
    Canvas canvas,
    List<Offset> nodePositions,
    NodeEditState nodeState,
    double halfSize,
    bool isClosed, {
    Shape? shape,
  }) {
    final activeIndex = nodeState.activeNodeIndex;
    final isDragging = nodeState.isDragging;

    // When dragging, only show the influence indicator (no path overlay to avoid double-line)
    // When not dragging, show a subtle path outline for interaction feedback
    if (!isDragging) {
      if (shape != null && shape.kind == ShapeKind.freehand) {
        _drawFreehandWeightedPath(canvas, shape, nodePositions);
      } else {
        _drawNodeEditPathWeighted(canvas, nodePositions, isClosed);
      }
    }

    // Draw segment hover highlight when not dragging (user can click anywhere on path)
    if (!isDragging && nodeState.hoveredSegmentIndex != null) {
      _drawHoveredSegment(
        canvas,
        nodePositions,
        nodeState.hoveredSegmentIndex!,
        isClosed,
      );
    }

    // Draw influence range indicator when dragging
    if (isDragging &&
        activeIndex != null &&
        activeIndex < nodePositions.length) {
      _drawWeightedInfluenceIndicator(
        canvas,
        nodePositions,
        activeIndex,
        nodeState.arcLengths,
        nodeState.weightedInfluenceRadius,
        nodeState.cornerIndices,
        isClosed,
      );
    }

    // Draw only the active/selected node (larger for visibility)
    if (activeIndex != null && activeIndex < nodePositions.length) {
      final activePos = nodePositions[activeIndex];
      _drawNodeHandle(
        canvas,
        activePos,
        halfSize * 1.2, // Slightly larger
        isSelected: true,
        isHovered: false,
      );
    }

    // Draw hovered node if different from active
    final hoveredIndex = nodeState.hoveredNodeIndex;
    if (hoveredIndex != null &&
        hoveredIndex != activeIndex &&
        hoveredIndex < nodePositions.length) {
      final hoveredPos = nodePositions[hoveredIndex];
      _drawNodeHandle(
        canvas,
        hoveredPos,
        halfSize * 0.8, // Slightly smaller
        isSelected: false,
        isHovered: true,
      );
    }
  }

  /// Draws the weighted overlay path for freehand using the same stroke outline
  /// as rendering, so the overlay matches the stroke (fixes "nodes stay behind").
  void _drawFreehandWeightedPath(
    Canvas canvas,
    Shape shape,
    List<Offset> nodePositions,
  ) {
    if (nodePositions.length < 2) return;

    final vectorPoints = _pointsWithPressure(
      nodePositions,
      shape.pointPressures,
    );
    final baseScale = _strokeScaleFor(shape);
    final scaleFactor = strokeScaleWithShape ? math.max(1.0, baseScale) : 1.0;
    final effectiveStrokeWidth = shape.strokeWidth / scaleFactor;
    final hasPressure =
        shape.pointPressures != null &&
        shape.pointPressures!.length == nodePositions.length;
    final renderer = _rendererFor(shape.brushType);

    final path = _buildFreehandPathFromOffsets(
      vectorPoints,
      effectiveStrokeWidth,
      shape.brushSmoothness ?? brushSmoothness,
      renderer,
      hasPressureData: hasPressure,
    );
    if (path == null) return;

    final strokeWidth = 1.0 / viewportScale;
    final pathPaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(0.3, 2.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);
  }

  /// Draws the path in weighted edit mode with subtle styling.
  void _drawNodeEditPathWeighted(
    Canvas canvas,
    List<Offset> nodePositions,
    bool isClosed,
  ) {
    if (nodePositions.length < 2) return;

    final path = Path()..moveTo(nodePositions.first.dx, nodePositions.first.dy);
    for (var i = 1; i < nodePositions.length; i++) {
      path.lineTo(nodePositions[i].dx, nodePositions[i].dy);
    }
    if (isClosed) {
      path.close();
    }

    // Draw with subtle dashed appearance for interaction hint without obscuring stroke
    final strokeWidth = 1.0 / viewportScale;
    final pathPaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(0.3, 2.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);
  }

  /// Draws a visual indicator showing the influence range during weighted drag.
  void _drawWeightedInfluenceIndicator(
    Canvas canvas,
    List<Offset> nodePositions,
    int activeIndex,
    List<double> arcLengths,
    double influenceRadius,
    Set<int> cornerIndices,
    bool isClosed,
  ) {
    if (arcLengths.isEmpty || arcLengths.length != nodePositions.length) return;

    final activeArcLength = arcLengths[activeIndex];
    final totalLength = arcLengths.last;

    // Draw gradient-like segments showing influence falloff
    final influencePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4.0 / viewportScale).clamp(1.0, 6.0)
      ..strokeCap = StrokeCap.round;

    // Sigma for Gaussian (same as in weighted move - gentler falloff)
    final sigma = influenceRadius / 2.0;
    final twoSigmaSquared = 2.0 * sigma * sigma;

    for (var i = 0; i < nodePositions.length - 1; i++) {
      // Compute average weight for this segment
      double dist1, dist2;
      if (isClosed) {
        final directDist1 = (arcLengths[i] - activeArcLength).abs();
        dist1 = directDist1 < totalLength - directDist1
            ? directDist1
            : totalLength - directDist1;
        final directDist2 = (arcLengths[i + 1] - activeArcLength).abs();
        dist2 = directDist2 < totalLength - directDist2
            ? directDist2
            : totalLength - directDist2;
      } else {
        dist1 = (arcLengths[i] - activeArcLength).abs();
        dist2 = (arcLengths[i + 1] - activeArcLength).abs();
      }

      final avgDist = (dist1 + dist2) / 2;
      var weight = _gaussianWeight(avgDist, twoSigmaSquared);

      // Reduce weight visualization for corners
      if (cornerIndices.contains(i) || cornerIndices.contains(i + 1)) {
        weight *= 0.5;
      }

      if (weight < 0.05) continue; // Skip segments with negligible influence

      // Color based on weight: bright cyan at high weight, fading to transparent
      final alpha = (weight * 0.6).clamp(0.0, 0.6);
      influencePaint.color = const Color(0xFF00BCD4).withValues(alpha: alpha);

      canvas.drawLine(nodePositions[i], nodePositions[i + 1], influencePaint);
    }

    // Handle closing segment for closed paths
    if (isClosed && nodePositions.length > 2) {
      final lastIdx = nodePositions.length - 1;
      double dist1, dist2;
      final directDist1 = (arcLengths[lastIdx] - activeArcLength).abs();
      dist1 = directDist1 < totalLength - directDist1
          ? directDist1
          : totalLength - directDist1;
      final directDist2 = (arcLengths[0] - activeArcLength).abs();
      dist2 = directDist2 < totalLength - directDist2
          ? directDist2
          : totalLength - directDist2;

      final avgDist = (dist1 + dist2) / 2;
      var weight = _gaussianWeight(avgDist, twoSigmaSquared);

      if (cornerIndices.contains(lastIdx) || cornerIndices.contains(0)) {
        weight *= 0.5;
      }

      if (weight >= 0.05) {
        final alpha = (weight * 0.6).clamp(0.0, 0.6);
        influencePaint.color = const Color(0xFF00BCD4).withValues(alpha: alpha);
        canvas.drawLine(
          nodePositions[lastIdx],
          nodePositions[0],
          influencePaint,
        );
      }
    }
  }

  /// Computes Gaussian weight for influence visualization.
  double _gaussianWeight(double distance, double twoSigmaSquared) {
    return math.exp(-(distance * distance) / twoSigmaSquared);
  }

  /// Draws a Bezier curve path in node edit mode.
  void _drawBezierPath(
    Canvas canvas,
    List<BezierPoint> bezierPoints,
    bool isClosed,
    Matrix4 transform,
  ) {
    if (bezierPoints.length < 2) return;

    final path = Path();

    // Transform first point to world coordinates
    Offset transformPoint(Offset local) {
      final v = transform.transform3(Vector3(local.dx, local.dy, 0));
      return Offset(v.x, v.y);
    }

    final firstWorld = transformPoint(bezierPoints.first.position);
    path.moveTo(firstWorld.dx, firstWorld.dy);

    // Draw Bezier segments
    for (var i = 0; i < bezierPoints.length; i++) {
      final nextIndex = (i + 1) % bezierPoints.length;
      if (!isClosed && nextIndex == 0) break;

      final current = bezierPoints[i];
      final next = bezierPoints[nextIndex];

      // Get control points in world coordinates
      final p0 = transformPoint(current.position);
      final p1 = transformPoint(current.controlOutAbsolute);
      final p2 = transformPoint(next.controlInAbsolute);
      final p3 = transformPoint(next.position);

      // Draw cubic Bezier curve
      path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    }

    // Draw the path
    final strokeWidth = 1.0 / viewportScale;
    final pathPaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(0.2, 3.0);

    canvas.drawPath(path, pathPaint);
  }

  /// Draws Bezier anchor points and control handles.
  void _drawBezierHandles(
    Canvas canvas,
    List<BezierPoint> bezierPoints,
    Matrix4 transform,
    NodeEditState nodeState,
    double handleSize,
  ) {
    Offset transformPoint(Offset local) {
      final v = transform.transform3(Vector3(local.dx, local.dy, 0));
      return Offset(v.x, v.y);
    }

    // Control handles are larger and more visible for easier interaction
    final controlHandleSize = handleSize * 0.8;
    final controlLineWidth = (1.5 / viewportScale).clamp(0.75, 3.0);

    // Control handle line paint - more visible
    final linePaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = controlLineWidth;

    // Control handle fill paint - distinct color (light blue)
    final controlFillPaint = Paint()
      ..color = const Color(0xFF64B5F6)
      ..style = PaintingStyle.fill;

    final controlStrokePaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (controlHandleSize * 0.25).clamp(0.75, 2.5);

    for (var i = 0; i < bezierPoints.length; i++) {
      final bp = bezierPoints[i];
      final anchor = transformPoint(bp.position);
      final isSelected = nodeState.selectedNodeIndices.contains(i);
      final isHovered = nodeState.hoveredNodeIndex == i;

      // Draw control handles for selected nodes
      if (isSelected || isHovered) {
        // Control In handle
        if (bp.controlIn != null) {
          final controlIn = transformPoint(bp.controlInAbsolute);
          // Draw line from anchor to control point
          canvas.drawLine(anchor, controlIn, linePaint);
          // Draw control point handle (circle) - larger for easier grabbing
          canvas.drawCircle(
            controlIn,
            controlHandleSize * 0.5,
            controlFillPaint,
          );
          canvas.drawCircle(
            controlIn,
            controlHandleSize * 0.5,
            controlStrokePaint,
          );
        }

        // Control Out handle
        if (bp.controlOut != null) {
          final controlOut = transformPoint(bp.controlOutAbsolute);
          // Draw line from anchor to control point
          canvas.drawLine(anchor, controlOut, linePaint);
          // Draw control point handle (circle) - larger for easier grabbing
          canvas.drawCircle(
            controlOut,
            controlHandleSize * 0.5,
            controlFillPaint,
          );
          canvas.drawCircle(
            controlOut,
            controlHandleSize * 0.5,
            controlStrokePaint,
          );
        }
      }

      // Draw anchor point (square for Bezier points to distinguish from polygon nodes)
      _drawBezierAnchor(
        canvas,
        anchor,
        handleSize * 0.5,
        isSelected: isSelected,
        isHovered: isHovered,
      );
    }
  }

  /// Draws a Bezier anchor point (square shape to distinguish from polygon nodes).
  void _drawBezierAnchor(
    Canvas canvas,
    Offset position,
    double halfSize, {
    required bool isSelected,
    required bool isHovered,
  }) {
    final rect = Rect.fromCenter(
      center: position,
      width: halfSize * 2,
      height: halfSize * 2,
    );

    // Shadow for contrast
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, halfSize * 0.15);
    canvas.drawRect(
      rect.shift(Offset(halfSize * 0.1, halfSize * 0.1)),
      shadowPaint,
    );

    // Fill
    final fillColor = isSelected
        ? selectionColor
        : (isHovered ? selectionColor.withValues(alpha: 0.4) : Colors.white);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Stroke/ring
    final strokeColor = isSelected ? Colors.white : selectionColor;
    final ringWidth = halfSize * 0.2;
    final ringPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth.clamp(0.5, 3.0);
    canvas.drawRect(rect, ringPaint);
  }

  /// Draws the path outline in node edit mode.
  void _drawNodeEditPath(
    Canvas canvas,
    List<Offset> nodePositions,
    bool isClosed,
  ) {
    _drawNodeEditPathWithColor(
      canvas,
      nodePositions,
      isClosed,
      selectionColor.withValues(alpha: 0.6),
    );
  }

  /// Draws a contour path with a specific color.
  void _drawNodeEditPathWithColor(
    Canvas canvas,
    List<Offset> nodePositions,
    bool isClosed,
    Color color,
  ) {
    if (nodePositions.length < 2) return;

    final path = Path()..moveTo(nodePositions.first.dx, nodePositions.first.dy);
    for (var i = 1; i < nodePositions.length; i++) {
      path.lineTo(nodePositions[i].dx, nodePositions[i].dy);
    }
    if (isClosed) {
      path.close();
    }

    // Dashed/highlighted path style
    final strokeWidth = 1.0 / viewportScale;
    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(0.2, 3.0);

    canvas.drawPath(path, pathPaint);
  }

  /// Draws highlight for hovered segment (for adding nodes).
  void _drawHoveredSegment(
    Canvas canvas,
    List<Offset> nodePositions,
    int segmentIndex,
    bool isClosed,
  ) {
    final maxIndex = isClosed
        ? nodePositions.length - 1
        : nodePositions.length - 2;
    if (segmentIndex < 0 || segmentIndex > maxIndex) return;

    final a = nodePositions[segmentIndex];
    final b = nodePositions[(segmentIndex + 1) % nodePositions.length];

    final strokeWidth = 3.0 / viewportScale;
    final highlightPaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(0.5, 8.0)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(a, b, highlightPaint);

    // Draw a preview node at the midpoint
    final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final previewSize = nodeHandleCanvasSize(viewportScale) * 0.7;
    final previewPaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(midpoint, previewSize / 2, previewPaint);
  }

  /// Draws a single node handle.
  void _drawNodeHandle(
    Canvas canvas,
    Offset position,
    double halfSize, {
    required bool isSelected,
    required bool isHovered,
  }) {
    // Shadow for contrast
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, halfSize * 0.15);
    canvas.drawCircle(
      position + Offset(halfSize * 0.1, halfSize * 0.1),
      halfSize,
      shadowPaint,
    );

    // Fill
    final fillColor = isSelected
        ? selectionColor
        : (isHovered ? selectionColor.withValues(alpha: 0.4) : Colors.white);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, halfSize, fillPaint);

    // Stroke/ring
    final strokeColor = isSelected ? Colors.white : selectionColor;
    final ringWidth = halfSize * 0.2;
    final ringPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth.clamp(0.5, 3.0);
    canvas.drawCircle(position, halfSize, ringPaint);
  }

  /// Draws a node handle for an inactive contour (smaller, dimmed, colored).
  void _drawInactiveNodeHandle(
    Canvas canvas,
    Offset position,
    double halfSize,
    Color color,
  ) {
    // Semi-transparent fill with contour color
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, halfSize, fillPaint);

    // Stroke/ring with contour color
    final ringWidth = halfSize * 0.25;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth.clamp(0.3, 2.0);
    canvas.drawCircle(position, halfSize, ringPaint);
  }

  /// Draws point handles for point path shapes during drawing.
  void _drawPointHandles(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;

    // Scale handle size inversely with viewport for consistent screen size
    final handleRadius = (6.0 / viewportScale).clamp(3.0, 12.0);
    final strokeWidth = (1.5 / viewportScale).clamp(0.5, 3.0);

    final fillPaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      // Draw white outline first for visibility
      canvas.drawCircle(point, handleRadius, strokePaint);
      // Then fill with selection color
      canvas.drawCircle(point, handleRadius * 0.8, fillPaint);

      // Draw inner dot for first point (start indicator)
      if (i == 0 && points.length > 1) {
        final innerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, handleRadius * 0.4, innerPaint);
      }
    }
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
    // Use consistent screen-space stroke width for selection edge
    // Clamp to reasonable bounds for both zoom in and zoom out
    const double screenStrokeWidth = 1.2;
    const double minStrokeWidth =
        0.3; // Minimum 0.3 pixels in canvas space (for extreme zoom in)
    const double maxStrokeWidth =
        5.0; // Maximum 5 pixels in canvas space (for extreme zoom out)
    final rawStrokeWidth = screenStrokeWidth / viewportScale;
    final strokeWidth = rawStrokeWidth.clamp(minStrokeWidth, maxStrokeWidth);
    const double selectionFillOpacity = 0.12;
    final highlightStroke = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final highlightFill = Paint()
      ..color = selectionColor.withValues(alpha: selectionFillOpacity)
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
    // Simple repaint check - compare all relevant properties
    return oldDelegate.shapes != shapes ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.selectedShapeIds != selectedShapeIds ||
        oldDelegate.selectionMode != selectionMode ||
        oldDelegate.inProgressStroke != inProgressStroke ||
        oldDelegate.brushThickness != brushThickness ||
        oldDelegate.brushOpacity != brushOpacity ||
        oldDelegate.brushSmoothness != brushSmoothness ||
        oldDelegate.brushColor != brushColor ||
        oldDelegate.strokeScaleWithShape != strokeScaleWithShape ||
        oldDelegate.selectionColor != selectionColor ||
        oldDelegate.rotationGuideCenter != rotationGuideCenter ||
        oldDelegate.rotationGuideAngle != rotationGuideAngle ||
        oldDelegate.pivotSnapGuide != pivotSnapGuide ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.nodeEditState != nodeEditState ||
        oldDelegate.mergePreviewShape != mergePreviewShape ||
        oldDelegate.artboardSize != artboardSize ||
        oldDelegate.artboardBackground != artboardBackground ||
        oldDelegate.worldOriginOffset != worldOriginOffset ||
        oldDelegate.imageCache != imageCache;
  }

  double _strokeSmoothing(double slider) =>
      StrokeRenderConfig.smoothingForValue(slider.clamp(0.0, 1.0));

  double _strokeStreamline(double slider) =>
      StrokeRenderConfig.streamlineForValue(slider.clamp(0.0, 1.0));

  void _drawStampedPreview(
    Canvas canvas,
    List<PointVector> points,
    Paint paint,
    double thickness,
  ) {
    if (points.isEmpty || thickness <= 0) return;
    final spacing = _stampSpacing(thickness);
    final baseRadius = thickness * 0.5;
    Offset? lastPoint;
    double lastPressure = points.first.pressure ?? 1.0;
    double distanceToNext = 0.0;
    Offset? lastStamp;

    void drawStamp(Offset pos, double pressure) {
      final scale = _pressureScale(pressure);
      final radius = baseRadius * scale;
      if (radius <= 0.001) return;
      canvas.drawCircle(pos, radius, paint);
      lastStamp = pos;
    }

    for (final p in points) {
      final pos = Offset(p.x, p.y);
      final pressure = p.pressure ?? 1.0;
      if (lastPoint == null) {
        drawStamp(pos, pressure);
        lastPoint = pos;
        lastPressure = pressure;
        distanceToNext = spacing;
        continue;
      }

      var segmentStart = lastPoint!;
      var segmentPressure = lastPressure;
      final segmentEnd = pos;
      final endPressure = pressure;
      var segment = segmentEnd - segmentStart;
      var segmentLen = segment.distance;
      if (segmentLen <= 0.0001) {
        lastPoint = segmentEnd;
        lastPressure = endPressure;
        continue;
      }

      var direction = segment / segmentLen;
      while (segmentLen >= distanceToNext) {
        final t = distanceToNext / segmentLen;
        final stampPos = segmentStart + direction * distanceToNext;
        final stampPressure = _lerp(segmentPressure, endPressure, t);
        drawStamp(stampPos, stampPressure);

        segmentStart = stampPos;
        segmentPressure = stampPressure;
        segment = segmentEnd - segmentStart;
        segmentLen = segment.distance;
        if (segmentLen <= 0.0001) {
          distanceToNext = spacing;
          break;
        }
        direction = segment / segmentLen;
        distanceToNext = spacing;
      }
      distanceToNext -= segmentLen;
      lastPoint = segmentEnd;
      lastPressure = endPressure;
    }

    if (lastPoint != null &&
        (lastStamp == null ||
            (lastPoint! - lastStamp!).distance > spacing * 0.25)) {
      drawStamp(lastPoint!, lastPressure);
    }
  }

  double _stampSpacing(double thickness) {
    final spacing = thickness.abs() * 0.25;
    return spacing.clamp(0.4, 12.0);
  }

  double _pressureScale(double pressure) {
    const thinning = 0.5;
    final p = pressure.clamp(0.0, 1.0);
    final minScale = (1.0 - thinning).clamp(0.2, 1.0);
    return minScale + (1.0 - minScale) * p;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  BrushRenderer _rendererFor(BrushType? type) {
    if (type == null) return brushRenderer;
    return BrushRendererRegistry.getRenderer(type);
  }

  List<PointVector> _pointsWithPressure(
    List<Offset> points,
    List<double>? pressures,
  ) {
    if (points.isEmpty) return const <PointVector>[];
    final hasPressure = pressures != null && pressures.length == points.length;
    if (hasPressure) {
      return List<PointVector>.generate(
        points.length,
        (i) =>
            PointVector.fromOffset(offset: points[i], pressure: pressures![i]),
        growable: false,
      );
    }
    return points
        .map((p) => PointVector.fromOffset(offset: p, pressure: 1.0))
        .toList(growable: false);
  }

  void _withShapeTransform(Canvas canvas, Matrix4 matrix, VoidCallback draw) {
    canvas.save();
    canvas.transform(matrix.storage);
    draw();
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Erase-mask helpers
  // ---------------------------------------------------------------------------

  /// Starts a per-shape layer and returns world-space erase contours.
  /// Caller must pass the returned paths to [_endEraseMask].
  List<Path>? _beginEraseMask(
    Canvas canvas,
    Shape shape,
    Rect layerBounds,
    Matrix4 matrix,
  ) {
    if (!shape.hasEraseMask) return null;

    // Build erase contours in world space from local-space contours.
    final erasePaths = <Path>[];
    for (final contour in shape.eraseContours!) {
      if (contour.length < 3) continue;
      final worldPoints = _transformOffsets(contour, matrix);
      final contourPath = Path()..fillType = PathFillType.nonZero;
      contourPath.moveTo(worldPoints.first.dx, worldPoints.first.dy);
      for (var i = 1; i < worldPoints.length; i++) {
        contourPath.lineTo(worldPoints[i].dx, worldPoints[i].dy);
      }
      contourPath.close();
      erasePaths.add(contourPath);
    }
    if (erasePaths.isEmpty) return null;

    // Draw shape into an isolated layer, then punch erased regions out.
    final layerRect = layerBounds.inflate(math.max(4.0, shape.strokeWidth * 2));
    canvas.saveLayer(layerRect, Paint());
    return erasePaths;
  }

  /// Punches out erased regions and restores the per-shape layer.
  void _endEraseMask(Canvas canvas, List<Path> erasePaths) {
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final erasePath in erasePaths) {
      canvas.drawPath(erasePath, clearPaint);
    }
    canvas.restore();
  }

  List<Offset> _transformOffsets(List<Offset> points, Matrix4 matrix) {
    if (points.isEmpty) return const <Offset>[];
    return points
        .map((p) {
          final v = matrix.transform3(Vector3(p.dx, p.dy, 0));
          return Offset(v.x, v.y);
        })
        .toList(growable: false);
  }

  List<List<Offset>> _transformContours(
    List<List<Offset>> contours,
    Matrix4 matrix,
  ) {
    if (contours.isEmpty) return const <List<Offset>>[];
    return contours
        .map((c) => _transformOffsets(c, matrix))
        .toList(growable: false);
  }

  Path? _buildFreehandFillPath(List<Offset> points) {
    if (points.length < 3) return null;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  Path? _buildContourPath(
    List<List<Offset>> contours, {
    required bool closePath,
    bool evenOdd = false,
  }) {
    if (contours.isEmpty) return null;
    final path = Path();
    for (final points in contours) {
      if (points.isEmpty) continue;
      path.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      if (closePath && points.length > 2) {
        path.close();
      }
    }
    if (evenOdd) {
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  /// Builds a path from Bezier curve data, transforming points to world coordinates.
  Path? _buildBezierCurvePath(
    List<BezierPoint> bezierPoints,
    Matrix4 transform,
    bool isClosed,
  ) {
    if (bezierPoints.length < 2) return null;

    final path = Path();

    // Transform local point to world coordinates
    Offset transformPoint(Offset local) {
      final v = transform.transform3(Vector3(local.dx, local.dy, 0));
      return Offset(v.x, v.y);
    }

    final firstWorld = transformPoint(bezierPoints.first.position);
    path.moveTo(firstWorld.dx, firstWorld.dy);

    // Draw Bezier segments
    for (var i = 0; i < bezierPoints.length; i++) {
      final nextIndex = (i + 1) % bezierPoints.length;
      if (!isClosed && nextIndex == 0) break;

      final current = bezierPoints[i];
      final next = bezierPoints[nextIndex];

      // Get control points in world coordinates
      final p1 = transformPoint(current.controlOutAbsolute);
      final p2 = transformPoint(next.controlInAbsolute);
      final p3 = transformPoint(next.position);

      // Draw cubic Bezier curve
      path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    }

    if (isClosed) {
      path.close();
    }

    return path;
  }

  String? _shapeRasterPaintPath(Shape shape) {
    final metadata = shape.metadata;
    if (metadata == null) return null;
    final raw = metadata[kShapeRasterPaintPathKey];
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    return null;
  }

  /// The raster paint sheet saves the image at an expanded rect (50% margin
  /// beyond the shape bounds on each side). This constant must match
  /// [_ShapeRasterPaintSheet._drawMarginFraction] in the paint sheet widget.
  static const double _rasterPaintMarginFraction = 0.5;

  void _drawShapeRasterOverlay(
    Canvas canvas, {
    required Shape shape,
    required Matrix4 matrix,
    required Rect? localBounds,
    required ui.Image? rasterImage,
  }) {
    if (rasterImage == null) return;
    final bounds = localBounds;
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) return;

    // The raster PNG covers an expanded area beyond the shape bounds.
    // Compute the same expanded rect so the image lines up correctly.
    final margin = math.max(bounds.width, bounds.height) *
        _rasterPaintMarginFraction;
    final drawBounds = bounds.inflate(margin);

    final src = Rect.fromLTWH(
      0,
      0,
      rasterImage.width.toDouble(),
      rasterImage.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (shape.opacity < 1.0) {
      paint.color = Color.fromARGB(
        (shape.opacity * 255).round().clamp(0, 255),
        255,
        255,
        255,
      );
    }

    canvas.save();
    canvas.transform(matrix.storage);
    // No clip — paint freely extends outside the shape outline.
    canvas.drawImageRect(rasterImage, src, drawBounds, paint);
    canvas.restore();
  }

  double _strokeScaleFor(Shape shape) {
    final sx = shape.scaleX.abs();
    final sy = shape.scaleY.abs();
    final maxScale = sx > sy ? sx : sy;
    return maxScale <= 0.0001 ? 1.0 : maxScale;
  }

  void _drawHandles(Canvas canvas, List<Offset> corners, Rect canvasBounds) {
    if (corners.length != 4) return;
    // Use constant screen-space size for handles (10 pixels on screen)
    // Since canvas coordinates are transformed, we divide by viewportScale
    // to maintain consistent screen size regardless of zoom direction
    // Clamp to reasonable bounds to prevent handles from becoming too large when zoomed out
    final size = selectionHandleCanvasSize(viewportScale);
    final half = size / 2;
    final handlePaint = Paint()
      ..color = selectionColor
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
    // Use consistent screen-space stroke width for rotation handle line
    // Clamp to reasonable bounds for both zoom in and zoom out
    const double screenLineWidth = 1.0;
    const double minStrokeWidth = 0.3;
    const double maxStrokeWidth = 5.0;
    final rawLineWidth = screenLineWidth / viewportScale;
    final lineWidth = rawLineWidth.clamp(minStrokeWidth, maxStrokeWidth);
    final linePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    canvas.drawLine(placement.anchor, placement.handle, linePaint);
  }

  void _drawPivot(Canvas canvas, Offset pivot) {
    // Use constant screen-space size for pivot handle (12 pixels on screen)
    // Clamp to reasonable bounds to maintain consistent appearance
    const double screenPivotSize = 12.0;
    const double minCanvasSize =
        1.0; // Minimum 1 pixel in canvas space (for extreme zoom in)
    const double maxCanvasSize =
        60.0; // Maximum 60 pixels in canvas space (for extreme zoom out)
    final rawSize = screenPivotSize / viewportScale;
    final size = rawSize.clamp(minCanvasSize, maxCanvasSize);
    final half = size / 2;
    final paint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivot, half * 0.6, paint);
    // Use consistent screen-space stroke width for pivot cross lines
    // Clamp to reasonable bounds for both zoom in and zoom out
    const double screenPivotStrokeWidth = 1.2;
    const double minStrokeWidth = 0.3;
    const double maxStrokeWidth = 5.0;
    final rawPivotStrokeWidth = screenPivotStrokeWidth / viewportScale;
    final pivotStrokeWidth = rawPivotStrokeWidth.clamp(
      minStrokeWidth,
      maxStrokeWidth,
    );
    final stroke = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = pivotStrokeWidth;
    canvas.drawLine(pivot + Offset(-half, 0), pivot + Offset(half, 0), stroke);
    canvas.drawLine(pivot + Offset(0, -half), pivot + Offset(0, half), stroke);
  }

  void _drawPivotGuide(Canvas canvas, Offset pivot, Offset target) {
    if ((pivot - target).distance < 0.5) return;
    // Use consistent screen-space stroke width for pivot guide
    // Clamp to reasonable bounds for both zoom in and zoom out
    const double screenGuideWidth = 3.0;
    const double minStrokeWidth = 0.3;
    const double maxStrokeWidth = 8.0;
    final rawGuideWidth = screenGuideWidth / viewportScale;
    final guideWidth = rawGuideWidth.clamp(minStrokeWidth, maxStrokeWidth);
    final guidePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = guideWidth
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
    final baseOffset = selectionHandleRotationOffset(viewportScale);
    Offset? fallbackHandle;
    Offset? fallbackAnchor;
    for (final anchor in edgeCenters) {
      final dir = anchor - center;
      final len = dir.distance;
      if (len <= 0) continue;
      final norm = dir / len;
      final candidate = center + norm * (len + baseOffset);
      fallbackHandle ??= candidate;
      fallbackAnchor ??= anchor;
      if (canvasBounds.contains(candidate)) {
        return _RotationHandlePlacement(handle: candidate, anchor: anchor);
      }
    }
    final rawHandle = fallbackHandle ?? center;
    return _RotationHandlePlacement(
      handle: _clampOffsetToRect(rawHandle, canvasBounds),
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
    // Use consistent screen-space stroke width for rotation guide
    // Clamp to reasonable bounds for both zoom in and zoom out
    const double screenGuideWidth = 1.2;
    const double minStrokeWidth = 0.3;
    const double maxStrokeWidth = 5.0;
    final rawGuideWidth = screenGuideWidth / viewportScale;
    final guideWidth = rawGuideWidth.clamp(minStrokeWidth, maxStrokeWidth);
    final guidePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = guideWidth
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
    if (selectionMode == SelectionMode.single) {
      return selectedShapeId == id;
    }
    return selectedShapeIds.contains(id);
  }

  Offset _clampOffsetToRect(Offset value, Rect rect) {
    return Offset(
      value.dx.clamp(rect.left, rect.right),
      value.dy.clamp(rect.top, rect.bottom),
    );
  }

  void _drawWorkspaceBackground(Canvas canvas, Size size) {
    final left = -worldOriginOffset.dx;
    final top = -worldOriginOffset.dy;
    final right = left + size.width;
    final bottom = top + size.height;
    final rect = Rect.fromLTRB(left, top, right, bottom);

    final backgroundPaint = Paint()..color = const Color(0xFFEDEFF2);
    canvas.drawRect(rect, backgroundPaint);

    var minorStep = 40.0;
    final maxDimension = math.max(size.width, size.height);
    if (maxDimension > 0) {
      while ((maxDimension / minorStep) > 2500) {
        minorStep *= 2.0;
      }
    }
    final majorStep = minorStep * 5.0;

    final minorPaint = Paint()
      ..color = const Color(0x3899A8BA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final majorPaint = Paint()
      ..color = const Color(0x668294A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final firstMinorX = (left / minorStep).floor() * minorStep;
    final firstMinorY = (top / minorStep).floor() * minorStep;
    for (double x = firstMinorX; x <= right; x += minorStep) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), minorPaint);
    }
    for (double y = firstMinorY; y <= bottom; y += minorStep) {
      canvas.drawLine(Offset(left, y), Offset(right, y), minorPaint);
    }

    final firstMajorX = (left / majorStep).floor() * majorStep;
    final firstMajorY = (top / majorStep).floor() * majorStep;
    for (double x = firstMajorX; x <= right; x += majorStep) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), majorPaint);
    }
    for (double y = firstMajorY; y <= bottom; y += majorStep) {
      canvas.drawLine(Offset(left, y), Offset(right, y), majorPaint);
    }
  }

  void _drawWorldOriginMarker(Canvas canvas) {
    const axisLength = 28.0;
    const circleRadius = 3.2;
    final axisPaint = Paint()
      ..color = const Color(0xFF5D6B7A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(-axisLength, 0),
      const Offset(axisLength, 0),
      axisPaint,
    );
    canvas.drawLine(
      const Offset(0, -axisLength),
      const Offset(0, axisLength),
      axisPaint,
    );
    final dotPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, circleRadius, dotPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '0,0',
        style: TextStyle(
          color: Color(0xFF394B5A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(8, 6));
  }

  /// Draws the artboard as a visual guide for unlimited canvas.
  /// The artboard is positioned at the origin (0,0) in world space.
  void _drawArtboard(
    Canvas canvas,
    Size artboardSize,
    CanvasBackground? background,
  ) {
    final artboardRect = Rect.fromLTWH(
      0,
      0,
      artboardSize.width,
      artboardSize.height,
    );

    // Draw shadow behind artboard for visual separation
    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(artboardRect.translate(4, 4), shadowPaint);

    // Draw artboard background
    if (background != null && !background.isTransparent) {
      final bgPaint = Paint()
        ..color = background.resolvedColor()
        ..style = PaintingStyle.fill;
      canvas.drawRect(artboardRect, bgPaint);
    } else {
      // Draw transparency checkerboard for transparent background
      _drawTransparencyCheckerboard(canvas, artboardRect);
    }

    // Draw artboard border
    final borderPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / viewportScale;
    canvas.drawRect(artboardRect, borderPaint);
  }

  /// Draws a checkerboard pattern to indicate transparency.
  void _drawTransparencyCheckerboard(Canvas canvas, Rect rect) {
    const tileSize = 18.0;
    const lightColor = Color(0xFFF2F2F2);
    const darkColor = Color(0xFFE0E0E0);

    canvas.save();
    canvas.clipRect(rect);

    final paint = Paint();
    final cols = (rect.width / tileSize).ceil();
    final rows = (rect.height / tileSize).ceil();

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final isLight = (x + y).isEven;
        paint.color = isLight ? lightColor : darkColor;
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + x * tileSize,
            rect.top + y * tileSize,
            tileSize,
            tileSize,
          ),
          paint,
        );
      }
    }

    canvas.restore();
  }
}

class _RotationHandlePlacement {
  const _RotationHandlePlacement({required this.handle, required this.anchor});

  final Offset handle;
  final Offset anchor;
}
