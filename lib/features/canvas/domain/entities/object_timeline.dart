import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';

/// Collection of per-object keyframe tracks.
class ObjectTimeline {
  ObjectTimeline({
    List<ObjectTimelineTrack> tracks = const <ObjectTimelineTrack>[],
  }) : tracks = List<ObjectTimelineTrack>.unmodifiable(_normalize(tracks));

  const ObjectTimeline.empty() : tracks = const <ObjectTimelineTrack>[];

  final List<ObjectTimelineTrack> tracks;

  bool get isEmpty => tracks.isEmpty;
  bool get isNotEmpty => tracks.isNotEmpty;

  List<String> get shapeIds =>
      List<String>.unmodifiable(tracks.map((t) => t.shapeId));

  ObjectTimelineTrack? trackForShape(String shapeId) {
    for (final track in tracks) {
      if (track.shapeId == shapeId) return track;
    }
    return null;
  }

  bool containsFrame(String shapeId, int frame) {
    return trackForShape(shapeId)?.containsFrame(frame) ?? false;
  }

  List<int> keyframeFrames(String shapeId) {
    return trackForShape(shapeId)?.frames ?? const <int>[];
  }

  int? previousFrame(String shapeId, int frame) {
    return trackForShape(shapeId)?.previousFrame(frame);
  }

  int? nextFrame(String shapeId, int frame) {
    return trackForShape(shapeId)?.nextFrame(frame);
  }

  ObjectTimeline upsert({
    required String shapeId,
    required ObjectTransformKeyframe keyframe,
  }) {
    if (shapeId.isEmpty) return this;
    final updated = List<ObjectTimelineTrack>.from(tracks);
    final index = updated.indexWhere((track) => track.shapeId == shapeId);
    if (index == -1) {
      updated.add(ObjectTimelineTrack(shapeId: shapeId, keyframes: [keyframe]));
    } else {
      updated[index] = updated[index].upsert(keyframe);
    }
    return ObjectTimeline(tracks: updated);
  }

  ObjectTimeline removeAtFrame({required String shapeId, required int frame}) {
    if (shapeId.isEmpty) return this;
    final updated = <ObjectTimelineTrack>[];
    var changed = false;
    for (final track in tracks) {
      if (track.shapeId != shapeId) {
        updated.add(track);
        continue;
      }
      final nextTrack = track.removeAtFrame(frame);
      if (nextTrack != track) {
        changed = true;
      }
      if (nextTrack.isNotEmpty) {
        updated.add(nextTrack);
      } else if (track.isNotEmpty) {
        changed = true;
      }
    }
    if (!changed) return this;
    return ObjectTimeline(tracks: updated);
  }

  ObjectTimeline removeShape(String shapeId) {
    if (shapeId.isEmpty) return this;
    return removeShapes(<String>{shapeId});
  }

  ObjectTimeline removeShapes(Set<String> shapeIds) {
    if (shapeIds.isEmpty || tracks.isEmpty) return this;
    final updated = tracks
        .where((track) => !shapeIds.contains(track.shapeId))
        .toList(growable: false);
    if (updated.length == tracks.length) return this;
    return ObjectTimeline(tracks: updated);
  }

  List<Map<String, dynamic>> toJson() {
    return tracks.map((t) => t.toJson()).toList(growable: false);
  }

  factory ObjectTimeline.fromJson(dynamic raw) {
    if (raw is! List) return const ObjectTimeline.empty();
    final tracks = <ObjectTimelineTrack>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final track = ObjectTimelineTrack.fromJson(entry);
        if (track.shapeId.isNotEmpty && track.isNotEmpty) {
          tracks.add(track);
        }
      }
    }
    if (tracks.isEmpty) return const ObjectTimeline.empty();
    return ObjectTimeline(tracks: tracks);
  }

  static List<ObjectTimelineTrack> _normalize(
    List<ObjectTimelineTrack> source,
  ) {
    if (source.isEmpty) return const <ObjectTimelineTrack>[];
    final byShapeId = <String, ObjectTimelineTrack>{};
    for (final track in source) {
      if (track.shapeId.isEmpty || track.isEmpty) continue;
      byShapeId[track.shapeId] = track;
    }
    final ids = byShapeId.keys.toList()..sort();
    return ids.map((id) => byShapeId[id]!).toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ObjectTimeline) return false;
    if (other.tracks.length != tracks.length) return false;
    for (var i = 0; i < tracks.length; i++) {
      if (other.tracks[i] != tracks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(tracks);
}
