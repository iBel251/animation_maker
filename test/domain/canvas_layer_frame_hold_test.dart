import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasLayer.frameAt', () {
    test('holds previous frame content when target frame is empty', () {
      final baseShape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 100)],
      );
      final layer = CanvasLayer(
        id: 'layer-1',
        name: 'Layer 1',
        frames: <int, CanvasFrame>{
          0: CanvasFrame(index: 0, shapes: <Shape>[baseShape]),
        },
      );

      final frame5 = layer.frameAt(5);
      expect(frame5.index, 5);
      expect(frame5.shapes.length, 1);
      expect(frame5.shapes.first.id, baseShape.id);
    });

    test('returns empty when there is no previous frame to hold', () {
      final layer = CanvasLayer(id: 'layer-1', name: 'Layer 1');
      final frame3 = layer.frameAt(3);
      expect(frame3.index, 3);
      expect(frame3.shapes, isEmpty);
    });

    test('does not propagate an empty frame when earlier non-empty exists', () {
      final baseShape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 100)],
      );
      final layer = CanvasLayer(
        id: 'layer-1',
        name: 'Layer 1',
        frames: <int, CanvasFrame>{
          0: CanvasFrame(index: 0, shapes: <Shape>[baseShape]),
          6: CanvasFrame(index: 6, shapes: const <Shape>[]),
        },
      );

      final frame8 = layer.frameAt(8);
      expect(frame8.index, 8);
      expect(frame8.shapes.length, 1);
      expect(frame8.shapes.first.id, 'shape-1');
    });
  });
}
