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
        switch (activeTool) {
          case EditorTool.brush:
            viewModel.startDrawing(details.localPosition);
            break;
          case EditorTool.shape:
            viewModel.startShapeDrawing(details.localPosition);
            break;
          case EditorTool.select:
            viewModel.selectAtPoint(details.localPosition);
            break;
        }
      },
      onPanUpdate: (details) {
        switch (activeTool) {
          case EditorTool.brush:
            viewModel.continueDrawing(details.localPosition);
            break;
          case EditorTool.shape:
            viewModel.updateShapeDrawing(details.localPosition);
            break;
          case EditorTool.select:
            viewModel.moveSelectedBy(details.delta);
            break;
        }
      },
      onPanEnd: (_) {
        switch (activeTool) {
          case EditorTool.brush:
            viewModel.endDrawing();
            break;
          case EditorTool.shape:
            viewModel.finishShapeDrawing();
            break;
          case EditorTool.select:
            viewModel.rebuildQuadTree();
            break;
        }
      },
      onTapDown: (details) {
        if (activeTool == EditorTool.select) {
          viewModel.selectAtPoint(details.localPosition);
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: ClipRect(
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
      ),
    );
  }
}

