import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';

class HistorySnapshot {
  const HistorySnapshot({
    required this.shapes,
    required this.selectedShapeId,
    required this.selectedShapeIds,
    required this.frameIndex,
    required this.activeLayerId,
    required this.sceneCameraTimeline,
    required this.objectTimeline,
    required this.sceneCamera,
  });

  final List<Shape> shapes;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final int frameIndex;
  final String activeLayerId;
  final SceneCameraTimeline sceneCameraTimeline;
  final ObjectTimeline objectTimeline;
  final SceneCamera? sceneCamera;

  ResolvedSelection resolveSelection({
    required SelectionMode mode,
    required Set<String> availableIds,
  }) {
    var resolvedId =
        selectedShapeId != null && availableIds.contains(selectedShapeId)
        ? selectedShapeId
        : null;
    var resolvedIds = selectedShapeIds
        .where(availableIds.contains)
        .toList(growable: false);

    if (mode == SelectionMode.single) {
      if (resolvedId == null && resolvedIds.isNotEmpty) {
        resolvedId = resolvedIds.first;
      }
      resolvedIds = resolvedId != null
          ? List<String>.unmodifiable([resolvedId])
          : const <String>[];
    } else if (resolvedId != null && !resolvedIds.contains(resolvedId)) {
      resolvedIds = List<String>.unmodifiable([resolvedId, ...resolvedIds]);
    } else {
      resolvedIds = List<String>.unmodifiable(resolvedIds);
    }

    return ResolvedSelection(
      selectedShapeId: resolvedId,
      selectedShapeIds: resolvedIds,
    );
  }
}

class ResolvedSelection {
  const ResolvedSelection({
    required this.selectedShapeId,
    required this.selectedShapeIds,
  });

  final String? selectedShapeId;
  final List<String> selectedShapeIds;
}

class HistoryManager {
  HistoryManager({this.maxLength = 100});

  final int maxLength;
  final List<HistorySnapshot> _stack = [];
  int _index = -1;

  bool get canUndo => _index > 0;
  bool get canRedo => _index + 1 < _stack.length;

  void reset() {
    _stack.clear();
    _index = -1;
  }

  void push({
    required List<Shape> shapes,
    required String? selectedId,
    required List<String> selectedIds,
    required int frameIndex,
    required String activeLayerId,
    required SceneCameraTimeline sceneCameraTimeline,
    required ObjectTimeline objectTimeline,
    required SceneCamera? sceneCamera,
  }) {
    // Truncate redo part
    if (_index + 1 < _stack.length) {
      _stack.removeRange(_index + 1, _stack.length);
    }

    _stack.add(
      HistorySnapshot(
        shapes: _cloneShapes(shapes),
        selectedShapeId: selectedId,
        selectedShapeIds: List<String>.unmodifiable(selectedIds),
        frameIndex: frameIndex,
        activeLayerId: activeLayerId,
        sceneCameraTimeline: sceneCameraTimeline,
        objectTimeline: objectTimeline,
        sceneCamera: sceneCamera?.copyWith(),
      ),
    );
    _index = _stack.length - 1;

    // Bound size
    if (_stack.length > maxLength) {
      final drop = _stack.length - maxLength;
      _stack.removeRange(0, drop);
      _index = _stack.length - 1;
    }
  }

  HistorySnapshot? undo() {
    if (!canUndo) return null;
    _index -= 1;
    return _stack[_index];
  }

  HistorySnapshot? redo() {
    if (!canRedo) return null;
    _index += 1;
    return _stack[_index];
  }

  List<Shape> _cloneShapes(List<Shape> shapes) =>
      shapes.map((s) => s.copyWith()).toList(growable: false);
}
