import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/spatial_object.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';

/// View model for spatial object operations.
/// Handles spatial draw mode, creating and managing spatial objects,
/// and attaching shapes to spatial objects.
class SpatialObjectViewModel {
  SpatialObjectViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required String Function() nextSpatialId,
  }) : _getState = getState,
       _setState = setState,
       _nextSpatialId = nextSpatialId;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final String Function() _nextSpatialId;

  /// Toggles spatial draw mode on/off.
  /// Only works when the brush tool is active.
  void toggleSpatialDrawMode() {
    final state = _getState();
    if (state.activeTool != EditorTool.brush) return;
    if (state.isSpatialDrawMode) {
      _setState(
        state.copyWith(
          isSpatialDrawMode: false,
          clearActiveSpatialObjectId: true,
        ),
      );
      return;
    }
    final spatialId = _nextSpatialId();
    final spatial = SpatialObject(
      id: spatialId,
      layerId: state.activeLayerId,
      childShapeIds: const [],
      strokeColor: state.currentColor,
      strokeWidth: state.brushSettings[state.currentBrush]!.thickness,
      opacity: state.brushSettings[state.currentBrush]!.opacity,
    );
    final updated = [...state.spatialObjects, spatial];
    _setState(
      state.copyWith(
        isSpatialDrawMode: true,
        spatialObjects: updated,
        activeSpatialObjectId: spatialId,
      ),
    );
  }

  /// Sets spatial draw mode to a specific value.
  /// Only works when the brush tool is active.
  void setSpatialDrawMode(bool value) {
    final state = _getState();
    if (state.activeTool != EditorTool.brush) return;
    if (state.isSpatialDrawMode == value) return;
    if (!value) {
      _setState(
        state.copyWith(
          isSpatialDrawMode: false,
          clearActiveSpatialObjectId: true,
        ),
      );
      return;
    }
    final spatialId = _nextSpatialId();
    final spatial = SpatialObject(
      id: spatialId,
      layerId: state.activeLayerId,
      childShapeIds: const [],
      strokeColor: state.currentColor,
      strokeWidth: state.brushSettings[state.currentBrush]!.thickness,
      opacity: state.brushSettings[state.currentBrush]!.opacity,
    );
    _setState(
      state.copyWith(
        isSpatialDrawMode: true,
        spatialObjects: [...state.spatialObjects, spatial],
        activeSpatialObjectId: spatialId,
      ),
    );
  }

  /// Starts editing an existing spatial object by enabling spatial draw mode
  /// and targeting the provided spatial object ID.
  ///
  /// Returns false when the brush tool is not active or the spatial object
  /// does not exist.
  bool startEditingSpatialObject(String spatialId) {
    final state = _getState();
    if (state.activeTool != EditorTool.brush) return false;
    final exists = state.spatialObjects.any(
      (spatial) => spatial.id == spatialId,
    );
    if (!exists) return false;

    _setState(
      state.copyWith(
        isSpatialDrawMode: true,
        activeSpatialObjectId: spatialId,
        clearSelection: true,
      ),
    );
    return true;
  }

  /// Ensures there's an active spatial object ID, creating one if needed.
  /// Returns null if not in spatial draw mode.
  String? ensureActiveSpatialObjectId() {
    final state = _getState();
    if (!state.isSpatialDrawMode) return null;
    var spatialId = state.activeSpatialObjectId;
    if (spatialId != null) return spatialId;
    spatialId = _nextSpatialId();
    final created = SpatialObject(
      id: spatialId,
      layerId: state.activeLayerId,
      childShapeIds: const [],
      strokeColor: state.currentColor,
      strokeWidth: state.brushSettings[state.currentBrush]!.thickness,
      opacity: state.brushSettings[state.currentBrush]!.opacity,
    );
    _setState(
      state.copyWith(
        spatialObjects: [...state.spatialObjects, created],
        activeSpatialObjectId: spatialId,
      ),
    );
    return spatialId;
  }

  /// Attaches shapes to a spatial object by their IDs.
  void attachShapesToSpatial(String spatialId, List<Shape> shapes) {
    if (shapes.isEmpty) return;
    final state = _getState();
    final index = state.spatialObjects.indexWhere((s) => s.id == spatialId);
    if (index == -1) return;
    final spatial = state.spatialObjects[index];
    final updatedSpatial = spatial.copyWith(
      childShapeIds: [...spatial.childShapeIds, ...shapes.map((s) => s.id)],
    );
    final updated = List<SpatialObject>.from(state.spatialObjects);
    updated[index] = updatedSpatial;
    _setState(state.copyWith(spatialObjects: updated));
  }

  /// Exits spatial draw mode (used when switching tools).
  void exitSpatialDrawMode() {
    final state = _getState();
    if (!state.isSpatialDrawMode) return;
    _setState(
      state.copyWith(
        isSpatialDrawMode: false,
        clearActiveSpatialObjectId: true,
      ),
    );
  }
}
