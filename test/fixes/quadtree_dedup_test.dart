import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuadTree Deduplication', () {
    test('returns no duplicates for shape spanning multiple quadrants', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 2,
      );

      // Create a large shape that spans all 4 quadrants (center at 50,50)
      final shape = Shape(
        id: 'test-shape',
        kind: ShapeKind.freehand,
        points: const [
          Offset(25, 25),
          Offset(75, 25),
          Offset(75, 75),
          Offset(25, 75),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      quadtree.insert(shape);

      // Query the center point which should be in all 4 child quadrants
      // after subdivision
      final results = quadtree.queryPoint(const Offset(50, 50));

      // Should return exactly 1 shape, not 4 copies
      expect(results.length, equals(1));
      expect(results.first.id, equals('test-shape'));
    });

    test('returns no duplicates for shape spanning 2 quadrants horizontally', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 1, // Force subdivision quickly
      );

      // Create shape that spans left-right across center
      final shape = Shape(
        kind: ShapeKind.freehand,
        id: 'horizontal-shape',
        points: const [
          Offset(25, 30),
          Offset(75, 30),
          Offset(75, 40),
          Offset(25, 40),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      quadtree.insert(shape);

      // Query a point in the shape
      final results = quadtree.queryPoint(const Offset(50, 35));

      expect(results.length, equals(1));
      expect(results.first.id, equals('horizontal-shape'));
    });

    test('returns no duplicates for shape spanning 2 quadrants vertically', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 1,
      );

      // Create shape that spans top-bottom across center
      final shape = Shape(
        kind: ShapeKind.freehand,
        id: 'vertical-shape',
        points: const [
          Offset(30, 25),
          Offset(40, 25),
          Offset(40, 75),
          Offset(30, 75),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      quadtree.insert(shape);

      // Query a point in the shape
      final results = quadtree.queryPoint(const Offset(35, 50));

      expect(results.length, equals(1));
      expect(results.first.id, equals('vertical-shape'));
    });

    test('returns multiple distinct shapes when query point hits both', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 2,
      );

      final shape1 = Shape(
        kind: ShapeKind.freehand,
        id: 'shape-1',
        points: const [
          Offset(10, 10),
          Offset(60, 10),
          Offset(60, 60),
          Offset(10, 60),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      final shape2 = Shape(
        kind: ShapeKind.freehand,
        id: 'shape-2',
        points: const [
          Offset(40, 40),
          Offset(90, 40),
          Offset(90, 90),
          Offset(40, 90),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      quadtree.insert(shape1);
      quadtree.insert(shape2);

      // Query point in overlap region
      final results = quadtree.queryPoint(const Offset(50, 50));

      // Should return 2 shapes, each appearing once
      expect(results.length, equals(2));
      final ids = results.map((s) => s.id).toSet();
      expect(ids, containsAll(['shape-1', 'shape-2']));
    });

    test('returns no shapes when query point is outside all shapes', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 2,
      );

      final shape = Shape(
        kind: ShapeKind.freehand,
        id: 'test-shape',
        points: const [
          Offset(10, 10),
          Offset(30, 10),
          Offset(30, 30),
          Offset(10, 30),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      quadtree.insert(shape);

      // Query point outside the shape
      final results = quadtree.queryPoint(const Offset(80, 80));

      expect(results, isEmpty);
    });

    test('handles deep tree with many subdivisions without duplicates', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 1000, 1000),
        capacity: 1,
        maxDepth: 8,
      );

      // Insert many small shapes to trigger multiple subdivisions
      for (int i = 0; i < 20; i++) {
        final offset = i * 40.0;
        quadtree.insert(Shape(
          kind: ShapeKind.freehand,
          id: 'shape-$i',
          points: [
            Offset(offset, offset),
            Offset(offset + 30, offset),
            Offset(offset + 30, offset + 30),
            Offset(offset, offset + 30),
          ],
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
        ));
      }

      // Insert one large shape that spans many quadrants
      final largeShape = Shape(
        kind: ShapeKind.freehand,
        id: 'large-shape',
        points: const [
          Offset(100, 100),
          Offset(900, 100),
          Offset(900, 900),
          Offset(100, 900),
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );
      quadtree.insert(largeShape);

      // Query center point
      final results = quadtree.queryPoint(const Offset(500, 500));

      // Should only return the large shape once, not multiple times
      final largeShapeResults =
          results.where((s) => s.id == 'large-shape').toList();
      expect(largeShapeResults.length, equals(1));
    });

    test('preserves shape identity through deduplication', () {
      final quadtree = QuadTree(
        boundary: const Rect.fromLTWH(0, 0, 100, 100),
        capacity: 1,
      );

      final originalShape = Shape(
        kind: ShapeKind.freehand,
        id: 'test-shape',
        points: const [
          Offset(25, 25),
          Offset(75, 25),
          Offset(75, 75),
          Offset(25, 75),
        ],
        strokeColor: const Color(0xFFFF0000),
        strokeWidth: 10.0,
      );

      quadtree.insert(originalShape);

      final results = quadtree.queryPoint(const Offset(50, 50));

      expect(results.length, equals(1));
      final returnedShape = results.first;

      // Verify it's the same shape (by reference)
      expect(identical(returnedShape, originalShape), isTrue);
      expect(returnedShape.strokeColor, equals(const Color(0xFFFF0000)));
      expect(returnedShape.strokeWidth, equals(10.0));
    });
  });
}
