import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/painting/raster_paint_modal_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeRasterPressure', () {
    test('normalizes stylus pressure using min and max', () {
      final normalized = normalizeRasterPressure(
        kind: PointerDeviceKind.stylus,
        pressure: 0.55,
        pressureMin: 0.1,
        pressureMax: 1.0,
      );
      expect(normalized, closeTo(0.5, 0.0001));
    });

    test('returns 1.0 for non-stylus input', () {
      final normalized = normalizeRasterPressure(
        kind: PointerDeviceKind.touch,
        pressure: 0.2,
        pressureMin: 0.0,
        pressureMax: 1.0,
      );
      expect(normalized, 1.0);
    });

    test('returns 1.0 when stylus range is invalid', () {
      final normalized = normalizeRasterPressure(
        kind: PointerDeviceKind.stylus,
        pressure: 0.3,
        pressureMin: 1.0,
        pressureMax: 1.0,
      );
      expect(normalized, 1.0);
    });
  });

  group('RasterHistory', () {
    test('push undo redo behavior is linear', () {
      final history = RasterHistory<String>();
      history.push('a');
      history.push('b');
      history.push('c');

      expect(history.cursor, 3);
      expect(history.appliedOperations, const <String>['a', 'b', 'c']);

      history.undo();
      expect(history.cursor, 2);
      expect(history.appliedOperations, const <String>['a', 'b']);

      history.redo();
      expect(history.cursor, 3);
      expect(history.appliedOperations, const <String>['a', 'b', 'c']);
    });

    test('push after undo truncates redo branch', () {
      final history = RasterHistory<String>();
      history.push('stroke-1');
      history.push('stroke-2');
      history.push('clip');

      history.undo();
      history.undo();
      expect(history.appliedOperations, const <String>['stroke-1']);
      expect(history.canRedo, isTrue);

      history.push('stroke-3');
      expect(history.appliedOperations, const <String>['stroke-1', 'stroke-3']);
      expect(history.operations, const <String>['stroke-1', 'stroke-3']);
      expect(history.canRedo, isFalse);
    });
  });

  group('canClipInsideFill', () {
    test('is enabled for closed fillable shapes', () {
      expect(
        canClipInsideFill(
          Shape(
            id: 'rect',
            kind: ShapeKind.rectangle,
            bounds: const Rect.fromLTWH(0, 0, 100, 60),
          ),
        ),
        isTrue,
      );
      expect(
        canClipInsideFill(
          Shape(
            id: 'polygon',
            kind: ShapeKind.polygon,
            points: const <Offset>[
              Offset(0, 0),
              Offset(100, 0),
              Offset(100, 100),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        canClipInsideFill(
          Shape(
            id: 'point-path',
            kind: ShapeKind.pointPath,
            isClosed: true,
            points: const <Offset>[Offset(0, 0), Offset(50, 0), Offset(50, 50)],
          ),
        ),
        isTrue,
      );
    });

    test('is disabled for non-fillable/open shapes', () {
      expect(
        canClipInsideFill(
          Shape(
            id: 'line',
            kind: ShapeKind.line,
            points: const <Offset>[Offset(0, 0), Offset(100, 0)],
          ),
        ),
        isFalse,
      );
      expect(
        canClipInsideFill(
          Shape(
            id: 'open-path',
            kind: ShapeKind.pointPath,
            isClosed: false,
            points: const <Offset>[Offset(0, 0), Offset(50, 0), Offset(50, 50)],
          ),
        ),
        isFalse,
      );
      expect(
        canClipInsideFill(
          Shape(
            id: 'freehand-open',
            kind: ShapeKind.freehand,
            points: const <Offset>[
              Offset(0, 0),
              Offset(60, 40),
              Offset(120, 60),
            ],
          ),
        ),
        isFalse,
      );
    });
  });
}
