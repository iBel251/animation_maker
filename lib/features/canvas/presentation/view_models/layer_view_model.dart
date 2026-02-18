import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/services/layer_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';

/// View model for layer management operations.
/// Encapsulates layer logic and delegates to LayerService for business logic.
class LayerViewModel {
  LayerViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function() pushHistory,
    required void Function() queueAutosave,
    required Future<void> Function({required String layerId, required int frameIndex}) loadFrame,
    required String Function() nextLayerId,
    required String Function() nextShapeId,
  })  : _getState = getState,
        _setState = setState,
        _pushHistory = pushHistory,
        _queueAutosave = queueAutosave,
        _loadFrame = loadFrame,
        _nextLayerId = nextLayerId,
        _nextShapeId = nextShapeId;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function() _pushHistory;
  final void Function() _queueAutosave;
  final Future<void> Function({required String layerId, required int frameIndex}) _loadFrame;
  final String Function() _nextLayerId;
  final String Function() _nextShapeId;

  final LayerService _service = const LayerService();

  /// Renames a layer.
  void renameLayer(String layerId, String newName) {
    final state = _getState();
    final result = _service.renameLayer(state.document, layerId, newName);
    if (result == null) return;

    _setState(state.copyWith(document: result));
    _pushHistory();
    _queueAutosave();
  }

  /// Deletes a layer. Cannot delete the last layer.
  Future<void> deleteLayer(String layerId) async {
    final state = _getState();
    final result = _service.deleteLayer(
      state.document,
      layerId,
      state.activeLayerId,
    );
    if (result == null) return;

    final (nextDoc, newActiveId) = result;
    _setState(state.copyWith(document: nextDoc));

    // If active layer changed, load the new layer's frame
    if (newActiveId != state.activeLayerId) {
      await _loadFrame(layerId: newActiveId, frameIndex: state.currentFrame);
    }

    _pushHistory();
    _queueAutosave();
  }

  /// Duplicates a layer with all its frames and shapes.
  Future<void> duplicateLayer(String layerId) async {
    final state = _getState();
    final (nextDoc, newLayerId) = _service.duplicateLayer(
      state.document,
      layerId,
      _nextLayerId,
      _nextShapeId,
    );

    if (newLayerId.isEmpty) return;

    _setState(state.copyWith(document: nextDoc));
    _pushHistory();
    _queueAutosave();
  }

  /// Reorders layers by moving from oldIndex to newIndex.
  void reorderLayers(int oldIndex, int newIndex) {
    final state = _getState();
    final result = _service.reorderLayers(state.document, oldIndex, newIndex);
    if (result == null) return;

    _setState(state.copyWith(document: result));
    _pushHistory();
    _queueAutosave();
  }

  /// Merges a layer with the layer below it.
  Future<void> mergeLayerDown(String layerId) async {
    final state = _getState();
    final result = _service.mergeLayerDown(state.document, layerId);
    if (result == null) return;

    final (nextDoc, targetLayerId) = result;
    _setState(state.copyWith(document: nextDoc));

    // If the merged layer was active, switch to the target layer
    if (layerId == state.activeLayerId) {
      await _loadFrame(layerId: targetLayerId, frameIndex: state.currentFrame);
    }

    _pushHistory();
    _queueAutosave();
  }

  /// Sets a layer's opacity (0.0 to 1.0).
  void setLayerOpacity(String layerId, double opacity) {
    final state = _getState();
    final result = _service.setLayerOpacity(state.document, layerId, opacity);
    if (result == null) return;

    _setState(state.copyWith(document: result));
    // Don't push history for every slider change, just autosave
    _queueAutosave();
  }

  /// Sets a layer's blend mode.
  void setLayerBlendMode(String layerId, BlendMode blendMode) {
    final state = _getState();
    final result = _service.setLayerBlendMode(state.document, layerId, blendMode);
    if (result == null) return;

    _setState(state.copyWith(document: result));
    _pushHistory();
    _queueAutosave();
  }

  /// Checks if a shape's layer is locked.
  bool isShapeLayerLocked(String shapeId) {
    final state = _getState();
    return _service.isLayerLockedForShape(state.document, shapeId);
  }

  /// Checks if a specific layer is locked.
  bool isLayerLocked(String layerId) {
    final state = _getState();
    return _service.isLayerLocked(state.document, layerId);
  }

  /// Finds the layer ID that contains a given shape.
  String? findLayerIdForShape(String shapeId) {
    final state = _getState();
    return _service.findLayerIdForShape(state.document, shapeId);
  }
}
