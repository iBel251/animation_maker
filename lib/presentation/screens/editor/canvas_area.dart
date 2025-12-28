import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas_painter.dart';
import 'editor_view_model.dart';

class CanvasArea extends ConsumerWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shapes = ref.watch(editorViewModelProvider.select((s) => s.shapes));
    final selectedShapeId =
        ref.watch(editorViewModelProvider.select((s) => s.selectedShapeId));
    final activeTool =
        ref.watch(editorViewModelProvider.select((s) => s.activeTool));
    final viewModel = ref.read(editorViewModelProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        if (activeTool != EditorTool.brush) return;
        viewModel.startDrawing(details.localPosition);
      },
      onPanUpdate: (details) {
        if (activeTool != EditorTool.brush) return;
        viewModel.continueDrawing(details.localPosition);
      },
      onPanEnd: (_) {
        if (activeTool != EditorTool.brush) return;
        viewModel.endDrawing();
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: CanvasPainter(
              shapes: shapes,
              selectedShapeId: selectedShapeId,
            ),
            child: SizedBox.expand(
              child: Center(
                child: Text('Canvas (draw here) — Shapes: ${shapes.length}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

