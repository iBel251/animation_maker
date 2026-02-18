import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_timeline.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'history_manager.dart';

class DocumentService {
  /// Creates a DocumentService with a large world boundary for the QuadTree.
  ///
  /// The default boundary spans from -50000 to 50000 in both axes,
  /// allowing shapes to exist far outside the artboard for an "infinite canvas" feel.
  DocumentService({
    Rect quadBoundary = const Rect.fromLTWH(-50000, -50000, 100000, 100000),
  }) : _quadBoundary = quadBoundary {
    _quadTree = QuadTree(boundary: _quadBoundary);
  }

  final Rect _quadBoundary;
  final HistoryManager history = HistoryManager();
  late QuadTree _quadTree;

  QuadTree get quadTree => _quadTree;

  void resetHistory({
    required List<Shape> shapes,
    required String? selectedId,
    required List<String> selectedIds,
    required int frameIndex,
    required String activeLayerId,
    required SceneCameraTimeline sceneCameraTimeline,
    required ObjectTimeline objectTimeline,
    required SceneCamera? sceneCamera,
  }) {
    history.reset();
    history.push(
      shapes: shapes,
      selectedId: selectedId,
      selectedIds: selectedIds,
      frameIndex: frameIndex,
      activeLayerId: activeLayerId,
      sceneCameraTimeline: sceneCameraTimeline,
      objectTimeline: objectTimeline,
      sceneCamera: sceneCamera,
    );
  }

  void pushHistory({
    required List<Shape> shapes,
    required String? selectedId,
    required List<String> selectedIds,
    required int frameIndex,
    required String activeLayerId,
    required SceneCameraTimeline sceneCameraTimeline,
    required ObjectTimeline objectTimeline,
    required SceneCamera? sceneCamera,
  }) {
    history.push(
      shapes: shapes,
      selectedId: selectedId,
      selectedIds: selectedIds,
      frameIndex: frameIndex,
      activeLayerId: activeLayerId,
      sceneCameraTimeline: sceneCameraTimeline,
      objectTimeline: objectTimeline,
      sceneCamera: sceneCamera,
    );
  }

  HistorySnapshot? undo() => history.undo();
  HistorySnapshot? redo() => history.redo();

  void rebuildQuadTree(List<Shape> shapes) {
    _quadTree = QuadTree(boundary: _quadBoundary);
    for (final shape in shapes) {
      _quadTree.insert(shape);
    }
  }
}
