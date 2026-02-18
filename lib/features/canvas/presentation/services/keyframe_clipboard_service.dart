import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';

/// Holds copied keyframe data for paste operations.
///
/// Exactly one of [objectKeyframes] or [cameraKeyframe] is non-null at a time,
/// depending on which type of keyframe was copied.
class KeyframeClipboardEntry {
  const KeyframeClipboardEntry._({
    this.objectKeyframes,
    this.rootShapeId,
    this.cameraKeyframe,
  });

  /// Creates an entry holding copied object transform keyframes for a full
  /// parent-child tree. [rootShapeId] is the shape that was selected when the
  /// copy was performed. [keyframes] maps each shape id in the tree to its
  /// keyframe at the copied frame.
  const KeyframeClipboardEntry.objectTree({
    required Map<String, ObjectTransformKeyframe> keyframes,
    required String rootShapeId,
  }) : this._(objectKeyframes: keyframes, rootShapeId: rootShapeId);

  /// Creates an entry holding a copied scene camera keyframe.
  const KeyframeClipboardEntry.camera({
    required SceneCameraKeyframe keyframe,
  }) : this._(cameraKeyframe: keyframe);

  /// All object keyframes in the copied tree, keyed by shape id.
  final Map<String, ObjectTransformKeyframe>? objectKeyframes;

  /// The shape that was selected (root of the tree) when the copy happened.
  final String? rootShapeId;

  final SceneCameraKeyframe? cameraKeyframe;

  bool get isObject => objectKeyframes != null && objectKeyframes!.isNotEmpty;
  bool get isCamera => cameraKeyframe != null;
}

/// In-memory clipboard for keyframe copy/paste operations.
///
/// Pasting re-targets keyframes to the current frame while preserving
/// per-shape transform values.
class KeyframeClipboardService {
  KeyframeClipboardEntry? _entry;

  /// The currently copied keyframe entry, or null if the clipboard is empty.
  KeyframeClipboardEntry? get entry => _entry;

  /// Whether the clipboard has content that can be pasted.
  bool get hasEntry => _entry != null;

  /// Whether the clipboard holds object keyframes.
  bool get hasObjectEntry => _entry?.isObject ?? false;

  /// Whether the clipboard holds a camera keyframe.
  bool get hasCameraEntry => _entry?.isCamera ?? false;

  /// Copies a full object tree's keyframes to the clipboard.
  void copyObjectTreeKeyframes({
    required Map<String, ObjectTransformKeyframe> keyframes,
    required String rootShapeId,
  }) {
    _entry = KeyframeClipboardEntry.objectTree(
      keyframes: Map<String, ObjectTransformKeyframe>.unmodifiable(keyframes),
      rootShapeId: rootShapeId,
    );
  }

  /// Copies a camera keyframe to the clipboard.
  void copyCameraKeyframe({
    required SceneCameraKeyframe keyframe,
  }) {
    _entry = KeyframeClipboardEntry.camera(keyframe: keyframe);
  }

  /// Clears the clipboard.
  void clear() {
    _entry = null;
  }
}
