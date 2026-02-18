import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:flutter/material.dart';

/// View model for node editing operations.
/// Handles entering/exiting node edit mode, node selection, movement,
/// and contour navigation.
class NodeEditViewModel {
  NodeEditViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function() pushHistory,
    required void Function() queueAutosave,
    required void Function(List<Shape> shapes,
            {String? selectedShapeId,
            List<String>? selectedShapeIds,
            bool rebuildQuadTree})
        setShapesAndRebuild,
    required void Function() rebuildQuadTree,
    required void Function(bool) setSelectionDirty,
    required String Function() nextShapeId,
    NodeEditService? nodeEditService,
  })  : _getState = getState,
        _setState = setState,
        _pushHistory = pushHistory,
        _queueAutosave = queueAutosave,
        _setShapesAndRebuild = setShapesAndRebuild,
        _rebuildQuadTree = rebuildQuadTree,
        _setSelectionDirty = setSelectionDirty,
        _nextShapeId = nextShapeId,
        _nodeEditService = nodeEditService ?? const NodeEditService();

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function() _pushHistory;
  final void Function() _queueAutosave;
  final void Function(List<Shape> shapes,
      {String? selectedShapeId,
      List<String>? selectedShapeIds,
      bool rebuildQuadTree}) _setShapesAndRebuild;
  final void Function() _rebuildQuadTree;
  final void Function(bool) _setSelectionDirty;
  final String Function() _nextShapeId;
  final NodeEditService _nodeEditService;

  /// Enters node edit mode for the currently selected shape.
  /// Returns false if no shape is selected or shape doesn't support node editing.
  bool enterNodeEditMode() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return false;

    final shape = state.shapes.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => state.shapes.first,
    );

    if (!_nodeEditService.isNodeEditable(shape)) return false;

    // Initialize node edit state with contour info
    final contourCount = _nodeEditService.getContourCount(shape);

    // Check if this shape should use weighted edit mode
    final useWeightedEdit = _nodeEditService.isWeightedEditEligible(shape);

    // If weighted edit, precompute arc-lengths and detect corners
    List<double> arcLengths = const [];
    Set<int> cornerIndices = const {};
    if (useWeightedEdit) {
      arcLengths = _nodeEditService.computeArcLengths(shape);
      // Skip corner detection for freehand — freehand sample points have many
      // incidental angle changes that aren't real corners. Treating any of them
      // as corners causes nodes to lag behind and create sharp spikes.
      if (shape.kind != ShapeKind.freehand) {
        cornerIndices = _nodeEditService.detectCorners(shape);
      }
    }

    _setState(state.copyWith(
      activeTool: EditorTool.nodeEdit,
      nodeEditState: NodeEditState.initial.copyWith(
        activeContourIndex: 0,
        totalContourCount: contourCount,
        useWeightedEdit: useWeightedEdit,
        arcLengths: arcLengths,
        cornerIndices: cornerIndices,
        weightedInfluenceRadius: arcLengths.isNotEmpty
            ? (arcLengths.last * 0.3).clamp(80.0, 600.0)
            : 100.0,
      ),
    ));
    return true;
  }

  /// Exits node edit mode and returns to select tool.
  void exitNodeEditMode() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    _setState(state.copyWith(
      activeTool: EditorTool.select,
      nodeEditState: NodeEditState.initial,
    ));
  }

  /// Checks if the currently selected shape has multiple contours.
  bool selectedShapeHasMultipleContours() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return false;

    try {
      final shape = state.shapes.firstWhere((s) => s.id == selectedId);
      return _nodeEditService.hasMultipleContours(shape);
    } catch (e) {
      return false;
    }
  }

  /// Gets the number of contours in the selected shape.
  int getSelectedShapeContourCount() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return 0;

    try {
      final shape = state.shapes.firstWhere((s) => s.id == selectedId);
      return _nodeEditService.getContourCount(shape);
    } catch (e) {
      return 0;
    }
  }

  /// Refreshes the weighted edit state for the current shape.
  void refreshWeightedEditState() {
    final state = _getState();
    if (!state.nodeEditState.useWeightedEdit) return;

    final selectedId = state.selectedShapeId;
    if (selectedId == null) return;

    try {
      final shape = state.shapes.firstWhere((s) => s.id == selectedId);
      final contourIndex = state.nodeEditState.activeContourIndex;

      final arcLengths =
          _nodeEditService.computeArcLengths(shape, contourIndex: contourIndex);
      final Set<int> cornerIndices;
      if (shape.kind == ShapeKind.freehand) {
        cornerIndices = const {};
      } else {
        cornerIndices = _nodeEditService.detectCorners(
          shape,
          contourIndex: contourIndex,
        );
      }

      _setState(state.copyWith(
        nodeEditState: state.nodeEditState.copyWith(
          arcLengths: arcLengths,
          cornerIndices: cornerIndices,
        ),
      ));
    } catch (e) {
      // Shape not found, ignore
    }
  }

  /// Explodes a multi-contour shape into separate shapes.
  bool explodeSelectedContours() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return false;

    final index = state.shapes.indexWhere((s) => s.id == selectedId);
    if (index == -1) return false;

    final shape = state.shapes[index];
    final explodedShapes =
        _nodeEditService.explodeContours(shape, _nextShapeId);
    if (explodedShapes == null || explodedShapes.isEmpty) return false;

    final updated = List<Shape>.from(state.shapes);
    updated.removeAt(index);
    updated.insertAll(index, explodedShapes);

    _setShapesAndRebuild(
      updated,
      selectedShapeId: explodedShapes.first.id,
      selectedShapeIds: explodedShapes.map((s) => s.id).toList(),
    );
    _pushHistory();
    _queueAutosave();

    return true;
  }

  /// Converts the selected rectangle or ellipse to an editable path.
  bool convertSelectedToPath() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return false;

    final shapeIndex = state.shapes.indexWhere((s) => s.id == selectedId);
    if (shapeIndex == -1) return false;

    final shape = state.shapes[shapeIndex];
    if (!_nodeEditService.canConvertToPath(shape)) return false;

    final convertedShape = _nodeEditService.convertToPath(shape);
    if (convertedShape == null) return false;

    _pushHistory();

    final newShapes = List<Shape>.from(state.shapes);
    newShapes[shapeIndex] = convertedShape;

    _setState(state.copyWith(shapes: newShapes));
    return true;
  }

  /// Converts and immediately enters node edit mode.
  bool convertAndEditNodes() {
    if (!convertSelectedToPath()) return false;
    return enterNodeEditMode();
  }

  /// Updates the node edit state.
  void updateNodeEditState(NodeEditState newState) {
    final state = _getState();
    _setState(state.copyWith(nodeEditState: newState));
  }

  /// Sets the node edit state directly.
  void setNodeEditState(NodeEditState newState) {
    final state = _getState();
    _setState(state.copyWith(nodeEditState: newState));
  }

  /// Selects the specified node indices.
  void selectNodes(Set<int> indices) {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        selectedNodeIndices: indices,
      ),
    ));
  }

  /// Toggles selection of a single node.
  void toggleNodeSelection(int index) {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final current = state.nodeEditState.selectedNodeIndices;
    final newSelection = current.contains(index)
        ? (Set<int>.from(current)..remove(index))
        : (Set<int>.from(current)..add(index));
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        selectedNodeIndices: newSelection,
      ),
    ));
  }

  /// Clears node selection.
  void clearNodeSelection() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        selectedNodeIndices: const {},
      ),
    ));
  }

  /// Selects all nodes in the current contour.
  void selectAllNodes() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return;

    final contourIndex = state.nodeEditState.activeContourIndex;
    final nodeCount =
        _nodeEditService.getNodeCount(shape, contourIndex: contourIndex);
    final allIndices = Set<int>.from(List.generate(nodeCount, (i) => i));
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        selectedNodeIndices: allIndices,
      ),
    ));
  }

  /// Moves selected nodes by a world-space delta.
  void moveSelectedNodes(Offset delta) {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return;

    final indices = state.nodeEditState.selectedNodeIndices;
    if (indices.isEmpty) return;

    final contourIndex = state.nodeEditState.activeContourIndex;
    final updated = _nodeEditService.moveNodes(shape, indices, delta,
        contourIndex: contourIndex);
    _applyNodeEditedShape(updated);
  }

  /// Sets the active contour index for node editing.
  void setActiveContour(int contourIndex) {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return;

    final contourCount = _nodeEditService.getContourCount(shape);
    if (contourIndex < 0 || contourIndex >= contourCount) return;

    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        activeContourIndex: contourIndex,
        selectedNodeIndices: const {},
        clearHoveredNodeIndex: true,
        clearHoveredSegmentIndex: true,
      ),
    ));
  }

  /// Navigates to the next contour.
  void nextContour() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return;

    final contourCount = _nodeEditService.getContourCount(shape);
    if (contourCount <= 1) return;

    final current = state.nodeEditState.activeContourIndex;
    final next = (current + 1) % contourCount;
    setActiveContour(next);
  }

  /// Navigates to the previous contour.
  void previousContour() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return;

    final contourCount = _nodeEditService.getContourCount(shape);
    if (contourCount <= 1) return;

    final current = state.nodeEditState.activeContourIndex;
    final prev = (current - 1 + contourCount) % contourCount;
    setActiveContour(prev);
  }

  /// Gets the current active contour index.
  int getActiveContourIndex() {
    return _getState().nodeEditState.activeContourIndex;
  }

  /// Called when starting a node drag operation.
  void beginNodeDrag(Map<int, Offset> startPositions) {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        isDragging: true,
        dragStartPositions: startPositions,
      ),
    ));
  }

  /// Called when ending a node drag operation.
  void endNodeDrag() {
    final state = _getState();
    if (!state.isNodeEditMode) return;
    if (state.nodeEditState.isDragging) {
      _pushHistory();
    }
    _setState(state.copyWith(
      nodeEditState: state.nodeEditState.copyWith(
        isDragging: false,
        dragStartPositions: const {},
      ),
    ));
    _rebuildQuadTree();
  }

  /// Gets the point count of the currently selected shape.
  int? getSelectedShapePointCount() {
    final shape = _selectedShapeForNodeEdit();
    if (shape == null) return null;
    return shape.points.length;
  }

  /// Checks if a shape supports node editing.
  bool canEnterNodeEditMode(Shape? shape) {
    if (shape == null) return false;
    return _nodeEditService.isNodeEditable(shape);
  }

  /// Public method for updating a single shape (used by node editing).
  void updateShape(Shape updated) {
    _applyNodeEditedShape(updated);
  }

  /// Gets the currently selected shape for node editing.
  Shape? _selectedShapeForNodeEdit() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return null;
    try {
      return state.shapes.firstWhere((s) => s.id == selectedId);
    } catch (_) {
      return null;
    }
  }

  /// Applies an edited shape to the shapes list.
  void _applyNodeEditedShape(Shape updated) {
    final state = _getState();
    final index = state.shapes.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;

    _setSelectionDirty(true);
    final newShapes = List<Shape>.from(state.shapes);
    newShapes[index] = updated;
    _setShapesAndRebuild(newShapes, rebuildQuadTree: false);

    // Validate activeContourIndex after shape update
    final currentState = _getState();
    if (currentState.isNodeEditMode) {
      final contourCount = _nodeEditService.getContourCount(updated);
      final currentIndex = currentState.nodeEditState.activeContourIndex;
      if (currentIndex >= contourCount) {
        _setState(currentState.copyWith(
          nodeEditState: currentState.nodeEditState.copyWith(
            activeContourIndex: (contourCount - 1).clamp(0, contourCount - 1),
            totalContourCount: contourCount,
            selectedNodeIndices: const {},
          ),
        ));
      } else if (currentState.nodeEditState.totalContourCount != contourCount) {
        _setState(currentState.copyWith(
          nodeEditState: currentState.nodeEditState.copyWith(
            totalContourCount: contourCount,
          ),
        ));
      }
    }
  }
}
