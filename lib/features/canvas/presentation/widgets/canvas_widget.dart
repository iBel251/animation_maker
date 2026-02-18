import 'dart:math' as math;
import 'package:animation_maker/features/canvas/domain/entities/camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/viewport_culler.dart';
import 'package:animation_maker/features/canvas/presentation/controllers/canvas_interaction_controller.dart';
import 'package:animation_maker/features/canvas/presentation/services/layer_render_shape_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_raster_paint_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'dart:ui' as ui;

import '../painters/camera_overlay_painter.dart';
import '../painters/canvas_painter.dart';
import '../providers/canvas_notifier.dart';
import '../providers/image_providers.dart';

String? _shapeRasterPaintPath(Shape shape) {
  final metadata = shape.metadata;
  if (metadata == null) return null;
  final raw = metadata[kShapeRasterPaintPathKey];
  if (raw is String && raw.isNotEmpty) {
    return raw;
  }
  return null;
}

/// Gesture configuration constants for consistent, maintainable gesture handling.
class _GestureConfig {
  // Scale thresholds
  static const double scaleUpdateThreshold =
      0.05; // 5% change threshold for scale updates
  static const double translationUpdateThreshold = 0.75;
  static const double minScaleMultiplier =
      0.05; // Allow zooming far below fit scale
  static const double maxScaleMultiplier =
      3.0; // Allow more zoom-in while still conservative
  static const double absoluteMaxScale =
      8.0; // Higher max zoom, still bounded by GPU limits

  // Rotation thresholds
  static const double rotationDeltaThreshold =
      0.0005; // Minimum rotation delta to apply
  static const double maxRotationDelta =
      math.pi * 2; // Prevent excessive rotation in single frame
  static const double gestureScaleDeltaThreshold = 0.001;

  // Timing
  static const Duration panModeDisableDelay = Duration(milliseconds: 300);

  // Boundary margin (screen space). Larger to allow wide panning range.
  static const double boundaryMargin = 20000.0;

  // Validation
  static const double minValidScale = 0.005;
  static const double maxValidScale =
      8.0; // Increased but still bounded by framebuffer limits

  // Maximum framebuffer dimension to prevent GPU crashes
  // Use conservative 8192 limit - safe for most modern devices
  static const double maxFramebufferDimension = 8192.0;

