import 'dart:collection';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/usecases/node_hit_test.dart';
import 'package:animation_maker/features/canvas/domain/usecases/node_operations.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_hit_result.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:flutter/gestures.dart';

/// Callback type for node edit state changes.
typedef NodeEditStateCallback = void Function(NodeEditState state);

/// Callback type for shape updates.
typedef ShapeUpdateCallback = void Function(Shape shape);

/// Callback type for history push.
typedef HistoryPushCallback = void Function();

/// Callback type for contour change.
typedef ContourChangeCallback = void Function(int contourIndex);

/// Context provided to the node interaction controller.
class NodeInteractionContext {
  const NodeInteractionContext({
    required this.selectedShape,
    required this.nodeEditState,
    required this.viewportScale,
    required this.toCanvas,
    required this.onStateChanged,
    required this.onShapeUpdated,
    required this.onHistoryPush,
    required this.onContourChange,
  });

  final Shape? selectedShape;
  final NodeEditState nodeEditState;
  final double viewportScale;
  final Offset Function(Offset screenPos) toCanvas;
  final NodeEditStateCallback onStateChanged;
  final ShapeUpdateCallback onShapeUpdated;
  final HistoryPushCallback onHistoryPush;
  final ContourChangeCallback onContourChange;

  /// Whether weighted edit mode is active for the current shape.
  bool get isWeightedEditActive => nodeEditState.useWeightedEdit;
}

/// Stores position and timestamp for velocity calculation.
class _PositionSample {
  const _PositionSample(this.position, this.timestamp);
  final Offset position;
  final Duration timestamp;
}

/// Controller for handling pointer events during node editing.
/// Follows the same pattern as CanvasInteractionController.
///
/// Includes input prediction and smoothing to improve stylus responsiveness.
/// Stylus digitizers often have slightly higher latency than capacitive touch;
/// this controller compensates by predicting movement based on velocity.
class NodeInteractionController {
  NodeInteractionController({
    NodeEditService? nodeEditService,
  }) : _nodeService = nodeEditService ?? const NodeEditService();

  final NodeEditService _nodeService;

  int? _activePointer;
  Offset? _lastDragPos;
  bool _isDragging = false;
  Set<int> _draggedNodeIndices = {};
  
  // Bezier control handle dragging state
  bool _isDraggingBezierHandle = false;
  int? _draggedBezierNodeIndex;
  BezierHandleType? _draggedBezierHandleType;
  
  // Input prediction state
  bool _isStylus = false;
  final Queue<_PositionSample> _positionHistory = Queue();
  Offset _smoothedVelocity = Offset.zero;
  
  // Tuning constants for input prediction
  static const int _maxHistorySamples = 5;
  static const double _velocitySmoothingFactor = 0.3; // Lower = smoother
  static const double _stylusPredictionMs = 12.0; // Prediction lookahead for stylus
  static const double _touchPredictionMs = 6.0; // Smaller prediction for touch

  /// Whether a drag operation is in progress.
  bool get isDragging => _isDragging || _isDraggingBezierHandle;

  /// Handles pointer down events.
  /// Returns true if the event was handled.
  bool handlePointerDown(
    NodeInteractionContext ctx,
    PointerDownEvent event,
  ) {
    final shape = ctx.selectedShape;
    if (shape == null) return false;
    if (!_nodeService.isNodeEditable(shape)) return false;

    final pos = ctx.toCanvas(event.localPosition);
    final activeContourIndex = ctx.nodeEditState.activeContourIndex;
    
    // Track if this is stylus input for prediction adjustments
    _isStylus = event.kind == PointerDeviceKind.stylus;
    
    // Reset prediction state
    _positionHistory.clear();
    _smoothedVelocity = Offset.zero;

    // First, hit test against the active contour
    // Pass selectedNodeIndices so we can hit test bezier control handles of selected nodes
    final hitResult = hitTestNodes(
      shape,
      pos,
      ctx.viewportScale,
      contourIndex: activeContourIndex,
      selectedNodeIndices: ctx.nodeEditState.selectedNodeIndices,
    );

    // If nothing hit on active contour, check if an inactive contour was clicked
    // (only in select mode - for contour switching)
    if ((hitResult == null || !hitResult.hasHit) &&
        ctx.nodeEditState.hasMultipleContours) {
      final allContoursHit = hitTestNodesOnlyAllContours(shape, pos, ctx.viewportScale);
      if (allContoursHit != null && 
          allContoursHit.hitNode && 
          allContoursHit.contourIndex != null &&
          allContoursHit.contourIndex != activeContourIndex) {
        // Clicked on an inactive contour - switch to it
        ctx.onContourChange(allContoursHit.contourIndex!);
        // Select the node we clicked on in the new contour
        ctx.onStateChanged(ctx.nodeEditState.copyWith(
          activeContourIndex: allContoursHit.contourIndex,
          selectedNodeIndices: {allContoursHit.nodeIndex!},
          clearHoveredNodeIndex: true,
          clearHoveredSegmentIndex: true,
        ));
        return true;
      }
    }

    return _handleSelectDown(ctx, event, pos, hitResult);
  }

