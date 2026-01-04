import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/presentation/painting/brush_stroke_factory.dart';
import 'package:animation_maker/presentation/painting/raster_controller.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:animation_maker/presentation/screens/editor/editor_view_model.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class StrokeDrawingService {
  StrokeDrawingService(this._rasterController);

  final RasterController _rasterController;
  final List<PointVector> _currentStrokePoints = [];
  bool _isDrawingStroke = false;

  bool get isDrawing => _isDrawingStroke;

  StrokeStartResult start(EditorState state, Offset point) {
    if (state.activeTool != EditorTool.brush) {
      return const StrokeStartResult(false, <PointVector>[], false);
    }
    if (_isDrawingStroke) {
      return const StrokeStartResult(false, <PointVector>[], false);
    }
    _currentStrokePoints
      ..clear()
      ..add(PointVector.fromOffset(offset: point, pressure: 1.0));
    _isDrawingStroke = true;
    return StrokeStartResult(
      true,
      List<PointVector>.from(_currentStrokePoints),
      true, // clear selection
    );
  }

  StrokeUpdateResult update(EditorState state, Offset point) {
    if (!_isDrawingStroke || state.activeTool != EditorTool.brush) {
      return const StrokeUpdateResult(false, <PointVector>[]);
    }
    _currentStrokePoints.add(
      PointVector.fromOffset(offset: point, pressure: 1.0),
    );
    return StrokeUpdateResult(
      true,
      List<PointVector>.from(_currentStrokePoints),
    );
  }

  Future<StrokeFinishResult> finish(
    EditorState state, {
    required String Function() nextShapeId,
    required String Function() nextGroupId,
  }) async {
    if (!_isDrawingStroke) {
      return StrokeFinishResult.empty();
    }
    final rasterPoints = _currentStrokePoints.isNotEmpty
        ? List<PointVector>.from(_currentStrokePoints)
        : <PointVector>[];
    _resetStrokeState();
    if (rasterPoints.isEmpty) {
      return StrokeFinishResult.empty();
    }

    String? strokeGroupId;
    if (state.brushVectorMode && state.groupingEnabled) {
      strokeGroupId = state.currentGroupId ?? nextGroupId();
    }

    final strokeResult = BrushStrokeFactory.build(
      asVector: state.brushVectorMode,
      vectorId: nextShapeId(),
      points: rasterPoints,
      color: state.currentColor,
      thickness: state.brushThickness,
      opacity: state.brushOpacity,
      thinning: _strokeThinning(),
      smoothing: _strokeSmoothing(state.brushSmoothness),
      streamline: _strokeStreamline(state.brushSmoothness),
      simulatePressure: true,
      brushType: state.currentBrush,
      groupId: strokeGroupId,
    );

    if (strokeResult.isVector && strokeResult.vectorShape != null) {
      final shape = strokeResult.vectorShape!;
      final selectId = state.activeTool == EditorTool.select ? shape.id : null;
      final nextGroup = strokeGroupId ?? state.currentGroupId;
      return StrokeFinishResult(
        newShapes: [shape],
        rasterImage: null,
        selectShapeId: selectId,
        clearSelection: selectId == null,
        inProgress: const [],
        newCurrentGroupId: nextGroup,
      );
    }

    final newRaster = await _rasterController.addStroke(
      strokeResult.rasterStroke!,
    );

    return StrokeFinishResult(
      newShapes: const [],
      rasterImage: newRaster,
      selectShapeId: null,
      clearSelection: false,
      inProgress: const [],
      newCurrentGroupId: state.currentGroupId,
    );
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
  }

  double _strokeSmoothing(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.75;
  double _strokeStreamline(double slider) =>
      0.05 + slider.clamp(0.0, 1.0) * 0.55;
  double _strokeThinning() => 0.5;
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
    required this.rasterImage,
    required this.selectShapeId,
    required this.clearSelection,
    required this.inProgress,
    required this.newCurrentGroupId,
  });

  final List<Shape> newShapes;
  final Image? rasterImage;
  final String? selectShapeId;
  final bool clearSelection;
  final List<PointVector> inProgress;
  final String? newCurrentGroupId;

  factory StrokeFinishResult.empty() => const StrokeFinishResult(
    newShapes: [],
    rasterImage: null,
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
