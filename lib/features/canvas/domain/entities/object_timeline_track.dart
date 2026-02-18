import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';

/// Immutable keyframe track for one shape id.
class ObjectTimelineTrack {
  ObjectTimelineTrack({
    required this.shapeId,
    List<ObjectTransformKeyframe> keyframes = const <ObjectTransformKeyframe>[],
  }) : keyframes = List<ObjectTransformKeyframe>.unmodifiable(
         _normalize(keyframes),
       );

  const ObjectTimelineTrack.empty({required this.shapeId})
    : keyframes = const <ObjectTransformKeyframe>[];

  final String shapeId;
  final List<ObjectTransformKeyframe> keyframes;

  bool get isEmpty => keyframes.isEmpty;
  bool get isNotEmpty => keyframes.isNotEmpty;

  List<int> get frames => List<int>.unmodifiable(keyframes.map((k) => k.frame));

  ObjectTransformKeyframe? atFrame(int frame) {
    for (final keyframe in keyframes) {
      if (keyframe.frame == frame) return keyframe;
    }
    return null;
  }

  bool containsFrame(int frame) => atFrame(frame) != null;

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

  ObjectTimelineTrack upsert(ObjectTransformKeyframe keyframe) {
    final updated = List<ObjectTransformKeyframe>.from(keyframes);
    final index = updated.indexWhere((k) => k.frame == keyframe.frame);
    if (index == -1) {
      updated.add(keyframe);
    } else {
      updated[index] = keyframe;
    }
    return ObjectTimelineTrack(shapeId: shapeId, keyframes: updated);
  }

  ObjectTimelineTrack removeAtFrame(int frame) {
    final updated = keyframes.where((k) => k.frame != frame).toList();
    if (updated.length == keyframes.length) return this;
    return ObjectTimelineTrack(shapeId: shapeId, keyframes: updated);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shapeId': shapeId,
      'keyframes': keyframes.map((k) => k.toJson()).toList(growable: false),
    };
  }

  factory ObjectTimelineTrack.fromJson(Map<String, dynamic> json) {
    final shapeId = (json['shapeId'] as String?) ?? '';
    final raw = json['keyframes'];
    final keyframes = <ObjectTransformKeyframe>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          keyframes.add(ObjectTransformKeyframe.fromJson(entry));
        }
      }
    }
    if (shapeId.isEmpty) {
      return const ObjectTimelineTrack.empty(shapeId: '');
    }
    if (keyframes.isEmpty) {
      return ObjectTimelineTrack(shapeId: shapeId);
    }
    return ObjectTimelineTrack(shapeId: shapeId, keyframes: keyframes);
  }

  static List<ObjectTransformKeyframe> _normalize(
    List<ObjectTransformKeyframe> source,
  ) {
    if (source.isEmpty) return const <ObjectTransformKeyframe>[];
    final byFrame = <int, ObjectTransformKeyframe>{};
    for (final keyframe in source) {
      byFrame[keyframe.frame] = keyframe;
    }
    final frames = byFrame.keys.toList()..sort();
    return frames.map((frame) => byFrame[frame]!).toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ObjectTimelineTrack) return false;
    if (other.shapeId != shapeId) return false;
    if (other.keyframes.length != keyframes.length) return false;
    for (var i = 0; i < keyframes.length; i++) {
      if (other.keyframes[i] != keyframes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(shapeId, Object.hashAll(keyframes));
}
