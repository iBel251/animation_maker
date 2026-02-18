import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Keyed transform values for a single object (shape) at a timeline frame.
class ObjectTransformKeyframe {
  const ObjectTransformKeyframe({
    required this.frame,
    required this.position,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.opacity,
    this.isVisible = true,
    this.strokeWidth = 2.0,
    this.strokeColor = const Color(0xFF000000),
    this.fillColor,
    this.keyedChannels = kAllObjectKeyChannels,
  }) : assert(frame >= 0, 'Frame must be non-negative');

  final int frame;
  final Offset position;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double opacity;
  final bool isVisible;
  final double strokeWidth;
  final Color strokeColor;
  final Color? fillColor;
  final Set<ObjectKeyChannel> keyedChannels;

  Set<ObjectKeyChannel> get effectiveKeyedChannels =>
      _normalizeChannels(keyedChannels);

  bool keysChannel(ObjectKeyChannel channel) =>
      effectiveKeyedChannels.contains(channel);

  factory ObjectTransformKeyframe.fromShape({
    required int frame,
    required Shape shape,
    Set<ObjectKeyChannel> keyedChannels = kAllObjectKeyChannels,
  }) {
    final channels = _normalizeChannels(keyedChannels);
    return ObjectTransformKeyframe(
      frame: frame,
      position: _shapeAnchor(shape),
      rotation: shape.rotation,
      scaleX: shape.scaleX,
      scaleY: shape.scaleY,
      opacity: shape.opacity,
      isVisible: shape.isVisible,
      strokeWidth: shape.strokeWidth,
      strokeColor: shape.strokeColor,
      fillColor: shape.fillColor,
      keyedChannels: channels,
    );
  }

  ObjectTransformKeyframe withShapeChannels({
    required Shape shape,
    required Set<ObjectKeyChannel> channels,
    bool mergeKeyedChannels = true,
  }) {
    final normalizedChannels = _normalizeChannels(channels);
    final nextChannels = mergeKeyedChannels
        ? _normalizeChannels({...keyedChannels, ...normalizedChannels})
        : normalizedChannels;
    final updatesFill = normalizedChannels.contains(ObjectKeyChannel.fillColor);
    return copyWith(
      position: normalizedChannels.contains(ObjectKeyChannel.position)
          ? _shapeAnchor(shape)
          : null,
      rotation: normalizedChannels.contains(ObjectKeyChannel.rotation)
          ? shape.rotation
          : null,
      scaleX: normalizedChannels.contains(ObjectKeyChannel.scale)
          ? shape.scaleX
          : null,
      scaleY: normalizedChannels.contains(ObjectKeyChannel.scale)
          ? shape.scaleY
          : null,
      opacity: normalizedChannels.contains(ObjectKeyChannel.opacity)
          ? shape.opacity
          : null,
      isVisible: normalizedChannels.contains(ObjectKeyChannel.visibility)
          ? shape.isVisible
          : null,
      strokeWidth: normalizedChannels.contains(ObjectKeyChannel.strokeWidth)
          ? shape.strokeWidth
          : null,
      strokeColor: normalizedChannels.contains(ObjectKeyChannel.strokeColor)
          ? shape.strokeColor
          : null,
      fillColor: updatesFill ? shape.fillColor : null,
      clearFillColor: updatesFill && shape.fillColor == null,
      keyedChannels: nextChannels,
    );
  }

  Shape applyToShape(Shape shape) {
    final moved = _moveShapeAnchorTo(shape, position);
    return moved.copyWith(
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      opacity: opacity.clamp(0.0, 1.0),
      isVisible: isVisible,
      strokeWidth: strokeWidth,
      strokeColor: strokeColor,
      fillColor: fillColor,
      clearFillColor: fillColor == null,
    );
  }

