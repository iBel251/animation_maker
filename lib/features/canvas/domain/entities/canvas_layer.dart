import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';

class CanvasLayer {
  CanvasLayer({
    required this.id,
    required this.name,
    Map<int, CanvasFrame> frames = const <int, CanvasFrame>{},
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
  }) : frames = Map<int, CanvasFrame>.unmodifiable(frames);

  final String id;
  final String name;
  final Map<int, CanvasFrame> frames;
  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final BlendMode blendMode;

  CanvasFrame frameAt(int index) {
    return frames[index] ?? CanvasFrame(index: index);
  }

  CanvasLayer upsertFrame(CanvasFrame frame) {
    final updated = Map<int, CanvasFrame>.from(frames);
    updated[frame.index] = frame;
    return copyWith(frames: updated);
  }

  CanvasLayer copyWith({
    String? id,
    String? name,
    Map<int, CanvasFrame>? frames,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    BlendMode? blendMode,
  }) {
    return CanvasLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      frames: frames ?? this.frames,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
    );
  }
}
