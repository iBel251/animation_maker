import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/services/transform_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransformService.translate erase mask behavior', () {
    test('shifts erase contours with translated geometry', () {
      const service = TransformService();
      const delta = Offset(8, -3);

      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.freehand,
        points: const [Offset(0, 0), Offset(20, 0), Offset(20, 20)],
        eraseContours: const [
          [Offset(2, 2), Offset(6, 2), Offset(6, 6), Offset(2, 6)],
        ],
      );

      final moved = service.translate(shape, delta);
      final movedErase = moved.eraseContours;
      expect(movedErase, isNotNull);
      expect(
        movedErase!.first.toList(growable: false),
        equals(const [
          Offset(10, -1),
          Offset(14, -1),
          Offset(14, 3),
          Offset(10, 3),
        ]),
      );
    });
  });
}
