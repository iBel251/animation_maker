import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Pure business logic for layer operations.
/// All methods are stateless and return new document instances.
class LayerService {
  const LayerService();

  /// Renames a layer in the document.
  /// Returns null if layer not found.
  CanvasDocument? renameLayer(
    CanvasDocument doc,
    String layerId,
    String newName,
  ) {
    final layer = doc.layerById(layerId);
    if (layer == null) return null;

    final updated = layer.copyWith(name: newName);
    return doc.upsertLayer(updated).copyWith(updatedAt: DateTime.now());
  }

  /// Removes a layer from the document.
  /// Returns null if this is the last layer (cannot delete).
  /// Returns the new active layer ID as the second element of the record.
  (CanvasDocument, String newActiveId)? deleteLayer(
    CanvasDocument doc,
    String layerId,
    String currentActiveLayerId,
  ) {
    if (doc.layers.length <= 1) return null;

    final layers = doc.layers.where((l) => l.id != layerId).toList();
    final nextDoc = doc.copyWith(
      layers: layers,
      updatedAt: DateTime.now(),
    );

    // Determine new active layer if we deleted the active one
    final newActiveId = layerId == currentActiveLayerId
        ? layers.first.id
        : currentActiveLayerId;

    return (nextDoc, newActiveId);
  }

  /// Deep copies a layer with all frames and shapes.
  /// Generates new IDs for the layer and all shapes.
  /// Inserts the new layer after the source layer.
  (CanvasDocument, String newLayerId) duplicateLayer(
    CanvasDocument doc,
    String layerId,
    String Function() nextLayerId,
    String Function() nextShapeId,
  ) {
    final sourceLayer = doc.layerById(layerId);
    if (sourceLayer == null) {
      return (doc, '');
    }

    final newId = nextLayerId();
    final newName = '${sourceLayer.name} Copy';

    // Deep copy all frames with new shape IDs
    final newFrames = <int, CanvasFrame>{};
    final shapeIdMap = <String, String>{}; // old ID -> new ID

    for (final entry in sourceLayer.frames.entries) {
      final frameIndex = entry.key;
      final sourceFrame = entry.value;
      final newShapes = <Shape>[];

      for (final shape in sourceFrame.shapes) {
        final newShapeId = nextShapeId();
        shapeIdMap[shape.id] = newShapeId;

        // Update groupId and parentId references if they point to shapes in this layer
        String? newGroupId = shape.groupId;
        String? newParentId = shape.parentId;

        if (newGroupId != null && shapeIdMap.containsKey(newGroupId)) {
          newGroupId = shapeIdMap[newGroupId];
        }
        if (newParentId != null && shapeIdMap.containsKey(newParentId)) {
          newParentId = shapeIdMap[newParentId];
        }

        newShapes.add(shape.copyWith(
          id: newShapeId,
          groupId: newGroupId,
          parentId: newParentId,
        ));
      }

      newFrames[frameIndex] = CanvasFrame(
        index: frameIndex,
        shapes: newShapes,
      );
    }

    final newLayer = CanvasLayer(
      id: newId,
      name: newName,
      frames: newFrames,
      isVisible: sourceLayer.isVisible,
      isLocked: sourceLayer.isLocked,
      opacity: sourceLayer.opacity,
      blendMode: sourceLayer.blendMode,
    );

    // Insert after source layer
    final layers = List<CanvasLayer>.from(doc.layers);
    final sourceIndex = layers.indexWhere((l) => l.id == layerId);
    layers.insert(sourceIndex + 1, newLayer);

    final nextDoc = doc.copyWith(
      layers: layers,
      updatedAt: DateTime.now(),
    );

    return (nextDoc, newId);
  }

