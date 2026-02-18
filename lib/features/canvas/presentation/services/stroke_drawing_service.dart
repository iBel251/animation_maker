import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_erase_service.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brush_stroke_factory.dart';
import 'package:animation_maker/features/canvas/presentation/services/stroke_input_processor.dart';
import '../providers/canvas_notifier.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class StrokeDrawingService {
  StrokeDrawingService();
  final List<PointVector> _currentStrokePoints = [];
  bool _isDrawingStroke = false;
  StrokeInputProcessor? _inputProcessor;
  final ShapeEraseService _eraseService = const ShapeEraseService();

  bool get isDrawing => _isDrawingStroke;

  StrokeStartResult start(
    EditorState state,
    ui.Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    if (state.activeTool != EditorTool.brush &&
        state.activeTool != EditorTool.eraser) {
      return const StrokeStartResult(false, <PointVector>[], false);
    }
    if (_isDrawingStroke) {
      return const StrokeStartResult(false, <PointVector>[], false);
    }
    _inputProcessor = StrokeInputProcessor(_settingsFor(state));
    final points = _inputProcessor!.start(point, timeStamp, pressure);
    _currentStrokePoints
      ..clear()
      ..addAll(points);
    _isDrawingStroke = true;

    final inProgress = List<PointVector>.unmodifiable(_currentStrokePoints);
    return StrokeStartResult(
      true,
      inProgress,
      true, // clear selection
    );
  }

  StrokeUpdateResult update(
    EditorState state,
    ui.Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    if (!_isDrawingStroke ||
        (state.activeTool != EditorTool.brush &&
            state.activeTool != EditorTool.eraser)) {
      return const StrokeUpdateResult(false, <PointVector>[]);
    }
    final processor =
        _inputProcessor ?? StrokeInputProcessor(_settingsFor(state));
    _inputProcessor ??= processor;
    final points = processor.add(point, timeStamp, pressure);
    if (points.isNotEmpty) {
      _currentStrokePoints.addAll(points);
    }
    final inProgress = List<PointVector>.unmodifiable(_currentStrokePoints);
    return StrokeUpdateResult(true, inProgress);
  }

  Future<StrokeFinishResult> finish(
    EditorState state, {
    required String Function() nextShapeId,
    required String Function() nextGroupId,
    required double brushSmoothness,
    List<Shape> shapes = const [],
    QuadTree? quadTree,
  }) async {
    if (!_isDrawingStroke) {
      return StrokeFinishResult.empty();
    }
    final tail = _inputProcessor?.finish() ?? const <PointVector>[];
    if (tail.isNotEmpty) {
      _currentStrokePoints.addAll(tail);
    }
    final strokePoints = _currentStrokePoints.isNotEmpty
        ? List<PointVector>.from(_currentStrokePoints)
        : <PointVector>[];
    if (strokePoints.isEmpty) {
      _resetStrokeState();
      return StrokeFinishResult.empty();
    }

    final isEraser = state.activeTool == EditorTool.eraser;

    // For eraser tool, perform actual vector erasing
    if (isEraser && shapes.isNotEmpty) {
      final eraserResult = await _performVectorErase(
        strokePoints: strokePoints,
        shapes: shapes,
        quadTree: quadTree,
        eraserThickness: state.eraserSettings.thickness,
        brushSmoothness: brushSmoothness,
        nextShapeId: nextShapeId,
        strokeScaleWithShape: state.strokeScaleWithShape,
      );
      _resetStrokeState();
      return eraserResult;
    }

    // Regular brush stroke
    String? strokeGroupId;
    if (!isEraser && state.groupingEnabled) {
      strokeGroupId = state.currentGroupId ?? nextGroupId();
    }

    final strokeColor = state.currentColor;
    final strokeResult = BrushStrokeFactory.build(
      vectorId: nextShapeId(),
      points: strokePoints,
      color: strokeColor,
      thickness: state.brushSettings[state.currentBrush]!.thickness,
      opacity: state.brushSettings[state.currentBrush]!.opacity,
      brushType: state.currentBrush,
      brushSmoothness: brushSmoothness,
      groupId: strokeGroupId,
    );

    _resetStrokeState();
    final shape = strokeResult.vectorShape;
    final selectId = state.activeTool == EditorTool.select ? shape.id : null;
    final nextGroup = strokeGroupId ?? state.currentGroupId;
    return StrokeFinishResult(
      newShapes: [shape],
      selectShapeId: selectId,
      clearSelection: selectId == null,
      inProgress: const [],
      newCurrentGroupId: nextGroup,
    );
  }

  /// Performs vector erasing by subtracting the eraser path from intersecting shapes.
  Future<StrokeFinishResult> _performVectorErase({
    required List<PointVector> strokePoints,
    required List<Shape> shapes,
    QuadTree? quadTree,
    required double eraserThickness,
    required double brushSmoothness,
    required String Function() nextShapeId,
    required bool strokeScaleWithShape,
  }) async {
    // Build the eraser path from stroke points
    final eraserPath = _buildEraserPath(strokePoints, eraserThickness);
    if (eraserPath == null) {
      return StrokeFinishResult.empty();
    }

    final eraserBounds = eraserPath.getBounds();
    final idsToDelete = <String>[];
    final newShapes = <Shape>[];
    final candidates = _eraseCandidates(
      shapes: shapes,
      quadTree: quadTree,
      eraserBounds: eraserBounds,
    );

    // Check each shape for intersection with eraser
    for (final shape in candidates) {
      // Quick bounds check first
      final shapeBounds = shape.worldBounds;
      if (shapeBounds == null || !shapeBounds.overlaps(eraserBounds)) {
        continue;
      }

      // Perform the actual erase operation
      final result = await _eraseService.eraseAsync(
        shape: shape,
        eraserPath: eraserPath,
        createId: nextShapeId,
        strokeScaleWithShape: strokeScaleWithShape,
        brushSmoothness: brushSmoothness,
        sampleDistance: _eraseSampleDistanceForThickness(eraserThickness),
      );

      if (result.didErase) {
        // When preserveId is true, replacement has same ID as original
        // This allows in-place updates in the layer tree
        if (!result.preserveId) {
          idsToDelete.add(shape.id);
        }
        newShapes.addAll(result.replacements);
      }
    }

    return StrokeFinishResult(
      newShapes: newShapes,
      selectShapeId: null,
      clearSelection: true,
      inProgress: const [],
      newCurrentGroupId: null,
      idsToDelete: idsToDelete,
    );
  }

  /// Builds an eraser Path using perfect_freehand for a smooth single outline.
  ui.Path? _buildEraserPath(List<PointVector> points, double thickness) {
    if (points.isEmpty || thickness <= 0) return null;

    // For single point, just draw a circle
    if (points.length == 1) {
      final path = ui.Path();
      path.addOval(
        ui.Rect.fromCircle(
          center: ui.Offset(points.first.x, points.first.y),
          radius: thickness / 2,
        ),
      );
      return path;
    }

    // Resample points to ensure smooth, consistent spacing
    final resampledPoints = _resamplePoints(points, thickness * 0.3);

    // Use perfect_freehand for smooth outline
    final outline = getStroke(
      resampledPoints,
      options: StrokeOptions(
        size: thickness,
        thinning: 0.0, // Consistent width
        smoothing: 0.8, // High smoothing for clean edges
        streamline: 0.8, // High streamline to reduce jitter
        simulatePressure: false,
        isComplete: true,
      ),
    );

    if (outline.isEmpty) return null;

    // Build smooth path using quadratic bezier curves
    return _buildSmoothPath(outline);
  }

  /// Resamples points to ensure consistent spacing for smoother eraser paths.
  List<PointVector> _resamplePoints(List<PointVector> points, double spacing) {
    if (points.length < 2) return points;

    final result = <PointVector>[points.first];
    var accumulated = 0.0;

    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final dx = curr.x - prev.x;
      final dy = curr.y - prev.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      accumulated += dist;

      // Add point if we've accumulated enough distance
      if (accumulated >= spacing) {
        result.add(curr);
        accumulated = 0.0;
      }
    }

    // Always include the last point
    if (result.last != points.last) {
      result.add(points.last);
    }

    return result;
  }

  /// Builds a smooth path from outline points using quadratic bezier curves.
  ui.Path _buildSmoothPath(List<ui.Offset> outline) {
    if (outline.isEmpty) return ui.Path();

    final path = ui.Path();

    if (outline.length == 1) {
      path.addOval(ui.Rect.fromCircle(center: outline.first, radius: 1));
      return path;
    }

    if (outline.length == 2) {
      path.moveTo(outline.first.dx, outline.first.dy);
      path.lineTo(outline.last.dx, outline.last.dy);
      path.close();
      return path;
    }

    // Use quadratic bezier curves for smoothness
    path.moveTo(outline.first.dx, outline.first.dy);

    for (var i = 1; i < outline.length - 1; i++) {
      final p0 = outline[i];
      final p1 = outline[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }

    // Connect to last point
    final last = outline.last;
    path.lineTo(last.dx, last.dy);
    path.close();

    return path;
  }

  StrokeCancelResult cancel() {
    if (!_isDrawingStroke) {
      return const StrokeCancelResult(false, <PointVector>[]);
    }
    _resetStrokeState();
    return const StrokeCancelResult(true, <PointVector>[]);
  }

  void _resetStrokeState() {
    _isDrawingStroke = false;
    _currentStrokePoints.clear();
    _inputProcessor?.reset();
    _inputProcessor = null;
  }

  StrokeInputSettings _settingsFor(EditorState state) {
    final isEraser = state.activeTool == EditorTool.eraser;
    final settings = isEraser
        ? state.eraserSettings
        : state.brushSettings[state.currentBrush]!;
    final thickness = settings.thickness.clamp(0.5, 300.0);

    // Eraser can use coarser input spacing to avoid excessive point growth when
    // users scrub quickly across many shapes.
    final minSpacing = isEraser
        ? (thickness * 0.08).clamp(0.5, 4.0)
        : (thickness * 0.02).clamp(0.1, 2.0);
    return StrokeInputSettings(
      minSpacing: minSpacing,
      maxSamplesPerSegment: isEraser ? 32 : 64,
    );
  }

  double _eraseSampleDistanceForThickness(double thickness) {
    final safeThickness = thickness.clamp(0.5, 300.0);
    return (safeThickness * 0.2).clamp(1.5, 8.0);
  }

  List<Shape> _eraseCandidates({
    required List<Shape> shapes,
    required ui.Rect eraserBounds,
    QuadTree? quadTree,
  }) {
    if (quadTree == null) return shapes;
    final indexed = quadTree.queryRect(eraserBounds);
    if (indexed.isEmpty) {
      // Safety fallback for cases where index is not initialized yet.
      if (quadTree.count == 0 && shapes.isNotEmpty) {
        return shapes;
      }
      return const <Shape>[];
    }

    // Keep candidate order consistent with layer order.
    final candidateIds = indexed.map((s) => s.id).toSet();
    return shapes
        .where((shape) => candidateIds.contains(shape.id))
        .toList(growable: false);
  }
}

class StrokeStartResult {
  const StrokeStartResult(this.started, this.inProgress, this.clearSelection);
  final bool started;
  final List<PointVector> inProgress;
  final bool clearSelection;
}

class StrokeUpdateResult {
  const StrokeUpdateResult(this.updated, this.inProgress);
  final bool updated;
  final List<PointVector> inProgress;
}

class StrokeFinishResult {
  const StrokeFinishResult({
    required this.newShapes,
    required this.selectShapeId,
    required this.clearSelection,
    required this.inProgress,
    required this.newCurrentGroupId,
    this.idsToDelete = const [],
  });

  final List<Shape> newShapes;
  final String? selectShapeId;
  final bool clearSelection;
  final List<PointVector> inProgress;
  final String? newCurrentGroupId;
  final List<String> idsToDelete;

  factory StrokeFinishResult.empty() => const StrokeFinishResult(
    newShapes: [],
    selectShapeId: null,
    clearSelection: false,
    inProgress: [],
    newCurrentGroupId: null,
  );
}

class StrokeCancelResult {
  const StrokeCancelResult(this.cancelled, this.inProgress);
  final bool cancelled;
  final List<PointVector> inProgress;
}
