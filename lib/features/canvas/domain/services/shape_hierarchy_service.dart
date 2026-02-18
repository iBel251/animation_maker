import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:vector_math/vector_math_64.dart';

/// Service for managing parent-child relationships between shapes.
///
/// Provides query methods, link/unlink operations, and transform computation
/// for hierarchical shape structures.
class ShapeHierarchyService {
  const ShapeHierarchyService();

  // ─────────────────────────────────────────────────────────────────────────
  // Query Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the parent of the given shape, or null if it has no parent.
  Shape? getParent(Shape shape, List<Shape> allShapes) {
    if (shape.parentId == null) return null;
    return allShapes.cast<Shape?>().firstWhere(
          (s) => s!.id == shape.parentId,
          orElse: () => null,
        );
  }

  /// Returns all direct children of the given shape.
  List<Shape> getChildren(Shape shape, List<Shape> allShapes) {
    return allShapes.where((s) => s.parentId == shape.id).toList();
  }

  /// Returns all ancestors of the given shape (parent, grandparent, etc.).
  /// The list is ordered from immediate parent to root ancestor.
  List<Shape> getAncestors(Shape shape, List<Shape> allShapes) {
    final ancestors = <Shape>[];
    var current = getParent(shape, allShapes);
    while (current != null) {
      ancestors.add(current);
      current = getParent(current, allShapes);
    }
    return ancestors;
  }

  /// Returns all descendants of the given shape (children, grandchildren, etc.).
  List<Shape> getDescendants(Shape shape, List<Shape> allShapes) {
    final descendants = <Shape>[];
    final queue = getChildren(shape, allShapes);
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      descendants.add(current);
      queue.addAll(getChildren(current, allShapes));
    }
    return descendants;
  }

  /// Returns true if [ancestor] is an ancestor of [descendant].
  bool isAncestorOf(Shape ancestor, Shape descendant, List<Shape> allShapes) {
    var current = getParent(descendant, allShapes);
    while (current != null) {
      if (current.id == ancestor.id) return true;
      current = getParent(current, allShapes);
    }
    return false;
  }

  /// Returns the depth of the shape in the hierarchy tree.
  /// Root shapes (no parent) have depth 0.
  int getDepth(Shape shape, List<Shape> allShapes) {
    var depth = 0;
    var current = getParent(shape, allShapes);
    while (current != null) {
      depth++;
      current = getParent(current, allShapes);
    }
    return depth;
  }

  /// Returns true if the shape has any children.
  bool hasChildren(Shape shape, List<Shape> allShapes) {
    return allShapes.any((s) => s.parentId == shape.id);
  }

  /// Returns true if the shape has a parent.
  bool hasParent(Shape shape) {
    return shape.parentId != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Link/Unlink Operations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new shape with parentId set to the given parent.
  Shape linkToParent(Shape child, String parentId) {
    return child.copyWith(parentId: parentId);
  }

  /// Creates a new shape with parentId cleared.
  Shape unlinkFromParent(Shape child) {
    return child.copyWith(clearParentId: true);
  }

  /// Checks if linking child to parent is valid.
  /// Returns false if:
  /// - child and parent are the same shape
  /// - parent is already a descendant of child (would create cycle)
  bool canLink(Shape child, Shape parent, List<Shape> allShapes) {
    // Can't link to self
    if (child.id == parent.id) return false;

    // Can't link if parent is already a descendant of child
    // (would create circular reference)
    return !isAncestorOf(child, parent, allShapes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Transform Computation
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes the world matrix for a shape by accumulating ancestor transforms.
  /// Only rotation and translation are inherited from ancestors, not scale.
  Matrix4 computeWorldMatrix(Shape shape, List<Shape> allShapes) {
    final ancestors = getAncestors(shape, allShapes);
    var worldMatrix = Matrix4.identity();

    // Apply ancestor transforms in reverse order (from root to immediate parent)
    // Only rotation and translation are inherited, not scale
    for (final ancestor in ancestors.reversed) {
      final pivot = ancestor.transform.pivot;
      final rotation = ancestor.transform.rotation;
      final position = ancestor.transform.position;
      final localOrigin = ancestor.localOrigin;
      final pivotWorld = localOrigin + pivot;

      // Apply translation and rotation only (no scale inheritance)
      worldMatrix = worldMatrix
        ..translate(position.dx, position.dy)
        ..translate(pivotWorld.dx, pivotWorld.dy)
        ..rotateZ(rotation)
        ..translate(-pivotWorld.dx, -pivotWorld.dy);
    }

    // Apply shape's own full transform (including scale)
    final shapeMatrix = shape.transformMatrix;
    worldMatrix = worldMatrix.multiplied(shapeMatrix);

    return worldMatrix;
  }

  /// Computes the world position of a shape's origin.
  Offset computeWorldPosition(Shape shape, List<Shape> allShapes) {
    final worldMatrix = computeWorldMatrix(shape, allShapes);
    final localOrigin = shape.localOrigin;
    final transformed = worldMatrix.transform3(
      Vector3(localOrigin.dx, localOrigin.dy, 0),
    );
    return Offset(transformed.x, transformed.y);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Movement Propagation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a list of shapes with updated positions after moving a parent.
  /// The parent and all descendants are moved by the same delta.
  List<Shape> moveWithChildren(
    Shape parent,
    Offset delta,
    List<Shape> allShapes,
  ) {
    final descendants = getDescendants(parent, allShapes);
    final updatedShapes = <Shape>[];

    // Move parent
    updatedShapes.add(
      parent.copyWith(
        translation: parent.transform.position + delta,
      ),
    );

    // Move all descendants by same delta
    for (final child in descendants) {
      updatedShapes.add(
        child.copyWith(
          translation: child.transform.position + delta,
        ),
      );
    }

    return updatedShapes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rotation Propagation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a list of shapes with updated transforms after rotating a parent.
  /// The parent rotates normally. Children's positions orbit around parent's pivot.
  List<Shape> rotateWithChildren(
    Shape parent,
    double angleDelta,
    List<Shape> allShapes,
  ) {
    final updatedShapes = <Shape>[];
    final parentPivotWorld = parent.transform.position +
        parent.localOrigin +
        parent.transform.pivot;

    // Rotate parent normally
    updatedShapes.add(
      parent.copyWith(
        rotation: parent.transform.rotation + angleDelta,
      ),
    );

    // Rotate children's positions around parent's pivot
    _rotateChildrenRecursively(
      parent,
      angleDelta,
      parentPivotWorld,
      allShapes,
      updatedShapes,
    );

    return updatedShapes;
  }

  void _rotateChildrenRecursively(
    Shape parent,
    double angleDelta,
    Offset pivotWorld,
    List<Shape> allShapes,
    List<Shape> updatedShapes,
  ) {
    final children = getChildren(parent, allShapes);

    for (final child in children) {
      // Rotate child's position around the pivot
      final childPos = child.transform.position;
      final relativePos = childPos - pivotWorld;
      final rotatedPos = _rotatePoint(relativePos, angleDelta);
      final newPos = pivotWorld + rotatedPos;

      updatedShapes.add(
        child.copyWith(
          translation: newPos,
        ),
      );

      // Recursively handle grandchildren using the same root pivot
      _rotateChildrenRecursively(
        child,
        angleDelta,
        pivotWorld,
        allShapes,
        updatedShapes,
      );
    }
  }

  Offset _rotatePoint(Offset point, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      point.dx * cos - point.dy * sin,
      point.dx * sin + point.dy * cos,
    );
  }
}
