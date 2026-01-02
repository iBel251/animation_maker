import 'dart:ui';

import 'package:animation_maker/domain/models/shape.dart';

/// Simple in-memory clipboard for shapes.
class EditorClipboard {
  List<Shape> _buffer = const [];

  bool get hasContent => _buffer.isNotEmpty;

  void copyShapes(List<Shape> shapes) {
    _buffer = shapes.map((s) => s.copyWith()).toList(growable: false);
  }

  /// Returns cloned shapes with fresh ids (via [idGenerator]) and optional offset.
  List<Shape> pasteClones(
    String Function() idGenerator, {
    Offset offset = Offset.zero,
  }) {
    if (_buffer.isEmpty) return const [];
    return _buffer
        .map(
          (shape) => _offsetShape(
            shape,
            offset,
            idGenerator(),
          ),
        )
        .toList(growable: false);
  }

  Shape _offsetShape(Shape shape, Offset delta, String newId) {
    final newBounds = shape.bounds?.shift(delta);
    final newPoints = shape.points.isNotEmpty
        ? shape.points.map((p) => p + delta).toList(growable: false)
        : null;
    return shape.copyWith(
      id: newId,
      bounds: newBounds,
      points: newPoints ?? shape.points.toList(),
      translation: shape.translation + delta,
    );
  }
}
