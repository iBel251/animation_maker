import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_hierarchy_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';

/// View model for parent-child linking operations.
/// Handles entering/exiting linking mode, creating links between shapes,
/// and unlinking shapes from their parents.
class LinkingModeViewModel {
  LinkingModeViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function(List<Shape> shapes) setShapesAndRebuild,
    required void Function() pushHistory,
    ShapeHierarchyService? hierarchyService,
  })  : _getState = getState,
        _setState = setState,
        _setShapesAndRebuild = setShapesAndRebuild,
        _pushHistory = pushHistory,
        _hierarchyService = hierarchyService ?? const ShapeHierarchyService();

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function(List<Shape> shapes) _setShapesAndRebuild;
  final void Function() _pushHistory;
  final ShapeHierarchyService _hierarchyService;

  /// Enters linking mode to establish parent-child relationship.
  /// The currently selected shape will become the child.
  void enterLinkingMode() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return;
    _setState(state.copyWith(
      isLinkingMode: true,
      linkingSourceShapeId: selectedId,
    ));
  }

  /// Exits linking mode without creating a relationship.
  void exitLinkingMode() {
    final state = _getState();
    _setState(state.copyWith(
      isLinkingMode: false,
      clearLinkingSource: true,
    ));
  }

  /// Completes linking by making the tapped shape the parent of the source shape.
  void completeLinking(String targetParentId) {
    final state = _getState();
    final childId = state.linkingSourceShapeId;
    if (childId == null) {
      exitLinkingMode();
      return;
    }

    // Find child and target parent shapes
    final childIndex = state.shapes.indexWhere((s) => s.id == childId);
    final parentIndex = state.shapes.indexWhere((s) => s.id == targetParentId);
    if (childIndex == -1 || parentIndex == -1) {
      exitLinkingMode();
      return;
    }

    final child = state.shapes[childIndex];
    final parent = state.shapes[parentIndex];

    final spatialId = child.spatialObjectId;
    final childrenToLink = spatialId == null
        ? [child]
        : state.shapes
            .where((s) => s.spatialObjectId == spatialId)
            .toList(growable: false);

    // Validate linking is allowed (no circular references)
    for (final candidate in childrenToLink) {
      if (!_hierarchyService.canLink(candidate, parent, state.shapes)) {
        exitLinkingMode();
        return;
      }
    }

    // Create the link(s)
    final updatedShapes = List<Shape>.from(state.shapes);
    for (final candidate in childrenToLink) {
      final idx = state.shapes.indexWhere((s) => s.id == candidate.id);
      if (idx == -1) continue;
      updatedShapes[idx] =
          _hierarchyService.linkToParent(candidate, targetParentId);
    }

    _setShapesAndRebuild(updatedShapes);
    _pushHistory();

    // Exit linking mode
    _setState(_getState().copyWith(
      isLinkingMode: false,
      clearLinkingSource: true,
    ));
  }

  /// Unlinks the currently selected shape from its parent.
  void unlinkFromParent() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return;

    final index = state.shapes.indexWhere((s) => s.id == selectedId);
    if (index == -1) return;

    final shape = state.shapes[index];
    if (shape.parentId == null) return;

    final spatialId = shape.spatialObjectId;
    final toUnlink = spatialId == null
        ? [shape]
        : state.shapes
            .where((s) => s.spatialObjectId == spatialId)
            .toList(growable: false);
    final updatedShapes = List<Shape>.from(state.shapes);
    for (final candidate in toUnlink) {
      final idx = state.shapes.indexWhere((s) => s.id == candidate.id);
      if (idx == -1) continue;
      updatedShapes[idx] = _hierarchyService.unlinkFromParent(candidate);
    }

    _setShapesAndRebuild(updatedShapes);
    _pushHistory();
  }

  /// Unlinks all children from the currently selected shape.
  void unlinkAllChildren() {
    final state = _getState();
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return;

    final shape = state.shapes.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => state.shapes.first,
    );

    final children = _hierarchyService.getChildren(shape, state.shapes);
    if (children.isEmpty) return;

    final childIds = children.map((c) => c.id).toSet();
    final updatedShapes = state.shapes.map((s) {
      if (childIds.contains(s.id)) {
        return _hierarchyService.unlinkFromParent(s);
      }
      return s;
    }).toList();

    _setShapesAndRebuild(updatedShapes);
    _pushHistory();
  }

  /// Gets the parent of the given shape, if any.
  Shape? getParentOf(Shape shape) {
    final state = _getState();
    return _hierarchyService.getParent(shape, state.shapes);
  }

  /// Gets all children of the given shape.
  List<Shape> getChildrenOf(Shape shape) {
    final state = _getState();
    return _hierarchyService.getChildren(shape, state.shapes);
  }

  /// Checks if the given shape has children.
  bool hasChildren(Shape shape) {
    final state = _getState();
    return _hierarchyService.hasChildren(shape, state.shapes);
  }
}
