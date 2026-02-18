import 'dart:math' as math;
import 'dart:ui';

import '../entities/shape.dart';

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

  /// Queries the quadtree for all shapes that contain the given point.
  ///
  /// Returns a list of shapes without duplicates, even if shapes span
  /// multiple quadrants. Shapes are identified by their ID for deduplication.
  List<Shape> queryPoint(Offset point) {
    final results = <String, Shape>{};  // Use Map to deduplicate by shape ID
    _queryPoint(point, results);
    return results.values.toList();
  }

  void _queryPoint(Offset point, Map<String, Shape> results) {
    if (!boundary.contains(point)) return;

    for (final entry in _entries) {
      if (entry.bounds.contains(point)) {
        // Use shape ID as key to prevent duplicates
        results[entry.shape.id] = entry.shape;
      }
    }

    if (_isLeaf) return;
    _nw?._queryPoint(point, results);
    _ne?._queryPoint(point, results);
    _sw?._queryPoint(point, results);
    _se?._queryPoint(point, results);
  }

  /// Queries the quadtree for all shapes that intersect with the given rect.
  ///
  /// This is useful for viewport culling - finding all shapes that might
  /// be visible in a given viewport area.
  /// Returns a list of shapes without duplicates.
  List<Shape> queryRect(Rect rect) {
    final results = <String, Shape>{};
    _queryRect(rect, results);
    return results.values.toList();
  }

  void _queryRect(Rect rect, Map<String, Shape> results) {
    // Early exit if query rect doesn't overlap this quadrant
    if (!boundary.overlaps(rect)) return;

    // Check all entries in this node
    for (final entry in _entries) {
      if (rect.overlaps(entry.bounds)) {
        results[entry.shape.id] = entry.shape;
      }
    }

    // Recurse into children if not a leaf
    if (_isLeaf) return;
    _nw?._queryRect(rect, results);
    _ne?._queryRect(rect, results);
    _sw?._queryRect(rect, results);
    _se?._queryRect(rect, results);
  }

  /// Returns the total number of shapes stored in this quadtree.
  int get count {
    int total = _entries.length;
    if (!_isLeaf) {
      total += (_nw?.count ?? 0) +
          (_ne?.count ?? 0) +
          (_sw?.count ?? 0) +
          (_se?.count ?? 0);
    }
    return total;
  }

  /// Clears all shapes from the quadtree.
  void clear() {
    _entries.clear();
    _nw = null;
    _ne = null;
    _sw = null;
    _se = null;
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
  final base = shape.localBounds;
  if (base == null) return null;
  if (shape.rotation == 0.0 && shape.scaleX == 1.0 && shape.scaleY == 1.0) {
    return base;
  }
  return _transformedAabb(base, shape.rotation, shape.scaleX, shape.scaleY);
}

Rect _transformedAabb(Rect rect, double rotation, double scaleX, double scaleY) {
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  final corners = <Offset>[
    Offset(rect.left, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right, rect.bottom),
    Offset(rect.left, rect.bottom),
  ];
  final cosA = math.cos(rotation);
  final sinA = math.sin(rotation);
  double minX = double.infinity, minY = double.infinity;
  double maxX = -double.infinity, maxY = -double.infinity;
  for (final c in corners) {
    final dx = (c.dx - cx) * scaleX;
    final dy = (c.dy - cy) * scaleY;
    final rx = dx * cosA - dy * sinA + cx;
    final ry = dx * sinA + dy * cosA + cy;
    if (rx < minX) minX = rx;
    if (rx > maxX) maxX = rx;
    if (ry < minY) minY = ry;
    if (ry > maxY) maxY = ry;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

class _Entry {
  _Entry(this.bounds, this.shape);
  final Rect bounds;
  final Shape shape;
}


