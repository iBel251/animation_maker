import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/raster_stroke.dart';

class CanvasFrame {
  CanvasFrame({
    required this.index,
    List<Shape> shapes = const <Shape>[],
    List<RasterStroke> rasterStrokes = const <RasterStroke>[],
  })  : shapes = List<Shape>.unmodifiable(shapes),
        rasterStrokes = List<RasterStroke>.unmodifiable(rasterStrokes);

  final int index;
  final List<Shape> shapes;
  final List<RasterStroke> rasterStrokes;

  CanvasFrame copyWith({
    int? index,
    List<Shape>? shapes,
    List<RasterStroke>? rasterStrokes,
  }) {
    return CanvasFrame(
      index: index ?? this.index,
      shapes: shapes ?? this.shapes,
      rasterStrokes: rasterStrokes ?? this.rasterStrokes,
    );
  }
}
