import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/transform_handle.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_bounds.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_hit_test.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_handle_metrics.dart';
import 'package:animation_maker/features/canvas/domain/usecases/transform_session.dart';
import 'package:animation_maker/features/canvas/presentation/controllers/node_interaction_controller.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/services/selection_utils.dart';
import 'package:animation_maker/features/canvas/presentation/services/snap_service.dart';
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class CanvasInteractionContext {
  const CanvasInteractionContext({
    required this.activeTool,
    required this.selectionMode,
    required this.isPanMode,
    required this.palmRejectionEnabled,
    required this.transformGroupAsOne,
    required this.selectedShapeId,
    required this.pivotSnapEnabled,
    required this.pivotSnapStrength,
    required this.isLinkingMode,
    required this.readState,
    required this.viewModel,
    required this.shapes,
    required this.selectedShape,
    required this.canvasBounds,
    required this.toCanvas,
    required this.readViewportScale,
    required this.onNodeStateChanged,
    required this.onShapeUpdated,
    required this.onHistoryPush,
  });

  final EditorTool activeTool;
  final SelectionMode selectionMode;
  final bool isPanMode;
  final bool palmRejectionEnabled;
  final bool transformGroupAsOne;
  final String? selectedShapeId;
  final bool pivotSnapEnabled;
  final double pivotSnapStrength;
  final bool isLinkingMode;
  final EditorState Function() readState;
  final EditorViewModel viewModel;
  final List<Shape> shapes;
  final Shape? selectedShape;
  final Rect canvasBounds;
  final Offset Function(Offset) toCanvas;
  final double Function() readViewportScale;
  final void Function(NodeEditState) onNodeStateChanged;
  final void Function(Shape) onShapeUpdated;
  final void Function() onHistoryPush;
}

/// Tracks pointer/transform state so CanvasWidget stays focused on layout.
class CanvasInteractionController {
  CanvasInteractionController({
    SelectionUtils? selectionUtils,
    NodeInteractionController? nodeController,
  })  : _selectionUtils = selectionUtils ?? const SelectionUtils(),
        _nodeController = nodeController ?? NodeInteractionController();

  final SelectionUtils _selectionUtils;
  final NodeInteractionController _nodeController;

  int _pointerCount = 0;
  int? _activePointer;
  bool _multiTouchInProgress = false;
  bool? _wasPanModeEnabledBeforeMultiTouch;
  Timer? _panModeDisableTimer;
  bool _didAutoEnablePanMode = false;
  // Atomic flag to prevent race conditions during state transitions
  bool _isProcessingMultiTouch = false;

  TransformHandle? _activeHandle;
  double _handleStartRotation = 0.0;
  Offset? _handleCenter;
  double _handleStartDistance = 0.0;
  double _handleStartAngle = 0.0;

  double? _rotationSnapAngle;
  Offset? _rotationSnapCenter;
  Offset? _pivotSnapAnchorWorld;

  Rect? _handleBaseBounds;
  Shape? _handleBaseShape;
  TransformSession? _transformSession;
  List<Shape> _rotationBaseShapes = const [];
  bool _spatialTransformActive = false;
  List<Shape> _spatialBaseShapes = const [];
  Offset _spatialCenter = Offset.zero;

  Offset? _lassoStartScene;
  Offset? _lassoStartScreen;
  Rect? _lassoRectScene;
  Rect? _lassoRectScreen;

  Offset? _dragStartPos;
  bool _isDraggingSelected = false;

  double? get rotationGuideAngle => _rotationSnapAngle;
  Offset? get rotationGuideCenter => _rotationSnapCenter;
  Offset? get pivotSnapGuide => _pivotSnapAnchorWorld;
  Rect? get lassoRectScreen => _lassoRectScreen;
  bool get isMultiTouchInProgress => _multiTouchInProgress;
  
  // Gesture configuration constants
  static const Duration _panModeDisableDelay = Duration(milliseconds: 300);

  /// Clears transient interaction state and cancels delayed callbacks.
  /// Call from owning widget `dispose` to avoid stale pointer/timer callbacks
  /// after route transitions.
  void dispose() {
    _panModeDisableTimer?.cancel();
    _panModeDisableTimer = null;
    _pointerCount = 0;
    _activePointer = null;
    _multiTouchInProgress = false;
    _wasPanModeEnabledBeforeMultiTouch = null;
    _didAutoEnablePanMode = false;
    _isProcessingMultiTouch = false;
    _dragStartPos = null;
    _isDraggingSelected = false;
    _clearLasso();
    _clearHandleState(null);
    _nodeController.reset();
  }
  