  /// Reorders layers by moving a layer from oldIndex to newIndex.
  /// Returns null if indices are invalid or the same.
  CanvasDocument? reorderLayers(
    CanvasDocument doc,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return null;
    if (oldIndex < 0 || oldIndex >= doc.layers.length) return null;
    if (newIndex < 0 || newIndex > doc.layers.length) return null;

    final layers = List<CanvasLayer>.from(doc.layers);
    final layer = layers.removeAt(oldIndex);

    // Adjust insert index if moving down
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    layers.insert(insertIndex, layer);

    return doc.copyWith(
      layers: layers,
      updatedAt: DateTime.now(),
    );
  }

  /// Merges a layer with the layer below it.
  /// Returns null if layer is at the bottom or not found.
  /// Returns the merged layer's ID as the second element.
  (CanvasDocument, String targetLayerId)? mergeLayerDown(
    CanvasDocument doc,
    String layerId,
  ) {
    final layerIndex = doc.layers.indexWhere((l) => l.id == layerId);
    if (layerIndex == -1) return null;
    if (layerIndex == doc.layers.length - 1) return null; // Already at bottom

    final topLayer = doc.layers[layerIndex];
    final bottomLayer = doc.layers[layerIndex + 1];

    // Merge frames: shapes from top layer go on top of bottom layer shapes
    final mergedFrames = Map<int, CanvasFrame>.from(bottomLayer.frames);

    for (final entry in topLayer.frames.entries) {
      final frameIndex = entry.key;
      final topShapes = entry.value.shapes;
      final bottomFrame =
          mergedFrames[frameIndex] ?? CanvasFrame(index: frameIndex);

      // Top layer shapes render on top, so they come after bottom shapes
      final mergedShapes = [...bottomFrame.shapes, ...topShapes];
      mergedFrames[frameIndex] = CanvasFrame(
        index: frameIndex,
        shapes: mergedShapes,
      );
    }

    final mergedLayer = bottomLayer.copyWith(frames: mergedFrames);

    final layers = List<CanvasLayer>.from(doc.layers);
    layers.removeAt(layerIndex); // Remove top layer
    layers[layerIndex] = mergedLayer; // Replace bottom layer with merged

    final nextDoc = doc.copyWith(
      layers: layers,
      updatedAt: DateTime.now(),
    );

    return (nextDoc, bottomLayer.id);
  }

  /// Updates a layer's opacity.
  /// Returns null if layer not found.
  CanvasDocument? setLayerOpacity(
    CanvasDocument doc,
    String layerId,
    double opacity,
  ) {
    final layer = doc.layerById(layerId);
    if (layer == null) return null;

    final updated = layer.copyWith(opacity: opacity.clamp(0.0, 1.0));
    return doc.upsertLayer(updated).copyWith(updatedAt: DateTime.now());
  }

  /// Updates a layer's blend mode.
  /// Returns null if layer not found.
  CanvasDocument? setLayerBlendMode(
    CanvasDocument doc,
    String layerId,
    BlendMode blendMode,
  ) {
    final layer = doc.layerById(layerId);
    if (layer == null) return null;

    final updated = layer.copyWith(blendMode: blendMode);
    return doc.upsertLayer(updated).copyWith(updatedAt: DateTime.now());
  }

  /// Finds the layer that contains a shape with the given ID.
  /// Searches across all frames in all layers.
  /// Returns null if shape not found.
  String? findLayerIdForShape(CanvasDocument doc, String shapeId) {
    for (final layer in doc.layers) {
      for (final frame in layer.frames.values) {
        if (frame.shapes.any((s) => s.id == shapeId)) {
          return layer.id;
        }
      }
    }
    return null;
  }

  /// Checks if the layer containing the given shape is locked.
  /// Returns false if shape or layer not found.
  bool isLayerLockedForShape(CanvasDocument doc, String shapeId) {
    final layerId = findLayerIdForShape(doc, shapeId);
    if (layerId == null) return false;

    final layer = doc.layerById(layerId);
    return layer?.isLocked ?? false;
  }

  /// Checks if a specific layer is locked.
  bool isLayerLocked(CanvasDocument doc, String layerId) {
    final layer = doc.layerById(layerId);
    return layer?.isLocked ?? false;
  }
}
