import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animation_maker/core/widgets/color_picker_widget.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brush_renderer.dart';
import 'package:animation_maker/features/canvas/presentation/painting/raster_paint_modal_logic.dart';
import 'package:animation_maker/features/canvas/presentation/services/fill_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

Future<Uint8List?> showShapeRasterPaintSheet({
  required BuildContext context,
  required Shape shape,
  ui.Image? existingRasterImage,
  List<Color> recentColors = const <Color>[],
  ValueChanged<Color>? onColorUsed,
}) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    enableDrag: false,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(ctx).viewPadding.bottom + 12,
      ),
      child: _ShapeRasterPaintSheet(
        shape: shape,
        existingRasterImage: existingRasterImage,
        recentColors: recentColors,
        onColorUsed: onColorUsed,
      ),
    ),
  );
}

enum _PaintTool { brush, eraser }

enum _ClipOpType { onShape, insideFill }

class _ShapeRasterPaintSheet extends StatefulWidget {
  const _ShapeRasterPaintSheet({
    required this.shape,
    this.existingRasterImage,
    this.recentColors = const <Color>[],
    this.onColorUsed,
  });

  final Shape shape;
  final ui.Image? existingRasterImage;
  final List<Color> recentColors;
  final ValueChanged<Color>? onColorUsed;

  @override
  State<_ShapeRasterPaintSheet> createState() => _ShapeRasterPaintSheetState();
}

