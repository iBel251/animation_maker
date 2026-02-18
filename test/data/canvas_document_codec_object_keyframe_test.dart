import 'dart:convert';
import 'dart:ui';

import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDocumentCodec object keyframes', () {
    test('round-trips object timeline', () {
      final document =
          CanvasDocument.singleLayer(
            id: 'doc-1',
            title: 'Doc',
            size: const Size(800, 600),
            fps: 24,
          ).copyWith(
            objectTimeline: ObjectTimeline(
              tracks: [
                ObjectTimelineTrack(
                  shapeId: 'shape-1',
                  keyframes: const [
                    ObjectTransformKeyframe(
                      frame: 0,
                      position: Offset(0, 0),
                      rotation: 0,
                      scaleX: 1,
                      scaleY: 1,
                      opacity: 1,
                    ),
                    ObjectTransformKeyframe(
                      frame: 12,
                      position: Offset(320, 180),
                      rotation: 0.6,
                      scaleX: 1.4,
                      scaleY: 0.8,
                      opacity: 0.5,
                      keyedChannels: <ObjectKeyChannel>{
                        ObjectKeyChannel.position,
                        ObjectKeyChannel.opacity,
                      },
                    ),
                  ],
                ),
              ],
            ),
          );

      final raw = CanvasDocumentCodec.encode(document);
      final decoded = CanvasDocumentCodec.decode(raw);

      expect(decoded.objectTimeline, document.objectTimeline);
      final keyframe = decoded.objectTimeline
          .trackForShape('shape-1')
          ?.atFrame(12);
      expect(keyframe?.effectiveKeyedChannels, const <ObjectKeyChannel>{
        ObjectKeyChannel.position,
        ObjectKeyChannel.opacity,
      });
    });

    test('decodes older json with missing object timeline', () {
      final document = CanvasDocument.singleLayer(
        id: 'legacy-doc',
        title: 'Legacy',
        size: const Size(640, 360),
        fps: 12,
      );
      final raw = CanvasDocumentCodec.encode(document);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json.remove('objectTimeline');

      final decoded = CanvasDocumentCodec.fromJson(json);

      expect(decoded.objectTimeline.isEmpty, isTrue);
    });
  });
}
