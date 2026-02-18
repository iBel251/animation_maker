import 'dart:ui';
import 'dart:math' as math;

import '../entities/camera.dart';

/// Stateless utility service for camera operations.
///
/// Provides methods for calculating camera positions, handling gestures,
/// and managing zoom/pan operations. All methods are pure functions that
/// return new [Camera] instances.
class CameraService {
  const CameraService();

  /// Default zoom limits.
  static const double defaultMinZoom = 0.005;
  static const double defaultMaxZoom = 20.0;

  /// Calculates camera to fit artboard in viewport with padding.
  ///
  /// The artboard will be centered and scaled to fit within the viewport
  /// while maintaining its aspect ratio.
  Camera fitToArtboard({
    required Size artboardSize,
    required Size viewportSize,
    double paddingPercent = 0.05,
  }) {
    if (artboardSize.isEmpty || viewportSize.isEmpty) {
      return const Camera();
    }

    // Calculate available space after padding
    final padding =
        math.min(viewportSize.width, viewportSize.height) * paddingPercent;
    final availableWidth = viewportSize.width - (padding * 2);
    final availableHeight = viewportSize.height - (padding * 2);

    // Calculate zoom to fit
    final zoomX = availableWidth / artboardSize.width;
    final zoomY = availableHeight / artboardSize.height;
    final zoom = math.min(zoomX, zoomY);

    // Center on artboard center (artboard is at origin, so center is size/2)
    final position = Offset(artboardSize.width / 2, artboardSize.height / 2);

    return Camera(position: position, zoom: zoom);
  }

  /// Calculates camera to fit a selection bounds in viewport.
  ///
  /// Useful for "zoom to selection" functionality.
  Camera fitToSelection({
    required Rect selectionBounds,
    required Size viewportSize,
    double paddingPercent = 0.1,
    double? maxZoom,
  }) {
    if (selectionBounds.isEmpty || viewportSize.isEmpty) {
      return const Camera();
    }

    // Use Camera.fitRect for the calculation
    var camera = Camera.fitRect(
      worldRect: selectionBounds,
      viewportSize: viewportSize,
      paddingPercent: paddingPercent,
    );

    // Clamp to max zoom if specified
    if (maxZoom != null && camera.zoom > maxZoom) {
      camera = camera.copyWith(zoom: maxZoom);
    }

    return camera;
  }

  /// Zooms to a specific point, keeping that point stationary on screen.
  ///
  /// This creates a natural zoom behavior where the user zooms "into"
  /// the point they're focused on.
  Camera zoomToPoint({
    required Camera current,
    required Offset screenPoint,
    required Size viewportSize,
    required double newZoom,
    double minZoom = defaultMinZoom,
    double maxZoom = defaultMaxZoom,
  }) {
    // Clamp the new zoom
    final clampedZoom = newZoom.clamp(minZoom, maxZoom);
    if (clampedZoom == current.zoom) return current;

    // Get the world point under the screen point
    final worldPoint = current.screenToWorld(screenPoint, viewportSize);

    // Calculate what the screen point would map to after zoom change
    // We need to adjust position so worldPoint stays at screenPoint
    final screenCenter = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );
    final offsetFromCenter = screenPoint - screenCenter;

    // In new zoom, this offset corresponds to different world distance
    final worldOffsetNew = offsetFromCenter / clampedZoom;

    // Apply rotation if any
    Offset rotatedOffset = worldOffsetNew;
    if (current.rotation != 0) {
      final cos = math.cos(-current.rotation);
      final sin = math.sin(-current.rotation);
      rotatedOffset = Offset(
        worldOffsetNew.dx * cos - worldOffsetNew.dy * sin,
        worldOffsetNew.dx * sin + worldOffsetNew.dy * cos,
      );
    }

    // New position keeps worldPoint at screenPoint
    final newPosition = worldPoint - rotatedOffset;

