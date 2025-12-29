import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas_painter.dart';
import 'editor_view_model.dart';

class CanvasArea extends ConsumerWidget {
  const CanvasArea({super.key});

  // Fixed logical canvas size.
  static const Size _designSize = Size(1920, 1080);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shapes = ref.watch(editorViewModelProvider.select((s) => s.shapes));
    final selectedShapeId =
        ref.watch(editorViewModelProvider.select((s) => s.selectedShapeId));
    final activeTool =
        ref.watch(editorViewModelProvider.select((s) => s.activeTool));
    final isPanMode =
        ref.watch(editorViewModelProvider.select((s) => s.isPanMode));
    final inProgressStroke =
        ref.watch(editorViewModelProvider.select((s) => s.inProgressStroke));
    final brushThickness =
        ref.watch(editorViewModelProvider.select((s) => s.brushThickness));
    final brushOpacity =
        ref.watch(editorViewModelProvider.select((s) => s.brushOpacity));
    final brushSmoothness =
        ref.watch(editorViewModelProvider.select((s) => s.brushSmoothness));
    final brushColor =
        ref.watch(editorViewModelProvider.select((s) => s.currentColor));
    final ui.Image? raster =
        ref.watch(editorViewModelProvider.select((s) => s.rasterLayer));
    final vm = ref.read(editorViewModelProvider.notifier);

    // Fix raster resolution to design size.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => vm.updateCanvasSize(_designSize),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _computeScale(
          constraints.maxWidth,
          constraints.maxHeight,
          _designSize,
        );
        final offset = Offset(
          (constraints.maxWidth - _designSize.width * scale) / 2,
          (constraints.maxHeight - _designSize.height * scale) / 2,
        );

        Offset _toCanvas(Offset local) => Offset(
              (local.dx - offset.dx) / scale,
              (local.dy - offset.dy) / scale,
            );

        final painter = CustomPaint(
          painter: CanvasPainter(
            shapes: shapes,
            selectedShapeId: selectedShapeId,
            rasterLayer: raster,
            inProgressStroke: inProgressStroke,
            brushThickness: brushThickness,
            brushOpacity: brushOpacity,
            brushSmoothness: brushSmoothness,
            brushColor: brushColor,
          ),
          child: const SizedBox.expand(),
        );

        final canvasContent = SizedBox(
          width: _designSize.width,
          height: _designSize.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRect(
              child: RepaintBoundary(child: painter),
            ),
          ),
        );

        final scaledCanvas = Positioned(
          left: offset.dx,
          top: offset.dy,
          width: _designSize.width * scale,
          height: _designSize.height * scale,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: canvasContent,
          ),
        );

        Widget child;
        if (isPanMode) {
          child = InteractiveViewer(
            constrained: false,
            panEnabled: true,
            scaleEnabled: true,
            minScale: 0.25,
            maxScale: 8.0,
            boundaryMargin: const EdgeInsets.all(2000),
            child: Stack(children: [scaledCanvas]),
          );
        } else {
          child = GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanDown: (d) {
              final pos = _toCanvas(d.localPosition);
              if (activeTool == EditorTool.brush) {
                vm.startDrawing(pos);
              } else if (activeTool == EditorTool.shape) {
                vm.startShapeDrawing(pos);
              }
            },
            onTapDown: (d) {
              if (activeTool == EditorTool.select) {
                vm.selectAtPoint(_toCanvas(d.localPosition));
              }
            },
            onPanUpdate: (d) {
              final pos = _toCanvas(d.localPosition);
              switch (activeTool) {
                case EditorTool.brush:
                  vm.continueDrawing(pos);
                  break;
                case EditorTool.shape:
                  vm.updateShapeDrawing(pos);
                  break;
                case EditorTool.select:
                  vm.moveSelectedBy(d.delta / scale);
                  break;
              }
            },
            onPanEnd: (_) {
              switch (activeTool) {
                case EditorTool.brush:
                  vm.endDrawing();
                  break;
                case EditorTool.shape:
                  vm.finishShapeDrawing();
                  break;
                case EditorTool.select:
                  vm.rebuildQuadTree();
                  vm.finalizeSelectionEdit();
                  break;
              }
            },
            onPanCancel: () {
              switch (activeTool) {
                case EditorTool.brush:
                  vm.endDrawing();
                  break;
                case EditorTool.shape:
                  vm.finishShapeDrawing();
                  break;
                case EditorTool.select:
                  break;
              }
            },
            child: Stack(children: [scaledCanvas]),
          );
        }

        return SizedBox.expand(child: Stack(children: [child]));
      },
    );
  }

  double _computeScale(double maxW, double maxH, Size design) {
    if (maxW <= 0 || maxH <= 0) return 1.0;
    final scaleX = maxW / design.width;
    final scaleY = maxH / design.height;
    return scaleX < scaleY ? scaleX : scaleY;
  }
}
