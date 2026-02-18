import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_erase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShapeEraseService mask budget', () {
    test('caps contour and point growth to avoid runaway masks', () {
      const service = ShapeEraseService();

      final largeMask = List<List<Offset>>.generate(280, (i) {
        final y = i.toDouble() * 0.1;
        return List<Offset>.generate(
          350,
          (j) => Offset(j.toDouble() * 0.2, y + (j.isEven ? 0 : 0.05)),
          growable: false,
        );
      }, growable: false);

      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.freehand,
        points: const [Offset(0, 0), Offset(100, 0), Offset(100, 100)],
        eraseContours: largeMask,
      );

      final result = service.erase(
        shape: shape,
        eraserPath: Path()..addRect(const Rect.fromLTWH(10, 10, 15, 15)),
        createId: () => 'unused-id',
      );

      expect(result.didErase, isTrue);
      expect(result.replacements, hasLength(1));

      final replacement = result.replacements.first;
      final contours = replacement.eraseContours;
      expect(contours, isNotNull);
      expect(contours!.length, lessThanOrEqualTo(256));

      var totalPoints = 0;
      for (final contour in contours) {
        expect(contour.length, lessThanOrEqualTo(320));
        totalPoints += contour.length;
      }
      expect(totalPoints, lessThanOrEqualTo(24000));
    });
  });
}
