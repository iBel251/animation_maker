import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/domain/services/quadtree.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';

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
  }) {
    history.reset();
    history.push(shapes: shapes, strokes: strokes, selectedId: selectedId);
  }

  void pushHistory({
    required List<Shape> shapes,
    required List<RasterStroke> strokes,
    required String? selectedId,
  }) {
    history.push(shapes: shapes, strokes: strokes, selectedId: selectedId);
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
