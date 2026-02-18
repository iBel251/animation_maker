import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/services/fill_utils.dart';

/// Normalizes pressure for raster modal input.
/// Stylus uses device min/max; other input kinds are treated as full pressure.
double normalizeRasterPressure({
  required PointerDeviceKind kind,
  required double pressure,
  required double pressureMin,
  required double pressureMax,
}) {
  if (kind != PointerDeviceKind.stylus) return 1.0;
  if (pressureMax <= pressureMin) return 1.0;
  final normalized = (pressure - pressureMin) / (pressureMax - pressureMin);
  return normalized.clamp(0.0, 1.0);
}

/// Returns whether "clip inside strokes" can be applied for [shape].
bool canClipInsideFill(Shape shape) {
  switch (shape.kind) {
    case ShapeKind.rectangle:
    case ShapeKind.ellipse:
    case ShapeKind.polygon:
      return true;
    case ShapeKind.pointPath:
      return shape.isClosed && shape.points.length >= 3;
    case ShapeKind.freehand:
      return FillUtils.isFreehandClosed(shape) && shape.points.length >= 3;
    case ShapeKind.line:
    case ShapeKind.image:
      return false;
  }
}

/// Local linear history utility used by the raster paint modal.
///
/// Supports undo/redo with branch truncation on push after undo.
class RasterHistory<T> {
  final List<T> _operations = <T>[];
  int _cursor = 0;

  int get cursor => _cursor;
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _operations.length;
  bool get isEmpty => _operations.isEmpty;

  List<T> get operations => List<T>.unmodifiable(_operations);

  List<T> get appliedOperations =>
      List<T>.unmodifiable(_operations.take(_cursor));

  void push(T operation) {
    if (_cursor < _operations.length) {
      _operations.removeRange(_cursor, _operations.length);
    }
    _operations.add(operation);
    _cursor = _operations.length;
  }

  void undo() {
    if (!canUndo) return;
    _cursor -= 1;
  }

  void redo() {
    if (!canRedo) return;
    _cursor += 1;
  }
}