  ObjectTransformKeyframe copyWith({
    int? frame,
    Offset? position,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? opacity,
    bool? isVisible,
    double? strokeWidth,
    Color? strokeColor,
    Color? fillColor,
    Set<ObjectKeyChannel>? keyedChannels,
    bool clearFillColor = false,
  }) {
    return ObjectTransformKeyframe(
      frame: frame ?? this.frame,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      opacity: opacity ?? this.opacity,
      isVisible: isVisible ?? this.isVisible,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: clearFillColor ? null : (fillColor ?? this.fillColor),
      keyedChannels: keyedChannels == null
          ? this.keyedChannels
          : _normalizeChannels(keyedChannels),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'frame': frame,
      'position': <String, dynamic>{'dx': position.dx, 'dy': position.dy},
      'rotation': rotation,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'opacity': opacity,
      'isVisible': isVisible,
      'strokeWidth': strokeWidth,
      'strokeColor': strokeColor.value,
      'fillColor': fillColor?.value,
      'keyedChannels': effectiveKeyedChannels
          .map((channel) => channel.name)
          .toList(growable: false),
    };
  }

  factory ObjectTransformKeyframe.fromJson(Map<String, dynamic> json) {
    final positionRaw = json['position'];
    var position = Offset.zero;
    if (positionRaw is Map<String, dynamic>) {
      position = Offset(
        _num(positionRaw['dx'], 0.0),
        _num(positionRaw['dy'], 0.0),
      );
    }
    return ObjectTransformKeyframe(
      frame: _int(json['frame'], 0).clamp(0, 1 << 30),
      position: position,
      rotation: _num(json['rotation'], 0.0),
      scaleX: _num(json['scaleX'], 1.0).clamp(0.001, 1000.0),
      scaleY: _num(json['scaleY'], 1.0).clamp(0.001, 1000.0),
      opacity: _num(json['opacity'], 1.0).clamp(0.0, 1.0),
      isVisible: json['isVisible'] as bool? ?? true,
      strokeWidth: _num(json['strokeWidth'], 2.0),
      strokeColor: _color(json['strokeColor'], const Color(0xFF000000)),
      fillColor: _colorNullable(json['fillColor']),
      keyedChannels: _channelsFromJson(json['keyedChannels']),
    );
  }

  static double _num(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  static Color _color(dynamic value, Color fallback) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    return fallback;
  }

  static Color? _colorNullable(dynamic value) {
    if (value == null) return null;
    return _color(value, const Color(0xFF000000));
  }

  static ObjectTransformKeyframe lerp(
    ObjectTransformKeyframe a,
    ObjectTransformKeyframe b,
    double t,
    int frame,
  ) {
    final clampedT = t.clamp(0.0, 1.0);
    return ObjectTransformKeyframe(
      frame: frame,
      position: Offset.lerp(a.position, b.position, clampedT) ?? a.position,
      rotation: _lerpNum(a.rotation, b.rotation, clampedT),
      scaleX: _lerpNum(a.scaleX, b.scaleX, clampedT),
      scaleY: _lerpNum(a.scaleY, b.scaleY, clampedT),
      opacity: _lerpNum(a.opacity, b.opacity, clampedT),
      // Style/visibility channels default to stepped behavior.
      isVisible: clampedT < 1.0 ? a.isVisible : b.isVisible,
      strokeWidth: clampedT < 1.0 ? a.strokeWidth : b.strokeWidth,
      strokeColor: clampedT < 1.0 ? a.strokeColor : b.strokeColor,
      fillColor: clampedT < 1.0 ? a.fillColor : b.fillColor,
      keyedChannels: _normalizeChannels({
        ...a.effectiveKeyedChannels,
        ...b.effectiveKeyedChannels,
      }),
    );
  }

  static double _lerpNum(double a, double b, double t) => a + (b - a) * t;

  static Offset _shapeAnchor(Shape shape) {
    return shape.worldBounds?.center ??
        shape.localBounds?.center ??
        shape.translation;
  }