  /// Handles pointer move events.
  /// Returns true if the event was handled.
  /// 
  /// For stylus input, applies velocity-based prediction to compensate for
  /// digitizer latency, making drags feel more responsive.
  bool handlePointerMove(
    NodeInteractionContext ctx,
    PointerMoveEvent event,
  ) {
    if (_activePointer != event.pointer) return false;
    if (!_isDragging && !_isDraggingBezierHandle) return false;

    final shape = ctx.selectedShape;
    if (shape == null) return false;

    final rawPos = ctx.toCanvas(event.localPosition);
    final timestamp = event.timeStamp;
    
    // Update position history for velocity calculation
    _positionHistory.addLast(_PositionSample(rawPos, timestamp));
    while (_positionHistory.length > _maxHistorySamples) {
      _positionHistory.removeFirst();
    }
    
    // Calculate velocity from position history
    final velocity = _calculateVelocity();
    
    // Smooth the velocity using exponential moving average
    _smoothedVelocity = Offset(
      _smoothedVelocity.dx + _velocitySmoothingFactor * (velocity.dx - _smoothedVelocity.dx),
      _smoothedVelocity.dy + _velocitySmoothingFactor * (velocity.dy - _smoothedVelocity.dy),
    );
    
    // Apply prediction based on input type
    // Stylus needs more prediction due to higher digitizer latency
    final predictionMs = _isStylus ? _stylusPredictionMs : _touchPredictionMs;
    final prediction = _smoothedVelocity * (predictionMs / 1000.0);
    
    // Combine raw position with prediction
    final predictedPos = rawPos + prediction;
    
    final delta = predictedPos - (_lastDragPos ?? predictedPos);
    _lastDragPos = predictedPos;

    if (delta == Offset.zero) return true;

    // Handle Bezier control handle dragging
    // Skip for weighted-edit-eligible shapes (merged shapes) - they use weighted editing
    if (_isDraggingBezierHandle &&
        _draggedBezierNodeIndex != null &&
        _draggedBezierHandleType != null &&
        !_nodeService.shouldHideBezierHandles(shape)) {
      Shape updated;
      if (_draggedBezierHandleType == BezierHandleType.controlIn) {
        updated = NodeOperations.moveBezierControlIn(
          shape,
          _draggedBezierNodeIndex!,
          delta,
          mirrorOpposite: true, // Mirror for smooth curves (like Adobe)
        );
      } else {
        updated = NodeOperations.moveBezierControlOut(
          shape,
          _draggedBezierNodeIndex!,
          delta,
          mirrorOpposite: true, // Mirror for smooth curves (like Adobe)
        );
      }
      ctx.onShapeUpdated(updated);
      return true;
    }

    // Move the selected nodes on the active contour
    final activeContourIndex = ctx.nodeEditState.activeContourIndex;
    final nodeState = ctx.nodeEditState;

    Shape updated;
    if (nodeState.useWeightedEdit &&
        nodeState.activeNodeIndex != null &&
        nodeState.hasArcLengths) {
      // Weighted move: affects nearby nodes with distance falloff
      updated = _nodeService.moveNodesWeighted(
        shape,
        nodeState.activeNodeIndex!,
        delta,
        arcLengths: nodeState.arcLengths,
        influenceRadius: nodeState.weightedInfluenceRadius,
        cornerIndices: nodeState.cornerIndices,
        contourIndex: activeContourIndex,
      );

    } else {
      // Standard move: only moves selected nodes
      updated = _nodeService.moveNodes(shape, _draggedNodeIndices, delta, contourIndex: activeContourIndex);
    }
    ctx.onShapeUpdated(updated);

    return true;
  }
  
