import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class ShapeGroupingService {
  int _groupCounter = 0;

  void syncIdCounters(CanvasDocument document) {
    var maxGroup = 0;
    for (final layer in document.layers) {
      for (final frame in layer.frames.values) {
        for (final shape in frame.shapes) {
          final groupId = shape.groupId;
          if (groupId != null) {
            maxGroup = math.max(maxGroup, _parseCounter(groupId, 'group-'));
          }
        }
      }
    }
    // Reset counter to match the loaded document (not max with existing)
    _groupCounter = maxGroup;
  }

  String nextGroupId() {
    _groupCounter += 1;
    return 'group-$_groupCounter';
  }

  int _parseCounter(String id, String prefix) {
    if (!id.startsWith(prefix)) return 0;
    final value = int.tryParse(id.substring(prefix.length));
    return value ?? 0;
  }

  List<Shape> groupSelectedShapes({
    required List<Shape> allShapes,
    required List<String> selectedShapeIds,
  }) {
    if (selectedShapeIds.length < 2) {
      return allShapes;
    }

    final newGroupId = nextGroupId();
    final selectedIdsSet = selectedShapeIds.toSet();
    final updatedShapes = <Shape>[];

    for (final shape in allShapes) {
      if (selectedIdsSet.contains(shape.id)) {
        updatedShapes.add(shape.copyWith(groupId: newGroupId));
      } else {
        updatedShapes.add(shape);
      }
    }

    return updatedShapes;
  }

  List<Shape> ungroupSelectedShapes({
    required List<Shape> allShapes,
    required List<String> selectedShapeIds,
  }) {
    if (selectedShapeIds.isEmpty) {
      return allShapes;
    }
    final selectedIdsSet = selectedShapeIds.toSet();

    // Case 1: A single shape is selected.
    if (selectedShapeIds.length == 1) {
      final shapeId = selectedShapeIds.first;
      final selectedShape =
          allShapes.firstWhere((s) => s.id == shapeId, orElse: () => allShapes.first);
      final groupId = selectedShape.groupId;

      if (groupId == null) {
        return allShapes; // Not in a group, nothing to do.
      }

      // Count members of the group.
      final groupMembers =
          allShapes.where((s) => s.groupId == groupId).toList(growable: false);

      // If it's a small group (<=2), dissolve it completely.
      if (groupMembers.length <= 2) {
        final groupIdsToDissolve = {groupId};
        return _dissolveGroups(allShapes, groupIdsToDissolve);
      }
      // If it's a larger group, ungroup just the selected shape.
      else {
        final updatedShapes = <Shape>[];
        for (final shape in allShapes) {
          if (shape.id == shapeId) {
            updatedShapes.add(_ungroupAndResetPivot(shape));
          } else {
            updatedShapes.add(shape);
          }
        }
        return updatedShapes;
      }
    }

    // Case 2: Multiple shapes are selected. Dissolve all their groups.
    final groupIdsToDissolve = <String>{};
    for (final shape in allShapes) {
      if (selectedIdsSet.contains(shape.id) && shape.groupId != null) {
        groupIdsToDissolve.add(shape.groupId!);
      }
    }

    if (groupIdsToDissolve.isEmpty) {
      return allShapes;
    }

    return _dissolveGroups(allShapes, groupIdsToDissolve);
  }

  /// Helper to dissolve a set of groups and reset pivots of their members.
  List<Shape> _dissolveGroups(
    List<Shape> allShapes,
    Set<String> groupIdsToDissolve,
  ) {
    final updatedShapes = <Shape>[];
    for (final shape in allShapes) {
      if (shape.groupId != null && groupIdsToDissolve.contains(shape.groupId)) {
        updatedShapes.add(_ungroupAndResetPivot(shape));
      } else {
        updatedShapes.add(shape);
      }
    }
    return updatedShapes;
  }

  /// Creates a new Shape with its groupId removed and its pivot reset to its
  /// local center, while adjusting its translation to keep it in the same
  /// world-space position.
  Shape _ungroupAndResetPivot(Shape shape) {
    if (shape.transform.pivot == Offset.zero) {
      return shape.copyWith(clearGroupId: true);
    }

    final origin = shape.localBounds?.center ?? Offset.zero;
    final oldPivot = shape.transform.pivot;
    const newPivot = Offset.zero;

    final p0 = origin + oldPivot;
    final p1 = origin + newPivot;
    final delta = p1 - p0;

    final cosA = math.cos(shape.rotation);
    final sinA = math.sin(shape.rotation);
    final flipSignX = shape.scaleX.sign;
    final flipSignY = shape.scaleY.sign;
    final flippedDelta = Offset(delta.dx * flipSignX, delta.dy * flipSignY);
    final absScaleX = shape.scaleX.abs();
    final absScaleY = shape.scaleY.abs();

    final lx = cosA * absScaleX * flippedDelta.dx - sinA * absScaleY * flippedDelta.dy;
    final ly = sinA * absScaleX * flippedDelta.dx + cosA * absScaleY * flippedDelta.dy;
    final compensation = (p0 - p1) + Offset(lx, ly);
    final newTranslation = shape.translation + compensation;

    return shape.copyWith(
      clearGroupId: true,
      pivot: Offset.zero,
      translation: newTranslation,
    );
  }
}
