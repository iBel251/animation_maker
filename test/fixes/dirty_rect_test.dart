import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/presentation/painters/canvas_painter.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dirty Rect Tracking', () {
    test('shouldRepaint returns false when shapes unchanged', () {
      final shapes = [
        Shape(
          id: 'shape1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: Colors.black,
          strokeWidth: 5.0,
        ),
      ];

      final painter1 = CanvasPainter(
        shapes: shapes,
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: shapes,
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('shouldRepaint returns true when shape added', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      final shape2 = Shape(
        id: 'shape2',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(150, 150, 100, 100),
        strokeColor: Colors.red,
        strokeWidth: 5.0,
      );

      final painter1 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1, shape2],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when shape removed', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      final shape2 = Shape(
        id: 'shape2',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(150, 150, 100, 100),
        strokeColor: Colors.red,
        strokeWidth: 5.0,
      );

      final painter1 = CanvasPainter(
        shapes: [shape1, shape2],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when shape modified', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      // Create a new shape with same ID but different properties
      // Shape equality is based on reference, not ID, so this will be different
      final shape1Modified = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.red,  // Changed color
        strokeWidth: 5.0,
      );

      final painter1 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1Modified],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when shape moved', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      // Create a new shape with same ID but different position
      final shape1Moved = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
        translation: const Offset(50, 50),  // Moved position
      );

      final painter1 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1Moved],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true for UI changes', () {
      final shapes = [
        Shape(
          id: 'shape1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          strokeColor: Colors.black,
          strokeWidth: 5.0,
        ),
      ];

      final painter1 = CanvasPainter(
        shapes: shapes,
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: shapes,
        selectedShapeId: 'shape1', // Changed selection
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint clears dirty tracking on UI changes', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      final shape1Modified = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.red,  // Changed color
        strokeWidth: 5.0,
      );

      // First change: shape modification (should track dirty rect)
      final painter1 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1Modified],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      // Second change: UI change (should clear dirty tracking)
      final painter3 = CanvasPainter(
        shapes: [shape1Modified],
        selectedShapeId: 'shape1', // UI change
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      // Both should trigger repaint
      expect(painter2.shouldRepaint(painter1), isTrue);
      expect(painter3.shouldRepaint(painter2), isTrue);
    });

    test('paint method completes without errors with dirty tracking', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      final painter = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      // Create a test canvas
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Should not throw
      expect(
        () => painter.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );

      recorder.endRecording();
    });

    test('paint works correctly after shape modification', () {
      final shape1 = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.black,
        strokeWidth: 5.0,
      );

      final shape1Modified = Shape(
        id: 'shape1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        strokeColor: Colors.red,  // Changed color
        strokeWidth: 5.0,
      );

      final painter1 = CanvasPainter(
        shapes: [shape1],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      final painter2 = CanvasPainter(
        shapes: [shape1Modified],
        selectedShapeId: null,
        selectionMode: SelectionMode.single,
        inProgressStroke: const [],
        brushThickness: 5.0,
        brushOpacity: 1.0,
        brushSmoothness: 0.5,
        brushColor: Colors.black,
        strokeScaleWithShape: false,
        selectionColor: Colors.blue,
        activeTool: EditorTool.brush,
      );

      // Trigger dirty tracking
      painter2.shouldRepaint(painter1);

      // Paint should work with dirty tracking active
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter2.paint(canvas, const Size(800, 600)),
        returnsNormally,
      );

      recorder.endRecording();
    });
  });
}
