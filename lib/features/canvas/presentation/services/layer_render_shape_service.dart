import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/object_timeline_service.dart';

/// Composes render-order shapes across all visible layers for a frame.
///
/// Non-active layers are sampled through the object timeline so playback
/// remains consistent while editing another layer.
class LayerRenderShapeService {
  const LayerRenderShapeService({
    ObjectTimelineService timelineService = const ObjectTimelineService(),
  }) : _timelineService = timelineService;

  final ObjectTimelineService _timelineService;

  /// Returns shapes ordered for painting:
  /// - top layers first
  /// - top shapes first inside each layer
  List<Shape> compute({
    required CanvasDocument document,
    required int currentFrame,
    required String activeLayerId,
    required List<Shape> activeLayerShapes,
  }) {
    final result = <Shape>[];
    final timeline = document.objectTimeline;
    for (var i = document.layers.length - 1; i >= 0; i--) {
      final layer = document.layers[i];
      if (!layer.isVisible) continue;

      final layerShapes = layer.id == activeLayerId
          ? activeLayerShapes
          : _timelineService.applyForFrame(
              timeline: timeline,
              shapes: layer.frameAt(currentFrame).shapes,
              frame: currentFrame,
            );
      for (var j = layerShapes.length - 1; j >= 0; j--) {
        result.add(layerShapes[j]);
      }
    }
    return result;
  }
}
