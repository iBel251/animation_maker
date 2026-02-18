import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/node_edit_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NodeEditViewModel', () {
    late EditorState state;
    late NodeEditViewModel viewModel;
    late bool historyPushed;
    late bool autosaveQueued;
    late bool quadTreeRebuilt;
    late bool selectionDirty;
    late int shapeIdCounter;

    setUp(() {
      historyPushed = false;
      autosaveQueued = false;
      quadTreeRebuilt = false;
      selectionDirty = false;
      shapeIdCounter = 0;

      // Create a freehand shape that supports node editing
      final testShape = Shape(
        id: 'shape-1',
        kind: ShapeKind.freehand,
        points: const [
          Offset(100, 100),
          Offset(150, 120),
          Offset(200, 100),
          Offset(250, 150),
        ],
        strokeColor: Colors.black,
        strokeWidth: 2,
      );

      state = EditorState.initial().copyWith(
        shapes: [testShape],
        selectedShapeId: 'shape-1',
        selectedShapeIds: ['shape-1'],
      );

      viewModel = NodeEditViewModel(
        getState: () => state,
        setState: (newState) => state = newState,
        pushHistory: () => historyPushed = true,
        queueAutosave: () => autosaveQueued = true,
        setShapesAndRebuild: (shapes,
            {String? selectedShapeId,
            List<String>? selectedShapeIds,
            bool rebuildQuadTree = true}) {
          state = state.copyWith(
            shapes: shapes,
            selectedShapeId: selectedShapeId,
            selectedShapeIds: selectedShapeIds,
          );
        },
        rebuildQuadTree: () => quadTreeRebuilt = true,
        setSelectionDirty: (value) => selectionDirty = value,
        nextShapeId: () => 'shape-${++shapeIdCounter}',
      );
    });

    group('enterNodeEditMode', () {
      test('enters node edit mode for valid shape', () {
        final result = viewModel.enterNodeEditMode();

        expect(result, isTrue);
        expect(state.activeTool, EditorTool.nodeEdit);
        expect(state.isNodeEditMode, isTrue);
        expect(state.nodeEditState.activeContourIndex, 0);
      });

      test('returns false when no shape is selected', () {
        state = state.copyWith(clearSelection: true);

        final result = viewModel.enterNodeEditMode();

        expect(result, isFalse);
        expect(state.activeTool, isNot(EditorTool.nodeEdit));
      });

      test('returns false for non-editable shape types', () {
        // Rectangle and Ellipse shapes are not directly node-editable
        // (they can be converted to paths first)
        final rectShape = Shape(
          id: 'rect-1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(100, 100, 50, 50),
          strokeColor: Colors.black,
          strokeWidth: 2,
        );
        final ellipseShape = Shape(
          id: 'ellipse-1',
          kind: ShapeKind.ellipse,
          bounds: const Rect.fromLTWH(100, 100, 50, 50),
          strokeColor: Colors.black,
          strokeWidth: 2,
        );

        // canConvertToPath is true but isNodeEditable is false
        expect(viewModel.canEnterNodeEditMode(rectShape), isFalse);
        expect(viewModel.canEnterNodeEditMode(ellipseShape), isFalse);
      });
    });

    group('exitNodeEditMode', () {
      test('exits node edit mode and returns to select tool', () {
        viewModel.enterNodeEditMode();
        expect(state.isNodeEditMode, isTrue);

        viewModel.exitNodeEditMode();

        expect(state.isNodeEditMode, isFalse);
        expect(state.activeTool, EditorTool.select);
        expect(state.nodeEditState, NodeEditState.initial);
      });

      test('does nothing if not in node edit mode', () {
        final originalState = state;
        viewModel.exitNodeEditMode();
        // State should remain unchanged
        expect(state.activeTool, originalState.activeTool);
      });
    });

    group('selectNodes', () {
      test('selects specified node indices', () {
        viewModel.enterNodeEditMode();

        viewModel.selectNodes({0, 2});

        expect(state.nodeEditState.selectedNodeIndices, {0, 2});
      });

      test('does nothing when not in node edit mode', () {
        viewModel.selectNodes({0, 1});

        expect(state.nodeEditState.selectedNodeIndices, isEmpty);
      });
    });

    group('toggleNodeSelection', () {
      test('adds node to selection', () {
        viewModel.enterNodeEditMode();
        viewModel.selectNodes({0});

        viewModel.toggleNodeSelection(1);

        expect(state.nodeEditState.selectedNodeIndices, {0, 1});
      });

      test('removes node from selection', () {
        viewModel.enterNodeEditMode();
        viewModel.selectNodes({0, 1});

        viewModel.toggleNodeSelection(1);

        expect(state.nodeEditState.selectedNodeIndices, {0});
      });
    });

    group('clearNodeSelection', () {
      test('clears all selected nodes', () {
        viewModel.enterNodeEditMode();
        viewModel.selectNodes({0, 1, 2});

        viewModel.clearNodeSelection();

        expect(state.nodeEditState.selectedNodeIndices, isEmpty);
      });
    });

    group('selectAllNodes', () {
      test('selects all nodes in the shape', () {
        viewModel.enterNodeEditMode();

        viewModel.selectAllNodes();

        // Shape has 4 points
        expect(state.nodeEditState.selectedNodeIndices, {0, 1, 2, 3});
      });
    });

    group('beginNodeDrag and endNodeDrag', () {
      test('beginNodeDrag sets dragging state', () {
        viewModel.enterNodeEditMode();

        viewModel.beginNodeDrag({0: const Offset(100, 100)});

        expect(state.nodeEditState.isDragging, isTrue);
        expect(state.nodeEditState.dragStartPositions, {0: const Offset(100, 100)});
      });

      test('endNodeDrag clears dragging state and pushes history', () {
        viewModel.enterNodeEditMode();
        viewModel.beginNodeDrag({0: const Offset(100, 100)});

        viewModel.endNodeDrag();

        expect(state.nodeEditState.isDragging, isFalse);
        expect(state.nodeEditState.dragStartPositions, isEmpty);
        expect(historyPushed, isTrue);
        expect(quadTreeRebuilt, isTrue);
      });
    });

    group('contour navigation', () {
      test('getActiveContourIndex returns current contour', () {
        viewModel.enterNodeEditMode();

        expect(viewModel.getActiveContourIndex(), 0);
      });

      test('setActiveContour changes active contour', () {
        // Create a shape with multiple contours
        final multiContourShape = Shape(
          id: 'multi-1',
          kind: ShapeKind.polygon,
          points: const [Offset(100, 100), Offset(200, 100)],
          contours: const [
            [Offset(100, 100), Offset(200, 100), Offset(150, 200)],
            [Offset(300, 100), Offset(400, 100), Offset(350, 200)],
          ],
          strokeColor: Colors.black,
          strokeWidth: 2,
        );
        state = state.copyWith(
          shapes: [multiContourShape],
          selectedShapeId: 'multi-1',
        );

        viewModel.enterNodeEditMode();
        viewModel.selectNodes({0});

        viewModel.setActiveContour(1);

        expect(state.nodeEditState.activeContourIndex, 1);
        expect(state.nodeEditState.selectedNodeIndices, isEmpty); // Cleared on contour change
      });
    });

    group('getSelectedShapeContourCount', () {
      test('returns contour count for selected shape', () {
        final count = viewModel.getSelectedShapeContourCount();
        expect(count, greaterThan(0));
      });

      test('returns 0 when no shape is selected', () {
        state = state.copyWith(clearSelection: true);

        final count = viewModel.getSelectedShapeContourCount();
        expect(count, 0);
      });
    });

    group('canEnterNodeEditMode', () {
      test('returns true for freehand shape', () {
        final shape = state.shapes.first;
        expect(viewModel.canEnterNodeEditMode(shape), isTrue);
      });

      test('returns false for null shape', () {
        expect(viewModel.canEnterNodeEditMode(null), isFalse);
      });
    });

    group('convertSelectedToPath', () {
      test('converts rectangle to path', () {
        final rectShape = Shape(
          id: 'rect-1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(100, 100, 50, 50),
          strokeColor: Colors.black,
          strokeWidth: 2,
        );
        state = state.copyWith(
          shapes: [rectShape],
          selectedShapeId: 'rect-1',
        );

        final result = viewModel.convertSelectedToPath();

        expect(result, isTrue);
        expect(historyPushed, isTrue);
        expect(state.shapes.first.kind, ShapeKind.polygon);
      });
    });

    group('integration', () {
      test('full node editing workflow', () {
        // Enter node edit mode
        expect(viewModel.enterNodeEditMode(), isTrue);
        expect(state.isNodeEditMode, isTrue);

        // Select some nodes
        viewModel.selectNodes({0, 1});
        expect(state.nodeEditState.selectedNodeIndices, {0, 1});

        // Start dragging
        viewModel.beginNodeDrag({
          0: const Offset(100, 100),
          1: const Offset(150, 120),
        });
        expect(state.nodeEditState.isDragging, isTrue);

        // End dragging
        viewModel.endNodeDrag();
        expect(state.nodeEditState.isDragging, isFalse);
        expect(historyPushed, isTrue);

        // Exit node edit mode
        viewModel.exitNodeEditMode();
        expect(state.isNodeEditMode, isFalse);
        expect(state.activeTool, EditorTool.select);
      });
    });
  });
}
