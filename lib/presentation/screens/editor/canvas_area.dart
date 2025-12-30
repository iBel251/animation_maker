import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:animation_maker/domain/models/shape.dart';

import 'canvas_painter.dart';
import 'editor_view_model.dart';
import 'shape_transformer.dart';

class CanvasArea extends ConsumerStatefulWidget {
  const CanvasArea({super.key});

  @override
  ConsumerState<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends ConsumerState<CanvasArea> {
  static const Size _designSize = Size(1920, 1080);
  final TransformationController _controller = TransformationController();
  double _lastMaxW = 0;
  double _lastMaxH = 0;
  double _baseScale = 1.0;
  double _currentScale = 1.0;
  int _pointerCount = 0;
  int? _activePointer;
  bool _multiTouchInProgress = false;
  bool _initializedTransform = false;
  _TransformHandle? _activeHandle;
  double _handleStartScale = 1.0;
  double _handleStartRotation = 0.0;
  Offset? _handleCenter;
  double _handleStartDistance = 0.0;
  double _handleStartAngle = 0.0;
  double _handleLastAngle = 0.0;
  Rect? _handleBaseBounds;
  List<Offset>? _handleBasePoints;
  String? _handleShapeId;

  static const double _minScale = 0.25;
  static const double _maxScale = 8.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    setState(() {
      _currentScale = _controller.value.getMaxScaleOnAxis();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shapes = ref.watch(editorViewModelProvider.select((s) => s.shapes));
    final selectedShapeId =
        ref.watch(editorViewModelProvider.select((s) => s.selectedShapeId));
    final activeTool =
        ref.watch(editorViewModelProvider.select((s) => s.activeTool));
    final isPanMode =
        ref.watch(editorViewModelProvider.select((s) => s.isPanMode));
    final inProgressStroke =
        ref.watch(editorViewModelProvider.select((s) => s.inProgressStroke));
    final brushThickness =
        ref.watch(editorViewModelProvider.select((s) => s.brushThickness));
    final brushOpacity =
        ref.watch(editorViewModelProvider.select((s) => s.brushOpacity));
    final brushSmoothness =
        ref.watch(editorViewModelProvider.select((s) => s.brushSmoothness));
    final brushColor =
        ref.watch(editorViewModelProvider.select((s) => s.currentColor));
    final brushType =
        ref.watch(editorViewModelProvider.select((s) => s.currentBrush));
    final palmRejectionEnabled =
        ref.watch(editorViewModelProvider.select((s) => s.palmRejectionEnabled));
    final ui.Image? raster =
        ref.watch(editorViewModelProvider.select((s) => s.rasterLayer));
    final vm = ref.read(editorViewModelProvider.notifier);
    final selectedShape = _findShape(shapes, selectedShapeId);

    // Keep raster resolution fixed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => vm.updateCanvasSize(_designSize),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final scale = _computeScale(maxW, maxH, _designSize);
        final offset = Offset(
          (maxW - _designSize.width * scale) / 2,
          (maxH - _designSize.height * scale) / 2,
        );

        if (!_initializedTransform ||
            maxW != _lastMaxW ||
            maxH != _lastMaxH) {
          _controller.value = Matrix4.identity()
            ..translate(offset.dx, offset.dy)
            ..scale(scale);
          _lastMaxW = maxW;
          _lastMaxH = maxH;
          _baseScale = scale;
          _currentScale = scale;
          _initializedTransform = true;
        } else {
          _currentScale = _controller.value.getMaxScaleOnAxis();
        }

        Offset _toCanvas(Offset local) => _controller.toScene(local);

        final painter = CustomPaint(
          painter: CanvasPainter(
            shapes: shapes,
            selectedShapeId: selectedShapeId,
            rasterLayer: raster,
            inProgressStroke: inProgressStroke,
            brushThickness: brushThickness,
            brushOpacity: brushOpacity,
            brushSmoothness: brushSmoothness,
            brushColor: brushColor,
            brushType: brushType,
            showSelectionHandles:
                activeTool == EditorTool.select && selectedShapeId != null,
            viewportScale: _currentScale,
          ),
          child: const SizedBox.expand(),
        );

        final canvasSurface = SizedBox(
          width: _designSize.width,
          height: _designSize.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRect(
              child: RepaintBoundary(child: painter),
            ),
          ),
        );

        final navActive = isPanMode;

        // InteractiveViewer handles pinch-zoom (always enabled) and single-finger pan only in pan mode.
        final viewer = InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          panEnabled: navActive,
          scaleEnabled: true, // allow two-finger pan/zoom even when drawing
          minScale: _baseScale,
          maxScale: _baseScale * 8,
          boundaryMargin: const EdgeInsets.all(2000),
          child: canvasSurface,
        );

        void handlePointerDown(PointerDownEvent event) {
          // Brush-only palm rejection: skip starting strokes with touch when enabled.
          if (activeTool == EditorTool.brush &&
              palmRejectionEnabled &&
              event.kind == PointerDeviceKind.touch) {
            return;
          }

          _pointerCount += 1;

          // Ignore drawing while multiple pointers are down; end active stroke/shape once.
          if (_pointerCount >= 2) {
            if (!_multiTouchInProgress) {
              _multiTouchInProgress = true;
              if (activeTool == EditorTool.brush) {
                vm.cancelDrawing();
              } else if (activeTool == EditorTool.shape) {
                vm.cancelShapeDrawing();
              }
              _activePointer = null;
            }
            return;
          }

          if (activeTool == EditorTool.brush &&
              palmRejectionEnabled &&
              _isRejectedPalm(event)) {
            // Skip starting a stroke with a palm/finger touch.
            return;
          }

          if (navActive) return;

          final pos = _toCanvas(event.localPosition);

          if (activeTool == EditorTool.select && selectedShape != null) {
            final hit = _hitTestHandle(selectedShape!, pos, _currentScale);
            if (hit != null) {
              _activeHandle = hit.type;
              _handleCenter = hit.center;
              _handleStartScale = selectedShape!.scale;
              _handleStartRotation = selectedShape!.rotation;
              _handleStartDistance = hit.startDistance;
              _handleStartAngle = hit.startAngle;
              _handleLastAngle = hit.startAngle;
              _handleBaseBounds = selectedShape!.bounds ?? _boundsFromPoints(selectedShape!.points);
              _handleBasePoints = selectedShape!.points.toList();
              _handleShapeId = selectedShape!.id;
              _activePointer = event.pointer;
              return;
            }
          }

          _activePointer = event.pointer;
          switch (activeTool) {
            case EditorTool.brush:
              vm.startDrawing(pos);
              break;
            case EditorTool.shape:
              vm.startShapeDrawing(pos);
              break;
            case EditorTool.select:
              vm.selectAtPoint(pos);
              break;
          }
        }

        void handlePointerMove(PointerMoveEvent event) {
          if (_multiTouchInProgress || _pointerCount >= 2) return;
          final navNow = isPanMode;
          if (navNow) return;

          final pos = _toCanvas(event.localPosition);

          if (_activeHandle != null &&
              _handleCenter != null &&
              _activePointer == event.pointer) {
            final currentState = ref.read(editorViewModelProvider);
            final currentShape =
                _findShape(currentState.shapes, currentState.selectedShapeId);
            if (currentShape == null) return;
            switch (_activeHandle!) {
              case _TransformHandle.scaleUniform:
                final dist = (pos - _handleCenter!).distance;
                if (dist > 0.001 && _handleStartDistance > 0.001) {
                  final factor = dist / _handleStartDistance;
                  vm.updateSelectedTransform(scale: _handleStartScale * factor);
                }
                break;
              case _TransformHandle.scaleX:
              case _TransformHandle.scaleY:
                if (_handleBaseBounds == null && _handleBasePoints == null) {
                  break;
                }
                final axis = hitAxisForHandle(_activeHandle!, currentShape);
                if (axis == null) break;
                final rel = (pos - _handleCenter!);
                final proj = rel.dx * axis.dx + rel.dy * axis.dy;
                if (_handleStartDistance.abs() > 0.001) {
                  final factor =
                      (proj.abs() / _handleStartDistance).clamp(0.05, 100.0);
                  final scaleX = _activeHandle == _TransformHandle.scaleX ? factor : 1.0;
                  final scaleY = _activeHandle == _TransformHandle.scaleY ? factor : 1.0;
                  vm.scaleSelectedGeometry(
                    baseBounds: _handleBaseBounds,
                    basePoints: _handleBasePoints,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    shapeId: _handleShapeId,
                  );
                }
                break;
              case _TransformHandle.rotate:
                final angle = math.atan2(
                  pos.dy - _handleCenter!.dy,
                  pos.dx - _handleCenter!.dx,
                );
                final delta = _normalizeAngle(angle - _handleLastAngle);
                vm.updateSelectedTransform(
                  rotation: currentShape.rotation + delta,
                );
                _handleLastAngle = angle;
                break;
            }
            return;
          }

          if (_activePointer != event.pointer) return;
          switch (activeTool) {
            case EditorTool.brush:
              vm.continueDrawing(pos);
              break;
            case EditorTool.shape:
              vm.updateShapeDrawing(pos);
              break;
            case EditorTool.select:
              vm.moveSelectedBy(event.delta / _currentScale);
              break;
          }
        }

        void handlePointerUp(PointerUpEvent event) {
          if (_pointerCount > 0) _pointerCount -= 1;
          final isLast = _pointerCount == 0;
          final navNow = isPanMode;

          if (_pointerCount < 2) {
            _multiTouchInProgress = false;
          }

          if (_activeHandle != null && _handleCenter != null) {
            vm.rebuildQuadTree();
            vm.finalizeSelectionEdit();
            _activeHandle = null;
            _handleCenter = null;
            _handleBaseBounds = null;
            _handleBasePoints = null;
            _handleShapeId = null;
            _activePointer = null;
            return;
          }

          if (navNow) {
            return;
          }

          if (_activePointer != event.pointer) {
            if (isLast) _activePointer = null;
            return;
          }

          switch (activeTool) {
            case EditorTool.brush:
              vm.endDrawing();
              break;
            case EditorTool.shape:
              vm.finishShapeDrawing();
              break;
            case EditorTool.select:
              vm.rebuildQuadTree();
              vm.finalizeSelectionEdit();
              break;
          }
          _activePointer = null;
        }

        void handlePointerCancel(PointerCancelEvent event) {
          if (_pointerCount > 0) _pointerCount -= 1;
          final isLast = _pointerCount == 0;
          final navNow = isPanMode;

          if (_pointerCount < 2) {
            _multiTouchInProgress = false;
          }

          if (_activeHandle != null && _handleCenter != null) {
            _activeHandle = null;
            _handleCenter = null;
            _handleBaseBounds = null;
            _handleBasePoints = null;
            _handleShapeId = null;
            _activePointer = null;
            return;
          }

          if (navNow) {
            _activePointer = null;
            return;
          }

          if (_activePointer != event.pointer) {
            if (isLast) _activePointer = null;
            return;
          }
          switch (activeTool) {
            case EditorTool.brush:
              vm.endDrawing();
              break;
            case EditorTool.shape:
              vm.finishShapeDrawing();
              break;
            case EditorTool.select:
              break;
          }
          _activePointer = null;
        }

        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: handlePointerDown,
              onPointerMove: handlePointerMove,
              onPointerUp: handlePointerUp,
              onPointerCancel: handlePointerCancel,
              child: viewer,
            ),
          ),
        );
      },
    );
  }

  double _computeScale(double maxW, double maxH, Size design) {
    if (maxW <= 0 || maxH <= 0) return 1.0;
    final scaleX = maxW / design.width;
    final scaleY = maxH / design.height;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  bool _isRejectedPalm(PointerDownEvent event) {
    // Allow stylus/mouse unconditionally.
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.mouse) {
      return false;
    }
    // For touch: reject if contact area is large (likely palm/heel).
    final major = event.radiusMajor;
    final minor = event.radiusMinor;
    const double palmThreshold = 24.0; // logical pixels radius
    if (major != null && major > palmThreshold) return true;
    if (minor != null && minor > palmThreshold) return true;
    return false;
  }

  Shape? _findShape(List<Shape> shapes, String? id) {
    if (id == null) return null;
    for (final s in shapes) {
      if (s.id == id) return s;
    }
    return null;
  }

  _HandleHit? _hitTestHandle(
    Shape shape,
    Offset posCanvas,
    double viewportScale,
  ) {
    final base = shape.bounds ?? _boundsFromPoints(shape.points);
    if (base == null) return null;
    final corners = _transformedCorners(
      base,
      shape.rotation,
      shape.scale,
    );
    final center = Offset(
      (corners[0].dx + corners[2].dx) / 2,
      (corners[0].dy + corners[2].dy) / 2,
    );
    final handleSize = 12 / viewportScale;
    final half = handleSize / 2;

    // Corner handles (uniform scale).
    for (final c in corners) {
      final rect = Rect.fromLTWH(
        c.dx - half,
        c.dy - half,
        handleSize,
        handleSize,
      );
      if (rect.contains(posCanvas)) {
        final dist = (c - center).distance;
        return _HandleHit(
          type: _TransformHandle.scaleUniform,
          center: center,
          startDistance: dist,
          startAngle: 0,
        );
      }
    }

    // Edge handles (axis scale).
    final topCenter = Offset(
      (corners[0].dx + corners[1].dx) / 2,
      (corners[0].dy + corners[1].dy) / 2,
    );
    final rightCenter = Offset(
      (corners[1].dx + corners[2].dx) / 2,
      (corners[1].dy + corners[2].dy) / 2,
    );
    final bottomCenter = Offset(
      (corners[2].dx + corners[3].dx) / 2,
      (corners[2].dy + corners[3].dy) / 2,
    );
    final leftCenter = Offset(
      (corners[3].dx + corners[0].dx) / 2,
      (corners[3].dy + corners[0].dy) / 2,
    );

    final edgeHandles = <Map<String, dynamic>>[
      {
        'pos': leftCenter,
        'type': _TransformHandle.scaleX,
      },
      {
        'pos': rightCenter,
        'type': _TransformHandle.scaleX,
      },
      {
        'pos': topCenter,
        'type': _TransformHandle.scaleY,
      },
      {
        'pos': bottomCenter,
        'type': _TransformHandle.scaleY,
      },
    ];

    for (final entry in edgeHandles) {
      final pos = entry['pos'] as Offset;
      final rect = Rect.fromLTWH(
        pos.dx - half,
        pos.dy - half,
        handleSize,
        handleSize,
      );
      if (rect.contains(posCanvas)) {
        final axisVector = (pos - center);
        final axis = axisVector.distance == 0
            ? Offset.zero
            : axisVector / axisVector.distance;
        final dist = axisVector.distance;
        return _HandleHit(
          type: entry['type'] as _TransformHandle,
          center: center,
          startDistance: dist,
          startAngle: 0,
          axis: axis,
        );
      }
    }

    // Rotate handle above top edge.
    final dir = (topCenter - center);
    final len = dir.distance;
    if (len > 0) {
      final norm = dir / len;
      final handleCenter = center + norm * (len + 20 / viewportScale);
      final rect = Rect.fromCircle(center: handleCenter, radius: half);
      if (rect.contains(posCanvas)) {
        final dist = (posCanvas - center).distance;
        final angle = math.atan2(
          posCanvas.dy - center.dy,
          posCanvas.dx - center.dx,
        );
        return _HandleHit(
          type: _TransformHandle.rotate,
          center: center,
          startDistance: dist,
          startAngle: angle,
        );
      }
    }
    return null;
  }

  Rect? _boundsFromPoints(List<Offset> points) {
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

  Offset? hitAxisForHandle(_TransformHandle handle, Shape shape) {
    switch (handle) {
      case _TransformHandle.scaleX:
        return Offset(math.cos(shape.rotation), math.sin(shape.rotation));
      case _TransformHandle.scaleY:
        return Offset(-math.sin(shape.rotation), math.cos(shape.rotation));
      default:
        return null;
    }
  }

  double _normalizeAngle(double angle) {
    while (angle <= -math.pi) {
      angle += 2 * math.pi;
    }
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    return angle;
  }
}

class _HandleHit {
  _HandleHit({
    required this.type,
    required this.center,
    required this.startDistance,
    required this.startAngle,
    this.axis,
  });

  final _TransformHandle type;
  final Offset center;
  final double startDistance;
  final double startAngle;
  final Offset? axis;
}

enum _TransformHandle { scaleUniform, scaleX, scaleY, rotate }
