import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('undo restores shape after eraser stroke', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CanvasScreen())),
    );

    final context = tester.element(find.byType(CanvasScreen));
    final container = ProviderScope.containerOf(context);
    final vm = container.read(editorViewModelProvider.notifier);

    final shape = Shape(
      id: 'shape-1',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(100, 100, 200, 120),
      strokeColor: Colors.black,
      strokeWidth: 4,
      fillColor: Colors.blue,
    );
    vm.setShapes([shape]);
    vm.setActiveTool(EditorTool.eraser);
    await tester.pump();

    vm.startDrawing(const Offset(120, 160));
    vm.continueDrawing(const Offset(280, 160));
    await vm.endDrawing();
    await tester.pump();

    final erased = container.read(editorViewModelProvider).shapes.single;
    expect(erased.hasEraseMask, isTrue);

    await vm.undo();
    await tester.pump(const Duration(milliseconds: 200));

    final restored = container.read(editorViewModelProvider).shapes.single;
    expect(restored.hasEraseMask, isFalse);
  });

  testWidgets('undo waits for in-flight eraser commit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CanvasScreen())),
    );

    final context = tester.element(find.byType(CanvasScreen));
    final container = ProviderScope.containerOf(context);
    final vm = container.read(editorViewModelProvider.notifier);

    final shape = Shape(
      id: 'shape-1',
      kind: ShapeKind.rectangle,
      bounds: const Rect.fromLTWH(100, 100, 200, 120),
      strokeColor: Colors.black,
      strokeWidth: 4,
      fillColor: Colors.blue,
    );
    vm.setShapes([shape]);
    vm.setActiveTool(EditorTool.eraser);
    await tester.pump();

    vm.startDrawing(const Offset(120, 160));
    vm.continueDrawing(const Offset(280, 160));

    // Intentionally do not await to emulate pointer-up flow.
    final commitFuture = vm.endDrawing();
    final undoFuture = vm.undo();

    await Future.wait([commitFuture, undoFuture]);
    await tester.pump(const Duration(milliseconds: 200));

    final restored = container.read(editorViewModelProvider).shapes.single;
    expect(restored.hasEraseMask, isFalse);
  });
}
