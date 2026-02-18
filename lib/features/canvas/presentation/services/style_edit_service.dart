import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class ShapeStylePatch {
  const ShapeStylePatch({
    this.strokeWidth,
    this.strokeColor,
    this.opacity,
    this.isVisible,
    this.fillColor,
    this.clearFillColor = false,
  });

  final double? strokeWidth;
  final Color? strokeColor;
  final double? opacity;
  final bool? isVisible;
  final Color? fillColor;
  final bool clearFillColor;

  bool get isNoop =>
      strokeWidth == null &&
      strokeColor == null &&
      opacity == null &&
      isVisible == null &&
      fillColor == null &&
      !clearFillColor;

  bool affectsShape(Shape shape) {
    if (strokeWidth != null && shape.strokeWidth != strokeWidth) return true;
    if (strokeColor != null && shape.strokeColor != strokeColor) return true;
    if (opacity != null && shape.opacity != opacity) return true;
    if (isVisible != null && shape.isVisible != isVisible) return true;
    if (clearFillColor && shape.fillColor != null) return true;
    if (fillColor != null && shape.fillColor != fillColor) return true;
    return false;
  }

  Shape applyToShape(Shape shape) {
    return shape.copyWith(
      strokeWidth: strokeWidth ?? shape.strokeWidth,
      strokeColor: strokeColor ?? shape.strokeColor,
      opacity: opacity ?? shape.opacity,
      isVisible: isVisible ?? shape.isVisible,
      fillColor: clearFillColor ? null : (fillColor ?? shape.fillColor),
      clearFillColor: clearFillColor,
    );
  }

  bool affectsKeyframe(ObjectTransformKeyframe keyframe) {
    if (strokeWidth != null && keyframe.strokeWidth != strokeWidth) return true;
    if (strokeColor != null && keyframe.strokeColor != strokeColor) return true;
    if (opacity != null && keyframe.opacity != opacity) return true;
    if (isVisible != null && keyframe.isVisible != isVisible) return true;
    if (clearFillColor && keyframe.fillColor != null) return true;
    if (fillColor != null && keyframe.fillColor != fillColor) return true;
    return false;
  }

  ObjectTransformKeyframe applyToKeyframe(ObjectTransformKeyframe keyframe) {
    return keyframe.copyWith(
      strokeWidth: strokeWidth ?? keyframe.strokeWidth,
      strokeColor: strokeColor ?? keyframe.strokeColor,
      opacity: opacity ?? keyframe.opacity,
      isVisible: isVisible ?? keyframe.isVisible,
      fillColor: clearFillColor ? null : (fillColor ?? keyframe.fillColor),
      clearFillColor: clearFillColor,
    );
  }
}

class StyleEditDocumentResult {
  const StyleEditDocumentResult({
    required this.document,
    required this.changed,
    required this.changedFrames,
    required this.changedKeyframes,
  });

  final CanvasDocument document;
  final bool changed;
  final bool changedFrames;
  final bool changedKeyframes;
}

class StyleEditService {
  const StyleEditService();

  StyleEditDocumentResult applyPatchToDocument({
    required CanvasDocument document,
    required Set<String> shapeIds,
    required ShapeStylePatch patch,
  }) {
    if (shapeIds.isEmpty || patch.isNoop) {
      return StyleEditDocumentResult(
        document: document,
        changed: false,
        changedFrames: false,
        changedKeyframes: false,
      );
    }

    final frameResult = _applyToFrames(
      document: document,
      shapeIds: shapeIds,
      patch: patch,
    );
    final keyframeResult = _applyToObjectTimeline(
      timeline: frameResult.document.objectTimeline,
      shapeIds: shapeIds,
      patch: patch,
    );
    if (!frameResult.changed && !keyframeResult.changed) {
      return StyleEditDocumentResult(
        document: document,
        changed: false,
        changedFrames: false,
        changedKeyframes: false,
      );
    }

    final nextDocument = frameResult.document.copyWith(
      objectTimeline: keyframeResult.timeline,
      updatedAt: DateTime.now(),
    );
    return StyleEditDocumentResult(
      document: nextDocument,
      changed: true,
      changedFrames: frameResult.changed,
      changedKeyframes: keyframeResult.changed,
    );
  }

  _FramePatchResult _applyToFrames({
    required CanvasDocument document,
    required Set<String> shapeIds,
    required ShapeStylePatch patch,
  }) {
    var changed = false;
    final nextLayers = <CanvasLayer>[];
    for (final layer in document.layers) {
      var layerChanged = false;
      final nextFrames = <int, CanvasFrame>{};
      for (final entry in layer.frames.entries) {
        final frame = entry.value;
        var frameChanged = false;
        final nextShapes = frame.shapes
            .map((shape) {
              if (!shapeIds.contains(shape.id)) return shape;
              if (!patch.affectsShape(shape)) return shape;
              frameChanged = true;
              return patch.applyToShape(shape);
            })
            .toList(growable: false);

        if (frameChanged) {
          layerChanged = true;
          nextFrames[entry.key] = frame.copyWith(
            shapes: List<Shape>.unmodifiable(nextShapes),
          );
        } else {
          nextFrames[entry.key] = frame;
        }
      }

      if (layerChanged) {
        changed = true;
        nextLayers.add(layer.copyWith(frames: nextFrames));
      } else {
        nextLayers.add(layer);
      }
    }

    if (!changed) {
      return _FramePatchResult(document: document, changed: false);
    }

    return _FramePatchResult(
      document: document.copyWith(layers: nextLayers),
      changed: true,
    );
  }

  _TimelinePatchResult _applyToObjectTimeline({
    required ObjectTimeline timeline,
    required Set<String> shapeIds,
    required ShapeStylePatch patch,
  }) {
    if (timeline.isEmpty) {
      return _TimelinePatchResult(timeline: timeline, changed: false);
    }

    var changed = false;
    final nextTracks = <ObjectTimelineTrack>[];
    for (final track in timeline.tracks) {
      if (!shapeIds.contains(track.shapeId) || track.keyframes.isEmpty) {
        nextTracks.add(track);
        continue;
      }

      var trackChanged = false;
      final nextKeyframes = track.keyframes
          .map((keyframe) {
            if (!patch.affectsKeyframe(keyframe)) return keyframe;
            trackChanged = true;
            return patch.applyToKeyframe(keyframe);
          })
          .toList(growable: false);

      if (trackChanged) {
        changed = true;
        nextTracks.add(
          ObjectTimelineTrack(shapeId: track.shapeId, keyframes: nextKeyframes),
        );
      } else {
        nextTracks.add(track);
      }
    }

    if (!changed) {
      return _TimelinePatchResult(timeline: timeline, changed: false);
    }

    return _TimelinePatchResult(
      timeline: ObjectTimeline(tracks: nextTracks),
      changed: true,
    );
  }
}

class _FramePatchResult {
  const _FramePatchResult({required this.document, required this.changed});

  final CanvasDocument document;
  final bool changed;
}

class _TimelinePatchResult {
  const _TimelinePatchResult({required this.timeline, required this.changed});

  final ObjectTimeline timeline;
  final bool changed;
}
