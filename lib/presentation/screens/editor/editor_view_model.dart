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
  });

  factory EditorState.initial() => const EditorState(
        shapes: <Shape>[],
        activeTool: EditorTool.brush,
        selectedShapeId: null,
        currentFrame: 0,
      );

  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
  final int currentFrame;

  EditorState copyWith({
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
    int? currentFrame,
  }) {
    return EditorState(
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId: selectedShapeId ?? this.selectedShapeId,
      currentFrame: currentFrame ?? this.currentFrame,
    );
  }
}

class EditorViewModel extends Notifier<EditorState> {
  @override
  EditorState build() => EditorState.initial();

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
}

final editorViewModelProvider =
    NotifierProvider<EditorViewModel, EditorState>(EditorViewModel.new);

