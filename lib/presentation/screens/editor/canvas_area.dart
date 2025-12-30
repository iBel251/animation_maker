import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas_painter.dart';
import 'editor_view_model.dart';

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
    final ui.Image? raster =
        ref.watch(editorViewModelProvider.select((s) => s.rasterLayer));
    final vm = ref.read(editorViewModelProvider.notifier);

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

        if (!_initializedTransform) {
          _controller.value = Matrix4.identity()
            ..translate(offset.dx, offset.dy)
            ..scale(scale);
          _lastMaxW = maxW;
          _lastMaxH = maxH;
          _baseScale = scale;
          _currentScale = scale;
          _initializedTransform = true;
        } else if (maxW != _lastMaxW || maxH != _lastMaxH) {
          // Preserve scene center when layout changes (e.g., sidebars open).
          final prevViewportCenter = Offset(_lastMaxW / 2, _lastMaxH / 2);
          final sceneCenter = _controller.toScene(prevViewportCenter);
          final currentScale = _controller.value.getMaxScaleOnAxis();
          final newViewportCenter = Offset(maxW / 2, maxH / 2);
          _controller.value = Matrix4.identity()
            ..translate(newViewportCenter.dx, newViewportCenter.dy)
            ..scale(currentScale)
            ..translate(-sceneCenter.dx, -sceneCenter.dy);
          _lastMaxW = maxW;
          _lastMaxH = maxH;
        }
        _currentScale = _controller.value.getMaxScaleOnAxis();

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

          if (navActive) return;

          _activePointer = event.pointer;
          final pos = _toCanvas(event.localPosition);
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

          if (_activePointer != event.pointer) return;
          final pos = _toCanvas(event.localPosition);
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
}
