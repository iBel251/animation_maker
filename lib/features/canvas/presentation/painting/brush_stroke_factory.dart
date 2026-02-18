import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import '../services/fill_utils.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class BrushStrokeResult {
  const BrushStrokeResult(this.vectorShape);

  final Shape vectorShape;
}

class BrushStrokeFactory {
  static BrushStrokeResult build({
    required String vectorId,
    required List<PointVector> points,
    required Color color,
    required double thickness,
    required double opacity,
    required BrushType brushType,
    double? brushSmoothness,
    String? groupId,
  }) {
    final offsets =
        points.map((p) => Offset(p.x, p.y)).toList(growable: false);
    final pressures = points
        .map((p) => (p.pressure ?? 1.0).clamp(0.0, 1.0))
        .toList(growable: false);
    final shape = Shape(
      id: vectorId,
      kind: ShapeKind.freehand,
      points: offsets,
      pointPressures: pressures,
      strokeColor: color,
      strokeWidth: thickness,
      opacity: opacity,
      brushType: brushType,
      brushSmoothness: brushSmoothness,
      isClosed: FillUtils.isFreehandClosedPoints(offsets),
      groupId: groupId,
    );
    return BrushStrokeResult(shape);
  }
}