  /// Cancels active tool operations consistently across all tools.
  /// This ensures proper state cleanup when multi-touch is detected.
  void _cancelActiveToolOperations(CanvasInteractionContext ctx, EditorViewModel vm) {
    switch (ctx.activeTool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        vm.cancelDrawing();
        break;
      case EditorTool.shape:
        // Skip canceling in point mode (has its own Cancel button)
        if (ctx.readState().pointModeState.isActive) break;
        vm.cancelShapeDrawing();
        break;
      case EditorTool.select:
        // For selection tool, clear any active transform handles
        // but don't cancel selection itself
        if (_activeHandle != null) {
          _clearHandleState(vm);
        }
        break;
      case EditorTool.nodeEdit:
        // Reset node controller state
        _nodeController.reset();
        break;
      case EditorTool.fill:
        // Fill tool is single-tap, nothing to cancel
        break;
      case EditorTool.camera:
        // Camera tool has no canvas interactions to cancel
        break;
    }
  }

  bool handlePointerDown(CanvasInteractionContext ctx, PointerDownEvent event) {
    final vm = ctx.viewModel;
    vm.setIsInteractingWithCanvas(true); // Hide bar on any interaction

    _pointerCount += 1;

    if (_pointerCount >= 2) {
      // Atomic check-and-set to prevent race conditions
      if (!_multiTouchInProgress && !_isProcessingMultiTouch) {
        _isProcessingMultiTouch = true;
        try {
          _multiTouchInProgress = true;
          // Cancel any pending pan mode disable timer
          _panModeDisableTimer?.cancel();
          _panModeDisableTimer = null;
          // Auto-enable pan mode for 2-finger pan/zoom
          final currentState = ctx.readState();
          _wasPanModeEnabledBeforeMultiTouch = currentState.isPanMode;
          if (!currentState.isPanMode) {
            vm.setPanMode(true);
            _didAutoEnablePanMode = true;
          } else {
            _didAutoEnablePanMode = false;
          }
          
          // Cancel active operations consistently across all tools
          _cancelActiveToolOperations(ctx, vm);
          
          _activePointer = null;
        } finally {
          _isProcessingMultiTouch = false;
        }
      }
      return false;
    }

    if (ctx.activeTool == EditorTool.brush &&
        ctx.palmRejectionEnabled &&
        event.kind == PointerDeviceKind.touch) {
      return false;
    }

    if (ctx.activeTool == EditorTool.brush &&
        ctx.palmRejectionEnabled &&
        _isRejectedPalm(event)) {
      return false;
    }

    // If user starts single-touch drawing, cancel any pending pan mode disable timer
    // and immediately disable pan mode if we auto-enabled it
    if (_wasPanModeEnabledBeforeMultiTouch != null && ctx.isPanMode) {
      _panModeDisableTimer?.cancel();
      _panModeDisableTimer = null;
      vm.setPanMode(_wasPanModeEnabledBeforeMultiTouch!);
      _wasPanModeEnabledBeforeMultiTouch = null;
    }

    if (ctx.isPanMode) return false;

    final pos = ctx.toCanvas(event.localPosition);

    if (ctx.activeTool == EditorTool.select &&
        ctx.selectedShape != null &&
        ctx.selectionMode == SelectionMode.single) {
      final state = ctx.readState();
      final selectedShape = ctx.selectedShape!;
      final spatialSelection = _spatialSelection(ctx);
      final handleShape = spatialSelection?.bounds != null
          ? _proxyShapeForBounds(spatialSelection!.bounds!)
          : selectedShape;
      final baseBounds = handleShape.localBounds;
      HandleHit? hit;
      if (spatialSelection?.corners != null) {
        hit = _hitTestHandleForCorners(
          spatialSelection!.corners!,
          pos,
          ctx.readViewportScale(),
          ctx.canvasBounds,
        );
      } else {
        hit = hitTestHandle(
          handleShape,
          pos,
          ctx.readViewportScale(),
          canvasBounds: ctx.canvasBounds,
          brushSmoothness: state
              .brushSettings[state.currentBrush]!
              .smoothness,
          strokeScaleWithShape: state.strokeScaleWithShape,
        );
        if (spatialSelection != null && hit?.type == TransformHandle.pivot) {
          hit = null;
        }
      }
      if (hit != null) {
        final origin = baseBounds?.center ?? Offset.zero;
        final centerOverride = spatialSelection?.corners != null
            ? Offset(
                (spatialSelection!.corners![0].dx +
                        spatialSelection.corners![2].dx) /
                    2,
                (spatialSelection.corners![0].dy +
                        spatialSelection.corners![2].dy) /
                    2,
              )
            : _pivotWorldForShape(handleShape, origin);
        final axis = _handleAxisFor(
          hit.type,
          spatialSelection != null ? 0.0 : selectedShape.rotation,
        );
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
        final sessionShapes = spatialSelection != null
            ? spatialSelection.shapes
            : (ctx.transformGroupAsOne
                ? _selectionUtils.selectedGroupShapes(
                    ctx.shapes,
                    ctx.selectedShapeId,
                  )
                : <Shape>[selectedShape]);
        _transformSession = spatialSelection == null
            ? TransformSession(
                shapes: sessionShapes,
                center: centerOverride,
              )
            : null;
        _activeHandle = hit.type;
        _handleCenter = centerOverride;
        _handleStartRotation = spatialSelection != null ? 0.0 : selectedShape.rotation;
        _handleStartDistance = startDistance.abs();
        _handleStartAngle = startAngle;
        _rotationSnapAngle = null;
        _rotationSnapCenter = centerOverride;
        _handleBaseBounds = baseBounds;
        _handleBaseShape = handleShape;
        _activePointer = event.pointer;
        // Store base shapes and start rotation session for hierarchy propagation
        if (hit.type == TransformHandle.rotate) {
          _rotationBaseShapes = sessionShapes;
          if (spatialSelection == null) {
            vm.startRotationSession(sessionShapes);
          }
        }
        _spatialTransformActive = spatialSelection != null;
        if (_spatialTransformActive) {
          _spatialBaseShapes = sessionShapes;
          _spatialCenter = centerOverride;
        }
        return false;
      }

      final topShape = vm.topShapeAtPoint(
        pos,
        viewportScale: ctx.readViewportScale(),
        excludeIds: ctx.selectedShapeId != null
            ? {ctx.selectedShapeId!}
            : null,
      );
      if (topShape != null && topShape.id != ctx.selectedShapeId) {
        // Handle linking mode - tapping a shape completes the link
        if (ctx.isLinkingMode) {
          vm.completeLinking(topShape.id);
          _activePointer = event.pointer;
          return false;
        }
        vm.selectShape(topShape.id);
        _activePointer = event.pointer;
        return false;
      }

      // If we still have a selected shape and didn't hit a handle or another shape,
      // check if click is within the selected shape's bounds to start dragging
      if (selectedShape != null) {
        final selectionBounds = spatialSelection?.bounds;
        final worldBounds = selectionBounds ?? selectedShape.worldBounds;
        if (worldBounds != null && worldBounds.contains(pos)) {
          // Start dragging the selected shape
          _dragStartPos = pos;
          _isDraggingSelected = true;
          _activePointer = event.pointer;
          return false;
        }
      }
    }

    _activePointer = event.pointer;
    switch (ctx.activeTool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        vm.startDrawing(
          pos,
          pressure: _pressureFromEvent(event),
          timeStamp: event.timeStamp,
        );
        break;
      case EditorTool.shape:
        // Check for point mode (tap-based drawing)
        final editorState = ctx.readState();
        if (editorState.shapeDrawKind == ShapeKind.pointPath) {
          // Enter point mode if not already active
          if (!editorState.pointModeState.isActive) {
            vm.enterPointMode();
          }
          // Add point at tap location
          vm.addPointModePoint(pos);
          // Don't start drag-based shape drawing
          return false;
        }
        vm.startShapeDrawing(pos);
        break;
      case EditorTool.select:
        if (ctx.selectionMode == SelectionMode.lasso) {
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
          return true;
        }
        vm.selectAtPoint(pos, viewportScale: ctx.readViewportScale());
        break;
      case EditorTool.nodeEdit:
        final nodeCtx = _buildNodeContext(ctx);
        _nodeController.handlePointerDown(nodeCtx, event);
        break;
      case EditorTool.fill:
        // Hit test to find shape under pointer and apply fill
        final hitShapeId = vm.hitTestShapeAt(pos, viewportScale: ctx.readViewportScale());
        if (hitShapeId != null) {
          final currentColor = ctx.readState().currentColor;
          vm.applyFillToShapeById(hitShapeId, currentColor);
        }
        break;
      case EditorTool.camera:
        // Camera tool: no canvas drawing/selection interactions
        break;
    }
    return false;
  }

