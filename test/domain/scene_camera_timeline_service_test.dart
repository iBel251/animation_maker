import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/services/scene_camera_timeline_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneCameraTimelineService', () {
    const service = SceneCameraTimelineService();
    const size = Size(1920, 1080);

    final timeline = SceneCameraTimeline(
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
    );

    test('samples exact keyframe values', () {
      final sampled = service.sampleCamera(
        timeline: timeline,
        frame: 10,
        size: size,
      );

      expect(sampled, isNotNull);
      expect(sampled!.position, const Offset(100, 50));
      expect(sampled.zoom, 2.0);
      expect(sampled.rotation, 1.0);
    });

    test('samples linear interpolation between keys', () {
      final sampled = service.sampleCamera(
        timeline: timeline,
        frame: 5,
        size: size,
      );

      expect(sampled, isNotNull);
      expect(sampled!.position.dx, closeTo(50.0, 0.0001));
      expect(sampled.position.dy, closeTo(25.0, 0.0001));
      expect(sampled.zoom, closeTo(1.5, 0.0001));
      expect(sampled.rotation, closeTo(0.5, 0.0001));
    });

    test('returns fallback before first keyframe', () {
      final before = service.sampleCamera(
        timeline: timeline,
        frame: -5,
        size: size,
      );
      // Before the first keyframe the camera stays at its fallback (rest)
      // state rather than snapping to a future keyframe.
      expect(before, isNull);
    });

    test('holds last keyframe value after keyed range', () {
      final after = service.sampleCamera(
        timeline: timeline,
        frame: 20,
        size: size,
      );

      expect(after, isNotNull);
      expect(after!.position, const Offset(100, 50));
    });

    test('finds previous and next keyframes', () {
      expect(service.previousKeyframe(timeline, 5), 0);
      expect(service.nextKeyframe(timeline, 5), 10);
      expect(service.previousKeyframe(timeline, 0), isNull);
      expect(service.nextKeyframe(timeline, 10), isNull);
    });
  });
}
