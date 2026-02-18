import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';

/// Samples scene camera state from keyframes.
class SceneCameraTimelineService {
  const SceneCameraTimelineService();

  SceneCamera? sampleCamera({
    required SceneCameraTimeline timeline,
    required int frame,
    required Size size,
    SceneCamera? fallback,
  }) {
    if (timeline.isEmpty) return fallback;

    final exact = timeline.atFrame(frame);
    if (exact != null) {
      return exact.toSceneCamera(size);
    }

    final previousFrameIndex = timeline.previousFrame(frame);
    final nextFrameIndex = timeline.nextFrame(frame);

    if (previousFrameIndex == null && nextFrameIndex == null) {
      return fallback;
    }
    // Before the first keyframe: keep the camera at its fallback state.
    // This prevents the camera from snapping to future keyframe transforms.
    if (previousFrameIndex == null) {
      return fallback;
    }
    if (nextFrameIndex == null) {
      final previous = timeline.atFrame(previousFrameIndex);
      return previous?.toSceneCamera(size) ?? fallback;
    }

    final previous = timeline.atFrame(previousFrameIndex);
    final next = timeline.atFrame(nextFrameIndex);
    if (previous == null || next == null) return fallback;

    final t = (frame - previous.frame) / (next.frame - previous.frame);
    return SceneCamera.lerp(
      previous.toSceneCamera(size),
      next.toSceneCamera(size),
      t,
    );
  }

  int? previousKeyframe(SceneCameraTimeline timeline, int frame) {
    return timeline.previousFrame(frame);
  }

  int? nextKeyframe(SceneCameraTimeline timeline, int frame) {
    return timeline.nextFrame(frame);
  }
}
