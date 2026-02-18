import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/keyframe_clipboard_service.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/object_keyframe_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectKeyframeViewModel', () {
    late EditorState state;
    late ObjectKeyframeViewModel viewModel;
    late int pushHistoryCount;

    setUp(() {
      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 100)],
      );
      state = EditorState.initial().copyWith(
        shapes: [shape],
        selectedShapeId: shape.id,
      );
      pushHistoryCount = 0;
      viewModel = ObjectKeyframeViewModel(
        getState: () => state,
        setState: (next) => state = next,
        pushHistory: () => pushHistoryCount += 1,
        clipboardService: KeyframeClipboardService(),
      );
    });

    test('adds keyframe for selected object at current frame', () {
      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      expect(state.document.objectTimeline.containsFrame('shape-1', 0), isTrue);
      expect(pushHistoryCount, 1);
    });

    test('updates existing keyframe for selected object', () {
      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      state = state.copyWith(
        shapes: [
          state.shapes.first.copyWith(
            translation: const Offset(200, 80),
            rotation: 0.25,
            scaleX: 1.3,
            scaleY: 0.8,
            opacity: 0.7,
          ),
        ],
      );
      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      final track = state.document.objectTimeline.trackForShape('shape-1');
      final key = track?.atFrame(0);
      expect(track, isNotNull);
      expect(track!.keyframes.length, 1);
      expect(key, isNotNull);
      expect(key!.position, const Offset(250, 130));
      expect(key.rotation, 0.25);
      expect(key.scaleX, 1.3);
      expect(key.scaleY, 0.8);
      expect(key.opacity, 0.7);
      expect(pushHistoryCount, 2);
    });

    test('deletes keyframe for selected object at current frame', () {
      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();
      expect(state.document.objectTimeline.containsFrame('shape-1', 0), isTrue);

      viewModel.deleteSelectedObjectAtCurrentFrame();

      expect(
        state.document.objectTimeline.containsFrame('shape-1', 0),
        isFalse,
      );
      expect(pushHistoryCount, 2);
    });

    test('resolves previous and next selected-object keyframes', () {
      state = state.copyWith(
        currentFrame: 5,
        document: state.document.copyWith(
          objectTimeline: ObjectTimeline(
            tracks: [
              ObjectTimelineTrack(
                shapeId: 'shape-1',
                keyframes: const [
                  ObjectTransformKeyframe(
                    frame: 1,
                    position: Offset(10, 10),
                    rotation: 0.1,
                    scaleX: 1,
                    scaleY: 1,
                    opacity: 1,
                  ),
                  ObjectTransformKeyframe(
                    frame: 8,
                    position: Offset(80, 40),
                    rotation: 0.8,
                    scaleX: 2,
                    scaleY: 2,
                    opacity: 0.5,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(viewModel.previousSelectedObjectKeyframeFrame(), 1);
      expect(viewModel.nextSelectedObjectKeyframeFrame(), 8);
    });

    test('applies interpolated transform to selected object at frame', () {
      state = state.copyWith(
        document: state.document.copyWith(
          objectTimeline: ObjectTimeline(
            tracks: [
              ObjectTimelineTrack(
                shapeId: 'shape-1',
                keyframes: const [
                  ObjectTransformKeyframe(
                    frame: 0,
                    position: Offset(50, 50),
                    rotation: 0.0,
                    scaleX: 1,
                    scaleY: 1,
                    opacity: 1,
                  ),
                  ObjectTransformKeyframe(
                    frame: 10,
                    position: Offset(150, 100),
                    rotation: 1.0,
                    scaleX: 2,
                    scaleY: 3,
                    opacity: 0.5,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      viewModel.applyObjectKeyframesForFrame(5);

      final sampled = state.shapes.first;
      expect(sampled.worldBounds, isNotNull);
      expect(sampled.worldBounds!.center.dx, closeTo(100.0, 0.0001));
      expect(sampled.worldBounds!.center.dy, closeTo(75.0, 0.0001));
      expect(sampled.rotation, closeTo(0.5, 0.0001));
      expect(sampled.scaleX, closeTo(1.5, 0.0001));
      expect(sampled.scaleY, closeTo(2.0, 0.0001));
      expect(sampled.opacity, closeTo(0.75, 0.0001));
    });

    test('extends frameCount when keying beyond current frame count', () {
      state = state.copyWith(currentFrame: 30);

      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      expect(state.document.frameCount, 31);
      expect(
        state.document.objectTimeline.containsFrame('shape-1', 30),
        isTrue,
      );
    });

    test('keying a parent also keys all descendants at same frame', () {
      final parent = Shape(
        id: 'parent-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 100)],
      );
      final child = Shape(
        id: 'child-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(120, 0), Offset(180, 60)],
        parentId: 'parent-1',
      );
      final grandChild = Shape(
        id: 'grand-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(200, 0), Offset(240, 40)],
        parentId: 'child-1',
      );

      state = state.copyWith(
        shapes: [parent, child, grandChild],
        selectedShapeId: 'parent-1',
        selectedShapeIds: const ['parent-1'],
      );

      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      final timeline = state.document.objectTimeline;
      expect(timeline.containsFrame('parent-1', 0), isTrue);
      expect(timeline.containsFrame('child-1', 0), isTrue);
      expect(timeline.containsFrame('grand-1', 0), isTrue);
      expect(pushHistoryCount, 1);
    });

    test('adds channel-specific keyframe for selected object', () {
      viewModel.addOrUpdateSelectedObjectChannelsAtCurrentFrame(
        const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
      );

      final keyframe = state.document.objectTimeline
          .trackForShape('shape-1')
          ?.atFrame(0);
      expect(keyframe, isNotNull);
      expect(keyframe!.effectiveKeyedChannels, const <ObjectKeyChannel>{
        ObjectKeyChannel.strokeColor,
      });
    });

    test(
      'channel-specific key update preserves non-target channels at same frame',
      () {
        viewModel.addOrUpdateSelectedObjectAtCurrentFrame();
        final original = state.document.objectTimeline
            .trackForShape('shape-1')!
            .atFrame(0)!;

        state = state.copyWith(
          shapes: [
            state.shapes.first.copyWith(
              translation: const Offset(300, 0),
              strokeColor: const Color(0xFFFF0000),
            ),
          ],
        );
        viewModel.addOrUpdateSelectedObjectChannelsAtCurrentFrame(
          const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
        );

        final updated = state.document.objectTimeline
            .trackForShape('shape-1')!
            .atFrame(0)!;
        expect(updated.position, original.position);
        expect(updated.strokeColor, const Color(0xFFFF0000));
        expect(updated.keysChannel(ObjectKeyChannel.strokeColor), isTrue);
      },
    );

    test('set channel mask replaces keyed channels at current frame', () {
      viewModel.addOrUpdateSelectedObjectAtCurrentFrame();

      viewModel.setSelectedObjectChannelsAtCurrentFrame(
        const <ObjectKeyChannel>{
          ObjectKeyChannel.strokeColor,
          ObjectKeyChannel.fillColor,
        },
      );

      final keyframe = state.document.objectTimeline
          .trackForShape('shape-1')
          ?.atFrame(0);
      expect(keyframe, isNotNull);
      expect(keyframe!.effectiveKeyedChannels, const <ObjectKeyChannel>{
        ObjectKeyChannel.strokeColor,
        ObjectKeyChannel.fillColor,
      });
    });

    test('setting empty channel mask removes keyframe at current frame', () {
      viewModel.addOrUpdateSelectedObjectChannelsAtCurrentFrame(
        const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
      );
      expect(state.document.objectTimeline.containsFrame('shape-1', 0), isTrue);

      viewModel.setSelectedObjectChannelsAtCurrentFrame(
        const <ObjectKeyChannel>{},
      );

      expect(
        state.document.objectTimeline.containsFrame('shape-1', 0),
        isFalse,
      );
    });

    test(
      'selectedObjectKeyChannelsAtCurrentFrame reports empty when unkeyed',
      () {
        expect(viewModel.selectedObjectKeyChannelsAtCurrentFrame, isEmpty);
      },
    );

    test('selectedObjectKeyChannelsAtCurrentFrame reports existing mask', () {
      viewModel.addOrUpdateSelectedObjectChannelsAtCurrentFrame(
        const <ObjectKeyChannel>{
          ObjectKeyChannel.position,
          ObjectKeyChannel.opacity,
        },
      );

      expect(viewModel.selectedObjectKeyChannelsAtCurrentFrame, const {
        ObjectKeyChannel.position,
        ObjectKeyChannel.opacity,
      });
    });
  });
}
