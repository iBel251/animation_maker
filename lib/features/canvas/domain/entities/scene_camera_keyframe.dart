import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';

/// A single keyed scene camera value at a timeline frame.
class SceneCameraKeyframe {
  const SceneCameraKeyframe({
    required this.frame,
    required this.position,
    required this.zoom,
    required this.rotation,
  }) : assert(frame >= 0, 'Frame must be non-negative'),
       assert(zoom > 0, 'Zoom must be positive');

  final int frame;
  final Offset position;
  final double zoom;
  final double rotation;

  factory SceneCameraKeyframe.fromSceneCamera({
    required int frame,
    required SceneCamera camera,
  }) {
    return SceneCameraKeyframe(
      frame: frame,
      position: camera.position,
      zoom: camera.zoom,
      rotation: camera.rotation,
    );
  }

  SceneCamera toSceneCamera(Size size) {
    return SceneCamera(
      position: position,
      size: size,
      zoom: zoom,
      rotation: rotation,
    );
  }

  SceneCameraKeyframe copyWith({
    int? frame,
    Offset? position,
    double? zoom,
    double? rotation,
  }) {
    return SceneCameraKeyframe(
      frame: frame ?? this.frame,
      position: position ?? this.position,
      zoom: zoom ?? this.zoom,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'frame': frame,
      'position': <String, dynamic>{'dx': position.dx, 'dy': position.dy},
      'zoom': zoom,
      'rotation': rotation,
    };
  }

  factory SceneCameraKeyframe.fromJson(Map<String, dynamic> json) {
    final positionValue = json['position'];
    var position = Offset.zero;
    if (positionValue is Map<String, dynamic>) {
      position = Offset(
        _num(positionValue['dx'], 0.0),
        _num(positionValue['dy'], 0.0),
      );
    }
    return SceneCameraKeyframe(
      frame: _int(json['frame'], 0).clamp(0, 1 << 30),
      position: position,
      zoom: _num(json['zoom'], 1.0).clamp(0.1, 10.0),
      rotation: _num(json['rotation'], 0.0),
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneCameraKeyframe &&
        other.frame == frame &&
        other.position == position &&
        other.zoom == zoom &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(frame, position, zoom, rotation);
}
