import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Eraser modifies shape when crossing it', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(),
        ),
      ),
    );

    final container = tester.element(find.byType(CanvasScreen));
    final providerContainer = ProviderScope.containerOf(container);
    final viewModel = providerContainer.read(editorViewModelProvider.notifier);

    // Get the canvas size to calculate proper coordinates
    final canvasSize = tester.getSize(find.byType(CanvasScreen));
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    // 1. Add a rectangle shape at the center of the canvas
    final shape = Shape(
      id: 'test_shape',
      kind: ShapeKind.rectangle,
      bounds: Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: 100,
        height: 100,
      ),
      strokeColor: Colors.red,
      strokeWidth: 4,
      fillColor: Colors.blue, // Filled shape so eraser works inside
    );
    viewModel.setShapes([shape]);
    await tester.pump();
    expect(providerContainer.read(editorViewModelProvider).shapes.length, 1);

    // 2. Find and tap the eraser tool button.
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();

    // Verify that the active tool is the eraser.
    expect(
      providerContainer.read(editorViewModelProvider).activeTool,
      EditorTool.eraser,
    );

    // 3. Start erasing across the center of the shape
    viewModel.startDrawing(
      Offset(centerX - 60, centerY),
      pressure: 1.0,
      timeStamp: Duration.zero,
    );
    await tester.pump();

    // Continue drawing across the shape
    for (var i = 0; i < 10; i++) {
      viewModel.continueDrawing(
        Offset(centerX - 60 + (i * 15), centerY),
        pressure: 1.0,
        timeStamp: Duration(milliseconds: i * 16),
      );
      await tester.pump();
    }

    // End drawing
    await viewModel.endDrawing();
    await tester.pump();

    // 4. Verify the shape was modified in place (same ID, different geometry)
    final shapesAfter = providerContainer.read(editorViewModelProvider).shapes;
    // The rectangle should be erased and replaced with a polygon
    expect(shapesAfter.length, 1);
    // The shape ID should be preserved (modified in place, not a new shape)
    expect(shapesAfter.first.id, 'test_shape');
    // The shape should now be a polygon (result of erasing a rectangle)
    expect(shapesAfter.first.kind, ShapeKind.polygon);
  });

  testWidgets('Eraser does not affect unfilled stroke when not touching it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(),
        ),
      ),
    );

    final container = tester.element(find.byType(CanvasScreen));
    final providerContainer = ProviderScope.containerOf(container);
    final viewModel = providerContainer.read(editorViewModelProvider.notifier);

    // 1. Add an unfilled freehand stroke (a simple line)
    final shape = Shape(
      id: 'test_stroke',
      kind: ShapeKind.freehand,
      points: const [
        Offset(100, 100),
        Offset(200, 100),
        Offset(300, 100),
      ],
      strokeColor: Colors.red,
      strokeWidth: 4,
      fillColor: null, // No fill - stroke only
    );
    viewModel.setShapes([shape]);
    await tester.pump();
    expect(providerContainer.read(editorViewModelProvider).shapes.length, 1);

    // 2. Switch to eraser tool
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();

    // 3. Erase INSIDE the stroke area but not touching the stroke line
    // The stroke is a horizontal line at y=100
    // We'll erase at y=120 which is below the stroke
    viewModel.startDrawing(
      const Offset(150, 120),
      pressure: 1.0,
      timeStamp: Duration.zero,
    );
    await tester.pump();

    viewModel.continueDrawing(
      const Offset(250, 120),
      pressure: 1.0,
      timeStamp: const Duration(milliseconds: 16),
    );
    await tester.pump();

    await viewModel.endDrawing();
    await tester.pump();

    // 4. The stroke should NOT be affected since we didn't touch it
    final shapesAfter = providerContainer.read(editorViewModelProvider).shapes;
    expect(shapesAfter.length, 1);
    expect(shapesAfter.first.id, 'test_stroke'); // Same shape, unmodified
    expect(shapesAfter.first.kind, ShapeKind.freehand); // Still freehand
  });

  testWidgets('Eraser does not affect unfilled rectangle when erasing inside',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CanvasScreen(),
        ),
      ),
    );

    final container = tester.element(find.byType(CanvasScreen));
    final providerContainer = ProviderScope.containerOf(container);
    final viewModel = providerContainer.read(editorViewModelProvider.notifier);

    // 1. Add an unfilled rectangle (stroke only, no fill)
    final shape = Shape(
      id: 'test_rect',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(100, 100, 200, 200),
      strokeColor: Colors.red,
      strokeWidth: 4,
      fillColor: null, // No fill - stroke only
    );
    viewModel.setShapes([shape]);
    await tester.pump();
    expect(providerContainer.read(editorViewModelProvider).shapes.length, 1);

    // 2. Switch to eraser tool
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();

    // 3. Erase INSIDE the rectangle (not touching the border)
    // Rectangle is at (100, 100) to (300, 300)
    // We'll erase in the middle at (200, 200)
    viewModel.startDrawing(
      const Offset(180, 200),
      pressure: 1.0,
      timeStamp: Duration.zero,
    );
    await tester.pump();

    viewModel.continueDrawing(
      const Offset(220, 200),
      pressure: 1.0,
      timeStamp: const Duration(milliseconds: 16),
    );
    await tester.pump();

    await viewModel.endDrawing();
    await tester.pump();

    // 4. The rectangle should NOT be affected since we didn't touch the border
    final shapesAfter = providerContainer.read(editorViewModelProvider).shapes;
    expect(shapesAfter.length, 1);
    expect(shapesAfter.first.id, 'test_rect'); // Same shape, unmodified
    expect(shapesAfter.first.kind, ShapeKind.rectangle); // Still rectangle
  });
}
