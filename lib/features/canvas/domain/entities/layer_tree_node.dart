import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

enum LayerTreeNodeType { layer, group, shape, spatial }

abstract class LayerTreeNode {
  LayerTreeNode({
    required this.id,
    required this.name,
    required this.type,
    required this.children,
    this.order = 0,
    this.isExpanded = true,
    this.isVisible = true,
    this.isLocked = false,
  });

  final String id;
  final String name;
  final LayerTreeNodeType type;
  final List<LayerTreeNode> children;
  final int order;
  final bool isExpanded;
  final bool isVisible;
  final bool isLocked;
}

class LayerNode extends LayerTreeNode {
  LayerNode({
    required this.layer,
    required List<LayerTreeNode> children,
    int order = 0,
    bool isExpanded = true,
  }) : super(
          id: layer.id,
          name: layer.name,
          type: LayerTreeNodeType.layer,
          children: children,
          order: order,
          isExpanded: isExpanded,
          isVisible: layer.isVisible,
          isLocked: layer.isLocked,
        );

  final CanvasLayer layer;
}

class GroupNode extends LayerTreeNode {
  GroupNode({
    required this.groupId,
    required this.layerId,
    required String name,
    required List<LayerTreeNode> children,
    int order = 0,
    bool isExpanded = true,
    bool isVisible = true,
    bool isLocked = false,
  }) : super(
          id: groupId,
          name: name,
          type: LayerTreeNodeType.group,
          children: children,
          order: order,
          isExpanded: isExpanded,
          isVisible: isVisible,
          isLocked: isLocked,
        );

  final String groupId;
  final String layerId;
}

class ShapeNode extends LayerTreeNode {
  ShapeNode({
    required this.shape,
    required this.layerId,
    required String name,
    this.depth = 0,
    int order = 0,
  }) : super(
          id: shape.id,
          name: name,
          type: LayerTreeNodeType.shape,
          children: const [],
          order: order,
          isExpanded: false,
          isVisible: shape.isVisible,
          isLocked: shape.isLocked,
        );

  final Shape shape;
  final String layerId;
  final int depth;
}

class SpatialNode extends LayerTreeNode {
  SpatialNode({
    required this.spatialId,
    required this.layerId,
    required String name,
    required this.childShapeIds,
    int order = 0,
  }) : super(
          id: spatialId,
          name: name,
          type: LayerTreeNodeType.spatial,
          children: const [],
          order: order,
          isExpanded: false,
          isVisible: true,
          isLocked: false,
        );

  final String spatialId;
  final String layerId;
  final List<String> childShapeIds;
}
