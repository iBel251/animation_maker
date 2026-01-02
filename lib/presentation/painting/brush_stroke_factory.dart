import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:animation_maker/presentation/screens/editor/fill_utils.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class BrushStrokeResult {
  const BrushStrokeResult.vector(this.vectorShape)
      : rasterStroke = null,
        isVector = true;
  const BrushStrokeResult.raster(this.rasterStroke)
      : vectorShape = null,
        isVector = false;

  final Shape? vectorShape;
  final RasterStroke? rasterStroke;
  final bool isVector;
}

class BrushStrokeFactory {
  static BrushStrokeResult build({
    required bool asVector,
    required String vectorId,
    required List<PointVector> points,
    required Color color,
    required double thickness,
    required double opacity,
    required double thinning,
    required double smoothing,
    required double streamline,
    required bool simulatePressure,
    required BrushType brushType,
    String? groupId,
  }) {
    if (asVector) {
      final offsets =
          points.map((p) => Offset(p.x, p.y)).toList(growable: false);
      final shape = Shape(
        id: vectorId,
        kind: ShapeKind.freehand,
        points: offsets,
        strokeColor: color,
        strokeWidth: thickness,
        opacity: opacity,
        brushType: brushType,
        isClosed: FillUtils.isFreehandClosedPoints(offsets),
        groupId: groupId,
      );
      return BrushStrokeResult.vector(shape);
    }

    return BrushStrokeResult.raster(
      RasterStroke(
        points: points,
        color: color,
        strokeWidth: thickness,
        opacity: opacity,
        thinning: thinning,
        smoothing: smoothing,
        streamline: streamline,
        simulatePressure: simulatePressure,
        brushType: brushType,
      ),
    );
  }
}
