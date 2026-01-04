import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'package:animation_maker/domain/models/shape.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'canvas_painter.dart';
import 'editor_view_model.dart';
import 'selection_types.dart';
import 'snap_service.dart';
import 'selection_handles.dart';
import 'transform_session.dart';

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
  TransformHandle? _activeHandle;
  double _handleStartScale = 1.0;
  double _handleStartRotation = 0.0;
  Offset? _handleCenter;
  double _handleStartDistance = 0.0;
  double _handleStartAngle = 0.0;
  double _handleLastAngle = 0.0;
  double? _rotationSnapAngle;
  Offset? _rotationSnapCenter;
  Offset? _pivotSnapAnchorWorld;
  Rect? _handleBaseBounds;
  List<Offset>? _handleBasePoints;
  String? _handleShapeId;
  Shape? _handleBaseShape;
  Offset? _handleAxis;
  List<Shape>? _handleBaseShapes;
  TransformSession? _transformSession;
  Offset? _lassoStartScene;
  Offset? _lassoStartScreen;
  Rect? _lassoRectScene;
  Rect? _lassoRectScreen;

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
    if (!mounted) return;
    final nextScale = _controller.value.getMaxScaleOnAxis();
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentScale = nextScale;
        });
      });
    } else {
      setState(() {
        _currentScale = nextScale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shapes = ref.watch(editorViewModelProvider.select((s) => s.shapes));
    final selectedShapeId = ref.watch(
      editorViewModelProvider.select((s) => s.selectedShapeId),
    );
    final selectedShapeIds = ref.watch(
      editorViewModelProvider.select((s) => s.selectedShapeIds),
    );
    final activeTool = ref.watch(
      editorViewModelProvider.select((s) => s.activeTool),
    );
    final selectionMode = ref.watch(
      editorViewModelProvider.select((s) => s.selectionMode),
    );
    final isPanMode = ref.watch(
      editorViewModelProvider.select((s) => s.isPanMode),
    );
    final inProgressStroke = ref.watch(
      editorViewModelProvider.select((s) => s.inProgressStroke),
    );
    final brushThickness = ref.watch(
      editorViewModelProvider.select((s) => s.brushThickness),
    );
    final brushOpacity = ref.watch(
      editorViewModelProvider.select((s) => s.brushOpacity),
    );
    final brushSmoothness = ref.watch(
      editorViewModelProvider.select((s) => s.brushSmoothness),
    );
    final brushColor = ref.watch(
      editorViewModelProvider.select((s) => s.currentColor),
    );
    final brushType = ref.watch(
      editorViewModelProvider.select((s) => s.currentBrush),
    );
    final palmRejectionEnabled = ref.watch(
      editorViewModelProvider.select((s) => s.palmRejectionEnabled),
    );
    final transformGroupAsOne = ref.watch(
      editorViewModelProvider.select((s) => s.transformGroupAsOne),
    );
    final pivotSnapEnabled = ref.watch(
      editorViewModelProvider.select((s) => s.pivotSnapEnabled),
    );
    final pivotSnapStrength = ref.watch(
      editorViewModelProvider.select((s) => s.pivotSnapStrength),
    );
    final ui.Image? raster = ref.watch(
      editorViewModelProvider.select((s) => s.rasterLayer),
    );
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

        if (!_initializedTransform || maxW != _lastMaxW || maxH != _lastMaxH) {
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
            selectedShapeIds: selectedShapeIds,
            selectionMode: selectionMode,
            rasterLayer: raster,
            inProgressStroke: inProgressStroke,
            brushThickness: brushThickness,
            brushOpacity: brushOpacity,
            brushSmoothness: brushSmoothness,
            brushColor: brushColor,
            brushType: brushType,
            showSelectionHandles:
                activeTool == EditorTool.select &&
                selectionMode == SelectionMode.single &&
                selectedShapeId != null &&
                (selectedShapeIds.length <= 1),
            viewportScale: _currentScale,
            rotationGuideCenter: _rotationSnapCenter,
            rotationGuideAngle: _rotationSnapAngle,
            pivotSnapGuide: _pivotSnapAnchorWorld,
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
            child: ClipRect(child: RepaintBoundary(child: painter)),
          ),
        );

        final navActive = isPanMode;
        final canvasBounds = Rect.fromLTWH(
          0,
          0,
          _designSize.width,
          _designSize.height,
        );

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

          if (activeTool == EditorTool.select &&
              selectedShape != null &&
              selectionMode == SelectionMode.single) {
            // If another shape sits under the tap, switch selection immediately
            // to avoid needing a second tap when handles are in the way.
            final topShape = vm.topShapeAtPoint(pos);
            if (topShape != null && topShape.id != selectedShapeId) {
              vm.selectShape(topShape.id);
              _activePointer = event.pointer;
              return;
            }

            final baseBounds =
                selectedShape!.bounds ??
                _boundsFromPoints(selectedShape!.points);
            final hit = hitTestHandle(
              selectedShape!,
              pos,
              _currentScale,
              canvasBounds: canvasBounds,
            );
            if (hit != null) {
              // Capture a snapshot of shapes to apply consistent transforms.
              _handleBaseShapes = transformGroupAsOne
                  ? _selectedGroupShapes(shapes, selectedShape!)
                  : null;
              _activeHandle = hit.type;
              final origin = (baseBounds)?.center ?? Offset.zero;
              final centerOverride = _pivotWorldForShape(
                selectedShape!,
                origin,
              );
              final axis = _handleAxisFor(hit.type, selectedShape!.rotation);
              final startAngle = math.atan2(
                pos.dy - centerOverride.dy,
                pos.dx - centerOverride.dx,
              );
              double startDistance;
              if (hit.type == TransformHandle.scaleUniform) {
                startDistance = (pos - centerOverride).distance;
              } else if (axis != null) {
                startDistance =
                    ((pos - centerOverride).dx * axis.dx +
                            (pos - centerOverride).dy * axis.dy)
                        .abs();
              } else {
                startDistance = (pos - centerOverride).distance;
              }
              // For pivot handle, no transform session needed.
              final sessionShapes = transformGroupAsOne
                  ? _selectedGroupShapes(shapes, selectedShape!)
                  : <Shape>[selectedShape!];
              _transformSession = TransformSession(
                shapes: sessionShapes,
                center: hit.type == TransformHandle.pivot
                    ? centerOverride
                    : centerOverride,
              );
              _handleCenter = centerOverride;
              _handleStartScale = selectedShape!.scale;
              _handleStartRotation = selectedShape!.rotation;
              _handleStartDistance = startDistance.abs();
              _handleStartAngle = startAngle;
              _handleLastAngle = startAngle;
              _rotationSnapAngle = null;
              _rotationSnapCenter = centerOverride;
              _handleBaseBounds = baseBounds;
              _handleBasePoints = selectedShape!.points.toList();
              _handleShapeId = selectedShape!.id;
              _handleBaseShape = selectedShape;
              _handleAxis = axis;
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
              if (selectionMode == SelectionMode.lasso) {
                _activePointer = event.pointer;
                _lassoStartScene = pos;
                _lassoStartScreen = event.localPosition;
                _lassoRectScene = Rect.fromLTWH(pos.dx, pos.dy, 0, 0);
                _lassoRectScreen = Rect.fromLTWH(
                  _lassoStartScreen!.dx,
                  _lassoStartScreen!.dy,
                  0,
                  0,
                );
                setState(() {});
                return;
              }
              vm.selectAtPoint(pos);
              break;
          }
        }

        void handlePointerMove(PointerMoveEvent event) {
          if (_multiTouchInProgress || _pointerCount >= 2) return;
          final navNow = isPanMode;
          if (navNow) return;

          final pos = _toCanvas(event.localPosition);

          if (activeTool == EditorTool.select &&
              selectionMode == SelectionMode.lasso &&
              _lassoStartScene != null &&
              _lassoStartScreen != null &&
              _activePointer == event.pointer) {
            setState(() {
              _lassoRectScene = Rect.fromPoints(_lassoStartScene!, pos);
              _lassoRectScreen = Rect.fromPoints(
                _lassoStartScreen!,
                event.localPosition,
              );
            });
            return;
          }

          if (_activeHandle != null &&
              _handleCenter != null &&
              _activePointer == event.pointer) {
            final currentState = ref.read(editorViewModelProvider);
            final currentShape = _findShape(
              currentState.shapes,
              currentState.selectedShapeId,
            );
            if (currentShape == null) return;
            switch (_activeHandle!) {
              case TransformHandle.scaleUniform:
                final dist = (pos - _handleCenter!).distance;
                if (dist > 0.001 && _handleStartDistance > 0.001) {
                  final factor = dist / _handleStartDistance;
                  final updated = _transformSession?.scaleUniform(factor);
                  if (updated != null) {
                    vm.applyTransformedShapes(updated);
                  }
                }
                break;
              case TransformHandle.scaleX:
              case TransformHandle.scaleY:
                if (_handleCenter == null) break;
                final axis = _handleAxisFor(
                  _activeHandle!,
                  currentShape.rotation,
                );
                if (axis == null || axis == Offset.zero) break;
                final normAxis = axis.distance == 0
                    ? const Offset(1, 0)
                    : axis / axis.distance;
                final rel = (pos - _handleCenter!);
                final proj = rel.dx * normAxis.dx + rel.dy * normAxis.dy;
                if (_handleStartDistance.abs() > 0.001) {
                  final factor = (proj.abs() / _handleStartDistance.abs())
                      .clamp(0.05, 3.0);
                  final updated = _transformSession?.scaleAxis(
                    _activeHandle!,
                    factor,
                    axis: normAxis,
                  );
                  if (updated != null) {
                    vm.applyTransformedShapes(updated);
                  }
                }
                break;
              case TransformHandle.rotate:
                final angle = math.atan2(
                  pos.dy - _handleCenter!.dy,
                  pos.dx - _handleCenter!.dx,
                );
                final deltaFromStart = _normalizeAngle(
                  angle - _handleStartAngle,
                );
                final proposed = _handleStartRotation + deltaFromStart;
                final snapped = SnapService.snapAngle(proposed);
                final applied = snapped ?? proposed;
                final delta = applied - _handleStartRotation;
                final updated = _transformSession?.rotate(delta);
                if (updated != null) {
                  vm.applyTransformedShapes(updated);
                }
                _rotationSnapAngle = snapped != null ? applied : null;
                _rotationSnapCenter = _handleCenter;
                _handleLastAngle = angle;
                break;
              case TransformHandle.pivot:
                if (_handleBaseBounds == null || _handleBaseShape == null)
                  break;
                final base = _handleBaseBounds!;
                final baseShape = _handleBaseShape!;

                // Apply snapping to get the final world target
                Offset worldTarget = pos;
                if (pivotSnapEnabled && pivotSnapStrength > 0) {
                  worldTarget = _snapPivotToAnchors(
                    pos,
                    base,
                    baseShape,
                    pivotSnapStrength,
                  );
                }

                final updated = _transformSession?.updatePivot(
                  baseShape.transform.pivot,
                  worldTarget: worldTarget,
                );
                if (updated != null) {
                  vm.applyTransformedShapes(updated);
                }
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
              if (selectionMode != SelectionMode.single) {
                return;
              }
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

          if (activeTool == EditorTool.select &&
              selectionMode == SelectionMode.lasso &&
              _lassoStartScene != null &&
              _activePointer == event.pointer) {
            final end = _toCanvas(event.localPosition);
            final rect = Rect.fromPoints(_lassoStartScene!, end);
            final ids = _shapeIdsInRect(
              rect,
              ref.read(editorViewModelProvider).shapes,
            );
            vm.setSelection(ids);
            _lassoStartScene = null;
            _lassoStartScreen = null;
            _lassoRectScene = null;
            _lassoRectScreen = null;
            _activePointer = null;
            setState(() {});
            return;
          }

          if (_activeHandle != null && _handleCenter != null) {
            vm.rebuildQuadTree();
            vm.finalizeSelectionEdit();
            _activeHandle = null;
            _handleCenter = null;
            _handleBaseBounds = null;
            _handleBasePoints = null;
            _handleShapeId = null;
            _handleBaseShape = null;
            _rotationSnapAngle = null;
            _rotationSnapCenter = null;
            _activePointer = null;
            _handleAxis = null;
            _handleBaseShapes = null;
            _transformSession = null;
            _pivotSnapAnchorWorld = null;
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

          if (selectionMode == SelectionMode.lasso) {
            _lassoStartScene = null;
            _lassoStartScreen = null;
            _lassoRectScene = null;
            _lassoRectScreen = null;
            if (isLast) _activePointer = null;
            setState(() {});
          }

          if (_activeHandle != null && _handleCenter != null) {
            _activeHandle = null;
            _handleCenter = null;
            _handleBaseBounds = null;
            _handleBasePoints = null;
            _handleShapeId = null;
            _handleBaseShape = null;
            _rotationSnapAngle = null;
            _rotationSnapCenter = null;
            _activePointer = null;
            _handleAxis = null;
            _handleBaseShapes = null;
            _transformSession = null;
            _pivotSnapAnchorWorld = null;
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
              child: Stack(
                children: [
                  viewer,
                  if (_lassoRectScreen != null)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _LassoPainter(rect: _lassoRectScreen!),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
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

  Rect? _boundsFromPoints(List<Offset> points) {
    return boundsFromPoints(points);
  }

  List<Offset> _transformedCorners(Rect rect, Matrix4 matrix) {
    return transformedCorners(rect, matrix);
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

  Rect? _groupBounds(List<Shape> shapes, String? groupId, {Rect? fallback}) {
    if (groupId == null) return fallback;
    Rect? acc = fallback;
    for (final s in shapes) {
      if (s.groupId != groupId) continue;
      final b = s.worldBounds ?? s.bounds ?? _boundsFromPoints(s.points);
      if (b == null) continue;
      acc = acc == null ? b : acc.expandToInclude(b);
    }
    return acc;
  }

  List<Shape> _selectedGroupShapes(List<Shape> shapes, Shape selected) {
    if (selected.groupId == null) return [selected];
    return shapes
        .where((s) => s.groupId == selected.groupId)
        .toList(growable: false);
  }

  Offset? _handleAxisFor(TransformHandle handle, double rotation) {
    return hitAxisForHandle(handle, rotation);
  }

  /// Pivot world position: translation + origin + pivot (rotation/scale do not move pivot itself).
  Offset _pivotWorldForShape(Shape shape, Offset origin) {
    return shape.translation + origin + shape.transform.pivot;
  }

  /// Snap pivot to common anchors (center, edge midpoints, corners) when near.
  /// Returns the snapped world position (or original if no snap).
  Offset _snapPivotToAnchors(
    Offset worldPos,
    Rect base,
    Shape shape,
    double strength,
  ) {
    _pivotSnapAnchorWorld = null;

    // Calculate snap threshold based on strength
    final baseThreshold = 6.0 + 12.0 * strength; // logical pixels
    final snapThreshold = baseThreshold / _currentScale; // in canvas units

    // Define snap candidates in local space (relative to shape center)
    final halfW = base.width * 0.5;
    final halfH = base.height * 0.5;
    final origin = base.center;
    final matrix = shape.matrixForRect(base);

    final candidates = <Offset>[
      Offset.zero, // center
      Offset(halfW, 0), // right
      Offset(-halfW, 0), // left
      Offset(0, halfH), // bottom
      Offset(0, -halfH), // top
      Offset(halfW, halfH), // bottom-right
      Offset(-halfW, halfH), // bottom-left
      Offset(halfW, -halfH), // top-right
      Offset(-halfW, -halfH), // top-left
    ];

    Offset bestWorld = worldPos;
    double bestDist = snapThreshold;

    // Check each candidate anchor point
    for (final c in candidates) {
      final localPoint = origin + c;
      final v = matrix.transform3(Vector3(localPoint.dx, localPoint.dy, 0));
      final worldCandidate = Offset(v.x, v.y);
      final d = (worldPos - worldCandidate).distance;

      if (d < bestDist) {
        bestDist = d;
        bestWorld = worldCandidate;
        // Store for visual feedback
        _pivotSnapAnchorWorld = worldCandidate;
      }
    }

    return bestWorld;
  }

  List<String> _shapeIdsInRect(Rect rect, List<Shape> shapes) {
    final selectionRect = Rect.fromPoints(
      Offset(math.min(rect.left, rect.right), math.min(rect.top, rect.bottom)),
      Offset(math.max(rect.left, rect.right), math.max(rect.top, rect.bottom)),
    );
    final hits = <String>[];
    for (final shape in shapes) {
      final bounds = _shapeSelectionBounds(shape);
      if (bounds == null) continue;
      final expanded = bounds.inflate(0.5);
      if (selectionRect.overlaps(expanded) ||
          selectionRect.contains(expanded.topLeft) ||
          selectionRect.contains(expanded.bottomRight) ||
          expanded.contains(selectionRect.center)) {
        hits.add(shape.id);
      }
    }
    return hits;
  }

  Rect? _shapeSelectionBounds(Shape shape) {
    final baseRect = shape.bounds;
    final points = <Offset>[];
    if (baseRect != null) {
      points.addAll(
        transformedCorners(baseRect, shape.matrixForRect(baseRect)),
      );
    } else if (shape.points.isNotEmpty) {
      final bounds = _boundsFromPoints(shape.points);
      final matrix = shape.matrixForRect(bounds ?? Rect.zero);
      for (final p in shape.points) {
        final v = matrix.transform3(Vector3(p.dx, p.dy, 0));
        points.add(Offset(v.x, v.y));
      }
    } else {
      return null;
    }

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
}

class _LassoPainter extends CustomPainter {
  const _LassoPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.width == 0 && rect.height == 0) return;
    final normalized = Rect.fromPoints(
      Offset(math.min(rect.left, rect.right), math.min(rect.top, rect.bottom)),
      Offset(math.max(rect.left, rect.right), math.max(rect.top, rect.bottom)),
    );
    final fill = Paint()
      ..color = const Color(0x221E88E5)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(normalized, fill);
    _drawDashedRect(canvas, normalized, stroke);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    // Top
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );
    // Right
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );
    // Bottom
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );
    // Left
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final direction = (end - start) / totalLength;
    double distance = 0.0;
    while (distance < totalLength) {
      final currentStart = start + direction * distance;
      distance += dashWidth;
      final currentEnd =
          start + direction * (distance > totalLength ? totalLength : distance);
      canvas.drawLine(currentStart, currentEnd, paint);
      distance += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LassoPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
