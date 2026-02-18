import 'dart:ui';

import 'package:animation_maker/features/canvas/domain/entities/camera.dart';
import 'package:animation_maker/features/canvas/domain/services/camera_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';

/// View model for managing camera/viewport operations.
///
/// Follows the existing ViewModel pattern where methods take [EditorState]
/// and return a new [EditorState] with camera modifications applied.
class CameraViewModel {
  CameraViewModel({
    CameraService? cameraService,
  }) : _cameraService = cameraService ?? const CameraService();

  final CameraService _cameraService;

  // Gesture tracking state for pinch-zoom
  Camera? _gestureStartCamera;
  Offset? _gestureStartFocalWorld;
  double _gestureStartZoom = 1.0;

  /// Updates the camera state directly.
  EditorState setCamera(EditorState state, Camera camera) {
    return state.copyWith(camera: camera);
  }

  /// Pans the camera by a screen-space delta.
  EditorState pan(EditorState state, Offset screenDelta) {
    final newCamera = _cameraService.pan(
      current: state.camera,
      screenDelta: screenDelta,
    );
    return state.copyWith(camera: newCamera);
  }

  /// Starts a pinch-zoom gesture, capturing initial state.
  void startPinchZoom(EditorState state, Offset screenFocalPoint, Size viewportSize) {
    _gestureStartCamera = state.camera;
    _gestureStartZoom = state.camera.zoom;
    _gestureStartFocalWorld = state.camera.screenToWorld(screenFocalPoint, viewportSize);
  }

  /// Updates pinch-zoom gesture with new scale and optional rotation.
  EditorState updatePinchZoom({
    required EditorState state,
    required Offset screenFocalPoint,
    required Size viewportSize,
    required double scale,
    double? rotation,
  }) {
    if (_gestureStartCamera == null) {
      startPinchZoom(state, screenFocalPoint, viewportSize);
    }

    final limits = _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );

    // Calculate new zoom from gesture start zoom
    final newZoom = (_gestureStartZoom * scale).clamp(limits.minZoom, limits.maxZoom);

    // Calculate scale delta relative to current zoom for focal point adjustment
    final scaleDelta = newZoom / state.camera.zoom;

    final newCamera = _cameraService.pinchZoom(
      current: state.camera,
      screenFocalPoint: screenFocalPoint,
      viewportSize: viewportSize,
      scaleDelta: scaleDelta,
      rotationDelta: rotation,
      minZoom: limits.minZoom,
      maxZoom: limits.maxZoom,
    );

    return state.copyWith(camera: newCamera);
  }

  /// Ends pinch-zoom gesture, clearing tracked state.
  void endPinchZoom() {
    _gestureStartCamera = null;
    _gestureStartFocalWorld = null;
    _gestureStartZoom = 1.0;
  }

  /// Zooms to fit the artboard in the viewport.
  EditorState fitToArtboard(EditorState state, Size viewportSize) {
    final newCamera = _cameraService.fitToArtboard(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );
    return state.copyWith(camera: newCamera);
  }

  /// Zooms to fit the current selection in the viewport.
  EditorState fitToSelection(EditorState state, Size viewportSize) {
    // Calculate selection bounds
    final selectedIds = state.selectedShapeIds.isNotEmpty
        ? state.selectedShapeIds
        : (state.selectedShapeId != null ? [state.selectedShapeId!] : <String>[]);

    if (selectedIds.isEmpty) {
      return fitToArtboard(state, viewportSize);
    }

    // Find bounds of selected shapes
    Rect? combinedBounds;
    for (final shape in state.shapes) {
      if (selectedIds.contains(shape.id)) {
        final bounds = shape.worldBounds;
        if (bounds != null) {
          combinedBounds = combinedBounds?.expandToInclude(bounds) ?? bounds;
        }
      }
    }

    if (combinedBounds == null || combinedBounds.isEmpty) {
      return fitToArtboard(state, viewportSize);
    }

    final limits = _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );

    final newCamera = _cameraService.fitToSelection(
      selectionBounds: combinedBounds,
      viewportSize: viewportSize,
      maxZoom: limits.maxZoom,
    );

    return state.copyWith(camera: newCamera);
  }

  /// Zooms to a specific level centered on a screen point.
  EditorState zoomToPoint({
    required EditorState state,
    required Offset screenPoint,
    required Size viewportSize,
    required double zoom,
  }) {
    final limits = _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );

    final newCamera = _cameraService.zoomToPoint(
      current: state.camera,
      screenPoint: screenPoint,
      viewportSize: viewportSize,
      newZoom: zoom,
      minZoom: limits.minZoom,
      maxZoom: limits.maxZoom,
    );

    return state.copyWith(camera: newCamera);
  }

  /// Zooms in by a fixed percentage.
  EditorState zoomIn(EditorState state, Size viewportSize) {
    final limits = _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );

    final newCamera = _cameraService.zoomIn(
      current: state.camera,
      viewportSize: viewportSize,
      maxZoom: limits.maxZoom,
    );

    return state.copyWith(camera: newCamera);
  }

  /// Zooms out by a fixed percentage.
  EditorState zoomOut(EditorState state, Size viewportSize) {
    final limits = _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );

    final newCamera = _cameraService.zoomOut(
      current: state.camera,
      viewportSize: viewportSize,
      minZoom: limits.minZoom,
    );

    return state.copyWith(camera: newCamera);
  }

  /// Sets zoom to exactly 100% (1:1 pixel mapping).
  EditorState actualSize(EditorState state) {
    final newCamera = _cameraService.actualSize(
      current: state.camera,
      artboardSize: state.document.size,
    );
    return state.copyWith(camera: newCamera);
  }

  /// Resets camera to default view (fit artboard).
  EditorState resetCamera(EditorState state, Size viewportSize) {
    final newCamera = _cameraService.reset(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );
    return state.copyWith(camera: newCamera);
  }

  /// Called when artboard size changes - recalculates camera if needed.
  EditorState onArtboardSizeChanged(
    EditorState state,
    Size newArtboardSize,
    Size viewportSize,
  ) {
    // Re-fit to the new artboard size
    final newCamera = _cameraService.fitToArtboard(
      artboardSize: newArtboardSize,
      viewportSize: viewportSize,
    );
    return state.copyWith(camera: newCamera);
  }

  /// Handles scroll wheel zoom, zooming toward the cursor position.
  EditorState handleScrollZoom({
    required EditorState state,
    required Offset screenPoint,
    required Size viewportSize,
    required double scrollDelta,
  }) {
    // Negative scroll delta = zoom in, positive = zoom out
    final zoomFactor = scrollDelta < 0 ? 1.1 : 0.9;
    final newZoom = state.camera.zoom * zoomFactor;

    return zoomToPoint(
      state: state,
      screenPoint: screenPoint,
      viewportSize: viewportSize,
      zoom: newZoom,
    );
  }

  /// Gets the current zoom limits for the state.
  ({double minZoom, double maxZoom}) getZoomLimits(
    EditorState state,
    Size viewportSize,
  ) {
    return _cameraService.zoomLimits(
      artboardSize: state.document.size,
      viewportSize: viewportSize,
    );
  }

  /// Calculates the visible world rect for the current camera.
  Rect visibleWorldRect(EditorState state, Size viewportSize) {
    return state.camera.visibleWorldRect(viewportSize);
  }
}
