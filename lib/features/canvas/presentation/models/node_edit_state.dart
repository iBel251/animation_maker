import 'dart:ui';

/// State for node editing mode.
/// Tracks selected nodes, hover state, drag operations, and active contour.
class NodeEditState {
  const NodeEditState({
    this.selectedNodeIndices = const {},
    this.hoveredNodeIndex,
    this.hoveredSegmentIndex,
    this.isDragging = false,
    this.dragStartPositions = const {},
    this.activeContourIndex = 0,
    this.totalContourCount = 1,
    this.useWeightedEdit = false,
    this.weightedInfluenceRadius = 100.0,
    this.cornerIndices = const {},
    this.arcLengths = const [],
  });

  /// Indices of currently selected nodes (within the active contour).
  final Set<int> selectedNodeIndices;

  /// Index of node under pointer (for hover feedback).
  final int? hoveredNodeIndex;

  /// Index of segment under pointer (for path hover feedback).
  final int? hoveredSegmentIndex;

  /// Whether a drag operation is in progress.
  final bool isDragging;

  /// Snapshot of node positions at drag start (for undo).
  final Map<int, Offset> dragStartPositions;

  /// Index of the currently active/editable contour in a multi-contour shape.
  /// For single-contour shapes, this is always 0.
  final int activeContourIndex;

  /// Total number of contours in the shape being edited.
  /// Used to enable/disable contour navigation UI.
  final int totalContourCount;

  /// Whether weighted edit mode is active (hidden nodes + soft drag).
  /// When true, nodes are hidden except the active one, and dragging
  /// affects nearby nodes with distance-based falloff.
  final bool useWeightedEdit;

  /// The influence radius for weighted dragging (in world units).
  /// Nodes beyond this arc-length distance from the active node won't move.
  final double weightedInfluenceRadius;

  /// Indices of detected corner nodes that should be protected during weighted drag.
  /// Corners receive reduced weight unless they are the active node.
  final Set<int> cornerIndices;

  /// Cumulative arc-lengths from the first node to each node.
  /// Used for computing weighted distances along the path.
  final List<double> arcLengths;

  /// Whether any nodes are selected.
  bool get hasSelection => selectedNodeIndices.isNotEmpty;

  /// Number of selected nodes.
  int get selectionCount => selectedNodeIndices.length;

  /// Whether the shape has multiple contours.
  bool get hasMultipleContours => totalContourCount > 1;

  /// Whether we can navigate to the previous contour.
  bool get canGoToPreviousContour => activeContourIndex > 0;

  /// Whether we can navigate to the next contour.
  bool get canGoToNextContour => activeContourIndex < totalContourCount - 1;

  /// The currently active (selected) node index for weighted edit mode.
  /// Returns null if no single node is selected.
  int? get activeNodeIndex =>
      selectedNodeIndices.length == 1 ? selectedNodeIndices.first : null;

  /// Whether we have valid arc-length data for weighted editing.
  bool get hasArcLengths => arcLengths.isNotEmpty;

  /// Total path length (arc-length of full contour).
  double get totalArcLength => arcLengths.isNotEmpty ? arcLengths.last : 0.0;

  NodeEditState copyWith({
    Set<int>? selectedNodeIndices,
    int? hoveredNodeIndex,
    bool clearHoveredNodeIndex = false,
    int? hoveredSegmentIndex,
    bool clearHoveredSegmentIndex = false,
    bool? isDragging,
    Map<int, Offset>? dragStartPositions,
    int? activeContourIndex,
    int? totalContourCount,
    bool? useWeightedEdit,
    double? weightedInfluenceRadius,
    Set<int>? cornerIndices,
    List<double>? arcLengths,
  }) {
    return NodeEditState(
      selectedNodeIndices: selectedNodeIndices ?? this.selectedNodeIndices,
      hoveredNodeIndex:
          clearHoveredNodeIndex ? null : (hoveredNodeIndex ?? this.hoveredNodeIndex),
      hoveredSegmentIndex:
          clearHoveredSegmentIndex ? null : (hoveredSegmentIndex ?? this.hoveredSegmentIndex),
      isDragging: isDragging ?? this.isDragging,
      dragStartPositions: dragStartPositions ?? this.dragStartPositions,
      activeContourIndex: activeContourIndex ?? this.activeContourIndex,
      totalContourCount: totalContourCount ?? this.totalContourCount,
      useWeightedEdit: useWeightedEdit ?? this.useWeightedEdit,
      weightedInfluenceRadius: weightedInfluenceRadius ?? this.weightedInfluenceRadius,
      cornerIndices: cornerIndices ?? this.cornerIndices,
      arcLengths: arcLengths ?? this.arcLengths,
    );
  }

  /// Creates a fresh state (used when entering node edit mode).
  static const NodeEditState initial = NodeEditState();
}