  bool handlePointerMove(CanvasInteractionContext ctx, PointerMoveEvent event) {
    if (_multiTouchInProgress || _pointerCount >= 2) return false;
    if (ctx.isPanMode) return false;

    final pos = ctx.toCanvas(event.localPosition);

    if (ctx.activeTool == EditorTool.select &&
        ctx.selectionMode == SelectionMode.lasso &&
        _lassoStartScene != null &&
        _lassoStartScreen != null &&
        _activePointer == event.pointer) {
      _lassoRectScene = Rect.fromPoints(_lassoStartScene!, pos);
      _lassoRectScreen = Rect.fromPoints(
        _lassoStartScreen!,
        event.localPosition,
      );
      return true;
    }

    if (_activeHandle != null &&
        _handleCenter != null &&
        _activePointer == event.pointer) {
      final currentState = ctx.readState();
      final currentShape = _findShape(
        currentState.shapes,
        currentState.selectedShapeId,
      );
      if (currentShape == null) return false;
      final vm = ctx.viewModel;
      if (_spatialTransformActive && _spatialBaseShapes.isNotEmpty) {
        switch (_activeHandle!) {
          case TransformHandle.scaleUniform:
            final dist = (pos - _handleCenter!).distance;
            if (dist > 0.001 && _handleStartDistance > 0.001) {
              final factor = dist / _handleStartDistance;
              vm.applyScaleFromSnapshot(
                baseShapes: _spatialBaseShapes,
                center: _spatialCenter,
                scaleX: factor,
                scaleY: factor,
              );
            }
            break;
          case TransformHandle.scaleX:
          case TransformHandle.scaleY:
            final axis = _activeHandle == TransformHandle.scaleX
                ? const Offset(1, 0)
                : const Offset(0, 1);
            final rel = (pos - _handleCenter!);
            final proj = rel.dx * axis.dx + rel.dy * axis.dy;
            if (_handleStartDistance.abs() > 0.001) {
              final factor = (proj.abs() / _handleStartDistance.abs())
                  .clamp(0.05, 3.0);
              vm.applyScaleFromSnapshot(
                baseShapes: _spatialBaseShapes,
                center: _spatialCenter,
                scaleX: _activeHandle == TransformHandle.scaleX ? factor : 1.0,
                scaleY: _activeHandle == TransformHandle.scaleY ? factor : 1.0,
              );
            }
            break;
          case TransformHandle.rotate:
            final angle = math.atan2(
              pos.dy - _handleCenter!.dy,
              pos.dx - _handleCenter!.dx,
            );
            final deltaFromStart = _normalizeAngle(angle - _handleStartAngle);
            final proposed = _handleStartRotation + deltaFromStart;
            final snapped = SnapService.snapAngle(proposed);
            final applied = snapped ?? proposed;
            final delta = applied - _handleStartRotation;
            vm.applyRotationFromSnapshot(
              baseShapes: _spatialBaseShapes,
              center: _spatialCenter,
              deltaAngle: delta,
            );
            _rotationSnapAngle = snapped != null ? applied : null;
            _rotationSnapCenter = _handleCenter;
            break;
          case TransformHandle.pivot:
            break;
        }
        return false;
      }
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
          final normAxis =
              axis.distance == 0 ? const Offset(1, 0) : axis / axis.distance;
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
          final deltaFromStart = _normalizeAngle(angle - _handleStartAngle);
          final proposed = _handleStartRotation + deltaFromStart;
          final snapped = SnapService.snapAngle(proposed);
          final applied = snapped ?? proposed;
          final delta = applied - _handleStartRotation;
          final updated = _transformSession?.rotate(delta);
          if (updated != null) {
            // Use applyRotationWithChildren to also rotate children's positions
            vm.applyRotationWithChildren(updated, delta, _rotationBaseShapes);
          }
          _rotationSnapAngle = snapped != null ? applied : null;
          _rotationSnapCenter = _handleCenter;
          break;
        case TransformHandle.pivot:
          if (_handleBaseBounds == null || _handleBaseShape == null) break;
          final base = _handleBaseBounds!;
          final baseShape = _handleBaseShape!;
          Offset worldTarget = pos;
          if (ctx.pivotSnapEnabled && ctx.pivotSnapStrength > 0) {
            worldTarget = _snapPivotToAnchors(
              pos,
              base,
              baseShape,
              ctx.pivotSnapStrength,
              ctx.readViewportScale(),
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
      return false;
    }

    if (_activePointer != event.pointer) return false;
    
    // Handle dragging selected shape (takes precedence over default drag)
    if (_isDraggingSelected && ctx.activeTool == EditorTool.select) {
      if (ctx.selectionMode == SelectionMode.single && ctx.selectedShape != null) {
        final vm = ctx.viewModel;
        vm.moveSelectedBy(event.delta / ctx.readViewportScale());
        return false;
      }
    }
    
    final vm = ctx.viewModel;
    switch (ctx.activeTool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        vm.continueDrawing(
          pos,
          pressure: _pressureFromEvent(event),
          timeStamp: event.timeStamp,
        );
        break;
      case EditorTool.shape:
        // Skip drag updates in point mode (tap-based)
        if (ctx.readState().pointModeState.isActive) break;
        vm.updateShapeDrawing(pos);
        break;
      case EditorTool.select:
        // Only use default drag if not already dragging via bounds click
        if (!_isDraggingSelected && ctx.selectionMode == SelectionMode.single) {
          vm.moveSelectedBy(event.delta / ctx.readViewportScale());
        }
        break;
      case EditorTool.nodeEdit:
        final nodeCtx = _buildNodeContext(ctx);
        _nodeController.handlePointerMove(nodeCtx, event);
        break;
      case EditorTool.fill:
      case EditorTool.camera:
        break;
    }
    return false;
  }

  bool handlePointerUp(CanvasInteractionContext ctx, PointerUpEvent event) {
    if (_pointerCount > 0) _pointerCount -= 1;
    final isLast = _pointerCount == 0;
    final vm = ctx.viewModel;

    if (_pointerCount < 2) {
      // Atomic state update: clear multi-touch flag
      _isProcessingMultiTouch = true;
      try {
        _multiTouchInProgress = false;
        // Delay disabling pan mode to avoid lag on quick re-pan gestures
        // This keeps pan mode enabled briefly after release for smoother UX
        if (_didAutoEnablePanMode && _wasPanModeEnabledBeforeMultiTouch != null) {
          _panModeDisableTimer?.cancel();
          _panModeDisableTimer = Timer(_panModeDisableDelay, () {
            // Double-check state hasn't changed during delay
            if (_wasPanModeEnabledBeforeMultiTouch != null &&
                !_multiTouchInProgress) {
              vm.setPanMode(_wasPanModeEnabledBeforeMultiTouch!);
              _wasPanModeEnabledBeforeMultiTouch = null;
            }
          });
        }
      } finally {
        _isProcessingMultiTouch = false;
      }
    }

    if (ctx.activeTool == EditorTool.select &&
        ctx.selectionMode == SelectionMode.lasso &&
        _lassoStartScene != null &&
        _activePointer == event.pointer) {
      final end = ctx.toCanvas(event.localPosition);
      final rect = Rect.fromPoints(_lassoStartScene!, end);
      final ids = _shapeIdsInRect(rect, ctx.readState().shapes);
      vm.setSelection(ids);
      _clearLasso();
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on release
      return true;
    }

    if (_activeHandle != null && _handleCenter != null) {
      vm.rebuildQuadTree();
      vm.finalizeSelectionEdit();
      _clearHandleState(vm);
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on release
      return false;
    }

    // End dragging selected shape
    if (_isDraggingSelected) {
      _isDraggingSelected = false;
      _dragStartPos = null;
      vm.rebuildQuadTree();
      vm.finalizeSelectionEdit();
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on release
      return false;
    }

    if (ctx.isPanMode) {
      vm.setIsInteractingWithCanvas(false); // Show bar on release
      return false;
    }

    if (_activePointer != event.pointer) {
      if (isLast) _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on release
      return false;
    }

    switch (ctx.activeTool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        vm.endDrawing();
        break;
      case EditorTool.shape:
        // Skip finishing in point mode (shape is finalized via Done button)
        if (ctx.readState().pointModeState.isActive) break;
        vm.finishShapeDrawing();
        break;
      case EditorTool.select:
        vm.rebuildQuadTree();
        vm.finalizeSelectionEdit();
        break;
      case EditorTool.nodeEdit:
        final nodeCtx = _buildNodeContext(ctx);
        _nodeController.handlePointerUp(nodeCtx, event);
        break;
      case EditorTool.fill:
      case EditorTool.camera:
        break;
    }
    _activePointer = null;
    vm.setIsInteractingWithCanvas(false); // Show bar on release
    return false;
  }

  bool handlePointerCancel(CanvasInteractionContext ctx, PointerCancelEvent event) {
    if (_pointerCount > 0) _pointerCount -= 1;
    final isLast = _pointerCount == 0;
    final vm = ctx.viewModel;
    var needsRepaint = false;

    if (_pointerCount < 2) {
      // Atomic state update: clear multi-touch flag
      _isProcessingMultiTouch = true;
      try {
        _multiTouchInProgress = false;
        // Delay disabling pan mode to avoid lag on quick re-pan gestures
        // This keeps pan mode enabled briefly after cancel for smoother UX
        if (_didAutoEnablePanMode && _wasPanModeEnabledBeforeMultiTouch != null) {
          _panModeDisableTimer?.cancel();
          _panModeDisableTimer = Timer(_panModeDisableDelay, () {
            // Double-check state hasn't changed during delay
            if (_wasPanModeEnabledBeforeMultiTouch != null &&
                !_multiTouchInProgress) {
              vm.setPanMode(_wasPanModeEnabledBeforeMultiTouch!);
              _wasPanModeEnabledBeforeMultiTouch = null;
            }
          });
        }
      } finally {
        _isProcessingMultiTouch = false;
      }
    }

    if (ctx.selectionMode == SelectionMode.lasso) {
      _clearLasso();
      if (isLast) _activePointer = null;
      needsRepaint = true;
      vm.setIsInteractingWithCanvas(false); // Show bar on cancel
    }

    if (_activeHandle != null && _handleCenter != null) {
      _clearHandleState(vm);
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on cancel
      return needsRepaint;
    }

    // Cancel dragging selected shape
    if (_isDraggingSelected) {
      _isDraggingSelected = false;
      _dragStartPos = null;
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on cancel
      return needsRepaint;
    }

    if (ctx.isPanMode) {
      _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on cancel
      return needsRepaint;
    }

    if (_activePointer != event.pointer) {
      if (isLast) _activePointer = null;
      vm.setIsInteractingWithCanvas(false); // Show bar on cancel
      return needsRepaint;
    }
    switch (ctx.activeTool) {
      case EditorTool.brush:
      case EditorTool.eraser:
        vm.cancelDrawing();
        break;
      case EditorTool.shape:
        // Skip canceling in point mode (has its own Cancel button)
        if (ctx.readState().pointModeState.isActive) break;
        vm.cancelShapeDrawing();
        break;
      case EditorTool.select:
        break;
      case EditorTool.nodeEdit:
        final nodeCtx = _buildNodeContext(ctx);
        _nodeController.handlePointerCancel(nodeCtx, event);
        break;
      case EditorTool.fill:
      case EditorTool.camera:
        break;
    }
    _activePointer = null;
    vm.setIsInteractingWithCanvas(false); // Show bar on cancel
    return needsRepaint;
  }

  _SpatialSelection? _spatialSelection(CanvasInteractionContext ctx) {
    final selectedId = ctx.selectedShapeId;
    if (selectedId == null) return null;
    Shape? selected;
    for (final shape in ctx.shapes) {
      if (shape.id == selectedId) {
        selected = shape;
        break;
      }
    }
    final spatialId = selected?.spatialObjectId;
    if (spatialId == null) return null;
    final spatialShapes = ctx.shapes
        .where((shape) => shape.spatialObjectId == spatialId)
        .toList(growable: false);
    if (spatialShapes.isEmpty) return null;
    final state = ctx.readState();
    final bounds = selectionBoundsForShapesWorld(
      spatialShapes,
      brushSmoothness: state.brushSettings[state.currentBrush]!.smoothness,
      strokeScaleWithShape: state.strokeScaleWithShape,
    );
    final corners = selectionCornersForShapesWorld(
      spatialShapes,
      brushSmoothness: state.brushSettings[state.currentBrush]!.smoothness,
      strokeScaleWithShape: state.strokeScaleWithShape,
    );
    return _SpatialSelection(
      spatialId: spatialId,
      shapes: spatialShapes,
      bounds: bounds,
      corners: corners,
    );
  }

  Shape _proxyShapeForBounds(Rect bounds) {
    return Shape(
      id: '_spatial_selection_proxy',
      kind: ShapeKind.rectangle,
      bounds: bounds,
      strokeWidth: 0,
      strokeColor: const Color(0xFF000000),
      fillColor: null,
      opacity: 1.0,
      isVisible: true,
      isLocked: false,
      points: const [],
      contours: const [],
      transform: const Transform2D(),
    );
  }

  Offset _rotationHandlePosition({
    required Offset center,
    required List<Offset> edgeCenters,
    required double viewportScale,
    required Rect canvasBounds,
  }) {
    final baseOffset = selectionHandleRotationOffset(viewportScale);
    Offset? fallback;
    for (final edgeCenter in edgeCenters) {
      final dir = edgeCenter - center;
      final len = dir.distance;
      if (len <= 0) continue;
      final norm = dir / len;
      final candidate = center + norm * (len + baseOffset);
      fallback ??= candidate;
      if (canvasBounds.contains(candidate)) {
        return candidate;
      }
    }
    return _clampOffsetToRect(fallback ?? center, canvasBounds);
  }

  Offset _clampOffsetToRect(Offset value, Rect rect) {
    return Offset(
      value.dx.clamp(rect.left, rect.right),
      value.dy.clamp(rect.top, rect.bottom),
    );
  }

  HandleHit? _hitTestHandleForCorners(
    List<Offset> corners,
    Offset posCanvas,
    double viewportScale,
    Rect canvasBounds,
  ) {
    if (corners.length != 4) return null;
    final center = Offset(
      (corners[0].dx + corners[2].dx) / 2,
      (corners[0].dy + corners[2].dy) / 2,
    );
    final handleSize = selectionHandleCanvasSize(viewportScale);
    final half = handleSize / 2;
    final safeBounds = canvasBounds.deflate(half);

    for (final c in corners) {
      final rect = Rect.fromLTWH(
        c.dx - half,
        c.dy - half,
        handleSize,
        handleSize,
      );
      if (rect.contains(posCanvas)) {
        final dist = (c - center).distance;
        return HandleHit(
          type: TransformHandle.scaleUniform,
          center: center,
          startDistance: dist,
          startAngle: 0,
        );
      }
    }

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
      {'pos': leftCenter, 'type': TransformHandle.scaleX},
      {'pos': rightCenter, 'type': TransformHandle.scaleX},
      {'pos': topCenter, 'type': TransformHandle.scaleY},
      {'pos': bottomCenter, 'type': TransformHandle.scaleY},
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
        return HandleHit(
          type: entry['type'] as TransformHandle,
          center: center,
          startDistance: dist,
          startAngle: 0,
          axis: axis,
        );
      }
    }

    final rotationHandle = _rotationHandlePosition(
      center: center,
      edgeCenters: [topCenter, rightCenter, bottomCenter, leftCenter],
      viewportScale: viewportScale,
      canvasBounds: safeBounds,
    );
    final rect = Rect.fromCircle(center: rotationHandle, radius: half);
    if (rect.contains(posCanvas)) {
      final dist = (posCanvas - center).distance;
      final angle = math.atan2(
        posCanvas.dy - center.dy,
        posCanvas.dx - center.dx,
      );
      return HandleHit(
        type: TransformHandle.rotate,
        center: center,
        startDistance: dist,
        startAngle: angle,
      );
    }

    return null;
  }

