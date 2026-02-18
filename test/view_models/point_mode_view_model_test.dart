import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/point_mode_state.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/point_mode_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointModeViewModel', () {
    late EditorState state;
    late PointModeViewModel viewModel;
    late bool historyPushed;
    late bool quadTreeRebuilt;
    late int shapeIdCounter;

    setUp(() {
      historyPushed = false;
      quadTreeRebuilt = false;
      shapeIdCounter = 0;

      state = EditorState.initial();

      viewModel = PointModeViewModel(
        getState: () => state,
        setState: (newState) => state = newState,
        setShapesAndRebuild: (shapes, {String? selectedShapeId}) {
          state = state.copyWith(
            shapes: shapes,
            selectedShapeId: selectedShapeId,
          );
        },
        rebuildQuadTree: (shapes) => quadTreeRebuilt = true,
        pushHistory: () => historyPushed = true,
        nextShapeId: () => 'shape-${++shapeIdCounter}',
      );
    });

    group('enterPointMode', () {
      test('enters point mode when not active', () {
        viewModel.enterPointMode();

        expect(state.pointModeState.isActive, isTrue);
      });

      test('clears selection when entering point mode', () {
        state = state.copyWith(
          selectedShapeId: 'some-shape',
          selectedShapeIds: ['some-shape'],
        );

        viewModel.enterPointMode();

        expect(state.selectedShapeId, isNull);
      });

      test('does nothing if already in point mode', () {
        viewModel.enterPointMode();
        final stateAfterFirstEnter = state;

        viewModel.enterPointMode();

        expect(state, equals(stateAfterFirstEnter));
      });
    });

    group('exitPointMode', () {
      test('exits point mode and resets state', () {
        viewModel.enterPointMode();
        expect(state.pointModeState.isActive, isTrue);

        viewModel.exitPointMode();

        expect(state.pointModeState.isActive, isFalse);
        expect(state.pointModeState, equals(PointModeState.initial));
      });

      test('removes preview shape when exiting', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        expect(state.shapes.length, 1);
        expect(state.pointModeState.previewShapeId, isNotNull);

        viewModel.exitPointMode();

        expect(state.shapes, isEmpty);
        expect(quadTreeRebuilt, isTrue);
      });

      test('does nothing if not in point mode', () {
        final initialState = state;
        viewModel.exitPointMode();

        expect(state.pointModeState, equals(initialState.pointModeState));
      });
    });

    group('addPointModePoint', () {
      test('adds point to placed points', () {
        viewModel.enterPointMode();

        viewModel.addPointModePoint(const Offset(100, 100));

        expect(state.pointModeState.placedPoints.length, 1);
        expect(state.pointModeState.placedPoints.first, const Offset(100, 100));
      });

      test('creates preview shape after first point', () {
        viewModel.enterPointMode();

        viewModel.addPointModePoint(const Offset(100, 100));

        expect(state.pointModeState.previewShapeId, isNotNull);
        expect(state.shapes.length, 1);
        expect(state.shapes.first.kind, ShapeKind.pointPath);
      });

      test('updates preview shape on subsequent points', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        final firstPreviewId = state.pointModeState.previewShapeId;

        viewModel.addPointModePoint(const Offset(200, 200));

        expect(state.pointModeState.previewShapeId, equals(firstPreviewId));
        expect(state.shapes.length, 1);
        expect(state.shapes.first.points.length, 2);
      });

      test('does nothing if not in point mode', () {
        viewModel.addPointModePoint(const Offset(100, 100));

        expect(state.pointModeState.placedPoints, isEmpty);
      });
    });

    group('removeLastPointModePoint', () {
      test('removes the last placed point', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 200));
        expect(state.pointModeState.placedPoints.length, 2);

        viewModel.removeLastPointModePoint();

        expect(state.pointModeState.placedPoints.length, 1);
        expect(state.pointModeState.placedPoints.first, const Offset(100, 100));
      });

      test('removes preview shape when removing last point', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        expect(state.shapes.length, 1);

        viewModel.removeLastPointModePoint();

        expect(state.pointModeState.placedPoints, isEmpty);
        expect(state.pointModeState.previewShapeId, isNull);
        expect(state.shapes, isEmpty);
      });

      test('does nothing if not in point mode', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.exitPointMode();

        viewModel.removeLastPointModePoint();

        // Should not have changed anything since we exited point mode
        expect(state.pointModeState.placedPoints, isEmpty);
      });

      test('does nothing if no points placed', () {
        viewModel.enterPointMode();

        viewModel.removeLastPointModePoint();

        expect(state.pointModeState.placedPoints, isEmpty);
      });
    });

    group('setPointModeConnectionType', () {
      test('sets connection type to curved', () {
        viewModel.enterPointMode();

        viewModel.setPointModeConnectionType(PointConnectionType.curved);

        expect(state.pointModeState.connectionType, PointConnectionType.curved);
      });

      test('sets connection type to straight', () {
        viewModel.enterPointMode();
        viewModel.setPointModeConnectionType(PointConnectionType.curved);

        viewModel.setPointModeConnectionType(PointConnectionType.straight);

        expect(
            state.pointModeState.connectionType, PointConnectionType.straight);
      });

      test('generates bezier points when switching to curved with 2+ points',
          () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 200));

        viewModel.setPointModeConnectionType(PointConnectionType.curved);

        expect(state.shapes.first.bezierPoints, isNotEmpty);
      });

      test('does nothing if not in point mode', () {
        viewModel.setPointModeConnectionType(PointConnectionType.curved);

        expect(
            state.pointModeState.connectionType, PointConnectionType.straight);
      });
    });

    group('togglePointModeClosed', () {
      test('toggles closed state from false to true', () {
        viewModel.enterPointMode();
        expect(state.pointModeState.isClosed, isFalse);

        viewModel.togglePointModeClosed();

        expect(state.pointModeState.isClosed, isTrue);
      });

      test('toggles closed state from true to false', () {
        viewModel.enterPointMode();
        viewModel.togglePointModeClosed();
        expect(state.pointModeState.isClosed, isTrue);

        viewModel.togglePointModeClosed();

        expect(state.pointModeState.isClosed, isFalse);
      });

      test('updates preview shape isClosed property', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 200));

        viewModel.togglePointModeClosed();

        expect(state.shapes.first.isClosed, isTrue);
      });

      test('does nothing if not in point mode', () {
        viewModel.togglePointModeClosed();

        expect(state.pointModeState.isClosed, isFalse);
      });
    });

    group('finalizePointMode', () {
      test('finalizes shape with 2+ points', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 200));
        final previewId = state.pointModeState.previewShapeId;

        viewModel.finalizePointMode();

        expect(state.pointModeState.isActive, isFalse);
        expect(state.shapes.length, 1);
        expect(state.selectedShapeId, equals(previewId));
        expect(historyPushed, isTrue);
      });

      test('does not finalize with only 1 point', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));

        viewModel.finalizePointMode();

        // Should still be in point mode since canConnect requires 2+ points
        expect(state.pointModeState.isActive, isTrue);
        expect(historyPushed, isFalse);
      });

      test('does nothing if not in point mode', () {
        viewModel.finalizePointMode();

        expect(historyPushed, isFalse);
      });

      test('does nothing if no preview shape exists', () {
        viewModel.enterPointMode();
        // No points added, so no preview shape

        viewModel.finalizePointMode();

        expect(historyPushed, isFalse);
      });
    });

    group('curved bezier generation', () {
      test('generates bezier points for curved path', () {
        viewModel.enterPointMode();
        viewModel.setPointModeConnectionType(PointConnectionType.curved);
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 150));
        viewModel.addPointModePoint(const Offset(300, 100));

        final shape = state.shapes.first;
        expect(shape.bezierPoints, isNotNull);
        expect(shape.bezierPoints!.length, 3);
      });

      test('bezier points have control handles', () {
        viewModel.enterPointMode();
        viewModel.setPointModeConnectionType(PointConnectionType.curved);
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 150));
        viewModel.addPointModePoint(const Offset(300, 100));

        final shape = state.shapes.first;
        final middlePoint = shape.bezierPoints![1];
        // Middle point should have non-zero control handles
        expect(middlePoint.controlIn, isNot(Offset.zero));
        expect(middlePoint.controlOut, isNot(Offset.zero));
      });
    });

    group('integration', () {
      test('full point mode workflow with straight lines', () {
        // Enter point mode
        viewModel.enterPointMode();
        expect(state.pointModeState.isActive, isTrue);

        // Add points
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 100));
        viewModel.addPointModePoint(const Offset(200, 200));
        expect(state.shapes.length, 1);
        expect(state.shapes.first.points.length, 3);

        // Finalize
        viewModel.finalizePointMode();
        expect(state.pointModeState.isActive, isFalse);
        expect(state.shapes.length, 1);
        expect(historyPushed, isTrue);
      });

      test('full point mode workflow with curved lines', () {
        // Enter point mode
        viewModel.enterPointMode();

        // Set curved connection type
        viewModel.setPointModeConnectionType(PointConnectionType.curved);

        // Add points
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 50));
        viewModel.addPointModePoint(const Offset(300, 100));

        // Close the shape
        viewModel.togglePointModeClosed();
        expect(state.shapes.first.isClosed, isTrue);

        // Finalize
        viewModel.finalizePointMode();
        expect(state.pointModeState.isActive, isFalse);
        expect(state.shapes.first.bezierPoints, isNotEmpty);
      });

      test('undo workflow using removeLastPointModePoint', () {
        viewModel.enterPointMode();
        viewModel.addPointModePoint(const Offset(100, 100));
        viewModel.addPointModePoint(const Offset(200, 200));
        viewModel.addPointModePoint(const Offset(300, 300));
        expect(state.pointModeState.placedPoints.length, 3);

        // Undo last two points
        viewModel.removeLastPointModePoint();
        viewModel.removeLastPointModePoint();
        expect(state.pointModeState.placedPoints.length, 1);

        // Exit without finalizing
        viewModel.exitPointMode();
        expect(state.shapes, isEmpty);
      });
    });
  });
}