  /// Calculates velocity from recent position samples (pixels per second).
  Offset _calculateVelocity() {
    if (_positionHistory.length < 2) return Offset.zero;
    
    final samples = _positionHistory.toList();
    final newest = samples.last;
    final oldest = samples.first;
    
    final dt = (newest.timestamp - oldest.timestamp).inMicroseconds / 1000000.0;
    if (dt < 0.001) return Offset.zero;
    
    final dx = newest.position.dx - oldest.position.dx;
    final dy = newest.position.dy - oldest.position.dy;
    
    return Offset(dx / dt, dy / dt);
  }

  /// Handles pointer up events.
  /// Returns true if the event was handled.
  bool handlePointerUp(
    NodeInteractionContext ctx,
    PointerUpEvent event,
  ) {
    if (_activePointer != event.pointer) return false;

    final wasDragging = _isDragging;
    final wasDraggingBezierHandle = _isDraggingBezierHandle;
    _clearDragState();

    if (wasDragging || wasDraggingBezierHandle) {
      // Push to history after drag completes
      ctx.onHistoryPush();

      // Update state to clear dragging flag
      ctx.onStateChanged(
        ctx.nodeEditState.copyWith(
          isDragging: false,
          dragStartPositions: const {},
        ),
      );
    }

    return wasDragging || wasDraggingBezierHandle;
  }

  /// Handles pointer cancel events.
  bool handlePointerCancel(
    NodeInteractionContext ctx,
    PointerCancelEvent event,
  ) {
    if (_activePointer != event.pointer) return false;

    final wasDragging = _isDragging;
    final wasDraggingBezierHandle = _isDraggingBezierHandle;
    _clearDragState();

    if (wasDragging || wasDraggingBezierHandle) {
      ctx.onStateChanged(
        ctx.nodeEditState.copyWith(
          isDragging: false,
          dragStartPositions: const {},
        ),
      );
    }

    return wasDragging || wasDraggingBezierHandle;
  }

  /// Handles hover events for visual feedback.
  void handleHover(
    NodeInteractionContext ctx,
    Offset screenPosition,
  ) {
    final shape = ctx.selectedShape;
    if (shape == null) return;

    final pos = ctx.toCanvas(screenPosition);
    final activeContourIndex = ctx.nodeEditState.activeContourIndex;
    final useWeightedEdit = ctx.nodeEditState.useWeightedEdit;

    // Hit test against the active contour only for hover feedback
    // In weighted edit mode, we also want segment hits for path interaction
    final hitResult = useWeightedEdit
        ? hitTestNodes(shape, pos, ctx.viewportScale, contourIndex: activeContourIndex)
        : hitTestNodesOnly(shape, pos, ctx.viewportScale, contourIndex: activeContourIndex);

    final newState = _nodeService.updateHover(ctx.nodeEditState, hitResult);

    if (newState != ctx.nodeEditState) {
      ctx.onStateChanged(newState);
    }
  }

