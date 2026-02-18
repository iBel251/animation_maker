import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/services/fill_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Self-Intersection Detection', () {
    test('detects no intersection for simple open path', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('detects endpoint closure', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
        const Offset(1, 1), // Close to start (within threshold)
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isTrue);
    });

    test('detects simple self-intersection (figure-8)', () {
      // Create a figure-8 shape (clear self-intersection)
      final points = [
        const Offset(50, 0),
        const Offset(100, 50),
        const Offset(50, 100),
        const Offset(0, 50), // Back to middle (intersects first segment)
        const Offset(50, 0),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isTrue);
    });

    test('detects crossing segments', () {
      // X shape - two segments crossing in the middle
      final points = [
        const Offset(0, 0),
        const Offset(100, 100),
        const Offset(0, 100),
        const Offset(100, 0), // Crosses the first segment
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isTrue);
    });

    test('no false positive for non-intersecting zigzag', () {
      final points = [
        const Offset(0, 0),
        const Offset(50, 50),
        const Offset(100, 0),
        const Offset(150, 50),
        const Offset(200, 0),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('handles complex path with many points', () {
      // Spiral that doesn't intersect itself
      final points = <Offset>[];
      for (int i = 0; i < 100; i++) {
        final angle = i * 0.2;
        final radius = i * 0.5;
        points.add(Offset(
          50 + radius * math.cos(angle),
          50 + radius * math.sin(angle),
        ));
      }

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      // Spiral shouldn't intersect itself
      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('detects intersection in dense path', () {
      // Create a dense path with intentional intersection
      final points = <Offset>[];

      // First segment: horizontal line
      for (int i = 0; i <= 20; i++) {
        points.add(Offset(i * 5.0, 50));
      }

      // Second segment: vertical line crossing the first
      for (int i = 0; i <= 20; i++) {
        points.add(Offset(50, i * 5.0));
      }

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isTrue);
    });

    test('handles very dense path efficiently (performance)', () {
      // Create a path with 1000 points (would be very slow with O(n²))
      final points = <Offset>[];
      for (int i = 0; i < 1000; i++) {
        points.add(Offset(i.toDouble(), (i % 100).toDouble()));
      }

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      final stopwatch = Stopwatch()..start();
      FillUtils.isFreehandClosed(shape);
      stopwatch.stop();

      // With spatial hashing, should complete in under 100ms even for 1000 points
      // Old O(n²) algorithm would take seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('handles edge case with 3 points', () {
      final points = [
        const Offset(0, 0),
        const Offset(50, 50),
        const Offset(100, 0),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      // 3 points can't self-intersect
      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('handles edge case with 2 points', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 100),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('handles collinear segments correctly', () {
      // Segments that are collinear but don't overlap
      final points = [
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(100, 0),
        const Offset(150, 0),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isFalse);
    });

    test('detects T-junction intersection', () {
      // T-shape where one segment ends on another
      final points = [
        const Offset(0, 50),
        const Offset(100, 50),
        const Offset(50, 50),
        const Offset(50, 0), // Perpendicular segment
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.isFreehandClosed(shape), isTrue);
    });

    test('canFill returns true for closed freehand', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
        const Offset(0, 0), // Closed
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.canFill(shape), isTrue);
    });

    test('canFill returns false for open freehand', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
      ];

      final shape = Shape(
        id: 'test',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.canFill(shape), isFalse);
    });

    test('canFill returns true for shapes that always support fill', () {
      final rect = Shape(
        id: 'rect',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      final ellipse = Shape(
        id: 'ellipse',
        kind: ShapeKind.ellipse,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      final polygon = Shape(
        id: 'polygon',
        kind: ShapeKind.polygon,
        points: const [
          Offset(0, 0),
          Offset(100, 0),
          Offset(50, 100),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.canFill(rect), isTrue);
      expect(FillUtils.canFill(ellipse), isTrue);
      expect(FillUtils.canFill(polygon), isTrue);
    });

    test('canFill returns false for line', () {
      final line = Shape(
        id: 'line',
        kind: ShapeKind.line,
        points: const [
          Offset(0, 0),
          Offset(100, 100),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      expect(FillUtils.canFill(line), isFalse);
    });
  });
}
