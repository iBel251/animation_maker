import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class CanvasFrame {
  CanvasFrame({
    required this.index,
    List<Shape> shapes = const <Shape>[],
  }) : shapes = List<Shape>.unmodifiable(shapes);

  final int index;
  final List<Shape> shapes;

  CanvasFrame copyWith({
    int? index,
    List<Shape>? shapes,
  }) {
    return CanvasFrame(
      index: index ?? this.index,
      shapes: shapes ?? this.shapes,
    );
  }
}