class _ShapeRasterPaintSheetState extends State<_ShapeRasterPaintSheet>
    with WidgetsBindingObserver {
  static const double _minBrushWidth = 1;
  static const double _maxBrushWidth = 60;
  static const double _previewPadding = 20;
  static const double _drawMarginFraction = 0.5;
  static const double _minViewportScale = 0.25;
  static const double _maxViewportScale = 8.0;
  static const double _minPointDistanceLocal = 0.15;

  late final Path _shapeDisplayPath;
  late final Path? _shapeInsideFillPath;
  late final Rect _shapeBounds;
  late final Rect _drawBounds;
  late final Matrix4 _visualMatrix;
  late final Matrix4 _inverseVisualMatrix;
  late final double _visualScaleEstimate;

  late final double _workingRasterScale;
  late final int _workingPixelWidth;
  late final int _workingPixelHeight;

  final BrushRenderer _proBrushRenderer = const PerfectFreehandRenderer();
  final RasterHistory<_RasterOp> _history = RasterHistory<_RasterOp>();
  final LinkedHashMap<int, _PointerSample> _activePointers =
      LinkedHashMap<int, _PointerSample>();

  _ActiveStroke? _activeStroke;
  int? _drawingPointerId;
  bool _isNavigating = false;
  double _gestureStartScale = 1.0;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartCenter = Offset.zero;
  double _gestureStartDistance = 1.0;

  double _viewportScale = 1.0;
  Offset _viewportPan = Offset.zero;

  double _brushWidthScreen = 10;
  double _eraserWidthScreen = 20;
  late Color _brushColor;
  bool _isSaving = false;
  _PaintTool _activeTool = _PaintTool.brush;

  ui.Image? _compositedImage;
  int _composeRequestId = 0;

  bool get _canClipInsideFill => _shapeInsideFillPath != null;
  bool get _hasAnyCommittedContent =>
      widget.existingRasterImage != null || _history.cursor > 0;

  double get _currentToolWidth =>
      _activeTool == _PaintTool.eraser ? _eraserWidthScreen : _brushWidthScreen;

  set _currentToolWidth(double value) {
    if (_activeTool == _PaintTool.eraser) {
      _eraserWidthScreen = value;
    } else {
      _brushWidthScreen = value;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shapeDisplayPath = _ShapeRasterPathBuilder.buildDisplayPath(widget.shape);
    _shapeBounds = _resolveShapeBounds(widget.shape, _shapeDisplayPath);
    final margin =
        math.max(_shapeBounds.width, _shapeBounds.height) * _drawMarginFraction;
    _drawBounds = _shapeBounds.inflate(margin);
    _shapeInsideFillPath = _ShapeRasterPathBuilder.buildInsideFillPath(
      widget.shape,
      _shapeBounds,
    );
    _visualMatrix = _buildVisualMatrix(widget.shape, _shapeBounds);
    _inverseVisualMatrix = Matrix4.copy(_visualMatrix);
    final determinant = _inverseVisualMatrix.invert();
    if (determinant == 0) {
      _inverseVisualMatrix.setIdentity();
    }
    final sx = widget.shape.scaleX.abs();
    final sy = widget.shape.scaleY.abs();
    _visualScaleEstimate = math.max(math.max(sx, sy), 0.001);
    _brushColor = widget.shape.strokeColor;

    final longest = math.max(_drawBounds.width, _drawBounds.height);
    _workingRasterScale = _computeAdaptiveScale(
      longestSide: longest,
      maxDimension: 4096,
      baseScale: 2.0,
      minScale: 1.0,
      maxScale: 4.0,
    );
    _workingPixelWidth = math.max(
      (_drawBounds.width * _workingRasterScale).ceil(),
      1,
    );
    _workingPixelHeight = math.max(
      (_drawBounds.height * _workingRasterScale).ceil(),
      1,
    );

    _recomposePreviewRaster();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetInteractionState(repaint: false);
    _compositedImage?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _resetInteractionState(repaint: true);
    }
  }

  @override
  void deactivate() {
    _resetInteractionState(repaint: false);
    super.deactivate();
  }

  Rect _resolveShapeBounds(Shape shape, Path displayPath) {
    final pathBounds = displayPath.getBounds();
    Rect rawBounds = pathBounds;
    if (_isInvalidBounds(rawBounds)) {
      rawBounds = shape.localBounds ?? const Rect.fromLTWH(0, 0, 160, 100);
    }
    if (_isInvalidBounds(rawBounds)) {
      rawBounds = const Rect.fromLTWH(0, 0, 160, 100);
    }
    return Rect.fromCenter(
      center: rawBounds.center,
      width: math.max(rawBounds.width, 1.0),
      height: math.max(rawBounds.height, 1.0),
    );
  }

  bool _isInvalidBounds(Rect bounds) {
    return !bounds.width.isFinite ||
        !bounds.height.isFinite ||
        bounds.width <= 0 ||
        bounds.height <= 0;
  }

  Matrix4 _buildVisualMatrix(Shape shape, Rect bounds) {
    double sx = shape.scaleX * (shape.isFlippedH ? -1.0 : 1.0);
    double sy = shape.scaleY * (shape.isFlippedV ? -1.0 : 1.0);
    if (sx.abs() < 0.001) {
      sx = sx.isNegative ? -0.001 : 0.001;
    }
    if (sy.abs() < 0.001) {
      sy = sy.isNegative ? -0.001 : 0.001;
    }
    final pivotWorld = bounds.center + shape.transform.pivot;
    return Matrix4.identity()
      ..translateByDouble(pivotWorld.dx, pivotWorld.dy, 0.0, 1.0)
      ..rotateZ(shape.rotation)
      ..scaleByDouble(sx, sy, 1.0, 1.0)
      ..translateByDouble(-pivotWorld.dx, -pivotWorld.dy, 0.0, 1.0);
  }

  double _computeAdaptiveScale({
    required double longestSide,
    required int maxDimension,
    required double baseScale,
    required double minScale,
    required double maxScale,
  }) {
    if (longestSide <= 0) return 1.0;
    var scale = baseScale;
    if (longestSide * scale > maxDimension) {
      scale = maxDimension / longestSide;
    }
    return scale.clamp(minScale, maxScale);
  }

  Offset _transformPoint(Matrix4 matrix, Offset point) {
    return MatrixUtils.transformPoint(matrix, point);
  }

  Offset _viewToLocal(
    Offset viewPoint,
    Size viewportSize,
    _LocalPreviewTransform fit,
  ) {
    final center = Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);
    final unpanned = viewPoint - _viewportPan;
    final unzoomed = ((unpanned - center) / _viewportScale) + center;
    final preFit = Offset(
      (unzoomed.dx - fit.offset.dx) / fit.scale,
      (unzoomed.dy - fit.offset.dy) / fit.scale,
    );
    return _transformPoint(_inverseVisualMatrix, preFit);
  }

  double _screenWidthToLocal(double widthScreen, _LocalPreviewTransform fit) {
    final effectiveScale = fit.scale * _viewportScale * _visualScaleEstimate;
    return widthScreen / math.max(effectiveScale, 0.001);
  }

  double _pressureFromEvent(PointerEvent event) {
    return normalizeRasterPressure(
      kind: event.kind,
      pressure: event.pressure,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
    );
  }

  void _resetView() {
    setState(() {
      _viewportScale = 1.0;
      _viewportPan = Offset.zero;
    });
  }

  void _handlePointerDown(
    PointerDownEvent event,
    Size viewportSize,
    _LocalPreviewTransform fit,
  ) {
    if (_activePointers.isNotEmpty &&
        _drawingPointerId == null &&
        !_isNavigating) {
      _resetInteractionState(repaint: false);
    }
    _activePointers[event.pointer] = _PointerSample(
      position: event.localPosition,
      pressure: _pressureFromEvent(event),
    );

    if (_activePointers.length == 1) {
      _startStroke(
        pointerId: event.pointer,
        viewPoint: event.localPosition,
        pressure: _pressureFromEvent(event),
        viewportSize: viewportSize,
        fit: fit,
      );
      return;
    }

    if (_activePointers.length == 2) {
      _commitOrDiscardActiveStrokeForGesture();
      _beginNavigationGesture();
    }
  }

  void _handlePointerMove(
    PointerMoveEvent event,
    Size viewportSize,
    _LocalPreviewTransform fit,
  ) {
    final sample = _activePointers[event.pointer];
    if (sample == null) return;
    _activePointers[event.pointer] = sample.copyWith(
      position: event.localPosition,
      pressure: _pressureFromEvent(event),
    );

    if (_activePointers.length >= 2) {
      if (!_isNavigating) {
        _beginNavigationGesture();
      } else {
        _updateNavigationGesture();
      }
      return;
    }

    if (_isNavigating && _activePointers.length < 2) {
      _endNavigationGesture();
      return;
    }

    if (_drawingPointerId != event.pointer) return;
    final stroke = _activeStroke;
    if (stroke == null) return;

    final localPoint = _viewToLocal(event.localPosition, viewportSize, fit);
    final pressure = _pressureFromEvent(event);
    final lastPoint = stroke.points.last.position;
    if ((localPoint - lastPoint).distance < _minPointDistanceLocal) {
      return;
    }

    setState(() {
      _activeStroke = stroke.copyWith(
        points: <_RasterPoint>[
          ...stroke.points,
          _RasterPoint(position: localPoint, pressure: pressure),
        ],
      );
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_drawingPointerId == event.pointer) {
      _commitActiveStroke();
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isNavigating) {
      _endNavigationGesture();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_drawingPointerId == event.pointer) {
      setState(_dropActiveStroke);
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isNavigating) {
      _endNavigationGesture();
    }
  }

  void _startStroke({
    required int pointerId,
    required Offset viewPoint,
    required double pressure,
    required Size viewportSize,
    required _LocalPreviewTransform fit,
  }) {
    if (_isNavigating || _activePointers.length != 1) return;

    final localPoint = _viewToLocal(viewPoint, viewportSize, fit);
    final widthLocal = _screenWidthToLocal(_currentToolWidth, fit);
    final isEraser = _activeTool == _PaintTool.eraser;

    setState(() {
      _drawingPointerId = pointerId;
      _activeStroke = _ActiveStroke(
        points: <_RasterPoint>[
          _RasterPoint(position: localPoint, pressure: pressure),
        ],
        color: isEraser ? Colors.transparent : _brushColor,
        baseWidthLocal: widthLocal,
        isEraser: isEraser,
      );
    });
  }

  void _dropActiveStroke() {
    if (_activeStroke == null && _drawingPointerId == null) return;
    _activeStroke = null;
    _drawingPointerId = null;
  }

  void _resetInteractionState({required bool repaint}) {
    void clearState() {
      _activePointers.clear();
      _dropActiveStroke();
      _isNavigating = false;
      _gestureStartScale = _viewportScale;
      _gestureStartPan = _viewportPan;
      _gestureStartCenter = Offset.zero;
      _gestureStartDistance = 1.0;
    }

    if (repaint && mounted) {
      setState(clearState);
      return;
    }
    clearState();
  }

  void _beginNavigationGesture() {
    final pair = _firstTwoPointerPositions();
    if (pair == null) return;
    setState(() {
      _isNavigating = true;
      _drawingPointerId = null;
      _gestureStartScale = _viewportScale;
      _gestureStartPan = _viewportPan;
      _gestureStartCenter = (pair.$1 + pair.$2) * 0.5;
      _gestureStartDistance = math.max((pair.$1 - pair.$2).distance, 1.0);
    });
  }

  void _updateNavigationGesture() {
    final pair = _firstTwoPointerPositions();
    if (pair == null) return;
    final currentCenter = (pair.$1 + pair.$2) * 0.5;
    final currentDistance = math.max((pair.$1 - pair.$2).distance, 1.0);
    final ratio = currentDistance / _gestureStartDistance;
    final nextScale = (_gestureStartScale * ratio).clamp(
      _minViewportScale,
      _maxViewportScale,
    );
    final centerDelta = currentCenter - _gestureStartCenter;

    setState(() {
      _viewportScale = nextScale;
      _viewportPan = _gestureStartPan + centerDelta;
    });
  }

  void _endNavigationGesture() {
    setState(() {
      _isNavigating = false;
    });
  }

  (Offset, Offset)? _firstTwoPointerPositions() {
    if (_activePointers.length < 2) return null;
    final values = _activePointers.values.take(2).toList(growable: false);
    return (values[0].position, values[1].position);
  }

  _RasterStrokeOp? _takeActiveStrokeAsOperation() {
    final stroke = _activeStroke;
    if (stroke == null || stroke.points.isEmpty) return null;
    _activeStroke = null;
    _drawingPointerId = null;
    return _RasterStrokeOp(
      points: List<_RasterPoint>.unmodifiable(stroke.points),
      color: stroke.color,
      baseWidthLocal: stroke.baseWidthLocal,
      isEraser: stroke.isEraser,
    );
  }

  void _commitActiveStroke() {
    final op = _takeActiveStrokeAsOperation();
    if (op == null) return;
    _pushOperation(op);
  }

  void _commitOrDiscardActiveStrokeForGesture() {
    final stroke = _activeStroke;
    if (stroke == null) return;

    // If the first touch has not actually moved, treat it as gesture setup
    // and avoid leaving a dot when pinch-zoom starts.
    if (stroke.points.length <= 1) {
      setState(_dropActiveStroke);
      return;
    }

    var length = 0.0;
    for (var i = 1; i < stroke.points.length; i++) {
      length +=
          (stroke.points[i].position - stroke.points[i - 1].position).distance;
    }
    if (length < _minPointDistanceLocal * 2.0) {
      setState(_dropActiveStroke);
      return;
    }

    _commitActiveStroke();
  }

  void _pushOperation(_RasterOp operation) {
    setState(() {
      _history.push(operation);
    });
    _recomposePreviewRaster();
  }

  void _undo() {
    if (!_history.canUndo) return;
    setState(() {
      _history.undo();
      _dropActiveStroke();
    });
    _recomposePreviewRaster();
  }

  void _redo() {
    if (!_history.canRedo) return;
    setState(() {
      _history.redo();
      _dropActiveStroke();
    });
    _recomposePreviewRaster();
  }

  void _clearAll() {
    if (!_hasAnyCommittedContent && _activeStroke == null) return;
    setState(() {
      _dropActiveStroke();
      _history.push(const _RasterClearOp());
    });
    _recomposePreviewRaster();
  }

  void _applyClip(_ClipOpType type) {
    if (!_hasAnyCommittedContent) return;
    if (type == _ClipOpType.insideFill && !_canClipInsideFill) return;
    final pendingStroke = _takeActiveStrokeAsOperation();
    setState(() {
      if (pendingStroke != null) {
        _history.push(pendingStroke);
      }
      _history.push(_RasterClipOp(type: type));
    });
    _recomposePreviewRaster();
  }

  Future<void> _pickBrushColorAdvanced() async {
    _commitOrDiscardActiveStrokeForGesture();
    _resetInteractionState(repaint: true);
    final picked = await showAdaptiveColorPicker(
      context: context,
      initialColor: _brushColor,
      recentColors: widget.recentColors,
    );
    if (!mounted || picked == null) return;
    setState(() => _brushColor = picked);
    widget.onColorUsed?.call(picked);
  }

  List<Color> _suggestedBrushColors() {
    final keys = <int>{};
    final colors = <Color>[];

    void addColor(Color? color) {
      if (color == null) return;
      final key = color.toARGB32();
      if (Color(key).a == 0.0) return;
      if (keys.add(key)) {
        colors.add(Color(key));
      }
    }

    addColor(_brushColor);
    addColor(widget.shape.strokeColor);
    addColor(widget.shape.fillColor);

    for (final operation in _history.appliedOperations) {
      if (operation is _RasterStrokeOp && !operation.isEraser) {
        addColor(operation.color);
      }
    }

    const fallback = <Color>[
      Colors.black,
      Colors.white,
      Colors.red,
      Colors.green,
      Colors.blue,
    ];
    for (final color in fallback) {
      addColor(color);
      if (colors.length >= 5) break;
    }

    if (colors.length > 5) {
      return colors.take(5).toList(growable: false);
    }
    return colors;
  }

  Future<void> _saveAndClose() async {
    if (_isSaving) return;

    final pendingStroke = _takeActiveStrokeAsOperation();
    setState(() {
      _isSaving = true;
      if (pendingStroke != null) {
        _history.push(pendingStroke);
      }
    });

    try {
      final pngBytes = await _renderRasterPng();
      if (!mounted) return;
      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save shape paint.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      Navigator.of(context).pop(pngBytes);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _recomposePreviewRaster() async {
    final requestId = ++_composeRequestId;
    final operations = _history.appliedOperations;
    final image = await _composeRasterImage(
      operations: operations,
      pixelWidth: _workingPixelWidth,
      pixelHeight: _workingPixelHeight,
      rasterScale: _workingRasterScale,
    );
    if (!mounted || requestId != _composeRequestId) {
      image?.dispose();
      return;
    }

    final previous = _compositedImage;
    setState(() {
      _compositedImage = image;
    });
    previous?.dispose();
  }

  Future<Uint8List?> _renderRasterPng() async {
    final width = _drawBounds.width;
    final height = _drawBounds.height;
    if (width <= 0 || height <= 0) return null;

    final longestSide = math.max(width, height);
    final rasterScale = _computeAdaptiveScale(
      longestSide: longestSide,
      maxDimension: 4096,
      baseScale: 2.0,
      minScale: 1.0,
      maxScale: 4.0,
    );
    final pixelWidth = math.max((width * rasterScale).ceil(), 1);
    final pixelHeight = math.max((height * rasterScale).ceil(), 1);

    final image = await _composeRasterImage(
      operations: _history.appliedOperations,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      rasterScale: rasterScale,
    );
    if (image == null) return null;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<ui.Image?> _composeRasterImage({
    required List<_RasterOp> operations,
    required int pixelWidth,
    required int pixelHeight,
    required double rasterScale,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
    );

    canvas.scale(rasterScale, rasterScale);
    canvas.translate(-_drawBounds.left, -_drawBounds.top);
    canvas.saveLayer(_drawBounds, Paint());

    final existing = widget.existingRasterImage;
    if (existing != null) {
      canvas.drawImageRect(
        existing,
        Rect.fromLTWH(
          0,
          0,
          existing.width.toDouble(),
          existing.height.toDouble(),
        ),
        _drawBounds,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    for (final operation in operations) {
      if (operation is _RasterStrokeOp) {
        _drawRasterStroke(canvas, operation);
      } else if (operation is _RasterClipOp) {
        _applyClipMask(canvas, operation.type, rasterScale: rasterScale);
      } else if (operation is _RasterClearOp) {
        canvas.drawRect(
          _drawBounds,
          Paint()
            ..blendMode = BlendMode.clear
            ..isAntiAlias = false,
        );
      }
    }

    canvas.restore();
    final image = await recorder.endRecording().toImage(
      pixelWidth,
      pixelHeight,
    );
    return image;
  }

  void _drawRasterStroke(Canvas canvas, _RasterStrokeOp stroke) {
    if (stroke.points.isEmpty) return;
    if (stroke.isEraser) {
      _drawEraserStroke(canvas, stroke);
      return;
    }

    final path = _buildProBrushPath(
      stroke.points,
      baseWidthLocal: stroke.baseWidthLocal,
      isComplete: true,
    );
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (path != null) {
      canvas.drawPath(path, _proBrushRenderer.decoratePaint(paint));
      return;
    }

    final point = stroke.points.first.position;
    canvas.drawCircle(point, stroke.baseWidthLocal * 0.5, paint);
  }

  void _drawEraserStroke(Canvas canvas, _RasterStrokeOp stroke) {
    final erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.baseWidthLocal
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first.position,
        stroke.baseWidthLocal * 0.5,
        erasePaint,
      );
      return;
    }

    final path = _buildSmoothPath(
      stroke.points.map((p) => p.position).toList(growable: false),
    );
    canvas.drawPath(path, erasePaint);
  }

  Path? _buildProBrushPath(
    List<_RasterPoint> points, {
    required double baseWidthLocal,
    required bool isComplete,
  }) {
    if (points.isEmpty || baseWidthLocal <= 0) return null;
    final vectors = points
        .map(
          (p) => PointVector(
            p.position.dx,
            p.position.dy,
            p.pressure.clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
    final options = BrushStrokeOptions(
      size: baseWidthLocal,
      thinning: 0.7,
      smoothing: 0.55,
      streamline: 0.35,
      simulatePressure: false,
      isComplete: isComplete,
    );
    return _proBrushRenderer.buildPath(vectors, options);
  }

  void _applyClipMask(
    Canvas canvas,
    _ClipOpType type, {
    required double rasterScale,
  }) {
    canvas.saveLayer(_drawBounds, Paint()..blendMode = BlendMode.dstIn);
    final maskFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (type) {
      case _ClipOpType.onShape:
        canvas.drawPath(_shapeDisplayPath, maskFill);
        // Compensate one destination pixel to avoid tiny AA seams between
        // fill-mask and stroke-mask coverage at clip boundaries.
        final compensation = 1.0 / math.max(rasterScale, 1.0);
        final strokeMaskWidth = math.max(
          widget.shape.strokeWidth + compensation,
          compensation,
        );
        final maskStroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = strokeMaskWidth
          ..isAntiAlias = true;
        canvas.drawPath(_shapeDisplayPath, maskStroke);
        break;
      case _ClipOpType.insideFill:
        final fillPath = _shapeInsideFillPath;
        if (fillPath == null) {
          canvas.restore();
          return;
        }
        canvas.drawPath(fillPath, maskFill);
        // Keep only area fully inside the stroke boundary by eroding the fill
        // path with the current stroke width (removes the inner half of the
        // centered vector stroke band).
        if (widget.shape.strokeWidth > 0) {
          // Compensate one destination pixel to avoid a tiny antialias seam.
          final compensation = 1.0 / math.max(rasterScale, 1.0);
          final clearWidth = math.max(
            widget.shape.strokeWidth - compensation,
            0.0,
          );
          if (clearWidth <= 0.0) {
            canvas.restore();
            return;
          }
          canvas.drawPath(
            fillPath,
            Paint()
              ..blendMode = BlendMode.clear
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = clearWidth
              ..isAntiAlias = true,
          );
        }
        break;
    }
    canvas.restore();
  }

  Path _buildSmoothPath(List<Offset> points) {
    if (points.length < 2) {
      return Path()
        ..moveTo(points.first.dx, points.first.dy)
        ..lineTo(points.first.dx, points.first.dy);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final mid0 = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    path.lineTo(mid0.dx, mid0.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final next = points[i + 1];
      final mid = Offset((p.dx + next.dx) / 2, (p.dy + next.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;
    final canSave = !_isSaving;
    final isBrush = _activeTool == _PaintTool.brush;
    final isEraser = _activeTool == _PaintTool.eraser;
    final canUndo = _history.canUndo;
    final canRedo = _history.canRedo;
    final canClipOnShape = _hasAnyCommittedContent;
    final canClipInside = canClipOnShape && _canClipInsideFill;
    final canClear = _hasAnyCommittedContent || _activeStroke != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Paint Shape',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Undo',
                            onPressed: canUndo ? _undo : null,
                            icon: const Icon(Icons.undo, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Redo',
                            onPressed: canRedo ? _redo : null,
                            icon: const Icon(Icons.redo, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Reset View',
                            onPressed: _resetView,
                            icon: const Icon(
                              Icons.center_focus_strong,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Clear all',
                            onPressed: canClear ? _clearAll : null,
                            icon: const Icon(
                              Icons.layers_clear_outlined,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final fit = _LocalPreviewTransform.fit(
                          localBounds: _drawBounds,
                          viewportSize: viewportSize,
                          padding: _previewPadding,
                        );

                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _handlePointerDown(event, viewportSize, fit),
                          onPointerMove: (event) =>
                              _handlePointerMove(event, viewportSize, fit),
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: CustomPaint(
                            painter: _ShapeRasterPreviewPainter(
                              shape: widget.shape,
                              drawBounds: _drawBounds,
                              displayPath: _shapeDisplayPath,
                              fit: fit,
                              viewportScale: _viewportScale,
                              viewportPan: _viewportPan,
                              visualMatrix: _visualMatrix,
                              compositedImage: _compositedImage,
                              activeStroke: _activeStroke,
                              proBrushRenderer: _proBrushRenderer,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolToggle(
                      icon: Icons.brush,
                      label: 'Brush',
                      isActive: isBrush,
                      onPressed: () =>
                          setState(() => _activeTool = _PaintTool.brush),
                    ),
                    const SizedBox(width: 8),
                    _ToolToggle(
                      icon: Icons.auto_fix_high,
                      label: 'Eraser',
                      isActive: isEraser,
                      onPressed: () =>
                          setState(() => _activeTool = _PaintTool.eraser),
                    ),
                    const SizedBox(width: 12),
                    if (isBrush)
                      _ColorSwatchRow(
                        selectedColor: _brushColor,
                        colors: _suggestedBrushColors(),
                        onColorSelected: (c) {
                          setState(() => _brushColor = c);
                          widget.onColorUsed?.call(c);
                        },
                        onAdvancedPressed: _pickBrushColorAdvanced,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolToggle(
                      icon: Icons.crop,
                      label: 'Clip On Shape',
                      isActive: false,
                      isEnabled: canClipOnShape,
                      onPressed: () => _applyClip(_ClipOpType.onShape),
                    ),
                    const SizedBox(width: 8),
                    _ToolToggle(
                      icon: Icons.filter_center_focus,
                      label: 'Clip Inside Strokes',
                      isActive: false,
                      isEnabled: canClipInside,
                      onPressed: () => _applyClip(_ClipOpType.insideFill),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Text(
                    isBrush ? 'Size' : 'Eraser',
                    style: theme.textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Slider(
                      min: _minBrushWidth,
                      max: _maxBrushWidth,
                      value: _currentToolWidth,
                      onChanged: (value) {
                        setState(() => _currentToolWidth = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _currentToolWidth.toStringAsFixed(0),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: canSave ? _saveAndClose : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShapeRasterPreviewPainter extends CustomPainter {
  const _ShapeRasterPreviewPainter({
    required this.shape,
    required this.drawBounds,
    required this.displayPath,
    required this.fit,
    required this.viewportScale,
    required this.viewportPan,
    required this.visualMatrix,
    required this.compositedImage,
    required this.activeStroke,
    required this.proBrushRenderer,
  });

  final Shape shape;
  final Rect drawBounds;
  final Path displayPath;
  final _LocalPreviewTransform fit;
  final double viewportScale;
  final Offset viewportPan;
  final Matrix4 visualMatrix;
  final ui.Image? compositedImage;
  final _ActiveStroke? activeStroke;
  final BrushRenderer proBrushRenderer;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF2F4F7);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final viewCenter = Offset(size.width * 0.5, size.height * 0.5);
    canvas.save();
    canvas.translate(viewportPan.dx, viewportPan.dy);
    canvas.translate(viewCenter.dx, viewCenter.dy);
    canvas.scale(viewportScale);
    canvas.translate(-viewCenter.dx, -viewCenter.dy);
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);
    canvas.transform(visualMatrix.storage);

    final strokeUnit = 1 / math.max(fit.scale * viewportScale, 0.001);
    final areaPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeUnit;
    canvas.drawRect(drawBounds, areaPaint);

    final opacity = shape.opacity.clamp(0.0, 1.0);
    final fillColor = shape.fillColor?.withValues(
      alpha: (shape.fillColor!.a * opacity).clamp(0.0, 1.0),
    );
    if (fillColor != null) {
      canvas.drawPath(
        displayPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    final strokeColor = shape.strokeColor.withValues(
      alpha: (shape.strokeColor.a * opacity).clamp(0.0, 1.0),
    );
    canvas.drawPath(
      displayPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(shape.strokeWidth, strokeUnit)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    final composed = compositedImage;
    if (composed != null) {
      canvas.drawImageRect(
        composed,
        Rect.fromLTWH(
          0,
          0,
          composed.width.toDouble(),
          composed.height.toDouble(),
        ),
        drawBounds,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final active = activeStroke;
    if (active != null && active.points.isNotEmpty) {
      if (active.isEraser) {
        final erasePreview = Paint()
          ..color = const Color(0x6690A4AE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active.baseWidthLocal
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true;
        if (active.points.length == 1) {
          canvas.drawCircle(
            active.points.first.position,
            active.baseWidthLocal * 0.5,
            erasePreview,
          );
        } else {
          final path = _buildSmoothPath(
            active.points.map((p) => p.position).toList(growable: false),
          );
          canvas.drawPath(path, erasePreview);
        }
      } else {
        final path = _buildBrushPreviewPath(active);
        if (path != null) {
          canvas.drawPath(
            path,
            proBrushRenderer.decoratePaint(
              Paint()
                ..color = active.color
                ..style = PaintingStyle.fill
                ..isAntiAlias = true,
            ),
          );
        } else {
          canvas.drawCircle(
            active.points.first.position,
            active.baseWidthLocal * 0.5,
            Paint()
              ..color = active.color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        }
      }
    }

    canvas.restore();
  }

  Path? _buildBrushPreviewPath(_ActiveStroke active) {
    final vectors = active.points
        .map(
          (p) => PointVector(
            p.position.dx,
            p.position.dy,
            p.pressure.clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
    final options = BrushStrokeOptions(
      size: active.baseWidthLocal,
      thinning: 0.7,
      smoothing: 0.55,
      streamline: 0.35,
      simulatePressure: false,
      isComplete: false,
    );
    return proBrushRenderer.buildPath(vectors, options);
  }

  Path _buildSmoothPath(List<Offset> points) {
    if (points.length < 2) {
      return Path()
        ..moveTo(points.first.dx, points.first.dy)
        ..lineTo(points.first.dx, points.first.dy);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final mid0 = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    path.lineTo(mid0.dx, mid0.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final next = points[i + 1];
      final mid = Offset((p.dx + next.dx) / 2, (p.dy + next.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _ShapeRasterPreviewPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.drawBounds != drawBounds ||
        oldDelegate.fit != fit ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.viewportPan != viewportPan ||
        oldDelegate.visualMatrix != visualMatrix ||
        oldDelegate.compositedImage != compositedImage ||
        oldDelegate.activeStroke != activeStroke;
  }
}

class _ShapeRasterPathBuilder {
  static Path buildDisplayPath(Shape shape) {
    final bounds = shape.localBounds ?? const Rect.fromLTWH(0, 0, 160, 100);
    switch (shape.kind) {
      case ShapeKind.rectangle:
        return Path()..addRect(shape.bounds ?? bounds);
      case ShapeKind.ellipse:
        return Path()..addOval(shape.bounds ?? bounds);
      case ShapeKind.polygon:
        if (shape.hasBezierCurves && shape.bezierPoints != null) {
          final path = _buildBezierPath(shape.bezierPoints!, shape.isClosed);
          if (path != null) return path;
        }
        if (shape.contours.isNotEmpty) {
          final path = Path();
          for (final contour in shape.contours) {
            if (contour.length >= 2) {
              path.addPolygon(contour, true);
            }
          }
          if (shape.contours.length > 1) {
            path.fillType = PathFillType.evenOdd;
          }
          if (path.computeMetrics().isNotEmpty) return path;
        }
        if (shape.points.length >= 2) {
          return Path()..addPolygon(shape.points, true);
        }
        return Path()..addRect(bounds);
      case ShapeKind.pointPath:
        if (shape.hasBezierCurves && shape.bezierPoints != null) {
          final path = _buildBezierPath(shape.bezierPoints!, shape.isClosed);
          if (path != null) return path;
        }
        if (shape.points.length >= 2) {
          final path = Path()
            ..moveTo(shape.points.first.dx, shape.points.first.dy);
          for (var i = 1; i < shape.points.length; i++) {
            path.lineTo(shape.points[i].dx, shape.points[i].dy);
          }
          if (shape.isClosed && shape.points.length > 2) {
            path.close();
          }
          return path;
        }
        return Path()..addRect(bounds);
      case ShapeKind.freehand:
        if (shape.points.length >= 2) {
          final path = Path()
            ..moveTo(shape.points.first.dx, shape.points.first.dy);
          for (var i = 1; i < shape.points.length; i++) {
            path.lineTo(shape.points[i].dx, shape.points[i].dy);
          }
          return path;
        }
        return Path()..addRect(bounds);
      case ShapeKind.line:
        if (shape.points.length >= 2) {
          final path = Path()
            ..moveTo(shape.points.first.dx, shape.points.first.dy);
          for (var i = 1; i < shape.points.length; i++) {
            path.lineTo(shape.points[i].dx, shape.points[i].dy);
          }
          return path;
        }
        return Path()..addRect(bounds);
      case ShapeKind.image:
        return Path()..addRect(shape.bounds ?? bounds);
    }
  }

  static Path? buildInsideFillPath(Shape shape, Rect fallbackBounds) {
    final bounds = shape.bounds ?? fallbackBounds;
    switch (shape.kind) {
      case ShapeKind.rectangle:
        return Path()..addRect(bounds);
      case ShapeKind.ellipse:
        return Path()..addOval(bounds);
      case ShapeKind.polygon:
        if (shape.hasBezierCurves && shape.bezierPoints != null) {
          return _buildBezierPath(shape.bezierPoints!, true);
        }
        if (shape.contours.isNotEmpty) {
          final path = Path();
          for (final contour in shape.contours) {
            if (contour.length >= 3) {
              path.addPolygon(contour, true);
            }
          }
          if (shape.contours.length > 1) {
            path.fillType = PathFillType.evenOdd;
          }
          return path.computeMetrics().isNotEmpty ? path : null;
        }
        if (shape.points.length >= 3) {
          return Path()..addPolygon(shape.points, true);
        }
        return null;
      case ShapeKind.pointPath:
        if (!shape.isClosed || shape.points.length < 3) return null;
        if (shape.hasBezierCurves && shape.bezierPoints != null) {
          return _buildBezierPath(shape.bezierPoints!, true);
        }
        return Path()..addPolygon(shape.points, true);
      case ShapeKind.freehand:
        if (!FillUtils.isFreehandClosed(shape) || shape.points.length < 3) {
          return null;
        }
        return Path()..addPolygon(shape.points, true);
      case ShapeKind.line:
      case ShapeKind.image:
        return null;
    }
  }

  static Path? _buildBezierPath(List<BezierPoint> points, bool close) {
    if (points.length < 2) return null;
    final path = Path();
    path.moveTo(points.first.position.dx, points.first.position.dy);
    for (var i = 0; i < points.length; i++) {
      final nextIndex = (i + 1) % points.length;
      if (!close && nextIndex == 0) break;
      final current = points[i];
      final next = points[nextIndex];
      final p1 = current.controlOutAbsolute;
      final p2 = next.controlInAbsolute;
      final p3 = next.position;
      path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    }
    if (close) {
      path.close();
    }
    return path;
  }
}

abstract class _RasterOp {
  const _RasterOp();
}

class _RasterStrokeOp extends _RasterOp {
  const _RasterStrokeOp({
    required this.points,
    required this.color,
    required this.baseWidthLocal,
    required this.isEraser,
  });

  final List<_RasterPoint> points;
  final Color color;
  final double baseWidthLocal;
  final bool isEraser;
}

class _RasterClipOp extends _RasterOp {
  const _RasterClipOp({required this.type});

  final _ClipOpType type;
}

class _RasterClearOp extends _RasterOp {
  const _RasterClearOp();
}

class _RasterPoint {
  const _RasterPoint({required this.position, required this.pressure});

  final Offset position;
  final double pressure;
}

class _ActiveStroke {
  const _ActiveStroke({
    required this.points,
    required this.color,
    required this.baseWidthLocal,
    required this.isEraser,
  });

  final List<_RasterPoint> points;
  final Color color;
  final double baseWidthLocal;
  final bool isEraser;

  _ActiveStroke copyWith({
    List<_RasterPoint>? points,
    Color? color,
    double? baseWidthLocal,
    bool? isEraser,
  }) {
    return _ActiveStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      baseWidthLocal: baseWidthLocal ?? this.baseWidthLocal,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}

class _PointerSample {
  const _PointerSample({required this.position, required this.pressure});

  final Offset position;
  final double pressure;

  _PointerSample copyWith({Offset? position, double? pressure}) {
    return _PointerSample(
      position: position ?? this.position,
      pressure: pressure ?? this.pressure,
    );
  }
}

class _LocalPreviewTransform {
  const _LocalPreviewTransform({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  factory _LocalPreviewTransform.fit({
    required Rect localBounds,
    required Size viewportSize,
    required double padding,
  }) {
    final safeWidth = math.max(localBounds.width, 1);
    final safeHeight = math.max(localBounds.height, 1);
    final availW = math.max(viewportSize.width - padding * 2, 1);
    final availH = math.max(viewportSize.height - padding * 2, 1);
    final scale = math
        .min(availW / safeWidth, availH / safeHeight)
        .clamp(0.001, 1000.0);
    final contentWidth = safeWidth * scale;
    final contentHeight = safeHeight * scale;
    final dx =
        (viewportSize.width - contentWidth) / 2 - localBounds.left * scale;
    final dy =
        (viewportSize.height - contentHeight) / 2 - localBounds.top * scale;
    return _LocalPreviewTransform(scale: scale, offset: Offset(dx, dy));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _LocalPreviewTransform &&
        other.scale == scale &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(scale, offset);
}

class _ToolToggle extends StatelessWidget {
  const _ToolToggle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.isEnabled = true,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final fgColor = isActive
        ? theme.colorScheme.onPrimaryContainer
        : isEnabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : theme.disabledColor;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.55,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isEnabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: fgColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
    required this.onAdvancedPressed,
  });

  final Color selectedColor;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onAdvancedPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAdvancedPressed,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(Icons.palette_outlined, size: 16),
              ),
            ),
          ),
        ),
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == color
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: selectedColor == color ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
