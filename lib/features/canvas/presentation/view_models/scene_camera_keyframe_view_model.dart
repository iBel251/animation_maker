import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_keyframe.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera_timeline.dart';
import 'package:animation_maker/features/canvas/domain/services/scene_camera_timeline_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/services/keyframe_clipboard_service.dart';

/// Encapsulates scene camera keyframe CRUD and sampling behavior.
class SceneCameraKeyframeViewModel {
  SceneCameraKeyframeViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required void Function() pushHistory,
    required KeyframeClipboardService clipboardService,
    SceneCameraTimelineService timelineService =
        const SceneCameraTimelineService(),
  }) : _getState = getState,
       _setState = setState,
       _pushHistory = pushHistory,
       _clipboardService = clipboardService,
       _timelineService = timelineService;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final void Function() _pushHistory;
  final KeyframeClipboardService _clipboardService;
  final SceneCameraTimelineService _timelineService;

  bool get hasKeyframeAtCurrentFrame {
    final state = _getState();
    return state.document.sceneCameraTimeline.containsFrame(state.currentFrame);
  }

  List<int> get keyframeFrames {
    return _getState().document.sceneCameraTimeline.frames;
  }

  int? previousKeyframeFrame() {
    final state = _getState();
    return _timelineService.previousKeyframe(
      state.document.sceneCameraTimeline,
      state.currentFrame,
    );
  }

  int? nextKeyframeFrame() {
    final state = _getState();
    return _timelineService.nextKeyframe(
      state.document.sceneCameraTimeline,
      state.currentFrame,
    );
  }

  void addOrUpdateAtCurrentFrame() {
    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return;

    final camera =
        state.sceneCamera ?? SceneCamera.fromDocument(state.document.size);
    final keyframe = SceneCameraKeyframe.fromSceneCamera(
      frame: frame,
      camera: camera,
    );
    final nextTimeline = state.document.sceneCameraTimeline.upsert(keyframe);
    if (nextTimeline == state.document.sceneCameraTimeline) {
      return;
    }

    final nextFrameCount = frame >= state.document.frameCount
        ? frame + 1
        : state.document.frameCount;
    final nextDocument = state.document.copyWith(
      sceneCameraTimeline: nextTimeline,
      frameCount: nextFrameCount,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument, sceneCamera: camera));
    _pushHistory();
  }

  void deleteAtCurrentFrame() {
    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return;

    final nextTimeline = state.document.sceneCameraTimeline.removeAtFrame(
      frame,
    );
    if (nextTimeline == state.document.sceneCameraTimeline) return;

    final nextDocument = state.document.copyWith(
      sceneCameraTimeline: nextTimeline,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument));
    applySceneCameraForFrame(frame);
    _pushHistory();
  }

  /// Whether the clipboard holds a camera keyframe that can be pasted.
  bool get canPasteCameraKeyframe => _clipboardService.hasCameraEntry;

  /// Copies the camera keyframe at the current frame.
  ///
  /// Returns `true` if a keyframe was found and copied, `false` otherwise.
  bool copyKeyframeAtCurrentFrame() {
    final state = _getState();
    final keyframe = state.document.sceneCameraTimeline.atFrame(
      state.currentFrame,
    );
    if (keyframe == null) return false;

    _clipboardService.copyCameraKeyframe(keyframe: keyframe);
    return true;
  }

  /// Pastes the clipboard's camera keyframe at the current frame.
  ///
  /// The pasted keyframe inherits the camera values from the copied keyframe
  /// but is re-targeted to the current frame.
  bool pasteKeyframeAtCurrentFrame() {
    final entry = _clipboardService.entry;
    if (entry == null || !entry.isCamera) return false;
    final copiedKeyframe = entry.cameraKeyframe!;

    final state = _getState();
    final frame = state.currentFrame;
    if (frame < 0) return false;

    final pastedKeyframe = copiedKeyframe.copyWith(frame: frame);
    final nextTimeline = state.document.sceneCameraTimeline.upsert(
      pastedKeyframe,
    );
    if (nextTimeline == state.document.sceneCameraTimeline) return false;

    final nextFrameCount = frame >= state.document.frameCount
        ? frame + 1
        : state.document.frameCount;
    final nextDocument = state.document.copyWith(
      sceneCameraTimeline: nextTimeline,
      frameCount: nextFrameCount,
      updatedAt: DateTime.now(),
    );
    _setState(state.copyWith(document: nextDocument));
    applySceneCameraForFrame(frame);
    _pushHistory();
    return true;
  }

  /// Applies a sampled camera at [frame] to editor state without history push.
  void applySceneCameraForFrame(int frame) {
    final state = _getState();
    if (frame < 0) return;

    final timeline = state.document.sceneCameraTimeline;
    final fallback = _fallbackCameraForSampling(state, timeline);
    if (timeline.isEmpty && fallback == null) return;

    final size = fallback?.size ?? state.document.size;
    final sampled = _timelineService.sampleCamera(
      timeline: timeline,
      frame: frame,
      size: size,
      fallback: fallback,
    );
    if (sampled == null || sampled == state.sceneCamera) return;
    _setState(state.copyWith(sceneCamera: sampled));
  }

  /// Samples camera for [frame] but does not mutate state.
  SceneCamera? sampleCameraForFrame(int frame, {SceneCamera? fallback}) {
    final state = _getState();
    final timeline = state.document.sceneCameraTimeline;
    final resolvedFallback =
        fallback ?? _fallbackCameraForSampling(state, timeline);
    final size = resolvedFallback?.size ?? state.document.size;
    return _timelineService.sampleCamera(
      timeline: timeline,
      frame: frame,
      size: size,
      fallback: resolvedFallback,
    );
  }

  SceneCamera? _fallbackCameraForSampling(
    EditorState state,
    SceneCameraTimeline timeline,
  ) {
    if (state.sceneCamera != null) return state.sceneCamera;
    if (timeline.isEmpty) return null;
    return SceneCamera.fromDocument(state.document.size);
  }
}
