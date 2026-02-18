import 'dart:math' as math;

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/services/clipboard_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_grouping_service.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_merge_service.dart';
import 'package:flutter/material.dart';

/// View model for managing shape operations (grouping, merging, clipboard)
class ShapeOperationsViewModel {
  ShapeOperationsViewModel({
    required ShapeGroupingService shapeGroupingService,
    required ShapeMergeService shapeMergeService,
    required EditorClipboard clipboard,
  })  : _shapeGroupingService = shapeGroupingService,
        _shapeMergeService = shapeMergeService,
        _clipboard = clipboard;

  final ShapeGroupingService _shapeGroupingService;
  final ShapeMergeService _shapeMergeService;
  final EditorClipboard _clipboard;

  /// Async version of mergeSelectedIds that uses Isolate for heavy operations.
  ///
  /// Returns a stream of states: first with isProcessingHeavyOperation=true,
  /// then the final state with merged shapes.
  Stream<EditorState> mergeSelectedIdsAsync({
    required EditorState state,
    required List<String> selectedIds,
    required String Function() nextShapeId,
  }) async* {
    if (selectedIds.length < 2) {
      yield state;
      return;
    }

    // Emit processing state
    yield state.copyWith(isProcessingHeavyOperation: true);

    // Run merge operation (uses isolate for 3+ shapes)
    final result = await _shapeMergeService.mergeAsync(
      shapes: state.shapes,
      selectedIds: selectedIds,
      createId: nextShapeId,
      strokeScaleWithShape: state.strokeScaleWithShape,
      brushSmoothness: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.smoothness
          : state.brushSettings[state.currentBrush]!.smoothness,
    );

    if (result.mergedShapes.isEmpty || result.removedIds.isEmpty) {
      yield state.copyWith(isProcessingHeavyOperation: false);
      return;
    }

    final removeSet = result.removedIds.toSet();
    final updated = <Shape>[];
    var insertAt = -1;
    for (var i = 0; i < state.shapes.length; i++) {
      final shape = state.shapes[i];
      if (removeSet.contains(shape.id)) {
        insertAt = math.max(insertAt, i);
        continue;
      }
      updated.add(shape);
    }
    if (insertAt < 0) {
      yield state.copyWith(isProcessingHeavyOperation: false);
      return;
    }
    final insertIndex = math.min(insertAt, updated.length);
    updated.insertAll(insertIndex, result.mergedShapes);

    final mergedIds =
        result.mergedShapes.map((shape) => shape.id).toList(growable: false);
    yield state.copyWith(
      shapes: updated,
      selectedShapeId: null,
      selectedShapeIds: mergedIds,
      isProcessingHeavyOperation: false,
    );
  }

  EditorState mergeSelectedIds({
    required EditorState state,
    required List<String> selectedIds,
    required String Function() nextShapeId,
  }) {
    if (selectedIds.length < 2) return state;
    final result = _shapeMergeService.merge(
      shapes: state.shapes,
      selectedIds: selectedIds,
      createId: nextShapeId,
      strokeScaleWithShape: state.strokeScaleWithShape,
      brushSmoothness: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.smoothness
          : state.brushSettings[state.currentBrush]!.smoothness,
    );
    if (result.mergedShapes.isEmpty || result.removedIds.isEmpty) {
      return state;
    }

    final removeSet = result.removedIds.toSet();
    final updated = <Shape>[];
    var insertAt = -1;
    for (var i = 0; i < state.shapes.length; i++) {
      final shape = state.shapes[i];
      if (removeSet.contains(shape.id)) {
        insertAt = math.max(insertAt, i);
        continue;
      }
      updated.add(shape);
    }
    if (insertAt < 0) return state;
    final insertIndex = math.min(insertAt, updated.length);
    updated.insertAll(insertIndex, result.mergedShapes);

    final mergedIds =
        result.mergedShapes.map((shape) => shape.id).toList(growable: false);
    return state.copyWith(
      shapes: updated,
      selectedShapeId: null,
      selectedShapeIds: mergedIds,
    );
  }