  // Helper to compute max scale based on canvas size to prevent framebuffer overflow
  static double computeMaxScale(double baseScale, {Size? canvasSize}) {
    // Start with base multiplier (conservative)
    double maxScale = math.max(
      baseScale * maxScaleMultiplier,
      absoluteMaxScale,
    );

    // If canvas size is known, limit based on framebuffer constraints
    if (canvasSize != null) {
      final maxDimension = math.max(canvasSize.width, canvasSize.height);
      if (maxDimension > 0) {
        // Calculate max scale that keeps the largest dimension under the limit
        // For 1920px canvas: 8192/1920 = 4.26x max zoom
        final dimensionLimit = maxFramebufferDimension / maxDimension;
        maxScale = math.min(maxScale, dimensionLimit);
      }
    }

    return maxScale.clamp(minValidScale, maxValidScale);
  }
}

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  final TransformationController _controller = TransformationController();
  final CanvasInteractionController _interactionController =
      CanvasInteractionController();
  final ViewportCuller _viewportCuller = const ViewportCuller();
  late CanvasInteractionContext _interactionContext;
  double _lastMaxW = 0;
  double _lastMaxH = 0;
  Size _lastDesignSize = Size.zero;
  double _baseScale = 1.0;
  double _currentScale = 1.0;
  bool _initializedTransform = false;
  bool _rotationInProgress = false;
  double _lastGestureRotation = 0.0;
  double _lastGestureScale = 1.0;
  double _canvasRotation = 0.0;
  Matrix4? _singleTouchNavigationLock;
  Size _lastViewportSize = Size.zero;
  Offset _worldOriginOffset = Offset.zero;
  double? _queuedViewportScale;
  bool _viewportScaleScheduled = false;
  late final ProviderSubscription<bool> _interactionSubscription;
  late final ProviderSubscription<Camera> _cameraSubscription;
  bool _isUpdatingFromCamera = false;
  Camera? _lastSyncedCamera;
  Offset _lastControllerTranslation = Offset.zero;
  Camera? _queuedCamera;
  bool _cameraUpdateScheduled = false;
  bool _pointerRepaintScheduled = false;
  final LayerRenderShapeService _layerRenderShapeService =
      const LayerRenderShapeService();
  static const double _virtualCanvasMultiplier = 50.0;
  static const double _virtualCanvasMin = 100000.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTransformChanged);
    _interactionSubscription = ref.listenManual<bool>(
      editorViewModelProvider.select((state) => state.isInteractingWithCanvas),
      (previous, next) {
        if (previous == true && next == false) {
          _flushViewportScale();
        }
      },
    );
    // Listen for external camera changes (zoom buttons, keyboard shortcuts)
    _cameraSubscription = ref.listenManual<Camera>(
      editorViewModelProvider.select((state) => state.camera),
      (previous, next) {
        _handleExternalCameraChange(previous, next);
      },
    );
  }

  @override
  void dispose() {
    final vm = ref.read(editorViewModelProvider.notifier);
    vm.cancelDrawing();
    vm.cancelShapeDrawing();
    vm.setIsInteractingWithCanvas(false);
    _interactionController.dispose();
    _controller.removeListener(_handleTransformChanged);
    _controller.dispose();
    _interactionSubscription.close();
    _cameraSubscription.close();
    super.dispose();
  }

  /// Handles external camera changes (from zoom buttons, keyboard shortcuts, etc.)
  /// Converts Camera state to InteractiveViewer transformation matrix.
  void _handleExternalCameraChange(Camera? previous, Camera next) {
    if (!mounted) return;

    // Skip if we're the source of this update (from InteractiveViewer gesture)
    if (_isUpdatingFromCamera) return;

    // Skip if camera hasn't meaningfully changed
    if (_lastSyncedCamera != null) {
      final zoomDiff = (next.zoom - _lastSyncedCamera!.zoom).abs();
      final posDiff = (next.position - _lastSyncedCamera!.position).distance;
      // Only sync if zoom changed by more than 1% or position changed significantly
      if (zoomDiff < 0.01 && posDiff < 1.0) {
        return;
      }
    }

    // Skip if viewport size isn't initialized
    if (_lastViewportSize.isEmpty) return;

    // Apply camera state to InteractiveViewer
    _applyCameraToController(next);
  }

  /// Converts Camera state to transformation matrix and applies to controller.
  void _applyCameraToController(Camera camera) {
    if (!mounted) return;

    _isUpdatingFromCamera = true;

    try {
      final viewportCenter = Offset(
        _lastViewportSize.width / 2,
        _lastViewportSize.height / 2,
      );

      // Calculate translation from camera position
      // Camera position is the world point at viewport center
      // screenPoint = worldPoint * zoom + translation
      // translation = screenPoint - worldPoint * zoom
      // translation = viewportCenter - (camera.position + worldOriginOffset) * camera.zoom
      final scenePosition = camera.position + _worldOriginOffset;
      final translation = Offset(
        viewportCenter.dx - scenePosition.dx * camera.zoom,
        viewportCenter.dy - scenePosition.dy * camera.zoom,
      );

      // Build transformation matrix
      final matrix = Matrix4.identity()
        ..translate(translation.dx, translation.dy)
        ..scale(camera.zoom);

      _controller.value = matrix;
      _currentScale = camera.zoom;
      _canvasRotation = camera.rotation;
      _lastControllerTranslation = translation;
      _lastSyncedCamera = camera;

      setState(() {});
    } finally {
      // Reset flag after a short delay to allow transform listener to fire
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isUpdatingFromCamera = false;
        }
      });
    }
  }

  void _handleTransformChanged() {
    if (!mounted) return;

    // Skip if we're programmatically updating from camera state
    if (_isUpdatingFromCamera) return;

    try {
      final matrix = _controller.value;
      final nextScale = matrix.getMaxScaleOnAxis();

      // Validate scale is within reasonable bounds
      if (nextScale < _GestureConfig.minValidScale ||
          nextScale > _GestureConfig.maxValidScale) {
        return; // Ignore invalid scale values
      }

      final translation = matrix.getTranslation();
      final nextTranslation = Offset(translation.x, translation.y);

      final scaleChanged =
          (nextScale - _currentScale).abs() >=
          _GestureConfig.scaleUpdateThreshold;
      final translationChanged =
          (nextTranslation - _lastControllerTranslation).distance >=
          _GestureConfig.translationUpdateThreshold;

      if (!scaleChanged && !translationChanged) {
        return;
      }

      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isUpdatingFromCamera) return;
          try {
            final currentMatrix = _controller.value;
            final currentScale = currentMatrix.getMaxScaleOnAxis();
            final currentTranslationVector = currentMatrix.getTranslation();
            final currentTranslation = Offset(
              currentTranslationVector.x,
              currentTranslationVector.y,
            );
            final currentScaleChanged =
                (currentScale - _currentScale).abs() >=
                _GestureConfig.scaleUpdateThreshold;
            final currentTranslationChanged =
                (currentTranslation - _lastControllerTranslation).distance >=
                _GestureConfig.translationUpdateThreshold;

            if (currentScale >= _GestureConfig.minValidScale &&
                currentScale <= _GestureConfig.maxValidScale &&
                (currentScaleChanged || currentTranslationChanged)) {
              if (currentScaleChanged) {
                setState(() {
                  _currentScale = currentScale;
                });
              }
              _lastControllerTranslation = currentTranslation;
              _syncCameraState(currentScale);
            }
          } catch (e) {
            // Silently handle errors during scale update
            debugPrint('Error updating scale: $e');
          }
        });
      } else {
        if (scaleChanged) {
          setState(() {
            _currentScale = nextScale;
          });
        }
        _lastControllerTranslation = nextTranslation;
        _syncCameraState(nextScale);
      }
    } catch (e) {
      // Silently handle errors during transform change
      debugPrint('Error in transform change handler: $e');
    }
  }

  /// Syncs the camera state from InteractiveViewer's transformation matrix.
  /// Extracts both zoom (scale) and position from the matrix.
  void _syncCameraState(double scale) {
    if (!mounted) return;

    // Extract translation from the transformation matrix
    final matrix = _controller.value;
    final translation = matrix.getTranslation();

    // Calculate camera position in world coordinates
    // The InteractiveViewer's matrix: translate(panX, panY) * scale(zoom)
    // Camera position = center of visible area in world space
    final viewportCenter = Offset(
      _lastViewportSize.width / 2,
      _lastViewportSize.height / 2,
    );

    // Convert viewport center to world coordinates
    // screenPoint = worldPoint * scale + translation
    // worldPoint = (screenPoint - translation) / scale
    final worldCenter =
        Offset(
          (viewportCenter.dx - translation.x) / scale,
          (viewportCenter.dy - translation.y) / scale,
        ) -
        _worldOriginOffset;

    // Create camera with extracted position and zoom
    final newCamera = Camera(
      position: worldCenter,
      zoom: scale,
      rotation: _canvasRotation,
    );

    // Track as last synced to avoid redundant external updates
    _lastSyncedCamera = newCamera;

    // Update camera state in the view model
    _scheduleCameraUpdate(newCamera);
  }

  void _scheduleCameraUpdate(Camera camera) {
    if (!mounted) return;
    _queuedCamera = camera;
    if (_cameraUpdateScheduled) {
      return;
    }
    _cameraUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraUpdateScheduled = false;
      if (!mounted) return;
      final nextCamera = _queuedCamera;
      if (nextCamera == null) return;
      final notifier = ref.read(editorViewModelProvider.notifier);
      notifier.setCamera(nextCamera);
      notifier.setViewportScale(nextCamera.zoom);
    });
  }

  void _scheduleViewportScaleUpdate(double scale) {
    if (!mounted) return;
    _queuedViewportScale = scale;
    final interacting = ref
        .read(editorViewModelProvider)
        .isInteractingWithCanvas;
    if (interacting) return;
    _flushViewportScale();
  }

  void _flushViewportScale() {
    if (!mounted) return;
    if (_viewportScaleScheduled) return;
    _viewportScaleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportScaleScheduled = false;
      if (!mounted) return;
      final value = _queuedViewportScale;
      if (value == null) return;
      ref.read(editorViewModelProvider.notifier).setViewportScale(value);
    });
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    try {
      _rotationInProgress = false;
      _lastGestureRotation = 0.0;
      final isPanMode = ref.read(editorViewModelProvider).isPanMode;
      final isSinglePointer = details.pointerCount <= 1;
      if (!isPanMode && isSinglePointer) {
        _singleTouchNavigationLock = Matrix4.copy(_controller.value);
      } else {
        _singleTouchNavigationLock = null;
      }
    } catch (e) {
      debugPrint('Error in interaction start: $e');
      _rotationInProgress = false;
      _lastGestureRotation = 0.0;
      _singleTouchNavigationLock = null;
    }
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    try {
      final isPanMode = ref.read(editorViewModelProvider).isPanMode;
      final isMultiTouch =
          details.pointerCount > 1 ||
          _interactionController.isMultiTouchInProgress;

      // Allow gesture recognizer to stay enabled globally, but freeze
      // canvas navigation for single-touch when pan mode is off.
      if (!isPanMode && !isMultiTouch) {
        final lock = _singleTouchNavigationLock;
        if (lock != null) {
          _isUpdatingFromCamera = true;
          try {
            _controller.value = Matrix4.copy(lock);
          } finally {
            _isUpdatingFromCamera = false;
          }
        }
        _rotationInProgress = false;
        return;
      }

      _singleTouchNavigationLock = null;

      if (!_interactionController.isMultiTouchInProgress) {
        _rotationInProgress = false;
        return;
      }

      if (!_rotationInProgress) {
        if (details.rotation.abs() < _GestureConfig.rotationDeltaThreshold) {
          return;
        }
        _rotationInProgress = true;
        _lastGestureRotation = details.rotation;
        return;
      }

      final rotationDelta = details.rotation - _lastGestureRotation;
      final clampedDelta = rotationDelta.clamp(
        -_GestureConfig.maxRotationDelta,
        _GestureConfig.maxRotationDelta,
      );

      if (clampedDelta.abs() < _GestureConfig.rotationDeltaThreshold) {
        return;
      }

      if (details.localFocalPoint.dx.isNaN ||
          details.localFocalPoint.dy.isNaN ||
          details.localFocalPoint.dx.isInfinite ||
          details.localFocalPoint.dy.isInfinite) {
        return;
      }

      Offset? focalScene;
      try {
        focalScene = _controller.toScene(details.localFocalPoint);
      } catch (e) {
        debugPrint('Error converting focal point to scene: $e');
        return;
      }

      if (focalScene == null ||
          focalScene.dx.isNaN ||
          focalScene.dy.isNaN ||
          focalScene.dx.isInfinite ||
          focalScene.dy.isInfinite) {
        return;
      }

      setState(() {
        _canvasRotation += clampedDelta;
      });
      _lastGestureRotation = details.rotation;
    } catch (e) {
      debugPrint('Error in interaction update: $e');
      _rotationInProgress = false;
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    try {
      _rotationInProgress = false;
      _lastGestureRotation = 0.0;
      _singleTouchNavigationLock = null;
      _scheduleViewportScaleUpdate(_controller.value.getMaxScaleOnAxis());
    } catch (e) {
      debugPrint('Error in interaction end: $e');
      _rotationInProgress = false;
      _lastGestureRotation = 0.0;
      _singleTouchNavigationLock = null;
    }
  }

  void _ensureCanvasVisible() {
    if (_lastViewportSize.isEmpty || _lastDesignSize.isEmpty) return;
    final rect = Rect.fromLTWH(
      0,
      0,
      _lastDesignSize.width,
      _lastDesignSize.height,
    );
    final corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final transformed = corners.map(_transformPoint).toList(growable: false);
    final minX = transformed.map((p) => p.dx).reduce(math.min);
    final maxX = transformed.map((p) => p.dx).reduce(math.max);
    final minY = transformed.map((p) => p.dy).reduce(math.min);
    final maxY = transformed.map((p) => p.dy).reduce(math.max);
    final canvasScreenRect = Rect.fromLTRB(minX, minY, maxX, maxY);
    final viewportRect = Rect.fromLTWH(
      0,
      0,
      _lastViewportSize.width,
      _lastViewportSize.height,
    ).inflate(32);

    if (!canvasScreenRect.overlaps(viewportRect)) {
      final scale = _computeScale(
        _lastViewportSize.width,
        _lastViewportSize.height,
        _lastDesignSize,
      );
      final offset = Offset(
        (_lastViewportSize.width - _lastDesignSize.width * scale) / 2 -
            _worldOriginOffset.dx * scale,
        (_lastViewportSize.height - _lastDesignSize.height * scale) / 2 -
            _worldOriginOffset.dy * scale,
      );
      _controller.value = Matrix4.identity()
        ..translate(offset.dx, offset.dy)
        ..scale(scale);
      _baseScale = scale;
      _currentScale = scale;
    }
  }

  Offset _transformPoint(Offset point) {
    final scenePoint = point + _worldOriginOffset;
    final vector = _controller.value.transform3(
      Vector3(scenePoint.dx, scenePoint.dy, 0),
    );
    return Offset(vector.x, vector.y);
  }

  @override
  Widget build(BuildContext context) {
    final shapes = ref.watch(editorViewModelProvider.select((s) => s.shapes));
    // Watch document and frame to trigger rebuild when layers change
    final document = ref.watch(
      editorViewModelProvider.select((s) => s.document),
    );
    final currentFrame = ref.watch(
      editorViewModelProvider.select((s) => s.currentFrame),
    );
    final activeLayerId = ref.watch(
      editorViewModelProvider.select((s) => s.activeLayerId),
    );
    // Watch point mode state for preview shape
    final pointModeState = ref.watch(
      editorViewModelProvider.select((s) => s.pointModeState),
    );
    // Watch camera state for viewport culling
    final camera = ref.watch(editorViewModelProvider.select((s) => s.camera));

    // Compute visible shapes from all layers (can't use .select with computed lists)
    var renderShapes = _layerRenderShapeService.compute(
      document: document,
      currentFrame: currentFrame,
      activeLayerId: activeLayerId,
      activeLayerShapes: shapes,
    );

    // Include point mode preview shape if active (it's in state.shapes but not in document yet)
    if (pointModeState.isActive && pointModeState.previewShapeId != null) {
      final previewShape = shapes
          .where((s) => s.id == pointModeState.previewShapeId)
          .firstOrNull;
      if (previewShape != null) {
        renderShapes = [...renderShapes, previewShape];
      }
    }

    // Apply viewport culling for performance (only render visible shapes)
    // Note: We preserve order for correct z-ordering
    if (_lastViewportSize.width > 0 && _lastViewportSize.height > 0) {
      renderShapes = _viewportCuller.cullShapesPreserveOrder(
        shapes: renderShapes,
        camera: camera,
        viewportSize: _lastViewportSize,
        marginPercent: 0.2, // 20% margin for smooth scrolling
      );
    }
    // Build image cache for rendering image shapes
    final imageService = ref.read(imageServiceProvider);
    final imageCache = <String, ui.Image>{};
    final uncachedPaths = <String>[];
    for (final shape in renderShapes) {
      if (shape.kind == ShapeKind.image && shape.imagePath != null) {
        final cached = imageService.getCachedImage(shape.imagePath!);
        if (cached != null) {
          imageCache[shape.imagePath!] = cached;
        } else {
          uncachedPaths.add(shape.imagePath!);
        }
      }
      final rasterPath = _shapeRasterPaintPath(shape);
      if (rasterPath != null) {
        final cached = imageService.getCachedImage(rasterPath);
        if (cached != null) {
          imageCache[rasterPath] = cached;
        } else {
          uncachedPaths.add(rasterPath);
        }
      }
    }
    if (uncachedPaths.isNotEmpty) {
      imageService.preloadImages(uncachedPaths).then((_) {
        if (mounted) setState(() {});
      });
    }

    final selectedShapeId = ref.watch(
      editorViewModelProvider.select((s) => s.selectedShapeId),
    );
    final selectedShapeIds = ref.watch(
      editorViewModelProvider.select((s) => s.selectedShapeIds),
    );
    final activeTool = ref.watch(
      editorViewModelProvider.select((s) => s.activeTool),
    );
    final selectionMode = ref.watch(
      editorViewModelProvider.select((s) => s.selectionMode),
    );
    final isPanMode = ref.watch(
      editorViewModelProvider.select((s) => s.isPanMode),
    );
    final inProgressStroke = ref.watch(
      editorViewModelProvider.select((s) => s.inProgressStroke),
    );
    final brushThickness = ref.watch(
      editorViewModelProvider.select(
        (s) => s.activeTool == EditorTool.eraser
            ? s.eraserSettings.thickness
            : s.brushSettings[s.currentBrush]!.thickness,
      ),
    );
    final brushOpacity = ref.watch(
      editorViewModelProvider.select(
        (s) => s.activeTool == EditorTool.eraser
            ? s.eraserSettings.opacity
            : s.brushSettings[s.currentBrush]!.opacity,
      ),
    );
    final brushSmoothness = ref.watch(
      editorViewModelProvider.select(
        (s) => s.activeTool == EditorTool.eraser
            ? s.eraserSettings.smoothness
            : s.brushSettings[s.currentBrush]!.smoothness,
      ),
    );
    final brushColor = ref.watch(
      editorViewModelProvider.select((s) => s.currentColor),
    );
    final brushType = ref.watch(
      editorViewModelProvider.select((s) => s.currentBrush),
    );
    final strokeScaleWithShape = ref.watch(
      editorViewModelProvider.select((s) => s.strokeScaleWithShape),
    );
    final palmRejectionEnabled = ref.watch(
      editorViewModelProvider.select((s) => s.palmRejectionEnabled),
    );
    final transformGroupAsOne = ref.watch(
      editorViewModelProvider.select((s) => s.transformGroupAsOne),
    );
    final isLinkingMode = ref.watch(
      editorViewModelProvider.select((s) => s.isLinkingMode),
    );
    final pivotSnapEnabled = ref.watch(
      editorViewModelProvider.select((s) => s.pivotSnapEnabled),
    );
    final pivotSnapStrength = ref.watch(
      editorViewModelProvider.select((s) => s.pivotSnapStrength),
    );
    final nodeEditState = ref.watch(
      editorViewModelProvider.select((s) => s.nodeEditState),
    );
    final mergePreviewShape = ref.watch(
      editorViewModelProvider.select((s) => s.mergePreviewShape),
    );
    final sceneCamera = ref.watch(
      editorViewModelProvider.select(
        (s) => s.sceneCameraVisible ? s.sceneCamera : null,
      ),
    );

    final selectionColor = Theme.of(context).colorScheme.primary;

    final canvasSize = ref.watch(
      editorViewModelProvider.select((s) => s.document.size),
    );
    final canvasBackground = ref.watch(
      editorViewModelProvider.select((s) => s.document.background),
    );
    final vm = ref.read(editorViewModelProvider.notifier);
    final selectedShape = _findShape(shapes, selectedShapeId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        _lastViewportSize = Size(maxW, maxH);
        final virtualCanvasSize = _computeVirtualCanvasSize(canvasSize);
        final worldOriginOffset = _computeWorldOriginOffset(
          canvasSize,
          virtualCanvasSize,
        );
        _worldOriginOffset = worldOriginOffset;

        final scale = _computeScale(maxW, maxH, canvasSize);
        final offset = Offset(
          (maxW - canvasSize.width * scale) / 2 - worldOriginOffset.dx * scale,
          (maxH - canvasSize.height * scale) / 2 - worldOriginOffset.dy * scale,
        );

        if (!_initializedTransform ||
            maxW != _lastMaxW ||
            maxH != _lastMaxH ||
            canvasSize != _lastDesignSize) {
          _controller.value = Matrix4.identity()
            ..translate(offset.dx, offset.dy)
            ..scale(scale);
          _lastMaxW = maxW;
          _lastMaxH = maxH;
          _lastDesignSize = canvasSize;
          _baseScale = scale;
          _currentScale = scale;
          _lastControllerTranslation = offset;
          _initializedTransform = true;

          // Initialize camera to fit artboard in viewport
          final initialCamera = Camera.fitRect(
            worldRect: Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
            viewportSize: Size(maxW, maxH),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref
                  .read(editorViewModelProvider.notifier)
                  .setCamera(initialCamera);
            }
          });
        } else {
          _currentScale = _controller.value.getMaxScaleOnAxis();
          _syncCameraState(_currentScale);
        }

        Offset _toCanvas(Offset local) {
          // Transform from screen coordinates to scene coordinates (accounts for InteractiveViewer's scale/pan)
          final scene = _controller.toScene(local);
          if (scene == null) return local;
          final world = scene - worldOriginOffset;

          // If canvas is rotated, we need to apply inverse rotation around canvas center
          // to get the correct canvas coordinates
          if (_canvasRotation != 0.0) {
            final canvasCenter = Offset(
              canvasSize.width / 2,
              canvasSize.height / 2,
            );
            final relativeToCenter = world - canvasCenter;
            final cos = math.cos(-_canvasRotation);
            final sin = math.sin(-_canvasRotation);
            final rotated = Offset(
              relativeToCenter.dx * cos - relativeToCenter.dy * sin,
              relativeToCenter.dx * sin + relativeToCenter.dy * cos,
            );
            return rotated + canvasCenter;
          }

          return world;
        }

        // Create painter with camera and artboard info for unlimited canvas rendering
        final painter = CustomPaint(
          painter: CanvasPainter(
            shapes: renderShapes,
            selectedShapeId: selectedShapeId,
            selectedShapeIds: selectedShapeIds,
            selectionMode: selectionMode,
            inProgressStroke: inProgressStroke,
            brushThickness: brushThickness,
            brushOpacity: brushOpacity,
            brushSmoothness: brushSmoothness,
            brushColor: brushColor,
            strokeScaleWithShape: strokeScaleWithShape,
            selectionColor: selectionColor,
            brushType: brushType,
            showSelectionHandles:
                activeTool == EditorTool.select &&
                selectionMode == SelectionMode.single &&
                selectedShapeId != null &&
                (selectedShapeIds.length <= 1 ||
                    shapes.any(
                      (s) =>
                          s.id == selectedShapeId && s.spatialObjectId != null,
                    )),
            viewportScale: _currentScale,
            rotationGuideCenter: _interactionController.rotationGuideCenter,
            rotationGuideAngle: _interactionController.rotationGuideAngle,
            pivotSnapGuide: _interactionController.pivotSnapGuide,
            activeTool: activeTool,
            nodeEditState: activeTool == EditorTool.nodeEdit
                ? nodeEditState
                : null,
            mergePreviewShape: mergePreviewShape,
            imageCache: imageCache,
            // Unlimited canvas: no artboard guide rendered
            artboardSize: null,
            artboardBackground: null,
            worldOriginOffset: worldOriginOffset,
          ),
          foregroundPainter: sceneCamera != null
              ? CameraOverlayPainter(
                  sceneCamera: sceneCamera,
                  viewportScale: _currentScale,
                  worldOriginOffset: worldOriginOffset,
                  isActive: activeTool == EditorTool.camera,
                )
              : null,
          child: const SizedBox.expand(),
        );

        // For unlimited canvas, use a larger virtual canvas area
        // The artboard is drawn by the painter as a visual guide, not a boundary
        // Virtual size is 3x the artboard size or at least 10000px
        // Canvas surface is a large area for InteractiveViewer
        // No ClipRect - shapes can render anywhere in world space
        final canvasSurface = SizedBox(
          width: virtualCanvasSize.width,
          height: virtualCanvasSize.height,
          child: RepaintBoundary(child: painter),
        );

        final canvasBounds = Rect.fromLTWH(
          -worldOriginOffset.dx,
          -worldOriginOffset.dy,
          virtualCanvasSize.width,
          virtualCanvasSize.height,
        );

        _interactionContext = CanvasInteractionContext(
          activeTool: activeTool,
          selectionMode: selectionMode,
          isPanMode: isPanMode,
          palmRejectionEnabled: palmRejectionEnabled,
          transformGroupAsOne: transformGroupAsOne,
          selectedShapeId: selectedShapeId,
          pivotSnapEnabled: pivotSnapEnabled,
          pivotSnapStrength: pivotSnapStrength,
          isLinkingMode: isLinkingMode,
          readState: () => ref.read(editorViewModelProvider),
          viewModel: vm,
          shapes: shapes,
          selectedShape: selectedShape,
          canvasBounds: canvasBounds,
          toCanvas: _toCanvas,
          readViewportScale: () => _currentScale,
          onNodeStateChanged: vm.setNodeEditState,
          onShapeUpdated: vm.updateShape,
          onHistoryPush: vm.finalizeSelectionEdit,
        );

        // InteractiveViewer handles pinch-zoom (always enabled) and single-finger pan only in pan mode.
        // Compute max scale with canvas size to prevent GPU framebuffer overflow at extreme zoom
        final maxScale = _GestureConfig.computeMaxScale(
          _baseScale,
          canvasSize: canvasSize,
        );
        final minScale = (_baseScale * _GestureConfig.minScaleMultiplier).clamp(
          _GestureConfig.minValidScale,
          _GestureConfig.maxValidScale,
        );
        final rotatedCanvas = Transform.rotate(
          alignment: Alignment.center,
          angle: _canvasRotation,
          child: canvasSurface,
        );
        final allowPanNavigation =
            isPanMode || _interactionController.isMultiTouchInProgress;
        final viewer = InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          // Disable single-touch pan while drawing/selecting; allow pan mode
          // and active multi-touch navigation.
          panEnabled: allowPanNavigation,
          scaleEnabled: true,
          minScale: minScale,
          maxScale: maxScale.clamp(minScale, _GestureConfig.maxValidScale),
          boundaryMargin: const EdgeInsets.all(_GestureConfig.boundaryMargin),
          clipBehavior:
              Clip.none, // Avoid clipping overhead for smoother gestures
          onInteractionStart: _handleInteractionStart,
          onInteractionUpdate: _handleInteractionUpdate,
          onInteractionEnd: _handleInteractionEnd,
          child: rotatedCanvas,
        );

        final lassoRectScreen = _interactionController.lassoRectScreen;

        return SizedBox.expand(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: Stack(
              children: [
                viewer,
                if (lassoRectScreen != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LassoPainter(rect: lassoRectScreen),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final wasMultiTouch = _interactionController.isMultiTouchInProgress;
    final needsRepaint = _interactionController.handlePointerDown(
      _interactionContext,
      event,
    );
    final multiTouchChanged =
        wasMultiTouch != _interactionController.isMultiTouchInProgress;
    if (needsRepaint || multiTouchChanged) {
      _schedulePointerRepaint();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final needsRepaint = _interactionController.handlePointerMove(
      _interactionContext,
      event,
    );
    if (needsRepaint) {
      _schedulePointerRepaint();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasMultiTouch = _interactionController.isMultiTouchInProgress;
    final needsRepaint = _interactionController.handlePointerUp(
      _interactionContext,
      event,
    );
    final multiTouchChanged =
        wasMultiTouch != _interactionController.isMultiTouchInProgress;
    if (needsRepaint || multiTouchChanged) {
      _schedulePointerRepaint();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    final wasMultiTouch = _interactionController.isMultiTouchInProgress;
    final needsRepaint = _interactionController.handlePointerCancel(
      _interactionContext,
      event,
    );
    final multiTouchChanged =
        wasMultiTouch != _interactionController.isMultiTouchInProgress;
    if (needsRepaint || multiTouchChanged) {
      _schedulePointerRepaint();
    }
  }

  void _schedulePointerRepaint() {
    if (!mounted) return;
    if (_pointerRepaintScheduled) return;
    _pointerRepaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pointerRepaintScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  double _computeScale(double maxW, double maxH, Size design) {
    if (maxW <= 0 || maxH <= 0) return 1.0;
    if (design.width <= 0 || design.height <= 0) return 1.0;
    final scaleX = maxW / design.width;
    final scaleY = maxH / design.height;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  Size _computeVirtualCanvasSize(Size artboardSize) {
    return Size(
      math.max(
        artboardSize.width * _virtualCanvasMultiplier,
        _virtualCanvasMin,
      ),
      math.max(
        artboardSize.height * _virtualCanvasMultiplier,
        _virtualCanvasMin,
      ),
    );
  }

  Offset _computeWorldOriginOffset(Size artboardSize, Size virtualCanvasSize) {
    return Offset(
      (virtualCanvasSize.width - artboardSize.width) / 2,
      (virtualCanvasSize.height - artboardSize.height) / 2,
    );
  }

  Shape? _findShape(List<Shape> shapes, String? id) {
    if (id == null) return null;
    for (final s in shapes) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class _LassoPainter extends CustomPainter {
  const _LassoPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.width == 0 && rect.height == 0) return;
    final normalized = Rect.fromPoints(
      Offset(math.min(rect.left, rect.right), math.min(rect.top, rect.bottom)),
      Offset(math.max(rect.left, rect.right), math.max(rect.top, rect.bottom)),
    );
    final fill = Paint()
      ..color = const Color(0x221E88E5)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(normalized, fill);
    _drawDashedRect(canvas, normalized, stroke);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    // Top
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );
    // Right
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );
    // Bottom
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
      paint,
      dashWidth,
      dashSpace,
    );
    // Left
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
      paint,
      dashWidth,
      dashSpace,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final direction = (end - start) / totalLength;
    double distance = 0.0;
    while (distance < totalLength) {
      final currentStart = start + direction * distance;
      distance += dashWidth;
      final currentEnd =
          start + direction * (distance > totalLength ? totalLength : distance);
      canvas.drawLine(currentStart, currentEnd, paint);
      distance += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LassoPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
