import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';

/// View model for scene camera manipulation.
///
/// Manages the scene camera state (move, zoom, rotate, resize) independently
/// from the workspace camera. The scene camera defines what the final
/// animation output frame shows.
class SceneCameraViewModel {
  SceneCameraViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
  })  : _getState = getState,
        _setState = setState;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;

  /// Sets or clears the scene camera.
  void setSceneCamera(SceneCamera? camera) {
    _setState(_getState().copyWith(
      sceneCamera: camera,
      clearSceneCamera: camera == null,
    ));
  }

  /// Translates the scene camera position by [delta] in world coordinates.
  void moveSceneCamera(Offset delta) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null || delta == Offset.zero) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(position: cam.position + delta),
    ));
  }

  /// Multiplies the scene camera zoom by [factor]. Clamped to [0.1, 10.0].
  void zoomSceneCamera(double factor) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null || factor == 1.0) return;
    final newZoom = (cam.zoom * factor).clamp(0.1, 10.0);
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(zoom: newZoom),
    ));
  }

  /// Adds [deltaAngle] (radians) to the scene camera rotation.
  void rotateSceneCamera(double deltaAngle) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null || deltaAngle == 0.0) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(rotation: cam.rotation + deltaAngle),
    ));
  }

  /// Sets the scene camera position to an absolute value.
  void setSceneCameraPosition(Offset position) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(position: position),
    ));
  }

  /// Sets the scene camera output size.
  void setSceneCameraSize(Size size) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null || size.width <= 0 || size.height <= 0) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(size: size),
    ));
  }

  /// Sets the scene camera zoom to an absolute value. Clamped to [0.1, 10.0].
  void setSceneCameraZoom(double zoom) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(zoom: zoom.clamp(0.1, 10.0)),
    ));
  }

  /// Sets the scene camera rotation to an absolute value (radians).
  void setSceneCameraRotation(double rotation) {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null) return;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(rotation: rotation),
    ));
  }

  /// Resets the scene camera to default values matching the document artboard.
  void resetSceneCamera() {
    final state = _getState();
    _setState(state.copyWith(
      sceneCamera: SceneCamera.fromDocument(state.document.size),
    ));
  }

  /// Positions and sizes the scene camera to frame the artboard exactly.
  void fitSceneCameraToArtboard() {
    final state = _getState();
    final cam = state.sceneCamera;
    if (cam == null) return;
    final docSize = state.document.size;
    _setState(state.copyWith(
      sceneCamera: cam.copyWith(
        position: Offset(docSize.width / 2, docSize.height / 2),
        size: docSize,
        zoom: 1.0,
        rotation: 0.0,
      ),
    ));
  }
}