  static Shape _moveShapeAnchorTo(Shape shape, Offset targetAnchor) {
    final currentAnchor = _shapeAnchor(shape);
    final delta = targetAnchor - currentAnchor;
    if (delta == Offset.zero) return shape;

    final usesTransformMatrix =
        shape.translation != Offset.zero ||
        shape.rotation != 0.0 ||
        shape.scaleX != 1.0 ||
        shape.scaleY != 1.0 ||
        shape.transform.pivot != Offset.zero;
    if (usesTransformMatrix) {
      return shape.copyWith(translation: shape.translation + delta);
    }

    final shiftedBounds = shape.bounds?.shift(delta);
    final shiftedContours = shape.contours.isNotEmpty
        ? shape.contours
              .map(
                (contour) =>
                    contour.map((p) => p + delta).toList(growable: false),
              )
              .toList(growable: false)
        : null;
    final shiftedPoints = shape.points.isNotEmpty
        ? shape.points.map((p) => p + delta).toList(growable: false)
        : null;
    final shiftedBezierPoints = shape.bezierPoints == null
        ? null
        : shape.bezierPoints!
              .map((bp) => bp.copyWith(position: bp.position + delta))
              .toList(growable: false);
    final shiftedEraseContours = shape.eraseContours == null
        ? null
        : shape.eraseContours!
              .map(
                (contour) =>
                    contour.map((p) => p + delta).toList(growable: false),
              )
              .toList(growable: false);

    final hasGeometryToShift =
        shiftedBounds != null ||
        shiftedContours != null ||
        shiftedPoints != null ||
        shiftedBezierPoints != null ||
        shiftedEraseContours != null;
    if (!hasGeometryToShift) {
      return shape.copyWith(translation: shape.translation + delta);
    }

    return shape.copyWith(
      bounds: shiftedBounds,
      points: shiftedContours != null
          ? shiftedContours.first
          : (shiftedPoints ?? shape.points.toList(growable: false)),
      contours: shiftedContours,
      bezierPoints: shiftedBezierPoints,
      eraseContours: shiftedEraseContours,
      pointPressures: shape.pointPressures?.toList(growable: false),
      translation: shape.translation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ObjectTransformKeyframe &&
        other.frame == frame &&
        other.position == position &&
        other.rotation == rotation &&
        other.scaleX == scaleX &&
        other.scaleY == scaleY &&
        other.opacity == opacity &&
        other.isVisible == isVisible &&
        other.strokeWidth == strokeWidth &&
        other.strokeColor == strokeColor &&
        other.fillColor == fillColor &&
        _sameChannelSet(other.effectiveKeyedChannels, effectiveKeyedChannels);
  }

  @override
  int get hashCode => Object.hash(
    frame,
    position,
    rotation,
    scaleX,
    scaleY,
    opacity,
    isVisible,
    strokeWidth,
    strokeColor,
    fillColor,
    Object.hashAll(_sortedChannels(effectiveKeyedChannels)),
  );

  static Set<ObjectKeyChannel> _normalizeChannels(
    Set<ObjectKeyChannel> channels,
  ) {
    if (channels.isEmpty) return kAllObjectKeyChannels;
    return Set<ObjectKeyChannel>.unmodifiable(channels);
  }

  static Set<ObjectKeyChannel> _channelsFromJson(dynamic raw) {
    if (raw is! List) return kAllObjectKeyChannels;
    final parsed = <ObjectKeyChannel>{};
    for (final entry in raw) {
      if (entry is String) {
        for (final channel in ObjectKeyChannel.values) {
          if (channel.name == entry) {
            parsed.add(channel);
            break;
          }
        }
      } else if (entry is int &&
          entry >= 0 &&
          entry < ObjectKeyChannel.values.length) {
        parsed.add(ObjectKeyChannel.values[entry]);
      }
    }
    return _normalizeChannels(parsed);
  }

  static bool _sameChannelSet(
    Set<ObjectKeyChannel> a,
    Set<ObjectKeyChannel> b,
  ) {
    if (a.length != b.length) return false;
    for (final channel in a) {
      if (!b.contains(channel)) return false;
    }
    return true;
  }

  static List<ObjectKeyChannel> _sortedChannels(
    Set<ObjectKeyChannel> channels,
  ) {
    final sorted = channels.toList(growable: false);
    sorted.sort((a, b) => a.index.compareTo(b.index));
    return sorted;
  }
}
