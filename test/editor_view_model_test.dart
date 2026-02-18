import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:animation_maker/features/canvas/presentation/models/style_edit_scope.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_raster_paint_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitForHistoryQueue() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
}

void main() {
  group('EditorViewModel scene camera keyframes', () {
    late _FakeCanvasRepository repo;
    late ProviderContainer container;
    late EditorViewModel vm;

    setUp(() {
      repo = _FakeCanvasRepository();
      container = ProviderContainer(
        overrides: [canvasRepositoryProvider.overrideWithValue(repo)],
      );
      vm = container.read(editorViewModelProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('add keyframe -> undo -> redo restores timeline state', () async {
      vm.setActiveTool(EditorTool.camera);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();
      expect(
        container
            .read(editorViewModelProvider)
            .document
            .sceneCameraTimeline
            .containsFrame(0),
        isTrue,
      );

      vm.deleteSceneCameraKeyframeAtCurrentFrame();
      expect(
        container
            .read(editorViewModelProvider)
            .document
            .sceneCameraTimeline
            .containsFrame(0),
        isFalse,
      );

      await vm.undo();
      await _waitForHistoryQueue();
      expect(
        container
            .read(editorViewModelProvider)
            .document
            .sceneCameraTimeline
            .containsFrame(0),
        isTrue,
      );

      await vm.redo();
      await _waitForHistoryQueue();
      expect(
        container
            .read(editorViewModelProvider)
            .document
            .sceneCameraTimeline
            .containsFrame(0),
        isFalse,
      );
    });

    test('changing frame applies interpolated scene camera', () async {
      vm.setActiveTool(EditorTool.camera);
      vm.setSceneCameraPosition(const Offset(0, 0));
      vm.setSceneCameraZoom(1.0);
      vm.setSceneCameraRotation(0.0);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();

      await vm.setCurrentFrame(10);
      vm.setSceneCameraPosition(const Offset(100, 50));
      vm.setSceneCameraZoom(2.0);
      vm.setSceneCameraRotation(1.0);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();

      await vm.setCurrentFrame(5);
      final camera = container.read(editorViewModelProvider).sceneCamera;
      expect(camera, isNotNull);
      expect(camera!.position.dx, closeTo(50.0, 0.0001));
      expect(camera.position.dy, closeTo(25.0, 0.0001));
      expect(camera.zoom, closeTo(1.5, 0.0001));
      expect(camera.rotation, closeTo(0.5, 0.0001));
    });

    test('saving document persists keyframe timeline', () async {
      vm.setActiveTool(EditorTool.camera);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();

      await vm.saveDocument(flush: true);

      expect(repo.saveCalls, greaterThan(0));
      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.sceneCameraTimeline.containsFrame(0), isTrue);
    });

    test('play and pause advances frames based on fps', () async {
      vm.updateDocumentMetadata(frameCount: 12, fps: 24);
      expect(container.read(editorViewModelProvider).currentFrame, 0);

      vm.playTimeline();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      vm.pauseTimeline();

      final state = container.read(editorViewModelProvider);
      expect(state.isTimelinePlaying, isFalse);
      expect(state.currentFrame, greaterThan(0));
    });

    test(
      'navigating to frame without explicit drawing keeps prior frame shapes',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(120, 80)],
        );
        vm.setShapes(<Shape>[shape]);
        expect(container.read(editorViewModelProvider).shapes.length, 1);

        await vm.setCurrentFrame(10);
        final frame10State = container.read(editorViewModelProvider);
        expect(frame10State.shapes.length, 1);
        expect(frame10State.shapes.first.id, 'shape-1');
      },
    );

    test(
      'object keyframe add -> undo -> redo restores timeline state',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(120, 80)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');

        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();
        expect(
          container
              .read(editorViewModelProvider)
              .document
              .objectTimeline
              .containsFrame('shape-1', 0),
          isTrue,
        );

        vm.deleteSelectedObjectKeyframeAtCurrentFrame();
        expect(
          container
              .read(editorViewModelProvider)
              .document
              .objectTimeline
              .containsFrame('shape-1', 0),
          isFalse,
        );

        await vm.undo();
        await _waitForHistoryQueue();
        expect(
          container
              .read(editorViewModelProvider)
              .document
              .objectTimeline
              .containsFrame('shape-1', 0),
          isTrue,
        );

        await vm.redo();
        await _waitForHistoryQueue();
        expect(
          container
              .read(editorViewModelProvider)
              .document
              .objectTimeline
              .containsFrame('shape-1', 0),
          isFalse,
        );
      },
    );

    test(
      'selection is preserved across frame changes when shape exists',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(120, 80)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');

        await vm.setCurrentFrame(10);

        final state = container.read(editorViewModelProvider);
        expect(state.selectedShapeId, 'shape-1');
        expect(state.selectedShapeIds, contains('shape-1'));
      },
    );

    test('renaming a shape is global and not frame-keyed', () async {
      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(120, 80)],
      );
      vm.setShapes(<Shape>[shape]);

      await vm.setCurrentFrame(10);
      vm.renameShape('shape-1', 'Hero');

      final frame10Name = container
          .read(editorViewModelProvider)
          .shapes
          .firstWhere((item) => item.id == 'shape-1')
          .name;
      expect(frame10Name, 'Hero');

      await vm.setCurrentFrame(0);
      final frame0Name = container
          .read(editorViewModelProvider)
          .shapes
          .firstWhere((item) => item.id == 'shape-1')
          .name;
      expect(frame0Name, 'Hero');
    });

    test(
      'object keyframes interpolate position on in-between frames',
      () async {
        final baseShape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[baseShape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final movedShape = baseShape.copyWith(
          points: baseShape.points
              .map((point) => point + const Offset(100, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[movedShape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();
        final trackAfterSecondKey = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .trackForShape('shape-1');
        expect(trackAfterSecondKey, isNotNull);
        expect(trackAfterSecondKey!.containsFrame(10), isTrue);
        expect(trackAfterSecondKey.atFrame(10), isNotNull);
        expect(
          trackAfterSecondKey.atFrame(10)!.position.dx,
          closeTo(150, 0.0001),
        );
        expect(
          trackAfterSecondKey.atFrame(10)!.position.dy,
          closeTo(50, 0.0001),
        );

        await vm.setCurrentFrame(5);
        final midpoint = container
            .read(editorViewModelProvider)
            .shapes
            .first
            .worldBounds!
            .center;
        expect(midpoint.dx, closeTo(100, 0.0001));
        expect(midpoint.dy, closeTo(50, 0.0001));
      },
    );

    test(
      'moving unkeyed shape on non-base frame persists across frames',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);

        await vm.setCurrentFrame(10);
        vm.selectShape('shape-1');
        final beforeCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;

        vm.moveSelectedBy(const Offset(80, 0));
        final movedCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(movedCenter.dx, closeTo(beforeCenter.dx + 80, 0.0001));
        expect(movedCenter.dy, closeTo(beforeCenter.dy, 0.0001));

        await vm.setCurrentFrame(0);
        final frame0Center = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(frame0Center.dx, closeTo(beforeCenter.dx + 80, 0.0001));
        expect(frame0Center.dy, closeTo(beforeCenter.dy, 0.0001));

        await vm.setCurrentFrame(10);
        final reloadedCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(reloadedCenter.dx, closeTo(beforeCenter.dx + 80, 0.0001));
        expect(reloadedCenter.dy, closeTo(beforeCenter.dy, 0.0001));

        await vm.setCurrentFrame(20);
        final frame20Center = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(frame20Center.dx, closeTo(beforeCenter.dx + 80, 0.0001));
        expect(frame20Center.dy, closeTo(beforeCenter.dy, 0.0001));
      },
    );

    test(
      'auto-key records unkeyed transform edits on non-base frame',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.setAutoKeyEnabled(true);

        await vm.setCurrentFrame(10);
        vm.selectShape('shape-1');

        final beforeCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        vm.moveSelectedBy(const Offset(80, 0));
        final movedCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(movedCenter.dx, closeTo(beforeCenter.dx + 80, 0.0001));

        final timeline = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline;
        expect(timeline.containsFrame('shape-1', 10), isTrue);
      },
    );

    test(
      'timeline style scope does not persist unkeyed style on non-base frame',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.setStyleEditScope(StyleEditScope.timeline);

        await vm.setCurrentFrame(10);
        vm.selectShape('shape-1');
        vm.updateSelectedStroke(
          strokeColor: const Color(0xFFFF0000),
          addToHistory: false,
        );

        final editedColor = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .strokeColor;
        expect(editedColor, const Color(0xFFFF0000));

        await vm.setCurrentFrame(0);
        await vm.setCurrentFrame(10);
        final reloadedColor = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .strokeColor;
        expect(reloadedColor, shape.strokeColor);
      },
    );

    test(
      'global style scope updates style consistently across frames and style keys',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final at10 = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .copyWith(translation: const Offset(120, 0));
        vm.setShapes(<Shape>[at10]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        vm.setStyleEditScope(StyleEditScope.global);
        await vm.setCurrentFrame(5);
        vm.selectShape('shape-1');
        vm.updateSelectedStroke(
          strokeColor: const Color(0xFF1E88E5),
          strokeWidth: 9.0,
          addToHistory: false,
        );

        final timeline = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .trackForShape('shape-1');
        expect(timeline, isNotNull);
        expect(timeline!.atFrame(0)!.strokeColor, const Color(0xFF1E88E5));
        expect(timeline.atFrame(10)!.strokeColor, const Color(0xFF1E88E5));
        expect(timeline.atFrame(0)!.strokeWidth, closeTo(9.0, 0.0001));
        expect(timeline.atFrame(10)!.strokeWidth, closeTo(9.0, 0.0001));

        await vm.setCurrentFrame(0);
        final frame0Shape = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        expect(frame0Shape.strokeColor, const Color(0xFF1E88E5));
        expect(frame0Shape.strokeWidth, closeTo(9.0, 0.0001));

        await vm.setCurrentFrame(10);
        final frame10Shape = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        expect(frame10Shape.strokeColor, const Color(0xFF1E88E5));
        expect(frame10Shape.strokeWidth, closeTo(9.0, 0.0001));
      },
    );

    test(
      'timeline style edit does not expand unkeyed channels when auto-key is off',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeChannelsAtCurrentFrame(
          const <ObjectKeyChannel>{ObjectKeyChannel.position},
        );

        vm.setStyleEditScope(StyleEditScope.timeline);
        vm.updateSelectedStroke(
          strokeColor: const Color(0xFFFF0000),
          addToHistory: false,
        );

        final keyframe = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .trackForShape('shape-1')
            ?.atFrame(0);
        expect(keyframe, isNotNull);
        expect(keyframe!.keysChannel(ObjectKeyChannel.position), isTrue);
        expect(keyframe.keysChannel(ObjectKeyChannel.strokeColor), isFalse);
        expect(keyframe.keysChannel(ObjectKeyChannel.rotation), isFalse);
      },
    );

    test(
      'stroke-only key does not auto-record fill or position keyframes when auto-key is off',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.setStyleEditScope(StyleEditScope.timeline);

        await vm.setCurrentFrame(10);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeChannelsAtCurrentFrame(
          const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
        );
        final initialKeyframe = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .trackForShape('shape-1')
            ?.atFrame(10);
        expect(initialKeyframe, isNotNull);
        expect(
          initialKeyframe!.effectiveKeyedChannels,
          const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
        );

        vm.updateSelectedStroke(
          strokeColor: const Color(0xFFFF0000),
          addToHistory: false,
        );
        vm.moveSelectedBy(const Offset(80, 0));
        vm.updateSelectedFill(const Color(0xFF00FF00), addToHistory: false);

        final updatedKeyframe = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .trackForShape('shape-1')
            ?.atFrame(10);
        expect(updatedKeyframe, isNotNull);
        expect(
          updatedKeyframe!.effectiveKeyedChannels,
          const <ObjectKeyChannel>{ObjectKeyChannel.strokeColor},
        );
        expect(updatedKeyframe.strokeColor, const Color(0xFFFF0000));
        expect(updatedKeyframe.position, initialKeyframe.position);
        expect(updatedKeyframe.fillColor, initialKeyframe.fillColor);

        await vm.setCurrentFrame(0);
        final frame0Shape = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        expect(frame0Shape.worldBounds, isNotNull);
        expect(frame0Shape.worldBounds!.center.dx, closeTo(130, 0.0001));
        expect(frame0Shape.worldBounds!.center.dy, closeTo(50, 0.0001));

        await vm.setCurrentFrame(10);
        final frame10Shape = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        expect(frame10Shape.strokeColor, const Color(0xFFFF0000));
        expect(frame10Shape.fillColor, shape.fillColor);
        expect(frame10Shape.worldBounds, isNotNull);
        expect(frame10Shape.worldBounds!.center.dx, closeTo(130, 0.0001));
        expect(frame10Shape.worldBounds!.center.dy, closeTo(50, 0.0001));
      },
    );

    test(
      'moving keyed shape without keyframe update does not persist transform',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final shapeAt10 = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        vm.setShapes(<Shape>[
          shapeAt10.copyWith(translation: const Offset(120, 0)),
        ]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(5);
        vm.selectShape('shape-1');
        final beforeCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;

        vm.moveSelectedBy(const Offset(80, 0));
        final movedCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(movedCenter.dx, closeTo(beforeCenter.dx + 80, 0.0001));
        expect(movedCenter.dy, closeTo(beforeCenter.dy, 0.0001));

        await vm.setCurrentFrame(4);
        await vm.setCurrentFrame(5);
        final reloadedCenter = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1')
            .worldBounds!
            .center;
        expect(reloadedCenter.dx, closeTo(beforeCenter.dx, 0.0001));
        expect(reloadedCenter.dy, closeTo(beforeCenter.dy, 0.0001));
      },
    );

    test(
      'keying a linked parent writes keyframes for linked descendants',
      () async {
        final parent = Shape(
          id: 'parent-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        final child = Shape(
          id: 'child-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(200, 0), Offset(250, 50)],
        );

        vm.setShapes(<Shape>[parent, child]);
        vm.selectShape('child-1');
        vm.enterLinkingMode();
        vm.completeLinking('parent-1');

        vm.selectShape('parent-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        final timeline0 = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline;
        expect(timeline0.containsFrame('parent-1', 0), isTrue);
        expect(timeline0.containsFrame('child-1', 0), isTrue);

        await vm.setCurrentFrame(10);
        final frame10Shapes = container.read(editorViewModelProvider).shapes;
        final parentAt10 = frame10Shapes.firstWhere((s) => s.id == 'parent-1');
        final childAt10 = frame10Shapes.firstWhere((s) => s.id == 'child-1');
        vm.setShapes(<Shape>[
          parentAt10.copyWith(translation: const Offset(100, 0)),
          childAt10.copyWith(translation: const Offset(100, 0)),
        ]);
        vm.selectShape('parent-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        final timeline10 = container
            .read(editorViewModelProvider)
            .document
            .objectTimeline;
        expect(timeline10.containsFrame('parent-1', 10), isTrue);
        expect(timeline10.containsFrame('child-1', 10), isTrue);
      },
    );

    test(
      'linked child keeps its own keyed pose after parent auto-keying',
      () async {
        final parent = Shape(
          id: 'parent-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        final child = Shape(
          id: 'child-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(200, 0), Offset(250, 50)],
        );

        vm.setShapes(<Shape>[parent, child]);
        vm.selectShape('child-1');
        vm.enterLinkingMode();
        vm.completeLinking('parent-1');

        vm.selectShape('parent-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final frame10Shapes = container.read(editorViewModelProvider).shapes;
        final parentAt10 = frame10Shapes.firstWhere((s) => s.id == 'parent-1');
        final childAt10 = frame10Shapes.firstWhere((s) => s.id == 'child-1');
        vm.setShapes(<Shape>[
          parentAt10.copyWith(translation: const Offset(100, 0)),
          childAt10,
        ]);
        vm.selectShape('parent-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(5);
        final frame5Shapes = container.read(editorViewModelProvider).shapes;
        final parentAt5 = frame5Shapes.firstWhere((s) => s.id == 'parent-1');
        final childAt5 = frame5Shapes.firstWhere((s) => s.id == 'child-1');
        expect(parentAt5.worldBounds, isNotNull);
        expect(childAt5.worldBounds, isNotNull);
        expect(parentAt5.worldBounds!.center.dx, closeTo(100, 0.0001));
        expect(childAt5.worldBounds!.center.dx, closeTo(225, 0.0001));
      },
    );

    test(
      'object timeline rows keep last 5 selected objects with latest on top',
      () {
        vm.setShapes(<Shape>[
          Shape(
            id: 'shape-1',
            name: 'A',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
          Shape(
            id: 'shape-2',
            name: 'B',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
          Shape(
            id: 'shape-3',
            name: 'C',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
          Shape(
            id: 'shape-4',
            name: 'D',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
          Shape(
            id: 'shape-5',
            name: 'E',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
          Shape(
            id: 'shape-6',
            name: 'F',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(20, 20)],
          ),
        ]);

        for (var i = 1; i <= 6; i++) {
          vm.selectShape('shape-$i');
        }

        final tracks = vm.objectTimelineTrackViewData;
        expect(tracks.length, 5);
        expect(
          tracks.map((track) => track.shapeId).toList(growable: false),
          const ['shape-6', 'shape-5', 'shape-4', 'shape-3', 'shape-2'],
        );
      },
    );

    test(
      'new object stays visible on future explicit frames created earlier',
      () async {
        final objectA = Shape(
          id: 'custom-a',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        vm.setShapes(<Shape>[objectA]);

        await vm.setCurrentFrame(20);
        final movedA = objectA.copyWith(
          points: objectA.points
              .map((point) => point + const Offset(80, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[movedA]);

        await vm.setCurrentFrame(0);
        final objectB = Shape(
          id: 'shape-2',
          kind: ShapeKind.ellipse,
          points: const [Offset(300, 150), Offset(360, 210)],
        );
        vm.setShapes(<Shape>[objectB, objectA]);

        await vm.setCurrentFrame(20);
        final idsAtFrame20 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAtFrame20, contains('custom-a'));
        expect(idsAtFrame20, contains('shape-2'));
      },
    );

    test('duplicate object stays visible on future explicit frames', () async {
      final objectA = Shape(
        id: 'custom-a',
        kind: ShapeKind.rectangle,
        points: const [Offset(0, 0), Offset(100, 80)],
      );
      vm.setShapes(<Shape>[objectA]);
      final layerId = container.read(editorViewModelProvider).activeLayerId;

      await vm.setCurrentFrame(20);
      final movedA = objectA.copyWith(
        points: objectA.points
            .map((point) => point + const Offset(80, 0))
            .toList(growable: false),
      );
      vm.setShapes(<Shape>[movedA]);
      final docAfterFrame20 = container.read(editorViewModelProvider).document;
      expect(
        docAfterFrame20.layerById(layerId)?.frames.containsKey(20),
        isTrue,
      );

      await vm.setCurrentFrame(0);
      vm.duplicateShape('custom-a');
      final docAfterDuplicate = container
          .read(editorViewModelProvider)
          .document;
      expect(
        docAfterDuplicate.layerById(layerId)?.frames[20]?.shapes.length,
        2,
      );

      await vm.setCurrentFrame(20);
      final idsAtFrame20 = container
          .read(editorViewModelProvider)
          .shapes
          .map((shape) => shape.id)
          .toSet();
      expect(idsAtFrame20.length, 2);
    });

    test(
      'new object created on keyed frame is visible on earlier frames too',
      () async {
        final objectA = Shape(
          id: 'shape-a',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        vm.setShapes(<Shape>[objectA]);
        vm.selectShape('shape-a');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final movedA = objectA.copyWith(
          points: objectA.points
              .map((point) => point + const Offset(80, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[movedA]);
        vm.selectShape('shape-a');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        final objectB = Shape(
          id: 'shape-b',
          kind: ShapeKind.ellipse,
          points: const [Offset(220, 120), Offset(280, 180)],
        );
        vm.setShapes(<Shape>[objectB, movedA]);

        await vm.setCurrentFrame(9);
        final idsAt9 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAt9, contains('shape-b'));

        await vm.setCurrentFrame(1);
        final idsAt1 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAt1, contains('shape-b'));
      },
    );

    test(
      'shape-tool created object stays visible on future explicit frames',
      () async {
        final objectA = Shape(
          id: 'custom-a',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        vm.setShapes(<Shape>[objectA]);

        await vm.setCurrentFrame(20);
        final movedA = objectA.copyWith(
          points: objectA.points
              .map((point) => point + const Offset(80, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[movedA]);

        await vm.setCurrentFrame(0);
        vm.setActiveTool(EditorTool.shape);
        vm.setShapeDrawKind(ShapeKind.rectangle);
        vm.startShapeDrawing(const Offset(300, 200));
        vm.updateShapeDrawing(const Offset(380, 280));
        vm.finishShapeDrawing();

        final idsAtFrame0 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAtFrame0.length, 2);
        final newShapeId = idsAtFrame0.firstWhere((id) => id != 'custom-a');
        final newShapeAtFrame0 = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((shape) => shape.id == newShapeId);
        final boundsAtFrame0 = newShapeAtFrame0.bounds;
        expect(boundsAtFrame0, isNotNull);
        expect(boundsAtFrame0!.width, greaterThan(0));
        expect(boundsAtFrame0.height, greaterThan(0));

        await vm.setCurrentFrame(20);
        final shapesAtFrame20 = container.read(editorViewModelProvider).shapes;
        final idsAtFrame20 = shapesAtFrame20.map((shape) => shape.id).toSet();
        expect(idsAtFrame20, contains('custom-a'));
        expect(idsAtFrame20, contains(newShapeId));
        final newShapeAtFrame20 = shapesAtFrame20.firstWhere(
          (shape) => shape.id == newShapeId,
        );
        final boundsAtFrame20 = newShapeAtFrame20.bounds;
        expect(boundsAtFrame20, isNotNull);
        expect(boundsAtFrame20!.width, greaterThan(0));
        expect(boundsAtFrame20.height, greaterThan(0));
      },
    );

    test(
      'loading stale document keeps missing shapes visible on exact frames',
      () async {
        const layerId = 'layer-1';
        const docId = 'stale-doc';
        final shapeA = Shape(
          id: 'shape-a',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        final shapeB = Shape(
          id: 'shape-b',
          kind: ShapeKind.ellipse,
          points: const [Offset(220, 120), Offset(280, 180)],
        );

        final staleDocument =
            CanvasDocument.singleLayer(
              id: docId,
              title: 'Stale',
              size: const Size(1920, 1080),
              fps: 24,
              frameCount: 21,
              shapes: [shapeA, shapeB],
              layerId: layerId,
            ).upsertLayer(
              CanvasLayer(
                id: layerId,
                name: 'Layer 1',
                frames: {
                  0: CanvasFrame(index: 0, shapes: [shapeA, shapeB]),
                  20: CanvasFrame(index: 20, shapes: [shapeA]),
                },
              ),
            );

        await repo.saveDocument(staleDocument);
        await vm.loadDocument(docId);
        await vm.setCurrentFrame(20);

        final idsAtFrame20 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAtFrame20, contains('shape-a'));
        expect(idsAtFrame20, contains('shape-b'));
      },
    );

    test(
      'loading non-explicit frame backfills shapes missing in nearest explicit predecessor',
      () async {
        const layerId = 'layer-1';
        const docId = 'stale-fallback-doc';
        final shapeA = Shape(
          id: 'shape-a',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        final shapeB = Shape(
          id: 'shape-b',
          kind: ShapeKind.ellipse,
          points: const [Offset(220, 120), Offset(280, 180)],
        );

        final staleDocument =
            CanvasDocument.singleLayer(
              id: docId,
              title: 'Stale Fallback',
              size: const Size(1920, 1080),
              fps: 24,
              frameCount: 12,
              shapes: [shapeA, shapeB],
              layerId: layerId,
            ).upsertLayer(
              CanvasLayer(
                id: layerId,
                name: 'Layer 1',
                frames: {
                  0: CanvasFrame(index: 0, shapes: [shapeA, shapeB]),
                  6: CanvasFrame(index: 6, shapes: [shapeA]),
                  10: CanvasFrame(index: 10, shapes: [shapeA]),
                },
              ),
            );

        await repo.saveDocument(staleDocument);
        await vm.loadDocument(docId);
        await vm.setCurrentFrame(9);

        final idsAtFrame9 = container
            .read(editorViewModelProvider)
            .shapes
            .map((shape) => shape.id)
            .toSet();
        expect(idsAtFrame9, contains('shape-a'));
        expect(idsAtFrame9, contains('shape-b'));
      },
    );

    test(
      'deleting shape removes it from all frames and object timeline track',
      () async {
        final baseShape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 100)],
        );
        vm.setShapes(<Shape>[baseShape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final movedShape = baseShape.copyWith(
          points: baseShape.points
              .map((point) => point + const Offset(100, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[movedShape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        expect(
          container
              .read(editorViewModelProvider)
              .document
              .objectTimeline
              .trackForShape('shape-1'),
          isNotNull,
        );

        vm.deleteShape('shape-1');

        final afterDelete = container.read(editorViewModelProvider);
        expect(
          afterDelete.document.objectTimeline.trackForShape('shape-1'),
          isNull,
        );
        expect(
          afterDelete.shapes.where((shape) => shape.id == 'shape-1'),
          isEmpty,
        );

        await vm.setCurrentFrame(0);
        expect(
          container
              .read(editorViewModelProvider)
              .shapes
              .where((shape) => shape.id == 'shape-1'),
          isEmpty,
        );

        await vm.setCurrentFrame(10);
        expect(
          container
              .read(editorViewModelProvider)
              .shapes
              .where((shape) => shape.id == 'shape-1'),
          isEmpty,
        );
      },
    );

    test(
      'deleteSelectedIds does not allow deleted shape to reappear on explicit frames',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(120, 80)],
        );
        vm.setShapes(<Shape>[shape]);

        await vm.setCurrentFrame(12);
        final moved = shape.copyWith(
          points: shape.points
              .map((point) => point + const Offset(60, 0))
              .toList(growable: false),
        );
        vm.setShapes(<Shape>[moved]);

        await vm.setCurrentFrame(6);
        vm.selectShape('shape-1');
        vm.deleteSelectedIds();

        expect(
          container
              .read(editorViewModelProvider)
              .shapes
              .where((item) => item.id == 'shape-1'),
          isEmpty,
        );

        await vm.setCurrentFrame(0);
        expect(
          container
              .read(editorViewModelProvider)
              .shapes
              .where((item) => item.id == 'shape-1'),
          isEmpty,
        );

        await vm.setCurrentFrame(12);
        expect(
          container
              .read(editorViewModelProvider)
              .shapes
              .where((item) => item.id == 'shape-1'),
          isEmpty,
        );
      },
    );

    test(
      'new unkeyed shape stays visible across all frames when another shape is keyed',
      () async {
        final keyedShape = Shape(
          id: 'keyed-1',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        );
        vm.setShapes(<Shape>[keyedShape]);
        vm.selectShape('keyed-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final keyedAt10 = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((shape) => shape.id == 'keyed-1')
            .copyWith(translation: const Offset(120, 0));
        vm.setShapes(<Shape>[keyedAt10]);
        vm.selectShape('keyed-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(0);
        final unkeyedShape = Shape(
          id: 'plain-1',
          kind: ShapeKind.ellipse,
          points: const [Offset(220, 120), Offset(280, 180)],
        );
        vm.setShapes(<Shape>[unkeyedShape, keyedShape]);

        for (var frame = 0; frame <= 14; frame++) {
          await vm.setCurrentFrame(frame);
          final ids = container
              .read(editorViewModelProvider)
              .shapes
              .map((shape) => shape.id)
              .toSet();
          expect(
            ids,
            contains('plain-1'),
            reason: 'plain-1 should remain visible at frame $frame',
          );
        }
      },
    );

    test('setShapeRasterPaintPath stores raster path metadata on shape', () {
      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(20, 30, 120, 80),
      );
      vm.setShapes(<Shape>[shape]);

      final updated = vm.setShapeRasterPaintPath(
        'shape-1',
        'images/shape_paint_100.png',
        addToHistory: false,
      );
      expect(updated, isTrue);

      final storedShape = container
          .read(editorViewModelProvider)
          .shapes
          .firstWhere((item) => item.id == 'shape-1');
      expect(
        storedShape.metadata?[kShapeRasterPaintPathKey],
        'images/shape_paint_100.png',
      );
    });

    test('setShapeRasterPaintPath clears raster path metadata when null', () {
      final shape = Shape(
        id: 'shape-1',
        kind: ShapeKind.rectangle,
        bounds: const Rect.fromLTWH(20, 30, 120, 80),
        metadata: const <String, dynamic>{
          kShapeRasterPaintPathKey: 'images/shape_paint_100.png',
          'custom': 'keep',
        },
      );
      vm.setShapes(<Shape>[shape]);

      final updated = vm.setShapeRasterPaintPath(
        'shape-1',
        null,
        addToHistory: false,
      );
      expect(updated, isTrue);

      final storedShape = container
          .read(editorViewModelProvider)
          .shapes
          .firstWhere((item) => item.id == 'shape-1');
      expect(storedShape.metadata?[kShapeRasterPaintPathKey], isNull);
      expect(storedShape.metadata?['custom'], 'keep');
    });

    test(
      'setShapeRasterPaintPath propagates to explicit future frames with keyframes',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 120, 80),
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(10);
        final movedAt10 = shape.copyWith(translation: const Offset(80, 0));
        vm.setShapes(<Shape>[movedAt10]);
        vm.selectShape('shape-1');
        vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();

        await vm.setCurrentFrame(0);
        final updated = vm.setShapeRasterPaintPath(
          'shape-1',
          'images/shape_paint_200.png',
          addToHistory: false,
        );
        expect(updated, isTrue);

        await vm.setCurrentFrame(10);
        final frame10Shape = container
            .read(editorViewModelProvider)
            .shapes
            .firstWhere((item) => item.id == 'shape-1');
        expect(
          frame10Shape.metadata?[kShapeRasterPaintPathKey],
          'images/shape_paint_200.png',
        );
      },
    );

    test(
      'loading another document clears stale selection and transient modes',
      () async {
        final shape = Shape(
          id: 'shape-1',
          kind: ShapeKind.rectangle,
          bounds: const Rect.fromLTWH(0, 0, 100, 80),
        );
        vm.setShapes(<Shape>[shape]);
        vm.selectShape('shape-1');
        vm.enterLinkingMode();
        vm.setActiveTool(EditorTool.nodeEdit);

        final otherDoc = CanvasDocument.singleLayer(
          id: 'document-2',
          title: 'Other',
          size: const Size(1280, 720),
          fps: 24,
          frameCount: 24,
        );
        await repo.saveDocument(otherDoc);
        await vm.loadDocument(otherDoc.id);

        final state = container.read(editorViewModelProvider);
        expect(state.selectedShapeId, isNull);
        expect(state.selectedShapeIds, isEmpty);
        expect(state.isLinkingMode, isFalse);
        expect(state.linkingSourceShapeId, isNull);
        expect(state.activeTool, isNot(EditorTool.nodeEdit));
      },
    );

    test('loading document with empty layers does not crash', () async {
      final malformed = CanvasDocument(
        id: 'document-empty-layers',
        title: 'Malformed',
        size: const Size(800, 600),
        background: const CanvasBackground.transparent(),
        fps: 24,
        frameCount: 1,
        layers: const <CanvasLayer>[],
      );
      await repo.saveDocument(malformed);
      await vm.loadDocument(malformed.id);

      final state = container.read(editorViewModelProvider);
      expect(state.document.layers, isNotEmpty);
      expect(state.activeLayerId, isNotEmpty);
    });
  });
}

class _FakeCanvasRepository implements CanvasRepository {
  final Map<String, CanvasDocument> _documents = <String, CanvasDocument>{};
  int saveCalls = 0;
  CanvasDocument? lastSaved;

  @override
  Future<void> deleteDocument(String id) async {
    _documents.remove(id);
  }

  @override
  Future<String> exportDocument(CanvasDocument document) async {
    return '';
  }

  @override
  Future<CanvasDocument> importDocument(String raw) async {
    throw UnimplementedError();
  }

  @override
  Future<List<CanvasDocumentSummary>> listDocuments() async {
    return _documents.values
        .map(
          (doc) => CanvasDocumentSummary(
            id: doc.id,
            title: doc.title,
            updatedAt: doc.updatedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CanvasDocument?> loadDocument(String id) async {
    return _documents[id];
  }

  @override
  Future<void> saveDocument(CanvasDocument document) async {
    saveCalls += 1;
    lastSaved = document;
    _documents[document.id] = document;
  }
}
