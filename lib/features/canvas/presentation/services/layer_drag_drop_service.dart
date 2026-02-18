enum LayerDragItemType { shape, group, layer }

class LayerDragData {
  const LayerDragData._({
    required this.type,
    required this.layerId,
    this.shapeId,
    this.groupId,
    this.shapeIds = const [],
    this.layerIndex,
  });

  const LayerDragData.shape({
    required String shapeId,
    required String layerId,
    String? groupId,
  }) : this._(
          type: LayerDragItemType.shape,
          layerId: layerId,
          shapeId: shapeId,
          groupId: groupId,
        );

  const LayerDragData.group({
    required String groupId,
    required String layerId,
    List<String> shapeIds = const [],
  }) : this._(
          type: LayerDragItemType.group,
          layerId: layerId,
          groupId: groupId,
          shapeIds: shapeIds,
        );

  const LayerDragData.layer({
    required String layerId,
    required int layerIndex,
  }) : this._(
          type: LayerDragItemType.layer,
          layerId: layerId,
          layerIndex: layerIndex,
        );

  final LayerDragItemType type;
  final String layerId;
  final String? shapeId;
  final String? groupId;
  final List<String> shapeIds;
  final int? layerIndex;
}

class LayerDragDropService {
  const LayerDragDropService();

  bool canDropOnLayer(LayerDragData data, String targetLayerId) {
    if (data.type == LayerDragItemType.group) {
      return data.layerId != targetLayerId;
    }
    return true;
  }

  bool canDropOnGroup(LayerDragData data, String targetGroupId) {
    if (data.type != LayerDragItemType.shape) return false;
    return data.groupId != targetGroupId;
  }

  bool canDropOnShape(LayerDragData data, String targetShapeId) {
    if (data.type != LayerDragItemType.shape) return false;
    return data.shapeId != targetShapeId;
  }

  /// Validates if a layer can be dropped at the target index.
  /// Returns false if:
  /// - Data is not a layer drag
  /// - layerIndex is null
  /// - Target index is out of bounds
  /// - Dropping at the same position (no-op)
  bool canDropLayerAt(LayerDragData data, int targetIndex, int totalLayers) {
    if (data.type != LayerDragItemType.layer) return false;
    if (data.layerIndex == null) return false;
    if (targetIndex < 0 || targetIndex > totalLayers) return false;
    // Cannot drop at the same position or the position right after (no change)
    return targetIndex != data.layerIndex && targetIndex != data.layerIndex! + 1;
  }
}
