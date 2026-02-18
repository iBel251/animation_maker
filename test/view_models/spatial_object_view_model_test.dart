import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/spatial_object_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpatialObjectViewModel', () {
    late EditorState state;
    late SpatialObjectViewModel viewModel;
    late int spatialIdCounter;

    setUp(() {
      spatialIdCounter = 0;

      state = EditorState.initial().copyWith(activeTool: EditorTool.brush);

      viewModel = SpatialObjectViewModel(
        getState: () => state,
        setState: (newState) => state = newState,
        nextSpatialId: () => 'spatial-${++spatialIdCounter}',
      );
    });

    group('toggleSpatialDrawMode', () {
      test('enables spatial draw mode when off', () {
        expect(state.isSpatialDrawMode, isFalse);

        viewModel.toggleSpatialDrawMode();

        expect(state.isSpatialDrawMode, isTrue);
        expect(state.activeSpatialObjectId, isNotNull);
        expect(state.spatialObjects.length, 1);
      });

      test('disables spatial draw mode when on', () {
        viewModel.toggleSpatialDrawMode();
        expect(state.isSpatialDrawMode, isTrue);

        viewModel.toggleSpatialDrawMode();

        expect(state.isSpatialDrawMode, isFalse);
        expect(state.activeSpatialObjectId, isNull);
      });

      test('does nothing if not using brush tool', () {
        state = state.copyWith(activeTool: EditorTool.select);

        viewModel.toggleSpatialDrawMode();

        expect(state.isSpatialDrawMode, isFalse);
        expect(state.spatialObjects, isEmpty);
      });

      test('creates spatial object with current settings', () {
        state = state.copyWith(currentColor: Colors.red);

        viewModel.toggleSpatialDrawMode();

        expect(state.spatialObjects.first.strokeColor, Colors.red);
      });
    });

    group('setSpatialDrawMode', () {
      test('enables spatial draw mode when set to true', () {
        viewModel.setSpatialDrawMode(true);

        expect(state.isSpatialDrawMode, isTrue);
        expect(state.activeSpatialObjectId, isNotNull);
      });

      test('disables spatial draw mode when set to false', () {
        viewModel.setSpatialDrawMode(true);
        expect(state.isSpatialDrawMode, isTrue);

        viewModel.setSpatialDrawMode(false);

        expect(state.isSpatialDrawMode, isFalse);
        expect(state.activeSpatialObjectId, isNull);
      });

      test('does nothing if already in desired state', () {
        final initialObjectCount = state.spatialObjects.length;

        viewModel.setSpatialDrawMode(false);

        expect(state.spatialObjects.length, initialObjectCount);
      });

      test('does nothing if not using brush tool', () {
        state = state.copyWith(activeTool: EditorTool.select);

        viewModel.setSpatialDrawMode(true);

        expect(state.isSpatialDrawMode, isFalse);
      });
    });

    group('ensureActiveSpatialObjectId', () {
      test('returns null if not in spatial draw mode', () {
        final result = viewModel.ensureActiveSpatialObjectId();

        expect(result, isNull);
      });

      test('returns existing spatial object id if present', () {
        viewModel.toggleSpatialDrawMode();
        final existingId = state.activeSpatialObjectId;

        final result = viewModel.ensureActiveSpatialObjectId();

        expect(result, existingId);
        expect(state.spatialObjects.length, 1);
      });

      test('creates new spatial object if id is null', () {
        // Manually set spatial draw mode without an active object
        state = state.copyWith(
          isSpatialDrawMode: true,
          clearActiveSpatialObjectId: true,
        );

        final result = viewModel.ensureActiveSpatialObjectId();

        expect(result, isNotNull);
        expect(state.activeSpatialObjectId, result);
        expect(state.spatialObjects.length, 1);
      });
    });

    group('startEditingSpatialObject', () {
      test('enables spatial draw mode for an existing spatial object', () {
        viewModel.toggleSpatialDrawMode();
        final spatialId = state.activeSpatialObjectId!;
        viewModel.exitSpatialDrawMode();

        final started = viewModel.startEditingSpatialObject(spatialId);

        expect(started, isTrue);
        expect(state.isSpatialDrawMode, isTrue);
        expect(state.activeSpatialObjectId, spatialId);
      });

      test('returns false when spatial object is missing', () {
        final started = viewModel.startEditingSpatialObject('missing-spatial');

        expect(started, isFalse);
        expect(state.isSpatialDrawMode, isFalse);
        expect(state.activeSpatialObjectId, isNull);
      });

      test('returns false if active tool is not brush', () {
        viewModel.toggleSpatialDrawMode();
        final spatialId = state.activeSpatialObjectId!;
        viewModel.exitSpatialDrawMode();
        state = state.copyWith(activeTool: EditorTool.select);

        final started = viewModel.startEditingSpatialObject(spatialId);

        expect(started, isFalse);
        expect(state.isSpatialDrawMode, isFalse);
      });
    });

    group('attachShapesToSpatial', () {
      test('attaches shapes to spatial object', () {
        viewModel.toggleSpatialDrawMode();
        final spatialId = state.activeSpatialObjectId!;

        final shapes = [
          Shape(
            id: 'shape-1',
            kind: ShapeKind.freehand,
            points: [const Offset(0, 0), const Offset(100, 100)],
            strokeColor: Colors.black,
            strokeWidth: 2,
          ),
          Shape(
            id: 'shape-2',
            kind: ShapeKind.freehand,
            points: [const Offset(50, 50), const Offset(150, 150)],
            strokeColor: Colors.black,
            strokeWidth: 2,
          ),
        ];

        viewModel.attachShapesToSpatial(spatialId, shapes);

        final spatial = state.spatialObjects.first;
        expect(spatial.childShapeIds.length, 2);
        expect(spatial.childShapeIds, contains('shape-1'));
        expect(spatial.childShapeIds, contains('shape-2'));
      });

      test('does nothing for empty shapes list', () {
        viewModel.toggleSpatialDrawMode();
        final spatialId = state.activeSpatialObjectId!;
        final initialSpatial = state.spatialObjects.first;

        viewModel.attachShapesToSpatial(spatialId, []);

        expect(
          state.spatialObjects.first.childShapeIds,
          initialSpatial.childShapeIds,
        );
      });

      test('does nothing if spatial object not found', () {
        viewModel.toggleSpatialDrawMode();
        final initialState = state;

        final shapes = [
          Shape(
            id: 'shape-1',
            kind: ShapeKind.freehand,
            points: [const Offset(0, 0)],
            strokeColor: Colors.black,
            strokeWidth: 2,
          ),
        ];

        viewModel.attachShapesToSpatial('non-existent', shapes);

        expect(state.spatialObjects, initialState.spatialObjects);
      });

      test('appends to existing child shape ids', () {
        viewModel.toggleSpatialDrawMode();
        final spatialId = state.activeSpatialObjectId!;

        // Attach first shape
        viewModel.attachShapesToSpatial(spatialId, [
          Shape(
            id: 'shape-1',
            kind: ShapeKind.freehand,
            points: [const Offset(0, 0)],
            strokeColor: Colors.black,
            strokeWidth: 2,
          ),
        ]);

        // Attach second shape
        viewModel.attachShapesToSpatial(spatialId, [
          Shape(
            id: 'shape-2',
            kind: ShapeKind.freehand,
            points: [const Offset(50, 50)],
            strokeColor: Colors.black,
            strokeWidth: 2,
          ),
        ]);

        final spatial = state.spatialObjects.first;
        expect(spatial.childShapeIds.length, 2);
      });
    });

    group('exitSpatialDrawMode', () {
      test('exits spatial draw mode', () {
        viewModel.toggleSpatialDrawMode();
        expect(state.isSpatialDrawMode, isTrue);

        viewModel.exitSpatialDrawMode();

        expect(state.isSpatialDrawMode, isFalse);
        expect(state.activeSpatialObjectId, isNull);
      });

      test('does nothing if not in spatial draw mode', () {
        final initialState = state;

        viewModel.exitSpatialDrawMode();

        expect(state.isSpatialDrawMode, initialState.isSpatialDrawMode);
      });
    });

    group('integration', () {
      test('full spatial object workflow', () {
        // Enable spatial draw mode
        viewModel.toggleSpatialDrawMode();
        expect(state.isSpatialDrawMode, isTrue);
        final spatialId = state.activeSpatialObjectId!;

        // Attach shapes
        final shape1 = Shape(
          id: 'stroke-1',
          kind: ShapeKind.freehand,
          points: [const Offset(0, 0), const Offset(100, 100)],
          strokeColor: Colors.black,
          strokeWidth: 2,
        );
        final shape2 = Shape(
          id: 'stroke-2',
          kind: ShapeKind.freehand,
          points: [const Offset(50, 50), const Offset(150, 150)],
          strokeColor: Colors.black,
          strokeWidth: 2,
        );

        viewModel.attachShapesToSpatial(spatialId, [shape1]);
        viewModel.attachShapesToSpatial(spatialId, [shape2]);

        // Verify spatial object has both strokes
        final spatial = state.spatialObjects.first;
        expect(spatial.childShapeIds, ['stroke-1', 'stroke-2']);

        // Exit spatial draw mode
        viewModel.exitSpatialDrawMode();
        expect(state.isSpatialDrawMode, isFalse);

        // Spatial object should still exist with its shapes
        expect(state.spatialObjects.length, 1);
        expect(state.spatialObjects.first.childShapeIds.length, 2);
      });
    });
  });
}
