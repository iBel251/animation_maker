import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:animation_maker/features/canvas/domain/entities/raster_stroke.dart';

import 'history_manager.dart';

class DocumentService {
  DocumentService({Rect quadBoundary = const Rect.fromLTWH(0, 0, 5000, 5000)})
    : _quadBoundary = quadBoundary {
    _quadTree = QuadTree(boundary: _quadBoundary);
  }

  final Rect _quadBoundary;
  final HistoryManager history = HistoryManager();
  late QuadTree _quadTree;

  QuadTree get quadTree => _quadTree;

  void resetHistory({
    required List<Shape> shapes,
    required List<RasterStroke> strokes,
    required String? selectedId,
    required List<String> selectedIds,
    required int frameIndex,
    required String activeLayerId,
  }) {
    history.reset();
    history.push(
      shapes: shapes,
      strokes: strokes,
      selectedId: selectedId,
      selectedIds: selectedIds,
      frameIndex: frameIndex,
      activeLayerId: activeLayerId,
    );
  }

  void pushHistory({
    required List<Shape> shapes,
    required List<RasterStroke> strokes,
    required String? selectedId,
    required List<String> selectedIds,
    required int frameIndex,
    required String activeLayerId,
  }) {
    history.push(
      shapes: shapes,
      strokes: strokes,
      selectedId: selectedId,
      selectedIds: selectedIds,
      frameIndex: frameIndex,
      activeLayerId: activeLayerId,
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



