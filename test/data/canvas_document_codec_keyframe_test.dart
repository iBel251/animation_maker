import 'dart:convert';
import 'dart:ui';

import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDocumentCodec scene camera keyframes', () {
    test('round-trips scene camera timeline', () {
      final document =
          CanvasDocument.singleLayer(
            id: 'doc-1',
            title: 'Doc',
            size: const Size(800, 600),
            fps: 24,
          ).copyWith(
            sceneCameraTimeline: SceneCameraTimeline(
              keyframes: const [
                SceneCameraKeyframe(
                  frame: 0,
                  position: Offset(0, 0),
                  zoom: 1.0,
                  rotation: 0.0,
                ),
                SceneCameraKeyframe(
                  frame: 12,
                  position: Offset(320, 180),
                  zoom: 2.5,
                  rotation: 0.6,
                ),
              ],
            ),
          );

      final raw = CanvasDocumentCodec.encode(document);
      final decoded = CanvasDocumentCodec.decode(raw);

      expect(decoded.sceneCameraTimeline, document.sceneCameraTimeline);
    });

    test('decodes older json with missing timeline', () {
      final document = CanvasDocument.singleLayer(
        id: 'legacy-doc',
        title: 'Legacy',
        size: const Size(640, 360),
        fps: 12,
      );
      final raw = CanvasDocumentCodec.encode(document);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json.remove('sceneCameraTimeline');

      final decoded = CanvasDocumentCodec.fromJson(json);

      expect(decoded.sceneCameraTimeline.isEmpty, isTrue);
    });
  });
}