    return current.copyWith(position: newPosition, zoom: clampedZoom);
  }

  /// Applies pan delta to camera (in screen space).
  ///
  /// The delta is converted to world space and applied to the camera position.
  Camera pan({required Camera current, required Offset screenDelta}) {
    // Convert screen delta to world delta (accounting for zoom and rotation)
    var worldDelta = screenDelta / current.zoom;

    // Apply inverse rotation if any
    if (current.rotation != 0) {
      final cos = math.cos(-current.rotation);
      final sin = math.sin(-current.rotation);
      worldDelta = Offset(
        worldDelta.dx * cos - worldDelta.dy * sin,
        worldDelta.dx * sin + worldDelta.dy * cos,
      );
    }

    // Subtract delta because dragging right should move camera left (show more right content)
    return current.copyWith(position: current.position - worldDelta);
  }

  /// Handles pinch-zoom gesture, maintaining the focal point position.
  ///
  /// [screenFocalPoint] is the center of the pinch gesture in screen coords.
  /// [scaleDelta] is the relative scale change (e.g., 1.1 for 10% zoom in).
  /// [rotationDelta] is optional rotation change in radians.
  Camera pinchZoom({
    required Camera current,
    required Offset screenFocalPoint,
    required Size viewportSize,
    required double scaleDelta,
    double? rotationDelta,
    double minZoom = defaultMinZoom,
    double maxZoom = defaultMaxZoom,
  }) {
    // Calculate new zoom
    final newZoom = (current.zoom * scaleDelta).clamp(minZoom, maxZoom);

    // Zoom to the focal point
    var result = zoomToPoint(
      current: current,
      screenPoint: screenFocalPoint,
      viewportSize: viewportSize,
      newZoom: newZoom,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    // Apply rotation if provided
    if (rotationDelta != null && rotationDelta != 0) {
      result = result.copyWith(rotation: result.rotation + rotationDelta);
    }

    return result;
  }

  /// Clamps camera to ensure artboard remains at least partially visible.
  ///
  /// This prevents users from panning so far that they lose the artboard.
  Camera clampToArtboard({
    required Camera camera,
    required Size artboardSize,
    required Size viewportSize,
    double minVisibleRatio = 0.1,
  }) {
    final artboardRect = Rect.fromLTWH(
      0,
      0,
      artboardSize.width,
      artboardSize.height,
    );
    final visibleRect = camera.visibleWorldRect(viewportSize);

    // Calculate how much of the artboard should remain visible
    final minVisibleWidth = artboardSize.width * minVisibleRatio;
    final minVisibleHeight = artboardSize.height * minVisibleRatio;

    // Calculate the bounds for camera position
    // Camera position is the center of what's visible
    final halfVisibleWidth = visibleRect.width / 2;
    final halfVisibleHeight = visibleRect.height / 2;

    // Allow panning such that at least minVisible portion remains in view
    final minX = artboardRect.left - halfVisibleWidth + minVisibleWidth;
    final maxX = artboardRect.right + halfVisibleWidth - minVisibleWidth;
    final minY = artboardRect.top - halfVisibleHeight + minVisibleHeight;
    final maxY = artboardRect.bottom + halfVisibleHeight - minVisibleHeight;

    final clampedX = camera.position.dx.clamp(minX, maxX);
    final clampedY = camera.position.dy.clamp(minY, maxY);

    if (clampedX == camera.position.dx && clampedY == camera.position.dy) {
      return camera;
    }

    return camera.copyWith(position: Offset(clampedX, clampedY));
  }

  /// Calculates zoom limits based on artboard size and viewport.
  ///
  /// Returns min/max zoom values that make sense for the given dimensions.
  ({double minZoom, double maxZoom}) zoomLimits({
    required Size artboardSize,
    required Size viewportSize,
    Rect? contentBounds,
    double absoluteMinZoom = 0.005,
    double absoluteMaxZoom = 30.0,
  }) {
    if (artboardSize.isEmpty || viewportSize.isEmpty) {
      return (minZoom: absoluteMinZoom, maxZoom: absoluteMaxZoom);
    }

    // Min zoom: fit entire artboard (or content) plus some margin
    final boundsToFit =
        contentBounds ??
        Rect.fromLTWH(0, 0, artboardSize.width, artboardSize.height);
    final fitZoomX = viewportSize.width / (boundsToFit.width * 1.5);
    final fitZoomY = viewportSize.height / (boundsToFit.height * 1.5);
    final fitZoom = math.min(fitZoomX, fitZoomY);
    final minZoom = math.max(absoluteMinZoom, fitZoom * 0.1);

    // Max zoom: reasonable detail level (e.g., 1 canvas pixel = 20 screen pixels)
    // Also consider GPU limits (8192px framebuffer safety)
    final maxDimension = math.max(artboardSize.width, artboardSize.height);
    final gpuSafeZoom = 8192 / maxDimension;
    final maxZoom = math.min(absoluteMaxZoom, gpuSafeZoom);

    return (minZoom: minZoom, maxZoom: maxZoom);
  }

  /// Zooms in by a fixed percentage (default 10%).
  Camera zoomIn({
    required Camera current,
    required Size viewportSize,
    double factor = 1.1,
    double maxZoom = defaultMaxZoom,
  }) {
    final newZoom = math.min(current.zoom * factor, maxZoom);
    return current.copyWith(zoom: newZoom);
  }

  /// Zooms out by a fixed percentage (default 10%).
  Camera zoomOut({
    required Camera current,
    required Size viewportSize,
    double factor = 1.1,
    double minZoom = defaultMinZoom,
  }) {
    final newZoom = math.max(current.zoom / factor, minZoom);
    return current.copyWith(zoom: newZoom);
  }

  /// Sets zoom to exactly 100% (1:1 pixel mapping).
  Camera actualSize({required Camera current, required Size artboardSize}) {
    // Keep position centered on artboard center at 100% zoom
    return Camera(
      position: Offset(artboardSize.width / 2, artboardSize.height / 2),
      zoom: 1.0,
      rotation: current.rotation,
    );
  }

  /// Resets camera to default view (fit artboard).
  Camera reset({
    required Size artboardSize,
    required Size viewportSize,
    double paddingPercent = 0.05,
  }) {
    return fitToArtboard(
      artboardSize: artboardSize,
      viewportSize: viewportSize,
      paddingPercent: paddingPercent,
    );
  }
}
