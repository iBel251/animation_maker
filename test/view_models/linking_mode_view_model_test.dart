import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/linking_mode_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkingModeViewModel', () {
    late EditorState state;
    late LinkingModeViewModel viewModel;
    late bool historyPushed;

    setUp(() {
      historyPushed = false;

      // Create two shapes for testing linking
      final parentShape = Shape(
        id: 'parent-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(100, 100, 50, 50),
        strokeColor: Colors.black,
        strokeWidth: 2,
      );

      final childShape = Shape(
        id: 'child-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(200, 200, 30, 30),
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

    group('enterLinkingMode', () {
      test('enters linking mode with selected shape as source', () {
        viewModel.enterLinkingMode();

        expect(state.isLinkingMode, isTrue);
        expect(state.linkingSourceShapeId, 'child-1');
      });

      test('does nothing if no shape is selected', () {
        state = state.copyWith(clearSelection: true);

        viewModel.enterLinkingMode();

        expect(state.isLinkingMode, isFalse);
        expect(state.linkingSourceShapeId, isNull);
      });
    });

    group('exitLinkingMode', () {
      test('exits linking mode and clears source', () {
        viewModel.enterLinkingMode();
        expect(state.isLinkingMode, isTrue);

        viewModel.exitLinkingMode();

        expect(state.isLinkingMode, isFalse);
        expect(state.linkingSourceShapeId, isNull);
      });

      test('can exit even if not in linking mode', () {
        viewModel.exitLinkingMode();

        expect(state.isLinkingMode, isFalse);
      });
    });

    group('completeLinking', () {
      test('links child to parent successfully', () {
        viewModel.enterLinkingMode();

        viewModel.completeLinking('parent-1');

        expect(state.isLinkingMode, isFalse);
        expect(historyPushed, isTrue);

        final linkedChild =
            state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(linkedChild.parentId, 'parent-1');
      });

      test('exits linking mode if source shape not found', () {
        state = state.copyWith(
          isLinkingMode: true,
          linkingSourceShapeId: 'non-existent',
        );

        viewModel.completeLinking('parent-1');

        expect(state.isLinkingMode, isFalse);
        expect(historyPushed, isFalse);
      });

      test('exits linking mode if target parent not found', () {
        viewModel.enterLinkingMode();

        viewModel.completeLinking('non-existent-parent');

        expect(state.isLinkingMode, isFalse);
        expect(historyPushed, isFalse);
      });

      test('exits linking mode if no source shape id', () {
        state = state.copyWith(
          isLinkingMode: true,
          clearLinkingSource: true,
        );

        viewModel.completeLinking('parent-1');

        expect(state.isLinkingMode, isFalse);
      });

      test('prevents circular reference (shape linking to itself)', () {
        // Try to link shape to itself
        viewModel.enterLinkingMode();

        viewModel.completeLinking('child-1');

        // Should exit linking mode without creating link
        expect(state.isLinkingMode, isFalse);
        final shape = state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(shape.parentId, isNull);
      });
    });

    group('unlinkFromParent', () {
      test('unlinks child from parent', () {
        // First create a link
        viewModel.enterLinkingMode();
        viewModel.completeLinking('parent-1');
        historyPushed = false;

        // Now unlink
        viewModel.unlinkFromParent();

        expect(historyPushed, isTrue);
        final unlinkedChild =
            state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(unlinkedChild.parentId, isNull);
      });

      test('does nothing if no shape is selected', () {
        state = state.copyWith(clearSelection: true);

        viewModel.unlinkFromParent();

        expect(historyPushed, isFalse);
      });

      test('does nothing if shape has no parent', () {
        viewModel.unlinkFromParent();

        expect(historyPushed, isFalse);
      });
    });

    group('unlinkAllChildren', () {
      test('unlinks all children from selected parent', () {
        // Create another child and link both to parent
        final childShape2 = Shape(
          id: 'child-2',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(300, 300, 30, 30),
          strokeColor: Colors.red,
          strokeWidth: 2,
          parentId: 'parent-1',
        );

        // Link first child
        viewModel.enterLinkingMode();
        viewModel.completeLinking('parent-1');

        // Add second child already linked
        state = state.copyWith(
          shapes: [...state.shapes, childShape2],
          selectedShapeId: 'parent-1',
          selectedShapeIds: ['parent-1'],
        );
        historyPushed = false;

        // Now unlink all children from parent
        viewModel.unlinkAllChildren();

        expect(historyPushed, isTrue);
        for (final shape in state.shapes) {
          if (shape.id == 'child-1' || shape.id == 'child-2') {
            expect(shape.parentId, isNull);
          }
        }
      });

      test('does nothing if no shape is selected', () {
        state = state.copyWith(clearSelection: true);

        viewModel.unlinkAllChildren();

        expect(historyPushed, isFalse);
      });

      test('does nothing if shape has no children', () {
        state = state.copyWith(
          selectedShapeId: 'child-1',
          selectedShapeIds: ['child-1'],
        );

        viewModel.unlinkAllChildren();

        expect(historyPushed, isFalse);
      });
    });

    group('getParentOf', () {
      test('returns parent shape when linked', () {
        // Create a link
        viewModel.enterLinkingMode();
        viewModel.completeLinking('parent-1');

        final child = state.shapes.firstWhere((s) => s.id == 'child-1');
        final parent = viewModel.getParentOf(child);

        expect(parent, isNotNull);
        expect(parent!.id, 'parent-1');
      });

      test('returns null when no parent', () {
        final child = state.shapes.firstWhere((s) => s.id == 'child-1');
        final parent = viewModel.getParentOf(child);

        expect(parent, isNull);
      });
    });

    group('getChildrenOf', () {
      test('returns children when they exist', () {
        // Create a link
        viewModel.enterLinkingMode();
        viewModel.completeLinking('parent-1');

        final parent = state.shapes.firstWhere((s) => s.id == 'parent-1');
        final children = viewModel.getChildrenOf(parent);

        expect(children.length, 1);
        expect(children.first.id, 'child-1');
      });

      test('returns empty list when no children', () {
        final child = state.shapes.firstWhere((s) => s.id == 'child-1');
        final children = viewModel.getChildrenOf(child);

        expect(children, isEmpty);
      });
    });

    group('hasChildren', () {
      test('returns true when shape has children', () {
        // Create a link
        viewModel.enterLinkingMode();
        viewModel.completeLinking('parent-1');

        final parent = state.shapes.firstWhere((s) => s.id == 'parent-1');
        expect(viewModel.hasChildren(parent), isTrue);
      });

      test('returns false when shape has no children', () {
        final child = state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(viewModel.hasChildren(child), isFalse);
      });
    });

    group('integration', () {
      test('full linking workflow', () {
        // Enter linking mode
        viewModel.enterLinkingMode();
        expect(state.isLinkingMode, isTrue);
        expect(state.linkingSourceShapeId, 'child-1');

        // Complete linking
        viewModel.completeLinking('parent-1');
        expect(state.isLinkingMode, isFalse);
        expect(historyPushed, isTrue);

        // Verify link
        final child = state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(child.parentId, 'parent-1');

        // Verify parent-child queries work
        final parent = state.shapes.firstWhere((s) => s.id == 'parent-1');
        expect(viewModel.getParentOf(child)?.id, 'parent-1');
        expect(viewModel.getChildrenOf(parent).first.id, 'child-1');
        expect(viewModel.hasChildren(parent), isTrue);

        // Unlink
        historyPushed = false;
        viewModel.unlinkFromParent();
        expect(historyPushed, isTrue);

        final unlinkedChild = state.shapes.firstWhere((s) => s.id == 'child-1');
        expect(unlinkedChild.parentId, isNull);
      });
    });
  });
}
