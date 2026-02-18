import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Samples object transforms from per-shape keyframe tracks.
class ObjectTimelineService {
  const ObjectTimelineService();

  Shape sampleShape({
    required ObjectTimeline timeline,
    required Shape shape,
    required int frame,
  }) {
    final track = timeline.trackForShape(shape.id);
    if (track == null || track.isEmpty) return shape;
    final sampledPosition = _sampleChannelValue<Offset>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.position,
      fallback: _shapeAnchor(shape),
      read: (keyframe) => keyframe.position,
      interpolate: (a, b, t) => Offset.lerp(a, b, t) ?? a,
    );
    final sampledRotation = _sampleChannelValue<double>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.rotation,
      fallback: shape.rotation,
      read: (keyframe) => keyframe.rotation,
      interpolate: _lerpNum,
    );
    final sampledScaleX = _sampleChannelValue<double>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.scale,
      fallback: shape.scaleX,
      read: (keyframe) => keyframe.scaleX,
      interpolate: _lerpNum,
    );
    final sampledScaleY = _sampleChannelValue<double>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.scale,
      fallback: shape.scaleY,
      read: (keyframe) => keyframe.scaleY,
      interpolate: _lerpNum,
    );
    final sampledOpacity = _sampleChannelValue<double>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.opacity,
      fallback: shape.opacity,
      read: (keyframe) => keyframe.opacity,
      interpolate: _lerpNum,
    );
    final sampledVisibility = _sampleChannelValue<bool>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.visibility,
      fallback: shape.isVisible,
      read: (keyframe) => keyframe.isVisible,
    );
    final sampledStrokeWidth = _sampleChannelValue<double>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.strokeWidth,
      fallback: shape.strokeWidth,
      read: (keyframe) => keyframe.strokeWidth,
    );
    final sampledStrokeColor = _sampleChannelValue<Color>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.strokeColor,
      fallback: shape.strokeColor,
      read: (keyframe) => keyframe.strokeColor,
    );
    final sampledFillColor = _sampleChannelValue<Color?>(
      track: track,
      frame: frame,
      channel: ObjectKeyChannel.fillColor,
      fallback: shape.fillColor,
      read: (keyframe) => keyframe.fillColor,
    );

    final sampled = ObjectTransformKeyframe(
      frame: frame < 0 ? 0 : frame,
      position: sampledPosition,
      rotation: sampledRotation,
      scaleX: sampledScaleX,
      scaleY: sampledScaleY,
      opacity: sampledOpacity,
      isVisible: sampledVisibility,
      strokeWidth: sampledStrokeWidth,
      strokeColor: sampledStrokeColor,
      fillColor: sampledFillColor,
      keyedChannels: kAllObjectKeyChannels,
    );
    final applied = sampled.applyToShape(shape);
    if (_sameShapeState(applied, shape)) return shape;
    return applied;
  }

  List<Shape> applyForFrame({
    required ObjectTimeline timeline,
    required List<Shape> shapes,
    required int frame,
  }) {
    if (timeline.isEmpty || shapes.isEmpty) return shapes;
    List<Shape>? updated;
    for (var i = 0; i < shapes.length; i++) {
      final shape = shapes[i];
      final sampledShape = sampleShape(
        timeline: timeline,
        shape: shape,
        frame: frame,
      );
      if (identical(sampledShape, shape)) continue;
      updated ??= List<Shape>.from(shapes);
      updated[i] = sampledShape;
    }
    if (updated == null) return shapes;
    return List<Shape>.unmodifiable(updated);
  }

  ObjectTransformKeyframe? sampleKeyframe({
    required ObjectTimelineTrack track,
    required int frame,
  }) {
    if (track.isEmpty) return null;

    final exact = track.atFrame(frame);
    if (exact != null) return exact;

    final previousFrame = track.previousFrame(frame);
    final nextFrame = track.nextFrame(frame);

    if (previousFrame == null && nextFrame == null) return null;
    // Before the first keyframe: keep the shape at its base (rest) position.
    // This prevents shapes from snapping to future keyframe transforms.
    if (previousFrame == null) return null;
    if (nextFrame == null) return track.atFrame(previousFrame);

    final previous = track.atFrame(previousFrame);
    final next = track.atFrame(nextFrame);
    if (previous == null || next == null) return null;
    final t = (frame - previous.frame) / (next.frame - previous.frame);
    return ObjectTransformKeyframe.lerp(previous, next, t, frame);
  }

  int? previousKeyframe({
    required ObjectTimeline timeline,
    required String shapeId,
    required int frame,
  }) {
    return timeline.previousFrame(shapeId, frame);
  }

  int? nextKeyframe({
    required ObjectTimeline timeline,
    required String shapeId,
    required int frame,
  }) {
    return timeline.nextFrame(shapeId, frame);
  }

  T _sampleChannelValue<T>({
    required ObjectTimelineTrack track,
    required int frame,
    required ObjectKeyChannel channel,
    required T fallback,
    required T Function(ObjectTransformKeyframe keyframe) read,
    T Function(T a, T b, double t)? interpolate,
  }) {
    final exact = _keyAtFrameForChannel(track, frame, channel);
    if (exact != null) return read(exact);

    final previous = _previousKeyForChannel(track, frame, channel);
    final next = _nextKeyForChannel(track, frame, channel);

    if (previous == null && next == null) return fallback;
    // Before the first keyed value for this channel, keep base/rest value.
    if (previous == null) return fallback;
    if (next == null || interpolate == null) return read(previous);

    final t = (frame - previous.frame) / (next.frame - previous.frame);
    return interpolate(read(previous), read(next), t.clamp(0.0, 1.0));
  }

  ObjectTransformKeyframe? _keyAtFrameForChannel(
    ObjectTimelineTrack track,
    int frame,
    ObjectKeyChannel channel,
  ) {
    final keyframe = track.atFrame(frame);
    if (keyframe == null) return null;
    return keyframe.keysChannel(channel) ? keyframe : null;
  }

  ObjectTransformKeyframe? _previousKeyForChannel(
    ObjectTimelineTrack track,
    int frame,
    ObjectKeyChannel channel,
  ) {
    ObjectTransformKeyframe? result;
    for (final keyframe in track.keyframes) {
      if (keyframe.frame >= frame) break;
      if (!keyframe.keysChannel(channel)) continue;
      result = keyframe;
    }
    return result;
  }

  ObjectTransformKeyframe? _nextKeyForChannel(
    ObjectTimelineTrack track,
    int frame,
    ObjectKeyChannel channel,
  ) {
    for (final keyframe in track.keyframes) {
      if (keyframe.frame <= frame) continue;
      if (!keyframe.keysChannel(channel)) continue;
      return keyframe;
    }
    return null;
  }

  double _lerpNum(double a, double b, double t) => a + (b - a) * t;

  Offset _shapeAnchor(Shape shape) {
    return shape.worldBounds?.center ??
        shape.localBounds?.center ??
        shape.translation;
  }

  bool _sameShapeState(Shape a, Shape b) {
    return a.translation == b.translation &&
        a.rotation == b.rotation &&
        a.scaleX == b.scaleX &&
        a.scaleY == b.scaleY &&
        a.opacity == b.opacity &&
        a.isVisible == b.isVisible &&
        a.strokeWidth == b.strokeWidth &&
        a.strokeColor == b.strokeColor &&
        a.fillColor == b.fillColor &&
        a.bounds == b.bounds &&
        _sameOffsets(a.points, b.points) &&
        _sameContours(a.contours, b.contours) &&
        _sameBezierPoints(a.bezierPoints, b.bezierPoints) &&
        _sameEraseContours(a.eraseContours, b.eraseContours);
  }

  bool _sameOffsets(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameContours(List<List<Offset>> a, List<List<Offset>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameOffsets(a[i], b[i])) return false;
    }
    return true;
  }

  bool _sameBezierPoints(List<BezierPoint>? a, List<BezierPoint>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameEraseContours(List<List<Offset>>? a, List<List<Offset>>? b) {
    if (a == null || b == null) return a == b;
    return _sameContours(a, b);
  }
}
