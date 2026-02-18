import 'package:flutter/material.dart';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/selection_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/selection_utils.dart';

/// View model for managing selection operations
class SelectionViewModel {
  SelectionViewModel({
    required SelectionService selectionService,
    required SelectionUtils selectionUtils,
  })  : _selectionService = selectionService,
        _selectionUtils = selectionUtils;

  final SelectionService _selectionService;
  final SelectionUtils _selectionUtils;

  EditorState selectShape(EditorState state, String? shapeId) {
    if (shapeId != null) {
      final expanded = _expandSpatialSelection(state.shapes, [shapeId]);
      if (expanded.length > 1) {
        return state.copyWith(
          selectedShapeId: shapeId,
          selectedShapeIds: expanded,
          clearSelection: false,
        );
      }
    }
    return state.copyWith(
      selectedShapeId: shapeId,
      selectedShapeIds: shapeId != null ? [shapeId] : const [],
      clearSelection: shapeId == null,
    );
  }

  EditorState setSelection(EditorState state, List<String> ids) {
    final expanded = _expandSpatialSelection(state.shapes, ids);
    final change = _selectionService.setSelection(expanded);
    return state.copyWith(
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  EditorState setSelectionMode(EditorState state, SelectionMode mode) {
    final change = _selectionService.setSelectionMode(
      _selectionContext(state),
      mode,
    );
    return state.copyWith(
      selectionMode: mode,
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  EditorState selectAtPoint(
    EditorState state,
    Offset point,
    QuadTree quadTree, {
    required double viewportScale,
  }) {
    final change = _selectionService.selectAtPoint(
      _selectionContext(state),
      point,
      quadTree,
      viewportScale: viewportScale,
    );
    if (change.selectedShapeId != null) {
      final expanded = _expandSpatialSelection(
        state.shapes,
        [change.selectedShapeId!],
      );
      if (expanded.length > 1) {
        return state.copyWith(
          selectedShapeId: change.selectedShapeId,
          selectedShapeIds: expanded,
          clearSelection: false,
        );
      }
    }
    return state.copyWith(
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
  }

  Shape? topShapeAtPoint(
    EditorState state,
    Offset point,
    QuadTree quadTree, {
    required double viewportScale,
  }) {
    return _selectionService.topShapeAtPoint(
      state.shapes,
      point,
      quadTree,
      viewportScale: viewportScale,
    );
  }

  List<int> selectedGroupIndices(EditorState state) {
    return _selectionUtils.selectedGroupIndices(
      state.shapes,
      state.selectedShapeId,
    );
  }

  List<Shape> selectedGroupShapes(EditorState state) {
    return _selectionUtils.selectedGroupShapes(
      state.shapes,
      state.selectedShapeId,
    );
  }

  SelectionContext _selectionContext(EditorState state) => SelectionContext(
    shapes: state.shapes,
    selectionMode: state.selectionMode,
    selectedShapeId: state.selectedShapeId,
    selectedShapeIds: state.selectedShapeIds,
  );

  List<String> _expandSpatialSelection(List<Shape> shapes, List<String> ids) {
    if (ids.isEmpty) return const [];
    final byId = {for (final shape in shapes) shape.id: shape};
    final expanded = <String>{};
    for (final id in ids) {
      final shape = byId[id];
      if (shape == null) continue;
      final spatialId = shape.spatialObjectId;
      if (spatialId == null) {
        expanded.add(id);
      } else {
        for (final s in shapes) {
          if (s.spatialObjectId == spatialId) {
            expanded.add(s.id);
          }
        }
      }
    }
    return expanded.toList(growable: false);
  }
}
