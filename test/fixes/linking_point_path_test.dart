import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/linking_mode_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkingModeViewModel with PointPath', () {
    late EditorState state;
    late LinkingModeViewModel viewModel;
    late bool historyPushed;

    setUp(() {
      historyPushed = false;

      // Create a parent shape
      final parentShape = Shape(
        id: 'parent-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(100, 100, 50, 50),
        strokeColor: Colors.black,
        strokeWidth: 2,
      );

      // Create a point path shape
      final childShape = Shape(
        id: 'child-1',
        kind: ShapeKind.pointPath,
        points: const [Offset(200, 200), Offset(220, 220)],
        strokeColor: Colors.blue,
        strokeWidth: 2,
      );

      state = EditorState.initial().copyWith(
        shapes: [parentShape, childShape],
        selectedShapeId: 'child-1',
        selectedShapeIds: ['child-1'],
      );

      viewModel = LinkingModeViewModel(
        getState: () => state,
        setState: (newState) => state = newState,
        setShapesAndRebuild: (shapes) {
          state = state.copyWith(shapes: shapes);
        },
        pushHistory: () => historyPushed = true,
      );
    });

    test('links a pointPath child to a parent successfully', () {
      viewModel.enterLinkingMode();
      viewModel.completeLinking('parent-1');

      expect(state.isLinkingMode, isFalse);
      expect(historyPushed, isTrue);

      final linkedChild = state.shapes.firstWhere((s) => s.id == 'child-1');
      expect(linkedChild.parentId, 'parent-1');
    });
  });
}
