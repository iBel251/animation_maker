import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';

const Set<ObjectKeyChannel> kTransformObjectKeyChannels = <ObjectKeyChannel>{
  ObjectKeyChannel.position,
  ObjectKeyChannel.rotation,
  ObjectKeyChannel.scale,
};

class TransformEditPersistencePlan {
  const TransformEditPersistencePlan({
    this.nonPersistentShapeIds = const <String>{},
    this.globalChannelsByShapeId = const <String, Set<ObjectKeyChannel>>{},
  });

  final Set<String> nonPersistentShapeIds;
  final Map<String, Set<ObjectKeyChannel>> globalChannelsByShapeId;

  bool get hasGlobalChannels => globalChannelsByShapeId.isNotEmpty;
}

/// Computes how transform edits should be persisted when manual keying is used.
///
/// Rules:
/// - Auto-key ON: treat edited shapes as timeline-driven (non-persistent base).
/// - Auto-key OFF:
///   - If an edited transform channel is keyed anywhere, keep frame edits
///     non-persistent unless explicitly keyed by the user.
///   - If a channel is unkeyed globally, treat it as a static/rest channel and
///     persist it globally across frames.
class TransformEditPersistenceService {
  const TransformEditPersistenceService();

  TransformEditPersistencePlan buildPlan({
    required ObjectTimeline timeline,
    required int frame,
    required bool autoKeyEnabled,
    required Iterable<String> shapeIds,
    required Set<ObjectKeyChannel> channels,
  }) {
    final uniqueShapeIds = shapeIds.toSet();
    if (uniqueShapeIds.isEmpty) {
      return const TransformEditPersistencePlan();
    }

    final normalizedChannels = channels
        .where(kTransformObjectKeyChannels.contains)
        .toSet();
    if (normalizedChannels.isEmpty) {
      return const TransformEditPersistencePlan();
    }

    if (autoKeyEnabled) {
      return TransformEditPersistencePlan(
        nonPersistentShapeIds: Set<String>.unmodifiable(uniqueShapeIds),
      );
    }

    final nonPersistentShapeIds = <String>{};
    final globalChannelsByShapeId = <String, Set<ObjectKeyChannel>>{};

    for (final shapeId in uniqueShapeIds) {
      final track = timeline.trackForShape(shapeId);
      final globalChannels = <ObjectKeyChannel>{};
      var hasAnimatedChannel = false;

      for (final channel in normalizedChannels) {
        final keyedAtFrame = _hasKeyForChannelAtFrame(track, frame, channel);
        final keyedAnywhere = _hasAnyKeyForChannel(track, channel);
        if (keyedAtFrame || keyedAnywhere) {
          hasAnimatedChannel = true;
        } else {
          globalChannels.add(channel);
        }
      }

      if (hasAnimatedChannel) {
        nonPersistentShapeIds.add(shapeId);
      }
      if (globalChannels.isNotEmpty) {
        globalChannelsByShapeId[shapeId] = Set<ObjectKeyChannel>.unmodifiable(
          globalChannels,
        );
      }
    }

    return TransformEditPersistencePlan(
      nonPersistentShapeIds: Set<String>.unmodifiable(nonPersistentShapeIds),
      globalChannelsByShapeId: Map<String, Set<ObjectKeyChannel>>.unmodifiable(
        globalChannelsByShapeId,
      ),
    );
  }

  bool _hasAnyKeyForChannel(
    ObjectTimelineTrack? track,
    ObjectKeyChannel channel,
  ) {
    if (track == null || track.keyframes.isEmpty) return false;
    for (final keyframe in track.keyframes) {
      if (keyframe.keysChannel(channel)) return true;
    }
    return false;
  }

  bool _hasKeyForChannelAtFrame(
    ObjectTimelineTrack? track,
    int frame,
    ObjectKeyChannel channel,
  ) {
    if (track == null) return false;
    final keyframe = track.atFrame(frame);
    if (keyframe == null) return false;
    return keyframe.keysChannel(channel);
  }
}
