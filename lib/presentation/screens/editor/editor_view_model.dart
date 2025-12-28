import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EditorTool {
  brush,
  shape,
  select,
}

class EditorState {
  const EditorState({
    required this.shapes,
    required this.activeTool,
    required this.selectedShapeId,
    required this.currentFrame,
    required this.isPropertiesOpen,
  });

  factory EditorState.initial() => const EditorState(
        shapes: <Shape>[],
        activeTool: EditorTool.brush,
        selectedShapeId: null,
        currentFrame: 0,
        isPropertiesOpen: true,
      );

  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
  final int currentFrame;
  final bool isPropertiesOpen;

  EditorState copyWith({
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
    int? currentFrame,
    bool? isPropertiesOpen,
  }) {
    return EditorState(
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId: selectedShapeId ?? this.selectedShapeId,
      currentFrame: currentFrame ?? this.currentFrame,
      isPropertiesOpen: isPropertiesOpen ?? this.isPropertiesOpen,
    );
  }
}

class EditorViewModel extends Notifier<EditorState> {
  @override
  EditorState build() => EditorState.initial();

  String? _currentDrawingId;

  void setActiveTool(EditorTool tool) {
    state = state.copyWith(activeTool: tool);
  }

  void selectShape(String? shapeId) {
    state = state.copyWith(selectedShapeId: shapeId);
  }

  void setShapes(List<Shape> shapes) {
    state = state.copyWith(shapes: List<Shape>.unmodifiable(shapes));
  }

  void setCurrentFrame(int frame) {
    state = state.copyWith(currentFrame: frame);
  }

  void togglePropertiesPanel() {
    state = state.copyWith(isPropertiesOpen: !state.isPropertiesOpen);
  }

  void startDrawing(Offset point) {
    if (state.activeTool != EditorTool.brush) return;
    final newShape = Shape(
      id: 'shape-${DateTime.now().microsecondsSinceEpoch}',
      kind: ShapeKind.freehand,
      points: [point],
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2.0,
    );
    final updatedShapes = [...state.shapes, newShape];
    state = state.copyWith(
      shapes: updatedShapes,
      selectedShapeId: newShape.id,
    );
    _currentDrawingId = newShape.id;
  }

  void continueDrawing(Offset point) {
    if (_currentDrawingId == null || state.activeTool != EditorTool.brush) {
      return;
    }
    final index =
        state.shapes.indexWhere((shape) => shape.id == _currentDrawingId);
    if (index == -1) return;

    final target = state.shapes[index];
    final updatedPoints = [...target.points, point];
    final updatedShape = target.copyWith(points: updatedPoints);

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updatedShape;

    state = state.copyWith(shapes: updatedShapes);
  }

  void endDrawing() {
    _currentDrawingId = null;
  }
}

final editorViewModelProvider =
    NotifierProvider<EditorViewModel, EditorState>(EditorViewModel.new);

