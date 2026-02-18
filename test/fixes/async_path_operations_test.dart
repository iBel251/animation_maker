import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_erase_service.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_merge_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Merge Modes', () {
    test('union combines all shapes into one', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        mode: MergeMode.union,
      );

      expect(result.mergedShapes.length, 1);
      expect(result.removedIds, containsAll(['rect1', 'rect2']));
    });

    test('intersect keeps only overlapping area', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        mode: MergeMode.intersect,
      );

      // Should have a merged shape (the intersection area)
      expect(result.mergedShapes.length, 1);
    });

    test('difference subtracts second shape from first', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        mode: MergeMode.difference,
      );

      expect(result.mergedShapes.length, 1);
    });

    test('xor keeps only non-overlapping areas', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        mode: MergeMode.xor,
      );

      expect(result.mergedShapes.length, 1);
    });
  });

  group('Multi-Contour Shapes', () {
    test('merging disjoint shapes creates multi-contour polygon', () {
      const service = ShapeMergeService();
      final shapes = _createDisjointRectangles();
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        mode: MergeMode.union,
      );

      expect(result.mergedShapes.length, 1);
      final merged = result.mergedShapes.first;
      // Disjoint shapes should create multiple contours
      expect(merged.contours.length, greaterThanOrEqualTo(2));
    });

    test('NodeEditService detects multiple contours', () {
      const nodeService = NodeEditService();
      final multiContourShape = Shape(
        id: 'test',
        kind: ShapeKind.polygon,
        points: const [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
        contours: const [
          [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
          [Offset(100, 100), Offset(110, 100), Offset(110, 110)],
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 1.0,
      );

      expect(nodeService.hasMultipleContours(multiContourShape), isTrue);
      expect(nodeService.getContourCount(multiContourShape), 2);
    });

    test('explodeContours splits multi-contour shape', () {
      const nodeService = NodeEditService();
      var idCounter = 0;
      final multiContourShape = Shape(
        id: 'test',
        kind: ShapeKind.polygon,
        points: const [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
        contours: const [
          [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
          [Offset(100, 100), Offset(110, 100), Offset(110, 110)],
        ],
        strokeColor: const Color(0xFF000000),
        strokeWidth: 2.0,
        fillColor: const Color(0xFFFF0000),
      );

      final exploded = nodeService.explodeContours(
        multiContourShape,
        () => 'exploded-${idCounter++}',
      );

      expect(exploded, isNotNull);
      expect(exploded!.length, 2);
      for (final shape in exploded) {
        expect(shape.strokeColor, equals(multiContourShape.strokeColor));
        expect(shape.strokeWidth, equals(multiContourShape.strokeWidth));
        expect(shape.fillColor, equals(multiContourShape.fillColor));
      }
    });
  });

  group('Degenerate Case Validation', () {
    test('skips shapes with too few points', () {
      const service = ShapeMergeService();
      final shapes = [
        Shape(
          id: 'valid',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'invalid',
          kind: ShapeKind.freehand,
          points: const [Offset(0, 0)], // Only 1 point
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'valid2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
      ];
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['valid', 'invalid', 'valid2'],
        createId: () => 'merged-${idCounter++}',
      );

      expect(result.skippedShapes.length, 1);
      expect(result.skippedShapes.first.id, 'invalid');
      expect(result.skippedShapes.first.reason, ShapeSkipReason.tooFewPoints);
    });

    test('skips shapes with zero area bounds', () {
      const service = ShapeMergeService();
      final shapes = [
        Shape(
          id: 'valid',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'zeroArea',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 0, 100), // Zero width
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'valid2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
      ];
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['valid', 'zeroArea', 'valid2'],
        createId: () => 'merged-${idCounter++}',
      );

      expect(result.skippedShapes.length, 1);
      expect(result.skippedShapes.first.id, 'zeroArea');
      expect(result.skippedShapes.first.reason, ShapeSkipReason.zeroArea);
    });

    test('provides skip summary for user feedback', () {
      const service = ShapeMergeService();
      final shapes = [
        Shape(
          id: 'valid',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'tooFew',
          kind: ShapeKind.freehand,
          points: const [Offset(0, 0)],
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
        Shape(
          id: 'valid2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
        ),
      ];
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['valid', 'tooFew', 'valid2'],
        createId: () => 'merged-${idCounter++}',
      );

      expect(result.hasSkippedShapes, isTrue);
      expect(result.skipSummary, contains('too few points'));
    });
  });

  group('Property Inheritance', () {
    test('inherits visibility from style source', () {
      const service = ShapeMergeService();
      final shapes = [
        Shape(
          id: 'rect1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
          isVisible: false, // Hidden
        ),
        Shape(
          id: 'rect2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
          isVisible: true,
        ),
      ];
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
      );

      // Should inherit visibility from first shape (style source)
      expect(result.mergedShapes.first.isVisible, isFalse);
    });

    test('inherits lock state from style source', () {
      const service = ShapeMergeService();
      final shapes = [
        Shape(
          id: 'rect1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
          isLocked: true, // Locked
        ),
        Shape(
          id: 'rect2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 1.0,
          isLocked: false,
        ),
      ];
      var idCounter = 0;

      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
      );

      // Should inherit lock state from first shape (style source)
      expect(result.mergedShapes.first.isLocked, isTrue);
    });
  });

  group('Path Simplification', () {
    test('simplifies merged paths when epsilon > 0', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      final withoutSimplification = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        simplifyEpsilon: 0, // No simplification
      );

      idCounter = 0;
      final withSimplification = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        simplifyEpsilon: 5.0, // More aggressive simplification
      );

      // Simplified version should have equal or fewer points
      expect(
        withSimplification.mergedShapes.first.points.length,
        lessThanOrEqualTo(withoutSimplification.mergedShapes.first.points.length),
      );
    });
  });

  group('Adaptive Sampling', () {
    test('uses adaptive sampling when sampleDistance is 0', () {
      const service = ShapeMergeService();
      final shapes = _createOverlappingRectangles();
      var idCounter = 0;

      // This should use adaptive sampling without errors
      final result = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: () => 'merged-${idCounter++}',
        sampleDistance: 0, // Adaptive
      );

      expect(result.mergedShapes.length, 1);
      expect(result.mergedShapes.first.points.length, greaterThan(0));
    });
  });
  group('Async Path Operations', () {
    test('mergeAsync returns same result as sync merge for 2 shapes', () async {
      const service = ShapeMergeService();

      final shapes = [
        Shape(
          id: 'rect1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFFFF0000),
        ),
        Shape(
          id: 'rect2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFF00FF00),
        ),
      ];

      var idCounter = 0;
      String createId() => 'merged-${idCounter++}';

      // Run sync version
      idCounter = 0;
      final syncResult = service.merge(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: createId,
      );

      // Run async version
      idCounter = 0;
      final asyncResult = await service.mergeAsync(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2'],
        createId: createId,
      );

      // Results should be equivalent
      expect(asyncResult.mergedShapes.length, equals(syncResult.mergedShapes.length));
      expect(asyncResult.removedIds, equals(syncResult.removedIds));
      expect(asyncResult.skippedIds, equals(syncResult.skippedIds));
    });

    test('mergeAsync handles 3+ shapes (uses isolate)', () async {
      const service = ShapeMergeService();

      final shapes = [
        Shape(
          id: 'rect1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFFFF0000),
        ),
        Shape(
          id: 'rect2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(50, 50, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFF00FF00),
        ),
        Shape(
          id: 'rect3',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(100, 100, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFF0000FF),
        ),
      ];

      var idCounter = 0;
      final result = await service.mergeAsync(
        shapes: shapes,
        selectedIds: ['rect1', 'rect2', 'rect3'],
        createId: () => 'merged-${idCounter++}',
      );

      // Should successfully merge
      expect(result.mergedShapes.length, greaterThan(0));
      expect(result.removedIds.length, equals(3));
    });

    test('mergeAsync returns empty for single shape', () async {
      const service = ShapeMergeService();

      final shapes = [
        Shape(
          id: 'rect1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
        ),
      ];

      final result = await service.mergeAsync(
        shapes: shapes,
        selectedIds: ['rect1'],
        createId: () => 'merged',
      );

      expect(result.mergedShapes, isEmpty);
      expect(result.removedIds, isEmpty);
    });

    test('eraseAsync returns same result as sync erase for simple shape', () async {
      const service = ShapeEraseService();

      final shape = Shape(
        id: 'rect1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
        fillColor: const Color(0xFFFF0000),
      );

      // Small eraser path
      final eraserPath = Path()
        ..addRect(const Rect.fromLTWH(80, 80, 40, 40));

      var idCounter = 0;
      String createId() => 'erased-${idCounter++}';

      // Run sync version
      idCounter = 0;
      final syncResult = service.erase(
        shape: shape,
        eraserPath: eraserPath,
        createId: createId,
      );

      // Run async version
      idCounter = 0;
      final asyncResult = await service.eraseAsync(
        shape: shape,
        eraserPath: eraserPath,
        createId: createId,
      );

      // Results should be equivalent
      expect(asyncResult.didErase, equals(syncResult.didErase));
      expect(asyncResult.replacements.length, equals(syncResult.replacements.length));
    });

    test('eraseAsync handles complex shape (uses isolate)', () async {
      const service = ShapeEraseService();

      // Create a complex freehand shape with many points
      final points = <Offset>[];
      for (int i = 0; i < 100; i++) {
        points.add(Offset(i.toDouble(), (i % 10).toDouble()));
      }

      final shape = Shape(
        id: 'freehand1',
        kind: ShapeKind.freehand,
        points: points,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
        isClosed: true,
      );

      final eraserPath = Path()
        ..addRect(const Rect.fromLTWH(40, 0, 20, 10));

      var idCounter = 0;
      final result = await service.eraseAsync(
        shape: shape,
        eraserPath: eraserPath,
        createId: () => 'erased-${idCounter++}',
      );

      // Should handle the operation without errors
      expect(result, isNotNull);
    });

    test('eraseAsync returns noop when eraser does not overlap', () async {
      const service = ShapeEraseService();

      final shape = Shape(
        id: 'rect1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 5.0,
      );

      // Eraser path far away from shape
      final eraserPath = Path()
        ..addRect(const Rect.fromLTWH(200, 200, 40, 40));

      final result = await service.eraseAsync(
        shape: shape,
        eraserPath: eraserPath,
        createId: () => 'erased',
      );

      expect(result.didErase, isFalse);
      expect(result.replacements, isEmpty);
    });

    test('mergeAsync completes within reasonable time for many shapes', () async {
      const service = ShapeMergeService();

      // Create 10 overlapping rectangles
      final shapes = List.generate(
        10,
        (i) => Shape(
          id: 'rect$i',
          kind: ShapeKind.rectangle,
          bounds: Rect.fromLTWH(i * 10.0, i * 10.0, 100, 100),
          strokeColor: const Color(0xFF000000),
          strokeWidth: 5.0,
          fillColor: const Color(0xFFFF0000),
        ),
      );

      final stopwatch = Stopwatch()..start();
      var idCounter = 0;
      final result = await service.mergeAsync(
        shapes: shapes,
        selectedIds: shapes.map((s) => s.id).toList(),
        createId: () => 'merged-${idCounter++}',
      );
      stopwatch.stop();

      // Should complete within 5 seconds even with isolate overhead
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(result.mergedShapes.length, greaterThan(0));
    });
  });
}

// Helper functions for creating test shapes
List<Shape> _createOverlappingRectangles() {
  return [
    Shape(
      id: 'rect1',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(0, 0, 100, 100),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 5.0,
      fillColor: const Color(0xFFFF0000),
    ),
    Shape(
      id: 'rect2',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(50, 50, 100, 100),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 5.0,
      fillColor: const Color(0xFF00FF00),
    ),
  ];
}

List<Shape> _createDisjointRectangles() {
  return [
    Shape(
      id: 'rect1',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(0, 0, 50, 50),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 5.0,
      fillColor: const Color(0xFFFF0000),
    ),
    Shape(
      id: 'rect2',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(200, 200, 50, 50), // Far away, no overlap
      strokeColor: const Color(0xFF000000),
      strokeWidth: 5.0,
      fillColor: const Color(0xFF00FF00),
    ),
  ];
}
