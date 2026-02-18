import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';

/// Immutable keyframe collection for scene camera animation.
class SceneCameraTimeline {
  SceneCameraTimeline({
    List<SceneCameraKeyframe> keyframes = const <SceneCameraKeyframe>[],
  }) : keyframes = List<SceneCameraKeyframe>.unmodifiable(
         _normalize(keyframes),
       );

  const SceneCameraTimeline.empty() : keyframes = const <SceneCameraKeyframe>[];

  final List<SceneCameraKeyframe> keyframes;

  bool get isEmpty => keyframes.isEmpty;
  bool get isNotEmpty => keyframes.isNotEmpty;

  List<int> get frames => List<int>.unmodifiable(keyframes.map((k) => k.frame));

  bool containsFrame(int frame) => atFrame(frame) != null;

  SceneCameraKeyframe? atFrame(int frame) {
    for (final keyframe in keyframes) {
      if (keyframe.frame == frame) return keyframe;
    }
    return null;
  }

  int? previousFrame(int frame) {
    int? result;
    for (final keyframe in keyframes) {
      if (keyframe.frame >= frame) break;
      result = keyframe.frame;
    }
    return result;
  }

  int? nextFrame(int frame) {
    for (final keyframe in keyframes) {
      if (keyframe.frame > frame) return keyframe.frame;
    }
    return null;
  }

  SceneCameraTimeline upsert(SceneCameraKeyframe keyframe) {
    final updated = List<SceneCameraKeyframe>.from(keyframes);
    final existingIndex = updated.indexWhere((k) => k.frame == keyframe.frame);
    if (existingIndex == -1) {
      updated.add(keyframe);
    } else {
      updated[existingIndex] = keyframe;
    }
    return SceneCameraTimeline(keyframes: updated);
  }

  SceneCameraTimeline removeAtFrame(int frame) {
    final updated = keyframes.where((k) => k.frame != frame).toList();
    if (updated.length == keyframes.length) return this;
    return SceneCameraTimeline(keyframes: updated);
  }

  List<Map<String, dynamic>> toJson() {
    return keyframes.map((k) => k.toJson()).toList(growable: false);
  }

  factory SceneCameraTimeline.fromJson(dynamic raw) {
    if (raw is! List) return const SceneCameraTimeline.empty();
    final keyframes = <SceneCameraKeyframe>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        keyframes.add(SceneCameraKeyframe.fromJson(entry));
      }
    }
    if (keyframes.isEmpty) return const SceneCameraTimeline.empty();
    return SceneCameraTimeline(keyframes: keyframes);
  }

  static List<SceneCameraKeyframe> _normalize(
    List<SceneCameraKeyframe> source,
  ) {
    if (source.isEmpty) return const <SceneCameraKeyframe>[];
    final byFrame = <int, SceneCameraKeyframe>{};
    for (final keyframe in source) {
      byFrame[keyframe.frame] = keyframe;
    }
    final frames = byFrame.keys.toList()..sort();
    return frames.map((frame) => byFrame[frame]!).toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SceneCameraTimeline) return false;
    if (other.keyframes.length != keyframes.length) return false;
    for (var i = 0; i < keyframes.length; i++) {
      if (other.keyframes[i] != keyframes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hashAll(keyframes);
  }
}
