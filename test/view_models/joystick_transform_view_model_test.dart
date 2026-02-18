import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/joystick_mode.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/joystick_transform_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JoystickTransformViewModel', () {
    late EditorState state;
    late JoystickTransformViewModel viewModel;
    late List<Shape> lastAppliedTransforms;
    late Offset lastMoveOffset;
    late Set<String> lastMoveShapeIds;
    late Offset lastMoveByIdsOffset;
    late bool finalizeCalled;

    setUp(() {
      state = EditorState.initial();
      lastAppliedTransforms = [];
      lastMoveOffset = Offset.zero;
      lastMoveShapeIds = <String>{};
      lastMoveByIdsOffset = Offset.zero;
      finalizeCalled = false;

      // Add a test shape to state
      final testShape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(100, 100, 50, 50),
        strokeColor: Colors.black,
        strokeWidth: 2,
      );
      state = state.copyWith(
        shapes: [testShape],
        selectedShapeId: 'shape-1',
        selectedShapeIds: ['shape-1'],
      );

      viewModel = JoystickTransformViewModel(
        getState: () => state,
        setState: (newState) => state = newState,
        getSelectedGroupShapes: () =>
            state.shapes.where((s) => s.id == state.selectedShapeId).toList(),
        getSelectionBounds: (shapes) {
          if (shapes.isEmpty) return null;
          Rect? bounds;
          for (final shape in shapes) {
            final shapeBounds = shape.bounds ?? shape.worldBounds;
            if (shapeBounds != null) {
              bounds = bounds?.expandToInclude(shapeBounds) ?? shapeBounds;
            }
          }
          return bounds;
        },
        applyTransformedShapes: (shapes) => lastAppliedTransforms = shapes,
        moveSelectedBy: (delta) => lastMoveOffset = delta,
        moveShapesByIds: (shapeIds, delta) {
          lastMoveShapeIds = shapeIds;
          lastMoveByIdsOffset = delta;
        },
        finalizeSelectionEdit: () => finalizeCalled = true,
      );
    });

    group('toggleJoystickController', () {
      test('toggles joystick controller enabled state', () {
        // EditorState.initial() has joystickControllerEnabled: true
        expect(state.joystickControllerEnabled, isTrue);

        viewModel.toggleJoystickController();
        expect(state.joystickControllerEnabled, isFalse);

        viewModel.toggleJoystickController();
        expect(state.joystickControllerEnabled, isTrue);
      });
    });

    group('setJoystickMode', () {
      test('sets joystick mode', () {
        expect(state.joystickMode, JoystickMode.move);

        viewModel.setJoystickMode(JoystickMode.scale);
        expect(state.joystickMode, JoystickMode.scale);

        viewModel.setJoystickMode(JoystickMode.rotate);
        expect(state.joystickMode, JoystickMode.rotate);
      });

      test('does not update state if mode is same', () {
        final originalState = state;
        viewModel.setJoystickMode(JoystickMode.move);
        // State reference should be same (no copyWith called)
        expect(identical(state, originalState), isTrue);
      });
    });

    group('startJoystickTransform and endJoystickTransform', () {
      test('startJoystickTransform sets isActive to true', () {
        expect(viewModel.isActive, isFalse);

        viewModel.startJoystickTransform();
        expect(viewModel.isActive, isTrue);
      });

      test(
        'endJoystickTransform sets isActive to false and calls finalize',
        () {
          viewModel.startJoystickTransform();
          expect(viewModel.isActive, isTrue);

          viewModel.endJoystickTransform();
          expect(viewModel.isActive, isFalse);
          expect(finalizeCalled, isTrue);
        },
      );

      test(
        'startJoystickTransform calculates center from selection bounds',
        () {
          viewModel.startJoystickTransform();
          // Center of Rect.fromLTWH(100, 100, 50, 50) is (125, 125)
          expect(viewModel.center, const Offset(125, 125));
        },
      );
    });

    group('applyJoystickMove', () {
      test('calls moveShapesByIds with delta during active session', () {
        viewModel.startJoystickTransform();
        viewModel.applyJoystickMove(const Offset(10, 20));
        expect(lastMoveByIdsOffset, const Offset(10, 20));
        expect(lastMoveShapeIds, contains('shape-1'));
      });

      test('falls back to moveSelectedBy when no session is active', () {
        viewModel.applyJoystickMove(const Offset(6, 4));
        expect(lastMoveOffset, const Offset(6, 4));
        expect(lastMoveShapeIds, isEmpty);
      });

      test('does not call move callbacks when delta is zero', () {
        viewModel.startJoystickTransform();
        lastMoveOffset = const Offset(999, 999);
        lastMoveByIdsOffset = const Offset(999, 999);
        viewModel.applyJoystickMove(Offset.zero);
        expect(lastMoveOffset, const Offset(999, 999));
        expect(lastMoveByIdsOffset, const Offset(999, 999));
      });
    });

    group('applyJoystickScale', () {
      test('does nothing when no joystick session is active', () {
        viewModel.applyJoystickScale(2.0);
        // Should not throw or change state
        expect(
          state.shapes.first.bounds,
          const Rect.fromLTWH(100, 100, 50, 50),
        );
      });

      test('applies uniform scale to shapes', () {
        viewModel.startJoystickTransform();
        viewModel.applyJoystickScale(2.0);

        // State should be updated with scaled shape
        final scaledShape = state.shapes.first;
        expect(scaledShape.bounds, isNotNull);
        // Scaling by 2x from center (125, 125):
        // Original: (100, 100, 150, 150) -> scaled bounds should be larger
        expect(scaledShape.bounds!.width, 100); // 50 * 2
        expect(scaledShape.bounds!.height, 100); // 50 * 2
      });
    });

    group('applyJoystickScaleDirectional', () {
      test('applies directional scale to shapes', () {
        viewModel.startJoystickTransform();
        viewModel.applyJoystickScaleDirectional(2.0, 1.0);

        final scaledShape = state.shapes.first;
        expect(scaledShape.bounds, isNotNull);
        expect(scaledShape.bounds!.width, 100); // 50 * 2
        expect(scaledShape.bounds!.height, 50); // 50 * 1 (unchanged)
      });
    });

    group('applyJoystickRotate', () {
      test('does nothing when no joystick session is active', () {
        viewModel.applyJoystickRotate(0.5);
        // Should not throw
        expect(lastAppliedTransforms, isEmpty);
      });

      test('applies rotation when session is active', () {
        viewModel.startJoystickTransform();
        viewModel.applyJoystickRotate(0.5);

        // Should have applied transforms
        expect(lastAppliedTransforms, isNotEmpty);
        expect(lastAppliedTransforms.first.rotation, closeTo(0.5, 0.001));
      });
    });

    group('integration', () {
      test('full joystick transform session works correctly', () {
        // Start session
        viewModel.startJoystickTransform();
        expect(viewModel.isActive, isTrue);

        // Apply some moves
        viewModel.applyJoystickMove(const Offset(10, 0));
        expect(lastMoveByIdsOffset, const Offset(10, 0));

        // Apply some scale
        viewModel.applyJoystickScale(1.5);
        expect(state.shapes.first.bounds!.width, 75); // 50 * 1.5

        // End session
        viewModel.endJoystickTransform();
        expect(viewModel.isActive, isFalse);
        expect(finalizeCalled, isTrue);
      });
    });
  });
}
