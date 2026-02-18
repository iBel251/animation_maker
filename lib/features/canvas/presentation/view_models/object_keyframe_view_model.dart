import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/object_timeline_service.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_hierarchy_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/keyframe_clipboard_service.dart';

/// Encapsulates object keyframe CRUD and transform sampling behavior.
class ObjectKeyframeViewModel {
  ObjectKeyframeViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function() pushHistory,
    required KeyframeClipboardService clipboardService,
    ObjectTimelineService timelineService = const ObjectTimelineService(),
    ShapeHierarchyService hierarchyService = const ShapeHierarchyService(),
  }) : _getState = getState,
       _setState = setState,
       _pushHistory = pushHistory,
       _clipboardService = clipboardService,
       _timelineService = timelineService,
       _hierarchyService = hierarchyService;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function() _pushHistory;
  final KeyframeClipboardService _clipboardService;
  final ObjectTimelineService _timelineService;
  final ShapeHierarchyService _hierarchyService;

  bool get hasSelectedObjectKeyframeAtCurrentFrame {
    final state = _getState();
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return false;
    return state.document.objectTimeline.containsFrame(
      shapeId,
      state.currentFrame,
    );
  }

  List<int> get selectedObjectKeyframeFrames {
    final state = _getState();
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return const <int>[];
    return state.document.objectTimeline.keyframeFrames(shapeId);
  }

  Set<ObjectKeyChannel> get selectedObjectKeyChannelsAtCurrentFrame {
    final state = _getState();
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return const <ObjectKeyChannel>{};
    final keyframe = state.document.objectTimeline
        .trackForShape(shapeId)
        ?.atFrame(state.currentFrame);
    if (keyframe == null) return const <ObjectKeyChannel>{};
    return keyframe.effectiveKeyedChannels;
  }

  int? previousSelectedObjectKeyframeFrame() {
    final state = _getState();
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return null;
    return _timelineService.previousKeyframe(
      timeline: state.document.objectTimeline,
      shapeId: shapeId,
      frame: state.currentFrame,
    );
  }

  int? nextSelectedObjectKeyframeFrame() {
    final state = _getState();
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return null;
    return _timelineService.nextKeyframe(
      timeline: state.document.objectTimeline,
      shapeId: shapeId,
      frame: state.currentFrame,
    );
  }

  void addOrUpdateSelectedObjectAtCurrentFrame() {
    addOrUpdateSelectedObjectChannelsAtCurrentFrame(kAllObjectKeyChannels);
  }

  void addOrUpdateSelectedObjectChannelsAtCurrentFrame(
    Set<ObjectKeyChannel> channels,
  ) {
    setSelectedObjectChannelsAtCurrentFrame(
      channels,
      mergeWithExistingChannels: true,
    );
  }

  void setSelectedObjectChannelsAtCurrentFrame(
    Set<ObjectKeyChannel> channels, {
    bool mergeWithExistingChannels = false,
  }) {
    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return;
    final hasRequestedChannels = channels.isNotEmpty;
    final normalizedChannels = hasRequestedChannels
        ? _normalizeChannels(channels)
        : const <ObjectKeyChannel>{};

    final selectedShape = _selectedShape(state);
    if (selectedShape == null) return;

    final targetShapes = _keyframeTargetShapes(state, selectedShape);
    var nextTimeline = state.document.objectTimeline;
    if (!hasRequestedChannels) {
      for (final shape in targetShapes) {
        nextTimeline = nextTimeline.removeAtFrame(
          shapeId: shape.id,
          frame: frame,
        );
      }
      if (nextTimeline == state.document.objectTimeline) return;
      final nextDocument = state.document.copyWith(
        objectTimeline: nextTimeline,
        updatedAt: DateTime.now(),
      );
      _setState(state.copyWith(document: nextDocument));
      applyObjectKeyframesForFrame(frame);
      _pushHistory();
      return;
    }

    for (final shape in targetShapes) {
      final existing = nextTimeline.trackForShape(shape.id)?.atFrame(frame);
      final keyframe = existing == null
          ? ObjectTransformKeyframe.fromShape(
              frame: frame,
              shape: shape,
              keyedChannels: normalizedChannels,
            )
          : existing.withShapeChannels(
              shape: shape,
              channels: normalizedChannels,
              mergeKeyedChannels: mergeWithExistingChannels,
            );
      nextTimeline = nextTimeline.upsert(shapeId: shape.id, keyframe: keyframe);
    }
    if (nextTimeline == state.document.objectTimeline) return;

    final nextFrameCount = frame >= state.document.frameCount
        ? frame + 1
        : state.document.frameCount;
    final nextDocument = state.document.copyWith(
      objectTimeline: nextTimeline,
      frameCount: nextFrameCount,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument));
    if (!mergeWithExistingChannels) {
      applyObjectKeyframesForFrame(frame);
    }
    _pushHistory();
  }

  void deleteSelectedObjectAtCurrentFrame() {
    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return;

    final selectedShape = _selectedShape(state);
    if (selectedShape == null) return;

    // Delete keyframes for the full tree (parent + all descendants).
    final targetShapes = _keyframeTargetShapes(state, selectedShape);
    var nextTimeline = state.document.objectTimeline;
    for (final shape in targetShapes) {
      nextTimeline = nextTimeline.removeAtFrame(
        shapeId: shape.id,
        frame: frame,
      );
    }
    if (nextTimeline == state.document.objectTimeline) return;

    final nextDocument = state.document.copyWith(
      objectTimeline: nextTimeline,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument));
    applyObjectKeyframesForFrame(frame);
    _pushHistory();
  }

  /// Applies sampled object transforms for [frame] without history push.
  void applyObjectKeyframesForFrame(int frame) {
    final state = _getState();
    if (frame < 0 || state.shapes.isEmpty) return;
    final timeline = state.document.objectTimeline;
    if (timeline.isEmpty) return;

    final nextShapes = _timelineService.applyForFrame(
      timeline: timeline,
      shapes: state.shapes,
      frame: frame,
    );
    if (_sameShapeList(nextShapes, state.shapes)) return;
    _setState(state.copyWith(shapes: nextShapes));
  }

  /// Whether the clipboard holds object keyframes that can be pasted.
  bool get canPasteObjectKeyframe => _clipboardService.hasObjectEntry;

  /// Copies the full tree's keyframes at the current frame for the selected
  /// shape and all its descendants.
  ///
  /// Returns `true` if at least one keyframe was found and copied.
  bool copySelectedObjectKeyframeAtCurrentFrame() {
    final state = _getState();
    final selectedShape = _selectedShape(state);
    if (selectedShape == null) return false;

    final frame = state.currentFrame;
    final targetShapes = _keyframeTargetShapes(state, selectedShape);
    final timeline = state.document.objectTimeline;

    // Collect keyframes for every shape in the tree that has one at this frame.
    final keyframes = <String, ObjectTransformKeyframe>{};
    for (final shape in targetShapes) {
      final track = timeline.trackForShape(shape.id);
      if (track == null) continue;
      final keyframe = track.atFrame(frame);
      if (keyframe != null) {
        keyframes[shape.id] = keyframe;
      }
    }
    if (keyframes.isEmpty) return false;

    _clipboardService.copyObjectTreeKeyframes(
      keyframes: keyframes,
      rootShapeId: selectedShape.id,
    );
    return true;
  }

  /// Pastes the clipboard's object keyframes at the current frame for the
  /// selected shape's full tree.
  ///
  /// Each shape in the current tree that has a matching entry in the clipboard
  /// gets its keyframe re-targeted to the current frame. Shapes without a
  /// clipboard match are skipped (e.g. children added after the copy).
  bool pasteObjectKeyframeAtCurrentFrame() {
    final entry = _clipboardService.entry;
    if (entry == null || !entry.isObject) return false;
    final copiedKeyframes = entry.objectKeyframes!;

    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return false;

    final selectedShape = _selectedShape(state);
    if (selectedShape == null) return false;

    final targetShapes = _keyframeTargetShapes(state, selectedShape);
    var nextTimeline = state.document.objectTimeline;

    for (final shape in targetShapes) {
      final copiedKf = copiedKeyframes[shape.id];
      if (copiedKf == null) continue;
      final pastedKf = copiedKf.copyWith(frame: frame);
      nextTimeline = nextTimeline.upsert(shapeId: shape.id, keyframe: pastedKf);
    }
    if (nextTimeline == state.document.objectTimeline) return false;

    final nextFrameCount = frame >= state.document.frameCount
        ? frame + 1
        : state.document.frameCount;
    final nextDocument = state.document.copyWith(
      objectTimeline: nextTimeline,
      frameCount: nextFrameCount,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument));
    applyObjectKeyframesForFrame(frame);
    _pushHistory();
    return true;
  }

  String? selectedObjectDisplayName() {
    final state = _getState();
    final shape = _selectedShape(state);
    if (shape == null) return null;
    if (shape.name != null && shape.name!.trim().isNotEmpty) {
      return shape.name!.trim();
    }
    return shape.id;
  }

  Shape? _selectedShape(EditorState state) {
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return null;
    for (final shape in state.shapes) {
      if (shape.id == shapeId) return shape;
    }
    return null;
  }

  /// Returns the selected shape, all its spatial-object siblings, and every
  /// descendant of each. This ensures that multi-part spatial objects and their
  /// full child trees are always keyframed together.
  List<Shape> _keyframeTargetShapes(EditorState state, Shape selectedShape) {
    final byId = <String, Shape>{};

    // Collect the root set: the selected shape plus any siblings that share
    // its spatialObjectId (a multi-body spatial object).
    final roots = <Shape>[selectedShape];
    final spatialId = selectedShape.spatialObjectId;
    if (spatialId != null) {
      for (final shape in state.shapes) {
        if (shape.spatialObjectId == spatialId &&
            shape.id != selectedShape.id) {
          roots.add(shape);
        }
      }
    }

    // For every root, collect it and its full descendant tree.
    for (final root in roots) {
      byId[root.id] = root;
      final descendants = _hierarchyService.getDescendants(root, state.shapes);
      for (final descendant in descendants) {
        byId[descendant.id] = descendant;
      }
    }

    return byId.values.toList(growable: false);
  }

  bool _sameShapeList(List<Shape> a, List<Shape> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  Set<ObjectKeyChannel> _normalizeChannels(Set<ObjectKeyChannel> channels) {
    if (channels.isEmpty) return kAllObjectKeyChannels;
    return Set<ObjectKeyChannel>.unmodifiable(channels);
  }
}

class ObjectTimelineTrackViewData {
  const ObjectTimelineTrackViewData({
    required this.shapeId,
    required this.displayName,
    required this.frames,
  });

  final String shapeId;
  final String displayName;
  final List<int> frames;
}
