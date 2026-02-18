import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

/// Result of resolving shapes for a frame load operation.
class FrameLoadResult {
  const FrameLoadResult({
    required this.document,
    required this.layer,
    required this.shapes,
    required this.repairedMissingShapes,
  });

  final CanvasDocument document;
  final CanvasLayer layer;
  final List<Shape> shapes;
  final bool repairedMissingShapes;
}

/// Stateless service that resolves which shapes should be loaded for a given
/// frame, merging historical shapes and repairing missing entries as needed.
class FrameShapeResolver {
  const FrameShapeResolver();

  /// Resolves the shapes for [frameIndex] in [layerId], backfilling from
  /// historical frames and repairing the document when shapes are missing.
  FrameLoadResult resolveFrameLoadShapes({
    required CanvasDocument document,
    required String layerId,
    required int frameIndex,
  }) {
    final layer = document.layerById(layerId) ?? document.layers.first;
    final explicitFrame = layer.frames[frameIndex];
    final sourceFrame = explicitFrame ?? layer.frameAt(frameIndex);

    final backfilled = mergeFrameShapesWithAllFrames(
      layer: layer,
      frameIndex: frameIndex,
      currentShapes: sourceFrame.shapes,
    );
    final backfilledChanged = !sameShapeIdOrder(
      backfilled,
      sourceFrame.shapes,
    );
    if (explicitFrame == null) {
      return FrameLoadResult(
        document: document,
        layer: layer,
        shapes: backfilled,
        repairedMissingShapes: false,
      );
    }

    final previousShapes = mergeFrameShapesWithAllFrames(
      layer: layer,
      frameIndex: frameIndex - 1,
      currentShapes: layer.frameAt(frameIndex - 1).shapes,
    );
    if (previousShapes.isEmpty) {
      if (backfilledChanged) {
        final repairedFrame = explicitFrame.copyWith(shapes: backfilled);
        final repairedLayer = layer.upsertFrame(repairedFrame);
        final repairedDocument = document
            .upsertLayer(repairedLayer)
            .copyWith(updatedAt: DateTime.now());
        final resolvedLayer =
            repairedDocument.layerById(repairedLayer.id) ?? repairedLayer;
        return FrameLoadResult(
          document: repairedDocument,
          layer: resolvedLayer,
          shapes: repairedFrame.shapes,
          repairedMissingShapes: true,
        );
      }
      return FrameLoadResult(
        document: document,
        layer: layer,
        shapes: backfilled,
        repairedMissingShapes: false,
      );
    }

    final merged = mergeFrameShapesWithPrevious(
      previousShapes: previousShapes,
      currentShapes: backfilled,
    );
    if (sameShapeIdOrder(merged, explicitFrame.shapes)) {
      return FrameLoadResult(
        document: document,
        layer: layer,
        shapes: merged,
        repairedMissingShapes: false,
      );
    }

    final repairedFrame = explicitFrame.copyWith(shapes: merged);
    final repairedLayer = layer.upsertFrame(repairedFrame);
    final repairedDocument = document
        .upsertLayer(repairedLayer)
        .copyWith(updatedAt: DateTime.now());
    final resolvedLayer =
        repairedDocument.layerById(repairedLayer.id) ?? repairedLayer;
    return FrameLoadResult(
      document: repairedDocument,
      layer: resolvedLayer,
      shapes: repairedFrame.shapes,
      repairedMissingShapes: true,
    );
  }

  /// Merges [currentShapes] with shapes from all other explicit frames in
  /// [layer], adding any missing shapes that appear in any frame.
  ///
  /// This ensures that a shape drawn on any frame is visible on every frame,
  /// regardless of whether it was drawn before or after [frameIndex].
  List<Shape> mergeFrameShapesWithAllFrames({
    required CanvasLayer layer,
    required int frameIndex,
    required List<Shape> currentShapes,
  }) {
    final otherFrameIndices =
        layer.frames.keys
            .where((index) => index != frameIndex)
            .toList(growable: false)
          ..sort((a, b) => b.compareTo(a));
    if (otherFrameIndices.isEmpty) {
      return List<Shape>.unmodifiable(currentShapes);
    }

    final merged = List<Shape>.from(currentShapes);
    final existingIds = {for (final shape in currentShapes) shape.id};
    var changed = false;
    for (final otherIndex in otherFrameIndices) {
      final frame = layer.frames[otherIndex];
      if (frame == null) continue;
      for (final shape in frame.shapes) {
        if (existingIds.contains(shape.id)) continue;
        merged.add(shape.copyWith());
        existingIds.add(shape.id);
        changed = true;
      }
    }

    if (!changed) {
      return List<Shape>.unmodifiable(currentShapes);
    }
    return List<Shape>.unmodifiable(merged);
  }

  /// Merges [currentShapes] with [previousShapes], adding any shapes from
  /// the previous frame that are not present in the current frame.
  List<Shape> mergeFrameShapesWithPrevious({
    required List<Shape> previousShapes,
    required List<Shape> currentShapes,
  }) {
    final merged = List<Shape>.from(currentShapes);
    final currentIds = {for (final shape in currentShapes) shape.id};
    for (final shape in previousShapes) {
      if (currentIds.contains(shape.id)) continue;
      merged.add(shape.copyWith());
    }
    return List<Shape>.unmodifiable(merged);
  }

  /// Maps incoming shapes back to their base (pre-keyframe) versions for
  /// document storage. Uses object identity to detect which shapes the caller
  /// actually modified vs. carried over unchanged from [displayShapes].
  List<Shape> resolveBaseShapesForSave({
    required List<Shape> incomingShapes,
    required List<Shape> displayShapes,
    required List<Shape> baseShapes,
  }) {
    if (baseShapes.isEmpty) return incomingShapes;

    final displayById = <String, Shape>{};
    for (final s in displayShapes) {
      displayById[s.id] = s;
    }

    final baseById = <String, Shape>{};
    for (final s in baseShapes) {
      baseById[s.id] = s;
    }

    final result = <Shape>[];
    for (final shape in incomingShapes) {
      final displayVersion = displayById[shape.id];
      if (displayVersion != null && identical(shape, displayVersion)) {
        // Same object reference as display → user didn't modify this shape.
        // Use the base (pre-keyframe) version for clean document storage.
        result.add(baseById[shape.id] ?? shape);
      } else {
        // User modified this shape or it is newly created → save as-is.
        result.add(shape);
      }
    }
    return result;
  }

  /// Returns true when both lists contain shapes with the same IDs in order.
  bool sameShapeIdOrder(List<Shape> a, List<Shape> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}
