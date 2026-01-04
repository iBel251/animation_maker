import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/domain/services/quadtree.dart';

import 'selection_types.dart';
import 'shape_transformer.dart';

class SelectionService {
  const SelectionService();

  SelectionChange setSelectionMode(SelectionContext context, SelectionMode mode) {
    var ids = List<String>.from(context.selectedShapeIds);
    var primary = context.selectedShapeId;
    switch (mode) {
      case SelectionMode.single:
        if (primary != null) {
          ids = [primary];
        } else if (ids.isNotEmpty) {
          primary = ids.last;
          ids = [primary];
        } else {
          ids = const [];
          primary = null;
        }
        break;
      case SelectionMode.multi:
        if (ids.isEmpty && primary != null) {
          ids = [primary];
        }
        primary = ids.length == 1 ? ids.first : null;
        break;
      case SelectionMode.lasso:
        ids = const [];
        primary = null;
        break;
      case SelectionMode.all:
        ids = context.shapes.map((s) => s.id).toList(growable: false);
        primary = ids.isNotEmpty ? ids.last : null;
        break;
    }
    return SelectionChange(
      selectedShapeId: primary,
      selectedShapeIds: ids,
      clearSelection: primary == null && ids.isEmpty,
    );
  }

  SelectionChange setSelection(List<String> ids) {
    final primary = ids.length == 1 ? ids.first : null;
    return SelectionChange(
      selectedShapeId: primary,
      selectedShapeIds: ids,
      clearSelection: ids.isEmpty,
    );
  }

  SelectionChange selectAtPoint(
    SelectionContext context,
    Offset point,
    QuadTree quadTree,
  ) {
    final hit = topShapeAtPoint(context.shapes, point, quadTree);
    switch (context.selectionMode) {
      case SelectionMode.single:
      case SelectionMode.lasso:
        return SelectionChange(
          selectedShapeId: hit?.id,
          selectedShapeIds: hit != null ? [hit.id] : const [],
          clearSelection: hit == null,
        );
      case SelectionMode.multi:
        if (hit == null) {
          return const SelectionChange(
            selectedShapeId: null,
            selectedShapeIds: <String>[],
            clearSelection: true,
          );
        }
        final ids = List<String>.from(context.selectedShapeIds);
        if (ids.contains(hit.id)) {
          ids.remove(hit.id);
        } else {
          ids.add(hit.id);
        }
        final primary = ids.length == 1 ? ids.first : null;
        return SelectionChange(
          selectedShapeId: primary,
          selectedShapeIds: ids,
          clearSelection: ids.isEmpty,
        );
      case SelectionMode.all:
        final ids = context.shapes.map((s) => s.id).toList(growable: false);
        return SelectionChange(
          selectedShapeId: ids.isNotEmpty ? ids.last : null,
          selectedShapeIds: ids,
          clearSelection: ids.isEmpty,
        );
    }
  }

  Shape? topShapeAtPoint(
    List<Shape> shapes,
    Offset point,
    QuadTree quadTree,
  ) {
    final candidates = quadTree.queryPoint(point);
    if (candidates.isNotEmpty) {
      for (var i = shapes.length - 1; i >= 0; i--) {
        final shape = shapes[i];
        if (candidates.contains(shape) && hitTest(shape, point)) {
          return shape;
        }
      }
    } else {
      for (var i = shapes.length - 1; i >= 0; i--) {
        final shape = shapes[i];
        if (hitTest(shape, point)) {
          return shape;
        }
      }
    }
    return null;
  }

  bool hitTest(Shape shape, Offset point) {
    final bounds = ShapeTransformer.bounds(shape);
    if (bounds == null) return false;
    const tolerance = 4.0;
    final expanded = bounds.inflate(tolerance);
    return expanded.contains(point);
  }
}

class SelectionContext {
  const SelectionContext({
    required this.shapes,
    required this.selectionMode,
    required this.selectedShapeId,
    required this.selectedShapeIds,
  });

  final List<Shape> shapes;
  final SelectionMode selectionMode;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
}

class SelectionChange {
  const SelectionChange({
    required this.selectedShapeId,
    required this.selectedShapeIds,
    required this.clearSelection,
  });

  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final bool clearSelection;
}
