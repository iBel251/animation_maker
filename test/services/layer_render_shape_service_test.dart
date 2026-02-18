import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/services/layer_render_shape_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LayerRenderShapeService', () {
    const service = LayerRenderShapeService();

    test('samples object timeline for non-active layers', () {
      final animatedShape = Shape(
        id: 'shape-a',
        kind: ShapeKind.rectangle,
        points: const <Offset>[Offset(0, 0), Offset(100, 100)],
      );
      final activeShape = Shape(
        id: 'shape-b',
        kind: ShapeKind.rectangle,
        points: const <Offset>[Offset(300, 0), Offset(360, 60)],
      );
      final document = CanvasDocument(
        id: 'doc-1',
        title: 'Doc',
        size: const Size(1920, 1080),
        background: const CanvasBackground.transparent(),
        fps: 24,
        frameCount: 11,
        layers: <CanvasLayer>[
          CanvasLayer(
            id: 'layer-a',
            name: 'Layer A',
            frames: <int, CanvasFrame>{
              0: CanvasFrame(index: 0, shapes: <Shape>[animatedShape]),
            },
          ),
          CanvasLayer(
            id: 'layer-b',
            name: 'Layer B',
            frames: <int, CanvasFrame>{
              0: CanvasFrame(index: 0, shapes: <Shape>[activeShape]),
            },
          ),
        ],
        objectTimeline: ObjectTimeline(
          tracks: <ObjectTimelineTrack>[
            ObjectTimelineTrack(
              shapeId: 'shape-a',
              keyframes: const <ObjectTransformKeyframe>[
                ObjectTransformKeyframe(
                  frame: 0,
                  position: Offset(50, 50),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                  isVisible: true,
                  strokeWidth: 2,
                  strokeColor: Color(0xFF000000),
                  keyedChannels: <ObjectKeyChannel>{ObjectKeyChannel.position},
                ),
                ObjectTransformKeyframe(
                  frame: 10,
                  position: Offset(150, 50),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                  isVisible: true,
                  strokeWidth: 2,
                  strokeColor: Color(0xFF000000),
                  keyedChannels: <ObjectKeyChannel>{ObjectKeyChannel.position},
                ),
              ],
            ),
          ],
        ),
      );

      final renderShapes = service.compute(
        document: document,
        currentFrame: 5,
        activeLayerId: 'layer-b',
        activeLayerShapes: <Shape>[activeShape],
      );

      final renderedAnimated = renderShapes.firstWhere(
        (shape) => shape.id == 'shape-a',
      );
      expect(renderedAnimated.worldBounds, isNotNull);
      expect(renderedAnimated.worldBounds!.center.dx, closeTo(100, 0.0001));
      expect(renderedAnimated.worldBounds!.center.dy, closeTo(50, 0.0001));
    });
  });
}
