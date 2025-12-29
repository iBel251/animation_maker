import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';
import 'package:animation_maker/presentation/painting/raster_stroke.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class HistorySnapshot {
  const HistorySnapshot({
    required this.shapes,
    required this.rasterStrokes,
    required this.selectedShapeId,
  });

  final List<Shape> shapes;
  final List<RasterStroke> rasterStrokes;
  final String? selectedShapeId;
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
    required List<RasterStroke> strokes,
    required String? selectedId,
  }) {
    // Truncate redo part
    if (_index + 1 < _stack.length) {
      _stack.removeRange(_index + 1, _stack.length);
    }

    _stack.add(
      HistorySnapshot(
        shapes: _cloneShapes(shapes),
        rasterStrokes: _cloneStrokes(strokes),
        selectedShapeId: selectedId,
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

  List<RasterStroke> _cloneStrokes(List<RasterStroke> strokes) =>
      strokes
          .map(
            (r) => RasterStroke(
              points: r.points
                  .map(
                    (p) => PointVector(
                      p.x,
                      p.y,
                      p.pressure,
                    ),
                  )
                  .toList(growable: false),
              color: r.color,
              strokeWidth: r.strokeWidth,
              opacity: r.opacity,
              thinning: r.thinning,
              smoothing: r.smoothing,
              streamline: r.streamline,
              simulatePressure: r.simulatePressure,
            ),
          )
          .toList(growable: false);
}
