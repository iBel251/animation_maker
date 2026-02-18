import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline_track.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/object_timeline_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectTimelineService', () {
    const service = ObjectTimelineService();

    final shape = Shape(
      id: 'shape-1',
      kind: ShapeKind.rectangle,
      points: const [Offset(0, 0), Offset(100, 80)],
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
              position: Offset(150, 90),
              rotation: 1,
              scaleX: 2,
              scaleY: 3,
              opacity: 0.5,
            ),
          ],
        ),
      ],
    );

    test('samples exact keyframe values', () {
      final sampled = service.sampleShape(
        timeline: timeline,
        shape: shape,
        frame: 10,
      );

      expect(sampled.worldBounds, isNotNull);
      expect(sampled.worldBounds!.center.dx, closeTo(150, 0.0001));
      expect(sampled.worldBounds!.center.dy, closeTo(90, 0.0001));
      expect(sampled.rotation, 1);
      expect(sampled.scaleX, 2);
      expect(sampled.scaleY, 3);
      expect(sampled.opacity, 0.5);
    });

    test('samples linear interpolation between keys', () {
      final sampled = service.sampleShape(
        timeline: timeline,
        shape: shape,
        frame: 5,
      );

      expect(sampled.worldBounds, isNotNull);
      expect(sampled.worldBounds!.center.dx, closeTo(100, 0.0001));
      expect(sampled.worldBounds!.center.dy, closeTo(65, 0.0001));
      expect(sampled.rotation, closeTo(0.5, 0.0001));
      expect(sampled.scaleX, closeTo(1.5, 0.0001));
      expect(sampled.scaleY, closeTo(2.0, 0.0001));
      expect(sampled.opacity, closeTo(0.75, 0.0001));
    });

    test('keeps base shape before first keyframe', () {
      final before = service.sampleShape(
        timeline: timeline,
        shape: shape,
        frame: -5,
      );
      // Before the first keyframe the shape stays at its base (rest)
      // position rather than snapping to a future keyframe.
      expect(identical(before, shape), isTrue);
    });

    test('holds last keyframe value after keyed range', () {
      final after = service.sampleShape(
        timeline: timeline,
        shape: shape,
        frame: 20,
      );

      expect(after.worldBounds, isNotNull);
      expect(after.worldBounds!.center.dx, closeTo(150, 0.0001));
      expect(after.worldBounds!.center.dy, closeTo(90, 0.0001));
    });

    test('finds previous and next keyframes per shape', () {
      expect(
        service.previousKeyframe(
          timeline: timeline,
          shapeId: 'shape-1',
          frame: 5,
        ),
        0,
      );
      expect(
        service.nextKeyframe(timeline: timeline, shapeId: 'shape-1', frame: 5),
        10,
      );
      expect(
        service.previousKeyframe(
          timeline: timeline,
          shapeId: 'shape-1',
          frame: 0,
        ),
        isNull,
      );
      expect(
        service.nextKeyframe(timeline: timeline, shapeId: 'shape-1', frame: 10),
        isNull,
      );
    });

    test('does not apply one object keyframes to other objects', () {
      final shapeA = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 80)],
      );
      final shapeB = Shape(
        id: 'shape-2',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(50, 40)],
      ).copyWith(translation: const Offset(300, 200));

      final applied = service.applyForFrame(
        timeline: timeline,
        shapes: [shapeA, shapeB],
        frame: 5,
      );

      expect(applied[0].worldBounds, isNotNull);
      expect(applied[0].worldBounds!.center.dx, closeTo(100, 0.0001));
      expect(applied[0].worldBounds!.center.dy, closeTo(65, 0.0001));
      expect(applied[1].translation, const Offset(300, 200));
      expect(applied[1].rotation, shapeB.rotation);
      expect(applied[1].scaleX, shapeB.scaleX);
      expect(applied[1].scaleY, shapeB.scaleY);
      expect(applied[1].opacity, shapeB.opacity);
    });

    test('linked child without its own track stays unchanged', () {
      final parent = Shape(
        id: 'parent-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 100)],
      );
      final child = Shape(
        id: 'child-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(200, 0), Offset(250, 50)],
        parentId: 'parent-1',
      );

      final parentTimeline = ObjectTimeline(
        tracks: [
          ObjectTimelineTrack(
            shapeId: 'parent-1',
            keyframes: const [
              ObjectTransformKeyframe(
                frame: 0,
                position: Offset(50, 50),
                rotation: 0,
                scaleX: 1,
                scaleY: 1,
                opacity: 1,
              ),
              ObjectTransformKeyframe(
                frame: 10,
                position: Offset(150, 50),
                rotation: 0,
                scaleX: 1,
                scaleY: 1,
                opacity: 1,
              ),
            ],
          ),
        ],
      );

      final applied = service.applyForFrame(
        timeline: parentTimeline,
        shapes: [parent, child],
        frame: 5,
      );

      expect(applied[0].worldBounds, isNotNull);
      expect(applied[1].worldBounds, isNotNull);
      expect(applied[0].worldBounds!.center.dx, closeTo(100, 0.0001));
      expect(applied[0].worldBounds!.center.dy, closeTo(50, 0.0001));
      expect(applied[1].worldBounds!.center.dx, closeTo(225, 0.0001));
      expect(applied[1].worldBounds!.center.dy, closeTo(25, 0.0001));
    });

    test(
      'linked child with its own keyframes keeps its own keyed transform',
      () {
        final parent = Shape(
          id: 'parent-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        final child = Shape(
          id: 'child-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(200, 0), Offset(250, 50)],
          parentId: 'parent-1',
        );

        final timeline = ObjectTimeline(
          tracks: [
            ObjectTimelineTrack(
              shapeId: 'parent-1',
              keyframes: const [
                ObjectTransformKeyframe(
                  frame: 0,
                  position: Offset(50, 50),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                ),
                ObjectTransformKeyframe(
                  frame: 10,
                  position: Offset(150, 50),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                ),
              ],
            ),
            ObjectTimelineTrack(
              shapeId: 'child-1',
              keyframes: const [
                ObjectTransformKeyframe(
                  frame: 0,
                  position: Offset(225, 25),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                ),
                ObjectTransformKeyframe(
                  frame: 10,
                  position: Offset(325, 25),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                ),
              ],
            ),
          ],
        );

        final applied = service.applyForFrame(
          timeline: timeline,
          shapes: [parent, child],
          frame: 5,
        );

        expect(applied[1].worldBounds, isNotNull);
        expect(applied[1].worldBounds!.center.dx, closeTo(275, 0.0001));
        expect(applied[1].worldBounds!.center.dy, closeTo(25, 0.0001));
      },
    );

    test(
      'samples only keyed channels and keeps other channels at base values',
      () {
        final styledShape = shape.copyWith(
          strokeColor: const Color(0xFF000000),
          strokeWidth: 3.0,
        );
        final sparseTimeline = ObjectTimeline(
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
                  keyedChannels: <ObjectKeyChannel>{ObjectKeyChannel.position},
                ),
                ObjectTransformKeyframe(
                  frame: 10,
                  position: Offset(150, 90),
                  rotation: 1,
                  scaleX: 2,
                  scaleY: 2,
                  opacity: 0.3,
                  strokeColor: Color(0xFFFF0000),
                  keyedChannels: <ObjectKeyChannel>{
                    ObjectKeyChannel.position,
                    ObjectKeyChannel.strokeColor,
                  },
                ),
              ],
            ),
          ],
        );

        final sampled = service.sampleShape(
          timeline: sparseTimeline,
          shape: styledShape,
          frame: 5,
        );

        expect(sampled.worldBounds, isNotNull);
        expect(sampled.worldBounds!.center.dx, closeTo(100, 0.0001));
        expect(sampled.worldBounds!.center.dy, closeTo(65, 0.0001));
        expect(sampled.rotation, styledShape.rotation);
        expect(sampled.scaleX, styledShape.scaleX);
        expect(sampled.scaleY, styledShape.scaleY);
        expect(sampled.opacity, styledShape.opacity);
        expect(sampled.strokeColor, styledShape.strokeColor);
        expect(sampled.strokeWidth, styledShape.strokeWidth);
      },
    );

    test(
      'holds style channel only after first keyed value for that channel',
      () {
        final sparseTimeline = ObjectTimeline(
          tracks: [
            ObjectTimelineTrack(
              shapeId: 'shape-1',
              keyframes: const [
                ObjectTransformKeyframe(
                  frame: 10,
                  position: Offset(150, 90),
                  rotation: 0,
                  scaleX: 1,
                  scaleY: 1,
                  opacity: 1,
                  strokeColor: Color(0xFFFF0000),
                  keyedChannels: <ObjectKeyChannel>{
                    ObjectKeyChannel.strokeColor,
                  },
                ),
              ],
            ),
          ],
        );

        final before = service.sampleShape(
          timeline: sparseTimeline,
          shape: shape,
          frame: 5,
        );
        final after = service.sampleShape(
          timeline: sparseTimeline,
          shape: shape,
          frame: 12,
        );

        expect(before.strokeColor, shape.strokeColor);
        expect(after.strokeColor, const Color(0xFFFF0000));
      },
    );
  });
}
