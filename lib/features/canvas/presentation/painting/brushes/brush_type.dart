import 'package:flutter/material.dart';

import 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';

export 'package:animation_maker/features/canvas/domain/entities/brush_type.dart';

class BrushDefinition {
  const BrushDefinition({
    required this.type,
    required this.icon,
    required this.label,
  });

  final BrushType type;
  final IconData icon;
  final String label;
}

const List<BrushDefinition> kBrushDefinitions = [
  BrushDefinition(
    type: BrushType.standard,
    icon: Icons.brush,
    label: 'Standard',
  ),
  BrushDefinition(
    type: BrushType.marker,
    icon: Icons.edit,
    label: 'Marker',
  ),
  BrushDefinition(
    type: BrushType.pencil,
    icon: Icons.create,
    label: 'Pencil',
  ),
  BrushDefinition(
    type: BrushType.hair,
    icon: Icons.cut,
    label: 'Hair',
  ),
  BrushDefinition(
    type: BrushType.cube,
    icon: Icons.grid_view,
    label: 'Cube',
  ),
  BrushDefinition(
    type: BrushType.gradient,
    icon: Icons.gradient,
    label: 'Gradient',
  ),
  BrushDefinition(
    type: BrushType.mosaic,
    icon: Icons.blur_on,
    label: 'Mosaic',
  ),
];

BrushDefinition brushDefinition(BrushType type) {
  return kBrushDefinitions.firstWhere((def) => def.type == type);
}


