import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Container object that groups multiple shapes into a single transformable unit.
/// This is not a renderable shape by itself; it owns child shape IDs and a transform.
class SpatialObject {
  const SpatialObject({
    required this.id,
    required this.layerId,
    required this.childShapeIds,
    this.name,
    this.parentId,
    this.transform = const Transform2D(),
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 2.0,
    this.fillColor,
    this.opacity = 1.0,
    this.isVisible = true,
    this.isLocked = false,
  });

  final String id;
  final String layerId;
  final String? name;
  final List<String> childShapeIds;
  final String? parentId;
  final Transform2D transform;

  // Unified styling (applied to all children when this object is edited as one).
  final Color strokeColor;
  final double strokeWidth;
  final Color? fillColor;
  final double opacity;

  final bool isVisible;
  final bool isLocked;

  Offset get translation => transform.position;
  double get rotation => transform.rotation;
  Offset get pivot => transform.pivot;

  SpatialObject copyWith({
    String? id,
    String? layerId,
    String? name,
    bool clearName = false,
    List<String>? childShapeIds,
    String? parentId,
    bool clearParentId = false,
    Transform2D? transform,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    bool clearFillColor = false,
    double? opacity,
    bool? isVisible,
    bool? isLocked,
  }) {
    return SpatialObject(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      name: clearName ? null : (name ?? this.name),
      childShapeIds: childShapeIds ?? this.childShapeIds,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      transform: transform ?? this.transform,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: clearFillColor ? null : (fillColor ?? this.fillColor),
      opacity: opacity ?? this.opacity,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
