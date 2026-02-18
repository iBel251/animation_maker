import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/audio_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class CanvasDocument {
  CanvasDocument({
    required this.id,
    required this.title,
    required this.size,
    required this.background,
    required this.fps,
    required this.frameCount,
    required List<CanvasLayer> layers,
    SceneCameraTimeline? sceneCameraTimeline,
    ObjectTimeline? objectTimeline,
    List<AudioTrack> audioTracks = const <AudioTrack>[],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    List<int> recentColors = const <int>[],
  }) : layers = List<CanvasLayer>.unmodifiable(layers),
       sceneCameraTimeline =
           sceneCameraTimeline ?? const SceneCameraTimeline.empty(),
       objectTimeline = objectTimeline ?? const ObjectTimeline.empty(),
       audioTracks = List<AudioTrack>.unmodifiable(audioTracks),
       recentColors = List<int>.unmodifiable(recentColors),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final Size size;
  final CanvasBackground background;
  final double fps;
  final int frameCount;
  final List<CanvasLayer> layers;
  final SceneCameraTimeline sceneCameraTimeline;
  final ObjectTimeline objectTimeline;
  final List<AudioTrack> audioTracks;
  final List<int> recentColors;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  CanvasLayer? layerById(String id) {
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  CanvasDocument upsertLayer(CanvasLayer layer) {
    final updated = List<CanvasLayer>.from(layers);
    final index = updated.indexWhere((l) => l.id == layer.id);
    if (index == -1) {
      updated.add(layer);
    } else {
      updated[index] = layer;
    }
    return copyWith(layers: updated);
  }

  CanvasDocument updateFrame({
    required String layerId,
    required int frameIndex,
    List<Shape>? shapes,
  }) {
    final baseLayer =
        layerById(layerId) ??
        CanvasLayer(id: layerId, name: 'Layer ${layers.length + 1}');
    final baseFrame = baseLayer.frameAt(frameIndex);
    final updatedFrame = baseFrame.copyWith(shapes: shapes ?? baseFrame.shapes);
    final updatedLayer = baseLayer.upsertFrame(updatedFrame);
    final nextFrameCount = frameIndex >= frameCount
        ? frameIndex + 1
        : frameCount;
    return upsertLayer(
      updatedLayer,
    ).copyWith(updatedAt: DateTime.now(), frameCount: nextFrameCount);
  }

  CanvasDocument copyWith({
    String? id,
    String? title,
    Size? size,
    CanvasBackground? background,
    double? fps,
    int? frameCount,
    List<CanvasLayer>? layers,
    SceneCameraTimeline? sceneCameraTimeline,
    ObjectTimeline? objectTimeline,
    List<AudioTrack>? audioTracks,
    List<int>? recentColors,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return CanvasDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      size: size ?? this.size,
      background: background ?? this.background,
      fps: fps ?? this.fps,
      frameCount: frameCount ?? this.frameCount,
      layers: layers ?? this.layers,
      sceneCameraTimeline: sceneCameraTimeline ?? this.sceneCameraTimeline,
      objectTimeline: objectTimeline ?? this.objectTimeline,
      audioTracks: audioTracks ?? this.audioTracks,
      recentColors: recentColors ?? this.recentColors,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  factory CanvasDocument.singleLayer({
    required String id,
    required String title,
    required Size size,
    CanvasBackground? background,
    required double fps,
    int frameCount = 1,
    List<Shape> shapes = const <Shape>[],
    String layerId = 'layer-1',
    String layerName = 'Layer 1',
    DateTime? createdAt,
    DateTime? updatedAt,
    int version = 1,
    List<int> recentColors = const <int>[],
  }) {
    final frame = CanvasFrame(index: 0, shapes: shapes);
    final layer = CanvasLayer(id: layerId, name: layerName, frames: {0: frame});
    return CanvasDocument(
      id: id,
      title: title,
      size: size,
      background: background ?? const CanvasBackground.transparent(),
      fps: fps,
      frameCount: frameCount,
      layers: [layer],
      recentColors: recentColors,
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: version,
    );
  }
}
