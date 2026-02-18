import 'dart:ui';

/// Type of Bezier control handle that was hit.
enum BezierHandleType {
  /// The incoming control handle (affects curve coming into anchor).
  controlIn,
  /// The outgoing control handle (affects curve going out of anchor).
  controlOut,
}

/// Result of hit testing nodes in node edit mode.
class NodeHitResult {
  const NodeHitResult({
    this.nodeIndex,
    this.segmentIndex,
    this.segmentT,
    this.worldPosition,
    this.contourIndex,
    this.bezierHandleType,
  });

  /// Index of the hit node (null if no node was hit).
  final int? nodeIndex;

  /// Index of the hit path segment (null if no segment was hit).
  /// A segment connects point[i] to point[i+1].
  final int? segmentIndex;

  /// Parameter along the segment where hit occurred (0.0 to 1.0).
  /// Used for adding nodes at specific positions.
  final double? segmentT;

  /// World position of the hit point.
  final Offset? worldPosition;

  /// Index of the contour that was hit (for multi-contour shapes).
  /// Null for single-contour shapes or when the hit test only checked one contour.
  final int? contourIndex;

  /// Type of Bezier control handle that was hit (null if anchor or segment).
  /// When this is set, [nodeIndex] refers to the anchor that owns this handle.
  final BezierHandleType? bezierHandleType;

  /// Whether a node anchor was hit (not a control handle).
  bool get hitNode => nodeIndex != null && bezierHandleType == null;

  /// Whether a Bezier control handle was hit.
  bool get hitBezierHandle => nodeIndex != null && bezierHandleType != null;

  /// Whether a segment was hit (but not a node or handle).
  bool get hitSegment => segmentIndex != null && nodeIndex == null;

  /// Whether anything was hit.
  bool get hasHit => nodeIndex != null || segmentIndex != null;

  @override
  String toString() {
    final contourStr = contourIndex != null ? ', contour: $contourIndex' : '';
    if (hitBezierHandle) {
      return 'NodeHitResult(bezierHandle: ${bezierHandleType!.name} of node $nodeIndex$contourStr)';
    }
    if (hitNode) return 'NodeHitResult(node: $nodeIndex$contourStr)';
    if (hitSegment) return 'NodeHitResult(segment: $segmentIndex, t: $segmentT$contourStr)';
    return 'NodeHitResult(none)';
  }
}
