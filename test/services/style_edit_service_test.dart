import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/services/style_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StyleEditService', () {
    const service = StyleEditService();

    test('applies style patch across explicit frames and object keyframes', () {
      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 80)],
      );
      final layer = CanvasLayer(
        id: 'layer-1',
        name: 'Layer 1',
        frames: {
          0: CanvasFrame(index: 0, shapes: [shape]),
          10: CanvasFrame(
            index: 10,
            shapes: [shape.copyWith(translation: const Offset(120, 0))],
          ),
        },
      );
      final timeline = ObjectTimeline(
        tracks: [
          ObjectTimelineTrack(
            shapeId: 'shape-1',
            keyframes: const [
              ObjectTransformKeyframe(
                frame: 0,
                position: Offset(50, 40),
                rotation: 0,
                scaleX: 1,
                scaleY: 1,
                opacity: 1,
              ),
              ObjectTransformKeyframe(
                frame: 10,
                position: Offset(170, 40),
                rotation: 0,
                scaleX: 1,
                scaleY: 1,
                opacity: 1,
              ),
            ],
          ),
        ],
      );
      final document = CanvasDocument(
        id: 'doc-1',
        title: 'Doc',
        size: const Size(800, 600),
        background: const CanvasBackground.transparent(),
        fps: 24,
        frameCount: 20,
        layers: [layer],
        objectTimeline: timeline,
      );

      final result = service.applyPatchToDocument(
        document: document,
        shapeIds: const {'shape-1'},
        patch: const ShapeStylePatch(
          strokeColor: Color(0xFF1E88E5),
          strokeWidth: 9.0,
          isVisible: false,
        ),
      );

      expect(result.changed, isTrue);
      expect(result.changedFrames, isTrue);
      expect(result.changedKeyframes, isTrue);

      final frame0Shape = result.document
          .layerById('layer-1')!
          .frames[0]!
          .shapes
          .firstWhere((item) => item.id == 'shape-1');
      final frame10Shape = result.document
          .layerById('layer-1')!
          .frames[10]!
          .shapes
          .firstWhere((item) => item.id == 'shape-1');
      expect(frame0Shape.strokeColor, const Color(0xFF1E88E5));
      expect(frame10Shape.strokeColor, const Color(0xFF1E88E5));
      expect(frame0Shape.strokeWidth, closeTo(9.0, 0.0001));
      expect(frame10Shape.strokeWidth, closeTo(9.0, 0.0001));
      expect(frame0Shape.isVisible, isFalse);
      expect(frame10Shape.isVisible, isFalse);

      final track = result.document.objectTimeline.trackForShape('shape-1');
      expect(track, isNotNull);
      expect(track!.atFrame(0)!.strokeColor, const Color(0xFF1E88E5));
      expect(track.atFrame(10)!.strokeColor, const Color(0xFF1E88E5));
      expect(track.atFrame(0)!.strokeWidth, closeTo(9.0, 0.0001));
      expect(track.atFrame(10)!.strokeWidth, closeTo(9.0, 0.0001));
      expect(track.atFrame(0)!.isVisible, isFalse);
      expect(track.atFrame(10)!.isVisible, isFalse);
    });

    test('returns unchanged document for noop patch', () {
      final document = CanvasDocument.singleLayer(
        id: 'doc-1',
        title: 'Doc',
        size: const Size(800, 600),
        fps: 24,
      );
      final result = service.applyPatchToDocument(
        document: document,
        shapeIds: const {'shape-1'},
        patch: const ShapeStylePatch(),
      );
      expect(result.changed, isFalse);
      expect(identical(result.document, document), isTrue);
    });
  });
}