  void _clearHandleState(EditorViewModel? vm) {
    _activeHandle = null;
    _handleCenter = null;
    _handleBaseBounds = null;
    _handleBaseShape = null;
    _rotationSnapAngle = null;
    _rotationSnapCenter = null;
    _activePointer = null;
    _transformSession = null;
    _pivotSnapAnchorWorld = null;
    _spatialTransformActive = false;
    _spatialBaseShapes = const [];
    _spatialCenter = Offset.zero;
    // End rotation session and clear base shapes
    if (_rotationBaseShapes.isNotEmpty) {
      vm?.endRotationSession();
      _rotationBaseShapes = const [];
    }
  }

  void _clearLasso() {
    _lassoStartScene = null;
    _lassoStartScreen = null;
    _lassoRectScene = null;
    _lassoRectScreen = null;
  }

  bool _isRejectedPalm(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.mouse) {
      return false;
    }
    final major = event.radiusMajor;
    final minor = event.radiusMinor;
    const double palmThreshold = 24.0;
    if (major != null && major > palmThreshold) return true;
    if (minor != null && minor > palmThreshold) return true;
    return false;
  }

  double _pressureFromEvent(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus) return 1.0;
    final min = event.pressureMin;
    final max = event.pressureMax;
    if (max <= min) return 1.0;
    final normalized = (event.pressure - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }

  Shape? _findShape(List<Shape> shapes, String? id) {
    if (id == null) return null;
    for (final s in shapes) {
      if (s.id == id) return s;
    }
    return null;
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

  Offset? _handleAxisFor(TransformHandle handle, double rotation) {
    return hitAxisForHandle(handle, rotation);
  }

  Offset _pivotWorldForShape(Shape shape, Offset origin) {
    return shape.translation + origin + shape.transform.pivot;
  }

  Offset _snapPivotToAnchors(
    Offset worldPos,
    Rect base,
    Shape shape,
    double strength,
    double viewportScale,
  ) {
    _pivotSnapAnchorWorld = null;

    final baseThreshold = 6.0 + 12.0 * strength;
    final snapThreshold = baseThreshold / viewportScale;

    final halfW = base.width * 0.5;
    final halfH = base.height * 0.5;
    final origin = base.center;
    final matrix = shape.matrixForRect(base);

    final candidates = <Offset>[
      Offset.zero,
      Offset(halfW, 0),
      Offset(-halfW, 0),
      Offset(0, halfH),
      Offset(0, -halfH),
      Offset(halfW, halfH),
      Offset(-halfW, halfH),
      Offset(halfW, -halfH),
      Offset(-halfW, -halfH),
    ];

    Offset bestWorld = worldPos;
    double bestDist = snapThreshold;

    for (final c in candidates) {
      final localPoint = origin + c;
      final v = matrix.transform3(Vector3(localPoint.dx, localPoint.dy, 0));
      final worldCandidate = Offset(v.x, v.y);
      final d = (worldPos - worldCandidate).distance;

      if (d < bestDist) {
        bestDist = d;
        bestWorld = worldCandidate;
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
    final baseRect = shape.localBounds;
    if (baseRect == null) return null;
    final points = <Offset>[];
    if (shape.bounds != null) {
      points.addAll(transformedCorners(baseRect, shape.matrixForRect(baseRect)));
    } else if (shape.contours.isNotEmpty) {
      final matrix = shape.matrixForRect(baseRect);
      for (final contour in shape.contours) {
        for (final p in contour) {
          final v = matrix.transform3(Vector3(p.dx, p.dy, 0));
          points.add(Offset(v.x, v.y));
        }
      }
    } else if (shape.points.isNotEmpty) {
      final matrix = shape.matrixForRect(baseRect);
      for (final p in shape.points) {
        final v = matrix.transform3(Vector3(p.dx, p.dy, 0));
        points.add(Offset(v.x, v.y));
      }
    }
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

  /// Builds the context for node interaction controller.
  NodeInteractionContext _buildNodeContext(CanvasInteractionContext ctx) {
    final state = ctx.readState();
    return NodeInteractionContext(
      selectedShape: ctx.selectedShape,
      nodeEditState: state.nodeEditState,
      viewportScale: ctx.readViewportScale(),
      toCanvas: ctx.toCanvas,
      onStateChanged: ctx.onNodeStateChanged,
      onShapeUpdated: ctx.onShapeUpdated,
      onHistoryPush: ctx.onHistoryPush,
      onContourChange: ctx.viewModel.setActiveContour,
    );
  }

  /// Handles hover events for node editing.
  void handleNodeHover(CanvasInteractionContext ctx, Offset screenPosition) {
    if (ctx.activeTool != EditorTool.nodeEdit) return;
    final nodeCtx = _buildNodeContext(ctx);
    _nodeController.handleHover(nodeCtx, screenPosition);
  }

  /// Gets whether node dragging is in progress.
  bool get isNodeDragging => _nodeController.isDragging;
}

class _SpatialSelection {
  const _SpatialSelection({
    required this.spatialId,
    required this.shapes,
    required this.bounds,
    required this.corners,
  });

  final String spatialId;
  final List<Shape> shapes;
  final Rect? bounds;
  final List<Offset>? corners;
}
