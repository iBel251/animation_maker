import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelinePanel', () {
    late ProviderContainer container;
    late EditorViewModel vm;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          canvasRepositoryProvider.overrideWithValue(_NoopCanvasRepository()),
        ],
      );
      vm = container.read(editorViewModelProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> pumpTimeline(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(),
              bottomNavigationBar: TimelinePanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> flushAutosaveTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    testWidgets('renders timeline controls and camera track', (tester) async {
      vm.updateDocumentMetadata(frameCount: 20);
      await pumpTimeline(tester);

      expect(find.byTooltip('Previous keyframe'), findsOneWidget);
      expect(find.byTooltip('Add Key'), findsOneWidget);
      expect(find.byTooltip('Delete keyframe'), findsOneWidget);
      expect(find.byTooltip('Next keyframe'), findsOneWidget);
      expect(find.byTooltip('Play timeline'), findsOneWidget);
      expect(find.text('24 fps'), findsOneWidget);
      expect(find.text('End 20'), findsOneWidget);
      expect(find.text('Camera'), findsAtLeastNWidgets(1));
      await flushAutosaveTimers(tester);
    });

    testWidgets('supports horizontal scrolling', (tester) async {
      vm.updateDocumentMetadata(frameCount: 120);
      await pumpTimeline(tester);

      final horizontalScrollableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      expect(horizontalScrollableFinder, findsAtLeastNWidgets(1));
      final timelineScrollable = horizontalScrollableFinder.last;
      final stateBefore = tester.state<ScrollableState>(timelineScrollable);
      expect(stateBefore.position.pixels, 0.0);

      await tester.drag(timelineScrollable, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(stateBefore.position.pixels, greaterThan(0.0));
      await flushAutosaveTimers(tester);
    });

    testWidgets('tapping frame updates current frame label', (tester) async {
      vm.updateDocumentMetadata(frameCount: 12);
      await pumpTimeline(tester);

      await tester.tap(find.bySemanticsLabel('Frame 6').first);
      await tester.pumpAndSettle();

      expect(find.text('Frame 6/12'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });

    testWidgets('add keyframe control creates keyframe marker', (tester) async {
      vm.updateDocumentMetadata(frameCount: 12);
      await pumpTimeline(tester);

      await tester.tap(find.byTooltip('Add Key'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Frame 1, keyframed'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });

    testWidgets(
      'primary Add Key writes selected object keyframe instead of camera',
      (tester) async {
        vm.updateDocumentMetadata(frameCount: 12);
        vm.setShapes(<Shape>[
          Shape(
            id: 'shape-1',
            name: 'Box',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(100, 80)],
          ),
        ]);
        vm.selectShape('shape-1');
        await pumpTimeline(tester);

        await tester.tap(find.byTooltip('Add Key'));
        await tester.pumpAndSettle();

        final state = container.read(editorViewModelProvider);
        expect(
          state.document.objectTimeline.containsFrame('shape-1', 0),
          isTrue,
        );
        expect(state.document.sceneCameraTimeline.containsFrame(0), isFalse);
        await flushAutosaveTimers(tester);
      },
    );

    testWidgets(
      'primary Add Key writes camera keyframe in camera tool even with object selected',
      (tester) async {
        vm.updateDocumentMetadata(frameCount: 12);
        vm.setShapes(<Shape>[
          Shape(
            id: 'shape-1',
            name: 'Box',
            kind: ShapeKind.rectangle,
            points: const [Offset(0, 0), Offset(100, 80)],
          ),
        ]);
        vm.selectShape('shape-1');
        vm.setActiveTool(EditorTool.camera);
        await pumpTimeline(tester);

        await tester.tap(find.byTooltip('Add Key'));
        await tester.pumpAndSettle();

        final state = container.read(editorViewModelProvider);
        expect(state.document.sceneCameraTimeline.containsFrame(0), isTrue);
        expect(
          state.document.objectTimeline.containsFrame('shape-1', 0),
          isFalse,
        );
        await flushAutosaveTimers(tester);
      },
    );

    testWidgets('add object keyframe control creates object track marker', (
      tester,
    ) async {
      vm.updateDocumentMetadata(frameCount: 12);
      vm.setShapes(<Shape>[
        Shape(
          id: 'shape-1',
          name: 'Box',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        ),
      ]);
      vm.selectShape('shape-1');
      await pumpTimeline(tester);

      expect(find.byTooltip('Add Key'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Add Key'));
      await tester.tap(find.byTooltip('Add Key'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Frame 1, object keyframed'),
        findsOneWidget,
      );
      expect(find.text('Box'), findsAtLeastNWidgets(1));
      await flushAutosaveTimers(tester);
    });

    testWidgets('selected object timeline row is visible before keying', (
      tester,
    ) async {
      vm.updateDocumentMetadata(frameCount: 12);
      vm.setShapes(<Shape>[
        Shape(
          id: 'shape-1',
          name: 'Circle',
          kind: ShapeKind.ellipse,
          points: const [Offset(0, 0), Offset(80, 80)],
        ),
      ]);
      vm.selectShape('shape-1');
      await pumpTimeline(tester);

      expect(find.text('Circle'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Add Key'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });

    testWidgets('channel key editor toggles channels into keyframe', (
      tester,
    ) async {
      vm.updateDocumentMetadata(frameCount: 12);
      vm.setShapes(<Shape>[
        Shape(
          id: 'shape-1',
          name: 'Box',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(100, 80)],
        ),
      ]);
      vm.selectShape('shape-1');
      await pumpTimeline(tester);

      await tester.tap(find.byTooltip('Edit Key Channels'));
      await tester.pumpAndSettle();
      final strokeColorItem = find.text('Stroke Color');
      await tester.ensureVisible(strokeColorItem);
      await tester.tap(strokeColorItem.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      final keyframe = container
          .read(editorViewModelProvider)
          .document
          .objectTimeline
          .trackForShape('shape-1')
          ?.atFrame(0);
      expect(keyframe, isNotNull);
      expect(keyframe!.effectiveKeyedChannels, const <ObjectKeyChannel>{
        ObjectKeyChannel.strokeColor,
      });

      await tester.tap(find.text('Stroke Color').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        container
            .read(editorViewModelProvider)
            .document
            .objectTimeline
            .containsFrame('shape-1', 0),
        isFalse,
      );
      await flushAutosaveTimers(tester);
    });

    testWidgets('object row tap switches selected object', (tester) async {
      vm.updateDocumentMetadata(frameCount: 12);
      vm.setShapes(<Shape>[
        Shape(
          id: 'shape-1',
          name: 'A',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(80, 80)],
        ),
        Shape(
          id: 'shape-2',
          name: 'B',
          kind: ShapeKind.rectangle,
          points: const [Offset(0, 0), Offset(60, 60)],
        ),
      ]);
      vm.selectShape('shape-2');
      vm.selectShape('shape-1');
      await pumpTimeline(tester);

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      );
      final target = find.byKey(const ValueKey('timeline_object_row_shape-2'));
      await tester.scrollUntilVisible(
        target,
        48.0,
        scrollable: verticalScrollable.first,
      );
      final frameCell = find.descendant(
        of: target,
        matching: find.bySemanticsLabel('Frame 1'),
      );
      await tester.tap(frameCell.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        container.read(editorViewModelProvider).selectedShapeId,
        'shape-2',
      );
      await flushAutosaveTimers(tester);
    });

    testWidgets('next/previous keyframe controls jump frames', (tester) async {
      vm.setActiveTool(EditorTool.camera);
      vm.updateDocumentMetadata(frameCount: 20);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();
      await vm.setCurrentFrame(10);
      vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame();
      await vm.setCurrentFrame(5);
      await pumpTimeline(tester);

      await tester.tap(find.byTooltip('Next keyframe'));
      await tester.pumpAndSettle();
      expect(find.text('Frame 11/20'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous keyframe'));
      await tester.pumpAndSettle();
      expect(find.text('Frame 1/20'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });

    testWidgets('fps can be edited from timeline controls', (tester) async {
      vm.updateDocumentMetadata(frameCount: 20, fps: 24);
      await pumpTimeline(tester);

      await tester.tap(find.text('24 fps'));
      await tester.pumpAndSettle();
      expect(find.text('Set FPS'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '30');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        container.read(editorViewModelProvider).document.fps,
        closeTo(30.0, 0.0001),
      );
      expect(find.text('30 fps'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });

    testWidgets('end frame can be edited from timeline controls', (
      tester,
    ) async {
      vm.updateDocumentMetadata(frameCount: 20, fps: 24);
      await pumpTimeline(tester);

      await tester.tap(find.text('End 20'));
      await tester.pumpAndSettle();
      expect(find.text('Set End Frame'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '150');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(container.read(editorViewModelProvider).document.frameCount, 150);
      expect(find.text('End 150'), findsOneWidget);
      await flushAutosaveTimers(tester);
    });
  });
}

class _NoopCanvasRepository implements CanvasRepository {
  @override
  Future<void> deleteDocument(String id) async {}

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
    return const <CanvasDocumentSummary>[];
  }

  @override
  Future<CanvasDocument?> loadDocument(String id) async {
    return null;
  }

  @override
  Future<void> saveDocument(CanvasDocument document) async {}
}
