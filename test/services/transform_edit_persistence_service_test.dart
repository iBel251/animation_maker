import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/presentation/services/transform_edit_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransformEditPersistenceService', () {
    const service = TransformEditPersistenceService();

    test('unkeyed transform channel persists globally', () {
      final plan = service.buildPlan(
        timeline: const ObjectTimeline.empty(),
        frame: 10,
        autoKeyEnabled: false,
        shapeIds: const <String>['shape-1'],
        channels: const <ObjectKeyChannel>{ObjectKeyChannel.position},
      );

      expect(plan.nonPersistentShapeIds, isEmpty);
      expect(plan.globalChannelsByShapeId['shape-1'], const <ObjectKeyChannel>{
        ObjectKeyChannel.position,
      });
    });

    test('keyed transform channel at current frame is non-persistent', () {
      final timeline = ObjectTimeline(
        tracks: <ObjectTimelineTrack>[
          ObjectTimelineTrack(
            shapeId: 'shape-1',
            keyframes: <ObjectTransformKeyframe>[
              _keyframe(
                frame: 10,
                keyedChannels: const <ObjectKeyChannel>{
                  ObjectKeyChannel.position,
                },
              ),
            ],
          ),
        ],
      );

      final plan = service.buildPlan(
        timeline: timeline,
        frame: 10,
        autoKeyEnabled: false,
        shapeIds: const <String>['shape-1'],
        channels: const <ObjectKeyChannel>{ObjectKeyChannel.position},
      );

      expect(plan.nonPersistentShapeIds, const <String>{'shape-1'});
      expect(plan.globalChannelsByShapeId.containsKey('shape-1'), isFalse);
    });

    test('keyed transform channel on another frame is non-persistent', () {
      final timeline = ObjectTimeline(
        tracks: <ObjectTimelineTrack>[
          ObjectTimelineTrack(
            shapeId: 'shape-1',
            keyframes: <ObjectTransformKeyframe>[
              _keyframe(
                frame: 0,
                keyedChannels: const <ObjectKeyChannel>{
                  ObjectKeyChannel.position,
                },
              ),
            ],
          ),
        ],
      );

      final plan = service.buildPlan(
        timeline: timeline,
        frame: 10,
        autoKeyEnabled: false,
        shapeIds: const <String>['shape-1'],
        channels: const <ObjectKeyChannel>{ObjectKeyChannel.position},
      );

      expect(plan.nonPersistentShapeIds, const <String>{'shape-1'});
      expect(plan.globalChannelsByShapeId.containsKey('shape-1'), isFalse);
    });

    test('style-only keys do not block global position persistence', () {
      final timeline = ObjectTimeline(
        tracks: <ObjectTimelineTrack>[
          ObjectTimelineTrack(
            shapeId: 'shape-1',
            keyframes: <ObjectTransformKeyframe>[
              _keyframe(
                frame: 10,
                keyedChannels: const <ObjectKeyChannel>{
                  ObjectKeyChannel.strokeColor,
                },
              ),
            ],
          ),
        ],
      );

      final plan = service.buildPlan(
        timeline: timeline,
        frame: 10,
        autoKeyEnabled: false,
        shapeIds: const <String>['shape-1'],
        channels: const <ObjectKeyChannel>{ObjectKeyChannel.position},
      );

      expect(plan.nonPersistentShapeIds, isEmpty);
      expect(plan.globalChannelsByShapeId['shape-1'], const <ObjectKeyChannel>{
        ObjectKeyChannel.position,
      });
    });

    test('auto-key forces non-persistent transform edits', () {
      final plan = service.buildPlan(
        timeline: const ObjectTimeline.empty(),
        frame: 5,
        autoKeyEnabled: true,
        shapeIds: const <String>['shape-1'],
        channels: const <ObjectKeyChannel>{
          ObjectKeyChannel.position,
          ObjectKeyChannel.rotation,
        },
      );

      expect(plan.nonPersistentShapeIds, const <String>{'shape-1'});
      expect(plan.globalChannelsByShapeId, isEmpty);
    });
  });
}

ObjectTransformKeyframe _keyframe({
  required int frame,
  required Set<ObjectKeyChannel> keyedChannels,
}) {
  return ObjectTransformKeyframe(
    frame: frame,
    position: Offset.zero,
    rotation: 0,
    scaleX: 1,
    scaleY: 1,
    opacity: 1,
    isVisible: true,
    strokeWidth: 2,
    strokeColor: const Color(0xFF000000),
    fillColor: null,
    keyedChannels: keyedChannels,
  );
}
