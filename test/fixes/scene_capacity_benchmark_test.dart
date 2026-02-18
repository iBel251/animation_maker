@Tags(<String>['benchmark'])
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document_summary.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/repositories/canvas_repository.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const bool _runSceneStress = bool.fromEnvironment(
  'RUN_SCENE_STRESS_TEST',
  defaultValue: false,
);

void main() {
  test('scene capacity benchmark prints handling limits', () async {
    final shapeCounts = <int>[100, 300, 600, 1000];
    final results = <_ScenePerfResult>[];

    for (final count in shapeCounts) {
      results.add(await _runCase(count));
    }

    final buffer = StringBuffer()
      ..writeln('')
      ..writeln('Scene capacity benchmark (ms/op)')
      ..writeln('Shapes | Move(all) | FrameScrub | Keyframe+Move(one)');
    for (final result in results) {
      buffer.writeln(
        '${result.shapeCount.toString().padLeft(6)} | '
        '${result.moveAllMs.toStringAsFixed(2).padLeft(8)} | '
        '${result.frameScrubMs.toStringAsFixed(2).padLeft(10)} | '
        '${result.keyframeMoveMs.toStringAsFixed(2).padLeft(17)}',
      );
    }

    const frameBudgetMs = 16.67; // 60 FPS budget per operation
    int? firstOverBudget;
    for (final result in results) {
      final over =
          result.moveAllMs > frameBudgetMs ||
          result.frameScrubMs > frameBudgetMs ||
          result.keyframeMoveMs > frameBudgetMs;
      if (over) {
        firstOverBudget = result.shapeCount;
        break;
      }
    }
    if (firstOverBudget == null) {
      buffer.writeln(
        'Estimated comfort limit: > ${shapeCounts.last} shapes on this machine',
      );
    } else {
      buffer.writeln(
        'Estimated comfort limit starts around: $firstOverBudget shapes',
      );
    }

    // Visible in test output when run with --reporter expanded.
    // ignore: avoid_print
    print(buffer.toString());
    expect(results, isNotEmpty);
  }, skip: !_runSceneStress);
}

Future<_ScenePerfResult> _runCase(int shapeCount) async {
  final repo = _PerfCanvasRepository();
  final container = ProviderContainer(
    overrides: [canvasRepositoryProvider.overrideWithValue(repo)],
  );
  final vm = container.read(editorViewModelProvider.notifier);
  try {
    vm.updateDocumentMetadata(frameCount: 180, fps: 24);
    final shapes = _generateShapes(shapeCount);
    vm.setShapes(shapes);

    final shapeIds = shapes.map((shape) => shape.id).toList(growable: false);
    vm.setSelectionMode(SelectionMode.multi);
    vm.setSelection(shapeIds);

    const moveSteps = 24;
    final moveWatch = Stopwatch()..start();
    for (var i = 0; i < moveSteps; i++) {
      vm.moveSelectedBy(const Offset(0.5, 0.25));
    }
    moveWatch.stop();

    const scrubSteps = 48;
    final scrubWatch = Stopwatch()..start();
    for (var i = 0; i < scrubSteps; i++) {
      await vm.setCurrentFrame((i * 3) % 180);
    }
    scrubWatch.stop();

    vm.setSelectionMode(SelectionMode.single);
    vm.selectShape(shapeIds.first);
    const keySteps = 16;
    final keyWatch = Stopwatch()..start();
    for (var i = 0; i < keySteps; i++) {
      await vm.setCurrentFrame(i);
      vm.moveSelectedBy(const Offset(1, 0));
      vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame();
    }
    keyWatch.stop();

    return _ScenePerfResult(
      shapeCount: shapeCount,
      moveAllMs: moveWatch.elapsedMicroseconds / 1000 / moveSteps,
      frameScrubMs: scrubWatch.elapsedMicroseconds / 1000 / scrubSteps,
      keyframeMoveMs: keyWatch.elapsedMicroseconds / 1000 / keySteps,
    );
  } finally {
    container.dispose();
  }
}

List<Shape> _generateShapes(int count) {
  final cols = math.sqrt(count).ceil();
  const cell = 24.0;
  const size = 16.0;
  final shapes = <Shape>[];
  for (var i = 0; i < count; i++) {
    final row = i ~/ cols;
    final col = i % cols;
    final x = col * cell;
    final y = row * cell;
    shapes.add(
      Shape(
        id: 'shape-$i',
        kind: ShapeKind.rectangle,
        bounds: Rect.fromLTWH(x, y, size, size),
      ),
    );
  }
  return shapes;
}

class _ScenePerfResult {
  const _ScenePerfResult({
    required this.shapeCount,
    required this.moveAllMs,
    required this.frameScrubMs,
    required this.keyframeMoveMs,
  });

  final int shapeCount;
  final double moveAllMs;
  final double frameScrubMs;
  final double keyframeMoveMs;
}

class _PerfCanvasRepository implements CanvasRepository {
  final Map<String, CanvasDocument> _documents = <String, CanvasDocument>{};

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
    _documents[document.id] = document;
  }
}
