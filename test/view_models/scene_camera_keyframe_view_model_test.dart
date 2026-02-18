import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/scene_camera_keyframe_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneCameraKeyframeViewModel', () {
    late EditorState state;
    late SceneCameraKeyframeViewModel viewModel;
    late int pushHistoryCount;

    setUp(() {
      state = EditorState.initial();
      pushHistoryCount = 0;
      viewModel = SceneCameraKeyframeViewModel(
        getState: () => state,
        setState: (next) => state = next,
        pushHistory: () => pushHistoryCount += 1,
      );
    });

    test('adds keyframe at current frame', () {
      expect(state.document.sceneCameraTimeline.isEmpty, isTrue);

      viewModel.addOrUpdateAtCurrentFrame();

      expect(state.document.sceneCameraTimeline.containsFrame(0), isTrue);
      expect(pushHistoryCount, 1);
    });

    test('updates existing keyframe at current frame', () {
      viewModel.addOrUpdateAtCurrentFrame();

      state = state.copyWith(
        sceneCamera: SceneCamera.fromDocument(
          state.document.size,
        ).copyWith(position: const Offset(200, 120), zoom: 1.8, rotation: 0.2),
      );
      viewModel.addOrUpdateAtCurrentFrame();
      final key = state.document.sceneCameraTimeline.atFrame(0);

      expect(state.document.sceneCameraTimeline.keyframes.length, 1);
      expect(key, isNotNull);
      expect(key!.position, const Offset(200, 120));
      expect(key.zoom, 1.8);
      expect(pushHistoryCount, 2);
    });

    test('deletes keyframe at current frame', () {
      viewModel.addOrUpdateAtCurrentFrame();
      expect(state.document.sceneCameraTimeline.containsFrame(0), isTrue);

      viewModel.deleteAtCurrentFrame();

      expect(state.document.sceneCameraTimeline.containsFrame(0), isFalse);
      expect(pushHistoryCount, 2);
    });

    test('resolves previous and next keyframes from current frame', () {
      state = state.copyWith(
        currentFrame: 5,
        document: state.document.copyWith(
          sceneCameraTimeline: SceneCameraTimeline(
            keyframes: const [
              SceneCameraKeyframe(
                frame: 1,
                position: Offset(10, 10),
                zoom: 1.0,
                rotation: 0.0,
              ),
              SceneCameraKeyframe(
                frame: 8,
                position: Offset(80, 40),
                zoom: 2.0,
                rotation: 0.5,
              ),
            ],
          ),
        ),
      );

      expect(viewModel.previousKeyframeFrame(), 1);
      expect(viewModel.nextKeyframeFrame(), 8);
    });

    test('applies interpolated camera for a frame', () {
      state = state.copyWith(
        sceneCamera: const SceneCamera(size: Size(1280, 720)),
        document: state.document.copyWith(
          sceneCameraTimeline: SceneCameraTimeline(
            keyframes: const [
              SceneCameraKeyframe(
                frame: 0,
                position: Offset(0, 0),
                zoom: 1.0,
                rotation: 0.0,
              ),
              SceneCameraKeyframe(
                frame: 10,
                position: Offset(100, 50),
                zoom: 2.0,
                rotation: 1.0,
              ),
            ],
          ),
        ),
      );

      viewModel.applySceneCameraForFrame(5);

      expect(state.sceneCamera, isNotNull);
      expect(state.sceneCamera!.position.dx, closeTo(50.0, 0.0001));
      expect(state.sceneCamera!.position.dy, closeTo(25.0, 0.0001));
      expect(state.sceneCamera!.zoom, closeTo(1.5, 0.0001));
      expect(state.sceneCamera!.size, const Size(1280, 720));
    });

    test('extends frameCount when keying beyond document frame count', () {
      state = state.copyWith(
        currentFrame: 25,
        sceneCamera: SceneCamera.fromDocument(state.document.size),
      );

      viewModel.addOrUpdateAtCurrentFrame();

      expect(state.document.frameCount, 26);
      expect(state.document.sceneCameraTimeline.containsFrame(25), isTrue);
    });
  });
}
