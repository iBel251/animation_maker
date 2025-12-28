import 'dart:ui';

import '../models/shape.dart';

/// A lightweight QuadTree for spatial queries over shape bounds.
class QuadTree {
  QuadTree({
    required this.boundary,
    this.capacity = 4,
    this.maxDepth = 8,
    this.depth = 0,
  });

  final Rect boundary;
  final int capacity;
  final int maxDepth;
  final int depth;

  final List<_Entry> _entries = [];
  QuadTree? _nw;
  QuadTree? _ne;
  QuadTree? _sw;
  QuadTree? _se;

  bool get _isLeaf => _nw == null;

  void insert(Shape shape) {
    final bounds = _shapeBounds(shape);
    if (bounds == null || !boundary.overlaps(bounds)) return;

    if (_isLeaf && _entries.length < capacity || depth >= maxDepth) {
      _entries.add(_Entry(bounds, shape));
      return;
    }

    _subdivideIfNeeded();
    _insertIntoChildren(_Entry(bounds, shape));
  }

  List<Shape> queryPoint(Offset point) {
    final results = <Shape>[];
    _queryPoint(point, results);
    return results;
  }

  void _queryPoint(Offset point, List<Shape> results) {
    if (!boundary.contains(point)) return;

    for (final entry in _entries) {
      if (entry.bounds.contains(point)) {
        results.add(entry.shape);
      }
    }

    if (_isLeaf) return;
    _nw?._queryPoint(point, results);
    _ne?._queryPoint(point, results);
    _sw?._queryPoint(point, results);
    _se?._queryPoint(point, results);
  }

  void _insertIntoChildren(_Entry entry) {
    _nw?.insert(entry.shape);
    _ne?.insert(entry.shape);
    _sw?.insert(entry.shape);
    _se?.insert(entry.shape);
  }

  void _subdivideIfNeeded() {
    if (!_isLeaf) return;
    final midX = boundary.left + boundary.width / 2;
    final midY = boundary.top + boundary.height / 2;

    _nw = QuadTree(
      boundary: Rect.fromLTRB(boundary.left, boundary.top, midX, midY),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _ne = QuadTree(
      boundary: Rect.fromLTRB(midX, boundary.top, boundary.right, midY),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _sw = QuadTree(
      boundary: Rect.fromLTRB(boundary.left, midY, midX, boundary.bottom),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _se = QuadTree(
      boundary: Rect.fromLTRB(midX, midY, boundary.right, boundary.bottom),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );

    // Re-insert any existing entries into children.
    final existing = List<_Entry>.from(_entries);
    _entries.clear();
    for (final entry in existing) {
      _insertIntoChildren(entry);
    }
  }
}

Rect? _shapeBounds(Shape shape) {
  if (shape.bounds != null) return shape.bounds;
  if (shape.points.isEmpty) return null;
  if (shape.points.length == 1) {
    final p = shape.points.first;
    return Rect.fromLTWH(p.dx, p.dy, 0, 0);
  }
  double minX = shape.points.first.dx;
  double maxX = shape.points.first.dx;
  double minY = shape.points.first.dy;
  double maxY = shape.points.first.dy;

  for (final p in shape.points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

class _Entry {
  _Entry(this.bounds, this.shape);
  final Rect bounds;
  final Shape shape;
}