  EditorState groupSelection({
    required EditorState state,
    required List<String> selectedShapeIds,
  }) {
    final updatedShapes = _shapeGroupingService.groupSelectedShapes(
      allShapes: state.shapes,
      selectedShapeIds: selectedShapeIds,
    );
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState ungroupSelection({
    required EditorState state,
    required List<String> selectedShapeIds,
  }) {
    final updatedShapes = _shapeGroupingService.ungroupSelectedShapes(
      allShapes: state.shapes,
      selectedShapeIds: selectedShapeIds,
    );
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState updateSelectedStroke({
    required EditorState state,
    required List<int> selectedIndices,
    double? strokeWidth,
    Color? strokeColor,
  }) {
    if (selectedIndices.isEmpty) return state;

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final index in selectedIndices) {
      final target = state.shapes[index];
      updatedShapes[index] = target.copyWith(
        strokeWidth: strokeWidth ?? target.strokeWidth,
        strokeColor: strokeColor ?? target.strokeColor,
      );
    }
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState updateSelectedFill({
    required EditorState state,
    required List<int> selectedIndices,
    Color? fillColor,
  }) {
    if (selectedIndices.isEmpty) return state;

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final index in selectedIndices) {
      final target = state.shapes[index];
      updatedShapes[index] = target.copyWith(fillColor: fillColor);
    }
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState updateSelectedBounds({
    required EditorState state,
    required int selectedIndex,
    double? x,
    double? y,
    double? width,
    double? height,
    required Rect? Function(Shape) shapeBounds,
  }) {
    if (selectedIndex == -1) return state;
    final target = state.shapes[selectedIndex];
    final existingBounds = target.bounds ?? shapeBounds(target);
    if (existingBounds == null) return state;

    final newWidth = (width ?? existingBounds.width)
        .clamp(0, double.infinity)
        .toDouble();
    final newHeight = (height ?? existingBounds.height)
        .clamp(0, double.infinity)
        .toDouble();
    final newRect = Rect.fromLTWH(
      x ?? existingBounds.left,
      y ?? existingBounds.top,
      newWidth,
      newHeight,
    );

    Shape updated;
    if (target.bounds != null) {
      updated = target.copyWith(bounds: newRect);
    } else {
      final delta = newRect.topLeft - existingBounds.topLeft;
      if (target.contours.isNotEmpty) {
        final shiftedContours = target.contours
            .map(
              (c) => c.map((p) => p + delta).toList(growable: false),
            )
            .toList(growable: false);
        updated = target.copyWith(
          points: shiftedContours.first,
          contours: shiftedContours,
          pointPressures: _preservePointPressures(target, shiftedContours.first),
        );
      } else {
        final shiftedPoints = target.points
            .map((p) => p + delta)
            .toList(growable: false);
        updated = target.copyWith(
          points: shiftedPoints,
          pointPressures: _preservePointPressures(target, shiftedPoints),
        );
      }
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[selectedIndex] = updated;
    return state.copyWith(shapes: updatedShapes);
  }

  EditorState copySelection({
    required EditorState state,
    required List<Shape> selectedShapes,
  }) {
    if (selectedShapes.isEmpty) return state;
    _clipboard.copyShapes(selectedShapes);
    return state.copyWith(); // Emit state copy to refresh listeners
  }

  EditorState pasteClipboard({
    required EditorState state,
    required String Function() nextShapeId,
  }) {
    if (!_clipboard.hasContent) return state;
    final clones = _clipboard.pasteClones(
      nextShapeId,
      offset: const Offset(16, 16),
    );
    if (clones.isEmpty) return state;
    final updated = [...state.shapes, ...clones];
    return state.copyWith(
      shapes: updated,
      selectedShapeId: clones.last.id,
    );
  }

  EditorState duplicateSelected({
    required EditorState state,
    required List<Shape> selectedShapes,
    required String Function() nextShapeId,
  }) {
    if (selectedShapes.isEmpty) return state;
    final newGroupId = selectedShapes.first.groupId != null
        ? _shapeGroupingService.nextGroupId()
        : null;
    final clones = selectedShapes
        .map(
          (shape) => shape.copyWith(
            id: nextShapeId(),
            groupId: newGroupId,
            bounds: shape.bounds?.shift(const Offset(16, 16)),
            points: shape.contours.isNotEmpty
                ? shape.contours
                    .first
                    .map((p) => p + const Offset(16, 16))
                    .toList()
                : shape.points.isNotEmpty
                    ? shape.points.map((p) => p + const Offset(16, 16)).toList()
                    : shape.points.toList(),
            contours: shape.contours.isNotEmpty
                ? shape.contours
                    .map(
                      (c) => c
                          .map((p) => p + const Offset(16, 16))
                          .toList(growable: false),
                    )
                    .toList(growable: false)
                : null,
            pointPressures: shape.pointPressures?.toList(growable: false),
          ),
        )
        .toList(growable: false);
    final updated = [...state.shapes, ...clones];
    return state.copyWith(
      shapes: updated,
      selectedShapeId: clones.last.id,
    );
  }

  EditorState deleteSelected({
    required EditorState state,
    required List<int> selectedIndices,
  }) {
    if (selectedIndices.isEmpty) return state;
    final updated = List<Shape>.from(state.shapes);
    selectedIndices
      ..sort((a, b) => b.compareTo(a))
      ..forEach(updated.removeAt);
    return state.copyWith(
      shapes: updated,
      clearSelection: true,
      selectedShapeId: null,
    );
  }

  EditorState deleteSelectedIds({
    required EditorState state,
    required List<String> selectedIds,
  }) {
    if (selectedIds.isEmpty) return state;
    final idSet = selectedIds.toSet();
    final updated = state.shapes
        .where((shape) => !idSet.contains(shape.id))
        .toList(growable: false);
    return state.copyWith(
      shapes: updated,
      clearSelection: true,
      selectedShapeId: null,
    );
  }

  EditorState deleteShapes({
    required EditorState state,
    required List<String> ids,
  }) {
    if (ids.isEmpty) return state;
    final idSet = ids.toSet();
    final updated = state.shapes
        .where((shape) => !idSet.contains(shape.id))
        .toList(growable: false);
    return state.copyWith(
      shapes: updated,
      clearSelection: true,
      selectedShapeId: null,
    );
  }

  bool get canPaste => _clipboard.hasContent;

  List<double>? _preservePointPressures(Shape shape, List<Offset>? points) {
    final pressures = shape.pointPressures;
    if (pressures == null || points == null) return null;
    if (pressures.length != points.length) return null;
    return pressures.toList(growable: false);
  }
}
