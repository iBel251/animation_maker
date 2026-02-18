import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/layer_tree_node.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/spatial_object.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/services/layer_drag_drop_service.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/layer_context_sheet.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/two_finger_draggable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LayersPanel extends ConsumerWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorViewModelProvider);
    final vm = ref.read(editorViewModelProvider.notifier);
    final theme = Theme.of(context);
    final nodes = _buildLayerNodes(
      state.document,
      state.currentFrame,
      groupNames: state.groupNames,
      spatialObjects: state.spatialObjects,
    );
    final dragDrop = const LayerDragDropService();
    return Container(
      color: AppColors.grey100,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Row(
              children: [
                Text(
                  'Layers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${nodes.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  tooltip: 'Add Layer',
                  onPressed: () => vm.addLayer(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ExpansionTileTheme(
                data: ExpansionTileThemeData(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: const EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  itemCount: nodes.length * 2 + 1,
                  itemBuilder: (context, index) {
                    if (index.isEven) {
                      final targetIndex = index ~/ 2;
                      return _LayerDropIndicator(
                        targetIndex: targetIndex,
                        totalLayers: nodes.length,
                        dragDrop: dragDrop,
                        onReorderLayers: vm.reorderLayers,
                      );
                    }

                    final node = nodes[index ~/ 2];
                    return _LayerNodeTile(
                      node: node,
                      layerIndex: index ~/ 2,
                      totalLayers: nodes.length,
                      isActive: node.layer.id == state.activeLayerId,
                      selectedShapeId: state.selectedShapeId,
                      onActivateLayer: vm.setActiveLayer,
                      onSelectShape: vm.selectShape,
                      onToggleLayerVisibility: vm.toggleLayerVisibility,
                      onToggleLayerLock: vm.toggleLayerLock,
                      onToggleShapeVisibility: vm.toggleShapeVisibility,
                      onToggleShapeLock: vm.toggleShapeLock,
                      onMoveShapeToLayer: vm.moveShapeToLayer,
                      onMoveShapeToLayerAtIndex: vm.moveShapeToLayerAtIndex,
                      onMoveShapeWithinGroupAtIndex:
                          vm.moveShapeWithinGroupAtIndex,
                      onMoveShapeToGroup: vm.moveShapeToGroup,
                      onCreateGroupFromShapes: vm.createGroupFromShapes,
                      onMoveGroupToLayer: vm.moveGroupToLayer,
                      onDeleteShape: vm.deleteShape,
                      onDuplicateShape: vm.duplicateShape,
                      onRenameShape: vm.renameShape,
                      onUngroupShapes: vm.ungroupShapes,
                      onDeleteGroup: vm.deleteGroup,
                      onDuplicateGroup: vm.duplicateGroup,
                      onRenameGroup: vm.renameGroup,
                      onRenameLayer: vm.renameLayer,
                      onDeleteLayer: vm.deleteLayer,
                      onDuplicateLayer: vm.duplicateLayer,
                      onMergeLayerDown: vm.mergeLayerDown,
                      onSetLayerOpacity: vm.setLayerOpacity,
                      onSetLayerBlendMode: vm.setLayerBlendMode,
                      dragDrop: dragDrop,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<LayerNode> _buildLayerNodes(
    CanvasDocument document,
    int frameIndex, {
    Map<String, String> groupNames = const {},
    List<SpatialObject> spatialObjects = const [],
  }) {
    final nodes = <LayerNode>[];
    for (
      var layerIndex = 0;
      layerIndex < document.layers.length;
      layerIndex++
    ) {
      final layer = document.layers[layerIndex];
      final shapes = layer.frameAt(frameIndex).shapes;
      final spatialInLayer = spatialObjects
          .where((spatial) => spatial.layerId == layer.id)
          .toList(growable: false);
      final grouped = <String, List<Shape>>{};
      final ungrouped = <Shape>[];

      final orderById = <String, int>{
        for (var i = 0; i < shapes.length; i++) shapes[i].id: i,
      };

      final spatialNodes = <SpatialNode>[];
      final spatialChildIds = <String>{};
      for (final spatial in spatialInLayer) {
        final childIds = spatial.childShapeIds
            .where(orderById.containsKey)
            .toList(growable: false);
        if (childIds.isEmpty) {
          continue;
        }
        spatialChildIds.addAll(childIds);
        final order = childIds
            .map((id) => orderById[id] ?? 0)
            .fold<int>(
              orderById[childIds.first] ?? 0,
              (min, value) => value < min ? value : min,
            );
        spatialNodes.add(
          SpatialNode(
            spatialId: spatial.id,
            layerId: spatial.layerId,
            name: spatial.name ?? 'Spatial ${spatial.id}',
            childShapeIds: childIds,
            order: order,
          ),
        );
      }

      for (var i = 0; i < shapes.length; i++) {
        final shape = shapes[i];
        if (spatialChildIds.contains(shape.id)) {
          continue;
        }
        final groupId = shape.groupId;
        if (groupId == null) {
          ungrouped.add(shape);
        } else {
          grouped.putIfAbsent(groupId, () => []).add(shape);
        }
      }

      final groupNodes = grouped.entries
          .map((entry) {
            final groupId = entry.key;
            final members = entry.value;
            final order = members
                .map((s) => orderById[s.id] ?? 0)
                .fold<int>(
                  members.isNotEmpty ? (orderById[members.first.id] ?? 0) : 0,
                  (min, value) => value < min ? value : min,
                );
            return GroupNode(
              groupId: groupId,
              layerId: layer.id,
              name: groupNames[groupId] ?? 'Group $groupId',
              order: order,
              isExpanded: true,
              isVisible: members.any((s) => s.isVisible),
              isLocked: members.every((s) => s.isLocked),
              children: _buildShapeTreeNodes(members, layer.id, orderById),
            );
          })
          .toList(growable: false);

      final shapeBlocks = _buildShapeTreeBlocks(ungrouped, layer.id, orderById);

      final blocks = <_ShapeTreeBlock>[
        for (final group in groupNodes)
          _ShapeTreeBlock(order: group.order, nodes: [group]),
        for (final spatial in spatialNodes)
          _ShapeTreeBlock(order: spatial.order, nodes: [spatial]),
        ...shapeBlocks,
      ]..sort((a, b) => a.order.compareTo(b.order));

      final children = <LayerTreeNode>[];
      for (final block in blocks) {
        children.addAll(block.nodes);
      }

      nodes.add(LayerNode(layer: layer, order: layerIndex, children: children));
    }
    return nodes;
  }

  String _shapeDisplayName(Shape shape) {
    if (shape.name != null && shape.name!.trim().isNotEmpty) {
      return shape.name!;
    }
    switch (shape.kind) {
      case ShapeKind.rectangle:
        return 'Rectangle';
      case ShapeKind.ellipse:
        return 'Ellipse';
      case ShapeKind.line:
        return 'Line';
      case ShapeKind.polygon:
        return 'Polygon';
      case ShapeKind.freehand:
        return 'Freehand';
      case ShapeKind.pointPath:
        return 'Point Path';
      case ShapeKind.image:
        return 'Image';
    }
  }

  List<ShapeNode> _buildShapeTreeNodes(
    List<Shape> shapes,
    String layerId,
    Map<String, int> orderById,
  ) {
    if (shapes.isEmpty) return const [];
    final byId = {for (final shape in shapes) shape.id: shape};
    final childrenByParent = <String, List<Shape>>{};
    final roots = <Shape>[];

    for (final shape in shapes) {
      final parentId = shape.parentId;
      if (parentId != null && byId.containsKey(parentId)) {
        (childrenByParent[parentId] ??= <Shape>[]).add(shape);
      } else {
        roots.add(shape);
      }
    }

    int compareOrder(Shape a, Shape b) {
      final oa = orderById[a.id] ?? 0;
      final ob = orderById[b.id] ?? 0;
      return oa.compareTo(ob);
    }

    roots.sort(compareOrder);
    for (final entry in childrenByParent.entries) {
      entry.value.sort(compareOrder);
    }

    final nodes = <ShapeNode>[];
    final visiting = <String>{};

    void addNode(Shape shape, int depth) {
      if (visiting.contains(shape.id)) {
        return;
      }
      visiting.add(shape.id);
      nodes.add(
        ShapeNode(
          shape: shape,
          layerId: layerId,
          name: _shapeDisplayName(shape),
          order: orderById[shape.id] ?? 0,
          depth: depth,
        ),
      );
      final children = childrenByParent[shape.id];
      if (children != null) {
        for (final child in children) {
          addNode(child, depth + 1);
        }
      }
      visiting.remove(shape.id);
    }

    for (final root in roots) {
      addNode(root, 0);
    }

    return nodes;
  }

  List<_ShapeTreeBlock> _buildShapeTreeBlocks(
    List<Shape> shapes,
    String layerId,
    Map<String, int> orderById,
  ) {
    if (shapes.isEmpty) return const [];
    final byId = {for (final shape in shapes) shape.id: shape};
    final childrenByParent = <String, List<Shape>>{};
    final roots = <Shape>[];

    for (final shape in shapes) {
      final parentId = shape.parentId;
      if (parentId != null && byId.containsKey(parentId)) {
        (childrenByParent[parentId] ??= <Shape>[]).add(shape);
      } else {
        roots.add(shape);
      }
    }

    int compareOrder(Shape a, Shape b) {
      final oa = orderById[a.id] ?? 0;
      final ob = orderById[b.id] ?? 0;
      return oa.compareTo(ob);
    }

    roots.sort(compareOrder);
    for (final entry in childrenByParent.entries) {
      entry.value.sort(compareOrder);
    }

    List<ShapeNode> buildSubtree(Shape shape, int depth, Set<String> visiting) {
      if (visiting.contains(shape.id)) {
        return const [];
      }
      visiting.add(shape.id);
      final nodes = <ShapeNode>[
        ShapeNode(
          shape: shape,
          layerId: layerId,
          name: _shapeDisplayName(shape),
          order: orderById[shape.id] ?? 0,
          depth: depth,
        ),
      ];
      final children = childrenByParent[shape.id];
      if (children != null) {
        for (final child in children) {
          nodes.addAll(buildSubtree(child, depth + 1, visiting));
        }
      }
      visiting.remove(shape.id);
      return nodes;
    }

    final blocks = <_ShapeTreeBlock>[];
    for (final root in roots) {
      blocks.add(
        _ShapeTreeBlock(
          order: orderById[root.id] ?? 0,
          nodes: buildSubtree(root, 0, <String>{}),
        ),
      );
    }
    return blocks;
  }
}

class _ShapeTreeBlock {
  const _ShapeTreeBlock({required this.order, required this.nodes});

  final int order;
  final List<LayerTreeNode> nodes;
}

class _LayerDropIndicator extends StatelessWidget {
  const _LayerDropIndicator({
    required this.targetIndex,
    required this.totalLayers,
    required this.dragDrop,
    required this.onReorderLayers,
  });

  final int targetIndex;
  final int totalLayers;
  final LayerDragDropService dragDrop;
  final void Function(int oldIndex, int newIndex) onReorderLayers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<LayerDragData>(
      onWillAccept: (data) =>
          data != null &&
          dragDrop.canDropLayerAt(data, targetIndex, totalLayers),
      onAccept: (data) {
        final oldIndex = data.layerIndex;
        if (oldIndex == null) return;
        onReorderLayers(oldIndex, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActive ? 12 : 8,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: isActive ? 3 : 1,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withOpacity(0.9)
                  : theme.dividerColor.withOpacity(0.28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _LayerNodeTile extends StatelessWidget {
  const _LayerNodeTile({
    required this.node,
    required this.layerIndex,
    required this.totalLayers,
    required this.isActive,
    required this.selectedShapeId,
    required this.onActivateLayer,
    required this.onSelectShape,
    required this.onToggleLayerVisibility,
    required this.onToggleLayerLock,
    required this.onToggleShapeVisibility,
    required this.onToggleShapeLock,
    required this.onMoveShapeToLayer,
    required this.onMoveShapeToLayerAtIndex,
    required this.onMoveShapeWithinGroupAtIndex,
    required this.onMoveShapeToGroup,
    required this.onCreateGroupFromShapes,
    required this.onMoveGroupToLayer,
    required this.onDeleteShape,
    required this.onDuplicateShape,
    required this.onRenameShape,
    required this.onUngroupShapes,
    required this.onDeleteGroup,
    required this.onDuplicateGroup,
    required this.onRenameGroup,
    required this.onRenameLayer,
    required this.onDeleteLayer,
    required this.onDuplicateLayer,
    required this.onMergeLayerDown,
    required this.onSetLayerOpacity,
    required this.onSetLayerBlendMode,
    required this.dragDrop,
  });

  final LayerNode node;
  final int layerIndex;
  final int totalLayers;
  final bool isActive;
  final String? selectedShapeId;
  final Future<void> Function(String layerId) onActivateLayer;
  final void Function(String? shapeId) onSelectShape;
  final void Function(String layerId) onToggleLayerVisibility;
  final void Function(String layerId) onToggleLayerLock;
  final void Function(String shapeId) onToggleShapeVisibility;
  final void Function(String shapeId) onToggleShapeLock;
  final void Function(String shapeId, String targetLayerId) onMoveShapeToLayer;
  final void Function(
    String shapeId,
    String targetLayerId,
    int index, {
    bool clearGroup,
  })
  onMoveShapeToLayerAtIndex;
  final void Function(
    String targetLayerId,
    String groupId,
    String shapeId,
    int index,
  )
  onMoveShapeWithinGroupAtIndex;
  final void Function(String shapeId, String? groupId) onMoveShapeToGroup;
  final void Function(List<String> shapeIds) onCreateGroupFromShapes;
  final void Function(String groupId, String targetLayerId) onMoveGroupToLayer;
  final void Function(String shapeId) onDeleteShape;
  final void Function(String shapeId) onDuplicateShape;
  final void Function(String shapeId, String newName) onRenameShape;
  final void Function(String groupId) onUngroupShapes;
  final void Function(String groupId) onDeleteGroup;
  final void Function(String groupId) onDuplicateGroup;
  final void Function(String groupId, String newName) onRenameGroup;
  final void Function(String layerId, String newName) onRenameLayer;
  final Future<void> Function(String layerId) onDeleteLayer;
  final Future<void> Function(String layerId) onDuplicateLayer;
  final Future<void> Function(String layerId) onMergeLayerDown;
  final void Function(String layerId, double opacity) onSetLayerOpacity;
  final void Function(String layerId, BlendMode blendMode) onSetLayerBlendMode;
  final LayerDragDropService dragDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<LayerDragData>(
      onWillAccept: (data) {
        if (data == null) return false;
        if (data.type == LayerDragItemType.group) {
          return dragDrop.canDropOnLayer(data, node.layer.id);
        }
        if (data.type == LayerDragItemType.shape) {
          return data.shapeId != null &&
              dragDrop.canDropOnLayer(data, node.layer.id);
        }
        return false;
      },
      onAccept: (data) {
        if (data.type == LayerDragItemType.group) {
          onMoveGroupToLayer(data.groupId!, node.layer.id);
        } else if (data.type == LayerDragItemType.shape &&
            data.shapeId != null) {
          onMoveShapeToLayer(data.shapeId!, node.layer.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bg = isActive
            ? theme.colorScheme.primary.withOpacity(0.08)
            : theme.colorScheme.surface;
        final layerDragData = LayerDragData.layer(
          layerId: node.layer.id,
          layerIndex: layerIndex,
        );
        return ExpansionTile(
          initiallyExpanded: node.isExpanded,
          backgroundColor: candidateData.isNotEmpty
              ? theme.colorScheme.primary.withOpacity(0.08)
              : bg,
          collapsedBackgroundColor: bg,
          title: InkWell(
            onTap: () => onActivateLayer(node.layer.id),
            onLongPress: () => showLayerContextMenu(
              context,
              layer: node.layer,
              layerIndex: layerIndex,
              totalLayers: totalLayers,
              onRename: onRenameLayer,
              onDuplicate: (id) => onDuplicateLayer(id),
              onDelete: (id) => onDeleteLayer(id),
              onMergeDown: (id) => onMergeLayerDown(id),
              onSetOpacity: onSetLayerOpacity,
              onSetBlendMode: onSetLayerBlendMode,
            ),
            child: Row(
              children: [
                LongPressDraggable<LayerDragData>(
                  data: layerDragData,
                  feedback: _DragGhost(label: node.name),
                  childWhenDragging: Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color:
                        (isActive
                                ? theme.colorScheme.primary
                                : theme.iconTheme.color)
                            ?.withOpacity(0.35),
                  ),
                  child: Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.iconTheme.color,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                _VerticalIconStack(
                  children: [
                    _TinyIconButton(
                      tooltip: node.layer.isVisible
                          ? 'Hide layer'
                          : 'Show layer',
                      onPressed: () => onToggleLayerVisibility(node.layer.id),
                      icon: node.layer.isVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    _TinyIconButton(
                      tooltip: node.layer.isLocked
                          ? 'Unlock layer'
                          : 'Lock layer',
                      onPressed: () => onToggleLayerLock(node.layer.id),
                      icon: node.layer.isLocked ? Icons.lock : Icons.lock_open,
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            _LayerChildrenList(
              layerId: node.layer.id,
              children: node.children,
              selectedShapeId: selectedShapeId,
              onActivateLayer: onActivateLayer,
              onSelectShape: onSelectShape,
              onToggleShapeVisibility: onToggleShapeVisibility,
              onToggleShapeLock: onToggleShapeLock,
              onMoveShapeToLayer: onMoveShapeToLayer,
              onMoveShapeToLayerAtIndex: onMoveShapeToLayerAtIndex,
              onMoveShapeWithinGroupAtIndex: onMoveShapeWithinGroupAtIndex,
              onMoveShapeToGroup: onMoveShapeToGroup,
              onCreateGroupFromShapes: onCreateGroupFromShapes,
              onMoveGroupToLayer: onMoveGroupToLayer,
              onDeleteShape: onDeleteShape,
              onDuplicateShape: onDuplicateShape,
              onRenameShape: onRenameShape,
              onUngroupShapes: onUngroupShapes,
              onDeleteGroup: onDeleteGroup,
              onDuplicateGroup: onDuplicateGroup,
              onRenameGroup: onRenameGroup,
              dragDrop: dragDrop,
            ),
          ],
        );
      },
    );
  }
}

class _LayerChildrenList extends StatelessWidget {
  const _LayerChildrenList({
    required this.layerId,
    required this.children,
    required this.selectedShapeId,
    required this.onActivateLayer,
    required this.onSelectShape,
    required this.onToggleShapeVisibility,
    required this.onToggleShapeLock,
    required this.onMoveShapeToLayer,
    required this.onMoveShapeToLayerAtIndex,
    required this.onMoveShapeWithinGroupAtIndex,
    required this.onMoveShapeToGroup,
    required this.onCreateGroupFromShapes,
    required this.onMoveGroupToLayer,
    required this.onDeleteShape,
    required this.onDuplicateShape,
    required this.onRenameShape,
    required this.onUngroupShapes,
    required this.onDeleteGroup,
    required this.onDuplicateGroup,
    required this.onRenameGroup,
    required this.dragDrop,
  });

  final String layerId;
  final List<LayerTreeNode> children;
  final String? selectedShapeId;
  final Future<void> Function(String layerId) onActivateLayer;
  final void Function(String? shapeId) onSelectShape;
  final void Function(String shapeId) onToggleShapeVisibility;
  final void Function(String shapeId) onToggleShapeLock;
  final void Function(String shapeId, String targetLayerId) onMoveShapeToLayer;
  final void Function(
    String shapeId,
    String targetLayerId,
    int index, {
    bool clearGroup,
  })
  onMoveShapeToLayerAtIndex;
  final void Function(
    String targetLayerId,
    String groupId,
    String shapeId,
    int index,
  )
  onMoveShapeWithinGroupAtIndex;
  final void Function(String shapeId, String? groupId) onMoveShapeToGroup;
  final void Function(List<String> shapeIds) onCreateGroupFromShapes;
  final void Function(String groupId, String targetLayerId) onMoveGroupToLayer;
  final void Function(String shapeId) onDeleteShape;
  final void Function(String shapeId) onDuplicateShape;
  final void Function(String shapeId, String newName) onRenameShape;
  final void Function(String groupId) onUngroupShapes;
  final void Function(String groupId) onDeleteGroup;
  final void Function(String groupId) onDuplicateGroup;
  final void Function(String groupId, String newName) onRenameGroup;
  final LayerDragDropService dragDrop;

  @override
  Widget build(BuildContext context) {
    final ordered = List<LayerTreeNode>.from(children);
    final widgets = <Widget>[];
    for (var i = 0; i <= ordered.length; i++) {
      final targetIndex = i == ordered.length
          ? ordered.length
          : ordered[i].order;
      widgets.add(
        _DropIndicator(
          onAccept: (data) {
            if (data.type != LayerDragItemType.shape || data.shapeId == null)
              return;
            onMoveShapeToLayerAtIndex(
              data.shapeId!,
              layerId,
              targetIndex,
              clearGroup: true,
            );
          },
        ),
      );
      if (i < ordered.length) {
        widgets.add(
          _TreeNodeTile(
            node: ordered[i],
            selectedShapeId: selectedShapeId,
            onActivateLayer: onActivateLayer,
            onSelectShape: onSelectShape,
            onToggleShapeVisibility: onToggleShapeVisibility,
            onToggleShapeLock: onToggleShapeLock,
            onMoveShapeToLayer: onMoveShapeToLayer,
            onMoveShapeToLayerAtIndex: onMoveShapeToLayerAtIndex,
            onMoveShapeWithinGroupAtIndex: onMoveShapeWithinGroupAtIndex,
            onMoveShapeToGroup: onMoveShapeToGroup,
            onCreateGroupFromShapes: onCreateGroupFromShapes,
            onMoveGroupToLayer: onMoveGroupToLayer,
            onDeleteShape: onDeleteShape,
            onDuplicateShape: onDuplicateShape,
            onRenameShape: onRenameShape,
            onUngroupShapes: onUngroupShapes,
            onDeleteGroup: onDeleteGroup,
            onDuplicateGroup: onDuplicateGroup,
            onRenameGroup: onRenameGroup,
            dragDrop: dragDrop,
          ),
        );
      }
    }
    return Column(children: widgets);
  }
}

class _TreeNodeTile extends StatelessWidget {
  const _TreeNodeTile({
    required this.node,
    required this.selectedShapeId,
    required this.onActivateLayer,
    required this.onSelectShape,
    required this.onToggleShapeVisibility,
    required this.onToggleShapeLock,
    required this.onMoveShapeToLayer,
    required this.onMoveShapeToLayerAtIndex,
    required this.onMoveShapeWithinGroupAtIndex,
    required this.onMoveShapeToGroup,
    required this.onCreateGroupFromShapes,
    required this.onMoveGroupToLayer,
    required this.onDeleteShape,
    required this.onDuplicateShape,
    required this.onRenameShape,
    required this.onUngroupShapes,
    required this.onDeleteGroup,
    required this.onDuplicateGroup,
    required this.onRenameGroup,
    required this.dragDrop,
  });

  final LayerTreeNode node;
  final String? selectedShapeId;
  final Future<void> Function(String layerId) onActivateLayer;
  final void Function(String? shapeId) onSelectShape;
  final void Function(String shapeId) onToggleShapeVisibility;
  final void Function(String shapeId) onToggleShapeLock;
  final void Function(String shapeId, String targetLayerId) onMoveShapeToLayer;
  final void Function(
    String shapeId,
    String targetLayerId,
    int index, {
    bool clearGroup,
  })
  onMoveShapeToLayerAtIndex;
  final void Function(
    String targetLayerId,
    String groupId,
    String shapeId,
    int index,
  )
  onMoveShapeWithinGroupAtIndex;
  final void Function(String shapeId, String? groupId) onMoveShapeToGroup;
  final void Function(List<String> shapeIds) onCreateGroupFromShapes;
  final void Function(String groupId, String targetLayerId) onMoveGroupToLayer;
  final void Function(String shapeId) onDeleteShape;
  final void Function(String shapeId) onDuplicateShape;
  final void Function(String shapeId, String newName) onRenameShape;
  final void Function(String groupId) onUngroupShapes;
  final void Function(String groupId) onDeleteGroup;
  final void Function(String groupId) onDuplicateGroup;
  final void Function(String groupId, String newName) onRenameGroup;
  final LayerDragDropService dragDrop;

  @override
  Widget build(BuildContext context) {
    if (node is GroupNode) {
      final group = node as GroupNode;
      final memberCount = group.children.whereType<ShapeNode>().length;
      final ordered = List<LayerTreeNode>.from(group.children)
        ..sort((a, b) => a.order.compareTo(b.order));
      return DragTarget<LayerDragData>(
        onWillAccept: (data) =>
            data != null && dragDrop.canDropOnGroup(data, group.groupId),
        onAccept: (data) {
          if (data.type == LayerDragItemType.shape) {
            onMoveShapeToGroup(data.shapeId!, group.groupId);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final groupDragData = LayerDragData.group(
            groupId: group.groupId,
            layerId: group.layerId,
            shapeIds: group.children
                .whereType<ShapeNode>()
                .map((s) => s.shape.id)
                .toList(growable: false),
          );
          return Padding(
            padding: const EdgeInsets.only(left: 2),
            child: TwoFingerDraggable<LayerDragData>(
              data: groupDragData,
              feedback: _DragGhost(label: group.name),
              onDragEnd: (globalPosition) {
                // Drop handled by DragTarget widgets
              },
              child: ExpansionTile(
                initiallyExpanded: group.isExpanded,
                backgroundColor: candidateData.isNotEmpty
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                    : null,
                title: Row(
                  children: [
                    LongPressDraggable<LayerDragData>(
                      data: groupDragData,
                      feedback: _DragGhost(label: group.name),
                      child: const Icon(Icons.drag_indicator, size: 18),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.folder_shared_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () => _showGroupContextMenu(
                          context,
                          groupId: group.groupId,
                          groupName: group.name,
                          onUngroup: onUngroupShapes,
                          onDelete: onDeleteGroup,
                          onDuplicate: onDuplicateGroup,
                          onRename: onRenameGroup,
                        ),
                        child: Text(
                          group.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$memberCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  _GroupChildrenList(
                    targetLayerId: group.layerId,
                    groupId: group.groupId,
                    ordered: ordered,
                    selectedShapeId: selectedShapeId,
                    onActivateLayer: onActivateLayer,
                    onSelectShape: onSelectShape,
                    onToggleShapeVisibility: onToggleShapeVisibility,
                    onToggleShapeLock: onToggleShapeLock,
                    onMoveShapeToLayer: onMoveShapeToLayer,
                    onMoveShapeToLayerAtIndex: onMoveShapeToLayerAtIndex,
                    onMoveShapeWithinGroupAtIndex:
                        onMoveShapeWithinGroupAtIndex,
                    onMoveShapeToGroup: onMoveShapeToGroup,
                    onCreateGroupFromShapes: onCreateGroupFromShapes,
                    onMoveGroupToLayer: onMoveGroupToLayer,
                    onDeleteShape: onDeleteShape,
                    onDuplicateShape: onDuplicateShape,
                    onRenameShape: onRenameShape,
                    onUngroupShapes: onUngroupShapes,
                    onDeleteGroup: onDeleteGroup,
                    onDuplicateGroup: onDuplicateGroup,
                    onRenameGroup: onRenameGroup,
                    dragDrop: dragDrop,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (node is SpatialNode) {
      final spatial = node as SpatialNode;
      final isSelected =
          selectedShapeId != null &&
          spatial.childShapeIds.contains(selectedShapeId);
      // Use first child shape for drag data so spatial can be moved to layers
      final spatialDragData = spatial.childShapeIds.isNotEmpty
          ? LayerDragData.shape(
              shapeId: spatial.childShapeIds.first,
              layerId: spatial.layerId,
            )
          : null;
      final tile = ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        tileColor: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : null,
        selected: isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.14),
        dense: true,
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 20,
        leading: const Icon(Icons.grid_view_outlined, size: 18),
        title: Text(
          spatial.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        onTap: () async {
          await onActivateLayer(spatial.layerId);
          if (spatial.childShapeIds.isNotEmpty) {
            onSelectShape(spatial.childShapeIds.first);
          }
        },
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${spatial.childShapeIds.length}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      // Wrap with TwoFingerDraggable if we have child shapes
      if (spatialDragData != null) {
        return TwoFingerDraggable<LayerDragData>(
          data: spatialDragData,
          feedback: _DragGhost(label: spatial.name),
          onDragEnd: (globalPosition) {
            // Drop handled by DragTarget widgets
          },
          child: tile,
        );
      }
      return tile;
    }

    if (node is ShapeNode) {
      final shapeNode = node as ShapeNode;
      final shape = shapeNode.shape;
      final isSelected = selectedShapeId == shape.id;
      final indent = 16.0 + (shapeNode.depth * 14.0);
      return DragTarget<LayerDragData>(
        onWillAccept: (data) =>
            data != null && dragDrop.canDropOnShape(data, shape.id),
        onAccept: (data) {
          if (data.type == LayerDragItemType.shape) {
            if (shape.groupId != null) {
              onMoveShapeToGroup(data.shapeId!, shape.groupId);
            } else {
              onCreateGroupFromShapes([shape.id, data.shapeId!]);
            }
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          final dragData = LayerDragData.shape(
            shapeId: shape.id,
            layerId: shapeNode.layerId,
            groupId: shape.groupId,
          );
          return TwoFingerDraggable<LayerDragData>(
            data: dragData,
            feedback: _DragGhost(label: shapeNode.name),
            onDragEnd: (globalPosition) {
              // Find the DragTarget at the drop position
              // The drop will be handled by the DragTarget widgets
            },
            child: ListTile(
              contentPadding: EdgeInsets.only(left: indent, right: 4),
              tileColor: isHovering
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.16)
                  : (isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null),
              selected: isSelected,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.14),
              dense: true,
              visualDensity: VisualDensity.compact,
              minLeadingWidth: 20,
              leading: LongPressDraggable<LayerDragData>(
                data: dragData,
                feedback: _DragGhost(label: shapeNode.name),
                child: const Icon(Icons.drag_indicator, size: 18),
              ),
              title: GestureDetector(
                onLongPress: () => _showShapeContextMenu(
                  context,
                  shapeId: shape.id,
                  shapeName: shapeNode.name,
                  onRename: onRenameShape,
                  onDuplicate: onDuplicateShape,
                  onDelete: onDeleteShape,
                ),
                child: Text(
                  shapeNode.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              onTap: () async {
                await onActivateLayer(shapeNode.layerId);
                onSelectShape(shape.id);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VerticalIconStack(
                    children: [
                      _TinyIconButton(
                        tooltip: shape.isVisible ? 'Hide shape' : 'Show shape',
                        onPressed: () => onToggleShapeVisibility(shape.id),
                        icon: shape.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      _TinyIconButton(
                        tooltip: shape.isLocked ? 'Unlock shape' : 'Lock shape',
                        onPressed: () => onToggleShapeLock(shape.id),
                        icon: shape.isLocked ? Icons.lock : Icons.lock_open,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

String _shapeKindLabel(ShapeKind kind) {
  switch (kind) {
    case ShapeKind.rectangle:
      return 'Rectangle';
    case ShapeKind.ellipse:
      return 'Ellipse';
    case ShapeKind.line:
      return 'Line';
    case ShapeKind.polygon:
      return 'Polygon';
    case ShapeKind.freehand:
      return 'Freehand';
    case ShapeKind.pointPath:
      return 'Point Path';
    case ShapeKind.image:
      return 'Image';
  }
}

void _showShapeContextMenu(
  BuildContext context, {
  required String shapeId,
  required String shapeName,
  required void Function(String shapeId, String newName) onRename,
  required void Function(String shapeId) onDuplicate,
  required void Function(String shapeId) onDelete,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(ctx).pop();
              _showRenameDialog(context, shapeId, shapeName, onRename);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.of(ctx).pop();
              onDuplicate(shapeId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(ctx).pop();
              onDelete(shapeId);
            },
          ),
        ],
      ),
    ),
  );
}

void _showRenameDialog(
  BuildContext context,
  String shapeId,
  String currentName,
  void Function(String shapeId, String newName) onRename,
) {
  final controller = TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Shape name',
        ),
        onSubmitted: (value) {
          Navigator.of(ctx).pop();
          onRename(shapeId, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onRename(shapeId, controller.text);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

void _showGroupContextMenu(
  BuildContext context, {
  required String groupId,
  required String groupName,
  required void Function(String groupId) onUngroup,
  required void Function(String groupId) onDelete,
  required void Function(String groupId) onDuplicate,
  required void Function(String groupId, String newName) onRename,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              groupName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(ctx).pop();
              _showGroupRenameDialog(context, groupId, groupName, onRename);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.of(ctx).pop();
              onDuplicate(groupId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.unfold_more_outlined),
            title: const Text('Ungroup'),
            onTap: () {
              Navigator.of(ctx).pop();
              onUngroup(groupId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete Group',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              onDelete(groupId);
            },
          ),
        ],
      ),
    ),
  );
}

void _showGroupRenameDialog(
  BuildContext context,
  String groupId,
  String currentName,
  void Function(String groupId, String newName) onRename,
) {
  final controller = TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename Group'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Group Name',
          hintText: 'Enter group name',
        ),
        onSubmitted: (value) {
          Navigator.of(ctx).pop();
          onRename(groupId, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onRename(groupId, controller.text);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

class _VerticalIconStack extends StatelessWidget {
  const _VerticalIconStack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 20,
          height: 16,
          child: Icon(
            icon,
            size: 12,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class _DropIndicator extends StatelessWidget {
  const _DropIndicator({required this.onAccept});

  final ValueChanged<LayerDragData> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<LayerDragData>(
      onWillAccept: (data) =>
          data != null && data.type == LayerDragItemType.shape,
      onAccept: onAccept,
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActive ? 10 : 6,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: isActive ? 3 : 1,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withOpacity(0.9)
                  : theme.dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _GroupChildrenList extends StatelessWidget {
  const _GroupChildrenList({
    required this.targetLayerId,
    required this.groupId,
    required this.ordered,
    required this.selectedShapeId,
    required this.onActivateLayer,
    required this.onSelectShape,
    required this.onToggleShapeVisibility,
    required this.onToggleShapeLock,
    required this.onMoveShapeToLayer,
    required this.onMoveShapeToLayerAtIndex,
    required this.onMoveShapeWithinGroupAtIndex,
    required this.onMoveShapeToGroup,
    required this.onCreateGroupFromShapes,
    required this.onMoveGroupToLayer,
    required this.onDeleteShape,
    required this.onDuplicateShape,
    required this.onRenameShape,
    required this.onUngroupShapes,
    required this.onDeleteGroup,
    required this.onDuplicateGroup,
    required this.onRenameGroup,
    required this.dragDrop,
  });

  final String targetLayerId;
  final String groupId;
  final List<LayerTreeNode> ordered;
  final String? selectedShapeId;
  final Future<void> Function(String layerId) onActivateLayer;
  final void Function(String? shapeId) onSelectShape;
  final void Function(String shapeId) onToggleShapeVisibility;
  final void Function(String shapeId) onToggleShapeLock;
  final void Function(String shapeId, String targetLayerId) onMoveShapeToLayer;
  final void Function(
    String shapeId,
    String targetLayerId,
    int index, {
    bool clearGroup,
  })
  onMoveShapeToLayerAtIndex;
  final void Function(
    String targetLayerId,
    String groupId,
    String shapeId,
    int index,
  )
  onMoveShapeWithinGroupAtIndex;
  final void Function(String shapeId, String? groupId) onMoveShapeToGroup;
  final void Function(List<String> shapeIds) onCreateGroupFromShapes;
  final void Function(String groupId, String targetLayerId) onMoveGroupToLayer;
  final void Function(String shapeId) onDeleteShape;
  final void Function(String shapeId) onDuplicateShape;
  final void Function(String shapeId, String newName) onRenameShape;
  final void Function(String groupId) onUngroupShapes;
  final void Function(String groupId) onDeleteGroup;
  final void Function(String groupId) onDuplicateGroup;
  final void Function(String groupId, String newName) onRenameGroup;
  final LayerDragDropService dragDrop;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i <= ordered.length; i++) {
      final targetIndex = i;
      widgets.add(
        _DropIndicator(
          onAccept: (data) {
            if (data.type != LayerDragItemType.shape || data.shapeId == null)
              return;
            onMoveShapeWithinGroupAtIndex(
              targetLayerId,
              groupId,
              data.shapeId!,
              targetIndex,
            );
          },
        ),
      );
      if (i < ordered.length) {
        widgets.add(
          _TreeNodeTile(
            node: ordered[i],
            selectedShapeId: selectedShapeId,
            onActivateLayer: onActivateLayer,
            onSelectShape: onSelectShape,
            onToggleShapeVisibility: onToggleShapeVisibility,
            onToggleShapeLock: onToggleShapeLock,
            onMoveShapeToLayer: onMoveShapeToLayer,
            onMoveShapeToLayerAtIndex: onMoveShapeToLayerAtIndex,
            onMoveShapeWithinGroupAtIndex: onMoveShapeWithinGroupAtIndex,
            onMoveShapeToGroup: onMoveShapeToGroup,
            onCreateGroupFromShapes: onCreateGroupFromShapes,
            onMoveGroupToLayer: onMoveGroupToLayer,
            onDeleteShape: onDeleteShape,
            onDuplicateShape: onDuplicateShape,
            onRenameShape: onRenameShape,
            onUngroupShapes: onUngroupShapes,
            onDeleteGroup: onDeleteGroup,
            onDuplicateGroup: onDuplicateGroup,
            onRenameGroup: onRenameGroup,
            dragDrop: dragDrop,
          ),
        );
      }
    }
    return Column(children: widgets);
  }
}
