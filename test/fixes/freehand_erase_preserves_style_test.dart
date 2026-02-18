import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_erase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShapeEraseService freehand erase behavior', () {
    test('erasing freehand keeps a single in-place replacement', () {
      const service = ShapeEraseService();

      final points = <Offset>[
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(20, 0),
        const Offset(30, 0),
        const Offset(40, 0),
        const Offset(50, 0),
        const Offset(60, 0),
        const Offset(70, 0),
        const Offset(80, 0),
      ];
      final pressures = <double>[0.4, 0.5, 0.6, 0.7, 0.8, 0.7, 0.6, 0.5, 0.4];

      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.freehand,
        points: points,
        pointPressures: pressures,
        strokeWidth: 12.0,
        spatialObjectId: 'spatial-1',
      );

      final eraserPath = Path()..addRect(const Rect.fromLTWH(35, -10, 20, 20));

      var counter = 0;
      final result = service.erase(
        shape: shape,
        eraserPath: eraserPath,
        createId: () => 'shape-new-${counter++}',
      );

      expect(result.didErase, isTrue);
      expect(result.replacements, isNotEmpty);
      expect(result.preserveId, isTrue);
      expect(result.replacements.length, equals(1));
      expect(result.replacements.first.id, equals('shape-1'));

      final replacement = result.replacements.first;
      expect(replacement.spatialObjectId, equals(shape.spatialObjectId));
      expect(replacement.points.length, greaterThanOrEqualTo(2));
    });
  });
}