  bool _handleSelectDown(
    NodeInteractionContext ctx,
    PointerDownEvent event,
    Offset canvasPos,
    NodeHitResult? hitResult,
  ) {
    final shape = ctx.selectedShape!;
    final state = ctx.nodeEditState;

    // Check if we hit a Bezier control handle
    if (hitResult != null && hitResult.hitBezierHandle) {
      // Start dragging the control handle
      _activePointer = event.pointer;
      _lastDragPos = canvasPos;
      _isDraggingBezierHandle = true;
      _draggedBezierNodeIndex = hitResult.nodeIndex;
      _draggedBezierHandleType = hitResult.bezierHandleType;
      
      ctx.onStateChanged(state.copyWith(
        isDragging: true,
      ));
      
      return true;
    }

    // In weighted edit mode, a segment hit should activate the nearest node
    if (state.useWeightedEdit && hitResult != null && hitResult.hitSegment) {
      // Map segment hit to nearest endpoint
      final segmentIndex = hitResult.segmentIndex!;
      final t = hitResult.segmentT ?? 0.5;
      // If t < 0.5, start node is closer; otherwise end node
      final nearestNodeIndex = t < 0.5 ? segmentIndex : segmentIndex + 1;
      // Clamp to valid range (for closed paths, wrap around)
      final nodeCount = _nodeService.getNodeCount(shape, contourIndex: state.activeContourIndex);
      final clampedIndex = nearestNodeIndex % nodeCount;
      
      return _startWeightedDrag(ctx, event, canvasPos, shape, state, clampedIndex);
    }

    if (hitResult == null || !hitResult.hitNode) {
      // Clicked empty space - clear selection
      if (state.selectedNodeIndices.isNotEmpty) {
        ctx.onStateChanged(state.copyWith(selectedNodeIndices: const {}));
      }
      return false;
    }

    final nodeIndex = hitResult.nodeIndex!;
    
    // In weighted edit mode, always select single node and start drag
    if (state.useWeightedEdit) {
      return _startWeightedDrag(ctx, event, canvasPos, shape, state, nodeIndex);
    }

    final isShiftPressed = event.buttons & kSecondaryMouseButton != 0;

    Set<int> newSelection;
    if (isShiftPressed) {
      // Toggle selection with shift
      if (state.selectedNodeIndices.contains(nodeIndex)) {
        newSelection = Set.from(state.selectedNodeIndices)..remove(nodeIndex);
      } else {
        newSelection = Set.from(state.selectedNodeIndices)..add(nodeIndex);
      }
    } else {
      // Replace selection unless already selected (allows dragging multiple)
      if (state.selectedNodeIndices.contains(nodeIndex)) {
        newSelection = state.selectedNodeIndices;
      } else {
        newSelection = {nodeIndex};
      }
    }

    // Start drag
    _activePointer = event.pointer;
    _lastDragPos = canvasPos;
    _isDragging = true;
    _draggedNodeIndices = Set.from(newSelection);

    if (_draggedNodeIndices.isEmpty) {
      _draggedNodeIndices = {nodeIndex};
      newSelection = {nodeIndex};
    }

    // Capture positions for undo (use active contour)
    final activeContourIndex = ctx.nodeEditState.activeContourIndex;
    final dragStartPositions = _nodeService.captureNodePositions(
      shape,
      _draggedNodeIndices,
      contourIndex: activeContourIndex,
    );

    ctx.onStateChanged(state.copyWith(
      selectedNodeIndices: newSelection,
      isDragging: true,
      dragStartPositions: dragStartPositions,
    ));

    return true;
  }

  /// Starts a weighted drag operation for a single node.
  bool _startWeightedDrag(
    NodeInteractionContext ctx,
    PointerDownEvent event,
    Offset canvasPos,
    Shape shape,
    NodeEditState state,
    int nodeIndex,
  ) {
    _activePointer = event.pointer;
    _lastDragPos = canvasPos;
    _isDragging = true;
    _draggedNodeIndices = {nodeIndex};

    // Capture all node positions for undo (weighted edit affects many nodes)
    final activeContourIndex = state.activeContourIndex;
    final nodeCount = _nodeService.getNodeCount(shape, contourIndex: activeContourIndex);
    final allIndices = Set<int>.from(List.generate(nodeCount, (i) => i));
    final dragStartPositions = _nodeService.captureNodePositions(
      shape,
      allIndices,
      contourIndex: activeContourIndex,
    );

    ctx.onStateChanged(state.copyWith(
      selectedNodeIndices: {nodeIndex},
      isDragging: true,
      dragStartPositions: dragStartPositions,
    ));

    return true;
  }

  void _clearDragState() {
    _activePointer = null;
    _lastDragPos = null;
    _isDragging = false;
    _draggedNodeIndices = {};
    // Clear bezier handle dragging state
    _isDraggingBezierHandle = false;
    _draggedBezierNodeIndex = null;
    _draggedBezierHandleType = null;
    // Clear prediction state
    _positionHistory.clear();
    _smoothedVelocity = Offset.zero;
    _isStylus = false;
  }

  /// Resets the controller state.
  void reset() {
    _clearDragState();
  }
}
